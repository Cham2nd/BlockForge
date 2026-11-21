const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '..');
const addon = path.join(root, 'BlockForge');
const toc = fs.readFileSync(path.join(addon, 'BlockForge.toc'), 'utf8');
const entries = toc.split(/\r?\n/).map(s => s.trim()).filter(s => s && !s.startsWith('#'));
const errors = [];
for (const file of fs.readdirSync(addon).filter(s => s.endsWith('.lua')))
  if (!entries.includes(file)) errors.push('TOC missing: ' + file);
for (const entry of entries)
  if (!fs.existsSync(path.join(addon, entry.replace(/\\/g, '/')))) errors.push('TOC file absent: ' + entry);
const version = (toc.match(/^## Version:\s*(\d+\.\d+\.\d+)\s*$/m) || [])[1];
const changelog = fs.readFileSync(path.join(root, 'release', 'CHANGELOG.md'), 'utf8');
const heading = (changelog.match(/^# BlockForge (\d+\.\d+\.\d+)\s*$/m) || [])[1];
if (!version || heading !== version) errors.push('Changelog / TOC version mismatch: ' + heading + ' / ' + version);
if (errors.length) { console.error(errors.join('\n')); process.exit(1); }
console.log('check_release.js : OK (' + entries.length + ' TOC entries, changelog ' + version + ')');
