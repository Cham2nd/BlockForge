// Limites de Lua 5.1 (le jeu) que fengari (Lua 5.3) ne voit pas : 60 upvalues par fonction, syntaxe 5.1.
// Sans ce controle, un fichier passe tous les tests et refuse de se charger en jeu.
// Usage : node check_limits.js [dossier BlockForge] [--list]
const fs = require("fs");
const { lua, lauxlib, to_luastring, to_jsstring } = require("fengari");
const dir = process.argv[2] && !process.argv[2].startsWith("--") ? process.argv[2] : __dirname + "/../BlockForge";
const list = process.argv.includes("--list");
const MAX_UPVALUES = 60;
const L = lauxlib.luaL_newstate();

let worst = 0;
const errors = [];
function walk(file, proto) {
  // Lua 5.3 compte _ENV (acces aux globales) comme upvalue, pas Lua 5.1
  const names = proto.upvalues.map((u) => (u.name ? to_jsstring(u.name.getstr()) : "?")).filter((n) => n !== "_ENV");
  worst = Math.max(worst, names.length);
  if (list && names.length > 40) console.log(`  ${file}:${proto.linedefined} : ${names.length} upvalues`);
  if (names.length > MAX_UPVALUES) errors.push(`${file}:${proto.linedefined} : ${names.length} upvalues (max ${MAX_UPVALUES}) : ${names.join(", ")}`);
  for (const child of proto.p) walk(file, child);
}

for (const file of fs.readdirSync(dir).filter((f) => f.endsWith(".lua"))) {
  // syntaxe Lua 5.1 stricte : fengari accepte aussi //, &, goto... que le jeu refuse
  try {
    require("luaparse").parse(fs.readFileSync(dir + "/" + file, "latin1"), { luaVersion: "5.1", encodingMode: "pseudo-latin1" });
  } catch (e) {
    errors.push(`${file} : syntaxe Lua 5.1 : ${e.message}`);
  }
  const src = fs.readFileSync(dir + "/" + file);
  if (lauxlib.luaL_loadbuffer(L, src, src.length, to_luastring("@" + file)) !== lua.LUA_OK)
    throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
  walk(file, L.stack[L.top - 1].value.p);
  lua.lua_pop(L, 1);
}
console.log(`check_limits.js : ${errors.length ? "ECHEC" : "OK"} (au plus ${worst} upvalues par fonction, max ${MAX_UPVALUES})`);
for (const e of errors) console.log("  " + e);
if (errors.length) process.exit(1);
