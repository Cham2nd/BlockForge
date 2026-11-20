-- BlockForge : onglet Accueil. Jauge des emplacements de macro, bilan de sante en bref, grandes entrees, suggestions.
-- Charge apres Wand.lua et Health.lua ; construit par UI.lua (ns.BuildHome) a la premiere ouverture de la fenetre.
local ADDON, ns = ...
local L = ns.L
local T = ns.Theme

local MAX_TILES, MAX_SUGGEST = 8, 5
local LEVEL = { ok = { 0.8, 0.8, 0.8 }, warn = { 1, 0.7, 0.3 }, full = { 1, 0.3, 0.3 } }

-- Grandes entrees de l'accueil : { id, title, desc (deux lignes de 192 px au plus), run, feature (facultatif : ns.Features) }.
-- Les fichiers charges ensuite ajoutent les leurs par table.insert ; huit tuiles au plus, quatre par ligne.
ns.HomeActions = {
  { id = "assistant", feature = "assistant", title = L["Assistant"], desc = L["Une bonne macro en deux clics, à partir d'un de tes sorts."],
    run = function() ns.OpenAssistant() end },
  { id = "wand", feature = "bars", title = L["Améliorer ma barre"], desc = L["Remplace un sort de ta barre par sa macro, à la même place."],
    run = function() ns.OpenWand() end },
  { id = "library", title = L["Bibliothèque"], desc = L["Des centaines de macros prêtes, classe par classe."],
    run = function() ns.Open("library") end },
  { id = "macros", title = L["Mes macros"], desc = L["Tes macros du jeu : touches, partage, sauvegardes."],
    run = function() ns.Open("macros") end },
}

-- Ajouts au bandeau de l'accueil : fonctions (bandeau, page) appelees a la fin de ns.BuildHome par les fichiers charges ensuite.
-- Place libre a droite du compte des macros : de 640 a 876, deux lignes de 18 px a -50 et a -72.
ns.HomeBuilders = {}

-- un seul grand panneau a la fois par-dessus une page
function ns.HidePanels()
  for _, key in ipairs({ "wand", "health", "assistant", "kitsPanel", "livingPanel", "profilesPanel" }) do
    if ns[key] then ns[key]:Hide() end
  end
end

local home -- widgets de la page, poses par ns.BuildHome

-- jauge de l'en-tete (visible sur tous les onglets) et du bandeau de l'accueil
local function PaintGauge()
  local account, char = GetNumMacros()
  local maxAccount, maxChar = ns.MacroLimits()
  account, char = account or 0, char or 0
  local text, level = ns.Gauge(account, maxAccount, char, maxChar)
  home.gauge:SetShown(ns.Enabled("gauge"))
  home.gauge.text:SetText(text)
  home.gauge.text:SetTextColor(LEVEL[level][1], LEVEL[level][2], LEVEL[level][3])
  home.counts:SetText(L["Macros générales : %d / %d  ·  macros de ce personnage : %d / %d"]:format(account, maxAccount, char, maxChar))
  for i, pair in ipairs({ { account, maxAccount }, { char, maxChar } }) do
    local _, own = ns.Gauge(pair[1], pair[2], 0, 1)
    local c = own == "ok" and T.accent or LEVEL[own]
    home.bars[i]:SetWidth(math.max(1, 300 * math.min(1, pair[1] / pair[2])))
    home.bars[i]:SetColorTexture(c[1], c[2], c[3], 0.9)
  end
end

