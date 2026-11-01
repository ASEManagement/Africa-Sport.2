import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const site = path.join(root, 'public-site');
const url = process.env.SUPABASE_URL?.trim();
const key = process.env.SUPABASE_PUBLISHABLE_KEY?.trim();
if (!url || !key) throw new Error('Configure the SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY GitHub repository secrets before deploying.');
fs.rmSync(site, { recursive: true, force: true });
fs.mkdirSync(site, { recursive: true });
for (const name of ['index.html','app.js','profile.js','directory.js','portal.js','ase-cloud.js','ase-logo.jpeg','hero-football.png','profile.css','directory.css','design.css']) {
  fs.copyFileSync(path.join(root, name), path.join(site, name));
}
let html = fs.readFileSync(path.join(site, 'index.html'), 'utf8').replace('<script src="ase-config.local.js"></script>', '');
fs.writeFileSync(path.join(site, 'index.html'), html);
const config = { supabaseUrl: url, supabasePublishableKey: key, localAdminCode: '' };
fs.writeFileSync(path.join(site, 'ase-config.js'), `window.ASE_CONFIG = ${JSON.stringify(config)};\n`);
