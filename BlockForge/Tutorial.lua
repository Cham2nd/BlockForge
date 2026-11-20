-- BlockForge : visite guidee. Un petit panneau non bloquant, pose a cote du widget explique, qu'un cadre entoure.
local ADDON, ns = ...
local L = ns.L
local T = ns.Theme

local function W(key) return function() return ns.ed.w[key] end end

-- Etapes : onglet, widget explique, position du panneau { son point, point du widget, x, y }, titre, texte.
-- Le panneau fait 320 x 140. Positions calculees dans la page de 884 x 570 (fenetre de 900 x 640) :
--   blocs 0-160, zone 166-582, reglages 588-884 (hauteur 430) ; apercu en dessous, de -436 a -566.
ns.TutorialSteps = {
  { tab = "editor", anchor = W("palette"), at = { "TOPLEFT", "TOPRIGHT", 8, -40 }, -- 168 a 488, -40 a -180
    title = L["Les blocs"],
    text = L["Chaque bloc est une ligne de macro : lancer un sort, utiliser un objet, donner un ordre au familier… Clique sur un bloc pour l'ajouter à ta macro, ou glisse-le à l'endroit voulu."] },
  { tab = "editor", anchor = W("canvas"), at = { "BOTTOMLEFT", "BOTTOMLEFT", 40, 40 }, -- 206 a 526, -250 a -390
    title = L["Ta macro"],
    text = L["Les blocs s'empilent ici, dans l'ordre où le jeu les lit. Glisse une ligne pour la déplacer ; « x2 » la duplique, « x » la supprime. Tu peux aussi déposer ici un sort du grimoire ou un objet des sacs."] },
  { tab = "editor", anchor = W("insp"), at = { "TOPRIGHT", "TOPLEFT", -8, -40 }, -- 260 a 580, -40 a -180
    title = L["Les conditions"],
    text = L["Clique sur un bloc, puis règle-le ici : son sort et ses conditions (cible survolée, focus, touche maintenue, combat…). Le « + » ajoute une alternative, essayée quand la précédente ne s'applique pas."] },
  { tab = "editor", anchor = W("preview"), at = { "BOTTOMLEFT", "TOPLEFT", 0, 40 }, -- 10 a 330, -294 a -434
    title = L["Aperçu et simulateur"],
    text = L["Le texte de la macro s'écrit tout seul, avec son compteur : 255 caractères au plus. « Simuler » montre quelle ligne partirait ; « Éditer le texte » te laisse taper la macro à la main."] },
  { tab = "editor", anchor = W("action"), at = { "BOTTOMLEFT", "TOPLEFT", 0, 42 }, -- 386 a 706, -294 a -434
    title = L["Le bouton d'action"],
    text = L["Voici l'icône et le nom qu'aura la macro sur une barre d'action. Clique dessus pour choisir une autre icône, ou laisse le jeu la choisir."] },
  { tab = "editor", anchor = W("save"), at = { "BOTTOMLEFT", "TOPLEFT", 0, 60 }, -- 450 a 770, -294 a -434
    title = L["Nommer et enregistrer"],
    text = L["Donne un nom (16 caractères au plus), puis « Créer / mettre à jour » : c'est une vraie macro du jeu, qui vient sous ton curseur. Pose-la sur une barre d'action. « Plus… » la garde dans ta bibliothèque ou l'envoie à un joueur."] },
  { tab = "editor", anchor = W("templates"), at = { "BOTTOMLEFT", "TOPRIGHT", 126, 8 }, -- 400 a 720, -252 a -392
    title = L["Les modèles"],
    text = L["Pas d'idée ? Pars d'un modèle (familier, PvP), puis glisse tes sorts sur les blocs marqués « (argument ?) ». À côté, « Annuler » et « Rétablir » reviennent sur tes dernières modifications."] },
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
  local steps = ns.TutorialSteps
  local s = steps[i]
  switching = true
  ns.ed.ShowTab(s.tab)
  switching = false
  local anchor = s.anchor()
  if not anchor then return Tutorial.Stop() end -- onglet qui n'a pas pu se construire
  Tutorial.step = i
  coach.title:SetText(s.title)
  coach.text:SetText(s.text)
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
    if Tutorial.step >= #ns.TutorialSteps then Tutorial.Stop() else Show(Tutorial.step + 1) end
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
  if not coach then Build() end
  ns.db.tutorialSeen = true
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
  local s = Tutorial.step and ns.TutorialSteps[Tutorial.step]
  if s and not switching and tab ~= s.tab then Tutorial.Stop() end
end
