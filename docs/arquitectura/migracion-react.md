# Migración del cliente a React (`/v2`)

Estado: guía vigente. Describe lo que **existe hoy en `main`**; lo que todavía
no existe está marcado como tal en la sección [Lo que todavía no existe](#lo-que-todavía-no-existe).
Si el código y esta guía discrepan, manda el código.

## Por qué se migra

El cliente de Flutter dibuja sobre un lienzo (CanvasKit/skwasm), no sobre el
DOM. Eso le cuesta cosas que una web común da gratis: texto seleccionable y
buscable, accesibilidad nativa del navegador, extensiones, herramientas de red
y de estilos que se puedan leer, y un bundle inicial más liviano. El destino es
`packages/dnd_web`: React + Vite + TypeScript + Tailwind.

Lo que **no** cambia es lo que hace valioso al proyecto: las reglas viven en
`dnd_engine`, una sola vez. El cliente nuevo no las reimplementa; corre el
mismo motor compilado a JavaScript. Ese es el motivo de fondo de todo el diseño
de abajo: migrar la pantalla sin migrar (ni duplicar) las reglas.

## Cómo conviven `/` y `/v2`

Un solo servidor, un solo origen, dos clientes:

| Ruta | Quién la sirve | Configuración |
| --- | --- | --- |
| `/` | Build de Flutter (`dnd_app`) | `DND_WEB_ROOT` (la imagen: `/app/web`) |
| `/v2/...` | Build de React (`dnd_web`) | `DND_WEB_V2_ROOT` (la imagen: `/app/web-v2`) |
| `/api`, `/auth`, `/mcp` | La API, igual para los dos | — |

- Comparten **origen y cookie de sesión** (`httpOnly`): el cliente React llama a
  `/api` con rutas relativas, igual que `api_client.dart`. No hay segundo login.
- `DND_WEB_V2_ROOT` es independiente de `DND_WEB_ROOT` a propósito
  (`WebConfig` en `packages/dnd_server/lib/src/config.dart`): sin la variable,
  `/v2` responde 404 y nada más cambia.
- El servidor sirve `/v2` con `buildWebV2Handler`
  (`packages/dnd_server/lib/src/web/web_v2.dart`): una ruta de cliente
  (`/v2/personajes/3`) cae a `index.html`; un archivo que falta es 404 de
  verdad. `index.html` va con `private, no-cache` y `assets/` (con hash en el
  nombre) con `immutable` por un año.
- Vite compila con `base: '/v2/'`; el router de `src/router.tsx` lee
  `import.meta.env.BASE_URL`, así que el prefijo vive en un solo lugar.
- El catálogo SRD llega al navegador como archivos estáticos en
  `/v2/content/*.json`, que `npm run build` copia desde
  `packages/dnd_engine/lib/assets/srd_2024` (`scripts/copy-content.mjs`). En
  inglés se pide además cada `X.en.json` y se superpone con el motor
  (`applyTranslation`), no con una copia en TypeScript.
- El motor llega como `src/engine/dnd_engine.generated.js`: salida de
  `dart compile js` sobre `packages/dnd_engine/js/entrypoint.dart`. **No se
  versiona.** `src/engine/index.ts` es la única puerta (`computeSheet`,
  `migrateCharacter`, `setEngineLanguage`, `applyTranslation`,
  `vocabularyLabel`, `inventoryOf`, `chapterGrants`, `catalogLabel`,
  `catalogLabelOrder`, `formatCost`, `abilityModifier`); la
  comunicación es JSON como texto de ida y vuelta. Los tipos de
  `src/engine/types.ts` están escritos a mano: los cuida la paridad (abajo).

## El flag por cuenta: `webV2` y `DND_V2_USERS`

La migración es **cuenta por cuenta**, no por porcentaje ni por rasgo: decide
quién la prueba primero, no el azar (`WebConfig.v2Users`).

- `DND_V2_USERS` (en `.env`: `V2_USERS`) es una lista de ids de cuenta separados
  por coma; tolera espacios y comas de más; vacía = nadie.
- `GET /api/me` devuelve `webV2: true` solo si el `userId` de esa respuesta
  está en la lista. Devuelve el booleano de **quien pregunta**, nunca la lista:
  la lista entera le diría a cualquiera quién más está probando.
- El cliente React comprueba el flag **él mismo**. Una cuenta sin `webV2` que
  entre a cualquier ruta de `/v2` ve la misma pantalla «No disponible» sea la
  ruta conocida o no: no hay pista de qué hay detrás (`src/App.tsx`). Sin sesión
  ve «No hay sesión iniciada» con un enlace a `/auth/login`.

**Cómo habilitar una cuenta**

1. Con la sesión iniciada en producción, abrir las herramientas de red del
   navegador y leer el `userId` de la respuesta de `GET /api/me`.
2. Agregarlo a `V2_USERS` en el `.env` del host (separado por coma).
3. `docker compose up -d` para recrear el contenedor del servidor: la variable
   se lee solo al arrancar.
4. Esa cuenta entra a `/v2/personajes/<id>` escribiendo la URL.

Los detalles de despliegue (caché, variables, probar sin Docker) están en
[Despliegue](../operaciones/despliegue.md#el-cliente-react-bajo-v2); no se
repiten acá.

## Qué hay hoy

- Andamiaje: Vite 8, React 19, TypeScript 7, Tailwind 4; tokens del
  [Apéndice B de diseño web](../desarrollo/diseno-web.md#apéndice-b--equivalencia-en-css)
  en `src/index.css` y como utilidades de Tailwind (la paleta por defecto está
  borrada).
- **Base de componentes** en `src/ui/` sobre primitivas de Radix UI (headless),
  íconos de `lucide-react` y la capa de datos de TanStack Query
  (`src/api/queries.ts`): el catálogo y su uso están en
  [Diseño web en React](../desarrollo/diseno-web-react.md).
- **Navegación sin recarga** (`src/router.tsx`, `Link` y `useRoute`): el
  catálogo y la lista de personajes quedan en caché entre pantallas.
- Marco (`Shell`): panel lateral de 236 px fijo desde 900 px y cajón debajo; el
  contenido ocupa todo el ancho.
- Sesión: `/api/me`, con los estados cargando, sin sesión, error con
  «Reintentar» y no disponible. Una cuenta sin `webV2` no pide nada más a la
  API.
- Tema: oscuro por defecto, con selector al pie del panel. Lo elegido en el
  navegador (`localStorage`) gana sobre el `themeMode` de los ajustes de la
  cuenta, porque React todavía no escribe en la cuenta.
- Idioma: español o inglés, resuelto una vez al cargar (clave `milantus.locale`
  de `localStorage`, luego `navigator.language`, luego español). Es el mismo
  criterio para los rótulos del motor.
- **Tres pantallas de solo lectura.** La primera, el **dashboard** en `/v2/`
  (`src/dashboard/`): la lista de personajes con el orden (`sortMode`:
  manual, más recientes, nombre, nivel, clase) y el favorito de los ajustes de
  la cuenta (`/api/settings`), buscador en el cliente por nombre, especie y
  clase, y los caídos al final, como en Flutter. Orden y favorito **se
  muestran, no se editan**; crear, Ajustes, Sugerencias, Cerrar sesión,
  Homebrew y el «DM» del interruptor de modo enlazan a la raíz de Flutter
  (`FLUTTER_HOME`, `src/router.tsx`). Cada tarjeta enlaza a la ficha. Las cifras
  (nivel, PG máximos, CA, velocidad, iniciativa) salen de `computeSheet`; los
  PG actuales, de la ficha cruda. Sigue el lienzo aprobado: título, buscador,
  orden y «Crear» en una barra que se envuelve, regla ornamental y tarjetas
  con barra de PG en verde/oro/carmesí y CA/VEL/INIC en placas. El panel
  lateral es el menú principal (`src/dashboard/RosterPanel.tsx`), con el
  interruptor «Jugador / DM»: «DM» lleva al Modo DM de Flutter.
- **La ficha de solo lectura**, con cinco pestañas que son rutas:
  `/v2/personajes/:id/personaje`, `/combate`, `/inventario`, `/campana` y
  `/diario` (`src/sheet/`); la ruta sin sufijo redirige a `personaje` y una
  pestaña desconocida es «Página no encontrada». Cabecera con nombre, especie y
  trasfondo, pills de nivel y de cada clase con su subclase, y una banda
  táctica de cinco placas centradas (Armadura, Puntos de golpe con barra y
  porcentaje, Iniciativa, Velocidad, Competencia: la percepción pasiva va con
  las habilidades). **Personaje**: identidad, características, habilidades y
  rasgos y dotes. **Combate**: PG y dados de golpe, defensa, ataques, conjuros
  (CD, ataque, aptitud, preparados y trucos, espacios que quedan, reacciones,
  y la lista: trucos, siempre preparados, preparados o conocidos y los de
  rasgos, cada uno desplegable con su ficha), salvaciones, condiciones y
  recursos. **Inventario**: monedas, carga y sintonización, y la mochila
  agrupada por familia con buscador y filtro; cada entrada la resuelve el
  motor (`inventoryOf`). **Campaña**: cada mesa con sus batallas y los
  capítulos cerrados con lo que repartieron (`GET /api/characters/:id/campaigns`,
  el mismo contrato que Flutter, y lo repartido lo nombra el motor). **Diario**:
  el trasfondo con el Markdown chico de Flutter y las entradas, que se abren en
  un diálogo. Nada se gasta, equipa ni edita. El panel es el de una pantalla de
  adentro: «volver», la tarjeta del personaje, las cinco pestañas, y Retrato,
  Subir nivel, Compartir e Imprimir, que enlazan a Flutter; al pie, «Solo
  lectura», el tema y la versión. La API no tiene `GET` por id, así que usa la
  lista de `/api/characters` (la misma consulta en caché que el dashboard) y
  busca, como Flutter; lo ajeno y lo inexistente son lo mismo. El personaje se
  migra con el motor (`migrateCharacter`) antes de leerlo y calcularlo.
- **El Códice** en `/v2/codice` (`src/codex/`): el catálogo de solo lectura
  con el glosario, las guías, especies, linajes, clases, subclases, trasfondos, dotes, conjuros,
  objetos mágicos, armas, armaduras y equipo, más el homebrew de la cuenta
  marcado «Propio». Sin criaturas: en Flutter son del Modo DM. Cada categoría
  y cada entrada es una ruta (`/v2/codice/conjuros/fireball`); la portada
  cuenta las entradas, la búsqueda del panel agrupa por categoría (cinco por
  grupo, «Ver las N» abre la categoría con `?q=`) y cada categoría tiene
  filtros por faceta (rareza, categoría de dote, nivel, escuela, familia).
  Rótulos, orden de las facetas y precios los da el motor (`catalogLabel`,
  `catalogLabelOrder`, `formatCost`). El **glosario** es texto propio y no
  del catálogo: sus términos y la regla de cada estado se copian de Flutter
  (`gl*` de los `.arb` y `ui/conditions.dart`) a `src/i18n/texts.ts`, y se
  lee en orden (numerado, con anterior y siguiente); el modificador de su
  tabla lo da el motor (`abilityModifier`). Las **guías** siguen el mismo
  camino (`guide*` de los `.arb`), ya partidas en `texts.ts`: párrafos, los
  pasos del primer combate, la ficha por pestaña y el consejo. Las dotes sin
  descripción no muestran sus efectos: el texto de
  cada efecto (`describeEffect`) vive en Flutter (ver su `ponytail:`).
- **Homebrew**: la ficha y el dashboard calculan con el catálogo oficial más
  el contenido homebrew de la cuenta (`GET /api/homebrew`, fusionado por id en
  `src/api/homebrew.ts`), como `HomebrewStore` + `ContentRepository.addAll` en
  Flutter. Igual que allá, se descarta una entrada sin id o cuyo `source` no es
  `homebrew`; a diferencia de allá, una entrada que el motor no puede leer no
  se descarta sola (ver su `ponytail:`).
- **Ningún enlace** desde Flutter hacia `/v2` y Flutter no lee `webV2`: se
  entra escribiendo la URL.

## Orden previsto de pantallas

De solo lectura a escritura, y de lo simple a lo crítico. La razón: cada paso
nuevo suma un riesgo (dejar de leer y empezar a escribir datos de una cuenta),
y conviene que el motor y la API estén probados en producción con el riesgo
anterior antes de sumar el siguiente. Es un orden previsto, no un compromiso:

1. Ficha de personaje, solo lectura *(existe)*.
2. Lista de personajes y navegación entre pantallas *(existe)*.
3. Lo de lectura más simple: ajustes de visualización, cuaderno/campañas en
   modo lectura, bestiario y catálogos *(el Códice existe)*.
4. Escrituras de bajo riesgo: PG y usos de recursos en la ficha, descansos.
5. Edición completa: creador de personajes, subida de nivel, inventario.
6. Lo crítico, que toca datos de otras cuentas o de varias a la vez: Modo DM,
   combate, vínculos y códigos de campaña. Antes de portar esto es lectura
   obligatoria [Modo DM](modo-dm.md): la frontera «el DM no escribe la ficha de
   otra cuenta» es del servidor y vale igual para el cliente nuevo.
7. Homebrew, importación/exportación y el resto.

## Cómo se prueba

Tres niveles, de lo mecánico a lo humano. Los comandos exactos están en
`CLAUDE.md` §Comandos; el orden de CI está en `.github/workflows/ci.yml`.

1. **Paridad del motor** (job `engine_js`). Dart genera casos y su salida
   esperada (`dnd_engine/tool/generate_js_parity_fixtures.dart`); Node los
   recalcula con el JS compilado (`npm run test:parity`) y compara el JSON
   completo, **incluido el orden de las claves**. No prueba reglas (las prueban
   los tests de `dnd_engine`): prueba que `dart2js` no cambie enteros contra
   dobles, orden ni redondeos. Es también la red del tipo escrito a mano de
   `types.ts`: un campo nuevo en `ComputedSheet.toJson` rompe acá aunque el tipo
   no lo diga.
2. **Playwright** (job `web_e2e`). Pocas pruebas y solo de reglas
   (`e2e/`): levanta el servidor real con repositorios en memoria y sesiones
   falsas (`dnd_server/test/e2e_server.dart`), sirve el `dist` de `/v2` con
   personajes, ajustes y un arma homebrew sembrados, y verifica que la ficha y
   el dashboard muestren los números que da el motor (el dashboard, además, el
   orden de los ajustes, el favorito y el buscador); que las pestañas de la
   ficha sean rutas propias con historial; que el ataque del arma homebrew
   aparezca (y que sin la fusión no estaría); que un lanzador liste sus
   trucos y conjuros, con los siempre preparados en su grupo; que el
   inventario, la campaña y el diario muestren lo que resuelve el motor y lo
   que manda la API (con una mesa sembrada: otra cuenta como DM, un capítulo
   cerrado y una batalla); que el Códice cuente y abra el homebrew de la
   cuenta, que su búsqueda general coincida con el catálogo y que el glosario
   se lea en orden (`e2e/codice.spec.ts`); y que una cuenta sin `webV2` vea
   «No disponible» sin pedir sus datos (`e2e/acceso.spec.ts`). Lo esperado se
   calcula con el mismo motor y la misma fusión (`e2e/helpers.ts`). Sin
   reintentos: no hay «a veces anda».
3. **Comparación manual en producción con una cuenta habilitada.** Lo que solo
   se ve con el stack real (túnel, caché, cuenta de verdad, personajes
   complejos) se compara a ojo contra la misma pantalla de Flutter, con una
   cuenta en `V2_USERS`. Se anota en `docs/operaciones/pruebas-en-produccion.md`
   (registro privado que Git ignora).

Además corre `tsc --noEmit` y el build de Vite en el job `dnd_web`. El tipo de
los textos hace de test de paridad es/en: las dos lenguas son del mismo tipo.

**No hay** tests unitarios ni de componentes de `dnd_web` (ni runner configurado
para ellos), ni un chequeo automático de literales sueltos como el
`l10n_no_literals_test` de Flutter.

## Cómo se vuelve atrás

Un cambio en `packages/dnd_web` despliega igual que los de los otros paquetes
(el `gate` de `cd.yml` lo incluye), también el revert. Cada nivel se deshace sin tocar el código de Flutter:

- **Una cuenta**: sacar su id de `V2_USERS` y `docker compose up -d`. Deja de
  ver `/v2` y nunca perdió nada: la ficha de solo lectura no escribe.
- **Todas**: vaciar `V2_USERS`. `/v2` sigue respondiendo pero ninguna cuenta
  pasa de «No disponible».
- **Apagar `/v2`**: sacar `DND_WEB_V2_ROOT` (la imagen lo fija; habría que
  sobrescribirlo o apuntar a un directorio inexistente). `/v2` responde 404 y
  el resto del servidor arranca igual.
- **Un cambio malo**: un commit de revert en `main`, como cualquier otro.

Cuando existan pantallas que **escriban**, el criterio tendrá que ser otro:
volver atrás ya no alcanza si una escritura dejó datos en un formato que
Flutter no entiende. Los documentos de usuario llevan `schemaVersion` y
rechazan versiones futuras (ver `CLAUDE.md`); cualquier escritura desde React
pasa por los mismos modelos y migraciones del engine, nunca por un formato
propio.

## Lo que todavía no existe

Para que nadie lo dé por hecho:

- Reordenar, marcar favorito, crear, renombrar o borrar personajes desde React.
- Cualquier escritura desde React: todo el cliente hoy es solo lectura.
- Enlaces desde Flutter hacia `/v2` o redirección automática por `webV2`.
- Tests de componentes y chequeo de literales sueltos en `dnd_web`.
- Un criterio medido de «paridad visual» con Flutter: hoy es la comparación
  manual.
- Retiro de Flutter: ver abajo; ninguno de los criterios está cumplido.

## Criterios para retirar Flutter

Flutter se retira de `/` solo cuando se cumplen **todos**. Son criterios
propuestos, no medidos todavía:

1. Toda pantalla de Flutter tiene su equivalente en React, incluidas las
   críticas (Modo DM, combate, homebrew) y las escrituras.
2. Todas las cuentas activas están en `V2_USERS` (o el flag se vuelve la regla
   por defecto) durante un período sin regresiones reportadas.
3. La paridad del motor sigue en verde en CI y existe un respaldo automático
   de la paridad de las pantallas con escritura (hoy no existe).
4. El despliegue de `dnd_web` es primera clase *(ya cumplido: el `gate` de
   `cd.yml` incluye `packages/dnd_web`)*.
5. Texto, accesibilidad y responsividad cumplen la misma guía de diseño
   ([Diseño web](../desarrollo/diseno-web.md)) que Flutter.
6. Hay una ventana en la que Flutter sigue sirviéndose en una ruta de reserva
   antes de borrar `dnd_app`, para poder volver atrás.

Retirar Flutter implica además actualizar `CLAUDE.md`, la guía de diseño (cuyo
destino hoy sigue siendo Flutter) y el pipeline de CI/CD en el mismo cambio.
