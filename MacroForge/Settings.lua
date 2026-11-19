-- MacroForge : parametres sauvegardes (MacroForgeDB) et page d'options
-- La page est construite deux fois : dans l'onglet "Paramètres" de la fenetre et dans les options du jeu.
local ADDON, ns = ...
local L = ns.L

ns.DEFAULTS = {
  minimap = { show = true, angle = 225 },
  scale = 1,
  rememberPos = true,
  pos = false,             -- { point, relPoint, x, y } ; false = fenetre centree
  perCharDefault = false,
  pickupAfterCreate = true,
  confirmOverwrite = true,
  localizeLibrary = true,
  libraryClass = "player", -- "player" (ma classe) ou "last" (derniere consultee)
  lastClass = false,
  helpTooltips = true,
}
ns.SCALE_MIN, ns.SCALE_MAX, ns.SCALE_STEP = 0.6, 1.5, 0.05

local OPTIONAL = { pos = true, lastClass = true } -- false ou une valeur, controlee par Sanitize

-- Complete db avec les valeurs par defaut ; une valeur du mauvais type est remplacee.
local function Merge(db, defaults)
  for k, def in pairs(defaults) do
    local v = db[k]
    if type(def) == "table" then
      if type(v) ~= "table" then v = {} end
      Merge(v, def)
      db[k] = v
    elseif v == nil or (not OPTIONAL[k] and type(v) ~= type(def)) then
      db[k] = def
    end
  end
end

local function Sanitize(db)
  local p = db.pos
  if p and not (type(p) == "table" and type(p[1]) == "string" and type(p[2]) == "string"
                and type(p[3]) == "number" and type(p[4]) == "number") then
    db.pos = false
  end
  if db.lastClass and type(db.lastClass) ~= "string" then db.lastClass = false end
  if db.libraryClass ~= "player" and db.libraryClass ~= "last" then db.libraryClass = "player" end
  db.scale = math.min(ns.SCALE_MAX, math.max(ns.SCALE_MIN, db.scale))
  db.minimap.angle = db.minimap.angle % 360
end

function ns.InitDB()
  if type(MacroForgeDB) ~= "table" then MacroForgeDB = {} end
  Merge(MacroForgeDB, ns.DEFAULTS)
  Sanitize(MacroForgeDB)
  ns.db = MacroForgeDB
end

local pages = {}

-- Applique tous les reglages a ce qui existe deja (fenetre, bouton, bibliotheque, pages)
function ns.ApplySettings()
  if ns.ApplyWindow then ns.ApplyWindow() end
  if ns.ApplyPerCharDefault then ns.ApplyPerCharDefault() end
  if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
  if ns.RefreshLibrary then ns.RefreshLibrary() end
  for _, page in ipairs(pages) do page.Sync() end
end

function ns.ResetDB()
  for k in pairs(MacroForgeDB) do MacroForgeDB[k] = nil end
  ns.InitDB()
  ns.ApplySettings()
end

---------------------------------------------------------------------------
-- Page d'options
---------------------------------------------------------------------------
local CHECKS = {
  { L["Afficher le bouton de la minicarte"], function(db) return db.minimap.show end,
    function(db, v) db.minimap.show = v end, function() ns.UpdateMinimapButton() end,
    L["Le bouton se déplace en le glissant autour de la minicarte."] },
  { L["Mémoriser la position de la fenêtre"], function(db) return db.rememberPos end,
    function(db, v) db.rememberPos = v if not v then db.pos = false end end, function() if ns.ApplyWindow then ns.ApplyWindow() end end,
    L["Désactivé : la fenêtre s'ouvre au centre de l'écran."] },
  { L["« Ce personnage seulement » coché par défaut"], function(db) return db.perCharDefault end,
    function(db, v) db.perCharDefault = v end, function() if ns.ApplyPerCharDefault then ns.ApplyPerCharDefault() end end,
    L["Les nouvelles macros vont dans l'onglet du personnage (30 places) au lieu des macros générales (120)."] },
  { L["Mettre la macro sous le curseur après création"], function(db) return db.pickupAfterCreate end,
    function(db, v) db.pickupAfterCreate = v end, nil,
    L["Pratique pour la poser tout de suite sur une barre d'action."] },
  { L["Demander confirmation avant d'écraser une macro existante"], function(db) return db.confirmOverwrite end,
    function(db, v) db.confirmOverwrite = v end, nil,
    L["Quand une macro du jeu porte déjà ce nom."] },
  { L["Traduire la bibliothèque dans la langue du jeu"], function(db) return db.localizeLibrary end,
    function(db, v) db.localizeLibrary = v end, function() if ns.RefreshLibrary then ns.RefreshLibrary() end end,
    L["Désactivé : les macros de la bibliothèque restent en anglais."] },
  { L["Infobulles d'aide détaillées"], function(db) return db.helpTooltips end,
    function(db, v) db.helpTooltips = v end, nil,
    L["Désactivé : les infobulles n'affichent plus que leur titre."] },
}

