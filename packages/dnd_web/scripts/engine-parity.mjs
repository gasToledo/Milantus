// Paridad del motor: el JS compilado tiene que dar, ficha por ficha, el mismo
// JSON que Dart.
//
//     dart run tool/generate_js_parity_fixtures.dart <dir>   (en dnd_engine)
//     npm run build:engine
//     npm run test:parity -- <dir>
//
// Los casos los genera Dart (`tool/generate_js_parity_fixtures.dart`): la
// salida esperada es la del motor de Dart, no una transcripción a mano que se
// pueda desactualizar. Esto es una prueba de **compilación**, no de reglas:
// las reglas ya las prueban los tests de dnd_engine; acá se mira que dart2js
// no cambie nada (enteros contra dobles, orden de claves, redondeos).
import { readFileSync, readdirSync } from 'node:fs';
import { resolve } from 'node:path';

import '../src/engine/dnd_engine.generated.js';

const dir = process.argv[2];
if (!dir) {
  console.error('Uso: npm run test:parity -- <directorio de fixtures>');
  process.exit(2);
}

/** Diferencias legibles entre dos JSON, con la ruta de cada una. */
function diferencias(esperado, obtenido, ruta = '$', salida = []) {
  if (salida.length >= 20) return salida;
  const tipo = (v) => (v === null ? 'null' : Array.isArray(v) ? 'array' : typeof v);
  if (tipo(esperado) !== tipo(obtenido)) {
    salida.push(`${ruta}: Dart ${JSON.stringify(esperado)} ≠ JS ${JSON.stringify(obtenido)}`);
  } else if (tipo(esperado) === 'array') {
    if (esperado.length !== obtenido.length) {
      salida.push(`${ruta}: Dart tiene ${esperado.length} elementos, JS ${obtenido.length}`);
    }
    for (let i = 0; i < Math.min(esperado.length, obtenido.length); i++) {
      diferencias(esperado[i], obtenido[i], `${ruta}[${i}]`, salida);
    }
  } else if (tipo(esperado) === 'object') {
    for (const k of new Set([...Object.keys(esperado), ...Object.keys(obtenido)])) {
      if (!(k in obtenido)) salida.push(`${ruta}.${k}: falta en JS (Dart ${JSON.stringify(esperado[k])})`);
      else if (!(k in esperado)) salida.push(`${ruta}.${k}: sobra en JS (${JSON.stringify(obtenido[k])})`);
      else diferencias(esperado[k], obtenido[k], `${ruta}.${k}`, salida);
    }
  } else if (esperado !== obtenido) {
    salida.push(`${ruta}: Dart ${JSON.stringify(esperado)} ≠ JS ${JSON.stringify(obtenido)}`);
  }
  return salida;
}

const motor = globalThis.dndEngine;
if (!motor) {
  console.error('El motor no se inicializó: ¿corriste `npm run build:engine`?');
  process.exit(2);
}

const base = resolve(dir);
const catalogo = readFileSync(resolve(base, 'catalog.json'), 'utf8');
const casos = readdirSync(base).filter((f) => f.endsWith('.json') && f !== 'catalog.json');
if (casos.length < 5) {
  console.error(`Hay ${casos.length} casos y se esperaban al menos 5 en ${base}.`);
  process.exit(2);
}

let fallas = 0;
for (const archivo of casos.sort()) {
  const { character, expected } = JSON.parse(readFileSync(resolve(base, archivo), 'utf8'));
  const obtenido = JSON.parse(motor.compute(JSON.stringify(character), catalogo));
  // `JSON.stringify` compara también el orden de las claves, que un
  // `deepEqual` dejaría pasar.
  if (JSON.stringify(obtenido) === JSON.stringify(expected)) {
    console.log(`ok   ${archivo}`);
    continue;
  }
  fallas++;
  console.error(`FALLA ${archivo}`);
  const dif = diferencias(expected, obtenido);
  for (const d of dif.length ? dif : ['(mismo contenido pero distinto orden de claves)']) {
    console.error(`  ${d}`);
  }
}
if (fallas) {
  console.error(`\n${fallas} de ${casos.length} fichas difieren entre Dart y JS.`);
  process.exit(1);
}
console.log(`\n${casos.length} fichas idénticas entre Dart y JS.`);
