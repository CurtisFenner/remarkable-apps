#include "clock.h"

double Clock_getSeconds(Clock const *clock)
{
	struct timespec ts;
	clock_gettime(clock->id, &ts);
	return ts.tv_sec + 1.0e-9 * ts.tv_nsec;
}

Clock Clock_monotonic()
{
	return (Clock){CLOCK_MONOTONIC};
}

Clock Clock_calendar1970()
{
	return (Clock){CLOCK_REALTIME};
}
