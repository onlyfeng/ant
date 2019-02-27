#define LUA_LIB
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <string.h>
#include <stdio.h>

static int DEBUG_HOST = 0;	// host L in client VM
static int DEBUG_CLIENT = 0;	// client L in host VM for hook
static int DEBUG_HOOK = 0;	// hook function in client VM (void * in host VM)

int eval_value(lua_State *L, lua_State *cL);
void probe(lua_State* cL, lua_State* hL, const char* name);

static void
clear_client(lua_State *L) {
	lua_pushnil(L);
	lua_rawsetp(L, LUA_REGISTRYINDEX, &DEBUG_HOOK);	// clear hook

	lua_State *cL = NULL;
	if (lua_rawgetp(L, LUA_REGISTRYINDEX, &DEBUG_CLIENT) != LUA_TNIL) {
		cL = lua_touserdata(L, -1);
	}
	lua_pop(L, 1);
	lua_pushnil(L);
	lua_rawsetp(L, LUA_REGISTRYINDEX, &DEBUG_CLIENT);

	if (cL) {
		lua_close(cL);
	}
}

static int
lhost_clear(lua_State *L) {
	clear_client(L);
	return 0;
}

static void
copy_string(lua_State *L, lua_State *cL, const char * key) {
	if (lua_getfield(L, -1, key) != LUA_TSTRING)
		luaL_error(L, "Invalid string : package.%s", key);
	const char * s = lua_tostring(L, -1);
	lua_pushstring(cL, s);
	lua_setfield(cL, -2, key);
	lua_pop(L, 1);
}

static void
copy_package_path(lua_State *hL, lua_State *L) {
	if (lua_getglobal(hL, "package") != LUA_TTABLE)
		luaL_error(L, "No package");
	if (lua_getglobal(L, "package") != LUA_TTABLE)
		luaL_error(L, "No package in debugger VM");

	copy_string(hL, L, "path");
	copy_string(hL, L, "cpath");

	lua_pop(L, 1);
	lua_pop(hL, 1);
}

// 1. lightuserdata string_mainscript
// 2. lightuserdata host_L
static int
client_main(lua_State *L) {
	lua_State *hL = lua_touserdata(L, 2);
	luaL_openlibs(L);
	copy_package_path(hL, L);

	lua_pushvalue(L, 2);
	lua_rawsetp(L, LUA_REGISTRYINDEX, &DEBUG_HOST);	// set host L

	const char * mainscript = (const char *)lua_touserdata(L, 1);


	if (luaL_loadstring(L, mainscript) != LUA_OK) {
		return lua_error(L);
	}
	lua_pushvalue(L, 3);	// preprocessor
	lua_call(L, 1, 0);
	return 0;
}

static void
push_errmsg(lua_State *L, lua_State *cL) {
	if (lua_type(cL, -1) != LUA_TSTRING) {
		lua_pushstring(L, "Unknown Error");
	} else {
		size_t sz = 0;
		const char * err = lua_tolstring(cL, -1, &sz);
		lua_pushlstring(L, err, sz);
	}
}

static int
lhost_start(lua_State *L) {
	clear_client(L);
	lua_CFunction preprocessor = NULL;
	const char * mainscript = luaL_checkstring(L, 1);	// index 1 is source
	if (lua_type(L, 2) == LUA_TFUNCTION) {
		// preprocess c function
		preprocessor = lua_tocfunction(L, 2);
		if (preprocessor == NULL) {
			return luaL_error(L, "Preprocessor must be a C function");
		}
		if (lua_getupvalue(L, 2, 1)) {
			return luaL_error(L, "Preprocessor must be a light C function (no upvalue)");
		}
	}
	lua_State *cL = luaL_newstate();
	if (cL == NULL)
		return luaL_error(L, "Can't new debug client");

	lua_pushlightuserdata(L, cL);
	lua_rawsetp(L, LUA_REGISTRYINDEX, &DEBUG_CLIENT);

	lua_pushcfunction(cL, client_main);
	lua_pushlightuserdata(cL, (void *)mainscript);
	lua_pushlightuserdata(cL, (void *)L);
	if (preprocessor) {
		lua_pushcfunction(cL, preprocessor);
	} else {
		lua_pushnil(cL);
	}

	if (lua_pcall(cL, 3, 0, 0) != LUA_OK) {
		push_errmsg(L, cL);
		clear_client(L);
		return lua_error(L);
	}
	// register hook thread into host
	if (lua_checkstack(cL, 1) == 0) {
		clear_client(L);
		return luaL_error(L, "debugger L stack overflow");
	}
	lua_pushlightuserdata(L, cL);
	lua_rawsetp(L, LUA_REGISTRYINDEX, &DEBUG_HOOK);
	return 0;
}

// use as hard break point
static int
lhost_probe(lua_State *L) {
	if (lua_rawgetp(L, LUA_REGISTRYINDEX, &DEBUG_HOOK) != LUA_TLIGHTUSERDATA) {
		// debugger not start
		return 0;
	}
	lua_State *cL = lua_touserdata(L, -1);
	probe(cL, L, luaL_checkstring(L, 1));
	return 0;
}

lua_State *
get_host(lua_State *L) {
	if (lua_rawgetp(L, LUA_REGISTRYINDEX, &DEBUG_HOST) != LUA_TLIGHTUSERDATA) {
		luaL_error(L, "Must call in debug client");
	}
	lua_State *hL = lua_touserdata(L, -1);
	lua_pop(L, 1);
	return hL;
}

void
set_host(lua_State* L, lua_State* hL) {
    lua_pushlightuserdata(L, hL);
    lua_rawsetp(L, LUA_REGISTRYINDEX, &DEBUG_HOST);
}

lua_State *
getthread(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	lua_State *hL = get_host(L);
	lua_pushvalue(L, 1);
	int ct = eval_value(L, hL);
	lua_pop(L, 1);
	if (ct == LUA_TNONE) {
		luaL_error(L, "Invalid thread");
		return NULL;
	}
	if (ct != LUA_TTHREAD) {
		lua_pop(hL, 1);
		luaL_error(L, "Need coroutine, Is %s", lua_typename(hL, ct));
		return NULL;
	}
	lua_State *co = lua_tothread(hL, -1);
	lua_pop(hL, 1);
	return co;
}

LUAMOD_API int
luaopen_remotedebug(lua_State *L) {
	luaL_checkversion(L);
	if (lua_rawgetp(L, LUA_REGISTRYINDEX, &DEBUG_HOST) != LUA_TNIL) {
		// It's client
		lua_newtable(L);
		lua_pushstring(L, "debugger");
		lua_setfield(L, -2, "status");
	} else {
		// It's host
		luaL_Reg l[] = {
			{ "start", lhost_start },
			{ "clear", lhost_clear },
			{ "probe", lhost_probe },
			{ NULL, NULL },
		};
		luaL_newlib(L,l);
		lua_pushstring(L, "host");
		lua_setfield(L, -2, "status");

		// autoclose debugger VM, __gc in module table
		lua_createtable(L,0,1);
		lua_pushcfunction(L, lhost_clear);
		lua_setfield(L, -2, "__gc");
		lua_setmetatable(L, -2);
	}
	return 1;
}
