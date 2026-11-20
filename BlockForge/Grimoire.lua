-- BlockForge : grimoire integre. Sorts, techniques du familier et objets utilisables du personnage, en grille d'icones.
-- Charge apres UI.lua : tout passe par ns.ed (l'editeur) et ns.ui (les constructeurs).
local ADDON, ns = ...
local L = ns.L
local T = ns.Theme

local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

-- API pas toutes verifiees en jeu : absente ou en erreur, l'appel rend nil et la liste est seulement plus courte
local function try(fn, ...)
  if not fn then return nil end
  local ok, a = pcall(fn, ...)
  if ok then return a end
end

---------------------------------------------------------------------------
-- Sources : listes de { name, icon, kind = "spell" | "pet" | "item" }
---------------------------------------------------------------------------
function ns.GrimoireSpells()
  local list = {}
  local isPassive = (C_Spell and C_Spell.IsSpellPassive) or IsPassiveSpell
  local getIcon = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
  for _, name in ipairs(ns.SpellBook()) do
    if not try(isPassive, name) then -- un passif ne se lance pas
      list[#list + 1] = { name = name, icon = getIcon and getIcon(name), kind = "spell" }
    end
  end
  return list
end

-- techniques du familier sorti ; les ordres (attaque, suivre...) sont des jetons PET_
function ns.PetAbilities()
  local list = {}
  if not GetPetActionInfo then return list end
  for i = 1, NUM_PET_ACTION_SLOTS or 10 do
    local name, icon = GetPetActionInfo(i)
    if type(name) == "string" and not name:find("^PET_") then
      ns.PetSpells[name:lower()] = true -- pas d'avertissement "sort inconnu"
      list[#list + 1] = { name = name, icon = (type(icon) == "number" or type(icon) == "string") and icon or nil, kind = "pet" }
    end
  end
  return list
end

function ns.HasPet()
  if UnitExists then return UnitExists("pet") and true or false end
  return #ns.PetAbilities() > 0
end

-- bijoux portes (emplacements 13 et 14) puis sacs : seulement ce qui a un effet « Utiliser »
function ns.BagItems()
  local list, seen = {}, {}
  local getName = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  local getIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
  local getSpell = (C_Item and C_Item.GetItemSpell) or GetItemSpell
  local function Add(id, icon)
    local name = id and try(getName, id)
    -- shortcut: sans GetItemSpell tous les objets sont listes, a filtrer par classe d'objet si un client n'a pas cette API
    if not name or seen[name] or (getSpell and not try(getSpell, id)) then return end
    seen[name] = true
    list[#list + 1] = { name = name, icon = icon or try(getIcon, id), kind = "item" }
  end
  for slot = 13, 14 do
    Add(try(GetInventoryItemID, "player", slot), try(GetInventoryItemTexture, "player", slot))
  end
  local numSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
  local getID = (C_Container and C_Container.GetContainerItemID) or GetContainerItemID
  for bag = 0, NUM_BAG_SLOTS or 4 do
    for slot = 1, try(numSlots, bag) or 0 do Add(try(getID, bag, slot)) end
  end
  return list
end

-- "harm", "help", ou "either" quand le jeu ne tranche pas (les deux, aucun, API absente)
function ns.SpellKind(name)
  local harm = try((C_Spell and C_Spell.IsSpellHarmful) or IsHarmfulSpell, name)
  local help = try((C_Spell and C_Spell.IsSpellHelpful) or IsHelpfulSpell, name)
  if harm and not help then return "harm" end
  if help and not harm then return "help" end
  return "either"
end

local SOURCES = {
  { label = L["Sorts"], list = ns.GrimoireSpells, empty = L["Aucun sort dans ton grimoire."] },
  { label = L["Familier"], list = ns.PetAbilities, empty = L["Aucun familier sorti."] },
  { label = L["Objets"], list = ns.BagItems, empty = L["Aucun objet utilisable dans tes sacs."] },
}
local SHARE = { 0.29, 0.4, 0.31 } -- largeur des trois puces : « Familier » est le plus long

-- croix de fermeture dans le bandeau d'un panneau (de -5 a -21, bandeau de -3 a -23)
function ns.CloseChip(panel)
  local close = ns.ui.Chip(panel, 22, 16)
  close:SetPoint("TOPRIGHT", -6, -5)
  close.text:ClearAllPoints()
  close.text:SetPoint("CENTER")
  close.text:SetText("x")
  ns.ui.Tint(close, T.close, 0.9)
  close:SetScript("OnClick", function() panel:Hide() end)
  return close
end

---------------------------------------------------------------------------
-- Grille : puces de source (18 px), recherche (de -22 a -42), puis rows lignes de cols cases de size px depuis -46
--   onClick(entree) ; grid.range est a placer par l'appelant ; grid.tip : ligne d'aide de l'infobulle des cases
---------------------------------------------------------------------------
function ns.BuildSpellGrid(parent, x, y, cols, rows, size, onClick)
  local ui = ns.ui
  local step = size + 2
  local width = cols * step - 2
  local grid = { source = 1, offset = 0, all = {}, shown = {}, cells = {}, chips = {} }
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetPoint("TOPLEFT", x, y)
  frame:SetSize(width, 46 + rows * step - 2)
  grid.frame = frame
  grid.range = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  local search
  local empty = ui.Label(frame, "", 2, -52, "GameFontDisableSmall")
  empty:SetWidth(width - 4)

  function grid.Render()
    local n = #grid.cells
    local last = math.max(0, math.ceil((#grid.shown - n) / cols) * cols)
    grid.offset = math.max(0, math.min(grid.offset, last))
    for i, cell in ipairs(grid.cells) do
      local entry = grid.shown[grid.offset + i]
      cell:SetShown(entry ~= nil)
      if entry then
        cell.icon:SetTexture(entry.icon or QUESTION)
        local c = entry.name == grid.picked and T.accent or T.grey
        cell:SetBackdropBorderColor(c[1], c[2], c[3], 1)
      end
    end
    for i, chip in ipairs(grid.chips) do
      ui.Tint(chip, i == grid.source and T.accent or T.grey, i == grid.source and 0.95 or 0.6)
    end
    grid.range:SetText(#grid.shown > n and ("%d-%d / %d"):format(grid.offset + 1, math.min(grid.offset + n, #grid.shown), #grid.shown) or "")
    empty:SetShown(#grid.shown == 0)
  end

  -- applique la recherche (sans accents ni casse) a la source deja lue
  function grid.Filter()
    local query = ns.Fold(ns.trim(search:GetText()))
    grid.shown = {}
    for _, entry in ipairs(grid.all) do
      if query == "" or ns.Fold(entry.name):find(query, 1, true) then grid.shown[#grid.shown + 1] = entry end
    end
    empty:SetText(query ~= "" and L["Aucun résultat."] or SOURCES[grid.source].empty)
    grid.Render()
  end

  -- relit la source : sorts appris, familier change, sacs modifies
  function grid.Fill()
    if InCombatLockdown() then return end -- pas de recherche de sort en combat (valeurs secretes)
    grid.all = SOURCES[grid.source].list()
    grid.Filter()
  end

  local cx = 0
  for i, source in ipairs(SOURCES) do
    local w = math.floor((width - 4) * SHARE[i])
    local chip = ui.Chip(frame, w, 18)
    chip:SetPoint("TOPLEFT", cx, 0)
    cx = cx + w + 2
    chip.text:ClearAllPoints()
    chip.text:SetPoint("LEFT", 2, 0)
    chip.text:SetPoint("RIGHT", -2, 0)
    chip.text:SetJustifyH("CENTER")
    chip.text:SetText(source.label)
    chip:SetScript("OnClick", function()
      grid.source, grid.offset = i, 0
      grid.Fill()
    end)
    grid.chips[i] = chip
  end
  search = ui.Edit(frame, width - 12, function() grid.offset = 0 grid.Filter() end)
  search:SetPoint("TOPLEFT", 6, -22)
  local hint = ui.Label(search, L["Rechercher..."], 2, -4, "GameFontDisableSmall")
  search:HookScript("OnTextChanged", function(self) hint:SetShown(self:GetText() == "") end)
  grid.search = search

  for i = 1, cols * rows do
    local cell = ui.IconButton(frame)
    cell:SetSize(size, size)
    cell:SetPoint("TOPLEFT", ((i - 1) % cols) * step, -46 - math.floor((i - 1) / cols) * step)
    cell:SetScript("OnClick", function()
      local entry = grid.shown[grid.offset + i]
      if entry then onClick(entry) end
    end)
    ui.Tip(cell, function()
      local entry = grid.shown[grid.offset + i]
      if entry then return ns.Plain(entry.name), grid.tip end
    end)
    grid.cells[i] = cell
  end
  frame:EnableMouseWheel(true)
  frame:SetScript("OnMouseWheel", function(_, delta)
    grid.offset = grid.offset - delta * cols * 2
    grid.Render()
  end)

  -- a jour seulement quand la grille se voit ; le cache de ns.SpellBook est vide par UI.lua, inscrit avant ce cadre
  -- on : faux quand la fonction qui porte la grille est coupee dans les Parametres
  function grid.Listen(on) ns.Listen(frame, on, "SPELLS_CHANGED", "BAG_UPDATE_DELAYED", "UNIT_PET") end
  grid.Listen(true)
  frame:SetScript("OnEvent", function(self, event, unit)
    if self:IsVisible() and (event ~= "UNIT_PET" or unit == "player") then grid.Fill() end
  end)
  frame:SetScript("OnShow", grid.Fill) -- fenetre rouverte : le personnage a pu changer entre-temps
  T.OnChange(grid.Render)
  return grid
end

---------------------------------------------------------------------------
-- Tiroir « Mon grimoire » : a la place de la palette de blocs, le temps de choisir
---------------------------------------------------------------------------
local drawer

local function OnPick(entry)
  if InCombatLockdown() then return ns.Msg(L["Impossible de modifier une macro en combat."]) end
  if IsShiftKeyDown and IsShiftKeyDown() then return ns.OpenAssistant(entry) end
  ns.ed.Insert(entry.name, entry.kind == "item" and "use" or "cast")
end

local function BuildDrawer()
  local ui, w = ns.ui, ns.ed.w
  -- meme place et meme taille que la palette (160 x 430), opaque et au-dessus d'elle : elle revient a la fermeture
  drawer = ui.Panel(w.page, 160, 430, L["Mon grimoire"])
  drawer:SetPoint("TOPLEFT", w.palette, "TOPLEFT")
  drawer:SetBackdropColor(T.panel[1], T.panel[2], T.panel[3], 1)
  drawer:SetFrameStrata("DIALOG")
  drawer:EnableMouse(true) -- le fond arrete les clics
  drawer:Hide()
  ns.CloseChip(drawer)
  -- 4 colonnes de 34 px : de 9 a 151 ; puces de -28 a -46, recherche de -50 a -70, 9 lignes de -74 a -396
  local grid = ns.BuildSpellGrid(drawer, 9, -28, 4, 9, 34, OnPick)
  grid.tip = L["Clic : ajoute à ta macro, ou remplit le bloc choisi. Maj+clic : ouvre l'Assistant pour ce sort."]
  -- sous la grille : rappel de -400 a -412, position dans la liste de -412 a -424 (panneau : 430)
  ui.Label(drawer, L["Maj+clic : Assistant"], 9, -400, "GameFontDisableSmall")
  grid.range:SetPoint("BOTTOMRIGHT", -9, 6)
  drawer.grid = grid
  ns.grimoire = drawer
end

function ns.HideGrimoire()
  if drawer then drawer:Hide() end
end

function ns.ToggleGrimoire()
  if drawer and drawer:IsShown() then return drawer:Hide() end
  if ns.Off("grimoire") then return end
  if InCombatLockdown() then return ns.Msg(L["Impossible de modifier une macro en combat."]) end
  if not drawer then BuildDrawer() end
  if ns.assistant then ns.assistant:Hide() end -- il couvrirait le tiroir
  drawer.grid.Fill()
  drawer:Show()
end

-- appele par UI.lua a la fin de la construction de l'editeur
function ns.BuildGrimoire()
  local ui, w = ns.ui, ns.ed.w
  -- sur la ligne des onglets (finis a 510 dans la page, de +25 a +3 au-dessus d'elle), dans l'editeur seulement :
  -- grimoire de 638 a 758, assistant de 764 a 884
  local assistant = ui.Button(w.page, L["Assistant"], 120, function() ns.OpenAssistant() end)
  assistant:SetPoint("BOTTOMRIGHT", w.page, "TOPRIGHT", 0, 3)
  T.Watch(function() ui.Tint(assistant, T.accent, 0.9) end)
  ui.Tip(assistant, function()
    return L["Assistant"], L["Choisis un sort : l'Assistant te propose des macros toutes faites, à créer en un clic. Aussi : /bf assistant."]
  end)
  local book = ui.Button(w.page, L["Mon grimoire"], 120, ns.ToggleGrimoire)
  book:SetPoint("RIGHT", assistant, "LEFT", -6, 0)
  ui.Tip(book, function()
    return L["Mon grimoire"], L["Tes sorts, les techniques de ton familier et tes objets utilisables, à ajouter d'un clic. S'ouvre à la place de la liste des blocs."]
  end)
  w.assistantButton, w.grimoireButton = assistant, book
  ns.OnFeatures(function()
    local grimoire, helper = ns.Enabled("grimoire"), ns.Enabled("assistant")
    book:SetShown(grimoire)
    assistant:SetShown(helper)
    if drawer then
      drawer.grid.Listen(grimoire)
      if not grimoire then drawer:Hide() end
    end
    if ns.assistant then
      ns.assistant.grid.Listen(helper)
      if not helper then ns.assistant:Hide() end
    end
  end, true)

  -- combat, onglet change ou fenetre fermee : le tiroir et l'Assistant se ferment
  local function HideAll()
    ns.HideGrimoire()
    if ns.assistant then ns.assistant:Hide() end
  end
  local events = CreateFrame("Frame")
  events:RegisterEvent("PLAYER_REGEN_DISABLED")
  events:SetScript("OnEvent", HideAll)
  w.page:HookScript("OnHide", HideAll)
end