local function CheckBox(parent, x, y, text)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(26, 26)
  cb:SetPoint("TOPLEFT", x, y)
  local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
  label:SetText(text)
  return cb
end

function ns.BuildSettingsPage(parent, title)
  local ui = ns.ui
  local syncs = {}
  local y = -12
  if title then
    local t = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 16, -16)
    t:SetText(title)
    y = -44
  else
    y = -36
  end

  for _, c in ipairs(CHECKS) do
    local label, get, set, apply, help = c[1], c[2], c[3], c[4], c[5]
    local cb = CheckBox(parent, 16, y, label)
    cb:SetScript("OnClick", function(self)
      set(ns.db, self:GetChecked() and true or false)
      if apply then apply() end
    end)
    ui.Tip(cb, function() return label, help end)
    syncs[#syncs + 1] = function() cb:SetChecked(get(ns.db)) end
    y = y - 28
  end

  -- Echelle
  y = y - 10
  local scaleText = ui.Label(parent, "", 20, y - 5, "GameFontHighlight")
  local function SetScale(v)
    v = math.floor(v / ns.SCALE_STEP + 0.5) * ns.SCALE_STEP
    ns.db.scale = math.min(ns.SCALE_MAX, math.max(ns.SCALE_MIN, v))
    if ns.ApplyWindow then ns.ApplyWindow() end
    for _, page in ipairs(pages) do page.Sync() end
  end
  local minus = ui.Button(parent, "-", 26, function() SetScale(ns.db.scale - ns.SCALE_STEP) end)
  minus:SetPoint("TOPLEFT", 230, y)
  local plus = ui.Button(parent, "+", 26, function() SetScale(ns.db.scale + ns.SCALE_STEP) end)
  plus:SetPoint("LEFT", minus, "RIGHT", 4, 0)
  local one = ui.Button(parent, L["100 %"], 60, function() SetScale(1) end)
  one:SetPoint("LEFT", plus, "RIGHT", 4, 0)
  syncs[#syncs + 1] = function()
    scaleText:SetText(L["Échelle de la fenêtre : %d %%"]:format(math.floor(ns.db.scale * 100 + 0.5)))
  end

  -- Classe affichee au depart dans la bibliotheque (deux cases exclusives)
  y = y - 40
  ui.Label(parent, L["Classe affichée à l'ouverture de la bibliothèque :"], 20, y, "GameFontNormal")
  y = y - 18
  local radios = {}
  for i, choice in ipairs({ { "player", L["Ma classe"] }, { "last", L["Dernière consultée"] } }) do
    local cb = CheckBox(parent, 30 + (i - 1) * 180, y, choice[2])
    cb:SetScript("OnClick", function()
      ns.db.libraryClass = choice[1]
      for _, page in ipairs(pages) do page.Sync() end
    end)
    radios[choice[1]] = cb
  end
  syncs[#syncs + 1] = function()
    for key, cb in pairs(radios) do cb:SetChecked(ns.db.libraryClass == key) end
  end

  y = y - 46
  local reset = ui.Button(parent, L["Réinitialiser les paramètres"], 210, function() ns.ResetDB() end)
  reset:SetPoint("TOPLEFT", 18, y)
  ui.Tip(reset, function() return L["Réinitialiser"], L["Remet tous les paramètres par défaut, y compris la position de la fenêtre et du bouton."] end)
  ui.Label(parent, L["Commande : /mf (ouvrir), /mf options (cette page)"], 20, y - 34, "GameFontDisableSmall")

  local page = { Sync = function() if ns.db then for _, f in ipairs(syncs) do f() end end end }
  pages[#pages + 1] = page
  parent:HookScript("OnShow", page.Sync)
  page.Sync()
  return page
end

---------------------------------------------------------------------------
-- Chargement : base de donnees, options du jeu, bouton de minicarte
---------------------------------------------------------------------------
local function RegisterGameOptions()
  local panel = CreateFrame("Frame")
  panel.name = "MacroForge" -- lu par InterfaceOptions_AddCategory (Classic Era)
  local page = ns.BuildSettingsPage(panel, "MacroForge")
  panel.OnRefresh = page.Sync         -- appeles par le panneau d'options de Forever s'ils existent
  panel.OnDefault = function() ns.ResetDB() end
  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, "MacroForge")
    Settings.RegisterAddOnCategory(category)
    ns.optionsCategory = category
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, name)
  if name ~= ADDON then return end
  self:UnregisterEvent("ADDON_LOADED")
  ns.InitDB()
  RegisterGameOptions()
  if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
end)
