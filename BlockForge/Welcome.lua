-- BlockForge : presentation 1.0, autonome sur UIParent, sans lecture du personnage en combat.
local ADDON, ns = ...
local L, T = ns.L, ns.Theme
local W = { version = '1.0', groups = {}, tiles = {}, icons = {} }
ns.Welcome = W
ns.RegisterFeature { id = 'welcome', label = L["Présentation de la 1.0"], desc = L["La présentation au premier démarrage et ses boutons de réouverture."], default = true }
ns.RegisterFeature { id = 'welcomeMotion', label = L["Animations de la présentation"], desc = L["Désactivé : la présentation apparaît immédiatement, sans mouvement."], default = true }

W.classics = L["Et aussi : conditions en boutons, simulateur, mes macros, mes modèles, envoi à un joueur, annuler/rétablir, texte libre, sélecteur d’icône, tutoriel, traduction des sorts, français/anglais, fonctions désactivables."]
W.tiles = {
  { feature = 'assistant', title = L["Assistant"], icon = 'INV_Misc_Note_01', new = true,
    line = L["Une recette. Ta macro."], detail = L["Choisis un sort et une recette : survol, focus, familier, bijoux…"], run = function() ns.OpenAssistant() end },
  { feature = 'grimoire', title = L["Mon grimoire"], icon = 'INV_Misc_Book_09', new = true,
    line = L["Tes sorts, en un clic."], detail = L["Sorts, techniques du familier et objets utilisables : clique pour les ajouter."], run = function() ns.Open('editor') ns.ToggleGrimoire() end },
  { feature = 'bars', title = L["Améliorer ma barre"], icon = 'INV_Misc_Key_04', new = true,
    line = L["Même place. Plus de choix."], detail = L["Transforme un sort de ta barre en macro, sans déplacer ton bouton."], run = function() ns.OpenWand() end },
  { feature = 'health', title = L["Bilan de santé"], icon = 'Spell_Holy_Heal', new = true,
    line = L["Repère ce qui cloche."], detail = L["Macros cassées, doublons, orphelines : contrôle tout, puis choisis quoi réparer."], run = function() ns.OpenHealth() end },
  { feature = 'living', title = L["Macros vivantes"], icon = 'INV_Potion_54', new = true,
    line = L["Tes sacs changent ? Elles suivent."], detail = L["Potions, bijoux et équipement se mettent à jour hors combat, avec un journal."], run = function() ns.OpenLiving() end },
  { feature = 'kits', title = L["Kits de personnage"], icon = 'INV_Misc_Bag_08', new = true,
    line = L["Ta classe, prête à jouer."], detail = L["Choisis ton rôle, coche tes macros, installe ton kit avec sauvegarde et annulation."], run = function() ns.OpenKits() end },
  { feature = 'profiles', title = L["Profils"], icon = 'INV_Misc_Gear_01', new = true,
    line = L["Change de spé, garde tes repères."], detail = L["Garde tes macros, tes touches et tes barres ; vois les changements avant activation."], run = function() ns.OpenProfiles() end },
  { feature = 'explain', title = L["Expliquer"], icon = 'INV_Letter_15', new = true,
    line = L["Lis ta macro en clair."], detail = L["Chaque ligne expliquée, avec ses conditions et ses alternatives."], run = function() ns.Open('editor') ns.ed.explainMode = true ns.ed.OnRefresh(ns.EditorText()) end },
  { feature = 'shorten', title = L["Raccourcir"], icon = 'Trade_Engineering', new = true,
    line = L["Gagne des caractères."], detail = L["Vois chaque réduction sûre et le total gagné. Un clic applique, Annuler revient en arrière."], run = function() ns.OpenShorten() end },
  { feature = 'home', title = L["Accueil"], icon = 'INV_Misc_Book_09', new = true,
    line = L["Choisis ta prochaine action."], detail = L["Tes outils, ton bilan et les macros utiles à ton personnage au même endroit."], run = function() ns.Open('home') end },
  { title = L["Éditeur par blocs"], icon = 'Trade_Engineering',
    line = L["Assemble. C’est une macro."], detail = L["Sorts, objets, familier, cibles : compose ta macro sans retenir la syntaxe."], run = function() ns.Open('editor') end },
  { title = L["Bibliothèque"], icon = 'INV_Misc_Book_09',
    line = L["274 macros. Neuf classes."], detail = L["Recherche, favoris, catégories et sorts traduits dans la langue du jeu."], run = function() ns.Open('library') end },
}

