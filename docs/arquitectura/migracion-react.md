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
  `npcViews`, `encounterView`, `musicSource`, `actOn`); la
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
  cuenta, porque React todavía no escribe en los ajustes de la cuenta.
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
  un diálogo. Lo único que se escribe son las acciones de partida y la
  mochila (abajo): el resto de la ficha no se edita. El panel es el de una pantalla de
  adentro: «volver», la tarjeta del personaje, las cinco pestañas, **Subir
  nivel** (el asistente de `/v2`, abajo), Retrato y Compartir, que enlazan a
  Flutter, e **Imprimir**; al pie, el
  estado del guardado, el tema y la versión. **Imprimir** (`PrintSheet`, el
  `print_sheet.dart` de Flutter) monta una hoja propia al pie de `body` y abre
  el diálogo del navegador (que ofrece también «Guardar como PDF»); la hoja de
  estilos de impresión (`index.css`) la deja sola en papel y en pantalla no se
  ve nunca. Es la misma hoja de Flutter, en blanco y negro (`--print-*`) y para
  jugar con lápiz: lo que cambia en la mesa (PG actuales y temporales, usos,
  monedas, carga) sale en blanco con el máximo al lado y casillas, y conjuros y
  rasgos van sin su texto. Tres hojas: cifras, características y salvaciones,
  habilidades, ataques, competencias e idiomas, estado y notas; recursos,
  rasgos e inventario; y conjuros (espacios y las listas de la pestaña Combate)
  si lanza alguno. Todo número es de `computeSheet` y la mochila de
  `inventoryOf`. La API no tiene `GET` por id, así que usa la
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
  capítulos, ni escenas de música, ni notas; todo eso sigue en Flutter. Se porta por
  secciones, una por PR; hoy existen la **Mesa**, **Capítulos**, el **Cuaderno**,
  los **PNJ de la mesa**, el **Combate**, el **Bestiario**, la **Biblioteca de
  PNJ** y el **Homebrew**: todas las secciones del panel, más la **ficha
  completa** de un miembro y la de un PNJ con ficha y la **música**. Rutas:
  `/v2/dm` (redirige a la primera campaña en curso, o a la primera que haya),
  `/v2/dm/campanas/:id/mesa|capitulos|cuaderno|pnj|combate`,
  `/v2/dm/campanas/:id/mesa/:miembro/personaje|combate`, `/v2/dm/bestiario[/:criatura]`,
  `/v2/dm/pnj[/:pnj]`, `/v2/dm/pnj/:pnj/ficha/personaje|combate|inventario` y `/v2/dm/homebrew[/:categoria[/:entrada]]`. El panel
  (`DmPanel`) sigue al de Flutter: el
  interruptor con «DM» activo, las herramientas (Bestiario, Biblioteca de PNJ y
  Homebrew), las campañas
  agrupadas En curso / En pausa / Terminadas (plegable, abierta si la elegida
  es una de ellas) y, de la campaña elegida, sus secciones. La **música**
  (`MusicPlayer`, el `dm/music/` de Flutter) es **solo para escuchar**: una pill
  «Música» flotante abajo a la derecha que se despliega con las escenas de la
  campaña (las del documento de `GET /api/campaigns`, que el servidor poda de la
  vista del jugador) y el reproductor de YouTube embebido, con pausar, reanudar,
  minimizar (que pausa: YouTube exige el reproductor a la vista) y «Abrir en
  YouTube» si el dueño no deja verlo afuera. El enlace lo interpreta el motor
  (`musicSource`, sobre `MusicSource.parse`): la pantalla nunca arma la dirección
  del iframe con lo que pegó el DM, y una escena que no es de YouTube se lista
  sin reproducirse. Vive en `DmPage` y no en una sección: cambiar de sección o
  abrir una herramienta de la cuenta no la corta; cambiar de campaña, sí. Crear,
  editar, reordenar, borrar y marcar «ofrecer al iniciar un combate» son
  escrituras (paso 6), y la oferta al empezar un combate no está porque acá
  nadie empieza uno. La **Mesa** lista a los jugadores
  vinculados (`GET /api/campaigns/:id/members`, que lee la ficha **real** del
  jugador, no una copia): retrato, nombre, especie y clase, nivel, barra
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
  nivel) no existe en su API. **Las menciones `@Nombre` son enlaces**, como en
  Flutter: las de una nota (en el Markdown chico, `MarkdownText` con
  `mentions`) y, en un combate, los jugadores y los PNJ que siguen en la
  campaña. Un personaje de la mesa (`GET /api/campaigns/:id/members`) lleva a
  su ficha completa, por el vínculo; un PNJ de la campaña (`GET
  /api/campaigns/:id/npcs`) a su ficha de la Biblioteca; si tienen el mismo
  nombre gana el jugador. El corte es el de Flutter (`withMentions`): sin
  distinguir mayúsculas ni tildes, gana el nombre más largo y tiene que
  terminar ahí; una `@` que no es de nadie queda como texto, y el que se fue
  de la campaña también. Si esas dos listas no cargan, las menciones se leen
  como texto y el Cuaderno no se cae. **Bestiario del DM**: es el mismo `BestiaryPage` del jugador
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
  su ficha. La tarjeta de la ficha compilada lleva a la **ficha completa del
  PNJ** (`NpcSheetView`; Flutter abre `SheetScreen` en `npcMode`): la misma
  `SheetTabs` de un jugador con Personaje, Combate e Inventario, sin Campaña ni
  Diario porque en un PNJ son su trasfondo y sus notas, y de solo lectura (en
  Flutter se edita). Sale del mismo `GET /api/npcs/:id`. Un PNJ ajeno y uno
  inexistente dan la misma pantalla «No se encontró el PNJ» —también en su
  ficha, igual que un PNJ sin ficha—: el servidor los responde igual (404). Crear, importar,
  editar, generar o subir retratos, el estado por campaña, exportar y borrar
  siguen en Flutter.
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
- **Retratos** (`src/ui/portrait.ts`, `Medallion`, `PortraitViewer`; en
  Flutter `portrait_image.dart` y `portrait_viewer.dart`): el medallón muestra
  el primer retrato de la ficha (`portraitPaths`) y, si no hay o no carga —uno
  borrado, uno de otra cuenta—, la inicial. Lo propio (la ficha, el dashboard,
  un PNJ y la ficha de un PNJ, que son del DM) va por `/api/portraits/<clave>`;
  el de un miembro de la Mesa, por **el vínculo**
  (`/api/campaigns/:id/members/:miembro/portrait/<archivo>`), porque con la
  clave tal cual el servidor lo busca en la cuenta del DM y responde 404. Un
  PNJ con ficha muestra el de su ficha, como `npcPortraitKey`. Cada medallón
  pide la miniatura de su tamaño (`?w=`, la escalera de anchos duplicada a
  propósito, como en Flutter). Donde el medallón no es parte de un enlace (el
  panel de la ficha, la cabecera de la ficha de un miembro, de un PNJ y de su
  ficha) se toca para abrir el **visor**: el original entero sobre el velo, que
  se cierra con `Esc`, un clic afuera o el botón. Generar, subir, elegir o
  borrar un retrato son escrituras: «Retrato» del panel sigue llevando a
  Flutter.
