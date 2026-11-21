// Charge l'add-on (ordre du .toc) dans fengari avec de faux widgets WoW, simule ADDON_LOADED, ouvre /bf et clique partout :
// editeur, rendu des blocs, bibliotheque, parametres, bouton de minicarte. Trois etats de BlockForgeDB : vide, partiel, corrompu.
// But : attraper les erreurs Lua (nil, ordre de creation, fermetures) et verifier que chaque reglage agit, pas valider le rendu.
// Usage : node test_ui.js <dossier BlockForge>
const fs = require("fs");
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require("fengari");
const dir = process.argv[2] || __dirname + "/../BlockForge";
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
  lua.lua_pushstring(L, to_luastring("BlockForge"));
  lua.lua_getglobal(L, to_luastring("NS"));
  check(lua.lua_pcall(L, 2, 0, 0));
}
// fichiers dans l'ordre du .toc
const tocFiles = fs.readFileSync(dir + "/BlockForge.toc", "utf8").split(/\r?\n/)
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
WIDGET = W
local function noop() end
W.__index = function(t, k)
  local m = rawget(W, k)
  if m then return m end
  if ABSENT and ABSENT[k] then return nil end -- methode que ce client n'a pas
  if type(k) == "string" and k:match("^%u") then return noop end -- toute methode inconnue est acceptee
  return nil -- champ absent (ex. .text) : nil comme en jeu
