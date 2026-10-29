// Compila el motor de Dart a JS para el bundle de Vite:
//
//     npm run build:engine
//
// Necesita el SDK de Dart en el PATH. La imagen de Docker hace lo mismo en su
// propia etapa (`engine-js` en packages/dnd_server/Dockerfile) porque la etapa
// de Node no tiene Dart: si cambian las banderas, cambian en los dos lados.
import { spawnSync } from 'node:child_process';
import { mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

// `fileURLToPath` y no `URL.pathname`: en Windows ese último devuelve
// `/C:/...` y rompe cualquier ruta que se arme a partir de él.
const aquí = dirname(fileURLToPath(import.meta.url));
const engineDir = resolve(aquí, '../../dnd_engine');
const salida = resolve(aquí, '../src/engine/dnd_engine.generated.js');

function dart(args) {
  // `shell` en Windows, donde `dart` es un .bat.
  const r = spawnSync('dart', args, {
    cwd: engineDir,
    stdio: 'inherit',
    shell: process.platform === 'win32',
  });
  if (r.error?.code === 'ENOENT') {
    console.error('No se encontró `dart` en el PATH (hace falta el SDK).');
    process.exit(1);
  }
  if (r.status !== 0) process.exit(r.status ?? 1);
}

mkdirSync(dirname(salida), { recursive: true });
dart(['pub', 'get']);
dart(['compile', 'js', '-O2', '--no-source-maps', '-o', salida, 'js/entrypoint.dart']);
console.log(`Motor compilado en ${salida}`);