- **Homebrew**: la ficha y el dashboard calculan con el catálogo oficial más
  el contenido homebrew de la cuenta (`GET /api/homebrew`, fusionado por id en
  `src/api/homebrew.ts`), como `HomebrewStore` + `ContentRepository.addAll` en
  Flutter. Igual que allá, se descarta una entrada sin id o cuyo `source` no es
  `homebrew`; a diferencia de allá, una entrada que el motor no puede leer no
  se descarta sola (ver su `ponytail:`).
- **Escrituras de la ficha propia** (paso 4). Es lo primero que React escribe
  en una cuenta, y solo en la ficha de `/v2/personajes/:id`: la de un miembro
  de la Mesa y la de un PNJ usan los mismos componentes sin `model.write` y no
  muestran un solo control. Hoy: **daño, curación y PG temporales** (un campo
  «Cantidad» y tres verbos, como Flutter); a 0 PG, las **salvaciones de
  muerte** con «+Éxito» y «+Fallo» (a tres éxitos se estabiliza y a tres
  fallos muere, con su aviso); el **dado de golpe**, que tira el motor y avisa
  cuánto curó; y **gastar y recuperar** cada espacio de conjuro (normal o de
  pacto) y cada recurso con usos, con los botones de cada fila. Una reserva
  (Imposición de Manos, Puntos de Concentración) pregunta cuántos puntos en un
  diálogo, como Flutter; pasarse de lo que queda lo recorta el motor. Y los
  **descansos corto y largo**, en «Recursos y descansos», con el aviso de
  Flutter (qué recuperó; en el largo, el cansancio que queda, la Inspiración
  Heroica ganada y los objetos que recargaron al amanecer) y su **«Deshacer»**,
  que vuelve a guardar la ficha entera de antes del descanso (con la mochila
  de antes de la recarga), tal como la dio el motor.
  Desde el paso 5: la **Inspiración Heroica** a mano (el casillero de Combate
  se toca para marcarla o gastarla, como en Flutter) y la **concentración**:
  «Concentrar» en cada conjuro de concentración de la lista (al desplegarlo) y
  «Terminar» en el aviso de la tarjeta de conjuros. Si hay compañeros que
  dependen de la concentración actual, se pregunta antes de despedirlos; cambiar
  de conjuro se avisa después. En Flutter la lista **no lanza** conjuros: gastar
  un espacio o el uso gratis al lanzar solo pasa al invocar un compañero, que
  sigue en Flutter. El uso gratis de un conjuro innato es su recurso
  (`innate-<id>`) y ya se gasta con los botones de recursos.
  En **Inventario** (5b1): las cinco monedas se escriben a mano (se guardan al
  salir del campo o con Enter); cada fila lleva la casilla de equipar (solo lo
  que se equipa, `InventoryOps.isEquippable`), − y + en la cantidad (el − se
  apaga en 1), − y + en las cargas, y el menú de Flutter: cantidad exacta,
  nota, sintonizar, mano secundaria (una sola, por el arma de base), a dos
  manos y quitar, que avisa con «Deshacer». Las reglas que estaban en el widget
  de Flutter (la mano secundaria única, el tope de cargas, qué se equipa, la
  bolsa sin monedas en cero) pasaron a `InventoryOps` y `CoinOps`, y Flutter
  las usa de ahí. Desde 5b2, **«Agregar objeto»** abre el catálogo
  (`src/sheet/ItemCatalog.tsx`, el `ItemCatalogDialog` de Flutter): buscador,
  pills de familia y, por fila, «Gratis» (suma sin pagar y el catálogo sigue
  abierto) y «Comprar», apagado con «te faltan…» si la bolsa no alcanza.
  Comprar, y «Vender…» del menú de la fila, abren el diálogo de Flutter
  (`TradeDialog`): cantidad, precio por unidad en po, pp y pc que se puede
  corregir, y la cuenta —qué sale de la bolsa, el vuelto, cuánto falta o cómo
  queda— que hace el motor (`tradePreview`, sobre `CoinOps.plan` y
  `receive`, las mismas que aplican `buy` y `sell`). Las dos se anotan en
  «Cuentas» del Diario con la fecha local que manda el cliente, y avisan con
  «Deshacer». Lo único que React resta es el precio de una fila contra la
  bolsa para el «te faltan»; la compra la vuelve a validar el motor.
  **Subida de nivel** (5c1, `/v2/personajes/:id/subir-nivel`,
  `src/levelup/LevelUpWizard.tsx`; «Subir nivel» del panel lleva ahí). Es el
  circuito rediseñado en el lienzo «Subida de nivel»: una sola forma de elegir
  (la opción, círculo si es una y cuadrado si son varias, apagada con el
  motivo si no se puede), un estado por bloque (falta o «n de m», listo,
  automático) y a la derecha la explicación de lo último que se tocó y «Así
  queda», que compara la ficha de antes con la que da el motor. Pasos:
  resumen (la clase en una fila con scroll horizontal, y qué trae el nivel),
  PG (promedio o tirada, que tira el motor, o lo que salió en la mesa),
  subclase si toca, mejora de característica o dote (con el +1 de los dones
  épicos) y revisión. Confirmar es la acción `levelUp`; vuelve a la ficha con
  el aviso y «Deshacer». **La lógica bajó al engine** (`LevelUp` y
  `LevelUpDraft`, `level_up.dart`): cómo queda el personaje, qué pasos hacen
  falta, si la mejora está completa, las dotes que se ofrecen con el
  prerrequisito que falta, los rasgos ganados y los PG actuales al confirmar.
  Flutter (`LevelUpScreen`) la usa de ahí. Desde 5c2, los pasos
  **Elecciones** (estilo de combate, invocaciones y demás cupos de rasgo, con
  la explicación de cada opción a la derecha) y **Competencias** (competencias
  nuevas y Pericia) aparecen si la subida los pide, después de la mejora. Lo
  elegido viaja en el borrador por `groupId` (`featurePicks`,
  `proficiencyPicks`) y el motor lo mezcla con lo que el personaje ya tenía,
  con el ámbito por clase de una multiclase; las opciones de cada cupo, su
  prerrequisito, lo bloqueado y lo que el personaje ya traía fijo
  (`LevelUp.featureSlots`, `proficiencySlots`) también son del motor, y
  Flutter los usa. Un cupo que no se revisa traba lo que ya traía, no lo
  elegido en esta subida. Desde 5c3, **Conjuros de rasgos** (los cupos que
  concede un rasgo o una dote, como Iniciado en la Magia) y **Conjuros** (los
  trucos y los preparados o conocidos de la clase que sube, con buscador y
  scroll propio, y la ficha del conjuro a la derecha) cierran el circuito:
  ninguna subida manda ya a la app principal. Qué se ofrece y qué ya concede
  un rasgo (y por eso no ocupa cupo) es `LevelUp.classSpells`, que también
  usa el editor de conjuros de Flutter (`SpellEditScreen`); lo elegido viaja
  como `spellPicks`, `classCantripPicks` y `classSpellPicks`. El motor
  rechaza confirmar una subida a medias. Las piezas del circuito (`Option`,
  `Block`, `Status`) viven en el asistente; si el creador (5d) las reusa,
  pasan a `src/ui/`.
  - **Toda escritura la hace el motor.** `actOn` (`act` de `js/entrypoint.dart`,
    sobre `SheetActions.apply` del engine) recibe la ficha y la acción y
    devuelve la ficha nueva, migrada y con el `schemaVersion` actual, más lo
    que pasó para el aviso. React no suma ni resta nada ni arma un formato
    propio: guarda lo que devolvió el motor. Lo que antes vivía en widgets de
    Flutter (el tope de usos de un recurso, los PG máximos de un compañero al
    descansar) pasó al engine y Flutter lo usa de ahí.
  - **El guardado es el de Flutter** (`src/api/characterSave.ts`, el
    `CharactersController`): `PUT /api/characters/:id` con la ficha entera,
    400 ms de espera para juntar toques seguidos y una cola por personaje que
    siempre manda la última copia. Mandar el estado y no la acción hace seguro
    reintentar. La ficha se actualiza al instante en la caché de
    `/api/characters` (`src/sheet/writer.ts`) y no se vuelve a pedir después de
    guardar.
  - **Conflictos: gana el último que guarda**, como entre dos pestañas de
    Flutter; el servidor no tiene versión con qué rechazar una copia vieja. Para
    no pisar lo hecho en Flutter, la ficha se vuelve a pedir al volver a la
    pestaña de `/v2`, **solo si no hay nada pendiente**, y una acción cancela el
    pedido de la lista que esté en vuelo. Lo que no cubre: una pestaña de
    Flutter abierta desde antes puede pisar lo que hizo React al guardar algo,
    porque Flutter no vuelve a pedir la lista. Evitarlo pide versión en el
    servidor (409) y que Flutter la use.
  - **Qué se ve**: al pie del panel, en vez de «Solo lectura», la pill del
    guardado (`SaveStatusBadge`: Guardando… / Guardado / No se guardó con
    «Reintentar»). Si falla, lo local se conserva; cerrar o recargar con algo
    pendiente lo pregunta el navegador (`beforeunload`). Los avisos van en
    `Toast`.
