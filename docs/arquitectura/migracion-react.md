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
  `catalogLabelOrder`, `formatCost`, `abilityModifier`, `bestiary`,
  `npcViews`, `encounterView`); la
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
- Tema: oscuro por defecto, con selector al pie del panel (y en Ajustes). Lo elegido en el
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
  muestran, no se editan**; crear, Ajustes, Sugerencias, Cerrar sesión
  enlazan a la raíz de Flutter (el Homebrew es del Modo DM y no está en este panel)
  (`FLUTTER_HOME`, `src/router.tsx`). Cada tarjeta enlaza a la ficha. Las cifras
  (nivel, PG máximos, CA, velocidad, iniciativa) salen de `computeSheet`; los
  PG actuales, de la ficha cruda. Sigue el lienzo aprobado: título, buscador,
  orden y «Crear» en una barra que se envuelve, regla ornamental y tarjetas
  con barra de PG en verde/oro/carmesí y CA/VEL/INIC en placas. El panel
  lateral es el menú principal (`src/dashboard/RosterPanel.tsx`), con el
  interruptor «Jugador / DM»: «DM» lleva al Modo DM de `/v2` (ver abajo).
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
  marcado «Propio». Las criaturas no están acá sino en el Bestiario. Cada categoría
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
- **Ajustes** en `/v2/ajustes` (`src/settings/`), a la que lleva «Ajustes» del
  pie del panel. Dos tarjetas con una diferencia que importa. **En este
  navegador**: el tema y el idioma, que son preferencias locales
  (`localStorage`, las mismas claves que Flutter: `milantus.v2.theme` y
  `milantus.locale`) y se cambian ahí mismo; cambiar el idioma recarga la
  página, porque se resuelve una sola vez al cargar (también el del motor).
  **En tu cuenta**: lo que Flutter guarda en `/api/settings` (con qué modo
  abre, el orden de los personajes, el favorito), que **se lee y no se edita**;
  un botón lleva a Flutter para cambiarlo. Quedan fuera lo que Flutter ofrece
  y actúa sobre sus propias funciones (mantener la pantalla encendida, volver a
  mostrar los tutoriales), la dificultad del encuentro (Modo DM) y el proveedor
  de retratos (vive en la pantalla de retratos).
- **Campañas** en `/v2/campanas` (`src/campaigns/`), **sin enlace en el menú
  de Jugador** (es del Modo DM; ver abajo): las mesas en las que juega la cuenta, de todos sus personajes en
  una lista (cada una con «Con <personaje>», que lleva a la pestaña Campaña de
  esa ficha). Es la **vista del jugador y nada más**: la misma consulta que la
  ficha (`GET /api/characters/:id/campaigns`), que el servidor ya poda con
  `Campaign.playerView()` y `EncounterLog.playerView()` —sin escenas de
  música, sin capítulos abiertos ni sus resúmenes, sin las notas del DM ni los
  PNJ—, y el bloque de cada mesa es el mismo componente que la pestaña
  (`CampaignBlock`). **No hay Cuaderno, notas ni lista de miembros** porque en
  Flutter son del Modo DM y el jugador no tiene ningún endpoint para leerlos;
  lo más parecido a «miembros» es «En la mesa también juega…», que ya trae
  cada campaña. Leer las campañas *como DM* (`/api/campaigns`) es el Modo DM,
  paso 6.
- **El Bestiario** en `/v2/bestiario` (`src/bestiary/`), **sin enlace en el menú de
  Jugador** (en Flutter es del Modo DM; ver abajo): la lista de criaturas del catálogo más las homebrew de la cuenta
  (marcadas «Propio»), con búsqueda por nombre y por línea de tipo, filtro por
  tipo y por rango de VD (un rango deja afuera a las que no tienen desafío; uno
  invertido corre el otro extremo) y orden por nombre o por VD. Cada criatura es
  una ruta (`/v2/bestiario/goblin`) y su perfil sigue al de Flutter: cifras
  (CA, PG con dados de golpe, iniciativa, VD, percepción pasiva), las seis
  características con sus salvaciones, datos de línea, rasgos y acciones
  agrupadas (con acierto, daño y alcance en placas, y el lanzamiento de
  conjuros enlazado al Códice). **Lo que deriva el motor** llega por
  `bestiary()` (`js/entrypoint.dart`): el orden y qué criaturas se listan (las
  invocaciones por fórmula quedan afuera), la línea de tipo (`displayKind`, que
  en un homebrew sigue al idioma), el tipo, el VD impreso
  (`Creature.challengeRatingText`), la iniciativa, la percepción pasiva y si el
  alcance de cada acción es cuerpo a cuerpo; el modificador de cada
  característica es `abilityModifier`. Es de solo lectura: **sumar al combate y
  «Editar una copia»** (Homebrew) son del Modo DM de Flutter y no están.
