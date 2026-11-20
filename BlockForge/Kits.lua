-- BlockForge : « Equiper mon personnage ». Trois choix, une liste de macros a cocher (ns.BuildKit, KitData.lua), puis
-- « Tout installer » : sauvegarde automatique, creation, une seule annulation. La pose sur une barre est une etape a part,
-- avec son apercu ; aucune touche n'est liee ici. Charge apres Bars.lua et Home.lua.
local ADDON, ns = ...
local L = ns.L
local T = ns.Theme

local MAX_ROWS, BAR_LINES = 20, 12

local Kits = {}
ns.KitsUI = Kits

-- API pas toutes verifiees en jeu : absente ou en erreur, l'appel rend nil
local function try(fn, ...)
  if not fn then return nil end
  local ok, a = pcall(fn, ...)
  if ok then return a end
end

local function Env()
  local getName, getItem = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo, C_Item and C_Item.GetItemNameByID
  return {
    localize = function(body) return ns.Localize(body, getName, RANK, getItem) end,
    unknown = function(body) return ns.UnknownSpells(ns.Parse(body)) end,
    spellName = function(english) return ns.SpellIDs[english] and try(getName, ns.SpellIDs[english]) end,
    desc = ns.LibraryDesc, enabled = ns.Enabled,
  }
end

-- choice : { role, hover, pet } ; les macros du kit pour la classe du personnage, nil si elle n'a pas de kit
function Kits.Build(choice)
  local _, class = UnitClass("player")
  return ns.BuildKit(class, choice.role, choice, ns.ReadMacros(), Env()), class
end

local function Installable(item) return not item.exists and not item.long end

