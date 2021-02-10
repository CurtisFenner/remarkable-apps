#include <math.h>
#include <stdio.h>

#include <unistd.h>

#include "framebuffer.h"
#include "input.h"
#include "interpreter.h"

Rectangle dirtyRectangle = {0, 0, 0, 0};

void penCallback(void *_fb, PenInput const *penInput)
{
	int buttonContact = penInput->touching.pressed;
	int buttonPen = penInput->pen.pressed;
	int buttonEraser = penInput->eraser.pressed;

	FrameBuffer *fb = _fb;
	double px = penInput->xPos.raw / 20966.0;
	double py = penInput->yPos.raw / 15725.0;
	Rectangle size = FrameBuffer_size(fb);
	int mx = (int)(size.width * py);
	int my = (int)(size.height * (1.0 - px));
	// fprintf(stderr, "Stylus state: (%d, %d) pen(%d) eraser(%d) contact(%d)\n",
	// 		mx, my, buttonPen, buttonEraser, buttonContact);

	if (!buttonContact)
	{
		return;
	}

	uint16_t color = buttonPen ? 0 : 0xff;

	int BRUSH = buttonEraser ? 8 : 2;

	for (int u = -BRUSH; u <= BRUSH; u++)
	{
		for (int v = -BRUSH; v <= BRUSH; v++)
		{
			int wx = mx + u;
			int wy = my + v;
			if (0 <= wx && wx < (int)size.width && 0 <= wy && wy < (int)size.height)
			{
				FrameBuffer_setPixel(fb, wx, wy, color);
			}
		}
	}

	int left = mx - BRUSH;
	int top = my - BRUSH;
	int right = mx + BRUSH + 1;
	int bottom = my + BRUSH + 1;
	if (left < 0)
	{
		left = 0;
	}
	if (top < 0)
	{
		top = 0;
	}
	if (right > (int)size.width)
	{
		right = size.width;
	}
	if (bottom > (int)size.height)
	{
		bottom = size.height;
	}
	Rectangle update = {left, top, right - left, bottom - top};
	Rectangle_expandToContain(&dirtyRectangle, update);
}

int main(int argc, char **argv)
{
	if (argc != 2)
	{
		fprintf(stderr, "must pass exactly 2 arguments\n");
		return 1;
	}
	run_script(argv[1]);

	FrameBuffer *fb = FrameBuffer_allocate("/dev/fb0");
	if (fb == NULL)
	{
		return 1;
	}

	Rectangle size = FrameBuffer_size(fb);

	PenInput penInput;
	if (PenInput_init(&penInput, "/dev/input/event1"))
	{
		return 1;
	}

	while (1)
	{
		PenInput_poll(&penInput, fb, penCallback);

		FrameBuffer_flush(fb, dirtyRectangle, 1);
		fprintf(stderr, "Dirty: (%d, %d, %d, %d)\n",
				dirtyRectangle.left, dirtyRectangle.top, dirtyRectangle.width, dirtyRectangle.height);
		dirtyRectangle = (Rectangle){0, 0, 0, 0};
		usleep(30 * 1000);
	}

	return 0;
}
