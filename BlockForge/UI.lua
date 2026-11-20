-- BlockForge : interface (editeur par blocs + bibliotheque + parametres). Ouvrir avec /bf
local ADDON, ns = ...
local L = ns.L

local MAX_ROWS = 12    -- shortcut: 12 lignes max sans defilement, a revoir si 255 caracteres en demandent plus
local MAX_CLAUSES = 4
local MAX_LIB_ROWS = 20 -- lignes visibles ; la molette fait defiler au-dela
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
local GROUP_COLORS = { { 0.35, 0.75, 0.95 }, { 0.95, 0.45, 0.45 }, { 0.72, 0.52, 0.98 }, { 0.98, 0.66, 0.25 } }
local PILL_LABEL = { nomod = L["Sans touche"] } -- libelles trop vagues hors de leur groupe

local blocks, selected, activeClause = {}, nil, 1
local rows, condButtons, clauseTabs = {}, {}, {}
local Refresh
local main, editor, library, settingsTab, canvas, dropLine
local nameBox, perChar, argBox, argLabel, resetBox, resetLabel, inspTitle, inspBody, inspHint
local preview, counter, counterBar, warnText

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
  Refresh()
end

local function AddBlock(id, at, arg)
  if #blocks >= MAX_ROWS then return Msg(L["Maximum %d blocs."]:format(MAX_ROWS)) end
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
  local needsArg = def.arg and not def.arg:find(L["optionnel"], 1, true)

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

local function DropIndex()
  local _, y = GetCursorPosition()
  for i = 1, #blocks do
    local row = rows[i]
    local mid = (row:GetTop() + row:GetBottom()) / 2 * row:GetEffectiveScale()
    if y > mid then return i end
  end
  return #blocks + 1
end

local function StartDrag(info, label, color)
  drag = info
  ghost.text:SetText(label)
  Tint(ghost, color, 0.95)
  ghost:Show()
  GameTooltip:Hide()
  if info.from then rows[info.from]:SetAlpha(0.35) end -- la ligne deplacee s'estompe
end

