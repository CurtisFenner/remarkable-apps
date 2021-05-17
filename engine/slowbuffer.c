#include "slowbuffer.h"

#include <stdbool.h>
#include <math.h>
#include <string.h>
#include <stdio.h>

#include "clock.h"

const double TIME_BOX_SECONDS = 10.0;
const double MIN_PULSE_SECONDS = 0.26;

typedef struct
{
	uint16_t ticks;
} Periodic;

typedef struct
{
	Rectangle rect;
	Periodic wait_until;
} QElement;

Periodic fromSeconds(double seconds)
{
	double onUnit = fmod(fmod(seconds, TIME_BOX_SECONDS) / TIME_BOX_SECONDS + 1, 1.0);
	return (Periodic){(uint16_t)(onUnit * UINT16_MAX)};
}

Periodic Periodic_add(Periodic a, Periodic b)
{
	return (Periodic){(uint16_t)(a.ticks + b.ticks)};
}

bool Periodic_before(Periodic a, Periodic b)
{
	return (uint16_t)(b.ticks - a.ticks) < UINT16_MAX / 2;
}

struct SlowBuffer
{
	FrameBuffer *fb;

	size_t widthPixels;
	size_t heightPixels;

	uint8_t *flushed_color;
	uint8_t *unflushed_color;
	uint16_t *flushed_at;

	size_t queueCapacity;
	size_t queueWrite;
	size_t queueRead;
	QElement *queue;
};

SlowBuffer *SlowBuffer_allocate(FrameBuffer *fb)
{
	SlowBuffer *sb = (SlowBuffer *)malloc(sizeof(SlowBuffer));
	if (sb == NULL)
	{
		return NULL;
	}

	sb->fb = fb;

	Rectangle size = FrameBuffer_size(fb);
	sb->widthPixels = size.width;
	sb->heightPixels = size.height;
	size_t count = size.width * size.height;

	sb->flushed_color = malloc(sizeof(uint8_t) * count);
	memset(sb->flushed_color, 15, sizeof(uint8_t) * count);

	sb->unflushed_color = malloc(sizeof(uint8_t) * count);
	memset(sb->unflushed_color, 15, sizeof(uint8_t) * count);

	sb->flushed_at = malloc(sizeof(uint16_t) * count);
	memset(sb->flushed_at, 0, sizeof(uint16_t) * count);

	sb->queueCapacity = 40000;
	sb->queue = (QElement *)malloc(sizeof(QElement) * sb->queueCapacity);
	sb->queueWrite = 0;
	sb->queueRead = 0;
	for (size_t i = 0; i < sb->queueCapacity; i++)
	{
		sb->queue[i].wait_until.ticks = 0;
		sb->queue[i].rect = (Rectangle){0, 0, 0, 0};
	}
	return sb;
}

void SlowBuffer_setPixel(SlowBuffer *sb, size_t x, size_t y, uint8_t color)
{
	if (x >= sb->widthPixels || y >= sb->heightPixels)
	{
		return;
	}
	size_t index = x + y * sb->widthPixels;
	sb->unflushed_color[index] = color;
}

void SlowBuffer_setRect(SlowBuffer *sb, Rectangle rect, uint8_t color)
{
	size_t width = sb->widthPixels;
	size_t x2 = rect.left + rect.width;
	if (x2 > width)
	{
		x2 = width;
	}
	if (x2 > rect.left)
	{
		size_t w = x2 - rect.left;
		size_t y2 = rect.top + rect.height;
		for (size_t y = rect.top; y < y2 && y < sb->heightPixels; y++)
		{
			memset(sb->unflushed_color + y * width + rect.left, color, w);
		}
	}
}

static bool SlowBuffer_tryflush(SlowBuffer *sb, Rectangle rect, QElement *delay)
{
	Clock clock = Clock_monotonic();

	Periodic now = fromSeconds(Clock_getSeconds(&clock));
	Periodic pulseAgo = Periodic_add(now, fromSeconds(-MIN_PULSE_SECONDS));

	size_t width = sb->widthPixels;
	size_t x2 = rect.left + rect.width;
	if (x2 > width)
	{
		x2 = width;
	}

	delay->rect.width = 0;
	delay->rect.height = 0;
	delay->wait_until = Periodic_add(now, fromSeconds(MIN_PULSE_SECONDS));
	delay->wait_until.ticks += 10;

	size_t screenWidth = sb->widthPixels;

	size_t updated = 0;
	size_t delayed = 0;

	if (x2 > rect.left)
	{
		size_t y2 = rect.top + rect.height;
		Rectangle pixel = {0, 0, 1, 1};
		for (pixel.top = rect.top; pixel.top < y2 && pixel.top < sb->heightPixels; pixel.top++)
		{
			for (pixel.left = rect.left; pixel.left < x2; pixel.left++)
			{
				size_t index = pixel.top * screenWidth + pixel.left;
				uint8_t flushed_color = sb->flushed_color[index];
				uint8_t unflushed_color = sb->unflushed_color[index];
				if (flushed_color != unflushed_color)
				{
					Periodic flushed_at = {sb->flushed_at[index]};
					if (Periodic_before(pulseAgo, flushed_at) && Periodic_before(flushed_at, now))
					{
						Rectangle_expandToContain(&delay->rect, pixel);
						delayed += 1;
					}
					else
					{
						FrameBuffer_setPixel(sb->fb, pixel.left, pixel.top, unflushed_color);
						sb->flushed_color[index] = unflushed_color;
						sb->flushed_at[index] = now.ticks;

						updated += 1;
					}
				}
			}
		}
	}

	FrameBuffer_flush(sb->fb, rect, 1);

	return delay->rect.width != 0;
}

void SlowBuffer_flush(SlowBuffer *sb, Rectangle rectangle)
{
	// Flush ONLY those pixels which were rendered long enough ago.
	if (SlowBuffer_tryflush(sb, rectangle, &sb->queue[sb->queueWrite]))
	{
		sb->queueWrite = (sb->queueWrite + 1) % sb->queueCapacity;
	}
	SlowBuffer_ping(sb);
}

void SlowBuffer_ping(SlowBuffer *sb)
{
	// Consume from the queue.
	Clock clock = Clock_monotonic();
	Periodic now = fromSeconds(Clock_getSeconds(&clock));

	// Assume the queue buffer doesn't fill up
	// (would require flushes > queueCapacity within MIN_PULSE_SECONDS pings())
	while (sb->queueRead != sb->queueWrite)
	{
		QElement dummy = {{0, 0, 0, 0}, {0}};
		QElement *front = sb->queue + sb->queueRead;
		if (Periodic_before(front->wait_until, now))
		{
			SlowBuffer_tryflush(sb, front->rect, &dummy);
			sb->queueRead = (sb->queueRead + 1) % (sb->queueCapacity);
		}
		else
		{
			break;
		}
	}
}

Rectangle SlowBuffer_size(SlowBuffer *sb)
{
	return FrameBuffer_size(sb->fb);
}

void SlowBuffer_deallocate(SlowBuffer *sb)
{
	free(sb->flushed_color);
	free(sb->unflushed_color);
	free(sb->flushed_at);
	free(sb->queue);
	free(sb);
}
