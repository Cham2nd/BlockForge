-- BlockForge : parametres sauvegardes (BlockForgeDB) et page d'options
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
  accent = "class",        -- couleur d'accent : "class" (classe du joueur) ou "gold"
  favorites = {},          -- [classe .. "/" .. nom] = true (bibliotheque)
  sets = {},               -- avant la 1.0 : [nom] = { { name, icon, body, char }, ... } ; relu et copie dans profiles (Profiles.lua)
  profiles = {},           -- [nom] = { macros, bindings, bars, owner, class, auto } : profils et sauvegardes automatiques
  specProfiles = {},       -- [personnage] = { [groupe de talents] = nom du profil propose }
  living = { chars = {}, account = {}, journal = {} }, -- macros vivantes : modeles a jetons et 20 dernieres reecritures (Living.lua)
  kits = {},               -- [personnage] = { class, role, hover, pet, waiting } : kit choisi (Kits.lua)
  personal = {},           -- { { name, body, icon, note }, ... } : "Mes modeles", communs a tous les personnages
  acceptShared = true,     -- proposer les macros envoyees par d'autres joueurs (Share.lua)
  tutorialSeen = false,    -- la visite guidee s'est deja lancee toute seule
  undo = false,            -- derniere operation annulable sur les barres ou les macros (Bars.lua) : { label, ops }
  features = {},           -- [id] = true / false : fonctions que le joueur peut couper (ns.RegisterFeature)
  errors = {},             -- diagnostics (Debug.lua) : 20 dernieres erreurs Lua de l'add-on
  selftest = {},           -- diagnostics (Debug.lua) : dernier rapport de /bf test
}
ns.SCALE_MIN, ns.SCALE_MAX, ns.SCALE_STEP = 0.6, 1.5, 0.05

local OPTIONAL = { pos = true, lastClass = true, undo = true }

---------------------------------------------------------------------------
-- Fonctions que le joueur peut couper, sans /reload (Parametres, section « Fonctions »).
-- { id, label, desc, default, key } ; key : reglage historique qui porte la valeur a la place de BlockForgeDB.features[id].
-- Un fichier charge plus tard ajoute les siennes par ns.RegisterFeature, et reagit par ns.OnFeatures.
---------------------------------------------------------------------------
ns.Features = {}
local featureById, featureWatchers = {}, {}

