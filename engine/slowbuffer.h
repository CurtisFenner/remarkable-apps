#ifndef _CF_SLOWBUFFER
#define _CF_SLOWBUFFER

#include "stddef.h"

#include "framebuffer.h"

struct SlowBuffer;
typedef struct SlowBuffer SlowBuffer;

SlowBuffer *SlowBuffer_allocate(FrameBuffer *fb);

void SlowBuffer_deallocate(SlowBuffer *sb);

void SlowBuffer_setPixel(SlowBuffer *sb, size_t x, size_t y, uint8_t color);
void SlowBuffer_setRect(SlowBuffer *sb, Rectangle rect, uint8_t color);

void SlowBuffer_flush(SlowBuffer *sb, Rectangle rectangle);

Rectangle SlowBuffer_size(SlowBuffer *sb);

void SlowBuffer_ping(SlowBuffer *sb);

#endif
