// Cas de regression pour Core.lua (revue)
const fs = require("fs");
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require("fengari");
const dir = process.argv[2] || __dirname + "/../BlockForge";
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
const run = (code, name) => { if (lauxlib.luaL_loadbuffer(L, code, code.length, to_luastring(name)) || lua.lua_pcall(L, 0, 0, 0)) throw new Error(to_jsstring(lua.lua_tostring(L, -1))); };
run(to_luastring("NS = {}"), "init");
const src = fs.readFileSync(dir + "/Core.lua", "utf8");
run(to_luastring("local chunk = function(...) " + src + "\nend chunk('BlockForge', NS)"), "@Core.lua");
run(to_luastring(String.raw`
local ns = NS
local function rt(s) return ns.Compile(ns.Parse(s)) end
-- commande collee au crochet
assert(rt("/cast[@focus] Fear") == "/cast [@focus] Fear", rt("/cast[@focus] Fear"))
assert(ns.Parse("/cast[@focus] Fear")[1].type == "cast")
-- Fold : recherche sans accents ni casse, octets UTF-8, autres caracteres intacts
assert(ns.Fold("Éclair GLACÉ : àâçôîïùûüéèêë ÀÂÇÔÎÏÙÛÜÈÊË") == "eclair glace : aacoiiuuueeee aacoiiuuueee", ns.Fold("Éclair GLACÉ"))
assert(ns.Fold("Œil ñ 100%") == "Œil ñ 100%")
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
NS.ItemIDs = { ["Major Soulstone"] = 16896, ["Kreeg's Stout Beatdown"] = 18284, ["Roasted Quail"] = 8952, Fear = 5 }
local calls = 0
local get = function(id) calls = calls + 1 return ({ "Soin", "Peur" })[id] end
assert(ns.Localize("/use Healing Potion", get) == "/use Healing Potion")
assert(ns.Localize("/cast Heal(Rank 2)", get, "R%1") == "/cast Soin(R%1 2)")
calls = 0
ns.Localize("/cast Fear", get)
assert(calls == 1, calls)
-- Localize : objets comme les sorts ; hors cache (nil) : nom anglais ; objet hors cache de meme nom qu'un sort : nom du sort
local items = { [16896] = "Pierre d'âme majeure", [18284] = "Raclée de Kreeg" }
local getItem = function(id) return items[id] end
local out = ns.Localize("/use [@player] Major Soulstone\n/use Kreeg's Stout Beatdown\n/use Roasted Quail\n/cast Fear", get, nil, getItem)
assert(out == "/use [@player] Pierre d'âme majeure\n/use Raclée de Kreeg\n/use Roasted Quail\n/cast Peur", out)
assert(ns.Localize("/use Major Soulstone", get) == "/use Major Soulstone") -- sans getItemName : rien pour les objets
-- Diagnose : pas de faux positif sur casts conditionnels
local function blk(arg, cond) local x = ns.NewBlock("cast"); x.clauses[1].arg = arg; if cond then x.clauses[1].conds = { cond } end return x end
local _, w = ns.Diagnose({ blk("A", "mod:shift"), blk("B", "nomod") })
assert(#w == 0)
_, w = ns.Diagnose({ blk("A"), blk("B") })
assert(#w == 1)

-- Export / Import : une seule ligne, sans |, aller-retour exact
local function roundtrip(name, body)
  local s = ns.Export(name, body)
  assert(s:sub(1, 4) == "BF1:" and not s:find("[|\n\r]"), s)
  local n2, b2 = ns.Import("  " .. s .. "\n") -- espaces et retour a la ligne du copier-coller
  assert(n2 == name and b2 == body, tostring(n2) .. " / " .. tostring(b2))
end
roundtrip("Peur", "#showtooltip\n/cast [@mouseover,harm,nodead][] Peur")
roundtrip("a:b|c%d", "/run print(\"||cff 100%\")\r\n/cast Fear;\t%41")
roundtrip("Éclair élevé", "/cast Éclair de givre\n/use 13")
roundtrip("Vide", "")
roundtrip(string.rep("é", 16), string.rep("x", 255)) -- 16 lettres (32 octets), 255 caracteres
local function rejects(s, fragment)
  local n, err = ns.Import(s)
  assert(n == nil and type(err) == "string" and err:find(fragment, 1, true), tostring(s) .. " -> " .. tostring(err))
end
rejects(nil, "BF1:")
rejects("", "BF1:")
rejects("/cast Fear", "BF1:")
rejects("BF1:nom", "BF1:")
rejects("BF1:a:b:c", "BF1:")
rejects("BF2:a:b", "2")
rejects("BF1:a:b%2", "abîmé")
rejects("BF1:a:b%zz", "abîmé")
rejects("BF1:a:b|cff", "abîmé")
rejects("BF1::body", "16")
rejects("BF1:%20%20:body", "16")
rejects(ns.Export(string.rep("x", 17), "b"), "16")
rejects(ns.Export("x", string.rep("y", 256)), "256 / 255")

-- Simulate : modeles remplis sous plusieurs etats
local function sim(text, state) return ns.Simulate(ns.Parse(text), state) end
local function fill(t) return (t.body:gsub("(/cast[^\n]*)", "%1 Fear")) end
local T = ns.Templates
local base = { mod = nil, target = "harm", targetDead = false, mouseover = "none", focus = "none" }
local function with(changes) local s = {} for k, v in pairs(base) do s[k] = v end for k, v in pairs(changes) do s[k] = v end return s end
-- 1 : familier + sort sur survol, sinon cible
local r = sim(fill(T[1]), base)
assert(r[1] == false and r[2].clause == 1 and r[2].unit == "target" and r[3].unit == "target" and not r[3].unknown)
r = sim(fill(T[1]), with({ mouseover = "harm" }))
assert(r[2].unit == "mouseover" and r[3].unit == "mouseover")
r = sim(fill(T[1]), with({ mouseover = "help" }))
assert(r[3].unit == "target")
-- 2 : modes sur touches
r = sim(T[2].body, base)
assert(r[1].clause == 1 and r[2].clause == nil and r[3].clause == nil and r[4].clause == nil)
r = sim(T[2].body, with({ mod = "shift" }))
assert(r[1].clause == nil and r[2].clause == 1 and r[3].clause == 1 and r[4].clause == nil)
r = sim(T[2].body, with({ mod = "ctrl" }))
assert(r[1].clause == nil and r[4].clause == 1)
-- 3 : interruption sur focus
r = sim(fill(T[3]), with({ focus = "harm" }))
assert(r[2].clause == 1 and r[3].unit == "focus")
r = sim(fill(T[3]), with({ focus = "help" }))
assert(r[3].unit == "target")
r = sim(fill(T[3]), with({ focus = "harm", focusDead = true }))
assert(r[3].unit == "target")
-- 4 : focus avec Maj, sinon survol, sinon cible
r = sim(fill(T[4]), with({ mod = "shift", focus = "harm", mouseover = "harm" }))
assert(r[2].unit == "focus")
r = sim(fill(T[4]), with({ focus = "harm", mouseover = "harm" }))
assert(r[2].unit == "mouseover")
r = sim(fill(T[4]), with({ mod = "alt", focus = "harm" }))
assert(r[2].unit == "target")
-- 5 : bijou puis sort
r = sim(fill(T[5]), base)
assert(r[2].clause == 1 and r[3].clause == 1)
-- alternatives separees par ; , negation, mod sans valeur, @unite
r = sim("/cast [nocombat] A; [combat] B", with({ combat = true }))
assert(r[1].clause == 2)
r = sim("/cast [mod] A; B", with({ mod = "alt" }))
assert(r[1].clause == 1)
r = sim("/cast [mod] A; B", base)
assert(r[1].clause == 2)
r = sim("/cast [nomod:shift/ctrl] A", with({ mod = "ctrl" }))
assert(r[1].clause == nil)
r = sim("/cast [@player,harm] A; [@player] B", base)
assert(r[1].clause == 2 and r[1].unit == "player")
r = sim("/cast [target=focus,exists] A; B", with({ focus = "help" }))
assert(r[1].clause == 1 and r[1].unit == "focus")
r = sim("/cast [@target,dead] A; [noexists] B; C", with({ target = "none" }))
assert(r[1].clause == 2)
-- inconnu : condition libre, champ d'etat absent, unite non simulee ; faux connu l'emporte
r = sim("/cast [flying] A; B", base)
assert(r[1].clause == 1 and r[1].unknown)
r = sim("/cast [combat] A; B", base) -- combat absent de l'etat
assert(r[1].unknown)
r = sim("/cast [@targettarget,harm] A; B", base)
assert(r[1].unknown and r[1].unit == "targettarget")
r = sim("/cast [@cursor] A", base)
assert(r[1].clause == 1 and not r[1].unknown)
r = sim("/cast [nomod,flying] A; B", with({ mod = "shift" }))
assert(r[1].clause == 2 and not r[1].unknown)
r = sim("/cast [stance:1/2] A; B", with({ form = 2 }))
assert(r[1].clause == 1)
r = sim("/stopcasting\n/cast [harm] A", with({ target = "help" }))
assert(r[1].clause == 1 and next(r[2]) == nil)
print("test_core OK")
`), "test");

