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
  { id = "stopcasting",  label = L["Arrêter l'incantation"], cmd = "/stopcasting", clauses = true, color = { 0.90, 0.35, 0.35 } },
  { id = "startattack",  label = L["Attaque auto"],        cmd = "/startattack",  clauses = true, color = { 0.90, 0.55, 0.20 } },
  { id = "stopattack",   label = L["Arrêter l'attaque"],        cmd = "/stopattack",   clauses = true, color = { 0.90, 0.55, 0.20 } },
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
for from, to in ("éeèeêeëeàaâaçcôoîiïiùuûuüuÉeÈeÊeËeÀaÂaÇcÔoÎiÏiÙuÛuÜu"):gmatch("(\195[\128-\191])(%a)") do FOLD[from] = to end -- locale-ok : table de lettres, pas un texte affiche
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
-- Coloration syntaxique pour l'affichage (codes |cffRRGGBB...|r du jeu)
--   palette : couleurs RRGGBB { command, meta, cond, target, arg } ; commands[commande] (facultatif) passe avant command
--   Sans perte : retirer les codes de couleur et lire "||" comme "|" redonne le texte exact.
---------------------------------------------------------------------------
function ns.Colorize(text, palette)
  local function paint(s, color)
    s = s:gsub("|", "||") -- un | seul serait lu par le jeu comme un code d'echappement
    if not color or not s:find("%S") then return s end
    return "|cff" .. color .. s .. "|r"
  end
  local function group(g) -- "[a,@unite,c]" : la cible ressort des autres conditions
    return paint("[", palette.cond) .. g:sub(2, -2):gsub("[^,]+", function(c)
      local unit = c:find("^%s*@") or c:lower():find("^%s*target=")
      return paint(c, unit and palette.target or palette.cond)
    end) .. paint("]", palette.cond)
  end
  local function args(s) return (s:gsub("[^;]+", function(a) return paint(a, palette.arg) end)) end
  return (text:gsub("[^\n]+", function(line)
    local lead, rest = line:match("^(%s*)(.*)$")
    local first = rest:sub(1, 1)
    if first == "#" then
      local word, tail = rest:match("^(#%S*)(.*)$")
      return lead .. paint(word, palette.meta) .. paint(tail, palette.arg)
    elseif first ~= "/" then
      return paint(line)
    end
    local cmd, tail = rest:match("^(/[^%s%[]*)(.*)$")
    local key = cmd:lower()
    local out = { lead, paint(cmd, palette.commands and palette.commands[key] or palette.command) }
    if key == "/run" or key == "/script" then -- du Lua : ses crochets ne sont pas des conditions
      out[#out + 1] = paint(tail, palette.arg)
      return table.concat(out)
    end
    local pos = 1
    while pos <= #tail do
      local s, e = tail:find("%b[]", pos)
      out[#out + 1] = args(tail:sub(pos, (s or #tail + 1) - 1))
      if not s then break end
      out[#out + 1] = group(tail:sub(s, e))
      pos = e + 1
    end
    return table.concat(out)
  end))
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
    -- un nom present mais pas encore traduit est protege tel quel : « Bandage » n'est pas remplace dans « Heavy Bandage »
    local target = body:find(name, 1, true) and (lookup(name, getName, getItemName) or name)
    if target then
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
    warnings[#warnings + 1] = L["Familier : ses ordres et techniques ne partent pas sur une monture ni juste après en être descendu. Appuie une seconde fois."]
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

-- texte venu d'ailleurs affiche tel quel : un | seul serait lu comme un code de couleur ou de lien
function ns.Plain(s) return (tostring(s):gsub("|", "||")) end

---------------------------------------------------------------------------
-- Envoi a un autre joueur : le texte "BF1:" coupe en messages "id:index:total:donnees"
---------------------------------------------------------------------------
-- un message d'add-on porte 255 octets ; un export fait au plus ~870 octets (nom et corps echappes)
local CHUNK, MAX_CHUNKS, MAX_BYTES, MAX_PENDING, MAX_PER_SENDER = 200, 6, 1000, 8, 2
ns.SHARE_TIMEOUT = 30

function ns.Chunks(payload, id)
  local parts, pos = {}, 1
  while pos <= #payload do
    local last = math.min(#payload, pos + CHUNK - 1)
    -- jamais au milieu d'un caractere UTF-8 (octets de suite : 128 a 191)
    while last > pos and last < #payload and payload:byte(last + 1) >= 128 and payload:byte(last + 1) < 192 do last = last - 1 end
    parts[#parts + 1] = payload:sub(pos, last)
    pos = last + 1
  end
  if #parts == 0 or #parts > MAX_CHUNKS or #payload > MAX_BYTES then return nil end
  for i, part in ipairs(parts) do parts[i] = ("%s:%d:%d:%s"):format(id, i, #parts, part) end
  return parts
end

-- Reception : box:Receive(expediteur, message, heure) renvoie le texte complet au dernier morceau, sinon nil.
-- Tout message douteux est ignore sans bruit ; un transfert incomplet est oublie apres ns.SHARE_TIMEOUT secondes.
function ns.NewInbox()
  local box = { pending = {}, count = 0 }
  local function drop(key)
    if box.pending[key] then
      box.pending[key] = nil
      box.count = box.count - 1
    end
  end
  function box:Receive(sender, msg, now)
    for key, t in pairs(self.pending) do
      if now - t.at > ns.SHARE_TIMEOUT then drop(key) end
    end
    if type(sender) ~= "string" or type(msg) ~= "string" or #msg > 255 then return nil end
    local id, index, total, data = msg:match("^(%w+):(%d+):(%d+):(.+)$")
    index, total = tonumber(index), tonumber(total)
    if not id or #id > 6 or total < 1 or total > MAX_CHUNKS or index < 1 or index > total then return nil end
    local prefix = sender .. "\0"
    local key = prefix .. id
    local t = self.pending[key]
    if t and t.total ~= total then
      drop(key)
      t = nil
    end
    if not t then
      local mine = 0
      for k in pairs(self.pending) do
        if k:sub(1, #prefix) == prefix then mine = mine + 1 end
      end
      if self.count >= MAX_PENDING or mine >= MAX_PER_SENDER then return nil end
      t = { total = total, parts = {}, have = 0, bytes = 0, at = now }
      self.pending[key] = t
      self.count = self.count + 1
    end
    if t.parts[index] then return nil end -- doublon
    t.parts[index], t.have, t.bytes = data, t.have + 1, t.bytes + #data
    if t.bytes > MAX_BYTES then
      drop(key)
      return nil
    end
    if t.have < t.total then return nil end
    drop(key)
    return table.concat(t.parts)
  end
  return box
end

---------------------------------------------------------------------------
-- Historique annuler / retablir : pile bornee de copies de la liste de blocs
---------------------------------------------------------------------------
function ns.CloneBlocks(blocks)
  local out = {}
  for i, b in ipairs(blocks) do
    local copy = { type = b.type, arg = b.arg, reset = b.reset }
    if b.clauses then
      copy.clauses = {}
      for j, clause in ipairs(b.clauses) do
        local conds = {}
        for k, cond in ipairs(clause.conds) do conds[k] = cond end
        copy.clauses[j] = { conds = conds, arg = clause.arg, alt = clause.alt }
      end
    end
    out[i] = copy
  end
  return out
end

-- empreinte d'un etat : contrairement au texte compile, elle voit les blocs et les alternatives encore vides
function ns.BlocksKey(blocks)
  local out = {}
  for _, b in ipairs(blocks) do
    out[#out + 1] = b.type .. "\1" .. (b.arg or "") .. "\1" .. (b.reset or "")
    for _, clause in ipairs(b.clauses or {}) do
      out[#out + 1] = "\2" .. table.concat(clause.conds, ",") .. "\1" .. (clause.alt or "") .. "\1" .. (clause.arg or "")
    end
  end
  return table.concat(out, "\3")
end

function ns.NewHistory(max)
  local h = { states = {}, at = 0, max = max or 50 }
  -- tag : deux enregistrements de suite avec le meme tag (frappe dans un champ) ne font qu'une etape
  function h:Record(blocks, tag)
    local key = ns.BlocksKey(blocks)
    local current = self.states[self.at]
    if current and current.key == key then return false end
    for i = #self.states, self.at + 1, -1 do self.states[i] = nil end -- un changement efface ce qui etait a retablir
    local state = { key = key, blocks = ns.CloneBlocks(blocks) }
    if tag and tag == self.tag then
      self.states[self.at] = state
    else
      self.states[#self.states + 1] = state
      if #self.states > self.max then table.remove(self.states, 1) end
      self.at = #self.states
    end
    self.tag = tag
    return true
  end
  local function move(self, step)
    local state = self.states[self.at + step]
    if not state then return nil end
    self.at, self.tag = self.at + step, nil
    return ns.CloneBlocks(state.blocks)
  end
  function h:Undo() return move(self, -1) end
  function h:Redo() return move(self, 1) end
  function h:CanUndo() return self.at > 1 end
  function h:CanRedo() return self.at < #self.states end
  return h
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

---------------------------------------------------------------------------
-- Assistant : recettes de macros pour un sort ou un objet
--   kind : "harm" | "help" | "either" (inconnu, ou les deux) | "pet" (technique du familier) | "item"
--   applies(kind, hasPet) ; build(nom, options) -> texte de macro
--   options : kind, showtooltip, nodead, stopattack (sans effet pour une aide ou un objet)
--   editorOnly : la macro contient un nom a remplacer, elle ne se cree pas telle quelle
--   desc tient sur une ligne de carte (608 px) : une centaine de caracteres au plus
---------------------------------------------------------------------------
local function forKinds(list)
  local set = {}
  for kind in list:gmatch("%a+") do set[kind] = true end
  return function(kind) return set[kind] == true end
end

local function alive(o) return o.nodead and ",nodead" or "" end

-- ce que le sort attend de l'unite survolee
local function wanted(o) return (o.kind == "harm" or o.kind == "help") and o.kind or "exists" end

-- tooltipName : #showtooltip nomme le sort, quand une ligne /use passe avant lui
local function recipeText(o, lines, tooltipName)
  local out = {}
  if o.showtooltip then out[1] = tooltipName and ("#showtooltip " .. tooltipName) or "#showtooltip" end
  if o.stopattack and o.kind ~= "help" and o.kind ~= "item" then out[#out + 1] = "/stopattack" end
  for _, line in ipairs(lines) do out[#out + 1] = line end
  return table.concat(out, "\n")
end

ns.Recipes = {
  { id = "mouseover_harm", title = L["Survol, sinon cible"],
    desc = L["Lance le sort sur l'ennemi sous ta souris ; sans survol, sur ta cible."],
    applies = forKinds("harm either pet"),
    build = function(name, o) return recipeText(o, { "/cast [@mouseover,harm" .. alive(o) .. "][] " .. name }) end },
  { id = "mouseover_help", title = L["Survol, sinon cible, sinon moi"],
    desc = L["Lance le sort sur l'allié sous ta souris, sinon sur ta cible amie, sinon sur toi."],
    applies = forKinds("help either pet"),
    build = function(name, o)
      return recipeText(o, { "/cast [@mouseover,help" .. alive(o) .. "][help" .. alive(o) .. "][@player] " .. name })
    end },
  { id = "focus_mod", title = L["Focus avec Maj"],
    desc = L["Maj maintenue : sur ton focus. Sinon sur l'unité sous ta souris, sinon sur ta cible."],
    applies = forKinds("harm help either pet"),
    build = function(name, o)
      return recipeText(o, { "/cast [mod:shift,@focus][@mouseover," .. wanted(o) .. alive(o) .. "][] " .. name })
    end },
  { id = "interrupt_focus", title = L["Interruption sur le focus"],
    desc = L["Arrête ton incantation, puis lance le sort sur ton focus s'il est hostile, sinon sur ta cible."],
    applies = forKinds("harm either pet"),
    build = function(name, o) return recipeText(o, { "/stopcasting", "/cast [@focus,harm" .. alive(o) .. "][] " .. name }) end },
  { id = "nearest", title = L["Ennemi le plus proche si pas de cible"],
    desc = L["Sans cible, prend l'ennemi le plus proche, puis lance le sort."],
    applies = forKinds("harm either"),
    build = function(name, o)
      return recipeText(o, { "/targetenemy [noexists]" .. (o.nodead and "[dead]" or ""), "/cast " .. name })
    end },
  { id = "self_alt", title = L["Sur moi avec Alt"],
    desc = L["Alt maintenue : sur toi. Sinon sur l'allié sous ta souris, sinon sur ta cible."],
    applies = forKinds("help either"),
    build = function(name, o) return recipeText(o, { "/cast [mod:alt,@player][@mouseover,help" .. alive(o) .. "][] " .. name }) end },
  { id = "with_pet", title = L["Avec le familier"],
    desc = L["Ton familier attaque ta cible, puis tu lances le sort."],
    applies = function(kind, hasPet) return hasPet == true and (kind == "harm" or kind == "either" or kind == "pet") end,
    build = function(name, o) return recipeText(o, { "/petattack", "/cast " .. name }) end },
  { id = "trinkets", title = L["Bijoux puis sort"],
    desc = L["Utilise tes deux bijoux (emplacements 13 et 14), puis lance le sort."],
    applies = forKinds("harm either"),
    build = function(name, o) return recipeText(o, { "/use 13", "/use 14", "/cast " .. name }, name) end },
  { id = "stopcasting", title = L["Annuler l'incantation en cours"],
    desc = L["Arrête ce que tu incantes, pour que celui-ci parte tout de suite."],
    applies = forKinds("harm help either pet item"),
    build = function(name, o) return recipeText(o, { "/stopcasting", (o.kind == "item" and "/use " or "/cast ") .. name }) end },
  { id = "sequence", title = L["Séquence de deux sorts"], editorOnly = true,
    desc = L["Chaque appui lance le sort suivant. Remplace « Deuxième sort » dans l'éditeur."],
    applies = forKinds("harm help either"),
    build = function(name, o) return recipeText(o, { "/castsequence reset=target " .. name .. ", " .. L["Deuxième sort"] }) end },
  { id = "item_fallback", title = L["Objet, puis sort"], editorOnly = true,
    desc = L["Utilise l'objet, puis lance le sort. Remplace « Sort de secours » dans l'éditeur."],
    applies = forKinds("item"),
    build = function(name, o) return recipeText(o, { "/use " .. name, "/cast " .. L["Sort de secours"] }) end },
  -- Recettes vivantes (feature : coupees avec la fonction). Les jetons {bf:...} sont remplaces par de vrais noms a l'enregistrement.
  -- name : nom de la macro, quand elle ne porte pas celui du sort choisi.
  -- Pierre et potion n'ont pas le meme temps de recharge : selon le jeu, les deux peuvent partir sur le meme appui.
  -- Le bandage se canalise : il reste derriere une touche, pour ne pas partir avec la potion.
  { id = "survival", feature = "living", name = L["Survie"], title = L["Bouton de survie"],
    desc = L["Pierre de soins, sinon ta meilleure potion ; avec une touche tenue : bandage. Suit tes sacs tout seul."],
    applies = forKinds("item"),
    build = function(_, o)
      return recipeText(o, { "/use [nomod] {bf:pierre_soin}", "/use [nomod] {bf:potion_soin}", "/use [mod] {bf:bandage}" })
    end },
  { id = "living_trinkets", feature = "living", title = L["Bijoux vivants"],
    desc = L["Tes deux bijoux par leur nom, puis le sort : la macro suit les bijoux que tu portes."],
    applies = forKinds("harm either"),
    build = function(name, o) return recipeText(o, { "/use {bf:bijou13}", "/use {bf:bijou14}", "/cast " .. name }, name) end },
}

-- nom de macro tire d'un nom de sort : 16 octets au plus (max : moins, pour laisser la place a un suffixe), sans couper un caractere UTF-8
function ns.MacroName(name, max)
  name = trim(name)
  local last = math.min(#name, max or 16)
  while last > 0 and last < #name and name:byte(last + 1) >= 128 and name:byte(last + 1) < 192 do last = last - 1 end
  return trim(name:sub(1, last))
end

---------------------------------------------------------------------------
-- V1 lot A : barres d'action, bilan de sante, jauge, suggestions. Logique pure : les API du jeu sont injectees (env).
---------------------------------------------------------------------------
-- texte de macro compare sans tenir compte des espaces : lignes rognees, espaces reduits, lignes vides retirees
function ns.NormBody(body)
  local lines = {}
  for line in ((body or "") .. "\n"):gmatch("(.-)\r?\n") do
    line = trim((line:gsub("%s+", " ")))
    if line ~= "" then lines[#lines + 1] = line end
  end
  return table.concat(lines, "\n")
end

-- nom de raccourci du bouton d'un emplacement ; nil pour la page 2 et les postures, qui prennent les touches de la barre principale
local BAR_BINDINGS = { [0] = "ACTIONBUTTON", [2] = "MULTIACTIONBAR3BUTTON", [3] = "MULTIACTIONBAR4BUTTON", [4] = "MULTIACTIONBAR2BUTTON",
  [5] = "MULTIACTIONBAR1BUTTON", [12] = "MULTIACTIONBAR5BUTTON", [13] = "MULTIACTIONBAR6BUTTON", [14] = "MULTIACTIONBAR7BUTTON" }
function ns.SlotBinding(slot)
  local prefix = BAR_BINDINGS[math.floor((slot - 1) / 12)]
  return prefix and (prefix .. ((slot - 1) % 12 + 1)) or nil
end

-- Quelle macro du jeu est dans un emplacement ? Selon le client, l'identifiant rendu est l'index de la macro, ou autre
-- chose (le sort qu'elle lancerait). text : nom affiche sur le bouton ; macros : { index, name, body } ; env.spellName(id).
-- Renvoie la macro et la methode ("index", "name", "body"), ou nil et "none".
-- shortcut: deux macros de meme nom (generale et personnage) sont confondues, a departager par l'index si la sonde de /bf test le permet
function ns.ResolveMacro(id, sub, text, macros, env)
  local byIndex, byName
  for _, m in ipairs(macros) do
    if m.index == id then byIndex = m end
    if text and text ~= "" and m.name == text and (not byName or m.index == id) then byName = m end
  end
  if byName then return byName, byName == byIndex and "index" or "name" end
  if byIndex and (sub == nil or sub == "" or sub == "macro") then return byIndex, "index" end
  local spell = sub == "spell" and env and env.spellName and env.spellName(id)
  if spell then
    local found, n = nil, 0
    for _, m in ipairs(macros) do
      if (m.body or ""):find(spell, 1, true) then found, n = m, n + 1 end
    end
    if n == 1 then return found, "body" end
  end
  return nil, "none"
end

-- env.slots, env.macros, env.action(slot) -> type, id, sous-type ; env.name(type, id) -> nom, icone ; facultatifs :
-- env.text(slot), env.texture(slot), env.key(slot, nomDeMacro), env.spellName(id).
-- Renvoie la liste { slot, kind, id, name, icon, macroName, macroIndex, key, how } et des comptes.
-- kind : "spell", "item", "macro", "empty", ou "other" (monture, ensemble, familier... : jamais touche).
function ns.ScanBars(env)
  local list, stats = {}, { content = 0, spells = 0, items = 0, macros = 0, other = 0, unresolved = 0 }
  for _, slot in ipairs(env.slots) do
    local kind, id, sub = env.action(slot)
    local e = { slot = slot, kind = "empty" }
    if kind == "spell" or kind == "item" then
      e.id = id
      e.name, e.icon = env.name(kind, id)
      e.kind = e.name and kind or "other" -- sans nom, pas de macro possible
    elseif kind == "macro" then
      e.kind, e.id, e.sub = "macro", id, sub
      local m, how = ns.ResolveMacro(id, sub, env.text and env.text(slot), env.macros, env)
      e.how = how
      if m then
        e.macroName, e.macroIndex, e.name, e.icon = m.name, m.index, m.name, m.icon
      else
        stats.unresolved = stats.unresolved + 1
      end
    elseif kind then
      e.kind, e.id, e.raw = "other", id, kind
    end
    if e.kind ~= "empty" then
      stats.content = stats.content + 1
      local count = e.kind == "other" and "other" or (e.kind .. "s")
      stats[count] = stats[count] + 1
      e.icon = e.icon or (env.texture and env.texture(slot)) or nil
    end
    e.key = env.key and env.key(slot, e.macroName) or nil
    list[#list + 1] = e
  end
  return list, stats
end

-- Conversion en masse : chaque sort des barres du type voulu ("help" ou "harm") recoit la macro de env.build.
-- env.kind(nom) ; env.build(nom a lancer) -> texte ; env.cast(entree) -> nom a lancer, suffixe du nom de macro (rang).
-- items : { slot, spell, macroName, body, create | reuse } ; skipped : meme forme avec skip = "name" (une autre macro
-- porte ce nom) ou "long" ; need : macros a creer. Une macro du meme nom n'est jamais ecrasee en masse.
function ns.BulkPlan(scan, want, macros, env)
  local plan, byName, made = { items = {}, skipped = {}, need = 0 }, {}, {}
  for _, m in ipairs(macros) do byName[m.name] = byName[m.name] or m end
  for _, e in ipairs(scan) do
    if e.kind == "spell" and env.kind(e.name) == want then
      local cast, tag = e.name, ""
      if env.cast then cast, tag = env.cast(e) end
      local item = { slot = e.slot, spell = cast, icon = e.icon, macroName = ns.MacroName(e.name, 16 - #tag) .. tag, body = env.build(cast) }
      local key, have = ns.NormBody(item.body), byName[item.macroName]
      if #item.body > ns.MAX_CHARS then
        item.skip = "long"
      elseif made[item.macroName] then
        if made[item.macroName] == key then item.reuse = true else item.skip = "name" end
      elseif have then
        if ns.NormBody(have.body) == key then item.reuse, made[item.macroName] = true, key else item.skip = "name" end
      else
        item.create, made[item.macroName] = true, key
        plan.need = plan.need + 1
      end
      local into = item.skip and plan.skipped or plan.items
      into[#into + 1] = item
    end
  end
  return plan
end

-- remplace un nom de sort par un autre dans un texte de macro, mot entier seulement
function ns.FixSpell(body, old, new)
  local out, from = {}, 1
  while old ~= "" do
    local s, e = body:find(old, from, true)
    if not s then break end
    local whole = not isWordChar(body:sub(s - 1, s - 1)) and not isWordChar(body:sub(e + 1, e + 1))
    out[#out + 1] = body:sub(from, s - 1) .. (whole and new or old)
    from = e + 1
  end
  out[#out + 1] = body:sub(from)
  return table.concat(out)
end

-- Bilan de sante des macros du jeu. macros : { name, body, ... }.
-- env.unknown(corps) -> noms de sorts inconnus ; env.nearest(nom) -> nom proche du grimoire ou nil ;
-- env.used(macro) -> posee sur une barre ou liee a une touche ; env.orphans == false : barres illisibles, groupe laisse vide.
-- Chaque groupe liste des { macro = m, ... } : broken (fix = { faux, juste }, ou maybe = nom que rien n'explique),
-- duplicates (of = la premiere macro de meme texte), orphans, risky (warning = premier avertissement de ns.Diagnose).
function ns.HealthCheck(macros, env)
  local report = { broken = {}, duplicates = {}, orphans = {}, risky = {}, total = #macros }
  local first = {}
  for _, m in ipairs(macros) do
    local fix, maybe
    for _, name in ipairs(env.unknown(m.body)) do
      local near = env.nearest(name)
      if near then fix = fix or { name, near } else maybe = maybe or name end
    end
    if fix or maybe then report.broken[#report.broken + 1] = { macro = m, fix = fix, maybe = not fix and maybe or nil } end
    local key = ns.NormBody(m.body)
    if key ~= "" then
      if first[key] then report.duplicates[#report.duplicates + 1] = { macro = m, of = first[key] } else first[key] = m end
    end
    if env.orphans ~= false and not env.used(m) then report.orphans[#report.orphans + 1] = { macro = m } end
    local _, warnings = ns.Diagnose(ns.Parse(m.body or ""))
    if #warnings > 0 then report.risky[#report.risky + 1] = { macro = m, warning = warnings[1] } end
  end
  return report
end

-- jauge des emplacements de macro : texte court et niveau ("ok", "warn" a partir de 85 %, "full")
function ns.Gauge(account, maxAccount, char, maxChar)
  local worst = math.max(account / maxAccount, char / maxChar)
  return ("%d / %d · %d / %d"):format(account, maxAccount, char, maxChar), worst >= 1 and "full" or worst >= 0.85 and "warn" or "ok"
end

-- Suggestions de l'accueil : parmi candidates ({ name, body, ... }, deja filtrees par classe et sorts connus),
-- celles que le joueur n'a pas (ni le nom, ni le texte aux espaces pres), max au plus.
function ns.Suggestions(candidates, macros, max)
  local names, bodies, out = {}, {}, {}
  for _, m in ipairs(macros) do
    names[ns.Fold(m.name)] = true
    bodies[ns.NormBody(m.body)] = true
  end
  for _, c in ipairs(candidates) do
    if #out >= (max or 5) then break end
    local key = ns.NormBody(c.body)
    if not names[ns.Fold(c.name)] and not names[ns.Fold(ns.MacroName(c.name))] and not bodies[key] then
      out[#out + 1] = c
      bodies[key] = true -- pas deux fois la meme macro
    end
  end
  return out
end

---------------------------------------------------------------------------
-- V1 lot B : macros vivantes, profils. Logique pure : sacs, equipement, raccourcis et barres sont injectes (env).
---------------------------------------------------------------------------
-- Objets des jetons, du meilleur au moins bon : { ID, niveau requis }. IDs ecrits de memoire des donnees de l'ere
-- classique, a verifier en jeu par /bf test. Pierres de soins : trois ID par rang (talent), aucun niveau retenu.
-- shortcut: bandages sans controle de la competence Secourisme, a lire dans les metiers si un bandage trop haut est choisi
ns.LivingItems = {
  potion_soin = { { 13446, 45 }, { 3928, 35 }, { 1710, 21 }, { 929, 12 }, { 858, 3 }, { 118, 1 } },
  potion_mana = { { 13444, 49 }, { 13443, 41 }, { 6149, 31 }, { 3827, 22 }, { 3385, 14 }, { 2455, 5 } },
  pierre_soin = { { 19013, 1 }, { 19012, 1 }, { 9421, 1 }, { 19011, 1 }, { 19010, 1 }, { 5510, 1 }, { 19009, 1 }, { 19008, 1 }, { 5509, 1 },
                  { 19007, 1 }, { 19006, 1 }, { 5511, 1 }, { 19005, 1 }, { 19004, 1 }, { 5512, 1 } },
  bandage = { { 14530, 1 }, { 14529, 1 }, { 8545, 1 }, { 8544, 1 }, { 6451, 1 }, { 6450, 1 }, { 3531, 1 }, { 3530, 1 }, { 2581, 1 }, { 1251, 1 } },
  nourriture = { { 22895, 55 }, { 8076, 45 }, { 8075, 35 }, { 1487, 25 }, { 1114, 15 }, { 1113, 5 }, { 5349, 1 },
                 { 8950, 45 }, { 4601, 35 }, { 4544, 25 }, { 4542, 15 }, { 4541, 5 }, { 4540, 1 },
                 { 8952, 45 }, { 4599, 35 }, { 3771, 25 }, { 3770, 15 }, { 2287, 5 }, { 117, 1 } },
  eau = { { 8079, 55 }, { 8078, 45 }, { 8077, 35 }, { 3772, 25 }, { 2136, 15 }, { 2288, 5 }, { 5350, 1 },
          { 8766, 45 }, { 1645, 35 }, { 1708, 25 }, { 1205, 15 }, { 1179, 5 }, { 159, 1 } },
}

-- Jetons proposes par « Vivant… ». slot : emplacement d'equipement lu par son nom. Le focus n'en fait pas partie : il change en combat.
ns.LivingTokens = {
  { id = "potion_soin", label = L["Potion de soin"], tip = L["La meilleure potion de soin de tes sacs que ton niveau permet."] },
  { id = "potion_mana", label = L["Potion de mana"], tip = L["La meilleure potion de mana de tes sacs que ton niveau permet."] },
  { id = "pierre_soin", label = L["Pierre de soins"], tip = L["La meilleure pierre de soins de démoniste de tes sacs, quel que soit son rang."] },
  { id = "bandage", label = L["Bandage"], tip = L["Le meilleur bandage de tes sacs."] },
  { id = "nourriture", label = L["Nourriture"], tip = L["La meilleure nourriture de tes sacs que ton niveau permet."] },
  { id = "eau", label = L["Eau"], tip = L["La meilleure boisson de tes sacs que ton niveau permet."] },
  { id = "bijou13", slot = 13, label = L["Bijou du haut"], tip = L["Le nom du bijou que tu portes dans cet emplacement."] },
  { id = "bijou14", slot = 14, label = L["Bijou du bas"], tip = L["Le nom du bijou que tu portes dans cet emplacement."] },
  { id = "arme", slot = 16, label = L["Arme en main droite"], tip = L["Le nom de l'arme que tu tiens en main droite."] },
  { id = "main_gauche", slot = 17, label = L["Main gauche"], tip = L["Le nom de l'arme ou du bouclier que tu tiens en main gauche."] },
  { id = "monture", label = L["Ma monture"], tip = L["La première monture trouvée dans tes sacs, si les montures sont des objets sur ce client."] },
  { id = "familier", label = L["Nom de mon familier"], tip = L["Le nom du familier sorti."] },
  { id = "sort", label = L["Plus haut rang du sort"], tip = L["Écrit le nom du sort sans son rang : le jeu lance alors le plus haut rang que tu connais."] },
}
local tokenById, TOKEN = {}, "{bf:([%w_]+):?([^}]*)}"
for _, t in ipairs(ns.LivingTokens) do tokenById[t.id] = t end
-- objets reconnus par leur type quand le client le donne (nourriture, boisson, monture), en plus des listes ci-dessus
local TOKEN_KIND = { nourriture = "food", eau = "drink", monture = "mount" }

function ns.HasTokens(text) return (text or ""):find("{bf:", 1, true) ~= nil end

-- jetons d'un texte, sans doublon : { raw = "{bf:sort:Peur}", id = "sort", param = "Peur", label }
function ns.TokensOf(text)
  local list, seen = {}, {}
  for raw, id, param in (text or ""):gmatch("(" .. TOKEN .. ")") do
    if not seen[raw] then
      seen[raw] = true
      list[#list + 1] = { raw = raw, id = id, param = param, label = tokenById[id] and tokenById[id].label or id }
    end
  end
  return list
end

-- texte montre au joueur : « <Potion de soin> » a la place du jeton
function ns.TokenText(text)
  return (text:gsub(TOKEN, function(id, param)
    return "<" .. (tokenById[id] and tokenById[id].label or id) .. (param ~= "" and (" " .. param) or "") .. ">"
  end))
end

-- env : level ; bags = { { id, name, kind ("food" | "drink" | "mount" | nil), level } } ; slots[13 | 14 | 16 | 17] = nom ;
-- pet = nom ; itemName(id) (facultatif). Renvoie le nom, et true s'il vient vraiment des sacs ou de l'equipement.
function ns.ResolveToken(id, param, env)
  local def = tokenById[id]
  if not def then return nil, false end
  if id == "sort" then
    local name = trim(((param or ""):gsub("%s*%(.-%)%s*$", "")))
    if name == "" then return nil, false end
    return name, true
  elseif id == "familier" then
    return env.pet, env.pet ~= nil
  elseif def.slot then
    local name = env.slots and env.slots[def.slot]
    return name, name ~= nil
  end
  local curated, rank = ns.LivingItems[id] or {}, {}
  for i, e in ipairs(curated) do rank[e[1]] = i end
  local best, bestLevel, bestRank
  for _, item in ipairs(env.bags or {}) do
    local r = rank[item.id]
    local level = (r and curated[r][2]) or (item.kind ~= nil and item.kind == TOKEN_KIND[id] and (item.level or 0)) or nil
    if level and item.name and level <= (env.level or 60) then
      r = r or 1000
      if not best or level > bestLevel or (level == bestLevel and r < bestRank) then best, bestLevel, bestRank = item.name, level, r end
    end
  end
  if best then return best, true end
  -- rien dans les sacs : le plus petit objet de la liste donne au moins un nom a ecrire
  local lowest = curated[#curated]
  return lowest and env.itemName and env.itemName(lowest[1]) or nil, false
end

-- Remplace chaque jeton du modele par un vrai nom. last[jeton] : nom ecrit la derniere fois, garde quand les sacs sont vides.
-- Renvoie le texte (nil si un jeton n'a aucun nom), names[jeton] = nom, et la liste des jetons sans objet (« rien dans les sacs »).
function ns.ResolveLiving(template, env, last)
  local names, missing, body = {}, {}, template
  for _, t in ipairs(ns.TokensOf(template)) do
    local name, found = ns.ResolveToken(t.id, t.param, env)
    if not found then
      name = (last and last[t.raw]) or name
      missing[#missing + 1] = t.raw
    end
    if not name then return nil, names, missing end
    names[t.raw] = name
    body = body:gsub(t.raw:gsub("%p", "%%%0"), (name:gsub("%%", "%%%%")))
  end
  return body, names, missing
end

---------------------------------------------------------------------------
-- Profil entier en texte : "BF2:nom:nombre" puis, par macro, ":a|c:nom:corps" (a = generale, c = personnage).
-- Macros seulement : ni raccourcis ni barres. Meme echappement et memes controles que "BF1:".
---------------------------------------------------------------------------
local MAX_PROFILE_MACROS, MAX_PROFILE_BYTES = 150, 200000

-- codec (facultatif) : pack(texte) -> texte compresse imprimable, unpack(texte) -> texte ; nil ou erreur si le client ne sait pas
function ns.ExportProfile(name, macros, codec)
  local parts = { "BF2", escape(name), tostring(#macros) }
  for _, m in ipairs(macros) do
    parts[#parts + 1] = m.char and "c" or "a"
    parts[#parts + 1] = escape(m.name)
    parts[#parts + 1] = escape(m.body)
  end
  local plain = table.concat(parts, ":")
  -- compresse seulement si l'aller-retour redonne le texte exact, et s'il est plus court
  local ok, packed = pcall(function()
    local z = codec and codec.pack and codec.pack(plain)
    return type(z) == "string" and not z:find("[^%w%+/=_%-]") and codec.unpack(z) == plain and z or nil
  end)
  if ok and packed and #packed + 5 < #plain then return "BF2z:" .. packed end
  return plain
end

-- renvoie { name, macros = { { name, body, char } } }, ou nil et la raison
function ns.ImportProfile(str, codec)
  str = trim(type(str) == "string" and str or "")
  if #str > MAX_PROFILE_BYTES then return nil, L["Texte trop long."] end
  local packed = str:match("^BF2z:(.+)$")
  if packed then
    local ok, plain = pcall(function() return codec and codec.unpack and codec.unpack(packed) end)
    if not ok or type(plain) ~= "string" then
      return nil, L["Ce texte est compressé et ce client ne sait pas le lire : demande un export non compressé."]
    end
    if #plain > MAX_PROFILE_BYTES then return nil, L["Texte trop long."] end
    str = plain
  end
  local fields = {}
  for field in (str .. ":"):gmatch("([^:]*):") do fields[#fields + 1] = field end
  if fields[1] ~= "BF2" then return nil, L["Texte non reconnu : il doit commencer par « BF2: »."] end
  local n = tonumber(fields[3])
  if not n or n < 1 or n > MAX_PROFILE_MACROS or n ~= math.floor(n) or #fields ~= 3 + n * 3 then
    return nil, L["Profil abîmé : le nombre de macros ne correspond pas."]
  end
  if fields[2]:gsub("%%%x%x", ""):find("[%%|%c]") then return nil, L["Texte abîmé : caractère inattendu."] end
  local profile, seen = { name = trim((unescape(fields[2]):gsub("[|%c]", ""))):sub(1, 40), macros = {} }, {}
  for i = 1, n do
    local scope = fields[3 * i + 1]
    local name, body = ns.Import("BF1:" .. fields[3 * i + 2] .. ":" .. fields[3 * i + 3])
    if not name then return nil, body end
    if (scope ~= "a" and scope ~= "c") or seen[scope .. name] then return nil, L["Profil abîmé : le nombre de macros ne correspond pas."] end
    seen[scope .. name] = true
    profile.macros[i] = { name = name, body = body, char = scope == "c" }
  end
  return profile
end

---------------------------------------------------------------------------
-- Activation d'un profil : ce qui changerait, sans rien toucher.
-- profile : { macros = { { name, body, char, icon } }, bindings = { [macro] = { touches } }, bars = { [emplacement] = macro } }
-- opts : update (reecrire une macro de meme nom au texte different), remove (retirer les macros absentes), keys, bars
-- env.binding(touche) -> action liee ou "" ; env.slot(emplacement) -> entree de ns.ScanBars ; env.unknown(corps) -> noms inconnus
-- Renvoie create, same, left (listes de macros), update ({ macro, old }), remove, binds ({ key, macro, replaces }),
-- slots ({ slot, macro, before }), blocked (emplacements jamais touches), need / freed [macro du personnage ?], unknown.
---------------------------------------------------------------------------
function ns.ProfilePlan(profile, macros, opts, env)
  local plan = { create = {}, update = {}, left = {}, same = {}, remove = {}, binds = {}, slots = {}, blocked = {},
                 need = { [false] = 0, [true] = 0 }, freed = { [false] = 0, [true] = 0 }, unknown = 0 }
  local have, wanted, names = {}, {}, {}
  local function key(m) return (m.char and "c" or "a") .. m.name end
  for _, m in ipairs(macros) do have[key(m)] = m end
  for _, m in ipairs(type(profile.macros) == "table" and profile.macros or {}) do
    local valid = type(m) == "table" and type(m.name) == "string" and type(m.body) == "string" and trim(m.name) ~= ""
      and #m.name:gsub("[\128-\191]", "") <= 16 and #m.body <= ns.MAX_CHARS
    if valid and not wanted[key(m)] then
      wanted[key(m)], names[m.name] = m, true
      local old, char = have[key(m)], m.char and true or false
      if not old then
        plan.create[#plan.create + 1] = m
        plan.need[char] = plan.need[char] + 1
      elseif ns.NormBody(old.body) == ns.NormBody(m.body) then
        plan.same[#plan.same + 1] = m
      elseif opts.update then
        plan.update[#plan.update + 1] = { macro = m, old = old }
      else
        plan.left[#plan.left + 1] = m
      end
      if env.unknown and #env.unknown(m.body) > 0 then plan.unknown = plan.unknown + 1 end
    end
  end
  if opts.remove then
    for _, m in ipairs(macros) do
      if not wanted[key(m)] then
        plan.remove[#plan.remove + 1] = m
        plan.freed[m.char and true or false] = plan.freed[m.char and true or false] + 1
      end
    end
  end
  if opts.keys and type(profile.bindings) == "table" then
    for name, keys in pairs(profile.bindings) do
      for _, k in ipairs(names[name] and type(keys) == "table" and keys or {}) do
        local now = type(k) == "string" and (env.binding(k) or "") or nil
        if now and now ~= "MACRO " .. name then
          plan.binds[#plan.binds + 1] = { key = k, macro = name, replaces = now ~= "" and now or nil }
        end
      end
    end
    table.sort(plan.binds, function(a, b) return a.key < b.key end)
  end
  if opts.bars and type(profile.bars) == "table" then
    for slot, name in pairs(profile.bars) do
      local now = type(slot) == "number" and names[name] and env.slot(slot)
      if now and now.macroName ~= name then
        if now.kind == "other" then
          plan.blocked[#plan.blocked + 1] = slot
        else
          plan.slots[#plan.slots + 1] = { slot = slot, macro = name, before = now }
        end
      end
    end
    table.sort(plan.slots, function(a, b) return a.slot < b.slot end)
    table.sort(plan.blocked)
  end
  return plan
end
