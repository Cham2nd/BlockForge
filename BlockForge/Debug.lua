-- BlockForge : diagnostics relus hors du jeu dans SavedVariables (ecrits au /reload ou a la deconnexion)
--   BlockForgeDB.errors   : 20 dernieres erreurs Lua qui citent l'add-on
--   BlockForgeDB.selftest : rapport de /bf test
local ADDON, ns = ...
local L = ns.L

local MAX_ERRORS, MAX_STACK = 20, 1500
local pending = {} -- erreurs du chargement des fichiers : BlockForgeDB n'existe pas encore

local function Version()
  local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  return tostring(get and get(ADDON, "Version") or "?")
end
ns.Version = Version -- affichee dans la barre de titre

local function Store(entry)
  local list = ns.db and ns.db.errors or pending
  list[#list + 1] = entry
  while #list > MAX_ERRORS do table.remove(list, 1) end
end

-- appele par ns.InitDB
function ns.FlushErrors()
  local list = pending
  pending = {}
  for _, entry in ipairs(list) do Store(entry) end
end

local function Record(msg)
  -- Midnight : un message secret ne peut pas etre lu par un add-on
  if canaccessvalue and not canaccessvalue(msg) then return end
  if type(msg) ~= "string" or not msg:find("BlockForge", 1, true) then return end
  -- meme calcul que Blizzard_ScriptErrors : la pile au moment de l'erreur, pas celle du gestionnaire
  local level = 3
  if GetCallstackHeight and GetErrorCallstackHeight and GetErrorCallstackHeight() then
    level = GetCallstackHeight() - (GetErrorCallstackHeight() - 1)
  end
  local ok, stack = pcall(debugstack, level)
  Store({ time = date("%Y-%m-%d %H:%M:%S"), version = Version(), message = msg,
          stack = ok and type(stack) == "string" and stack:sub(1, MAX_STACK) or "" })
end

-- le gestionnaire precedent recoit toujours l'erreur, telle quelle
if geterrorhandler and seterrorhandler then
  local previous, busy = geterrorhandler(), false
  pcall(seterrorhandler, function(msg, ...)
    if not busy then
      busy = true
      pcall(Record, msg)
      busy = false
    end
    if previous then return previous(msg, ...) end
  end)
end

---------------------------------------------------------------------------
-- /bf test : verifications dans le vrai client, sans toucher aux macros ni aux raccourcis
---------------------------------------------------------------------------
local APIS = {
  "C_Spell.GetSpellName", "C_Spell.GetSpellInfo", "C_Spell.GetSpellTexture",
  "C_Item.GetItemInfo", "C_Item.GetItemIconByID", "C_Item.GetItemNameByID", "C_Item.RequestLoadItemDataByID",
  "C_AddOns.GetAddOnMetadata", "Settings.RegisterCanvasLayoutCategory", "Settings.RegisterAddOnCategory",
  "CreateMacro", "EditMacro", "PickupMacro", "GetMacroInfo", "GetMacroIndexByName", "GetNumMacros",
  "SetBindingMacro", "GetBindingAction", "GetBindingKey", "GetBindingName", "GetCurrentBindingSet", "SaveBindings",
  "IsKeyPressIgnoredForBinding", "CreateKeyChordStringUsingMetaKeyState",
  "GetCursorInfo", "GetCursorPosition", "ClearCursor", "GetInventoryItemTexture", "InCombatLockdown",
  "UnitClass", "GetLocale", "StaticPopup_Show", "geterrorhandler", "seterrorhandler", "debugstack", "GetBuildInfo",
}

-- facultatives : l'add-on a un repli pour chacune, leur absence n'est pas un echec
local OPTIONAL = { "RAID_CLASS_COLORS", "GetMacroIcons", "GetPetActionInfo", "C_SpellBook.GetNumSpellBookSkillLines" }

local function Lookup(path)
  local v = _G
  for key in path:gmatch("[^.]+") do v = type(v) == "table" and v[key] or nil end
  return v
end

local function First(list, n) return table.concat(list, ", ", 1, math.min(#list, n)) end

local CHECKS = {
  { "api", function(out)
    for _, path in ipairs(APIS) do
      out[#out + 1] = (type(Lookup(path)) == "function" and "OK api " or "FAIL api absent: ") .. path
    end
    for _, path in ipairs(OPTIONAL) do
      out[#out + 1] = "INFO optional api " .. (Lookup(path) ~= nil and "present: " or "absent: ") .. path
    end
  end },
  { "round trip", function(out)
    local bad = {}
    for _, e in ipairs(ns.Library) do
      if ns.Compile(ns.Parse(e.body)) ~= e.body then bad[#bad + 1] = e.class .. "/" .. e.name end
    end
    out[#out + 1] = (#bad == 0 and "OK" or "FAIL") .. (" round trip Parse/Compile: %d / %d differ %s"):format(#bad, #ns.Library, First(bad, 10))
  end },
  { "spell ids", function(out)
    local missing, n = {}, 0
    for name, id in pairs(ns.SpellIDs) do
      n = n + 1
      if not C_Spell.GetSpellName(id) then missing[#missing + 1] = name .. "=" .. id end
    end
    table.sort(missing)
    out[#out + 1] = (#missing == 0 and "OK" or "FAIL") .. (" spell ids without name: %d / %d %s"):format(#missing, n, First(missing, 10))
  end },
  { "item ids", function(out)
    local missing, n = 0, 0
    for _, id in pairs(ns.ItemIDs) do
      n = n + 1
      if not C_Item.GetItemNameByID(id) then missing = missing + 1 end
    end
    out[#out + 1] = ("INFO items not cached yet: %d / %d"):format(missing, n)
  end },
  { "class", function(out)
    local _, class = UnitClass("player")
    local n, bad, names, seen = 0, 0, {}, {}
    for _, e in ipairs(ns.Library) do
      if e.class == class then
        n = n + 1
        local unknown = ns.LibraryUnknown(e)
        if #unknown > 0 then bad = bad + 1 end
        for _, name in ipairs(unknown) do
          if not seen[name] then
            seen[name] = true
            local near = ns.Nearest(name, ns.SpellBook())
            names[#names + 1] = near and (name .. " ~ " .. near) or name
          end
        end
      end
    end
    out[#out + 1] = ("INFO class %s: %d / %d library macros unusable, unknown spells: %s"):format(tostring(class), bad, n, First(names, 30))
  end },
  { "spellbook", function(out)
    local book = ns.SpellBook()
    out[#out + 1] = (#book > 0 and "OK" or "FAIL") .. (" spellbook: %d spells: %s"):format(#book, First(book, 200))
    local pet = {}
    for _, tpl in ipairs(ns.PetTemplates()) do pet[#pet + 1] = tpl.body:match("%] (.+)$") end
    out[#out + 1] = ("INFO pet abilities: %d: %s"):format(#pet, First(pet, 10))
  end },
  { "macros", function(out)
    local account, char = GetNumMacros()
    out[#out + 1] = ("INFO macros: %s account, %s character"):format(tostring(account), tostring(char))
  end },
  { "tabs", function(out)
    local errors = ns.TabErrors()
    for _, key in ipairs({ "editor", "library", "macros", "settings" }) do
      out[#out + 1] = errors[key] and ("FAIL tab " .. key .. ": " .. errors[key]) or ("OK tab " .. key)
    end
    local a = ns.Theme.accent
    out[#out + 1] = ("INFO look: accent %s = %.2f %.2f %.2f, opening fade %s, icon choices %d"):format(
      tostring(ns.db.accent), a[1], a[2], a[3], ns.fade and "on" or "absent", #ns.IconChoices())
  end },
}

function ns.SelfTest()
  local function Msg(text) print(L["|cff66ccffBlockForge|r : %s"]:format(text)) end
  if InCombatLockdown() then return Msg(L["Autotest impossible en combat."]) end
  local lines = {}
  for _, check in ipairs(CHECKS) do
    local ok, err = pcall(check[2], lines)
    if not ok then lines[#lines + 1] = "FAIL " .. check[1] .. ": " .. tostring(err) end
  end
  local passed, failed = 0, 0
  for _, line in ipairs(lines) do
    if line:find("^OK") then passed = passed + 1 elseif line:find("^FAIL") then failed = failed + 1 end
  end
  local version, build, _, toc = GetBuildInfo()
  local _, class = UnitClass("player")
  ns.db.selftest = { time = date("%Y-%m-%d %H:%M:%S"), version = Version(),
    build = ("%s %s %s"):format(tostring(version), tostring(build), tostring(toc)),
    locale = tostring(GetLocale()), class = tostring(class), lines = lines }
  Msg(L["Autotest : %d OK, %d en échec. Détails enregistrés, visibles après /reload."]:format(passed, failed))
end
