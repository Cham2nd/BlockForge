// Traduit toute la bibliotheque avec la table francaise du client et verifie le resultat
const fs = require("fs");
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require("fengari");
const dir = process.argv[2] || __dirname + "/../BlockForge";
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
require(__dirname + "/lua51")(L);
const run = (code, name) => { if (lauxlib.luaL_loadbuffer(L, code, code.length, to_luastring(name)) || lua.lua_pcall(L, 0, 0, 0)) throw new Error(to_jsstring(lua.lua_tostring(L, -1))); };
let fr = "FR = {\n";
for (const line of fs.readFileSync(process.argv[3], "utf8").split(/\r?\n/).slice(1)) {
  const m = line.match(/^(\d+),(.*)$/); if (!m) continue;
  let n = m[2]; if (n.startsWith('"')) n = n.slice(1, -1).replace(/""/g, '"');
  fr += `[${m[1]}]=${JSON.stringify(n)},\n`;
}
run(to_luastring(fr + "}\nNS = {}"), "fr");
for (const f of ["Core.lua", "Library.lua", "SpellIDs.lua", "UI.lua"]) {
  let src = fs.readFileSync(dir + "/" + f, "utf8");
  if (f === "UI.lua") src = "if true then return end " + src; // syntaxe seulement
  run(to_luastring("local chunk = function(...) " + src + "\nend chunk('BlockForge', NS)"), "@" + f);
}
run(to_luastring(`
local ns, long, left = NS, 0, {}
local get = function(id) return FR[id] end
local show = { ["Fear Focus"] = 1, ["Sacrifice MO"] = 1, ["Earth Shock R1"] = 1, ["DoT Sequence"] = 1, ["Pet Ability"] = 1 }
for _, m in ipairs(ns.Library) do
  local out = ns.Localize(m.body, get, "Rang")
  assert(not out:find("[%c]", 1) or true and not out:find(string.char(1), 1, true), m.name)
  assert(ns.Compile(ns.Parse(out)) == out, "aller-retour " .. m.name)
  if #out > 255 then long = long + 1 print("TROP LONG " .. #out .. " " .. m.class .. " / " .. m.name) end
  if show[m.name] then print("--- " .. m.name) print(out) end
end
assert(ns.Localize("/cast Fear", function() return nil end) == "/cast Fear") -- sort inconnu : texte inchange
print(#ns.Library .. " macros traduites, " .. long .. " depassent 255 caracteres")
`), "test");
