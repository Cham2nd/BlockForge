// Controle la bibliotheque : champs, limites du jeu, doublons, et chaque sort lance doit avoir son ID.
// Usage : node check_library.js [dossier BlockForge] [SpellName.csv du build]
// Avec le CSV (export wago.tools de la table SpellName), verifie aussi que chaque ID porte bien ce nom.
const fs = require("fs");
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require("fengari");
const dir = process.argv[2] && !process.argv[2].endsWith(".csv") ? process.argv[2] : __dirname + "/../BlockForge";
const csv = process.argv.find((a) => a.endsWith(".csv"));
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
const fail = () => { throw new Error(to_jsstring(lua.lua_tostring(L, -1))); };
const run = (code) => { if (lauxlib.luaL_dostring(L, to_luastring(code)) !== lua.LUA_OK) fail(); };

run("NS = {}");
const optional = fs.existsSync(dir + "/ItemIDs.lua") ? ["ItemIDs.lua"] : [];
for (const f of ["Locale.lua", "Core.lua", "Library.lua", "SpellIDs.lua", ...optional]) {
  const src = fs.readFileSync(dir + "/" + f);
  if (lauxlib.luaL_loadbuffer(L, src, src.length, to_luastring("@" + f)) !== lua.LUA_OK) fail();
  lua.lua_pushstring(L, to_luastring("BlockForge"));
  lua.lua_getglobal(L, to_luastring("NS"));
  if (lua.lua_pcall(L, 2, 0, 0) !== lua.LUA_OK) fail();
}

if (csv) {
  let names = "CSV = {";
  for (const line of fs.readFileSync(csv, "utf8").split(/\r?\n/).slice(1)) {
    const m = line.match(/^(\d+),(.*)$/);
    if (!m) continue;
    const n = m[2].startsWith('"') ? m[2].slice(1, -1).replace(/""/g, '"') : m[2];
    names += `[${m[1]}]=${JSON.stringify(n)},`;
  }
  run(names + "}");
}

run(String.raw`
local ns, errors, seen = NS, {}, {}
local CATEGORY = { PvE = true, PvP = true, Pet = true, Utility = true }
local function err(entry, text) errors[#errors + 1] = entry.class .. " / " .. entry.name .. " : " .. text end
for _, m in ipairs(ns.Library) do
  local key = m.class .. "/" .. m.name
  if seen[key] then err(m, "doublon") end
  seen[key] = true
  if #m.name > 16 then err(m, "nom de plus de 16 caracteres") end
  if #m.body > 255 then err(m, "macro de plus de 255 caracteres") end
  if not CATEGORY[m.category] then err(m, "categorie inconnue") end
  if (m.desc or "") == "" then err(m, "description francaise (desc) manquante") end
  if (m.descEN or "") == "" then err(m, "description anglaise (descEN) manquante") end
  -- descEN restee en francais (lettre accentuee, octet de tete 195) ; desc qui vouvoie ; nom de macro hors ASCII
  if (m.descEN or ""):find("\195") then err(m, "descEN contient une lettre accentuee") end
  if m.descEN == m.desc then err(m, "descEN identique a desc") end
  local words = " " .. (m.desc or ""):lower():gsub("[^%a\128-\255]", " ") .. " "
  if words:find(" vous ") or words:find(" votre ") or words:find(" vos ") then err(m, "desc vouvoie le joueur") end
  if m.name:find("[^\32-\126]") then err(m, "nom hors ASCII") end
  for _, spell in ipairs(ns.SpellsOf(ns.Parse(m.body))) do
    local id = ns.SpellIDs[spell]
    if not id and not (ns.ItemIDs and ns.ItemIDs[spell]) then
      err(m, "sort sans ID : " .. spell)
    elseif id and CSV and CSV[id] ~= spell then
      err(m, "ID " .. id .. " = " .. tostring(CSV[id]) .. " au lieu de " .. spell)
    end
  end
end
print("check_library.js : " .. #ns.Library .. " macros, " .. #errors .. " erreur(s)" .. (CSV and "" or " (sans table du build)"))
for _, e in ipairs(errors) do print("  " .. e) end
assert(#errors == 0)
`);
