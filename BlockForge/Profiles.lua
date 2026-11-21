-- BlockForge : profils. Un profil = des macros, et au choix les touches qui y menent et leur place sur les barres.
-- Les anciennes sauvegardes (BlockForgeDB.sets) y sont copiees ; les sauvegardes automatiques d'avant chaque operation
-- de masse y vivent aussi. Activer passe toujours par un apercu, une sauvegarde automatique et une annulation globale.
-- Charge apres Bars.lua, Personal.lua et Home.lua.
local ADDON, ns = ...
local L = ns.L
local T = ns.Theme

local MAX_AUTO, MAX_ROWS, MAX_LINES = 5, 18, 22

local Profiles = {}
ns.Profiles = Profiles

-- API pas toutes verifiees en jeu : absente ou en erreur, l'appel rend nil
local function try(fn, ...)
  if not fn then return nil end
  local ok, a, b = pcall(fn, ...)
  if ok then return a, b end
end


-- groupe de talents actif (double specialisation), nil si le client ne le donne pas
function Profiles.ActiveSpec()
  local group = try(C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup) or try(GetActiveSpecGroup)
  return type(group) == "number" and group or nil
end

-- compression du client, seulement si toutes ses pieces sont la ; ns.ExportProfile verifie l'aller-retour avant de s'en servir
function Profiles.Codec()
  local E, method = C_EncodingUtil, Enum and Enum.CompressionMethod and Enum.CompressionMethod.Deflate
  if not (E and E.CompressString and E.DecompressString and E.EncodeBase64 and E.DecodeBase64 and method) then return nil end
  return { pack = function(text) return E.EncodeBase64(E.CompressString(text, method)) end,
           unpack = function(text) return E.DecompressString(E.DecodeBase64(text), method) end }
end