function ns.RegisterFeature(def)
  ns.Features[#ns.Features + 1] = def
  featureById[def.id] = def
  if not def.key then ns.DEFAULTS.features[def.id] = def.default ~= false end
end

function ns.Enabled(id)
  local def, db = featureById[id], ns.db
  if not def or not db then return true end
  if def.key then return db[def.key] ~= false end
  return db.features[id] ~= false
end

-- true, et un message, quand la fonction est coupee : « if ns.Off("bars") then return end »
function ns.Off(id)
  if ns.Enabled(id) then return false end
  ns.Msg(L["« %s » : fonction désactivée dans les Paramètres."]:format(featureById[id].label))
  return true
end

-- fn : affiche ou cache les entrees d'une fonction, inscrit ou retire ses evenements ; now : appelee aussi tout de suite
function ns.OnFeatures(fn, now)
  featureWatchers[#featureWatchers + 1] = fn
  if now then fn() end
end

-- une fonction qui echoue n'empeche pas les autres de suivre le reglage
function ns.ApplyFeatures()
  for _, fn in ipairs(featureWatchers) do
    local ok, err = pcall(fn)
    if not ok and geterrorhandler then geterrorhandler()(err) end
  end
end

-- evenements d'un cadre inscrits seulement tant que sa fonction est active
function ns.Listen(frame, on, ...)
  for i = 1, select("#", ...) do
    local event = select(i, ...)
    if on then frame:RegisterEvent(event) else frame:UnregisterEvent(event) end
  end
end

for _, def in ipairs({
  { id = "home", label = L["Onglet Accueil"], desc = L["Désactivé : l'onglet disparaît et la fenêtre s'ouvre sur l'éditeur."] },
  { id = "bars", label = L["Améliorer ma barre"], desc = L["Désactivé : BlockForge ne modifie plus aucun emplacement de tes barres d'action, conversions en masse comprises."] },
  { id = "health", label = L["Bilan de santé"], desc = L["Désactivé : plus de contrôle de tes macros, ni réparation, ni archivage."] },
  { id = "suggestions", label = L["Suggestions de l'accueil"], desc = L["Désactivé : l'accueil ne propose plus de macros de la bibliothèque."] },
  { id = "gauge", label = L["Jauge des macros dans l'en-tête"], desc = L["Désactivé : le compte des emplacements de macro n'est plus affiché en haut de la fenêtre."] },
  { id = "assistant", label = L["Assistant"], desc = L["Désactivé : le bouton, l'entrée de l'accueil et /bf assistant ne proposent plus de macros toutes faites."] },
  { id = "grimoire", label = L["Mon grimoire"], desc = L["Désactivé : le bouton « Mon grimoire » de l'éditeur disparaît."] },
  { id = "share", key = "acceptShared", label = L["Échange de macros entre joueurs"],
    desc = L["Envoyer une macro à un joueur et recevoir les siennes. Une macro reçue t'est toujours proposée avant d'être ouverte. Désactivé : rien n'est envoyé, et ce qui arrive est ignoré sans rien afficher."] },
  { id = "tutorial", label = L["Visite guidée à la première ouverture"], desc = L["Désactivé : la visite ne se lance plus toute seule. /bf tuto la lance toujours."] },
  { id = "colorize", label = L["Aperçu coloré"], desc = L["Désactivé : le texte des macros s'affiche d'une seule couleur."] },
  { id = "living", label = L["Macros vivantes"], desc = L["Désactivé : BlockForge ne réécrit plus aucune macro tout seul, et « Vivant… » disparaît de l'éditeur. Tes macros gardent leur dernier texte."] },
  { id = "kits", label = L["Kits de personnage"], desc = L["Désactivé : plus de « Équiper mon personnage », ni d'annonce des macros de ton kit devenues disponibles."] },
  { id = "profiles", label = L["Profils"], desc = L["Désactivé : la colonne des profils de « Mes macros » disparaît. Les sauvegardes automatiques restent faites avant chaque opération de masse."] },
  { id = "specProfiles", label = L["Proposer un profil au changement de spé"], desc = L["Désactivé : BlockForge ne propose plus rien quand tu changes de spécialisation."] },
}) do ns.RegisterFeature(def) end -- false ou une valeur, controlee par Sanitize

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
  if db.undo and not (type(db.undo) == "table" and type(db.undo.ops) == "table" and type(db.undo.label) == "string") then db.undo = false end
  if db.libraryClass ~= "player" and db.libraryClass ~= "last" then db.libraryClass = "player" end
  if db.accent ~= "class" and db.accent ~= "gold" then db.accent = "class" end
  db.scale = math.min(ns.SCALE_MAX, math.max(ns.SCALE_MIN, db.scale))
  db.minimap.angle = db.minimap.angle % 360
  -- modeles : seules les entrees lisibles sont gardees (fichier modifie a la main, ancienne version)
  local kept = {}
  for _, m in ipairs(db.personal) do
    if type(m) == "table" and type(m.name) == "string" and type(m.body) == "string" then
      if type(m.note) ~= "string" then m.note = nil end
      if type(m.icon) ~= "string" and type(m.icon) ~= "number" then m.icon = nil end
      kept[#kept + 1] = m
    end
  end
  db.personal = kept
end

function ns.InitDB()
  if type(BlockForgeDB) ~= "table" then BlockForgeDB = {} end
  Merge(BlockForgeDB, ns.DEFAULTS)
  Sanitize(BlockForgeDB)
  ns.db = BlockForgeDB
  ns.ApplyTheme()
  ns.ApplyFeatures()
  if ns.FlushErrors then ns.FlushErrors() end
end

local pages = {}

-- Applique tous les reglages a ce qui existe deja (fenetre, bouton, bibliotheque, pages)
function ns.ApplySettings()
  ns.ApplyTheme()
  if ns.ApplyWindow then ns.ApplyWindow() end
  if ns.ApplyPerCharDefault then ns.ApplyPerCharDefault() end
  if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
  if ns.RefreshLibrary then ns.RefreshLibrary() end
  ns.ApplyFeatures()
  for _, page in ipairs(pages) do page.Sync() end
end

function ns.SetFeature(id, on)
  local def = featureById[id]
  if not def or not ns.db then return end
  if def.key then ns.db[def.key] = on else ns.db.features[id] = on end
  ns.ApplyFeatures()
  for _, page in ipairs(pages) do page.Sync() end
end

function ns.ResetDB()
  -- favoris, sauvegardes et modeles ne sont pas des reglages : la reinitialisation les garde (et ne relance pas la visite)
  local keep = {}
  for _, k in ipairs({ "favorites", "sets", "profiles", "specProfiles", "living", "kits", "personal", "tutorialSeen", "undo" }) do keep[k] = BlockForgeDB[k] end
  for k in pairs(BlockForgeDB) do BlockForgeDB[k] = nil end
  for k, v in pairs(keep) do BlockForgeDB[k] = v end
  ns.personalCache = nil
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

-- Titre a y, puis une case par choix dessous ; db[key] prend la valeur de la case cochee
local function Radios(parent, y, syncs, title, key, choices, apply)
  ns.ui.Label(parent, title, 20, y, "GameFontNormal")
  local boxes = {}
  for i, choice in ipairs(choices) do
    local cb = CheckBox(parent, 30 + (i - 1) * 180, y - 18, choice[2])
    cb:SetScript("OnClick", function()
      ns.db[key] = choice[1]
      if apply then apply() end
      for _, page in ipairs(pages) do page.Sync() end
    end)
    boxes[choice[1]] = cb
  end
  syncs[#syncs + 1] = function()
    for value, cb in pairs(boxes) do cb:SetChecked(ns.db[key] == value) end
  end
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

  -- Deux choix exclusifs : classe affichee au depart dans la bibliotheque, couleur d'accent (appliquee tout de suite)
  y = y - 40
  Radios(parent, y, syncs, L["Classe affichée à l'ouverture de la bibliothèque :"], "libraryClass",
    { { "player", L["Ma classe"] }, { "last", L["Dernière consultée"] } })
  y = y - 52
  Radios(parent, y, syncs, L["Couleur d'accent de l'interface :"], "accent",
    { { "class", L["Couleur de ma classe"] }, { "gold", L["Or"] } }, ns.ApplyTheme)
  y = y - 18

  y = y - 46
  local reset = ui.Button(parent, L["Réinitialiser les paramètres"], 210, function() ns.ResetDB() end)
  reset:SetPoint("TOPLEFT", 18, y)
  ui.Tip(reset, function() return L["Réinitialiser"], L["Remet tous les paramètres par défaut, y compris la position de la fenêtre et du bouton."] end)
  -- reinitialiser de 18 a 228, visite guidee de 234 a 414
  local tour = ui.Button(parent, L["Revoir le tutoriel"], 180, function()
    if ns.Tutorial then ns.Tutorial.Start(true) end
  end)
  tour:SetPoint("LEFT", reset, "RIGHT", 6, 0)
  ui.Tip(tour, function() return L["Revoir le tutoriel"], L["Relance la visite guidée de la fenêtre, étape par étape. Aussi : /bf tuto."] end)
  ui.Label(parent, L["Commandes : /bf (ouvrir), /bf options (cette page), /bf tuto (visite guidée), /bf test (diagnostic)"], 20, y - 34, "GameFontDisableSmall")

  -- Fonctions : colonne de droite de l'onglet (de 470 a 876), une case de 26 px tous les 26 depuis -54 ;
  -- 14 cases finissent a -418, au-dessus de la ligne des commandes (-432).
  -- shortcut: absente de la page d'options du jeu, trop etroite pour deux colonnes ; a mettre en liste defilante si on la veut la-bas
  if not title then
    ui.Label(parent, L["Fonctions (décoche pour désactiver)"], 474, -36, "GameFontNormal")
    for i, def in ipairs(ns.Features) do
      local cb = CheckBox(parent, 470, -54 - (i - 1) * 26, def.label)
      cb:SetScript("OnClick", function(self) ns.SetFeature(def.id, self:GetChecked() and true or false) end)
      ui.Tip(cb, function() return def.label, def.desc end)
      syncs[#syncs + 1] = function() cb:SetChecked(ns.Enabled(def.id)) end
    end
  end

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
  panel.name = "BlockForge" -- lu par InterfaceOptions_AddCategory (Classic Era)
  local page = ns.BuildSettingsPage(panel, "BlockForge")
  panel.OnRefresh = page.Sync         -- appeles par le panneau d'options de Forever s'ils existent
  panel.OnDefault = function() ns.ResetDB() end
  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, "BlockForge")
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
