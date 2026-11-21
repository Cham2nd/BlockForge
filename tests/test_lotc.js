// V1 lot C : le meme faux client que les regressions historiques, dans un etat neuf.
const fs = require('fs');
const bootstrap = fs.readFileSync(__dirname + '/test_ui.js', 'utf8').split('// ---------------------------------------------------------------- 1. BlockForgeDB')[0];
const scenarios = fs.readFileSync(__dirname + '/lotc_core.lua', 'utf8');
const ui = fs.readFileSync(__dirname + '/lotc_ui.lua', 'utf8');
new Function('require', '__dirname', 'process', bootstrap + `
for (const lang of ['frFR', 'enUS']) {
  boot('nil', 'function GetLocale() return "' + lang + '" end');
  run(` + JSON.stringify(scenarios) + `, '=lotc_core_' + lang);
  run(` + JSON.stringify(ui) + `, '=lotc_ui_' + lang);
}

for (const db of ['{ tutorialSeen = true }', '{ favorites = { OLD = true } }']) {
  boot(db);
  run("assert(NS.welcomeUpgrading) NS.SetFeature('welcomeMotion', false) NS.OpenWelcome() assert(NS.Welcome.panel.titleText._text == NS.L['BlockForge passe en 1.0.'])", '=lotc_upgrade');
}
boot('{ welcomeSeen = "1.0", welcomeAnnounced = true, tutorialSeen = true }');
run("fireEvent('PLAYER_ENTERING_WORLD') assert(not NS.Welcome.events._scripts.OnUpdate and not NS.Welcome.panel)", '=lotc_seen');
boot('{ features = { welcome = false, explain = false, translate = false, shorten = false } }');
run("fireEvent('PLAYER_ENTERING_WORLD') assert(next(NS.Welcome.events._events) == nil and not NS.Welcome.events._scripts.OnUpdate) NS.Open('editor') assert(not NS.ed.w.explain:IsShown() and not NS.ed.w.translate:IsShown() and not NS.ed.w.shorten:IsShown())", '=lotc_disabled');
console.log('test_lotc OK (FR/EN, 274 macros, 520 recipes, 108 states, welcome, switches, undo)');
`)(require, __dirname, process);
