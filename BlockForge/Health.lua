-- BlockForge : bilan de sante des macros du jeu. Quatre groupes (ns.HealthCheck, Core.lua), et pour chaque macro :
-- ouvrir, reparer, archiver. Rien n'est supprime sans etre d'abord range dans « Mes modeles », ni sans confirmation.
-- Charge apres Bars.lua (annulation, lecture des barres) et Personal.lua.
local ADDON, ns = ...
local L = ns.L
local T = ns.Theme

local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local MAX_ROWS = 18

ns.HealthGroups = {
  { key = "broken", label = L["Cassées"], tip = L["Un sort que ton personnage ne connaît pas : souvent un nom mal écrit, parfois un objet ou un sort que tu n'as pas encore."] },
  { key = "duplicates", label = L["Doublons"], tip = L["Le même texte qu'une autre macro, aux espaces près."] },
  { key = "orphans", label = L["Orphelines"], tip = L["Sur aucune barre de ce personnage et liées à aucune touche. Une macro appelée par /click ou par un autre add-on, ou posée sur la barre d'un autre personnage, paraît orpheline : c'est pourquoi elles sont archivées, jamais supprimées sans copie."] },
  { key = "risky", label = L["À risque"], tip = L["Un avertissement de l'éditeur : trop longue, conditions contradictoires, familier juste après une monture…"] },
}

local Health = {}
ns.Health = Health

-- rapport de ns.HealthCheck, plus usage[nom] = emplacements et orphansKnown ; nil en combat
function Health.Report()
  if InCombatLockdown() then return nil end
  local macros = ns.ReadMacros()
  local scan, stats = ns.Bars.Scan()
  local usage, book = {}, nil
  for _, e in ipairs(scan or {}) do
    if e.macroName then
      usage[e.macroName] = usage[e.macroName] or {}
      table.insert(usage[e.macroName], e.slot)
    end
  end
  -- une seule macro de barre non identifiee et « orpheline » ne veut plus rien dire : le groupe reste vide
  local known = scan ~= nil and stats.unresolved == 0
  local report = ns.HealthCheck(macros, {
    unknown = function(body) return ns.UnknownSpells(ns.Parse(body or "")) end,
    nearest = function(name)
      book = book or ns.SpellBook()
      return ns.Nearest(name, book)
    end,
    orphans = known,
    used = function(m) return usage[m.name] ~= nil or GetBindingKey("MACRO " .. m.name) ~= nil end,
  })
  report.usage, report.orphansKnown = usage, known
  return report
end

function Health.Reason(group, item)
  if group == "broken" then
    if item.fix then return L["Sort inconnu : « %s ». Le plus proche dans ton grimoire : « %s »."]:format(ns.Plain(item.fix[1]), ns.Plain(item.fix[2])) end
    return L["« %s » n'est pas dans ton grimoire : peut-être cassée (ou un objet, un sort pas encore appris)."]:format(ns.Plain(item.maybe))
  elseif group == "duplicates" then
    return L["Même texte que « %s »."]:format(ns.Plain(item.of.name))
  elseif group == "orphans" then
    return L["Sur aucune barre et liée à aucune touche."]
  end
  return item.warning
end

-- remplace le nom inconnu par le nom proche ; l'ancien texte est garde pour « Annuler »
function Health.Repair(item)
  if ns.Off("health") then return end
  if InCombatLockdown() then return ns.Msg(L["Impossible de modifier une macro en combat."]) end
  local m = item.macro
  local index = item.fix and ns.Bars.FindExact(m.name, m.char, m.body)
  local body = index and ns.FixSpell(m.body, item.fix[1], item.fix[2])
  if not body or body == m.body or #body > ns.MAX_CHARS then
    return ns.Msg(L["Réparation impossible ici : ouvre la macro dans l'éditeur."])
  end
  EditMacro(index, m.name, nil, body)
  ns.SetUndo({ label = L["réparation de « %s »"]:format(m.name),
    ops = { { op = "edit", name = m.name, char = m.char and true or false, body = m.body } } })
  ns.Msg(L["Macro « %s » réparée : « %s » remplacé par « %s »."]:format(m.name, item.fix[1], item.fix[2]))
  return true
end

