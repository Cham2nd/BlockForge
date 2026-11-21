
local ns, L, W = NS, NS.L, NS.Welcome
ns.Open('library')
assert(ns.ed.w.libraryLiving and ns.ed.w.libraryLiving:IsShown(), 'categorie vivante absente')
assert(ns.ed.w.libraryLiving.text._text == L['Vivantes'])
fire(ns.ed.w.libraryLiving, 'OnClick')
local livingRows = {}
for _, row in ipairs(ns.ed.w.libraryList._children) do if row.mark and row:IsShown() then livingRows[#livingRows + 1] = row end end
assert(#livingRows == 6)
for i, entry in ipairs(ns.Living.LibraryEntries()) do
  assert(entry.desc == entry.descEN and not entry.body:find('/cast', 1, true))
  fire(livingRows[i], 'OnClick')
  assert(livingRows[i].text._text:find(entry.name, 1, true))
end
ns.SetFeature('living', false)
assert(not ns.ed.w.libraryLiving:IsShown() and not ns.ed.w.macroLiving:IsShown())
ns.SetFeature('living', true)
ns.OpenAssistant()
assert(#ns.assistant.state.recipes == 5 and ns.assistant.cards[1].living:IsShown())
assert(ns.assistant.livingHeading:IsShown() and ns.assistant.livingHeading._text == L['Macros vivantes'])
ns.SetFeature('living', false)
assert(#ns.assistant.state.recipes == 0)
assert(not ns.assistant.livingHeading:IsShown())
ns.SetFeature('living', true)
ns.OpenLiving()
assert(ns.livingPanel.create._text == L['Créer une macro vivante'])
fire(ns.livingPanel.create, 'OnClick')
assert(ns.assistant:IsShown() and ns.assistant.cards[1].recipe.standalone and not ns.livingPanel:IsShown())
ns.assistant:Hide()
local calls = #CALLS
assert(ns.welcomeUpgrading == false and ns.db.welcomeSeen == '')
ns.SetFeature('welcomeMotion', false)
fireEvent('PLAYER_ENTERING_WORLD')
assert(W.events._scripts.OnUpdate and not W.panel)
fire(W.events, 'OnUpdate', 2.9)
assert(not W.panel)
COMBAT = true
fire(W.events, 'OnUpdate', 0.2)
assert(not W.panel and W.pending)
COMBAT = false
fireEvent('PLAYER_REGEN_ENABLED')
local p = W.panel
assert(p and p:IsShown() and p._parent == UIParent and p._w == 720 and p._h == 460)
assert(p.titleText._text == L['Tes macros. Sans une ligne de code.'])
assert(#p.tiles == 12 and ns.db.welcomeSeen == '' and ns.db.welcomeAnnounced)
local chat = #PRINTS
for i, spec in ipairs(W.tiles) do
  assert(p.tiles[i].text._text == spec.title)
  assert(p.tiles[i]._point[2] >= 22 and p.tiles[i]._point[2] + p.tiles[i]._w <= 698)
  assert(-p.tiles[i]._point[3] + p.tiles[i]._h <= 320)
  if spec.feature then
    ns.SetFeature(spec.feature, false)
    fire(p.tiles[i], 'OnEnter')
    assert(p.detail._text:find(spec.title, 1, true))
    local count = #PRINTS
    W.Activate(i)
    assert(p:IsShown() and #PRINTS == count + 1)
    ns.SetFeature(spec.feature, true)
  end
  local previous, activated = spec.run, 0
  spec.run = function() activated = activated + 1 end
  W.Activate(i)
  assert(activated == 1 and not p:IsShown())
  spec.run = previous
  ns.OpenWelcome()
end
assert(ns.db.welcomeSeen == '1.0' and ns.db.tutorialSeen)
W.Close()
assert(not p:IsShown())
fireEvent('PLAYER_ENTERING_WORLD')
assert(not W.events._scripts.OnUpdate)
fireEvent('PLAYER_REGEN_ENABLED')
assert(not p:IsShown())
for _, cmd in ipairs({ 'intro', 'nouveautes', 'whatsnew' }) do
  SlashCmdList.BLOCKFORGE(cmd)
  assert(p:IsShown())
  fire(p, 'OnHide') p:Hide()
end
ns.Open('editor')
local w = ns.ed.w
assert(not ns.Tutorial.step, 'two welcomes')
fire(w.versionButton, 'OnClick') assert(p:IsShown()) W.Close()
fire(w.settings.welcomeButton, 'OnClick') assert(p:IsShown()) W.Close()
ns.welcomeUpgrading = true
ns.OpenWelcome()
assert(p.titleText._text == L['BlockForge passe en 1.0.'])
fire(p.tour, 'OnClick')
assert(ns.Tutorial.step and #ns.Tutorial.steps < #ns.TutorialSteps)
ns.Tutorial.Stop()
ns.welcomeUpgrading = false
ns.OpenWelcome()
COMBAT = true fireEvent('PLAYER_REGEN_DISABLED')
assert(not p:IsShown())
ns.OpenWelcome() assert(W.pending and not p:IsShown())
COMBAT = false fireEvent('PLAYER_REGEN_ENABLED')
assert(p:IsShown()) W.Close()
ns.SetFeature('welcome', false)
assert(not p:IsShown() and next(W.events._events) == nil and not W.events._scripts.OnUpdate)
assert(not w.versionButton:IsShown() and not w.settings.welcomeButton:IsShown())
ns.OpenWelcome() assert(not p:IsShown())
ns.SetFeature('welcome', true)

-- Plus de vingt fonctions : chaque ligne est atteignable et commande la bonne fonction.
for i = 1, 5 do ns.RegisterFeature { id = 'test_' .. i, label = 'Test ' .. i, desc = 'Test', default = true } end
local list, seen = w.settings.featureList, {}
for offset = 0, #ns.Features do
  list.offset = offset list.Render()
  for _, cb in ipairs(list.rows) do
    if cb.def then seen[cb.def.id] = true assert(cb.label._text == cb.def.label) end
  end
end
for _, def in ipairs(ns.Features) do assert(seen[def.id], def.id) end
local last = list.rows[#list.rows]
click(last, false) assert(not ns.Enabled(last.def.id))
click(last, true) assert(ns.Enabled(last.def.id))
fire(list, 'OnMouseWheel', 200) assert(list.offset == 0)

-- Explication, propositions de traduction et raccourcissement, puis annulation et retablissement.
ns.SetFeature('translate', false)
ns.ed.Load('TEST', '/cast [target=focus,modifier:shift] Fear(Rank 1);')
fire(w.explain, 'OnClick')
assert(w.explanation:IsShown() and w.preview._h == 38 and w.explanation.full ~= '')
local source = ns.EditorText()
ns.OpenShorten()
local shortPanel = ns.shortenPanel
assert(shortPanel:IsShown() and shortPanel.after == '/cast [@focus,mod:shift]Fear(Rank 1)' and #shortPanel.changes > 0)
fire(shortPanel.apply, 'OnClick')
assert(ns.EditorText() == '/cast [@focus,mod:shift]Fear(Rank 1)')
ns.ed.Step(false) assert(ns.EditorText() == source)
ns.ed.Step(true) assert(ns.EditorText() == '/cast [@focus,mod:shift]Fear(Rank 1)')
ns.ed.Load('TEST', string.rep('/cast [target=focus] Fear\n', 12))
assert(w.shorten:IsShown()) fire(w.shorten, 'OnClick') assert(shortPanel:IsShown())
COMBAT = true
local before = ns.EditorText()
fire(shortPanel.apply, 'OnClick') assert(ns.EditorText() == before)
COMBAT = false
ns.SetFeature('shorten', false)
assert(not shortPanel:IsShown() and not w.shorten:IsShown())
ns.OpenShorten() assert(not shortPanel:IsShown())
ns.SetFeature('shorten', true)
ns.SetFeature('translate', true)
local get = C_Spell.GetSpellName
C_Spell.GetSpellName = function(id) return id == ns.SpellIDs.Fear and (GetLocale() == 'enUS' and 'Fear' or 'Peur') or nil end
local imported = GetLocale() == 'enUS' and '/cast Peur' or '/cast Fear'
ns.ed.Load('TEST', imported)
assert(w.translate:IsShown())
fire(w.translate, 'OnClick')
assert(ns.EditorText() ~= imported)
ns.ed.Step(false) assert(ns.EditorText() == imported)
fire(w.textToggle, 'OnClick')
assert(ns.ed.textMode)
w.textBox._text = imported fire(w.textBox, 'OnTextChanged', true)
assert(w.translate:IsShown() and w.textScroll._h == 62)
fire(w.translate, 'OnClick')
assert(ns.EditorText() ~= imported)
ns.ed.Step(false) assert(ns.EditorText() == imported)
ns.SetFeature('translate', false) assert(not w.translate:IsShown())
ns.SetFeature('explain', false) assert(not w.explain:IsShown() and not w.explanation:IsShown())
ns.SetFeature('translate', true) ns.SetFeature('explain', true)
C_Spell.GetSpellName = get
fire(w.textToggle, 'OnClick')
ns.ed.Load('TEST', '/cast Corruption')
ns.OpenShorten()
assert(not shortPanel.apply._enabled)
shortPanel:Hide()
assert(#CALLS == calls, 'help tools wrote a game macro')
local n = #PRINTS
SlashCmdList.BLOCKFORGE('aide') assert(#PRINTS == n + 14)
SlashCmdList.BLOCKFORGE('?') assert(#PRINTS == n + 28)

-- API d'animation absente, puis disponible : alpha reel, clic d'interruption, fermeture et icone de repli.
ns.SetFeature('welcomeMotion', true)
local oldCreate = WIDGET.CreateAnimationGroup
WIDGET.CreateAnimationGroup = nil ABSENT = { CreateAnimationGroup = true }
ns.OpenWelcome() assert(p:IsShown())
ABSENT = nil WIDGET.CreateAnimationGroup = oldCreate
local oldAnimation = WIDGET.CreateAnimation
WIDGET.CreateAnimation = function(self, kind)
  assert(kind == 'Alpha' or kind == 'Translation')
  return oldAnimation(self, 'Alpha')
end
local oldAlpha = WIDGET.SetAlpha
WIDGET.SetAlpha = function(self, value) self._alpha = value end
ns.OpenWelcome()
assert(p._alpha == 0 and p.tiles[1]._alpha == 0)
fire(p, 'OnMouseDown')
assert(p._alpha == 1 and p.tiles[1]._alpha == 1 and #W.groups == 0)
W.Close()
local ending = W.groups[#W.groups]
assert(ending) fire(ending.group, 'OnFinished')
assert(not p:IsShown() and p._alpha == 1)
WIDGET.SetAlpha, WIDGET.CreateAnimation = oldAlpha, oldAnimation
GetFileIDFromPath = function() return 0 end
W.CheckIcon(p.tiles[1].icon, W.tiles[1].icon)
assert(W.icons[W.tiles[1].icon] == 'fallback' and p.tiles[1].icon._tex:find('QuestionMark'))
GetFileIDFromPath = nil

-- Les routes de chaque tuile ouvrent leurs vrais panneaux, sans remplacer les actions.
ns.SetFeature('welcomeMotion', false)
ns.SetFeature('translate', false)
local previousAction = GetActionInfo
GetActionInfo = function() return nil end
local routes = { 'assistant', 'grimoire', 'wand', 'health', 'livingPanel', 'kitsPanel', 'profilesPanel' }
for i = 1, 12 do
  ns.HidePanels() ns.HideGrimoire()
  ns.OpenWelcome()
  W.Activate(i)
  assert(not p:IsShown())
  if routes[i] then assert(ns[routes[i]] and ns[routes[i]]:IsShown(), 'tile route ' .. i)
  elseif i == 8 then assert(w.explanation:IsShown() and ns.ed.explainMode)
  elseif i == 9 then assert(ns.shortenPanel:IsShown())
  elseif i == 10 then assert(w.home:IsVisible())
  elseif i == 11 then assert(w.page:IsVisible())
  elseif i == 12 then assert(w.library:IsVisible()) end
end
GetActionInfo = previousAction
for _, id in ipairs({ 'assistant', 'grimoire', 'bars', 'health', 'living', 'kits', 'profiles', 'explain', 'shorten', 'home' }) do
  local found = false
  for _, spec in ipairs(W.tiles) do if spec.feature == id then found = spec.new and spec.title ~= '' and spec.line ~= '' end end
  assert(found, 'missing headline ' .. id)
end
local expected = GetLocale() == 'enUS' and {
  'condition', 'simulator', 'templates', 'send', 'undo', 'free text', 'icon', 'tutorial', 'English', 'feature'
} or { 'conditions', 'simulateur', 'modèles', 'envoi', 'annuler', 'texte libre', 'icône', 'tutoriel', 'anglais', 'désactivables' }
for _, word in ipairs(expected) do assert(W.classics:lower():find(word:lower(), 1, true), 'missing classic ' .. word) end
assert(W.tiles[11].title == L['Éditeur par blocs'] and W.tiles[12].line:find('274', 1, true))
ns.OpenWelcome()
assert(W.veil and W.veil:IsShown())
W.Close()
assert(not W.veil:IsShown())
local out, frames = {}, #ALL
ns.LotCTest(out)
frames = #ALL
ns.LotCTest({})
assert(#ALL == frames, 'diagnostic widgets leaked')
assert(not table.concat(out, '\n'):find('FAIL'))

-- Des reouvertures ne multiplient pas les groupes d'animation.
ns.SetFeature('welcomeMotion', true)
WIDGET.CreateAnimation = function(self, kind) return oldAnimation(self, 'Alpha') end
ns.OpenWelcome()
W.Close()
fire(W.groups[#W.groups].group, 'OnFinished')
local animatedFrames = #ALL
for i = 1, 5 do
  ns.OpenWelcome()
  fire(p, 'OnUpdate', 1.3)
  assert(not p._scripts.OnUpdate)
  W.Close()
  fire(W.groups[#W.groups].group, 'OnFinished')
end
assert(#ALL == animatedFrames, 'animation groups leaked across opens')
WIDGET.CreateAnimation = oldAnimation
