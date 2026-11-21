// Verifie la syntaxe des 3 fichiers Lua et l'aller-retour Parse -> Compile sur toute la bibliotheque
const fs = require("fs");
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require("fengari");
const dir = process.argv[2] || __dirname + "/../BlockForge";
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
require(__dirname + "/lua51")(L);

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
-- nouvelles conditions : aller-retour, paires exclusives, contradiction signalee
local conds = "/cast [spec:1,group:raid,pvpcombat,swimming,indoors,resting][spec:2,group,outdoors] Fear"
assert(ns.Compile(ns.Parse(conds)) == conds)
for _, c in ipairs({ "spec:1", "spec:2", "group", "group:raid", "pvpcombat", "swimming", "indoors", "outdoors", "resting" }) do
  assert(ns.KnownConditions[c], "condition sans bouton : " .. c)
end
local ex = ns.NewClause()
ns.ToggleCond(ex, "spec:1") ns.ToggleCond(ex, "indoors") ns.ToggleCond(ex, "spec:2") ns.ToggleCond(ex, "outdoors")
assert(table.concat(ex.conds, ",") == "spec:2,outdoors", table.concat(ex.conds, ","))
local _, w9 = ns.Diagnose(ns.Parse("/cast [indoors,outdoors] Fear"))
assert(#w9 == 1 and w9[1]:find("contradictoires"))
-- ordres de familier ajoutes : blocs reconnus et avertissement monture
for _, cmd in ipairs({ "petstay", "petdefensive", "petaggressive" }) do
  local blocks = ns.Parse("/dismount\\n/" .. cmd .. " [mod:ctrl]")
  assert(blocks[2].type == cmd and ns.Compile(blocks) == "/dismount\\n/" .. cmd .. " [mod:ctrl]")
  local _, wp = ns.Diagnose(blocks)
  assert(#wp == 1 and wp[1]:find("Familier"), cmd)
end
-- modeles : aller-retour exact, emplacements vides, syntaxe valide une fois remplis
assert(#ns.Templates == 5)
for _, t in ipairs(ns.Templates) do
  local blocks = ns.Parse(t.body)
  assert(ns.Compile(blocks) == t.body, t.label)
  for _, blk in ipairs(blocks) do
    assert(blk.type ~= "raw", t.label .. " : ligne non reconnue")
    if blk.type == "cast" then
      assert(blk.clauses[1].arg == "", t.label .. " : emplacement non vide")
      blk.clauses[1].arg = "Fear"
    end
  end
  local filled = ns.Compile(blocks)
  assert(filled == t.body:gsub("(/cast[^\\n]*)", "%1 Fear"), filled)
  assert(ns.Compile(ns.Parse(filled)) == filled, filled)
  local _, wt = ns.Diagnose(ns.Parse(filled))
  assert(#wt == 0, t.label .. " : " .. tostring(wt[1]))
end
print(#ns.Library .. " macros, " .. bad .. " aller-retour differents")
assert(bad == 0)
`);
