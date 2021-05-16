#ifndef _CF_TIME
#define _CF_TIME

#include <time.h>

typedef struct
{
	clockid_t id;
} Clock;

double Clock_getSeconds(Clock const *clock);

Clock Clock_monotonic();
Clock Clock_calendar1970();

#endif
