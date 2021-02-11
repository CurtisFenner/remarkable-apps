#include "input.h"

#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <poll.h>
#include <unistd.h>
#include <errno.h>
#include <sys/time.h>
#include <linux/input.h>

int PenInput_init(PenInput *input, char const *device)
{
	input->fileDescriptor = open(device, O_RDONLY);

	input->xPos = (Axis){0, 0, 0};
	input->yPos = (Axis){0, 0, 0};

	input->pressure = (Axis){0, 0, 0};
	input->distance = (Axis){0, 0, 0};

	input->xTilt = (Axis){0, 0, 0};
	input->yTilt = (Axis){0, 0, 0};

	input->pen = (Button){0};
	input->eraser = (Button){0};
	input->touching = (Button){0};

	return 0;
}

void PenInput_free(PenInput *input)
{
	close(input->fileDescriptor);
}

// https://github.com/torvalds/linux/blob/master/include/uapi/linux/input.h#L28

/// `packet`: An input_event packet of 8 + 2 + 2 + 4 bytes.
static void PenInput_processPacket(PenInput *input, struct input_event event, void *data, void (*callback)(void *, PenInput const *))
{
	if (event.type == 0)
	{
		// Callback time!
		if (callback != NULL)
		{
			callback(data, input);
		}
	}
	else if (event.type == 1)
	{
		// "Buttons"
		Button *button = NULL;
		if (event.code == 320)
		{
			button = &input->pen;
		}
		else if (event.code == 321)
		{
			button = &input->eraser;
		}
		else if (event.code == 330)
		{
			button = &input->touching;
		}

		if (button != NULL)
		{
			button->pressed = event.value;
		}
	}
	else if (event.type == 3)
	{
		// "Absolutes"
		Axis *axis = NULL;
		if (event.code == 0)
		{
			axis = &input->xPos;
		}
		else if (event.code == 1)
		{
			axis = &input->yPos;
		}
		else if (event.code == 24)
		{
			axis = &input->pressure;
		}
		else if (event.code == 25)
		{
			axis = &input->distance;
		}
		else if (event.code == 26)
		{
			axis = &input->xTilt;
		}
		else if (event.code == 27)
		{
			axis = &input->yTilt;
		}

		if (axis != NULL)
		{
			axis->raw = event.value;
		}
	}
}

void PenInput_poll(PenInput *input, void *data, void (*callback)(void *, PenInput const *))
{
	struct timeval began;
	gettimeofday(&began, NULL);

	while (1)
	{
		struct pollfd fds[1];
		// TODO: Needs to set poll events.
		fds[0] = (struct pollfd){input->fileDescriptor, POLLIN, 0};

		// Wait for 50 milliseconds
		int success = poll(&fds[0], 1, 50);
		// printf("poll result: %d\n", success);
		if (success < 0)
		{
			fprintf(stderr, "PenInput_poll: unexpected error %d from poll.\n", errno);
			return;
		}
		else if (success == 0)
		{
			// No inputs
			return;
		}

		struct input_event event;
		size_t progress = 0;
		while (progress < sizeof(event))
		{
			int r = read(input->fileDescriptor, ((char *)&event) + progress, sizeof(event) - progress);
			if (r < 0)
			{
				fprintf(stderr, "PenInput_poll: unexpect error %d from read.\n", errno);
				continue;
			}
			progress += r;
		}
		PenInput_processPacket(input, event, data, callback);

		if (timercmp(&began, &event.time, <))
		{
			break;
		}
	}
}

// https://github.com/freedesktop-unofficial-mirror/evtest/blob/master/evtest.c

/*
Select the device event number [0-2]: 1
Input driver version is 1.0.1
Input device ID: bus 0x18 vendor 0x56a product 0x0 version 0x30
Input device name: "Wacom I2C Digitizer"
Supported events:
  Event type 0 (EV_SYN)
  Event type 1 (EV_KEY)
    Event code 320 (BTN_TOOL_PEN)
    Event code 321 (BTN_TOOL_RUBBER)
    Event code 330 (BTN_TOUCH)
    Event code 331 (BTN_STYLUS)
    Event code 332 (BTN_STYLUS2)
  Event type 3 (EV_ABS)
    Event code 0 (ABS_X)
      Value   7000
      Min        0
      Max    20966
    Event code 1 (ABS_Y)
      Value   3307
      Min        0
      Max    15725
    Event code 24 (ABS_PRESSURE)
      Value      0
      Min        0
      Max     4095
    Event code 25 (ABS_DISTANCE)
      Value     89
      Min        0
      Max      255
    Event code 26 (ABS_TILT_X)
      Value    600
      Min    -9000
      Max     9000
    Event code 27 (ABS_TILT_Y)
      Value  -3300
      Min    -9000
      Max     9000
Properties:
Testing ... (interrupt to exit)
*/

/*
Select the device event number [0-2]: 2
Input driver version is 1.0.1
Input device ID: bus 0x0 vendor 0x0 product 0x0 version 0x0
Input device name: "cyttsp5_mt"
Supported events:
  Event type 0 (EV_SYN)
  Event type 1 (EV_KEY)
  Event type 2 (EV_REL)
  Event type 3 (EV_ABS)
    Event code 25 (ABS_DISTANCE)
      Value      0
      Min        0
      Max      255
    Event code 47 (ABS_MT_SLOT)
      Value      0
      Min        0
      Max       31
    Event code 48 (ABS_MT_TOUCH_MAJOR)
      Value      0
      Min        0
      Max      255
    Event code 49 (ABS_MT_TOUCH_MINOR)
      Value      0
      Min        0
      Max      255
    Event code 52 (ABS_MT_ORIENTATION)
      Value      0
      Min     -127
      Max      127
    Event code 53 (ABS_MT_POSITION_X)
      Value      0
      Min        0
      Max     1403
    Event code 54 (ABS_MT_POSITION_Y)
      Value      0
      Min        0
      Max     1871
    Event code 55 (ABS_MT_TOOL_TYPE)
      Value      0
      Min        0
      Max        1
    Event code 57 (ABS_MT_TRACKING_ID)
      Value      0
      Min        0
      Max    65535
    Event code 58 (ABS_MT_PRESSURE)
      Value      0
      Min        0
      Max      255

*/
