-- BlockForge : expliquer, traduire et raccourcir dans l'editeur, sans ecrire de macro dans le jeu.
local ADDON, ns = ...
local L, T = ns.L, ns.Theme
for _, def in ipairs({
  { id = 'explain', label = L["Expliquer"], desc = L["Chaque ligne de macro expliquée en clair, dans l’éditeur et les détails."] },
  { id = 'translate', label = L["Traduire les sorts"], desc = L["Propose de traduire les noms de sorts collés ou importés dans la langue du jeu."] },
  { id = 'shorten', label = L["Raccourcir"], desc = L["Propose des réductions sûres et annulables, avec le gain de chaque changement."] },
}) do def.default = true ns.RegisterFeature(def) end

-- Le texte defile dans un cadre fixe ; une absence d'API laisse un apercu borne et son infobulle complete.
function ns.HelpText(parent, x, y, width, height)
  local frame = CreateFrame('ScrollFrame', nil, parent)
  frame:SetPoint('TOPLEFT', x, y)
  frame:SetSize(width, height)
  local child = CreateFrame('Frame', nil, frame)
  child:SetSize(width, height)
  local label = ns.ui.Label(child, '', 0, 0, 'GameFontHighlightSmall')
  label:SetWidth(width - 8)
  label:SetJustifyV('TOP')
  local scrollable = frame.SetScrollChild and frame.SetVerticalScroll and frame.GetVerticalScroll
  if scrollable then frame:SetScrollChild(child) else label:SetHeight(height) end
  frame:EnableMouse(true)
  frame:EnableMouseWheel(true)
  frame:SetScript('OnMouseWheel', function(_, delta)
    if scrollable then frame:SetVerticalScroll(math.max(0, math.min(frame.max or 0, (frame:GetVerticalScroll() or 0) - delta * 28))) end
  end)
  ns.ui.Tip(frame, function() return L["Expliquer"], frame.full end)
  function frame:SetContent(text)
    self.full = text
    label:SetText(text)
    local measured = label.GetStringHeight and label:GetStringHeight()
    local size = type(measured) == 'number' and measured or (14 * (1 + #text / math.max(1, (width - 8) / 7)))
    child:SetHeight(math.max(height, size))
    self.max = math.max(0, size - height)
    if scrollable then frame:SetVerticalScroll(0) end
  end
  frame.label = label
  return frame
end

function ns.Explanation(text)
  return ns.Plain(table.concat(ns.Explain(text, L), '\n'))
end

function ns.BuildDetailExplanation(parent, body, x, y, width, height, fullHeight)
  local explanation = ns.HelpText(parent, x, y, width, height)
  function explanation:Update(text)
    self.body = text or ''
    local on = ns.Enabled('explain')
    self:SetShown(on and self.body ~= '')
    body:SetHeight(on and fullHeight - height - 10 or fullHeight)
    if on then self:SetContent(ns.Explanation(self.body)) end
  end
  ns.OnFeatures(function() explanation:Update(explanation.body) end, true)
  return explanation
end

function ns.EditorText()
  local view = ns.ed
  if view.textMode and view.dirty and view.w.textBox then return view.w.textBox:GetText() end
  return ns.Compile(view.Blocks())
end

function ns.ApplyEditorText(text)
  if InCombatLockdown() then return ns.Msg(L["Impossible de modifier une macro en combat."]) end
  if ns.ed.Commit then ns.ed.Commit() end
  ns.ed.history.tag = nil
  ns.ed.SetBlocks(ns.Parse(text, true))
  return true
end

function ns.TranslatedText(text)
  if InCombatLockdown() then return text, 0 end
  return ns.Translate(text, (C_Spell and C_Spell.GetSpellName) or GetSpellInfo, RANK)
end

function ns.TranslateEditor()
  if ns.Off('translate') then return end
  if InCombatLockdown() then return ns.Msg(L["Impossible de modifier une macro en combat."]) end
  local text, count = ns.TranslatedText(ns.EditorText())
  if count > 0 then return ns.ApplyEditorText(text) end
  ns.Msg(L["Aucun nom de sort reconnu à traduire. Les noms absents de la table restent tels quels."])
end

function ns.OpenShorten()
  if ns.Off('shorten') then return end
  if InCombatLockdown() then return ns.Msg(L["Impossible de modifier une macro en combat."]) end
  ns.Open('editor')
  ns.HidePanels()
  local p = ns.shortenPanel
  if not p then
    p = ns.ui.Panel(ns.ed.w.main, 680, 400, L["Raccourcir"])
    p:SetPoint('CENTER')
    p:SetFrameStrata('DIALOG')
    p:EnableMouse(true)
    ns.CloseChip(p)
    p.total = ns.ui.Label(p, '', 16, -34, 'GameFontNormal')
    p.total:SetWidth(648)
    p.list = ns.HelpText(p, 16, -64, 648, 278)
    ns.ui.Tip(p.list, function() return L["Raccourcir"], p.list.full end)
    p.apply = ns.ui.Button(p, L["Appliquer"], 200, function()
      if ns.Off('shorten') then return end
      if InCombatLockdown() then return ns.Msg(L["Impossible de modifier une macro en combat."]) end
      if ns.EditorText() ~= p.before then return ns.OpenShorten() end
      if ns.ApplyEditorText(p.after) then p:Hide() end
    end)
    p.apply:SetPoint('BOTTOMLEFT', 16, 16)
    local close = ns.ui.Button(p, L["Fermer"], 200, function() p:Hide() end)
    close:SetPoint('BOTTOMRIGHT', -16, 16)
    ns.shortenPanel = p
    ns.ed.w.page:HookScript('OnHide', function() p:Hide() end)
  end
  p.before = ns.EditorText()
  local after, changes, saved = ns.Shorten(p.before)
  p.after, p.changes = after, changes
  p.total:SetText(L["%d caractères gagnés : %d → %d / 255"]:format(saved, #p.before, #after))
  local lines = {}
  for _, c in ipairs(changes) do
    lines[#lines + 1] = L["Ligne %d : −%d caractères\n%s\n→ %s"]:format(c.line, c.saved, ns.Plain(c.before), ns.Plain(c.after))
  end
  p.list:SetContent(#lines > 0 and table.concat(lines, '\n\n') or L["Aucune réduction sûre. Les rangs, les commandes et l’ordre des actions sont conservés."])
  if saved > 0 then p.apply:Enable() else p.apply:Disable() end
  p:Show()
end

function ns.BuildMacroHelp()
  local view, ui = ns.ed, ns.ui
  local w = view.w
  local explain = ui.Chip(w.bottom, 70, 16)
  explain:SetPoint('TOPLEFT', 262, -5)
  explain.text:SetText(L["Expliquer"])
  local prose = ns.HelpText(w.bottom, 10, -82, 364, 42)
  local translate = ui.Button(w.bottom, L["Traduire les sorts dans la langue du jeu"], 364, ns.TranslateEditor)
  translate:SetPoint('TOPLEFT', 10, -104)
  translate:SetHeight(20)
  ui.Tip(translate, function() return L["Traduire les sorts dans la langue du jeu"], L["Français ↔ anglais pour les sorts connus de la table. Les autres noms restent intacts. Annuler revient au texte collé."] end)
  local shorten = ui.Button(w.bottom, L["Raccourcir"], 100, ns.OpenShorten)
  shorten:SetPoint('TOPLEFT', 776, -82)
  shorten:SetHeight(18)
  local function Sync(text)
    text = text or ns.EditorText()
    local on = ns.Enabled('explain')
    explain:SetShown(on)
    if not on then view.explainMode = false end
    local show = on and view.explainMode and not view.textMode
    prose:SetShown(show and true or false)
    w.preview:SetHeight(show and 38 or 86)
    if show then prose:SetContent(ns.Explanation(text)) end
    ui.Tint(explain, show and T.accent or T.grey, 0.8)
    local translated = text
    if ns.Enabled('translate') and not InCombatLockdown() then translated = ns.TranslatedText(text) end
    local offer = translated ~= text and ns.Enabled('translate')
    translate:SetShown(offer)
    if w.textScroll then w.textScroll:SetHeight(offer and 62 or 86) end
    if offer and not view.textMode then w.preview:SetHeight(62) prose:Hide() end
    shorten:SetShown(ns.Enabled('shorten') and #text > ns.MAX_CHARS)
    w.warnText:SetWidth(ns.Enabled('shorten') and #text > ns.MAX_CHARS and 310 or 420)
  end
  explain:SetScript('OnClick', function() view.explainMode = not view.explainMode Sync() end)
  local previous = view.OnRefresh
  function view.OnRefresh(text) if previous then previous(text) end Sync(text) end
  if w.textBox then w.textBox:HookScript('OnTextChanged', function(_, user) if user then Sync(ns.EditorText()) end end) end
  if w.textToggle then w.textToggle:HookScript('OnClick', function() Sync() end) end
  w.explain, w.explanation, w.translate, w.shorten = explain, prose, translate, shorten
  ns.OnFeatures(function()
    if not ns.Enabled('shorten') and ns.shortenPanel then ns.shortenPanel:Hide() end
    Sync()
  end, true)
end

function ns.PrintHelp()
  for _, line in ipairs({
    L["/bf ou /blockforge : ouvrir ou fermer BlockForge."],
    L["/bf aide, /bf ? : toutes les commandes."],
    L["/bf intro, /bf nouveautes, /bf whatsnew : présentation de la 1.0."],
    L["/bf options, /bf config, /bf param : paramètres."],
    L["/bf tuto, /bf tutorial, /bf help : visite guidée."],
    L["/bf assistant : recettes de macros."],
    L["/bf barre, /bf bars : améliorer ma barre."],
    L["/bf bilan, /bf health : bilan de santé."],
    L["/bf kit : kits de personnage."],
    L["/bf profil, /bf profile : profils."],
    L["/bf vivant, /bf living : macros vivantes."],
    L["/bf test : diagnostic complet, sans modifier tes macros."],
  }) do ns.Msg(line) end
end

function ns.LotCTest(out)
  if ns.Enabled('explain') then
    local count = 0
    for _, entry in ipairs(ns.Library) do
      local text = ns.LibraryBody(entry)
      local lines, good = ns.Explain(text, L), true
      for _, line in ipairs(lines) do if line == '' or line:find('%%[sd]') then good = false end end
      if good and #lines == #ns.Parse(text) then count = count + 1 end
    end
    out[#out + 1] = (count == #ns.Library and 'OK ' or 'FAIL ') .. L["Expliquer : %d / %d macros dans la langue du jeu."]:format(count, #ns.Library)
  else out[#out + 1] = 'INFO ' .. L["Expliquer : désactivé."] end
  if ns.Enabled('shorten') then
    local count = 0
    for _, entry in ipairs(ns.Library) do if ns.ShorteningCheck(entry.body) then count = count + 1 end end
    out[#out + 1] = (count == #ns.Library and 'OK ' or 'FAIL ') .. L["Raccourcir : propriétés vérifiées sur %d / %d macros."]:format(count, #ns.Library)
  else out[#out + 1] = 'INFO ' .. L["Raccourcir : désactivé."] end
  local W = ns.Welcome
  out[#out + 1] = 'INFO ' .. L["Présentation : vue %s, attente %s, %d tuiles."]:format(tostring(ns.db.welcomeSeen), tostring(W.pending == true), #W.tiles)
  if not ns.lotCProbe then
    local probe = CreateFrame('ScrollFrame')
    probe.texture = probe:CreateTexture(nil, 'ARTWORK')
    probe.label = probe:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    ns.lotCProbe = probe
  end
  local probe, texture = ns.lotCProbe, ns.lotCProbe.texture
  local iconStates = { unknown = L["non vérifiable"], ok = L["chargée"], fallback = L["icône de secours"] }
  for _, tile in ipairs(W.tiles) do
    W.CheckIcon(texture, tile.icon)
    out[#out + 1] = 'INFO ' .. L["Icône de présentation %s : %s"]:format(tile.icon, iconStates[W.icons[tile.icon]])
  end
  for _, method in ipairs({ 'CreateAnimationGroup', 'GetStringHeight', 'GetTexture', 'SetScrollChild' }) do
    local widget = method == 'GetTexture' and texture or method == 'GetStringHeight' and probe.label or probe
    out[#out + 1] = 'INFO ' .. L["API facultative %s : %s"]:format(method, tostring(widget[method] ~= nil))
  end
  out[#out + 1] = 'INFO ' .. L["API facultative %s : %s"]:format('GetFileIDFromPath', tostring(GetFileIDFromPath ~= nil))
  out[#out + 1] = 'INFO ' .. L["API facultative %s : %s"]:format('SetBlendMode', tostring(texture.SetBlendMode ~= nil))
  if probe.animationChecked == nil then
    probe.animationChecked = true
    local ok, group = pcall(function() return probe.CreateAnimationGroup and probe:CreateAnimationGroup() end)
    if ok and group then
      probe.group = group
      for _, kind in ipairs({ 'alpha', 'Translation' }) do
        local valid, animation = pcall(function() return group.CreateAnimation and group:CreateAnimation(kind) end)
        probe[kind:lower()] = valid and animation or false
      end
    end
  end
  for _, pair in ipairs({ { 'group', 'CreateAnimation' }, { 'group', 'SetLooping' }, { 'group', 'Play' }, { 'group', 'Stop' },
    { 'alpha', 'SetFromAlpha' }, { 'alpha', 'SetToAlpha' }, { 'alpha', 'SetStartDelay' }, { 'alpha', 'SetDuration' },
    { 'alpha', 'SetOrder' }, { 'translation', 'SetOffset' } }) do
    out[#out + 1] = 'INFO ' .. L["API facultative %s : %s"]:format(pair[1] .. ':' .. pair[2], tostring(probe[pair[1]] and probe[pair[1]][pair[2]] ~= nil or false))
  end
  probe:Hide()
end