local function EndDrag()
  local d = drag
  drag = nil
  ghost:Hide()
  dropLine:Hide()
  if d and d.from then rows[d.from]:SetAlpha(1) end
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
    local at = DropIndex()
    dropLine:ClearAllPoints()
    if at <= #blocks then
      dropLine:SetPoint("BOTTOMLEFT", rows[at], "TOPLEFT", 0, 1)
    elseif #blocks > 0 then
      dropLine:SetPoint("TOPLEFT", rows[#blocks], "BOTTOMLEFT", 0, -1)
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
  local parsed = ns.Parse(body or "")
  -- trop de lignes pour l'editeur : ne rien charger plutot que couper, sinon enregistrer ecraserait la fin
  if #parsed > MAX_ROWS then return Msg(L["Macro non chargée : %d lignes, l'éditeur en affiche %d au plus."]:format(#parsed, MAX_ROWS)) end
  blocks = parsed
  nameBox:SetText(name or "")
  selected, activeClause = blocks[1], 1
  Refresh()
end

local function LoadExisting()
  local name = ns.trim(nameBox:GetText())
  local macroName, _, body = GetMacroInfo(name)
  if not macroName then return Msg(L["Aucune macro nommée « %s »."]:format(name)) end
  LoadText(macroName, body)
end

---------------------------------------------------------------------------
-- Rafraichissement
---------------------------------------------------------------------------
function Refresh()
  for i, row in ipairs(rows) do
    local block = blocks[i]
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
  if #unknown > 0 then
    warnings[#warnings + 1] = L["Sort inconnu de ce personnage (ou mal écrit) : %s"]:format(table.concat(unknown, ", "))
  end
  local len = #text
  preview:SetText(text ~= "" and text or "|cff777777" .. L["(la macro compilée s'affiche ici)"] .. "|r")
  local ratio = math.min(1, len / ns.MAX_CHARS)
  local r, g = len > ns.MAX_CHARS and 1 or (ratio > 0.85 and 1 or 0.3), len > ns.MAX_CHARS and 0.25 or (ratio > 0.85 and 0.7 or 0.9)
  counter:SetText(("%d / %d"):format(len, ns.MAX_CHARS))
  counter:SetTextColor(r, g, 0.3)
  counterBar:SetWidth(math.max(1, counterBar.max * ratio))
  counterBar:SetColorTexture(r, g, 0.3, 0.9)
  warnText:SetText(table.concat(warnings, "\n"))
end

---------------------------------------------------------------------------
-- Construction de l'editeur
---------------------------------------------------------------------------
local function BuildEditor(parent)
  -- Palette
  local palette = Panel(parent, 176, 430, L["Blocs"])
  palette:SetPoint("TOPLEFT", 0, 0)
  for i, def in ipairs(ns.BlockDefs) do
    local chip = Chip(palette, 160, 20)
    chip:SetPoint("TOPLEFT", 8, -28 - (i - 1) * 22)
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
  for i = 1, MAX_ROWS do
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
    row:SetScript("OnClick", function() Select(blocks[i]) end)
    row:SetScript("OnDragStart", function()
      local def = ns.BlockById[blocks[i].type]
      StartDrag({ from = i }, row.full or def.label, def.color)
    end)
    row:SetScript("OnDragStop", EndDrag)
    -- un sort lache sur une ligne s'insere a cette place
    row:SetScript("OnReceiveDrag", function()
      local name, id = CursorPayload()
      if name then AddBlock(id, i, name) end
    end)
    Tip(row, function()
      if drag or not blocks[i] then return end
      return row.full, L["Clic : régler. Glisser : déplacer."]
    end)
    local del = Button(row, "x", 22, function()
      if selected == blocks[i] then selected = nil end
      table.remove(blocks, i)
      Refresh()
    end)
    del:SetPoint("LEFT", row, "RIGHT", 2, 0)
    Tip(del, function() return L["Supprimer ce bloc"] end)
    rows[i] = row
  end
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
  -- Pas : titre 13, ligne 19, ecart 2 => le champ "Autre condition" finit a -418 (panneau : 430).
  local sep = clauseTabs.box:CreateTexture(nil, "ARTWORK")
  sep:SetColorTexture(1, 1, 1, 0.12)
  sep:SetPoint("TOPLEFT", 8, -131 + 44)
  sep:SetSize(280, 1)
  local y = -134
  for gi, group in ipairs(ns.ConditionGroups) do
    local color = GROUP_COLORS[gi] or GREY
    local title = Label(clauseTabs.box, group.label .. (group.exclusive and "  |cff888888" .. L["(une seule)"] .. "|r" or ""), 10, y + 44)
    title:SetTextColor(Light(color))
    y = y - 13
    for i, item in ipairs(group.items) do
      local col, line = (i - 1) % 3, math.floor((i - 1) / 3)
      local b = Chip(clauseTabs.box, 90, 18)
      b:SetPoint("TOPLEFT", 10 + col * 92, y + 44 - line * 19)
      b.text:SetText(item[2])
      b.cond, b.color = item[1], color
      b:SetScript("OnClick", function()
        ns.ToggleCond(EditedArgHolder(), item[1])
        Refresh()
      end)
      Tip(b, function() return item[2], "[" .. item[1] .. "]  " .. L["clic : activer / retirer"] end)
      condButtons[#condButtons + 1] = b
    end
    y = y - math.ceil(#group.items / 3) * 19 - 2
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
end

---------------------------------------------------------------------------
-- Bibliotheque
---------------------------------------------------------------------------
local CLASS_ORDER = { "ALL", "WARLOCK", "HUNTER", "ROGUE", "MAGE", "PRIEST", "DRUID", "WARRIOR", "PALADIN", "SHAMAN" }
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

-- la bibliotheque est ecrite en anglais : traduite a la demande, et seulement si le reglage le veut
local function LibraryBody(entry)
  if not ns.db.localizeLibrary then return entry.body end
  if not entry.localized then
    entry.localized = ns.Localize(entry.body, (C_Spell and C_Spell.GetSpellName) or GetSpellInfo, RANK)
  end
  return entry.localized
end

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

  local entryRows, classChips, shown, offset = {}, {}, {}, 0
  local empty = Label(listPanel, L["Aucune macro pour cette classe."], 10, -34, "GameFontDisableSmall")
  local range = listPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  range:SetPoint("RIGHT", listPanel.band, "RIGHT", -6, 0)

  local function ShowDetail()
    if not current then return end
    title:SetText(current.name)
    desc:SetText(LibraryDesc(current) or "")
    body:SetText(LibraryBody(current))
    source:SetText(current.source and L["Source : %s"]:format(current.source) or "")
  end

  local function Render()
    -- la bibliotheque peut changer de taille : l'offset reste dans les bornes
    offset = math.max(0, math.min(offset, #shown - MAX_LIB_ROWS))
    for i, row in ipairs(entryRows) do
      local entry = shown[offset + i]
      row:SetShown(entry ~= nil)
      if entry then
        row.text:SetText(("[%s] %s"):format(CATEGORY_LABEL[entry.category] or entry.category or "?", entry.name))
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

  for i = 1, MAX_LIB_ROWS do
    local row = Chip(listPanel, 284, 24)
    row:SetPoint("TOPLEFT", 8, -28 - (i - 1) * 26)
    row.mark = SideBar(row, GOLD)
    row:SetScript("OnClick", function()
      current = shown[offset + i]
      ShowDetail()
      open:Enable()
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

  local function ShowClass(class)
    shown, offset = {}, 0
    ns.db.lastClass = class
    local getName = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
    for _, entry in ipairs(ns.Library or {}) do
      if entry.class == class then
        -- noms dans la langue du client, meme si l'affichage traduit est coupe
        entry.usable = #UnknownSpells(ns.Parse(ns.Localize(entry.body, getName, RANK))) == 0
        if entry.usable or not ns.db.onlyKnown then shown[#shown + 1] = entry end
      end
    end
    Render()
    for token, chip in pairs(classChips) do
      Tint(chip, token == class and GOLD or GREY, token == class and 0.95 or 0.7)
    end
  end

  for i, token in ipairs(CLASS_ORDER) do
    local chip = Chip(classPanel, 160, 22)
    chip:SetPoint("TOPLEFT", 8, -28 - (i - 1) * 24)
    chip.text:SetText(token == "ALL" and L["Toutes classes"]
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
    ShowClass(ns.db.lastClass)
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
end

---------------------------------------------------------------------------
-- Fenetre principale
---------------------------------------------------------------------------
local ShowTab

function ns.ApplyWindow()
  if not main then return end
  main:SetScale(ns.db.scale)
  main:ClearAllPoints()
  local p = ns.db.rememberPos and ns.db.pos
  if p then main:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else main:SetPoint("CENTER") end
end

local function Build()
  main = CreateFrame("Frame", "BlockForgeFrame", UIParent, "BasicFrameTemplateWithInset")
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
  for _, key in ipairs({ "editor", "library", "settings" }) do
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
  tabs.settings = Button(main, L["Paramètres"], 110, function() ShowTab("settings") end)
  tabs.settings:SetPoint("LEFT", tabs.library, "RIGHT", 4, 0)

  BuildEditor(editor)
  BuildLibrary(library, function() ShowTab("editor") end)
  local settingsPanel = Panel(settingsTab, 884, 566, L["Paramètres"])
  settingsPanel:SetPoint("TOPLEFT")
  ns.BuildSettingsPage(settingsPanel)
  ShowTab("editor")
  ns.ApplyWindow()
  Refresh()
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
  ns.Toggle()
end
