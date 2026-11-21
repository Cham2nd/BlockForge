const fs = require('fs');
const bootstrap = fs.readFileSync(__dirname + '/test_ui.js', 'utf8').split('// ---------------------------------------------------------------- 1. BlockForgeDB')[0];
const scenarios = fs.readFileSync(__dirname + '/release_101.lua', 'utf8');
new Function('require', '__dirname', 'process', bootstrap + `
for (const lang of ['frFR', 'enUS']) {
 boot('nil', 'function GetLocale() return "' + lang + '" end');
 run(` + JSON.stringify(scenarios) + `, '=release101_' + lang);
}
console.log('test_101 OK (FR/EN, ownership, cache, macro window, labels, debounce, logs, probes)');
`)(require, __dirname, process);
