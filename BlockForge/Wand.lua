-- BlockForge : « Ameliorer ma barre ». Notre propre image des barres d'action (les boutons du jeu ne sont pas touches) :
-- un clic sur un sort ouvre ses recettes dans l'Assistant, qui pose la macro choisie a la meme place.
-- Charge apres Bars.lua et Assistant.lua.
local ADDON, ns = ...
local L = ns.L
local T = ns.Theme

local COLS, CELL, STEP = 12, 34, 36
local PREVIEW_ROWS = 12
local KIND = {
  spell = L["Sort : clic pour choisir sa macro."], item = L["Objet : clic pour choisir sa macro."],
  macro = L["Macro : clic pour l'ouvrir dans l'éditeur."], empty = L["Emplacement vide."],
  other = L["Autre type d'action (monture, familier, ensemble…) : BlockForge n'y touche pas."],
}

local panel
-- scan : dernier releve des barres ; plan : conversion en masse en attente de confirmation ; offset : defilement de l'apercu
local state = { scan = {}, offset = 0 }

-- touche en peu de lettres : la case fait 34 px
local function KeyText(key)
  if not key then return "" end
  return (key:gsub("SHIFT%-", "s-"):gsub("CTRL%-", "c-"):gsub("ALT%-", "a-"):gsub("NUMPAD", "n"):gsub("BUTTON", "b")):sub(1, 5)
end

