const {lua,lauxlib,to_luastring,to_jsstring}=require('fengari');
module.exports = function harden(L) {
 const source = String.raw`
local original, unpack51 = string.format, table.unpack
unpack = unpack or unpack51
__testWrite = io and io.write
function string.format(fmt, ...)
  local args, index = {...}, 0
  for spec in fmt:gmatch("%%([-+ #0%d.]*[cdiouxXeEfgGqs%%])") do
    if spec ~= "%" then
      index = index + 1
      if spec:sub(-1) == "s" then
        local kind = type(args[index])
        if kind ~= "string" and kind ~= "number" then error("Lua 5.1: %s requires string or number, got " .. kind, 2) end
      end
    end
  end
  return original(fmt, ...)
end
table.pack, table.unpack, utf8, os, io = nil, nil, nil, nil, nil
assert(not pcall(string.format, "%s", nil))
assert(not pcall(string.format, "%s", false))
assert(not pcall(string.format, "%s", {}))
assert(string.format("%% %s %.2f %s", "ok", 1.5, 2) == "% ok 1.50 2")
`;
 if(lauxlib.luaL_dostring(L,to_luastring(source))!==lua.LUA_OK) throw Error(to_jsstring(lua.lua_tostring(L,-1)));
};
