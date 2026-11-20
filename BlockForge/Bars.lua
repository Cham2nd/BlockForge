-- BlockForge : barres d'action. Lecture des emplacements, pose verifiee d'une macro, annulation de la derniere operation.
-- Rien ne s'accroche aux boutons du jeu : tout passe par les numeros d'emplacement, hors combat.
local ADDON, ns = ...
local L = ns.L

local Bars = {}
ns.Bars = Bars

-- API pas toutes verifiees en jeu : absente ou en erreur, l'appel rend nil
local function try(fn, ...)
  if not fn then return nil end
  local ok, a, b, c = pcall(fn, ...)
  if ok then return a, b, c end
end

-- un numero hors de ces plages peut faire planter le client ; 121 a 144 (possession) n'est jamais a nous
local function ValidSlot(slot)
  return type(slot) == "number" and slot == math.floor(slot) and ((slot >= 1 and slot <= 120) or (slot >= 145 and slot <= 180))
end

function Bars.Ready() return type(GetActionInfo) == "function" end

-- 1 a 120 : barres et postures ; 145 a 180 : barres 6 a 8, seulement si le client les a
function Bars.Slots()
  local slots = {}
  for slot = 1, 120 do slots[#slots + 1] = slot end
  if _G.MultiBar5 and _G.MultiBar7 then
    for slot = 145, 180 do slots[#slots + 1] = slot end
  end
  return slots
end

local function Env(slots)
  local getText = (C_ActionBar and C_ActionBar.GetActionText) or GetActionText
  local spellName = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
  local spellIcon = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
  local itemName = C_Item and C_Item.GetItemNameByID
  local itemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  local itemIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
  return {
    slots = slots or Bars.Slots(), macros = ns.ReadMacros(),
    action = function(slot) return try(GetActionInfo, slot) end,
    text = function(slot) return (try(getText, slot)) end,
    texture = function(slot) return (try(GetActionTexture, slot)) end,
    spellName = function(id) return (try(spellName, id)) end,
    name = function(kind, id)
      if kind == "spell" then return (try(spellName, id)), (try(spellIcon, id)) end
      return (try(itemName, id)) or (try(itemInfo, id)), (try(itemIcon, id))
    end,
    -- la touche du bouton, sinon celle de la macro elle-meme
    key = function(slot, macroName)
      local binding = ns.SlotBinding(slot)
      return (binding and try(GetBindingKey, binding)) or (macroName and try(GetBindingKey, "MACRO " .. macroName)) or nil
    end,
  }
end

-- liste des emplacements et comptes (ns.ScanBars) ; nil en combat ou si le client ne lit pas les barres
function Bars.Scan()
  if InCombatLockdown() or not Bars.Ready() then return nil end
  return ns.ScanBars(Env())
end

function Bars.Read(slot)
  if not ValidSlot(slot) or not Bars.Ready() then return nil end
  return ns.ScanBars(Env({ slot }))[1]
end

-- Nom a ecrire dans /cast pour le sort d'un emplacement. Un rang inferieur au plus haut connu est garde, « Sort(Rang 3) »,
-- avec son chiffre en suffixe du nom de macro ; sinon le nom seul, qui suivra les rangs appris plus tard.
function Bars.CastName(e)
  local sub = try(C_Spell and C_Spell.GetSpellSubtext, e.id)
  local best = try(C_Spell and C_Spell.GetSpellInfo, e.name)
  local digits = type(sub) == "string" and sub:match("%d+")
  if digits and type(best) == "table" and best.spellID and best.spellID ~= e.id then
    return e.name .. "(" .. sub .. ")", " " .. digits
  end
  return e.name, ""
end

local function Same(a, b)
  if a.kind ~= b.kind then return false end
  if a.kind == "empty" then return true end
  if a.kind == "macro" then return a.macroName ~= nil and a.macroName == b.macroName end
  return a.id == b.id or (a.name ~= nil and a.name == b.name)
end

-- ce que l'emplacement contenait, tel qu'il est garde pour l'annulation (BlockForgeDB)
local function Content(e) return { kind = e.kind, id = e.id, name = e.name, macroName = e.macroName } end

local function PickupFor(kind)
  if kind == "spell" then return (C_Spell and C_Spell.PickupSpell) or PickupSpell end
  if kind == "item" then return (C_Item and C_Item.PickupItem) or PickupItem end
end

-- peut-on remettre ce contenu en place ? Sinon on ne le remplace pas.
function Bars.CanRestore(content)
  if not (PlaceAction and ClearCursor and GetCursorInfo) then return false end
  if content.kind == "empty" then return PickupAction ~= nil end
  if content.kind == "macro" then return content.macroName ~= nil end
  return content.id ~= nil and PickupFor(content.kind) ~= nil
end

-- remet dans l'emplacement ce qu'il contenait ; true seulement si la relecture le confirme
function Bars.Restore(slot, content)
  if not ns.Enabled("bars") then return false end -- fonction coupee : aucune ecriture sur les barres
  if InCombatLockdown() or not ValidSlot(slot) or type(content) ~= "table" or not Bars.CanRestore(content) then return false end
  ClearCursor()
  if content.kind == "empty" then
    PickupAction(slot)
    ClearCursor()
  else
    if content.kind == "macro" then
      local index = GetMacroIndexByName(content.macroName)
      if index and index > 0 then PickupMacro(index) end
    else
      pcall(PickupFor(content.kind), content.id)
    end
    if GetCursorInfo() ~= content.kind then
      ClearCursor()
      return false
    end
    PlaceAction(slot)
    ClearCursor()
  end
  local now = Bars.Read(slot)
  return now ~= nil and Same(now, content)
end

-- Pose la macro (index, nom) dans l'emplacement et verifie en relisant. Renvoie true, ou false et la raison.
-- before : contenu lu juste avant ; explicit : le joueur a designe cet emplacement, meme vide.
function Bars.Place(slot, index, name, before, explicit)
  if not ns.Enabled("bars") then return false, "off" end -- fonction coupee : aucune ecriture sur les barres
  if InCombatLockdown() then return false, "combat" end
  if not (Bars.Ready() and PlaceAction and PickupMacro and GetCursorInfo and ClearCursor) then return false, "api" end
  if not ValidSlot(slot) then return false, "slot" end
  before = before or Bars.Read(slot)
  if not before then return false, "api" end
  local plain = before.kind == "spell" or before.kind == "item" or before.kind == "macro"
  if not plain and not (explicit and before.kind == "empty") then return false, "kind" end
  if not Bars.CanRestore(before) then return false, "restore" end
  ClearCursor()
  PickupMacro(index)
  if GetCursorInfo() ~= "macro" then
    ClearCursor()
    return false, "pickup"
  end
  PlaceAction(slot)
  local held, now = GetCursorInfo(), Bars.Read(slot)
  if now and now.kind == "macro" and now.macroName == name then
    if held == nil or held == before.kind then
      ClearCursor() -- l'ancien contenu, echange par le jeu : il quitte la barre, rien n'est detruit
      return true
    end
    -- curseur inattendu : ce que le jeu a souleve retourne a sa place
    PlaceAction(slot)
    ClearCursor()
    return false, "cursor"
  end
  ClearCursor()
  now = Bars.Read(slot)
  if now and not Same(now, before) then Bars.Restore(slot, before) end
  return false, "verify"
end

-- plan B : la macro reste sous le curseur, le joueur la depose lui-meme
function Bars.Cursor(index)
  if not ns.Enabled("bars") or InCombatLockdown() or not (PickupMacro and ClearCursor) then return end
  ClearCursor()
  PickupMacro(index)
end

-- index de la macro de ce nom, de cet onglet et de ce texte (aux espaces pres)
local function FindExact(name, char, body)
  local key = ns.NormBody(body)
  for _, m in ipairs(ns.ReadMacros()) do
    if m.name == name and (m.char and true or false) == (char and true or false) and ns.NormBody(m.body) == key then return m.index end
  end
end
Bars.FindExact = FindExact

---------------------------------------------------------------------------
-- Annulation de la derniere operation : BlockForgeDB.undo = { label, ops }, relu apres un /reload.
-- ops, rejouees a l'envers : { op = "slot", slot, before, macro } ; { op = "created", name, char, body } ;
-- { op = "edit", name, char, body } ; { op = "delete", name, char, body, icon, slots }
---------------------------------------------------------------------------
function ns.SetUndo(record) ns.db.undo = record end

function ns.UndoLabel()
  local u = ns.db.undo
  return type(u) == "table" and type(u.ops) == "table" and type(u.label) == "string" and u.label or nil
end

local UNDO = {}

-- l'emplacement n'est restaure que s'il porte encore la macro posee : un changement du joueur est respecte
function UNDO.slot(op)
  local now = Bars.Read(op.slot)
  if not now or now.kind ~= "macro" or now.macroName ~= op.macro then return false end
  return Bars.Restore(op.slot, op.before)
end

-- la macro creee n'est supprimee que si elle est intacte et n'est plus sur aucune barre
function UNDO.created(op)
  if type(op.name) ~= "string" or type(op.body) ~= "string" or not DeleteMacro then return false end
  for _, e in ipairs(Bars.Scan() or {}) do
    if e.macroName == op.name then return false end
  end
  local index = FindExact(op.name, op.char, op.body)
  if not index then return false end
  DeleteMacro(index)
  return FindExact(op.name, op.char, op.body) == nil
end

function UNDO.edit(op)
  if type(op.name) ~= "string" or type(op.body) ~= "string" then return false end
  local index = ns.FindMacro(op.name, op.char and true or false)
  if not index then return false end
  EditMacro(index, op.name, nil, op.body)
  return true
end

function UNDO.delete(op)
  if type(op.name) ~= "string" or type(op.body) ~= "string" or #op.name > 16 or #op.body > ns.MAX_CHARS then return false end
  local char = op.char and true or false
  local numAccount, numChar = GetNumMacros()
  local maxAccount, maxChar = ns.MacroLimits()
  if (char and numChar >= maxChar) or (not char and numAccount >= maxAccount) then return false end
  local icon = (type(op.icon) == "string" or type(op.icon) == "number") and op.icon or "INV_Misc_QuestionMark"
  local index = CreateMacro(op.name, icon, op.body, char)
  if not index or index == 0 then return false end
  -- elle retrouve ses emplacements restes vides ; un emplacement occupe depuis n'est pas touche
  for _, slot in ipairs(type(op.slots) == "table" and op.slots or {}) do
    local now = Bars.Read(slot)
    if now and now.kind == "empty" then Bars.Place(slot, index, op.name, now, true) end
  end
  return true
end

-- renvoie le nombre d'etapes annulees et le nombre d'etapes laissees telles quelles
function ns.RunUndo()
  if InCombatLockdown() then return ns.Msg(L["Impossible de modifier une macro en combat."]) end
  local u = ns.db.undo
  if not ns.UndoLabel() then return end
  -- remettre un emplacement, c'est ecrire sur les barres : l'annulation attend que la fonction soit reactivee
  for _, op in ipairs(u.ops) do
    if type(op) == "table" and op.op == "slot" and ns.Off("bars") then return end
  end
  local done, kept = 0, 0
  for i = #u.ops, 1, -1 do
    local op = u.ops[i]
    local fn = type(op) == "table" and UNDO[op.op]
    local ok, result = pcall(fn or error, op)
    if ok and result then done = done + 1 else kept = kept + 1 end
  end
  ns.db.undo = false
  ns.Msg(L["Annulation de « %s » : %d étape(s) rétablie(s), %d laissée(s) telle(s) quelle(s)."]:format(u.label, done, kept))
  return done, kept
end

---------------------------------------------------------------------------
-- Remplacer le contenu d'un emplacement par une macro
---------------------------------------------------------------------------
-- Cree la macro (ou reprend celle du meme nom), la pose, et ajoute a ops de quoi annuler.
-- overwrite : une macro du meme nom au texte different peut etre reecrite (le joueur a confirme).
-- Renvoie "placed" ou "cursor" (creee mais pas posee) et l'index de la macro ; nil et un message sinon.
local function Apply(slot, name, body, forChar, ops, overwrite)
  local before = Bars.Read(slot)
  if not before then return nil, L["Ce client ne laisse pas BlockForge lire les barres d'action."] end
  if before.kind ~= "spell" and before.kind ~= "item" and before.kind ~= "macro" then
    return nil, L["Cet emplacement ne contient ni sort, ni objet, ni macro : BlockForge n'y touche pas."]
  end
  local index = GetMacroIndexByName(name)
  if index and index > 0 then
    local _, _, oldBody = GetMacroInfo(index)
    if ns.NormBody(oldBody) ~= ns.NormBody(body) then
      if not overwrite then return nil, L["Une autre macro s'appelle déjà « %s »."]:format(name) end
      local maxAccount = ns.MacroLimits()
      EditMacro(index, name, nil, body)
      ops[#ops + 1] = { op = "edit", name = name, char = index > maxAccount, body = oldBody or "" }
    end
  else
    local numAccount, numChar = GetNumMacros()
    local maxAccount, maxChar = ns.MacroLimits()
    if forChar and numChar >= maxChar then return nil, L["Plus de place dans les macros du personnage."] end
    if not forChar and numAccount >= maxAccount then return nil, L["Plus de place dans les macros générales."] end
    index = CreateMacro(name, "INV_Misc_QuestionMark", body, forChar)
    if not index or index == 0 then return nil, L["Le jeu a refusé de créer la macro."] end
    ops[#ops + 1] = { op = "created", name = name, char = forChar, body = body }
  end
  if not Bars.Place(slot, index, name, before) then return "cursor", index end
  ops[#ops + 1] = { op = "slot", slot = slot, before = Content(before), macro = name }
  return "placed", index
end

-- Un emplacement (Assistant) : la macro prend la place du sort. onDone(resultat) : appele une fois la macro creee.
function Bars.Upgrade(slot, name, body, onDone, confirmed)
  if ns.Off("bars") then return end
  if InCombatLockdown() then return ns.Msg(L["Impossible de modifier une macro en combat."]) end
  if name == "" then return ns.Msg(L["Donne un nom à la macro."]) end
  if body == "" then return ns.Msg(L["La macro est vide."]) end
  if #body > ns.MAX_CHARS then return ns.Msg(L["Macro trop longue : %d / %d."]:format(#body, ns.MAX_CHARS)) end
  local before = Bars.Read(slot)
  if not before then return ns.Msg(L["Ce client ne laisse pas BlockForge lire les barres d'action."]) end
  local index = GetMacroIndexByName(name)
  if index and index > 0 and not confirmed and ns.db.confirmOverwrite and StaticPopup_Show then
    local _, _, oldBody = GetMacroInfo(index)
    if ns.NormBody(oldBody) ~= ns.NormBody(body) then
      StaticPopup_Show("BLOCKFORGE_BAR_OVERWRITE", name, nil, { slot = slot, name = name, body = body, onDone = onDone })
      return
    end
  end
  local ops = {}
  local result, info = Apply(slot, name, body, ns.db.perCharDefault and true or false, ops, true)
  if #ops > 0 then ns.SetUndo({ label = L["« %s » sur l'emplacement %d"]:format(name, slot), ops = ops }) end
  if not result then return ns.Msg(info) end
  if result == "placed" then
    ns.Msg(L["Macro « %s » posée sur l'emplacement %d, à la place de « %s ». « Annuler » remet tout comme avant."]:format(name, slot, before.name or "?"))
  else
    Bars.Cursor(info)
    ns.Msg(L["Macro « %s » créée, mais le jeu n'a pas confirmé la pose. Elle est sous ton curseur : dépose-la sur l'emplacement %d."]:format(name, slot))
  end
  if onDone then onDone(result) end
  return result
end

if StaticPopupDialogs then
  StaticPopupDialogs.BLOCKFORGE_BAR_OVERWRITE = {
    text = L["La macro « %s » existe déjà. La remplacer ?"],
    button1 = YES or L["Oui"], button2 = NO or L["Non"],
    OnAccept = function(_, data) Bars.Upgrade(data.slot, data.name, data.body, data.onDone, true) end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  }
end

-- places libres pour les macros que BlockForge cree (onglet choisi dans les parametres)
function Bars.FreeMacros()
  local numAccount, numChar = GetNumMacros()
  local maxAccount, maxChar = ns.MacroLimits()
  if ns.db.perCharDefault then return maxChar - numChar end
  return maxAccount - numAccount
end

-- Conversion en masse d'un plan de ns.BulkPlan. Renvoie les emplacements convertis et ceux laisses tels quels.
function Bars.Convert(plan, label)
  if ns.Off("bars") then return end
  if InCombatLockdown() then return ns.Msg(L["Impossible de modifier une macro en combat."]) end
  if plan.need > Bars.FreeMacros() then
    return ns.Msg(L["Pas assez de place : %d macros à créer, %d places libres."]:format(plan.need, Bars.FreeMacros()))
  end
  local ops, placed, failed = {}, 0, 0
  for _, item in ipairs(plan.items) do
    if Apply(item.slot, item.macroName, item.body, ns.db.perCharDefault and true or false, ops, false) == "placed" then
      placed = placed + 1
    else
      failed = failed + 1
    end
  end
  if #ops > 0 then ns.SetUndo({ label = label, ops = ops }) end
  ns.Msg(L["%d emplacement(s) converti(s), %d laissé(s) tel(s) quel(s). « Annuler » remet tout comme avant."]:format(placed, failed))
  return placed, failed
end
