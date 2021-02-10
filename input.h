#ifndef _CF_INPUT
#define _CF_INPUT

#include <stdint.h>

typedef struct
{
	int32_t minimum;
	int32_t maximum;
	int32_t raw;
} Axis;

typedef struct
{
	int pressed;
} Button;

typedef struct PenInput PenInput;

typedef struct
{
	// This value is passed as the first argument to the callback.
	void *id;

	void (*callback)(void *id, PenInput const *penInput);
} PenInputCallback;

struct PenInput
{
	int fileDescriptor;

	Axis xPos;
	Axis yPos;
	Axis pressure;
	Axis distance;
	Axis xTilt;
	Axis yTilt;

	// N.B.: pen/erasure become "pressed" prior to actual contact (i.e., when
	// only "hovering")
	Button pen;
	Button eraser;
	Button touching;
};

int PenInput_init(PenInput *input, char const *device);

// Processes data from the input device, and calls the callback at appropriate
// sync times.
void PenInput_poll(PenInput *input, void *data, void (*callback)(void *, PenInput const *));

#endif