- **Ningún enlace** desde Flutter hacia `/v2` y Flutter no lee `webV2`: se
  entra escribiendo la URL.

## Orden previsto de pantallas

De solo lectura a escritura, y de lo simple a lo crítico. La razón: cada paso
nuevo suma un riesgo (dejar de leer y empezar a escribir datos de una cuenta),
y conviene que el motor y la API estén probados en producción con el riesgo
anterior antes de sumar el siguiente. Es un orden previsto, no un compromiso:

1. Ficha de personaje, solo lectura *(existe)*.
2. Lista de personajes y navegación entre pantallas *(existe)*.
3. Todo lo de lectura *(existe)*: ajustes de visualización, campañas del
   jugador en modo lectura (el cuaderno es del DM), bestiario y catálogos (el
   Códice). **Lectura del Modo DM** (se sumó a este paso): Mesa, Capítulos,
   Cuaderno, Bestiario, Biblioteca de PNJ, PNJ de la mesa, Homebrew y Combate;
   la ficha completa de un miembro y la de un PNJ con ficha; la música (solo
   escuchar); los retratos con su visor; las menciones `@Nombre` del Cuaderno
   como enlaces, e imprimir la ficha.
4. Escrituras de bajo riesgo *(existe)*: PG y salvaciones de muerte, usos de
   espacios, recursos y dados de golpe, y los descansos con «Deshacer», solo
   en la ficha propia.
