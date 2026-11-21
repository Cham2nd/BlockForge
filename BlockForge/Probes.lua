-- Sondes isolees : les appels facultatifs restent lisibles meme quand le client les refuse.
local ADDON, ns = ...
local L = ns.L

local function Lookup(path)
  local value = _G
  for key in path:gmatch("[^.]+") do
    if type(value) ~= "table" then return nil end
    value = value[key]
  end
  return value
end

local function Values(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
  return table.concat(parts, ",")
end

local function Safe(fn, ...)
  if type(fn) ~= "function" then return "absent" end
  local function result(ok, ...)
    return ok and Values(...) or tostring((...))
  end
  return result(pcall(fn, ...))
end

local function Has(path) return Lookup(path) ~= nil and "present" or "absent" end

local function DB()
  if type(ns.db.selftest) ~= "table" then ns.db.selftest = {} end
  return ns.db.selftest
end

local function Bags(visit)
  local slots = Lookup("C_Container.GetContainerNumSlots") or GetContainerNumSlots
  local item = Lookup("C_Container.GetContainerItemID") or GetContainerItemID
  if type(slots) ~= "function" or type(item) ~= "function" then return "absent" end
  for bag = 0, NUM_BAG_SLOTS or 4 do
    local n = slots(bag)
    for slot = 1, n or 0 do
      local id = item(bag, slot)
      if id and visit(id) == false then return end
    end
  end
end

local cold = CreateFrame("Frame")
cold:RegisterEvent("PLAYER_ENTERING_WORLD")
cold:SetScript("OnEvent", function()
  if not ns.db then return end
  local ok, count = pcall(function()
    local name = Lookup("C_Item.GetItemNameByID")
    if type(name) ~= "function" then return "absent" end
    local n = 0
    local missing = Bags(function(id) if name(id) == nil then n = n + 1 end end)
    return missing or n
  end)
  DB().cold = ok and count or tostring(count)
end)

function ns.ReleaseProbes(out)
  local bookOK, book = pcall(ns.SpellBook)
  local spell = bookOK and book and book[1]
  local id = spell and ns.SpellIDs[spell]
  if not id and spell and Lookup("C_Spell.GetSpellInfo") then
    local ok, info = pcall(C_Spell.GetSpellInfo, spell)
    if ok and type(info) == "table" then id = info.spellID end
  end
  local checks = {
    {2, function() return Safe(SecureCmdOptionParse, "[combat] A; [mod:shift] B; C") end},
    {3, function() return Safe(Lookup("C_Spell.IsSpellUsable"), id) .. " " .. Safe(Lookup("C_Spell.IsSpellInRange"), id, "target") .. " " .. Has("C_Item.IsUsableItem") end},
    {4, function()
      local fn = Lookup("C_Spell.GetSpellCooldown")
      if type(fn) ~= "function" then return "absent" end
      local c = fn(id)
      return type(c) .. " secret=" .. Safe(issecretvalue, c and c.duration)
    end},
    {5, function() return Has("C_Secrets.ShouldSpellCooldownBeSecret") .. " " .. Has("C_Secrets.HasSecretRestrictions") .. " " .. Has("issecretvalue") .. " " .. Has("canaccessvalue") end},
    {6, function()
      local enum = Lookup("Enum.AddOnRestrictionType")
      if type(enum) ~= "table" then return "absent" end
      local parts = {}
      for name, value in pairs(enum) do parts[#parts+1] = name .. "=" .. Safe(Lookup("C_RestrictedActions.IsAddOnRestrictionActive"), value) end
      table.sort(parts)
      return table.concat(parts, " ")
    end},
    {7, function() return Safe(Lookup("C_ChatInfo.AreOutgoingAddonChatMessagesRestricted")) .. " " .. Safe(Lookup("C_ChatInfo.InChatMessagingLockdown")) end},
    {9, function()
      local parts = {}
      for _, name in ipairs({"SetBindingClick", "SetBindingSpell", "SetBindingItem", "SetOverrideBindingClick", "ClearOverrideBindings"}) do parts[#parts+1] = name .. "=" .. Has(name) end
      return table.concat(parts, " ")
    end},
    {12, function() return Has("GameTooltip.SetSpellByID") .. " " .. Has("GameTooltip.SetItemByID") .. " " .. Has("C_TooltipInfo.GetSpellByID") end},
    {14, function()
      local fn = Lookup("C_EditMode.GetLayouts")
      if type(fn) ~= "function" then return "absent" end
      local layouts = fn()
      return tostring(layouts and layouts.activeLayout) .. " " .. tostring(layouts and layouts.layouts and #layouts.layouts)
    end},
    {15, function() return tostring(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or "absent") .. " " .. tostring(SOUNDKIT and SOUNDKIT.U_CHAT_SCROLL_BUTTON or "absent") end},
    {16, function() return Has("C_ActionBar.FindSpellActionButtons") .. " " .. Has("C_ActionBar.IsUsableAction") .. " " .. Has("C_ActionBar.IsMacroActionWithShowTooltip") end},
    {17, function() return Safe(Lookup("C_SpecializationInfo.GetNumSpecGroups")) .. " spec:2=" .. Safe(SecureCmdOptionParse, "[spec:2] Y; N") end},
    {18, function()
      local instant, effect = Lookup("C_Item.GetItemInfoInstant") or GetItemInfoInstant, Lookup("C_Item.GetItemSpell") or GetItemSpell
      if type(instant) ~= "function" or type(effect) ~= "function" then return "absent" end
      local lines, seen = {}, {}
      local missing = Bags(function(item)
        if not seen[item] then
          seen[item] = true
          local _, _, _, _, _, class, sub = instant(item)
          if class == 0 and sub == 5 then lines[#lines+1] = tostring(item) .. " " .. Safe(effect, item) end
        end
        if #lines >= 20 then return false end
      end)
      return missing or table.concat(lines, "; ") .. " food=" .. Safe(Lookup("C_Spell.GetSpellName"), 433) .. " drink=" .. Safe(Lookup("C_Spell.GetSpellName"), 430)
    end},
    {19, function() return tostring(DB().cold or "absent") end},
    {20, function() return Safe(Lookup("C_RestrictedActions.CheckAllowProtectedFunctions"), ns.probeButton, true) end},
    {21, function() return MacroFrame and Safe(MacroFrame.IsShown, MacroFrame) or "false" end},
  }
  for _, check in ipairs(checks) do
    local ok, value = pcall(check[2])
    out[#out+1] = "INFO V" .. check[1] .. " " .. tostring(value)
  end
  local saved = DB()
  for _, key in ipairs({"V1", "V8", "V10", "V11", "V13"}) do
    local value = saved.probe and saved.probe[key] or "absent"
    if key == "V1" and saved.clicked then value = true if saved.probe then saved.probe.V1 = true end end
    if key == "V13" and saved.link then value = "true" end
    out[#out+1] = "INFO " .. key .. " " .. tostring(value)
  end
end

local function Link(link)
  if link == "addon:BlockForge:probe" and ns.db then
    local saved = DB()
    saved.link = true
    if saved.probe then saved.probe.V13 = true end
  end
end

local function HookLink()
  if ns.probeLinkHooked then return "present" end
  if EventRegistry and type(EventRegistry.RegisterCallback) == "function" then
    local ok = pcall(EventRegistry.RegisterCallback, EventRegistry, "SetItemRef", function(_, link) Link(link) end, ns)
    if ok then ns.probeLinkHooked = true return "present" end
  end
  if type(hooksecurefunc) == "function" and type(SetItemRef) == "function" then
    local ok, err = pcall(hooksecurefunc, "SetItemRef", Link)
    if ok then ns.probeLinkHooked = true return "present" end
    return tostring(err)
  end
  return "absent"
end

local function Binding(frame)
  if type(GetBindingAction) ~= "function" or type(SetOverrideBindingClick) ~= "function" or type(ClearOverrideBindings) ~= "function" then return "absent" end
  local key = "CTRL-SHIFT-F12"
  local ok, base = pcall(GetBindingAction, key)
  if not ok then return tostring(base) end
  local read, override = pcall(GetBindingAction, key, true)
  if not read then return tostring(override) end
  if (base and base ~= "") or (override and override ~= "") then return "occupied" end
  local set, err = pcall(SetOverrideBindingClick, frame, true, key, "BlockForgeProbeButton")
  local action = set and Safe(GetBindingAction, key, true) or tostring(err)
  local cleared, failure = pcall(ClearOverrideBindings, frame)
  return cleared and action or action .. " clear: " .. tostring(failure)
end

function ns.OpenProbe()
  if InCombatLockdown() then return ns.Msg(L["Impossible de modifier une macro en combat."]) end
  local saved = DB()
  saved.clicked, saved.link = false, false
  saved.probe = { V11 = Safe(GetCursorInfo) }
  local probe = saved.probe
  if not ns.probeFrame then
    local ok, frame = pcall(CreateFrame, "Frame", "BlockForgeProbeFrame", UIParent, "BackdropTemplate")
    if not ok then probe.V1 = tostring(frame) return end
    ns.probeFrame = frame
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    frame:SetBackdropColor(0.08, 0.09, 0.12, 0.98)
    frame:EnableMouse(true)
    frame:SetSize(340, 140)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "BlockForgeProbeFrame") end
    ns.ui.Label(frame, L["Sondes BlockForge"], 16, -16, "GameFontNormal")
    local made, button = pcall(CreateFrame, "Button", "BlockForgeProbeButton", frame, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    if made then
      ns.probeButton = button
      button:SetSize(144, 26)
      button:SetPoint("TOPLEFT", 16, -44)
      button:SetText(L["Clique ici"])
      probe.V1 = Safe(function()
        if type(button.RegisterForClicks) ~= "function" then return "absent" end
        button:RegisterForClicks("AnyUp", "AnyDown")
        button:SetAttribute("type", "macro")
        button:SetAttribute("macrotext", "/run BlockForgeDB.selftest.clicked=true")
        return "pending"
      end)
    else probe.V1 = tostring(button) end
    ns.probeClickResult = probe.V1
    local close = ns.ui.Button(frame, L["Terminé"], 144, function()
      frame:Hide()
      ns.Msg(L["Sondes enregistrées. Tape /reload pour les conserver."])
    end)
    close:SetPoint("TOPLEFT", 176, -44)
    ns.CloseChip(frame)
  else probe.V1 = ns.probeClickResult end
  ns.probeFrame:Show()
  probe.V13 = HookLink()
  if DEFAULT_CHAT_FRAME and type(DEFAULT_CHAT_FRAME.AddMessage) == "function" then
    pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "|Haddon:BlockForge:probe|h[" .. L["BlockForge : clique ici"] .. "]|h")
  end
  probe.V10 = Binding(ns.probeFrame)
  local ok, name = false, nil
  if type(UnitName) == "function" then ok, name = pcall(UnitName, "player") end
  local send = Lookup("C_ChatInfo.SendAddonMessage")
  if ok and type(name) == "string" and name ~= "" and type(send) == "function" then
    local sent, result = pcall(send, "BlockForge", "x", "WHISPER", name)
    if sent then probe.V8 = result else probe.V8 = tostring(result) end
  else probe.V8 = "absent" end
end
