#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include "stdio.h"
#include "stdbool.h"

#include "interpreter.h"

#include "framebuffer.h"
#include "input.h"

typedef struct
{
	PenInput *penInput;
	FrameBuffer *frameBuffer;
} Device;

static int s_FrameBuffer_size(lua_State *L)
{
	Device *vfb = luaL_checkudata(L, 1, "C-FrameBuffer");
	FrameBuffer *fb = vfb->frameBuffer;
	Rectangle size = FrameBuffer_size(fb);
	lua_pushinteger(L, size.width);
	lua_pushinteger(L, size.height);
	return 2;
}

static int s_FrameBuffer_setPixel(lua_State *L)
{
	Device *vfb = luaL_checkudata(L, 1, "C-FrameBuffer");
	FrameBuffer *fb = vfb->frameBuffer;
	lua_Integer ix = luaL_checkinteger(L, 2);
	lua_Integer iy = luaL_checkinteger(L, 3);
	lua_Integer icolor = luaL_checkinteger(L, 4);

	Rectangle size = FrameBuffer_size(fb);
	if (ix < 0 || ix >= size.width)
	{
		return 0;
	}
	else if (iy < 0 || iy >= size.height)
	{
		return 0;
	}
	else if (icolor < 0 || icolor > UINT16_MAX)
	{
		luaL_error(L, "invalid color `%d`", icolor);
	}

	FrameBuffer_setPixel(fb, (size_t)ix, (size_t)iy, (uint16_t)icolor);

	return 0;
}

typedef struct
{
	lua_State *L;
	Rectangle screenSize;
} s_PenInput_pollPen_callback_closure;

static void s_PenInput_pollPen_callback(void *vclosure, PenInput const *penInput)
{
	s_PenInput_pollPen_callback_closure *closure = vclosure;
	lua_State *L = closure->L;

	double px = penInput->xPos.raw / 20966.0;
	double py = penInput->yPos.raw / 15725.0;
	int mx = (int)(closure->screenSize.width * py);
	int my = (int)(closure->screenSize.height * (1.0 - px));

	// Make a copy of the callback function.
	lua_pushvalue(L, 2);

	// Construct a Lua table describing the pen's state.
	lua_newtable(L);

	lua_pushstring(L, "xPos");
	lua_pushnumber(L, mx);
	lua_rawset(L, -3);

	lua_pushstring(L, "yPos");
	lua_pushnumber(L, my);
	lua_rawset(L, -3);

	lua_pushstring(L, "touching");
	lua_pushboolean(L, penInput->touching.pressed);
	lua_rawset(L, -3);

	lua_pushstring(L, "hoverDraw");
	lua_pushboolean(L, penInput->pen.pressed);
	lua_rawset(L, -3);

	lua_pushstring(L, "hoverErase");
	lua_pushboolean(L, penInput->eraser.pressed);
	lua_rawset(L, -3);

	// Invoke the function at position 3.
	lua_call(L, 1, 0);
}

static int s_PenInput_pollPen(lua_State *L)
{
	Device *device = luaL_checkudata(L, 1, "C-PenInput");
	PenInput *pi = device->penInput;
	luaL_checktype(L, 2, LUA_TFUNCTION);

	Rectangle screenSize = FrameBuffer_size(device->frameBuffer);
	s_PenInput_pollPen_callback_closure closure = {L, screenSize};
	PenInput_poll(pi, &closure, s_PenInput_pollPen_callback);

	return 0;
}

static int s_FrameBuffer_flush(lua_State *L)
{
	Device *device = luaL_checkudata(L, 1, "C-FrameBuffer");
	lua_Integer x1 = luaL_checkinteger(L, 2);
	lua_Integer y1 = luaL_checkinteger(L, 3);
	lua_Integer x2 = luaL_checkinteger(L, 4);
	lua_Integer y2 = luaL_checkinteger(L, 5);
	lua_Integer waveform = luaL_checkinteger(L, 6);

	Rectangle screenSize = FrameBuffer_size(device->frameBuffer);

	if (x2 <= x1 || y2 <= y1)
	{
		return 0;
	}
	if (x1 < 0 || x1 >= screenSize.width)
	{
		return luaL_error(L, "x1 `%d` is out of bounds.", x1);
	}
	else if (y1 < 0 || y1 > screenSize.height)
	{
		return luaL_error(L, "y1 `%d` is out of bounds", y1);
	}
	else if (x2 > screenSize.width)
	{
		return luaL_error(L, "x2 `%d` is out of bounds.", x2);
	}
	else if (y2 > screenSize.height)
	{
		return luaL_error(L, "y2 `%d` is out of bounds.", y2);
	}

	Rectangle rect = {x1, y1, x2 - x1, y2 - y1};

	FrameBuffer_flush(device->frameBuffer, rect, waveform);
	return 0;
}

void run_script(char const *script, PenInput *penInput, FrameBuffer *fb)
{
	lua_State *L = luaL_newstate();

	Device *vfb = lua_newuserdata(L, sizeof(Device));
	*vfb = (Device){penInput, fb};
	if (luaL_newmetatable(L, "C-FrameBuffer"))
	{
		lua_pushstring(L, "__index");
		lua_newtable(L);

		lua_pushstring(L, "setPixel");
		lua_pushcfunction(L, s_FrameBuffer_setPixel);
		lua_rawset(L, -3);

		lua_pushstring(L, "size");
		lua_pushcfunction(L, s_FrameBuffer_size);
		lua_rawset(L, -3);

		lua_pushstring(L, "flush");
		lua_pushcfunction(L, s_FrameBuffer_flush);
		lua_rawset(L, -3);

		lua_rawset(L, -3);
	}
	lua_setmetatable(L, -2);
	lua_setglobal(L, "rm_fb");

	Device *vpi = lua_newuserdata(L, sizeof(Device));
	*vpi = (Device){penInput, fb};
	if (luaL_newmetatable(L, "C-PenInput"))
	{
		lua_pushstring(L, "__index");
		lua_newtable(L);

		lua_pushstring(L, "poll");
		lua_pushcfunction(L, s_PenInput_pollPen);
		lua_rawset(L, -3);

		lua_rawset(L, -3);
	}
	lua_setmetatable(L, -2);
	lua_setglobal(L, "rm_pen");

	luaL_openlibs(L);

	if (luaL_dofile(L, script) != LUA_OK)
	{
		fprintf(stderr, "run_script: error running `%s`\n", script);
		fprintf(stderr, "\t```%s```\n", lua_tostring(L, -1));
	}

	lua_close(L);
}
