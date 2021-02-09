#ifndef _CF_FRAMEBUFFER
#define _CF_FRAMEBUFFER

#include "stddef.h"
#include "stdint.h"
#include "stdlib.h"

typedef struct
{
	size_t left;
	size_t top;
	size_t width;
	size_t height;
} Rectangle;

struct FrameBuffer;
typedef struct FrameBuffer FrameBuffer;

/// Initializes a FrameBuffer structure for the given device.
/// `device` is a path to a framebuffer device; rm2fb-client makes `"/dev/fb0"`
/// work.
/// RETURNS `NULL` if there was a problem initializing the FrameBuffer.
FrameBuffer *FrameBuffer_allocate(char const *device);

void FrameBuffer_deallocate(FrameBuffer *fb);

void FrameBuffer_setPixel(FrameBuffer *fb, size_t x, size_t y, uint16_t color);

void FrameBuffer_flush(FrameBuffer *fb, Rectangle rectangle, int waveform);

Rectangle FrameBuffer_size(FrameBuffer const *fb);

#endif
