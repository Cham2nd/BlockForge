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
local tabEditor, tabLibrary = byText("Éditeur"), byText("Bibliothèque")
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
assert(not libRows[1]:IsShown(), "classe vide : aucune ligne")
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
assert(#checks == 12, "cases : " .. #checks) -- 8 reglages + 2 choix de classe + 2 couleurs d'accent
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
assert(#gameChecks == 12)
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

-- sauvegarde puis restauration : mise a jour + creation + manque de place
COMBAT = true
fire(byText("Sauvegarder mes macros"), "OnClick")
assert(lastLine():find("combat") and next(db.sets) == nil, "sauvegarde en combat")
COMBAT = false
fire(byText("Sauvegarder mes macros"), "OnClick")
local set = db.sets["2026-11-20"]
assert(set and #set == 3, "sauvegarde absente")
setBox._text = "2026-11-20"
fire(byText("Sauvegarder mes macros"), "OnClick")
local replacePop = POPUPS[#POPUPS]
assert(replacePop.which == "BLOCKFORGE_REPLACE_SET" and replacePop.text:find("2026-11-20", 1, true) and not lastLine():find("remplac"), "confirmation attendue avant de remplacer")
StaticPopupDialogs.BLOCKFORGE_REPLACE_SET.OnAccept({}, replacePop.data)
assert(lastLine():find("remplac"), lastLine())
set = db.sets["2026-11-20"]
set[#set + 1] = { name = "Trop", body = "/sit", char = true }
MACROS["Soin"].body = "/cast Autre"
MACROS["Sans curseur"] = nil       -- supprimee en jeu : les index suivants glissent
MACROS["Soin"].index = 1
for i = 2, 30 do MACROS["Perso" .. i] = { index = 120 + i, body = "/sit", char = true } end -- onglet personnage plein
local restoreBtn = byText("Restaurer")
COMBAT = true
fire(restoreBtn, "OnClick")
assert(lastLine():find("combat"), "restauration en combat")
COMBAT = false
local popupsBefore2 = #POPUPS
fire(restoreBtn, "OnClick")
local pop = POPUPS[#POPUPS]
assert(#POPUPS == popupsBefore2 + 1 and pop.which == "BLOCKFORGE_RESTORE" and pop.text:find("2026-11-20", 1, true), "confirmation attendue")
COMBAT = true
StaticPopupDialogs.BLOCKFORGE_RESTORE.OnAccept({}, pop.data) -- combat commence pendant la confirmation
assert(MACROS["Soin"].body == "/cast Autre", "restauration en combat")
COMBAT = false
StaticPopupDialogs.BLOCKFORGE_RESTORE.OnAccept({}, pop.data)
assert(MACROS["Soin"].body == soinBody and MACROS["Test BM"] and MACROS["Sans curseur"], "restauration incomplete")
assert(MACROS["Sans curseur"].index == 2 and not MACROS["Trop"], "creation ou place")
assert(lastLine():find("2 mises à jour, 1 créées, 1 ignorées"), lastLine())
assert(MACROS["Perso2"].body == "/sit", "macro absente de la sauvegarde modifiee")
for i = 2, 30 do MACROS["Perso" .. i] = nil end
fireEvent("UPDATE_MACROS")
-- les sauvegardes survivent a la reinitialisation, la suppression demande confirmation
ns.ResetDB()
assert(db.sets["2026-11-20"], "sauvegarde perdue a la reinitialisation")
fire(byText("Supprimer", mPage), "OnClick")
assert(POPUPS[#POPUPS].which == "BLOCKFORGE_DELETE_SET")
StaticPopupDialogs.BLOCKFORGE_DELETE_SET.OnAccept({}, POPUPS[#POPUPS].data)
assert(db.sets["2026-11-20"] == nil, "sauvegarde non supprimee")

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
io.write(#ALL .. " widgets, " .. #CALLS .. " appels macro, " .. #PRINTS .. " messages\n")
for _, p in ipairs(PRINTS) do io.write("  > ", p, "\n") end
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
boot("nil", `function GetLocale() return "enUS" end`);
run(String.raw`
SlashCmdList.BLOCKFORGE("")
assert(BlockForgeFrame.TitleText._text == "BlockForge — block-based macro editor")
-- visite guidee en anglais : lancee a la premiere ouverture, aucun texte reste en francais
local coach = NS.Tutorial.coach
assert(NS.Tutorial.step == 1 and coach.title._text == "Blocks" and coach.next._text == "Next" and coach.skip._text == "Skip", coach.title._text)
for _, s in ipairs(NS.TutorialSteps) do
  for _, c in ipairs({ "é", "è", "ê", "à", "ù", "ç", "«", "»", " :", " ;", " ?" }) do
    assert(not (s.title .. s.text):find(c, 1, true), "etape en francais : " .. s.title)
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

-- A. tutoriel : premiere ouverture en combat = rien, la visite attend ; hors combat elle se lance une seule fois
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
assert(#steps >= 8 and #steps <= 10, #steps)
assert(coach._parent == BlockForgeFrame and coach._w == 320 and coach._h == 140)
local tabs = { editor = byText("Éditeur"), library = byText("Bibliothèque"), macros = byText("Mes macros", BlockForgeFrame), settings = byText("Paramètres", BlockForgeFrame) }
local seenTabs = {}
for i, s in ipairs(steps) do
  assert(tour.step == i, "etape " .. i)
  -- chaque etape : onglet affiche, widget existant et visible dans la fenetre, panneau et cadre poses dessus, textes non vides
  local anchor = s.anchor()
  assert(getmetatable(anchor) == WIDGET and inside(anchor, BlockForgeFrame), "repere de l'etape " .. i)
  assert(tabs[s.tab].line:IsShown() and anchor:IsVisible(), "onglet de l'etape " .. i)
  assert(coach._point[2] == anchor and tour.frame._point[2] == anchor, "panneau non pose sur le repere " .. i)
  assert(coach.title._text == s.title and coach.text._text == s.text and #s.title > 3 and #s.text > 40 and #s.text < 330, "texte de l'etape " .. i)
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
  assert(tour.step == 1 and coach:IsShown() and tabs.editor.line:IsShown(), cmd)
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
assert(tour.step == 1 and tabs.editor.line:IsShown())
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

console.log("test_ui.js : OK (8 scenarios)");