5. Edición completa: creador de personajes, subida de nivel, inventario. Por
   partes: 5a, la Inspiración Heroica y la concentración *(existe)*; 5b1,
   editar la mochila desde la fila y las monedas *(existe)*; 5b2, catálogo,
   comprar y vender *(existe)*; 5c1, subida de nivel sin elecciones de rasgos,
   competencias ni conjuros *(existe)*; 5c2, esas elecciones de rasgos y
   competencias *(existe)*; 5c3, los conjuros *(existe)*; 5d, creador.
6. Lo crítico, que toca datos de otras cuentas o de varias a la vez: Modo DM,
   combate, vínculos y códigos de campaña. Antes de portar esto es lectura
   obligatoria [Modo DM](modo-dm.md): la frontera «el DM no escribe la ficha de
   otra cuenta» es del servidor y vale igual para el cliente nuevo. Entra acá
   también la edición de la ficha completa de un PNJ (inventario, comprar y
   vender, y el resto de lo que ya se escribe en la ficha propia): reutiliza
   las acciones del motor y la cola de guardado del paso 5, pero guarda por
   `PUT /api/npcs/:id`.
7. Homebrew, importación/exportación y el resto.

## Cómo se prueba

Tres niveles, de lo mecánico a lo humano. Los comandos exactos están en
`CLAUDE.md` §Comandos; el orden de CI está en `.github/workflows/ci.yml`.

