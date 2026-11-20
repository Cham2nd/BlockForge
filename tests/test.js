// Verifie la syntaxe des 3 fichiers Lua et l'aller-retour Parse -> Compile sur toute la bibliotheque
const fs = require("fs");
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require("fengari");
const dir = process.argv[2] || __dirname + "/../BlockForge";
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

function load(file) {
  const src = fs.readFileSync(dir + "/" + file);
  if (lauxlib.luaL_loadbuffer(L, src, src.length, to_luastring("@" + file)) !== lua.LUA_OK)
    throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
}
function run(code) {
  if (lauxlib.luaL_dostring(L, to_luastring(code)) !== lua.LUA_OK)
    throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
}

load("UI.lua"); lua.lua_pop(L, 1); // syntaxe seulement : l'interface a besoin du jeu
run("NS = {}");
for (const f of ["Locale.lua", "Core.lua", "Library.lua"]) {
  load(f);
  lua.lua_pushstring(L, to_luastring("BlockForge"));
  lua.lua_getglobal(L, to_luastring("NS"));
  if (lua.lua_pcall(L, 2, 0, 0) !== lua.LUA_OK) throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
}
run(`
local ns, bad = NS, 0
for _, m in ipairs(ns.Library) do
  local out = ns.Compile(ns.Parse(m.body))
  if out ~= m.body then bad = bad + 1 print("DIFF " .. m.class .. " / " .. m.name .. "\\n  " .. m.body:gsub("\\n", "\\n  ") .. "\\n=>\\n  " .. out:gsub("\\n", "\\n  ")) end
end
-- construction par blocs
local b = ns.NewBlock("cast")
b.clauses[1].arg = "Fear"
ns.ToggleCond(b.clauses[1], "harm")
ns.ToggleCond(b.clauses[1], "@focus")
ns.ToggleCond(b.clauses[1], "@mouseover") -- remplace @focus (groupe exclusif)
b.clauses[2] = ns.NewClause()
b.clauses[2].arg = "Fear"
assert(ns.CompileBlock(b) == "/cast [@mouseover,harm] Fear; Fear", ns.CompileBlock(b))
local seq = ns.NewBlock("castsequence")
seq.reset, seq.clauses[1].arg = "target", "Immolate, Corruption"
assert(ns.CompileBlock(seq) == "/castsequence reset=target Immolate, Corruption")
local _, warns = ns.Diagnose({ ns.NewBlock("cast") })
assert(#warns == 1)
local _, w2 = ns.Diagnose({ ns.NewBlock("dismount"), ns.NewBlock("petattack") })
assert(#w2 == 1 and w2[1]:find("Familier"))
local sl = ns.NewBlock("cast")
sl.clauses[1].arg = "Spell Lock(Rank 2)"
ns.ToggleCond(sl.clauses[1], "@focus")
local _, w3 = ns.Diagnose({ ns.NewBlock("dismount"), sl })
assert(#w3 == 1 and w3[1]:find("Familier"))
sl.clauses[1].arg = "Fear"
local _, w4 = ns.Diagnose({ ns.NewBlock("dismount"), sl })
assert(#w4 == 0)
-- sorts d'une macro, conditions contradictoires, #showtooltip mal place
local names = ns.SpellsOf(ns.Parse("#showtooltip\\n/cast [mod] !Stealth; Fear(Rank 2)\\n/castsequence reset=3 Immolate, Fear\\n/use 13"))
assert(table.concat(names, "|") == "Stealth|Fear|Immolate", table.concat(names, "|"))
local _, w5 = ns.Diagnose(ns.Parse("/cast [combat,nocombat] Fear"))
assert(#w5 == 1 and w5[1]:find("contradictoires"))
local _, w6 = ns.Diagnose(ns.Parse("/cast [harm,help] Fear"))
assert(#w6 == 1)
local _, w7 = ns.Diagnose(ns.Parse("/cast [harm,nodead] Fear\\n#showtooltip"))
assert(#w7 == 1 and w7[1]:find("showtooltip"))
local _, w8 = ns.Diagnose(ns.Parse("#showtooltip Fear\\n/cast [@mouseover,harm,nodead][] Fear"))
assert(#w8 == 0)
print(#ns.Library .. " macros, " .. bad .. " aller-retour differents")
assert(bad == 0)
`);