function W.Mark()
  if ns.db then ns.db.welcomeSeen, ns.db.tutorialSeen = W.version, true end
end

function W.Finish()
  W.epoch = (W.epoch or 0) + 1
  for _, entry in ipairs(W.groups) do
    if entry.group.Stop then entry.group:Stop() end
    entry.frame:SetAlpha(entry.alpha or 1)
  end
  W.groups = {}
  if W.panel then
    W.panel:SetAlpha(1)
    W.panel:SetScript('OnUpdate', nil)
    W.panel.line:SetWidth(714)
    W.panel.demoText:SetText(ns.Code(W.demoText))
    if W.panel.halo then W.panel.halo:SetAlpha(0) end
  end
end

-- Alpha reel fixe au depart et a l'arrivee : les animations ne le modifient pas elles-memes.
local function Animate(frame, delay, distance, duration, from, to, done, vertical)
  if not ns.Enabled('welcomeMotion') or not frame.CreateAnimationGroup then frame:SetAlpha(to or 1) if done then done() end return end
  frame.welcomeAnimations = frame.welcomeAnimations or {}
  local key = distance and distance ~= 0 and 'move' or 'fade'
  local cached = frame.welcomeAnimations[key]
  local ok, group = pcall(function()
    if cached then
      if cached.group.Stop then cached.group:Stop() end
    else
      local g = frame:CreateAnimationGroup()
      if not (g and g.CreateAnimation and g.SetScript and g.Play and g.Stop) then return end
      local a = g:CreateAnimation('Alpha')
      if not (a and a.SetFromAlpha and a.SetToAlpha and a.SetDuration and a.SetStartDelay) then return end
      cached = { group = g, alpha = a }
      if key == 'move' then
        local t = g:CreateAnimation('Translation')
        if not (t and t.SetOffset and t.SetDuration and t.SetStartDelay) then return end
        cached.translation = t
      end
      frame.welcomeAnimations[key] = cached
    end
    local a = cached.alpha
    a:SetFromAlpha(from or 0) a:SetToAlpha(to or 1) a:SetDuration(duration or 0.25) a:SetStartDelay(delay or 0)
    if cached.translation then
      local t = cached.translation
      t:SetOffset(vertical and 0 or distance, vertical and distance or 0)
      t:SetDuration(duration or 0.25) t:SetStartDelay(delay or 0)
    end
    return cached.group
  end)
  if not ok or not group then frame:SetAlpha(to or 1) if done then done() end return end
  for i = #W.groups, 1, -1 do if W.groups[i].group == group then table.remove(W.groups, i) end end
  frame:SetAlpha(from or 0)
  local entry = { group = group, frame = frame, alpha = to or 1 }
  W.groups[#W.groups + 1] = entry
  group:SetScript('OnFinished', function()
    for i, candidate in ipairs(W.groups) do if candidate == entry then table.remove(W.groups, i) break end end
    frame:SetAlpha(to or 1)
    if done then done() end
  end)
  group:Play()
  return true
end

local function Pulse(frame, count, low, duration)
  if not ns.Enabled('welcomeMotion') then return end
  local epoch = W.epoch
  local function step(left)
    if epoch ~= W.epoch or left == 0 or not W.panel:IsShown() then return end
    Animate(frame, 0, 0, duration, 1, low, function()
      if epoch ~= W.epoch then return end
      Animate(frame, 0, 0, duration, low, 1, function() if epoch == W.epoch then step(left - 1) end end)
    end)
  end
  -- Trois battements au plus, meme si l'API ne peut pas les jouer.
  step(count)
end

local function Halo(frame)
  if not ns.Enabled('welcomeMotion') or not frame.CreateAnimationGroup then return end
  local ok, group = pcall(function()
    if frame.welcomeHalo then return frame.welcomeHalo end
    local g = frame:CreateAnimationGroup()
    if not (g and g.CreateAnimation and g.SetLooping and g.Play and g.Stop) then return end
    for i = 1, 2 do
      local a = g:CreateAnimation('Alpha')
      if not (a and a.SetOrder and a.SetFromAlpha and a.SetToAlpha and a.SetDuration) then return end
      a:SetOrder(i) a:SetDuration(0.8) a:SetFromAlpha(i == 1 and 0 or 1) a:SetToAlpha(i == 1 and 1 or 0)
    end
    g:SetLooping('REPEAT')
    frame.welcomeHalo = g
    return g
  end)
  if ok and group then
    frame:SetAlpha(0)
    W.groups[#W.groups + 1] = { group = group, frame = frame, alpha = 0 }
    group:Play()
  end
end

function W.Place()
  if not W.panel or not ns.db then return end
  local main = ns.ed and ns.ed.w.main
  local fit = math.min((UIParent:GetWidth() or 0) / 900, (UIParent:GetHeight() or 0) / 640)
  W.panel:SetScale(fit > 0 and math.min(ns.db.scale, fit) or ns.db.scale)
  W.panel:ClearAllPoints()
  if main and main:IsShown() then
    W.panel:SetPoint('CENTER', main, 'CENTER')
    if not W.veil then
      W.veil = CreateFrame('Frame', nil, main)
      W.veil:SetAllPoints() W.veil:SetFrameStrata('DIALOG') W.veil:EnableMouse(true)
      local shade = W.veil:CreateTexture(nil, 'BACKGROUND')
      shade:SetAllPoints() shade:SetColorTexture(0, 0, 0, 0.6)
    end
    W.veil:Show()
    if W.veil.GetFrameLevel and W.panel.SetFrameLevel then W.panel:SetFrameLevel((W.veil:GetFrameLevel() or 0) + 1) end
  else
    W.panel:SetPoint('CENTER')
    if W.veil then W.veil:Hide() end
  end
end

function W.Close(action)
  W.Mark()
  W.Finish()
  if not W.panel then return end
  Animate(W.panel, 0, 0, 0.15, 1, 0, function()
    W.panel:Hide()
    if W.veil then W.veil:Hide() end
    W.panel:SetAlpha(1)
    if action then action() end
  end)
end

function W.Activate(i)
  local tile = W.tiles[i]
  if not tile then return end
  W.Mark() W.Finish()
  if tile.feature and not ns.Enabled(tile.feature) then
    W.panel.detail:SetText(L["« %s » est désactivé dans les Paramètres."]:format(tile.title))
    ns.Off(tile.feature)
    return
  end
  W.Close(tile.run)
end

function W.CheckIcon(texture, icon)
  local path = 'Interface\\Icons\\' .. icon
  texture:SetTexture(path)
  local known, valid = false, true
  if GetFileIDFromPath then
    local ok, id = pcall(GetFileIDFromPath, path)
    if ok then known, valid = true, id ~= nil and id ~= 0 end
  elseif texture.GetTexture then
    local ok, value = pcall(texture.GetTexture, texture)
    if ok then known, valid = true, value ~= nil and value ~= false end
  end
  W.icons[icon] = not known and 'unknown' or valid and 'ok' or 'fallback'
  if known and not valid then texture:SetTexture('Interface\\Icons\\INV_Misc_QuestionMark') end
end

local function BuildTile(p, spec, i)
  local ui = ns.ui
  local tile = ui.Chip(p, 160, 66)
  tile:SetPoint('TOPLEFT', 22 + ((i - 1) % 4) * 172, -114 - math.floor((i - 1) / 4) * 70)
  tile.text:ClearAllPoints()
  tile.text:SetPoint('TOPLEFT', 30, -16)
  tile.text:SetSize(124, 16)
  tile.text:SetText(spec.title)
  tile.icon = tile:CreateTexture(nil, 'ARTWORK')
  tile.icon:SetPoint('TOPLEFT', 8, -15) tile.icon:SetSize(18, 18)
  W.CheckIcon(tile.icon, spec.icon)
  tile.desc = ui.Label(tile, spec.line, 10, -34, 'GameFontHighlightSmall')
  tile.desc:SetSize(140, 28) tile.desc:SetJustifyV('TOP')
  if spec.new then
    tile.badge = ui.Label(tile, L["NOUVEAU"], 98, -3, 'GameFontDisableSmall')
    tile.badge:SetSize(56, 11) T.AccentText(tile.badge)
  end
  tile:SetScript('OnMouseDown', function() W.Mark() W.Finish() end)
  tile:SetScript('OnClick', function() W.Activate(i) end)
  tile:SetScript('OnEnter', function()
    local enabled = not spec.feature or ns.Enabled(spec.feature)
    ui.Tint(tile, enabled and T.accent or T.grey, 0.95)
    tile.icon:SetSize(20, 20)
    p.detail:SetText(enabled and spec.detail or L["« %s » est désactivé dans les Paramètres."]:format(spec.title))
    Animate(p.detail, 0, 0, 0.12)
  end)
  tile:SetScript('OnLeave', function() tile.icon:SetSize(18, 18) ui.Tint(tile, T.grey, 0.65) end)
  return tile
end

local function Build()
  local ui = ns.ui
  local p = ui.Panel(UIParent, 720, 460)
  W.panel, p.tiles = p, {}
  _G.BlockForgeWelcome = p
  if UISpecialFrames then table.insert(UISpecialFrames, 'BlockForgeWelcome') end
  p:SetPoint('CENTER') p:SetFrameStrata('DIALOG') p:EnableMouse(true)
  p:SetScript('OnMouseDown', function() W.Mark() W.Finish() end)
  p:SetScript('OnHide', function() W.Finish() if W.veil then W.veil:Hide() end if not W.suspended then W.Mark() end end)
  local line = T.Accent(p:CreateTexture(nil, 'ARTWORK'))
  line:SetPoint('TOPLEFT', 3, -3) line:SetSize(714, 2)
  p.line = line
  p.close = ui.Button(p, 'x', 22, function() W.Close() end)
  p.close:SetPoint('TOPRIGHT', -7, -8) p.close:SetHeight(18)
  local icon = p:CreateTexture(nil, 'ARTWORK')
  icon:SetPoint('TOPLEFT', 22, -22) icon:SetSize(48, 48)
  W.CheckIcon(icon, 'INV_Misc_Book_09')
  p.titleText = T.AccentText(ui.Label(p, '', 82, -22, 'GameFontNormalLarge'))
  p.titleText:SetSize(342, 46) p.titleText:SetJustifyV('TOP')
  p.subtitle = ui.Label(p, '', 22, -76, 'GameFontHighlightSmall')
  p.subtitle:SetSize(402, 34) p.subtitle:SetJustifyV('TOP')
  p.demo = {}
  for i, text in ipairs({ L["Lancer un sort"], L["Survol"], L["Vivante"] }) do
    local chip = ui.Chip(p, 78, 22)
    chip:SetPoint('TOPLEFT', 440 + (i - 1) * 84, -26)
    chip.text:SetText(text) ui.Tint(chip, T.groups[i], 0.9)
    chip:SetScript('OnClick', function() W.Mark() W.Finish() end)
    p.demo[i] = chip
  end
  W.demoText = ns.Localize('/cast [@mouseover,harm,nodead][] Corruption', (C_Spell and C_Spell.GetSpellName) or GetSpellInfo, RANK)
  p.demoText = ui.Label(p, ns.Code(W.demoText), 440, -58, 'BlockForgeCodeFont')
  p.demoText:SetSize(252, 44)
  for i, spec in ipairs(W.tiles) do p.tiles[i] = BuildTile(p, spec, i) end
  local classics = ui.Label(p, W.classics, 22, -328, 'GameFontHighlightSmall')
  classics:SetSize(676, 44) classics:SetJustifyV('TOP')
  p.classics = classics
  p.detail = ui.Label(p, '', 22, -376, 'GameFontHighlightSmall')
  p.detail:SetSize(676, 26)
  p.tour = ui.Button(p, '', 240, function() W.Close(function() ns.Tutorial.Start(true, ns.welcomeUpgrading) end) end)
  p.tour:SetPoint('TOPLEFT', 22, -406) p.tour:SetHeight(28)
  ui.Tint(p.tour, T.accent, 0.9)
  p.halo = T.Accent(p.tour:CreateTexture(nil, 'OVERLAY'), 0.25)
  p.halo:SetAllPoints() p.halo:SetAlpha(0)
  if p.halo.SetBlendMode then p.halo:SetBlendMode('ADD') end
  p.tour:SetScript('OnEnter', function() W.Finish() end)
  p.assistant = ui.Button(p, L["Ouvrir l’assistant"], 200, function()
    W.Mark() W.Finish()
    if not ns.Off('assistant') then W.Close(function() ns.OpenAssistant() end) end
  end)
  p.assistant:SetPoint('TOPLEFT', 274, -406) p.assistant:SetHeight(28)
  p.later = ui.Button(p, L["Plus tard"], 212, function() W.Close() end)
  p.later:SetPoint('TOPLEFT', 486, -406) p.later:SetHeight(28)
  local footer = ui.Label(p, L["Pour revoir cet écran : /bf intro"], 22, -440, 'GameFontDisableSmall')
  footer:SetSize(676, 14)
  for _, button in ipairs({ p.close, p.tour, p.assistant, p.later }) do button:SetScript('OnMouseDown', function() W.Mark() W.Finish() end) end
end

function W.Show()
  if not ns.db or ns.Off('welcome') then return end
  if InCombatLockdown() then W.pending = true return end
  W.pending = false
  if ns.Tutorial then ns.Tutorial.Stop() end
  if not W.panel then Build() end
  local p = W.panel
  W.Finish()
  p.titleText:SetText(ns.welcomeUpgrading and L["BlockForge passe en 1.0."] or L["Tes macros. Sans une ligne de code."])
  p.subtitle:SetText(ns.welcomeUpgrading and L["Tes repères restent. Dix nouveautés pour créer, comprendre et faire vivre tes macros."] or L["Assemble des blocs, suis une recette ou pioche dans 274 macros prêtes."])
  p.tour:SetText(ns.welcomeUpgrading and L["Voir les nouveautés"] or L["Visite guidée (1 min)"])
  p.later:SetText(ns.welcomeUpgrading and L["Fermer"] or L["Plus tard"])
  p.detail:SetText(L["Survole une tuile pour le détail. Clique pour l’ouvrir."])
  p.tour:SetShown(ns.Enabled('tutorial'))
  p.assistant:SetShown(ns.Enabled('assistant'))
  W.Place()
  p:Show()
  local animated = Animate(p, 0, 16, 0.25, nil, nil, nil, true)
  Animate(p.line, 0.1, 0, 0.4)
  for i, chip in ipairs(p.demo) do Animate(chip, 0.3 + (i - 1) * 0.12, 12, 0.25) end
  Animate(p.demoText, 0.8, 0, 0.4)
  Halo(p.halo)
  if animated then
    local elapsed = 0
    p.line:SetWidth(1)
    p.demoText:SetText('')
    p:SetScript('OnUpdate', function(_, dt)
      elapsed = elapsed + dt
      p.line:SetWidth(math.max(1, 714 * math.min(1, math.max(0, (elapsed - 0.1) / 0.4))))
      local letters = math.floor(#W.demoText * math.min(1, math.max(0, (elapsed - 0.8) / 0.4)))
      -- Ne jamais couper un caractere UTF-8 ni une balise de couleur.
      while letters > 0 and letters < #W.demoText and W.demoText:byte(letters + 1) >= 128 and W.demoText:byte(letters + 1) < 192 do letters = letters - 1 end
      p.demoText:SetText(ns.Code(W.demoText:sub(1, letters)))
      if elapsed >= 1.2 then p:SetScript('OnUpdate', nil) end
    end)
  end
  for i, tile in ipairs(p.tiles) do
    local spec = W.tiles[i]
    local on = not spec.feature or ns.Enabled(spec.feature)
    tile.desc:SetText(on and spec.line or L["Désactivé dans Paramètres"])
    Animate(tile, 0.35 + (i - 1) * 0.035, 8, 0.2, 0, on and (ns.welcomeUpgrading and not spec.new and 0.7 or 1) or 0.4)
    if tile.badge then Pulse(tile.badge, 3, 0.5, 0.12) end
  end
end
ns.OpenWelcome = W.Show

local events = CreateFrame('Frame')
W.events = events
local function Ready()
  events:SetScript('OnUpdate', nil)
  if not ns.db or not ns.Enabled('welcome') then return end
  if InCombatLockdown() then W.pending = true return end
  if not ns.db.welcomeAnnounced then
    ns.db.welcomeAnnounced = true
    ns.Msg(L["BlockForge 1.0 est installé. /bf pour l’ouvrir, /bf intro pour la présentation."])
  end
  if W.pending or ns.db.welcomeSeen ~= W.version then W.Show() end
end
function W.Schedule()
  if not ns.db or not ns.Enabled('welcome') or (ns.db.welcomeSeen == W.version and ns.db.welcomeAnnounced) then return end
  W.elapsed = 0
  events:SetScript('OnUpdate', function(_, elapsed)
    W.elapsed = W.elapsed + elapsed
    if W.elapsed >= 3 then Ready() end
  end)
end
events:SetScript('OnEvent', function(_, event)
  if event == 'PLAYER_ENTERING_WORLD' then W.Schedule()
  elseif event == 'PLAYER_REGEN_ENABLED' then if W.pending then Ready() end
  elseif W.panel and W.panel:IsShown() then
    W.pending, W.suspended = ns.db.welcomeSeen ~= W.version, true
    W.panel:Hide() W.Finish() if W.veil then W.veil:Hide() end W.suspended = false
  end
end)
ns.OnFeatures(function()
  if not ns.db then return end
  local on = ns.Enabled('welcome')
  ns.Listen(events, on, 'PLAYER_ENTERING_WORLD', 'PLAYER_REGEN_ENABLED', 'PLAYER_REGEN_DISABLED')
  if not on then
    events:SetScript('OnUpdate', nil) W.pending = false W.Finish()
    if W.panel then W.panel:Hide() end
    if W.veil then W.veil:Hide() end
  elseif W.panel and W.panel:IsShown() then
    W.Finish()
    for i, tile in ipairs(W.panel.tiles) do
      local spec = W.tiles[i]
      local enabled = not spec.feature or ns.Enabled(spec.feature)
      tile:SetAlpha(enabled and 1 or 0.4)
      tile.desc:SetText(enabled and spec.line or L["Désactivé dans Paramètres"])
    end
    W.panel.tour:SetShown(ns.Enabled('tutorial')) W.panel.assistant:SetShown(ns.Enabled('assistant'))
  end
end)
