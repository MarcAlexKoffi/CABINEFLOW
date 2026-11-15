// Run after building lib/main_backoffice.dart into build/catalog_import_backoffice.
// Only generated Back-office files are changed; shared web/ sources stay reusable.
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const crypto = require('node:crypto');
const output = path.resolve(__dirname, '../build/catalog_import_backoffice');
for (const name of ['index.html', 'manifest.json', 'main.dart.js', 'flutter_bootstrap.js', 'assets/assets/templates/Modele_import_offres_IzyTel.xlsx']) {
  if (!fs.existsSync(path.join(output, name))) throw Error('Missing Back-office build file: ' + name);
}
const indexPath = path.join(output, 'index.html');
let html = fs.readFileSync(indexPath, 'utf8');
html = html.replace(/<title>[\s\S]*?<\/title>/, '<title>IzyTel Back-office</title>');
const metadata = {
  description: 'IzyTel Back-office — administration du catalogue et des opérations.',
  'og:title': 'IzyTel Back-office',
  'og:description': 'Administration IzyTel : catalogue, équipe et opérations.',
  'twitter:title': 'IzyTel Back-office',
  'twitter:description': 'Administration IzyTel : catalogue, équipe et opérations.',
  'apple-mobile-web-app-title': 'IzyTel Back-office',
};
for (const [name, value] of Object.entries(metadata)) {
  html = html.replace(new RegExp('(<meta (?:name|property)="' + name + '" content=")[^"]*(")'), '$1' + value + '$2');
}
if (!html.includes('name="robots"')) html = html.replace('</head>', '  <meta name="robots" content="noindex, nofollow">\n</head>');
fs.writeFileSync(indexPath, html);
const manifestPath = path.join(output, 'manifest.json');
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
Object.assign(manifest, {name: 'IzyTel Back-office', short_name: 'IzyTel Admin', description: metadata.description});
fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + '\n');
const applicationCommit = cp.execFileSync('git', ['rev-parse', 'HEAD'], {cwd: path.resolve(__dirname, '..'), encoding: 'utf8'}).trim();
const sha256 = name => crypto.createHash('sha256').update(fs.readFileSync(path.join(output, name))).digest('hex');
const version = {surface: 'backoffice', applicationCommit, builtAt: new Date().toISOString(), entrypoint: 'lib/main_backoffice.dart', mainDartJsSha256: sha256('main.dart.js')};
fs.writeFileSync(path.join(output, 'version.json'), JSON.stringify(version, null, 2) + '\n');
if (!html.includes('<title>IzyTel Back-office</title>') || !html.includes('name="robots"')) throw Error('Back-office metadata preparation failed');
console.log(JSON.stringify({...version, indexSha256: sha256('index.html'), output}, null, 2));
