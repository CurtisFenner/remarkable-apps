#include "framebuffer.h"

#include <assert.h>
#include <stdint.h>
#include <stdio.h>

#include <fcntl.h>
#include <unistd.h>

#include <sys/ioctl.h>
#include <sys/mman.h>

#include "mxcfb.h"

#define TEMP_USE_REMARKABLE_DRAW 0x0018

struct FrameBuffer
{
	int fileDescriptor;
	size_t widthPixels;
	size_t heightPixels;
	size_t colorDataBytes;
	uint16_t *colorData;
};

FrameBuffer *FrameBuffer_allocate(char const *device)
{
	FrameBuffer *fb = (FrameBuffer *)malloc(sizeof(FrameBuffer));
	if (fb == NULL)
	{
		return NULL;
	}

	fb->fileDescriptor = open(device, O_RDWR);
	if (fb->fileDescriptor < 1)
	{
		fprintf(stderr, "FrameBuffer_initialize: could not open `%s`.\n", device);
		free(fb);
		return NULL;
	}

	// Fetch the size of the display.
	struct fb_var_screeninfo screenInfo;
	if (ioctl(fb->fileDescriptor, FBIOGET_VSCREENINFO, &screenInfo) != 0)
	{
		close(fb->fileDescriptor);
		fprintf(stderr, "FrameBuffer_initialize: could not FBIOGET_VSCREENFINO `%s`.\n", device);
		free(fb);
		return NULL;
	}

	fb->widthPixels = screenInfo.xres;
	fb->heightPixels = screenInfo.yres;

	if (screenInfo.bits_per_pixel != 16)
	{
		close(fb->fileDescriptor);
		fprintf(stderr, "FrameBuffer_initialize: expected 16 bits per pixel, but got %d.\n", screenInfo.bits_per_pixel);
		free(fb);
		return NULL;
	}

	// Memory-map the data buffer.
	fb->colorDataBytes = fb->widthPixels * fb->heightPixels * sizeof(uint16_t);
	fb->colorData = mmap(NULL, fb->colorDataBytes, PROT_WRITE, MAP_SHARED, fb->fileDescriptor, 0);
	if (fb->colorData == MAP_FAILED)
	{
		close(fb->fileDescriptor);
		fprintf(stderr, "FrameBuffer_initialize: mmap failed.\n");
		free(fb);
		return NULL;
	}

	return fb;
}

void FrameBuffer_deallocate(FrameBuffer *fb)
{
	close(fb->fileDescriptor);
	if (munmap(fb->colorData, fb->colorDataBytes) != 0)
	{
		fprintf(stderr, "FrameBuffer_deallocate: munmap unexpectedly failed.\n");
	}
	free(fb);
}

void FrameBuffer_setPixel(FrameBuffer *fb, size_t x, size_t y, uint16_t color)
{
	assert(x < fb->widthPixels);
	assert(y < fb->heightPixels);

	int index = x + y * fb->widthPixels;
	fb->colorData[index] = color;
}

/// `waveform`: 3
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

Rectangle FrameBuffer_size(FrameBuffer const *fb)
{
	return (Rectangle){0, 0, fb->widthPixels, fb->heightPixels};
}
