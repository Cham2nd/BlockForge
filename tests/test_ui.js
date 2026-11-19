// Charge l'add-on (ordre du .toc) dans fengari avec de faux widgets WoW, simule ADDON_LOADED, ouvre /mf et clique partout :
// editeur, rendu des blocs, bibliotheque, parametres, bouton de minicarte. Trois etats de MacroForgeDB : vide, partiel, corrompu.
// But : attraper les erreurs Lua (nil, ordre de creation, fermetures) et verifier que chaque reglage agit, pas valider le rendu.
// Usage : node test_ui.js <dossier MacroForge>
const fs = require("fs");
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require("fengari");
const dir = process.argv[2] || __dirname + "/../MacroForge";
let L;

function check(status) {
  if (status !== lua.LUA_OK) throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
}
function run(code, name) {
  const buf = to_luastring(code);
  check(lauxlib.luaL_loadbuffer(L, buf, buf.length, to_luastring(name)));
  // traceback pour situer l'erreur dans le fichier de l'add-on
  lua.lua_getglobal(L, to_luastring("debug"));
  lua.lua_getfield(L, -1, to_luastring("traceback"));
  lua.lua_remove(L, -2);
  lua.lua_insert(L, -2);
  check(lua.lua_pcall(L, 0, 0, -2));
  lua.lua_pop(L, 1);
}
function loadAddonFile(file) {
  const src = fs.readFileSync(dir + "/" + file);
  check(lauxlib.luaL_loadbuffer(L, src, src.length, to_luastring("@" + file)));
  lua.lua_pushstring(L, to_luastring("MacroForge"));
  lua.lua_getglobal(L, to_luastring("NS"));
  check(lua.lua_pcall(L, 2, 0, 0));
}
// fichiers dans l'ordre du .toc
const tocFiles = fs.readFileSync(dir + "/MacroForge.toc", "utf8").split(/\r?\n/)
  .map(l => l.trim()).filter(l => l && !l.startsWith("#"));