1. **Paridad del motor** (job `engine_js`). Dart genera casos y su salida
   esperada (`dnd_engine/tool/generate_js_parity_fixtures.dart`); Node los
   recalcula con el JS compilado (`npm run test:parity`) y compara el JSON
   completo, **incluido el orden de las claves**. No prueba reglas (las prueban
   los tests de `dnd_engine`): prueba que `dart2js` no cambie enteros contra
   dobles, orden ni redondeos. Los casos `accion-*` prueban lo mismo con `act`:
   la ficha que el cliente guarda después de una acción (con una semilla fija
   para el dado de golpe y la recarga al amanecer). Es también la red del tipo escrito a mano de
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
   trucos y conjuros, con los siempre preparados en su grupo; que imprimir arme
   la hoja con los números del motor, que solo se vea en papel y se vaya al
   cerrar el diálogo; que el
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
   no la abra por URL, que el retrato sembrado del miembro llegue por el vínculo (y
   por la clave dé 404), con miniatura en la Mesa y el original en el visor, que la música ponga una escena sembrada con el reproductor
   que arma el motor y siga al cambiar de sección, sin escribir, que Capítulos muestre estado, objetivo y recompensas (y que
   el objetivo y los capítulos sin cerrar no lleguen al jugador), que el
   Cuaderno junte notas, combates (con un PNJ aliado por su nombre propio) y
   subidas de nivel, busque, enlace las menciones de una nota y de un combate a
   la ficha del miembro o del PNJ (y deje como texto las de nadie), y que nada
   de eso llegue al jugador, que el
   Bestiario del DM abra bajo `/v2/dm/bestiario` con el homebrew de la cuenta y
   sin dárselo a otra, y que otra cuenta —con o sin `webV2`— reciba el mismo 404
   que ante una campaña inexistente, en la API y en la pantalla
   (`e2e/dm.spec.ts`); que la Biblioteca de PNJ liste los tres PNJ sembrados
   (bloque, ficha y sin estadísticas) con la línea que arma el motor, filtre por
   campaña, tag y nombre, abra la ficha con la voz, el trasfondo, las notas, el
   bloque o la ficha compilada y el estado por campaña, y de ahí la ficha
   completa con Personaje, Combate e Inventario, sin escribir nada, y que
   los PNJ de la mesa muestren su estado y los PG con que volvió el herido, sin
   escribir, y que
   otra cuenta tenga la biblioteca vacía, reciba por un PNJ ajeno o por los PNJ
   de una mesa ajena el mismo 404 que por lo inexistente (en la API y en la
   pantalla, también en la ficha completa del PNJ) y no encuentre nada de eso en la vista del jugador (`e2e/pnj.spec.ts`); que el Homebrew cuente lo
   propio por categoría (un arma, una dote y una criatura sembradas), abra la
   ficha del Códice bajo `/v2/dm/homebrew`, busque en todo y lleve la criatura al
   Bestiario, sin escribir, y que otra cuenta no reciba nada ni lo abra por URL
   (`e2e/homebrew.spec.ts`); que el Combate muestre el orden sembrado con el
   turno, ACTUÓ y SALTA, los PG de cada fuente (los del jugador, de su ficha), la
   CA de cada una, el perfil del que juega y los combates cerrados, sin escribir,
   y que otra cuenta reciba el mismo 404 que ante una campaña inexistente y el
   jugador vinculado solo su estado de turno (`e2e/combate.spec.ts`); que
   daño, curación y PG temporales manden y dejen guardada exactamente la ficha
   que da el motor, que se relea sin migrar y al recargar, que solo se escriba
   la ficha propia, que a 0 PG tres «+Éxito» seguidos estabilicen y guarden lo
   del motor, que gastar y recuperar un espacio y un uso manden y guarden lo
   del motor, que el dado de golpe gaste uno y cure lo que dice su aviso, que
   los descansos guarden lo del motor (el largo, además, recargue el objeto y
   lo cuente) y que «Deshacer» vuelva a guardar la ficha de antes, que la
   Inspiración Heroica y la concentración guarden lo del motor, que la mochila
   se edite desde la fila (equipar, cantidad, nota, monedas) y que quitar se
   deshaga, que comprar del catálogo y vender guarden lo del motor y vender
   se deshaga, que una bárbara sembrada suba a 4 por PG, subclase y mejora
   guardando lo del motor y se deshaga, que un guerrero elija en la subida el
   estilo de combate pendiente y guarde lo del motor, que la clériga suba
   eligiendo Orden Divina, los conjuros de Iniciado en la Magia y los de
   clase y guarde lo del motor, y
   que la ficha de otra cuenta (la de un miembro, para el DM) no
   tenga un solo control (`e2e/escritura.spec.ts`, con una cuenta propia para
   no cambiar lo que leen las demás); y que una cuenta sin `webV2` vea
   «No disponible» sin pedir sus datos (`e2e/acceso.spec.ts`). Lo esperado se
   calcula con el mismo motor y la misma fusión (`e2e/helpers.ts`). Sin
   reintentos: no hay «a veces anda».

   **Trampa al volver escribible una pantalla:** las pruebas de lectura
   (`ficha.spec.ts`, `codice.spec.ts`…) entran con la cuenta de `TOKEN`, que es
   **dueña** de sus fichas, así que ven los controles nuevos. Una celda que
   antes mostraba «Sí» y ahora es una casilla las rompe sin que el cambio
   toque esos archivos (pasó con la columna «Equipado» del Inventario en 5b1:
   CI en rojo y el CD salteado). Antes de commitear, buscá en `e2e/` cada
   `data-field` y cada texto de la pantalla que cambió, y adaptá lo que lea
   como texto lo que ahora es un control. Si Playwright no corre en la máquina
   (ver la trampa del antivirus en `CLAUDE.md`), mirá el resultado de CI antes
   de seguir con el próximo cambio: CI en rojo no llega a producción.
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
  ver `/v2`; lo que ya escribió desde ahí (ver abajo) queda en su ficha y
  Flutter lo abre como propio.
