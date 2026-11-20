-- BlockForge : bibliotheque personnelle (« Mes modeles »). BlockForgeDB.personal, commun a tous les personnages du compte.
local ADDON, ns = ...
local L = ns.L

local MAX_PERSONAL = 200

local function Find(name)
  for i, m in ipairs(ns.db.personal) do
    if m.name == name then return i, m end
  end
end

-- Lignes affichees par l'onglet Bibliotheque : meme forme qu'une macro de ns.Library, refaites a chaque changement
-- pour ne rien ecrire d'autre que name / body / icon / note dans les variables sauvegardees.
function ns.PersonalEntries()
  if not ns.personalCache then
    local list = {}
    for i, m in ipairs(ns.db.personal) do
      local note = ns.Plain(m.note or "") -- peut venir d'un autre joueur (macro recue)
      list[i] = { class = "PERSONAL", personal = m, name = m.name, body = m.body, icon = m.icon, desc = note, descEN = note }
    end
    ns.personalCache = list
  end
  return ns.personalCache
end

local function Changed()
  ns.personalCache = nil
  if ns.ReloadLibrary then ns.ReloadLibrary() end
end

local function Store(name, body, icon, note)
  local at, old = Find(name)
  ns.db.personal[at or (#ns.db.personal + 1)] = { name = name, body = body, icon = icon, note = note or (old and old.note) or nil }
  Changed()
  ns.Msg(L["« %s » est dans ta bibliothèque : onglet Bibliothèque, « Mes modèles »."]:format(name))
end

-- renvoie true si le modele est range tout de suite (false : refuse, ou confirmation demandee)
function ns.AddPersonal(name, body, icon, note)
  if InCombatLockdown() then return ns.Msg(L["Impossible de modifier une macro en combat."]) end
  name = ns.trim((name or ""):gsub("[|%c]", "")) -- un | dans un nom serait lu comme un code de couleur dans les listes
  body = body or ""
  if name == "" then return ns.Msg(L["Donne un nom à la macro."]) end
  if ns.trim(body) == "" then return ns.Msg(L["La macro est vide."]) end
  if #body > ns.MAX_CHARS then return ns.Msg(L["Macro trop longue : %d / %d."]:format(#body, ns.MAX_CHARS)) end
  if type(icon) ~= "string" and type(icon) ~= "number" then icon = nil end
  if Find(name) then
    if StaticPopup_Show then
      StaticPopup_Show("BLOCKFORGE_REPLACE_PERSONAL", name, nil, { name = name, body = body, icon = icon, note = note })
      return false
    end
  elseif #ns.db.personal >= MAX_PERSONAL then
    return ns.Msg(L["Ta bibliothèque est pleine (%d modèles) : supprimes-en un d'abord."]:format(MAX_PERSONAL))
  end
  Store(name, body, icon, note)
  return true
end

-- Archive sans question (bilan de sante) : renvoie le nom sous lequel le modele est range, nil si la bibliotheque est pleine.
-- Un modele de meme nom n'est jamais ecrase : meme texte, il sert d'archive ; texte different, le nom recoit un suffixe.
-- note (facultatif) : d'ou vient l'archive, quand ce n'est pas le bilan de sante.
function ns.ArchivePersonal(name, body, icon, note)
  local base = ns.trim((name or ""):gsub("[|%c]", ""))
  if base == "" then base = "?" end
  local stored, n = base, 1
  while true do
    local _, old = Find(stored)
    if not old then break end
    if old.body == body then return stored end
    n = n + 1
    stored = ns.MacroName(base, 13) .. " ~" .. n
  end
  if #ns.db.personal >= MAX_PERSONAL then return nil end
  if type(icon) ~= "string" and type(icon) ~= "number" then icon = nil end
  ns.db.personal[#ns.db.personal + 1] = { name = stored, body = body or "", icon = icon, note = note or L["Archivée par le bilan de santé."] }
  Changed()
  return stored
end

if StaticPopupDialogs then
  StaticPopupDialogs.BLOCKFORGE_REPLACE_PERSONAL = {
    text = L["Le modèle « %s » existe déjà dans ta bibliothèque. Le remplacer ?"],
    button1 = YES or L["Oui"], button2 = NO or L["Non"],
    OnAccept = function(_, data) Store(data.name, data.body, data.icon, data.note) end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  }
  StaticPopupDialogs.BLOCKFORGE_DELETE_PERSONAL = {
    text = L["Supprimer le modèle « %s » de ta bibliothèque ? C'est définitif."],
    button1 = YES or L["Oui"], button2 = NO or L["Non"],
    OnAccept = function(_, m)
      for i, other in ipairs(ns.db.personal) do
        if other == m then table.remove(ns.db.personal, i) break end
      end
      Changed()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  }
end

-- Actions d'un modele dans le panneau « Detail » de la bibliotheque (396 x 566). Comptes depuis le bas :
--   10 : ouvrir de 10 a 190 (UI.lua), supprimer de 196 a 376
--   38 : renommer de 10 a 130, note de 136 a 256, exporter de 262 a 382
--   66 : champ de partage de 16 a 256, importer de 262 a 382
-- Renvoie { Sync(affiche, ligne choisie) } pour UI.lua.
function ns.BuildPersonal(detail)
  local ui = ns.ui
  local current
  local group = CreateFrame("Frame", nil, detail)
  group:SetAllPoints()

  local delete = ui.Button(group, L["Supprimer"], 180, function()
    if current and StaticPopup_Show then StaticPopup_Show("BLOCKFORGE_DELETE_PERSONAL", current.name, nil, current.personal) end
  end)
  delete:SetPoint("BOTTOMLEFT", 196, 10)

  local rename = ui.Button(group, L["Renommer"], 120, function()
    local m = current and current.personal
    if not m then return end
    ns.Prompt(L["Nouveau nom du modèle"], m.name, 16, L["Renommer"], function(text)
      text = ns.trim((text:gsub("[|%c]", "")))
      if text == "" or text == m.name then return end
      if Find(text) then return ns.Msg(L["Un modèle s'appelle déjà « %s »."]:format(text)) end
      m.name = text
      Changed()
    end)
  end)
  rename:SetPoint("BOTTOMLEFT", 10, 38)

  local note = ui.Button(group, L["Note…"], 120, function()
    local m = current and current.personal
    if not m then return end
    ns.Prompt(L["Note du modèle (à quoi il sert)"], m.note or "", 120, L["Enregistrer"], function(text)
      m.note = text ~= "" and text or nil
      Changed()
    end)
  end)
  note:SetPoint("BOTTOMLEFT", 136, 38)
  ui.Tip(note, function() return L["Note…"], L["Un rappel affiché sous le nom du modèle, et trouvé par la recherche."] end)

  local share = ui.Edit(group, 240, function() end)
  share:SetPoint("BOTTOMLEFT", 16, 67)
  share:SetMaxLetters(0) -- 0 = sans limite : une macro de 255 caracteres echappee depasse 255
  local export = ui.Button(group, L["Exporter"], 120, function()
    if not current then return end
    share:SetText(ns.Export(current.name, current.body))
    share:SetFocus()
    share:HighlightText()
  end)
  export:SetPoint("BOTTOMLEFT", 262, 38)
  ui.Tip(export, function() return L["Exporter"], L["Met la macro dans le champ ci-dessus en une ligne de texte : Ctrl+C pour la copier."] end)
  local import = ui.Button(group, L["Importer"], 120, function()
    local name, text = ns.Import(share:GetText())
    if not name then return ns.Msg(text) end
    if ns.AddPersonal(name, text) then share:SetText("") end
  end)
  import:SetPoint("BOTTOMLEFT", 262, 66)
  ui.Tip(import, function() return L["Importer"], L["Colle (Ctrl+V) dans le champ un texte « BF1:... », puis clique : la macro est rangée dans tes modèles."] end)

  local needEntry = { delete, rename, note, export }
  return { Sync = function(shown, entry)
    current = entry and entry.personal and entry or nil
    group:SetShown(shown)
    for _, b in ipairs(needEntry) do
      if current then b:Enable() else b:Disable() end
    end
  end }
end