// ---------------------------------------------------------------- faux WoW
const MOCK = String.raw`
NS = {}
ALL = {}            -- tous les widgets crees
CALLS = {}          -- appels aux API de macros
MOUSE_OVER = false  -- valeur de IsMouseOver
CURSOR = {}         -- retours de GetCursorInfo
CURSOR_POS = { 500, 290 }
COMBAT = false
MACROS = {}         -- name -> { index, body }
PRINTS = {}
POPUPS = {}
REGISTERED = {}
TOOLTIP_LINES = 0

local W = {}
local function noop() end
W.__index = function(t, k)
  local m = rawget(W, k)
  if m then return m end
  if type(k) == "string" and k:match("^%u") then return noop end -- toute methode inconnue est acceptee
  return nil -- champ absent (ex. .text) : nil comme en jeu
end
local function new(kind, parent, template)
  local w = setmetatable({ _type = kind, _parent = parent, _template = template, _scripts = {}, _children = {},
                           _events = {}, _w = 0, _h = 0 }, W)
  if parent then table.insert(parent._children, w) end
  ALL[#ALL + 1] = w
  if template == "BasicFrameTemplateWithInset" then
    w.TitleText = new("FontString", w)
    w.CloseButton = new("Button", w, "UIPanelCloseButton")
  elseif template == "UICheckButtonTemplate" then
    w.Text = new("FontString", w)
  end
  return w
end
function W:SetScript(name, fn) self._scripts[name] = fn end
function W:GetScript(name) return self._scripts[name] end
function W:HookScript(name, fn)
  local old = self._scripts[name]
  self._scripts[name] = old and function(...) old(...) fn(...) end or fn
end
function W:CreateTexture() return new("Texture", self) end
function W:CreateFontString(_, _, font)
  assert(font == nil or type(font) == "string", "police invalide")
  return new("FontString", self)
end
function W:SetText(t)
  assert(t == nil or type(t) == "string" or type(t) == "number", "SetText: type " .. type(t))
  self._text = t ~= nil and tostring(t) or ""
  if self._type == "EditBox" and self._scripts.OnTextChanged then self._scripts.OnTextChanged(self, false) end
end
function W:GetText() return self._text or "" end
function W:GetStringWidth() return #(self._text or "") * 6 end
function W:Show() self._shown = true end
function W:Hide() self._shown = false end
function W:SetShown(v) self._shown = not not v end
function W:IsShown() return self._shown ~= false end
function W:IsVisible()
  if self._shown == false then return false end
  return self._parent == nil or self._parent:IsVisible()
end
function W:SetChecked(v) self._checked = v end
function W:GetChecked() return self._checked end
function W:HasFocus() return FOCUS == self end
function W:SetFocus() FOCUS = self end
function W:ClearFocus() if FOCUS == self then FOCUS = nil end end
function W:IsMouseOver() return MOUSE_OVER end
function W:GetTop() return 300 end
function W:GetBottom() return 276 end
function W:GetEffectiveScale() return 1 end
function W:SetSize(w, h) self._w, self._h = w, h end
function W:SetWidth(w) assert(type(w) == "number", "SetWidth sans nombre") self._w = w end
function W:SetHeight(h) self._h = h end
function W:GetWidth() return self._w end
function W:GetCenter() return 1000, 600 end
function W:SetScale(s) assert(type(s) == "number" and s > 0, "SetScale invalide") self._scale = s end
function W:SetTexture(t) self._tex = t end
function W:SetColorTexture(...) self._tex = "color" end
function W:Enable() self._enabled = true end
function W:Disable() self._enabled = false end
function W:RegisterEvent(e) self._events[e] = true end
function W:UnregisterEvent(e) self._events[e] = nil end
function W:ClearAllPoints() self._point = nil end
function W:SetPoint(p, a, ...)
  assert(type(p) == "string", "SetPoint sans point")
  if type(a) == "table" then assert(getmetatable(a) == W, "SetPoint : relatif invalide") end
  self._point = { p, a, ... }
end
function W:GetPoint() if self._point then return unpack(self._point) end end
function W:GetName() return self._name end

function CreateFrame(kind, name, parent, template)
  assert(type(kind) == "string")
  assert(parent == nil or getmetatable(parent) == W, "CreateFrame : parent invalide")
  local w = new(kind, parent, template)
  w._name = name
  if name then _G[name] = w end
  return w
end
function CreateFont(name) local f = new("Font") _G[name] = f return f end
UIParent = new("Frame")
Minimap = new("Minimap", UIParent)
Minimap._w = 140
GameTooltip = new("GameTooltip", UIParent)
function GameTooltip:AddLine() TOOLTIP_LINES = TOOLTIP_LINES + 1 end
UISpecialFrames = {}
tinsert = table.insert
BackdropTemplateMixin = {}
Constants = { MacroConsts = { MAX_ACCOUNT_MACROS = 120, MAX_CHARACTER_MACROS = 30 } }
LOCALIZED_CLASS_NAMES_MALE = { WARLOCK = "Démoniste", HUNTER = "Chasseur", ROGUE = "Voleur", MAGE = "Mage",
  PRIEST = "Prêtre", DRUID = "Druide", WARRIOR = "Guerrier", PALADIN = "Paladin", SHAMAN = "Chaman" }
RANK = "Rang"
YES, NO = "Oui", "Non"
SlashCmdList = {}
StaticPopupDialogs = {}
function StaticPopup_Show(which, a1, a2, data)
  assert(StaticPopupDialogs[which], "dialogue inconnu " .. tostring(which))
  POPUPS[#POPUPS + 1] = { which = which, text = StaticPopupDialogs[which].text:format(a1), data = data }
end
Settings = {
  RegisterCanvasLayoutCategory = function(frame, name)
    assert(getmetatable(frame) == W and type(name) == "string")
    return { GetID = function() return 42 end }
  end,
  RegisterAddOnCategory = function(cat) REGISTERED[#REGISTERED + 1] = cat end,
}
C_Spell = {
  GetSpellName = function(id) return id == 172 and "Corruption" or ("Sort" .. id) end,
  GetSpellTexture = function(name) assert(not COMBAT, "recherche d'icone en combat") if name == "Corruption" then return 136118 end end,
}
C_Item = { GetItemInfo = function(id) return "Pierre de soins", "link" end, GetItemIconByID = function() return 135230 end }
function GetInventoryItemTexture() return 135000 end
function UnitClass() return "Démoniste", "WARLOCK", 9 end
function InCombatLockdown() return COMBAT end
function IsShiftKeyDown() return false end
function GetCursorInfo() return unpack(CURSOR) end
function GetCursorPosition() return CURSOR_POS[1], CURSOR_POS[2] end
function ClearCursor() CURSOR = {} end
function GetNumMacros()
  local a, c = 0, 0
  for _, m in pairs(MACROS) do if m.char then c = c + 1 else a = a + 1 end end
  return a, c
end
function GetMacroIndexByName(name) return MACROS[name] and MACROS[name].index or 0 end
function GetMacroInfo(name)
  local m = MACROS[name]
  if m then return name, 134400, m.body end
end
local nextIndex = 121
function CreateMacro(name, icon, body, perChar)
  assert(type(name) == "string" and #name <= 16, "nom invalide")
  assert(perChar == nil or type(perChar) == "boolean", "CreateMacro : 4e argument booleen attendu")
  assert(not COMBAT, "CreateMacro en combat")
  local index = nextIndex
  nextIndex = nextIndex + 1
  MACROS[name] = { index = index, body = body, char = perChar }
  CALLS[#CALLS + 1] = { "CreateMacro", name, body, perChar }
  return index
end
function EditMacro(index, name, icon, body)
  assert(not COMBAT, "EditMacro en combat")
  assert(type(index) == "number" and index > 0)
  MACROS[name].body = body
  CALLS[#CALLS + 1] = { "EditMacro", name, body }
  return index
end
function PickupMacro(x) assert(x ~= nil) CALLS[#CALLS + 1] = { "PickupMacro", x } end
function print(...) PRINTS[#PRINTS + 1] = table.concat({ ... }, " ") end
unpack = unpack or table.unpack

-- outils des scenarios
function fire(w, script, ...)
  local fn = w._scripts[script]
  assert(fn, "pas de script " .. script)
  return fn(w, ...)
end
function find(pred)
  for _, w in ipairs(ALL) do if pred(w) then return w end end
end
function inside(w, root) -- w descend de root ?
  while w do if w == root then return true end w = w._parent end
  return false
end
function byText(text, root) -- bouton UIPanelButtonTemplate ou puce (texte dans .text), sous root si donne
  local w = find(function(w)
    return ((w._text == text and w._type == "Button") or (w.text and w.text._text == text)) and (not root or inside(w, root))
  end)
  assert(w, "widget introuvable : " .. text)
  return w
end
function lastLine() return PRINTS[#PRINTS] or "" end
function fireEvent(event, ...)
  for _, w in ipairs(ALL) do if w._events[event] then w._scripts.OnEvent(w, event, ...) end end
end
-- cases a cocher d'une page de parametres, dans l'ordre, avec leur libelle
function checkboxes(root)
  local list = {}
  for _, w in ipairs(ALL) do
    if w._template == "UICheckButtonTemplate" and w._parent == root then
      local label
      for _, s in ipairs(root._children) do
        if s._type == "FontString" and s._point and s._point[2] == w then label = s._text end
      end
      list[#list + 1] = { box = w, label = label }
    end
  end
  return list
end
function click(cb, value) cb._checked = value fire(cb, "OnClick", "LeftButton") end
`;

