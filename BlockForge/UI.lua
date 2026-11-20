-- BlockForge : interface (editeur par blocs + bibliotheque + parametres). Ouvrir avec /bf
local ADDON, ns = ...
local L = ns.L

local MAX_ROWS = 12    -- lignes visibles ; la molette fait defiler au-dela (la vraie limite : 255 caracteres)
local MAX_CLAUSES = 4
local MAX_LIB_ROWS = 18 -- lignes visibles ; la molette fait defiler au-dela
local ROW_W, ROW_H, ROW_STEP = 360, 24, 27
local BACKDROP = BackdropTemplateMixin and "BackdropTemplate" or nil
local WHITE = "Interface\\Buttons\\WHITE8x8"
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
-- Forever : Constants.MacroConsts (120 / 30) ; Classic Era : globales MAX_*_MACROS
local MACRO_CONSTS = (Constants and Constants.MacroConsts) or {}
local MAX_ACCOUNT = MACRO_CONSTS.MAX_ACCOUNT_MACROS or MAX_ACCOUNT_MACROS or 120
local MAX_CHARACTER = MACRO_CONSTS.MAX_CHARACTER_MACROS or MAX_CHARACTER_MACROS or 18

-- Palette de l'interface
local GOLD = { 1, 0.82, 0.1 }
local GREY = { 0.3, 0.3, 0.34 }
local MUTED = { 0.62, 0.62, 0.66 }
-- une couleur par groupe de conditions (meme ordre que ns.ConditionGroups)
local GROUP_COLORS = { { 0.35, 0.75, 0.95 }, { 0.95, 0.45, 0.45 }, { 0.72, 0.52, 0.98 }, { 0.98, 0.66, 0.25 }, { 0.45, 0.85, 0.55 } }
local GROUP_COLS = { 3, 3, 4, 3, 3 } -- boutons par ligne : les touches (libelles courts) tiennent sur une seule
local PILL_LABEL = { nomod = L["Sans touche"] } -- libelles trop vagues hors de leur groupe

local blocks, selected, activeClause = {}, nil, 1
local rows, condButtons, clauseTabs = {}, {}, {}
local editOffset, editRange = 0, nil -- rows[i] affiche blocks[editOffset + i]
local Refresh
local main, editor, library, settingsTab, canvas, dropLine
local nameBox, perChar, argBox, argLabel, resetBox, resetLabel, inspTitle, inspBody, inspHint
local preview, counter, counterBar, warnText, fixButton

local function Msg(text) print(L["|cff66ccffBlockForge|r : %s"]:format(text)) end