end
local function new(kind, parent, template)
  local w = setmetatable({ _type = kind, _parent = parent, _template = template, _scripts = {}, _children = {},
                           _events = {}, _w = 0, _h = 0 }, W)
  if parent then table.insert(parent._children, w) end
  ALL[#ALL + 1] = w
  if template == "UICheckButtonTemplate" then
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
function W:GetHeight() return self._h end
function W:GetCenter() return 1000, 600 end
function W:SetScale(s) assert(type(s) == "number" and s > 0, "SetScale invalide") self._scale = s end
function W:SetTexture(t) self._tex = t end
function W:SetColorTexture(...) self._tex = "color" self._color = { ... } end
function W:SetTextColor(...) self._textColor = { ... } end
function W:SetBackdropBorderColor(...) self._border = { ... } end
function W:CreateAnimationGroup() return new("AnimationGroup", self) end
function W:CreateAnimation(kind) assert(kind == "Alpha") return new("Animation", self) end
function W:Play() self._plays = (self._plays or 0) + 1 end
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
RAID_CLASS_COLORS = { WARLOCK = { r = 0.53, g = 0.53, b = 0.93 } }
YES, NO = "Oui", "Non"
SlashCmdList = {}
StaticPopupDialogs = {}
function StaticPopup_Show(which, a1, a2, data)
  assert(StaticPopupDialogs[which], "dialogue inconnu " .. tostring(which))
  POPUPS[#POPUPS + 1] = { which = which, text = StaticPopupDialogs[which].text:format(a1, a2), data = data }
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
ITEM_NAMES = {}     -- cache d'objets du client : id -> nom traduit
ITEM_REQUESTS = {}  -- appels a RequestLoadItemDataByID
C_Item = { GetItemInfo = function(id) return "Pierre de soins", "link" end, GetItemIconByID = function() return 135230 end,
  GetItemNameByID = function(id) return ITEM_NAMES[id] end,
  RequestLoadItemDataByID = function(id) ITEM_REQUESTS[#ITEM_REQUESTS + 1] = id end }
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
function GetMacroInfo(key) -- nom ou index (1-120 generales, 121-150 personnage)
  for name, m in pairs(MACROS) do
    if name == key or m.index == key then return name, m.icon or 134400, m.body end
  end
end
function CreateMacro(name, icon, body, perChar)
  assert(type(name) == "string" and #name <= 16, "nom invalide")
  assert(perChar == nil or type(perChar) == "boolean", "CreateMacro : 4e argument booleen attendu")
  assert(not COMBAT, "CreateMacro en combat")
  local a, c = GetNumMacros()
  if (perChar and c >= 30) or (not perChar and a >= 120) then return nil end
  local index = perChar and 121 + c or 1 + a -- shortcut: pas de tri alphabetique comme en jeu
  MACROS[name] = { index = index, body = body, char = perChar, icon = icon }
  CALLS[#CALLS + 1] = { "CreateMacro", name, body, perChar, icon }
  return index
end
function EditMacro(index, name, icon, body)
  assert(not COMBAT, "EditMacro en combat")
  assert(type(index) == "number" and index > 0)
  local m = MACROS[name]
  assert(m and m.index == index, "EditMacro : index ne correspond pas au nom")
  m.body = body
  if icon then m.icon = icon end
  CALLS[#CALLS + 1] = { "EditMacro", name, body, icon }
  return index
end
BINDINGS = {}       -- touche -> action
SAVED_BINDINGS = nil
CHORD = ""          -- modificateurs tenus, ex. "CTRL-"
function GetBindingAction(key) return BINDINGS[key] or "" end
function GetBindingKey(action) for k, v in pairs(BINDINGS) do if v == action then return k end end end
function GetBindingName(action) return "Nom de " .. action end
function SetBindingMacro(key, name) assert(not COMBAT, "SetBindingMacro en combat") BINDINGS[key] = "MACRO " .. name return true end
function GetCurrentBindingSet() return 2 end
function SaveBindings(set) SAVED_BINDINGS = set end
function IsKeyPressIgnoredForBinding(key) return key == "LSHIFT" or key == "LCTRL" or key == "LALT" end
function CreateKeyChordStringUsingMetaKeyState(key) return CHORD .. key end
function date(fmt)
  assert(fmt == "%Y-%m-%d" or fmt == "%Y-%m-%d %H:%M:%S", fmt)
  return fmt == "%Y-%m-%d" and "2026-11-20" or "2026-11-20 12:00:00"
end
HANDLED = {}        -- erreurs recues par le gestionnaire du jeu
local errorHandler = function(msg) HANDLED[#HANDLED + 1] = msg end
function geterrorhandler() return errorHandler end
function seterrorhandler(fn) assert(type(fn) == "function") errorHandler = fn end
function debugstack() return string.rep("x", 3000) end
function GetBuildInfo() return "1.60.1", "70959", "Nov 1 2026", 16001 end
C_AddOns = { GetAddOnMetadata = function(addon, field) assert(addon == "BlockForge") return field == "Version" and "0.6.2" or nil end }
function PickupMacro(x) assert(x ~= nil) CALLS[#CALLS + 1] = { "PickupMacro", x } end
-- lot 2 : canal des add-ons, cible, horloge, touche Ctrl
SENT = {}           -- messages d'add-on envoyes : { prefixe, texte, canal, destinataire }
SEND_RESULT = 0     -- retour de SendAddonMessage (0 = envoye)
PREFIXES = {}
NOW = 1000
CTRL = false
TARGET = nil        -- nom du joueur ami cible
C_ChatInfo = {
  RegisterAddonMessagePrefix = function(p) PREFIXES[#PREFIXES + 1] = p return true end,
  SendAddonMessage = function(prefix, text, channel, target)
    assert(not COMBAT, "SendAddonMessage en combat")
    assert(#prefix <= 16 and #text <= 255, "message d'add-on trop long : " .. #text)
    SENT[#SENT + 1] = { prefix, text, channel, target }
    return SEND_RESULT
  end,
}
function GetTime() return NOW end
function IsControlKeyDown() return CTRL end
function UnitName(unit) assert(unit == "player") return "Moi" end
function GetNormalizedRealmName() return "Royaume" end
function UnitExists(unit) return unit == "target" and TARGET ~= nil end
function UnitIsPlayer() return true end
function UnitIsFriend() return true end
function UnitIsUnit() return false end
function GetUnitName(unit, realm) assert(unit == "target" and realm == true) return TARGET end
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
function byText(text, root) -- bouton ou puce (texte dans .text), sous root si donne
  local w = find(function(w)
    return ((w._text == text and w._type == "Button") or (w.text and w.text._text == text)) and (not root or inside(w, root))
  end)
  assert(w, "widget introuvable : " .. text)
  return w
end
function lastLine() return PRINTS[#PRINTS] or "" end
function plain(s) -- texte affiche sans ses codes de couleur, || relu comme |
  local out, i = {}, 1
  while i <= #s do
    if s:sub(i, i + 1) == "||" then out[#out + 1] = "|" i = i + 2
    elseif s:find("^|c%x%x%x%x%x%x%x%x", i) then i = i + 10
    elseif s:sub(i, i + 1) == "|r" then i = i + 2
    else out[#out + 1] = s:sub(i, i) i = i + 1 end
  end
  return table.concat(out)
end
function libraryList() -- liste de la bibliotheque : lignes marquees, sans colonne d'onglet (Mes macros)
  for _, w in ipairs(ALL) do
    if w._scripts.OnMouseWheel then
      for _, c in ipairs(w._children) do if c.mark and not c.scope then return w end end
    end
  end
end
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
require(__dirname + "/lua51")(L);
  run(MOCK, "=mock");
  if (prelude) run(prelude, "=prelude");
  run("BlockForgeDB = " + dbLua, "=db");
  for (const f of tocFiles) loadAddonFile(f);
  run(`fireEvent("ADDON_LOADED", "Blizzard_Autre") fireEvent("ADDON_LOADED", "BlockForge")
       assert(NS.db == BlockForgeDB, "base non initialisee")`, "=load");
}

// ---------------------------------------------------------------- 1. BlockForgeDB absente : tout l'add-on
boot("nil");
run(String.raw`
local ns, db = NS, BlockForgeDB
assert(db.minimap.show == true and db.scale == 1 and db.confirmOverwrite == true, "valeurs par defaut absentes")
assert(#REGISTERED == 1, "categorie d'options non enregistree")
assert(BlockForgeMinimapButton and BlockForgeMinimapButton:IsShown(), "bouton de minicarte absent")

-- ouverture
SlashCmdList.BLOCKFORGE("")
assert(BlockForgeFrame, "BlockForgeFrame absent")
assert(BlockForgeFrame.TitleText._text:find("BlockForge"), "titre non pose")
assert(UISpecialFrames[1] == "BlockForgeFrame")
assert(BlockForgeFrame._scale == 1)
-- barre de titre : version du TOC ; fondu joue a la creation puis a chaque ouverture
assert(find(function(w) return w._type == "FontString" and w._text == "v0.6.2" and w._parent == BlockForgeFrame end), "version absente du titre")
assert(ns.fade and ns.fade._plays == 1, "fondu non joue a l'ouverture")
fire(BlockForgeFrame, "OnShow")
assert(ns.fade._plays == 2)
-- couleur d'accent par defaut : celle de la classe (faux RAID_CLASS_COLORS), sur le titre et l'onglet actif
local T = ns.Theme
assert(db.accent == "class" and T.accent[1] == 0.53 and T.accent[3] == 0.93, "accent de classe : " .. T.accent[1])
assert(BlockForgeFrame.TitleText._textColor[1] == 0.53, "titre sans la couleur d'accent")
-- V1 : la fenetre s'ouvre sur l'accueil
local tabHome, tabEditor, tabLibrary = byText("Accueil"), byText("Éditeur"), byText("Bibliothèque")
assert(tabHome.line:IsShown() and not tabEditor.line:IsShown() and tabHome._border[1] == 0.53, "la fenetre ne s'ouvre pas sur l'accueil")
fire(tabEditor, "OnClick")
assert(not tabHome.line:IsShown(), "accueil encore marque")
assert(tabEditor.line:IsShown() and not tabLibrary.line:IsShown() and tabEditor._border[1] == 0.53 and tabLibrary._border[1] ~= 0.53, "onglet actif non marque")

-- reperes
local palette = {}
for _, def in ipairs(ns.BlockDefs) do palette[def.id] = byText(def.label, BlockForgeFrame) end
local canvas = find(function(w) return w._scripts.OnReceiveDrag and w._type == "Frame" end)
assert(canvas, "zone de construction introuvable")
local rows = {}
for _, c in ipairs(canvas._children) do if c.pills then rows[#rows + 1] = c end end
assert(#rows == 12, "lignes : " .. #rows)
local function delButton(row)
  for _, c in ipairs(row._children) do if c._type == "Button" then return c end end
end
local edits = {}
for _, w in ipairs(ALL) do if w._type == "EditBox" then edits[#edits + 1] = w end end
local argBox, resetBox, custom, nameBox, textBox, modelShare, search = edits[1], edits[2], edits[3], edits[4], edits[5], edits[6], edits[7]
assert(#edits == 9, "champs : " .. #edits) -- + partage des modeles (Bibliotheque), partage et nom de sauvegarde (Mes macros)
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

-- 1. clic sur chaque bloc : 21 blocs acceptes, 12 lignes visibles, defilement jusqu'au dernier ajoute
local editRange = find(function(w) return w._type == "FontString" and w._point and w._point[1] == "BOTTOMRIGHT" and w._parent == canvas end)
for _, def in ipairs(ns.BlockDefs) do fire(palette[def.id], "OnClick", "LeftButton") end
assert(editRange._text == "10-21 / 21  (molette)", "defilement : " .. tostring(editRange._text))
assert(rows[12].full == ns.BlockById.raw.label, "dernier bloc non visible : " .. tostring(rows[12].full))
fire(clear, "OnClick")
assert(editRange._text == "", "indicateur sans defilement")

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

-- 4b. macro de 15 lignes : rien de perdu, defilement, selection et deplacement au-dela de la 12e ligne
local long = {}
for i = 1, 15 do long[i] = "/cast A" .. i end
MACROS["Longue"] = { index = 5, body = table.concat(long, "\n") }
nameBox._text = "Longue"
fire(byText("Charger ce nom"), "OnClick")
MACROS["Longue"] = nil
local function compiled() -- texte de l'apercu (simulateur coupe) = ns.Compile des blocs
  return plain(find(function(w) return w._type == "FontString" and w._text and plain(w._text):find("^/cast A") and not inside(w, ghost) end)._text)
end
assert(compiled() == table.concat(long, "\n"), "macro coupee : " .. compiled())
assert(rows[1].full == "/cast A1" and editRange._text == "1-12 / 15  (molette)", editRange._text)
fire(canvas, "OnMouseWheel", -1)
assert(rows[1].full == "/cast A4" and rows[12].full == "/cast A15" and editRange._text == "4-15 / 15  (molette)", rows[1].full)
fire(canvas, "OnMouseWheel", -1) -- deja en bas : l'offset reste borne
assert(rows[1].full == "/cast A4")
fire(rows[12], "OnClick")
assert(argBox._text == "A15", "selection au-dela de la 12e ligne : " .. argBox._text)
fire(rows[12], "OnDragStart")
fire(ghost, "OnUpdate", 0.01)
fire(rows[12], "OnDragStop") -- depose au-dessus de la 1re ligne visible (bloc 4)
table.insert(long, 4, table.remove(long, 15))
assert(compiled() == table.concat(long, "\n"), "deplacement : " .. compiled())
assert(rows[1].full == "/cast A15" and argBox._text == "A15", "le bloc deplace doit rester visible et choisi")
for _ = 1, 5 do fire(canvas, "OnMouseWheel", 1) end
assert(rows[1].full == "/cast A1")
fire(palette.cast, "OnClick") -- ajout en bas, hors des lignes visibles : on defile jusqu'a lui
assert(rows[12].full == "/cast" and argBox._text == "" and editRange._text == "5-16 / 16  (molette)", editRange._text)
fire(delButton(rows[12]), "OnClick")
assert(editRange._text == "4-15 / 15  (molette)" and rows[12]:IsShown(), editRange._text)
fire(clear, "OnClick")

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
-- "Automatique" : comme avant, point d'interrogation a la creation, icone gardee a la mise a jour
assert(CALLS[1][5] == "INV_Misc_QuestionMark" and CALLS[3][4] == nil, "icone automatique : " .. tostring(CALLS[1][5]))

-- 6b. bouton d'action (icone et nom comme sur une barre) et grille d'icones
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local accent = ns.Theme.accent
local action = find(function(w) return w.icon and w._type == "Button" and w._parent == nameBox._parent end)
assert(action, "bouton d'action introuvable")
fire(clear, "OnClick")
assert(action.icon._tex == QUESTION and action._border[1] ~= accent[1], "macro vide : point d'interrogation")
fire(palette.use, "OnClick")
argBox._text = "13"
fire(argBox, "OnTextChanged", true)
assert(action.icon._tex == 135000, "premier /use : " .. tostring(action.icon._tex))
nameBox._text = "Abc"
fire(nameBox, "OnTextChanged", true)
assert(find(function(w) return w._type == "FontString" and w._text == "Abc" and w._point and w._point[2] == action end), "nom sous le bouton")
-- macro du jeu avec sa propre icone : restauree ; #showtooltip passe avant le premier /use
MACROS["Ico"] = { index = 7, body = "#showtooltip Corruption\n/use 13", icon = 132000 }
nameBox._text = "Ico"
fire(byText("Charger ce nom"), "OnClick")
assert(action.icon._tex == 132000 and action._border[1] == accent[1], "icone de la macro chargee : " .. tostring(action.icon._tex))
C_SpellBook = {
  GetNumSpellBookSkillLines = function() return 1 end,
  GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = 3 } end,
  GetSpellBookItemName = function(i) return ({ "Peur", "Corruption", "Corruption" })[i] end,
}
Enum = { SpellBookSpellBank = { Player = 0 } }
fireEvent("SPELLS_CHANGED")
GetMacroIcons = function(t) t[1] = 134400 for i = 1, 200 do t[i + 1] = 200000 + i end end
COMBAT = true
fire(action, "OnClick")
local picker = find(function(w) return rawget(w, "Toggle") end)
assert(not picker:IsShown() and lastLine():find("combat"), "grille ouverte en combat")
COMBAT = false
fire(action, "OnClick")
assert(picker:IsShown(), "grille non ouverte")
local cells = {}
for _, c in ipairs(picker._children) do if c.icon then cells[#cells + 1] = c end end
assert(#cells == 48, "boutons de la grille : " .. #cells) -- reutilises : pas un par icone
-- Automatique, puis le grimoire (sans doublon, sans sort sans icone), puis les icones de macro du jeu (sans le ?)
assert(cells[1].icon._tex == QUESTION and cells[2].icon._tex == 136118 and cells[3].icon._tex == 200001 and cells[48].icon._tex == 200046,
  "contenu de la grille : " .. tostring(cells[3].icon._tex))
assert(cells[1]._border[1] ~= accent[1], "Automatique marque alors que la macro a une icone")
for _ = 1, 50 do fire(picker, "OnMouseWheel", -1) end -- 202 icones : la derniere page commence a la 161e
assert(cells[1].icon._tex == 200159 and cells[42].icon._tex == 200200 and not cells[43]:IsShown(), "derniere page : " .. tostring(cells[1].icon._tex))
for _ = 1, 50 do fire(picker, "OnMouseWheel", 1) end
fire(cells[1], "OnClick") -- Automatique : l'icone suit #showtooltip
assert(not picker:IsShown() and action.icon._tex == 136118 and action._border[1] ~= accent[1], "Automatique : " .. tostring(action.icon._tex))
fire(saveBtn, "OnClick") -- choix explicite sur une macro existante : le point d'interrogation remplace son icone
local icoPop = POPUPS[#POPUPS]
assert(icoPop.which == "BLOCKFORGE_OVERWRITE" and icoPop.data.icon == "INV_Misc_QuestionMark", "icone automatique non transmise")
StaticPopupDialogs.BLOCKFORGE_OVERWRITE.OnAccept({}, icoPop.data)
assert(CALLS[#CALLS][1] == "EditMacro" and CALLS[#CALLS][4] == "INV_Misc_QuestionMark" and MACROS["Ico"].icon == "INV_Misc_QuestionMark")
fire(byText("Charger ce nom"), "OnClick") -- rechargee sans toucher a l'icone : la mise a jour la garde
assert(action.icon._tex == 136118)
fire(saveBtn, "OnClick")
assert(POPUPS[#POPUPS].data.icon == nil, "icone envoyee sans choix du joueur")
fire(action, "OnClick")
assert(cells[1]._border[1] == accent[1], "Automatique non marque")
fire(cells[5], "OnClick") -- une icone du jeu, pour une nouvelle macro
assert(action.icon._tex == 200003 and action._border[1] == accent[1])
fire(action, "OnClick")
assert(cells[5]._border[1] == accent[1] and cells[1]._border[1] ~= accent[1], "icone choisie non marquee")
fire(nameBox._parent, "OnHide") -- onglet change ou fenetre fermee : la grille se ferme
assert(not picker:IsShown(), "grille restee ouverte")
nameBox._text = "Ico2"
perChar._checked = false
fire(saveBtn, "OnClick")
assert(CALLS[#CALLS - 1][1] == "CreateMacro" and CALLS[#CALLS - 1][2] == "Ico2" and CALLS[#CALLS - 1][5] == 200003, "icone choisie non enregistree")
fire(clear, "OnClick")
assert(action.icon._tex == QUESTION and action._border[1] ~= accent[1], "Tout effacer doit revenir a Automatique")
MACROS["Ico"], MACROS["Ico2"], C_SpellBook, GetMacroIcons = nil, nil, nil, nil
fireEvent("SPELLS_CHANGED")

-- 7. bibliotheque : chaque classe, molette, chaque ligne, ouverture
fire(byText("Bibliothèque"), "OnClick")
local listPanel = libraryList()
assert(listPanel, "liste sans molette")
local libRows = {}
for _, c in ipairs(listPanel._children) do if c.mark then libRows[#libRows + 1] = c end end
assert(#libRows == 18)
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
assert(last == libRows[18], "la derniere page doit rester pleine")
fire(last, "OnClick")
fire(byText("Ouvrir dans l'éditeur"), "OnClick")
for i = #ns.Library, 1, -1 do if ns.Library[i].class == "SHAMAN" then table.remove(ns.Library, i) end end
fire(byText("Bibliothèque"), "OnClick")
fire(byText("Chaman"), "OnClick")
assert(libRows[6]:IsShown() and not libRows[7]:IsShown(), "classe sans recette de sort : six recettes vivantes communes")
assert(db.lastClass == "SHAMAN", "derniere classe non memorisee")

-- 7b. recherche + categorie + favoris
local function visibleRows()
  local list = {}
  for _, r in ipairs(libRows) do if r:IsShown() then list[#list + 1] = r end end
  return list
end
local function rowOf(name)
  for _, r in ipairs(visibleRows()) do if r.text._text:find(name, 1, true) then return r end end
end
local pet
for _, e in ipairs(ns.Library) do if e.class == "WARLOCK" and e.category == "Pet" then pet = e break end end
fire(byText("Démoniste"), "OnClick")
-- sorts connus : calcules une fois par macro, pas a chaque rendu ni a chaque frappe ; recalcules quand les sorts changent
local spellInfoCalls = 0
C_Spell.GetSpellInfo = function(name) spellInfoCalls = spellInfoCalls + 1 return { name = name } end
fireEvent("SPELLS_CHANGED") -- oublie les resultats calcules sans GetSpellInfo
fire(byText("Démoniste"), "OnClick")
local firstRender = spellInfoCalls
assert(firstRender > 0, "aucune verification de sort")
fire(byText("Démoniste"), "OnClick")
search._text = "peur"
fire(search, "OnTextChanged", true)
local fold, folds = ns.Fold, 0
ns.Fold = function(s) folds = folds + 1 return fold(s) end
search._text = "peu"
fire(search, "OnTextChanged", true)
ns.Fold = fold
assert(folds == 1, "texte de recherche recalcule : " .. folds) -- la requete seulement
search._text = ""
fire(search, "OnTextChanged", true)
assert(spellInfoCalls == firstRender, ("GetSpellInfo : %d appels apres %d"):format(spellInfoCalls, firstRender))
fireEvent("PLAYER_REGEN_ENABLED")
fire(byText("Démoniste"), "OnClick")
assert(spellInfoCalls == 2 * firstRender, "cache non invalide en fin de combat")
C_Spell.GetSpellInfo = nil
fireEvent("SPELLS_CHANGED")
ns.Library[#ns.Library + 1] = { class = "WARLOCK", name = "ZZ Éclair GLACÉ", category = "PvE", body = "/cast Sort" }
for _, q in ipairs({ "eclair glace", "ÉCLAIR GLACÉ", "éclair glacé" }) do -- sans accents ni casse
  search._text = q
  fire(search, "OnTextChanged", true)
  assert(rowOf("ZZ Éclair GLACÉ"), "recherche sans accents : " .. q)
end
table.remove(ns.Library)
search._text = pet.name:upper() -- insensible a la casse
fire(search, "OnTextChanged", true)
assert(rowOf(pet.name), "recherche : macro absente")
fire(byText("PvP", listPanel), "OnClick")
assert(not rowOf(pet.name), "categorie PvP : macro Familier affichee")
fire(byText("Familier", listPanel), "OnClick")
fire(rowOf(pet.name), "OnClick")
fire(byText("Ajouter aux favoris"), "OnClick")
assert(db.favorites["WARLOCK/" .. pet.name] == true, "favori non enregistre")
assert(rowOf(pet.name).text._text:find("FavoritesIcon"), "marque de favori absente")
search._text = "aucune macro ne contient ce texte"
fire(search, "OnTextChanged", true)
assert(#visibleRows() == 0)
search._text = ""
fire(search, "OnTextChanged", true)
fire(byText("Toutes", listPanel), "OnClick")
local favChip = find(function(w) return w.text and w.text._text and w.text._text:find("Favoris$") end)
fire(favChip, "OnClick")
assert(#visibleRows() == 1 and rowOf(pet.name), "liste des favoris")
assert(db.lastClass == "WARLOCK", "Favoris memorise comme derniere classe")
local onlyKnownBox = find(function(w) return w._template == "UICheckButtonTemplate" and inside(w, listPanel._parent) and w ~= perChar end)
click(onlyKnownBox, false) -- la case garde la liste des favoris
assert(#visibleRows() == 1)
fire(byText("Retirer des favoris"), "OnClick")
assert(db.favorites["WARLOCK/" .. pet.name] == nil and #visibleRows() == 0, "favori non retire")
fire(byText("Démoniste"), "OnClick")

-- 7c. modele charge dans l'editeur
fire(byText("Éditeur"), "OnClick")
fire(clear, "OnClick")
local tplList = byText(ns.Templates[1].label)._parent
fire(byText("Modèles"), "OnClick")
assert(tplList:IsShown())
fire(canvas, "OnHide") -- onglet change ou fenetre fermee : la liste se ferme
assert(not tplList:IsShown(), "liste des modeles restee ouverte")
fire(byText("Modèles"), "OnClick")
fire(byText(ns.Templates[1].label), "OnClick") -- editeur vide : pas de confirmation
assert(not tplList:IsShown())
assert(rows[3].full == "/cast [@mouseover,harm,nodead][]", rows[3].full)
local marked
for _, t in ipairs(rows[3].texts) do if t:IsShown() and t._text == "(argument ?)" then marked = true end end
assert(marked, "emplacement vide non signale")
CURSOR = { "spell", 3, "spell", 172 }
fire(rows[3], "OnReceiveDrag") -- le sort remplit l'emplacement au lieu d'ajouter un bloc
assert(rows[3].full == "/cast [@mouseover,harm,nodead][] Corruption" and not rows[4]:IsShown(), rows[3].full)
local popupsBefore = #POPUPS
fire(byText(ns.Templates[5].label), "OnClick")
assert(#POPUPS == popupsBefore + 1 and POPUPS[#POPUPS].which == "BLOCKFORGE_TEMPLATE", "confirmation attendue")
assert(rows[3].full:find("Corruption"), "modele charge avant confirmation")
StaticPopupDialogs.BLOCKFORGE_TEMPLATE.OnAccept({}, POPUPS[#POPUPS].data)
assert(rows[2].full == "/use 13" and rows[3].full == "/cast", "modele non charge")
-- sort inconnu : le nom le plus proche du grimoire est propose, un clic le met a la place
C_Spell.GetSpellInfo = function() return nil end
C_SpellBook = {
  GetNumSpellBookSkillLines = function() return 1 end,
  GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = 2 } end,
  GetSpellBookItemName = function(i) return ({ "Peur", "Corruptio" })[i] end,
}
Enum = { SpellBookSpellBank = { Player = 0 } }
fireEvent("SPELLS_CHANGED")
CURSOR = { "spell", 3, "spell", 172 }
fire(rows[3], "OnReceiveDrag")
local fixChip = byText("Remplacer par « Corruptio »")
assert(fixChip and fixChip:IsShown(), "correction non proposee")
fire(fixChip, "OnClick")
assert(rows[3].full == "/cast Corruptio", rows[3].full)
C_Spell.GetSpellInfo, C_SpellBook = nil, nil
fireEvent("SPELLS_CHANGED")
fire(clear, "OnClick")
assert(not fixChip:IsShown(), "correction restee affichee")
-- modeles du familier sorti : un par technique, pas pour les ordres
GetPetActionInfo = function(i) return ({ "PET_ACTION_ATTACK", nil, nil, "Verrou magique" })[i] end
fire(byText("Modèles"), "OnClick")
fire(byText("Familier : Verrou magique"), "OnClick")
assert(rows[2].full == "/cast [@mouseover,exists,nodead][] Verrou magique", rows[2].full)
assert(#ns.PetTemplates() == 1, "ordre du familier pris pour une technique")
GetPetActionInfo = nil
fire(clear, "OnClick")
fire(byText("Bibliothèque"), "OnClick")

-- 8. parametres : onglet de la fenetre
fire(byText("Paramètres", BlockForgeFrame), "OnClick")
local settingsPanel = find(function(w) return w._template == "UICheckButtonTemplate" and inside(w, BlockForgeFrame) and w ~= perChar and w:IsVisible() end)._parent
assert(settingsPanel:IsVisible(), "onglet Parametres non affiche")
local checks = checkboxes(settingsPanel)
assert(#checks == 11, "cases : " .. #checks) -- les fonctions ont leur propre liste defilante
assert(settingsPanel.featureList and #settingsPanel.featureList.rows == 12)
for _, c in ipairs(checks) do assert(c.label, "case sans libelle") end
local function cb(fragment)
  for _, c in ipairs(checks) do if c.label:find(fragment, 1, true) then return c.box end end
  error("case introuvable : " .. fragment)
end
-- chaque case affiche la valeur sauvegardee
assert(cb("minicarte")._checked == true and cb("personnage")._checked == false)

click(cb("minicarte"), false)
assert(db.minimap.show == false and not BlockForgeMinimapButton:IsShown(), "bouton de minicarte toujours visible")
click(cb("minicarte"), true)
assert(BlockForgeMinimapButton:IsShown())

BlockForgeFrame._point = { "TOPLEFT", UIParent, "TOPLEFT", 50, -60 }
fire(BlockForgeFrame, "OnDragStop")
assert(db.pos and db.pos[1] == "TOPLEFT" and db.pos[3] == 50, "position non memorisee")
click(cb("position"), false)
assert(db.rememberPos == false and db.pos == false and BlockForgeFrame._point[1] == "CENTER", "position non oubliee")
BlockForgeFrame._point = { "TOPLEFT", UIParent, "TOPLEFT", 70, -80 }
fire(BlockForgeFrame, "OnDragStop")
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
local bodyLabel = find(function(w) return w._type == "FontString" and plain(w._text or "") == "/cast " .. C_Spell.GetSpellName(id) end)
assert(bodyLabel, "bibliotheque non traduite")
click(cb("Traduire"), false)
assert(plain(bodyLabel._text) == "/cast " .. spell, "bibliotheque toujours traduite : " .. plain(bodyLabel._text))
fire(byText("Ouvrir dans l'éditeur"), "OnClick")
assert(rows[1].full == "/cast " .. spell, "l'editeur doit recevoir le texte anglais")
click(cb("Traduire"), true)
assert(plain(bodyLabel._text) == "/cast " .. C_Spell.GetSpellName(id))

-- objet hors cache : nom anglais et demande, puis GET_ITEM_INFO_RECEIVED retraduit le detail
local nItems = 0
for _ in pairs(ns.ItemIDs) do nItems = nItems + 1 end
assert(#ITEM_REQUESTS == nItems, "objets demandes : " .. #ITEM_REQUESTS .. " / " .. nItems)
local stone = ns.ItemIDs["Major Soulstone"]
ns.Library[#ns.Library + 1] = { class = "ALL", name = "ZZ Objet", category = "PvE", body = "/use [@player] Major Soulstone" }
fire(byText("Bibliothèque"), "OnClick")
fire(byText("Toutes classes"), "OnClick")
for _ = 1, 30 do fire(listPanel, "OnMouseWheel", -1) end
local itemRow
for _, r in ipairs(libRows) do if r:IsShown() and r.text._text:find("ZZ Objet") then itemRow = r end end
fire(itemRow, "OnClick")
assert(plain(bodyLabel._text) == "/use [@player] Major Soulstone", "objet hors cache : " .. plain(bodyLabel._text))
assert(#ITEM_REQUESTS == nItems, "demande repetee a l'affichage")
ITEM_NAMES[stone] = "Pierre d'âme majeure"
fireEvent("GET_ITEM_INFO_RECEIVED", 999999, true) -- autre objet : rien
assert(plain(bodyLabel._text) == "/use [@player] Major Soulstone")
fireEvent("GET_ITEM_INFO_RECEIVED", stone, true)
assert(plain(bodyLabel._text) == "/use [@player] Pierre d'âme majeure", "objet non retraduit : " .. plain(bodyLabel._text))

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
assert(math.abs(db.scale - 1.5) < 1e-6 and math.abs(BlockForgeFrame._scale - 1.5) < 1e-6, "echelle max : " .. db.scale)
for _ = 1, 30 do fire(sminus, "OnClick") end
assert(math.abs(db.scale - 0.6) < 1e-6, "echelle min : " .. db.scale)
fire(sone, "OnClick")
assert(db.scale == 1)
-- petit ecran : l'echelle appliquee est bornee pour que la fenetre (900 x 640) tienne, le reglage garde sa valeur
UIParent._w, UIParent._h = 1200, 700
for _ = 1, 30 do fire(splus, "OnClick") end
assert(math.abs(db.scale - 1.5) < 1e-6 and math.abs(BlockForgeFrame._scale - 700 / 640) < 1e-6, "echelle bornee : " .. BlockForgeFrame._scale)
fire(sone, "OnClick")
assert(BlockForgeFrame._scale == 1)
UIParent._w, UIParent._h = 0, 0
fire(splus, "OnClick")

-- classe de depart
click(cb("Dernière"), true)
assert(db.libraryClass == "last" and cb("Ma classe")._checked == false, "choix exclusif casse")
click(cb("Ma classe"), true)
assert(db.libraryClass == "player" and cb("Dernière")._checked == false)
click(cb("Dernière"), true)

-- couleur d'accent : appliquee tout de suite au titre, a l'onglet actif, aux bandeaux et aux selections
local function exact(label) for _, c in ipairs(checks) do if c.label == label then return c.box end end error(label) end
local band = find(function(w) return w._type == "Texture" and w._parent == settingsPanel and w._color and w._color[1] == 0.53 end)
assert(band, "bandeau de panneau sans la couleur d'accent")
fire(byText("Paramètres", BlockForgeFrame), "OnClick")
click(exact("Or"), true)
assert(db.accent == "gold" and T.accent[1] == 1 and T.accent[2] == 0.82 and exact("Couleur de ma classe")._checked == false, "accent or")
assert(BlockForgeFrame.TitleText._textColor[2] == 0.82 and band._color[2] == 0.82 and tabEditor.line._color[2] == 0.82, "accent non repeint")
assert(byText("Paramètres", BlockForgeFrame)._border[2] == 0.82 and tabEditor._border[2] ~= 0.82, "onglets non repeints")
fire(byText("Bibliothèque"), "OnClick")
assert(byText("Toutes classes")._border[2] == 0.82 and byText("Démoniste")._border[2] ~= 0.82, "classe choisie non repeinte")
fire(byText("Paramètres", BlockForgeFrame), "OnClick")
click(exact("Couleur de ma classe"), true)
assert(db.accent == "class" and T.accent[1] == 0.53 and BlockForgeFrame.TitleText._textColor[1] == 0.53 and exact("Or")._checked == false)
click(exact("Or"), true)

-- reinitialisation
click(cb("minicarte"), false)
db.minimap.angle = 10
fire(byText("Réinitialiser les paramètres", settingsPanel), "OnClick")
assert(db.scale == 1 and db.minimap.show == true and db.minimap.angle == 225 and db.libraryClass == "player"
  and db.pos == false and db.lastClass == false and db.accent == "class" and T.accent[1] == 0.53, "reinitialisation incomplete")
assert(BlockForgeFrame._scale == 1 and BlockForgeMinimapButton:IsShown())
assert(cb("minicarte")._checked == true and cb("Ma classe")._checked == true, "cases non resynchronisees")
assert(NS.db == BlockForgeDB, "reference de la base perdue")

-- page des options du jeu : meme reglages, synchronisee
local gamePanel
for _, w in ipairs(ALL) do if w.name == "BlockForge" and not w._parent then gamePanel = w end end
assert(gamePanel, "panneau des options du jeu absent")
local gameChecks = checkboxes(gamePanel)
assert(#gameChecks == 11) -- sans la colonne des fonctions
click(gameChecks[1].box, false)
fire(settingsPanel, "OnShow")
assert(cb("minicarte")._checked == false, "les deux pages ne sont pas synchronisees")
click(gameChecks[1].box, true)
gamePanel.OnRefresh(gamePanel)
gamePanel.OnDefault(gamePanel)
assert(db == BlockForgeDB and BlockForgeDB.scale == 1)

-- 9. bouton de minicarte
local mm = BlockForgeMinimapButton
BlockForgeFrame:Hide()
fire(mm, "OnClick", "LeftButton")
assert(BlockForgeFrame:IsShown(), "clic gauche : ouvrir")
fire(mm, "OnClick", "LeftButton")
assert(not BlockForgeFrame:IsShown(), "clic gauche : fermer")
fire(mm, "OnClick", "RightButton")
assert(BlockForgeFrame:IsShown() and settingsPanel:IsVisible(), "clic droit : parametres")
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
BlockForge_OnAddonCompartmentClick("BlockForge", "LeftButton")
BlockForge_OnAddonCompartmentClick("BlockForge", "RightButton")
BlockForge_OnAddonCompartmentEnter("BlockForge", UIParent)
BlockForge_OnAddonCompartmentLeave("BlockForge", UIParent)

-- 11. Mes macros : liste, ouverture, export / import, sauvegardes, raccourcis, refus en combat
MACROS["Soin"] = { index = 2, body = "/cast [@mouseover,help][] Soin", icon = 135907 }
fire(byText("Mes macros"), "OnClick")
local mList = find(function(w) return w.scope end)._parent
local mPage = mList._parent
fire(mPage, "OnShow")
local mRows = {}
for _, c in ipairs(mList._children) do if c.scope then mRows[#mRows + 1] = c end end
assert(#mRows == 20)
local function mRow(name) for _, r in ipairs(mRows) do if r:IsShown() and r.text._text == name then return r end end end
assert(mRow("Sans curseur") and mRow("Soin") and mRow("Test BM"), "macros non listees")
assert(mRow("Test BM").scope._text == "Personnage" and mRow("Soin").scope._text == "Générale", "onglet non indique")
assert(mRow("Soin").icon._tex == 135907)
MACROS["Ajout"] = { index = 3, body = "/sit" }
fireEvent("UPDATE_MACROS")
assert(mRow("Ajout"), "UPDATE_MACROS ignore")
MACROS["Ajout"] = nil
fireEvent("UPDATE_MACROS")
fire(mRow("Soin"), "OnClick")
local soinBody = MACROS["Soin"].body
assert(find(function(w) return w._type == "FontString" and plain(w._text or "") == soinBody and inside(w, mPage) end), "corps non affiche")
fire(byText("Ouvrir dans l'éditeur", mPage), "OnClick")
assert(rows[1]:IsVisible() and rows[1].full == soinBody and nameBox._text == "Soin", "macro non ouverte dans l'editeur")

-- simulateur : l'apercu change selon l'etat, et redevient normal une fois coupe
local previewLabel = find(function(w) return w._type == "FontString" and plain(w._text or "") == soinBody and not inside(w, mPage) end)
assert(previewLabel, "apercu introuvable")
local simToggle = byText("Simuler")
local survol = byText("Survol : —")
assert(not survol:IsShown(), "etats visibles sans simulation")
fire(simToggle, "OnClick")
assert(survol:IsShown() and previewLabel._text:find("-> @target", 1, true), previewLabel._text)
fire(survol, "OnClick") -- hostile : [@mouseover,help] echoue, [] part sur la cible
assert(survol.text._text == "Survol : Hostile" and previewLabel._text:find("-> @target", 1, true))
fire(survol, "OnClick") -- amie
assert(previewLabel._text:find("-> @mouseover", 1, true), previewLabel._text)
fire(simToggle, "OnClick")
assert(plain(previewLabel._text) == soinBody and previewLabel._text ~= soinBody and not survol:IsShown(), "apercu toujours simule")

-- export puis import : ouvert dans l'editeur, rien d'enregistre
fire(byText("Mes macros"), "OnClick")
local share, setBox = edits[8], edits[9]
fire(byText("Exporter", mPage), "OnClick")
assert(share._text == ns.Export("Soin", soinBody) and FOCUS == share, "export : " .. share._text)
share._text = share._text:gsub("^BF1:Soin:", "BF1:Soin2:")
local callsBefore = #CALLS
fire(byText("Importer", mPage), "OnClick")
assert(nameBox._text == "Soin2" and rows[1].full == soinBody and rows[1]:IsVisible(), "import non ouvert")
assert(#CALLS == callsBefore, "l'import ne doit rien enregistrer")
fire(byText("Mes macros"), "OnClick")
share._text = "n'importe quoi"
fire(byText("Importer", mPage), "OnClick")
assert(lastLine():find("BF1:", 1, true), lastLine())

-- sauvegarde (un profil, macros seules) puis restauration par l'apercu du profil : mise a jour + creation + manque de place
COMBAT = true
fire(byText("Sauvegarder mes macros"), "OnClick")
assert(lastLine():find("combat") and next(db.profiles) == nil, "sauvegarde en combat")
COMBAT = false
fire(byText("Sauvegarder mes macros"), "OnClick")
local set = db.profiles["2026-11-20"]
assert(set and #set.macros == 3 and set.bindings == nil and set.bars == nil and set.owner == "Moi-Royaume" and set.class == "WARLOCK", "sauvegarde absente")
assert(set.macros[1].index == nil and next(db.sets) == nil, "le profil ne garde que nom, icone, texte et onglet")
setBox._text = "2026-11-20"
fire(byText("Sauvegarder mes macros"), "OnClick")
local replacePop = POPUPS[#POPUPS]
assert(replacePop.which == "BLOCKFORGE_REPLACE_SET" and replacePop.text:find("2026-11-20", 1, true) and not lastLine():find("remplac"), "confirmation attendue avant de remplacer")
StaticPopupDialogs.BLOCKFORGE_REPLACE_SET.OnAccept({}, replacePop.data)
assert(lastLine():find("remplac"), lastLine())
set = db.profiles["2026-11-20"]
set.macros[#set.macros + 1] = { name = "Trop", body = "/sit", char = true }
MACROS["Soin"].body = "/cast Autre"
MACROS["Sans curseur"] = nil       -- supprimee en jeu : les index suivants glissent
MACROS["Soin"].index = 1
for i = 2, 30 do MACROS["Perso" .. i] = { index = 120 + i, body = "/sit", char = true } end -- onglet personnage plein
local restoreBtn = byText("Restaurer")
COMBAT = true
fire(restoreBtn, "OnClick")
assert(lastLine():find("combat") and ns.profilesPanel == nil, "apercu du profil en combat")
COMBAT = false
local popupsBefore2 = #POPUPS
fire(restoreBtn, "OnClick")
local pp = ns.profilesPanel
assert(#POPUPS == popupsBefore2 and pp and pp:IsShown() and pp.state.chosen == "2026-11-20" and pp._w == 884 and pp._h == 566, "apercu du profil attendu")
assert(pp.activate._text == "Activer (3)" and pp.summary._text:find("À créer : 2 · à réécrire : 1 · laissées : 0 · déjà identiques : 1", 1, true), pp.summary._text)
-- pas assez de place : rien n'est touche, le manque est chiffre
local callsBefore2 = #CALLS
fire(pp.activate, "OnClick")
assert(lastLine():find("il manque 0 place(s) dans les macros générales et 1 dans celles du personnage. Rien n'a été changé", 1, true), lastLine())
assert(#CALLS == callsBefore2 and MACROS["Soin"].body == "/cast Autre" and ns.UndoLabel() == nil and db.profiles["2026-11-20"] and not next(db.profiles, "2026-11-20"), "profil applique a moitie")
set.macros[#set.macros] = nil
ns.Profiles.Render()
COMBAT = true
fire(pp.activate, "OnClick") -- combat commence pendant l'apercu
assert(MACROS["Soin"].body == "/cast Autre" and lastLine():find("combat"), "activation en combat")
COMBAT = false
fire(pp.activate, "OnClick")
assert(MACROS["Soin"].body == soinBody and MACROS["Test BM"] and MACROS["Sans curseur"], "restauration incomplete")
assert(MACROS["Sans curseur"].index == 2 and not MACROS["Trop"], "creation ou place")
assert(PRINTS[#PRINTS - 1]:find("1 macro(s) créée(s), 1 mise(s) à jour, 0 archivée(s) puis retirée(s), 0 touche(s), 0 emplacement(s) ; 0 étape(s) refusée(s)", 1, true), PRINTS[#PRINTS - 1])
assert(lastLine():find("Sauvegarde automatique « Auto 2026-11-20 12:00:00 profil »", 1, true) and ns.UndoLabel() == "profil « 2026-11-20 »", lastLine())
local auto = db.profiles["Auto 2026-11-20 12:00:00 profil"]
assert(auto and auto.auto == true and #auto.macros == 31, "sauvegarde automatique absente")
assert(MACROS["Perso2"].body == "/sit", "macro absente de la sauvegarde modifiee")
db.undo = false
pp:Hide()
for i = 2, 30 do MACROS["Perso" .. i] = nil end
fireEvent("UPDATE_MACROS")
-- les sauvegardes survivent a la reinitialisation, la suppression demande confirmation
ns.ResetDB()
assert(db.profiles["2026-11-20"] and db.profiles["Auto 2026-11-20 12:00:00 profil"], "sauvegarde perdue a la reinitialisation")
fire(byText("Supprimer", mPage), "OnClick")
assert(POPUPS[#POPUPS].which == "BLOCKFORGE_DELETE_SET")
StaticPopupDialogs.BLOCKFORGE_DELETE_SET.OnAccept({}, POPUPS[#POPUPS].data)
assert(db.profiles["2026-11-20"] == nil and db.profiles["Auto 2026-11-20 12:00:00 profil"], "sauvegarde non supprimee")

-- raccourci : sans conflit, avec conflit, Echap, combat
fire(mRow("Soin"), "OnClick")
local bindBtn = byText("Raccourci…", mPage)
fire(bindBtn, "OnClick")
assert(bindBtn._scripts.OnKeyDown, "capture non demarree")
fire(bindBtn, "OnKeyDown", "LSHIFT") -- modificateur seul : on attend la touche
assert(bindBtn._scripts.OnKeyDown)
CHORD = "CTRL-"
fire(bindBtn, "OnKeyDown", "F")
CHORD = ""
assert(BINDINGS["CTRL-F"] == "MACRO Soin" and SAVED_BINDINGS == 2 and not bindBtn._scripts.OnKeyDown, "raccourci non pose")
assert(find(function(w) return w._type == "FontString" and w._text and w._text:find("Raccourci : CTRL-F", 1, true) end), "touche actuelle non affichee")
BINDINGS.G = "TOGGLEWORLDMAP"
fire(bindBtn, "OnClick")
fire(bindBtn, "OnKeyDown", "G")
pop = POPUPS[#POPUPS]
assert(BINDINGS.G == "TOGGLEWORLDMAP" and pop.which == "BLOCKFORGE_BIND" and pop.text:find("Nom de TOGGLEWORLDMAP", 1, true), "conflit non signale")
StaticPopupDialogs.BLOCKFORGE_BIND.OnAccept({}, pop.data)
assert(BINDINGS.G == "MACRO Soin")
fire(bindBtn, "OnClick")
fire(bindBtn, "OnKeyDown", "ESCAPE")
assert(not bindBtn._scripts.OnKeyDown and bindBtn._text == "Raccourci…", "Echap n'annule pas")
fire(bindBtn, "OnClick")
fireEvent("PLAYER_REGEN_DISABLED")
assert(not bindBtn._scripts.OnKeyDown, "capture gardee en combat")
COMBAT = true
fire(bindBtn, "OnClick")
assert(not bindBtn._scripts.OnKeyDown and lastLine():find("combat"), "capture en combat")
StaticPopupDialogs.BLOCKFORGE_BIND.OnAccept({}, { key = "H", name = "Soin" })
assert(BINDINGS.H == nil and lastLine():find("combat"), "raccourci pose en combat")
COMBAT = false

-- 12. journal d'erreurs : seules celles qui citent l'add-on, le gestionnaire precedent recoit tout, tel quel
local handler = geterrorhandler()
HANDLED = {}
handler("Interface/AddOns/BlockForge/UI.lua:12: boom", "extra")
handler("Interface/AddOns/Autre/Autre.lua:1: pas nous")
assert(#HANDLED == 2 and HANDLED[1] == "Interface/AddOns/BlockForge/UI.lua:12: boom" and HANDLED[2]:find("pas nous"), "gestionnaire precedent non appele")
local e = db.errors[1]
assert(#db.errors == 1 and e.message == HANDLED[1] and e.version == "0.6.2" and e.time == "2026-11-20 12:00:00" and #e.stack == 1500, "erreur mal enregistree")
for i = 1, 25 do handler("BlockForge erreur " .. i) end
assert(#db.errors == 20 and db.errors[1].message == "BlockForge erreur 6" and db.errors[20].message == "BlockForge erreur 25", "plafond de 20")
db.errors = 5 -- erreur dans le journal lui-meme : avalee, l'erreur du jeu passe quand meme
handler("BlockForge encore")
assert(HANDLED[#HANDLED] == "BlockForge encore" and #HANDLED == 28)
db.errors = {}

-- 13. /bf test : refuse en combat, rapport enregistre, aucune macro ni raccourci touche
GetLocale = function() return "frFR" end
COMBAT = true
SlashCmdList.BLOCKFORGE("test")
assert(lastLine():find("combat") and next(db.selftest) == nil, "autotest en combat")
COMBAT = false
local callsBeforeTest, bindingsBefore = #CALLS, BINDINGS.G
SlashCmdList.BLOCKFORGE("test")
local report = db.selftest
assert(report.time == "2026-11-20 12:00:00" and report.version == "0.6.2" and report.build == "1.60.1 70959 16001"
  and report.locale == "frFR" and report.class == "WARLOCK", "en-tete du rapport")
local byStart, text = {}, table.concat(report.lines, "\n")
for _, line in ipairs(report.lines) do
  assert(type(line) == "string", "ligne non texte")
  local kind = line:match("^(%u+) ")
  assert(kind == "OK" or kind == "FAIL" or kind == "INFO", line)
  byStart[kind] = (byStart[kind] or 0) + 1
end
assert(text:find("OK api C_Spell.GetSpellName", 1, true) and text:find("FAIL api absent: C_Spell.GetSpellInfo", 1, true), text)
assert(text:find("OK round trip Parse/Compile: 0 / ", 1, true) and text:find("OK spell ids without name: 0 / ", 1, true), text)
assert(text:find("INFO items not cached yet:", 1, true) and text:find("INFO class WARLOCK:", 1, true) and text:find("INFO macros: ", 1, true), text)
for _, tab in ipairs({ "editor", "library", "macros", "settings" }) do assert(text:find("OK tab " .. tab, 1, true), tab) end
assert(text:find("INFO optional api present: RAID_CLASS_COLORS", 1, true) and text:find("INFO optional api absent: GetMacroIcons", 1, true), text)
assert(text:find("INFO look: accent class = 0.53 0.53 0.93, opening fade on, icon choices ", 1, true), text)
assert(lastLine():find(("%d OK, %d en échec"):format(byStart.OK, byStart.FAIL or 0), 1, true), lastLine())
assert(#CALLS == callsBeforeTest and BINDINGS.G == bindingsBefore, "l'autotest a touche aux macros")
GetLocale = nil
-- diagnostics effaces par la reinitialisation, favoris et sauvegardes gardes
handler("BlockForge avant reinitialisation")
ns.ResetDB()
assert(next(db.errors) == nil and next(db.selftest) == nil, "diagnostics gardes a la reinitialisation")

-- 10. toutes les infobulles, commandes, fermeture / reouverture
for _, w in ipairs(ALL) do
  if w._scripts.OnEnter then w._scripts.OnEnter(w) end
  if w._scripts.OnLeave then w._scripts.OnLeave(w) end
end
SlashCmdList.BLOCKFORGE("options")
assert(BlockForgeFrame:IsShown() and settingsPanel:IsVisible())
SlashCmdList.BLOCKFORGE("")
assert(not BlockForgeFrame:IsShown())
SlashCmdList.BLOCKFORGE("")
assert(BlockForgeFrame:IsShown())
__testWrite(#ALL .. " widgets, " .. #CALLS .. " appels macro, " .. #PRINTS .. " messages\n")
for _, p in ipairs(PRINTS) do __testWrite("  > ", p, "\n") end
`, "=scenario");

// ---------------------------------------------------------------- 2. BlockForgeDB partielle (ancienne version)
boot(`{ scale = "grand", minimap = { angle = 400 }, pos = { "TOPLEFT", "TOPLEFT", 10, -20 },
        libraryClass = "last", lastClass = "MAGE", perCharDefault = true, confirmOverwrite = false }`);
run(String.raw`
local db = BlockForgeDB
assert(db.scale == 1, "echelle invalide gardee")
assert(db.minimap.show == true and db.minimap.angle == 40, "minicarte mal completee")
assert(db.pos[3] == 10 and db.libraryClass == "last" and db.lastClass == "MAGE")
assert(db.confirmOverwrite == false and db.pickupAfterCreate == true and db.localizeLibrary == true)
-- /bf test avant toute ouverture : la fenetre est construite cachee ; un onglet en erreur n'empeche pas les autres
GetLocale = function() return "frFR" end
local getNum = GetNumMacros
GetNumMacros = function() error("panne de macros") end
SlashCmdList.BLOCKFORGE("test")
GetNumMacros, GetLocale = getNum, nil
local text = table.concat(db.selftest.lines, "\n")
assert(text:find("FAIL tab macros: [^\n]*panne de macros") and text:find("OK tab library", 1, true) and text:find("FAIL macros: ", 1, true), text)
assert(HANDLED[#HANDLED]:find("panne de macros"), "erreur d'onglet non transmise au jeu")
assert(not BlockForgeFrame:IsShown(), "l'autotest ne doit pas ouvrir la fenetre")
SlashCmdList.BLOCKFORGE("")
local p = BlockForgeFrame._point
assert(p[1] == "TOPLEFT" and p[2] == UIParent and p[4] == 10 and p[5] == -20, "position non restauree")
local perChar = find(function(w) return w._template == "UICheckButtonTemplate" and inside(w, BlockForgeFrame) end)
assert(perChar._checked == true, "case du personnage non cochee au chargement")
fire(byText("Bibliothèque"), "OnClick")
-- la bibliotheque s'ouvre sur la derniere classe (Mage) : sa puce est dans l'etat choisi
local listPanel = libraryList()
local first
for _, c in ipairs(listPanel._children) do if c.mark and c:IsShown() then first = c break end end
local mage
for _, e in ipairs(NS.Library) do if e.class == "MAGE" then mage = e break end end
assert(first and first.text._text:find(mage.name, 1, true), "bibliotheque non ouverte sur la derniere classe")
`, "=partiel");

// ---------------------------------------------------------------- 3. BlockForgeDB corrompue
boot(`{ minimap = "oui", pos = 5, lastClass = 12, libraryClass = "autre", scale = 9, helpTooltips = "non", accent = 7 }`);
run(String.raw`
local db = BlockForgeDB
assert(type(db.minimap) == "table" and db.minimap.show == true and db.minimap.angle == 225)
assert(db.pos == false and db.lastClass == false and db.libraryClass == "player")
assert(db.scale == 1.5 and db.helpTooltips == true and db.accent == "class", "valeurs corrompues gardees")
SlashCmdList.BLOCKFORGE("")
assert(BlockForgeFrame._point[1] == "CENTER")
fire(BlockForgeMinimapButton, "OnClick", "RightButton")
`, "=corrompu");

// ---------------------------------------------------------------- 4. sans API Settings (Classic Era) ni Minimap
L = null;
L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
require(__dirname + "/lua51")(L);
run(MOCK, "=mock");
run(`Settings = nil  Minimap = nil  CATEGORIES = {}  C_Item = {}  RAID_CLASS_COLORS = nil  WIDGET.CreateAnimationGroup = nil
     function InterfaceOptions_AddCategory(p) assert(p.name == "BlockForge") CATEGORIES[#CATEGORIES + 1] = p end
     BlockForgeDB = nil`, "=classic");
for (const f of tocFiles) loadAddonFile(f);
run(`fireEvent("ADDON_LOADED", "BlockForge")
     assert(#CATEGORIES == 1, "repli InterfaceOptions_AddCategory absent")
     SlashCmdList.BLOCKFORGE("options")
     -- sans couleurs de classe ni animations : accent or, pas de fondu, aucune erreur
     assert(NS.db.accent == "class" and NS.Theme.accent[2] == 0.82 and NS.fade == nil, "replis du theme")`, "=classic2");

// ---------------------------------------------------------------- 5. client anglais : textes et descEN
boot("{ features = { welcome = false } }", `function GetLocale() return "enUS" end`);
run(String.raw`
SlashCmdList.BLOCKFORGE("")
assert(BlockForgeFrame.TitleText._text == "BlockForge — block-based macro editor")
-- visite guidee en anglais : lancee a la premiere ouverture, aucun texte reste en francais
local coach = NS.Tutorial.coach
assert(NS.Tutorial.step == 1 and coach.title._text == "The home tab" and coach.next._text == "Next" and coach.skip._text == "Skip", coach.title._text)
for _, s in ipairs(NS.TutorialSteps) do
  for _, c in ipairs({ "é", "è", "ê", "à", "ù", "ç", "«", "»", " :", " ;", " ?" }) do
    assert(not (s.title .. (type(s.text) == "function" and s.text() or s.text)):find(c, 1, true), "etape en francais : " .. s.title)
  end
end
fire(coach.skip, "OnClick")
assert(byText("Undo") and byText("Redo") and byText("Edit text") and byText("More...") and byText("Add to my library") and byText("My templates") and byText("Send to..."))
fire(byText("Create / update"), "OnClick")
assert(lastLine():find("Give the macro a name"), lastLine())
local descs = {}
for _, e in ipairs(NS.Library) do e.descEN = e.descEN or ("EN " .. e.name) descs[e.descEN] = true end
fire(byText("Library"), "OnClick")
fire(byText("All classes"), "OnClick")
local listPanel = libraryList()
for _, c in ipairs(listPanel._children) do if c.mark and c:IsShown() then fire(c, "OnClick") break end end
assert(find(function(w) return w._type == "FontString" and descs[w._text] end), "descEN non affichee")
fire(byText("Settings", BlockForgeFrame), "OnClick")
for _, w in ipairs(ALL) do
  if w._scripts.OnEnter then w._scripts.OnEnter(w) end
end
`, "=anglais");

// ---------------------------------------------------------------- 6. cycle 3, lot 2 : tutoriel, annuler / retablir, texte libre, modeles, envoi
boot("nil");
run(String.raw`
local ns, db = NS, BlockForgeDB
local function said(fragment) return lastLine():find(fragment, 1, true) ~= nil end
local function accept(kind) -- repond au dernier dialogue : "OnAccept", "OnAlt" ou "OnCancel"
  local p = POPUPS[#POPUPS]
  StaticPopupDialogs[p.which][kind or "OnAccept"]({}, p.data)
end

-- A. tutoriel seul : sans presentation, premiere ouverture hors combat
ns.SetFeature("welcome", false)
assert(db.tutorialSeen == false and db.acceptShared == true and type(db.personal) == "table")
COMBAT = true
SlashCmdList.BLOCKFORGE("")
assert(BlockForgeFrame:IsShown() and db.tutorialSeen == false and ns.Tutorial.step == nil, "visite lancee en combat")
SlashCmdList.BLOCKFORGE("tuto")
assert(said("combat") and ns.Tutorial.step == nil)
COMBAT = false
SlashCmdList.BLOCKFORGE("") -- ferme
SlashCmdList.BLOCKFORGE("") -- rouvre : premiere ouverture hors combat
local tour, steps = ns.Tutorial, ns.TutorialSteps
local coach = tour.coach
assert(db.tutorialSeen == true and tour.step == 1 and coach and coach:IsShown() and tour.frame:IsShown(), "visite non lancee")
assert(#steps >= 8 and #steps <= 12, #steps)
assert(coach._parent == BlockForgeFrame and coach._w == 320 and coach._h == 140)
local tabs = { home = byText("Accueil"), editor = byText("Éditeur"), library = byText("Bibliothèque"), macros = byText("Mes macros", BlockForgeFrame), settings = byText("Paramètres", BlockForgeFrame) }
local seenTabs = {}
for i, s in ipairs(steps) do
  assert(tour.step == i, "etape " .. i)
  -- chaque etape : onglet affiche, widget existant et visible dans la fenetre, panneau et cadre poses dessus, textes non vides
  local anchor = s.anchor()
  assert(getmetatable(anchor) == WIDGET and inside(anchor, BlockForgeFrame), "repere de l'etape " .. i)
  assert(tabs[s.tab].line:IsShown() and anchor:IsVisible(), "onglet de l'etape " .. i)
  assert(coach._point[2] == anchor and tour.frame._point[2] == anchor, "panneau non pose sur le repere " .. i)
  local text = type(s.text) == "function" and s.text() or s.text -- etape des kits, profils et macros vivantes : texte selon les fonctions actives
  assert(coach.title._text == s.title and coach.text._text == text and #s.title > 3 and #text > 40 and #text < 330, "texte de l'etape " .. i)
  assert(coach.count._text == i .. " / " .. #steps, coach.count._text)
  assert(coach.prev._enabled == (i > 1), "bouton precedent a l'etape " .. i)
  assert(coach.next._text == (i == #steps and "Terminer" or "Suivant"))
  seenTabs[s.tab] = true
  if i < #steps then fire(coach.next, "OnClick") end
end
assert(seenTabs.editor and seenTabs.library and seenTabs.macros and seenTabs.settings, "un onglet n'est pas visite")
fire(coach.prev, "OnClick")
assert(tour.step == #steps - 1 and tabs[steps[#steps - 1].tab].line:IsShown(), "retour en arriere")
fire(coach.next, "OnClick")
fire(coach.next, "OnClick") -- « Terminer »
assert(tour.step == nil and not coach:IsShown() and not tour.frame:IsShown(), "fin de visite")
-- une seule fois toute seule ; /bf tuto, /bf tutorial et /bf help la relancent
SlashCmdList.BLOCKFORGE("")
SlashCmdList.BLOCKFORGE("")
assert(BlockForgeFrame:IsShown() and tour.step == nil, "visite relancee a la 2e ouverture")
for _, cmd in ipairs({ "tuto", "tutorial", "help", " TUTO " }) do
  SlashCmdList.BLOCKFORGE(cmd)
  assert(tour.step == 1 and coach:IsShown() and tabs.home.line:IsShown(), cmd)
  fire(coach.skip, "OnClick") -- « Passer »
  assert(tour.step == nil and not coach:IsShown(), "passer")
end
-- elle ne bloque rien : changer d'onglet a la main, fermer la fenetre ou entrer en combat l'arrete proprement
SlashCmdList.BLOCKFORGE("tuto")
fire(tabs.library, "OnClick")
assert(tour.step == nil and tabs.library.line:IsShown(), "changement d'onglet pendant la visite")
SlashCmdList.BLOCKFORGE("tuto")
fire(BlockForgeFrame, "OnHide") -- fermeture, Echap compris
assert(tour.step == nil and not coach:IsShown())
SlashCmdList.BLOCKFORGE("tuto")
fireEvent("PLAYER_REGEN_DISABLED")
assert(tour.step == nil and not coach:IsShown(), "visite encore la en combat")
-- bouton des parametres
fire(tabs.settings, "OnClick")
fire(byText("Revoir le tutoriel", BlockForgeFrame), "OnClick")
assert(tour.step == 1 and tabs.home.line:IsShown())
fire(coach.skip, "OnClick")

-- reperes de l'editeur
local w = ns.ed.w
local palette = {}
for _, def in ipairs(ns.BlockDefs) do palette[def.id] = byText(def.label, w.palette) end
local rows = {}
for _, c in ipairs(w.canvas._children) do if c.pills then rows[#rows + 1] = c end end
local function rowButton(row, text)
  for _, c in ipairs(row._children) do if c._type == "Button" and c._text == text then return c end end
end
local edits = {}
for _, e in ipairs(ALL) do if e._type == "EditBox" then edits[#edits + 1] = e end end
local argBox, nameBox, textBox, modelShare, search = edits[1], edits[4], edits[5], edits[6], edits[7]
assert(textBox == w.textBox, "champ du texte libre")
local undo, redo, clear = byText("Annuler", w.canvas), byText("Rétablir", w.canvas), byText("Tout effacer")
local function text() return ns.Compile(ns.ed.Blocks()) end
local function typeArg(s) -- frappe lettre par lettre
  FOCUS = argBox
  for i = 1, #s do argBox._text = s:sub(1, i) fire(argBox, "OnTextChanged", true) end
end
local function blur(box) FOCUS = nil fire(box, "OnEditFocusLost") end

-- B. annuler / retablir
assert(text() == "" and undo._enabled == false and redo._enabled == false, "historique non vide au depart")
fire(palette.cast, "OnClick")
typeArg("Fear")
blur(argBox)
fire(palette.use, "OnClick")
typeArg("13")
blur(argBox)
assert(text() == "/cast Fear\n/use 13" and undo._enabled == true and redo._enabled == false)
fire(undo, "OnClick")
assert(text() == "/cast Fear\n/use" and redo._enabled == true, "la frappe doit faire une seule etape : " .. text())
fire(undo, "OnClick")
assert(text() == "/cast Fear")
fire(undo, "OnClick")
assert(text() == "/cast", text())
fire(undo, "OnClick")
assert(text() == "" and undo._enabled == false)
fire(undo, "OnClick") -- plus rien : sans effet
for _ = 1, 4 do fire(redo, "OnClick") end
assert(text() == "/cast Fear\n/use 13" and redo._enabled == false)
fire(redo, "OnClick")
assert(text() == "/cast Fear\n/use 13")
-- conditions, alternative, suppression, dupliquer, deplacement, modele, chargement, tout effacer : chacun s'annule
fire(rows[1], "OnClick")
fire(byText("Survol", w.insp), "OnClick")
assert(text() == "/cast [@mouseover] Fear\n/use 13")
fire(undo, "OnClick")
assert(text() == "/cast Fear\n/use 13", "condition non annulee")
fire(rowButton(rows[1], "x"), "OnClick")
assert(text() == "/use 13")
fire(undo, "OnClick")
assert(text() == "/cast Fear\n/use 13", "suppression non annulee")
-- C. dupliquer : copie juste en dessous, independante de l'original
fire(rowButton(rows[1], "x2"), "OnClick")
assert(text() == "/cast Fear\n/cast Fear\n/use 13", text())
assert(argBox._text == "Fear", "la copie doit etre choisie")
typeArg("Peur")
blur(argBox)
assert(text() == "/cast Fear\n/cast Peur\n/use 13", "la copie partage son argument avec l'original")
fire(undo, "OnClick")
fire(undo, "OnClick")
assert(text() == "/cast Fear\n/use 13", "duplication non annulee")
-- frappe puis clic sur un autre bouton sans quitter le champ : deux etapes distinctes
fire(rows[1], "OnClick")
typeArg("Feara")
fire(byText("Hostile", w.insp), "OnClick")
assert(text() == "/cast [harm] Feara\n/use 13")
fire(undo, "OnClick")
assert(text() == "/cast Feara\n/use 13", "le clic a ete fondu dans la frappe")
blur(argBox)
fire(undo, "OnClick")
assert(text() == "/cast Fear\n/use 13")
local popups = #POPUPS
fire(byText(ns.Templates[3].label), "OnClick")
assert(#POPUPS == popups + 1)
accept()
assert(text() == ns.Templates[3].body)
fire(undo, "OnClick")
assert(text() == "/cast Fear\n/use 13", "modele non annule")
fire(clear, "OnClick")
assert(text() == "")
fire(undo, "OnClick")
assert(text() == "/cast Fear\n/use 13", "« Tout effacer » non annule")
MACROS["Jeu"] = { index = 3, body = "/cast A\n/cast B" }
nameBox._text = "Jeu"
fire(byText("Charger ce nom"), "OnClick")
assert(text() == "/cast A\n/cast B")
fire(undo, "OnClick")
assert(text() == "/cast Fear\n/use 13", "chargement non annule")
-- Ctrl+Z / Ctrl+Y : seulement avec Ctrl, jamais pendant la frappe dans un champ, et la touche reste transmise au jeu
assert(ns.ed.keys == nil, "clavier arme en combat") -- la fenetre a ete construite en combat (debut du scenario)
fireEvent("PLAYER_REGEN_ENABLED")
local keys = ns.ed.keys
assert(keys and keys._scripts.OnKeyDown, "clavier non arme a la fin du combat")
fire(keys, "OnKeyDown", "Z") -- sans Ctrl : rien
assert(text() == "/cast Fear\n/use 13")
CTRL = true
fire(keys, "OnKeyDown", "Z")
assert(text() == "/cast Fear\n/use", text())
fire(keys, "OnKeyDown", "Y")
assert(text() == "/cast Fear\n/use 13")
GetCurrentKeyBoardFocus = function() return argBox end
fire(keys, "OnKeyDown", "Z")
assert(text() == "/cast Fear\n/use 13", "Ctrl+Z pris pendant une saisie")
GetCurrentKeyBoardFocus = nil
CTRL = false
-- historique borne a 50 etats
for i = 1, 60 do fire(palette.stopcasting, "OnClick") end
assert(#ns.ed.history.states == 50, #ns.ed.history.states)
fire(clear, "OnClick")

-- D. texte libre : bascule, frappe relue apres une pause, ligne inconnue gardee, compteur vivant
local toggle = byText("Éditer le texte")
local scroll, preview = textBox._parent, w.preview
local counter = find(function(x) return x._type == "FontString" and x._parent == w.bottom and (x._text or ""):find("^%d+ / 255$") end)
assert(counter and counter._text == "0 / 255" and not scroll:IsShown() and preview:IsShown())
fire(palette.cast, "OnClick")
typeArg("Fear")
blur(argBox)
fire(toggle, "OnClick")
assert(scroll:IsShown() and not preview:IsShown() and textBox._text == "/cast Fear", "texte libre non affiche")
fire(palette.stopcasting, "OnClick") -- les blocs changent : le champ suit tant qu'il n'a pas le focus
assert(textBox._text == "/cast Fear\n/stopcasting")
FOCUS = textBox
MOUSE_OVER = true -- la souris reste sur le champ pendant la frappe
local typed = "#showtooltip\n/cast [@mouseover,harm][] Fear\n\n/commande inconnue [x] y\n  du texte libre  "
for _, s in ipairs({ typed:sub(1, 20), typed:sub(1, 50), typed }) do
  textBox._text = s
  fire(textBox, "OnTextChanged", true)
end
assert(counter._text == #ns.trim(typed) .. " / 255", "compteur pendant la frappe : " .. counter._text)
assert(text() == "/cast Fear\n/stopcasting", "relu a chaque touche")
fire(textBox, "OnUpdate", 0.5)
assert(text() == "/cast Fear\n/stopcasting", "relu avant la pause")
fire(textBox, "OnUpdate", 0.5)
local clean = "#showtooltip\n/cast [@mouseover,harm][] Fear\n/commande inconnue [x] y\ndu texte libre"
assert(text() == clean, text())
local blocks = ns.ed.Blocks()
assert(#blocks == 4 and blocks[2].type == "cast" and blocks[3].type == "raw" and blocks[4].type == "raw")
assert(textBox._text == typed, "le champ ne doit pas etre reecrit pendant la frappe")
assert(rows[2].full == "/cast [@mouseover,harm][] Fear" and rows[4]:IsShown(), "les blocs ne suivent pas le texte")
assert(counter._text == #clean .. " / 255")
textBox._text = typed .. "\n/use 13"
fire(textBox, "OnTextChanged", true)
blur(textBox) -- perte du focus : relu tout de suite, texte remis au propre
assert(text() == clean .. "\n/use 13" and textBox._text == clean .. "\n/use 13", textBox._text)
fire(undo, "OnClick") -- toute la frappe (deux relectures) ne fait qu'une etape
assert(text() == "/cast Fear\n/stopcasting" and textBox._text == "/cast Fear\n/stopcasting", "annulation du texte libre : " .. text())
fire(redo, "OnClick")
assert(text() == clean .. "\n/use 13")
-- trop long : le compteur passe au rouge, rien n'est perdu
FOCUS = textBox
textBox._text = string.rep("/cast Sort tres long\n", 15)
fire(textBox, "OnTextChanged", true)
assert(counter._text == "314 / 255" and counter._textColor[1] == 1 and counter._textColor[2] == 0.25, counter._text)
-- annuler pendant la frappe : le texte en cours est d'abord pris en compte, puis annule
fire(undo, "OnClick")
assert(text() == clean .. "\n/use 13", text())
-- la souris quitte le champ (pour aller cliquer) : relu tout de suite ; le bloc clique ensuite n'est pas ecrase
-- par le texte du champ, qui a garde le focus, et le champ affiche le nouveau bloc
textBox._text = "/cast A"
fire(textBox, "OnTextChanged", true)
MOUSE_OVER = false
fire(textBox, "OnUpdate", 0.01)
assert(text() == "/cast A", "texte non relu quand la souris quitte le champ")
fire(palette.stopcasting, "OnClick")
assert(text() == "/cast A\n/stopcasting" and textBox._text == "/cast A\n/stopcasting", "champ non mis a jour apres un clic : " .. textBox._text)
fire(textBox, "OnUpdate", 2)
assert(text() == "/cast A\n/stopcasting", "bloc clique ecrase par l'ancien texte du champ")
FOCUS = nil
fire(toggle, "OnClick")
assert(not scroll:IsShown() and preview:IsShown())
fire(textBox, "OnCursorChanged", 0, -120, 2, 13) -- suivi du curseur et molette : sans erreur avec un cadre sans defilement
fire(scroll, "OnMouseWheel", -1)
fire(scroll, "OnMouseDown")
FOCUS = nil
fire(clear, "OnClick")

-- E. bibliotheque personnelle : rien dans les macros du jeu, tout dans BlockForgeDB.personal
local callsBefore = #CALLS
local more = byText("Plus…")
local addModel = byText("Ajouter à ma bibliothèque")
local menu = addModel._parent
assert(not menu:IsShown())
fire(more, "OnClick")
assert(menu:IsShown())
nameBox._text = ""
fire(addModel, "OnClick")
assert(not menu:IsShown() and said("nom") and #db.personal == 0, "modele sans nom accepte")
nameBox._text = "Mon |modele"
fire(addModel, "OnClick")
assert(said("vide") and #db.personal == 0, "modele vide accepte")
fire(palette.cast, "OnClick")
typeArg("Corruption")
blur(argBox)
COMBAT = true
fire(addModel, "OnClick")
assert(said("combat") and #db.personal == 0, "modele ajoute en combat")
COMBAT = false
fire(addModel, "OnClick")
assert(#db.personal == 1 and db.personal[1].name == "Mon modele" and db.personal[1].body == "/cast Corruption" and db.personal[1].icon == nil, "modele non range")
assert(said("Mes modèles"))
local popups2 = #POPUPS
fire(addModel, "OnClick") -- meme nom : confirmation avant de remplacer
assert(#POPUPS == popups2 + 1 and POPUPS[#POPUPS].which == "BLOCKFORGE_REPLACE_PERSONAL" and #db.personal == 1)
typeArg("Peur")
blur(argBox)
fire(addModel, "OnClick")
assert(db.personal[1].body == "/cast Corruption", "remplace sans confirmation")
accept()
assert(#db.personal == 1 and db.personal[1].body == "/cast Peur")
nameBox._text = "Second"
typeArg("Corruption")
blur(argBox)
fire(addModel, "OnClick")
assert(#db.personal == 2 and db.personal[2].body == "/cast Corruption")
-- onglet Bibliotheque, « Mes modeles »
fire(tabs.library, "OnClick")
local listPanel = w.libraryList
local libRows = {}
for _, c in ipairs(listPanel._children) do if c.mark then libRows[#libRows + 1] = c end end
local function shownNames()
  local list = {}
  for _, r in ipairs(libRows) do if r:IsShown() then list[#list + 1] = r.text._text end end
  return table.concat(list, ",")
end
local mine = byText("Mes modèles", w.libraryClasses)
fire(mine, "OnClick")
assert(shownNames() == "Mon modele,Second", shownNames())
local delete, rename, note = byText("Supprimer", w.library), byText("Renommer", w.library), byText("Note…", w.library)
local exportB, importB = byText("Exporter", w.library), byText("Importer", w.library)
local openB, favB = byText("Ouvrir dans l'éditeur", w.library), byText("Ajouter aux favoris", w.library)
assert(delete:IsVisible() and delete._enabled == false and rename._enabled == false and importB:IsVisible() and not favB:IsShown(), "actions sans modele choisi")
fire(libRows[1], "OnClick")
assert(delete._enabled and rename._enabled and note._enabled and exportB._enabled)
assert(find(function(x) return x._type == "FontString" and x._text and plain(x._text) == "/cast Peur" and inside(x, w.library) end), "corps du modele non affiche")
-- renommer : fenetre de saisie ; nom deja pris refuse ; Entree valide
fire(rename, "OnClick")
local prompt = ns.prompt
assert(prompt:IsShown() and prompt.box._text == "Mon modele" and FOCUS == prompt.box and prompt.ok._text == "Renommer")
prompt.box._text = "Second"
fire(prompt.box, "OnEnterPressed")
assert(not prompt:IsShown() and said("déjà") and db.personal[1].name == "Mon modele")
fire(rename, "OnClick")
prompt.box._text = "  Peur |survol  "
fire(prompt.ok, "OnClick")
assert(db.personal[1].name == "Peur survol" and shownNames() == "Peur survol,Second", shownNames())
assert(rename._enabled, "la selection doit suivre le modele renomme")
fire(rename, "OnClick")
fire(prompt.box, "OnEscapePressed") -- Echap : rien ne change
assert(not prompt:IsShown() and db.personal[1].name == "Peur survol")
-- note : affichee (echappee) et trouvee par la recherche
fire(note, "OnClick")
prompt.box._text = "Pour les |cffff0000donjons"
fire(prompt.box, "OnEnterPressed")
assert(db.personal[1].note == "Pour les |cffff0000donjons")
assert(find(function(x) return x._type == "FontString" and x._text == "Pour les ||cffff0000donjons" end), "note non affichee ou non echappee")
search._text = "DONJON"
fire(search, "OnTextChanged", true)
assert(shownNames() == "Peur survol", shownNames())
search._text = "/cast"
fire(search, "OnTextChanged", true)
assert(shownNames() == "Peur survol,Second")
search._text = ""
fire(search, "OnTextChanged", true)
fire(byText("PvP", listPanel), "OnClick") -- un modele n'a pas de categorie
assert(shownNames() == "")
fire(byText("Toutes", listPanel), "OnClick")
-- « Mes sorts seulement » : meme filtre que la bibliotheque
C_Spell.GetSpellInfo = function(name) return name ~= "Corruption" and { name = name } or nil end
fireEvent("SPELLS_CHANGED")
fire(mine, "OnClick")
assert(shownNames() == "Peur survol,Second", shownNames()) -- sans la case : grise, pas cache
local second
for _, r in ipairs(libRows) do if r.text._text == "Second" then second = r end end
assert(second.text._textColor[1] == 0.5 and libRows[1].text._textColor[1] == 1, "modele au sort inconnu non grise")
local onlyKnown = find(function(x) return x._template == "UICheckButtonTemplate" and x._parent == w.libraryClasses end)
click(onlyKnown, true)
assert(shownNames() == "Peur survol", "« Mes sorts seulement » sans effet sur les modeles : " .. shownNames())
click(onlyKnown, false)
C_Spell.GetSpellInfo = nil
fireEvent("SPELLS_CHANGED")
fire(mine, "OnClick")
fire(libRows[1], "OnClick")
-- exporter / importer (format BF1)
fire(exportB, "OnClick")
assert(modelShare._text == ns.Export("Peur survol", "/cast Peur"), modelShare._text)
modelShare._text = "n'importe quoi"
fire(importB, "OnClick")
assert(said("BF1") and #db.personal == 2)
modelShare._text = ns.Export("Importe", "/use 13\n/cast Fear")
fire(importB, "OnClick")
assert(#db.personal == 3 and db.personal[3].name == "Importe" and db.personal[3].body == "/use 13\n/cast Fear" and modelShare._text == "")
assert(shownNames() == "Peur survol,Second,Importe")
-- ouvrir dans l'editeur
fire(libRows[3], "OnClick")
fire(openB, "OnClick")
assert(tabs.editor.line:IsShown() and text() == "/use 13\n/cast Fear" and nameBox._text == "Importe", "modele non ouvert")
-- supprimer : confirmation, puis la liste et le detail se vident
fire(tabs.library, "OnClick")
local popups3 = #POPUPS
fire(delete, "OnClick")
assert(#POPUPS == popups3 + 1 and POPUPS[#POPUPS].which == "BLOCKFORGE_DELETE_PERSONAL" and POPUPS[#POPUPS].text:find("Importe") and #db.personal == 3)
accept()
assert(#db.personal == 2 and shownNames() == "Peur survol,Second" and delete._enabled == false and openB._enabled == false, "modele non supprime")
-- les autres classes marchent toujours, et le bouton des favoris revient
fire(byText("Démoniste"), "OnClick")
assert(not delete:IsVisible() and favB:IsShown() and libRows[1]:IsShown())
-- la reinitialisation des parametres garde les modeles et ne relance pas la visite
ns.ResetDB()
assert(#db.personal == 2 and db.tutorialSeen == true and db.acceptShared == true)
assert(#CALLS == callsBefore, "une macro du jeu a ete touchee")

-- F. envoi a un joueur : en morceaux, par chuchotement d'add-on
assert(PREFIXES[1] == "BlockForge" and ns.CanShare())
fire(tabs.editor, "OnClick")
local sendChip = byText("Envoyer à…", menu)
nameBox._text = "Envoi"
COMBAT = true
fire(sendChip, "OnClick")
assert(said("combat") and not prompt:IsShown() and #SENT == 0)
COMBAT = false
TARGET = "Ami-Royaume"
fire(sendChip, "OnClick")
assert(prompt:IsShown() and prompt.box._text == "Ami-Royaume" and prompt.ok._text == "Envoyer" and prompt.title._text:find("Envoi"), "cible non proposee")
fire(prompt.box, "OnEnterPressed")
assert(#SENT == 1 and SENT[1][1] == "BlockForge" and SENT[1][3] == "WHISPER" and SENT[1][4] == "Ami-Royaume" and said("envoyée"), lastLine())
assert(SENT[1][2]:find("^%d+:1:1:BF1:Envoi:"), SENT[1][2])
TARGET = nil
fire(sendChip, "OnClick")
assert(prompt.box._text == "", "sans cible : champ vide")
fire(prompt.box, "OnEnterPressed") -- nom vide : rien
assert(#SENT == 1)
-- macro longue : plusieurs messages de moins de 255 octets
fire(tabs.macros, "OnClick")
MACROS = { Longue = { index = 1, body = string.rep("/cast [@mouseover,harm] Éclair|:%\n", 7) } }
fire(w.macros, "OnShow")
local macroRow = find(function(x) return x.scope and x.text._text == "Longue" end)
fire(macroRow, "OnClick")
local sendMacro = byText("Envoyer à…", w.macros)
assert(sendMacro._enabled)
fire(sendMacro, "OnClick")
prompt.box._text = "Ami"
SENT = {}
fire(prompt.ok, "OnClick")
assert(#SENT >= 2, #SENT)
-- echec : retour false, code d'erreur, ou erreur Lua ; en combat rien ne part
for _, result in ipairs({ false, 3 }) do
  SEND_RESULT, SENT = result, {}
  assert(ns.SendMacro("Envoi", "/cast A", "Ami") == nil and said("échoué") and #SENT == 1, "echec non signale")
end
SEND_RESULT = 0
local realSend = C_ChatInfo.SendAddonMessage
C_ChatInfo.SendAddonMessage = function() error("bloque") end
assert(ns.SendMacro("Envoi", "/cast A", "Ami|r") == nil and said("échoué") and said("Ami||r"))
C_ChatInfo.SendAddonMessage = realSend
COMBAT, SENT = true, {}
assert(ns.SendMacro("Envoi", "/cast A", "Ami") == nil and said("combat") and #SENT == 0)
COMBAT = false
assert(ns.SendMacro(string.rep("x", 17), "/cast A", "Ami") == nil and #SENT == 0, "nom trop long envoye")

-- G. reception : rien n'est cree sans un clic ; tout ce qui est douteux est ignore sans bruit
MACROS["Longue"] = nil
local function deliver(sender, name, body, id)
  for _, chunk in ipairs(ns.Chunks(ns.Export(name, body), id or "1")) do fireEvent("CHAT_MSG_ADDON", "BlockForge", chunk, "WHISPER", sender) end
end
local function state() return #POPUPS .. "/" .. #CALLS .. "/" .. #db.personal .. "/" .. text() .. "/" .. #PRINTS end
fire(tabs.editor, "OnClick")
fire(clear, "OnClick")
local quiet = state()
local body = string.rep("/cast [@mouseover,harm] Éclair|:%\n", 7)
deliver("Moi-Royaume", "Perso", body) -- envoye par soi-meme
deliver("Moi", "Perso", body)
assert(state() == quiet, "message de soi-meme accepte")
COMBAT = true
deliver("Autre-Royaume", "Combat", body) -- en combat : meme pas mis en attente
COMBAT = false
assert(state() == quiet, "reception en combat")
fireEvent("CHAT_MSG_ADDON", "AutreAddon", "1:1:1:" .. ns.Export("X", "/cast A"), "WHISPER", "Autre-Royaume")
fireEvent("CHAT_MSG_ADDON", "BlockForge", "1:1:1:" .. ns.Export("X", "/cast A"), "PARTY", "Autre-Royaume")
fireEvent("CHAT_MSG_ADDON", "BlockForge", "1:1:1:pas un export", "WHISPER", "Autre-Royaume")
fireEvent("CHAT_MSG_ADDON", "BlockForge", "n'importe quoi", "WHISPER", "Autre-Royaume")
fireEvent("CHAT_MSG_ADDON", "BlockForge", "1:1:1:" .. ns.Export("|cffff0000Admin", "/cast A"), "WHISPER", "Autre-Royaume")
fireEvent("CHAT_MSG_ADDON", "BlockForge", "1:1:1:BF1:" .. string.rep("x", 17) .. ":/cast A", "WHISPER", "Autre-Royaume")
fireEvent("CHAT_MSG_ADDON", "BlockForge", "1:1:1:" .. ns.Export("X", "/cast A"), "WHISPER", string.rep("x", 65))
fireEvent("CHAT_MSG_ADDON", "BlockForge", "1:1:1:" .. ns.Export("X", "/cast A"), "WHISPER", nil)
assert(state() == quiet, "message douteux accepte : " .. state())
db.acceptShared = false
deliver("Autre-Royaume", "Refusee", body)
assert(state() == quiet, "reglage « accepter » ignore")
db.acceptShared = true
-- transfert incomplet oublie apres le delai
local parts = ns.Chunks(ns.Export("Tardive", body), "7")
assert(#parts >= 2)
fireEvent("CHAT_MSG_ADDON", "BlockForge", parts[1], "WHISPER", "Autre-Royaume")
NOW = NOW + ns.SHARE_TIMEOUT + 1
for i = 2, #parts do fireEvent("CHAT_MSG_ADDON", "BlockForge", parts[i], "WHISPER", "Autre-Royaume") end
assert(state() == quiet, "transfert perime accepte")
NOW = NOW + ns.SHARE_TIMEOUT + 1
-- macro valide, morceaux dans le desordre : une proposition, et rien d'autre
local ok = ns.Chunks(ns.Export("Recue", body), "8")
for i = #ok, 1, -1 do fireEvent("CHAT_MSG_ADDON", "BlockForge", ok[i], "WHISPER", "Autre|cffff0000-Royaume") end
local p = POPUPS[#POPUPS]
assert(p.which == "BLOCKFORGE_INCOMING" and p.text:find("Recue", 1, true) and p.text:find("Autre||cffff0000-Royaume", 1, true), "proposition attendue : " .. p.text)
assert(text() == "" and #db.personal == 2 and #CALLS == callsBefore and next(MACROS) == nil, "quelque chose a ete cree sans confirmation")
local asked = #POPUPS
deliver("Tiers-Royaume", "Autre", "/cast A") -- une proposition a la fois
assert(#POPUPS == asked, "deux propositions en meme temps")
-- accepter en combat : refuse
COMBAT = true
accept()
assert(said("combat") and text() == "" and #db.personal == 2)
COMBAT = false
accept() -- la proposition a ete consommee : un second clic ne fait rien
assert(text() == "")
-- limite par expediteur : pas de nouvelle proposition avant 30 s
deliver("Autre|cffff0000-Royaume", "Encore", "/cast A", "9")
assert(#POPUPS == asked, "expediteur non limite")
NOW = NOW + 31
deliver("Autre-Royaume", "Ouverte", body, "10")
assert(#POPUPS == asked + 1)
SlashCmdList.BLOCKFORGE("") -- fenetre fermee : « Ouvrir » la rouvre sur l'editeur
assert(not BlockForgeFrame:IsShown())
accept("OnAccept")
assert(BlockForgeFrame:IsShown() and tabs.editor.line:IsShown() and text() == ns.trim(body) and nameBox._text == "Ouverte", "macro recue non ouverte")
assert(#CALLS == callsBefore and #db.personal == 2, "macro recue enregistree toute seule")
-- « Ma bibliotheque » : rangee dans les modeles, avec l'expediteur en note
NOW = NOW + 31
deliver("Autre-Royaume", "Rangee", "/cast B", "11")
accept("OnAlt")
assert(#db.personal == 3 and db.personal[3].name == "Rangee" and db.personal[3].body == "/cast B" and db.personal[3].note == "Reçue de Autre-Royaume")
-- refuser : rien, et la proposition suivante peut arriver
NOW = NOW + 31
deliver("Autre-Royaume", "Non", "/cast C", "12")
accept("OnCancel")
NOW = NOW + 31
deliver("Autre-Royaume", "Suite", "/cast D", "13")
assert(#POPUPS == asked + 4 and #db.personal == 3 and #CALLS == callsBefore)
accept("OnCancel")

-- H. /bf test : lignes du lot 2
GetLocale = function() return "frFR" end
SlashCmdList.BLOCKFORGE("test")
GetLocale = nil
local report = table.concat(db.selftest.lines, "\n")
assert(report:find("OK share round trip: ", 1, true) and report:find("OK tutorial: " .. #steps .. " steps, anchors missing: ", 1, true), report)
assert(report:find("INFO lot 2: sharing on (accept true), text editor on, undo keys on, personal macros 3, tutorial seen true", 1, true), report)
assert(report:find("INFO optional api present: C_ChatInfo.SendAddonMessage", 1, true) and report:find("INFO optional api absent: canaccessvalue", 1, true), report)
for _, x in ipairs(ALL) do
  if x._scripts.OnEnter then x._scripts.OnEnter(x) end
end
`, "=lot2");

// ---------------------------------------------------------------- 7. modeles abimes dans BlockForgeDB, client sans canal d'add-on ni clavier
boot(`{ tutorialSeen = true, acceptShared = "oui", personal = { 5, { name = 1, body = "/cast A" }, { name = "Garde", body = "/cast A", note = 3, icon = {} }, { name = "Sans corps" } } }`,
  `C_ChatInfo = nil  IsControlKeyDown = nil  GetTime = nil  UnitName = nil`);
run(String.raw`
local ns, db = NS, BlockForgeDB
assert(#db.personal == 1 and db.personal[1].name == "Garde" and db.personal[1].note == nil and db.personal[1].icon == nil and db.acceptShared == true, "modeles non nettoyes")
SlashCmdList.BLOCKFORGE("")
assert(ns.Tutorial.step == nil, "visite relancee alors qu'elle a deja ete vue")
assert(not ns.CanShare() and ns.ed.keys == nil)
assert(not find(function(w) return (w._text == "Envoyer à…") or (w.text and w.text._text == "Envoyer à…") end), "bouton d'envoi visible sans canal d'add-on")
assert(byText("Ajouter à ma bibliothèque") and byText("Annuler") and byText("Éditer le texte"))
fireEvent("CHAT_MSG_ADDON", "BlockForge", "1:1:1:" .. ns.Export("X", "/cast A"), "WHISPER", "Autre") -- personne n'ecoute
assert(#POPUPS == 0)
assert(ns.SendMacro("X", "/cast A", "Ami") == nil)
GetLocale = function() return "frFR" end
SlashCmdList.BLOCKFORGE("test")
GetLocale = nil
local report = table.concat(db.selftest.lines, "\n")
assert(report:find("INFO lot 2: sharing absent (accept true), text editor on, undo keys absent, personal macros 1", 1, true), report)
assert(report:find("INFO optional api absent: C_ChatInfo.SendAddonMessage", 1, true))
-- sans champ de saisie sur plusieurs lignes : pas de bascule, l'apercu reste
`, "=sans canal");
boot("nil", `ABSENT = { SetMultiLine = true, SetPropagateKeyboardInput = true }`);
run(String.raw`
SlashCmdList.BLOCKFORGE("")
assert(not find(function(w) return w.text and w.text._text == "Éditer le texte" end), "bascule du texte libre sans champ multi-ligne")
assert(NS.ed.w.preview:IsShown() and NS.ed.Commit == nil)
assert(NS.ed.keys == nil, "clavier arme sans SetPropagateKeyboardInput : les touches du joueur seraient avalees")
fire(byText("Annuler"), "OnClick")
`, "=sans multiligne");

// ---------------------------------------------------------------- 8. cycle 4, lot 1 : grimoire integre et Assistant
boot("{ tutorialSeen = true }", String.raw`
SHIFT, HAS_PET = false, false
function IsShiftKeyDown() return SHIFT end
BOOK = { "Corruption", "Peur", "Éclair de givre", "Soins rapides", "Maîtrise passive" }
C_SpellBook = {
  GetNumSpellBookSkillLines = function() return 1 end,
  GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = #BOOK } end,
  GetSpellBookItemName = function(i) return BOOK[i] end,
}
Enum = { SpellBookSpellBank = { Player = 0 } }
C_Spell.GetSpellInfo = function(name) for _, n in ipairs(BOOK) do if n == name then return {} end end end
C_Spell.IsSpellPassive = function(name) return name == "Maîtrise passive" end
C_Spell.IsSpellHarmful = function(name) assert(not COMBAT, "type de sort lu en combat") return name == "Corruption" or name == "Peur" end
C_Spell.IsSpellHelpful = function(name) return name == "Soins rapides" end
PET = { "PET_ACTION_ATTACK", "Morsure" }
function GetPetActionInfo(i) if PET[i] then return PET[i], 132000 + i end end
function UnitExists(unit) return unit == "pet" and HAS_PET end
BAGS = { [0] = { 5512, 2589 }, [1] = { 5512, 118 } } -- 2589 : etoffe, sans effet « Utiliser »
ITEMS = { [5512] = "Pierre de soins", [2589] = "Étoffe de lin", [118] = "Potion de soins", [9000] = "Bijou de test" }
C_Container = {
  GetContainerNumSlots = function(bag) return BAGS[bag] and #BAGS[bag] or 0 end,
  GetContainerItemID = function(bag, slot) return BAGS[bag][slot] end,
}
C_Item.GetItemInfo = function(id) return ITEMS[id] end
C_Item.GetItemSpell = function(id) if id ~= 2589 then return "Effet", 1 end end
function GetInventoryItemID(unit, slot) assert(unit == "player") if slot == 13 then return 9000 end end
`);
run(String.raw`
local ns, db = NS, BlockForgeDB
local function said(fragment) return lastLine():find(fragment, 1, true) ~= nil end
local function names(list)
  local out = {}
  for i, e in ipairs(list) do out[i] = e.name end
  return table.concat(out, ",")
end
local function text() return ns.Compile(ns.ed.Blocks()) end
local function created()
  local n, last = 0, nil
  for _, c in ipairs(CALLS) do if c[1] == "CreateMacro" then n, last = n + 1, c end end
  return n, last
end
SlashCmdList.BLOCKFORGE("")
ns.Open("editor") -- la fenetre s'ouvre sur l'accueil
local w = ns.ed.w
local bookButton, assistantButton = w.grimoireButton, w.assistantButton
assert(bookButton._text == "Mon grimoire" and assistantButton._text == "Assistant", "boutons de l'editeur absents")
assert(inside(bookButton, w.page) and bookButton._w == 120 and assistantButton._point[2] == w.page and assistantButton._point[1] == "BOTTOMRIGHT")
assert(ns.grimoire == nil and ns.assistant == nil, "panneaux construits avant d'etre demandes")

-- A. tiroir : sorts sans le passif, icone connue ou point d'interrogation, 4 x 9 cases dans la largeur de la palette
fire(bookButton, "OnClick")
local drawer = ns.grimoire
local grid = drawer.grid
assert(drawer:IsShown() and drawer._w == 160 and drawer._h == 430 and drawer._point[2] == w.palette and #grid.cells == 36)
assert(names(grid.shown) == "Corruption,Peur,Éclair de givre,Soins rapides", names(grid.shown))
assert(grid.cells[1]._tex == nil and grid.cells[1].icon._tex == 136118 and grid.cells[2].icon._tex:find("QuestionMark"))
assert(grid.cells[4]:IsShown() and not grid.cells[5]:IsShown() and grid.range._text == "")
for i, cell in ipairs(grid.cells) do -- aucune case hors du panneau (160 x 430, bord interieur a 157 et -427)
  local x, y = 9 + cell._point[2], -28 + cell._point[3]
  assert(x >= 3 and x + cell._w <= 157 and y - cell._h >= -427, "case " .. i .. " hors du tiroir")
end
-- recherche sans accents ni casse
grid.search._text = "ECLAIR"
fire(grid.search, "OnTextChanged", true)
assert(names(grid.shown) == "Éclair de givre" and grid.cells[1]:IsShown() and not grid.cells[2]:IsShown())
grid.search._text = "zzz"
fire(grid.search, "OnTextChanged", true)
assert(#grid.shown == 0 and not grid.cells[1]:IsShown())
grid.search._text = ""
fire(grid.search, "OnTextChanged", true)
assert(#grid.shown == 4)
-- familier : les ordres (jetons PET_) sont ecartes ; objets : bijou porte puis sacs, sans doublon ni objet sans effet
fire(grid.chips[2], "OnClick")
assert(names(grid.shown) == "Morsure" and grid.cells[1].icon._tex == 132002 and ns.PetSpells.morsure, names(grid.shown))
fire(grid.chips[3], "OnClick")
assert(names(grid.shown) == "Bijou de test,Pierre de soins,Potion de soins", names(grid.shown))
assert(grid.cells[1].icon._tex == 135000 and grid.cells[2].icon._tex == 135230)
-- clic : un bloc /use ou /cast s'ajoute en bas
fire(grid.cells[2], "OnClick")
assert(text() == "/use Pierre de soins", text())
fire(grid.chips[1], "OnClick")
fire(grid.cells[1], "OnClick")
assert(text() == "/use Pierre de soins\n/cast Corruption", text())
-- bloc choisi avec un emplacement vide : le clic le remplit ; bloc choisi d'un autre type : ajout en bas
ns.ed.Load("", "#showtooltip\n/cast [@mouseover,harm,nodead][]\n/use")
local rows = {}
for _, c in ipairs(w.canvas._children) do if c.pills then rows[#rows + 1] = c end end
fire(grid.cells[2], "OnClick") -- #showtooltip est choisi
assert(text() == "#showtooltip\n/cast [@mouseover,harm,nodead][]\n/use\n/cast Peur", text())
fire(rows[2], "OnClick")
fire(grid.cells[2], "OnClick")
assert(text() == "#showtooltip\n/cast [@mouseover,harm,nodead][] Peur\n/use\n/cast Peur", text())
fire(grid.cells[1], "OnClick") -- le bloc choisi est plein : ajout en bas
assert(text():find("\n/cast Corruption$"), text())
fire(rows[3], "OnClick")
fire(grid.chips[3], "OnClick")
fire(grid.cells[3], "OnClick")
assert(text():find("\n/use Potion de soins\n", 1, true), text())
fire(grid.chips[1], "OnClick")
-- evenements : la grille visible suit le grimoire et le familier ; fermee, elle ne relit rien
BOOK[#BOOK + 1] = "Nouveau sort"
fireEvent("SPELLS_CHANGED")
assert(#grid.shown == 5 and grid.shown[5].name == "Nouveau sort", names(grid.shown))
fire(grid.chips[2], "OnClick")
PET[3] = "Griffe"
fireEvent("UNIT_PET", "target")
assert(#grid.shown == 1, "UNIT_PET d'une autre unite")
fireEvent("UNIT_PET", "player")
assert(names(grid.shown) == "Morsure,Griffe")
fire(grid.chips[3], "OnClick")
BAGS[1][3], ITEMS[929] = 929, "Potion de mana"
fireEvent("BAG_UPDATE_DELAYED")
assert(#grid.shown == 4)
fire(find(function(x) return x._parent == drawer and x.text and x.text._text == "x" end), "OnClick") -- croix du bandeau
assert(not drawer:IsShown())
BAGS[1][4], ITEMS[930] = 930, "Parchemin"
fireEvent("BAG_UPDATE_DELAYED")
assert(#grid.shown == 4, "grille fermee relue")
fire(bookButton, "OnClick")
assert(drawer:IsShown() and #grid.shown == 5)
fire(bookButton, "OnClick") -- le bouton referme
assert(not drawer:IsShown())
-- molette : 60 sorts dans 36 cases, par deux lignes
fire(bookButton, "OnClick")
fire(grid.chips[1], "OnClick")
for i = 1, 55 do BOOK[#BOOK + 1] = "Sort " .. i end
fireEvent("SPELLS_CHANGED")
assert(#grid.shown == 60 and grid.range._text == "1-36 / 60", grid.range._text)
fire(grid.frame, "OnMouseWheel", -1)
assert(grid.offset == 8 and grid.range._text == "9-44 / 60")
for _ = 1, 9 do fire(grid.frame, "OnMouseWheel", -1) end
assert(grid.offset == 24 and grid.range._text == "25-60 / 60" and grid.cells[36]:IsShown(), grid.range._text)
for _ = 1, 9 do fire(grid.frame, "OnMouseWheel", 1) end
assert(grid.offset == 0)
-- combat : pas de clic, pas d'ouverture, tout se ferme
local before = text()
COMBAT = true
fire(grid.cells[1], "OnClick")
assert(said("combat") and text() == before, "bloc ajoute en combat")
fireEvent("PLAYER_REGEN_DISABLED")
assert(not drawer:IsShown())
PRINTS = {}
fire(bookButton, "OnClick")
assert(said("combat") and not drawer:IsShown())
PRINTS = {}
fire(assistantButton, "OnClick")
assert(said("combat") and ns.assistant == nil)
SlashCmdList.BLOCKFORGE("assistant")
assert(ns.assistant == nil)
COMBAT = false

-- B. Maj+clic : l'Assistant s'ouvre sur ce sort, le tiroir se ferme, rien n'est ajoute a la macro
fire(bookButton, "OnClick")
SHIFT = true
fire(grid.cells[1], "OnClick")
SHIFT = false
local panel = ns.assistant
local state, cards = panel.state, panel.cards
assert(panel:IsShown() and not drawer:IsShown() and text() == before, "Maj+clic")
assert(panel._w == 884 and panel._h == 566 and panel._parent == w.page and #cards == 4 and #panel.grid.cells == 72)
assert(state.entry.name == "Corruption" and state.kind == "harm" and panel.name._text == "Corruption" and panel.kind._text == "Sort offensif")
assert(panel.icon._tex == 136118 and not panel.intro:IsShown() and panel.grid.picked == "Corruption")
local function ids()
  local out = {}
  for i, r in ipairs(state.recipes) do out[i] = r.id end
  return table.concat(out, " ")
end
-- seulement les recettes d'un sort offensif, sans celle du familier (aucun familier sorti)
assert(ids() == "mouseover_harm focus_mod interrupt_focus nearest trinkets stopcasting sequence living_trinkets survival living_mana living_food_water living_bandage living_healing", ids())
local body = "#showtooltip\n/cast [@mouseover,harm,nodead][] Corruption"
assert(cards[1].recipe.id == "mouseover_harm" and cards[1].body == body and plain(cards[1].code._text) == body, cards[1].body)
assert(cards[1].code._text:find("|cff") and cards[1].title._text == "Survol, sinon cible" and #cards[1].desc._text > 20)
assert(cards[1].count._text == #body .. " / 255" and cards[4]:IsShown() and panel.range._text == "1-4 / 13  (molette)", panel.range._text)
for i, card in ipairs(cards) do -- cartes dans le panneau : 248 + 628 <= 881, derniere finie avant -563
  assert(card._w == 628 and card._h == 114 and -70 + card._point[3] - card._h >= -550 and card.code._h == 65, "carte " .. i)
  assert(card.count._w == 52 and 336 - card.count._w > 280, "compteur sur l'etiquette vivante")
end
assert(panel.range._point[3] == 1 and 566 - 1 - 10 > 552, "position sur la derniere carte")
-- options : chaque puce refait le texte des cartes
local tooltipChip, deadChip, attackChip = panel.chips[1], panel.chips[2], panel.chips[3]
assert(tooltipChip.text._text == "#showtooltip" and deadChip.text._text == "Ne pas viser les morts" and attackChip:IsShown())
fire(deadChip, "OnClick")
assert(cards[1].body == "#showtooltip\n/cast [@mouseover,harm][] Corruption", cards[1].body)
fire(tooltipChip, "OnClick")
assert(cards[1].body == "/cast [@mouseover,harm][] Corruption" and cards[1].count._text == "36 / 255")
fire(attackChip, "OnClick")
assert(cards[1].body == "/stopattack\n/cast [@mouseover,harm][] Corruption")
fire(attackChip, "OnClick")
fire(tooltipChip, "OnClick")
fire(deadChip, "OnClick")
assert(cards[1].body == body)
-- molette : les 8 recettes dans 4 cartes ; la sequence ne se cree pas telle quelle
for _ = 1, 4 do fire(panel.deck, "OnMouseWheel", -1) end
assert(cards[1].recipe.id == "trinkets" and cards[3].recipe.id == "sequence" and cards[4].recipe.id == "living_trinkets" and panel.range._text == "5-8 / 13  (molette)", panel.range._text)
assert(cards[3].create._enabled == false and cards[4].create._enabled == true and plain(cards[4].code._text):find("/use <Bijou du haut>", 1, true), cards[4].code._text)
for _ = 1, 9 do fire(panel.deck, "OnMouseWheel", 1) end
assert(cards[1].recipe.id == "mouseover_harm" and cards[1].create._enabled == true)
-- autre sort dans la grille de l'Assistant : aide, donc d'autres recettes et pas de /stopattack
fire(panel.grid.cells[4], "OnClick")
assert(state.entry.name == "Soins rapides" and state.kind == "help" and panel.kind._text == "Sort d'aide")
assert(ids() == "mouseover_help focus_mod self_alt stopcasting sequence living_trinkets survival living_mana living_food_water living_bandage living_healing" and not attackChip:IsShown(), ids())
assert(cards[2].body == "#showtooltip\n/cast [mod:shift,@focus][@mouseover,help,nodead][] Soins rapides", cards[2].body)
-- type inconnu du jeu : toutes les recettes de sort ; familier sorti : sa recette en plus
fire(panel.grid.cells[3], "OnClick")
assert(state.kind == "either" and #state.recipes == 15 and attackChip:IsShown(), ids())
HAS_PET = true
fire(panel.grid.cells[1], "OnClick")
assert(ids() == "mouseover_harm focus_mod interrupt_focus nearest with_pet trinkets stopcasting sequence living_trinkets survival living_mana living_food_water living_bandage living_healing", ids())
fire(panel.grid.chips[2], "OnClick")
fire(panel.grid.cells[1], "OnClick")
assert(state.kind == "pet" and panel.kind._text == "Technique du familier" and ids():find("with_pet", 1, true), ids())
HAS_PET = false
-- objet : /use, et seulement ses recettes
fire(panel.grid.chips[3], "OnClick")
fire(panel.grid.cells[2], "OnClick")
assert(state.kind == "item" and ids() == "stopcasting item_fallback survival living_mana living_food_water living_bandage living_healing" and cards[3]:IsShown() and cards[4]:IsShown() and panel.range._text == "1-4 / 7  (molette)", ids())
assert(cards[1].body == "#showtooltip\n/stopcasting\n/use Pierre de soins" and cards[2].create._enabled == false)

-- C. « Ouvrir dans l'editeur » : les blocs de la recette, le nom du sort, l'Assistant se ferme ; Ctrl+Z rend l'ancien contenu
ns.ed.Load("", "/cast Peur")
fire(cards[1].open, "OnClick")
assert(not panel:IsShown() and text() == "#showtooltip\n/stopcasting\n/use Pierre de soins" and ns.ed.Name() == "Pierre de soins", text())
assert(#ns.ed.Blocks() == 3 and ns.ed.Blocks()[3].type == "use")
ns.ed.Step(false)
assert(text() == "/cast Peur", "annuler apres l'Assistant : " .. text())

-- D. « Creer la macro » : une seule macro, nom de 16 octets au plus, icone automatique ; meme nom : confirmation
BOOK[1] = "Éclair de givre pénétrant du grand nord"
fireEvent("SPELLS_CHANGED")
SlashCmdList.BLOCKFORGE("assistant")
assert(panel:IsShown() and state.entry.name == "Pierre de soins", "/bf assistant")
fire(panel.grid.chips[1], "OnClick")
fire(panel.grid.cells[1], "OnClick")
assert(state.entry.name == BOOK[1] and state.kind == "either")
local n0 = created()
fire(cards[1].create, "OnClick")
local n1, call = created()
assert(n1 == n0 + 1 and call[2] == "Éclair de givre" and #call[2] <= 16 and call[3] == cards[1].body and call[5] == "INV_Misc_QuestionMark", call[2])
assert(call[4] == false and said("créée") and panel:IsShown())
assert(#cards[1].body <= 255 and cards[1].body:find(BOOK[1], 1, true))
local popups = #POPUPS
fire(cards[2].create, "OnClick")
assert(created() == n1 and #POPUPS == popups + 1 and POPUPS[#POPUPS].which == "BLOCKFORGE_OVERWRITE", "remplacement sans confirmation")
StaticPopupDialogs.BLOCKFORGE_OVERWRITE.OnAccept({}, POPUPS[#POPUPS].data)
assert(MACROS["Éclair de givre"].body == cards[2].body and MACROS["Éclair de givre"].icon == "INV_Misc_QuestionMark" and created() == n1)
-- macros du personnage par defaut : la macro de l'Assistant y va aussi
db.perCharDefault = true
fire(panel.grid.cells[2], "OnClick")
fire(cards[1].create, "OnClick")
local n2, charCall = created()
assert(n2 == n1 + 1 and charCall[2] == "Peur" and charCall[4] == true)
db.perCharDefault = false
-- combat : refus, rien de cree, l'Assistant se ferme et ne se rouvre pas
local calls = #CALLS
COMBAT = true
PRINTS = {}
fire(cards[3].create, "OnClick")
assert(said("combat") and #CALLS == calls, "macro creee en combat")
fireEvent("PLAYER_REGEN_DISABLED")
assert(not panel:IsShown())
SlashCmdList.BLOCKFORGE("assistant")
assert(not panel:IsShown())
COMBAT = false
-- bouton de l'editeur, depuis un autre onglet : retour a l'editeur, dernier sort garde ; croix : ferme
fire(byText("Bibliothèque"), "OnClick")
fire(assistantButton, "OnClick")
assert(panel:IsShown() and byText("Éditeur").line:IsShown() and state.entry.name == "Peur")
fire(find(function(x) return x._parent == panel and x.text and x.text._text == "x" end), "OnClick")
assert(not panel:IsShown())
-- la visite guidee ferme l'Assistant et montre les deux boutons
fire(assistantButton, "OnClick")
SlashCmdList.BLOCKFORGE("tuto")
assert(not panel:IsShown() and ns.Tutorial.step == 1)
local seen = {}
for i, s in ipairs(ns.TutorialSteps) do seen[s.anchor()] = i end
assert(#ns.TutorialSteps == 12 and seen[bookButton] and seen[assistantButton] == seen[bookButton] + 1, "etapes du grimoire et de l'Assistant")
fire(assistantButton, "OnClick")
assert(panel:IsShown() and ns.Tutorial.step == nil, "visite encore la sous l'Assistant")

-- E. /bf test
GetLocale = function() return "frFR" end
SlashCmdList.BLOCKFORGE("test")
GetLocale = nil
local report = table.concat(db.selftest.lines, "\n")
assert(report:find("INFO grimoire: 60 castable spells (1 harmful, 1 helpful, 58 either), 2 pet abilities, 5 usable items, pet out false", 1, true), report)
assert(report:find("OK assistant recipes: " .. #ns.Recipes .. ", broken: ", 1, true) and report:find("OK grimoire and assistant buttons", 1, true), report)
assert(report:find("OK tutorial: 12 steps, anchors missing: ", 1, true), report)
assert(report:find("INFO optional api present: C_Spell.IsSpellPassive", 1, true) and report:find("INFO optional api absent: IsHarmfulSpell", 1, true)
  and report:find("INFO optional api present: C_Container.GetContainerItemID", 1, true) and report:find("INFO optional api absent: NUM_BAG_SLOTS", 1, true), report)
for _, x in ipairs(ALL) do
  if x._scripts.OnEnter then x._scripts.OnEnter(x) end
end
`, "=grimoire");

// client sans les API facultatives du lot (ni grimoire enumerable, ni sacs, ni type de sort), en anglais : listes vides, aucune erreur
boot("{ tutorialSeen = true }", `function GetLocale() return "enUS" end  IsShiftKeyDown = nil  UnitExists = nil  GetInventoryItemTexture = nil`);
run(String.raw`
local ns = NS
SlashCmdList.BLOCKFORGE("")
fire(byText("My spellbook"), "OnClick")
local grid = ns.grimoire.grid
for i = 1, 3 do
  fire(grid.chips[i], "OnClick")
  assert(#grid.shown == 0 and not grid.cells[1]:IsShown(), "source " .. i)
end
assert(grid.chips[1].text._text == "Spells" and grid.chips[2].text._text == "Pet" and grid.chips[3].text._text == "Items")
assert(ns.SpellKind("Corruption") == "either" and ns.HasPet() == false)
SlashCmdList.BLOCKFORGE("assistant")
local panel = ns.assistant
assert(panel:IsShown() and not ns.grimoire:IsShown() and not panel.intro:IsShown() and panel.name._text == "Pick a spell on the left." and panel.cards[1]:IsShown() and #panel.state.recipes == 5)
-- un sort tape a la main dans l'editeur n'a pas besoin de la grille : l'Assistant accepte une entree directe
ns.OpenAssistant({ name = "Fireball", kind = "spell" })
assert(#panel.state.recipes == 15 and panel.cards[1].title._text == "Mouseover, else target" and panel.kind._text == "Harmful or helpful spell")
for _, r in ipairs(ns.Recipes) do
  for _, c in ipairs({ "é", "è", "ê", "à", "ù", "ç", "«", "»", " :", " ;" }) do
    assert(not (r.title .. r.desc .. r.build("X", {})):find(c, 1, true), "recette en francais : " .. r.id)
  end
end
fire(panel.cards[1].create, "OnClick")
assert(CALLS[#CALLS][1] == "PickupMacro" and CALLS[#CALLS - 1][2] == "Fireball" and CALLS[#CALLS - 1][3] == "#showtooltip\n/cast [@mouseover,harm,nodead][] Fireball", CALLS[#CALLS - 1][3])
for _, x in ipairs(ALL) do
  if x._scripts.OnEnter then x._scripts.OnEnter(x) end
end
`, "=grimoire sans api");

// ---------------------------------------------------------------- 10. V1 lot A : accueil, barres d'action, bilan de sante
// Faux emplacements d'action : SLOTS[slot] = { type, id }. Le curseur porte { type, id } ; PlaceAction echange comme le jeu.
const BARS = String.raw`
SLOTS = {}
PLACE_OK = true     -- false : le jeu ignore PlaceAction (pose refusee)
RELATED = false     -- true : GetActionInfo rend pour une macro un identifiant qui n'est pas son index
PLACES = 0
local function valid(slot) assert(type(slot) == "number" and ((slot >= 1 and slot <= 120) or (slot >= 145 and slot <= 180)), "emplacement invalide : " .. tostring(slot)) end
function GetActionInfo(slot)
  valid(slot)
  local a = SLOTS[slot]
  if not a then return nil end
  if a[1] == "macro" and RELATED then return "macro", 5000 + a[2], "spell" end
  return a[1], a[2]
end
function GetActionText(slot)
  local a = SLOTS[slot]
  if a and a[1] == "macro" then
    for name, m in pairs(MACROS) do if m.index == a[2] then return name end end
  end
end
function GetActionTexture(slot) return SLOTS[slot] and 134400 or nil end
function PickupMacro(x)
  assert(not COMBAT, "PickupMacro en combat")
  local index = type(x) == "number" and x or GetMacroIndexByName(x)
  CALLS[#CALLS + 1] = { "PickupMacro", x }
  CURSOR = { "macro", index }
end
function PickupAction(slot) valid(slot) assert(not COMBAT) CURSOR = SLOTS[slot] or {} SLOTS[slot] = nil end
function PlaceAction(slot)
  valid(slot)
  assert(not COMBAT, "PlaceAction en combat")
  PLACES = PLACES + 1
  if not PLACE_OK or not CURSOR[1] then return end
  local old = SLOTS[slot]
  SLOTS[slot] = { CURSOR[1], CURSOR[2] }
  CURSOR = old or {}
end
-- comme le jeu : les index suivants reculent d'un cran, la macro quitte les barres
function DeleteMacro(index)
  assert(not COMBAT, "DeleteMacro en combat")
  local gone
  for name, m in pairs(MACROS) do if m.index == index then gone = name end end
  assert(gone, "DeleteMacro : index inconnu " .. tostring(index))
  MACROS[gone] = nil
  local char = index > 120
  for _, m in pairs(MACROS) do
    if m.index > index and (m.index > 120) == char then m.index = m.index - 1 end
  end
  for slot, a in pairs(SLOTS) do
    if a[1] == "macro" then
      if a[2] == index then SLOTS[slot] = nil
      elseif a[2] > index and (a[2] > 120) == char then a[2] = a[2] - 1 end
    end
  end
  CALLS[#CALLS + 1] = { "DeleteMacro", gone }
end
SPELLS = { [172] = "Corruption", [5782] = "Peur", [2061] = "Soins rapides", [2060] = "Soins rapides", [139] = "Rénovation" }
BEST = { Corruption = 172, Peur = 5782, ["Soins rapides"] = 2061, ["Rénovation"] = 139 } -- plus haut rang connu
local baseName = C_Spell.GetSpellName
C_Spell.GetSpellName = function(id) return SPELLS[id] or baseName(id) end
C_Spell.GetSpellInfo = function(name) if BEST[name] then return { spellID = BEST[name] } end end
C_Spell.GetSpellSubtext = function(id) return id == 2060 and "Rang 2" or id == 2061 and "Rang 3" or "" end
C_Spell.IsSpellHarmful = function(name) return name == "Corruption" or name == "Peur" end
C_Spell.IsSpellHelpful = function(name) return name == "Soins rapides" or name == "Rénovation" end
C_Spell.PickupSpell = function(id) assert(not COMBAT) CURSOR = { "spell", id } end
C_Item.PickupItem = function(id) assert(not COMBAT) CURSOR = { "item", id } end
C_Item.GetItemNameByID = function(id) return id == 5512 and "Pierre de soins" or nil end
BOOK = { "Corruption", "Peur", "Soins rapides", "Rénovation" }
C_SpellBook = {
  GetNumSpellBookSkillLines = function() return 1 end,
  GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = #BOOK } end,
  GetSpellBookItemName = function(i) return BOOK[i] end,
}
Enum = { SpellBookSpellBank = { Player = 0 } }
function slotIs(slot, kind, id) local a = SLOTS[slot] return (a == nil and kind == nil) or (a ~= nil and a[1] == kind and a[2] == id) end
function accept(which) -- le joueur clique « Oui » sur la derniere confirmation
  local p = POPUPS[#POPUPS]
  assert(p and p.which == which, "confirmation attendue : " .. which .. ", recue : " .. tostring(p and p.which))
  StaticPopupDialogs[which].OnAccept(nil, p.data)
end
`;
boot("{ tutorialSeen = true }", BARS);
run(String.raw`
local ns, db = NS, BlockForgeDB
local function said(fragment) return lastLine():find(fragment, 1, true) ~= nil end
local function count(kind) local n = 0 for _, c in ipairs(CALLS) do if c[1] == kind then n = n + 1 end end return n end
-- macros du joueur et barres de depart
CreateMacro("Vieille", 1, "/cast Peurr")
CreateMacro("Double1", 1, "/cast Peur")
CreateMacro("Double2", 1, " /cast  Peur ")
CreateMacro("Orph", 1, "/cast Corruption")
CreateMacro("Risque", 1, "/cast [combat,nocombat] Peur")
SLOTS[1], SLOTS[2], SLOTS[3], SLOTS[4] = { "spell", 172 }, { "spell", 2061 }, { "item", 5512 }, { "companion", 3 }
SLOTS[5], SLOTS[14], SLOTS[26], SLOTS[61] = { "macro", MACROS.Double1.index }, { "spell", 2060 }, { "spell", 139 }, { "spell", 5782 }
BINDINGS["1"], BINDINGS["F5"] = "ACTIONBUTTON1", "MACRO Double2"
-- suggestions : trois macros de bibliotheque pour ce personnage, dont deux deja possedees (par le texte, par le nom)
table.insert(ns.Library, 1, { class = "WARLOCK", category = "PvE", name = "Sugg texte", body = "/cast  Corruption", desc = "d1" })
table.insert(ns.Library, 2, { class = "WARLOCK", category = "PvE", name = "double1", body = "/cast Peur\n/use 13", desc = "d2" })
table.insert(ns.Library, 3, { class = "WARLOCK", category = "PvE", name = "Sugg neuve", body = "/cast Peur\n/use 14", desc = "d3" })
table.insert(ns.Library, 4, { class = "WARLOCK", category = "PvE", name = "Sugg inconnue", body = "/cast Sort inconnu", desc = "d4" })

-- 1. la fenetre s'ouvre sur l'accueil ; les cinq onglets tiennent sans se chevaucher ni toucher les boutons de l'editeur
SlashCmdList.BLOCKFORGE("")
local w, home = ns.ed.w, ns.home
local labels = { "Accueil", "Éditeur", "Bibliothèque", "Mes macros", "Paramètres" }
local tabs, x = {}, {}
for i, label in ipairs(labels) do
  tabs[i] = byText(label, BlockForgeFrame)
  assert(tabs[i]._parent == BlockForgeFrame and tabs[i]._w == 118 and tabs[i]._point[1] == "TOPLEFT" and tabs[i]._point[3] == -33, "onglet " .. label)
  x[i] = tabs[i]._point[2]
end
for i = 1, 4 do assert(x[i] + 118 <= x[i + 1], "onglets qui se chevauchent : " .. i) end
assert(x[1] == 10 and x[5] + 118 == 616)
-- boutons de l'editeur : page a 8, large de 884 ; assistant de 772 a 892, grimoire de 646 a 766 dans la fenetre
assert(w.assistantButton._point[1] == "BOTTOMRIGHT" and w.assistantButton._point[2] == w.page and w.assistantButton._w == 120 and w.grimoireButton._w == 120)
assert(w.grimoireButton._point[2] == w.assistantButton and w.grimoireButton._point[4] == -6)
assert(x[5] + 118 < 8 + 884 - 120 - 6 - 120, "les onglets touchent « Mon grimoire »")
assert(BlockForgeFrame._w == 900 and BlockForgeFrame._h == 640)
assert(tabs[1].line:IsShown() and not tabs[2].line:IsShown() and w.home:IsVisible() and not w.page:IsVisible(), "accueil non affiche par defaut")
-- /bf options et /bf assistant gardent leur onglet
SlashCmdList.BLOCKFORGE("options")
assert(tabs[5].line:IsShown())
SlashCmdList.BLOCKFORGE("assistant")
assert(tabs[2].line:IsShown() and ns.assistant:IsShown())
-- l'Assistant a aussi son entree vers « Ameliorer ma barre » ; /bf barre et /bf bilan ouvrent les deux outils
assert(ns.assistant.bars:IsShown() and ns.assistant.bars._w == 150 and ns.assistant.bars._point[2] == -34)
fire(ns.assistant.bars, "OnClick")
assert(ns.wand:IsShown() and not ns.assistant:IsShown() and tabs[1].line:IsShown())
SlashCmdList.BLOCKFORGE("bilan")
assert(ns.health:IsShown() and not ns.wand:IsShown())
SlashCmdList.BLOCKFORGE("barre")
assert(ns.wand:IsShown() and not ns.health:IsShown())
ns.wand:Hide()
fire(tabs[1], "OnClick")

-- 2. accueil : jauge, bilan en bref, entrees, suggestions
assert(home.gauge.text._text == "5 / 120 · 0 / 30" and home.gauge._parent == BlockForgeFrame and home.gauge:IsShown(), home.gauge.text._text)
assert(home.gauge._point[1] == "RIGHT" and home.gauge._point[2] == w.headerRight and home.gauge._point[3] == "LEFT")
assert(home.counts._text:find("5 / 120", 1, true) and home.counts._text:find("0 / 30", 1, true))
local real = GetNumMacros
GetNumMacros = function() return 103, 30 end
ns.RefreshHome()
assert(home.gauge.text._text == "103 / 120 · 30 / 30" and home.gauge.text._textColor[2] == 0.3, "jauge pleine non rouge")
GetNumMacros = function() return 103, 2 end
ns.RefreshHome()
assert(home.gauge.text._textColor[2] == 0.7, "jauge proche de la limite non orange")
GetNumMacros = real
ns.RefreshHome()
assert(home.gauge.text._textColor[1] == 0.8)
-- six entrees sur deux lignes de quatre : les kits et les profils (lot B) passent a la deuxieme, de -86 a -138 dans un panneau de 150
assert(#ns.HomeActions == 6 and #home.tiles == 6 and ns.HomeActions[5].id == "kits" and ns.HomeActions[6].id == "profiles")
for i, tile in ipairs(home.tiles) do
  assert(tile._w == 212 and tile._h == 52 and tile._point[2] == 8 + ((i - 1) % 4) * 218 and tile._point[3] == -28 - math.floor((i - 1) / 4) * 58 and tile.text._text == ns.HomeActions[i].title)
end
assert(home.tiles[4]._point[2] + 212 <= 884 - 8 and home.tiles[6]._point[3] - 52 >= -147, "tuiles hors du panneau")
-- bilan en bref : Vieille cassee, Double2 en double, orphelines : Vieille, Orph, Risque ; a risque : Risque
local function chip(i) return home.healthChips[i].text._text end
assert(chip(1) == "Cassées : 1" and chip(2) == "Doublons : 1" and chip(3) == "Orphelines : 3" and chip(4) == "À risque : 1", chip(1) .. chip(2) .. chip(3) .. chip(4))
-- suggestions : sorts tous connus, ni le texte ni le nom deja possedes
assert(#home.suggestions >= 1 and #home.suggestions <= 5 and home.suggestions[1].name == "Sugg neuve", home.suggestions[1] and home.suggestions[1].name)
for _, s in ipairs(home.suggestions) do
  assert(s.name ~= "Sugg texte" and s.name ~= "double1" and s.name ~= "Sugg inconnue", "suggestion deja possedee ou inutilisable : " .. s.name)
  assert(#ns.LibraryUnknown(s.entry) == 0)
end
assert(home.rows[1]:IsShown() and home.rows[1].text._text == "Sugg neuve" and home.rows[1].desc._text == "d3")
-- « Ouvrir » la met dans l'editeur ; « Creer » en fait une macro du jeu, et elle quitte les suggestions
fire(home.rows[1].open, "OnClick")
assert(tabs[2].line:IsShown() and ns.Compile(ns.ed.Blocks()) == "/cast Peur\n/use 14")
fire(tabs[1], "OnClick")
db.pickupAfterCreate = false
fire(home.rows[1].create, "OnClick")
assert(MACROS["Sugg neuve"] and MACROS["Sugg neuve"].body == "/cast Peur\n/use 14", "suggestion non creee")
for _, s in ipairs(home.suggestions) do assert(s.name ~= "Sugg neuve", "suggestion creee encore proposee") end
DeleteMacro(MACROS["Sugg neuve"].index)
ns.RefreshHome()

-- 3. « Ameliorer ma barre » : notre image des barres
fire(home.tiles[2], "OnClick")
local wand = ns.wand
assert(wand and wand:IsShown() and wand._parent == w.home and wand._w == 884 and wand._h == 566 and #wand.cells == 120, "panneau des barres")
local function cell(slot) return wand.cells[slot] end
for i, c in ipairs(wand.cells) do
  assert(c.slot == i and c._w == 34 and c._point[2] == 68 + ((i - 1) % 12) * 36 and c._point[3] == -46 - math.floor((i - 1) / 12) * 36, "case " .. i)
end
assert(cell(120)._point[2] + 34 <= 498 and -cell(120)._point[3] + 34 <= 520, "la grille deborde")
assert(cell(1).entry.kind == "spell" and cell(1).entry.name == "Corruption" and cell(1).key._text == "1" and cell(1).icon._tex == 134400)
assert(cell(3).entry.kind == "item" and cell(3).entry.name == "Pierre de soins" and cell(4).entry.kind == "other" and cell(6).entry.kind == "empty")
assert(cell(5).entry.kind == "macro" and cell(5).entry.macroName == "Double1" and cell(5)._border[1] == 0.53, "macro non reconnue sur la barre")
assert(wand.undo._enabled == false and wand.undo._text == "Rien à annuler" and not wand.confirm:IsShown())
-- un emplacement vide ou d'un autre type n'ouvre rien
local calls, places = #CALLS, PLACES
fire(cell(4), "OnClick")
fire(cell(6), "OnClick")
assert(wand:IsShown() and wand.status._text:find("vide", 1, true) and #CALLS == calls and PLACES == places and not (ns.assistant and ns.assistant:IsShown()))
-- une macro s'ouvre dans l'editeur
fire(cell(5), "OnClick")
assert(tabs[2].line:IsShown() and ns.ed.Name() == "Double1")

-- 4. un sort : l'Assistant en mode « emplacement », la macro prend sa place, « Annuler » remet le sort et supprime la macro
ns.OpenWand()
fire(cell(1), "OnClick")
local panel = ns.assistant
assert(panel:IsShown() and not wand:IsShown() and panel.state.slot == 1 and panel.title._text == "Assistant — emplacement 1 de ta barre", panel.title._text)
assert(panel.state.kind == "harm" and panel.cards[1].create._text == "Créer et poser" and panel.cards[1].title._text == "Survol, sinon cible")
fire(panel.cards[1].create, "OnClick")
local made = MACROS.Corruption
assert(made and made.body == "#showtooltip\n/cast [@mouseover,harm,nodead][] Corruption" and slotIs(1, "macro", made.index), "macro non posee a la place du sort")
assert(CURSOR[1] == nil, "le curseur garde quelque chose")
assert(said("emplacement 1") and wand:IsShown() and not panel:IsShown() and cell(1).entry.macroName == "Corruption")
assert(BlockForgeDB.undo == db.undo and db.undo.label == "« Corruption » sur l'emplacement 1" and #db.undo.ops == 2, "annulation non enregistree dans BlockForgeDB")
assert(db.undo.ops[2].op == "slot" and db.undo.ops[2].before.kind == "spell" and db.undo.ops[2].before.id == 172 and db.undo.ops[1].op == "created")
assert(wand.undo._enabled == true and wand.undo._text == "Annuler : « Corruption » sur l'emplacement 1")
fire(wand.undo, "OnClick")
assert(slotIs(1, "spell", 172) and MACROS.Corruption == nil and db.undo == false and CURSOR[1] == nil, "annulation incomplete")
assert(wand.undo._enabled == false and cell(1).entry.kind == "spell")
-- un autre sort choisi dans la grille de l'Assistant quitte le mode « emplacement » : simple creation
fire(cell(1), "OnClick")
panel.grid.Fill()
fire(panel.grid.cells[2], "OnClick")
assert(panel.state.slot == nil and panel.title._text == "Assistant" and panel.cards[1].create._text == "Créer la macro")
panel:Hide()

-- 5. une macro du meme nom au texte different : confirmation, puis « Annuler » lui rend son texte sans la supprimer
CreateMacro("Peur", 1, "/cast Peur")
ns.OpenWand()
fire(cell(61), "OnClick")
local popups = #POPUPS
fire(panel.cards[1].create, "OnClick")
assert(#POPUPS == popups + 1 and POPUPS[#POPUPS].which == "BLOCKFORGE_BAR_OVERWRITE" and slotIs(61, "spell", 5782) and MACROS.Peur.body == "/cast Peur", "ecrasement sans confirmation")
accept("BLOCKFORGE_BAR_OVERWRITE")
assert(slotIs(61, "macro", MACROS.Peur.index) and MACROS.Peur.body:find("@mouseover", 1, true) and wand:IsShown())
assert(db.undo.ops[1].op == "edit" and db.undo.ops[1].body == "/cast Peur")
fire(wand.undo, "OnClick")
assert(slotIs(61, "spell", 5782) and MACROS.Peur and MACROS.Peur.body == "/cast Peur", "la macro qui existait doit rester, avec son ancien texte")

-- 6. l'autre convention de GetActionInfo (identifiant qui n'est pas l'index) : pose verifiee par le nom, annulation comprise
RELATED = true
fire(cell(1), "OnClick")
fire(panel.cards[1].create, "OnClick")
assert(slotIs(1, "macro", MACROS.Corruption.index) and cell(1).entry.macroName == "Corruption" and cell(1).entry.how == "name" and cell(5).entry.macroName == "Double1")
fire(wand.undo, "OnClick")
assert(slotIs(1, "spell", 172) and MACROS.Corruption == nil)
RELATED = false

-- 7. plan B : le jeu ignore la pose. La macro est creee, laissee sous le curseur, l'emplacement intact ; « Annuler » la supprime
PLACE_OK = false
fire(cell(1), "OnClick")
fire(panel.cards[1].create, "OnClick")
assert(MACROS.Corruption and slotIs(1, "spell", 172) and CURSOR[1] == "macro" and CURSOR[2] == MACROS.Corruption.index, "plan B : macro sous le curseur")
assert(said("sous ton curseur") and said("emplacement 1") and #db.undo.ops == 1 and db.undo.ops[1].op == "created")
PLACE_OK = true
ClearCursor()
fire(wand.undo, "OnClick")
assert(MACROS.Corruption == nil and slotIs(1, "spell", 172))
-- relecture differente de la macro attendue : l'emplacement revient a son contenu, plan B
local realText = GetActionText
GetActionText = function() return "Autre chose" end
RELATED = true
local ok, why = ns.Bars.Place(1, MACROS.Orph.index, "Orph")
assert(ok == false and why == "verify" and CURSOR[1] == nil, tostring(why))
GetActionText, RELATED = realText, false
assert(slotIs(1, "spell", 172), "emplacement non restaure apres une verification ratee")
-- emplacements jamais touches : autre type, vide non designe, numero hors plage
assert(select(2, ns.Bars.Place(4, MACROS.Orph.index, "Orph")) == "kind" and slotIs(4, "companion", 3))
assert(select(2, ns.Bars.Place(6, MACROS.Orph.index, "Orph")) == "kind" and slotIs(6))
for _, bad in ipairs({ 0, 121, 144, 181, 1.5, "1" }) do
  assert(select(2, ns.Bars.Place(bad, MACROS.Orph.index, "Orph")) == "slot" and ns.Bars.Restore(bad, { kind = "empty" }) == false)
end
-- vide designe par le joueur : pose, puis remise a vide
assert(ns.Bars.Place(6, MACROS.Orph.index, "Orph", nil, true) == true and slotIs(6, "macro", MACROS.Orph.index))
assert(ns.Bars.Restore(6, { kind = "empty" }) == true and slotIs(6))

-- 8. combat : rien ne se lit, ne se pose, ne s'annule
db.undo = { owner = NS.CharKey(), label = "test", ops = { { op = "slot", slot = 1, before = { kind = "spell", id = 172 }, macro = "X" } } }
COMBAT = true
calls, places = #CALLS, PLACES
ns.OpenWand()
assert(said("combat"))
assert(ns.Bars.Scan() == nil and select(2, ns.Bars.Place(1, 1, "Orph")) == "combat" and ns.Bars.Restore(1, { kind = "spell", id = 172 }) == false)
ns.Bars.Upgrade(1, "Corruption", "/cast Corruption")
assert(said("combat"))
ns.Bars.Convert({ items = {}, need = 0 }, "x")
assert(said("combat"))
ns.RunUndo()
assert(said("combat") and db.undo ~= false, "annulation perdue en combat")
ns.OpenHealth()
assert(said("combat"))
ns.Health.DoArchive({ MACROS.Orph }, {})
ns.Health.Repair({ macro = { name = "Vieille", body = "/cast Peurr" }, fix = { "Peurr", "Peur" } })
assert(#CALLS == calls and PLACES == places and MACROS.Orph and MACROS.Vieille.body == "/cast Peurr", "action en combat")
-- le panneau ouvert se ferme a l'entree en combat
COMBAT = false
db.undo = false
ns.OpenWand()
fireEvent("PLAYER_REGEN_DISABLED")
assert(not wand:IsShown())

-- 9. conversion en masse des sorts d'aide : apercu, compte, une confirmation, une annulation globale
ns.OpenWand()
fire(byText("Passer mes sorts d'aide au survol", wand), "OnClick")
local plan = wand.state.plan
assert(#plan.items == 3 and plan.need == 3 and #plan.skipped == 0, #plan.items)
assert(wand.previewTitle._text == "Aperçu : 3 emplacement(s) à convertir" and wand.confirm:IsShown() and wand.confirm._text == "Convertir (3)" and wand.confirm._enabled == true)
assert(wand.rows[1]._text == "2 : Soins rapides  ->  macro « Soins rapides »", wand.rows[1]._text)
-- un rang inferieur au plus haut connu est garde dans la macro, avec un nom a part
assert(wand.rows[2]._text == "14 : Soins rapides(Rang 2)  ->  macro « Soins rapides 2 »", wand.rows[2]._text)
assert(wand.rows[3]._text == "26 : Rénovation  ->  macro « Rénovation »" and wand.rows[4]._text == "")
assert(wand.need._text == "Macros à créer : 3 · places libres : 114", wand.need._text)
assert(slotIs(2, "spell", 2061) and not MACROS["Soins rapides"], "l'apercu ne change rien")
-- pas assez de place : refus, bouton grise
GetNumMacros = function() return 118, 0 end
fire(byText("Passer mes sorts d'aide au survol", wand), "OnClick")
assert(wand.confirm._enabled == false and wand.need._textColor[2] == 0.3 and wand.need._text:find("places libres : 2", 1, true))
calls = #CALLS
assert(ns.Bars.Convert(wand.state.plan, "x") == nil and said("Pas assez de place : 3 macros à créer, 2 places libres") and #CALLS == calls)
GetNumMacros = real
fire(byText("Passer mes sorts d'aide au survol", wand), "OnClick")
fire(wand.confirm, "OnClick")
assert(slotIs(2, "macro", MACROS["Soins rapides"].index) and slotIs(14, "macro", MACROS["Soins rapides 2"].index) and slotIs(26, "macro", MACROS["Rénovation"].index))
assert(MACROS["Soins rapides"].body == "#showtooltip\n/cast [@mouseover,help,nodead][help,nodead][@player] Soins rapides")
assert(MACROS["Soins rapides 2"].body:find("Soins rapides(Rang 2)", 1, true))
assert(wand.state.plan == nil and not wand.confirm:IsShown() and wand.status._text:find("3 emplacement(s) converti(s), 0", 1, true) and CURSOR[1] == nil)
assert(#db.undo.ops == 6 and db.undo.label == "sorts d'aide au survol" and wand.undo._text == "Annuler : sorts d'aide au survol")
-- les sorts offensifs ne sont pas touches par la conversion des aides
assert(slotIs(1, "spell", 172) and slotIs(61, "spell", 5782) and slotIs(3, "item", 5512) and slotIs(4, "companion", 3))
-- une seconde conversion ne trouve plus rien
fire(byText("Passer mes sorts d'aide au survol", wand), "OnClick")
assert(#wand.state.plan.items == 0 and wand.confirm._enabled == false)
fire(byText("Fermer l'aperçu", wand), "OnClick")
assert(wand.state.plan == nil)
fire(wand.undo, "OnClick")
assert(slotIs(2, "spell", 2061) and slotIs(14, "spell", 2060) and slotIs(26, "spell", 139), "annulation globale : emplacements")
assert(not MACROS["Soins rapides"] and not MACROS["Soins rapides 2"] and not MACROS["Rénovation"] and db.undo == false, "annulation globale : macros")
-- sorts offensifs : la macro « Peur » du joueur porte deja ce nom avec un autre texte, elle n'est pas ecrasee en masse
fire(byText("Passer mes sorts offensifs au survol", wand), "OnClick")
plan = wand.state.plan
assert(#plan.items == 1 and plan.items[1].slot == 1 and #plan.skipped == 1 and plan.skipped[1].slot == 61 and plan.skipped[1].skip == "name")
assert(wand.rows[2]._text:find("laissé", 1, true))
fire(wand.confirm, "OnClick")
assert(slotIs(1, "macro", MACROS.Corruption.index) and slotIs(61, "spell", 5782) and MACROS.Peur.body == "/cast Peur")
-- un emplacement change par le joueur depuis n'est pas touche par l'annulation, et la macro posee ailleurs reste
SLOTS[1], SLOTS[7] = { "spell", 5782 }, { "macro", MACROS.Corruption.index }
fire(wand.undo, "OnClick")
assert(slotIs(1, "spell", 5782) and MACROS.Corruption and slotIs(7, "macro", MACROS.Corruption.index) and said("0 étape(s) rétablie(s), 2 laissée(s)"), lastLine())
SLOTS[1], SLOTS[7] = { "spell", 172 }, nil
DeleteMacro(MACROS.Corruption.index)
DeleteMacro(MACROS.Peur.index)

-- 10. bilan de sante
fire(tabs[1], "OnClick")
ns.RefreshHome()
fire(home.healthChips[1], "OnClick")
local health = ns.health
assert(health and health:IsShown() and not wand:IsShown() and health._parent == w.home and health._w == 884 and health.state.group == "broken")
for i, c in ipairs(health.chips) do assert(c._w == 212 and c._point[2] == 8 + (i - 1) * 218) end
assert(health.chips[4]._point[2] + 212 <= 876 and health.chips[1].text._text == "Cassées : 1" and health.chips[3].text._text == "Orphelines : 3")
assert(health.rows[1]:IsShown() and health.rows[1].text._text == "Vieille" and not health.rows[2]:IsShown())
assert(health.rows[1].reason._text == "Sort inconnu : « Peurr ». Le plus proche dans ton grimoire : « Peur ».", health.rows[1].reason._text)
assert(health.open._enabled == false and health.repair._enabled == false and health.archive._enabled == false)
fire(health.rows[1], "OnClick")
assert(health.name._text == "Vieille" and health.open._enabled and health.repair._enabled and health.archive._enabled and health.info._text:find("Sur aucune barre", 1, true))
-- reparer : le nom proche remplace le nom inconnu ; « Annuler » remet l'ancien texte
fire(health.repair, "OnClick")
assert(MACROS.Vieille.body == "/cast Peur" and said("réparée") and db.undo.ops[1].op == "edit" and health.chips[1].text._text == "Cassées : 0")
assert(health.undo._enabled and health.undo._text == "Annuler : réparation de « Vieille »")
fire(health.undo, "OnClick")
assert(MACROS.Vieille.body == "/cast Peurr" and db.undo == false and health.chips[1].text._text == "Cassées : 1" and health.undo._enabled == false)
-- ouvrir
fire(health.rows[1], "OnClick")
fire(health.open, "OnClick")
assert(tabs[2].line:IsShown() and ns.ed.Name() == "Vieille")
-- doublons et a risque
ns.OpenHealth("duplicates")
assert(health.rows[1].text._text == "Double2" and health.rows[1].reason._text == "Même texte que « Double1 ».")
fire(health.chips[4], "OnClick")
assert(health.state.group == "risky" and health.rows[1].text._text == "Risque" and health.rows[1].reason._text:find("contradictoires", 1, true))
-- nom que rien n'explique : « peut-etre », sans reparation
CreateMacro("Mystere", 1, "/cast Zzzzzzzz")
ns.OpenHealth("broken")
fire(health.rows[2], "OnClick")
assert(health.name._text == "Mystere" and health.reason._text:find("peut-être", 1, true) and health.repair._enabled == false, health.reason._text)
DeleteMacro(MACROS.Mystere.index)

-- 11. archiver : confirmation qui nomme le nombre, copie dans « Mes modeles » AVANT la suppression, annulation qui recree
ns.OpenHealth("duplicates")
fire(health.rows[1], "OnClick")
local personal, deletes = #db.personal, count("DeleteMacro")
fire(health.archive, "OnClick")
assert(POPUPS[#POPUPS].which == "BLOCKFORGE_ARCHIVE" and POPUPS[#POPUPS].text:find("Archiver 1 macro(s)", 1, true), POPUPS[#POPUPS].text)
assert(MACROS.Double2 and #db.personal == personal and count("DeleteMacro") == deletes, "suppression sans confirmation")
accept("BLOCKFORGE_ARCHIVE")
assert(MACROS.Double2 == nil and #db.personal == personal + 1 and db.personal[#db.personal].name == "Double2" and db.personal[#db.personal].body == " /cast  Peur ", "archive absente")
assert(said("1 macro(s) archivée(s)") and db.undo.ops[1].op == "delete" and health.chips[2].text._text == "Doublons : 0")
fire(health.undo, "OnClick")
assert(MACROS.Double2 and MACROS.Double2.body == " /cast  Peur " and #db.personal == personal + 1, "macro non recreee, ou copie retiree")
-- la meme macro archivee deux fois : une seule copie ; un modele de meme nom au texte different n'est jamais ecrase
assert(ns.ArchivePersonal("Double2", " /cast  Peur ") == "Double2" and #db.personal == personal + 1)
assert(ns.ArchivePersonal("Double2", "/cast Autre") == "Double2 ~2" and #db.personal == personal + 2 and db.personal[personal + 1].body == " /cast  Peur ")
-- une macro posee sur une barre : l'annulation lui rend son emplacement reste vide
ns.OpenHealth("duplicates")
local first
for _, m in ipairs(ns.ReadMacros()) do if m.name == "Double1" then first = m end end
assert(slotIs(5, "macro", first.index))
ns.Health.Archive({ first }, health.state.report.usage)
accept("BLOCKFORGE_ARCHIVE")
assert(MACROS.Double1 == nil and slotIs(5) and db.undo.ops[1].slots[1] == 5)
ns.RunUndo()
assert(MACROS.Double1 and slotIs(5, "macro", MACROS.Double1.index), "macro non reposee sur sa barre")
-- bibliotheque pleine : pas de copie, donc pas de suppression
local kept = db.personal
db.personal = {}
for i = 1, 200 do db.personal[i] = { name = "M" .. i, body = "/x" } end
ns.personalCache = nil
ns.Health.DoArchive({ ns.ReadMacros()[1] }, {})
assert(MACROS.Vieille and said("0 macro(s) archivée(s)") and said("1 laissée(s)"), lastLine())
db.personal = kept
ns.personalCache = nil
-- sans DeleteMacro (client qui ne l'a pas) : refus, rien n'est archive pour rien
local del = DeleteMacro
DeleteMacro = nil
popups = #POPUPS
ns.Health.Archive({ ns.ReadMacros()[1] }, {})
assert(#POPUPS == popups and said("supprimer"))
DeleteMacro = del

-- 12. archiver les orphelines : une confirmation avec leur nombre, une annulation globale
ns.OpenHealth("orphans")
local orphans = {}
for i, item in ipairs(health.state.report.orphans) do orphans[i] = item.macro.name end
table.sort(orphans)
assert(table.concat(orphans, ",") == "Orph,Risque,Vieille", table.concat(orphans, ","))
assert(health.bulk._enabled and health.bulk._text == "Archiver les orphelines… (3)")
personal = #db.personal
fire(health.bulk, "OnClick")
assert(POPUPS[#POPUPS].text:find("Archiver 3 macro(s)", 1, true) and MACROS.Orph and MACROS.Risque and MACROS.Vieille)
accept("BLOCKFORGE_ARCHIVE")
assert(not MACROS.Orph and not MACROS.Risque and not MACROS.Vieille and MACROS.Double1 and MACROS.Double2 and #db.personal == personal + 3, "orphelines non archivees")
assert(#db.undo.ops == 3 and db.undo.label == "archivage de 3 macro(s)" and health.bulk._enabled == false and health.bulk._text == "Archiver les orphelines… (0)")
for _, name in ipairs(orphans) do
  local found
  for _, m in ipairs(db.personal) do if m.name == name then found = m end end
  assert(found and found.note == "Archivée par le bilan de santé.", "copie absente : " .. name)
end
fire(health.undo, "OnClick")
assert(MACROS.Orph and MACROS.Orph.body == "/cast Corruption" and MACROS.Risque and MACROS.Vieille and MACROS.Vieille.body == "/cast Peurr" and db.undo == false)
assert(slotIs(5, "macro", MACROS.Double1.index), "les index ont bouge : la macro de la barre doit rester la meme")
-- une macro de barre que BlockForge ne sait pas identifier : aucune orpheline annoncee, archivage en masse grise
SLOTS[30] = { "macro", 140 }
ns.OpenHealth("orphans")
assert(health.state.report.orphansKnown == false and #health.state.report.orphans == 0 and health.bulk._enabled == false and health.empty:IsShown() and health.empty._text:find("pas pu lire", 1, true))
SLOTS[30] = nil

-- 13. /bf test : sondes en lecture seule
local slotsBefore = {}
for slot, a in pairs(SLOTS) do slotsBefore[slot] = a[1] .. a[2] end
calls, places = #CALLS, PLACES
local keysBefore = BINDINGS.F5
GetLocale = function() return "frFR" end -- lu par l'autotest
SlashCmdList.BLOCKFORGE("test")
local text = table.concat(db.selftest.lines, "\n")
assert(text:find("OK tab home", 1, true) and text:find("INFO probe bars: 120 slots read, 8 with content (5 spells, 1 items, 1 macros, 1 other)", 1, true), text)
assert(text:find("INFO probe P4 GetActionInfo(5) = macro, id " .. MACROS.Double1.index .. ", subtype nil", 1, true) and text:find("identified by index as Double1", 1, true), text)
assert(text:find("OK macros on bars identified: 1 / 1", 1, true) and text:find("INFO probe bindings: ACTIONBUTTON1=1", 1, true) and text:find("1 macros bound to a key", 1, true), text)
assert(text:find("INFO probe actions: PlaceAction present, PickupAction present, PickupMacro present, DeleteMacro present", 1, true), text)
assert(text:find("INFO probe P6 spec: C_SpecializationInfo absent", 1, true) and text:find("INFO probe P10 C_EncodingUtil: absent", 1, true), text)
assert(text:find("INFO probe P13 secure button: SecureActionButtonTemplate created", 1, true) and text:find("INFO probe P11 compartment:", 1, true), text)
assert(text:find("INFO probe P7 conditions: SecureCmdOptionParse absent", 1, true), text)
assert(text:find("OK home tab: 6 entries", 1, true) and text:find("INFO health: 5 macros, 1 broken, 1 duplicates, 3 orphans (bars fully read: true), 1 at risk", 1, true), text)
assert(text:find("INFO features: home=on, bars=on, health=on, suggestions=on, gauge=on, assistant=on, grimoire=on, share=on, tutorial=on, colorize=on", 1, true), text)
assert(text:find("INFO optional api present: GetActionInfo", 1, true) and text:find("INFO optional api absent: C_ActionBar.PutActionInSlot", 1, true))
assert(not text:find("FAIL v1", 1, true), text)
-- lot B : jetons, ID embarques, kits, profils, export « BF2: » ; toujours sans rien toucher
assert(text:find("INFO living tokens (level 60, 0 bag items): potion_soin=none", 1, true) and text:find("INFO living item ids without a name (not cached yet, or wrong id): 0 / 69", 1, true), text)
assert(text:find("OK kits: 27, dangling references or bad counts: 0", 1, true) and text:find("INFO kit of this class (leveling, mouseover, pet): 16 macros", 1, true), text)
assert(text:find("INFO profiles: 0 (0 automatic backups, 0 from other characters)", 1, true) and text:find("spec API active group nil", 1, true), text)
assert(text:find("OK BF2 profile round trip: 20 macros", 1, true) and text:find("plain (C_EncodingUtil absent)", 1, true) and text:find("INFO optional api absent: C_Timer.After", 1, true), text)
assert(#CALLS == calls and PLACES == places and BINDINGS.F5 == keysBefore and CURSOR[1] == nil, "l'autotest a touche aux barres ou aux macros")
for slot, a in pairs(SLOTS) do assert(slotsBefore[slot] == a[1] .. a[2], "emplacement change par l'autotest") end
-- la sonde ne cree le bouton securise qu'une fois
local widgets = #ALL
SlashCmdList.BLOCKFORGE("test")
assert(#ALL == widgets, "l'autotest cree des widgets a chaque passage")
-- sonde P7 quand le client a SecureCmdOptionParse
function SecureCmdOptionParse(s) if s:find("talent") then error("x") end return (s:find("^%[no") and not s:find("flyable")) and "N" or "Y" end
SlashCmdList.BLOCKFORGE("test")
text = table.concat(db.selftest.lines, "\n")
assert(text:find("combat=understood:Y", 1, true) and text:find("flyable=ignored:Y", 1, true) and text:find("talent:1/1=error", 1, true), text)

-- 14. toutes les infobulles
for _, x in ipairs(ALL) do
  if x._scripts.OnEnter then x._scripts.OnEnter(x) end
end
`, "=v1 lot A");

// client sans les API de barres (GetActionInfo, DeleteMacro...) : rien ne casse, les outils se refusent proprement
boot("{ tutorialSeen = true, undo = 5 }");
run(String.raw`
local ns, db = NS, BlockForgeDB
assert(db.undo == false, "annulation abimee non nettoyee")
CreateMacro("Seule", 1, "/cast Corruption")
SlashCmdList.BLOCKFORGE("")
local home = ns.home
assert(home and ns.ed.w.home:IsVisible() and home.gauge.text._text == "1 / 120 · 0 / 30")
-- barres illisibles : aucune orpheline annoncee
assert(home.report.orphansKnown == false and home.healthChips[3].text._text == "Orphelines : 0")
ns.OpenWand()
assert(lastLine():find("lire les barres", 1, true) and ns.wand == nil)
assert(ns.Bars.Scan() == nil and ns.Bars.Read(1) == nil and select(2, ns.Bars.Place(1, 1, "Seule")) == "api")
ns.Bars.Upgrade(1, "Seule", "/cast Peur")
assert(lastLine():find("lire les barres", 1, true) and MACROS.Seule.body == "/cast Corruption")
ns.OpenHealth()
assert(ns.health:IsShown() and ns.health.bulk._enabled == false)
ns.Health.Archive({ ns.ReadMacros()[1] }, {})
assert(lastLine():find("supprimer", 1, true) and MACROS.Seule and #POPUPS == 0)
GetLocale = function() return "frFR" end
SlashCmdList.BLOCKFORGE("test")
local text = table.concat(db.selftest.lines, "\n")
assert(text:find("INFO probe bars: GetActionInfo absent", 1, true) and text:find("OK tab home", 1, true) and not text:find("FAIL v1", 1, true), text)
`, "=sans barres");

// l'annulation survit a un /reload : relue dans BlockForgeDB
boot(`{ tutorialSeen = true, undo = { owner = "Moi-Royaume", label = "ancienne", ops = { { op = "edit", name = "M", char = false, body = "/cast Avant" }, { op = "inconnue" }, 7 } } }`, BARS);
run(String.raw`
local ns, db = NS, BlockForgeDB
CreateMacro("M", 1, "/cast Apres")
assert(ns.UndoLabel() == "ancienne")
SlashCmdList.BLOCKFORGE("")
ns.OpenWand()
assert(ns.wand.undo._enabled and ns.wand.undo._text == "Annuler : ancienne")
fire(ns.wand.undo, "OnClick")
assert(MACROS.M.body == "/cast Avant" and db.undo == false and lastLine():find("1 étape(s) rétablie(s), 2 laissée(s)", 1, true), lastLine())
-- une operation venue d'un fichier modifie a la main ne peut pas viser un emplacement hors plage
db.undo = { owner = NS.CharKey(), label = "x", ops = { { op = "slot", slot = 130, before = { kind = "empty" }, macro = "M" }, { op = "delete", name = string.rep("n", 17), body = "/x" } } }
local places, calls = PLACES, #CALLS
ns.RunUndo()
assert(PLACES == places and #CALLS == calls and db.undo == false)
`, "=annulation relue");

// ---------------------------------------------------------------- 11. fonctions coupees dans les Parametres
boot("{ tutorialSeen = true }", BARS);
run(String.raw`
local ns, db = NS, BlockForgeDB
local function said(fragment) return lastLine():find(fragment, 1, true) ~= nil end
local function refused() return said("fonction désactivée dans les Paramètres") end
CreateMacro("Vieille", 1, "/cast Peurr")
SLOTS[1] = { "spell", 172 }
SlashCmdList.BLOCKFORGE("")
local w, home = ns.ed.w, ns.home
local tabHome, tabEditor = byText("Accueil", BlockForgeFrame), byText("Éditeur", BlockForgeFrame)
-- Fonctions actives par defaut, rendues dans douze lignes reutilisables.
local ids = {}
for i, def in ipairs(ns.Features) do
  ids[i] = def.id
  assert(type(def.label) == "string" and type(def.desc) == "string" and ns.Enabled(def.id) == true, def.id)
end
assert(table.concat(ids, ",") == "home,bars,health,suggestions,gauge,assistant,grimoire,share,tutorial,colorize,living,kits,profiles,specProfiles,explain,translate,shorten,welcome,welcomeMotion", table.concat(ids, ","))
assert(ns.Enabled("inconnue") == true)
fire(byText("Paramètres", BlockForgeFrame), "OnClick")
local boxes = {}
for i, cb in ipairs(w.settings.featureList.rows) do
  boxes[cb.def.id] = cb
  assert(cb._checked == true and cb._point[3] == -(i - 1) * 26, cb.def.id)
  assert(-cb._point[3] + cb._h <= w.settings.featureList._h)
end
assert(#ns.Features == 19 and #w.settings.featureList.rows == 12)


-- tout est construit et ouvert une fois, pour verifier ensuite que les evenements sont retires
ns.OpenWand()
ns.OpenHealth()
ns.Open("editor")
ns.ToggleGrimoire()
SlashCmdList.BLOCKFORGE("assistant")
ns.assistant:Hide()
local function listens(frame, event) return frame._events[event] == true end
assert(listens(ns.wand, "ACTIONBAR_SLOT_CHANGED") and listens(ns.health, "UPDATE_MACROS") and listens(w.home, "UPDATE_MACROS"))
local shareFrame = find(function(x) return x._events.CHAT_MSG_ADDON end)
assert(shareFrame, "ecoute des macros recues absente")

-- bars : plus aucune ecriture sur les barres
ns.OpenWand()
click(boxes.bars, false)
assert(db.features.bars == false and not ns.Enabled("bars") and not ns.wand:IsShown() and not home.tiles[2]:IsShown(), "bars non coupee")
assert(not listens(ns.wand, "ACTIONBAR_SLOT_CHANGED") and not listens(ns.wand, "UPDATE_MACROS"))
-- les tuiles restantes se resserrent
assert(home.tiles[1]._point[2] == 8 and home.tiles[3]._point[2] == 226 and home.tiles[4]._point[2] == 444)
local calls, places = #CALLS, PLACES
ns.OpenWand()
assert(refused() and said("Améliorer ma barre") and not ns.wand:IsShown())
ns.Bars.Upgrade(1, "Corruption", "/cast Corruption")
assert(refused())
ns.Bars.Convert({ items = { { slot = 1, macroName = "Corruption", body = "/cast Corruption" } }, need = 1 }, "x")
assert(refused())
assert(select(2, ns.Bars.Place(1, MACROS.Vieille.index, "Vieille")) == "off" and ns.Bars.Restore(1, { kind = "spell", id = 172 }) == false)
ns.Bars.Cursor(MACROS.Vieille.index)
SlashCmdList.BLOCKFORGE("barre")
assert(refused() and not ns.assistant.bars:IsShown(), "entree de l'Assistant vers les barres encore visible")
-- l'Assistant ouvert sur un emplacement avant la coupure ne pose rien non plus
ns.OpenAssistant({ name = "Corruption", base = "Corruption", kind = "spell" }, 1)
fire(ns.assistant.cards[1].create, "OnClick")
assert(refused() and not MACROS.Corruption)
ns.assistant:Hide()
-- une annulation qui toucherait aux barres attend la reactivation
db.undo = { owner = NS.CharKey(), label = "pose", ops = { { op = "slot", slot = 1, before = { kind = "spell", id = 172 }, macro = "X" } } }
ns.RunUndo()
assert(refused() and db.undo ~= false)
db.undo = false
assert(#CALLS == calls and PLACES == places and CURSOR[1] == nil and slotIs(1, "spell", 172), "ecriture sur les barres alors que la fonction est coupee")
click(boxes.bars, true)
assert(home.tiles[2]:IsShown() and home.tiles[2]._point[2] == 226 and listens(ns.wand, "ACTIONBAR_SLOT_CHANGED"))
ns.OpenWand()
assert(ns.wand:IsShown())
ns.wand:Hide()

-- health : ni panneau, ni reparation, ni archivage, ni calcul sur l'accueil
ns.OpenHealth()
ns.SetFeature("health", false)
assert(not ns.health:IsShown() and not w.homeHealth:IsShown() and not listens(ns.health, "UPDATE_MACROS") and boxes.health._checked == false)
ns.OpenHealth()
assert(refused() and not ns.health:IsShown())
local popups = #POPUPS
ns.Health.Archive({ ns.ReadMacros()[1] }, {})
assert(refused() and #POPUPS == popups)
ns.Health.DoArchive({ ns.ReadMacros()[1] }, {})
assert(refused() and MACROS.Vieille)
ns.Health.Repair({ macro = ns.ReadMacros()[1], fix = { "Peurr", "Peur" } })
assert(refused() and MACROS.Vieille.body == "/cast Peurr")
local reports = 0
local realReport = ns.Health.Report
ns.Health.Report = function() reports = reports + 1 return realReport() end
ns.Open("home")
ns.RefreshHome()
assert(reports == 0, "le bilan tourne alors qu'il est coupe")
ns.SetFeature("health", true)
assert(w.homeHealth:IsShown() and reports == 1 and listens(ns.health, "UPDATE_MACROS"))
ns.Health.Report = realReport

-- suggestions
assert(w.homeSuggest:IsShown())
ns.SetFeature("suggestions", false)
assert(not w.homeSuggest:IsShown() and #home.suggestions == 0)
ns.SetFeature("suggestions", true)
assert(w.homeSuggest:IsShown())

-- gauge
ns.SetFeature("gauge", false)
assert(not home.gauge:IsShown() and listens(w.home, "UPDATE_MACROS"), "l'accueil ecoute encore pour lui-meme")
ns.SetFeature("gauge", true)
assert(home.gauge:IsShown())

-- home : l'onglet disparait, les autres se resserrent, la fenetre passe et s'ouvre sur l'editeur
ns.Open("home")
ns.SetFeature("home", false)
assert(not tabHome:IsShown() and tabEditor._point[2] == 10 and tabEditor.line:IsShown() and not w.home:IsVisible(), "accueil non coupe")
assert(byText("Paramètres", BlockForgeFrame)._point[2] == 10 + 3 * 122)
assert(listens(w.home, "UPDATE_MACROS"), "la jauge de l'en-tete ecoute encore")
ns.SetFeature("gauge", false)
assert(not listens(w.home, "UPDATE_MACROS") and not listens(w.home, "PLAYER_REGEN_ENABLED"), "accueil et jauge coupes : plus aucune ecoute")
ns.SetFeature("gauge", true)
SlashCmdList.BLOCKFORGE("")
SlashCmdList.BLOCKFORGE("")
assert(BlockForgeFrame:IsShown() and tabEditor.line:IsShown())
ns.SetFeature("home", true)
assert(tabHome:IsShown() and tabHome._point[2] == 10 and tabEditor._point[2] == 132)

-- assistant
ns.Open("editor")
ns.SetFeature("assistant", false)
assert(not w.assistantButton:IsShown() and w.grimoireButton:IsShown() and not home.tiles[1]:IsShown() and home.tiles[2]._point[2] == 8)
SlashCmdList.BLOCKFORGE("assistant")
assert(refused() and said("Assistant") and not ns.assistant:IsShown())
assert(not listens(ns.assistant.grid.frame, "SPELLS_CHANGED"))
-- un sort de barre ne peut plus ouvrir ses recettes
ns.OpenWand()
fire(ns.wand.cells[1], "OnClick")
assert(refused() and not ns.assistant:IsShown())
ns.wand:Hide()
ns.SetFeature("assistant", true)
assert(w.assistantButton:IsShown() and listens(ns.assistant.grid.frame, "SPELLS_CHANGED"))

-- grimoire
ns.Open("editor")
ns.ToggleGrimoire()
assert(ns.grimoire:IsShown())
ns.SetFeature("grimoire", false)
assert(not w.grimoireButton:IsShown() and not ns.grimoire:IsShown() and not listens(ns.grimoire.grid.frame, "SPELLS_CHANGED"))
ns.ToggleGrimoire()
assert(refused() and not ns.grimoire:IsShown())
ns.SetFeature("grimoire", true)
assert(w.grimoireButton:IsShown() and listens(ns.grimoire.grid.frame, "SPELLS_CHANGED"))

-- share : l'ancien reglage porte la valeur ; plus d'envoi, plus d'ecoute
assert(w.send:IsShown() and byText("Envoyer à…", w.bottom):IsShown())
ns.SetFeature("share", false)
assert(db.acceptShared == false and db.features.share == nil and not w.send:IsShown() and not byText("Envoyer à…", w.bottom):IsShown())
assert(not listens(shareFrame, "CHAT_MSG_ADDON"))
ns.SendPrompt("Nom", "/cast A")
assert(refused() and not (ns.prompt and ns.prompt:IsShown()) and #SENT == 0)
ns.SetFeature("share", true)
assert(db.acceptShared == true and w.send:IsShown() and listens(shareFrame, "CHAT_MSG_ADDON"))

-- colorize : l'apercu n'a plus de code de couleur
ns.Open("editor")
ns.ed.Load("Test", "/cast [@mouseover,help] Soins")
assert(w.preview._text:find("|cff", 1, true))
ns.SetFeature("colorize", false)
assert(w.preview._text == "/cast [@mouseover,help] Soins", w.preview._text)
ns.SetFeature("colorize", true)
assert(w.preview._text:find("|cff", 1, true))

-- la visite guidee saute les etapes des fonctions coupees
ns.SetFeature("grimoire", false)
ns.SetFeature("home", false)
SlashCmdList.BLOCKFORGE("tuto")
local tour = ns.Tutorial
assert(#ns.TutorialSteps == 12 and #tour.steps == 9 and tour.step == 1 and tour.coach.count._text == "1 / 9" and tabEditor.line:IsShown())
for _, s in ipairs(tour.steps) do assert(s.feature ~= "grimoire" and s.feature ~= "home") end
for _ = 1, 9 do fire(tour.coach.next, "OnClick") end
assert(tour.step == nil)

-- /bf test liste l'etat des fonctions ; la reinitialisation les reactive toutes
GetLocale = function() return "frFR" end
SlashCmdList.BLOCKFORGE("test")
assert(table.concat(db.selftest.lines, "\n"):find("INFO features: home=off, bars=on, health=on, suggestions=on, gauge=on, assistant=on, grimoire=off, share=on", 1, true))
ns.ResetDB()
for _, def in ipairs(ns.Features) do assert(ns.Enabled(def.id), def.id) end
assert(tabHome:IsShown() and w.grimoireButton:IsShown())
`, "=fonctions");

// au chargement : accueil coupe, la fenetre s'ouvre sur l'editeur ; visite coupee, elle ne se lance pas seule ; valeurs abimees remises
boot("{ features = { home = false, tutorial = false, bars = 5 }, acceptShared = false }", BARS);
run(String.raw`
local ns, db = NS, BlockForgeDB
assert(db.features.bars == true and db.features.home == false and not ns.Enabled("share"))
assert(find(function(x) return x._events.CHAT_MSG_ADDON end) == nil, "ecoute des macros recues malgre la coupure")
SlashCmdList.BLOCKFORGE("")
assert(byText("Éditeur", BlockForgeFrame).line:IsShown() and not byText("Accueil", BlockForgeFrame):IsShown() and byText("Éditeur", BlockForgeFrame)._point[2] == 10)
assert(ns.Tutorial.step == nil and db.tutorialSeen == false, "visite lancee alors qu'elle est coupee")
assert(ns.home.gauge:IsShown() and ns.home.gauge.text._text == "0 / 120 · 0 / 30", "la jauge ne depend pas de l'accueil")
SlashCmdList.BLOCKFORGE("tuto")
assert(ns.Tutorial.step == 1 and #ns.Tutorial.steps == 10) -- sans les deux etapes de l'accueil
`, "=fonctions au chargement");

// ---------------------------------------------------------------- 12. V1 lot B : macros vivantes
// Sacs, equipement, niveau, familier, horloge differee (C_Timer) et double specialisation du faux client.
const LOTB = BARS + String.raw`
TIMERS = {}
C_Timer = { After = function(delay, fn) assert(delay == 1) TIMERS[#TIMERS + 1] = fn end }
function tick() local list = TIMERS TIMERS = {} for _, fn in ipairs(list) do fn() end end
LEVEL, PETNAME, SPEC = 60, nil, 1
function UnitLevel(unit) assert(unit == "player") return LEVEL end
BAGS = { [0] = {} }
ITEMS = { [118] = "Potion de soins mineure", [929] = "Potion de soins", [13446] = "Potion de soins majeure", [5512] = "Pierre de soins mineure",
  [9421] = "Pierre de soins majeure", [1251] = "Bandage en lin", [14530] = "Bandage runique épais", [9000] = "Bijou de test", [9001] = "Autre bijou",
  [159] = "Eau de source", [5000] = "Fromage inconnu", [6000] = "Cheval", [16896] = "Pierre d'âme majeure" }
CLASS = { [5000] = { 0, 5 }, [6000] = { 15, 5 }, [159] = { 0, 5 } } -- classe et sous-classe d'objet
EFFECT = { [5000] = "Sort433", [159] = "Sort430" }                   -- nom de l'effet « Utiliser »
MINLEVEL = { [5000] = 25 }
EQUIP = { [13] = 9000 }
C_Container = {
  GetContainerNumSlots = function(bag) return BAGS[bag] and #BAGS[bag] or 0 end,
  GetContainerItemID = function(bag, slot) return BAGS[bag][slot] end,
}
C_Item.GetItemInfo = function(id) assert(not COMBAT, "objet lu en combat") return ITEMS[id], "lien", 1, 1, MINLEVEL[id] or 0 end
C_Item.GetItemNameByID = function(id) return ITEMS[id] end
C_Item.GetItemInfoInstant = function(id) local c = CLASS[id] or { 7, 0 } return id, "", "", "", 1, c[1], c[2] end
C_Item.GetItemSpell = function(id) return EFFECT[id] end
function GetInventoryItemID(unit, slot) assert(unit == "player") return EQUIP[slot] end
function UnitExists(unit) return unit == "pet" and PETNAME ~= nil end
function UnitName(unit) if unit == "pet" then return PETNAME end assert(unit == "player") return "Moi" end
function SetBinding(key, action) assert(not COMBAT, "SetBinding en combat") BINDINGS[key] = action return true end
C_SpecializationInfo = { GetActiveSpecGroup = function() return SPEC end }
function count(kind) local n = 0 for _, c in ipairs(CALLS) do if c[1] == kind then n = n + 1 end end return n end
function printed(fragment) for _, line in ipairs(PRINTS) do if line:find(fragment, 1, true) then return true end end return false end
`;
boot("{ tutorialSeen = true }", LOTB);
run(String.raw`
local ns, db = NS, BlockForgeDB
local function said(fragment) return lastLine():find(fragment, 1, true) ~= nil end
local function text() return ns.Compile(ns.ed.Blocks()) end
SlashCmdList.BLOCKFORGE("")
ns.Open("editor")
local w, view, Living = ns.ed.w, ns.ed, ns.Living
local rows = {}
for _, c in ipairs(w.canvas._children) do if c.pills then rows[#rows + 1] = c end end

-- 1. editeur : « Vivant… » sur la ligne de l'argument (de 206 a 286, de -68 a -84), au-dessus du champ (-86), dans un panneau de 296
local chip, menu = w.livingChip, w.livingMenu
assert(chip and chip._parent == w.insp and chip._w == 80 and chip._h == 16 and chip._point[2] == 206 and chip._point[3] == -68 and chip.text._text == "Vivant…")
assert(206 + 80 <= 296 - 3 and -68 - 16 >= -86 and -68 <= -44 - 22, "puce hors du panneau, sur le champ ou sur les alternatives")
assert(not chip:IsShown() and not menu:IsShown(), "puce visible sans bloc choisi")
view.Load("Essai", "#showtooltip\n/use Potion\n/castsequence A, B\n/stopcasting\n/run x()")
fire(rows[2], "OnClick")
assert(chip:IsShown() and not menu:IsShown())
fire(chip, "OnClick")
-- liste de 13 jetons : 190 de large sous la puce (de 96 a 286), finie avant le bas du panneau (430)
assert(menu:IsShown() and menu._w == 190 and menu._h == 12 + 13 * 20 and menu._point[1] == "TOPRIGHT" and menu._point[2] == chip and -86 - menu._h >= -427, "liste hors du panneau")
local items, n = {}, 0
for _, c in ipairs(menu._children) do
  if c.text then
    n = n + 1
    items[c.text._text] = c
    assert(c._w == 174 and c._point[2] == 8 and c._point[3] == -6 - (n - 1) * 20 and c._point[3] - c._h >= -menu._h + 3, "jeton " .. n)
  end
end
assert(n == 13 and items["Potion de soin"] and items["Bijou du haut"] and items["Plus haut rang du sort"] and not items["Focus"])
fire(items["Potion de soin"], "OnClick")
assert(not menu:IsShown() and text() == "#showtooltip\n/use {bf:potion_soin}\n/castsequence A, B\n/stopcasting\n/run x()", text())
-- pastille « vivant » sur la ligne du bloc, pas sur les autres
local function pill(row)
  for _, p in ipairs(row.pills) do if p:IsShown() and p.text._text == "vivant" then return true end end
  return false
end
assert(pill(rows[2]) and not pill(rows[1]) and not pill(rows[3]), "pastille vivant")
-- pas de jeton pour une sequence, une commande sans argument ou une ligne libre
for i = 3, 5 do
  fire(rows[i], "OnClick")
  assert(not chip:IsShown(), "puce sur la ligne " .. i)
end
-- « plus haut rang » : enveloppe le nom tape, sans son rang ; refuse un argument vide
view.Load("Essai", "/cast Peur(Rang 2)\n/cast")
fire(rows[1], "OnClick")
fire(items["Plus haut rang du sort"], "OnClick")
assert(text() == "/cast {bf:sort:Peur}\n/cast", text())
fire(items["Plus haut rang du sort"], "OnClick") -- deux fois : le jeton n'est pas enveloppe dans lui-meme
assert(text() == "/cast {bf:sort:Peur}\n/cast", text())
fire(rows[2], "OnClick")
fire(items["Plus haut rang du sort"], "OnClick")
assert(said("Écris d'abord le nom du sort") and text() == "/cast {bf:sort:Peur}\n/cast")
-- un jeton n'est pas un « sort inconnu »
assert(#ns.UnknownSpells(ns.Parse("/cast {bf:sort:Peur}\n/cast Inconnu")) == 1)
COMBAT = true
fire(rows[1], "OnClick")
fire(items["Potion de soin"], "OnClick")
assert(said("combat") and text() == "/cast {bf:sort:Peur}\n/cast")
COMBAT = false

-- 2. enregistrement : la macro du jeu recoit de vrais noms, jamais un jeton ; le modele reste dans BlockForgeDB
local template = "#showtooltip\n/use {bf:potion_soin}\n/use {bf:bijou13}"
view.Load("Survie", template)
view.SaveMacro("Survie", text(), false, nil, false)
local m = MACROS.Survie
-- sacs vides : le nom de la plus petite potion de la liste, et la macro est marquee
assert(m and m.body == "#showtooltip\n/use Potion de soins mineure\n/use Bijou de test", m and m.body)
local rec = db.living.account.Survie
assert(rec and rec.template == template and rec.body == m.body and rec.flag == "missing" and next(db.living.chars) == nil)
assert(ns.LivingLabel("Survie", false) == "vivante, rien dans les sacs" and ns.LivingLabel("Survie", true) == nil and ns.LivingLabel("Autre", false) == nil)
-- un jeton sans aucun nom possible : rien n'est cree
local created = count("CreateMacro")
view.SaveMacro("Vide", "/use {bf:bijou14}", false, nil, false)
assert(count("CreateMacro") == created and not MACROS.Vide and said("Bijou du bas") and said("n'a pas été enregistrée") and db.living.account.Vide == nil)
-- trop longue une fois les noms ecrits
ITEMS[9000] = string.rep("x", 250)
view.SaveMacro("Longue", "/use {bf:bijou13}\n/stopcasting", false, nil, false)
assert(not MACROS.Longue and said("trop longue une fois les jetons remplacés"))
ITEMS[9000] = "Bijou de test"

-- 3. reecriture : une passe par seconde au plus, seulement si le texte change, meme index, meme nom, meme icone
local index, icon, edits = m.index, m.icon, count("EditMacro")
BAGS[0] = { 929, 13446, 118 }
LEVEL = 30
fireEvent("BAG_UPDATE_DELAYED")
assert(#TIMERS == 1 and m.body:find("mineure") and count("EditMacro") == edits, "reecriture sans attendre")
fireEvent("BAG_UPDATE_DELAYED")
fireEvent("PLAYER_EQUIPMENT_CHANGED")
assert(#TIMERS == 1, "plus d'une passe par seconde")
tick()
-- niveau 30 : la potion majeure (niveau 45) n'est pas retenue
assert(m.body == "#showtooltip\n/use Potion de soins\n/use Bijou de test", m.body)
assert(MACROS.Survie == m and m.index == index and m.icon == icon and count("EditMacro") == edits + 1, "index, nom ou icone changes")
local call = CALLS[#CALLS]
assert(call[1] == "EditMacro" and call[2] == "Survie" and call[4] == nil, "EditMacro doit garder l'icone")
assert(rec.flag == nil and rec.body == m.body and rec.last["{bf:potion_soin}"] == "Potion de soins")
local journal = db.living.journal
assert(#journal == 1 and journal[1].macro == "Survie" and journal[1].text == "Potion de soin : Potion de soins mineure -> Potion de soins", journal[1] and journal[1].text)
-- rien n'a change : aucune ecriture
fireEvent("SPELLS_CHANGED")
tick()
assert(count("EditMacro") == edits + 1 and #journal == 1, "reecriture inutile")
-- en combat : rien ne part ; la passe attend la sortie du combat
LEVEL = 60
COMBAT = true
fireEvent("BAG_UPDATE_DELAYED")
assert(#TIMERS == 0 and Living.Pass() == 0 and count("EditMacro") == edits + 1, "reecriture en combat")
COMBAT = false
fireEvent("PLAYER_REGEN_ENABLED")
assert(#TIMERS == 1)
tick()
assert(m.body == "#showtooltip\n/use Potion de soins majeure\n/use Bijou de test" and count("EditMacro") == edits + 2, m.body)
-- le combat commence pendant l'attente : la passe ne fait rien
BAGS[0] = { 118 }
fireEvent("BAG_UPDATE_DELAYED")
COMBAT = true
tick()
assert(m.body:find("majeure") and count("EditMacro") == edits + 2)
COMBAT = false
BAGS[0] = {}
fireEvent("PLAYER_REGEN_ENABLED")
tick()
-- sacs vides : le dernier nom est garde, la macro est marquee « rien dans les sacs »
assert(m.body:find("majeure") and rec.flag == "missing" and count("EditMacro") == edits + 2 and ns.LivingLabel("Survie", false) == "vivante, rien dans les sacs")
EQUIP[13] = 9001
fireEvent("PLAYER_EQUIPMENT_CHANGED")
tick()
assert(m.body == "#showtooltip\n/use Potion de soins majeure\n/use Autre bijou" and journal[#journal].text == "Bijou du haut : Bijou de test -> Autre bijou")
-- familier d'un autre joueur : ignore ; connexion : une passe (macros generales resolues pour ce personnage)
fireEvent("UNIT_PET", "party1")
assert(#TIMERS == 0)
fireEvent("UNIT_PET", "player")
fireEvent("PLAYER_ENTERING_WORLD")
assert(#TIMERS == 1)
tick()
-- ce que le faux client donne a lire : objets classes par le jeu, equipement, familier
BAGS[0] = { 5000, 6000, 159, 2589 }
PETNAME = "Rex"
local env = Living.Env()
assert(env.level == 60 and #env.bags == 4 and env.bags[1].kind == "food" and env.bags[1].level == 25 and env.bags[2].kind == "mount" and env.bags[3].kind == "drink")
assert(env.bags[4].kind == nil and env.bags[4].name == nil and env.slots[13] == "Autre bijou" and env.slots[14] == nil and env.pet == "Rex")
assert(ns.ResolveToken("nourriture", "", env) == "Fromage inconnu" and ns.ResolveToken("monture", "", env) == "Cheval" and ns.ResolveToken("familier", "", env) == "Rex")
BAGS[0], PETNAME = {}, nil

-- 4. modifiee hors de BlockForge : plus jamais reecrite sans confirmation
m.body = "/use Autre chose"
BAGS[0] = { 118 }
fireEvent("BAG_UPDATE_DELAYED")
tick()
assert(m.body == "/use Autre chose" and rec.flag == "diverged" and ns.LivingLabel("Survie", false) == "vivante, modifiée ailleurs")
assert(journal[#journal].text:find("Modifiée hors de BlockForge", 1, true))
local lines = #journal
fireEvent("BAG_UPDATE_DELAYED")
tick()
assert(#journal == lines and m.body == "/use Autre chose" and count("EditMacro") == edits + 3, "ecrasement silencieux")
view.Load("Survie", m.body) -- l'editeur ouvre le texte du jeu, pas le modele
assert(text() == "/use Autre chose")
-- panneau : liste, journal (20 lignes de 12 px de -314 a -554, panneau de 566), confirmation
SlashCmdList.BLOCKFORGE("vivant")
local panel = ns.livingPanel
assert(panel and panel:IsShown() and panel._w == 884 and panel._h == 566 and panel._parent == w.home and #panel.rows == 18 and #panel.lines == 20)
for i, row in ipairs(panel.rows) do assert(row._w == 420 and row._point[3] == -54 - (i - 1) * 24 and row._point[3] - row._h >= -484, "ligne " .. i) end
for i, line in ipairs(panel.lines) do assert(line._point[2] == 440 and line._w == 436 and line._point[3] == -314 - (i - 1) * 12 and line._point[3] - 12 >= -563, "journal " .. i) end
assert(panel.resume._point[2] == 440 and panel.resume._w == 215 and panel.forget._point[2] == 661 and 661 + 215 == 876)
assert(panel.rows[1]:IsShown() and panel.rows[1].text._text == "Survie" and panel.rows[1].state._text == "vivante, modifiée ailleurs" and not panel.rows[2]:IsShown())
assert(not panel.empty:IsShown() and panel.resume._enabled == false and panel.lines[1]._text:find("Modifiée hors de BlockForge", 1, true) and panel.lines[#journal + 1]._text == "")
fire(panel.rows[1], "OnClick")
assert(panel.resume._enabled == true and panel.forget._enabled == true and plain(panel.body._text) == template and panel.name._text == "Survie")
COMBAT = true
fire(panel.resume, "OnClick")
assert(said("combat") and rec.flag == "diverged" and m.body == "/use Autre chose")
COMBAT = false
fire(panel.resume, "OnClick")
assert(rec.flag == nil and m.body == "#showtooltip\n/use Potion de soins mineure\n/use Autre bijou" and panel.resume._enabled == false, m.body)
assert(panel.rows[1].state._text == "vivante" and panel.lines[1]._text:find("Potion de soins majeure -> Potion de soins mineure", 1, true), panel.lines[1]._text)
-- l'editeur rouvre le modele a jetons de la macro vivante
view.Load("Survie", m.body)
assert(text() == template, text())
-- « ne plus suivre » : le modele est oublie, la macro du jeu garde son texte
fire(panel.rows[1], "OnClick")
fire(panel.forget, "OnClick")
assert(db.living.account.Survie == nil and not panel.rows[1]:IsShown() and panel.empty:IsShown() and m.body:find("mineure") and ns.LivingLabel("Survie", false) == nil)
BAGS[0] = { 13446 }
fireEvent("BAG_UPDATE_DELAYED")
assert(#TIMERS == 0, "du travail alors qu'aucune macro n'est vivante")
fireEvent("PLAYER_REGEN_DISABLED")
assert(not panel:IsShown(), "panneau ouvert en combat")

-- 5. macro du personnage ; reecrite sans jeton, elle n'est plus vivante (apres la confirmation seulement)
view.SaveMacro("Perso", "/use {bf:bijou13}", true, nil, false)
local me = db.living.chars["Moi-Royaume"]
assert(MACROS.Perso.char == true and MACROS.Perso.body == "/use Autre bijou" and me and me.Perso and db.living.account.Perso == nil)
assert(ns.LivingLabel("Perso", true) == "vivante" and ns.LivingLabel("Perso", false) == nil)
view.SaveMacro("Perso", "/use 13", true, nil, false)
assert(me.Perso and MACROS.Perso.body == "/use Autre bijou", "modele oublie avant la confirmation")
accept("BLOCKFORGE_OVERWRITE")
assert(me.Perso == nil and MACROS.Perso.body == "/use 13")
-- la macro supprimee dans le jeu : le modele est retire a la passe suivante
view.SaveMacro("Ephemere", "/use {bf:bijou13}", false, nil, false)
DeleteMacro(MACROS.Ephemere.index)
fireEvent("BAG_UPDATE_DELAYED")
tick()
assert(db.living.account.Ephemere == nil and journal[#journal].text:find("n'existe plus", 1, true))

-- 6. plusieurs macros reecrites d'un coup : sauvegarde automatique d'abord, et une annulation
view.SaveMacro("V1", "/use {bf:bijou13}", false, nil, false)
view.SaveMacro("V2", "/use {bf:bijou13}\n/stopcasting", false, nil, false)
db.undo = false
EQUIP[13] = 9000
fireEvent("PLAYER_EQUIPMENT_CHANGED")
tick()
assert(MACROS.V1.body == "/use Bijou de test" and MACROS.V2.body == "/use Bijou de test\n/stopcasting")
local backup = db.profiles["Auto 2026-11-20 12:00:00 macros vivantes"]
assert(backup and backup.auto == true and ns.UndoLabel() == "réécriture de 2 macros vivantes" and #db.undo.ops == 2)
local saved
for _, s in ipairs(backup.macros) do if s.name == "V1" then saved = s end end
assert(saved and saved.body == "/use Autre bijou", "la sauvegarde doit dater d'avant la reecriture")
-- une annulation deja en attente (operation du joueur) n'est pas remplacee
db.undo = { owner = NS.CharKey(), label = "operation du joueur", ops = {} }
EQUIP[13] = 9001
fireEvent("PLAYER_EQUIPMENT_CHANGED")
tick()
assert(MACROS.V1.body == "/use Autre bijou" and ns.UndoLabel() == "operation du joueur")
db.undo = false

-- 7. accueil : ligne des macros vivantes dans le bandeau (de 640 a 876, de -72 a -90), sans toucher au compte des macros
ns.Open("home")
local line = find(function(x) return x.text and x.text._text == "Macros vivantes : 2 · journal" end)
assert(line and line._parent == w.homeTop and line._w == 236 and line._h == 18 and line._point[2] == 640 and line._point[3] == -72 and line:IsShown())
assert(640 + 236 <= 884 - 8 and -72 - 18 >= -93 and ns.home.counts._w == 620 and 10 + 620 <= 640, "ligne hors du bandeau")
fire(line, "OnClick")
assert(panel:IsShown() and panel.rows[2].text._text == "V2")
panel:Hide()
-- « Mes macros » : la macro vivante est marquee dans la liste et dans le detail
ns.Open("macros")
fireEvent("UPDATE_MACROS")
local mrow = find(function(x) return x.scope and x.text._text == "V1" end)
assert(mrow and mrow.scope._text == "Macro vivante")
fire(mrow, "OnClick")
assert(find(function(x) return x._type == "FontString" and x._text and x._text:find("Macro générale", 1, true) and x._text:find("·  vivante", 1, true) end), "detail sans la mention vivante")

-- 8. Assistant : « Bouton de survie » pour un objet, cree en un clic, vivant
BAGS[0] = { 9421, 929, 14530 }
DeleteMacro(MACROS.Survie.index)
ns.OpenAssistant({ name = "Pierre de soins majeure", kind = "item" })
local assistant = ns.assistant
local card = assistant.cards[3]
assert(card.recipe.id == "survival" and card.title._text == "Bouton de survie" and card.living:IsShown() and plain(card.code._text):find("/use [nomod] <Pierre de soins>", 1, true), card.code._text)
fire(card.create, "OnClick")
assert(MACROS.Survie and MACROS.Survie.body == "#showtooltip\n/use [nomod] Pierre de soins majeure\n/use [nomod] Potion de soins\n/use [mod] Bandage runique épais", MACROS.Survie and MACROS.Survie.body)
assert(db.living.account.Survie and db.living.account.Survie.flag == nil, "macro de survie non vivante")
-- « Bijoux vivants » sur un emplacement de barre : la macro posee porte les vrais noms
SLOTS[1] = { "spell", 172 }
ns.OpenAssistant({ name = "Corruption", base = "Corruption", kind = "spell" }, 1)
local trinkets
for i = 1, 12 do
  local c = assistant.cards[4]
  if c.recipe.id == "living_trinkets" then trinkets = c break end
  fire(assistant.deck, "OnMouseWheel", -1)
end
assert(trinkets, "recette des bijoux vivants absente")
fire(trinkets.create, "OnClick")
assert(said("Bijou du bas") and not MACROS.Corruption and slotIs(1, "spell", 172), "macro posee avec un jeton sans nom")
EQUIP[14] = 9000
fire(trinkets.create, "OnClick")
assert(MACROS.Corruption and MACROS.Corruption.body == "#showtooltip Corruption\n/use Autre bijou\n/use Bijou de test\n/cast Corruption", MACROS.Corruption and MACROS.Corruption.body)
assert(slotIs(1, "macro", MACROS.Corruption.index) and db.living.account.Corruption and db.living.account.Corruption.template:find("{bf:bijou13}", 1, true), "macro vivante non posee")

-- Recettes autonomes : sort, objet, familier ou aucune selection ; regroupees apres le sort.
local expected = "survival living_mana living_food_water living_bandage living_healing"
local function autonomes()
  local out, found = {}, false
  for _, r in ipairs(assistant.state.recipes) do
    if r.standalone then found = true out[#out + 1] = r.id
    else assert(not found, "recette de sort apres les autonomes") end
  end
  return table.concat(out, " ")
end
for _, entry in ipairs({ { name = "Soins rapides", kind = "spell" }, { name = "Pierre de soins", kind = "item" }, { name = "Griffe", kind = "pet" } }) do
  ns.OpenAssistant(entry)
  assert(autonomes() == expected)
  local bijoux = false
  for _, r in ipairs(assistant.state.recipes) do if r.id == "living_trinkets" then bijoux = true end end
  assert(bijoux == (entry.kind == "spell"), "bijoux sans sort ou absents pour une aide")
end
ns.OpenAssistant(nil, nil, true)
assert(assistant.state.entry == nil and #assistant.state.recipes == 5 and autonomes() == expected and not assistant.intro:IsShown())
for _, c in ipairs(assistant.cards) do
  assert(c.living:IsShown() and c.title._w == 220 and c.living._point[2] == 236 and c.living._w == 44)
  assert(10 + c.title._w < c.living._point[2] and 236 + c.living._w <= 280)
end
ns.SetFeature("living", false)
assert(#assistant.state.recipes == 0 and not assistant.cards[1]:IsShown() and assistant.intro:IsShown())
ns.SetFeature("living", true)
assert(#assistant.state.recipes == 5)

-- Journal : bouton dans le panneau, ouvre directement les recettes vivantes sans selection.
ns.OpenLiving()
assert(panel.create._text == "Créer une macro vivante" and panel.create._w == 410 and panel.create._point[2] == 12 and panel.create._point[3] == -500)
assert(12 + panel.create._w <= 428 and -500 - panel.create._h >= -566)
fire(panel.create, "OnClick")
assert(not panel:IsShown() and assistant:IsShown() and assistant.cards[1].recipe.standalone and not assistant.state.entry)
BAGS[0] = { 5000, 159 }
local meal = assistant.cards[3]
assert(meal.recipe.id == "living_food_water" and meal.create._text == "Créer la macro")
fire(meal.create, "OnClick")
assert(MACROS.Repas and MACROS.Repas.body == "#showtooltip\n/use Fromage inconnu\n/use Eau de source", MACROS.Repas and MACROS.Repas.body)
assert(not MACROS.Repas.body:find("{bf:", 1, true) and db.living.account.Repas and db.living.account.Repas.template:find("{bf:nourriture}", 1, true))
-- Accueil vide : la ligne mene elle aussi aux recettes vivantes.
local account, chars = db.living.account, db.living.chars
db.living.account, db.living.chars = {}, {}
ns.Open("home")
Living.HomeChip()
line = find(function(x) return x.text and x.text._text == "Macros vivantes : 0 · journal" end)
fire(line, "OnClick")
assert(assistant:IsShown() and assistant.cards[1].recipe.standalone and not assistant.state.entry)
db.living.account, db.living.chars = account, chars

-- Bibliotheque : six recettes dans chaque classe, texte traduit, jetons lisibles, favoris et creation.
ns.Open("library")
local livingChip = w.libraryLiving
local libRows = {}
for _, row in ipairs(w.libraryList._children) do if row.mark then libRows[#libRows + 1] = row end end
local function visibleLibrary()
  local out = {}
  for _, row in ipairs(libRows) do if row:IsShown() then out[#out + 1] = row end end
  return out
end
assert(livingChip.text._text == "Vivantes" and livingChip:IsShown())
for _, c in ipairs(w.libraryList._children) do
  if c.text and not c.mark then
    assert(c._point[2] >= 8 and c._point[2] + c._w <= 292 and (c._point[3] == -52 or c._point[3] == -74))
  end
end
assert(libRows[1]._point[3] == -96 and libRows[18]._point[3] - libRows[18]._h >= -566)
fire(livingChip, "OnClick")
for _, class in ipairs({ "Toutes classes", "Démoniste", "Mage", "Guerrier" }) do
  fire(byText(class, w.libraryClasses), "OnClick")
  assert(#visibleLibrary() == 6, "recettes communes absentes : " .. class)
end
local search = find(function(x) return x._type == "EditBox" and x._parent == w.libraryList end)
search:SetText("eau")
fire(search, "OnTextChanged", true)
assert(#visibleLibrary() == 1 and visibleLibrary()[1].text._text:find("Manger et boire", 1, true))
fire(visibleLibrary()[1], "OnClick")
local code = find(function(x) return x._type == "FontString" and x._text and plain(x._text):find("/use <Eau>", 1, true) and inside(x, w.library) end)
assert(code and not code._text:find("{bf:", 1, true))
fire(byText("Ajouter aux favoris", w.library), "OnClick")
assert(db.favorites["Living/living_food_water"])
fire(find(function(x) return x.text and x._parent == w.libraryClasses and x.text._text:find("Favoris", 1, true) end), "OnClick")
assert(#visibleLibrary() == 1)
DeleteMacro(MACROS.Repas.index)
fire(byText("Créer", w.library), "OnClick")
assert(MACROS.Repas and not MACROS.Repas.body:find("{bf:", 1, true) and db.living.account.Repas)
assert(MACROS.Repas.body == "#showtooltip\n/use Fromage inconnu\n/use Eau de source")
fire(byText("Ouvrir dans l'éditeur", w.library), "OnClick")
assert(ns.ed.Name() == "Repas" and text():find("{bf:eau}", 1, true))
ns.Open("library")
ns.SetFeature("living", false)
assert(not livingChip:IsShown() and #visibleLibrary() == 0 and not byText("Créer", w.library):IsShown())
ns.SetFeature("living", true)
assert(livingChip:IsShown() and #visibleLibrary() == 1)

-- Assistant : titre de groupe dans le flux ; cartes et titre sans chevauchement.
ns.OpenAssistant({ name = "Corruption", kind = "spell" })
assert(not assistant.livingHeading:IsShown())
for _ = 1, 4 do fire(assistant.deck, "OnMouseWheel", -1) end
assert(assistant.livingHeading:IsShown() and assistant.livingHeading._text == "Macros vivantes")
local headingY = -assistant.livingHeading._point[5]
assert(headingY == 3 * 116 and assistant.cards[4]._point[3] == -(headingY + 18))
for _ = 1, 20 do fire(assistant.deck, "OnMouseWheel", -1) end
assert(assistant.livingHeading._point[5] == 0)
for i, c in ipairs(assistant.cards) do
  assert(-c._point[3] + c._h <= 482)
  if i > 1 then assert(-c._point[3] >= -assistant.cards[i - 1]._point[3] + assistant.cards[i - 1]._h + 2) end
end
ns.SetFeature("living", false)
assert(not assistant.livingHeading:IsShown())
ns.SetFeature("living", true)

-- Mes macros : uniquement les macros du jeu suivies, avec leur portee ; retrait immediat au desabonnement.
view.SaveMacro("Ordinaire", "/use Eau de source", false, nil, false)
ns.Open("macros")
local macroChip = w.macroLiving
assert(macroChip.text._text == "Vivantes" and macroChip:IsShown())
fire(macroChip, "OnClick")
local function trackedRows()
  local out = {}
  for _, row in ipairs(macroChip._parent._children) do
    if row.scope and row:IsShown() then
      assert(row.text._text ~= "Ordinaire" and ns.LivingLabel(row.text._text, row.scope._text == "Personnage"))
      out[#out + 1] = row
    end
  end
  return out
end
assert(#trackedRows() == #Living.List())
Living.Forget("Repas", false)
for _, row in ipairs(trackedRows()) do assert(row.text._text ~= "Repas") end
ns.SetFeature("living", false)
assert(not macroChip:IsShown())
local regular
for _, row in ipairs(macroChip._parent._children) do if row.scope and row:IsShown() and row.text._text == "Ordinaire" then regular = row end end
assert(regular, "filtre invisible encore actif")
ns.SetFeature("living", true)
assert(macroChip:IsShown())
`, "=macros vivantes");

// ---------------------------------------------------------------- 13. V1 lot B : kits de personnage
boot("{ tutorialSeen = true }", LOTB);
run(String.raw`
local ns, db = NS, BlockForgeDB
local function said(fragment) return lastLine():find(fragment, 1, true) ~= nil end
SLOTS[1] = { "spell", 172 }
SlashCmdList.BLOCKFORGE("")
local w, home = ns.ed.w, ns.home
-- entree de l'accueil ; /bf kit ouvre le meme panneau
assert(home.tiles[5].text._text == "Équiper mon personnage" and home.tiles[5]:IsShown())
assert(ns.kitsPanel == nil, "panneau construit avant d'etre demande")
fire(home.tiles[5], "OnClick")
local panel = ns.kitsPanel
local state = panel.state
assert(panel:IsShown() and panel._w == 884 and panel._h == 566 and panel._parent == w.home and #panel.rows == 20)
panel:Hide()
SlashCmdList.BLOCKFORGE("kit")
assert(panel:IsShown())
-- trois roles, deux visees, familier (le demoniste en a un) ; au depart : montee de niveau, survol, sans familier (aucun sorti)
assert(#panel.chips == 7 and state.choice.role == "leveling" and state.choice.hover == true and state.choice.pet == false)
local function chip(label) for _, c in ipairs(panel.chips) do if c.text._text == label then return c end end error("puce absente : " .. label) end
for i, a in ipairs(panel.chips) do -- puces sans chevauchement, dans le panneau
  assert(a._point[2] >= 8 and a._point[2] + a._w <= 876 and (a._point[3] == -28 or a._point[3] == -52) and a._h == 18, "puce " .. i)
  for j, b in ipairs(panel.chips) do
    if i < j and a._point[3] == b._point[3] then assert(a._point[2] + a._w <= b._point[2] or b._point[2] + b._w <= a._point[2], "puces qui se chevauchent : " .. i .. ", " .. j) end
  end
end
assert(chip("Montée de niveau")._border[1] == 0.53 and chip("JcJ")._border[1] ~= 0.53 and chip("Au survol")._border[1] == 0.53 and chip("Sans")._border[1] == 0.53)
-- 20 lignes de 20 px tous les 22 de -80 a -518, comptes a -522, boutons en bas sans chevauchement
for i, row in ipairs(panel.rows) do
  assert(row._w == 868 and row._h == 20 and row._point[2] == 8 and row._point[3] == -80 - (i - 1) * 22 and row._point[3] - 20 >= -518, "ligne " .. i)
  assert(row.text._point[2] == 26 and 26 + row.text._w <= row.desc._point[2] and row.desc._point[2] + row.desc._w <= row.state._point[2] and row.state._point[2] + row.state._w <= 868)
end
assert(panel.status._point[3] == -522 and panel.undo._w == 300 and panel.toBars._point[2] == 450 and 8 + 300 <= 450 and 450 + panel.toBars._w <= 884 - 8 - panel.install._w)
local function item(name)
  for i, it in ipairs(state.items) do if it.name == name then return it, panel.rows[i] end end
end
local function usable()
  local n = 0
  for _, it in ipairs(state.items) do if #it.unknown == 0 and not it.exists then n = n + 1 end end
  return n
end

-- 1. la liste : macros traduites, description, utilisable ou « sort pas encore appris » (decochee), kit de 8 a 20 macros
assert(#state.items >= 8 and #state.items <= 20 and panel.rows[#state.items]:IsShown() and not panel.rows[#state.items + 1]:IsShown())
local fear, fearRow = item("Fear MO")
assert(fear.body == "#showtooltip Peur\n/dismount\n/cast [@mouseover,exists,harm][] Peur" and #fear.unknown == 0, fear.body)
assert(fearRow.text._text == "Fear MO" and #fearRow.desc._text > 20 and fearRow.state._text == "utilisable maintenant" and state.checked["Fear MO"] == true and fearRow.check._color[1] == 0.53)
local drain, drainRow = item("Drain Soul MO")
assert(#drain.unknown == 1 and drainRow.state._text == "sort pas encore appris : " .. drain.unknown[1] and state.checked["Drain Soul MO"] == false and drainRow.text._textColor[1] == 0.6)
local survie = item("Survie")
assert(survie and survie.living == true and survie.body:find("{bf:pierre_soin}", 1, true) and #survie.unknown == 0 and state.checked.Survie == true)
assert(item("Pet Attack") == nil and item("Soulstone").body:find("Pierre d'âme majeure", 1, true), "familier ou objet")
local n = usable()
assert(n >= 4 and panel.install._text == "Tout installer (" .. n .. ")" and panel.install._enabled == true, panel.install._text)
assert(panel.status._text == "Macros à créer : " .. n .. " · places libres : 120 générales, 30 du personnage", panel.status._text)
assert(panel.toBars:IsShown() and panel.toBars._enabled == false, "pose proposee avant l'installation")
-- une case se decoche et se recoche ; une macro au sort inconnu peut etre cochee a la main
fire(fearRow, "OnClick")
assert(state.checked["Fear MO"] == false and panel.install._text == "Tout installer (" .. n - 1 .. ")")
fire(fearRow, "OnClick")
fire(drainRow, "OnClick")
assert(state.checked["Drain Soul MO"] == true and panel.install._text == "Tout installer (" .. n + 1 .. ")")
fire(drainRow, "OnClick")
-- visee « cible » : plus de survol ; la macro qui ne ferait plus que lancer le sort quitte le kit
fire(chip("Sur la cible"), "OnClick")
assert(state.choice.hover == false and item("Fear MO").body == "#showtooltip Peur\n/dismount\n/cast Peur" and item("Drain Soul MO") == nil, item("Fear MO").body)
for _, it in ipairs(state.items) do assert(not it.body:find("@mouseover", 1, true), it.name) end
assert(#state.items >= 8)
fire(chip("Au survol"), "OnClick")
-- familier, autre role
fire(chip("Avec"), "OnClick")
assert(item("Pet Attack") and item("Pet Follow") and #state.items <= 20)
fire(chip("JcJ"), "OnClick")
assert(state.choice.role == "pvp" and item("Spell Lock Focus") and item("Target player") and not item("Drain Soul MO"))
fire(chip("Sans"), "OnClick")
fire(chip("Montée de niveau"), "OnClick")

-- 2. macros deja la : meme texte sous un autre nom = « tu l'as deja » ; meme nom, autre texte = laissee, jamais ecrasee
CreateMacro("Fear MO", 1, "/cast Autre")
CreateMacro("Suivante", 1, "/cleartarget [dead]\n/targetenemy [noharm]\n/startattack")
fireEvent("UPDATE_MACROS")
fear, fearRow = item("Fear MO")
local nextTarget, nextRow = item("Next target")
assert(fear.exists == "name" and fearRow.state._text == "laissée : une autre macro porte ce nom" and nextTarget.exists == "same" and nextRow.state._text == "tu l'as déjà")
fire(fearRow, "OnClick") -- ne se coche pas
assert(fearRow.check._color[1] ~= 0.53 and usable() == n - 2 and panel.install._text == "Tout installer (" .. n - 2 .. ")")

-- 3. pas assez de place : refus chiffre, rien n'est cree, aucune sauvegarde
local real, calls = GetNumMacros, #CALLS
GetNumMacros = function() return 120, 29 end
fire(panel.install, "OnClick")
assert(said("Pas assez de place : " .. n - 2 .. " macros à créer, 1 places libres (0 générales, 1 du personnage). Rien n'a été créé."), lastLine())
assert(#CALLS == calls and next(db.profiles) == nil and ns.UndoLabel() == nil and db.kits["Moi-Royaume"] == nil)
-- en combat : rien
GetNumMacros = real
COMBAT = true
fire(panel.install, "OnClick")
assert(said("combat") and #CALLS == calls)
COMBAT = false
-- l'onglet general est plein : les macros vont dans celui du personnage, et c'est dit
GetNumMacros = function() local _, c = real() return 120, c end
local before = #ns.ReadMacros()
fire(panel.install, "OnClick")
GetNumMacros = real
assert(MACROS.Soulstone and MACROS.Soulstone.char == true and MACROS.Survie and MACROS.Survie.char == true and MACROS["Fear MO"].body == "/cast Autre", "installation")
assert(printed(n - 2 .. " macro(s) sont allées dans l'autre onglet") and printed("Kit : " .. n - 2 .. " macro(s) créée(s), 0 non créée(s)"))
assert(said("Sauvegarde automatique « Auto 2026-11-20 12:00:00 kit »"), lastLine())
local backup = db.profiles["Auto 2026-11-20 12:00:00 kit"]
assert(backup and backup.auto == true and #backup.macros == 2 and ns.UndoLabel() == "kit de " .. n - 2 .. " macros" and #db.undo.ops == n - 2)
-- la macro de survie est vivante : de vrais noms dans le jeu (sacs vides : les plus petits objets), le modele dans BlockForgeDB
assert(MACROS.Survie.body == "#showtooltip\n/use [nomod] Pierre de soins mineure\n/use [nomod] Potion de soins mineure\n/use [mod] Bandage en lin", MACROS.Survie.body)
assert(db.living.chars["Moi-Royaume"].Survie.template:find("{bf:bandage}", 1, true))
-- le kit est retenu pour ce personnage, avec les macros qui attendent un sort
local mem = db.kits["Moi-Royaume"]
assert(mem and mem.class == "WARLOCK" and mem.role == "leveling" and mem.hover == true and mem.pet == false and mem.waiting["Drain Soul MO"] and not mem.waiting.Survie and not mem.waiting["Fear MO"])
assert(item("Soulstone").exists == "same" and item("Survie").exists == "name" and panel.install._text == "Tout installer (0)" and panel.install._enabled == false)

-- 4. pose sur une barre : etape a part, avec son apercu ; emplacements vides seulement, sauf « remplacer »
assert(panel.toBars._enabled == true and #state.installed == n - 2 and state.installed[1] == "Soulstone")
fire(panel.toBars, "OnClick")
assert(panel.barView:IsShown() and not panel.listView:IsShown() and #panel.barRows == 10 and #panel.barLines == 12)
for i, r in ipairs(panel.barRows) do
  assert(r.first == (i - 1) * 12 + 1 and r._w == 300 and r._point[2] == 8 and r._point[3] == -100 - (i - 1) * 22 and r._point[3] - 20 >= -518, "rangee " .. i)
end
for i, l in ipairs(panel.barLines) do assert(l._point[2] == 320 and 320 + l._w <= 876 and l._point[3] == -120 - (i - 1) * 16 and l._point[3] - 16 <= -120 and l._point[3] - 16 >= -322, "apercu " .. i) end
assert(panel.replace._point[3] == -322 and panel.place._point[3] == -370 and panel.place._enabled == false and panel.barRows[1].text._text == "Emplacements 1 à 12 : 11 vides")
local places = PLACES
fire(panel.barRows[1], "OnClick")
assert(panel.barLines[1]._text == "Emplacement 2 : macro « Soulstone »" and panel.barLines[2]._text == "Emplacement 3 : macro « Survie »" and panel.place._text == "Poser (" .. n - 2 .. ")", panel.barLines[1]._text)
fire(panel.replace, "OnClick")
assert(panel.barLines[1]._text == "Emplacement 1 : macro « Soulstone », à la place de « Corruption »", panel.barLines[1]._text)
fire(panel.replace, "OnClick")
assert(PLACES == places and slotIs(2, nil), "l'apercu a pose quelque chose")
local record = db.undo
fire(panel.place, "OnClick")
assert(slotIs(1, "spell", 172) and slotIs(2, "macro", MACROS.Soulstone.index) and slotIs(3, "macro", MACROS.Survie.index), "pose")
assert(db.undo == record and #record.ops == (n - 2) * 2 and next(BINDINGS) == nil and SAVED_BINDINGS == nil, "une seule annulation, aucune touche liee")
assert(not panel.barView:IsShown() and panel.listView:IsShown() and panel.toBars._enabled == false)
-- une seule annulation defait la pose et les creations
fire(panel.undo, "OnClick")
assert(slotIs(2, nil) and slotIs(3, nil) and not MACROS.Soulstone and not MACROS.Survie and MACROS["Fear MO"] and ns.UndoLabel() == nil, "annulation du kit")
assert(panel.undo._text == "Rien à annuler" and item("Soulstone").exists == nil)

-- 5. sans la fonction « Ameliorer ma barre » : l'etape de pose disparait, et rien ne se pose
ns.SetFeature("bars", false)
assert(not panel.toBars:IsShown())
assert(ns.KitsUI.Place({ { slot = 2, macro = "Fear MO", before = { kind = "empty" } } }) == nil and slotIs(2, nil) and said("fonction désactivée"))
ns.SetFeature("bars", true)
assert(panel.toBars:IsShown())

-- 6. nouveau sort appris : une ligne sur l'accueil, une seule ligne de discussion par session, installation en un clic
for name, on in pairs(state.checked) do if on then fire(select(2, item(name)), "OnClick") end end
fire(select(2, item("Soulstone")), "OnClick")
fire(panel.install, "OnClick")
assert(MACROS.Soulstone and ns.UndoLabel() == "kit de 1 macros")
panel:Hide()
local line = find(function(x) return x.text and x._parent == w.homeTop and x._point and x._point[2] == 640 and x._point[3] == -50 end)
assert(line and line._w == 236 and line._h == 18 and not line:IsShown() and -50 - 18 <= -68 and -68 > -72, "ligne du kit")
local unknown = drain.unknown[1]
local prints = #PRINTS
fireEvent("SPELLS_CHANGED")
assert(#PRINTS == prints and not line:IsShown(), "annonce sans nouveau sort")
BEST[unknown] = 1120
COMBAT = true
fireEvent("SPELLS_CHANGED")
assert(#PRINTS == prints and not line:IsShown(), "annonce en combat")
COMBAT = false
fireEvent("PLAYER_REGEN_ENABLED")
tick()
assert(#PRINTS == prints + 1 and said("1 macro(s) de ton kit sont maintenant disponibles") and line:IsShown() and line.text._text == "Kit : 1 macro(s) disponibles — installer", lastLine())
fireEvent("SPELLS_CHANGED")
assert(#PRINTS == prints + 1, "une seule annonce par session")
fire(line, "OnClick")
assert(MACROS["Drain Soul MO"] and MACROS["Drain Soul MO"].body:find(unknown, 1, true) and not line:IsShown() and db.kits["Moi-Royaume"].waiting["Drain Soul MO"] == nil)
assert(ns.UndoLabel() == "kit de 1 macros" and db.profiles["Auto 2026-11-20 12:00:00 kit 3"], "sauvegarde avant l'installation depuis l'accueil")
-- une macro creee entre l'affichage et le clic : l'installation ne l'ecrase pas, et le dit
local kept = MACROS["Fear MO"].body
ns.KitsUI.Install({ { name = "Fear MO", body = "/cast Peur", unknown = {} } })
assert(MACROS["Fear MO"].body == kept and printed("Kit : 0 macro(s) créée(s), 1 non créée(s)") and ns.UndoLabel() == "kit de 1 macros", "macro du meme nom ecrasee")
`, "=kits");

// kit retenu par le personnage : repris a l'ouverture ; cinq sauvegardes automatiques au plus
boot(`{ tutorialSeen = true, kits = { ["Moi-Royaume"] = { class = "WARLOCK", role = "group", hover = false, pet = true, waiting = {} } } }`, LOTB);
run(String.raw`
local ns, db = NS, BlockForgeDB
SlashCmdList.BLOCKFORGE("kit")
local state = ns.kitsPanel.state
assert(state.choice.role == "group" and state.choice.hover == false and state.choice.pet == true and #state.items >= 8 and #state.items <= 20)
local names = {}
for i = 1, 7 do
  local real = date
  date = function(fmt) return fmt == "%Y-%m-%d %H:%M:%S" and ("2026-11-20 12:00:0" .. i) or real(fmt) end
  names[i] = ns.Backup("essai")
  date = real
end
local autos = 0
for name, p in pairs(db.profiles) do if p.auto then autos = autos + 1 end end
assert(autos == 5 and not db.profiles[names[1]] and not db.profiles[names[2]] and db.profiles[names[3]] and db.profiles[names[7]], "cinq sauvegardes automatiques au plus")
COMBAT = true
assert(ns.Backup("essai") == nil)
`, "=kit retenu");

// ---------------------------------------------------------------- 14. V1 lot B : profils
// Anciennes sauvegardes (sets), un profil illisible, un profil d'un autre personnage en anglais.
boot(`{ tutorialSeen = true,
  sets = { ["Vieux"] = { { name = "A", body = "/cast Peur", icon = 5, index = 3 }, { name = "B", body = "/sit", char = true }, 7, { name = "Sans corps" } },
           ["Double"] = { { name = "C", body = "/dance" } }, [3] = { { name = "D", body = "/x" } } },
  profiles = { ["Double"] = { macros = {} }, ["Abime"] = 5, ["Sans macros"] = { owner = "x" },
    ["Reroll"] = { owner = "Reroll-Royaume", class = "MAGE", macros = { { name = "Sheep", body = "#showtooltip Polymorph\\n/cast [@mouseover,harm][] Polymorph" }, { name = "Peur", body = "/cast Fear", char = true } } } } }`, LOTB);
run(String.raw`
local ns, db = NS, BlockForgeDB
local function said(fragment) return lastLine():find(fragment, 1, true) ~= nil end
local P = ns.Profiles

-- 1. migration des anciennes sauvegardes : copiees une fois, sans perte, l'ancienne cle reste lisible
local old = db.profiles.Vieux
assert(old and #old.macros == 2 and old.macros[1].name == "A" and old.macros[1].icon == 5 and old.macros[1].index == nil and old.macros[1].char == false and old.macros[2].char == true)
assert(db.sets.Vieux and #db.sets.Vieux == 4 and db.sets.Vieux.migrated == true and db.sets.Vieux[1].body == "/cast Peur", "ancienne cle perdue")
assert(#db.profiles.Double.macros == 0 and db.profiles["Double (2)"] and db.profiles["Double (2)"].macros[1].name == "C", "nom deja pris : la sauvegarde ecrasee")
assert(db.profiles.Abime == nil and db.profiles["Sans macros"] == nil and db.profiles.Reroll, "profils illisibles")
ns.InitDB() -- un second chargement ne recopie rien ; un profil supprime ne revient pas
local n = 0
for _ in pairs(db.profiles) do n = n + 1 end
assert(n == 4 and not db.profiles["Vieux (2)"])
P.Delete("Vieux")
ns.InitDB()
assert(db.profiles.Vieux == nil and db.sets.Vieux)
ns.ResetDB()
assert(db.profiles.Reroll and db.sets.Vieux, "profils perdus a la reinitialisation")

-- 2. enregistrer : macros, et au choix touches et barres
CreateMacro("Kick", 7, "/cast Peur")
CreateMacro("Soin", 8, "/cast Soins rapides", true)
BINDINGS.F, BINDINGS.G = "MACRO Kick", "ACTIONBUTTON2"
SLOTS[5], SLOTS[6] = { "macro", MACROS.Kick.index }, { "spell", 172 }
SlashCmdList.BLOCKFORGE("")
local w, home = ns.ed.w, ns.home
assert(home.tiles[6].text._text == "Profils")
-- la colonne de « Mes macros » : liste des profils, et « Profils… » au-dessus de « Restaurer » (de -510 a -532)
ns.Open("macros")
fireEvent("UPDATE_MACROS")
local more = byText("Profils…", w.macros)
assert(more._w == 160 and more._point[1] == "BOTTOMLEFT" and more._point[2] == 8 and more._point[3] == 34 and more._parent:IsShown() and more._parent._w == 176)
assert(-84 - 17 * 22 - 20 >= -(566 - 34 - 22), "« Profils… » sur la liste")
assert(ns.profilesPanel == nil, "panneau construit avant d'etre demande")
fire(more, "OnClick")
local panel = ns.profilesPanel
local state = panel.state
assert(panel:IsShown() and panel._w == 884 and panel._h == 566 and panel._parent == w.macros and #panel.rows == 18 and #panel.lines == 22)
panel:Hide()
SlashCmdList.BLOCKFORGE("profil")
assert(panel:IsShown())
panel:Hide()
SlashCmdList.BLOCKFORGE("profile")
assert(panel:IsShown() and byText("Mes macros", BlockForgeFrame).line:IsShown())
-- disposition : liste a gauche (8 a 300), detail a droite (312 a 876), rien ne se chevauche
for i, row in ipairs(panel.rows) do assert(row._w == 292 and row._point[2] == 8 and row._point[3] == -52 - (i - 1) * 22 and row._point[3] - 20 >= -446, "ligne " .. i) end
for i, line in ipairs(panel.lines) do assert(line._w == 564 and 312 + 564 <= 876 and line._point[3] == -(i - 1) * 16 and -118 + line._point[3] - 16 >= -470, "apercu " .. i) end
assert(panel.saveName._point[3] == -456 and panel.saveChips[1]._point[3] == -480 and panel.saveChips[1]._point[2] + panel.saveChips[1]._w <= panel.saveChips[2]._point[2])
assert(panel.saveChips[2]._point[2] + panel.saveChips[2]._w <= 300 and panel.delete._w == 140 and panel.summary._point[3] == -476 and panel.share._point[3] == -512)
local xs = {}
for i, c in ipairs(panel.options) do
  assert(c._point[2] >= 312 and c._point[2] + c._w <= 876 and (c._point[3] == -70 or c._point[3] == -92), "option " .. i)
  xs[#xs + 1] = c
end
for _, c in ipairs(panel.specs) do xs[#xs + 1] = c end
for i, a in ipairs(xs) do
  for j, b in ipairs(xs) do
    if i < j and a._point[3] == b._point[3] then assert(a._point[2] + a._w <= b._point[2] or b._point[2] + b._w <= a._point[2], "puces qui se chevauchent : " .. i .. ", " .. j) end
  end
end
assert(panel.share._point[2] + panel.share._w <= panel.export._point[2] and panel.export._point[2] + panel.export._w <= 804 and 804 + 72 == 876)
assert(panel.undo._point[2] == 312 and 312 + panel.undo._w <= 884 - 8 - panel.activate._w, "boutons du bas")
-- mes profils : Double, Double (2) ; ceux des autres personnages a part
local function names() local out = {} for i, name in ipairs(state.names) do out[i] = name end return table.concat(out, ",") end
assert(names() == "Double (2),Double" and panel.rows[1].text._text:find("Double (2)", 1, true) and not panel.rows[3]:IsShown(), names())
panel.saveName._text = "PvP"
fire(byText("Enregistrer mon profil", panel), "OnClick")
local pvp = db.profiles.PvP
assert(pvp and #pvp.macros == 2 and pvp.owner == "Moi-Royaume" and pvp.class == "WARLOCK" and pvp.macros[1].icon == 7 and pvp.macros[2].char == true)
assert(pvp.bindings and #pvp.bindings.Kick == 1 and pvp.bindings.Kick[1] == "F" and pvp.bindings.Soin == nil and pvp.bars and pvp.bars[5] == "Kick" and pvp.bars[6] == nil)
assert(state.chosen == "PvP" and panel.saveName._text == "" and said("Sauvegarde « PvP » enregistrée (2 macros)"))
-- sans les touches ni les barres ; un nom deja pris demande confirmation
fire(panel.saveChips[1], "OnClick")
fire(panel.saveChips[2], "OnClick")
panel.saveName._text = "Simple"
fire(byText("Enregistrer mon profil", panel), "OnClick")
assert(db.profiles.Simple and db.profiles.Simple.bindings == nil and db.profiles.Simple.bars == nil)
panel.saveName._text = "Simple"
local popups = #POPUPS
fire(byText("Enregistrer mon profil", panel), "OnClick")
assert(#POPUPS == popups + 1 and POPUPS[#POPUPS].which == "BLOCKFORGE_REPLACE_SET")
fire(panel.saveChips[1], "OnClick")
fire(panel.saveChips[2], "OnClick")
-- profil identique a l'etat du jeu : rien a faire
state.chosen = "PvP"
P.Render()
assert(panel.activate._text == "Activer (0)" and panel.activate._enabled == false and panel.summary._text:find("déjà identiques : 2", 1, true))
assert(panel.info._text == "2 macros · touches : oui · barres : oui · Moi-Royaume", panel.info._text)

-- 3. activer : apercu de tout ce qui change, avec ce que chaque touche et chaque emplacement perd
MACROS.Kick.body = "/cast Autre"
BINDINGS.F = "ACTIONBUTTON3"
SLOTS[5] = { "spell", 172 }
DeleteMacro(MACROS.Soin.index)
CreateMacro("Extra", 9, "/dance")
SLOTS[7] = { "macro", MACROS.Extra.index }
fireEvent("UPDATE_MACROS")
local function lines() local out = {} for i, line in ipairs(state.lines) do out[i] = line end return table.concat(out, "\n") end
assert(lines() == "Créée : Soin\nRéécrite : Kick\nTouche F : macro « Kick », à la place de « Nom de ACTIONBUTTON3 »\nEmplacement 5 : macro « Kick », à la place de « Corruption »", lines())
assert(panel.lines[1]._text == "Créée : Soin" and panel.lines[5]._text == "" and panel.activate._text == "Activer (4)" and panel.activate._enabled == true)
assert(panel.summary._text == "À créer : 1 · à réécrire : 1 · laissées : 0 · déjà identiques : 0 · à retirer : 0 · touches : 1 · emplacements : 1", panel.summary._text)
local function option(key) for _, c in ipairs(panel.options) do if c.key == key then return c end end end
-- « reecrire » decoche : la macro de meme nom est laissee, et c'est ecrit
fire(option("update"), "OnClick")
assert(lines():find("Laissée (même nom, autre texte) : Kick", 1, true) and not lines():find("Réécrite", 1, true) and panel.activate._text == "Activer (3)")
fire(option("update"), "OnClick")
-- touches et barres decochees : rien de ce cote
fire(option("keys"), "OnClick")
fire(option("bars"), "OnClick")
assert(lines() == "Créée : Soin\nRéécrite : Kick" and panel.activate._text == "Activer (2)")
fire(option("keys"), "OnClick")
fire(option("bars"), "OnClick")
-- « retirer les absentes » : decoche au depart ; coche, la macro absente du profil est annoncee
assert(state.opts.remove == false and state.opts.update == true)
fire(option("remove"), "OnClick")
assert(lines():find("Archivée puis retirée : Extra", 1, true) and panel.activate._text == "Activer (5)")
-- rien n'a encore bouge
assert(MACROS.Kick.body == "/cast Autre" and BINDINGS.F == "ACTIONBUTTON3" and slotIs(5, "spell", 172) and MACROS.Extra and not MACROS.Soin and #db.personal == 0)
COMBAT = true
assert(P.Apply("PvP", state.opts) == nil and said("combat") and MACROS.Kick.body == "/cast Autre")
COMBAT = false
SAVED_BINDINGS = nil
fire(panel.activate, "OnClick")
assert(MACROS.Kick.body == "/cast Peur" and MACROS.Kick.icon == 7 and MACROS.Soin and MACROS.Soin.char == true and MACROS.Soin.body == "/cast Soins rapides", "macros du profil")
assert(not MACROS.Extra and #db.personal == 1 and db.personal[1].name == "Extra" and db.personal[1].body == "/dance" and db.personal[1].note == "Archivée à l'activation d'un profil.", "macro retiree sans archive")
assert(BINDINGS.F == "MACRO Kick" and BINDINGS.G == "ACTIONBUTTON2" and SAVED_BINDINGS == 2, "touches")
assert(slotIs(5, "macro", MACROS.Kick.index) and slotIs(6, "spell", 172) and slotIs(7, nil), "barres")
assert(printed("Profil « PvP » : 1 macro(s) créée(s), 1 mise(s) à jour, 1 archivée(s) puis retirée(s), 1 touche(s), 1 emplacement(s) ; 0 étape(s) refusée(s)"))
local backup = db.profiles["Auto 2026-11-20 12:00:00 profil"]
assert(backup and backup.auto and #backup.macros == 2 and backup.macros[1].body ~= nil and said("Sauvegarde automatique « Auto 2026-11-20 12:00:00 profil »"))
local kept
for _, s in ipairs(backup.macros) do if s.name == "Kick" then kept = s end end
assert(kept.body == "/cast Autre" and ns.UndoLabel() == "profil « PvP »" and #db.undo.ops == 5 and panel.status._text:find("Profil activé", 1, true))
assert(panel.activate._text == "Activer (0)" and panel.undo._text == "Annuler : profil « PvP »")
-- une seule annulation : emplacement, touche, creation, reecriture, suppression
SAVED_BINDINGS = nil
fire(panel.undo, "OnClick")
assert(said("5 étape(s) rétablie(s), 0 laissée(s)"), lastLine())
assert(MACROS.Kick.body == "/cast Autre" and not MACROS.Soin and MACROS.Extra and MACROS.Extra.body == "/dance" and MACROS.Extra.icon == 9, "macros apres annulation")
assert(BINDINGS.F == "ACTIONBUTTON3" and SAVED_BINDINGS == 2 and slotIs(5, "spell", 172) and slotIs(7, "macro", MACROS.Extra.index), "touches et barres apres annulation")
assert(#db.personal == 1 and ns.UndoLabel() == nil, "l'archive reste dans Mes modeles")
fire(option("remove"), "OnClick")
-- une touche liee ailleurs entre-temps n'est pas reprise par l'annulation
fire(panel.activate, "OnClick")
BINDINGS.F = "ACTIONBUTTON9"
fire(panel.undo, "OnClick")
assert(BINDINGS.F == "ACTIONBUTTON9" and said("1 laissée(s)"), lastLine())
-- pas assez de place : refus chiffre, rien ne bouge
local real, calls = GetNumMacros, #CALLS
GetNumMacros = function() local a = real() return a, 30 end
fire(panel.activate, "OnClick")
GetNumMacros = real
assert(said("il manque 0 place(s) dans les macros générales et 1 dans celles du personnage. Rien n'a été changé.") and #CALLS == calls and ns.UndoLabel() == nil, lastLine())
-- sans « Ameliorer ma barre » : la partie barres disparait de l'apercu
ns.SetFeature("bars", false)
assert(not option("bars"):IsShown() and not lines():find("Emplacement", 1, true))
ns.SetFeature("bars", true)
assert(option("bars"):IsShown() and lines():find("Emplacement 5", 1, true))

-- 4. copier depuis un autre personnage : noms de sorts dans la langue du jeu, sorts inconnus signales
fire(panel.foreign, "OnClick")
assert(names() == "Reroll" and panel.rows[1].text._text:find("Reroll-Royaume", 1, true) and state.chosen == "PvP")
fire(panel.rows[1], "OnClick")
assert(state.chosen == "Reroll" and lines() == "Créée : Sheep\nCréée : Peur" and not option("keys"):IsShown() and not option("bars"):IsShown(), lines())
assert(panel.warn._text == "1 macro(s) de ce profil utilisent un sort que ce personnage ne connaît pas.", panel.warn._text)
fire(panel.activate, "OnClick")
assert(MACROS.Peur and MACROS.Peur.char == true and MACROS.Peur.body == "/cast Peur" and MACROS.Sheep.body == "#showtooltip Sort118\n/cast [@mouseover,harm][] Sort118", MACROS.Sheep and MACROS.Sheep.body)
assert(db.profiles.Reroll.macros[2].body == "/cast Fear", "le profil enregistre ne doit pas etre traduit sur place")
fire(panel.undo, "OnClick")
assert(not MACROS.Peur and not MACROS.Sheep)
fire(panel.mine, "OnClick")

-- 5. export et import « BF2: » : macros seules ; l'import ajoute un profil et montre son apercu, sans rien creer
state.chosen = "PvP"
P.Render()
fire(panel.export, "OnClick")
local exported = panel.share._text
assert(exported == "BF2:PvP:2:a:Kick:/cast Peur:c:Soin:/cast Soins rapides" and FOCUS == panel.share, exported)
calls = #CALLS
fire(byText("Importer", panel), "OnClick")
local imported = db.profiles["PvP (2)"]
assert(imported and imported.imported == true and imported.bindings == nil and imported.bars == nil and #imported.macros == 2 and imported.macros[2].char == true)
assert(#CALLS == calls and state.chosen == "PvP (2)" and panel.share._text == "" and panel.status._text:find("Rien n'est créé", 1, true) and lines() == "Créée : Soin\nRéécrite : Kick", lines())
for _, bad in ipairs({ "BF1:Kick:%2Fsit", "BF2:x:2:a:A:%2Fsit", "n'importe quoi", "BF2z:AAAA" }) do
  n = 0
  for _ in pairs(db.profiles) do n = n + 1 end
  panel.share._text = bad
  fire(byText("Importer", panel), "OnClick")
  local after = 0
  for _ in pairs(db.profiles) do after = after + 1 end
  assert(after == n and #CALLS == calls and (said("BF2") or said("Profil abîmé") or said("compressé")), bad .. " : " .. lastLine())
end
assert(P.Codec() == nil, "compression sans C_EncodingUtil")
-- supprimer un profil : confirmation ; son association a une specialisation part avec lui
db.specProfiles["Moi-Royaume"] = { [1] = "PvP (2)" }
fire(panel.delete, "OnClick")
assert(POPUPS[#POPUPS].which == "BLOCKFORGE_DELETE_SET" and db.profiles["PvP (2)"])
accept("BLOCKFORGE_DELETE_SET")
assert(db.profiles["PvP (2)"] == nil and db.specProfiles["Moi-Royaume"][1] == nil and state.chosen == nil and panel.activate._enabled == false)

-- 6. double specialisation : un profil propose, hors combat seulement, jamais applique tout seul
state.chosen = "PvP"
P.Render()
assert(panel.specs[1]:IsShown() and panel.specs[2]:IsShown() and panel.specs[2].text._text == "Spé 2")
fire(panel.specs[2], "OnClick")
assert(db.specProfiles["Moi-Royaume"][2] == "PvP" and panel.specs[2]._border[1] == 0.53 and panel.specs[1]._border[1] ~= 0.53)
panel:Hide()
popups, calls = #POPUPS, #CALLS
fireEvent("PLAYER_TALENT_UPDATE") -- meme groupe : rien
assert(#POPUPS == popups)
SPEC = 2
COMBAT = true
fireEvent("ACTIVE_TALENT_GROUP_CHANGED")
assert(#POPUPS == popups, "proposition en combat")
COMBAT = false
fireEvent("PLAYER_REGEN_ENABLED")
local pop = POPUPS[#POPUPS]
assert(#POPUPS == popups + 1 and pop.which == "BLOCKFORGE_SPEC_PROFILE" and pop.text:find("spécialisation 2", 1, true) and pop.text:find("« PvP »", 1, true), pop.text)
assert(#CALLS == calls and MACROS.Kick.body == "/cast Autre" and not panel:IsShown(), "profil applique sans accord")
fireEvent("PLAYER_REGEN_ENABLED")
fireEvent("PLAYER_TALENT_UPDATE")
assert(#POPUPS == popups + 1, "proposition repetee")
accept("BLOCKFORGE_SPEC_PROFILE") -- « Oui » ouvre l'apercu : c'est « Activer » qui applique
assert(panel:IsShown() and state.chosen == "PvP" and #CALLS == calls and MACROS.Kick.body == "/cast Autre")
-- retour a la specialisation 1, sans profil associe : rien
SPEC = 1
fireEvent("ACTIVE_TALENT_GROUP_CHANGED")
assert(#POPUPS == popups + 1)
-- la fonction coupee : plus d'ecoute, plus de proposition, plus de puces
ns.SetFeature("specProfiles", false)
assert(find(function(x) return x._events.ACTIVE_TALENT_GROUP_CHANGED or x._events.PLAYER_TALENT_UPDATE end) == nil and not panel.specs[1]:IsShown())
SPEC = 2
fireEvent("ACTIVE_TALENT_GROUP_CHANGED")
fireEvent("PLAYER_REGEN_ENABLED")
assert(#POPUPS == popups + 1)
ns.SetFeature("specProfiles", true)
assert(find(function(x) return x._events.ACTIVE_TALENT_GROUP_CHANGED end) and panel.specs[1]:IsShown())

-- 7. « Restaurer » de la colonne ouvre l'apercu du profil choisi ; le combat ferme le panneau
panel:Hide()
fireEvent("UPDATE_MACROS")
local setRow = find(function(x) return x.text and x._parent == more._parent and x.text._text and x.text._text:find("Simple", 1, true) end)
assert(setRow, "profil absent de la colonne")
fire(setRow, "OnClick")
fire(byText("Restaurer", w.macros), "OnClick")
assert(panel:IsShown() and state.chosen == "Simple")
fireEvent("PLAYER_REGEN_DISABLED")
assert(not panel:IsShown())
`, "=profils");

// client sans double specialisation, avec la compression du client : puces cachees, aucune ecoute ; export compresse seulement s'il se relit
boot("{ tutorialSeen = true }", LOTB + String.raw`
C_SpecializationInfo = nil
function GetLocale() return "frFR" end
Enum.CompressionMethod = { Deflate = 0 }
PACK_OK = true
STORE = {} -- faux compresseur : le texte est range, et rendu par son numero
C_EncodingUtil = {
  CompressString = function(s, method) assert(method == 0) STORE[#STORE + 1] = s return "\1" .. #STORE end,
  DecompressString = function(s, method) assert(method == 0) return PACK_OK and STORE[tonumber(s:sub(2))] or "?" end,
  EncodeBase64 = function(s) return "Z" .. s:sub(2) end,
  DecodeBase64 = function(s) return "\1" .. s:sub(2) end,
}
`);
run(String.raw`
local ns, db = NS, BlockForgeDB
assert(ns.Profiles.ActiveSpec() == nil and find(function(x) return x._events.ACTIVE_TALENT_GROUP_CHANGED or x._events.PLAYER_TALENT_UPDATE end) == nil)
for i = 1, 12 do CreateMacro("Macro" .. i, 1, "/cast Sort numero " .. i) end
SlashCmdList.BLOCKFORGE("profil")
local panel = ns.profilesPanel
panel.saveName._text = "Tout"
fire(byText("Enregistrer mon profil", panel), "OnClick")
assert(not panel.specs[1]:IsShown() and not panel.specs[2]:IsShown(), "puces de specialisation sans l'API")
local codec = ns.Profiles.Codec()
assert(codec and codec.unpack(codec.pack("BF2:a:/cast X")) == "BF2:a:/cast X")
local plain = ns.ExportProfile("Tout", db.profiles.Tout.macros)
fire(panel.export, "OnClick")
local packed = panel.share._text
assert(packed:sub(1, 5) == "BF2z:" and #packed < #plain and not packed:find("[^%w_:]"), packed)
fire(byText("Importer", panel), "OnClick")
local back = db.profiles["Tout (2)"]
assert(back and #back.macros == 12 and back.macros[12].body == "/cast Sort numero 12", "import compresse")
-- la compression du client ne se relit pas : export en clair
PACK_OK = false
fire(panel.export, "OnClick")
assert(panel.share._text:sub(1, 4) == "BF2:" and panel.share._text:sub(1, 5) ~= "BF2z:")
-- et un texte compresse illisible est refuse sans rien ajouter
panel.share._text = packed
fire(byText("Importer", panel), "OnClick")
assert(db.profiles["Tout (3)"] == nil and lastLine():find("BF2", 1, true), lastLine())
SlashCmdList.BLOCKFORGE("test")
local report = table.concat(db.selftest.lines, "\n")
assert(report:find("plain (compression did not round-trip, or was not shorter)", 1, true) and report:find("spec API active group nil", 1, true), report)
PACK_OK = true
SlashCmdList.BLOCKFORGE("test")
report = table.concat(db.selftest.lines, "\n")
assert(report:find("OK BF2 profile round trip: 20 macros", 1, true) and report:find("compressed with C_EncodingUtil", 1, true) and not report:find("FAIL v1 lot B", 1, true), report)
`, "=profils sans double specialisation");

// ---------------------------------------------------------------- 15. V1 lot B : chaque fonction coupee cache ses entrees et n'ecoute plus rien
boot("{ tutorialSeen = true }", LOTB);
run(String.raw`
local ns, db = NS, BlockForgeDB
local function said(fragment) return lastLine():find(fragment, 1, true) ~= nil end
local function refused(label) return said("« " .. label .. " » : fonction désactivée dans les Paramètres") end
local function listening(event) return find(function(x) return x._events[event] end) ~= nil end
SLOTS[1] = { "spell", 172 }
BAGS[0] = { 929 }
SlashCmdList.BLOCKFORGE("")
local w, home, view = ns.ed.w, ns.home, ns.ed
-- tout est construit et ouvert une fois
ns.OpenKits()
ns.OpenLiving()
ns.OpenProfiles()
ns.Open("editor")
view.Load("Potion", "/use {bf:potion_soin}")
view.SaveMacro("Potion", "/use {bf:potion_soin}", false, nil, false)
assert(MACROS.Potion.body == "/use Potion de soins" and ns.LivingLabel("Potion", false) == "vivante")
local kits, living, profiles = ns.kitsPanel, ns.livingPanel, ns.profilesPanel
local kitTile, profileTile = home.tiles[5], home.tiles[6]
local livingLine = find(function(x) return x.text and x._parent == w.homeTop and x._point and x._point[2] == 640 and x._point[3] == -72 end)
local kitLine = find(function(x) return x.text and x._parent == w.homeTop and x._point and x._point[2] == 640 and x._point[3] == -50 end)
local column = byText("Profils…", w.macros)._parent
assert(kitTile:IsShown() and profileTile:IsShown() and livingLine:IsShown() and column:IsShown() and w.livingChip:IsShown())
assert(listening("PLAYER_EQUIPMENT_CHANGED") and listening("ACTIVE_TALENT_GROUP_CHANGED"))
-- un seul grand panneau a la fois sur une page
ns.OpenKits()
assert(kits:IsShown() and not living:IsShown())
ns.OpenLiving()
assert(living:IsShown() and not kits:IsShown())
ns.OpenWand()
assert(ns.wand:IsShown() and not living:IsShown())
ns.OpenKits()
assert(kits:IsShown() and not ns.wand:IsShown())
ns.OpenHealth()
assert(ns.health:IsShown() and not kits:IsShown())
ns.OpenLiving()

-- macros vivantes coupees : plus d'ecoute, plus de reecriture, plus de jeton, plus d'entree
ns.SetFeature("living", false)
assert(db.features.living == false and not listening("PLAYER_EQUIPMENT_CHANGED") and not living:IsShown() and not livingLine:IsShown())
assert(not w.livingChip:IsShown() and not w.livingMenu:IsShown() and ns.LivingLabel("Potion", false) == nil)
BAGS[0] = { 13446 }
local edits = count("EditMacro")
fireEvent("BAG_UPDATE_DELAYED")
assert(#TIMERS == 0 and ns.Living.Pass() == 0 and count("EditMacro") == edits and MACROS.Potion.body == "/use Potion de soins", "reecriture malgre la coupure")
SlashCmdList.BLOCKFORGE("vivant")
assert(refused("Macros vivantes") and not living:IsShown())
-- un jeton ne peut plus etre enregistre : il n'arrive jamais dans une macro du jeu
local created = count("CreateMacro")
view.SaveMacro("Jeton", "/use {bf:potion_soin}", false, nil, false)
assert(refused("Macros vivantes") and count("CreateMacro") == created and not MACROS.Jeton)
assert(ns.Living.Resume("Potion", false) == nil and refused("Macros vivantes"))
-- l'editeur ouvre le texte du jeu ; l'Assistant et les kits n'ont plus de recette vivante
view.Load("Potion", MACROS.Potion.body)
assert(ns.Compile(view.Blocks()) == "/use Potion de soins")
ns.OpenAssistant({ name = "Potion de soins", kind = "item" })
for _, r in ipairs(ns.assistant.state.recipes) do assert(r.feature ~= "living", r.id) end
assert(#ns.assistant.state.recipes == 2)
ns.assistant:Hide()
ns.OpenKits()
for _, item in ipairs(kits.state.items) do assert(not item.living and item.name ~= "Survie", item.name) end
assert(#kits.state.items >= 8)
-- reactivee : la macro suit de nouveau
ns.SetFeature("living", true)
assert(listening("PLAYER_EQUIPMENT_CHANGED") and livingLine:IsShown() and ns.LivingLabel("Potion", false) == "vivante")
fireEvent("BAG_UPDATE_DELAYED")
tick()
assert(MACROS.Potion.body == "/use Potion de soins majeure")

-- kits coupes
ns.OpenKits()
local item
for _, it in ipairs(kits.state.items) do if it.name == "Soulstone" then item = it end end
ns.SetFeature("kits", false)
assert(not kits:IsShown() and not kitTile:IsShown() and profileTile:IsShown() and profileTile._point[2] == 8 and profileTile._point[3] == -86, "tuile des kits encore la")
SlashCmdList.BLOCKFORGE("kit")
assert(refused("Kits de personnage") and not kits:IsShown())
created = count("CreateMacro")
assert(ns.KitsUI.Install({ item }, { role = "leveling", hover = true, pet = false }) == nil and refused("Kits de personnage") and count("CreateMacro") == created)
assert(next(db.profiles) == nil and db.kits["Moi-Royaume"] == nil, "sauvegarde ou kit retenu malgre la coupure")
ns.SetFeature("kits", true)
assert(kitTile:IsShown() and profileTile._point[2] == 226)
-- un kit en attente de sorts ecoute le grimoire ; coupe, il n'ecoute plus et sa ligne disparait
ns.OpenKits()
local before, watcher = {}, nil
for _, x in ipairs(ALL) do if x._events.SPELLS_CHANGED then before[x] = true end end
ns.KitsUI.Install({ item }, { role = "leveling", hover = true, pet = false })
local waiting = next(db.kits["Moi-Royaume"].waiting)
for _, x in ipairs(ALL) do if x._events.SPELLS_CHANGED and not before[x] then watcher = x end end
assert(waiting and watcher and watcher._events.PLAYER_REGEN_ENABLED, "le kit n'ecoute pas les sorts appris")
for _, it in ipairs(kits.state.items) do
  if it.name == waiting then
    for _, spell in ipairs(it.unknown) do BEST[spell] = 1 end
  end
end
fireEvent("SPELLS_CHANGED")
tick()
assert(kitLine:IsShown())
ns.SetFeature("kits", false)
assert(not kitLine:IsShown() and not watcher._events.SPELLS_CHANGED and not watcher._events.PLAYER_REGEN_ENABLED and #ns.KitsUI.Ready() == 0)
ns.SetFeature("kits", true)
assert(kitLine:IsShown() and watcher._events.SPELLS_CHANGED)

-- profils coupes : la colonne de « Mes macros », la tuile et le panneau disparaissent ; la sauvegarde automatique reste
ns.OpenProfiles()
ns.SetFeature("profiles", false)
assert(not profiles:IsShown() and not profileTile:IsShown() and not column:IsShown() and not listening("ACTIVE_TALENT_GROUP_CHANGED"))
SlashCmdList.BLOCKFORGE("profil")
assert(refused("Profils") and not profiles:IsShown())
local name = ns.Backup("essai")
assert(name and db.profiles[name].auto == true, "le filet de securite ne depend pas de la fonction")
local calls = #CALLS
assert(ns.Profiles.Apply(name, { update = true }) == nil and refused("Profils") and #CALLS == calls)
SPEC = 2
fireEvent("ACTIVE_TALENT_GROUP_CHANGED")
fireEvent("PLAYER_REGEN_ENABLED")
for _, p in ipairs(POPUPS) do assert(p.which ~= "BLOCKFORGE_SPEC_PROFILE") end
-- les trois fonctions coupees : l'etape de la visite qui en parle est sautee ; une seule active : elle ne parle que de celle-la
ns.SetFeature("living", false)
ns.SetFeature("kits", false)
SlashCmdList.BLOCKFORGE("tuto")
local tour = ns.Tutorial
assert(#ns.TutorialSteps == 12 and #tour.steps == 11, #tour.steps)
for _, s in ipairs(tour.steps) do assert(s.any == nil, "etape des fonctions coupees") end
tour.Stop()
ns.SetFeature("living", true)
SlashCmdList.BLOCKFORGE("tuto")
assert(#tour.steps == 12 and tour.steps[2].any)
fire(tour.coach.next, "OnClick")
assert(tour.coach.text._text == "Une macro « vivante » suit tes sacs et ton équipement : BlockForge la réécrit hors combat.", tour.coach.text._text)
tour.Stop()
-- Les fonctions du lot B restent accessibles apres defilement.
fire(byText("Paramètres", BlockForgeFrame), "OnClick")
local list, seen = w.settings.featureList, {}
list.offset = 7 list.Render()
for i, cb in ipairs(list.rows) do
  if cb.def then
    seen[cb.def.id] = cb
    assert(-cb._point[3] + cb._h <= list._h, cb.def.id)
  end
end
assert(seen.living._checked == true and seen.kits._checked == false and seen.profiles._checked == false and seen.specProfiles._checked == true)
click(seen.kits, true)
click(seen.profiles, true)
assert(kitTile:IsShown() and profileTile:IsShown() and column:IsShown() and listening("ACTIVE_TALENT_GROUP_CHANGED"))
ns.ResetDB()
for _, def in ipairs(ns.Features) do assert(ns.Enabled(def.id), def.id) end
assert(db.living.account.Potion and db.kits["Moi-Royaume"] and db.profiles[name], "la reinitialisation des reglages garde les modeles, le kit et les profils")
`, "=fonctions du lot B");

// coupees des le chargement : rien n'ecoute, aucune entree ; donnees abimees remises d'aplomb
boot(`{ tutorialSeen = true, features = { living = false, kits = false, profiles = false }, living = { chars = 5, account = { Bidon = 7, Vraie = { template = "/use {bf:bijou13}", body = "/use X" } }, journal = "non" },
  kits = { ["Moi-Royaume"] = { class = "WARLOCK", role = "leveling", hover = true, pet = false, waiting = { ["Drain Soul MO"] = true } } }, profiles = 5, specProfiles = "non" }`, LOTB);
run(String.raw`
local ns, db = NS, BlockForgeDB
local function listening(event) return find(function(x) return x._events[event] end) ~= nil end
assert(type(db.living.chars) == "table" and type(db.living.journal) == "table" and type(db.profiles) == "table" and type(db.specProfiles) == "table")
-- seul UI.lua ecoute SPELLS_CHANGED (cache du grimoire) : ni les macros vivantes, ni le kit retenu qui attend pourtant un sort
local spellListeners = 0
for _, x in ipairs(ALL) do if x._events.SPELLS_CHANGED then spellListeners = spellListeners + 1 end end
assert(not listening("PLAYER_EQUIPMENT_CHANGED") and not listening("BAG_UPDATE_DELAYED") and not listening("ACTIVE_TALENT_GROUP_CHANGED") and spellListeners == 1, spellListeners)
SlashCmdList.BLOCKFORGE("")
local home, w = ns.home, ns.ed.w
assert(#home.tiles == 6 and not home.tiles[5]:IsShown() and not home.tiles[6]:IsShown() and home.tiles[4]:IsShown())
assert(not find(function(x) return x.text and x._parent == w.homeTop and x._point and x._point[2] == 640 and x:IsShown() end), "lignes du bandeau malgre la coupure")
assert(not byText("Profils…", w.macros)._parent:IsShown())
ns.Open("editor")
assert(not w.livingChip:IsShown())
-- reactivees : les entrees reviennent, l'entree illisible des macros vivantes est retiree, l'autre gardee
ns.SetFeature("living", true)
ns.SetFeature("kits", true)
ns.SetFeature("profiles", true)
assert(listening("PLAYER_EQUIPMENT_CHANGED") and listening("ACTIVE_TALENT_GROUP_CHANGED") and home.tiles[5]:IsShown() and home.tiles[6]:IsShown())
local list = ns.Living.List()
assert(#list == 1 and list[1].name == "Vraie" and db.living.account.Bidon == nil and type(list[1].rec.last) == "table")
`, "=fonctions du lot B au chargement");

console.log("test_ui.js : OK (15 scenarios)");
