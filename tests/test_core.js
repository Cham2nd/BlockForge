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
run(to_luastring("local chunk = function(...) " + fs.readFileSync(dir + "/Library.lua", "utf8") + "\nend chunk('BlockForge', NS)"), "@Library.lua");
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

-- Nearest : faute de frappe, accent, casse ; jamais un autre vrai sort
local book = { "Malédiction de faiblesse", "Malédiction de fatigue", "Peur", "Corruption" }
assert(ns.Nearest("malediction de faibless", book) == "Malédiction de faiblesse")
assert(ns.Nearest("Coruption", book) == "Corruption")
assert(ns.Nearest("PEUR", book) == "Peur")
assert(ns.Nearest("Malédiction de témérité", book) == nil)
assert(ns.Nearest("Pet", book) == nil or ns.Nearest("Pet", book) == "Peur")
assert(ns.Nearest("Trait de l'ombre", book) == nil and ns.Nearest("x", {}) == nil)

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

-- Colorize : sans perte (codes de couleur retires, || relu comme |), une couleur par role
local P = { command = "111111", meta = "222222", cond = "333333", target = "444444", arg = "555555", commands = { ["/use"] = "666666" } }
local function strip(s)
  local out, i = {}, 1
  while i <= #s do
    if s:sub(i, i + 1) == "||" then out[#out + 1] = "|" i = i + 2
    elseif s:find("^|c%x%x%x%x%x%x%x%x", i) then i = i + 10
    elseif s:sub(i, i + 1) == "|r" then i = i + 2
    else
      assert(s:sub(i, i) ~= "|", "| non echappe : " .. s)
      out[#out + 1] = s:sub(i, i)
      i = i + 1
    end
  end
  return table.concat(out)
end
local function col(s)
  local c = ns.Colorize(s, P)
  assert(strip(c) == s, "Colorize avec perte : " .. s .. " => " .. c)
  return c
end
assert(#ns.Library >= 274, "bibliotheque non chargee")
for _, e in ipairs(ns.Library) do
  assert(col(e.body) ~= e.body, "rien de colore : " .. e.name)
end
for _, s in ipairs({ "", "\n", "  /cast  [ @focus , harm ] [] Fear ; Peur  \r\n\n#show\n texte libre | ici", "/cast [mod", "/cast ]x[",
                     "/run print(\"|cffff0000rouge|r ||\") t[1]=2", "/script x={[1]=2}", "#showtooltip", "/castsequence reset=5 A, B",
                     "/cast [target=focus,exists][@mouseover] X", "/", "#", "|", "/use||13" }) do col(s) end
local c = col("#showtooltip Fear\n/cast [@focus,harm] Fear; Peur\n/use 13\n/petattack [target=pet]")
assert(c:find("|cff222222#showtooltip|r|cff555555 Fear|r", 1, true), c)
assert(c:find("|cff111111/cast|r", 1, true) and c:find("|cff666666/use|r", 1, true), c) -- commands passe avant command
assert(c:find("|cff333333[|r|cff444444@focus|r,|cff333333harm|r|cff333333]|r", 1, true), c)
assert(c:find("|cff555555 Fear|r;|cff555555 Peur|r", 1, true) and c:find("|cff444444target=pet|r", 1, true), c)
assert(col("/run a[1]=2"):find("|cff555555 a[1]=2|r", 1, true), "crochets de /run pris pour des conditions")
assert(col("/say a | b") == "|cff111111/say|r|cff555555 a || b|r")
assert(col("bonjour | tous") == "bonjour || tous")
print("test_core OK")
`), "test");

// Cycle 3, lot 2 : historique annuler / retablir, texte libre, envoi en morceaux
run(to_luastring(String.raw`
local ns = NS
local function text(blocks) return ns.Compile(blocks) end

-- copie : independante de l'original, alternatives et blocs vides compris
local src = ns.Parse("/cast [@focus,harm] Fear; Peur\n/castsequence reset=3 A, B")
src[#src + 1] = ns.NewBlock("raw")
local copy = ns.CloneBlocks(src)
assert(ns.BlocksKey(copy) == ns.BlocksKey(src) and #copy == 3 and copy[1] ~= src[1] and copy[1].clauses[1].conds ~= src[1].clauses[1].conds)
copy[1].clauses[1].conds[1] = "@mouseover"
assert(src[1].clauses[1].conds[1] == "@focus", "la copie partage ses conditions")
-- l'empreinte voit ce que le texte compile ne voit pas : bloc libre vide, alternative vide
local a, b = { ns.NewBlock("cast") }, { ns.NewBlock("cast") }
b[1].clauses[2] = ns.NewClause()
assert(text(a) == text(b) and ns.BlocksKey(a) ~= ns.BlocksKey(b))
assert(ns.BlocksKey({}) ~= ns.BlocksKey({ ns.NewBlock("raw") }))

-- pile : rien a annuler au depart, un etat identique n'est pas empile, annuler / retablir
local h = ns.NewHistory(5)
local blocks = {}
assert(h:Record(blocks) and not h:Record(blocks) and not h:CanUndo() and not h:CanRedo() and h:Undo() == nil and h:Redo() == nil)
blocks = ns.Parse("/cast A")
assert(h:Record(blocks))
blocks[2] = ns.NewBlock("stopcasting")
assert(h:Record(blocks) and h:CanUndo() and not h:CanRedo())
local back = h:Undo()
assert(text(back) == "/cast A" and h:CanRedo())
back[1].clauses[1].arg = "modifie"
assert(text(h:Redo()) == "/cast A\n/stopcasting", "l'etat rendu doit etre une copie")
assert(text(h:Undo()) == "/cast A", "l'historique a ete modifie par l'appelant")
assert(text(h:Undo()) == "" and h:Undo() == nil and not h:CanUndo())
-- un changement apres une annulation efface ce qui etait a retablir
assert(h:Record(ns.Parse("/use 13")) and not h:CanRedo() and h:Redo() == nil)
assert(text(h:Undo()) == "")
-- frappe : meme tag = une seule etape ; un autre tag, ou aucun, en ouvre une nouvelle
h = ns.NewHistory(50)
h:Record({})
for _, s in ipairs({ "F", "Fe", "Fea", "Fear" }) do h:Record(ns.Parse("/cast " .. s), "arg") end
assert(#h.states == 2 and text(h:Undo()) == "", "frappe non regroupee")
assert(text(h:Redo()) == "/cast Fear")
h:Record(ns.Parse("/cast Fear\n/use 13"), "arg") -- apres annuler / retablir : nouvelle etape
h:Record(ns.Parse("/cast Fear\n/use 14"), "reset")
h:Record(ns.Parse("/cast Fear\n/use 15"))
h:Record(ns.Parse("/cast Fear\n/use 16"))
assert(#h.states == 6, #h.states)
-- pile bornee : les plus anciens etats sont oublies
h = ns.NewHistory(5)
for i = 1, 20 do h:Record(ns.Parse("/cast A" .. i)) end
assert(#h.states == 5 and h.at == 5)
local n = 0
while h:Undo() do n = n + 1 end
assert(n == 4 and text(ns.CloneBlocks(h.states[1].blocks)) == "/cast A16")

-- texte libre : aller-retour, ligne inconnue gardee telle quelle, lignes vides et espaces retires
local typed = "#showtooltip Fear\n\n  /cast [@mouseover,harm][] Fear  \n/commande inconnue [x] y; z\ndu texte sans barre\n/run print(\"a;b\")\n"
local parsed = ns.Parse(typed)
assert(#parsed == 5 and parsed[3].type == "raw" and parsed[4].type == "raw" and parsed[2].type == "cast")
local clean = "#showtooltip Fear\n/cast [@mouseover,harm][] Fear\n/commande inconnue [x] y; z\ndu texte sans barre\n/run print(\"a;b\")"
assert(text(parsed) == clean, text(parsed))
assert(text(ns.Parse(clean)) == clean, "le texte remis au propre doit etre stable")
assert(text(ns.Parse("/cast [@focus")) == "/cast [@focus", "ligne en cours de frappe perdue")

-- morceaux : moins de 255 octets chacun, recolles dans l'ordre ou le desordre, jamais coupes dans un caractere UTF-8
local payload = ns.Export(string.rep("é", 16), string.rep("é|:%\n", 42)) -- 252 octets dont 4 sur 6 sont echappes
assert(#payload > 600 and #payload <= 1000, #payload)
local chunks = ns.Chunks(payload, "42")
assert(#chunks >= 4 and #chunks <= 6, #chunks)
for i, c in ipairs(chunks) do
  assert(#c <= 255 and c:match("^42:" .. i .. ":" .. #chunks .. ":"), c)
end
local box = ns.NewInbox()
for i = 1, #chunks - 1 do assert(box:Receive("Ami", chunks[i], 0) == nil) end
assert(box:Receive("Ami", chunks[#chunks], 1) == payload and box.count == 0)
local n2, b2 = ns.Import(payload)
assert(n2 == string.rep("é", 16) and b2 == string.rep("é|:%\n", 42))
box = ns.NewInbox()
local got
for i = #chunks, 1, -1 do got = box:Receive("Ami", chunks[i], 0) or got end
assert(got == payload, "desordre")
local utf = ns.Chunks("BF1:x:" .. string.rep("é", 300), "7") -- 606 octets non echappes
for _, c in ipairs(utf) do
  local data = c:match("^7:%d+:%d+:(.*)$")
  assert(not data:find("^[\128-\191]") and #data % 2 == 0 or data:find("^BF1"), "coupe au milieu d'un caractere")
end
assert(ns.Chunks("", "1") == nil and ns.Chunks(string.rep("x", 1001), "1") == nil, "vide ou trop long")
-- doublon ignore, puis le transfert se termine normalement
box = ns.NewInbox()
local two = ns.Chunks(string.rep("a", 300), "9")
assert(#two == 2 and box:Receive("Ami", two[1], 0) == nil and box:Receive("Ami", two[1], 0) == nil)
assert(box:Receive("Ami", two[2], 0) == string.rep("a", 300))
-- deux expediteurs avec le meme numero : pas de melange
box = ns.NewInbox()
local other = ns.Chunks(string.rep("b", 300), "9")
box:Receive("Ami", two[1], 0) box:Receive("Autre", other[1], 0)
assert(box:Receive("Autre", other[2], 0) == string.rep("b", 300) and box:Receive("Ami", two[2], 0) == string.rep("a", 300))
-- malforme : ignore sans erreur, rien en attente
box = ns.NewInbox()
for _, bad in ipairs({ "", "bonjour", "9:1:2", "9:0:2:x", "9:3:2:x", "9:1:0:x", "9:1:7:x", "9:1:2:", "abcdefg:1:2:x",
                       "9:x:2:y", "9:1:99999999999999999999:x", ":1:2:x", "9:1:2:" .. string.rep("x", 250) }) do
  assert(box:Receive("Ami", bad, 0) == nil and box.count == 0, bad)
end
assert(box:Receive(nil, two[1], 0) == nil and box:Receive("Ami", 12, 0) == nil and box.count == 0)
-- trop gros : 6 morceaux de 200 octets depassent la limite, le transfert est abandonne
box = ns.NewInbox()
local big
for i = 1, 6 do big = box:Receive("Ami", ("5:%d:6:%s"):format(i, string.rep("x", 200)), 0) end
assert(big == nil and box.count == 0, "transfert trop gros accepte")
-- delai : un transfert incomplet est oublie, ses morceaux tardifs ne completent rien
box = ns.NewInbox()
box:Receive("Ami", two[1], 0)
assert(box.count == 1 and box:Receive("Ami", two[2], ns.SHARE_TIMEOUT + 1) == nil)
assert(box:Receive("Ami", two[1], ns.SHARE_TIMEOUT + 2) == string.rep("a", 300), "le transfert repart de zero apres le delai")
-- plafonds : 2 transferts en attente par expediteur, 8 en tout
box = ns.NewInbox()
for i = 1, 5 do box:Receive("Bavard", i .. ":1:2:x", 0) end
assert(box.count == 2, box.count)
for i = 1, 20 do box:Receive("Joueur" .. i, "1:1:2:x", 0) end
assert(box.count == 8, box.count)
-- total different pour le meme numero : l'ancien transfert est remplace
box = ns.NewInbox()
box:Receive("Ami", "3:1:3:aaa", 0)
assert(box:Receive("Ami", "3:1:2:bb", 0) == nil and box:Receive("Ami", "3:2:2:cc", 0) == "bbcc")
-- Plain : un | recu ne peut pas ouvrir un code de couleur
assert(ns.Plain("|cffff0000Admin|r") == "||cffff0000Admin||r" and ns.Plain(12) == "12")
print("test_core lot 2 OK")
`), "lot2");

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
