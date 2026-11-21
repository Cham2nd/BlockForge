-- BlockForge : Assistant. Un sort choisi a gauche, ses recettes (ns.Recipes, Core.lua) en cartes a droite, creees en un clic.
-- Charge apres Grimoire.lua, dont il reprend la grille.
local ADDON, ns = ...
local L = ns.L
local T = ns.Theme

local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local CARDS = 4 -- cartes visibles ; la molette fait defiler les autres

local OPTIONS = {
  { key = "showtooltip", label = "#showtooltip", w = 96,
    tip = L["Le bouton de la macro montre l'icône, l'infobulle et le temps de recharge du sort."] },
  { key = "nodead", label = L["Ne pas viser les morts"], w = 150,
    tip = L["Ajoute « nodead » : une unité morte est ignorée, le sort part sur la suivante."] },
  { key = "stopattack", label = L["Arrêter l'attaque avant"], w = 150,
    tip = L["Ajoute /stopattack : ton attaque automatique s'arrête avant le sort (contrôles qui se brisent aux dégâts)."] },
}
local KIND = { harm = L["Sort offensif"], help = L["Sort d'aide"], either = L["Sort offensif ou d'aide"],
               pet = L["Technique du familier"], item = L["Objet"] }
local SOURCE_OF = { spell = 1, pet = 2, item = 3 }

local panel
-- entry : sort, technique ou objet choisi ; kind : son type pour les recettes ; recipes : celles qui s'appliquent
-- slot : emplacement de barre a remplacer (« Ameliorer ma barre »), nil pour une simple creation
local state = { options = { showtooltip = true, nodead = true, stopattack = false }, recipes = {}, offset = 0 }

