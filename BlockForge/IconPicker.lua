-- BlockForge : choix de l'icone d'une macro. Grille defilante : 48 boutons reutilises, quelle que soit la taille de la liste.
local ADDON, ns = ...
local L = ns.L

local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local COLS, ROWS, CELL = 8, 6, 38 -- boutons de 36 px, 2 px d'ecart

-- false = "Automatique", puis les icones du grimoire, puis celles que le jeu propose pour les macros (si le client les donne)
local macroIcons
function ns.IconChoices()
  local list, seen = { false }, { [134400] = true, INV_Misc_QuestionMark = true } -- le point d'interrogation : deja en tete
  local function Add(icon)
    if icon and not seen[icon] then
      seen[icon] = true
      list[#list + 1] = icon
    end
  end
  local getSpellIcon = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
  if getSpellIcon and not InCombatLockdown() then -- pas de recherche de sort en combat (valeurs secretes)
    for _, name in ipairs(ns.SpellBook()) do Add(getSpellIcon(name)) end
  end
  if not macroIcons then
    macroIcons = {}
    if GetMacroIcons then pcall(GetMacroIcons, macroIcons) end
  end
  for _, icon in ipairs(macroIcons) do Add(icon) end
  return list
end

-- anciens clients : GetMacroIcons donne des noms de fichier sans dossier
local function Path(icon)
  if type(icon) == "string" and not icon:find("[\\/]") then return "Interface\\Icons\\" .. icon end
  return icon
end

-- onPick(icone) : nil pour "Automatique"
function ns.BuildIconPicker(parent, onPick)
  local ui, T = ns.ui, ns.Theme
  -- 8 colonnes : 8 + 8 x 38 - 2 + 8 = 318 ; 6 lignes depuis -28 finissent a -254 (panneau : 262)
  local picker = ui.Panel(parent, 318, 262, L["Icône de la macro"])
  picker:SetFrameStrata("DIALOG")
  picker:EnableMouse(true) -- le fond arrete les clics : pas de clic sur ce qui est dessous
  picker:Hide()
  local range = picker:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  range:SetPoint("RIGHT", picker.band, "RIGHT", -6, 0)

  local cells, icons, offset, current = {}, {}, 0, nil
  local function Render()
    local last = math.max(0, math.ceil((#icons - #cells) / COLS) * COLS)
    offset = math.max(0, math.min(offset, last))
    for i, cell in ipairs(cells) do
      local icon = icons[offset + i]
      cell:SetShown(icon ~= nil)
      if icon ~= nil then
        cell.icon:SetTexture(icon and Path(icon) or QUESTION)
        local c = (icon or nil) == current and T.accent or T.grey
        cell:SetBackdropBorderColor(c[1], c[2], c[3], 1)
      end
    end
    range:SetText(#icons > #cells
      and L["%d-%d / %d  (molette)"]:format(offset + 1, math.min(offset + #cells, #icons), #icons) or "")
  end

  for i = 1, COLS * ROWS do
    local cell = ui.IconButton(picker)
    cell:SetPoint("TOPLEFT", 8 + ((i - 1) % COLS) * CELL, -28 - math.floor((i - 1) / COLS) * CELL)
    cell:SetScript("OnClick", function()
      picker:Hide()
      onPick(icons[offset + i] or nil)
    end)
    ui.Tip(cell, function()
      if icons[offset + i] == false then
        return L["Automatique"], L["Le jeu choisit l'icône : celle de #showtooltip, sinon du premier sort ou objet de la macro."]
      end
    end)
    cells[i] = cell
  end
  picker:EnableMouseWheel(true)
  picker:SetScript("OnMouseWheel", function(_, delta)
    offset = offset - delta * COLS * 2
    Render()
  end)

  -- chosen : icone actuelle de la macro (nil = automatique) ; la grille s'ouvre sur sa ligne
  function picker:Toggle(chosen)
    if self:IsShown() then return self:Hide() end
    icons, current, offset = ns.IconChoices(), chosen, 0
    for i = 2, #icons do
      if icons[i] == chosen then offset = math.floor((i - 1) / COLS) * COLS break end
    end
    Render()
    self:Show()
  end
  return picker
end