// Langue : Locale.lua + Core.lua avec un client anglais, puis sans GetLocale (hors jeu : francais)
function loadLocalized(locale) {
  const S = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(S);
  const go = (code, name) => { if (lauxlib.luaL_loadbuffer(S, code, code.length, to_luastring(name)) || lua.lua_pcall(S, 0, 0, 0)) throw new Error(to_jsstring(lua.lua_tostring(S, -1))); };
  go(to_luastring("NS = {}" + (locale ? ` function GetLocale() return "${locale}" end` : "")), "init");
  for (const f of ["Locale.lua", "Core.lua"])
    go(to_luastring("local chunk = function(...) " + fs.readFileSync(dir + "/" + f, "utf8") + "\nend chunk('BlockForge', NS)"), "@" + f);
  return go;
}
const TEXTS = String.raw`
local ns = NS
local texts = {}
for _, def in ipairs(ns.BlockDefs) do texts[#texts + 1] = def.label texts[#texts + 1] = def.arg end
for _, g in ipairs(ns.ConditionGroups) do
  texts[#texts + 1] = g.label
  for _, item in ipairs(g.items) do texts[#texts + 1] = item[2] end
end
local function blk(t, arg) local x = ns.NewBlock(t) if arg then x.clauses[1].arg = arg end return x end
local _, w = ns.Diagnose({ blk("cast"), blk("cast", "A"), blk("cast", "B"), blk("dismount"), blk("petattack"), blk("raw") })
local long = blk("cast", string.rep("x", 300))
local _, w2 = ns.Diagnose({ long })
assert(#w == 3 and #w2 == 1, #w .. " " .. #w2)
for _, s in ipairs(w) do texts[#texts + 1] = s end
texts[#texts + 1] = w2[1]
`;
loadLocalized("enUS")(to_luastring(TEXTS + String.raw`
for _, s in ipairs(texts) do
  for _, c in ipairs({ "é", "è", "ê", "à", "ù", "ç", "ô", "î", "«", "»", " :", " ;" }) do
    assert(not s:find(c, 1, true), "texte francais en anglais : " .. s)
  end
end
assert(ns.BlockById.cast.label == "Cast a spell" and w2[1]:find("^Too long: %d+ / 255 characters%.$"), w2[1])
print("test_core anglais OK (" .. #texts .. " textes)")
`), "en");
loadLocalized(null)(to_luastring(TEXTS + String.raw`
assert(ns.BlockById.cast.label == "Lancer un sort" and ns.ConditionGroups[1].items[1][2] == "Survol")
assert(w[1] == "« Lancer un sort » n'a pas d'argument." and w2[1]:find("^Trop long : "), w[1])
print("test_core francais OK")
`), "fr");
