-- BlockForge : palette de l'interface. La couleur d'accent suit le reglage (classe du joueur ou or).
local ADDON, ns = ...

local T = {
  gold   = { 1, 0.82, 0.1 },
  accent = { 1, 0.82, 0.1 }, -- modifiee sur place par ns.ApplyTheme : toute reference la suit
  grey   = { 0.3, 0.3, 0.34 },
  muted  = { 0.62, 0.62, 0.66 },
  button = { 0.42, 0.42, 0.48 },
  close  = { 0.9, 0.35, 0.35 },
  window = { 0.07, 0.07, 0.09 },
  panel  = { 0.03, 0.03, 0.05 },
  band   = { 0.13, 0.13, 0.17 },
  border = { 0.45, 0.45, 0.5 },
  row    = { 0.09, 0.09, 0.11 },
  -- une couleur par groupe de conditions (meme ordre que ns.ConditionGroups)
  groups = { { 0.35, 0.75, 0.95 }, { 0.95, 0.45, 0.45 }, { 0.72, 0.52, 0.98 }, { 0.98, 0.66, 0.25 }, { 0.45, 0.85, 0.55 } },
  category = { PvE = { 0.25, 0.55, 0.95 }, PvP = { 0.9, 0.35, 0.35 }, Pet = { 0.85, 0.7, 0.2 }, Utility = { 0.3, 0.75, 0.4 } },
  sim = { ok = "|cff66ff66", off = "|cff777777", unknown = "|cffffaa33" },
  -- palette de ns.Colorize (RRGGBB) ; commands est rempli plus bas : chaque commande a la couleur de son bloc
  code = { command = "66bbff", meta = "9aa0b0", cond = "ffb347", target = "66dd88", arg = "f2f2f2", commands = {} },
}
ns.Theme = T

function T.Light(c) return math.min(1, c[1] + 0.25), math.min(1, c[2] + 0.25), math.min(1, c[3] + 0.25) end

function T.Hex(r, g, b)
  return ("%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

for _, def in ipairs(ns.BlockDefs or {}) do
  if def.cmd:sub(1, 1) == "/" then T.code.commands[def.cmd] = T.Hex(T.Light(def.color)) end
end

-- texte de macro affiche : colore, ou d'une seule couleur si le joueur a coupe la fonction
function ns.Code(text)
  if ns.Enabled and not ns.Enabled("colorize") then return ns.Plain(text) end
  return ns.Colorize(text, T.code)
end

local watchers = {}
-- fn peint un element a la couleur d'accent : appelee tout de suite, puis a chaque changement du reglage
function T.Watch(fn)
  watchers[#watchers + 1] = fn
  fn()
end
-- pour ce qui ne peut pas etre peint tout de suite (fenetre en cours de construction)
function T.OnChange(fn) watchers[#watchers + 1] = fn end

function T.Accent(texture, alpha)
  T.Watch(function() texture:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], alpha or 1) end)
  return texture
end

function T.AccentText(fontString)
  T.Watch(function() fontString:SetTextColor(T.accent[1], T.accent[2], T.accent[3]) end)
  return fontString
end

function ns.ApplyTheme()
  local c = T.gold
  if ns.db and ns.db.accent == "class" and RAID_CLASS_COLORS and UnitClass then
    local _, class = UnitClass("player")
    local cc = class and RAID_CLASS_COLORS[class]
    if cc and cc.r then c = { cc.r, cc.g, cc.b } end
  end
  T.accent[1], T.accent[2], T.accent[3] = c[1], c[2], c[3]
  for _, fn in ipairs(watchers) do fn() end
end
