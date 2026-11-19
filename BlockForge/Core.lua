-- BlockForge : coeur (modele de blocs, compilation blocs -> texte, analyse texte -> blocs)
-- Ce fichier ne depend d'aucune API d'interface : il peut etre teste hors du jeu.
local ADDON, ns = ...
ns = ns or {}
if not ADDON then _G.BlockForgeNS = ns end -- execution hors jeu (tests)
-- certains tests chargent ce fichier sans Locale.lua : la cle sert alors de texte
local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })

ns.MAX_CHARS = 255

---------------------------------------------------------------------------
-- Types de blocs
--   clauses = true  : le bloc accepte des alternatives "[conditions] argument; ..."
--   arg     = texte d'aide pour l'argument (nil = pas d'argument)
---------------------------------------------------------------------------
ns.BlockDefs = {
  { id = "showtooltip",  label = L["Icône / infobulle"],   cmd = "#showtooltip",  arg = L["sort (optionnel)"], color = { 0.55, 0.55, 0.60 } },
  { id = "cast",         label = L["Lancer un sort"],      cmd = "/cast",         arg = L["nom du sort"], clauses = true, color = { 0.25, 0.55, 0.95 } },
  { id = "use",          label = L["Utiliser un objet"],   cmd = "/use",          arg = L["objet ou n° d'emplacement"], clauses = true, color = { 0.30, 0.75, 0.40 } },
  { id = "castsequence", label = L["Séquence de sorts"],   cmd = "/castsequence", arg = L["Sort A, Sort B, ..."], clauses = true, reset = true, color = { 0.60, 0.40, 0.90 } },
  { id = "stopcasting",  label = L["Interrompre mon cast"], cmd = "/stopcasting", clauses = true, color = { 0.90, 0.35, 0.35 } },
  { id = "startattack",  label = L["Attaque auto"],        cmd = "/startattack",  clauses = true, color = { 0.90, 0.55, 0.20 } },
  { id = "stopattack",   label = L["Stop attaque"],        cmd = "/stopattack",   clauses = true, color = { 0.90, 0.55, 0.20 } },
  { id = "petattack",    label = L["Familier : attaque"],  cmd = "/petattack",    clauses = true, color = { 0.85, 0.70, 0.20 } },
  { id = "petfollow",    label = L["Familier : suivre"],   cmd = "/petfollow",    clauses = true, color = { 0.85, 0.70, 0.20 } },
  { id = "petpassive",   label = L["Familier : passif"],   cmd = "/petpassive",   clauses = true, color = { 0.85, 0.70, 0.20 } },
  { id = "cancelaura",   label = L["Annuler un buff"],     cmd = "/cancelaura",   arg = L["nom du buff"], clauses = true, color = { 0.80, 0.40, 0.70 } },
  { id = "target",       label = L["Cibler"],              cmd = "/target",       arg = L["nom ou unité"], clauses = true, color = { 0.35, 0.75, 0.80 } },
  { id = "targetenemy",  label = L["Cibler ennemi proche"], cmd = "/targetenemy", clauses = true, color = { 0.35, 0.75, 0.80 } },
  { id = "focus",        label = L["Définir le focus"],    cmd = "/focus",        arg = L["unité (optionnel)"], clauses = true, color = { 0.35, 0.75, 0.80 } },
  { id = "assist",       label = L["Assister"],            cmd = "/assist",       arg = L["nom ou unité"], clauses = true, color = { 0.35, 0.75, 0.80 } },
  { id = "equip",        label = L["Équiper"],             cmd = "/equip",        arg = L["nom de l'objet"], clauses = true, color = { 0.30, 0.75, 0.40 } },
  { id = "dismount",     label = L["Descendre de monture"], cmd = "/dismount",    clauses = true, color = { 0.55, 0.55, 0.60 } },
  { id = "raw",          label = L["Ligne libre"],         cmd = "",              arg = L["/commande ..."], color = { 0.45, 0.45, 0.45 } },
}

ns.BlockById = {}
for _, def in ipairs(ns.BlockDefs) do ns.BlockById[def.id] = def end

-- Alias de commandes reconnus par l'analyseur
local CMD_ALIASES = {
  ["/cast"] = "cast", ["/spell"] = "cast",
  ["/use"] = "use",
  ["/castsequence"] = "castsequence",
  ["/stopcasting"] = "stopcasting",
  ["/startattack"] = "startattack",
  ["/stopattack"] = "stopattack",
  ["/petattack"] = "petattack",
  ["/petfollow"] = "petfollow",
  ["/petpassive"] = "petpassive",
  ["/cancelaura"] = "cancelaura",
  ["/target"] = "target", ["/tar"] = "target",
  ["/targetenemy"] = "targetenemy",
  ["/focus"] = "focus",
  ["/assist"] = "assist",
  ["/equip"] = "equip",
  ["/dismount"] = "dismount",
}

---------------------------------------------------------------------------
-- Conditions proposees dans l'editeur (groupes de boutons)
--   exclusive = true : une seule valeur du groupe a la fois
---------------------------------------------------------------------------
ns.ConditionGroups = {
  { label = L["Cible du sort"], exclusive = true, items = {
      { "@mouseover", L["Survol"] }, { "@focus", L["Focus"] }, { "@player", L["Moi"] },
      { "@pet", L["Familier"] }, { "@target", L["Cible"] }, { "@targettarget", L["Cible de cible"] },
      { "@cursor", L["Curseur"] },
  } },
  { label = L["État de la cible"], items = {
      { "harm", L["Hostile"] }, { "help", L["Amie"] }, { "exists", L["Existe"] },
      { "nodead", L["Vivante"] }, { "dead", L["Morte"] },
  } },
  { label = L["Touche maintenue"], items = {
      { "mod:shift", L["Maj"] }, { "mod:ctrl", L["Ctrl"] }, { "mod:alt", L["Alt"] }, { "nomod", L["Aucune"] },
  } },
  { label = L["Mon état"], items = {
      { "combat", L["En combat"] }, { "nocombat", L["Hors combat"] }, { "stealth", L["Camouflé"] },
      { "nostealth", L["Pas camouflé"] }, { "mounted", L["Monté"] }, { "pet", L["Familier sorti"] },
      { "nopet", L["Pas de familier"] }, { "channeling", L["Canalise"] }, { "nochanneling", L["Ne canalise pas"] },
  } },
}

ns.KnownConditions = {}
for _, group in ipairs(ns.ConditionGroups) do
  for _, item in ipairs(group.items) do ns.KnownConditions[item[1]] = group end
end

---------------------------------------------------------------------------
-- Outils
---------------------------------------------------------------------------
local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
ns.trim = trim

function ns.NewClause() return { conds = {}, arg = "" } end

function ns.NewBlock(id)
  local def = ns.BlockById[id] or ns.BlockById.raw
  local block = { type = def.id, arg = "" }
  if def.clauses then block.clauses = { ns.NewClause() } end
  if def.reset then block.reset = "" end
  return block
end

function ns.HasCond(clause, cond)
  for i, c in ipairs(clause.conds) do if c == cond then return i end end
  return nil
end

-- Active/desactive une condition ; gere les groupes exclusifs (une seule cible @...)
function ns.ToggleCond(clause, cond)
  local at = ns.HasCond(clause, cond)
  if at then table.remove(clause.conds, at) return false end
  local group = ns.KnownConditions[cond]
  if group and group.exclusive then
    -- le groupe exclusif est celui des cibles : on retire aussi "@party1", "target=focus"... venus d'une macro analysee
    for i = #clause.conds, 1, -1 do
      local c = clause.conds[i]
      if ns.KnownConditions[c] == group or c:find("^@") or c:find("^target=") then table.remove(clause.conds, i) end
    end
    table.insert(clause.conds, 1, cond) -- la cible se lit mieux en premier
  else
    clause.conds[#clause.conds + 1] = cond
  end
  return true
end

---------------------------------------------------------------------------
-- Compilation : blocs -> texte de macro
---------------------------------------------------------------------------
local function compileClause(clause, reset)
  local out = ""
  if #clause.conds > 0 then out = "[" .. table.concat(clause.conds, ",") .. "]" end
  if clause.alt and clause.alt ~= "" then out = out .. clause.alt end
  local arg = trim(clause.arg or "")
  if arg ~= "" and reset and reset ~= "" then arg = "reset=" .. reset .. " " .. arg end
  if arg ~= "" then out = (out ~= "" and (out .. " ") or "") .. arg end
  return trim(out)
end

function ns.CompileBlock(block)
  if block.type == "raw" then return trim(block.arg or "") end
  local def = ns.BlockById[block.type] or ns.BlockById.raw
  if not def.clauses then
    local arg = trim(block.arg or "")
    return arg ~= "" and (def.cmd .. " " .. arg) or def.cmd
  end
  local parts = {}
  for _, clause in ipairs(block.clauses or {}) do
    local text = compileClause(clause, block.reset)
    if text ~= "" then parts[#parts + 1] = text end
  end
  if #parts == 0 then return def.cmd end
  return def.cmd .. " " .. table.concat(parts, "; ")
end

function ns.Compile(blocks)
  local lines = {}
  for _, block in ipairs(blocks) do
    local line = ns.CompileBlock(block)
    if line ~= "" then lines[#lines + 1] = line end
  end
  return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- Analyse : texte de macro -> blocs (pour ouvrir une macro existante dans l'editeur)
---------------------------------------------------------------------------
local function splitTopLevel(text, sep)
  -- coupe sur `sep` en ignorant ce qui est entre crochets
  local parts, depth, current = {}, 0, ""
  for i = 1, #text do
    local ch = text:sub(i, i)
    if ch == "[" then depth = depth + 1 elseif ch == "]" then depth = math.max(0, depth - 1) end
    if ch == sep and depth == 0 then
      parts[#parts + 1] = current
      current = ""
    else
      current = current .. ch
    end
  end
  parts[#parts + 1] = current
  return parts
end

local function parseClause(text, hasReset)
  local clause = ns.NewClause()
  local rest = trim(text)
  local first = true
  while true do
    local group = rest:match("^(%b[])")
    if not group then break end
    if first then
      for cond in group:sub(2, -2):gmatch("[^,]+") do
        cond = trim(cond)
        if cond ~= "" then clause.conds[#clause.conds + 1] = cond end
      end
      if #clause.conds == 0 then clause.alt = (clause.alt or "") .. "[]" end
      first = false
    else
      clause.alt = (clause.alt or "") .. group
    end
    rest = trim(rest:sub(#group + 1))
  end
  local reset
  if hasReset then
    local r, after = rest:match("^reset=(%S+)%s*(.*)$")
    if r then reset, rest = r, after end
  end
  clause.arg = rest
  return clause, reset
end

function ns.ParseLine(line)
  line = trim(line)
  if line == "" then return nil end
  local lower = line:lower()
  if lower:match("^#showtooltip") or lower:match("^#show%s") or lower == "#show" then
    local block = ns.NewBlock("showtooltip")
    block.arg = trim((line:gsub("^#%a+", "", 1)))
    return block
  end
  local cmd, rest = line:match("^(/[^%s%[]+)%s*(.*)$") -- "/cast[@focus] Sort" (sans espace) est valide
  local id = cmd and CMD_ALIASES[cmd:lower()]
  local def = id and ns.BlockById[id]
  if not def then
    local block = ns.NewBlock("raw")
    block.arg = line
    return block
  end
  local block = ns.NewBlock(id)
  block.clauses = {}
  local firstReset
  for n, part in ipairs(splitTopLevel(rest, ";")) do
    local clause, reset = parseClause(part, def.reset)
    if n == 1 then firstReset = reset
    elseif reset ~= firstReset then
      -- reset= different selon l'alternative : le bloc n'en porte qu'un, on garde la ligne telle quelle
      local raw = ns.NewBlock("raw")
      raw.arg = line
      return raw
    end
    block.clauses[#block.clauses + 1] = clause
  end
  block.reset = firstReset or ""
  return block
end

function ns.Parse(text)
  local blocks = {}
  for line in (text .. "\n"):gmatch("(.-)\r?\n") do
    local block = ns.ParseLine(line)
    if block then blocks[#blocks + 1] = block end
  end
  return blocks
end

---------------------------------------------------------------------------
-- Traduction : remplace les noms de sorts anglais par ceux de la langue du client
--   getName(id) -> nom localise ou nil (C_Spell.GetSpellName en jeu)
--   rankWord    -> mot "Rank" localise (global RANK en jeu)
---------------------------------------------------------------------------
local sortedNames
local function isWordChar(c) return c ~= "" and c:find("^[%w\128-\255]") ~= nil end

function ns.Localize(body, getName, rankWord)
  if not sortedNames then
    sortedNames = {}
    for name in pairs(ns.SpellIDs or {}) do sortedNames[#sortedNames + 1] = name end
    -- les plus longs d'abord : "Blessing of Sacrifice" avant "Sacrifice"
    table.sort(sortedNames, function(a, b) return #a > #b or (#a == #b and a < b) end)
  end
  local localized = {}
  for i, name in ipairs(sortedNames) do
    -- on teste la presence avant getName : 151 appels x plusieurs centaines de noms
    local target = body:find(name, 1, true) and getName(ns.SpellIDs[name])
    if target and target ~= name then
      local from = 1
      while true do
        local s, e = body:find(name, from, true)
        if not s then break end
        if isWordChar(body:sub(s - 1, s - 1)) or isWordChar(body:sub(e + 1, e + 1)) then
          from = s + 1 -- "Heal" dans "Healing Potion" : pas un nom de sort
        else
          -- jeton temporaire : un nom deja traduit ne peut plus etre retouche
          local token = "\1" .. i .. "\2"
          body = body:sub(1, s - 1) .. token .. body:sub(e + 1)
          localized[i] = target
          from = s + #token
        end
      end
    end
  end
  body = body:gsub("\1(%d+)\2", function(i) return localized[tonumber(i)] end)
  if rankWord and rankWord ~= "Rank" then body = body:gsub("%(Rank (%d+)%)", "(" .. rankWord:gsub("%%", "%%%%") .. " %1)") end
  return body
end

---------------------------------------------------------------------------
-- Diagnostics affiches sous l'apercu
---------------------------------------------------------------------------
-- techniques de familier lancees par /cast (noms en minuscules ; UI.lua ajoute les noms traduits)
-- shortcut: noms ambigus avec un sort du joueur (Charge, Prowl, Dash) laisses de cote
ns.PetSpells = {}
for name in ("spell lock,devour magic,seduction,sacrifice,fire shield,consume shadows,torment,suffering,soothing kiss,lash of pain,firebolt,phase shift,blood pact,paranoia,lesser invisibility,growl,bite,claw,dive,cower,furious howl,screech"):gmatch("[^,]+") do
  ns.PetSpells[name] = true
end

function ns.Diagnose(blocks)
  local text = ns.Compile(blocks)
  local warnings = {}
  if #text > ns.MAX_CHARS then
    warnings[#warnings + 1] = L["Trop long : %d / %d caractères."]:format(#text, ns.MAX_CHARS)
  end
  local plainCasts, dismount, pet = 0, false, false
  for _, block in ipairs(blocks) do
    local t = block.type
    if t == "dismount" then dismount = true end
    if t == "petattack" or t == "petfollow" or t == "petpassive" then pet = true end
    if t == "cast" or t == "use" or t == "castsequence" then
      local hasArg, plain = false, true
      for _, clause in ipairs(block.clauses or {}) do
        if trim(clause.arg or "") ~= "" then hasArg = true end
        for spell in (clause.arg or ""):gmatch("[^,]+") do
          if ns.PetSpells[trim(spell:gsub("^%s*!", ""):gsub("%(.-%)%s*$", "")):lower()] then pet = true end
        end
        if #clause.conds > 0 or (clause.alt or "") ~= "" then plain = false end
      end
      if not hasArg then
        warnings[#warnings + 1] = L["« %s » n'a pas d'argument."]:format(ns.BlockById[t].label)
      elseif plain and t ~= "use" then
        plainCasts = plainCasts + 1
      end
    end
  end
  -- seuls les sorts sans aucune condition sont surs de se bloquer entre eux
  if plainCasts > 1 then
    warnings[#warnings + 1] = L["Plusieurs sorts sans condition : le premier part, les suivants ne servent que s'il échoue (ou s'il ne déclenche pas le temps de recharge global)."]
  end
  -- une macro ne peut pas attendre : pas de /wait pour laisser le familier revenir
  if dismount and pet then
    warnings[#warnings + 1] = L["Familier : ses ordres et techniques ne partent pas sur une monture ni juste après en être descendu. Appuyer une seconde fois."]
  end
  return text, warnings
end
