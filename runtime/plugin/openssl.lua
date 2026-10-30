-- Load the native Lua OpenSSL binding from the installed runtime Resources.
local path = assert(system.pathForFile("plugin/openssl.so", system.SystemResourceDirectory),
    "native OpenSSL module is missing")
local load, message = package.loadlib(path, "luaopen_openssl")
assert(load, message)
return load()
