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
--   optional = true : l'argument peut rester vide
---------------------------------------------------------------------------
ns.BlockDefs = {
  { id = "showtooltip",  label = L["Icône / infobulle"],   cmd = "#showtooltip",  arg = L["sort (optionnel)"], optional = true, color = { 0.55, 0.55, 0.60 } },
  { id = "cast",         label = L["Lancer un sort"],      cmd = "/cast",         arg = L["nom du sort"], clauses = true, color = { 0.25, 0.55, 0.95 } },
  { id = "use",          label = L["Utiliser un objet"],   cmd = "/use",          arg = L["objet ou n° d'emplacement"], clauses = true, color = { 0.30, 0.75, 0.40 } },
  { id = "castsequence", label = L["Séquence de sorts"],   cmd = "/castsequence", arg = L["Sort A, Sort B, ..."], clauses = true, reset = true, color = { 0.60, 0.40, 0.90 } },
  { id = "stopcasting",  label = L["Interrompre mon cast"], cmd = "/stopcasting", clauses = true, color = { 0.90, 0.35, 0.35 } },
  { id = "startattack",  label = L["Attaque auto"],        cmd = "/startattack",  clauses = true, color = { 0.90, 0.55, 0.20 } },
  { id = "stopattack",   label = L["Stop attaque"],        cmd = "/stopattack",   clauses = true, color = { 0.90, 0.55, 0.20 } },
  { id = "petattack",    label = L["Familier : attaque"],  cmd = "/petattack",    clauses = true, color = { 0.85, 0.70, 0.20 } },
  { id = "petfollow",    label = L["Familier : suivre"],   cmd = "/petfollow",    clauses = true, color = { 0.85, 0.70, 0.20 } },
  { id = "petpassive",   label = L["Familier : passif"],   cmd = "/petpassive",   clauses = true, color = { 0.85, 0.70, 0.20 } },
  { id = "petstay",      label = L["Familier : rester"],   cmd = "/petstay",      clauses = true, color = { 0.85, 0.70, 0.20 } },
  { id = "petdefensive", label = L["Familier : défensif"], cmd = "/petdefensive", clauses = true, color = { 0.85, 0.70, 0.20 } },
  { id = "petaggressive", label = L["Familier : agressif"], cmd = "/petaggressive", clauses = true, color = { 0.85, 0.70, 0.20 } },
  { id = "cancelaura",   label = L["Annuler un buff"],     cmd = "/cancelaura",   arg = L["nom du buff"], clauses = true, color = { 0.80, 0.40, 0.70 } },
  { id = "target",       label = L["Cibler"],              cmd = "/target",       arg = L["nom ou unité"], clauses = true, color = { 0.35, 0.75, 0.80 } },
  { id = "targetenemy",  label = L["Cibler ennemi proche"], cmd = "/targetenemy", clauses = true, color = { 0.35, 0.75, 0.80 } },
  { id = "focus",        label = L["Définir le focus"],    cmd = "/focus",        arg = L["unité (optionnel)"], optional = true, clauses = true, color = { 0.35, 0.75, 0.80 } },
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
  ["/petstay"] = "petstay",
  ["/petdefensive"] = "petdefensive",
  ["/petaggressive"] = "petaggressive",
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
  { label = L["Situation"], items = {
      { "spec:1", L["Spé 1"] }, { "spec:2", L["Spé 2"] }, { "pvpcombat", L["Talents JcJ"] },
      { "indoors", L["Intérieur"] }, { "outdoors", L["Extérieur"] }, { "swimming", L["Nage"] },
      { "group", L["En groupe"] }, { "group:raid", L["En raid"] }, { "resting", L["Repos"] },
  } },
}

-- paires qui s'excluent dans un groupe non exclusif : activer l'une retire l'autre
local OPPOSITE = { ["spec:1"] = "spec:2", ["spec:2"] = "spec:1", indoors = "outdoors", outdoors = "indoors" }

ns.KnownConditions = {}
for _, group in ipairs(ns.ConditionGroups) do
  for _, item in ipairs(group.items) do ns.KnownConditions[item[1]] = group end
end

---------------------------------------------------------------------------
-- Outils
---------------------------------------------------------------------------
local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
ns.trim = trim

-- recherche sans accents ni casse : les lettres accentuees du francais (UTF-8, octet de tete 195) deviennent ASCII
local FOLD = {}
for from, to in ("éeèeêeëeàaâaçcôoîiïiùuûuüuÉeÈeÊeËeÀaÂaÇcÔoÎiÏiÙuÛuÜu"):gmatch("(\195[\128-\191])(%a)") do FOLD[from] = to end
function ns.Fold(s) return (s:lower():gsub("\195[\128-\191]", FOLD)) end