-- Archive puis supprime, apres confirmation. usage : emplacements de chaque macro, pour les lui rendre a l'annulation.
function Health.DoArchive(list, usage)
  if ns.Off("health") then return end
  if InCombatLockdown() then return ns.Msg(L["Impossible de modifier une macro en combat."]) end
  if not DeleteMacro then return ns.Msg(L["Ce client ne laisse pas BlockForge supprimer une macro."]) end
  local ops, done, kept = {}, 0, 0
  for _, m in ipairs(list) do
    local index = ns.Bars.FindExact(m.name, m.char, m.body) -- relu : les index changent a chaque suppression
    local stored = index and ns.ArchivePersonal(m.name, m.body, m.icon)
    local ok = false
    if stored then
      local account, char = GetNumMacros()
      DeleteMacro(index)
      local account2, char2 = GetNumMacros()
      ok = account2 + char2 == account + char - 1
    end
    if ok then
      done = done + 1
      ops[#ops + 1] = { op = "delete", name = m.name, char = m.char and true or false, body = m.body, icon = m.icon,
                        slots = usage and usage[m.name] or nil }
    else
      kept = kept + 1
    end
  end
  if #ops > 0 then ns.SetUndo({ label = L["archivage de %d macro(s)"]:format(done), ops = ops }) end
  ns.Msg(L["%d macro(s) archivée(s) dans « Mes modèles » puis supprimée(s), %d laissée(s). « Annuler » les recrée."]:format(done, kept))
  return done, kept
end

if StaticPopupDialogs then
  StaticPopupDialogs.BLOCKFORGE_ARCHIVE = {
    text = L["Archiver %d macro(s) dans « Mes modèles », puis les supprimer du jeu ?\nElles restent dans ta bibliothèque et « Annuler » les recrée. Une macro générale disparaît aussi des barres de tes autres personnages."],
    button1 = YES or L["Oui"], button2 = NO or L["Non"],
    OnAccept = function(_, data)
      Health.DoArchive(data.list, data.usage)
      if data.done then data.done() end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  }
end