local function RenderPlan()
  local ui, plan = ns.ui, state.plan
  local lines = {}
  for _, item in ipairs(plan and plan.items or {}) do
    lines[#lines + 1] = L["%d : %s  ->  macro « %s »"]:format(item.slot, ns.Plain(item.spell), ns.Plain(item.macroName))
  end
  for _, item in ipairs(plan and plan.skipped or {}) do
    lines[#lines + 1] = "|cff999999" .. (item.skip == "long" and L["%d : %s — laissé (macro trop longue)"]:format(item.slot, ns.Plain(item.spell))
      or L["%d : %s — laissé (une autre macro s'appelle « %s »)"]:format(item.slot, ns.Plain(item.spell), ns.Plain(item.macroName))) .. "|r"
  end
  state.offset = math.max(0, math.min(state.offset, #lines - PREVIEW_ROWS))
  for i, row in ipairs(panel.rows) do
    row:SetText(lines[state.offset + i] or "")
  end
  local n, free = plan and #plan.items or 0, ns.Bars.FreeMacros()
  local enough = plan ~= nil and plan.need <= free
  panel.previewTitle:SetText(not plan and "" or n == 0 and L["Aucun sort de ce type à convertir sur tes barres."]
    or L["Aperçu : %d emplacement(s) à convertir"]:format(n))
  panel.need:SetText(plan and L["Macros à créer : %d · places libres : %d"]:format(plan.need, free) or "")
  panel.need:SetTextColor(1, enough and 1 or 0.3, enough and 1 or 0.3)
  panel.confirm:SetText(L["Convertir (%d)"]:format(n))
  panel.confirm:SetShown(plan ~= nil)
  panel.cancel:SetShown(plan ~= nil)
  if enough and n > 0 then panel.confirm:Enable() else panel.confirm:Disable() end
  local label = ns.UndoLabel()
  panel.undo:SetText(label and L["Annuler : %s"]:format(ns.Plain(label)) or L["Rien à annuler"])
  if label then panel.undo:Enable() else panel.undo:Disable() end
end

local function Refresh()
  if InCombatLockdown() then return end -- les barres ne se lisent et ne se changent que hors combat
  local scan, stats = ns.Bars.Scan()
  state.scan, state.stats = scan or {}, stats
  local bySlot = {}
  for _, e in ipairs(state.scan) do bySlot[e.slot] = e end
  for _, cell in ipairs(panel.cells) do
    local e = bySlot[cell.slot]
    cell.entry = e
    local kind = e and e.kind or "empty"
    if kind == "empty" then
      cell.icon:SetColorTexture(0.12, 0.12, 0.14, 1)
    else
      cell.icon:SetTexture(e.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    end
    cell:SetAlpha(kind == "empty" and 0.35 or kind == "other" and 0.6 or 1)
    cell.key:SetText(KeyText(e and e.key))
    local c = kind == "macro" and T.accent or T.grey -- deja une macro : bordure a la couleur d'accent
    cell:SetBackdropBorderColor(c[1], c[2], c[3], 1)
  end
  RenderPlan()
end

-- want : "help" ou "harm" ; la recette « survol » de l'Assistant, avec ses options par defaut
local function Plan(want)
  if ns.Off("bars") then return end
  if InCombatLockdown() then return ns.Msg(L["Impossible de modifier une macro en combat."]) end
  local recipe
  for _, r in ipairs(ns.Recipes) do
    if r.id == "mouseover_" .. want then recipe = r end
  end
  local options = { kind = want, showtooltip = true, nodead = true, stopattack = false }
  Refresh()
  state.plan = ns.BulkPlan(state.scan, want, ns.ReadMacros(), {
    kind = ns.SpellKind, cast = ns.Bars.CastName,
    build = function(name) return recipe.build(name, options) end,
  })
  state.plan.want, state.offset = want, 0
  panel.status:SetText("")
  RenderPlan()
end

local function OnSlot(cell)
  local e = cell.entry
  if InCombatLockdown() then return ns.Msg(L["Impossible de modifier une macro en combat."]) end
  if not e then return end
  if e.kind == "spell" or e.kind == "item" then
    local entry = { name = e.name, base = e.name, icon = e.icon, kind = e.kind }
    if e.kind == "spell" then
      local cast, tag = ns.Bars.CastName(e)
      entry.name, entry.macroName = cast, ns.MacroName(e.name, 16 - #tag) .. tag
    end
    return ns.OpenAssistant(entry, e.slot)
  end
  if e.kind == "macro" and e.macroIndex then
    local name, icon, body = GetMacroInfo(e.macroIndex)
    if name and ns.ed.Load(name, body, icon) then return ns.Open("editor") end
  end
  panel.status:SetText(e.kind == "macro" and L["BlockForge n'a pas su dire quelle macro est dans cet emplacement."] or KIND[e.kind])
end

local function BuildCell(slot, row, col)
  local ui = ns.ui
  local cell = ui.IconButton(panel)
  cell:SetSize(CELL, CELL)
  cell:SetPoint("TOPLEFT", 68 + col * STEP, -46 - row * STEP)
  cell.slot = slot
  -- touche en haut a droite, sur l'icone
  cell.key = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  cell.key:SetPoint("TOPRIGHT", -2, -2)
  cell.key:SetWidth(CELL - 4)
  cell.key:SetJustifyH("RIGHT")
  cell.key:SetWordWrap(false)
  cell:SetScript("OnClick", OnSlot)
  ui.Tip(cell, function()
    local e = cell.entry
    if not e then return end
    return e.name and L["Emplacement %d : %s"]:format(e.slot, ns.Plain(e.name)) or L["Emplacement %d"]:format(e.slot),
      e.kind == "macro" and not e.macroIndex and L["BlockForge n'a pas su dire quelle macro est dans cet emplacement."] or KIND[e.kind],
      e.key and L["Touche : %s"]:format(e.key) or nil
  end)
  return cell
end

local function Build()
  local ui, page = ns.ui, ns.ed.w.home
  -- 884 x 566 : toute la page d'accueil. Numeros de 8 a 62, grille de 68 a 498 (12 cases de 34 tous les 36),
  -- lignes de -46 a -512 au plus (13 lignes) ; a droite, de 512 a 876 : conversions en masse et annulation.
  panel = ui.Panel(page, 884, 566, L["Améliorer ma barre"])
  panel:SetPoint("TOPLEFT")
  panel:SetBackdropColor(T.panel[1], T.panel[2], T.panel[3], 1)
  panel:SetFrameStrata("DIALOG")
  panel:SetFrameLevel((page:GetFrameLevel() or 0) + 10)
  panel:EnableMouse(true) -- le fond arrete les clics
  panel:Hide()
  ns.CloseChip(panel)

  local hint = ui.Label(panel, L["Tes barres d'action, emplacement par emplacement. Les cases estompées sont vides."], 8, -28, "GameFontDisableSmall")
  hint:SetWidth(490)
  hint:SetWordWrap(false)
  panel.cells = {}
  for i, slot in ipairs(ns.Bars.Slots()) do
    local row, col = math.floor((i - 1) / COLS), (i - 1) % COLS
    if col == 0 then
      local label = ui.Label(panel, ("%d-%d"):format(slot, slot + COLS - 1), 8, -57 - row * STEP, "GameFontDisableSmall")
      label:SetWidth(54)
      label:SetJustifyH("RIGHT")
    end
    panel.cells[i] = BuildCell(slot, row, col)
  end
  -- sous la grille, de -520 a -544 : ce qui vient de se passer
  panel.status = ui.Label(panel, "", 8, -520, "GameFontHighlightSmall")
  panel.status:SetWidth(490)

  local intro = ui.Label(panel, L["Clique sur un sort ou un objet de tes barres : l'Assistant propose ses macros, et celle que tu choisis prend sa place, au même endroit. Un clic sur une macro l'ouvre dans l'éditeur. Tout se défait avec « Annuler », en bas."],
    512, -28, "GameFontHighlightSmall")
  intro:SetWidth(364) -- de -28 a -76 au plus (4 lignes)
  local help = ui.Button(panel, L["Passer mes sorts d'aide au survol"], 364, function() Plan("help") end)
  help:SetPoint("TOPLEFT", 512, -82)
  ui.Tip(help, function()
    return L["Passer mes sorts d'aide au survol"], L["Chaque sort d'aide de tes barres devient une macro « survol, sinon cible, sinon moi », à la même place. Tu vois la liste avant de confirmer."]
  end)
  local harm = ui.Button(panel, L["Passer mes sorts offensifs au survol"], 364, function() Plan("harm") end)
  harm:SetPoint("TOPLEFT", 512, -108)
  ui.Tip(harm, function()
    return L["Passer mes sorts offensifs au survol"], L["Chaque sort offensif de tes barres devient une macro « survol, sinon cible », à la même place. Tu vois la liste avant de confirmer."]
  end)

  -- Apercu : titre a -140, 12 lignes de 14 px tous les 16 de -158 a -348, compte a -354, boutons de -372 a -394
  panel.previewTitle = T.AccentText(ui.Label(panel, "", 512, -140, "GameFontNormal"))
  panel.previewTitle:SetWidth(364)
  panel.previewTitle:SetWordWrap(false)
  local preview = CreateFrame("Frame", nil, panel)
  preview:SetPoint("TOPLEFT", 512, -158)
  preview:SetSize(364, 190)
  preview:EnableMouseWheel(true)
  preview:SetScript("OnMouseWheel", function(_, delta)
    state.offset = state.offset - delta * 3
    RenderPlan()
  end)
  panel.rows = {}
  for i = 1, PREVIEW_ROWS do
    local row = ui.Label(preview, "", 0, -(i - 1) * 16, "GameFontHighlightSmall")
    row:SetWidth(364)
    row:SetWordWrap(false)
    panel.rows[i] = row
  end
  panel.need = ui.Label(panel, "", 512, -354, "GameFontHighlightSmall")
  panel.need:SetWidth(364)
  panel.confirm = ui.Button(panel, "", 178, function()
    local plan = state.plan
    if not plan then return end
    local placed, failed = ns.Bars.Convert(plan, plan.want == "help" and L["sorts d'aide au survol"] or L["sorts offensifs au survol"])
    if not placed then return end -- refuse (combat, place) : l'apercu reste
    state.plan = nil
    panel.status:SetText(L["%d emplacement(s) converti(s), %d laissé(s) tel(s) quel(s). « Annuler » remet tout comme avant."]:format(placed, failed))
    Refresh()
  end)
  panel.confirm:SetPoint("TOPLEFT", 512, -372)
  T.Watch(function() ui.Tint(panel.confirm, T.accent, 0.9) end)
  panel.cancel = ui.Button(panel, L["Fermer l'aperçu"], 178, function()
    state.plan = nil
    RenderPlan()
  end)
  panel.cancel:SetPoint("TOPLEFT", 698, -372)

  -- annulation de la derniere operation (meme apres un /reload) : de 512 a 876, de -536 a -558
  panel.undo = ui.Button(panel, "", 364, function()
    if ns.RunUndo() then panel.status:SetText("") end
    Refresh()
  end)
  panel.undo:SetPoint("BOTTOMRIGHT", -8, 8)
  ui.Tip(panel.undo, function()
    return L["Annuler la dernière opération"], L["Remet les emplacements comme avant et supprime les macros que l'opération avait créées. Un emplacement que tu as changé depuis n'est pas touché."]
  end)

  panel:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then return self:Hide() end
    if self:IsVisible() then Refresh() end
  end)
  page:HookScript("OnHide", function() panel:Hide() end)
  panel.state, panel.Refresh = state, Refresh
  ns.wand = panel
  ns.OnFeatures(function()
    local on = ns.Enabled("bars")
    ns.Listen(panel, on, "ACTIONBAR_SLOT_CHANGED", "UPDATE_MACROS", "PLAYER_REGEN_DISABLED")
    if not on then panel:Hide() end
  end, true)
  T.OnChange(function() if not InCombatLockdown() then Refresh() end end)
end

function ns.OpenWand()
  if ns.Off("bars") then return end
  if InCombatLockdown() then return ns.Msg(L["Impossible de modifier une macro en combat."]) end
  if not ns.Bars.Ready() then return ns.Msg(L["Ce client ne laisse pas BlockForge lire les barres d'action."]) end
  ns.Open("home")
  if ns.Tutorial then ns.Tutorial.Stop() end -- le panneau de la visite passerait dessous
  if not ns.ed.w.home then return end -- l'accueil n'a pas pu se construire
  if not panel then Build() end
  ns.HidePanels()
  state.plan = nil
  Refresh()
  panel:Show()
end