function boot(dbLua, prelude) {
  L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  run(MOCK, "=mock");
  if (prelude) run(prelude, "=prelude");
  run("MacroForgeDB = " + dbLua, "=db");
  for (const f of tocFiles) loadAddonFile(f);
  run(`fireEvent("ADDON_LOADED", "Blizzard_Autre") fireEvent("ADDON_LOADED", "MacroForge")
       assert(NS.db == MacroForgeDB, "base non initialisee")`, "=load");
}

// ---------------------------------------------------------------- 1. MacroForgeDB absente : tout l'add-on
boot("nil");
run(String.raw`
local ns, db = NS, MacroForgeDB
assert(db.minimap.show == true and db.scale == 1 and db.confirmOverwrite == true, "valeurs par defaut absentes")
assert(#REGISTERED == 1, "categorie d'options non enregistree")
assert(MacroForgeMinimapButton and MacroForgeMinimapButton:IsShown(), "bouton de minicarte absent")

-- ouverture
SlashCmdList.MACROFORGE("")
assert(MacroForgeFrame, "MacroForgeFrame absent")
assert(MacroForgeFrame.TitleText._text:find("MacroForge"), "titre non pose")
assert(UISpecialFrames[1] == "MacroForgeFrame")
assert(MacroForgeFrame._scale == 1)

-- reperes
local palette = {}
for _, def in ipairs(ns.BlockDefs) do palette[def.id] = byText(def.label, MacroForgeFrame) end
local canvas = find(function(w) return w._scripts.OnReceiveDrag and w._type == "Frame" end)
assert(canvas, "zone de construction introuvable")
local rows = {}
for _, c in ipairs(canvas._children) do if c._type == "Button" then rows[#rows + 1] = c end end
assert(#rows == 12, "lignes : " .. #rows)
local function delButton(row)
  for _, c in ipairs(row._children) do if c._template == "UIPanelButtonTemplate" then return c end end
end
local edits = {}
for _, w in ipairs(ALL) do if w._type == "EditBox" then edits[#edits + 1] = w end end
local argBox, resetBox, custom, nameBox = edits[1], edits[2], edits[3], edits[4]
assert(#edits == 4, "champs : " .. #edits)
local perChar = find(function(w) return w._template == "UICheckButtonTemplate" and w._parent == nameBox._parent end)
assert(perChar)
local condButtons = {}
for _, w in ipairs(ALL) do if w.cond then condButtons[#condButtons + 1] = w end end
local box = condButtons[1]._parent
local clauseTabs = {}
for i = 1, 4 do clauseTabs[i] = byText(tostring(i), box) end
local plus, minus = byText("+", box), byText("-", box)
local clear = byText("Tout effacer")
local saveBtn = byText("Créer / mettre à jour")

-- 1. clic sur chaque bloc : 18 blocs, 12 acceptes puis message
for _, def in ipairs(ns.BlockDefs) do fire(palette[def.id], "OnClick", "LeftButton") end
assert(lastLine():find("Maximum"), "pas de message de limite")
fire(clear, "OnClick")

-- 2. chaque type de bloc : selection, conditions, alternatives, argument, suppression
for _, def in ipairs(ns.BlockDefs) do
  fire(clear, "OnClick")
  fire(palette[def.id], "OnClick")
  fire(rows[1], "OnClick")
  if def.arg then
    argBox._text = "Corruption"
    fire(argBox, "OnTextChanged", true)
  end
  if def.reset then
    resetBox._text = "target"
    fire(resetBox, "OnTextChanged", true)
  end
  if def.clauses then
    for _, b in ipairs(condButtons) do fire(b, "OnClick") end
    for _, b in ipairs(condButtons) do fire(b, "OnClick") end
    fire(condButtons[1], "OnClick")
    for _ = 1, 5 do fire(plus, "OnClick") end -- depasse MAX_CLAUSES sans erreur
    fire(clauseTabs[2], "OnClick")
    argBox._text = "Peur"
    fire(argBox, "OnTextChanged", true)
    custom._text = "stance:1"
    fire(custom, "OnEnterPressed")
    fire(byText("Vider"), "OnClick")
    fire(clauseTabs[4], "OnClick")
    for _ = 1, 5 do fire(minus, "OnClick") end
    -- tabulation entre les champs visibles
    FOCUS = argBox
    fire(argBox, "OnTabPressed")
  end
  fire(delButton(rows[1]), "OnClick")
end

-- 3. rendu des blocs : pastilles, icone, debordement
fire(clear, "OnClick")
fire(palette.cast, "OnClick")
fire(byText("Survol", box), "OnClick")
fire(byText("Hostile", box), "OnClick")
argBox._text = "Corruption"
fire(argBox, "OnTextChanged", true)
local r1 = rows[1]
assert(r1.pills[1]:IsShown() and r1.pills[1].text._text == "@ Survol", "pastille de cible : " .. tostring(r1.pills[1].text._text))
assert(r1.pills[2].text._text == "Hostile")
assert(r1.icon._tex == 136118, "icone du sort absente : " .. tostring(r1.icon._tex))
assert(not r1.more:IsShown(), "debordement inattendu")
assert(r1.full == "/cast [@mouseover,harm] Corruption", r1.full)
fire(plus, "OnClick")
argBox._text = string.rep("Trait de l'ombre ", 6)
fire(argBox, "OnTextChanged", true)
assert(r1.more:IsShown(), "debordement non signale")
fire(palette.stopattack, "OnClick")
assert(rows[2].icon._tex == "color", "bloc sans argument : carre de couleur attendu")
fire(palette.use, "OnClick")
argBox._text = "13"
fire(argBox, "OnTextChanged", true)
assert(rows[3].icon._tex == 135000, "emplacement d'objet sans icone")
fire(palette.castsequence, "OnClick")
resetBox._text = "target"
fire(resetBox, "OnTextChanged", true)
argBox._text = "Corruption, Immolation"
fire(argBox, "OnTextChanged", true)
assert(rows[4].pills[1].text._text == "reset=target" and rows[4].icon._tex == 136118)
COMBAT = true
fire(rows[1], "OnClick") -- en combat : pas de recherche d'icone (le faux C_Spell refuserait)
COMBAT = false
fire(palette.raw, "OnClick")
for i = 1, 5 do fire(rows[i], "OnClick") end

-- 4. glisser-deposer : nouveau bloc depuis la palette, puis deplacement d'une ligne
fire(clear, "OnClick")
fire(palette.cast, "OnClick")
fire(palette.use, "OnClick")
local ghost = find(function(w) return w._scripts.OnUpdate and w._parent == UIParent end)
MOUSE_OVER = true
fire(palette.stopcasting, "OnDragStart")
fire(ghost, "OnUpdate", 0.01)
fire(palette.stopcasting, "OnDragStop")
assert(rows[3]:IsShown(), "le bloc glisse n'a pas ete ajoute")
fire(rows[3], "OnDragStart")
fire(ghost, "OnUpdate", 0.01)
fire(rows[3], "OnDragStop")
MOUSE_OVER = false -- depose hors de la zone : rien ne change
fire(rows[1], "OnDragStart")
fire(ghost, "OnUpdate", 0.01)
fire(rows[1], "OnDragStop")
fire(clear, "OnClick") -- zone vide : la ligne de depot se place en haut
MOUSE_OVER = true
fire(palette.cast, "OnDragStart")
fire(ghost, "OnUpdate", 0.01)
fire(palette.cast, "OnDragStop")

-- 5. sort du grimoire et objet des sacs
CURSOR = { "spell", 3, "spell", 172 }
fire(canvas, "OnReceiveDrag")
CURSOR = { "spell", 3, "spell", 172 }
fire(rows[1], "OnReceiveDrag")
CURSOR = { "item", 5512, "link" }
fire(rows[2], "OnClick")
fire(argBox, "OnMouseDown", "LeftButton")
fire(canvas, "OnMouseUp", "LeftButton") -- curseur vide : rien

-- 6. enregistrement (reglages par defaut : sous le curseur, confirmation avant d'ecraser)
nameBox._text = "Test BM"
COMBAT = true
fire(saveBtn, "OnClick")
assert(lastLine():find("combat"), "pas de refus en combat")
COMBAT = false
perChar._checked = true
fire(saveBtn, "OnClick")
local call = CALLS[1]
assert(call and call[1] == "CreateMacro" and call[4] == true, "CreateMacro non appele")
assert(CALLS[2][1] == "PickupMacro" and CALLS[2][2] == 121)
assert(call[3]:find("/cast Corruption"), "corps inattendu : " .. call[3])
fire(saveBtn, "OnClick")
assert(#CALLS == 2 and #POPUPS == 1 and POPUPS[1].text:find("Test BM"), "confirmation attendue avant d'ecraser")
StaticPopupDialogs[POPUPS[1].which].OnAccept({}, POPUPS[1].data)
assert(CALLS[3][1] == "EditMacro", "mise a jour attendue apres confirmation")
fire(clear, "OnClick")
nameBox._text = "Test BM"
fire(byText("Charger ce nom"), "OnClick")
nameBox._text = "Inconnue"
fire(byText("Charger ce nom"), "OnClick")
assert(lastLine():find("Aucune"))
nameBox._text = ""
fire(saveBtn, "OnClick")

-- 7. bibliotheque : chaque classe, molette, chaque ligne, ouverture
fire(byText("Bibliothèque"), "OnClick")
local listPanel
for _, w in ipairs(ALL) do if w._scripts.OnMouseWheel then listPanel = w end end
assert(listPanel, "liste sans molette")
local libRows = {}
for _, c in ipairs(listPanel._children) do if c._type == "Button" then libRows[#libRows + 1] = c end end
assert(#libRows == 20)
local opened = 0
for _, token in ipairs({ "ALL", "WARLOCK", "HUNTER", "ROGUE", "MAGE", "PRIEST", "DRUID", "WARRIOR", "PALADIN", "SHAMAN" }) do
  fire(byText(token == "ALL" and "Toutes classes" or LOCALIZED_CLASS_NAMES_MALE[token]), "OnClick")
  fire(listPanel, "OnMouseWheel", -1)
  fire(listPanel, "OnMouseWheel", 1)
  local seen = {}
  repeat -- toutes les macros de la classe, page par page
    local fresh = 0
    for _, r in ipairs(libRows) do
      if r:IsShown() and not seen[r.text._text] then
        seen[r.text._text] = true
        fresh = fresh + 1
        fire(r, "OnClick")
        fire(byText("Ouvrir dans l'éditeur"), "OnClick")
        opened = opened + 1
        fire(byText("Bibliothèque"), "OnClick")
      end
    end
    for _ = 1, 7 do fire(listPanel, "OnMouseWheel", -1) end
  until fresh == 0
end
assert(opened >= #ns.Library - 5, ("macros ouvertes : %d / %d"):format(opened, #ns.Library)) -- noms en double possibles
for i = 1, 25 do ns.Library[#ns.Library + 1] = { class = "MAGE", name = "X" .. i, category = "PvE", body = "/cast Sort" .. i } end
fire(byText("Mage"), "OnClick")
for _ = 1, 30 do fire(listPanel, "OnMouseWheel", -1) end
local last
for _, r in ipairs(libRows) do if r:IsShown() then last = r end end
assert(last == libRows[20], "la derniere page doit rester pleine")
fire(last, "OnClick")
fire(byText("Ouvrir dans l'éditeur"), "OnClick")
for i = #ns.Library, 1, -1 do if ns.Library[i].class == "SHAMAN" then table.remove(ns.Library, i) end end
fire(byText("Bibliothèque"), "OnClick")
fire(byText("Chaman"), "OnClick")
assert(not libRows[1]:IsShown(), "classe vide : aucune ligne")
assert(db.lastClass == "SHAMAN", "derniere classe non memorisee")

-- 8. parametres : onglet de la fenetre
fire(byText("Paramètres", MacroForgeFrame), "OnClick")
local settingsPanel = find(function(w) return w._template == "UICheckButtonTemplate" and inside(w, MacroForgeFrame) and w ~= perChar end)._parent
assert(settingsPanel:IsVisible(), "onglet Parametres non affiche")
local checks = checkboxes(settingsPanel)
assert(#checks == 9, "cases : " .. #checks) -- 7 reglages + 2 choix de classe
for _, c in ipairs(checks) do assert(c.label, "case sans libelle") end
local function cb(fragment)
  for _, c in ipairs(checks) do if c.label:find(fragment, 1, true) then return c.box end end
  error("case introuvable : " .. fragment)
end
-- chaque case affiche la valeur sauvegardee
assert(cb("minicarte")._checked == true and cb("personnage")._checked == false)

click(cb("minicarte"), false)
assert(db.minimap.show == false and not MacroForgeMinimapButton:IsShown(), "bouton de minicarte toujours visible")
click(cb("minicarte"), true)
assert(MacroForgeMinimapButton:IsShown())

MacroForgeFrame._point = { "TOPLEFT", UIParent, "TOPLEFT", 50, -60 }
fire(MacroForgeFrame, "OnDragStop")
assert(db.pos and db.pos[1] == "TOPLEFT" and db.pos[3] == 50, "position non memorisee")
click(cb("position"), false)
assert(db.rememberPos == false and db.pos == false and MacroForgeFrame._point[1] == "CENTER", "position non oubliee")
MacroForgeFrame._point = { "TOPLEFT", UIParent, "TOPLEFT", 70, -80 }
fire(MacroForgeFrame, "OnDragStop")
assert(db.pos == false, "position memorisee alors que le reglage est coupe")
click(cb("position"), true)

click(cb("personnage"), true)
assert(perChar._checked == true, "case du personnage non cochee")
perChar._checked = false
fire(clear, "OnClick")
assert(perChar._checked == true, "Tout effacer doit remettre la valeur par defaut")
click(cb("personnage"), false)
assert(perChar._checked == false)

click(cb("curseur"), false)
fire(byText("Éditeur"), "OnClick")
fire(palette.cast, "OnClick")
argBox._text = "Corruption"
fire(argBox, "OnTextChanged", true)
nameBox._text = "Sans curseur"
local before = #CALLS
fire(saveBtn, "OnClick")
assert(#CALLS == before + 1 and CALLS[#CALLS][1] == "CreateMacro", "PickupMacro appele malgre le reglage")
click(cb("curseur"), true)

click(cb("confirmation"), false)
local popups = #POPUPS
fire(saveBtn, "OnClick")
assert(#POPUPS == popups and CALLS[#CALLS][1] == "EditMacro", "ecrasement direct attendu")
click(cb("confirmation"), true)

-- traduction : une macro avec un sort connu de SpellIDs change de texte
local spell, id = next(ns.SpellIDs)
ns.Library[#ns.Library + 1] = { class = "ALL", name = "ZZ Trad", category = "PvE", body = "/cast " .. spell }
fire(byText("Bibliothèque"), "OnClick")
fire(byText("Toutes classes"), "OnClick")
for _ = 1, 30 do fire(listPanel, "OnMouseWheel", -1) end
local tradRow
for _, r in ipairs(libRows) do if r:IsShown() and r.text._text:find("ZZ Trad") then tradRow = r end end
fire(tradRow, "OnClick")
local bodyLabel = find(function(w) return w._type == "FontString" and w._text == "/cast " .. C_Spell.GetSpellName(id) end)
assert(bodyLabel, "bibliotheque non traduite")
click(cb("Traduire"), false)
assert(bodyLabel._text == "/cast " .. spell, "bibliotheque toujours traduite : " .. bodyLabel._text)
fire(byText("Ouvrir dans l'éditeur"), "OnClick")
assert(rows[1].full == "/cast " .. spell, "l'editeur doit recevoir le texte anglais")
click(cb("Traduire"), true)
assert(bodyLabel._text == "/cast " .. C_Spell.GetSpellName(id))

click(cb("Infobulles"), false)
TOOLTIP_LINES = 0
fire(saveBtn, "OnEnter")
assert(TOOLTIP_LINES == 0, "lignes d'aide affichees malgre le reglage")
click(cb("Infobulles"), true)
fire(saveBtn, "OnEnter")
assert(TOOLTIP_LINES > 0, "lignes d'aide absentes")

-- echelle
local splus, sminus, sone = byText("+", settingsPanel), byText("-", settingsPanel), byText("100 %", settingsPanel)
for _ = 1, 30 do fire(splus, "OnClick") end
assert(math.abs(db.scale - 1.5) < 1e-6 and math.abs(MacroForgeFrame._scale - 1.5) < 1e-6, "echelle max : " .. db.scale)
for _ = 1, 30 do fire(sminus, "OnClick") end
assert(math.abs(db.scale - 0.6) < 1e-6, "echelle min : " .. db.scale)
fire(sone, "OnClick")
assert(db.scale == 1)
fire(splus, "OnClick")

-- classe de depart
click(cb("Dernière"), true)
assert(db.libraryClass == "last" and cb("Ma classe")._checked == false, "choix exclusif casse")
click(cb("Ma classe"), true)
assert(db.libraryClass == "player" and cb("Dernière")._checked == false)
click(cb("Dernière"), true)

-- reinitialisation
click(cb("minicarte"), false)
db.minimap.angle = 10
fire(byText("Réinitialiser les paramètres", settingsPanel), "OnClick")
assert(db.scale == 1 and db.minimap.show == true and db.minimap.angle == 225 and db.libraryClass == "player"
  and db.pos == false and db.lastClass == false, "reinitialisation incomplete")
assert(MacroForgeFrame._scale == 1 and MacroForgeMinimapButton:IsShown())
assert(cb("minicarte")._checked == true and cb("Ma classe")._checked == true, "cases non resynchronisees")
assert(NS.db == MacroForgeDB, "reference de la base perdue")

-- page des options du jeu : meme reglages, synchronisee
local gamePanel
for _, w in ipairs(ALL) do if w.name == "MacroForge" and not w._parent then gamePanel = w end end
assert(gamePanel, "panneau des options du jeu absent")
local gameChecks = checkboxes(gamePanel)
assert(#gameChecks == 9)
click(gameChecks[1].box, false)
fire(settingsPanel, "OnShow")
assert(cb("minicarte")._checked == false, "les deux pages ne sont pas synchronisees")
click(gameChecks[1].box, true)
gamePanel.OnRefresh(gamePanel)
gamePanel.OnDefault(gamePanel)
assert(db == MacroForgeDB and MacroForgeDB.scale == 1)

-- 9. bouton de minicarte
local mm = MacroForgeMinimapButton
MacroForgeFrame:Hide()
fire(mm, "OnClick", "LeftButton")
assert(MacroForgeFrame:IsShown(), "clic gauche : ouvrir")
fire(mm, "OnClick", "LeftButton")
assert(not MacroForgeFrame:IsShown(), "clic gauche : fermer")
fire(mm, "OnClick", "RightButton")
assert(MacroForgeFrame:IsShown() and settingsPanel:IsVisible(), "clic droit : parametres")
fire(mm, "OnEnter")
fire(mm, "OnLeave")
CURSOR_POS = { 1000, 700 } -- au-dessus du centre de la minicarte (1000, 600)
fire(mm, "OnDragStart")
assert(mm._scripts.OnUpdate, "pas de suivi du curseur")
mm._scripts.OnUpdate(mm, 0.01)
CURSOR_POS = { 900, 600 } -- a gauche
fire(mm, "OnDragStop")
assert(math.abs(db.minimap.angle - 180) < 1e-6, "angle : " .. db.minimap.angle)
assert(mm._scripts.OnUpdate == nil, "suivi du curseur non arrete")
local p = mm._point
assert(p[2] == Minimap and math.abs(p[4] + 80) < 1e-6 and math.abs(p[5]) < 1e-6, "position autour de la minicarte")
-- menu des add-ons (Forever)
MacroForge_OnAddonCompartmentClick("MacroForge", "LeftButton")
MacroForge_OnAddonCompartmentClick("MacroForge", "RightButton")
MacroForge_OnAddonCompartmentEnter("MacroForge", UIParent)
MacroForge_OnAddonCompartmentLeave("MacroForge", UIParent)

-- 10. toutes les infobulles, commandes, fermeture / reouverture
for _, w in ipairs(ALL) do
  if w._scripts.OnEnter then w._scripts.OnEnter(w) end
  if w._scripts.OnLeave then w._scripts.OnLeave(w) end
end
SlashCmdList.MACROFORGE("options")
assert(MacroForgeFrame:IsShown() and settingsPanel:IsVisible())
SlashCmdList.MACROFORGE("")
assert(not MacroForgeFrame:IsShown())
SlashCmdList.MACROFORGE("")
assert(MacroForgeFrame:IsShown())
io.write(#ALL .. " widgets, " .. #CALLS .. " appels macro, " .. #PRINTS .. " messages\n")
for _, p in ipairs(PRINTS) do io.write("  > ", p, "\n") end
`, "=scenario");

