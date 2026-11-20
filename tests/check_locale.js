// Verifie que chaque L["..."] des fichiers Lua a sa traduction anglaise dans Locale.lua,
// sans typographie francaise et avec les memes %s/%d dans le meme ordre.
// Usage : node check_locale.js [dossier BlockForge] [--list]
const fs = require("fs");
const dir = process.argv[2] && !process.argv[2].startsWith("--") ? process.argv[2] : __dirname + "/../BlockForge";
const FILES = ["Core.lua", "Settings.lua", "Debug.lua", "UI.lua", "Minimap.lua"];
const USE = /\bL\["((?:[^"\\]|\\.)*)"\]/g;
const DEF = /^\s*L\["((?:[^"\\]|\\.)*)"\]\s*=\s*"((?:[^"\\]|\\.)*)"/gm;

const used = new Map(); // cle brute (telle qu'ecrite dans le source) -> premier fichier:ligne
for (const f of FILES) {
  fs.readFileSync(dir + "/" + f, "utf8").split(/\r?\n/).forEach((line, i) => {
    if (line.trimStart().startsWith("--")) return;
    for (const m of line.matchAll(USE)) if (!used.has(m[1])) used.set(m[1], f + ":" + (i + 1));
  });
}
const en = new Map();
const errors = [];
for (const m of fs.readFileSync(dir + "/Locale.lua", "utf8").matchAll(DEF)) {
  if (en.has(m[1])) errors.push("doublon : " + m[1]);
  en.set(m[1], m[2]);
}
const placeholders = s => (s.match(/%[-\d.]*[a-z%]/g) || []).join(" ");
for (const [key, where] of used) {
  if (!en.has(key)) { errors.push("sans traduction (" + where + ") : " + key); continue; }
  const v = en.get(key);
  if (/[éèêëàâùûçôîïœ«»]/i.test(v)) errors.push("caractere francais : " + v);
  if (/ [:;?!]/.test(v)) errors.push("espace avant ponctuation : " + v);
  if (placeholders(v) !== placeholders(key)) errors.push("formats differents : " + key + " -> " + v);
}
for (const key of en.keys()) if (!used.has(key)) errors.push("traduction inutilisee : " + key);
if (process.argv.includes("--list")) for (const key of used.keys()) console.log(key);
if (errors.length) { console.error(errors.join("\n")); process.exit(1); }
console.log("check_locale.js : OK (" + used.size + " cles)");
