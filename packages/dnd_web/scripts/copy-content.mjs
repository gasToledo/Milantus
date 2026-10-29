// Copia el catálogo SRD del motor a `dist/content/`, para que el navegador lo
// pida por `/v2/content/<archivo>.json`:
//
//     npm run build   (lo corre después de `vite build`)
//
// Por qué copiarlo al build y no servirlo con una ruta propia: el servidor ya
// sirve `dist` con `Cache-Control: private, no-cache` para todo lo que no
// lleva huella en el nombre, o sea que el navegador revalida (`Last-Modified`
// → 304) y un catálogo nuevo llega con el despliegue siguiente, sin tocar
// código del servidor ni abrir una ruta más. Es contenido público del SRD;
// los datos de cuentas y el homebrew siguen detrás de `/api`.
//
// Solo van los catálogos y sus traducciones: `manifest.json` y los
// `expected_*.json` son de las pruebas del motor. La imagen de Docker pone el
// mismo directorio en esta ruta relativa (etapa `web-v2-build`).
import { cpSync, mkdirSync, readdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

// `fileURLToPath` y no `URL.pathname`: en Windows ese último devuelve `/C:/...`.
const aquí = dirname(fileURLToPath(import.meta.url));
const origen = resolve(aquí, '../../dnd_engine/lib/assets/srd_2024');
const destino = resolve(aquí, '../dist/content');

mkdirSync(destino, { recursive: true });
const archivos = readdirSync(origen).filter(
  (f) => f.endsWith('.json') && f !== 'manifest.json' && !f.startsWith('expected_'),
);
for (const f of archivos) cpSync(resolve(origen, f), resolve(destino, f));
console.log(`Catálogo copiado: ${archivos.length} archivos en ${destino}`);