-- Cree les macros de la liste. Refuse tout s'il n'y a pas la place ; sinon dit exactement ce qui a ete fait.
-- Renvoie les noms crees, nil si rien n'a ete touche.
function Kits.Install(items, choice)
  if ns.Off("kits") then return end
  if InCombatLockdown() then return ns.Msg(L["Impossible de modifier une macro en combat."]) end
  if #items == 0 then return end
  local numAccount, numChar = GetNumMacros()
  local maxAccount, maxChar = ns.MacroLimits()
  local freeAccount, freeChar = maxAccount - numAccount, maxChar - numChar
  if #items > freeAccount + freeChar then
    return ns.Msg(L["Pas assez de place : %d macros à créer, %d places libres (%d générales, %d du personnage). Rien n'a été créé."]:format(
      #items, freeAccount + freeChar, freeAccount, freeChar))
  end
  local backup = ns.Backup(L["kit"])
  local ops, created, spill, failed = {}, {}, 0, 0
  for _, item in ipairs(items) do
    local char = ns.db.perCharDefault and true or false
    local account, own = GetNumMacros()
    -- l'onglet prefere est plein : la macro va dans l'autre
    if (char and own >= maxChar) or (not char and account >= maxAccount) then char, spill = not char, spill + 1 end
    local taken = GetMacroIndexByName(item.name)
    local body = (not taken or taken == 0) and ns.LivingPrepare(item.name, item.body) -- jetons d'une recette vivante
    local index = body and CreateMacro(item.name, "INV_Misc_QuestionMark", body, char)
    if index and index ~= 0 then
      ns.LivingCommit(item.name)
      created[#created + 1] = item.name
      ops[#ops + 1] = { op = "created", name = item.name, char = char, body = body }
    else
      failed = failed + 1
    end
  end
  local record
  if #ops > 0 then
    record = { label = L["kit de %d macros"]:format(#created), ops = ops }
    ns.SetUndo(record)
  end
  -- kit retenu pour ce personnage, avec les macros qui attendent un sort pas encore appris
  if choice then
    local mem = { class = select(2, UnitClass("player")), role = choice.role, hover = choice.hover and true or false,
                  pet = choice.pet and true or false, waiting = {} }
    for _, item in ipairs(Kits.Build(choice) or {}) do
      if Installable(item) and #item.unknown > 0 then mem.waiting[item.name] = true end
    end
    ns.db.kits[ns.CharKey()] = mem
  end
  ns.Msg(L["Kit : %d macro(s) créée(s), %d non créée(s). « Annuler » les supprime."]:format(#created, failed))
  if spill > 0 then
    ns.Msg(L["%d macro(s) sont allées dans l'autre onglet de macros, faute de place dans celui que tu préfères."]:format(spill))
  end
  if backup then ns.Msg(L["Sauvegarde automatique « %s ». « Annuler » remet tout comme avant."]:format(backup)) end
  if Kits.Watch then Kits.Watch() end
  if ns.RefreshHome then ns.RefreshHome() end
  return created, record
end

-- macros du kit retenu dont tous les sorts sont maintenant connus, et qui ne sont pas encore creees
function Kits.Ready()
  local mem = ns.db and ns.db.kits[ns.CharKey()]
  if type(mem) ~= "table" or type(mem.waiting) ~= "table" or InCombatLockdown() or not ns.Enabled("kits") then return {} end
  local ready = {}
  for _, item in ipairs(ns.BuildKit(mem.class, mem.role, mem, ns.ReadMacros(), Env()) or {}) do
    if mem.waiting[item.name] and Installable(item) and #item.unknown == 0 then ready[#ready + 1] = item end
  end
  return ready
end

function Kits.InstallReady()
  local mem = ns.db.kits[ns.CharKey()]
  local ready = Kits.Ready()
  if #ready == 0 or not mem then return end
  return Kits.Install(ready, mem)
end

-- « Nouveau sort appris » : une ligne discrete sur l'accueil, et une seule ligne de discussion par session
local watcher, announced = CreateFrame("Frame"), false
local function Check()
  local ready = Kits.Ready()
  if Kits.HomeLine then Kits.HomeLine(ready) end
  if #ready > 0 and not announced then
    announced = true
    ns.Msg(L["%d macro(s) de ton kit sont maintenant disponibles : onglet Accueil de BlockForge pour les installer."]:format(#ready))
  end
end
watcher:SetScript("OnEvent", Check)

-- evenements inscrits seulement si la fonction est active et qu'un kit attend encore des sorts
function Kits.Watch()
  if not ns.db then return end
  local mem = ns.db.kits[ns.CharKey()]
  local on = ns.Enabled("kits") and type(mem) == "table" and type(mem.waiting) == "table" and next(mem.waiting) ~= nil
  ns.Listen(watcher, on, "SPELLS_CHANGED", "PLAYER_REGEN_ENABLED")
  if Kits.HomeLine then Kits.HomeLine(on and Kits.Ready() or {}) end
end
ns.OnFeatures(Kits.Watch)

---------------------------------------------------------------------------
-- Pose sur une barre : une rangee de 12, les emplacements vides seulement, sauf si le joueur coche « remplacer »
---------------------------------------------------------------------------
-- names : macros a poser, dans l'ordre ; first : premier emplacement de la rangee
function Kits.BarPlan(names, first, replace)
  local plan, i = {}, 1
  for slot = first, first + 11 do
    local now = names[i] and ns.Bars.Read(slot)
    if now and (now.kind == "empty" or (replace and (now.kind == "spell" or now.kind == "item" or now.kind == "macro"))) then
      plan[#plan + 1] = { slot = slot, macro = names[i], before = now }
      i = i + 1
    end
  end
  return plan, #names - (i - 1)
end

-- record : annulation du kit qui vient d'etre installe ; la pose s'y ajoute, pour qu'un seul « Annuler » defasse tout
function Kits.Place(plan, record)
  if ns.Off("kits") or ns.Off("bars") then return end
  if InCombatLockdown() then return ns.Msg(L["Impossible de modifier une macro en combat."]) end
  local ops, placed, failed = {}, 0, 0
  for _, p in ipairs(plan) do
    local index = GetMacroIndexByName(p.macro)
    if index and index > 0 and ns.Bars.Place(p.slot, index, p.macro, p.before, true) then
      placed = placed + 1
      ops[#ops + 1] = { op = "slot", slot = p.slot, before = ns.Bars.Content(p.before), macro = p.macro }
    else
      failed = failed + 1
    end
  end
  if #ops > 0 then
    if record and ns.db.undo == record then
      for _, op in ipairs(ops) do record.ops[#record.ops + 1] = op end
    else
      ns.SetUndo({ label = L["pose de %d macros sur une barre"]:format(placed), ops = ops })
    end
  end
  ns.Msg(L["%d macro(s) posée(s) sur ta barre, %d refusée(s) par le jeu. « Annuler » remet les emplacements comme avant."]:format(placed, failed))
  return placed, failed
end

---------------------------------------------------------------------------
-- Panneau
---------------------------------------------------------------------------
local panel
-- items : macros du kit affiche ; checked[nom] ; installed, record : derniere installation (pour la pose sur une barre)
local state = { choice = { role = "leveling", hover = true, pet = false }, items = {}, checked = {}, installed = {}, bars = false }

local function StateText(item)
  if item.long then return L["trop longue une fois traduite"], 0.5 end
  if item.exists == "same" then return L["tu l'as déjà"], 0.5 end
  if item.exists == "name" then return L["laissée : une autre macro porte ce nom"], 0.5 end
  if #item.unknown > 0 then return L["sort pas encore appris : %s"]:format(ns.Plain(item.unknown[1])), 0.6 end
  return L["utilisable maintenant"], 1
end

local function Chosen()
  local list = {}
  for _, item in ipairs(state.items) do
    if state.checked[item.name] and Installable(item) then list[#list + 1] = item end
  end
  return list
end

local function RenderBars()
  local ui = ns.ui
  local plan, left = {}, 0
  if state.first then plan, left = Kits.BarPlan(state.installed, state.first, state.replace) end
  state.barPlan = plan
  for _, chip in ipairs(panel.barRows) do
    local empty = 0
    for slot = chip.first, chip.first + 11 do
      local e = ns.Bars.Read(slot)
      if e and e.kind == "empty" then empty = empty + 1 end
    end
    chip.text:SetText(L["Emplacements %d à %d : %d vides"]:format(chip.first, chip.first + 11, empty))
    ui.Tint(chip, chip.first == state.first and T.accent or T.grey, chip.first == state.first and 0.95 or 0.6)
  end
  for i, line in ipairs(panel.barLines) do
    local p = plan[i]
    line:SetText(p and (p.before.kind == "empty" and L["Emplacement %d : macro « %s »"]:format(p.slot, ns.Plain(p.macro))
      or L["Emplacement %d : macro « %s », à la place de « %s »"]:format(p.slot, ns.Plain(p.macro), ns.Plain(p.before.macroName or p.before.name or "?"))) or "")
  end
  panel.barTitle:SetText(state.first and L["Aperçu : %d macro(s) à poser"]:format(#plan) or L["Choisis une rangée à gauche."])
  panel.barLeft:SetText(state.first and left > 0 and L["%d macro(s) ne tiennent pas dans cette rangée : elles restent dans tes macros."]:format(left) or "")
  ui.Tint(panel.replace, state.replace and T.accent or T.grey, state.replace and 0.95 or 0.6)
  panel.place:SetText(L["Poser (%d)"]:format(#plan))
  if #plan > 0 then panel.place:Enable() else panel.place:Disable() end
end

local function Render()
  if not panel or not panel:IsShown() then return end
  local ui, choice = ns.ui, state.choice
  for _, chip in ipairs(panel.chips) do
    local on = choice[chip.key] == chip.value
    ui.Tint(chip, on and T.accent or T.grey, on and 0.95 or 0.6)
  end
  panel.listView:SetShown(not state.bars)
  panel.barView:SetShown(state.bars)
  for i, row in ipairs(panel.rows) do
    local item = state.items[i]
    row:SetShown(item ~= nil)
    if item then
      local text, alpha = StateText(item)
      local on = state.checked[item.name] and Installable(item)
      row.text:SetText(ns.Plain(item.name))
      row.desc:SetText(item.desc or "")
      row.state:SetText(text)
      row.text:SetTextColor(alpha, alpha, alpha)
      row.check:SetColorTexture(on and T.accent[1] or 0.2, on and T.accent[2] or 0.2, on and T.accent[3] or 0.22, 1)
      ui.Tint(row, on and T.accent or T.grey, on and 0.6 or 0.4)
    end
  end
  panel.empty:SetShown(#state.items == 0)
  local n = #Chosen()
  local numAccount, numChar = GetNumMacros()
  local maxAccount, maxChar = ns.MacroLimits()
  local free = maxAccount - numAccount + maxChar - numChar
  panel.status:SetText(L["Macros à créer : %d · places libres : %d générales, %d du personnage"]:format(n, maxAccount - numAccount, maxChar - numChar))
  panel.status:SetTextColor(1, n <= free and 1 or 0.3, n <= free and 1 or 0.3)
  panel.install:SetText(L["Tout installer (%d)"]:format(n))
  if n > 0 and n <= free and not state.bars then panel.install:Enable() else panel.install:Disable() end
  local canBars = ns.Enabled("bars") and ns.Bars.Ready()
  panel.toBars:SetShown(canBars and true or false)
  if #state.installed > 0 and not state.bars then panel.toBars:Enable() else panel.toBars:Disable() end
  local label = ns.UndoLabel()
  panel.undo:SetText(label and L["Annuler : %s"]:format(ns.Plain(label)) or L["Rien à annuler"])
  if label then panel.undo:Enable() else panel.undo:Disable() end
  if state.bars then RenderBars() end
end

-- relit le kit pour les choix du moment ; keep : les cases gardent leur etat
local function Refresh(keep)
  if InCombatLockdown() then return end
  state.items = Kits.Build(state.choice) or {}
  if not keep then
    state.checked = {}
    for _, item in ipairs(state.items) do state.checked[item.name] = Installable(item) and #item.unknown == 0 end
  end
  Render()
end

local function Build()
  local ui, page = ns.ui, ns.ed.w.home
  local _, class = UnitClass("player")
  -- 884 x 566 : toute la page d'accueil. Choix sur deux lignes, a -28 et -52 ; 20 lignes de 20 tous les 22 de -80 a -518 ;
  -- comptes a -522 ; en bas, de -536 a -558 : annuler de 8 a 308, barre de 450 a 650, installer de 656 a 876.
  panel = ui.Panel(page, 884, 566, L["Équiper mon personnage"])
  panel:SetPoint("TOPLEFT")
  panel:SetBackdropColor(T.panel[1], T.panel[2], T.panel[3], 1)
  panel:SetFrameStrata("DIALOG")
  panel:SetFrameLevel((page:GetFrameLevel() or 0) + 10)
  panel:EnableMouse(true) -- le fond arrete les clics
  panel:Hide()
  ns.CloseChip(panel)

  panel.chips = {}
  local function Choice(key, value, label, x, y, w, tip)
    local chip = ui.Chip(panel, w, 18)
    chip:SetPoint("TOPLEFT", x, y)
    chip.text:SetJustifyH("CENTER")
    chip.text:SetText(label)
    chip.key, chip.value = key, value
    chip:SetScript("OnClick", function()
      state.choice[key], state.bars = value, false
      Refresh()
    end)
    if tip then ui.Tip(chip, function() return label, tip end) end
    panel.chips[#panel.chips + 1] = chip
  end
  ui.Label(panel, L["Rôle"], 8, -32, "GameFontNormalSmall")
  for i, role in ipairs(ns.KitRoles) do Choice("role", role.id, role.label, 90 + (i - 1) * 156, -28, 150) end
  ui.Label(panel, L["Visée"], 8, -56, "GameFontNormalSmall")
  Choice("hover", true, L["Au survol"], 90, -52, 150, L["Les sorts partent sur l'unité sous ta souris, sinon sur ta cible."])
  Choice("hover", false, L["Sur la cible"], 246, -52, 150, L["Les macros visent ta cible, sans survol. Celles qui ne serviraient plus à rien sont retirées du kit."])
  if ns.KitPetClasses[class] then
    ui.Label(panel, L["Familier"], 420, -56, "GameFontNormalSmall")
    Choice("pet", true, L["Avec"], 500, -52, 100)
    Choice("pet", false, L["Sans"], 606, -52, 100)
  end

  local listView = CreateFrame("Frame", nil, panel)
  listView:SetAllPoints()
  panel.listView = listView
  panel.rows = {}
  for i = 1, MAX_ROWS do
    -- case de 6 a 18, nom de 26 a 166, description de 172 a 612, etat de 618 a 862
    local row = ui.Chip(listView, 868, 20)
    row:SetPoint("TOPLEFT", 8, -80 - (i - 1) * 22)
    row.check = row:CreateTexture(nil, "ARTWORK")
    row.check:SetSize(12, 12)
    row.check:SetPoint("LEFT", 6, 0)
    row.text:ClearAllPoints()
    row.text:SetPoint("LEFT", 26, 0)
    row.text:SetWidth(140)
    row.desc = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.desc:SetPoint("LEFT", 172, 0)
    row.desc:SetWidth(440)
    row.desc:SetJustifyH("LEFT")
    row.desc:SetWordWrap(false)
    row.state = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.state:SetPoint("LEFT", 618, 0)
    row.state:SetWidth(244)
    row.state:SetJustifyH("LEFT")
    row.state:SetWordWrap(false)
    row:SetScript("OnClick", function()
      local item = state.items[i]
      if item and Installable(item) then
        state.checked[item.name] = not state.checked[item.name]
        Render()
      end
    end)
    ui.Tip(row, function()
      local item = state.items[i]
      if item then return ns.Plain(item.name), item.desc, ns.Plain(ns.TokenText(item.body)) end
    end)
    panel.rows[i] = row
  end
  panel.empty = ui.Label(listView, L["Aucun kit pour cette classe."], 12, -86, "GameFontDisableSmall")

  -- Pose sur une barre : rangees de 8 a 308 (13 au plus, de 20 tous les 22 depuis -100) ; a droite, de 320 a 876 :
  -- titre a -100, 12 lignes de -120 a -312, « remplacer » a -322, reste a -346, boutons de -370 a -392
  local barView = CreateFrame("Frame", nil, panel)
  barView:SetAllPoints()
  panel.barView = barView
  local intro = ui.Label(barView, L["Choisis une rangée de 12 emplacements : les macros que tu viens d'installer vont dans ses emplacements vides, dans l'ordre."], 8, -80, "GameFontHighlightSmall")
  intro:SetWidth(868)
  intro:SetWordWrap(false)
  panel.barRows = {}
  local slots = ns.Bars.Slots()
  for i = 1, #slots / 12 do
    local chip = ui.Chip(barView, 300, 20)
    chip:SetPoint("TOPLEFT", 8, -100 - (i - 1) * 22)
    chip.first = slots[(i - 1) * 12 + 1]
    chip:SetScript("OnClick", function()
      state.first = chip.first
      Render()
    end)
    panel.barRows[i] = chip
  end
  panel.barTitle = T.AccentText(ui.Label(barView, "", 320, -100, "GameFontNormal"))
  panel.barLines = {}
  for i = 1, BAR_LINES do
    local line = ui.Label(barView, "", 320, -120 - (i - 1) * 16, "GameFontHighlightSmall")
    line:SetWidth(556)
    line:SetWordWrap(false)
    panel.barLines[i] = line
  end
  panel.replace = ui.Chip(barView, 300, 18)
  panel.replace:SetPoint("TOPLEFT", 320, -322)
  panel.replace.text:SetText(L["Remplacer ce qui s'y trouve"])
  panel.replace:SetScript("OnClick", function()
    state.replace = not state.replace
    Render()
  end)
  ui.Tip(panel.replace, function()
    return L["Remplacer ce qui s'y trouve"], L["Décoché : seuls les emplacements vides reçoivent une macro. Coché : les sorts, objets et macros de la rangée sont remplacés ; « Annuler » les remet."]
  end)
  panel.barLeft = ui.Label(barView, "", 320, -346, "GameFontDisableSmall")
  panel.barLeft:SetWidth(556)
  panel.barLeft:SetWordWrap(false)
  panel.place = ui.Button(barView, "", 200, function()
    if not state.barPlan or #state.barPlan == 0 then return end
    if Kits.Place(state.barPlan, state.record) then
      state.bars, state.installed = false, {}
      Refresh(true)
    end
  end)
  panel.place:SetPoint("TOPLEFT", 320, -370)
  T.Watch(function() ui.Tint(panel.place, T.accent, 0.9) end)
  local back = ui.Button(barView, L["Retour au kit"], 150, function()
    state.bars = false
    Render()
  end)
  back:SetPoint("TOPLEFT", 526, -370)

  panel.status = ui.Label(panel, "", 8, -522, "GameFontHighlightSmall")
  panel.status:SetWidth(868)
  panel.status:SetWordWrap(false)
  panel.undo = ui.Button(panel, "", 300, function()
    ns.RunUndo()
    state.installed, state.bars = {}, false
    Refresh(true)
  end)
  panel.undo:SetPoint("BOTTOMLEFT", 8, 8)
  ui.Tip(panel.undo, function() return L["Annuler la dernière opération"], L["Supprime les macros que le kit vient de créer et remet tes emplacements de barre comme avant."] end)
  panel.toBars = ui.Button(panel, L["Poser sur une barre…"], 200, function()
    state.bars, state.first, state.replace = true, nil, false
    Render()
  end)
  panel.toBars:SetPoint("BOTTOMLEFT", 450, 8)
  ui.Tip(panel.toBars, function()
    return L["Poser sur une barre…"], L["Étape facultative, après l'installation : tu choisis une rangée et tu vois ce qui sera posé avant de confirmer. Aucune touche n'est liée : pour cela, « Raccourci… » dans « Mes macros »."]
  end)
  panel.install = ui.Button(panel, "", 220, function()
    local created, record = Kits.Install(Chosen(), state.choice)
    if created then
      state.installed, state.record = created, record
      Refresh()
    end
  end)
  panel.install:SetPoint("BOTTOMRIGHT", -8, 8)
  T.Watch(function() ui.Tint(panel.install, T.accent, 0.9) end)
  ui.Tip(panel.install, function()
    return L["Tout installer"], L["Crée les macros cochées, après une sauvegarde automatique de toutes tes macros. Une macro qui existe déjà n'est jamais écrasée. Hors combat seulement."]
  end)

  panel:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then return self:Hide() end
    if self:IsVisible() then Refresh(true) end
  end)
  page:HookScript("OnHide", function() panel:Hide() end)
  panel.state = state
  ns.kitsPanel = panel
  ns.OnFeatures(function()
    local on = ns.Enabled("kits")
    ns.Listen(panel, on, "UPDATE_MACROS", "SPELLS_CHANGED", "PLAYER_REGEN_DISABLED")
    if not on then panel:Hide() else Render() end
  end, true)
  T.OnChange(Render)
end

function ns.OpenKits()
  if ns.Off("kits") then return end
  if InCombatLockdown() then return ns.Msg(L["Impossible de modifier une macro en combat."]) end
  ns.Open("home")
  if ns.Tutorial then ns.Tutorial.Stop() end -- le panneau de la visite passerait dessous
  if not ns.ed.w.home then return end -- l'accueil n'a pas pu se construire
  local mem = ns.db.kits[ns.CharKey()]
  if not panel then
    -- au premier affichage : le kit deja choisi par ce personnage, sinon le familier s'il est sorti
    if type(mem) == "table" then
      state.choice = { role = mem.role, hover = mem.hover and true or false, pet = mem.pet and true or false }
    else
      state.choice.pet = ns.HasPet() and ns.KitPetClasses[select(2, UnitClass("player"))] or false
    end
    Build()
  end
  ns.HidePanels()
  state.bars = false
  panel:Show()
  Refresh()
end

table.insert(ns.HomeActions, { id = "kits", feature = "kits", title = L["Équiper mon personnage"],
  desc = L["Un kit de macros pour ta classe et ton rôle, installé d'un coup."],
  run = function() ns.OpenKits() end })

-- Accueil : « N macros de ton kit sont maintenant disponibles », dans le bandeau, de 640 a 876, de -50 a -68
table.insert(ns.HomeBuilders, function(top, page)
  local ui = ns.ui
  local chip = ui.Chip(top, 236, 18)
  chip:SetPoint("TOPLEFT", 640, -50)
  chip:Hide()
  local ready = {}
  chip:SetScript("OnClick", function()
    if InCombatLockdown() then return ns.Msg(L["Impossible de modifier une macro en combat."]) end
    Kits.InstallReady()
  end)
  ui.Tip(chip, function()
    local names = {}
    for i, item in ipairs(ready) do names[i] = ns.Plain(item.name) end
    return L["Nouveaux sorts appris"], L["Ces macros de ton kit attendaient un sort que tu connais maintenant. Clic : les créer (sauvegarde automatique, « Annuler » possible)."],
      table.concat(names, ", ")
  end)
  function Kits.HomeLine(list)
    ready = list
    chip:SetShown(#ready > 0 and ns.Enabled("kits"))
    chip.text:SetText(L["Kit : %d macro(s) disponibles — installer"]:format(#ready))
    ui.Tint(chip, T.accent, 0.8)
  end
  page:HookScript("OnShow", function() Kits.HomeLine(Kits.Ready()) end)
  Kits.HomeLine(Kits.Ready())
end)
