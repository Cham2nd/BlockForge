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

// Cycle 4, lot 1 : recettes de l'Assistant, pour chaque recette x type de sort x options
run(to_luastring(String.raw`
local ns = NS
local long = string.rep("x", 30) -- nom de sort de 30 caracteres
local ids, perKind, built = {}, {}, 0
local function applicable(kind, hasPet)
  local list = {}
  for _, r in ipairs(ns.Recipes) do
    if r.applies(kind, hasPet) then list[#list + 1] = r.id end
  end
  return table.concat(list, " ")
end
for _, r in ipairs(ns.Recipes) do
  assert(type(r.id) == "string" and not ids[r.id] and #r.title > 3 and #r.desc > 20, "recette mal decrite : " .. tostring(r.id))
  ids[r.id] = true
  for _, kind in ipairs({ "harm", "help", "either", "pet", "item" }) do
    for _, hasPet in ipairs({ true, false }) do
      if r.applies(kind, hasPet) then
        perKind[kind] = (perKind[kind] or 0) + 1
        for bits = 0, 7 do
          local o = { kind = kind, showtooltip = bits % 2 == 1, nodead = math.floor(bits / 2) % 2 == 1, stopattack = bits >= 4 }
          local text = r.build(long, o)
          local where = r.id .. " / " .. kind .. " / " .. bits .. " :\n" .. text
          assert(ns.Compile(ns.Parse(text)) == text, "aller-retour : " .. where)
          assert(#text <= ns.MAX_CHARS, "trop long : " .. where)
          local _, warnings = ns.Diagnose(ns.Parse(text))
          assert(#warnings == 0, "avertissement « " .. tostring(warnings[1]) .. " » : " .. where)
          assert(r.name or text:find(long, 1, true), "sans le sort : " .. where) -- r.name : recette sans sort (bouton de survie)
          assert((text:sub(1, 12) == "#showtooltip") == o.showtooltip and (text:find("nodead", 1, true) == nil or o.nodead), where)
          assert((text:find("/stopattack", 1, true) ~= nil) == (o.stopattack and kind ~= "help" and kind ~= "item"), where)
          built = built + 1
        end
      end
    end
  end
end
assert(#ns.Recipes >= 10 and built > 300, built)
for _, kind in ipairs({ "harm", "help", "either", "pet", "item" }) do assert((perKind[kind] or 0) >= 2, "type sans recette : " .. kind) end
-- recettes proposees selon le type du sort ; « Avec le familier » seulement avec un familier
assert(applicable("harm", false) == "mouseover_harm focus_mod interrupt_focus nearest trinkets stopcasting sequence living_trinkets", applicable("harm", false))
assert(applicable("harm", true) == "mouseover_harm focus_mod interrupt_focus nearest with_pet trinkets stopcasting sequence living_trinkets", applicable("harm", true))
assert(applicable("help", true) == "mouseover_help focus_mod self_alt stopcasting sequence", applicable("help", true))
assert(applicable("item", true) == "stopcasting item_fallback survival", applicable("item", true))
local all = applicable("either", true) -- type inconnu : toutes les recettes de sort
for id in pairs(ids) do assert(id == "item_fallback" or id == "survival" or all:find(id, 1, true), "recette absente pour un sort de type inconnu : " .. id) end
-- textes exacts
local function build(id, kind, o)
  for _, r in ipairs(ns.Recipes) do
    if r.id == id then
      o = o or { showtooltip = true, nodead = true }
      o.kind = kind
      return r.build("Peur", o), r
    end
  end
end
assert(build("mouseover_harm", "harm") == "#showtooltip\n/cast [@mouseover,harm,nodead][] Peur")
assert(build("mouseover_harm", "harm", {}) == "/cast [@mouseover,harm][] Peur")
assert(build("mouseover_help", "help") == "#showtooltip\n/cast [@mouseover,help,nodead][help,nodead][@player] Peur")
assert(build("focus_mod", "harm") == "#showtooltip\n/cast [mod:shift,@focus][@mouseover,harm,nodead][] Peur")
assert(build("focus_mod", "either", {}) == "/cast [mod:shift,@focus][@mouseover,exists][] Peur")
assert(build("interrupt_focus", "harm") == "#showtooltip\n/stopcasting\n/cast [@focus,harm,nodead][] Peur")
assert(build("nearest", "harm") == "#showtooltip\n/targetenemy [noexists][dead]\n/cast Peur")
assert(build("nearest", "harm", { stopattack = true }) == "/stopattack\n/targetenemy [noexists]\n/cast Peur")
assert(build("self_alt", "help", { stopattack = true }) == "/cast [mod:alt,@player][@mouseover,help][] Peur")
assert(build("with_pet", "harm") == "#showtooltip\n/petattack\n/cast Peur")
assert(build("trinkets", "harm") == "#showtooltip Peur\n/use 13\n/use 14\n/cast Peur") -- sans le nom, l'icone serait celle du bijou
assert(build("stopcasting", "item") == "#showtooltip\n/stopcasting\n/use Peur")
local seq, seqRecipe = build("sequence", "harm")
assert(seq == "#showtooltip\n/castsequence reset=target Peur, Deuxième sort" and seqRecipe.editorOnly == true)
local item, itemRecipe = build("item_fallback", "item")
assert(item == "#showtooltip\n/use Peur\n/cast Sort de secours" and itemRecipe.editorOnly == true)
-- le simulateur lit bien ce que la recette promet
local sim = ns.Simulate(ns.Parse(build("focus_mod", "harm", {})), { mod = "shift", target = "harm", mouseover = "harm", focus = "harm" })
assert(sim[1].unit == "focus")
sim = ns.Simulate(ns.Parse(build("mouseover_harm", "harm")), { mod = false, target = "harm", mouseover = "none", focus = "none" })
assert(sim[2].unit == "target")
-- MacroName : 16 octets au plus, jamais au milieu d'un caractere accentue
assert(ns.MacroName("Peur") == "Peur" and ns.MacroName("  Trait de l'ombre  ") == "Trait de l'ombre")
assert(ns.MacroName("Éclair de givre pénétrant") == "Éclair de givre", ns.MacroName("Éclair de givre pénétrant"))
assert(ns.MacroName("Brûlure de l'âme") == "Brûlure de l'â", ns.MacroName("Brûlure de l'âme"))
assert(ns.MacroName("abcdefghijklmnoé") == "abcdefghijklmno" and ns.MacroName("") == "")
print("test_core recettes OK (" .. #ns.Recipes .. " recettes, " .. built .. " macros)")
`), "recettes");

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