-- macros de la bibliotheque dont le personnage connait tous les sorts : sa classe d'abord, puis « toutes classes »
local function Candidates()
  local _, class = UnitClass("player")
  local list = {}
  for _, wanted in ipairs({ class or "", "ALL" }) do
    for _, entry in ipairs(ns.Library or {}) do
      if entry.class == wanted and #ns.LibraryUnknown(entry) == 0 then
        list[#list + 1] = { name = entry.name, body = ns.LibraryBody(entry), entry = entry }
      end
    end
  end
  return list
end

-- full : aussi le bilan et les suggestions (hors combat seulement : ils lisent sorts, macros et barres)
local function Refresh(full)
  if not home then return end
  PaintGauge()
  if not full or InCombatLockdown() or not ns.Enabled("home") then return end
  local ui = ns.ui
  -- une fonction coupee dans les Parametres ne calcule rien
  if ns.Enabled("health") then
    local report = ns.Health.Report()
    home.report = report
    for _, chip in ipairs(home.healthChips) do
      local n = #report[chip.group.key]
      chip.text:SetText(L["%s : %d"]:format(chip.group.label, n))
      ui.Tint(chip, n > 0 and T.accent or T.grey, n > 0 and 0.8 or 0.5)
    end
    home.healthTotal:SetText(L["%d macros contrôlées."]:format(report.total))
  end
  home.suggestions = ns.Enabled("suggestions") and ns.Suggestions(Candidates(), ns.ReadMacros(), MAX_SUGGEST) or {}
  for i, row in ipairs(home.rows) do
    local s = home.suggestions[i]
    row:SetShown(s ~= nil)
    if s then
      row.text:SetText(ns.Plain(s.name))
      row.desc:SetText(ns.LibraryDesc(s.entry) or "")
    end
  end
  home.noSuggestion:SetShown(#home.suggestions == 0)
end

function ns.RefreshHome() Refresh(home ~= nil and home.page:IsVisible()) end

local function OpenSuggestion(i)
  local s = home.suggestions[i]
  if s and ns.ed.Load(s.name, s.body) then ns.Open("editor") end
end

local function CreateSuggestion(i)
  local s = home.suggestions[i]
  if not s then return end
  ns.ed.SaveMacro(ns.MacroName(s.name), s.body, ns.db.perCharDefault and true or false, nil, false)
  Refresh(true) -- la macro creee quitte les suggestions
end

function ns.BuildHome(page)
  local ui, w = ns.ui, ns.ed.w
  home = { page = page, bars = {}, tiles = {}, healthChips = {}, rows = {}, suggestions = {} }
  ns.home = home

  -- Page de 884 x 566 : bandeau de 0 a -96, entrees de -102 a -252, puis de -258 a -566 le bilan (0 a 300) et les suggestions (306 a 884)
  local top = ui.Panel(page, 884, 96, L["Accueil"])
  top:SetPoint("TOPLEFT")
  local className = UnitClass("player")
  local hello = ui.Label(top, L["Bienvenue, %s — %s"]:format(UnitName and UnitName("player") or "?", className or "?"), 10, -30, "GameFontHighlightLarge")
  hello:SetWidth(864)
  hello:SetWordWrap(false)
  home.counts = ui.Label(top, "", 10, -54, "GameFontHighlight")
  home.counts:SetWidth(620) -- les lignes des kits et des macros vivantes commencent a 640
  home.counts:SetWordWrap(false)
  -- deux barres de 300 x 6 a -76 : macros generales de 10 a 310, macros du personnage de 330 a 630
  for i = 1, 2 do
    local bg = top:CreateTexture(nil, "ARTWORK")
    bg:SetColorTexture(1, 1, 1, 0.08)
    bg:SetPoint("TOPLEFT", 10 + (i - 1) * 320, -76)
    bg:SetSize(300, 6)
    home.bars[i] = top:CreateTexture(nil, "OVERLAY")
    home.bars[i]:SetPoint("TOPLEFT", bg)
    home.bars[i]:SetHeight(6)
  end

  -- Jauge de l'en-tete : 140 px a gauche de la version (vers 675 a 815 ; le titre finit avant 320)
  local gauge = CreateFrame("Frame", nil, w.main)
  gauge:SetSize(140, 16)
  gauge:SetPoint("RIGHT", w.headerRight, "LEFT", -12, 0)
  gauge:EnableMouse(true)
  gauge.text = gauge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  gauge.text:SetPoint("RIGHT")
  ui.Tip(gauge, function()
    return L["Emplacements de macro"], L["Macros générales, puis macros de ce personnage. La jauge passe à l'orange près de la limite, au rouge quand un onglet est plein."]
  end)
  home.gauge = gauge

  -- Entrees : tuiles de 212 x 52 tous les 218 (de 8 a 874), deux lignes a -28 et -86 (fin a -138, panneau : 150)
  local actions = ui.Panel(page, 884, 150, L["Que veux-tu faire ?"])
  actions:SetPoint("TOPLEFT", 0, -102)
  for i, action in ipairs(ns.HomeActions) do
    if i > MAX_TILES then break end
    local tile = ui.Chip(actions, 212, 52)
    tile:SetPoint("TOPLEFT", 8 + ((i - 1) % 4) * 218, -28 - math.floor((i - 1) / 4) * 58)
    tile.text:ClearAllPoints()
    tile.text:SetPoint("TOPLEFT", 10, -7)
    tile.text:SetWidth(192)
    tile.text:SetFontObject(GameFontNormal)
    tile.text:SetText(action.title)
    tile.desc = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tile.desc:SetPoint("TOPLEFT", 10, -23)
    tile.desc:SetSize(192, 24)
    tile.desc:SetJustifyH("LEFT")
    tile.desc:SetJustifyV("TOP")
    tile.desc:SetText(action.desc)
    tile.action = action
    T.Watch(function() ui.Tint(tile, T.accent, 0.45) end)
    tile:SetScript("OnClick", function() action.run() end)
    ui.Tip(tile, function() return action.title, action.desc end)
    home.tiles[i] = tile
  end
  home.actions = actions

  -- Bilan en bref (300 x 308) : total a -30, quatre groupes de 24 px tous les 28 de -48 a -156, aide de -166 a -202, bouton en bas
  local health = ui.Panel(page, 300, 308, L["Bilan de santé"])
  health:SetPoint("TOPLEFT", 0, -258)
  home.healthTotal = ui.Label(health, "", 10, -30, "GameFontHighlightSmall")
  for i, group in ipairs(ns.HealthGroups) do
    local chip = ui.Chip(health, 284, 24)
    chip:SetPoint("TOPLEFT", 8, -48 - (i - 1) * 28)
    chip.group = group
    chip:SetScript("OnClick", function() ns.OpenHealth(group.key) end)
    ui.Tip(chip, function() return group.label, group.tip end)
    home.healthChips[i] = chip
  end
  local hint = ui.Label(health, L["Clique sur un groupe pour voir ses macros : ouvrir, réparer, ou archiver dans « Mes modèles » avant de supprimer."],
    10, -166, "GameFontDisableSmall")
  hint:SetWidth(280)
  local openHealth = ui.Button(health, L["Ouvrir le bilan de santé"], 284, function() ns.OpenHealth() end)
  openHealth:SetPoint("BOTTOMLEFT", 8, 10)
  T.Watch(function() ui.Tint(openHealth, T.accent, 0.9) end)

  -- Suggestions (578 x 308) : cinq lignes de 562 x 50 tous les 54, de -28 a -294 ;
  -- nom et description de 10 a 376, « Ouvrir » de 386 a 466, « Creer » de 472 a 552
  local suggest = ui.Panel(page, 578, 308, L["Suggestions pour ton personnage"])
  suggest:SetPoint("TOPLEFT", 306, -258)
  for i = 1, MAX_SUGGEST do
    local row = ui.Chip(suggest, 562, 50)
    row:SetPoint("TOPLEFT", 8, -28 - (i - 1) * 54)
    ui.Tint(row, T.grey, 0.5)
    row.text:ClearAllPoints()
    row.text:SetPoint("TOPLEFT", 10, -6)
    row.text:SetWidth(366)
    row.desc = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.desc:SetPoint("TOPLEFT", 10, -22)
    row.desc:SetSize(366, 24)
    row.desc:SetJustifyH("LEFT")
    row.desc:SetJustifyV("TOP")
    row.open = ui.Button(row, L["Ouvrir"], 80, function() OpenSuggestion(i) end)
    row.open:SetPoint("RIGHT", -96, 0)
    row.create = ui.Button(row, L["Créer"], 80, function() CreateSuggestion(i) end)
    row.create:SetPoint("RIGHT", -10, 0)
    row:SetScript("OnClick", function() OpenSuggestion(i) end)
    ui.Tip(row, function()
      local s = home.suggestions[i]
      if s then return ns.Plain(s.name), ns.LibraryDesc(s.entry), L["Une macro de la bibliothèque que tu n'as pas encore, et dont ton personnage connaît tous les sorts."] end
    end)
    home.rows[i] = row
  end
  home.noSuggestion = ui.Label(suggest, L["Rien à suggérer : tu as déjà les macros de la bibliothèque que ton personnage peut lancer."], 10, -34, "GameFontDisableSmall")
  home.noSuggestion:SetWidth(556)

  w.home, w.homeTop, w.homeActions, w.homeHealth, w.homeSuggest = page, top, actions, health, suggest
  for _, build in ipairs(ns.HomeBuilders) do build(top, page) end
  page:SetScript("OnEvent", function() if w.main:IsVisible() then ns.RefreshHome() end end)
  page:HookScript("OnShow", ns.RefreshHome)
  T.OnChange(function() Refresh(false) end)
  -- fonctions coupees dans les Parametres : leurs tuiles et leurs panneaux disparaissent, les tuiles restantes se resserrent
  ns.OnFeatures(function()
    local shown = 0
    for _, tile in ipairs(home.tiles) do
      local on = not tile.action.feature or ns.Enabled(tile.action.feature)
      tile:SetShown(on)
      if on then
        tile:ClearAllPoints()
        tile:SetPoint("TOPLEFT", 8 + (shown % 4) * 218, -28 - math.floor(shown / 4) * 58)
        shown = shown + 1
      end
    end
    health:SetShown(ns.Enabled("health"))
    suggest:SetShown(ns.Enabled("suggestions"))
    -- la jauge de l'en-tete et l'accueil ecoutent les memes evenements
    ns.Listen(page, ns.Enabled("home") or ns.Enabled("gauge"), "UPDATE_MACROS", "PLAYER_REGEN_ENABLED")
    Refresh(true)
  end, true)
end