-- nom de la liste le plus proche de name (faute de frappe, accent, casse) ; nil si rien d'assez proche
-- seuil bas (3 lettres au plus) : au-dela, on proposerait un autre vrai sort
function ns.Nearest(name, list)
  local a = ns.Fold(name)
  local best, limit = nil, math.min(3, math.max(1, math.floor(#a / 4))) + 1
  for _, cand in ipairs(list) do
    local b = ns.Fold(cand)
    if math.abs(#a - #b) < limit then
      local prev = {}
      for j = 0, #b do prev[j] = j end
      for i = 1, #a do
        local cur = { [0] = i }
        for j = 1, #b do
          cur[j] = math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a:byte(i) == b:byte(j) and 0 or 1))
        end
        prev = cur
      end
      if prev[#b] < limit then best, limit = cand, prev[#b] end
    end
  end
  return best
end

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
    local other = OPPOSITE[cond] and ns.HasCond(clause, OPPOSITE[cond])
    if other then table.remove(clause.conds, other) end
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
ns.CompileClause = compileClause

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
-- Traduction : remplace les noms de sorts et d'objets anglais par ceux de la langue du client
--   getName(id)     -> nom de sort localise ou nil (C_Spell.GetSpellName en jeu)
--   rankWord        -> mot "Rank" localise (global RANK en jeu)
--   getItemName(id) -> nom d'objet localise ou nil tant qu'il n'est pas en cache (facultatif)
---------------------------------------------------------------------------
local sortedNames
local function isWordChar(c) return c ~= "" and c:find("^[%w\128-\255]") ~= nil end

-- l'objet d'abord ; le sort de meme nom sert tant que l'objet n'est pas en cache
local function lookup(name, getName, getItemName)
  local item = getItemName and ns.ItemIDs and ns.ItemIDs[name]
  local spell = ns.SpellIDs and ns.SpellIDs[name]
  return (item and getItemName(item)) or (spell and getName(spell))
end

function ns.Localize(body, getName, rankWord, getItemName)
  if not sortedNames then
    sortedNames = {}
    for name in pairs(ns.SpellIDs or {}) do sortedNames[#sortedNames + 1] = name end
    for name in pairs(ns.ItemIDs or {}) do
      if not (ns.SpellIDs and ns.SpellIDs[name]) then sortedNames[#sortedNames + 1] = name end
    end
    -- les plus longs d'abord : "Blessing of Sacrifice" avant "Sacrifice"
    table.sort(sortedNames, function(a, b) return #a > #b or (#a == #b and a < b) end)
  end
  local localized = {}
  for i, name in ipairs(sortedNames) do
    -- on teste la presence avant getName : 151 appels x plusieurs centaines de noms
    local target = body:find(name, 1, true) and lookup(name, getName, getItemName)
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
-- Modeles de l'editeur : les sorts sont laisses vides, l'editeur les marque "(argument ?)"
---------------------------------------------------------------------------
ns.Templates = {
  { label = L["Familier : attaque + sort"],
    desc = L["Le familier attaque l'ennemi survolé, sinon ta cible, puis tu lances un sort sur lui."],
    body = "#showtooltip\n/petattack [@mouseover,harm,nodead][]\n/cast [@mouseover,harm,nodead][]" },
  { label = L["Familier : modes sur touches"],
    desc = L["Sans touche : attaque. Maj : suivre et passif. Ctrl : défensif."],
    body = "/petattack [nomod]\n/petfollow [mod:shift]\n/petpassive [mod:shift]\n/petdefensive [mod:ctrl]" },
  { label = L["PvP : interruption sur focus"],
    desc = L["Arrête ton incantation, puis lance le sort sur le focus s'il existe et est hostile, sinon sur ta cible."],
    body = "#showtooltip\n/stopcasting\n/cast [@focus,exists,harm,nodead][]" },
  { label = L["PvP : contrôle sur survol"],
    desc = L["Lance le sort sur l'ennemi survolé, sinon sur ta cible. Avec Maj : sur le focus."],
    body = "#showtooltip\n/cast [@focus,mod:shift,harm,nodead][@mouseover,harm,nodead][]" },
  { label = L["PvP : bijou puis sort"],
    desc = L["Utilise le bijou du haut (emplacement 13), puis lance le sort."],
    body = "#showtooltip\n/use 13\n/cast" },
}

---------------------------------------------------------------------------
-- Diagnostics affiches sous l'apercu
---------------------------------------------------------------------------
-- techniques de familier lancees par /cast (noms en minuscules ; UI.lua ajoute les noms traduits)
-- shortcut: noms ambigus avec un sort du joueur (Charge, Prowl, Dash) laisses de cote
ns.PetSpells = {}
for name in ("spell lock,devour magic,seduction,sacrifice,fire shield,consume shadows,torment,suffering,soothing kiss,lash of pain,firebolt,phase shift,blood pact,paranoia,lesser invisibility,growl,bite,claw,dive,cower,furious howl,screech"):gmatch("[^,]+") do
  ns.PetSpells[name] = true
end

-- noms des sorts lances par /cast et /castsequence, sans "!", sans rang, sans doublon
function ns.SpellsOf(blocks)
  local list, seen = {}, {}
  for _, block in ipairs(blocks) do
    if block.type == "cast" or block.type == "castsequence" then
      for _, clause in ipairs(block.clauses or {}) do
        for spell in (clause.arg or ""):gmatch("[^,]+") do
          local name = trim(spell:gsub("^%s*!", ""):gsub("%(.-%)%s*$", ""))
          if name ~= "" and not seen[name] then
            seen[name] = true
            list[#list + 1] = name
          end
        end
      end
    end
  end
  return list
end

function ns.Diagnose(blocks)
  local text = ns.Compile(blocks)
  local warnings = {}
  if #text > ns.MAX_CHARS then
    warnings[#warnings + 1] = L["Trop long : %d / %d caractères."]:format(#text, ns.MAX_CHARS)
  end
  local plainCasts, dismount, pet, tooltips, clash = 0, false, false, 0, false
  for i, block in ipairs(blocks) do
    local t = block.type
    if t == "showtooltip" then tooltips = tooltips + (i == 1 and 1 or 2) end
    for _, clause in ipairs(block.clauses or {}) do
      local has = {}
      for _, cond in ipairs(clause.conds) do has[cond] = true end
      if has.harm and has.help then clash = true end
      for cond in pairs(has) do
        if has["no" .. cond] or has[OPPOSITE[cond]] then clash = true end
      end
    end
    if t == "dismount" then dismount = true end
    if t:find("^pet") then pet = true end
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
  if tooltips > 1 then
    warnings[#warnings + 1] = L["#showtooltip doit être la première ligne, une seule fois."]
  end
  if clash then
    warnings[#warnings + 1] = L["Conditions contradictoires dans une même alternative : elle ne sera jamais vraie."]
  end
  -- une macro ne peut pas attendre : pas de /wait pour laisser le familier revenir
  if dismount and pet then
    warnings[#warnings + 1] = L["Familier : ses ordres et techniques ne partent pas sur une monture ni juste après en être descendu. Appuyer une seconde fois."]
  end
  return text, warnings
end

---------------------------------------------------------------------------
-- Partage par texte : "BF1:nom:corps" sur une seule ligne
---------------------------------------------------------------------------
-- | est un code d'echappement du chat, : separe les champs, les retours a la ligne ne passent pas
local function escape(s) return (s:gsub("[%%|:%c]", function(c) return ("%%%02X"):format(c:byte()) end)) end
local function unescape(s) return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)) end

function ns.Export(name, body) return "BF1:" .. escape(name) .. ":" .. escape(body) end

function ns.Import(str)
  local version, name, body = trim(type(str) == "string" and str or ""):match("^BF(%d+):([^:]*):([^:]*)$")
  if not version then return nil, L["Texte non reconnu : il doit commencer par « BF1: »."] end
  if version ~= "1" then return nil, L["Version « %s » non prise en charge."]:format(version) end
  -- un % sans deux chiffres hexa, un | ou un caractere de controle : texte abime en route
  if (name .. body):gsub("%%%x%x", ""):find("[%%|%c]") then return nil, L["Texte abîmé : caractère inattendu."] end
  name, body = unescape(name), unescape(body)
  local letters = #name:gsub("[\128-\191]", "") -- 16 lettres, pas 16 octets
  if trim(name) == "" or letters > 16 then return nil, L["Nom de macro vide ou trop long (16 caractères max)."] end
  if #body > ns.MAX_CHARS then return nil, L["Macro trop longue : %d / %d."]:format(#body, ns.MAX_CHARS) end
  return name, body
end

---------------------------------------------------------------------------
-- Simulateur : quelle alternative part pour un etat du jeu suppose
--   state.mod = "shift" | "ctrl" | "alt" | nil ; state.target / mouseover / focus = "harm" | "help" | "none"
--   state.targetDead (idem mouseoverDead, focusDead), booleens combat, stealth, pet, mounted, channeling,
--   pvpcombat, swimming, resting, indoors ; spec = 1 | 2 ; group = false | "party" | "raid" ; form = nombre
--   Un champ absent (sauf mod) rend la condition inconnue : on ne devine pas.
---------------------------------------------------------------------------
local MODS = { shift = true, ctrl = true, alt = true }
local FLAGS = { combat = true, stealth = true, mounted = true, pet = true, channeling = true,
                pvpcombat = true, swimming = true, resting = true, indoors = true }

local function unitKind(state, unit)
  if unit == "player" then return "help", false end
  if unit == "pet" then
    if state.pet == nil then return nil end
    return state.pet and "help" or "none", false
  end
  if unit == "target" or unit == "mouseover" or unit == "focus" then return state[unit], state[unit .. "Dead"] == true end
end

local function anyNumber(value, n)
  for v in value:gmatch("[^/]+") do if tonumber(v) == n then return true end end
  return false
end

-- true / false, ou nil si le simulateur ne sait pas
local function evalCond(cond, unit, state)
  local word, value = cond:lower():match("^(%a+):?(.*)$")
  if not word then return nil end
  local neg = word:sub(1, 2) == "no"
  if neg then word = word:sub(3) end
  local r
  if word == "mod" or word == "modifier" then
    r = value == "" and (state.mod or false) ~= false
    for v in value:gmatch("[^/]+") do
      if not MODS[v] then return nil end
      if v == state.mod then r = true end
    end
  elseif word == "harm" or word == "help" or word == "exists" or word == "dead" then
    local kind, dead = unitKind(state, unit)
    if value ~= "" or kind == nil then return nil end
    if word == "exists" then r = kind ~= "none"
    elseif word == "dead" then r = kind ~= "none" and dead
    else r = kind == word end
  elseif FLAGS[word] or word == "outdoors" then
    local v = state[word == "outdoors" and "indoors" or word]
    if value ~= "" or v == nil then return nil end
    r = (v == true) ~= (word == "outdoors")
  elseif word == "spec" then
    if value == "" or state.spec == nil then return nil end
    r = anyNumber(value, state.spec)
  elseif word == "group" then
    if state.group == nil or not (value == "" or value == "party" or value == "raid") then return nil end
    r = (value == "raid" and state.group == "raid") or (value ~= "raid" and state.group ~= false)
  elseif word == "form" or word == "stance" then
    if state.form == nil then return nil end
    if value == "" then r = state.form ~= 0 else r = anyNumber(value, state.form) end
  else
    return nil
  end
  if neg then return not r end
  return r
end

-- un groupe "[a,b,c]" : faux des qu'une condition connue est fausse, inconnu s'il en reste une inconnue
local function evalGroup(conds, state)
  local unit = "target"
  for _, c in ipairs(conds) do
    local u = c:lower():match("^@(.+)$") or c:lower():match("^target=(.+)$")
    if u then unit = trim(u) end
  end
  local unknown = false
  for _, c in ipairs(conds) do
    if not (c:find("^@") or c:lower():find("^target=")) then
      local ok = evalCond(c, unit, state)
      if ok == false then return false, unit end
      if ok == nil then unknown = true end
    end
  end
  if unknown then return nil, unit end
  return true, unit
end

-- par bloc : false (ligne sans conditions possibles), ou { clause = k, unit = u, unknown = true|nil }, {} si rien ne part
function ns.Simulate(blocks, state)
  local out = {}
  for i, block in ipairs(blocks) do
    local res = false
    if block.clauses then
      res = {}
      local present = false
      for ci, clause in ipairs(block.clauses) do
        if compileClause(clause, block.reset) ~= "" then
          present = true
          -- "[a][b] sort" : chaque crochet est une alternative qui partage l'argument
          local groups = {}
          if #clause.conds > 0 then groups[1] = clause.conds end
          for g in (clause.alt or ""):gmatch("%b[]") do
            local list = {}
            for c in g:sub(2, -2):gmatch("[^,]+") do
              c = trim(c)
              if c ~= "" then list[#list + 1] = c end
            end
            groups[#groups + 1] = list
          end
          if #groups == 0 then groups[1] = {} end
          for _, conds in ipairs(groups) do
            local ok, unit = evalGroup(conds, state)
            if ok ~= false then
              res = { clause = ci, unit = unit, unknown = ok == nil or nil }
              break
            end
          end
          if res.clause then break end
        end
      end
      -- commande seule ("/stopcasting") : part toujours
      if not present then res = { clause = 1, unit = "target" } end
    end
    out[i] = res
  end
  return out
end