// V1 lot A : barres d'action, bilan de sante, jauge, suggestions (logique pure de Core.lua)
run(to_luastring(String.raw`
local ns = NS
-- texte compare aux espaces pres
assert(ns.NormBody("  /cast   A \r\n\n/use 13  ") == "/cast A\n/use 13" and ns.NormBody(nil) == "")
-- nom de macro avec place pour un suffixe, sans couper un caractere
assert(ns.MacroName("Soins rapides superieurs") == "Soins rapides su" and ns.MacroName("Soins rapides superieurs", 14) == "Soins rapides")
assert(ns.MacroName("Abcdefghijklé", 13) == "Abcdefghijkl")
-- raccourci du bouton d'un emplacement
assert(ns.SlotBinding(1) == "ACTIONBUTTON1" and ns.SlotBinding(12) == "ACTIONBUTTON12" and ns.SlotBinding(13) == nil)
assert(ns.SlotBinding(25) == "MULTIACTIONBAR3BUTTON1" and ns.SlotBinding(48) == "MULTIACTIONBAR4BUTTON12" and ns.SlotBinding(49) == "MULTIACTIONBAR2BUTTON1")
assert(ns.SlotBinding(72) == "MULTIACTIONBAR1BUTTON12" and ns.SlotBinding(100) == nil and ns.SlotBinding(145) == "MULTIACTIONBAR5BUTTON1" and ns.SlotBinding(180) == "MULTIACTIONBAR7BUTTON12")

-- quelle macro dans un emplacement : les deux conventions de GetActionInfo
local macros = { { index = 1, name = "Alpha", body = "/cast Peur" }, { index = 2, name = "Beta", body = "/cast Corruption" },
                 { index = 121, name = "Perso", body = "/use 13" } }
local env = { spellName = function(id) return id == 172 and "Corruption" or nil end }
local function resolve(id, sub, text)
  local m, how = ns.ResolveMacro(id, sub, text, macros, env)
  return (m and m.name or "nil") .. "/" .. how
end
assert(resolve(2, nil, "Beta") == "Beta/index", resolve(2, nil, "Beta"))        -- l'identifiant est l'index, le nom le confirme
assert(resolve(121, "", nil) == "Perso/index")                                   -- index seul, sans nom affiche
assert(resolve(172, "spell", "Beta") == "Beta/name")                             -- l'identifiant est le sort : le nom tranche
assert(resolve(1, "spell", "Beta") == "Beta/name")                               -- un identifiant de sort qui ressemble a un index
assert(resolve(172, "spell", nil) == "Beta/body")                                -- ni index ni nom : la seule macro qui lance ce sort
assert(resolve(1, "spell", nil) == "nil/none" and resolve(999, "spell", "Inconnue") == "nil/none")
macros[4] = { index = 3, name = "Gamma", body = "/cast [mod] Corruption" }
assert(resolve(172, "spell", nil) == "nil/none", "deux macros lancent ce sort : pas de devinette")
macros[4] = nil
-- deux macros de meme nom : celle dont l'index correspond
macros[4] = { index = 122, name = "Beta", body = "/use 14" }
assert(ns.ResolveMacro(122, nil, "Beta", macros, env).index == 122 and ns.ResolveMacro(2, nil, "Beta", macros, env).index == 2)
macros[4] = nil

-- releve des barres avec de faux emplacements
local actions = { [1] = { "spell", 172 }, [2] = { "item", 5512 }, [3] = { "macro", 2 }, [4] = { "companion", 7 },
                  [6] = { "macro", 172, "spell" }, [7] = { "spell", 999 }, [8] = { "macro", 140 } }
local list, stats = ns.ScanBars({
  slots = { 1, 2, 3, 4, 5, 6, 7, 8 }, macros = macros, spellName = env.spellName,
  action = function(slot) local a = actions[slot] if a then return a[1], a[2], a[3] end end,
  name = function(kind, id)
    if kind == "spell" then return env.spellName(id), id == 172 and 136118 or nil end
    return "Pierre de soins", 135230
  end,
  text = function(slot) return slot == 3 and "Beta" or nil end,
  texture = function() return 134400 end,
  key = function(slot, macroName) return slot == 1 and "1" or macroName and "F5" or nil end,
})
assert(#list == 8 and list[1].kind == "spell" and list[1].name == "Corruption" and list[1].id == 172 and list[1].icon == 136118 and list[1].key == "1")
assert(list[2].kind == "item" and list[2].name == "Pierre de soins" and list[2].icon == 135230)
assert(list[3].kind == "macro" and list[3].macroName == "Beta" and list[3].macroIndex == 2 and list[3].how == "index" and list[3].key == "F5")
assert(list[4].kind == "other" and list[4].raw == "companion" and list[4].icon == 134400)
assert(list[5].kind == "empty" and list[5].icon == nil and list[5].slot == 5)
assert(list[6].kind == "macro" and list[6].macroName == "Beta" and list[6].how == "body")
assert(list[7].kind == "other", "un sort sans nom n'est pas convertible")
assert(list[8].kind == "macro" and list[8].macroName == nil and list[8].how == "none")
assert(stats.content == 7 and stats.spells == 1 and stats.items == 1 and stats.macros == 3 and stats.other == 2 and stats.unresolved == 1)

-- conversion en masse : memes sorts regroupes, macro existante reprise ou respectee, rang garde
local scan = { { slot = 1, kind = "spell", name = "Soin", id = 1 }, { slot = 2, kind = "spell", name = "Soin", id = 1 },
  { slot = 3, kind = "spell", name = "Peur" }, { slot = 4, kind = "spell", name = "Rapide" }, { slot = 5, kind = "spell", name = "Pris" },
  { slot = 6, kind = "item", name = "Soin" }, { slot = 7, kind = "spell", name = "Soin", id = 2 }, { slot = 8, kind = "macro", name = "Soin" },
  { slot = 9, kind = "spell", name = "Long" } }
local have = { { name = "Rapide", body = "#showtooltip\n/cast   [@mouseover,help][] Rapide " }, { name = "Pris", body = "/cast Autre" } }
local plan = ns.BulkPlan(scan, "help", have, {
  kind = function(name) return name == "Peur" and "harm" or "help" end,
  build = function(name) return name == "Long" and string.rep("x", 256) or ("#showtooltip\n/cast [@mouseover,help][] " .. name) end,
  cast = function(e) if e.id == 2 then return e.name .. "(Rang 1)", " 1" end return e.name, "" end,
})
local function line(item) return item.slot .. ":" .. item.macroName .. ":" .. (item.create and "create" or item.reuse and "reuse" or item.skip) end
local got = {}
for _, item in ipairs(plan.items) do got[#got + 1] = line(item) end
assert(table.concat(got, " ") == "1:Soin:create 2:Soin:reuse 4:Rapide:reuse 7:Soin 1:create", table.concat(got, " "))
assert(plan.need == 2 and #plan.skipped == 2 and line(plan.skipped[1]) == "5:Pris:name" and line(plan.skipped[2]) == "9:Long:long")
assert(plan.items[4].body == "#showtooltip\n/cast [@mouseover,help][] Soin(Rang 1)" and plan.items[4].spell == "Soin(Rang 1)")
assert(#ns.BulkPlan(scan, "harm", have, { kind = function(name) return name == "Peur" and "harm" or "help" end, build = function(n) return "/cast " .. n end }).items == 1)

-- reparation : mot entier seulement
assert(ns.FixSpell("#showtooltip Peurr\n/cast [mod] Peurr; SuperPeurr", "Peurr", "Peur") == "#showtooltip Peur\n/cast [mod] Peur; SuperPeurr")
assert(ns.FixSpell("/cast A", "", "B") == "/cast A" and ns.FixSpell("/cast A", "Z", "B") == "/cast A")

-- bilan de sante
local list = { { name = "A", body = "/cast Peurr" }, { name = "B", body = "/cast Peur" }, { name = "C", body = " /cast  Peur \n" },
               { name = "D", body = "/cast Zzzzzz" }, { name = "E", body = "/cast [combat,nocombat] Peur" }, { name = "F", body = "" },
               { name = "G", body = "/use Pierre de soins" } }
local henv = {
  unknown = function(body)
    local out = {}
    for _, name in ipairs(ns.SpellsOf(ns.Parse(body))) do if name ~= "Peur" then out[#out + 1] = name end end
    return out
  end,
  nearest = function(name) return ns.Nearest(name, { "Peur" }) end,
  used = function(m) return m.name ~= "B" and m.name ~= "F" end,
}
local r = ns.HealthCheck(list, henv)
assert(r.total == 7 and #r.broken == 2 and r.broken[1].macro.name == "A" and r.broken[1].fix[1] == "Peurr" and r.broken[1].fix[2] == "Peur" and r.broken[1].maybe == nil)
assert(r.broken[2].macro.name == "D" and r.broken[2].fix == nil and r.broken[2].maybe == "Zzzzzz", "nom que rien n'explique : peut-etre")
assert(#r.duplicates == 1 and r.duplicates[1].macro.name == "C" and r.duplicates[1].of.name == "B", "doublon aux espaces pres ; une macro vide n'est pas un doublon")
assert(#r.orphans == 2 and r.orphans[1].macro.name == "B" and r.orphans[2].macro.name == "F")
assert(#r.risky == 1 and r.risky[1].macro.name == "E" and r.risky[1].warning:find("contradictoires"))
-- un objet absent des sacs n'est pas « casse » : /use n'est pas controle
for _, item in ipairs(r.broken) do assert(item.macro.name ~= "G") end
henv.orphans = false
assert(#ns.HealthCheck(list, henv).orphans == 0, "barres illisibles : aucune orpheline annoncee")

-- jauge
local text, level = ns.Gauge(87, 120, 12, 30)
assert(text == "87 / 120 · 12 / 30" and level == "ok", text)
assert(select(2, ns.Gauge(101, 120, 0, 30)) == "ok" and select(2, ns.Gauge(102, 120, 0, 30)) == "warn" and select(2, ns.Gauge(10, 120, 26, 30)) == "warn")
assert(select(2, ns.Gauge(120, 120, 0, 30)) == "full" and select(2, ns.Gauge(0, 120, 30, 30)) == "full")

-- suggestions : ni le nom (meme coupe a 16 octets, sans accents ni casse), ni le texte deja possede ; cinq au plus
local cands = { { name = "Feu", body = "/cast Feu" }, { name = "Glace", body = "/cast Glace" }, { name = "Terre", body = "/cast  Terre" },
  { name = "Un nom vraiment long", body = "/cast Long" }, { name = "Glace bis", body = "/cast Glace " } }
for i = 1, 6 do cands[#cands + 1] = { name = "Autre" .. i, body = "/cast Autre" .. i } end
local owned = { { name = "FEU", body = "/x" }, { name = "Autre", body = "/cast Terre" }, { name = "un nom vraiment", body = "/y" } }
local s = ns.Suggestions(cands, owned, 5)
local names = {}
for i, c in ipairs(s) do names[i] = c.name end
assert(table.concat(names, ",") == "Glace,Autre1,Autre2,Autre3,Autre4", table.concat(names, ","))
assert(#ns.Suggestions(cands, {}) == 5 and #ns.Suggestions({}, owned) == 0)
print("test_core V1 lot A OK")
`), "v1a");

