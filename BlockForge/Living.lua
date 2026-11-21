-- BlockForge : macros vivantes. Le modele d'une macro garde des jetons ({bf:potion_soin}) ; la macro du jeu, elle, porte
-- toujours un vrai nom, que BlockForge reecrit au repos quand les sacs, l'equipement, le grimoire ou le familier changent.
-- Rien ici ne lit un temps de recharge ou des points de vie, et rien ne s'ecrit en combat.
-- Charge apres Bars.lua, Home.lua et Profiles.lua (ns.CharKey, ns.Backup).
local ADDON, ns = ...
local L = ns.L
local T = ns.Theme

local MAX_JOURNAL, MAX_ROWS = 20, 18
local EVENTS = { "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "SPELLS_CHANGED", "UNIT_PET", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }

local events = CreateFrame("Frame")
local Living = { retries = 0, generation = 0 }
ns.Living = Living

-- Entrees communes a toutes les classes ; les bijoux seuls n'attendent aucun sort.
function Living.LibraryEntries()
  if not Living.entries then
    Living.entries = {}
    for _, recipe in ipairs(ns.Recipes) do
      if recipe.feature == "living" then
        Living.entries[#Living.entries + 1] = { class = "ALL", category = "Living", living = recipe.id,
          name = recipe.title, macroName = recipe.name or ns.MacroName(recipe.title),
          desc = recipe.desc, descEN = recipe.desc, body = recipe.build(nil, { showtooltip = true }) }
      end
    end
  end
  return Living.entries
end

-- API pas toutes verifiees en jeu : absente ou en erreur, l'appel rend nil
local function try(fn, ...)
  if not fn then return nil end
  local ok, a = pcall(fn, ...)
  if ok then return a end
end

-- Ce que ns.ResolveLiving a besoin de savoir du personnage : niveau, sacs, quatre emplacements d'equipement, familier.
function Living.Env()
  local env = { level = try(UnitLevel, "player") or 60, bags = {}, slots = {} }
  local byId, info = C_Item and C_Item.GetItemNameByID, (C_Item and C_Item.GetItemInfo) or GetItemInfo
  function env.itemName(id) return try(byId, id) or try(info, id) end
  local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  local itemSpell = (C_Item and C_Item.GetItemSpell) or GetItemSpell
  local spellName = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
  -- l'effet d'une nourriture s'appelle comme le sort 433, celui d'une boisson comme le sort 430 (a verifier en jeu)
  local food, drink = try(spellName, 433), try(spellName, 430)
  local numSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
  local getID = (C_Container and C_Container.GetContainerItemID) or GetContainerItemID
  local seen = {}
  for bag = 0, NUM_BAG_SLOTS or 4 do
    for slot = 1, try(numSlots, bag) or 0 do
      local id = try(getID, bag, slot)
      if id and not seen[id] then
        seen[id] = true
        local item = { id = id, name = env.itemName(id) }
        -- classe d'objet, quand le client la donne : 0 / 5 = nourriture et boisson, 15 / 5 = monture
        local ok, _, _, _, _, _, class, sub = pcall(instant or error, id)
        if ok and class == 0 and sub == 5 then
          local effect = try(itemSpell, id)
          item.kind = effect ~= nil and ((effect == food and "food") or (effect == drink and "drink")) or nil
          local read, _, _, _, _, minLevel = pcall(info or error, id)
          item.level = read and type(minLevel) == "number" and minLevel or 0
        elseif ok and class == 15 and sub == 5 then
          item.kind, item.level = "mount", 0
        end
        env.bags[#env.bags + 1] = item
      end
    end
  end
  for _, slot in ipairs({ 13, 14, 16, 17 }) do
    local id = try(GetInventoryItemID, "player", slot)
    env.slots[slot] = id and env.itemName(id) or nil
  end
  if try(UnitExists, "pet") then env.pet = try(UnitName, "pet") end
  return env
end

---------------------------------------------------------------------------
-- Modeles : BlockForgeDB.living.chars[personnage][macro] pour une macro du personnage, .account[macro] pour une macro
-- generale (resolue pour chaque personnage a sa connexion). { template, body = dernier texte ecrit, last[jeton] = nom, flag }
-- flag : nil, "missing" (rien dans les sacs), "long" (plus de 255 caracteres), "diverged" (modifiee ailleurs : plus reecrite)
---------------------------------------------------------------------------
local function Scope(char, create)
  local db = ns.db.living
  if not char then return db.account end
  local me = ns.CharKey()
  if type(db.chars[me]) ~= "table" then
    if not create then return {} end
    db.chars[me] = {}
  end
  return db.chars[me]
end

-- { name, char, rec }, par nom ; une entree illisible (fichier modifie a la main) est retiree
function Living.List()
  local list = {}
  if not ns.db then return list end
  for _, char in ipairs({ false, true }) do
    local scope = Scope(char)
    for name, rec in pairs(scope) do
      if type(name) == "string" and type(rec) == "table" and type(rec.template) == "string" and type(rec.body) == "string" then
        if type(rec.last) ~= "table" then rec.last = {} end
        list[#list + 1] = { name = name, char = char, rec = rec }
      else
        scope[name] = nil
      end
    end
  end
  table.sort(list, function(a, b) return a.name < b.name or (a.name == b.name and b.char and not a.char) end)
  return list
end

local function Log(macro, text)
  local journal = ns.db.living.journal
  journal[#journal + 1] = { time = date("%Y-%m-%d %H:%M:%S"), macro = macro, text = text }
  while #journal > MAX_JOURNAL do table.remove(journal, 1) end
end

local STATE = { missing = L["vivante, rien dans les sacs"], long = L["vivante, trop longue"], diverged = L["vivante, modifiée ailleurs"] }
-- pour « Mes macros » : nil si la macro n'est pas vivante, sinon son etat en quelques mots
function ns.LivingLabel(name, char)
  if not ns.db or not ns.Enabled("living") then return nil end
  local rec = Scope(char and true or false)[name]
  return type(rec) == "table" and (STATE[rec.flag] or L["vivante"]) or nil
end

-- texte a ouvrir dans l'editeur : le modele a jetons, si ce texte est bien celui que BlockForge a ecrit pour cette macro
function ns.LivingBody(name, body)
  if not ns.Enabled("living") then return body end
  for _, e in ipairs(Living.List()) do
    if e.name == name and e.rec.flag ~= "diverged" and ns.NormBody(e.rec.body) == ns.NormBody(body) then return e.rec.template end
  end
  return body
end

local function Updated()
  if Living.Render then Living.Render() end
  if Living.HomeChip then Living.HomeChip() end
  ns.RefreshSets()
end

-- Enregistrement : Prepare rend le texte a ecrire dans le jeu (jetons remplaces), nil et un message s'il ne peut pas ;
-- Commit, une fois la macro vraiment ecrite, retient le modele. Une macro reecrite sans jeton n'est plus vivante.
local pending = {}

function ns.LivingPrepare(name, body)
  pending[name] = nil
  if not ns.HasTokens(body) then return body end
  if ns.Off("living") then return nil end
  local last
  for _, e in ipairs(Living.List()) do
    if e.name == name then last = e.rec.last end
  end
  local resolved, names, missing = ns.ResolveLiving(body, Living.Env(), last)
  if not resolved then
    local token = ns.TokensOf(missing[#missing] or "")[1]
    ns.Msg(L["« %s » : rien dans tes sacs ni sur toi pour ce jeton. La macro n'a pas été enregistrée."]:format(token and token.label or "?"))
    return nil
  end
  if #resolved > ns.MAX_CHARS then
    ns.Msg(L["Macro trop longue une fois les jetons remplacés : %d / %d."]:format(#resolved, ns.MAX_CHARS))
    return nil
  end
  pending[name] = { template = body, resolved = resolved, names = names, missing = #missing > 0 }
  return resolved
end

-- shortcut: macro generale et macro du personnage de meme nom confondues, a departager par l'index si le cas se presente
function ns.LivingCommit(name)
  local p = pending[name]
  pending[name] = nil
  if not ns.db then return end
  local index = GetMacroIndexByName(name)
  local body = index and index > 0 and select(3, GetMacroInfo(index)) or nil
  local had = Scope(true)[name] or Scope(false)[name]
  Scope(true)[name], Scope(false)[name] = nil, nil
  if p and body and ns.NormBody(body) == ns.NormBody(p.resolved) then
    Scope(index > ns.MacroLimits(), true)[name] = { template = p.template, body = body, last = p.names, flag = p.missing and "missing" or nil }
  end
  if p or had then Updated() end
end

local function Wait(on)
  ns.Listen(events, on and ns.Enabled("living"), "GET_ITEM_INFO_RECEIVED")
end

local function Schedule(delay)
  if Living.scheduled then return end
  Living.scheduled = true
  local generation = Living.generation
  local function run()
    if generation ~= Living.generation then return end
    Living.scheduled = false
    Living.Pass()
  end
  if C_Timer and C_Timer.After then
    local ok = pcall(C_Timer.After, delay, run)
    if ok then return end
  end
  local elapsed = 0
  events:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed >= delay then events:SetScript("OnUpdate", nil) run() end
  end)
end

local function Cancel()
  Living.generation = Living.generation + 1
  Living.scheduled = false
  events:SetScript("OnUpdate", nil)
end

local function MacroOpen()
  if not MacroFrame then return false end
  if not Living.macroHooked and type(MacroFrame.HookScript) == "function" then
    local ok = pcall(MacroFrame.HookScript, MacroFrame, "OnHide", function() Living.Request() end)
    if ok then Living.macroHooked = true end
  end
  if type(MacroFrame.IsShown) ~= "function" then return true end
  local ok, shown = pcall(MacroFrame.IsShown, MacroFrame)
  return not ok or shown and true or false
end

local function Cold(env)
  local ids = {}
  for _, list in pairs(ns.LivingItems) do for _, item in ipairs(list) do ids[item[1]] = true end end
  local cold = false
  for _, item in ipairs(env.bags) do
    if ids[item.id] and not item.name then
      cold = true
      try(C_Item and C_Item.RequestLoadItemDataByID, item.id)
    end
  end
  return cold
end

local function Downgrade(rec, names, env)
  for _, token in ipairs(ns.TokensOf(rec.template)) do
    local list = ns.LivingItems[token.id]
    local old, new = rec.last[token.raw], names[token.raw]
    if list and new and old ~= new then
      if not old then return true end
      local before, after
      for rank, item in ipairs(list) do
        local name = env.itemName(item[1])
        if name == old then before = rank end
        if name == new then after = rank end
      end
      -- un ancien nom hors cache ne permet pas de prouver une amelioration
      if not before or not after or after > before then return true end
    end
  end
  return false
end

-- Une passe : chaque macro vivante est relue, comparee, et reecrite seulement si son texte resolu a change.
-- Renvoie le nombre de macros reecrites.
function Living.Pass()
  if not ns.db or not ns.Enabled("living") or InCombatLockdown() then return 0 end
  if MacroOpen() then return 0 end
  Living.lastPass = GetTime and GetTime() or 0
  local list = Living.List()
  if #list == 0 then Cancel() Wait(false) Living.retries = 0 return 0 end
  local env, edits, touched = Living.Env(), {}, false
  local cold = Cold(env)
  if cold and Living.retries < 5 then
    Wait(true)
    if not Living.scheduled then
      Living.retries = Living.retries + 1
      Log("", L["Cache des objets incomplet : passe reportée de 2 secondes."])
      Schedule(2)
    end
    return 0
  end
  Cancel()
  Wait(cold)
  if not cold then Living.retries = 0 end
  for _, e in ipairs(list) do
    local rec, index = e.rec, ns.FindMacro(e.name, e.char)
    local body = index and select(3, GetMacroInfo(index)) or nil
    if not index then
      Scope(e.char)[e.name] = nil
      Log(e.name, L["La macro n'existe plus : elle n'est plus suivie."])
      touched = true
    elseif ns.NormBody(body) ~= ns.NormBody(rec.body) then
      if rec.flag ~= "diverged" then
        rec.flag, touched = "diverged", true
        Log(e.name, L["Modifiée hors de BlockForge : elle n'est plus réécrite tant que tu ne l'as pas confirmé."])
      end
    elseif rec.flag ~= "diverged" then
      local new, names, missing = ns.ResolveLiving(rec.template, env, rec.last)
      local flag = (not new and "missing") or (#new > ns.MAX_CHARS and "long") or (#missing > 0 and "missing") or nil
      touched = touched or flag ~= rec.flag
      rec.flag = flag
      if cold and new and Downgrade(rec, names, env) then
        Log(e.name, L["Cache des objets incomplet : remplacement par un objet inférieur refusé."])
      elseif new and #new <= ns.MAX_CHARS and ns.NormBody(new) ~= ns.NormBody(body) then
        edits[#edits + 1] = { entry = e, index = index, old = body, new = new, names = names }
      elseif new and #new <= ns.MAX_CHARS then
        rec.last = names
      end
    end
  end
  -- plusieurs macros d'un coup : sauvegarde automatique d'abord, et une annulation, sauf si le joueur en a deja une en attente
  local ops = {}
  if #edits > 1 then ns.Backup(L["macros vivantes"]) end
  for _, edit in ipairs(edits) do
    local e, rec = edit.entry, edit.entry.rec
    EditMacro(edit.index, e.name, nil, edit.new) -- meme index, meme nom, icone inchangee
    local name, _, body = GetMacroInfo(edit.index)
    if name == e.name and body == edit.new then
      for _, token in ipairs(ns.TokensOf(rec.template)) do
        local was, now = rec.last[token.raw], edit.names[token.raw]
        if was ~= now then Log(e.name, L["%s : %s -> %s"]:format(token.label, ns.Plain(was or "?"), ns.Plain(now))) end
      end
      rec.body, rec.last = edit.new, edit.names
      ops[#ops + 1] = { op = "edit", name = e.name, char = e.char, body = edit.old }
    else
      Log(e.name, L["Le jeu a refusé la réécriture."])
    end
  end
  if #ops > 1 and not ns.UndoLabel() then ns.SetUndo({ label = L["réécriture de %d macros vivantes"]:format(#ops), ops = ops }) end
  if touched or #edits > 0 then Updated() end
  return #ops
end

-- Les demandes se regroupent ; un evenement de cache peut terminer l'attente avant le delai.
function Living.Request()
  if not ns.db or not ns.Enabled("living") or Living.scheduled or InCombatLockdown() or #Living.List() == 0 then return end
  Schedule(1)
end

events:SetScript("OnEvent", function(_, event, unit)
  if event == "GET_ITEM_INFO_RECEIVED" then
    if ns.Enabled("living") then Living.Pass() end
  elseif event ~= "UNIT_PET" or unit == "player" then Living.Request() end
end)

-- le joueur confirme : la macro modifiee ailleurs redevient vivante, et son texte sera de nouveau ecrase par le modele
function Living.Resume(name, char)
  if ns.Off("living") then return end
  if InCombatLockdown() then return ns.Msg(L["Impossible de modifier une macro en combat."]) end
  local rec, index = Scope(char)[name], ns.FindMacro(name, char)
  if not rec or not index then return end
  rec.body, rec.flag = select(3, GetMacroInfo(index)) or "", nil
  Living.Pass()
  Updated()
  return true
end

function Living.Forget(name, char)
  Scope(char)[name] = nil
  Updated()
end

---------------------------------------------------------------------------
-- Editeur : « Vivant… » sur la ligne de l'argument, et sa liste de jetons
---------------------------------------------------------------------------
function ns.BuildLiving()
  local ui, view = ns.ui, ns.ed
  local insp = view.w.insp
  -- puce de 206 a 286, de -68 a -84 (le champ de l'argument commence a -86) ; liste de 96 a 286, de -86 a -358
  local chip = ui.Chip(insp, 80, 16)
  chip:SetPoint("TOPLEFT", 206, -68)
  chip:SetFrameLevel((insp:GetFrameLevel() or 0) + 5)
  chip.text:SetJustifyH("CENTER")
  chip.text:SetText(L["Vivant…"])
  T.Watch(function() ui.Tint(chip, T.accent, 0.6) end)
  local menu = ui.Panel(insp, 190, 12 + #ns.LivingTokens * 20)
  menu:SetPoint("TOPRIGHT", chip, "BOTTOMRIGHT", 0, -2)
  menu:SetBackdropColor(T.panel[1], T.panel[2], T.panel[3], 1)
  menu:SetFrameStrata("DIALOG")
  menu:EnableMouse(true) -- le fond arrete les clics
  menu:Hide()
  for i, token in ipairs(ns.LivingTokens) do
    local item = ui.Chip(menu, 174, 18)
    item:SetPoint("TOPLEFT", 8, -6 - (i - 1) * 20)
    item.text:SetText(token.label)
    T.Watch(function() ui.Tint(item, T.accent, 0.45) end)
    item:SetScript("OnClick", function()
      menu:Hide()
      if InCombatLockdown() then return ns.Msg(L["Impossible de modifier une macro en combat."]) end
      view.Arg(function(old)
        if token.id ~= "sort" then return "{bf:" .. token.id .. "}" end
        local spell = ns.trim((old:gsub("^{bf:sort:([^}]*)}$", "%1"):gsub("%s*%(.-%)%s*$", "")))
        if spell == "" or ns.HasTokens(spell) then
          ns.Msg(L["Écris d'abord le nom du sort dans l'argument, puis choisis ce jeton."])
          return nil
        end
        return "{bf:sort:" .. spell .. "}"
      end)
    end)
    ui.Tip(item, function() return token.label, token.tip end)
  end
  chip:SetScript("OnClick", function() menu:SetShown(not menu:IsShown()) end)
  ui.Tip(chip, function()
    return L["Vivant…"], L["Met un jeton à la place d'un nom fixe : ta meilleure potion, ton bijou du moment, ton arme… La macro du jeu porte toujours un vrai nom, que BlockForge réécrit hors combat quand tes sacs ou ton équipement changent."]
  end)
  local function Sync()
    local kind = view.Arg()
    local on = ns.Enabled("living") and kind ~= nil and ns.BlockById[kind].arg ~= nil and kind ~= "raw" and kind ~= "castsequence"
    chip:SetShown(on)
    if not on then menu:Hide() end
  end
  -- Tools.lua a deja pose view.OnRefresh : les deux se suivent
  local previous = view.OnRefresh
  function view.OnRefresh(text)
    if previous then previous(text) end
    Sync()
  end
  insp:HookScript("OnHide", function() menu:Hide() end)
  view.w.livingChip, view.w.livingMenu = chip, menu
  ns.OnFeatures(Sync, true)
end

---------------------------------------------------------------------------
-- Panneau : les macros vivantes et leur etat a gauche, le modele et le journal a droite
---------------------------------------------------------------------------
local panel
local state = { offset = 0, list = {} }

local function Render()
  if not panel or not panel:IsShown() then return end
  local ui = ns.ui
  state.list = Living.List()
  local current
  for _, e in ipairs(state.list) do
    if state.name == e.name and state.char == e.char then current = e end
  end
  state.offset = math.max(0, math.min(state.offset, #state.list - MAX_ROWS))
  for i, row in ipairs(panel.rows) do
    local e = state.list[state.offset + i]
    row:SetShown(e ~= nil)
    if e then
      row.text:SetText(ns.Plain(e.name))
      row.state:SetText(ns.LivingLabel(e.name, e.char) or "")
      ui.Tint(row, e.char and T.accent or T.grey, e == current and 1 or 0.5)
      row.mark:SetShown(e == current)
    end
  end
  panel.empty:SetShown(#state.list == 0)
  panel.name:SetText(current and ns.Plain(current.name) or L["Choisis une macro dans la liste."])
  panel.info:SetText(current and ((current.char and L["Macro du personnage"] or L["Macro générale"]) .. "  ·  " .. ns.LivingLabel(current.name, current.char)) or "")
  panel.body:SetText(current and ns.Code(current.rec.template) or "")
  local diverged = current ~= nil and current.rec.flag == "diverged"
  if diverged then panel.resume:Enable() else panel.resume:Disable() end
  if current then panel.forget:Enable() else panel.forget:Disable() end
  local journal = ns.db.living.journal
  for i, line in ipairs(panel.lines) do
    local entry = journal[#journal - i + 1] -- le plus recent en haut
    line:SetText(type(entry) == "table" and ("|cff888888%s|r  %s : %s"):format(tostring(entry.time):sub(6, 16), ns.Plain(entry.macro), tostring(entry.text)) or "")
  end
  panel.noJournal:SetShown(#journal == 0)
end
Living.Render = Render

local function Build()
  local ui, page = ns.ui, ns.ed.w.home
  -- 884 x 566 : toute la page d'accueil. Liste de 8 a 428 : 18 lignes de 22 tous les 24 de -54 a -484. Detail de 440 a 876 :
  -- nom a -54, etat a -76, modele de -98 a -248, actions de -258 a -280, journal de 20 lignes de 12 de -314 a -554.
  panel = ui.Panel(page, 884, 566, L["Macros vivantes"])
  panel:SetPoint("TOPLEFT")
  panel:SetBackdropColor(T.panel[1], T.panel[2], T.panel[3], 1)
  panel:SetFrameStrata("DIALOG")
  panel:SetFrameLevel((page:GetFrameLevel() or 0) + 10)
  panel:EnableMouse(true) -- le fond arrete les clics
  panel:Hide()
  ns.CloseChip(panel)
  local hint = ui.Label(panel, L["Tes macros à jetons. BlockForge les réécrit hors combat, jamais pendant."], 8, -30, "GameFontDisableSmall")
  hint:SetWidth(420)
  hint:SetWordWrap(false)
  panel.rows = {}
  for i = 1, MAX_ROWS do
    -- nom de 12 a 190, etat de 196 a 414
    local row = ui.Chip(panel, 420, 22)
    row:SetPoint("TOPLEFT", 8, -54 - (i - 1) * 24)
    row.mark = ui.SideBar(row, T.accent)
    row.text:ClearAllPoints()
    row.text:SetPoint("LEFT", 12, 0)
    row.text:SetWidth(178)
    row.state = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.state:SetPoint("LEFT", 196, 0)
    row.state:SetWidth(218)
    row.state:SetJustifyH("LEFT")
    row.state:SetWordWrap(false)
    row:SetScript("OnClick", function()
      local e = state.list[state.offset + i]
      state.name, state.char = e and e.name, e and e.char
      Render()
    end)
    panel.rows[i] = row
  end
  panel:EnableMouseWheel(true)
  panel:SetScript("OnMouseWheel", function(_, delta)
    state.offset = state.offset - delta * 3
    Render()
  end)
  panel.empty = ui.Label(panel, L["Aucune macro vivante. Clique sur « Créer une macro vivante » pour choisir une recette dans l'Assistant, ou choisis un bloc puis « Vivant… » dans l'éditeur."], 12, -60, "GameFontDisableSmall")
  panel.empty:SetWidth(410)
  -- Sous la liste (fin a -484), de 12 a 422 et de -500 a -522.
  panel.create = ui.Button(panel, L["Créer une macro vivante"], 410, function()
    ns.OpenAssistant(nil, nil, true)
    if ns.assistant and ns.assistant:IsShown() then panel:Hide() end
  end)
  panel.create:SetPoint("TOPLEFT", 12, -500)
  ns.OnFeatures(function() panel.create:SetShown(ns.Enabled("assistant")) end, true)

  panel.name = ui.Label(panel, "", 440, -54, "GameFontHighlightLarge")
  panel.name:SetWidth(436)
  panel.name:SetWordWrap(false)
  panel.info = ui.Label(panel, "", 440, -76, "GameFontHighlightSmall")
  panel.info:SetWidth(436)
  panel.info:SetWordWrap(false)
  panel.body = ui.Label(panel, "", 440, -98, "BlockForgeCodeFont")
  panel.body:SetSize(436, 150)
  panel.body:SetJustifyV("TOP")
  -- reprendre de 440 a 655, ne plus suivre de 661 a 876
  panel.resume = ui.Button(panel, L["Redevenir vivante"], 215, function()
    if state.name then Living.Resume(state.name, state.char) end
  end)
  panel.resume:SetPoint("TOPLEFT", 440, -258)
  ui.Tip(panel.resume, function()
    return L["Redevenir vivante"], L["Cette macro a été modifiée hors de BlockForge : elle n'est plus réécrite. Ce bouton confirme que le modèle à jetons reprend la main : le texte actuel de la macro sera remplacé. Hors combat seulement."]
  end)
  panel.forget = ui.Button(panel, L["Ne plus suivre"], 215, function()
    if state.name then Living.Forget(state.name, state.char) end
  end)
  panel.forget:SetPoint("TOPLEFT", 661, -258)
  ui.Tip(panel.forget, function() return L["Ne plus suivre"], L["BlockForge oublie le modèle à jetons. La macro du jeu garde son texte actuel et n'est plus jamais réécrite."] end)

  T.AccentText(ui.Label(panel, L["Dernières réécritures"], 440, -294, "GameFontNormal"))
  panel.lines = {}
  for i = 1, MAX_JOURNAL do
    local line = ui.Label(panel, "", 440, -314 - (i - 1) * 12, "GameFontHighlightSmall")
    line:SetWidth(436)
    line:SetWordWrap(false)
    panel.lines[i] = line
  end
  panel.noJournal = ui.Label(panel, L["Rien pour l'instant."], 440, -314, "GameFontDisableSmall")

  panel:SetScript("OnEvent", function(self) self:Hide() end)
  page:HookScript("OnHide", function() panel:Hide() end)
  panel.state = state
  ns.livingPanel = panel
  ns.OnFeatures(function()
    local on = ns.Enabled("living")
    ns.Listen(panel, on, "PLAYER_REGEN_DISABLED")
    if not on then panel:Hide() end
  end, true)
  T.OnChange(Render)
end

function ns.OpenLiving()
  if ns.Off("living") then return end
  if InCombatLockdown() then return ns.Msg(L["Impossible de lire les macros en combat."]) end
  ns.Open("home")
  if ns.Tutorial then ns.Tutorial.Stop() end -- le panneau de la visite passerait dessous
  if not ns.ed.w.home then return end -- l'accueil n'a pas pu se construire
  if not panel then Build() end
  ns.HidePanels()
  panel:Show()
  Render()
end

-- Accueil : une ligne dans le bandeau, de 640 a 876, de -72 a -90 (sous celle du kit)
table.insert(ns.HomeBuilders, function(top, page)
  local ui = ns.ui
  local chip = ui.Chip(top, 236, 18)
  chip:SetPoint("TOPLEFT", 640, -72)
  chip:SetScript("OnClick", function()
    if #Living.List() == 0 and ns.Enabled("assistant") then ns.OpenAssistant(nil, nil, true)
    else ns.OpenLiving() end
  end)
  ui.Tip(chip, function()
    local journal = ns.db.living.journal
    local last = journal[#journal]
    return L["Macros vivantes"], L["Les macros que BlockForge tient à jour toutes seules, et le journal de ses 20 dernières réécritures. Aussi : /bf vivant."],
      type(last) == "table" and (ns.Plain(last.macro) .. " : " .. tostring(last.text)) or nil
  end)
  function Living.HomeChip()
    local on = ns.Enabled("living")
    chip:SetShown(on)
    if on then
      chip.text:SetText(L["Macros vivantes : %d · journal"]:format(#Living.List()))
      ui.Tint(chip, T.accent, 0.45)
    end
  end
  page:HookScript("OnShow", Living.HomeChip)
  T.OnChange(Living.HomeChip)
  ns.OnFeatures(Living.HomeChip, true)
end)

-- evenements inscrits seulement tant que la fonction est active
ns.OnFeatures(function()
  if not ns.db then return end
  local on = ns.Enabled("living")
  ns.Listen(events, on, unpack(EVENTS))
  if not on then Cancel() Living.retries = 0 Wait(false) end
end)