// ---------------------------------------------------------------- 2. MacroForgeDB partielle (ancienne version)
boot(`{ scale = "grand", minimap = { angle = 400 }, pos = { "TOPLEFT", "TOPLEFT", 10, -20 },
        libraryClass = "last", lastClass = "MAGE", perCharDefault = true, confirmOverwrite = false }`);
run(String.raw`
local db = MacroForgeDB
assert(db.scale == 1, "echelle invalide gardee")
assert(db.minimap.show == true and db.minimap.angle == 40, "minicarte mal completee")
assert(db.pos[3] == 10 and db.libraryClass == "last" and db.lastClass == "MAGE")
assert(db.confirmOverwrite == false and db.pickupAfterCreate == true and db.localizeLibrary == true)
SlashCmdList.MACROFORGE("")
local p = MacroForgeFrame._point
assert(p[1] == "TOPLEFT" and p[2] == UIParent and p[4] == 10 and p[5] == -20, "position non restauree")
local perChar = find(function(w) return w._template == "UICheckButtonTemplate" and inside(w, MacroForgeFrame) end)
assert(perChar._checked == true, "case du personnage non cochee au chargement")
fire(byText("Bibliothèque"), "OnClick")
-- la bibliotheque s'ouvre sur la derniere classe (Mage) : sa puce est dans l'etat choisi
local listPanel
for _, w in ipairs(ALL) do if w._scripts.OnMouseWheel then listPanel = w end end
local first
for _, c in ipairs(listPanel._children) do if c._type == "Button" and c:IsShown() then first = c break end end
local mage
for _, e in ipairs(NS.Library) do if e.class == "MAGE" then mage = e break end end
assert(first and first.text._text:find(mage.name, 1, true), "bibliotheque non ouverte sur la derniere classe")
`, "=partiel");