- **Todas**: vaciar `V2_USERS`. `/v2` sigue respondiendo pero ninguna cuenta
  pasa de «No disponible».
- **Apagar `/v2`**: sacar `DND_WEB_V2_ROOT` (la imagen lo fija; habría que
  sobrescribirlo o apuntar a un directorio inexistente). `/v2` responde 404 y
  el resto del servidor arranca igual.
- **Un cambio malo**: un commit de revert en `main`, como cualquier otro.

**Con escrituras el criterio cambia** (paso 4 en adelante): sacar una cuenta
de `V2_USERS` o revertir el commit ya no deshace lo que React guardó. Lo que
hace seguro volver atrás es que **no hay nada que deshacer en el formato**:

- Toda ficha que guarda React la produjo el motor (`actOn`): sale de
  `Character.fromJson` → la acción → `Character.toJson`, el mismo camino que un
  guardado de Flutter, con el `schemaVersion` actual. Flutter la abre igual que
  una propia y no hay campo que solo entienda React.
- La imagen compila Flutter, React y el motor del mismo commit, así que nunca
  conviven un motor de `/v2` más nuevo que el de `/`. El servidor vuelve a leer
  cada ficha con `Character.fromJson`, que rechaza una versión futura.
- Lo que sí puede pasar es un **valor** equivocado (un daño de más): se
  corrige a mano en la ficha, desde Flutter o desde `/v2`, como cualquier
  error de la mesa. Un revert del cliente no lo arregla.
- Un cambio malo del motor que escribiera algo raro se arregla como siempre:
  un commit nuevo (y, si dejó documentos que ya no se leen, una migración del
  modelo con su test, nunca editar la base a mano).

## Lo que todavía no existe

Para que nadie lo dé por hecho:

- Editar la ficha completa de un PNJ (paso 6): reutiliza las acciones y la
  cola de guardado del paso 5, pero guarda por `PUT /api/npcs/:id`.
- Toda otra escritura desde React: los pasos 5 a 7 están enteros por hacer.
  Entre ellos, reordenar, marcar favorito, crear, renombrar o borrar
  personajes, condiciones, compañeros (y con ellos lanzar gastando espacio o
  uso gratis), cambiar el truco innato y Forma Salvaje; en el inventario,
  los planos del Artífice y los objetivos de arma de un rasgo (Pacto del
  Filo); preparar conjuros desde la ficha (el editor ya existe en la subida),
  y
  escribir en `/api/settings` (por eso el tema elegido en el navegador gana
  sobre el de la cuenta).
- Control de versión en el servidor para las escrituras (rechazar una copia
  vieja con 409): hoy gana el último que guarda, como en Flutter.
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