-- profils illisibles retires ; anciennes sauvegardes copiees une seule fois (elles restent sous leur ancienne cle)
local function Migrate()
  local db = ns.db
  for name, p in pairs(db.profiles) do
    if type(name) ~= "string" or type(p) ~= "table" or type(p.macros) ~= "table" then db.profiles[name] = nil end
  end
  for name, set in pairs(db.sets) do
    if type(name) == "string" and type(set) == "table" and not set.migrated then
      local target, n, macros = name, 1, {}
      while db.profiles[target] do
        n = n + 1
        target = name .. " (" .. n .. ")"
      end
      for _, m in ipairs(set) do
        if type(m) == "table" and type(m.name) == "string" and type(m.body) == "string" then
          macros[#macros + 1] = { name = m.name, icon = m.icon, body = m.body, char = m.char and true or false }
        end
      end
      db.profiles[target] = { macros = macros }
      set.migrated = true
    end
  end
end

local function Changed()
  if Profiles.Render then Profiles.Render() end
  if ns.RefreshSets then ns.RefreshSets() end
end

-- opts.keys : aussi les touches liees a ces macros ; opts.bars : aussi les emplacements de barre qui les portent
function Profiles.Capture(opts)
  local _, class = UnitClass("player")
  local p = { macros = {}, owner = ns.CharKey(), class = class }
  for i, m in ipairs(ns.ReadMacros()) do
    p.macros[i] = { name = m.name, icon = m.icon, body = m.body, char = m.char and true or false }
    local keys = opts and opts.keys and { GetBindingKey("MACRO " .. m.name) } or {}
    if #keys > 0 then
      p.bindings = p.bindings or {}
      p.bindings[m.name] = keys
    end
  end
  local scan = opts and opts.bars and ns.Enabled("bars") and ns.Bars.Scan()
  for _, e in ipairs(scan or {}) do
    if e.macroName then
      p.bars = p.bars or {}
      p.bars[e.slot] = e.macroName
    end
  end
  return p
end

function Profiles.Save(name, opts)
  if InCombatLockdown() then return ns.Msg(L["Impossible de lire les macros en combat."]) end
  local replaced = ns.db.profiles[name] ~= nil
  local p = Profiles.Capture(opts)
  ns.db.profiles[name] = p
  ns.Msg((replaced and L["Sauvegarde « %s » remplacée (%d macros)."] or L["Sauvegarde « %s » enregistrée (%d macros)."]):format(name, #p.macros))
  Changed()
  return p
end

function Profiles.Delete(name)
  ns.db.profiles[name] = nil
  for _, byGroup in pairs(ns.db.specProfiles) do
    for group, profile in pairs(type(byGroup) == "table" and byGroup or {}) do
      if profile == name then byGroup[group] = nil end
    end
  end
  Changed()
end

-- Sauvegarde automatique de toutes les macros avant une operation de masse ; les MAX_AUTO dernieres sont gardees.
-- Ne depend pas de la fonction « Profils » : c'est un filet, pas une entree. Renvoie son nom, nil en combat.
function ns.Backup(tag)
  if InCombatLockdown() or not ns.db then return nil end
  local base = "Auto " .. date("%Y-%m-%d %H:%M:%S") .. " " .. tag
  local name, n = base, 1
  while ns.db.profiles[name] do
    n = n + 1
    name = base .. " " .. n
  end
  local p = Profiles.Capture({ keys = true })
  p.auto = true
  ns.db.profiles[name] = p
  local autos = {}
  for other, profile in pairs(ns.db.profiles) do
    if profile.auto then autos[#autos + 1] = other end
  end
  table.sort(autos)
  for i = 1, #autos - MAX_AUTO do ns.db.profiles[autos[i]] = nil end
  Changed()
  return name
end

-- profil d'un autre personnage ou importe : ses noms de sorts anglais passent dans la langue du client
local function Foreign(p) return p.imported or (p.owner ~= nil and p.owner ~= ns.CharKey()) end

-- plan d'activation (ns.ProfilePlan) ; nil en combat ou si le profil n'existe plus
function Profiles.Plan(name, opts)
  local p = ns.db.profiles[name]
  if not p or InCombatLockdown() then return nil end
  local source = { macros = p.macros, bindings = p.bindings, bars = p.bars }
  if Foreign(p) then
    source.macros = {}
    local getName, getItem = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo, C_Item and C_Item.GetItemNameByID
    for i, m in ipairs(p.macros) do
      source.macros[i] = type(m) == "table" and type(m.body) == "string"
        and { name = m.name, icon = m.icon, char = m.char, body = ns.Localize(m.body, getName, RANK, getItem) } or m
    end
  end
  local bars = opts.bars and ns.Enabled("bars") and ns.Bars.Ready()
  return ns.ProfilePlan(source, ns.ReadMacros(), { update = opts.update, remove = opts.remove, keys = opts.keys, bars = bars }, {
    binding = function(key) return GetBindingAction(key) end,
    slot = function(slot) return ns.Bars.Read(slot) end,
    unknown = function(body) return ns.UnknownSpells(ns.Parse(body)) end,
  })
end

-- Active le profil : sauvegarde automatique, macros, touches, barres, puis une seule annulation pour le tout.
-- Renvoie le compte de ce qui a ete fait, nil si rien n'a ete touche.
function Profiles.Apply(name, opts)
  if ns.Off("profiles") then return end
  if InCombatLockdown() then return ns.Msg(L["Impossible de modifier une macro en combat."]) end
  local plan = Profiles.Plan(name, opts)
  if not plan then return end
  local numAccount, numChar = GetNumMacros()
  local maxAccount, maxChar = ns.MacroLimits()
  local lackAccount = plan.need[false] - (maxAccount - numAccount + plan.freed[false])
  local lackChar = plan.need[true] - (maxChar - numChar + plan.freed[true])
  if lackAccount > 0 or lackChar > 0 then
    return ns.Msg(L["Pas assez de place pour ce profil : il manque %d place(s) dans les macros générales et %d dans celles du personnage. Rien n'a été changé."]:format(
      math.max(0, lackAccount), math.max(0, lackChar)))
  end
  if #plan.remove > 0 and not DeleteMacro then return ns.Msg(L["Ce client ne laisse pas BlockForge supprimer une macro."]) end
  local backup = ns.Backup(L["profil"])
  local ops, did = {}, { created = 0, updated = 0, removed = 0, binds = 0, slots = 0, failed = 0 }
  local function op(record) ops[#ops + 1] = record end

  -- 1. macros absentes du profil : archivees dans « Mes modeles », puis supprimees (les index changent a chaque suppression)
  local usage = {}
  for _, e in ipairs(#plan.remove > 0 and ns.Bars.Scan() or {}) do
    if e.macroName then
      usage[e.macroName] = usage[e.macroName] or {}
      table.insert(usage[e.macroName], e.slot)
    end
  end
  for _, m in ipairs(plan.remove) do
    local index = ns.Bars.FindExact(m.name, m.char, m.body)
    local stored = index and ns.ArchivePersonal(m.name, m.body, m.icon, L["Archivée à l'activation d'un profil."])
    local before = stored and GetNumMacros() + select(2, GetNumMacros())
    if stored then DeleteMacro(index) end
    if stored and GetNumMacros() + select(2, GetNumMacros()) == before - 1 then
      did.removed = did.removed + 1
      op({ op = "delete", name = m.name, char = m.char and true or false, body = m.body, icon = m.icon, slots = usage[m.name] })
    else
      did.failed = did.failed + 1
    end
  end
  -- 2. meme nom, texte different : reecrites (le joueur l'a coche et l'a vu dans l'apercu)
  for _, u in ipairs(plan.update) do
    local m = u.macro
    local index = ns.FindMacro(m.name, m.char and true or false)
    if index then
      EditMacro(index, m.name, m.icon, m.body)
      did.updated = did.updated + 1
      op({ op = "edit", name = m.name, char = m.char and true or false, body = u.old.body, icon = u.old.icon })
    else
      did.failed = did.failed + 1
    end
  end
  -- 3. creations
  for _, m in ipairs(plan.create) do
    local char = m.char and true or false
    local icon = (type(m.icon) == "string" or type(m.icon) == "number") and m.icon or "INV_Misc_QuestionMark"
    local index = CreateMacro(m.name, icon, m.body, char)
    if index and index ~= 0 then
      did.created = did.created + 1
      op({ op = "created", name = m.name, char = char, body = m.body })
    else
      did.failed = did.failed + 1
    end
  end
  -- 4. touches : l'ancienne action de chaque touche est gardee pour l'annulation ; une seule ecriture a la fin
  for _, b in ipairs(SetBindingMacro and plan.binds or {}) do
    SetBindingMacro(b.key, b.macro)
    if GetBindingAction(b.key) == "MACRO " .. b.macro then
      did.binds = did.binds + 1
      op({ op = "bind", key = b.key, macro = b.macro, before = b.replaces or "" })
    else
      did.failed = did.failed + 1
    end
  end
  if did.binds > 0 then SaveBindings(GetCurrentBindingSet()) end
  -- 5. barres
  -- shortcut: macro generale et macro du personnage de meme nom confondues ici, a departager si les profils melent les deux
  for _, s in ipairs(plan.slots) do
    local index = GetMacroIndexByName(s.macro)
    if index and index > 0 and ns.Bars.Place(s.slot, index, s.macro, s.before, true) then
      did.slots = did.slots + 1
      op({ op = "slot", slot = s.slot, before = ns.Bars.Content(s.before), macro = s.macro })
    else
      did.failed = did.failed + 1
    end
  end
  if #ops > 0 then ns.SetUndo({ label = L["profil « %s »"]:format(name), ops = ops }) end
  ns.Msg(L["Profil « %s » : %d macro(s) créée(s), %d mise(s) à jour, %d archivée(s) puis retirée(s), %d touche(s), %d emplacement(s) ; %d étape(s) refusée(s) par le jeu."]:format(
    name, did.created, did.updated, did.removed, did.binds, did.slots, did.failed))
  if backup then ns.Msg(L["Sauvegarde automatique « %s ». « Annuler » remet tout comme avant."]:format(backup)) end
  Changed()
  if ns.RefreshHome then ns.RefreshHome() end
  return did
end

---------------------------------------------------------------------------
-- Double specialisation : un profil propose (jamais applique) quand le groupe de talents change
---------------------------------------------------------------------------
local specFrame, lastGroup, pendingGroup = CreateFrame("Frame"), nil, nil

function Profiles.SpecProfile(group)
  local byGroup = ns.db.specProfiles[ns.CharKey()]
  local name = type(byGroup) == "table" and byGroup[group] or nil
  return name and ns.db.profiles[name] and name or nil
end

local function Propose()
  if InCombatLockdown() or not pendingGroup then return end
  local group, name = pendingGroup, Profiles.SpecProfile(pendingGroup)
  pendingGroup = nil
  if name and StaticPopup_Show then StaticPopup_Show("BLOCKFORGE_SPEC_PROFILE", group, ns.Plain(name), name) end
end

specFrame:SetScript("OnEvent", function(_, event)
  if event ~= "PLAYER_REGEN_ENABLED" then
    local group = Profiles.ActiveSpec()
    -- le premier releve (connexion) ne propose rien
    if group and lastGroup and group ~= lastGroup then pendingGroup = group end
    lastGroup = group or lastGroup
  end
  Propose()
end)

if StaticPopupDialogs then
  StaticPopupDialogs.BLOCKFORGE_SPEC_PROFILE = {
    text = L["Tu es passé sur ta spécialisation %d. Voir le profil « %s » pour l'activer ?"],
    button1 = YES or L["Oui"], button2 = NO or L["Non"],
    OnAccept = function(_, name) ns.OpenProfiles(name) end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  }
end

---------------------------------------------------------------------------
-- Panneau
---------------------------------------------------------------------------
local panel
-- others : profils des autres personnages ; chosen : profil affiche ; opts : parties a activer ; save : parties a enregistrer
local state = { others = false, offset = 0, lineOffset = 0, names = {}, lines = {},
                opts = { update = true, remove = false, keys = true, bars = true }, save = { keys = true, bars = true } }
local OPTION = {
  { key = "keys", x = 312, w = 100, label = L["Touches"], tip = L["Aussi les touches liées aux macros du profil. Une touche déjà prise est montrée dans l'aperçu avec ce qu'elle perd."] },
  { key = "bars", x = 418, w = 100, label = L["Barres"], tip = L["Aussi la place des macros du profil sur tes barres d'action. Demande la fonction « Améliorer ma barre »."] },
  { key = "update", x = 524, w = 300, label = L["Réécrire les macros de même nom"], tip = L["Une macro du jeu qui porte le nom d'une macro du profil, avec un autre texte, prend le texte du profil. Décoché : elle est laissée telle quelle."] },
  { key = "remove", x = 312, y = -92, w = 300, label = L["Retirer les macros absentes du profil"], tip = L["Les macros du jeu qui ne sont pas dans le profil sont archivées dans « Mes modèles », puis supprimées. Une macro générale disparaît aussi pour tes autres personnages."] },
}

local function ActionName(action) return ns.Plain(GetBindingName and GetBindingName(action) or action) end

local function Describe(e)
  if e.kind == "empty" then return L["vide"] end
  return ns.Plain(e.macroName or e.name or "?")
end

local function PlanLines(plan)
  local lines = {}
  local function add(text) lines[#lines + 1] = text end
  for _, m in ipairs(plan.create) do add(L["Créée : %s"]:format(ns.Plain(m.name))) end
  for _, u in ipairs(plan.update) do add(L["Réécrite : %s"]:format(ns.Plain(u.macro.name))) end
  for _, m in ipairs(plan.left) do add("|cff999999" .. L["Laissée (même nom, autre texte) : %s"]:format(ns.Plain(m.name)) .. "|r") end
  for _, m in ipairs(plan.remove) do add(L["Archivée puis retirée : %s"]:format(ns.Plain(m.name))) end
  for _, b in ipairs(plan.binds) do
    add(b.replaces and L["Touche %s : macro « %s », à la place de « %s »"]:format(b.key, ns.Plain(b.macro), ActionName(b.replaces))
      or L["Touche %s : macro « %s »"]:format(b.key, ns.Plain(b.macro)))
  end
  for _, s in ipairs(plan.slots) do
    add(L["Emplacement %d : macro « %s », à la place de « %s »"]:format(s.slot, ns.Plain(s.macro), Describe(s.before)))
  end
  for _, slot in ipairs(plan.blocked) do add("|cff999999" .. L["Emplacement %d : laissé (monture, familier, ensemble…)"]:format(slot) .. "|r") end
  return lines
end

local function Render()
  if not panel or not panel:IsShown() then return end
  local ui, db, me = ns.ui, ns.db, ns.CharKey()
  state.names = {}
  for name, p in pairs(db.profiles) do
    if ((p.owner ~= nil and p.owner ~= me) and true or false) == state.others then state.names[#state.names + 1] = name end
  end
  table.sort(state.names, function(a, b) return a > b end) -- dates recentes en haut
  if state.chosen and not db.profiles[state.chosen] then state.chosen = nil end
  state.offset = math.max(0, math.min(state.offset, #state.names - MAX_ROWS))
  for i, row in ipairs(panel.rows) do
    local name = state.names[state.offset + i]
    row:SetShown(name ~= nil)
    if name then
      local p = db.profiles[name]
      row.text:SetText(ns.Plain(name) .. "  |cff888888(" .. #p.macros .. ")" .. (state.others and ("  " .. ns.Plain(p.owner)) or "") .. "|r")
      ui.Tint(row, name == state.chosen and T.accent or T.grey, name == state.chosen and 0.95 or (p.auto and 0.35 or 0.6))
    end
  end
  panel.empty:SetShown(#state.names == 0)
  panel.empty:SetText(state.others and L["Aucun profil enregistré par un autre personnage de ce compte."] or L["Aucun profil : enregistres-en un ci-dessous."])
  ui.Tint(panel.mine, state.others and T.grey or T.accent, state.others and 0.6 or 0.95)
  ui.Tint(panel.foreign, state.others and T.accent or T.grey, state.others and 0.95 or 0.6)
  for _, chip in ipairs(panel.saveChips) do
    ui.Tint(chip, state.save[chip.key] and T.accent or T.grey, state.save[chip.key] and 0.95 or 0.6)
  end

  local p = state.chosen and db.profiles[state.chosen]
  local plan = p and Profiles.Plan(state.chosen, state.opts)
  state.plan = plan
  panel.name:SetText(p and ns.Plain(state.chosen) or L["Choisis un profil dans la liste."])
  panel.info:SetText(p and L["%d macros · touches : %s · barres : %s · %s"]:format(#p.macros, p.bindings and L["oui"] or L["non"],
    p.bars and L["oui"] or L["non"], p.owner and ns.Plain(p.owner) or L["origine inconnue"]) or "")
  local has = { keys = p and p.bindings ~= nil, bars = p and p.bars ~= nil and ns.Enabled("bars"), update = p ~= nil, remove = p ~= nil }
  for _, chip in ipairs(panel.options) do
    chip:SetShown(has[chip.key] and true or false)
    ui.Tint(chip, state.opts[chip.key] and T.accent or T.grey, state.opts[chip.key] and 0.95 or 0.6)
  end
  local spec, byGroup = ns.Enabled("specProfiles") and Profiles.ActiveSpec(), db.specProfiles[me]
  for group, chip in ipairs(panel.specs) do
    local on = type(byGroup) == "table" and state.chosen ~= nil and byGroup[group] == state.chosen
    chip:SetShown(p ~= nil and spec ~= nil and spec ~= false)
    ui.Tint(chip, on and T.accent or T.grey, on and 0.95 or 0.6)
  end
  state.lines = plan and PlanLines(plan) or {}
  state.lineOffset = math.max(0, math.min(state.lineOffset, #state.lines - MAX_LINES))
  for i, line in ipairs(panel.lines) do line:SetText(state.lines[state.lineOffset + i] or "") end
  panel.range:SetText(#state.lines > MAX_LINES and L["%d-%d / %d  (molette)"]:format(state.lineOffset + 1, state.lineOffset + MAX_LINES, #state.lines) or "")
  panel.summary:SetText(plan and L["À créer : %d · à réécrire : %d · laissées : %d · déjà identiques : %d · à retirer : %d · touches : %d · emplacements : %d"]:format(
    #plan.create, #plan.update, #plan.left, #plan.same, #plan.remove, #plan.binds, #plan.slots) or "")
  panel.warn:SetText(plan and plan.unknown > 0 and L["%d macro(s) de ce profil utilisent un sort que ce personnage ne connaît pas."]:format(plan.unknown) or "")
  local work = plan and (#plan.create + #plan.update + #plan.remove + #plan.binds + #plan.slots) or 0
  panel.activate:SetText(L["Activer (%d)"]:format(work))
  if work > 0 then panel.activate:Enable() else panel.activate:Disable() end
  for _, b in ipairs({ panel.delete, panel.export }) do
    if p then b:Enable() else b:Disable() end
  end
  local label = ns.UndoLabel()
  panel.undo:SetText(label and L["Annuler : %s"]:format(ns.Plain(label)) or L["Rien à annuler"])
  if label then panel.undo:Enable() else panel.undo:Disable() end
end
Profiles.Render = Render

local function Toggle(tbl, key)
  tbl[key] = not tbl[key]
  state.lineOffset = 0
  Render()
end

local function SaveClicked()
  if InCombatLockdown() then return ns.Msg(L["Impossible de lire les macros en combat."]) end
  local name = ns.trim((panel.saveName:GetText():gsub("[|%c]", "")))
  if name == "" then name = date("%Y-%m-%d") end
  local function save()
    if Profiles.Save(name, state.save) then
      state.others, state.chosen = false, name
      panel.saveName:SetText("")
      Render()
    end
  end
  if ns.db.profiles[name] == nil or not StaticPopup_Show then return save() end
  StaticPopup_Show("BLOCKFORGE_REPLACE_SET", name, nil, save)
end

local function ImportClicked()
  local p, err = ns.ImportProfile(panel.share:GetText(), Profiles.Codec())
  if not p then return ns.Msg(err) end
  local base = p.name ~= "" and p.name or L["Profil importé"]
  local name, n = base, 1
  while ns.db.profiles[name] do
    n = n + 1
    name = base .. " (" .. n .. ")"
  end
  ns.db.profiles[name] = { macros = p.macros, imported = true }
  state.others, state.chosen, state.lineOffset = false, name, 0
  panel.share:SetText("")
  panel.status:SetText(L["Profil importé : %d macros. Rien n'est créé tant que tu n'as pas cliqué « Activer »."]:format(#p.macros))
  Changed()
end

local function Build()
  local ui, page = ns.ui, ns.ed.w.macros
  -- 884 x 566 : toute la page « Mes macros ». Liste de 8 a 300 : filtres a -28, 18 lignes de 20 tous les 22 de -52 a -446,
  -- enregistrement de -456 a -526, suppression en bas. Detail de 312 a 876 : nom a -28, parties de -70 a -110,
  -- apercu de 22 lignes de -118 a -470, comptes a -476, alertes a -494, partage a -512, boutons de -536 a -558.
  panel = ui.Panel(page, 884, 566, L["Profils"])
  panel:SetPoint("TOPLEFT")
  panel:SetBackdropColor(T.panel[1], T.panel[2], T.panel[3], 1)
  panel:SetFrameStrata("DIALOG")
  panel:SetFrameLevel((page:GetFrameLevel() or 0) + 10)
  panel:EnableMouse(true) -- le fond arrete les clics
  panel:Hide()
  ns.CloseChip(panel)

  panel.mine = ui.Chip(panel, 140, 18)
  panel.mine:SetPoint("TOPLEFT", 8, -28)
  panel.mine.text:SetText(L["Mes profils"])
  panel.mine:SetScript("OnClick", function() state.others, state.offset = false, 0 Render() end)
  panel.foreign = ui.Chip(panel, 146, 18)
  panel.foreign:SetPoint("TOPLEFT", 154, -28)
  panel.foreign.text:SetText(L["Autres personnages"])
  panel.foreign:SetScript("OnClick", function() state.others, state.offset = true, 0 Render() end)
  ui.Tip(panel.foreign, function()
    return L["Copier depuis un autre personnage"], L["Les profils enregistrés par tes autres personnages. À l'activation, les noms de sorts passent dans la langue du jeu, et l'aperçu compte les macros dont ce personnage ne connaît pas un sort."]
  end)
  panel.rows = {}
  for i = 1, MAX_ROWS do
    local row = ui.Chip(panel, 292, 20)
    row:SetPoint("TOPLEFT", 8, -52 - (i - 1) * 22)
    row:SetScript("OnClick", function()
      state.chosen, state.lineOffset = state.names[state.offset + i], 0
      panel.status:SetText("")
      Render()
    end)
    panel.rows[i] = row
  end
  panel.empty = ui.Label(panel, "", 12, -58, "GameFontDisableSmall")
  panel.empty:SetWidth(284)
  local list = CreateFrame("Frame", nil, panel)
  list:SetPoint("TOPLEFT", 8, -52)
  list:SetSize(292, 394)
  list:EnableMouseWheel(true)
  list:SetScript("OnMouseWheel", function(_, delta) state.offset = state.offset - delta * 3 Render() end)

  -- nom de 14 a 294 a -456 ; parties a enregistrer de 8 a 148 et de 154 a 300 a -480 ; bouton de -504 a -526
  panel.saveName = ui.Edit(panel, 280, function() end)
  panel.saveName:SetPoint("TOPLEFT", 14, -456)
  panel.saveName:SetMaxLetters(40)
  local hint = ui.Label(panel.saveName, L["Nom (vide : date)"], 2, -4, "GameFontDisableSmall")
  panel.saveName:HookScript("OnTextChanged", function(self) hint:SetShown(self:GetText() == "") end)
  panel.saveChips = {}
  for i, spec in ipairs({ { "keys", L["Avec les touches"], 8, 140 }, { "bars", L["Avec les barres"], 154, 146 } }) do
    local chip = ui.Chip(panel, spec[4], 18)
    chip:SetPoint("TOPLEFT", spec[3], -480)
    chip.text:SetText(spec[2])
    chip.key = spec[1]
    chip:SetScript("OnClick", function() Toggle(state.save, spec[1]) end)
    ui.Tip(chip, function() return spec[2], L["Ce que le profil retient en plus des macros. Tu choisis de nouveau à l'activation."] end)
    panel.saveChips[i] = chip
  end
  local save = ui.Button(panel, L["Enregistrer mon profil"], 292, SaveClicked)
  save:SetPoint("TOPLEFT", 8, -504)
  T.Watch(function() ui.Tint(save, T.accent, 0.9) end)
  ui.Tip(save, function() return L["Enregistrer mon profil"], L["Copie toutes tes macros (générales et de ce personnage), avec leurs touches et leur place sur les barres si tu le veux."] end)
  panel.delete = ui.Button(panel, L["Supprimer"], 140, function()
    if state.chosen and StaticPopup_Show then StaticPopup_Show("BLOCKFORGE_DELETE_SET", state.chosen, nil, state.chosen) end
  end)
  panel.delete:SetPoint("BOTTOMLEFT", 8, 8)

  local split = panel:CreateTexture(nil, "ARTWORK")
  split:SetColorTexture(1, 1, 1, 0.12)
  split:SetPoint("TOPLEFT", 306, -28)
  split:SetSize(1, 530)
  panel.name = ui.Label(panel, "", 312, -28, "GameFontHighlightLarge")
  panel.name:SetWidth(530)
  panel.name:SetWordWrap(false)
  panel.info = ui.Label(panel, "", 312, -50, "GameFontHighlightSmall")
  panel.info:SetWidth(564)
  panel.info:SetWordWrap(false)
  panel.options = {}
  for i, option in ipairs(OPTION) do
    local chip = ui.Chip(panel, option.w, 18)
    chip:SetPoint("TOPLEFT", option.x, option.y or -70)
    chip.text:SetText(option.label)
    chip.key = option.key
    chip:SetScript("OnClick", function() Toggle(state.opts, option.key) end)
    ui.Tip(chip, function() return option.label, option.tip end)
    panel.options[i] = chip
  end
  -- association a une specialisation : de 624 a 704 et de 710 a 790, a -92
  panel.specs = {}
  for group = 1, 2 do
    local chip = ui.Chip(panel, 80, 18)
    chip:SetPoint("TOPLEFT", 624 + (group - 1) * 86, -92)
    chip.text:SetJustifyH("CENTER")
    chip.text:SetText(group == 1 and L["Spé 1"] or L["Spé 2"])
    chip:SetScript("OnClick", function()
      if not state.chosen then return end
      local me = ns.CharKey()
      local byGroup = type(ns.db.specProfiles[me]) == "table" and ns.db.specProfiles[me] or {}
      ns.db.specProfiles[me] = byGroup
      byGroup[group] = byGroup[group] ~= state.chosen and state.chosen or nil
      Render()
    end)
    ui.Tip(chip, function()
      return L["Profil de cette spécialisation"], L["Quand tu passes sur cette spécialisation, BlockForge te propose ce profil, hors combat. Rien n'est activé sans ton accord."]
    end)
    panel.specs[group] = chip
  end
  local preview = CreateFrame("Frame", nil, panel)
  preview:SetPoint("TOPLEFT", 312, -118)
  preview:SetSize(564, 352)
  preview:EnableMouseWheel(true)
  preview:SetScript("OnMouseWheel", function(_, delta) state.lineOffset = state.lineOffset - delta * 3 Render() end)
  panel.lines = {}
  for i = 1, MAX_LINES do
    local line = ui.Label(preview, "", 0, -(i - 1) * 16, "GameFontHighlightSmall")
    line:SetWidth(564)
    line:SetWordWrap(false)
    panel.lines[i] = line
  end
  panel.range = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  panel.range:SetPoint("TOPRIGHT", -34, -9)
  panel.summary = ui.Label(panel, "", 312, -476, "GameFontHighlightSmall")
  panel.summary:SetWidth(564)
  panel.summary:SetWordWrap(false)
  panel.warn = ui.Label(panel, "", 312, -494, "GameFontRedSmall")
  panel.warn:SetWidth(280)
  panel.warn:SetWordWrap(false)
  panel.status = ui.Label(panel, "", 596, -494, "GameFontHighlightSmall")
  panel.status:SetWidth(280)
  panel.status:SetWordWrap(false)

  -- partage : champ de 318 a 718 a -512, exporter de 726 a 798, importer de 804 a 876
  panel.share = ui.Edit(panel, 400, function() end)
  panel.share:SetPoint("TOPLEFT", 318, -512)
  panel.share:SetMaxLetters(0) -- 0 = sans limite : un profil entier fait plusieurs milliers de caracteres
  panel.export = ui.Button(panel, L["Exporter"], 72, function()
    local p = state.chosen and ns.db.profiles[state.chosen]
    if not p then return end
    panel.share:SetText(ns.ExportProfile(state.chosen, p.macros, Profiles.Codec()))
    panel.share:SetFocus()
    panel.share:HighlightText()
  end)
  panel.export:SetPoint("TOPLEFT", 726, -511)
  ui.Tip(panel.export, function() return L["Exporter"], L["Met les macros du profil (sans touches ni barres) dans le champ, en une ligne de texte « BF2: » : Ctrl+C pour la copier."] end)
  local import = ui.Button(panel, L["Importer"], 72, ImportClicked)
  import:SetPoint("TOPLEFT", 804, -511)
  ui.Tip(import, function() return L["Importer"], L["Colle (Ctrl+V) dans le champ un texte « BF2: », puis clique : le profil s'ajoute à la liste et son aperçu s'affiche. Rien n'est créé avant « Activer »."] end)

  -- annuler de 312 a 700, activer de 706 a 876
  panel.undo = ui.Button(panel, "", 388, function()
    ns.RunUndo()
    panel.status:SetText("")
    Render()
  end)
  panel.undo:SetPoint("BOTTOMLEFT", 312, 8)
  ui.Tip(panel.undo, function() return L["Annuler la dernière opération"], L["Défait d'un coup tout ce que la dernière activation a changé : macros, touches et emplacements."] end)
  panel.activate = ui.Button(panel, "", 170, function()
    local name = state.chosen
    local did = name and Profiles.Apply(name, state.opts)
    if did then panel.status:SetText(L["Profil activé. « Annuler » remet tout comme avant."]) end
    Render()
  end)
  panel.activate:SetPoint("BOTTOMRIGHT", -8, 8)
  T.Watch(function() ui.Tint(panel.activate, T.accent, 0.9) end)
  ui.Tip(panel.activate, function()
    return L["Activer"], L["Fait ce que l'aperçu annonce, après une sauvegarde automatique de toutes tes macros. Hors combat seulement."]
  end)

  panel:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then return self:Hide() end
    if self:IsVisible() then Render() end
  end)
  page:HookScript("OnHide", function() panel:Hide() end)
  panel.state = state
  ns.profilesPanel = panel
  T.OnChange(Render)
end

-- name (facultatif) : profil a afficher tout de suite, avec son apercu
function ns.OpenProfiles(name)
  if ns.Off("profiles") then return end
  if InCombatLockdown() then return ns.Msg(L["Impossible de lire les macros en combat."]) end
  ns.Open("macros")
  if ns.Tutorial then ns.Tutorial.Stop() end -- le panneau de la visite passerait dessous
  if not ns.ed.w.macros then return end -- l'onglet n'a pas pu se construire
  if not panel then Build() end
  ns.HidePanels()
  local p = name and ns.db.profiles[name]
  if p then state.chosen, state.others, state.lineOffset = name, p.owner ~= nil and p.owner ~= ns.CharKey(), 0 end
  panel:Show()
  ns.Listen(panel, true, "UPDATE_MACROS", "PLAYER_REGEN_DISABLED")
  Render()
end

table.insert(ns.HomeActions, { id = "profiles", feature = "profiles", title = L["Profils"],
  desc = L["Tes macros, tes touches et tes barres en un clic, d'une spé ou d'un personnage à l'autre."],
  run = function() ns.OpenProfiles() end })

-- appele au chargement de BlockForgeDB, puis a chaque changement d'une fonction dans les Parametres
ns.OnFeatures(function()
  if not ns.db then return end
  Migrate()
  local on = ns.Enabled("profiles")
  if panel then
    ns.Listen(panel, on and panel:IsShown(), "UPDATE_MACROS", "PLAYER_REGEN_DISABLED")
    if not on then panel:Hide() else Render() end
  end
  local spec = on and ns.Enabled("specProfiles") and Profiles.ActiveSpec() ~= nil
  -- un evenement que ce client ne connait pas ferait une erreur : chacun est inscrit a part
  for _, event in ipairs({ "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_TALENT_UPDATE", "PLAYER_REGEN_ENABLED" }) do
    pcall(spec and specFrame.RegisterEvent or specFrame.UnregisterEvent, specFrame, event)
  end
  if spec then lastGroup = lastGroup or Profiles.ActiveSpec() else lastGroup, pendingGroup = nil, nil end
end)