// ---------------------------------------------------------------- 3. MacroForgeDB corrompue
boot(`{ minimap = "oui", pos = 5, lastClass = 12, libraryClass = "autre", scale = 9, helpTooltips = "non" }`);
run(String.raw`
local db = MacroForgeDB
assert(type(db.minimap) == "table" and db.minimap.show == true and db.minimap.angle == 225)
assert(db.pos == false and db.lastClass == false and db.libraryClass == "player")
assert(db.scale == 1.5 and db.helpTooltips == true, "valeurs corrompues gardees")
SlashCmdList.MACROFORGE("")
assert(MacroForgeFrame._point[1] == "CENTER")
fire(MacroForgeMinimapButton, "OnClick", "RightButton")
`, "=corrompu");

// ---------------------------------------------------------------- 4. sans API Settings (Classic Era) ni Minimap
L = null;
L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
run(MOCK, "=mock");
run(`Settings = nil  Minimap = nil  CATEGORIES = {}
     function InterfaceOptions_AddCategory(p) assert(p.name == "MacroForge") CATEGORIES[#CATEGORIES + 1] = p end
     MacroForgeDB = nil`, "=classic");
for (const f of tocFiles) loadAddonFile(f);
run(`fireEvent("ADDON_LOADED", "MacroForge")
     assert(#CATEGORIES == 1, "repli InterfaceOptions_AddCategory absent")
     SlashCmdList.MACROFORGE("options")`, "=classic2");

// ---------------------------------------------------------------- 5. client anglais : textes et descEN
boot("nil", `function GetLocale() return "enUS" end`);
run(String.raw`
SlashCmdList.MACROFORGE("")
assert(MacroForgeFrame.TitleText._text == "MacroForge — block-based macro editor")
fire(byText("Create / update"), "OnClick")
assert(lastLine():find("Give the macro a name"), lastLine())
local descs = {}
for _, e in ipairs(NS.Library) do e.descEN = e.descEN or ("EN " .. e.name) descs[e.descEN] = true end
fire(byText("Library"), "OnClick")
fire(byText("All classes"), "OnClick")
local listPanel
for _, w in ipairs(ALL) do if w._scripts.OnMouseWheel then listPanel = w end end
for _, c in ipairs(listPanel._children) do if c._type == "Button" and c:IsShown() then fire(c, "OnClick") break end end
assert(find(function(w) return w._type == "FontString" and descs[w._text] end), "descEN non affichee")
fire(byText("Settings", MacroForgeFrame), "OnClick")
for _, w in ipairs(ALL) do
  if w._scripts.OnEnter then w._scripts.OnEnter(w) end
end
`, "=anglais");

console.log("test_ui.js : OK (5 scenarios)");
