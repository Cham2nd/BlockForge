-- BlockForge : bouton rond autour de la minicarte (sans bibliotheque externe) + menu des add-ons (Forever)
local ADDON, ns = ...
local L = ns.L

local ICON = "Interface\\Icons\\INV_Misc_Book_09"
local atan2 = math.atan2 or math.atan -- Lua 5.1 en jeu ; math.atan(y, x) ailleurs
local button

local function Place()
  local angle = math.rad(ns.db.minimap.angle)
  local radius = Minimap:GetWidth() / 2 + 10 -- la minicarte de Forever est ronde
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function DragUpdate()
  local mx, my = Minimap:GetCenter()
  local px, py = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  ns.db.minimap.angle = math.deg(atan2(py / scale - my, px / scale - mx)) % 360
  Place()
end

local function ShowTooltip(owner)
  GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
  GameTooltip:SetText("BlockForge", 1, 1, 1)
  GameTooltip:AddLine(L["Clic gauche : ouvrir / fermer"], 0.8, 0.8, 0.8)
  GameTooltip:AddLine(L["Clic droit : paramètres"], 0.8, 0.8, 0.8)
  if owner == button then GameTooltip:AddLine(L["Glisser : déplacer autour de la minicarte"], 0.8, 0.8, 0.8) end
  GameTooltip:Show()
end

local function OnClick(mouseButton)
  if mouseButton == "RightButton" then ns.OpenSettings() else ns.Toggle() end
end

local function Create()
  -- disposition des boutons de minicarte classiques : bordure 53 px en haut a gauche d'un bouton de 31 px
  button = CreateFrame("Button", "BlockForgeMinimapButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  local bg = button:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  bg:SetSize(20, 20)
  bg:SetPoint("TOPLEFT", 7, -5)
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetTexture(ICON)
  icon:SetSize(17, 17)
  icon:SetPoint("TOPLEFT", 7, -6)
  icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")
  button:SetScript("OnClick", function(_, mouseButton) OnClick(mouseButton) end)
  button:SetScript("OnDragStart", function(self)
    GameTooltip:Hide()
    self:SetScript("OnUpdate", DragUpdate)
  end)
  button:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    DragUpdate()
  end)
  button:SetScript("OnEnter", ShowTooltip)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function ns.UpdateMinimapButton()
  if not ns.db or not Minimap then return end
  if not button then
    if not ns.db.minimap.show then return end
    Create()
  end
  button:SetShown(ns.db.minimap.show)
  Place()
end

-- Menu des add-ons de la minicarte (## AddonCompartmentFunc dans le .toc) ; ignore sur Classic Era
function BlockForge_OnAddonCompartmentClick(_, mouseButton) OnClick(mouseButton) end
function BlockForge_OnAddonCompartmentEnter(_, menuButton) ShowTooltip(menuButton) end
function BlockForge_OnAddonCompartmentLeave() GameTooltip:Hide() end
