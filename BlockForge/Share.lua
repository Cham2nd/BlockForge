-- BlockForge : envoi d'une macro a un autre joueur par le canal des add-ons (chuchotement).
-- Frontiere de confiance : ce qui arrive vient d'un inconnu. Rien n'est cree ni modifie sans un clic du joueur,
-- le texte recu repasse par ns.Import, et ce qui s'affiche (expediteur, nom) est echappe.
local ADDON, ns = ...
local L = ns.L

local PREFIX = "BlockForge"
local PROMPT_GAP = 30 -- secondes entre deux propositions d'un meme joueur
local Now = GetTime or time or function() return 0 end

local chat = C_ChatInfo
local available = type(chat) == "table" and type(chat.RegisterAddonMessagePrefix) == "function"
  and type(chat.SendAddonMessage) == "function"
function ns.CanShare() return available end
if available then pcall(chat.RegisterAddonMessagePrefix, PREFIX) end

local COMBAT = L["Impossible de modifier une macro en combat."]

---------------------------------------------------------------------------
-- Envoi
---------------------------------------------------------------------------
-- depart au hasard : apres un /reload, un envoi ne reprend pas le numero d'un transfert encore en attente en face
local nextId = math.random(0, 99999)

function ns.SendMacro(name, body, target)
  if InCombatLockdown() then return ns.Msg(COMBAT) end
  target = ns.trim(target or "")
  if not available or target == "" then return end
  local payload = ns.Export(name, body)
  local valid, err = ns.Import(payload) -- les controles que fera celui qui recoit
  if not valid then return ns.Msg(err) end
  nextId = (nextId + 1) % 100000
  local chunks = ns.Chunks(payload, tostring(nextId))
  if not chunks then return ns.Msg(L["Macro trop longue pour être envoyée."]) end
  for _, chunk in ipairs(chunks) do
    local ok, result = pcall(chat.SendAddonMessage, PREFIX, chunk, "WHISPER", target)
    -- retour selon le client : rien, un booleen, ou un code dont 0 veut dire « envoye »
    if not ok or result == false or (type(result) == "number" and result ~= 0) then
      return ns.Msg(L["L'envoi à %s a échoué : les messages d'add-on sont peut-être bloqués ici (instance, combat)."]:format(ns.Plain(target)))
    end
  end
  ns.Msg(L["Macro « %s » envoyée à %s. Elle lui sera proposée s'il a BlockForge."]:format(ns.Plain(name), ns.Plain(target)))
  return true
end

-- nom de la cible si c'est un autre joueur ami, sinon ""
local function FriendlyTarget()
  if not (UnitExists and UnitIsPlayer and UnitIsFriend and UnitIsUnit and GetUnitName) then return "" end
  if not UnitExists("target") or not UnitIsPlayer("target") or not UnitIsFriend("player", "target")
     or UnitIsUnit("target", "player") then return "" end
  return ((GetUnitName("target", true) or ""):gsub("%s", "")) -- "Nom-Royaume" sans espace, comme pour un chuchotement
end

function ns.SendPrompt(name, body)
  if InCombatLockdown() then return ns.Msg(COMBAT) end
  name = ns.trim(name or "")
  if name == "" then return ns.Msg(L["Donne un nom à la macro."]) end
  if ns.trim(body or "") == "" then return ns.Msg(L["La macro est vide."]) end
  local ok, target = pcall(FriendlyTarget)
  ns.Prompt(L["Envoyer « %s » à quel joueur ?"]:format(ns.Plain(name)), ok and target or "", 64, L["Envoyer"], function(text)
    if text ~= "" then ns.SendMacro(name, body, text) end
  end)
end

---------------------------------------------------------------------------
-- Reception
---------------------------------------------------------------------------
local inbox = ns.NewInbox()
local lastPrompt = {} -- expediteur -> heure de sa derniere proposition
local incoming        -- macro proposee, en attente de la reponse du joueur : une seule a la fois

local function IsSelf(sender)
  local me = UnitName and UnitName("player")
  local short, realm = sender:match("^([^-]+)-?(.*)$")
  if not me or short ~= me then return false end
  local mine = GetNormalizedRealmName and GetNormalizedRealmName()
  return realm == "" or not mine or realm == mine
end

function ns.OnShareMessage(prefix, text, channel, sender)
  -- en combat rien ne se declenche, et les arguments peuvent etre des valeurs secretes : on ne les lit meme pas
  if InCombatLockdown() then return end
  if canaccessvalue and not (canaccessvalue(prefix) and canaccessvalue(text) and canaccessvalue(channel) and canaccessvalue(sender)) then return end
  if prefix ~= PREFIX or channel ~= "WHISPER" or not ns.db or not ns.db.acceptShared then return end
  if type(sender) ~= "string" or sender == "" or #sender > 64 or IsSelf(sender) then return end
  local now = Now()
  local payload = inbox:Receive(sender, text, now)
  if not payload then return end
  for who, at in pairs(lastPrompt) do
    if now - at > PROMPT_GAP then lastPrompt[who] = nil end
  end
  -- une proposition restee sans reponse (fenetre jamais affichee) ne bloque pas les suivantes pour toujours
  if incoming and now - incoming.at > 90 then incoming = nil end
  if incoming or lastPrompt[sender] or not StaticPopup_Show then return end
  local name, body = ns.Import(payload)
  -- un nom s'affiche tel quel dans les listes : ni code de couleur ni retour a la ligne venant d'un inconnu
  if not name or name:find("[|%c]") then return end
  lastPrompt[sender] = now
  incoming = { name = name, body = body, sender = sender, at = now }
  StaticPopup_Show("BLOCKFORGE_INCOMING", ns.Plain(sender), ns.Plain(name), incoming)
end

-- le joueur a clique : la macro s'ouvre dans l'editeur (non enregistree) ou va dans ses modeles, jamais dans les macros du jeu
local function Take(data, toLibrary)
  if not data or incoming ~= data then return end
  incoming = nil
  if InCombatLockdown() then return ns.Msg(COMBAT) end
  if toLibrary then
    ns.AddPersonal(data.name, data.body, nil, L["Reçue de %s"]:format(data.sender))
  else
    ns.Open("editor")
    ns.ed.Load(data.name, data.body)
    ns.Msg(L["Macro « %s » ouverte dans l'éditeur : « Créer / mettre à jour » pour l'enregistrer."]:format(data.name))
  end
end

if StaticPopupDialogs then
  StaticPopupDialogs.BLOCKFORGE_INCOMING = {
    text = L["%s t'envoie la macro « %s ».\n« Ouvrir » la montre dans l'éditeur, « Ma bibliothèque » la range dans tes modèles. Rien n'est enregistré dans tes macros du jeu."],
    button1 = L["Ouvrir"], button2 = L["Refuser"], button3 = L["Ma bibliothèque"],
    OnAccept = function(_, data) Take(data, false) end,
    OnAlt = function(_, data) Take(data, true) end,
    OnCancel = function(_, data) if incoming == data then incoming = nil end end,
    timeout = 60, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  }
end

if available then
  local events = CreateFrame("Frame")
  events:RegisterEvent("CHAT_MSG_ADDON")
  events:SetScript("OnEvent", function(_, _, ...) ns.OnShareMessage(...) end)
end
