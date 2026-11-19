// Cas de regression pour Core.lua (revue)
const fs = require("fs");
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require("fengari");
const dir = process.argv[2] || __dirname + "/../MacroForge";
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
const run = (code, name) => { if (lauxlib.luaL_loadbuffer(L, code, code.length, to_luastring(name)) || lua.lua_pcall(L, 0, 0, 0)) throw new Error(to_jsstring(lua.lua_tostring(L, -1))); };
run(to_luastring("NS = {}"), "init");
const src = fs.readFileSync(dir + "/Core.lua", "utf8");
run(to_luastring("local chunk = function(...) " + src + "\nend chunk('MacroForge', NS)"), "@Core.lua");
run(to_luastring(String.raw`
local ns = NS
local function rt(s) return ns.Compile(ns.Parse(s)) end
-- commande collee au crochet
assert(rt("/cast[@focus] Fear") == "/cast [@focus] Fear", rt("/cast[@focus] Fear"))
assert(ns.Parse("/cast[@focus] Fear")[1].type == "cast")
-- reset= different par alternative : ligne gardee telle quelle
local s = "/castsequence [mod:shift] reset=5 A, B; reset=10 C, D"
assert(ns.Parse(s)[1].type == "raw" and rt(s) == s)
-- reset identique : bloc normal
local b = ns.Parse("/castsequence reset=target A, B")[1]
assert(b.type == "castsequence" and b.reset == "target")
assert(rt("/castsequence reset=target A, B") == "/castsequence reset=target A, B")
-- pas de reset orphelin
local c = ns.NewBlock("castsequence"); c.reset = "5"
assert(ns.CompileBlock(c) == "/castsequence")
-- groupe exclusif : cibles inconnues retirees aussi
local cl = ns.NewClause(); cl.conds = { "@party1", "harm", "target=focus" }
ns.ToggleCond(cl, "@mouseover")
assert(table.concat(cl.conds, ",") == "@mouseover,harm", table.concat(cl.conds, ","))
-- Localize : bornes de mots, appels getName evites, % dans Rank
NS.SpellIDs = { Heal = 1, Fear = 2 }
local calls = 0
local get = function(id) calls = calls + 1 return ({ "Soin", "Peur" })[id] end
assert(ns.Localize("/use Healing Potion", get) == "/use Healing Potion")
assert(ns.Localize("/cast Heal(Rank 2)", get, "R%1") == "/cast Soin(R%1 2)")
calls = 0
ns.Localize("/cast Fear", get)
assert(calls == 1, calls)
-- Diagnose : pas de faux positif sur casts conditionnels
local function blk(arg, cond) local x = ns.NewBlock("cast"); x.clauses[1].arg = arg; if cond then x.clauses[1].conds = { cond } end return x end
local _, w = ns.Diagnose({ blk("A", "mod:shift"), blk("B", "nomod") })
assert(#w == 0)
_, w = ns.Diagnose({ blk("A"), blk("B") })
assert(#w == 1)
print("test_core OK")
`), "test");