---------------------------------------------------------------------------
-- Petits constructeurs
---------------------------------------------------------------------------
local function Panel(parent, w, h, title)
  local f = CreateFrame("Frame", nil, parent, BACKDROP)
  f:SetSize(w, h)
  f:SetBackdrop({ bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                  edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
  f:SetBackdropColor(0.04, 0.04, 0.06, 0.9)
  f:SetBackdropBorderColor(0.45, 0.45, 0.5)
  if title then
    -- bandeau de titre : la meme hierarchie dans tous les panneaux
    local band = f:CreateTexture(nil, "BORDER")
    band:SetColorTexture(0.13, 0.13, 0.17, 1)
    band:SetPoint("TOPLEFT", 3, -3)
    band:SetPoint("TOPRIGHT", -3, -3)
    band:SetHeight(20)
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.35)
    line:SetPoint("TOPLEFT", band, "BOTTOMLEFT")
    line:SetPoint("TOPRIGHT", band, "BOTTOMRIGHT")
    line:SetHeight(1)
    local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("LEFT", band, "LEFT", 7, 0)
    t:SetText(title)
    f.band = band
  end
  return f
end

local function Label(parent, text, x, y, font)
  local t = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormalSmall")
  t:SetPoint("TOPLEFT", x, y)
  t:SetJustifyH("LEFT")
  t:SetText(text)
  return t
end

-- Pastille : fond sombre de la couleur, bordure de 1 px de la couleur vive
local PILL_BACKDROP = { bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 }
local function Tint(chip, color, alpha)
  alpha = alpha or 0.8
  chip:SetBackdropColor(color[1] * 0.45, color[2] * 0.45, color[3] * 0.45, alpha)
  chip:SetBackdropBorderColor(color[1], color[2], color[3], math.min(1, alpha + 0.25))
end

local function Chip(parent, w, h)
  local b = CreateFrame("Button", nil, parent, BACKDROP)
  b:SetSize(w, h)
  b:SetBackdrop(PILL_BACKDROP)
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.text:SetPoint("LEFT", 6, 0)
  b.text:SetPoint("RIGHT", -6, 0)
  b.text:SetJustifyH("LEFT")
  b.text:SetWordWrap(false)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetPoint("TOPLEFT", 1, -1)
  hl:SetPoint("BOTTOMRIGHT", -1, 1)
  hl:SetColorTexture(1, 1, 1, 0.12)
  return b
end

-- Barre de couleur a gauche d'une puce (type de bloc, element choisi)
local function SideBar(frame, color)
  local bar = frame:CreateTexture(nil, "ARTWORK")
  bar:SetPoint("TOPLEFT", 1, -1)
  bar:SetPoint("BOTTOMLEFT", 1, 1)
  bar:SetWidth(4)
  bar:SetColorTexture(color[1], color[2], color[3], 1)
  return bar
end

local function Button(parent, text, w, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, 22)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

local function Edit(parent, w, onChange)
  local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  e:SetSize(w, 20)
  e:SetAutoFocus(false)
  e:SetScript("OnTextChanged", function(self, user) if user then onChange(self:GetText()) end end)
  e:SetScript("OnEnterPressed", e.ClearFocus)
  e:SetScript("OnEscapePressed", e.ClearFocus)
  return e
end

local function SetTextIfIdle(box, text)
  if not box:HasFocus() then box:SetText(text or "") end
end

-- Infobulle : lines(self) renvoie le titre puis des lignes grises (masquees si l'aide est coupee)
local function Tip(frame, lines)
  frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local t = { lines(self) }
    if not t[1] then return end
    GameTooltip:SetText(t[1], 1, 1, 1, 1, true)
    if not ns.db or ns.db.helpTooltips then
      for i = 2, #t do GameTooltip:AddLine(t[i], 0.8, 0.8, 0.8, true) end
    end
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Tab / Maj+Tab passent au champ visible suivant / precedent de la liste
local function TabOrder(boxes)
  for i, box in ipairs(boxes) do
    box:SetScript("OnTabPressed", function()
      local step = IsShiftKeyDown() and -1 or 1
      for k = 1, #boxes - 1 do
        local nextBox = boxes[(i - 1 + k * step) % #boxes + 1]
        if nextBox:IsVisible() then return nextBox:SetFocus() end
      end
    end)
  end
end

-- partages avec Settings.lua
ns.ui = { Panel = Panel, Label = Label, Button = Button, Tip = Tip }

-- police du code : le client n'a pas de police a chasse fixe, ARIALN (etroite) est la plus lisible
local codeFont = CreateFont("BlockForgeCodeFont")
codeFont:SetFont("Fonts\\ARIALN.TTF", 13, "")
codeFont:SetTextColor(0.9, 0.95, 0.9)

---------------------------------------------------------------------------
-- Sort ou objet tenu par le curseur (glisse depuis le grimoire ou les sacs)
---------------------------------------------------------------------------
local function CursorPayload()
  local kind, a, _, c = GetCursorInfo()
  local name
  if kind == "spell" then
    local id = c or a
    name = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or (GetSpellInfo and GetSpellInfo(id))
  elseif kind == "item" then
    name = ((C_Item and C_Item.GetItemInfo) or GetItemInfo)(a)
  end
  if not name then return nil end
  ClearCursor()
  return name, (kind == "item") and "use" or "cast"
end

local function EditedArgHolder()
  if not selected then return nil end
  return selected.clauses and selected.clauses[activeClause] or selected
end

local function Select(block)
  -- sans cela, un champ garde le focus et la frappe suivante irait dans le nouveau bloc
  argBox:ClearFocus()
  resetBox:ClearFocus()
  selected, activeClause = block, 1
  -- bloc hors des lignes visibles : on fait defiler jusqu'a lui
  for i, b in ipairs(blocks) do
    if b == block then editOffset = math.min(math.max(editOffset, i - MAX_ROWS), i - 1) end
  end
  Refresh()
end

local function AddBlock(id, at, arg)
  local block = ns.NewBlock(id)
  if arg then
    if block.clauses then block.clauses[1].arg = arg else block.arg = arg end
  end
  table.insert(blocks, at or (#blocks + 1), block)
  Select(block)
end

---------------------------------------------------------------------------
-- Rendu d'un bloc : barre de type, icone, commande, pastilles de conditions, argument
---------------------------------------------------------------------------
local condInfo = {} -- cond -> { label, color }
for gi, group in ipairs(ns.ConditionGroups) do
  for _, item in ipairs(group.items) do
    local label = PILL_LABEL[item[1]] or item[2]
    condInfo[item[1]] = { gi == 1 and ("@ " .. label) or label, GROUP_COLORS[gi] or GREY }
  end
end

local function Light(c) return math.min(1, c[1] + 0.25), math.min(1, c[2] + 0.25), math.min(1, c[3] + 0.25) end

local function ArgIcon(block)
  if InCombatLockdown() then return nil end -- pas de recherche de sort en combat (valeurs secretes)
  local arg
  for _, holder in ipairs(block.clauses or { block }) do
    arg = ns.trim(holder.arg or "")
    if arg ~= "" then break end
  end
  if not arg or arg == "" then return nil end
  local name = ns.trim(((arg:gsub("^reset=%S+%s*", "")):match("^[^,]+") or ""):gsub("^!", ""))
  if name == "" then return nil end
  if block.type == "use" or block.type == "equip" then
    local slot = tonumber(name)
    if slot then return GetInventoryItemTexture and GetInventoryItemTexture("player", slot) end
    local getItemIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
    return getItemIcon and getItemIcon(name)
  end
  if block.type == "raw" or block.type == "target" or block.type == "focus" or block.type == "assist" then return nil end
  local getSpellIcon = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
  if not getSpellIcon then return nil end
  return getSpellIcon(name) or getSpellIcon((name:gsub("%s*%(.-%)$", "")))
end

-- sorts que le personnage ne connait pas : la recherche par nom ne repond que pour les sorts connus
-- shortcut: techniques de familier ignorees (inconnues tant que le familier n'est pas sorti)
local function UnknownSpells(blockList)
  local unknown = {}
  if InCombatLockdown() or not (C_Spell and C_Spell.GetSpellInfo) then return unknown end
  for _, name in ipairs(ns.SpellsOf(blockList)) do
    if not ns.PetSpells[name:lower()] and not tonumber(name) and not C_Spell.GetSpellInfo(name) then
      unknown[#unknown + 1] = name
    end
  end
  return unknown
end

local function RowPart(row, kind, n)
  local pool = row[kind]
  if not pool[n] then
    if kind == "pills" then
      local p = CreateFrame("Frame", nil, row, BACKDROP)
      p:SetHeight(16)
      p:SetBackdrop(PILL_BACKDROP)
      p.text = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      p.text:SetPoint("CENTER")
      pool[n] = p
    else
      pool[n] = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      pool[n]:SetWordWrap(false)
    end
  end
  return pool[n]
end

local function LayoutRow(row, block, def)
  row.bar:SetColorTexture(def.color[1], def.color[2], def.color[3], 1)
  local icon = ArgIcon(block)
  if icon then
    row.icon:SetTexture(icon)
  elseif def.arg then
    row.icon:SetTexture(QUESTION)
  else
    row.icon:SetColorTexture(def.color[1] * 0.6, def.color[2] * 0.6, def.color[3] * 0.6, 1)
  end
  row.cmd:SetText(def.cmd ~= "" and def.cmd or L["ligne libre"])
  row.cmd:SetTextColor(Light(def.color))

  local x, limit = 31 + (row.cmd:GetStringWidth() or 0) + 7, ROW_W - 16
  local used, overflow = { pills = 0, texts = 0 }, false
  local function put(w, width)
    if overflow or x + width > limit then overflow = true w:Hide() return end
    w:ClearAllPoints()
    w:SetPoint("LEFT", row, "LEFT", x, 0)
    w:Show()
    x = x + width + 4
  end
  local function pill(text, color)
    used.pills = used.pills + 1
    local p = RowPart(row, "pills", used.pills)
    p.text:SetText(text)
    Tint(p, color, 0.95)
    local width = (p.text:GetStringWidth() or 0) + 10
    p:SetWidth(width)
    put(p, width)
  end
  local function text(s, r, g, b)
    used.texts = used.texts + 1
    local t = RowPart(row, "texts", used.texts)
    t:SetText(s)
    t:SetTextColor(r, g, b)
    put(t, t:GetStringWidth() or 0)
  end
  local needsArg = def.arg and not def.optional

  if not def.clauses then
    local arg = ns.trim(block.arg or "")
    if arg ~= "" then text(arg, 1, 1, 1)
    elseif needsArg then text(L["(vide)"], 0.6, 0.6, 0.6) end
  else
    if def.reset and (block.reset or "") ~= "" then pill("reset=" .. block.reset, MUTED) end
    for ci, clause in ipairs(block.clauses) do
      if ci > 1 then text(L["sinon"], MUTED[1], MUTED[2], MUTED[3]) end
      for _, cond in ipairs(clause.conds) do
        local info = condInfo[cond]
        pill(info and info[1] or cond, info and info[2] or GREY)
      end
      if (clause.alt or "") ~= "" then text(clause.alt, MUTED[1], MUTED[2], MUTED[3]) end
      local arg = ns.trim(clause.arg or "")
      if arg ~= "" then text(arg, 1, 1, 1)
      elseif needsArg then text(L["(argument ?)"], 1, 0.4, 0.4) end
    end
  end
  for kind, n in pairs(used) do
    for i = n + 1, #row[kind] do row[kind][i]:Hide() end
  end
  row.more:SetShown(overflow) -- texte complet : infobulle de la ligne et apercu
end

---------------------------------------------------------------------------
-- Glisser-deposer des blocs
---------------------------------------------------------------------------
local ghost, drag

-- lignes visibles occupees par un bloc
local function VisibleCount() return math.max(0, math.min(MAX_ROWS, #blocks - editOffset)) end

local function DropIndex()
  local _, y = GetCursorPosition()
  for i = 1, VisibleCount() do
    local row = rows[i]
    local mid = (row:GetTop() + row:GetBottom()) / 2 * row:GetEffectiveScale()
    if y > mid then return editOffset + i end
  end
  return editOffset + VisibleCount() + 1
end

-- info.from : index du bloc deplace ; info.row : sa ligne, estompee pendant le glisser
local function StartDrag(info, label, color)
  drag = info
  ghost.text:SetText(label)
  Tint(ghost, color, 0.95)
  ghost:Show()
  GameTooltip:Hide()
  if info.row then info.row:SetAlpha(0.35) end
end

local function EndDrag()
  local d = drag
  drag = nil
  ghost:Hide()
  dropLine:Hide()
  if d and d.row then d.row:SetAlpha(1) end
  if not d or not canvas:IsMouseOver() then return end
  local at = DropIndex()
  if d.new then
    AddBlock(d.new, at)
  else
    local block = table.remove(blocks, d.from)
    if at > d.from then at = at - 1 end
    table.insert(blocks, at, block)
    Select(block)
  end
end

local function GhostUpdate(self)
  local x, y = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  self:ClearAllPoints()
  self:SetPoint("LEFT", UIParent, "BOTTOMLEFT", x / scale + 12, y / scale)
  if canvas:IsMouseOver() then
    local at, n = DropIndex() - editOffset, VisibleCount()
    dropLine:ClearAllPoints()
    if at <= n then
      dropLine:SetPoint("BOTTOMLEFT", rows[at], "TOPLEFT", 0, 1)
    elseif n > 0 then
      dropLine:SetPoint("TOPLEFT", rows[n], "BOTTOMLEFT", 0, -1)
    else
      dropLine:SetPoint("TOPLEFT", canvas, "TOPLEFT", 8, -26)
    end
    dropLine:Show()
  else
    dropLine:Hide()
  end
end

---------------------------------------------------------------------------
-- Enregistrement dans les macros du jeu
---------------------------------------------------------------------------
local function Overwrite(name, body)
  if InCombatLockdown() then return Msg(L["Impossible de modifier une macro en combat."]) end
  local index = GetMacroIndexByName(name) -- relu : l'index a pu changer pendant la confirmation
  if not index or index == 0 then return Msg(L["La macro « %s » n'existe plus."]:format(name)) end
  EditMacro(index, name, nil, body)
  Msg(L["Macro « %s » mise à jour."]:format(name))
end

if StaticPopupDialogs then
  StaticPopupDialogs.BLOCKFORGE_OVERWRITE = {
    text = L["La macro « %s » existe déjà. La remplacer ?"],
    button1 = YES or L["Oui"], button2 = NO or L["Non"],
    OnAccept = function(_, data) Overwrite(data.name, data.body) end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  }
end

local function Save()
  local name = ns.trim(nameBox:GetText())
  local body = ns.Compile(blocks)
  if InCombatLockdown() then return Msg(L["Impossible de modifier une macro en combat."]) end
  if name == "" then return Msg(L["Donne un nom à la macro."]) end
  if body == "" then return Msg(L["La macro est vide."]) end
  if #body > ns.MAX_CHARS then return Msg(L["Macro trop longue : %d / %d."]:format(#body, ns.MAX_CHARS)) end
  local index = GetMacroIndexByName(name)
  if index and index > 0 then
    if ns.db.confirmOverwrite and StaticPopup_Show then
      StaticPopup_Show("BLOCKFORGE_OVERWRITE", name, nil, { name = name, body = body })
    else
      Overwrite(name, body)
    end
    return
  end
  local forChar = perChar:GetChecked() and true or false
  local numAccount, numChar = GetNumMacros()
  if forChar and numChar >= MAX_CHARACTER then return Msg(L["Plus de place dans les macros du personnage."]) end
  if not forChar and numAccount >= MAX_ACCOUNT then return Msg(L["Plus de place dans les macros générales."]) end
  local created = CreateMacro(name, "INV_Misc_QuestionMark", body, forChar)
  if not created or created == 0 then return Msg(L["Le jeu a refusé de créer la macro."]) end
  if ns.db.pickupAfterCreate then
    PickupMacro(created) -- la macro vient sous le curseur : il reste a la poser sur une barre
    Msg(L["Macro « %s » créée. Pose-la sur une barre d'action."]:format(name))
  else
    Msg(L["Macro « %s » créée (%s)."]:format(name, forChar and L["macros du personnage"] or L["macros générales"]))
  end
end

function ns.ApplyPerCharDefault()
  if perChar then perChar:SetChecked(ns.db.perCharDefault) end
end

local function LoadText(name, body)
  blocks = ns.Parse(body or "")
  nameBox:SetText(name or "")
  selected, activeClause, editOffset = blocks[1], 1, 0
  Refresh()
  return true
end

-- le nom tape est garde : un modele est un point de depart, pas une macro du jeu
local function LoadTemplate(tpl) LoadText(nameBox:GetText(), tpl.body) end

if StaticPopupDialogs then
  StaticPopupDialogs.BLOCKFORGE_TEMPLATE = {
    text = L["Remplacer le contenu de l'éditeur par le modèle « %s » ?"],
    button1 = YES or L["Oui"], button2 = NO or L["Non"],
    OnAccept = function(_, tpl) LoadTemplate(tpl) end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  }
end

local function ChooseTemplate(tpl)
  if #blocks > 0 and StaticPopup_Show then
    StaticPopup_Show("BLOCKFORGE_TEMPLATE", tpl.label, nil, tpl)
  else
    LoadTemplate(tpl)
  end
end

local function LoadExisting()
  local name = ns.trim(nameBox:GetText())
  local macroName, _, body = GetMacroInfo(name)
  if not macroName then return Msg(L["Aucune macro nommée « %s »."]:format(name)) end
  LoadText(macroName, body)
end

---------------------------------------------------------------------------
-- Simulateur : l'apercu colore l'alternative qui partirait pour l'etat choisi
---------------------------------------------------------------------------
-- seuls ces etats sont reglables ; les autres conditions restent "inconnues" pour ns.Simulate
local simOn, simState = false, { mod = false, target = "harm", targetDead = false, mouseover = "none", focus = "none" }
local SIM_CHIPS = {
  { L["Touche : %s"], 92, { { L["Aucune"], { mod = false } }, { L["Maj"], { mod = "shift" } },
      { L["Ctrl"], { mod = "ctrl" } }, { L["Alt"], { mod = "alt" } } } },
  { L["Cible : %s"], 100, { { L["Hostile"], { target = "harm", targetDead = false } }, { L["Morte"], { target = "harm", targetDead = true } },
      { L["Amie"], { target = "help", targetDead = false } }, { "—", { target = "none", targetDead = false } } } },
  { L["Survol : %s"], 116, { { "—", { mouseover = "none" } }, { L["Hostile"], { mouseover = "harm" } }, { L["Amie"], { mouseover = "help" } } } },
  { L["Focus : %s"], 96, { { "—", { focus = "none" } }, { L["Hostile"], { focus = "harm" } }, { L["Amie"], { focus = "help" } } } },
}
local SIM_OK, SIM_OFF, SIM_UNKNOWN = "|cff66ff66", "|cff777777", "|cffffaa33"

local function SimulatedText()
  local results, lines = ns.Simulate(blocks, simState), {}
  for i, block in ipairs(blocks) do
    local line, res = ns.CompileBlock(block), results[i]
    if line ~= "" and res then
      local def = ns.BlockById[block.type]
      local color = not res.clause and SIM_OFF or res.unknown and SIM_UNKNOWN or SIM_OK
      local parts = {}
      for ci, clause in ipairs(block.clauses) do
        local t = ns.CompileClause(clause, block.reset)
        if t ~= "" then parts[#parts + 1] = (ci == res.clause and color or SIM_OFF) .. t .. "|r" end
      end
      line = color .. def.cmd .. "|r" .. (#parts > 0 and (" " .. table.concat(parts, "; ")) or "")
      if not res.clause then line = line .. SIM_OFF .. "  —|r"
      elseif res.unknown then line = line .. SIM_UNKNOWN .. "  ?|r"
      elseif def.arg or block.type == "petattack" then line = line .. SIM_OK .. "  -> @" .. res.unit .. "|r" end
    end
    if line ~= "" then lines[#lines + 1] = line end
  end
  return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- Rafraichissement
---------------------------------------------------------------------------
function Refresh()
  editOffset = math.max(0, math.min(editOffset, #blocks - MAX_ROWS))
  editRange:SetText(#blocks > MAX_ROWS
    and L["%d-%d / %d  (molette)"]:format(editOffset + 1, editOffset + MAX_ROWS, #blocks) or "")
  for i, row in ipairs(rows) do
    local block = blocks[editOffset + i]
    if block then
      local def = ns.BlockById[block.type]
      local isSel = block == selected
      local line = ns.CompileBlock(block)
      row.full = line ~= "" and line or def.label
      LayoutRow(row, block, def)
      if isSel then
        row:SetBackdropColor(0.2, 0.18, 0.08, 1)
        row:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
      else
        row:SetBackdropColor(0.09, 0.09, 0.11, 0.95)
        row:SetBackdropBorderColor(def.color[1] * 0.7, def.color[2] * 0.7, def.color[3] * 0.7, 1)
      end
      row:Show()
    else
      row:Hide()
    end
  end
  canvas.hint:SetShown(#blocks == 0)

  local def = selected and ns.BlockById[selected.type]
  inspBody:SetShown(def ~= nil)
  inspHint:SetShown(def == nil)
  if def then
    inspTitle:SetText(def.label .. "  |cff888888" .. def.cmd .. "|r")
    inspTitle:SetTextColor(Light(def.color))
    local holder = EditedArgHolder()
    argLabel:SetText(def.arg and L["Argument : %s"]:format(def.arg) or L["Pas d'argument"])
    argBox:SetShown(def.arg ~= nil)
    SetTextIfIdle(argBox, holder.arg)
    resetLabel:SetShown(def.reset == true)
    resetBox:SetShown(def.reset == true)
    SetTextIfIdle(resetBox, selected.reset)
    local n = selected.clauses and #selected.clauses or 0
    for i, tab in ipairs(clauseTabs) do
      tab:SetShown(i <= n)
      Tint(tab, i == activeClause and GOLD or GREY, i == activeClause and 0.95 or 0.7)
    end
    clauseTabs.box:SetShown(n > 0)
    for _, b in ipairs(condButtons) do
      local on = n > 0 and ns.HasCond(holder, b.cond)
      Tint(b, on and b.color or GREY, on and 1 or 0.6)
      b.text:SetTextColor(1, 1, 1, on and 1 or 0.75)
    end
  end

  local text, warnings = ns.Diagnose(blocks)
  local unknown = UnknownSpells(blocks)
  local fix
  if #unknown > 0 then
    for i, name in ipairs(unknown) do
      local near = ns.Nearest(name, ns.SpellBook())
      if near then
        fix = fix or { name, near }
        unknown[i] = L["%s (proche : %s)"]:format(name, near)
      end
    end
    warnings[#warnings + 1] = L["Sort inconnu de ce personnage (ou mal écrit) : %s"]:format(table.concat(unknown, ", "))
  end
  fixButton.fix = fix
  fixButton:SetShown(fix ~= nil)
  if fix then fixButton.text:SetText(L["Remplacer par « %s »"]:format(fix[2])) end
  local len = #text
  preview:SetText(text ~= "" and (simOn and SimulatedText() or text) or "|cff777777" .. L["(la macro compilée s'affiche ici)"] .. "|r")
  local ratio = math.min(1, len / ns.MAX_CHARS)
  local r, g = len > ns.MAX_CHARS and 1 or (ratio > 0.85 and 1 or 0.3), len > ns.MAX_CHARS and 0.25 or (ratio > 0.85 and 0.7 or 0.9)
  counter:SetText(("%d / %d"):format(len, ns.MAX_CHARS))
  counter:SetTextColor(r, g, 0.3)
  counterBar:SetWidth(math.max(1, counterBar.max * ratio))
  counterBar:SetColorTexture(r, g, 0.3, 0.9)
  warnText:SetText(table.concat(warnings, "\n"))
end

-- Bas de l'editeur, hors de BuildEditor : Lua 5.1 (le jeu) refuse plus de 60 upvalues par fonction
local function BuildBottom(parent, palette)
  -- Bas : apercu (gauche) | nom et enregistrement (droite)
  local bottom = Panel(parent, 884, 130, L["Aperçu"])
  bottom:SetPoint("TOPLEFT", palette, "BOTTOMLEFT", 0, -6)
  counter = bottom:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  counter:SetPoint("RIGHT", bottom.band, "LEFT", 430, 0)
  local barBg = bottom:CreateTexture(nil, "ARTWORK")
  barBg:SetColorTexture(1, 1, 1, 0.08)
  barBg:SetPoint("TOPLEFT", 10, -29)
  barBg:SetSize(420, 4)
  counterBar = bottom:CreateTexture(nil, "OVERLAY")
  counterBar:SetPoint("TOPLEFT", barBg)
  counterBar:SetHeight(4)
  counterBar.max = 420
  preview = Label(bottom, "", 10, -38, "BlockForgeCodeFont")
  preview:SetSize(420, 86) -- hauteur fixe : une macro tres longue est coupee au lieu de deborder du panneau
  preview:SetJustifyV("TOP")

  -- Simulateur dans le bandeau : bouton entre le titre et le compteur (fini a 430), etats de 446 a 863
  local simChips = {}
  local simToggle = Chip(bottom, 80, 16)
  simToggle:SetPoint("TOPLEFT", 74, -5)
  simToggle.text:SetText(L["Simuler"])
  local function SimSync()
    Tint(simToggle, simOn and GOLD or GREY, simOn and 0.95 or 0.7)
    for _, chip in ipairs(simChips) do
      chip:SetShown(simOn)
      chip.text:SetText(chip.spec[1]:format(chip.spec[3][chip.at][1]))
    end
  end
  simToggle:SetScript("OnClick", function() simOn = not simOn SimSync() Refresh() end)
  Tip(simToggle, function()
    return L["Simuler : quelle ligne part"],
      L["Choisis l'état du jeu à droite. Dans l'aperçu : vert = l'alternative qui part (-> unité visée), gris = ne part pas, orange = condition que le simulateur ne sait pas évaluer."],
      L["Il ne connaît ni les temps de recharge, ni la portée, ni l'étape en cours d'une /castsequence."]
  end)
  local sx = 446
  for i, spec in ipairs(SIM_CHIPS) do
    local chip = Chip(bottom, spec[2], 16)
    chip:SetPoint("TOPLEFT", sx, -5)
    sx = sx + spec[2] + 3
    chip.spec, chip.at = spec, 1
    Tint(chip, MUTED, 0.6)
    chip:SetScript("OnClick", function()
      chip.at = chip.at % #spec[3] + 1
      for k, v in pairs(spec[3][chip.at][2]) do simState[k] = v end
      SimSync()
      Refresh()
    end)
    Tip(chip, function() return chip.text:GetText(), L["Clic : valeur suivante."] end)
    simChips[i] = chip
  end
  SimSync()

  local split = bottom:CreateTexture(nil, "ARTWORK")
  split:SetColorTexture(1, 1, 1, 0.12)
  split:SetPoint("TOPLEFT", 440, -30)
  split:SetSize(1, 92)

  Label(bottom, L["Nom"], 452, -36, "GameFontNormal")
  nameBox = Edit(bottom, 140, function() end)
  nameBox:SetPoint("TOPLEFT", 490, -32)
  nameBox:SetMaxLetters(16)
  Tip(nameBox, function() return L["Nom de la macro"], L["16 caractères max. Un nom existant est mis à jour au lieu d'être recréé."] end)
  perChar = CreateFrame("CheckButton", nil, bottom, "UICheckButtonTemplate")
  perChar:SetSize(24, 24)
  perChar:SetPoint("LEFT", nameBox, "RIGHT", 8, 0)
  perChar:SetChecked(ns.db.perCharDefault)
  local perCharText = Label(bottom, L["Ce personnage seulement"], 0, 0, "GameFontHighlightSmall")
  perCharText:ClearAllPoints()
  perCharText:SetPoint("LEFT", perChar, "RIGHT", 2, 0)

  local save = Button(bottom, L["Créer / mettre à jour"], 150, Save)
  save:SetPoint("TOPLEFT", 450, -58)
  Tip(save, function() return L["Créer / mettre à jour"], L["Hors combat seulement."] end)
  local load = Button(bottom, L["Charger ce nom"], 120, LoadExisting)
  load:SetPoint("LEFT", save, "RIGHT", 6, 0)
  Tip(load, function() return L["Charger ce nom"], L["Ouvre dans l'éditeur la macro du jeu qui porte ce nom."] end)
  local reset = Button(bottom, L["Tout effacer"], 110, function() LoadText("", "") ns.ApplyPerCharDefault() end)
  reset:SetPoint("LEFT", load, "RIGHT", 6, 0)
  warnText = Label(bottom, "", 452, -86, "GameFontRedSmall")
  warnText:SetWidth(420)
  -- sort mal ecrit : un clic met le nom du grimoire a la place
  fixButton = Chip(bottom, 240, 16)
  fixButton:SetPoint("BOTTOMRIGHT", -8, 5)
  Tint(fixButton, GOLD, 0.6)
  fixButton:Hide()
  fixButton:SetScript("OnClick", function()
    local old, new = fixButton.fix[1], fixButton.fix[2]
    for _, block in ipairs(blocks) do
      if block.type == "cast" or block.type == "castsequence" then
        for _, clause in ipairs(block.clauses or {}) do
          local s, e = (clause.arg or ""):find(old, 1, true)
          if s then clause.arg = clause.arg:sub(1, s - 1) .. new .. clause.arg:sub(e + 1) end
        end
      end
    end
    Refresh()
  end)
end

-- Ligne i de la zone de construction : elle affiche blocks[editOffset + i]
local function BuildRow(i)
  local row = CreateFrame("Button", nil, canvas, BACKDROP)
  row:SetSize(ROW_W, ROW_H)
  row:SetPoint("TOPLEFT", 8, -28 - (i - 1) * ROW_STEP)
  row:SetBackdrop(PILL_BACKDROP)
  row.pills, row.texts = {}, {}
  row.bar = SideBar(row, GREY)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(18, 18)
  row.icon:SetPoint("LEFT", 8, 0)
  row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  row.cmd = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.cmd:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
  row.more = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.more:SetPoint("RIGHT", -5, 0)
  row.more:SetText("…")
  local hl = row:CreateTexture(nil, "HIGHLIGHT")
  hl:SetPoint("TOPLEFT", 1, -1)
  hl:SetPoint("BOTTOMRIGHT", -1, 1)
  hl:SetColorTexture(1, 1, 1, 0.08)
  row:RegisterForDrag("LeftButton")
  row:SetScript("OnClick", function() Select(blocks[editOffset + i]) end)
  row:SetScript("OnDragStart", function()
    local def = ns.BlockById[blocks[editOffset + i].type]
    StartDrag({ from = editOffset + i, row = row }, row.full or def.label, def.color)
  end)
  row:SetScript("OnDragStop", EndDrag)
  -- un sort lache sur une ligne s'insere a cette place, ou remplit l'emplacement vide du bloc (modele)
  row:SetScript("OnReceiveDrag", function()
    local name, id = CursorPayload()
    if not name then return end
    local block = blocks[editOffset + i]
    if block and (block.type == id or block.type == "castsequence") then
      for _, clause in ipairs(block.clauses) do
        if ns.trim(clause.arg) == "" then clause.arg = name return Select(block) end
      end
    end
    AddBlock(id, math.min(editOffset + i, #blocks + 1), name)
  end)
  Tip(row, function()
    if drag or not blocks[editOffset + i] then return end
    return row.full, L["Clic : régler. Glisser : déplacer."]
  end)
  local del = Button(row, "x", 22, function()
    if selected == blocks[editOffset + i] then selected = nil end
    table.remove(blocks, editOffset + i)
    Refresh()
  end)
  del:SetPoint("LEFT", row, "RIGHT", 2, 0)
  Tip(del, function() return L["Supprimer ce bloc"] end)
  return row
end

-- Modeles : bouton en bas de la zone (les 12 lignes finissent a -349), liste au-dessus
-- un modele par technique du familier sorti (barre du familier) ; les ordres (attaque, suivre...) sont des jetons PET_
function ns.PetTemplates()
  local list = {}
  if not GetPetActionInfo then return list end
  for i = 1, NUM_PET_ACTION_SLOTS or 10 do
    local name = GetPetActionInfo(i)
    if type(name) == "string" and not name:find("^PET_") then
      ns.PetSpells[name:lower()] = true -- pas d'avertissement "sort inconnu"
      list[#list + 1] = { label = L["Familier : %s"]:format(name),
        desc = L["Lance %s (technique du familier sorti) sur l'unité survolée, sinon sur ta cible."]:format(name),
        body = "#showtooltip\n/cast [@mouseover,exists,nodead][] " .. name }
    end
  end
  return list
end

local function BuildTemplates()
  local tplList = Panel(canvas, 220, 12)
  local chips = {}
  local function Fill()
    local list = {}
    for _, tpl in ipairs(ns.Templates) do list[#list + 1] = tpl end
    for _, tpl in ipairs(ns.PetTemplates()) do list[#list + 1] = tpl end
    tplList:SetHeight(12 + #list * 22)
    for i, tpl in ipairs(list) do
      local chip = chips[i]
      if not chip then
        chip = Chip(tplList, 204, 20)
        chip:SetPoint("TOPLEFT", 8, -6 - (i - 1) * 22)
        Tint(chip, GOLD, 0.45)
        chip:SetScript("OnClick", function() tplList:Hide() ChooseTemplate(chip.tpl) end)
        Tip(chip, function() return chip.tpl.label, chip.tpl.desc end)
        chips[i] = chip
      end
      chip.tpl = tpl
      chip.text:SetText(tpl.label)
      chip:Show()
    end
    for i = #list + 1, #chips do chips[i]:Hide() end
  end
  Fill()
  local tplButton = Button(canvas, L["Modèles"], 100, function()
    if not tplList:IsShown() then Fill() end -- le familier a pu changer
    tplList:SetShown(not tplList:IsShown())
  end)
  tplButton:SetPoint("BOTTOMLEFT", 8, 8)
  Tip(tplButton, function() return L["Modèles"], L["Point de départ guidé : choisis un modèle, puis glisse tes sorts sur les blocs marqués « (argument ?) »."] end)
  tplList:SetPoint("BOTTOMLEFT", tplButton, "TOPLEFT", 0, 2)
  tplList:SetFrameStrata("DIALOG")
  tplList:EnableMouse(true) -- le fond arrete les clics : pas de clic sur les lignes en dessous
  tplList:Hide()
  -- onglet change ou fenetre fermee (Echap compris) : la liste se ferme aussi
  canvas:HookScript("OnHide", function() tplList:Hide() end)
end

---------------------------------------------------------------------------
-- Construction de l'editeur
---------------------------------------------------------------------------
local function BuildEditor(parent)
  -- Palette
  local palette = Panel(parent, 176, 430, L["Blocs"])
  palette:SetPoint("TOPLEFT", 0, 0)
  for i, def in ipairs(ns.BlockDefs) do
    local chip = Chip(palette, 160, 18)
    chip:SetPoint("TOPLEFT", 8, -28 - (i - 1) * 19) -- 21 blocs : le dernier finit a -426 (panneau : 430)
    chip.text:SetPoint("LEFT", 10, 0)
    chip.text:SetText(def.label)
    Tint(chip, def.color, 0.55)
    SideBar(chip, def.color)
    chip:RegisterForDrag("LeftButton")
    chip:SetScript("OnDragStart", function() StartDrag({ new = def.id }, def.label, def.color) end)
    chip:SetScript("OnDragStop", EndDrag)
    chip:SetScript("OnClick", function() AddBlock(def.id) end)
    Tip(chip, function()
      return def.label, def.cmd ~= "" and def.cmd or L["Ligne tapée telle quelle"],
        L["Clic : ajoute en bas. Glisser : place où tu veux."]
    end)
  end

  -- Zone de construction
  canvas = Panel(parent, 400, 430, L["Ta macro — glisse les blocs ici, ou clique dessus"])
  canvas:SetPoint("TOPLEFT", palette, "TOPRIGHT", 6, 0)
  canvas:EnableMouse(true)
  local function CanvasDrop()
    local name, id = CursorPayload()
    if name then AddBlock(id, nil, name) end
  end
  canvas:SetScript("OnReceiveDrag", CanvasDrop)
  canvas:SetScript("OnMouseUp", CanvasDrop)
  canvas.hint = Label(canvas, L["Vide : clique un bloc à gauche, ou glisse ici\nun sort du grimoire ou un objet des sacs."],
    12, -36, "GameFontDisableSmall")
  for i = 1, MAX_ROWS do rows[i] = BuildRow(i) end
  canvas:EnableMouseWheel(true)
  canvas:SetScript("OnMouseWheel", function(_, delta)
    editOffset = editOffset - delta * 3
    Refresh()
  end)
  editRange = canvas:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  editRange:SetPoint("BOTTOMRIGHT", -10, 14)
  BuildTemplates()

  dropLine = canvas:CreateTexture(nil, "OVERLAY")
  dropLine:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
  dropLine:SetSize(ROW_W, 2)
  dropLine:Hide()

  ghost = Chip(UIParent, 220, 22)
  ghost:SetFrameStrata("TOOLTIP")
  ghost:EnableMouse(false)
  ghost:Hide()
  ghost:SetScript("OnUpdate", GhostUpdate)

  -- Reglages du bloc selectionne
  local insp = Panel(parent, 296, 430, L["Réglages du bloc"])
  insp:SetPoint("TOPLEFT", canvas, "TOPRIGHT", 6, 0)
  inspHint = Label(insp, L["Clique un bloc de ta macro\npour le régler."], 10, -34, "GameFontDisableSmall")
  inspBody = CreateFrame("Frame", nil, insp)
  inspBody:SetAllPoints()
  inspTitle = Label(inspBody, "", 10, -28, "GameFontHighlight")

  -- Alternatives "[conditions] argument; [conditions] argument"
  clauseTabs.box = CreateFrame("Frame", nil, inspBody)
  clauseTabs.box:SetPoint("TOPLEFT", 0, -44)
  clauseTabs.box:SetSize(296, 22)
  Label(clauseTabs.box, L["Alternative"], 10, -5)
  for i = 1, MAX_CLAUSES do
    local tab = Chip(clauseTabs.box, 22, 20)
    tab:SetPoint("TOPLEFT", 80 + (i - 1) * 24, 0)
    tab.text:ClearAllPoints()
    tab.text:SetPoint("CENTER")
    tab.text:SetText(i)
    tab:SetScript("OnClick", function() argBox:ClearFocus() activeClause = i Refresh() end)
    Tip(tab, function() return L["Alternative %d"]:format(i), L["Le jeu essaie les alternatives dans l'ordre : la première dont les conditions sont vraies est utilisée."] end)
    clauseTabs[i] = tab
  end
  local add = Button(clauseTabs.box, "+", 24, function()
    if #selected.clauses >= MAX_CLAUSES then return end
    selected.clauses[#selected.clauses + 1] = ns.NewClause()
    activeClause = #selected.clauses
    Refresh()
  end)
  add:SetPoint("TOPLEFT", 184, 1)
  Tip(add, function() return L["Ajouter une alternative"], L["Exemple : [@mouseover,harm] Peur; Peur"] end)
  local remove = Button(clauseTabs.box, "-", 24, function()
    if #selected.clauses <= 1 then return end
    argBox:ClearFocus()
    table.remove(selected.clauses, activeClause)
    activeClause = math.min(activeClause, #selected.clauses)
    Refresh()
  end)
  remove:SetPoint("LEFT", add, "RIGHT", 2, 0)
  Tip(remove, function() return L["Retirer l'alternative affichée"] end)

  argLabel = Label(inspBody, "", 10, -72)
  argBox = Edit(inspBody, 268, function(text)
    EditedArgHolder().arg = text
    Refresh()
  end)
  argBox:SetPoint("TOPLEFT", 14, -86)
  local function ArgDrop()
    local name = CursorPayload()
    if not name then return end
    EditedArgHolder().arg = name
    argBox:ClearFocus()
    Refresh()
  end
  argBox:SetScript("OnReceiveDrag", ArgDrop)
  argBox:HookScript("OnMouseDown", ArgDrop)
  Tip(argBox, function() return L["Argument"], L["Tape le nom, ou glisse ici un sort du grimoire / un objet des sacs."] end)

  resetLabel = Label(inspBody, L["reset=  (ex. 3, target, combat)"], 80, -113)
  resetBox = Edit(inspBody, 56, function(text)
    selected.reset = ns.trim(text)
    Refresh()
  end)
  resetBox:SetPoint("TOPLEFT", 14, -108)

  -- Conditions. Les y sont comptes depuis le haut du panneau (box est a -44, d'ou le +44).
  -- Pas : titre 12, ligne 16, ecart 1, 12 lignes => le champ "Autre condition" finit a -425 (panneau : 430).
  local sep = clauseTabs.box:CreateTexture(nil, "ARTWORK")
  sep:SetColorTexture(1, 1, 1, 0.12)
  sep:SetPoint("TOPLEFT", 8, -131 + 44)
  sep:SetSize(280, 1)
  local y = -134
  for gi, group in ipairs(ns.ConditionGroups) do
    local color = GROUP_COLORS[gi] or GREY
    local title = Label(clauseTabs.box, group.label .. (group.exclusive and "  |cff888888" .. L["(une seule)"] .. "|r" or ""), 10, y + 44)
    title:SetTextColor(Light(color))
    y = y - 12
    local cols = GROUP_COLS[gi] or 3
    local step = math.floor(276 / cols)
    for i, item in ipairs(group.items) do
      local col, line = (i - 1) % cols, math.floor((i - 1) / cols)
      local b = Chip(clauseTabs.box, step - 2, 15)
      b:SetPoint("TOPLEFT", 10 + col * step, y + 44 - line * 16)
      b.text:SetText(item[2])
      b.cond, b.color = item[1], color
      b:SetScript("OnClick", function()
        ns.ToggleCond(EditedArgHolder(), item[1])
        Refresh()
      end)
      Tip(b, function() return item[2], "[" .. item[1] .. "]  " .. L["clic : activer / retirer"] end)
      condButtons[#condButtons + 1] = b
    end
    y = y - math.ceil(#group.items / cols) * 16 - 1
  end
  Label(clauseTabs.box, L["Autre condition (ex. stance:1) puis Entrée"], 10, y + 44)
  local custom = Edit(clauseTabs.box, 150, function() end)
  custom:SetPoint("TOPLEFT", 14, y + 30)
  custom:SetScript("OnEnterPressed", function(self)
    local cond = ns.trim(self:GetText())
    if cond ~= "" and not ns.HasCond(EditedArgHolder(), cond) then ns.ToggleCond(EditedArgHolder(), cond) end
    self:SetText("")
    self:ClearFocus()
    Refresh()
  end)
  local clear = Button(clauseTabs.box, L["Vider"], 80, function()
    local holder = EditedArgHolder()
    holder.conds, holder.alt = {}, nil
    Refresh()
  end)
  clear:SetPoint("LEFT", custom, "RIGHT", 8, 0)
  Tip(clear, function() return L["Vider"], L["Retire toutes les conditions de l'alternative affichée."] end)
  TabOrder({ argBox, resetBox, custom })

  BuildBottom(parent, palette)
end

---------------------------------------------------------------------------
-- Bibliotheque
---------------------------------------------------------------------------
local FAV = "FAVORITES" -- pseudo-classe : jamais memorisee comme derniere classe
local CLASS_ORDER = { FAV, "ALL", "WARLOCK", "HUNTER", "ROGUE", "MAGE", "PRIEST", "DRUID", "WARRIOR", "PALADIN", "SHAMAN" }
local CATEGORY_COLOR = { PvE = { 0.25, 0.55, 0.95 }, PvP = { 0.9, 0.35, 0.35 }, Pet = { 0.85, 0.7, 0.2 }, Utility = { 0.3, 0.75, 0.4 } }
local CATEGORY_LABEL = { Pet = L["Familier"], Utility = L["Utilitaire"] }

-- noms traduits des techniques de familier, pour l'avertissement monture de ns.Diagnose
for name, id in pairs(ns.SpellIDs) do
  local localized = ns.PetSpells[name:lower()] and ((C_Spell and C_Spell.GetSpellName) or GetSpellInfo)(id)
  if localized then ns.PetSpells[localized:lower()] = true end
end

-- description affichee : descEN hors client francais, s'il existe
local ENGLISH = GetLocale and GetLocale() ~= "frFR"
local function LibraryDesc(entry) return ENGLISH and entry.descEN or entry.desc end

-- nom d'objet : nil tant que l'objet n'est pas en cache (demande dans BuildLibrary)
local GetItemName = C_Item and C_Item.GetItemNameByID

-- la bibliotheque est ecrite en anglais : traduite a la demande, et seulement si le reglage le veut
local function LibraryBody(entry)
  if not ns.db.localizeLibrary then return entry.body end
  if not entry.localized then
    entry.localized = ns.Localize(entry.body, (C_Spell and C_Spell.GetSpellName) or GetSpellInfo, RANK, GetItemName)
  end
  return entry.localized
end

-- texte cherche par la recherche : calcule une fois par macro et par langue d'affichage
local function SearchText(entry)
  local lang = ns.db.localizeLibrary
  if entry.searchLang ~= lang then
    entry.search = ns.Fold(entry.name .. "\n" .. (LibraryDesc(entry) or "") .. "\n" .. LibraryBody(entry))
    entry.searchLang = lang
  end
  return entry.search
end

-- sorts de la macro inconnus du personnage, gardes jusqu'a ce que ses sorts changent ou que le combat finisse
local GetSpellName = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
function ns.LibraryUnknown(entry)
  if not entry.unknown then
    -- noms dans la langue du client, meme si l'affichage traduit est coupe
    entry.unknown = UnknownSpells(ns.Parse(ns.Localize(entry.body, GetSpellName, RANK)))
  end
  return entry.unknown
end
-- noms du grimoire du joueur, gardes jusqu'a SPELLS_CHANGED ; liste vide si le client n'a aucune des deux API
local spellBook
function ns.SpellBook()
  if spellBook then return spellBook end
  local list, seen = {}, {}
  local function Add(name)
    if name and not seen[name] then seen[name] = true list[#list + 1] = name end
  end
  pcall(function()
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
      for tab = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local info = C_SpellBook.GetSpellBookSkillLineInfo(tab)
        for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
          Add(C_SpellBook.GetSpellBookItemName(i, Enum.SpellBookSpellBank.Player))
        end
      end
    else
      for tab = 1, GetNumSpellTabs() do
        local _, _, offset, count = GetSpellTabInfo(tab)
        for i = offset + 1, offset + count do Add((GetSpellBookItemName(i, "spell"))) end
      end
    end
  end)
  if #list > 0 then spellBook = list end -- vide a la connexion : on reessaie au prochain appel
  return list
end

local usableEvents = CreateFrame("Frame")
usableEvents:RegisterEvent("SPELLS_CHANGED")
usableEvents:RegisterEvent("PLAYER_REGEN_ENABLED") -- en combat, UnknownSpells ne verifie rien
usableEvents:SetScript("OnEvent", function()
  spellBook = nil
  for _, entry in ipairs(ns.Library or {}) do entry.unknown = nil end
end)

local function BuildLibrary(parent, showEditor)
  local classPanel = Panel(parent, 176, 566, L["Classe"])
  classPanel:SetPoint("TOPLEFT", 0, 0)
  local listPanel = Panel(parent, 300, 566, L["Macros"])
  listPanel:SetPoint("TOPLEFT", classPanel, "TOPRIGHT", 6, 0)
  local detail = Panel(parent, 396, 566, L["Détail"])
  detail:SetPoint("TOPLEFT", listPanel, "TOPRIGHT", 6, 0)

  local title = Label(detail, "", 10, -32, "GameFontHighlightLarge")
  title:SetWidth(376)
  local desc = Label(detail, L["Choisis une macro dans la liste."], 10, -56, "GameFontHighlightSmall")
  desc:SetWidth(376)
  local body = Label(detail, "", 0, 0, "BlockForgeCodeFont")
  body:ClearAllPoints()
  body:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -14) -- suit la description, quelle que soit sa longueur
  body:SetWidth(376)
  local source = Label(detail, "", 10, -500, "GameFontDisableSmall")
  source:SetWidth(376)
  local current
  local open = Button(detail, L["Ouvrir dans l'éditeur"], 180, function()
    if not current then return end
    LoadText(current.name, LibraryBody(current))
    showEditor()
  end)
  open:SetPoint("BOTTOMLEFT", 10, 10)
  open:Disable()
  local function FavKey(entry) return entry.class .. "/" .. entry.name end
  local ShowClass
  local favButton = Button(detail, L["Ajouter aux favoris"], 180, function()
    if not current then return end
    local key = FavKey(current)
    ns.db.favorites[key] = not ns.db.favorites[key] or nil
    ShowClass(nil, true)
  end)
  favButton:SetPoint("LEFT", open, "RIGHT", 6, 0)
  favButton:Disable()

  local entryRows, classChips, catChips, shown, offset = {}, {}, {}, {}, 0
  local currentClass, category, query
  local empty = Label(listPanel, "", 10, -80, "GameFontDisableSmall")
  local range = listPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  range:SetPoint("RIGHT", listPanel.band, "RIGHT", -6, 0)

  local function ShowDetail()
    if not current then return end
    title:SetText(current.name)
    desc:SetText(LibraryDesc(current) or "")
    body:SetText(LibraryBody(current))
    source:SetText(current.source and L["Source : %s"]:format(current.source) or "")
    favButton:SetText(ns.db.favorites[FavKey(current)] and L["Retirer des favoris"] or L["Ajouter aux favoris"])
  end

  local function Render()
    -- la bibliotheque peut changer de taille : l'offset reste dans les bornes
    offset = math.max(0, math.min(offset, #shown - MAX_LIB_ROWS))
    for i, row in ipairs(entryRows) do
      local entry = shown[offset + i]
      row:SetShown(entry ~= nil)
      if entry then
        row.text:SetText((ns.db.favorites[FavKey(entry)] and "|A:PetJournal-FavoritesIcon:12:12|a" or "")
          .. ("[%s] %s"):format(CATEGORY_LABEL[entry.category] or entry.category or "?", entry.name))
        local c = entry.usable and 1 or 0.5 -- grise : un sort de la macro n'est pas connu du personnage
        row.text:SetTextColor(c, c, c)
        Tint(row, CATEGORY_COLOR[entry.category] or GREY, entry == current and 1 or 0.45)
        row.mark:SetShown(entry == current)
      end
    end
    empty:SetShown(#shown == 0)
    range:SetText(#shown > MAX_LIB_ROWS
      and L["%d-%d / %d  (molette)"]:format(offset + 1, math.min(offset + MAX_LIB_ROWS, #shown), #shown) or "")
  end

  -- Recherche et categories au-dessus de la liste ; 18 lignes depuis -74 finissent a -540 (panneau : 566)
  local search = Edit(listPanel, 272, function(text)
    query = ns.Fold(ns.trim(text))
    ShowClass()
  end)
  search:SetPoint("TOPLEFT", 14, -28)
  local searchHint = Label(search, L["Rechercher..."], 2, -4, "GameFontDisableSmall")
  search:HookScript("OnTextChanged", function(self) searchHint:SetShown(self:GetText() == "") end)
  Tip(search, function() return L["Rechercher"], L["Nom, description ou texte de la macro."] end)
  local x = 8
  for i, cat in ipairs({ false, "PvE", "PvP", "Pet", "Utility" }) do
    local w = ({ 52, 44, 44, 64, 72 })[i]
    local chip = Chip(listPanel, w, 18)
    chip:SetPoint("TOPLEFT", x, -52)
    chip.text:SetText(cat and (CATEGORY_LABEL[cat] or cat) or L["Toutes"])
    chip:SetScript("OnClick", function()
      category = cat or nil
      ShowClass()
    end)
    catChips[cat] = chip
    x = x + w + 2
  end

  for i = 1, MAX_LIB_ROWS do
    local row = Chip(listPanel, 284, 24)
    row:SetPoint("TOPLEFT", 8, -74 - (i - 1) * 26)
    row.mark = SideBar(row, GOLD)
    row:SetScript("OnClick", function()
      current = shown[offset + i]
      ShowDetail()
      open:Enable()
      favButton:Enable()
      Render()
    end)
    Tip(row, function()
      local entry = shown[offset + i]
      if entry then return entry.name, LibraryDesc(entry) end
    end)
    entryRows[i] = row
  end
  listPanel:EnableMouseWheel(true)
  listPanel:SetScript("OnMouseWheel", function(_, delta)
    offset = offset - delta * 3
    Render()
  end)

  -- recherche en texte simple (find sans motif) sur ce qui est affiche
  local function Matches(entry)
    if category and entry.category ~= category then return false end
    if not query or query == "" then return true end
    return SearchText(entry):find(query, 1, true) ~= nil
  end

  -- sans argument : reapplique les filtres a la classe affichee
  function ShowClass(class, keepOffset)
    currentClass = class or currentClass
    shown = {}
    if not keepOffset then offset = 0 end
    if currentClass ~= FAV then ns.db.lastClass = currentClass end
    for _, entry in ipairs(ns.Library or {}) do
      local inList = currentClass == FAV and ns.db.favorites[FavKey(entry)] or entry.class == currentClass
      if inList and Matches(entry) then
        entry.usable = #ns.LibraryUnknown(entry) == 0
        if entry.usable or not ns.db.onlyKnown then shown[#shown + 1] = entry end
      end
    end
    empty:SetText((category or (query and query ~= "")) and L["Aucune macro ne correspond."]
      or currentClass == FAV and L["Aucun favori : ajoute-en depuis le détail d'une macro."]
      or L["Aucune macro pour cette classe."])
    Render()
    ShowDetail()
    for token, chip in pairs(classChips) do
      Tint(chip, token == currentClass and GOLD or GREY, token == currentClass and 0.95 or 0.7)
    end
    for cat, chip in pairs(catChips) do
      local on = (category or false) == cat
      Tint(chip, on and GOLD or (CATEGORY_COLOR[cat] or GREY), on and 0.95 or 0.6)
    end
  end

  for i, token in ipairs(CLASS_ORDER) do
    local chip = Chip(classPanel, 160, 22)
    chip:SetPoint("TOPLEFT", 8, -28 - (i - 1) * 24)
    chip.text:SetText(token == FAV and ("|A:PetJournal-FavoritesIcon:12:12|a" .. L["Favoris"])
      or token == "ALL" and L["Toutes classes"]
      or (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]) or token)
    chip:SetScript("OnClick", function() ShowClass(token) end)
    classChips[token] = chip
  end
  local onlyKnown = CreateFrame("CheckButton", nil, classPanel, "UICheckButtonTemplate")
  onlyKnown:SetSize(24, 24)
  onlyKnown:SetPoint("BOTTOMLEFT", 6, 6)
  onlyKnown:SetChecked(ns.db.onlyKnown)
  onlyKnown:SetScript("OnClick", function(self)
    ns.db.onlyKnown = self:GetChecked() and true or false
    ShowClass()
  end)
  local onlyKnownText = Label(classPanel, L["Mes sorts seulement"], 0, 0, "GameFontHighlightSmall")
  onlyKnownText:ClearAllPoints()
  onlyKnownText:SetPoint("LEFT", onlyKnown, "RIGHT", 2, 0)
  Tip(onlyKnown, function() return L["Mes sorts seulement"], L["Cache les macros dont un sort n'est pas connu de ce personnage. Sans la case, elles sont grisées."] end)

  local _, playerClass = UnitClass("player")
  local start = ns.db.libraryClass == "last" and ns.db.lastClass
  if not (start and classChips[start]) then start = classChips[playerClass] and playerClass or "ALL" end
  ShowClass(start)
  ns.RefreshLibrary = function() ShowDetail() Render() end

  -- objets hors cache : demandes une seule fois ; a leur arrivee, les macros qui les citent sont retraduites
  if GetItemName and C_Item.RequestLoadItemDataByID then
    local nameOf = {}
    for name, id in pairs(ns.ItemIDs or {}) do
      nameOf[id] = name
      if not GetItemName(id) then C_Item.RequestLoadItemDataByID(id) end
    end
    local itemEvents = CreateFrame("Frame")
    itemEvents:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    itemEvents:SetScript("OnEvent", function(_, _, itemID)
      local name = nameOf[itemID]
      if not name then return end
      for _, entry in ipairs(ns.Library or {}) do
        if entry.body:find(name, 1, true) then entry.localized, entry.searchLang = nil, nil end
      end
      ns.RefreshLibrary()
    end)
  end
end

---------------------------------------------------------------------------
-- Mes macros : liste, partage par texte, sauvegardes, raccourcis
---------------------------------------------------------------------------
local MAX_MACRO_ROWS, MAX_SET_ROWS = 20, 18
local RefreshMacros -- pose par BuildMacros

local function ReadMacros()
  local list = {}
  local numAccount, numChar = GetNumMacros()
  for i = 1, numAccount + numChar do
    local index = i <= numAccount and i or MAX_ACCOUNT + i - numAccount -- macros du personnage : 121 a 150
    local name, icon, body = GetMacroInfo(index)
    if name then list[#list + 1] = { name = name, icon = icon, body = body or "", char = i > numAccount } end
  end
  return list
end

-- GetMacroIndexByName ne distingue pas general / personnage : on cherche dans la bonne plage, relue a chaque fois
local function FindMacro(name, char)
  local numAccount, numChar = GetNumMacros()
  local first = char and MAX_ACCOUNT + 1 or 1
  for index = first, first + (char and numChar or numAccount) - 1 do
    if GetMacroInfo(index) == name then return index end
  end
end

local function RestoreSet(setName)
  if InCombatLockdown() then return Msg(L["Impossible de modifier une macro en combat."]) end
  local set = ns.db.sets[setName]
  if type(set) ~= "table" then return end
  local updated, created, skipped = 0, 0, 0
  for _, m in ipairs(set) do
    if type(m) == "table" and type(m.name) == "string" and type(m.body) == "string" then
      local char = m.char and true or false
      local index = FindMacro(m.name, char)
      if index then
        EditMacro(index, m.name, m.icon, m.body)
        updated = updated + 1
      else
        local numAccount, numChar = GetNumMacros()
        local room = (char and numChar < MAX_CHARACTER) or (not char and numAccount < MAX_ACCOUNT)
        local done = room and CreateMacro(m.name, m.icon or "INV_Misc_QuestionMark", m.body, char)
        if done and done ~= 0 then created = created + 1 else skipped = skipped + 1 end
      end
    end
  end
  Msg(L["Sauvegarde « %s » restaurée : %d mises à jour, %d créées, %d ignorées faute de place."]:format(setName, updated, created, skipped))
  if RefreshMacros then RefreshMacros() end
end

local function BindMacro(key, name)
  if InCombatLockdown() then return Msg(L["Impossible de changer un raccourci en combat."]) end
  SetBindingMacro(key, name)
  -- relu plutot que de se fier au retour de SetBindingMacro
  if GetBindingAction(key) ~= "MACRO " .. name then return Msg(L["Le jeu a refusé le raccourci."]) end
  SaveBindings(GetCurrentBindingSet())
  Msg(L["Touche %s : macro « %s »."]:format(key, name))
  if RefreshMacros then RefreshMacros() end
end

if StaticPopupDialogs then
  StaticPopupDialogs.BLOCKFORGE_RESTORE = {
    text = L["Restaurer la sauvegarde « %s » ?\nLes macros du jeu de même nom (même onglet) seront remplacées, les autres créées s'il reste de la place. Les macros absentes de la sauvegarde ne sont pas touchées."],
    button1 = YES or L["Oui"], button2 = NO or L["Non"],
    OnAccept = function(_, setName) RestoreSet(setName) end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  }
  StaticPopupDialogs.BLOCKFORGE_DELETE_SET = {
    text = L["Supprimer la sauvegarde « %s » ? C'est définitif."],
    button1 = YES or L["Oui"], button2 = NO or L["Non"],
    OnAccept = function(_, setName)
      ns.db.sets[setName] = nil
      if RefreshMacros then RefreshMacros() end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  }
  StaticPopupDialogs.BLOCKFORGE_REPLACE_SET = {
    text = L["La sauvegarde « %s » existe déjà. La remplacer par tes macros actuelles ?"],
    button1 = YES or L["Oui"], button2 = NO or L["Non"],
    OnAccept = function(_, save) save() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  }
  StaticPopupDialogs.BLOCKFORGE_BIND = {
    text = L["La touche %s sert déjà à « %s ». La remplacer ?"],
    button1 = YES or L["Oui"], button2 = NO or L["Non"],
    OnAccept = function(_, data) BindMacro(data.key, data.name) end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  }
end

local function BuildMacros(parent, showEditor)
  local listPanel = Panel(parent, 300, 566, L["Mes macros"])
  listPanel:SetPoint("TOPLEFT", 0, 0)
  local detail = Panel(parent, 396, 566, L["Détail"])
  detail:SetPoint("TOPLEFT", listPanel, "TOPRIGHT", 6, 0)
  local setsPanel = Panel(parent, 176, 566, L["Sauvegardes"])
  setsPanel:SetPoint("TOPLEFT", detail, "TOPRIGHT", 6, 0)

  local macros, current, offset, rowsM = {}, nil, 0, {}
  local counts = listPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  counts:SetPoint("RIGHT", listPanel.band, "RIGHT", -6, 0)
  local empty = Label(listPanel, L["Aucune macro."], 10, -40, "GameFontDisableSmall")

  -- Detail : nom, onglet et touche, corps, actions ; partage par texte en dessous (corps : -76 a -306)
  local title = Label(detail, L["Choisis une macro dans la liste."], 10, -32, "GameFontHighlightLarge")
  title:SetWidth(376)
  local info = Label(detail, "", 10, -54, "GameFontHighlightSmall")
  info:SetWidth(376)
  local body = Label(detail, "", 10, -76, "BlockForgeCodeFont")
  body:SetSize(376, 230)
  body:SetJustifyV("TOP")
  local capturing

  local function ShowDetail()
    if not current then return end
    title:SetText(current.name)
    local key = GetBindingKey("MACRO " .. current.name)
    info:SetText((current.char and L["Macro du personnage"] or L["Macro générale"]) .. "  ·  "
      .. (key and L["Raccourci : %s"]:format(key) or L["Aucun raccourci"]))
    body:SetText(current.body)
  end

  local open = Button(detail, L["Ouvrir dans l'éditeur"], 180, function()
    if current and LoadText(current.name, current.body) then showEditor() end
  end)
  open:SetPoint("TOPLEFT", 10, -312)
  local bind
  local function StopCapture()
    capturing = nil
    bind:SetScript("OnKeyDown", nil)
    bind:EnableKeyboard(false)
    bind:SetText(L["Raccourci…"])
    ShowDetail()
  end
  local function OnKey(_, key)
    if key == "ESCAPE" then return StopCapture() end
    if IsKeyPressIgnoredForBinding(key) then return end -- Maj seule : on attend la touche
    local chord, name = CreateKeyChordStringUsingMetaKeyState(key), capturing
    StopCapture()
    local action = GetBindingAction(chord) or ""
    if action ~= "" and action ~= "MACRO " .. name then
      StaticPopup_Show("BLOCKFORGE_BIND", chord, GetBindingName and GetBindingName(action) or action, { key = chord, name = name })
    else
      BindMacro(chord, name)
    end
  end
  bind = Button(detail, L["Raccourci…"], 180, function(self)
    if not current then return end
    if capturing then return StopCapture() end
    if InCombatLockdown() then return Msg(L["Impossible de changer un raccourci en combat."]) end
    capturing = current.name
    self:SetText(L["Appuie sur une touche…"])
    info:SetText(L["Appuie sur une touche, avec Maj / Ctrl / Alt si tu veux. Échap : annuler."])
    self:EnableKeyboard(true) -- protege en combat : la capture ne demarre qu'hors combat
    self:SetScript("OnKeyDown", OnKey)
  end)
  bind:SetPoint("LEFT", open, "RIGHT", 6, 0)
  Tip(bind, function() return L["Raccourci…"], L["Associe une touche à cette macro. Hors combat seulement."] end)

  Label(detail, L["Partager (texte)"], 10, -350, "GameFontNormal")
  local share = Edit(detail, 370, function() end)
  share:SetPoint("TOPLEFT", 14, -366)
  share:SetMaxLetters(0) -- 0 = sans limite : une macro de 255 caracteres echappee depasse 255
  local export = Button(detail, L["Exporter"], 120, function()
    if not current then return end
    share:SetText(ns.Export(current.name, current.body))
    share:SetFocus()
    share:HighlightText()
  end)
  export:SetPoint("TOPLEFT", 10, -392)
  Tip(export, function() return L["Exporter"], L["Met la macro dans le champ ci-dessus en une ligne de texte : Ctrl+C pour la copier."] end)
  local import = Button(detail, L["Importer"], 120, function()
    local name, text = ns.Import(share:GetText())
    if not name then return Msg(text) end
    if LoadText(name, text) then
      showEditor()
      Msg(L["Macro « %s » ouverte dans l'éditeur : « Créer / mettre à jour » pour l'enregistrer."]:format(name))
    end
  end)
  import:SetPoint("LEFT", export, "RIGHT", 6, 0)
  Tip(import, function() return L["Importer"], L["Colle (Ctrl+V) dans le champ un texte « BF1:... », puis clique : la macro s'ouvre dans l'éditeur, sans être enregistrée."] end)
  for _, b in ipairs({ open, bind, export }) do b:Disable() end

  local function Render()
    offset = math.max(0, math.min(offset, #macros - MAX_MACRO_ROWS))
    for i, row in ipairs(rowsM) do
      local m = macros[offset + i]
      row:SetShown(m ~= nil)
      if m then
        row.icon:SetTexture(m.icon or QUESTION)
        row.text:SetText(m.name)
        row.scope:SetText(m.char and L["Personnage"] or L["Générale"])
        Tint(row, m.char and GOLD or GREY, m == current and 1 or 0.5)
        row.mark:SetShown(m == current)
      end
    end
    empty:SetShown(#macros == 0)
    local numAccount, numChar = GetNumMacros()
    counts:SetText(L["%d/%d générales · %d/%d perso"]:format(numAccount, MAX_ACCOUNT, numChar, MAX_CHARACTER))
  end

  for i = 1, MAX_MACRO_ROWS do -- 20 lignes depuis -28 finissent a -546 (panneau : 566)
    local row = Chip(listPanel, 284, 24)
    row:SetPoint("TOPLEFT", 8, -28 - (i - 1) * 26)
    row.mark = SideBar(row, GOLD)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", 8, 0)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    row.text:SetPoint("LEFT", 32, 0)
    row.text:SetPoint("RIGHT", -76, 0)
    row.scope = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.scope:SetPoint("RIGHT", -6, 0)
    row:SetScript("OnClick", function()
      if capturing then StopCapture() end
      current = macros[offset + i]
      for _, b in ipairs({ open, bind, export }) do b:Enable() end
      ShowDetail()
      Render()
    end)
    rowsM[i] = row
  end
  listPanel:EnableMouseWheel(true)
  listPanel:SetScript("OnMouseWheel", function(_, delta)
    offset = offset - delta * 3
    Render()
  end)

  -- Sauvegardes : nom, bouton, liste (18 lignes de -84 a -478), restaurer / supprimer en bas
  local setRows, setNames, chosen, setOffset = {}, {}, nil, 0
  local setName = Edit(setsPanel, 150, function() end)
  setName:SetPoint("TOPLEFT", 14, -30)
  setName:SetMaxLetters(40)
  local setHint = Label(setName, L["Nom (vide : date)"], 2, -4, "GameFontDisableSmall")
  setName:HookScript("OnTextChanged", function(self) setHint:SetShown(self:GetText() == "") end)
  Tip(setName, function() return L["Nom de la sauvegarde"], L["Vide : la date du jour. Un nom existant est remplacé après confirmation."] end)
  local restore, delete

  local function RenderSets()
    setNames = {}
    for name in pairs(ns.db.sets) do setNames[#setNames + 1] = name end
    table.sort(setNames, function(a, b) return a > b end) -- dates recentes en haut
    if chosen and not ns.db.sets[chosen] then chosen = nil end
    setOffset = math.max(0, math.min(setOffset, #setNames - MAX_SET_ROWS))
    for i, row in ipairs(setRows) do
      local name = setNames[setOffset + i]
      row:SetShown(name ~= nil)
      if name then
        local set = ns.db.sets[name]
        row.text:SetText(name .. "  |cff888888(" .. (type(set) == "table" and #set or 0) .. ")|r")
        Tint(row, name == chosen and GOLD or GREY, name == chosen and 0.95 or 0.6)
      end
    end
    if chosen then restore:Enable() delete:Enable() else restore:Disable() delete:Disable() end
  end

  local function SaveSet(name)
    if InCombatLockdown() then return Msg(L["Impossible de lire les macros en combat."]) end
    local replaced = ns.db.sets[name] ~= nil
    local list = ReadMacros()
    ns.db.sets[name] = list
    chosen = name
    setName:SetText("")
    Msg((replaced and L["Sauvegarde « %s » remplacée (%d macros)."] or L["Sauvegarde « %s » enregistrée (%d macros)."]):format(name, #list))
    RenderSets()
  end
  local saveSet = Button(setsPanel, L["Sauvegarder mes macros"], 160, function()
    if InCombatLockdown() then return Msg(L["Impossible de lire les macros en combat."]) end
    local name = ns.trim(setName:GetText())
    if name == "" then name = date("%Y-%m-%d") end
    if ns.db.sets[name] == nil then return SaveSet(name) end
    StaticPopup_Show("BLOCKFORGE_REPLACE_SET", name, nil, function() SaveSet(name) end)
  end)
  saveSet:SetPoint("TOPLEFT", 8, -54)
  Tip(saveSet, function() return L["Sauvegarder mes macros"], L["Copie toutes tes macros (générales et de ce personnage) dans BlockForge, pour les restaurer plus tard."] end)

  for i = 1, MAX_SET_ROWS do
    local row = Chip(setsPanel, 160, 20)
    row:SetPoint("TOPLEFT", 8, -84 - (i - 1) * 22)
    row:SetScript("OnClick", function()
      chosen = setNames[setOffset + i]
      RenderSets()
    end)
    setRows[i] = row
  end
  setsPanel:EnableMouseWheel(true)
  setsPanel:SetScript("OnMouseWheel", function(_, delta)
    setOffset = setOffset - delta * 3
    RenderSets()
  end)
  restore = Button(setsPanel, L["Restaurer"], 78, function()
    if not chosen then return end
    if InCombatLockdown() then return Msg(L["Impossible de modifier une macro en combat."]) end
    StaticPopup_Show("BLOCKFORGE_RESTORE", chosen, nil, chosen)
  end)
  restore:SetPoint("BOTTOMLEFT", 8, 8)
  Tip(restore, function() return L["Restaurer"], L["Hors combat seulement."] end)
  delete = Button(setsPanel, L["Supprimer"], 78, function()
    if chosen then StaticPopup_Show("BLOCKFORGE_DELETE_SET", chosen, nil, chosen) end
  end)
  delete:SetPoint("LEFT", restore, "RIGHT", 4, 0)

  function RefreshMacros()
    macros = ReadMacros()
    -- la selection survit a la relecture : meme nom, meme onglet
    local was = current
    current = nil
    for _, m in ipairs(macros) do
      if was and m.name == was.name and m.char == was.char then current = m end
    end
    if not current then
      title:SetText(L["Choisis une macro dans la liste."])
      info:SetText("")
      body:SetText("")
      for _, b in ipairs({ open, bind, export }) do b:Disable() end
    elseif not capturing then
      ShowDetail()
    end
    Render()
    RenderSets()
  end
  parent:HookScript("OnShow", RefreshMacros)
  parent:HookScript("OnHide", function() if capturing then StopCapture() end end)
  listPanel:RegisterEvent("UPDATE_MACROS")
  listPanel:RegisterEvent("PLAYER_REGEN_DISABLED")
  listPanel:SetScript("OnEvent", function(_, event)
    -- la capture de touche s'arrete avant le verrouillage du combat
    if event == "PLAYER_REGEN_DISABLED" then
      if capturing then StopCapture() end
    elseif parent:IsVisible() then
      RefreshMacros()
    end
  end)
  RefreshMacros()
end

---------------------------------------------------------------------------
-- Fenetre principale
---------------------------------------------------------------------------
local ShowTab

function ns.ApplyWindow()
  if not main then return end
  -- la fenetre ne depasse jamais l'ecran ; le reglage enregistre reste celui choisi
  local fit = math.min((UIParent:GetWidth() or 0) / main:GetWidth(), (UIParent:GetHeight() or 0) / main:GetHeight())
  main:SetScale(fit > 0 and math.min(ns.db.scale, fit) or ns.db.scale)
  main:ClearAllPoints()
  local p = ns.db.rememberPos and ns.db.pos
  if p then main:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else main:SetPoint("CENTER") end
end

-- un onglet qui echoue n'empeche pas les autres ; l'erreur est notee pour /bf test puis transmise au gestionnaire du jeu
local buildErrors = {}
local function TryBuild(key, build)
  xpcall(build, function(err)
    buildErrors[key] = tostring(err)
    return geterrorhandler()(err)
  end)
end

local function Build()
  main =CreateFrame("Frame", "BlockForgeFrame", UIParent, "BasicFrameTemplateWithInset")
  main:SetSize(900, 640)
  main:SetFrameStrata("HIGH")
  main:SetMovable(true)
  main:SetClampedToScreen(true)
  main:EnableMouse(true)
  main:RegisterForDrag("LeftButton")
  main:SetScript("OnDragStart", main.StartMoving)
  main:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if ns.db.rememberPos then
      local point, _, relPoint, x, y = self:GetPoint(1)
      if point then ns.db.pos = { point, relPoint, x, y } end
    end
  end)
  local title = main.TitleText or (main.TitleContainer and main.TitleContainer.TitleText)
  if title then title:SetText(L["BlockForge — éditeur de macros par blocs"]) end
  tinsert(UISpecialFrames, "BlockForgeFrame")

  local pages = {}
  for _, key in ipairs({ "editor", "library", "macros", "settings" }) do
    pages[key] = CreateFrame("Frame", nil, main)
    pages[key]:SetPoint("TOPLEFT", 8, -58)
    pages[key]:SetSize(884, 570)
  end
  editor, library, settingsTab = pages.editor, pages.library, pages.settings

  local tabs = {}
  function ShowTab(which)
    for key, page in pairs(pages) do
      page:SetShown(key == which)
      -- onglet actif : surbrillance verrouillee
      if key == which then tabs[key]:LockHighlight() else tabs[key]:UnlockHighlight() end
    end
  end
  tabs.editor = Button(main, L["Éditeur"], 110, function() ShowTab("editor") end)
  tabs.editor:SetPoint("TOPLEFT", 10, -30)
  tabs.library = Button(main, L["Bibliothèque"], 110, function() ShowTab("library") end)
  tabs.library:SetPoint("LEFT", tabs.editor, "RIGHT", 4, 0)
  tabs.macros = Button(main, L["Mes macros"], 110, function() ShowTab("macros") end)
  tabs.macros:SetPoint("LEFT", tabs.library, "RIGHT", 4, 0)
  tabs.settings = Button(main, L["Paramètres"], 110, function() ShowTab("settings") end)
  tabs.settings:SetPoint("LEFT", tabs.macros, "RIGHT", 4, 0)

  local function ShowEditor() ShowTab("editor") end
  TryBuild("editor", function() BuildEditor(editor) end)
  TryBuild("library", function() BuildLibrary(library, ShowEditor) end)
  TryBuild("macros", function() BuildMacros(pages.macros, ShowEditor) end)
  TryBuild("settings", function()
    local settingsPanel = Panel(settingsTab, 884, 566, L["Paramètres"])
    settingsPanel:SetPoint("TOPLEFT")
    ns.BuildSettingsPage(settingsPanel)
  end)
  ShowTab("editor")
  ns.ApplyWindow()
  if not buildErrors.editor then Refresh() end
end

-- pour /bf test : construit la fenetre (sans l'afficher si elle ne l'etait pas) et renvoie les erreurs par onglet
function ns.TabErrors()
  if not main then
    Build()
    main:Hide()
  end
  return buildErrors
end

function ns.Toggle()
  if not main then Build() return end
  main:SetShown(not main:IsShown())
end

function ns.OpenSettings()
  if not main then Build() end
  main:Show()
  ShowTab("settings")
end

SLASH_BLOCKFORGE1 = "/blockforge"
SLASH_BLOCKFORGE2 = "/bf"
SlashCmdList.BLOCKFORGE = function(msg)
  msg = ns.trim((msg or ""):lower())
  if msg == "options" or msg == "config" or msg == "param" then return ns.OpenSettings() end
  if msg == "test" then return ns.SelfTest() end
  ns.Toggle()
end