local function Render()
  local ui, entry = ns.ui, state.entry
  panel.title:SetText(state.slot and L["Assistant — emplacement %d de ta barre"]:format(state.slot) or L["Assistant"])
  panel.icon:SetTexture(entry and entry.icon or QUESTION)
  panel.name:SetText(entry and ns.Plain(entry.name) or L["Choisis un sort à gauche."])
  panel.kind:SetText(entry and KIND[state.kind] or "")
  panel.intro:SetShown(entry == nil and #state.recipes == 0)
  local options = { kind = state.kind }
  for _, chip in ipairs(panel.chips) do
    local on = state.options[chip.key]
    options[chip.key] = on
    ui.Tint(chip, on and T.accent or T.grey, on and 0.95 or 0.6)
    -- sans effet sur une aide ou un objet : la puce disparait
    chip:SetShown(not (chip.key == "stopattack" and (state.kind == "help" or state.kind == "item")))
  end
  local n = #state.recipes
  state.offset = math.max(0, math.min(state.offset, n - CARDS))
  local y, heading = 0, false
  panel.livingHeading:Hide()
  for i, card in ipairs(panel.cards) do
    local recipe = state.recipes[state.offset + i]
    card:SetShown(recipe ~= nil)
    if recipe then
      if recipe.feature == "living" and not heading then
        -- Le titre suit la frontiere du groupe, meme lorsque la premiere carte visible est vivante.
        panel.livingHeading:ClearAllPoints()
        panel.livingHeading:SetPoint("TOPLEFT", panel.deck, "TOPLEFT", 10, -y)
        panel.livingHeading:Show()
        y, heading = y + 18, true
      end
      card:ClearAllPoints()
      card:SetPoint("TOPLEFT", 0, -y)
      y = y + 116
      card.recipe, card.body = recipe, recipe.build(entry and entry.name, options)
      card.title:SetText(recipe.title)
      card.title:SetWidth(recipe.feature == "living" and 220 or 270)
      card.living:SetShown(recipe.feature == "living")
      card.desc:SetText(recipe.desc)
      card.code:SetText(ns.Code(ns.TokenText(card.body))) -- un jeton vivant se lit « <Potion de soin> »
      card.count:SetText(("%d / %d"):format(#card.body, ns.MAX_CHARS))
      card.create:SetText(state.slot and L["Créer et poser"] or L["Créer la macro"])
      -- un nom reste a remplacer : la macro passe par l'editeur
      if recipe.editorOnly then card.create:Disable() else card.create:Enable() end
    end
  end
  panel.range:SetText(n > CARDS and L["%d-%d / %d  (molette)"]:format(state.offset + 1, state.offset + CARDS, n) or "")
  panel.grid.picked = entry and entry.name
  panel.grid.Render()
end

-- slot : seulement quand le sort vient d'un emplacement de barre ; un autre sort choisi dans la grille quitte ce mode
local function Pick(entry, slot)
  state.entry, state.slot = entry, slot
  -- base : nom sans rang, le seul que le jeu sait classer
  state.kind = entry and (entry.kind == "spell" and ns.SpellKind(entry.base or entry.name) or entry.kind) or nil
  state.recipes, state.offset = {}, 0
  local hasPet = ns.HasPet()
  for _, standalone in ipairs({ false, true }) do
    for _, recipe in ipairs(ns.Recipes) do
      -- Recettes autonomes apres celles du sort ; feature : masquees quand la fonction est coupee.
      if (recipe.standalone == true) == standalone and (not recipe.feature or ns.Enabled(recipe.feature))
          and (standalone or (entry and recipe.applies(state.kind, hasPet))) then
        state.recipes[#state.recipes + 1] = recipe
      end
    end
  end
  Render()
end

-- Carte de 628 x 114 ; code de -46 a -111 : cinq lignes de 13 px. Titre de groupe : 18 px.
local function BuildCard(deck, i)
  local ui = ns.ui
  local card = ui.Panel(deck, 628, 114)
  card:SetPoint("TOPLEFT", 0, -(i - 1) * 116)
  card.title = T.AccentText(ui.Label(card, "", 10, -10, "GameFontNormal"))
  card.title:SetWidth(220)
  card.title:SetWordWrap(false)
  -- Etiquette de 236 a 280, avant le compteur ; aucun espace pris sur la description ni le code.
  card.living = ui.Label(card, L["vivante"], 236, -10, "GameFontDisableSmall")
  card.living:SetWidth(44)
  card.living:SetWordWrap(false)
  card.create = ui.Button(card, L["Créer la macro"], 120, function()
    local name = card.recipe.name or state.entry.macroName or ns.MacroName(state.entry.name)
    if state.slot then
      -- la macro prend la place du sort ; retour a l'image des barres, ou « Annuler » attend
      return ns.Bars.Upgrade(state.slot, name, card.body, function()
        panel:Hide()
        ns.OpenWand()
      end)
    end
    ns.ed.SaveMacro(name, card.body, ns.db.perCharDefault and true or false, nil, false)
  end)
  card.create:SetPoint("TOPRIGHT", -8, -6)
  ui.Tip(card.create, function()
    if state.slot then
      return L["Créer et poser"], L["Crée la macro et la met dans cet emplacement de ta barre, à la place du sort. « Annuler », dans « Améliorer ma barre », remet le sort. Hors combat seulement."]
    end
    return L["Créer la macro"], L["Crée tout de suite une macro du jeu au nom du sort, avec l'icône automatique. Hors combat seulement."]
  end)
  card.open = ui.Button(card, L["Ouvrir dans l'éditeur"], 150, function()
    local typed = ns.ed.Name()
    -- le contenu remplace reste a portee de « Annuler » (Ctrl+Z)
    ns.ed.Load(typed ~= "" and typed or card.recipe.name or ns.MacroName(state.entry.name), card.body)
    panel:Hide()
  end)
  card.open:SetPoint("RIGHT", card.create, "LEFT", -6, 0)
  card.count = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  card.count:SetPoint("RIGHT", card.open, "LEFT", -8, 0)
  card.count:SetWidth(52) -- de 284 a 336, apres l'etiquette vivante (fin a 280)
  card.count:SetWordWrap(false)
  card.count:SetJustifyH("RIGHT")
  card.desc = ui.Label(card, "", 10, -31, "GameFontHighlightSmall")
  card.desc:SetWidth(608)
  card.desc:SetWordWrap(false)
  card.code = ui.Label(card, "", 10, -46, "BlockForgeCodeFont")
  card.code:SetSize(608, 65)
  card.code:SetJustifyV("TOP")
  card:EnableMouse(true)
  ui.Tip(card, function()
    if ns.Enabled("explain") and card.body then return L["Expliquer"], ns.Explanation(card.body) end
  end)
  return card
end

local function Build()
  local ui, page = ns.ui, ns.ed.w.page
  -- 884 x 566 : toute la page de l'editeur. Grille de 8 a 234, trait a 240, recettes de 248 a 876.
  panel = ui.Panel(page, 884, 566, L["Assistant"])
  panel:SetPoint("TOPLEFT")
  panel:SetBackdropColor(T.panel[1], T.panel[2], T.panel[3], 1)
  panel:SetFrameStrata("DIALOG")
  panel:SetFrameLevel((page:GetFrameLevel() or 0) + 10) -- au-dessus des listes de l'editeur (modeles, icones, « Plus… »)
  panel:EnableMouse(true) -- le fond arrete les clics
  panel:Hide()
  ns.CloseChip(panel)

  -- 6 colonnes de 36 px : puces de -28 a -46, recherche de -50 a -70, 12 lignes de -74 a -528, position dessous
  panel.grid = ns.BuildSpellGrid(panel, 8, -28, 6, 12, 36, function(entry) Pick(entry) end)
  panel.grid.tip = L["Clic : affiche les macros possibles pour ce sort."]
  panel.grid.range:SetPoint("TOPRIGHT", panel.grid.frame, "BOTTOMRIGHT", 0, -6)
  local split = panel:CreateTexture(nil, "ARTWORK")
  split:SetColorTexture(1, 1, 1, 0.12)
  split:SetPoint("TOPLEFT", 240, -28)
  split:SetSize(1, 530)

  -- Sort choisi : icone de 248 a 284 (de -28 a -64), nom a droite, type dessous ; options de 472 a 876, de -46 a -64
  local iconBg = panel:CreateTexture(nil, "BORDER")
  iconBg:SetColorTexture(0, 0, 0, 1)
  iconBg:SetPoint("TOPLEFT", 248, -28)
  iconBg:SetSize(36, 36)
  panel.icon = panel:CreateTexture(nil, "ARTWORK")
  panel.icon:SetPoint("TOPLEFT", 250, -30)
  panel.icon:SetSize(32, 32)
  panel.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  panel.name = ui.Label(panel, "", 292, -27, "GameFontHighlightLarge")
  panel.name:SetWidth(584)
  panel.name:SetWordWrap(false)
  panel.kind = ui.Label(panel, "", 292, -50, "GameFontDisableSmall")
  panel.kind:SetWidth(174)
  panel.kind:SetWordWrap(false)
  panel.chips = {}
  local x = 472
  for i, option in ipairs(OPTIONS) do
    local chip = ui.Chip(panel, option.w, 18)
    chip:SetPoint("TOPLEFT", x, -46)
    x = x + option.w + 4
    chip.text:SetText(option.label)
    chip.key = option.key
    chip:SetScript("OnClick", function()
      state.options[option.key] = not state.options[option.key]
      Render()
    end)
    ui.Tip(chip, function() return option.label, option.tip end)
    panel.chips[i] = chip
  end

  -- Quatre cartes (4 * 114 + 3 * 2) et un titre (18) : 480 px, de -70 a -550.
  local deck = CreateFrame("Frame", nil, panel)
  deck:SetPoint("TOPLEFT", 248, -70)
  deck:SetSize(628, 482)
  panel.livingHeading = T.AccentText(ui.Label(deck, L["Macros vivantes"], 10, 0, "GameFontNormal"))
  panel.livingHeading:SetSize(608, 16)
  panel.livingHeading:SetWordWrap(false)
  deck:EnableMouseWheel(true)
  deck:SetScript("OnMouseWheel", function(_, delta)
    state.offset = state.offset - delta
    Render()
  end)
  panel.cards = {}
  for i = 1, CARDS do panel.cards[i] = BuildCard(deck, i) end
  panel.range = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  panel.range:SetPoint("BOTTOMRIGHT", -8, 1)
  panel.intro = ui.Label(panel, L["Choisis à gauche un sort, une technique de ton familier ou un objet : l'Assistant te propose des macros toutes faites. « Créer la macro » l'enregistre tout de suite, « Ouvrir dans l'éditeur » te laisse la retoucher."],
    258, -84, "GameFontHighlight")
  panel.intro:SetWidth(600)
  -- dans le bandeau, de 700 a 850 (la croix va de 856 a 878) : l'autre entree de « Ameliorer ma barre »
  local bars = ui.Chip(panel, 150, 16)
  bars:SetPoint("TOPRIGHT", -34, -5)
  bars.text:SetJustifyH("CENTER")
  bars.text:SetText(L["Améliorer ma barre"])
  T.Watch(function() ui.Tint(bars, T.accent, 0.6) end)
  bars:SetScript("OnClick", function()
    panel:Hide()
    ns.OpenWand()
  end)
  ui.Tip(bars, function() return L["Améliorer ma barre"], L["Remplace un sort de ta barre par sa macro, à la même place."] end)
  ns.OnFeatures(function() bars:SetShown(ns.Enabled("bars")) end, true)
  panel.deck, panel.state, panel.bars = deck, state, bars
  ns.assistant = panel
  ns.OnFeatures(function() if panel:IsShown() then Pick(state.entry, state.slot) end end)
  T.OnChange(Render)
end

-- entry (facultatif) : sort choisi dans le grimoire integre (Maj+clic), ou sort d'un emplacement de barre (slot)
function ns.OpenAssistant(entry, slot, living)
  if ns.Off("assistant") then return end
  if InCombatLockdown() then return ns.Msg(L["Impossible de modifier une macro en combat."]) end
  ns.Open("editor")
  if ns.Tutorial then ns.Tutorial.Stop() end -- le panneau de la visite passerait dessous
  if not ns.ed.w.page then return end -- l'editeur n'a pas pu se construire
  if not panel then Build() end
  ns.HideGrimoire()
  if entry then panel.grid.source = SOURCE_OF[entry.kind] or 1 end
  panel.grid.Fill()
  if ns.wand then ns.wand:Hide() end
  if entry then
    Pick(entry, slot)
  else
    if living then Pick(nil) else Pick(state.entry) end
  end
  if living then
    for i, recipe in ipairs(state.recipes) do
      if recipe.standalone then state.offset = i - 1 break end
    end
    Render()
  end
  panel:Show()
end
