
local ns, L = NS, NS.L
local function same(a, b, state)
  local ba, bb = a, b
  assert(#ba == #bb, 'line count changed')
  local sa, sb = ns.Simulate(ba, state), ns.Simulate(bb, state)
  for i, x in ipairs(ba) do
    local y = bb[i]
    assert(x.type == y.type, 'command changed')
    if sa[i] then
      assert(sa[i].clause == sb[i].clause and sa[i].unit == sb[i].unit and sa[i].unknown == sb[i].unknown, 'branch changed')
      if sa[i].clause then
        local ca, cb = x.clauses[sa[i].clause], y.clauses[sb[i].clause]
        local aa, ab = ca.arg, cb.arg
        if x.type == 'castsequence' then aa, ab = aa:gsub(',%s+', ','), ab:gsub(',%s+', ',') end
        assert(aa == ab and x.reset == y.reset, 'argument changed')
      end
    elseif x.type == 'raw' then assert(x.arg == y.arg, 'raw changed') end
  end
end
local bodies = {}
for _, entry in ipairs(ns.Library) do bodies[#bodies + 1] = entry.body end
assert(#bodies == 274)
for _, recipe in ipairs(ns.Recipes) do
  for _, kind in ipairs({ 'harm', 'help', 'either', 'pet', 'item' }) do
    for options = 0, 7 do
      bodies[#bodies + 1] = recipe.build('Corruption', {kind = kind, showtooltip = options % 2 == 1, nodead = math.floor(options / 2) % 2 == 1, stopattack = options >= 4})
    end
  end
end
for _, body in ipairs(bodies) do
  local short, changes, saved = ns.Shorten(body)
  assert(#short <= #body and saved == #body - #short)
  assert(ns.Shorten(short) == short, 'not idempotent: ' .. body)
  local total = 0
  for _, change in ipairs(changes) do
    assert(change.saved == #change.before - #change.after and change.saved > 0)
    total = total + change.saved
  end
  assert(total == saved)
  local phrases = ns.Explain(body, L)
  assert(#phrases == #ns.Parse(body), 'missing explanation')
  for _, phrase in ipairs(phrases) do
    assert(phrase ~= '' and phrase ~= '.' and not phrase:find('%%[sd]'), phrase)
    if GetLocale() == 'enUS' then
      assert(not phrase:find('sinon') and not phrase:find('^Lance ') and not phrase:find('Ligne libre') and not phrase:find('sur ta cible'), phrase)
    end
  end
  local parsedBody, parsedShort = ns.Parse(body), ns.Parse(short)
  for _, mod in ipairs({ false, 'shift', 'ctrl', 'alt' }) do
    for _, target in ipairs({ 'none', 'harm', 'help' }) do
      for _, mouseover in ipairs({ 'none', 'harm', 'help' }) do
        for _, focus in ipairs({ 'none', 'harm', 'help' }) do
          same(parsedBody, parsedShort, {mod = mod, target = target, mouseover = mouseover, focus = focus,
            targetDead = mod == 'ctrl', mouseoverDead = mod == 'alt', focusDead = mod == 'shift',
            combat = mod ~= false, stealth = mod == 'shift', pet = true, mounted = false, channeling = false,
            group = 'raid', spec = 2, form = 1, indoors = false, resting = false, swimming = true, pvpcombat = true})
        end
      end
    end
  end
end
for _, def in ipairs(ns.BlockDefs) do
  local b = ns.NewBlock(def.id)
  if b.clauses then b.clauses[1].arg = 'Corruption' else b.arg = '/unknown example' end
  assert(#ns.Explain({ b }, L) == 1)
end
for _, group in ipairs(ns.ConditionGroups) do
  for _, item in ipairs(group.items) do
    local phrase = ns.Explain('/cast [' .. item[1] .. '] Corruption', L)[1]
    assert(not phrase:find('condition "') and not phrase:find('condition «'), phrase)
  end
end
local unknown = ns.Explain('/cast [mystery:17] Corruption', L)[1]
assert(unknown:find('mystery:17', 1, true))
assert(ns.Explain('/use {bf:potion_soin}', L)[1]:find(L['Potion de soin'], 1, true))
assert(not ns.Explain('/use {bf:potion_soin}', L)[1]:find('{bf:', 1, true))
assert(ns.Explain('/castsequence reset=target/5 A, B', L)[1]:find('5', 1, true))
local source = '/cast [target=focus, modifier:shift] Fear(Rank 1);'
local short = ns.Shorten(source)
assert(short == '/cast [@focus,mod:shift]Fear(Rank 1)', short)
assert(ns.Shorten('/run print("[target=x]");') == '/run print("[target=x]");')
assert(ns.Shorten('/cast A\n/cast A') == '/cast A\n/cast A', 'repeated cast merged')
assert(ns.Shorten('#showtooltip A\n/use 13\n/cast A'):find('#showtooltip A', 1, true), 'tooltip changed')
assert(ns.Shorten('#showtooltip A\n/cast [harm] A'):find('#showtooltip A', 1, true), 'conditional tooltip changed')
assert(ns.Shorten('#showtooltip A\n/cast A') == '#showtooltip\n/cast A')
local preserved = ns.Parse(short, true)
assert(ns.Compile(preserved) == short and ns.Compile(ns.CloneBlocks(preserved)) == short)
preserved[1].clauses[1].arg = 'Other'
assert(ns.Compile(preserved):find('Other', 1, true))
local get = function(id) return id == ns.SpellIDs.Fear and 'Peur' or nil end
local translated, n = ns.Translate('/cast [@focus] Fear(Rank 2)\n/run print("Fear")\n/target Fear', get, 'Rang')
assert(n == 1 and translated == '/cast [@focus] Peur(Rang 2)\n/run print("Fear")\n/target Fear', translated)
get = function(id) return id == ns.SpellIDs.Fear and 'Fear' or nil end
assert(ns.Translate('/cast Peur(Rang 2)', get, 'Rank') == '/cast Fear(Rank 2)')
assert(ns.Translate('/cast Inconnu', get, 'Rank') == '/cast Inconnu')
assert(ns.Translate('/castsequence reset=target Peur, Peur', get, 'Rank') == '/castsequence reset=target Fear, Fear')

assert(ns.Shorten('/focus [@mouseover];') == '/focus [@mouseover];', 'empty focus fallback removed')
assert(ns.Shorten('/petattack [harm];') == '/petattack [harm];', 'empty no-argument fallback removed')
assert(ns.Shorten('/cast [modifier:shift,button:2,nomodifier:alt] A;') == '/cast [mod:shift,btn:2,nomod:alt]A')
assert(ns.Explain('/focus [@mouseover]', L)[1]:find(L['sur l’unité survolée'], 1, true))
assert(not ns.Explain('/focus [@mouseover]', L)[1]:find(L['ta cible'], 1, true))
assert(ns.Explain('#showtooltip [mod:shift] A; B', L)[1]:find(L[' ; sinon '], 1, true))
assert(not ns.Explain('/cast A;', L)[1]:find(L[' ; sinon '], 1, true))
assert(ns.Explain('/focus [@mouseover];', L)[1]:find(L[' ; sinon '], 1, true))