- **Campañas y Bestiario del jugador no están en el menú de Jugador**: se entra
  escribiendo la URL. Pertenecen al Modo DM, que ahora existe en parte (abajo): el
  panel DM enlaza el Bestiario.
- **El Modo DM, de solo lectura** en `/v2/dm` (`src/dm/`), al que lleva «DM» del
  interruptor. **Ninguna escritura**: ni crear o editar campañas, ni cerrar
  capítulos, ni música, ni notas; todo eso sigue en Flutter. Se porta por
  secciones, una por PR; hoy existen la **Mesa**, **Capítulos**, el **Cuaderno**,
  los **PNJ de la mesa**, el **Combate**, el **Bestiario**, la **Biblioteca de
  PNJ** y el **Homebrew**: todas las secciones del panel, más la **ficha
  completa de un miembro**. De lectura faltan todavía la de un PNJ con ficha y
  la música (ver «Lo que todavía no existe»). Rutas:
  `/v2/dm` (redirige a la primera campaña en curso, o a la primera que haya),
  `/v2/dm/campanas/:id/mesa|capitulos|cuaderno|pnj|combate`,
  `/v2/dm/campanas/:id/mesa/:miembro/personaje|combate`, `/v2/dm/bestiario[/:criatura]`,
  `/v2/dm/pnj[/:pnj]` y `/v2/dm/homebrew[/:categoria[/:entrada]]`. El panel
  (`DmPanel`) sigue al de Flutter: el
  interruptor con «DM» activo, las herramientas (Bestiario, Biblioteca de PNJ y
  Homebrew), las campañas
  agrupadas En curso / En pausa / Terminadas (plegable, abierta si la elegida
  es una de ellas) y, de la campaña elegida, sus secciones. La **Mesa** lista a los jugadores
  vinculados (`GET /api/campaigns/:id/members`, que lee la ficha **real** del
  jugador, no una copia): retrato inicial, nombre, especie y clase, nivel, barra
  de PG, placas CA / Inic / CD / Pasiva y los estados como pills carmesí. Las
  cifras salen de `computeSheet` con el catálogo del DM (SRD más **su** homebrew,
  como Flutter) y nunca se recalculan. **No muestra el nombre del jugador** que
  trae el diseño: la API de miembros no lo devuelve, y sumarlo abriría otra
  puerta entre cuentas (`modo-dm.md`). Cada tarjeta lleva a la **ficha completa
  del miembro** (`MemberSheetView`, la `MemberSheetScreen` de Flutter): la misma
  ficha de solo lectura del jugador (`SheetTabs`, que comparte con la ficha
  propia) con las pestañas que sirven en combate, Personaje y Combate, y sin un
  solo control. La URL lleva el **vínculo** (`memberId`) y no el id del
  personaje, porque es la fila de `campaign_members` la que autoriza al DM; se
  lee de la misma consulta que la Mesa, sin otra puerta, y como en Flutter no se
  sondea. Un vínculo cortado y uno inexistente dicen lo mismo («Ya no ves esta
  ficha»). La campaña es una ruta, y una ajena
  o inexistente muestra la misma pantalla «No se encontró la campaña»: el
  servidor las responde igual (404).
  **Capítulos** (`GET /api/campaigns/:id/chapters`): una tarjeta por capítulo con
  su estado (Cerrado / Abierto con borde oro / Pendiente), el **objetivo** —que
  el servidor nunca manda a un jugador, y por eso solo se lee con la cuenta del
  DM— y lo que reparte (placas de nivel, oro y objetos, y la línea que arma el
  motor con `chapterGrants`). Cerrar un capítulo avisa a otras cuentas y sigue en
  Flutter. La cabecera de la Mesa dice el capítulo en marcha. **Cuaderno**
  (`GET /api/campaigns/:id/notebook`, un solo pedido con `notes`,
  `encounterLogs` y `levelUps`): una pill por capítulo —se abre en el que está
  en marcha— más «Sin capítulo», un buscador que sin tildes ni mayúsculas cuenta
  las coincidencias en cada pill, el conteo de lo que hay y las entradas de la
  más vieja a la más nueva, con borde izquierdo oro (nota), carmesí (combate) y
  verde (subida de nivel). La nota se lee con el Markdown chico de la mesa; el
  combate se redacta como en Flutter (quiénes pelearon, contra quién, cuántos
  cayeron, aliados y neutrales, con los monstruos por su nombre del catálogo) y
  la subida de nivel dice la clase. Un combate o una subida de un capítulo que ya
  no existe va a «Sin capítulo» en vez de perderse. Es solo del DM: lo que el
  servidor poda para el jugador (notas, nombres propios de PNJ, subidas de
  nivel) no existe en su API. **Las menciones `@Nombre` se leen como texto**: en
  Flutter enlazan a la ficha del personaje o del PNJ, que acá todavía no
  existen. **Bestiario del DM**: es el mismo `BestiaryPage` del jugador
  (`/v2/bestiario`, ya completo) montado bajo `/v2/dm/bestiario` con el panel del
  DM (`dm` en `BestiaryPage`): igual navegador, filtros y perfil, con la
  cabecera del Modo DM y sus propias URL. Es una herramienta de la cuenta y no de
  una campaña: abre también sin campañas, no depende de la lista y trae el
  homebrew de **la cuenta** (el de otra no llega). Sumar al combate y «Editar una
  copia» siguen en Flutter.
  **Biblioteca de PNJ** (`GET /api/npcs` y `GET /api/npcs/:id`): también es de la
  cuenta y no de una campaña. La lista lleva un buscador por nombre (sin tildes
  ni mayúsculas), pills de campaña con su conteo (Todas, cada campaña, Sin
  campaña) y, más chicas, de tag; cada tarjeta dice qué es el PNJ («Bandido ·
  CA 12 · PG 11», «Elfo · Mago 3», «Sin estadísticas»), sus tags y en qué
  campañas está, y lleva a su ficha (`/v2/dm/pnj/garrick`). La ficha muestra la
  voz como cita, el trasfondo con el Markdown chico, las notas (las mismas
  tarjetas del Diario, `DiaryEntries`), con qué pelea —el bloque con CA, PG, VD
  y las primeras acciones, o la ficha compilada con CA, PG, iniciativa y
  pasiva— y el estado en cada campaña como pill con la palabra. **Lo que deriva
  el motor** llega por `npcViews` (`npcs` de `js/entrypoint.dart`, sobre
  `NpcStats` del engine): el PNJ migrado, los PG de un bloque (su fórmula
  resuelta) o de la ficha compilada, la CA, si viene herido en una campaña, el
  nombre de la criatura de base en el idioma activo y la especie y las clases de
  su ficha. Un PNJ ajeno y uno inexistente dan la misma pantalla «No se
  encontró el PNJ»: el servidor los responde igual (404). Crear, importar,
  editar, retratos, el estado por campaña, exportar y borrar siguen en Flutter,
  y el retrato todavía no se muestra (el medallón lleva la inicial, como en el
  resto de `/v2`).
  **PNJ de la mesa** (`GET /api/campaigns/:id/npcs`): los PNJ vinculados a la
  campaña con su estado **en esa** campaña. Arriba, el conteo («2 PNJ · 1 vivo ·
  0 muertos · 1 desconocido») y las pills de tag; cada tarjeta lleva la
  identidad (que abre la ficha de la Biblioteca), la línea de tipo con los PG
  con que volvió del último combate de esa mesa («Bandido · CA 12 · PG 7/11»),
  sus tags y el estado como pill con la palabra; un muerto va tachado y
  atenuado. Los PG del herido los resuelve el motor (`npcViews` con `currentHp`
  y `status` de cada entrada), igual que en la Biblioteca. Cambiar el estado,
  traer de la biblioteca y quitar de la campaña siguen en Flutter.
  **Homebrew** (`GET /api/homebrew`, el mismo pedido que fusiona el catálogo):
  es de la cuenta, no de una campaña. La portada tiene una tarjeta por
  categoría con cuánto propio hay y una muestra (Armas, Armaduras, Objetos
  mágicos, Equipo, Dotes, Especies, Trasfondos, Conjuros y Criaturas: los
  objetos se parten como en el Códice y no en una sola «Objetos» como en
  Flutter) y un buscador que mira todas a la vez. Una categoría es **la misma
  vista del Códice** (`CategoryView`) con solo lo que el catálogo fusionado marca
  `homebrew` y las URL del Modo DM, así una ficha no puede quedar distinta en los
  dos lugares; una criatura propia abre su perfil en el Bestiario del DM. Lo de
  otra cuenta no llega (la API es por cuenta) y su URL muestra la categoría
  vacía. Crear, editar, importar, exportar y borrar siguen en Flutter.
  **Combate** (`GET /api/campaigns/:id/encounter`, más los miembros, los PNJ de
  la mesa y el Cuaderno): el combate abierto, de solo lectura. Arriba, una placa
  con la ronda, «Turno N de M» y cuántos quedan en pie por bando (o «Armando el
  combate» mientras nadie tiró iniciativa); debajo, la planilla de Flutter
  —iniciativa con TURNO / ACTUÓ / SALTA, nombre con el bando y su línea, PG con
  barra y MALTRECHO, CA y efectos— y a su lado «Del turno», con el perfil del
  Bestiario del monstruo que juega, las acciones del bloque de un PNJ o, si le
  toca a un jugador, que su ficha la lleva quien lo juega. Al pie, los combates
  cerrados redactados como en el Cuaderno. **Los PG salen de dos fuentes**,
  como en Flutter: los de un monstruo o un PNJ, del encuentro; los de un
  jugador, de **su ficha real** (actuales de la ficha cruda, máximo de
  `computeSheet`), que el DM no escribe: la fila dice «En su ficha». Sin combate
  abierto, el vacío lo dice y siguen los pasados. **Lo que deriva el motor**
  llega por `encounterView` (`encounter` de `js/entrypoint.dart`): el encuentro
  migrado, de quién es el turno (salta a los caídos), quién está caído o
  maltrecho y cuántos quedan en pie (`Encounter.standing`, que se movió al
  engine desde la pantalla de Flutter y Flutter ahora usa). El combate de otra
  cuenta responde el mismo 404 que una campaña inexistente, y el jugador nunca
  recibe el documento: solo su estado de turno (`GET /api/characters/:id/turn`).
  No se sondea cada 5 s como en Flutter (ver el `ponytail:` de
  `useCampaignEncounter`). Tirar iniciativa, dañar o curar, pasar el turno,
  sumar o sacar combatientes, anotar efectos, las acciones legendarias, la
  dificultad y cerrar siguen en Flutter.
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
3. Lo de lectura más simple: ajustes de visualización *(existe)*,
   campañas del jugador en modo lectura *(existen; el cuaderno es del DM)*,
   bestiario *(existe)* y catálogos *(el Códice existe)*.
   **Lectura del Modo DM** (se sumó a este paso): Mesa, Capítulos, Cuaderno,
   Bestiario, Biblioteca de PNJ, PNJ de la mesa, Homebrew y Combate *(existen)*.
   La ficha completa de un miembro *(existe)*.
   **Faltan para cerrar el paso**, todas de lectura:
   - la ficha completa de un PNJ con ficha (Flutter abre `SheetScreen`; acá la
     ficha del PNJ muestra solo el resumen compilado);
   - la música: escuchar las escenas de la campaña (`dm/music/` de Flutter),
     que no escribe nada; crearlas y editarlas es del paso 6;
   - los retratos (personaje, miembro y PNJ: hoy el medallón lleva la inicial)
     y su visor;
   - las menciones `@Nombre` del Cuaderno como enlaces, que dependen de las dos
     fichas de arriba;
   - imprimir la ficha (`print_sheet.dart`).
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
   se lea en orden (`e2e/codice.spec.ts`); que Ajustes muestre lo de la cuenta,
   cambie el tema y el idioma sin escribir en la API y recuerde el idioma con la
   clave de Flutter (`e2e/ajustes.spec.ts`); que Campañas muestre la mesa
   sembrada con lo que reparte el motor y que **nada del DM** (escena de música,
   capítulo en marcha, nota) aparezca ni en la API ni en pantalla, y que otra
   cuenta, o el propio DM, reciba 404 al pedir las campañas de un personaje
   ajeno, idéntico al de un id inexistente (`e2e/campanas.spec.ts`); que el
   Bestiario liste las criaturas que da el motor más una criatura homebrew
   sembrada (con la iniciativa derivada por el motor, no la de la
   característica), abra un perfil con sus modificadores, salvaciones y
   conjuros, filtre y ordene, y que el homebrew no llegue a otra cuenta
   (`e2e/bestiario.spec.ts`); que la Mesa del DM
   liste a los dos jugadores sembrados (de dos cuentas distintas) con los números
   del motor y los estados de la ficha, sin escribir nada, que leerla no cambie la
   ficha del jugador, que su tarjeta abra la ficha completa del miembro (por el
   vínculo, con Personaje y Combate y los números del motor) y que otra cuenta
   no la abra por URL, que Capítulos muestre estado, objetivo y recompensas (y que
   el objetivo y los capítulos sin cerrar no lleguen al jugador), que el
   Cuaderno junte notas, combates (con un PNJ aliado por su nombre propio) y
   subidas de nivel, busque, y que nada de eso llegue al jugador, que el
   Bestiario del DM abra bajo `/v2/dm/bestiario` con el homebrew de la cuenta y
   sin dárselo a otra, y que otra cuenta —con o sin `webV2`— reciba el mismo 404
   que ante una campaña inexistente, en la API y en la pantalla
   (`e2e/dm.spec.ts`); que la Biblioteca de PNJ liste los tres PNJ sembrados
   (bloque, ficha y sin estadísticas) con la línea que arma el motor, filtre por
   campaña, tag y nombre, abra la ficha con la voz, el trasfondo, las notas, el
   bloque o la ficha compilada y el estado por campaña, sin escribir nada, y que
   los PNJ de la mesa muestren su estado y los PG con que volvió el herido, sin
   escribir, y que
   otra cuenta tenga la biblioteca vacía, reciba por un PNJ ajeno o por los PNJ
   de una mesa ajena el mismo 404 que por lo inexistente (en la API y en la
   pantalla) y no encuentre nada de eso en la vista del jugador (`e2e/pnj.spec.ts`); que el Homebrew cuente lo
   propio por categoría (un arma, una dote y una criatura sembradas), abra la
   ficha del Códice bajo `/v2/dm/homebrew`, busque en todo y lleve la criatura al
   Bestiario, sin escribir, y que otra cuenta no reciba nada ni lo abra por URL
   (`e2e/homebrew.spec.ts`); que el Combate muestre el orden sembrado con el
   turno, ACTUÓ y SALTA, los PG de cada fuente (los del jugador, de su ficha), la
   CA de cada una, el perfil del que juega y los combates cerrados, sin escribir,
   y que otra cuenta reciba el mismo 404 que ante una campaña inexistente y el
   jugador vinculado solo su estado de turno (`e2e/combate.spec.ts`); y que una cuenta sin `webV2` vea
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

- Las lecturas que faltan del paso 3 (la lista está en «Orden previsto de
  pantallas»): la ficha completa de un PNJ con ficha, la música, los retratos, las menciones `@Nombre` como enlaces e imprimir.
- Cualquier escritura desde React: todo el cliente hoy es solo lectura, así que
  los pasos 4 a 7 están enteros por hacer. Entre ellos, reordenar, marcar
  favorito, crear, renombrar o borrar personajes, y escribir en `/api/settings`
  (por eso el tema elegido en el navegador gana sobre el de la cuenta).
- Enlaces desde Flutter hacia `/v2` o redirección automática por `webV2`.
- Tests de componentes y chequeo de literales sueltos en `dnd_web`.
- Un criterio medido de «paridad visual» con Flutter: hoy es la comparación
  manual.
- Retiro de Flutter: ver abajo; de los seis criterios solo está cumplido el 4.

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
