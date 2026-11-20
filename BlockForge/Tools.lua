-- BlockForge : outils de l'editeur (annuler / retablir, texte libre, menu « Plus… ») et petite fenetre de saisie.
-- Charge apres UI.lua : tout passe par ns.ed (l'editeur) et ns.ui (les constructeurs), sans variable locale de UI.lua.
local ADDON, ns = ...
local L = ns.L
local T = ns.Theme

---------------------------------------------------------------------------
-- Saisie d'une ligne (nom d'un joueur, nouveau nom d'un modele) : un seul panneau, reutilise
-- shortcut: pas de StaticPopup a champ de saisie, dont l'acces au champ change d'un client a l'autre
---------------------------------------------------------------------------
-- onAccept(texte sans espaces autour) : appele aussi pour un texte vide
function ns.Prompt(title, text, maxLetters, acceptLabel, onAccept)
  local ui = ns.ui
  local p = ns.prompt
  if not p then
    -- 320 x 96 : champ de 18 a 304 a -34, boutons de 14 a 154 et de 166 a 306, de -64 a -86
    p = ui.Panel(ns.ed.w.main, 320, 96, " ")
    p:SetPoint("CENTER")
    p:SetFrameStrata("FULLSCREEN_DIALOG")
    p:EnableMouse(true) -- le fond arrete les clics
    p.box = ui.Edit(p, 286, function() end)
    p.box:SetPoint("TOPLEFT", 18, -34)
    local function Accept()
      local value, fn = ns.trim(p.box:GetText()), p.onAccept
      p:Hide()
      if fn then fn(value) end
    end
    p.box:SetScript("OnEnterPressed", Accept)
    p.box:SetScript("OnEscapePressed", function() p:Hide() end)
    p.ok = ui.Button(p, "", 140, Accept)
    p.ok:SetPoint("TOPLEFT", 14, -64)
    local close = ui.Button(p, L["Fermer"], 140, function() p:Hide() end)
    close:SetPoint("LEFT", p.ok, "RIGHT", 12, 0)
    ns.prompt = p
  end
  p.title:SetText(title)
  p.onAccept = onAccept
  p.ok:SetText(acceptLabel)
  p.box:SetMaxLetters(maxLetters)
  p.box:SetText(text or "")
  p:Show()
  p.box:SetFocus()
  p.box:HighlightText()
end

---------------------------------------------------------------------------
-- Annuler / Retablir : boutons en bas de la zone de construction, Ctrl+Z / Ctrl+Y
---------------------------------------------------------------------------
local function BuildUndo(view)
  local ui, w = ns.ui, view.w
  -- « Modeles » va de 8 a 108 : annuler de 112 a 178, retablir de 182 a 248 ; l'indicateur de defilement (aligne a 406) commence apres 264
  local undo = ui.Button(w.canvas, L["Annuler"], 66, function() view.Step(false) end)
  undo:SetPoint("BOTTOMLEFT", 112, 8)
  local redo = ui.Button(w.canvas, L["Rétablir"], 66, function() view.Step(true) end)
  redo:SetPoint("LEFT", undo, "RIGHT", 4, 0)
  ui.Tip(undo, function() return L["Annuler"], L["Revient à l'état d'avant ta dernière modification des blocs (Ctrl+Z). Les 50 dernières sont gardées."] end)
  ui.Tip(redo, function() return L["Rétablir"], L["Refait la modification que tu viens d'annuler (Ctrl+Y)."] end)
  w.undo, w.redo = undo, redo

  -- Clavier : la touche est toujours transmise au jeu (aucun raccourci du joueur n'est avale), et un champ de saisie
  -- actif recoit la frappe avant nous. Sans SetPropagateKeyboardInput, pas de clavier du tout : boutons seulement.
  local keys = CreateFrame("Frame", nil, w.page)
  keys:SetSize(1, 1)
  keys:SetPoint("TOPLEFT")
  local function Arm()
    -- EnableKeyboard et SetPropagateKeyboardInput sont proteges en combat : on attend la fin du combat
    if view.keys or InCombatLockdown() or not (keys.SetPropagateKeyboardInput and IsControlKeyDown) then return end
    keys:SetPropagateKeyboardInput(true)
    keys:EnableKeyboard(true)
    keys:SetScript("OnKeyDown", function(_, key)
      if not IsControlKeyDown() or (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()) then return end
      if key == "Z" then view.Step(false) elseif key == "Y" then view.Step(true) end
    end)
    view.keys = keys
  end
  keys:RegisterEvent("PLAYER_REGEN_ENABLED")
  keys:SetScript("OnEvent", Arm)
  keys:SetScript("OnShow", Arm)
  Arm()
end

---------------------------------------------------------------------------
-- Texte libre : l'apercu devient un champ de saisie ; le texte tape est relu en blocs
---------------------------------------------------------------------------
local function BuildTextMode(view)
  local ui, w = ns.ui, view.w
  local scroll = CreateFrame("ScrollFrame", nil, w.bottom)
  local box = CreateFrame("EditBox", nil, scroll)
  scroll:Hide()
  if not (box.SetMultiLine and scroll.SetScrollChild) then return end -- pas de champ sur plusieurs lignes : l'apercu reste seul

  -- meme place que l'apercu : 364 x 86 a (10, -38) ; le champ defile dans ce cadre au lieu de deborder du panneau
  scroll:SetPoint("TOPLEFT", 10, -38)
  scroll:SetSize(364, 86)
  local bg = scroll:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(1, 1, 1, 0.06)
  box:SetMultiLine(true)
  box:SetAutoFocus(false)
  box:SetFontObject(BlockForgeCodeFont)
  box:SetWidth(364)
  box:SetMaxLetters(1000) -- au-dela de 255 le compteur passe au rouge ; 1000 borne un collage enorme
  scroll:SetScrollChild(box)

  -- relu apres une pause ou a la perte du focus, pas a chaque touche : le champ garde son texte et son curseur
  -- view.dirty : du texte tape n'a pas encore ete relu
  local idle = 0
  function view.Commit()
    if not view.dirty then return end
    view.dirty = false
    view.typing = "text"
    view.SetBlocks(ns.Parse(box:GetText()))
    view.typing = nil
  end
  box:SetScript("OnTextChanged", function(self, user)
    if not user then return end
    view.dirty, idle = true, 0
    view.Count(#ns.trim(self:GetText()))
  end)
  box:SetScript("OnUpdate", function(_, elapsed)
    if not view.dirty then return end
    idle = idle + elapsed
    -- la souris quitte le champ : relu tout de suite, avant un clic sur un bloc (un clic ne retire pas le focus du champ)
    if idle > 0.8 or not scroll:IsMouseOver() then view.Commit() end
  end)
  box:SetScript("OnEditFocusLost", function(self)
    view.Commit()
    view.history.tag = nil
    self:SetText(ns.Compile(view.Blocks())) -- texte remis au propre (espaces, lignes vides)
  end)
  box:SetScript("OnEscapePressed", box.ClearFocus)
  -- le cadre suit le curseur (y negatif depuis le haut du champ)
  box:SetScript("OnCursorChanged", function(_, _, y, _, height)
    local top, at = -y, scroll:GetVerticalScroll() or 0
    if top < at then scroll:SetVerticalScroll(top)
    elseif top + height > at + 86 then scroll:SetVerticalScroll(top + height - 86) end
  end)
  scroll:EnableMouse(true)
  scroll:SetScript("OnMouseDown", function() box:SetFocus() end) -- clic sous la derniere ligne
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local max = math.max(0, (box:GetHeight() or 0) - 86)
    self:SetVerticalScroll(math.max(0, math.min(max, (self:GetVerticalScroll() or 0) - delta * 26)))
  end)

  -- Bascule dans le bandeau : « Simuler » va de 74 a 154, celle-ci de 158 a 258, le compteur commence apres 340
  local toggle = ui.Chip(w.bottom, 100, 16)
  toggle:SetPoint("TOPLEFT", 158, -5)
  toggle.text:SetText(L["Éditer le texte"])
  local function Sync()
    ui.Tint(toggle, view.textMode and T.accent or T.grey, view.textMode and 0.95 or 0.7)
    scroll:SetShown(view.textMode == true)
    w.preview:SetShown(not view.textMode)
  end
  toggle:SetScript("OnClick", function()
    view.Commit()
    box:ClearFocus()
    view.textMode = not view.textMode
    if view.textMode then box:SetText(ns.Compile(view.Blocks())) end
    Sync()
  end)
  ui.Tip(toggle, function()
    return L["Éditer le texte"],
      L["Tape ou colle la macro à la main à la place de l'aperçu. Les blocs suivent après une courte pause ; une ligne que l'éditeur ne connaît pas est gardée telle quelle."]
  end)
  T.Watch(Sync)
  w.textToggle, w.textBox = toggle, box
end

---------------------------------------------------------------------------
-- « Plus… » : actions secondaires de l'editeur, dans une liste au-dessus du bouton
---------------------------------------------------------------------------
local function BuildMore(view)
  local ui, w = ns.ui, view.w
  local items = {
    { L["Ajouter à ma bibliothèque"], L["Garde cette macro dans « Mes modèles » (onglet Bibliothèque), pour tous tes personnages."],
      function() ns.AddPersonal(view.Name(), ns.Compile(view.Blocks()), view.icon) end },
  }
  if ns.CanShare and ns.CanShare() then
    items[2] = { L["Envoyer à…"], L["Envoie cette macro à un autre joueur qui a BlockForge. Il choisit de l'ouvrir ou non ; rien n'est enregistré chez lui sans son accord."],
      function() ns.SendPrompt(view.Name(), ns.Compile(view.Blocks())) end, "share" }
  end
  -- bouton de 814 a 876 sur la ligne des boutons (-58) ; liste de 216 de large, de 660 a 876, entre -56 et 0
  local menu = ui.Panel(w.bottom, 216, 12 + #items * 22)
  local more = ui.Button(w.bottom, L["Plus…"], 62, function() menu:SetShown(not menu:IsShown()) end)
  more:SetPoint("LEFT", w.reset, "RIGHT", 4, 0)
  ui.Tip(more, function() return L["Plus…"], L["Garder la macro dans ta bibliothèque, ou l'envoyer à un autre joueur."] end)
  menu:SetPoint("BOTTOMRIGHT", more, "TOPRIGHT", 0, 2)
  menu:SetFrameStrata("DIALOG")
  menu:EnableMouse(true) -- le fond arrete les clics
  menu:Hide()
  for i, item in ipairs(items) do
    local chip = ui.Chip(menu, 200, 20)
    chip:SetPoint("TOPLEFT", 8, -6 - (i - 1) * 22)
    chip.text:SetText(item[1])
    T.Watch(function() ui.Tint(chip, T.accent, 0.45) end)
    chip:SetScript("OnClick", function()
      menu:Hide()
      item[3]()
    end)
    ui.Tip(chip, function() return item[1], item[2] end)
    -- item[4] : fonction que le joueur peut couper dans les Parametres
    if item[4] then ns.OnFeatures(function() chip:SetShown(ns.Enabled(item[4])) end, true) end
  end
  w.bottom:HookScript("OnHide", function() menu:Hide() end)
  w.more = more
end

-- appele par UI.lua a la fin de la construction de l'editeur
function ns.BuildEditorTools()
  local view = ns.ed
  BuildUndo(view)
  BuildTextMode(view)
  BuildMore(view)
  function view.OnRefresh(text)
    local h, w = view.history, view.w
    if h:CanUndo() then w.undo:Enable() else w.undo:Disable() end
    if h:CanRedo() then w.redo:Enable() else w.redo:Disable() end
    -- les blocs ont change ailleurs que dans le champ (clic, annuler...) : le champ suit, meme s'il a le focus
    if view.textMode and view.typing ~= "text" and not view.dirty then w.textBox:SetText(text) end
  end
end