-- jamais sans la confirmation, qui nomme le nombre de macros
function Health.Archive(list, usage, done)
  if ns.Off("health") then return end
  if InCombatLockdown() then return ns.Msg(L["Impossible de modifier une macro en combat."]) end
  if not DeleteMacro or not StaticPopup_Show then return ns.Msg(L["Ce client ne laisse pas BlockForge supprimer une macro."]) end
  if #list == 0 then return end
  StaticPopup_Show("BLOCKFORGE_ARCHIVE", #list, nil, { list = list, usage = usage, done = done })
end

---------------------------------------------------------------------------
-- Panneau
---------------------------------------------------------------------------
local panel
local state = { group = "broken", offset = 0 }

local function Items() return state.report and state.report[state.group] or {} end

local function Render()
  local ui, items = ns.ui, Items()
  for _, chip in ipairs(panel.chips) do
    local on = chip.group.key == state.group
    chip.text:SetText(L["%s : %d"]:format(chip.group.label, state.report and #state.report[chip.group.key] or 0))
    ui.Tint(chip, on and T.accent or T.grey, on and 0.95 or 0.6)
  end
  state.offset = math.max(0, math.min(state.offset, #items - MAX_ROWS))
  for i, row in ipairs(panel.rows) do
    local item = items[state.offset + i]
    row:SetShown(item ~= nil)
    if item then
      row.icon:SetTexture(item.macro.icon or QUESTION)
      row.text:SetText(ns.Plain(item.macro.name))
      row.reason:SetText(Health.Reason(state.group, item))
      ui.Tint(row, item.macro.char and T.accent or T.grey, item == state.current and 1 or 0.5)
      row.mark:SetShown(item == state.current)
    end
  end
  panel.range:SetText(#items > MAX_ROWS and L["%d-%d / %d  (molette)"]:format(state.offset + 1, math.min(state.offset + MAX_ROWS, #items), #items) or "")
  panel.empty:SetShown(#items == 0)
  panel.empty:SetText(state.group == "orphans" and state.report and not state.report.orphansKnown
    and L["BlockForge n'a pas pu lire toutes tes barres : impossible de dire quelles macros sont orphelines."]
    or L["Rien à signaler dans ce groupe."])

  local item = state.current
  local m = item and item.macro
  panel.name:SetText(m and ns.Plain(m.name) or L["Choisis une macro dans la liste."])
  local slots = m and state.report.usage[m.name]
  local key = m and GetBindingKey("MACRO " .. m.name)
  panel.info:SetText(m and ((m.char and L["Macro du personnage"] or L["Macro générale"]) .. "  ·  "
    .. (key and L["Raccourci : %s"]:format(key) or L["Aucun raccourci"]) .. "  ·  "
    .. (slots and L["Emplacements : %s"]:format(table.concat(slots, ", ")) or L["Sur aucune barre"])) or "")
  panel.reason:SetText(item and Health.Reason(state.group, item) or "")
  panel.body:SetText(m and ns.Code(m.body) or "")
  for _, b in ipairs({ panel.open, panel.archive }) do
    if m then b:Enable() else b:Disable() end
  end
  if item and item.fix then panel.repair:Enable() else panel.repair:Disable() end
  local orphans = state.report and #state.report.orphans or 0
  panel.bulk:SetText(L["Archiver les orphelines… (%d)"]:format(orphans))
  if orphans > 0 then panel.bulk:Enable() else panel.bulk:Disable() end
  local label = ns.UndoLabel()
  panel.undo:SetText(label and L["Annuler : %s"]:format(ns.Plain(label)) or L["Rien à annuler"])
  if label then panel.undo:Enable() else panel.undo:Disable() end
end

-- relit macros et barres ; la macro choisie le reste si elle est encore dans le groupe
local function Refresh()
  if InCombatLockdown() then return end
  local was = state.current and state.current.macro
  state.report, state.current = Health.Report(), nil
  for _, item in ipairs(Items()) do
    if was and item.macro.name == was.name and item.macro.char == was.char then state.current = item end
  end
  Render()
  if ns.RefreshHome then ns.RefreshHome() end
end

local function Build()
  local ui, page = ns.ui, ns.ed.w.home
  -- 884 x 566 : toute la page d'accueil. Groupes de -28 a -48 ; liste de 8 a 428, 18 lignes de 22 tous les 24 de -54 a -484 ;
  -- detail de 440 a 876 ; en bas, de -536 a -558 : archivage en masse a gauche, annulation a droite.
  panel = ui.Panel(page, 884, 566, L["Bilan de santé"])
  panel:SetPoint("TOPLEFT")
  panel:SetBackdropColor(T.panel[1], T.panel[2], T.panel[3], 1)
  panel:SetFrameStrata("DIALOG")
  panel:SetFrameLevel((page:GetFrameLevel() or 0) + 10)
  panel:EnableMouse(true) -- le fond arrete les clics
  panel:Hide()
  ns.CloseChip(panel)

  panel.chips = {}
  for i, group in ipairs(ns.HealthGroups) do
    local chip = ui.Chip(panel, 212, 20)
    chip:SetPoint("TOPLEFT", 8 + (i - 1) * 218, -28) -- le quatrieme finit a 874
    chip.group = group
    chip:SetScript("OnClick", function()
      state.group, state.offset, state.current = group.key, 0, nil
      Render()
    end)
    ui.Tip(chip, function() return group.label, group.tip end)
    panel.chips[i] = chip
  end

  panel.rows = {}
  for i = 1, MAX_ROWS do
    -- icone de 6 a 22, nom de 28 a 190, raison de 196 a 414
    local row = ui.Chip(panel, 420, 22)
    row:SetPoint("TOPLEFT", 8, -54 - (i - 1) * 24)
    row.mark = ui.SideBar(row, T.accent)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", 6, 0)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    row.text:ClearAllPoints()
    row.text:SetPoint("LEFT", 28, 0)
    row.text:SetWidth(162)
    row.reason = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.reason:SetPoint("LEFT", 196, 0)
    row.reason:SetWidth(218)
    row.reason:SetJustifyH("LEFT")
    row.reason:SetWordWrap(false)
    row:SetScript("OnClick", function()
      state.current = Items()[state.offset + i]
      panel.status:SetText("")
      Render()
    end)
    panel.rows[i] = row
  end
  panel:EnableMouseWheel(true)
  panel:SetScript("OnMouseWheel", function(_, delta)
    state.offset = state.offset - delta * 3
    Render()
  end)
  panel.empty = ui.Label(panel, "", 12, -60, "GameFontDisableSmall")
  panel.empty:SetWidth(410)
  panel.range = ui.Label(panel, "", 8, -490, "GameFontDisableSmall")

  -- Detail : nom a -54, onglet / touche / emplacements a -76, raison de -94 a -130, texte de -136 a -326, actions de -336 a -358
  panel.name = ui.Label(panel, "", 440, -54, "GameFontHighlightLarge")
  panel.name:SetWidth(436)
  panel.name:SetWordWrap(false)
  panel.info = ui.Label(panel, "", 440, -76, "GameFontHighlightSmall")
  panel.info:SetWidth(436)
  panel.info:SetWordWrap(false)
  panel.reason = ui.Label(panel, "", 440, -94, "GameFontNormalSmall")
  panel.reason:SetSize(436, 36)
  panel.reason:SetJustifyV("TOP")
  panel.body = ui.Label(panel, "", 440, -136, "BlockForgeCodeFont")
  panel.body:SetSize(436, 190)
  panel.body:SetJustifyV("TOP")
  panel.open = ui.Button(panel, L["Ouvrir"], 140, function()
    local m = state.current and state.current.macro
    if m and ns.ed.Load(m.name, m.body, m.icon) then ns.Open("editor") end
  end)
  panel.open:SetPoint("TOPLEFT", 440, -336)
  ui.Tip(panel.open, function() return L["Ouvrir"], L["Ouvre la macro en blocs dans l'éditeur."] end)
  panel.repair = ui.Button(panel, L["Réparer"], 140, function()
    if state.current and Health.Repair(state.current) then
      panel.status:SetText(L["Réparée. « Annuler », en bas, remet l'ancien texte."])
      Refresh()
    end
  end)
  panel.repair:SetPoint("TOPLEFT", 588, -336)
  ui.Tip(panel.repair, function() return L["Réparer"], L["Remplace le nom inconnu par le nom le plus proche de ton grimoire. Hors combat seulement."] end)
  panel.archive = ui.Button(panel, L["Archiver"], 140, function()
    local item = state.current
    if item then Health.Archive({ item.macro }, state.report.usage, Refresh) end
  end)
  panel.archive:SetPoint("TOPLEFT", 736, -336)
  ui.Tip(panel.archive, function()
    return L["Archiver"], L["Copie la macro dans « Mes modèles » (onglet Bibliothèque), puis la supprime du jeu, après confirmation. « Annuler » la recrée."]
  end)
  -- de -368 a -416 : ce qui vient de se passer
  panel.status = ui.Label(panel, "", 440, -368, "GameFontHighlightSmall")
  panel.status:SetWidth(436)

  panel.bulk = ui.Button(panel, "", 240, function()
    local list = {}
    for _, item in ipairs(state.report and state.report.orphans or {}) do list[#list + 1] = item.macro end
    Health.Archive(list, state.report and state.report.usage, Refresh)
  end)
  panel.bulk:SetPoint("BOTTOMLEFT", 8, 8)
  ui.Tip(panel.bulk, function()
    return L["Archiver les orphelines…"], L["Copie dans « Mes modèles » toutes les macros du groupe « Orphelines », puis les supprime du jeu. Une confirmation donne leur nombre ; « Annuler » les recrée toutes."]
  end)
  panel.undo = ui.Button(panel, "", 436, function()
    ns.RunUndo()
    panel.status:SetText("")
    Refresh()
  end)
  panel.undo:SetPoint("BOTTOMRIGHT", -8, 8)
  ui.Tip(panel.undo, function()
    return L["Annuler la dernière opération"], L["Recrée les macros archivées, ou remet l'ancien texte d'une macro réparée. Les copies restent dans « Mes modèles »."]
  end)

  panel:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then return self:Hide() end
    if self:IsVisible() then Refresh() end
  end)
  page:HookScript("OnHide", function() panel:Hide() end)
  panel.state, panel.Refresh = state, Refresh
  ns.health = panel
  ns.OnFeatures(function()
    local on = ns.Enabled("health")
    ns.Listen(panel, on, "UPDATE_MACROS", "PLAYER_REGEN_DISABLED")
    if not on then panel:Hide() end
  end, true)
  T.OnChange(Render)
end

-- group (facultatif) : "broken", "duplicates", "orphans" ou "risky"
function ns.OpenHealth(group)
  if ns.Off("health") then return end
  if InCombatLockdown() then return ns.Msg(L["Impossible de lire les macros en combat."]) end
  ns.Open("home")
  if ns.Tutorial then ns.Tutorial.Stop() end -- le panneau de la visite passerait dessous
  if not ns.ed.w.home then return end -- l'accueil n'a pas pu se construire
  if not panel then Build() end
  if ns.wand then ns.wand:Hide() end
  if ns.assistant then ns.assistant:Hide() end
  if group and state.group ~= group then state.group, state.offset, state.current = group, 0, nil end
  Refresh()
  panel:Show()
end
