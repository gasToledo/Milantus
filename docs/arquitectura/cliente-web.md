# El cliente web (`packages/dnd_web`)

Estado: guía vigente. Cómo se arma el cliente por dentro y cómo se prueba. El
sistema visual está en [Diseño web](../desarrollo/diseno-web.md) y
[Diseño web en React](../desarrollo/diseno-web-react.md); cómo se sirve y se
despliega, en [Despliegue](../operaciones/despliegue.md#el-cliente-web). Si el
código y esta guía discrepan, manda el código.

React + Vite + TypeScript + Tailwind, servido en la raíz del mismo origen que
la API. Reemplazó al cliente de Flutter, que se borró el 2026-11-20 (v2.0.0);
la historia de esa migración está en el historial de Git.

## Las reglas no viven acá

El cliente **no reimplementa ninguna regla**: corre el mismo `dnd_engine`
compilado a JavaScript. Una regla que falte se agrega al motor con su test,
nunca en TypeScript.

- El motor llega como `src/engine/dnd_engine.generated.js`, salida de
  `dart compile js` sobre `packages/dnd_engine/js/entrypoint.dart`. **No se
  versiona**: lo genera `npm run build:engine` (y la etapa `engine-js` del
  `Dockerfile`).
- `src/engine/index.ts` es **la única puerta** al motor (`computeSheet`,
  `actOn`, `encounterAct`, `creationView` y el resto). La comunicación es JSON
  como texto, de ida y vuelta.
- Los tipos de `src/engine/types.ts` están escritos a mano. Los cuida la prueba
  de paridad (abajo): un campo nuevo en `ComputedSheet.toJson` la rompe aunque
  el tipo no lo diga.

## El catálogo

El SRD llega al navegador como archivos estáticos en `/content/*.json`, que
`npm run build` copia desde `packages/dnd_engine/lib/assets/srd_2024`
(`scripts/copy-content.mjs`; la lista está en `PACKS` de `src/api/catalog.ts`).
En inglés se pide además cada `X.en.json` y se superpone con el motor
(`applyTranslation`), no con una copia en TypeScript. El homebrew de la cuenta
se fusiona con el catálogo oficial en el cliente (`mergeHomebrew`).

## Las escrituras

Toda ficha que guarda el cliente la produce el motor: `actOn` lee el personaje
con `Character.fromJson`, aplica la acción y devuelve `Character.toJson`, con el
`schemaVersion` actual. No hay campo que escriba la pantalla por su cuenta.

El guardado (`src/api/characterSave.ts`) junta los toques seguidos, manda
siempre **la copia entera** (repetir un PUT no aplica dos veces el mismo daño)
y lleva la versión que leyó: si otro dispositivo guardó antes, el servidor
responde 409, lo pendiente se descarta y la pantalla vuelve a pedir la ficha.

Un valor equivocado (un daño de más) se corrige a mano en la ficha, como
cualquier error de la mesa: revertir el cliente no lo deshace. Un cambio malo
del motor que dejara documentos ilegibles se arregla con una migración del
modelo y su test, nunca editando la base.

## El guion del capítulo

- Las ediciones las aplica el motor (`scriptEdit`), se ven al instante en la
  caché y se guardan en fila (`dm/script/scriptWriter.ts` sobre
  `api/scriptSave.ts`, la misma cola que los PNJ). Si un guardado falla, lo
  pendiente se descarta y se relee.
- Los estados de los hitos se calculan en el cliente con `scriptView`, para que
  una edición se vea sin esperar. El progreso, en cambio, solo cambia por la
  ruta del servidor, que recibe la acción después de confirmar lo pendiente del
  guion.
- Editar / En juego vive en `?modo=` (`editar` o `juego`). Sin él, un capítulo
  en marcha abre en juego; en pantallas de menos de 900 px el capítulo se abre
  siempre en juego.
- El Registro agrupa las entradas por hito con `groupByMilestone`
  (`dm/notebook.ts`): es presentación, no una regla.

## Cómo se prueba

Los comandos están en `CLAUDE.md` §Comandos y el listón de qué prueba entra,
en `CLAUDE.md` §Tests.

1. **Paridad del motor** (job `engine_js`). Dart genera casos y su salida
   esperada (`dnd_engine/tool/generate_js_parity_fixtures.dart`); Node los
   recalcula con el JS compilado (`npm run test:parity`) y compara el JSON
   completo, **incluido el orden de las claves**. No prueba reglas (las prueban
   los tests del motor): prueba que `dart2js` no cambie enteros por dobles,
   orden ni redondeos. Los casos `accion-*` cubren `actOn` con una semilla fija
   para los dados; los `puente-*`, las funciones de lectura que la pantalla
   llama con sus argumentos.
2. **Pruebas de componentes** (`npm test`, vitest, en el job `dnd_web`): pocas,
   solo donde la lógica de pantalla no es del motor (el historial del Quiz,
   por ejemplo).
3. **Playwright** (job `web_e2e`). Levanta el servidor real con repositorios
   en memoria y sesiones falsas (`dnd_server/test/e2e_server.dart`), sirve el
   `dist` con personajes, campañas y homebrew sembrados, y verifica que una
   escritura mande lo que da el motor, que lo ajeno responda igual que lo
   inexistente y que la ficha ajena no tenga controles. Lo esperado se calcula
   con el mismo motor (`e2e/helpers.ts`). Sin reintentos.
4. **A mano en producción**, lo que solo se ve con el stack real (túnel, caché,
   personajes complejos). Se anota en `docs/operaciones/pruebas-en-produccion.md`
   (registro privado que Git ignora).

Además, `tsc --noEmit` hace de prueba de paridad es/en: los textos de las dos
lenguas son del mismo tipo. **No hay** un chequeo automático de literales
sueltos: lo cuida la revisión.
