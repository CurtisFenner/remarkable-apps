#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

void run_script(char const *script)
{
	lua_State *L = luaL_newstate();

	luaL_openlibs(L);

	luaL_dostring(L, "print('hi there')");

	lua_close(L);
}
