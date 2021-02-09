#include <math.h>

#include "framebuffer.h"

int main(int argc, char **argv)
{
	FrameBuffer *fb = FrameBuffer_allocate("/dev/fb0");
	if (fb == NULL)
	{
		return 1;
	}

	Rectangle size = FrameBuffer_size(fb);

	for (size_t y = 0; y < size.height; y++)
	{
		for (size_t x = 0; x < size.width; x++)
		{
			int sx = 1 + (int)sqrt(x);
			int sy = 1 + (int)sqrt(y);

			double px = (x - sx * sx) / (double)((sx + 1) * (sx + 1) - sx * sx);

			uint16_t color = 0;
			if (sx % 2 == sy % 2)
			{
				color = (uint16_t)(0xff * px);
			}
			FrameBuffer_setPixel(fb, x, y, color);
		}
	}

	int chunk = size.height / 10;

	Rectangle rectangle = {0, 0 * chunk, size.width, chunk - 32};
	FrameBuffer_flush(fb, rectangle, 0);

	rectangle = (Rectangle){0, 1 * chunk, size.width, chunk - 32};
	FrameBuffer_flush(fb, rectangle, 1);

	rectangle = (Rectangle){0, 2 * chunk, size.width, chunk - 32};
	FrameBuffer_flush(fb, rectangle, 2);

	rectangle = (Rectangle){0, 3 * chunk, size.width, chunk - 32};
	FrameBuffer_flush(fb, rectangle, 3);

	rectangle = (Rectangle){0, 4 * chunk, size.width, chunk - 32};
	FrameBuffer_flush(fb, rectangle, 4);

	rectangle = (Rectangle){0, 5 * chunk, size.width, chunk - 32};
	FrameBuffer_flush(fb, rectangle, 7);

	rectangle = (Rectangle){0, 6 * chunk, size.width, chunk - 32};
	FrameBuffer_flush(fb, rectangle, 257);

	return 0;
}