// ---------------------------------------------------------------- V1 lot B : jetons vivants, export « BF2: », plan d'activation d'un profil
run(to_luastring(String.raw`
local ns = NS
local function bag(...) local list = {} for i, id in ipairs({ ... }) do list[i] = { id = id, name = "objet" .. id } end return list end
local function tok(id, env, param) return ns.ResolveToken(id, param or "", env) end

-- 1. jetons d'un texte : sans doublon, parametre, libelle ; texte montre au joueur
local t = ns.TokensOf("/use {bf:potion_soin}\n/cast {bf:sort:Éclair de givre(Rang 3)}\n/use {bf:potion_soin}\n/use {bf:inconnu}")
assert(#t == 3 and t[1].raw == "{bf:potion_soin}" and t[1].id == "potion_soin" and t[1].param == "" and t[1].label == "Potion de soin")
assert(t[2].id == "sort" and t[2].param == "Éclair de givre(Rang 3)" and t[3].label == "inconnu")
assert(ns.HasTokens("/use {bf:eau}") and not ns.HasTokens("/use Eau") and not ns.HasTokens(nil))
assert(ns.TokenText("/use {bf:bijou13}\n/cast {bf:sort:Peur}") == "/use <Bijou du haut>\n/cast <Plus haut rang du sort Peur>")
assert(#ns.LivingTokens == 13)
for _, def in ipairs(ns.LivingTokens) do
  assert(def.id ~= "focus" and #def.label > 2 and #def.tip > 10, def.id) -- le focus change en combat : jamais un jeton
end
-- chaque liste : des ID entiers, sans doublon, un niveau entre 1 et 60
for id, list in pairs(ns.LivingItems) do
  local seen = {}
  assert(#list >= 6, id)
  for _, e in ipairs(list) do
    assert(type(e[1]) == "number" and e[1] == math.floor(e[1]) and not seen[e[1]] and e[2] >= 1 and e[2] <= 60, id .. " : " .. tostring(e[1]))
    seen[e[1]] = true
  end
end

-- 2. potions : la meilleure presente, dans la limite du niveau
local env = { level = 60, bags = bag(118, 929, 13446, 3928, 2455) }
assert(tok("potion_soin", env) == "objet13446" and select(2, tok("potion_soin", env)) == true)
env.level = 44
assert(tok("potion_soin", env) == "objet3928", "niveau 44 : la potion majeure (45) est exclue")
env.level = 11
assert(tok("potion_soin", env) == "objet118", "niveau 11 : la potion de soins (12) est exclue")
env.level = 4
assert(tok("potion_mana", env) == nil and select(2, tok("potion_mana", env)) == false, "niveau 4 : la potion de mana mineure (5) est exclue")
env.level = 5
assert(tok("potion_mana", env) == "objet2455")
-- rien dans les sacs : pas trouve ; avec itemName, le nom du plus petit objet de la liste
env = { level = 60, bags = bag(2589) }
local name, found = tok("potion_soin", env)
assert(name == nil and found == false)
env.itemName = function(id) return "nom" .. id end
name, found = tok("potion_soin", env)
assert(name == "nom118" and found == false)
-- un objet sans nom (pas en cache) est ignore
assert(tok("potion_soin", { level = 60, bags = { { id = 13446 }, { id = 929, name = "Potion" } } }) == "Potion")
-- 3. pierres de soins : n'importe quel rang, la plus haute d'abord, amelioree comprise ; bandages : le meilleur
assert(tok("pierre_soin", { level = 60, bags = bag(5512, 5509, 19006) }) == "objet5509")
assert(tok("pierre_soin", { level = 60, bags = bag(5510, 19012) }) == "objet19012")
assert(tok("pierre_soin", { level = 1, bags = bag(9421) }) == "objet9421", "aucun niveau retenu pour les pierres")
assert(tok("bandage", { level = 60, bags = bag(1251, 6451, 3530) }) == "objet6451")
-- 4. nourriture et eau : listes, plus les objets que le client classe lui-meme (kind), au niveau requis lu
env = { level = 60, bags = { { id = 4540, name = "Pain" }, { id = 70001, name = "Festin", kind = "food", level = 45 },
                             { id = 70002, name = "Trop haut", kind = "food", level = 61 }, { id = 70003, name = "Jus", kind = "drink", level = 10 },
                             { id = 159, name = "Eau de source" }, { id = 70004, name = "Cheval", kind = "mount", level = 0 } } }
assert(tok("nourriture", env) == "Festin" and tok("eau", env) == "Jus" and tok("monture", env) == "Cheval")
env.level = 9
assert(tok("nourriture", env) == "Pain" and tok("eau", env) == "Eau de source")
assert(tok("nourriture", { level = 60, bags = bag(5349, 4540, 117) }) == "objet5349", "meme niveau : l'ordre de la liste")
assert(tok("monture", { level = 60, bags = bag(118), itemName = function() return "x" end }) == nil, "pas de liste de montures : rien a proposer")
-- 5. equipement, familier, plus haut rang
env = { level = 60, bags = {}, slots = { [13] = "Bijou A", [16] = "Épée" }, pet = "Rex" }
assert(tok("bijou13", env) == "Bijou A" and tok("bijou14", env) == nil and tok("arme", env) == "Épée" and tok("main_gauche", env) == nil)
assert(tok("familier", env) == "Rex" and tok("familier", { bags = {} }) == nil)
assert(tok("sort", env, "Éclair de givre(Rang 3)") == "Éclair de givre" and tok("sort", env, "Peur") == "Peur" and tok("sort", env, "") == nil)
assert(tok("focus", env) == nil and tok("inconnu", env) == nil)

-- 6. texte entier : noms ecrits, jetons sans objet, dernier nom garde, nil si un jeton n'a aucun nom
env = { level = 60, bags = bag(929), slots = { [13] = "Bijou 100%" } }
local body, names, missing = ns.ResolveLiving("#showtooltip\n/use {bf:potion_soin}\n/use {bf:bijou13}\n/use {bf:potion_soin}", env)
assert(body == "#showtooltip\n/use objet929\n/use Bijou 100%\n/use objet929" and #missing == 0 and names["{bf:bijou13}"] == "Bijou 100%", body)
body, names, missing = ns.ResolveLiving("/use {bf:potion_soin}\n/use {bf:bijou14}", env, { ["{bf:bijou14}"] = "Ancien bijou" })
assert(body == "/use objet929\n/use Ancien bijou" and #missing == 1 and missing[1] == "{bf:bijou14}", body)
body, names, missing = ns.ResolveLiving("/use {bf:potion_soin}\n/use {bf:bijou14}", env)
assert(body == nil and missing[#missing] == "{bf:bijou14}")
env.bags = {}
body, names, missing = ns.ResolveLiving("/use {bf:potion_soin}", env, { ["{bf:potion_soin}"] = "Potion d'avant" })
assert(body == "/use Potion d'avant" and missing[1] == "{bf:potion_soin}", "sacs vides : le nom precedent est garde")
assert(ns.ResolveLiving("/cast Peur", env) == "/cast Peur")
-- la recette du bouton de survie : trois lignes /use, jamais de jeton lie au combat
for _, r in ipairs(ns.Recipes) do
  if r.id == "survival" then
    local text = r.build("", { kind = "item", showtooltip = true })
    assert(text == "#showtooltip\n/use [nomod] {bf:pierre_soin}\n/use [nomod] {bf:potion_soin}\n/use [mod] {bf:bandage}" and r.feature == "living" and r.name == "Survie", text)
    local out = ns.ResolveLiving(text, { level = 60, bags = bag(9421, 13446, 14530) })
    assert(out == "#showtooltip\n/use [nomod] objet9421\n/use [nomod] objet13446\n/use [mod] objet14530", out)
  end
end

-- 8. profil en texte : aller-retour, onglet de chaque macro, caracteres speciaux
local macros = { { name = "Soin: 1", body = "#showtooltip\n/cast [@mouseover,help] Soins|100%", char = false },
                 { name = "Éclair", body = "/cast Éclair de givre", char = true }, { name = "Vide", body = "", char = false } }
local text = ns.ExportProfile("Raid: mardi", macros)
assert(text:sub(1, 4) == "BF2:" and not text:find("[|\n]") and text:find(":3:a:", 1, true), text)
local p = ns.ImportProfile("  " .. text .. "\n")
assert(p and p.name == "Raid: mardi" and #p.macros == 3)
for i, m in ipairs(macros) do assert(p.macros[i].name == m.name and p.macros[i].body == m.body and p.macros[i].char == m.char, "macro " .. i) end
-- compression : seulement si le client la propose, si l'aller-retour est exact et si le texte est plus court
local store = {}
local good = { pack = function(s) store.K1 = s return "K1" end, unpack = function(z) return store[z] end }
local packed = ns.ExportProfile("Raid", macros, good)
assert(packed == "BF2z:K1", packed)
p = ns.ImportProfile(packed, good)
assert(p and #p.macros == 3 and p.macros[2].char == true)
local _, err = ns.ImportProfile(packed)
assert(err:find("compressé"), err)
_, err = ns.ImportProfile(packed, { unpack = function() error("boum") end })
assert(err:find("compressé"), err)
local plain = ns.ExportProfile("Raid", macros)
assert(ns.ExportProfile("Raid", macros, { pack = function() return "K1" end, unpack = function() return "autre" end }) == plain, "aller-retour faux : texte en clair")
assert(ns.ExportProfile("Raid", macros, { pack = function() error("boum") end, unpack = function() end }) == plain, "erreur du client : texte en clair")
assert(ns.ExportProfile("Raid", macros, { pack = function(s) return s .. "AAAA" end, unpack = function(z) return z:sub(1, -5) end }) == plain, "pas plus court : texte en clair")
assert(ns.ExportProfile("Raid", macros, { pack = function() return "K 1" end, unpack = function() return plain end }) == plain, "texte non imprimable : en clair")
-- textes abimes ou hostiles : toujours nil et une raison, jamais une erreur
local bad = { "", "BF1:a:b", "BF2:x", "BF2:x:0", "BF2:x:2:a:A:%2Fsit", "BF2:x:1:z:A:%2Fsit", "BF2:x:1:a::%2Fsit", "BF2:x:1:a:A:%ZZ",
  "BF2:x:1:a:A:a|b", "BF2:x:1.5:a:A:b", "BF2:x:151", "BF2:x:2:a:A:b:a:A:c", "BF2:x:1:a:" .. string.rep("n", 17) .. ":b",
  "BF2:x:1:a:A:" .. string.rep("b", 256), "BF2:x%7C:1:a:A:b:extra", string.rep("x", 200001), 5, nil }
for i = 1, 18 do
  local ok, res, why = pcall(ns.ImportProfile, bad[i])
  assert(ok and res == nil and type(why) == "string" and #why > 5, "texte abime accepte : " .. tostring(bad[i]):sub(1, 40))
end
p = ns.ImportProfile("BF2:%7CNom%0A:1:c:A:b")
assert(p and p.name == "Nom" and p.macros[1].char == true, "nom de profil nettoye")
local many = {}
for i = 1, 150 do many[i] = { name = "M" .. i, body = string.rep("x", 255), char = i > 120 } end
p = ns.ImportProfile(ns.ExportProfile("Tout", many))
assert(p and #p.macros == 150 and p.macros[150].char == true, "150 macros de 255 caracteres")

-- 9. plan d'activation
local current = { { name = "Kick", body = "/cast Autre", index = 1 }, { name = "Meme", body = " /sit ", index = 2 },
                  { name = "Extra", body = "/dance", index = 3 }, { name = "Perso", body = "/x", char = true, index = 121 } }
local profile = { macros = { { name = "Kick", body = "/cast Peur" }, { name = "Meme", body = "/sit" }, { name = "Neuve", body = "/a" },
                             { name = "Perso", body = "/b" }, { name = "Kick", body = "/doublon" }, { name = "PersoNeuve", body = "/c", char = true },
                             { name = "", body = "/vide" }, { name = "Longue", body = string.rep("x", 256) }, 7 },
                  bindings = { Kick = { "F", "G", 5 }, Neuve = { "H" }, Absente = { "J" } },
                  bars = { [5] = "Kick", [6] = "Neuve", [7] = "Kick", [8] = "Absente", [9] = "Meme", x = "Kick" } }
local slots = { [5] = { kind = "spell", name = "Corruption" }, [6] = { kind = "macro", macroName = "Neuve" }, [7] = { kind = "other" }, [9] = { kind = "empty" } }
local penv = { binding = function(k) return ({ F = "ACTIONBUTTON1", G = "MACRO Kick", H = "" })[k] end, slot = function(s) return slots[s] end,
               unknown = function(b) return b == "/a" and { "x" } or {} end }
local plan = ns.ProfilePlan(profile, current, { update = true, keys = true, bars = true }, penv)
assert(#plan.create == 3 and plan.create[1].name == "Neuve" and plan.create[2].name == "Perso" and plan.create[3].name == "PersoNeuve")
assert(plan.need[false] == 2 and plan.need[true] == 1 and #plan.update == 1 and plan.update[1].macro.body == "/cast Peur" and plan.update[1].old.index == 1)
assert(#plan.same == 1 and #plan.left == 0 and #plan.remove == 0 and plan.unknown == 1)
assert(#plan.binds == 2 and plan.binds[1].key == "F" and plan.binds[1].replaces == "ACTIONBUTTON1" and plan.binds[2].key == "H" and plan.binds[2].replaces == nil)
assert(#plan.slots == 2 and plan.slots[1].slot == 5 and plan.slots[1].before.name == "Corruption" and plan.slots[2].slot == 9 and plan.slots[2].macro == "Meme")
assert(#plan.blocked == 1 and plan.blocked[1] == 7)
-- sans « reecrire » : la macro de meme nom est laissee ; sans touches ni barres : rien de ce cote
plan = ns.ProfilePlan(profile, current, {}, penv)
assert(#plan.update == 0 and #plan.left == 1 and plan.left[1].name == "Kick" and #plan.binds == 0 and #plan.slots == 0 and #plan.remove == 0)
-- « retirer les absentes » : meme nom dans l'autre onglet = absente ; les places liberees sont comptees par onglet
plan = ns.ProfilePlan(profile, current, { remove = true }, penv)
assert(#plan.remove == 2 and plan.remove[1].name == "Extra" and plan.remove[2].name == "Perso" and plan.freed[false] == 1 and plan.freed[true] == 1)
plan = ns.ProfilePlan({}, current, { update = true, remove = true, keys = true, bars = true }, penv)
assert(#plan.create == 0 and #plan.remove == 4, "profil sans macros")
print("test_core V1 lot B OK")
`), "v1b");
