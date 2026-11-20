// Controle des textes de l'interface, dans tous les fichiers Lua de l'add-on (sauf les donnees) :
//  - chaque L["..."] a sa traduction anglaise dans Locale.lua, sans typographie francaise, avec les memes %s/%d dans le meme ordre ;
//  - pas de traduction inutilisee, en double, ou identique a une cle de plusieurs mots (oubli de traduction) ;
//  - les cles francaises tutoient le joueur ;
//  - aucun texte affiche n'est ecrit en dur : chaine accentuee hors de L["..."], ou chaine de mots passee telle quelle
//    a SetText / AddLine / print / Label / Button / Tip / text = / buttonN = ;
//  - le TOC a ses deux descriptions (## Notes et ## Notes-frFR).
// Une ligne qui porte le commentaire "locale-ok" est exemptee (table de lettres, nom propre...).
// Usage : node check_locale.js [dossier BlockForge] [--list]
const fs = require("fs");
const dir = process.argv[2] && !process.argv[2].startsWith("--") ? process.argv[2] : __dirname + "/../BlockForge";
const DATA = ["Locale.lua", "Library.lua", "SpellIDs.lua", "ItemIDs.lua"];
const FILES = fs.readdirSync(dir).filter((f) => f.endsWith(".lua") && !DATA.includes(f));
const STR = '"((?:[^"\\\\]|\\\\.)*)"';
const USE = new RegExp("\\bL\\[" + STR + "\\]", "g");
const DEF = new RegExp("^\\s*L\\[" + STR + "\\]\\s*=\\s*" + STR, "gm");
const ACCENT = /[À-ÖØ-öø-ÿŒœ«»]/;
const WORDS = /[A-Za-z]{3,}/;
const NAMES = ["BlockForge"]; // noms propres : pas de traduction
// appels qui affichent leur premier texte ; le texte doit passer par L["..."]
const SHOWN = [
  new RegExp("\\b(?:SetText|AddLine|SetFormattedText|print|Msg)\\(\\s*" + STR, "g"),
  new RegExp("\\b(?:Label|Button|Panel)\\([^,()]+,\\s*(?:[\\d\\s,]*)" + STR, "g"),
  new RegExp("\\b(?:text|button[123])\\s*=\\s*" + STR, "g"),
  new RegExp("\\bTip\\(.*\\breturn\\s+" + STR, "g"),
];

// retire le commentaire de fin de ligne, sans se tromper sur un "--" dans une chaine
function code(line) {
  let quote = null;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (quote) {
      if (c === "\\") i++;
      else if (c === quote) quote = null;
    } else if (c === '"' || c === "'") quote = c;
    else if (c === "-" && line[i + 1] === "-") return line.slice(0, i);
  }
  return line;
}

const errors = [];
const used = new Map(); // cle brute (telle qu'ecrite dans le source) -> premier fichier:ligne
for (const f of FILES) {
  fs.readFileSync(dir + "/" + f, "utf8").split(/\r?\n/).forEach((raw, i) => {
    const where = f + ":" + (i + 1);
    const line = code(raw);
    for (const m of line.matchAll(USE)) if (!used.has(m[1])) used.set(m[1], where);
    if (raw.includes("locale-ok")) return;
    const bare = line.replace(USE, "L[]");
    for (const m of bare.matchAll(new RegExp(STR, "g")))
      if (ACCENT.test(m[1])) errors.push("texte accentue hors de L[...] (" + where + ") : " + m[1]);
    for (const re of SHOWN)
      for (const m of bare.matchAll(re))
        if (WORDS.test(m[1]) && !NAMES.includes(m[1]) && !ACCENT.test(m[1])) errors.push("texte affiche ecrit en dur (" + where + ") : " + m[1]);
  });
}
const en = new Map();
for (const m of fs.readFileSync(dir + "/Locale.lua", "utf8").matchAll(DEF)) {
  if (en.has(m[1])) errors.push("doublon : " + m[1]);
  en.set(m[1], m[2]);
}
const placeholders = (s) => (s.match(/%[-\d.]*[a-z%]/g) || []).join(" ");
for (const [key, where] of used) {
  if (/\b(vous|votre|vos)\b/i.test(key)) errors.push("vouvoiement (" + where + ") : " + key);
  if (!en.has(key)) { errors.push("sans traduction (" + where + ") : " + key); continue; }
  const v = en.get(key);
  if (ACCENT.test(v)) errors.push("caractere francais : " + v);
  if (/ [:;?!]/.test(v)) errors.push("espace avant ponctuation : " + v);
  if (placeholders(v) !== placeholders(key)) errors.push("formats differents : " + key + " -> " + v);
  if (v === key && /\s/.test(key) && !/^[\w%]+ %[ds]$/.test(key)) errors.push("traduction identique a la cle : " + key);
}
for (const key of en.keys()) if (!used.has(key)) errors.push("traduction inutilisee : " + key);

const toc = fs.readFileSync(dir + "/BlockForge.toc", "utf8");
const note = (tag) => (toc.match(new RegExp("^## " + tag + ":\\s*(\\S.*)$", "m")) || [])[1];
if (!note("Notes") || !note("Notes-frFR")) errors.push("TOC : ## Notes et ## Notes-frFR attendus");
else if (ACCENT.test(note("Notes"))) errors.push("TOC : ## Notes doit etre en anglais : " + note("Notes"));
for (const f of FILES.concat(DATA)) if (!toc.split(/\r?\n/).includes(f)) errors.push("TOC : fichier absent : " + f);

if (process.argv.includes("--list")) for (const key of used.keys()) console.log(key);
if (errors.length) { console.error(errors.join("\n")); process.exit(1); }
console.log("check_locale.js : OK (" + used.size + " cles, " + FILES.length + " fichiers)");
