-- BlockForge : kits de personnage. Par classe et par role, une liste de references a la bibliotheque et aux recettes.
-- Aucune API du jeu ici : ns.BuildKit recoit ce qu'il lui faut (env), et tests/check_library.js controle chaque reference.
local ADDON, ns = ...
local L = ns.L

ns.KitRoles = {
  { id = "leveling", label = L["Montée de niveau"] },
  { id = "group", label = L["Donjon / raid"] },
  { id = "pvp", label = L["JcJ"] },
}
ns.KitPetClasses = { HUNTER = true, WARLOCK = true }

-- "Nom" : macro de la classe dans la bibliotheque ; "@Nom" : macro « toutes classes » ; "+" devant : seulement avec un familier.
-- extra : recettes, { recipe = id, spell = nom anglais de SpellIDs.lua, kind = "harm" | "help" }.
local function Refs(names, extra)
  local list = {}
  for name in names:gmatch("[^;]+") do
    name = ns.trim(name)
    local pet = name:sub(1, 1) == "+" or nil
    if pet then name = name:sub(2) end
    if name:sub(1, 1) == "@" then
      list[#list + 1] = { all = name:sub(2), pet = pet }
    else
      list[#list + 1] = { lib = name, pet = pet }
    end
  end
  for _, ref in ipairs(extra or {}) do list[#list + 1] = ref end
  return list
end
local SURVIVAL = { recipe = "survival" }

-- common : ajoute a la fin des trois roles de la classe. De 8 a 20 macros par kit, quels que soient la visee et le familier.
ns.Kits = {
  WARLOCK = {
    common = Refs("Demon Summon; Create Stones; Soulstone; Tap / Imp; Curses", { SURVIVAL }),
    leveling = Refs("+Pet Attack; +Pet Follow; +SB + Pet; +DoT Sequence; Fear MO; Drain Soul MO; +Consume Shadows; +Torment; @Next target; @Wand"),
    group = Refs("+Pet Attack; +Pet Follow; Banish Focus; DoT Mouseover; Banes; Shadowburn; Rain of Fire; Hellfire; +Sacrifice; @Assist focus; @Focus mouseover; @Trinkets"),
    pvp = Refs("+Pet Attack; +Pet Follow; +Spell Lock Focus; +Devour Magic MO; +Seduce MO; Fear MO; Fear Focus; Death Coil MO; Shadow Ward; Amp Exhaustion; @Target player; @Focus mouseover; @Trinkets"),
  },
  HUNTER = {
    common = Refs("+Pet Care; Feign Death; Aspects; Trap Switch; Tracking", { SURVIVAL }),
    leveling = Refs("Auto Shot; +Mark + Pet; +Pet Attack MO; +Pet Atk/Recall; Melee; Wing Clip; Hawk/Cheetah; +Growl Auto; Concussive MO; @Next target"),
    group = Refs("Auto Shot; Aimed Shot; +Mark + Pet; +Pet Attack MO; +Pet Atk/Recall; Tranq Shot; Distract Shot MO; Rapid Fire; AoE Shots; Volley; +Growl Auto; @Assist focus; @Trinkets"),
    pvp = Refs("Auto Shot; +Pet Attack MO; +Pet Atk/Recall; Scatter Shot; Freezing Trap; Wing Clip; Concussive MO; Viper Sting MO; Flare Cursor; Deterrence; +Intimidation; @Target player; @Focus mouseover"),
  },
  ROGUE = {
    common = Refs("Stealth; Panic; Evis/Rupture; Distract", { SURVIVAL }),
    leveling = Refs("CS / SS; Ambush/Backstab; PP + Cheap Shot; Riposte/SS; Gouge; Kick MO; Sap MO; Vanish; @Next target"),
    group = Refs("CS / SS; Combat Combo; Rogue Burst; Kick Focus; Kick MO; Sap MO; Vanish; Riposte/SS; @Assist focus; @Focus mouseover; @Trinkets"),
    pvp = Refs("Kick Focus; Kick MO; Blind; Sap PvP; Gouge; Kidney/Gouge; Vanish; Prem + CS; Stun Chain; Ambush/Backstab; @Target player; @Focus mouseover; @Trinkets"),
  },
  MAGE = {
    common = Refs("Conjure; Intellect; Armor Swap; Barrier; Decurse", { SURVIVAL }),
    leveling = Refs("Fire Blast MO; Frost Cycle; Fire Cycle; Nova Combo; Sheep Mouseover; AoE Cursor; Blink; @Wand; @Next target",
      { { recipe = "nearest", spell = "Frostbolt", kind = "harm" } }),
    group = Refs("Sheep Focus; Sheep Mouseover; CS Focus; AoE Cursor; Frost Cycle; Fire Cycle; Arcane Cycle; Fire Blast MO; Dampen/Amplify; Slow Fall MO; @Assist focus; @Focus mouseover; @Trinkets"),
    pvp = Refs("CS Mouseover; CS Focus; Sheep Mouseover; Sheep Focus; Ice Block; Blink; Nova R1; Frostbolt R1; Nova Combo; Fire Blast MO; @Target player; @Focus mouseover; @Trinkets"),
  },
  PRIEST = {
    common = Refs("Fortitude; Self Buffs; Shield Now; Fade; Rez Mouseover", { SURVIVAL }),
    leveling = Refs("Smite / Nova; Shadow DoTs; Shadow Cycle; Mind Flay; Renew MO; Flash Heal MO; Scream; @Wand; @Next target",
      { { recipe = "nearest", spell = "Smite", kind = "harm" } }),
    group = Refs("Flash Heal MO; GHeal Downrank; Renew MO; Dispel MO; Focus+PoH; Prayer Mending; Shackle MO; Levitate MO; PI Mouseover; @Focus mouseover; @Trinkets"),
    pvp = Refs("Dispel MO; Scream; Mana Burn MO; Fear Ward; SWD Focus; Silence Focus; Priest Panic; Flash Heal MO; Renew MO; Shadow DoTs; @Target player; @Focus mouseover; @Trinkets"),
  },
  DRUID = {
    common = Refs("Forms; Travel/Aqua; Cancel Form; Defensives; Decurse/Poison; Revive MO", { SURVIVAL }),
    leveling = Refs("Powershift Cat; Cat Combo; Prowl Opener; Bear Threat; Rejuv/Regrowth; Roots MO; Faerie Fire; Balance Nukes; @Next target"),
    group = Refs("Rejuv/Regrowth; HT Downrank; Swiftmend MO; Innervate MO; Rebirth MO; Faerie Fire; Cat Combo; Bear Threat; Balance DoTs; Hurricane; @Assist focus; @Focus mouseover; @Trinkets"),
    pvp = Refs("Dire Bear; Feral Charge; Bash; NS + HT; Roots MO; Powershift Cat; Rejuv/Regrowth; Faerie Fire; Prowl Opener; @Target player; @Focus mouseover; @Trinkets"),
  },
  WARRIOR = {
    common = Refs("Shouts; HS/Cleave; Execute; Debuffs", { SURVIVAL }),
    leveling = Refs("Charge+Bloodrage; Overpower; Victory Rush; Hamstring; Pummel/Bash; War AoE; Berserker Rage; @Next target"),
    group = Refs("Charge+Bloodrage; Taunt/Mocking; Taunt MO; Tank Panic; Block / Slam; Pummel/Bash; War AoE; Warrior Burst; Overpower; @Assist focus; @Focus mouseover; @Trinkets"),
    pvp = Refs("Charge/Intercept; Intercept; Pummel/Bash; Pummel mouseover; Berserker Rage; Hamstring; Overpower; Warrior Burst; @Target player; @Focus mouseover; @Trinkets"),
  },
  PALADIN = {
    common = Refs("Auras; Blessings; Seals; Cleanse MO; Redemption MO; Lay on Hands", { SURVIVAL }),
    leveling = Refs("Seal of Command; Crusader judge; Hammer of Wrath; Flash of Light; HoJ focus; Divine Shield; AoE Threat; @Next target"),
    group = Refs("Flash of Light; Favor+HolyLight; Holy Shock MO; BoP mouseover; Freedom MO; Crusader judge; AoE Threat; Div Intervention; Hammer of Wrath; @Assist focus; @Focus mouseover; @Trinkets",
      { { recipe = "mouseover_help", spell = "Holy Light", kind = "help" } }),
    pvp = Refs("Freedom MO; BoP mouseover; Sacrifice MO; HoJ focus; Divine Shield; Repentance MO; Flash of Light; Hammer of Wrath; @Target player; @Focus mouseover; @Trinkets"),
  },
  SHAMAN = {
    common = Refs("Weapon enchant; Shield Swap; Ghost Wolf; Totems; Cure Poison MO; Cure Disease MO", { SURVIVAL }),
    leveling = Refs("Shock MO; Stormstrike; Ele Rotation; Fire Totem; Utility Totems; LHW MO; Purge; Totem Recall; @Next target"),
    group = Refs("Chain Heal MO; LHW MO; NS + Heal; Water Totem; Utility Totems; Fire Totem; Shock MO; Chain Light MO; Totem Recall; @Assist focus; @Focus mouseover; @Trinkets",
      { { recipe = "mouseover_help", spell = "Healing Wave", kind = "help" } }),
    pvp = Refs("Earth Shock R1; ES focus; Frost Shock; Purge; Grounding Totem; NS + Heal; LHW MO; Utility Totems; @Target player; @Focus mouseover; @Trinkets"),
  },
}

local function Lib(class, name)
  for _, entry in ipairs(ns.Library or {}) do
    if entry.class == class and entry.name == name then return entry end
  end
end

local function Recipe(id)
  for _, recipe in ipairs(ns.Recipes) do
    if recipe.id == id then return recipe end
  end
end

-- visee « cible » : les alternatives au survol sont retirees, le reste de la macro ne change pas
local function NoHover(body)
  local lines = {}
  for line in (body .. "\n"):gmatch("(.-)\n") do
    line = line:gsub("%b[]", function(group) if group:find("@mouseover", 1, true) then return "" end end)
    line = ns.trim((line:gsub("^(/%S+)%s*%[%]%s*", "%1 "):gsub("%s+", " ")))
    lines[#lines + 1] = line
  end
  return table.concat(lines, "\n")
end

-- sans le survol il ne reste qu'un « /cast Sort » : autant poser le sort lui-meme sur la barre
local function Trivial(body)
  local casts, others = 0, 0
  for line in (body .. "\n"):gmatch("(.-)\n") do
    if line:find("^/cast [^%[;]+$") then casts = casts + 1 elseif not line:find("^#") then others = others + 1 end
  end
  return casts == 1 and others == 0
end

-- Les macros d'un kit, dans l'ordre. opts : hover (visee au survol), pet (avec un familier). macros : celles du jeu.
-- env.localize(corps) ; env.unknown(corps) -> noms de sorts inconnus ; env.spellName(nom anglais) ; env.desc(entree de
-- bibliotheque) ; env.enabled(fonction). Chaque macro : { name, body, desc, unknown, living, exists, long } ;
-- exists : "same" (elle existe deja, au texte pres) ou "name" (une autre macro porte ce nom : jamais ecrasee).
function ns.BuildKit(class, role, opts, macros, env)
  local kit = ns.Kits[class] and ns.Kits[class][role]
  if not kit then return nil end
  local byName, bodies, items, used = {}, {}, {}, {}
  for _, m in ipairs(macros) do
    byName[m.name] = m
    bodies[ns.NormBody(m.body)] = true
  end
  for _, list in ipairs({ kit, ns.Kits[class].common }) do
    for _, ref in ipairs(list) do
      local item
      if ref.pet and not opts.pet then
        item = nil
      elseif ref.recipe then
        local recipe = Recipe(ref.recipe)
        if recipe and (not recipe.feature or env.enabled(recipe.feature)) then
          local spell = ref.spell and (env.spellName(ref.spell) or ref.spell) or ""
          item = { name = recipe.name or ns.MacroName(spell), desc = recipe.desc,
                   body = recipe.build(spell, { kind = ref.kind or "item", showtooltip = true, nodead = true }) }
        end
      else
        local entry = Lib(ref.all and "ALL" or class, ref.all or ref.lib)
        if entry then item = { name = entry.name, body = env.localize(entry.body), desc = env.desc(entry) } end
      end
      if item and not opts.hover then
        local body = NoHover(item.body)
        if body ~= item.body then
          if Trivial(body) then item = nil else item.body = body end
        end
      end
      if item and not used[item.name] then
        used[item.name] = true
        item.living = ns.HasTokens(item.body)
        item.unknown = env.unknown(item.body)
        item.long = #item.body > ns.MAX_CHARS or nil
        local have = byName[item.name]
        if have then
          item.exists = (not item.living and ns.NormBody(have.body) == ns.NormBody(item.body)) and "same" or "name"
        elseif bodies[ns.NormBody(item.body)] then
          item.exists = "same"
        end
        items[#items + 1] = item
      end
    end
  end
  return items
end

-- Controle des donnees : chaque reference existe, chaque kit garde de 8 a 20 macros. Liste de problemes, vide si tout va bien.
function ns.KitProblems()
  local problems = {}
  local env = { localize = function(body) return body end, unknown = function() return {} end, spellName = function(name) return name end,
                desc = function(entry) return entry.desc end, enabled = function() return true end }
  for class, kits in pairs(ns.Kits) do
    for _, role in ipairs(ns.KitRoles) do
      local where = class .. " / " .. role.id
      if not kits[role.id] or not kits.common then problems[#problems + 1] = where .. " : kit absent" end
      for _, list in ipairs({ kits[role.id] or {}, kits.common or {} }) do
        for _, ref in ipairs(list) do
          if ref.recipe then
            if not Recipe(ref.recipe) then problems[#problems + 1] = where .. " : recette inconnue " .. ref.recipe end
            if ref.spell and not (ns.SpellIDs and ns.SpellIDs[ref.spell]) then problems[#problems + 1] = where .. " : sort sans ID " .. ref.spell end
          elseif not Lib(ref.all and "ALL" or class, ref.all or ref.lib) then
            problems[#problems + 1] = where .. " : macro absente de la bibliotheque " .. (ref.all or ref.lib)
          end
        end
      end
      for _, hover in ipairs({ true, false }) do
        for _, pet in ipairs({ true, false }) do
          local items = ns.BuildKit(class, role.id, { hover = hover, pet = pet }, {}, env) or {}
          if #items < 8 or #items > 20 then
            problems[#problems + 1] = ("%s : %d macros (survol %s, familier %s)"):format(where, #items, tostring(hover), tostring(pet))
          end
        end
      end
    end
  end
  table.sort(problems)
  return problems
end
