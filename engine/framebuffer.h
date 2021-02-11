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

/// MODIFIES the Rectangle pointed to by a to contain Rectangle b.
/// A zero-area rectangle is considered to be contained by all other rectangles.
void Rectangle_expandToContain(Rectangle *a, Rectangle b);

struct FrameBuffer;
typedef struct FrameBuffer FrameBuffer;

/// Initializes a FrameBuffer structure for the given device.
/// `device` is a path to a framebuffer device;
/// rm2fb-client makes `"/dev/fb0"` work.
/// RETURNS `NULL` if there was a problem initializing the FrameBuffer.
FrameBuffer *FrameBuffer_allocate(char const *device);

/// Frees the resources held by this FrameBuffer, invalidating it.
void FrameBuffer_deallocate(FrameBuffer *fb);

/// Sets the color of a single pixel in this FrameBuffer.
void FrameBuffer_setPixel(FrameBuffer *fb, size_t x, size_t y, uint16_t color);

/// Flushes the contents of the FrameBuffer to the physical display.
/// Only the specified Rectangle is requested to flush.
/// The waveform affects the speed and quality of the update on the display;
/// some waveforms allow fewer colors but are faster or more accurate.
void FrameBuffer_flush(FrameBuffer *fb, Rectangle rectangle, int waveform);

/// Gets the size of the FrameBuffer. The width and height are bounds on
/// coordinates passed to `FrameBuffer_setPixel`.
Rectangle FrameBuffer_size(FrameBuffer const *fb);

#endif
