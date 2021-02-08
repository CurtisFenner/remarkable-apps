#include <assert.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>

#include <fcntl.h>
#include <unistd.h>

#include <sys/ioctl.h>
#include <sys/mman.h>

#include "mxcfb.h"

// ?
#define TEMP_USE_REMARKABLE_DRAW 0x0018

typedef struct
{
	int left;
	int top;
	int width;
	int height;
} Rectangle;

typedef struct
{
	int fileDescriptor;
	size_t widthPixels;
	size_t heightPixels;
	size_t colorDataBytes;
	uint16_t *colorData;
} FrameBuffer;

/// Initializes a given FrameBuffer structure.
/// `device` is a path to a framebuffer device; rm2fb-client makes `"/dev/fb0"`
/// work.
/// RETURNS non-zero if there was a problem initializing the FrameBuffer.
int FrameBuffer_initialize(FrameBuffer *fb, char const *device)
{
	fb->fileDescriptor = open(device, O_RDWR);
	if (fb->fileDescriptor < 1)
	{
		fprintf(stderr, "FrameBuffer_initialize: could not open `%s`.\n", device);
		return 1;
	}

	// Fetch the size of the display.
	struct fb_var_screeninfo screenInfo;
	if (ioctl(fb->fileDescriptor, FBIOGET_VSCREENINFO, &screenInfo) != 0)
	{
		close(fb->fileDescriptor);
		fprintf(stderr, "FrameBuffer_initialize: could not FBIOGET_VSCREENFINO `%s`.\n", device);
		return 1;
	}

	fb->widthPixels = screenInfo.xres;
	fb->heightPixels = screenInfo.yres;

	if (screenInfo.bits_per_pixel != 16)
	{
		close(fb->fileDescriptor);
		fprintf(stderr, "FrameBuffer_initialize: expected 16 bits per pixel, but got %d.\n", screenInfo.bits_per_pixel);
		return 1;
	}

	// Memory-map the data buffer.
	fb->colorDataBytes = fb->widthPixels * fb->heightPixels * sizeof(uint16_t);
	fb->colorData = mmap(NULL, fb->colorDataBytes, PROT_WRITE, MAP_SHARED, fb->fileDescriptor, 0);
	if (fb->colorData == MAP_FAILED)
	{
		close(fb->fileDescriptor);
		fprintf(stderr, "FrameBuffer_initialize: mmap failed.\n");
		return 1;
	}

	return 0;
}

void FrameBuffer_setPixel(FrameBuffer *fb, size_t x, size_t y, uint16_t color)
{
	assert(x < fb->widthPixels);
	assert(y < fb->heightPixels);

	int index = x + y * fb->widthPixels;
	fb->colorData[index] = color;
}

/// `waveform`: 3: didn't
void FrameBuffer_flush(FrameBuffer *fb, Rectangle rectangle, int waveform)
{
	struct mxcfb_update_data updateRequest;

	updateRequest.update_region.left = rectangle.left;
	updateRequest.update_region.top = rectangle.top;
	updateRequest.update_region.width = rectangle.width;
	updateRequest.update_region.height = rectangle.height;

	updateRequest.update_marker = 0;
	updateRequest.waveform_mode = waveform;

	// Perform a partial update.
	updateRequest.update_mode = 0;

	// ??
	updateRequest.dither_mode = 0;

	updateRequest.temp = TEMP_USE_REMARKABLE_DRAW;
	updateRequest.flags = 0;

	// Sync the mapped memory to ensure it is visible to the server.
	if (msync(fb->colorData, fb->colorDataBytes, MS_SYNC))
	{
		fprintf(stderr, "FrameBuffer_flush: unexpected error from msync.\n");
	}

	if (ioctl(fb->fileDescriptor, MXCFB_SEND_UPDATE, &updateRequest))
	{
		fprintf(stderr, "FrameBuffer_flush: unexpected error from ioctl.\n");
	}
}

int main(int argc, char **argv)
{
	FrameBuffer fb;
	if (FrameBuffer_initialize(&fb, "/dev/fb0"))
	{
		return 1;
	}

	for (int y = 0; y < fb.heightPixels; y++)
	{
		for (int x = 0; x < fb.widthPixels; x++)
		{
			int sx = 1 + (int)sqrt(x);
			int sy = 1 + (int)sqrt(y);

			uint16_t color = 0;
			if (sx % 2 == sy % 2)
			{
				color = 0xff;
			}
			FrameBuffer_setPixel(&fb, x, y, color);
		}
	}

	Rectangle rectangle = {0, 0, fb.widthPixels, fb.heightPixels};
	FrameBuffer_flush(&fb, rectangle, 3);

	return 0;
}
