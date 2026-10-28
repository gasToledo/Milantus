// Carga el JS compilado en Node y compara contra la referencia de la VM de Dart.
//   node tool/js_spike/run.mjs build/js_spike/engine.js build/js_spike/fixtures
import { readFileSync, readdirSync } from 'node:fs';
import { createRequire } from 'node:module';
import { gzipSync } from 'node:zlib';
import { isDeepStrictEqual } from 'node:util';

const [, , jsPath, fxDir] = process.argv;
const dir = new URL('../../lib/assets/srd_2024/', import.meta.url).pathname;
const read = (f) => JSON.parse(readFileSync(dir + f, 'utf8'));

// Mismo ensamblado que content_pack_loader_io: items = items + magic + efa.
const catalog = JSON.stringify({
  races: read('races.json'), classes: read('classes.json'),
  subclasses: read('subclasses.json'), lineages: read('lineages.json'),
  backgrounds: read('backgrounds.json'), feats: read('feats.json'),
  weapons: read('weapons.json'), armor: read('armor.json'),
  items: [...read('items.json'), ...read('magic_items.json'), ...read('efa_magic_items.json')],
  spells: read('spells.json'), creatures: read('creatures.json'),
});
console.log(`catálogo: ${(catalog.length / 1e6).toFixed(2)} MB de JSON`);
const raw = readFileSync(jsPath);
console.log(`engine.js: ${(raw.length / 1024).toFixed(0)} KB crudo, ${(gzipSync(raw).length / 1024).toFixed(0)} KB gzip`);

let t = performance.now();
createRequire(import.meta.url)(new URL(jsPath, `file://${process.cwd()}/`).pathname);
console.log(`arranque (require): ${(performance.now() - t).toFixed(1)} ms`);
const e = globalThis.dndEngine;

let fail = 0;
for (const f of readdirSync(fxDir).filter((f) => f.endsWith('.character.json'))) {
  const id = f.split('.')[0];
  if (id === 'v1') {
    const got = JSON.parse(e.migrateCharacter(readFileSync(`${fxDir}/${f}`, 'utf8')));
    const want = JSON.parse(readFileSync(`${fxDir}/v1.migrated.json`, 'utf8'));
    const ok = isDeepStrictEqual(got, want);
    console.log(`${ok ? 'OK  ' : 'FALLA'} migrateCharacter(v1)`);
    fail += ok ? 0 : 1;
    continue;
  }
  const chr = readFileSync(`${fxDir}/${f}`, 'utf8');
  t = performance.now();
  const got = JSON.parse(e.compute(chr, catalog)); // primera: parsea el catálogo
  const first = performance.now() - t;
  t = performance.now();
  const N = 200;
  for (let i = 0; i < N; i++) e.compute(chr, catalog);
  const avg = (performance.now() - t) / N;
  const want = JSON.parse(readFileSync(`${fxDir}/${id}.expected.json`, 'utf8'));
  const ok = isDeepStrictEqual(got, want);
  console.log(`${ok ? 'OK  ' : 'FALLA'} ${id}: 1ª ${first.toFixed(0)} ms (con catálogo), luego ${avg.toFixed(2)} ms/compute · nivel ${got.level} CA ${got.armorClass} PG ${got.maxHp}`);
  if (!ok) { fail++; console.log(' js  :', JSON.stringify(got)); console.log(' dart:', JSON.stringify(want)); }
}
process.exit(fail ? 1 : 0);
