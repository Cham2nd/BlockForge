-- BlockForge : visite guidee. Un petit panneau non bloquant, pose a cote du widget explique, qu'un cadre entoure.
local ADDON, ns = ...
local L = ns.L
local T = ns.Theme

local function W(key) return function() return ns.ed.w[key] end end

-- Douze etapes au plus. Etapes : onglet, fonction (facultatif : l'etape est sautee si le joueur l'a coupee), widget explique, position du panneau { son point, point du widget, x, y }, titre, texte.
-- Le panneau fait 320 x 140. Positions calculees dans la page de 884 x 570 (fenetre de 900 x 640) :
--   blocs 0-160, zone 166-582, reglages 588-884 (hauteur 430) ; apercu en dessous, de -436 a -566.
ns.TutorialSteps = {
  -- accueil : les entrees sont un panneau de 884 x 150 a -102 ; la visite se pose dessous, a gauche
  { tab = "home", feature = "home", anchor = W("homeActions"), at = { "TOPLEFT", "BOTTOMLEFT", 8, -8 }, -- 8 a 328, -260 a -400
    title = L["L'accueil"],
    text = L["BlockForge s'ouvre ici. « Améliorer ma barre » remplace un sort de ta barre par sa macro, à la même place. En bas, le bilan de santé repère tes macros cassées, en double ou jamais utilisées, à côté de macros suggérées pour ton personnage."] },
  -- any : montree si au moins une de ces fonctions est active ; text peut etre une fonction, qui ne parle que de celles-la
  { tab = "home", feature = "home", any = { "kits", "profiles", "living" }, anchor = W("homeActions"), at = { "TOPLEFT", "BOTTOMLEFT", 8, -8 },
    title = L["Kits, profils, macros vivantes"],
    text = function()
      local parts = {}
      if ns.Enabled("kits") then parts[#parts + 1] = L["« Équiper mon personnage » installe d'un coup un kit de macros pour ta classe et ton rôle."] end
      if ns.Enabled("profiles") then parts[#parts + 1] = L["« Profils » garde tes macros, tes touches et tes barres, pour une autre spé ou un autre personnage."] end
      if ns.Enabled("living") then parts[#parts + 1] = L["Une macro « vivante » suit tes sacs et ton équipement : BlockForge la réécrit hors combat."] end
      return table.concat(parts, " ")
    end },
  { tab = "editor", anchor = W("palette"), at = { "TOPLEFT", "TOPRIGHT", 8, -40 }, -- 168 a 488, -40 a -180
    title = L["Les blocs"],
    text = L["Chaque bloc est une ligne de macro : lancer un sort, utiliser un objet, donner un ordre au familier… Clique sur un bloc pour l'ajouter à ta macro, ou glisse-le à l'endroit voulu."] },
  { tab = "editor", anchor = W("canvas"), at = { "BOTTOMLEFT", "BOTTOMLEFT", 40, 40 }, -- 206 a 526, -250 a -390
    title = L["Ta macro"],
    text = L["Les blocs s'empilent ici, dans l'ordre où le jeu les lit. Glisse une ligne pour la déplacer ; « x2 » la duplique, « x » la supprime. En bas : « Modèles » pour partir d'un exemple, « Annuler » et « Rétablir » pour revenir en arrière."] },
  { tab = "editor", anchor = W("insp"), at = { "TOPRIGHT", "TOPLEFT", -8, -40 }, -- 260 a 580, -40 a -180
    title = L["Les conditions"],
    text = L["Clique sur un bloc, puis règle-le ici : son sort et ses conditions (cible survolée, focus, touche maintenue, combat…). Le « + » ajoute une alternative, essayée quand la précédente ne s'applique pas."] },
  { tab = "editor", anchor = W("preview"), at = { "BOTTOMLEFT", "TOPLEFT", 0, 40 }, -- 10 a 330, -294 a -434
    title = L["Aperçu et simulateur"],
    text = L["Le texte de la macro s'écrit tout seul, avec son compteur : 255 caractères au plus. « Simuler » montre quelle ligne partirait ; « Éditer le texte » te laisse taper la macro à la main."] },
  { tab = "editor", anchor = W("save"), at = { "BOTTOMLEFT", "TOPLEFT", 0, 60 }, -- 450 a 770, -294 a -434
    title = L["Nommer et enregistrer"],
    text = L["Donne un nom (16 caractères au plus), puis « Créer / mettre à jour » : c'est une vraie macro du jeu, à poser sur une barre d'action. À gauche, le bouton montre son icône : clique dessus pour la changer. « Plus… » la garde dans ta bibliothèque ou l'envoie à un joueur."] },
  -- boutons sur la ligne des onglets, de +25 a +3 au-dessus de la page : le panneau se pose dessous, aligne a droite
  { tab = "editor", feature = "grimoire", anchor = W("grimoireButton"), at = { "TOPRIGHT", "BOTTOMRIGHT", 0, -8 }, -- 438 a 758, -5 a -145
    title = L["Mon grimoire"],
    text = L["Tes sorts, les techniques de ton familier et les objets utilisables de tes sacs, en icônes. Un clic ajoute le sort à ta macro, ou remplit le bloc choisi s'il attend un sort. Maj+clic ouvre l'Assistant pour ce sort."] },
  { tab = "editor", feature = "assistant", anchor = W("assistantButton"), at = { "TOPRIGHT", "BOTTOMRIGHT", 0, -8 }, -- 564 a 884, -5 a -145
    title = L["L'Assistant"],
    text = L["Une bonne macro en deux clics : choisis un sort, l'Assistant propose des macros toutes faites (survol, focus, interruption, familier, bijoux…). « Créer la macro » l'enregistre, « Ouvrir dans l'éditeur » te laisse la retoucher."] },
  { tab = "library", anchor = W("libraryList"), at = { "TOPLEFT", "TOPRIGHT", 8, -40 }, -- 490 a 810, -40 a -180
    title = L["La bibliothèque"],
    text = L["Des centaines de macros prêtes, par classe. Cherche par nom, filtre par catégorie, garde tes favoris. « Mes sorts seulement » cache celles que ton personnage ne peut pas lancer. « Mes modèles » : tes propres macros, pour tous tes personnages."] },
  { tab = "macros", anchor = W("macroDetail"), at = { "TOPRIGHT", "TOPRIGHT", -8, -84 }, -- 374 a 694, -84 a -224
    title = L["Mes macros"],
    text = L["Tes macros du jeu : ouvre-les en blocs, associe-leur une touche, exporte-les en texte ou envoie-les à un joueur. À droite, sauvegarde toutes tes macros d'un coup pour les restaurer plus tard."] },
  { tab = "settings", anchor = W("settings"), at = { "BOTTOMRIGHT", "BOTTOMRIGHT", -16, 16 }, -- 548 a 868, -410 a -550
    title = L["Paramètres et diagnostic"],
    text = L["Règle ici la fenêtre, le bouton de minicarte et la création des macros. Pour revoir cette visite : « Revoir le tutoriel » ou /bf tuto. En cas de souci, /bf test contrôle l'add-on dans le jeu."] },
}

local Tutorial = {}
ns.Tutorial = Tutorial
local coach, frame, switching

local function Show(i)
  local steps = Tutorial.steps
  local s = steps[i]
  switching = true
  ns.ed.ShowTab(s.tab)
  switching = false
  local anchor = s.anchor()
  if not anchor then return Tutorial.Stop() end -- onglet qui n'a pas pu se construire
  Tutorial.step = i
  coach.title:SetText(s.title)
  coach.text:SetText(type(s.text) == "function" and s.text() or s.text)
  coach.count:SetText(("%d / %d"):format(i, #steps))
  coach:ClearAllPoints()
  coach:SetPoint(s.at[1], anchor, s.at[2], s.at[3], s.at[4])
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", -2, 2)
  frame:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 2, -2)
  if i > 1 then coach.prev:Enable() else coach.prev:Disable() end
  coach.next:SetText(i == #steps and L["Terminer"] or L["Suivant"])
  coach:Show()
  frame:Show()
end

local function Build()
  local ui, main = ns.ui, ns.ed.w.main
  -- 320 x 140 : texte de -28 a -106, boutons de -110 a -132 (precedent 8-92, compteur 100-146, passer 152-222, suivant 228-312)
  coach = ui.Panel(main, 320, 140, " ")
  coach:SetFrameStrata("DIALOG")
  coach:EnableMouse(true) -- seul le panneau arrete les clics : le reste de la fenetre reste utilisable
  coach.text = ui.Label(coach, "", 10, -28, "GameFontHighlightSmall")
  coach.text:SetSize(300, 78)
  coach.text:SetJustifyV("TOP")
  coach.prev = ui.Button(coach, L["Précédent"], 84, function() Show(Tutorial.step - 1) end)
  coach.prev:SetPoint("BOTTOMLEFT", 8, 8)
  coach.count = coach:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  coach.count:SetPoint("BOTTOMLEFT", 100, 13)
  coach.next = ui.Button(coach, L["Suivant"], 84, function()
    if Tutorial.step >= #Tutorial.steps then Tutorial.Stop() else Show(Tutorial.step + 1) end
  end)
  coach.next:SetPoint("BOTTOMRIGHT", -8, 8)
  coach.skip = ui.Button(coach, L["Passer"], 70, function() Tutorial.Stop() end)
  coach.skip:SetPoint("RIGHT", coach.next, "LEFT", -6, 0)
  T.Watch(function() ui.Tint(coach.next, T.accent, 0.9) end)

  -- cadre de 2 px autour du widget explique ; sans souris, il ne gene aucun clic
  frame = CreateFrame("Frame", nil, main)
  frame:SetFrameStrata("DIALOG")
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local line = T.Accent(frame:CreateTexture(nil, "OVERLAY"))
    local vertical = side == "LEFT" or side == "RIGHT"
    line:SetPoint(vertical and ("TOP" .. side) or (side .. "LEFT"))
    line:SetPoint(vertical and ("BOTTOM" .. side) or (side .. "RIGHT"))
    if vertical then line:SetWidth(2) else line:SetHeight(2) end
  end

  local events = CreateFrame("Frame")
  events:RegisterEvent("PLAYER_REGEN_DISABLED")
  events:SetScript("OnEvent", function() Tutorial.Stop() end)
  Tutorial.coach, Tutorial.frame = coach, frame
end

-- manual : demandee par le joueur (bouton, /bf tuto) ; sinon premiere ouverture de la fenetre
function Tutorial.Start(manual)
  if InCombatLockdown() then
    if manual then ns.Msg(L["Pas de visite guidée en combat."]) end
    return
  end
  ns.Open()
  -- le grimoire couvrirait la palette, l'Assistant tout l'editeur
  if ns.HideGrimoire then ns.HideGrimoire() end
  ns.HidePanels()
  if not coach then Build() end
  ns.db.tutorialSeen = true
  Tutorial.steps = {}
  for _, s in ipairs(ns.TutorialSteps) do
    local on = not s.feature or ns.Enabled(s.feature)
    for i, feature in ipairs(s.any or {}) do
      if ns.Enabled(feature) then break end
      if i == #s.any then on = false end
    end
    if on then Tutorial.steps[#Tutorial.steps + 1] = s end
  end
  Show(1)
end

function Tutorial.Stop()
  Tutorial.step = nil
  if coach then
    coach:Hide()
    frame:Hide()
  end
end

-- appele par UI.lua a chaque changement d'onglet demande
function Tutorial.OnTab(tab)
  local s = Tutorial.step and Tutorial.steps[Tutorial.step]
  if s and not switching and tab ~= s.tab then Tutorial.Stop() end
end
