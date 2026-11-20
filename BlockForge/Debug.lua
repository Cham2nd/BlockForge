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
local OPTIONAL = { "RAID_CLASS_COLORS", "GetMacroIcons", "GetPetActionInfo", "C_SpellBook.GetNumSpellBookSkillLines",
  -- cycle 3, lot 2 : envoi a un joueur, cible pre-remplie, Ctrl+Z / Ctrl+Y
  "C_ChatInfo.RegisterAddonMessagePrefix", "C_ChatInfo.SendAddonMessage", "GetTime", "UnitName", "GetNormalizedRealmName",
  "UnitExists", "UnitIsPlayer", "UnitIsFriend", "UnitIsUnit", "GetUnitName", "IsControlKeyDown", "GetCurrentKeyBoardFocus",
  "canaccessvalue",
  -- cycle 4, lot 1 : grimoire integre et Assistant
  "C_Spell.IsSpellPassive", "IsPassiveSpell", "C_Spell.IsSpellHarmful", "C_Spell.IsSpellHelpful", "IsHarmfulSpell", "IsHelpfulSpell",
  "C_Container.GetContainerNumSlots", "C_Container.GetContainerItemID", "GetContainerNumSlots", "GetContainerItemID",
  "C_Item.GetItemSpell", "GetItemSpell", "GetInventoryItemID", "NUM_BAG_SLOTS", "IsShiftKeyDown",
  -- V1 lot A : barres d'action, bilan de sante ; et ce que les lots suivants comptent utiliser
  "GetActionInfo", "HasAction", "GetActionText", "GetActionTexture", "C_ActionBar.GetActionText", "C_ActionBar.PutActionInSlot",
  "PlaceAction", "PickupAction", "PickupSpell", "C_Spell.PickupSpell", "PickupItem", "C_Item.PickupItem", "DeleteMacro",
  "C_Spell.GetSpellSubtext", "MultiBar5", "MultiBar7", "C_KeyBindings.GetBindingByKey",
  "C_EncodingUtil.CompressString", "C_EncodingUtil.SerializeCBOR", "C_EncodingUtil.EncodeBase64",
  "C_SpecializationInfo.GetActiveSpecGroup", "C_SpecializationInfo.GetNumSpecGroups", "C_SpecializationInfo.GetSpecialization",
  "GetNumSpecGroups", "GetActiveSpecGroup", "C_Traits", "C_ClassTalents", "GetTalentInfo", "C_Container.GetContainerItemInfo",
  "SecureCmdOptionParse", "RegisterAttributeDriver", "UnregisterAttributeDriver", "RegisterStateDriver", "SecureHandlerWrapScript",
  "AddonCompartmentFrame", "BlockForge_OnAddonCompartmentClick" }

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
    for _, key in ipairs({ "home", "editor", "library", "macros", "settings" }) do
      out[#out + 1] = errors[key] and ("FAIL tab " .. key .. ": " .. errors[key]) or ("OK tab " .. key)
    end
    local a = ns.Theme.accent
    out[#out + 1] = ("INFO look: accent %s = %.2f %.2f %.2f, opening fade %s, icon choices %d"):format(
      tostring(ns.db.accent), a[1], a[2], a[3], ns.fade and "on" or "absent", #ns.IconChoices())
  end },
  { "lot 2", function(out)
    -- aller-retour de l'envoi : la plus longue macro de la bibliotheque, coupee puis recollee dans le desordre
    local longest = ns.Library[1]
    for _, e in ipairs(ns.Library) do
      if #e.body > #longest.body then longest = e end
    end
    local payload = ns.Export(longest.name, longest.body)
    local chunks, box, got = ns.Chunks(payload, "1"), ns.NewInbox(), nil
    for i = #chunks, 1, -1 do got = box:Receive("selftest", chunks[i], 0) or got end
    out[#out + 1] = (got == payload and "OK" or "FAIL") .. (" share round trip: %d bytes in %d messages"):format(#payload, #chunks)
    local missing = {}
    for i, step in ipairs(ns.TutorialSteps) do
      if not step.anchor() then missing[#missing + 1] = tostring(i) end
    end
    out[#out + 1] = (#missing == 0 and "OK" or "FAIL") .. (" tutorial: %d steps, anchors missing: %s"):format(#ns.TutorialSteps, First(missing, 20))
    local w = ns.ed.w
    out[#out + 1] = ("INFO lot 2: sharing %s (accept %s), text editor %s, undo keys %s, personal macros %d, tutorial seen %s"):format(
      ns.CanShare() and "on" or "absent", tostring(ns.db.acceptShared), w.textToggle and "on" or "absent",
      ns.ed.keys and "on" or "absent", #ns.db.personal, tostring(ns.db.tutorialSeen))
  end },
  { "cycle 4", function(out)
    local spells, kinds = ns.GrimoireSpells(), { harm = 0, help = 0, either = 0 }
    for _, e in ipairs(spells) do
      local kind = ns.SpellKind(e.name)
      kinds[kind] = kinds[kind] + 1
    end
    out[#out + 1] = ("INFO grimoire: %d castable spells (%d harmful, %d helpful, %d either), %d pet abilities, %d usable items, pet out %s"):format(
      #spells, kinds.harm, kinds.help, kinds.either, #ns.PetAbilities(), #ns.BagItems(), tostring(ns.HasPet()))
    -- chaque recette, pour un vrai sort du personnage : relue sans perte et sans avertissement
    local name, bad = spells[1] and spells[1].name or "Test", {}
    for _, r in ipairs(ns.Recipes) do
      local text = r.build(name, { kind = "either", showtooltip = true, nodead = true, stopattack = true })
      local _, warnings = ns.Diagnose(ns.Parse(text))
      if ns.Compile(ns.Parse(text)) ~= text or #text > ns.MAX_CHARS or #warnings > 0 then bad[#bad + 1] = r.id end
    end
    out[#out + 1] = (#bad == 0 and "OK" or "FAIL") .. (" assistant recipes: %d, broken: %s"):format(#ns.Recipes, First(bad, 20))
    local w = ns.ed.w
    out[#out + 1] = (w.grimoireButton and w.assistantButton and "OK" or "FAIL") .. " grimoire and assistant buttons"
  end },
  -- Sondes de l'etude technique (P4, P6, P7, P10, P11, P13 en partie), en lecture seule : rien ici ne modifie
  -- une barre, une macro ou un raccourci. Les observations brutes sont relues dans BlockForgeDB.selftest.
  { "v1 lot A", function(out)
    local function safe(fn, ...)
      if type(fn) ~= "function" then return "absent" end
      local ok, v = pcall(fn, ...)
      return ok and tostring(v) or "error"
    end
    local function has(path) return Lookup(path) ~= nil and "present" or "absent" end
    local scan, stats = ns.Bars.Scan()
    if not scan then
      out[#out + 1] = "INFO probe bars: GetActionInfo absent, bar tools off"
    else
      out[#out + 1] = ("INFO probe bars: %d slots read, %d with content (%d spells, %d items, %d macros, %d other), bars 6-8 (slots 145-180) %s"):format(
        #scan, stats.content, stats.spells, stats.items, stats.macros, stats.other, #scan > 120 and "read" or "absent")
      local shown = 0
      for _, e in ipairs(scan) do
        if e.kind == "macro" and shown < 6 then
          shown = shown + 1
          local byId = type(e.id) == "number" and e.id >= 1 and e.id <= 150 and GetMacroInfo(e.id) or nil
          out[#out + 1] = ("INFO probe P4 GetActionInfo(%d) = macro, id %s, subtype %s ; C_ActionBar.GetActionText %s, GetActionText %s ; GetMacroInfo(id) %s ; identified by %s as %s"):format(
            e.slot, tostring(e.id), tostring(e.sub), safe(C_ActionBar and C_ActionBar.GetActionText, e.slot), safe(GetActionText, e.slot),
            tostring(byId), tostring(e.how), tostring(e.macroName))
        end
      end
      if stats.macros == 0 then
        out[#out + 1] = "INFO probe P4: no macro on the bars ; put one on a bar and run /bf test again"
      else
        out[#out + 1] = (stats.unresolved == 0 and "OK" or "FAIL") .. (" macros on bars identified: %d / %d"):format(stats.macros - stats.unresolved, stats.macros)
      end
    end
    local keys, bound = {}, 0
    for _, binding in ipairs({ "ACTIONBUTTON1", "MULTIACTIONBAR1BUTTON1", "MULTIACTIONBAR3BUTTON1", "MULTIACTIONBAR5BUTTON1" }) do
      keys[#keys + 1] = binding .. "=" .. safe(GetBindingKey, binding)
    end
    for _, m in ipairs(ns.ReadMacros()) do
      if GetBindingKey("MACRO " .. m.name) then bound = bound + 1 end
    end
    out[#out + 1] = ("INFO probe bindings: %s ; %d macros bound to a key"):format(table.concat(keys, ", "), bound)
    out[#out + 1] = ("INFO probe actions: PlaceAction %s, PickupAction %s, PickupMacro %s, DeleteMacro %s, PickupSpell %s / %s, PickupItem %s / %s, C_ActionBar %s"):format(
      has("PlaceAction"), has("PickupAction"), has("PickupMacro"), has("DeleteMacro"), has("PickupSpell"), has("C_Spell.PickupSpell"),
      has("PickupItem"), has("C_Item.PickupItem"), has("C_ActionBar"))
    local S = C_SpecializationInfo or {}
    out[#out + 1] = ("INFO probe P6 spec: C_SpecializationInfo %s, active group %s, groups %s, specialization %s ; GetActiveSpecGroup %s, GetNumSpecGroups %s ; C_Traits %s, C_ClassTalents %s, GetTalentInfo %s"):format(
      has("C_SpecializationInfo"), safe(S.GetActiveSpecGroup), safe(S.GetNumSpecGroups), safe(S.GetSpecialization),
      safe(GetActiveSpecGroup), safe(GetNumSpecGroups), has("C_Traits"), has("C_ClassTalents"), has("GetTalentInfo"))
    out[#out + 1] = ("INFO probe containers: C_Container %s, slots in bag 0 %s"):format(has("C_Container"), safe(C_Container and C_Container.GetContainerNumSlots, 0))
    if type(SecureCmdOptionParse) == "function" then
      -- une condition comprise repond differemment a [c] et a [noc] ; une condition inconnue repond pareil, ou echoue
      local results = {}
      for _, cond in ipairs({ "combat", "mounted", "pet", "spec:1", "spec:2", "known:" .. (ns.SpellBook()[1] or "?"), "form:1", "stance:1",
                              "group", "indoors", "flyable", "talent:1/1", "exists", "harm", "help" }) do
        local ok1, a = pcall(SecureCmdOptionParse, "[" .. cond .. "] Y; N")
        local ok2, b = pcall(SecureCmdOptionParse, "[no" .. cond .. "] Y; N")
        results[#results + 1] = cond .. "=" .. ((not ok1 or not ok2) and "error" or (a ~= b and "understood:" or "ignored:") .. tostring(a))
      end
      out[#out + 1] = "INFO probe P7 conditions: " .. table.concat(results, ", ")
    else
      out[#out + 1] = "INFO probe P7 conditions: SecureCmdOptionParse absent"
    end
    local E = C_EncodingUtil
    if not E then
      out[#out + 1] = "INFO probe P10 C_EncodingUtil: absent"
    else
      local src = string.rep("/cast [@mouseover,help,nodead][] Test\n", 20)
      local ok, err = pcall(function()
        local method = Enum.CompressionMethod.Deflate
        local packed = E.CompressString(src, method)
        local text = E.EncodeBase64(packed)
        out[#out + 1] = ("INFO probe P10 C_EncodingUtil: %d bytes, %d compressed, %d in base64, round trip %s, CBOR %s"):format(#src, #packed, #text,
          tostring(E.DecompressString(E.DecodeBase64(text), method) == src), tostring(E.DeserializeCBOR(E.SerializeCBOR({ body = src })).body == src))
      end)
      if not ok then out[#out + 1] = "INFO probe P10 C_EncodingUtil: present, error " .. tostring(err) end
    end
    -- bouton securise : cree une seule fois, cache, sans attribut ni raccourci
    if ns.probeButton == nil then
      local ok, button = pcall(CreateFrame, "Button", nil, UIParent, "SecureActionButtonTemplate")
      ns.probeButton = ok and button or false
      if ns.probeButton then ns.probeButton:Hide() end
    end
    out[#out + 1] = ("INFO probe P13 secure button: SecureActionButtonTemplate %s out of combat ; RegisterAttributeDriver %s, RegisterStateDriver %s, SecureHandlerWrapScript %s"):format(
      ns.probeButton and "created" or "refused", has("RegisterAttributeDriver"), has("RegisterStateDriver"), has("SecureHandlerWrapScript"))
    out[#out + 1] = ("INFO probe P11 compartment: AddonCompartmentFrame %s, TOC function %s"):format(has("AddonCompartmentFrame"), has("BlockForge_OnAddonCompartmentClick"))

    local states = {}
    for _, def in ipairs(ns.Features) do states[#states + 1] = def.id .. "=" .. (ns.Enabled(def.id) and "on" or "off") end
    out[#out + 1] = "INFO features: " .. table.concat(states, ", ")
    local account, char = GetNumMacros()
    local maxAccount, maxChar = ns.MacroLimits()
    local gauge, level = ns.Gauge(account or 0, maxAccount, char or 0, maxChar)
    local home, report = ns.home, ns.Health.Report()
    out[#out + 1] = (home and ns.ed.w.home and "OK" or "FAIL") .. (" home tab: %d entries, %d suggestions, gauge %s (%s)"):format(
      #ns.HomeActions, home and #home.suggestions or 0, gauge, level)
    out[#out + 1] = ("INFO health: %d macros, %d broken, %d duplicates, %d orphans (bars fully read: %s), %d at risk ; undo pending: %s"):format(
      report.total, #report.broken, #report.duplicates, #report.orphans, tostring(report.orphansKnown), #report.risky, tostring(ns.UndoLabel()))
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
