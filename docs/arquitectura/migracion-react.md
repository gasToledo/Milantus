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
  `npcViews`, `encounterView`, `encounterAct`, `encounterDetails`,
  `encounterInitiatives`, `musicSource`, `actOn`); la
  comunicación es JSON como texto de ida y vuelta. Los tipos de
  `src/engine/types.ts` están escritos a mano: los cuida la paridad (abajo).

## El flag por cuenta: `webV2` y `DND_V2_USERS`

La migración es **cuenta por cuenta**, no por porcentaje ni por rasgo: decide
quién la prueba primero, no el azar (`WebConfig.v2Users`).

- `DND_V2_USERS` (en `.env`: `V2_USERS`) es una lista de ids de cuenta separados
  por coma; tolera espacios y comas de más; vacía = nadie; `*` = todas las
  cuentas.
- `GET /` (el `index.html` de Flutter) responde **302 a `/v2/`** con
  `Cache-Control: no-store` si la sesión es válida y la cuenta tiene `webV2`
  (`rootHandler` en `app.dart`, con la misma resolución de sesión que `/api`).
  Sin sesión, sin flag, o con la cookie `milantus_v1=1`, se sirve Flutter. La
  cookie la escribe el interruptor «Usar la versión anterior» de Ajustes de
  `/v2`: es por navegador y solo la lee el servidor.
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

> **Desde 2026-11-04, las funciones nuevas van solo a `/v2`.** Flutter no recibe
> nada más: se depreca al terminar la migración y no vale gastar en dárselas.
> Tiene que seguir compilando y leyendo los datos. Lo que Flutter no conoce (por
> ejemplo un `kind` de aviso nuevo) lo marca visto en silencio, y se acepta.

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
- Tema: oscuro por defecto. El selector al pie del panel cambia el tema de
  este navegador (`localStorage`). En Ajustes se puede cambiar el tema de la
  cuenta (`themeMode`) y quitar la preferencia local para usar el de la cuenta.
- Idioma: español o inglés, resuelto una vez al cargar (clave `milantus.locale`
  de `localStorage`, luego `navigator.language`, luego español). Es el mismo
  criterio para los rótulos del motor.
- **El dashboard** en `/v2/personajes` (`src/dashboard/`) es la primera de las
  pantallas de lectura, y desde 5f también escribe: la lista de personajes con
  el orden (`sortMode`: manual, más recientes, nombre, nivel, clase) y el
  favorito de los ajustes de la cuenta (`/api/settings`), buscador en el
  cliente por nombre, especie y clase, y los caídos al final, como en Flutter.
  **5f *(existe)***: el selector de orden, reordenar (tomando la tarjeta entera
  o desde su menú, solo dentro del mismo grupo —favorito, vivos, caídos— y sin buscador activo, para
  no perder el lugar de las tarjetas ocultas), el favorito, renombrar, borrar,
  rehacer desde nivel 1 (`/v2/personajes/:id/rehacer`, el mismo creador con
  `replacing`) y «Probar con uno de ejemplo» en la cuenta vacía. Los ajustes
  se guardan con `patchSettings` (`src/api/settingsSave.ts`): el documento
  viaja entero, así que hay una cola de un solo guardado a la vez que combina
  los parches. Renombrar y borrar descartan lo pendiente de la ficha
  (`dropPending`). Ajustes es una pantalla de /v2; «Sugerencias y errores»
  abre un diálogo (`src/ui/feedback.tsx`, `POST /api/feedback`) y «Cerrar
  sesión» hace `POST /auth/logout` y navega al `logoutUrl` que devuelve, o a
  la raíz (`FLUTTER_HOME`, `src/router.tsx`) si vino `null`: ninguno pasa por
  Flutter. El Homebrew es del Modo DM y no está en este panel. Cada tarjeta enlaza a la ficha. Las cifras
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
  un diálogo (desde 5e8 se escriben en la ficha propia, abajo). Lo que se
  escribe son las acciones de partida, la mochila, las elecciones y el Diario
  (abajo): el resto de la ficha no se edita. El panel es el de una pantalla de
  adentro: «volver», la tarjeta del personaje, las cinco pestañas, **Subir
  nivel** (el asistente de `/v2`, abajo), **Retrato** (abajo), **Compartir**
  (`ShareDialog`, abajo) e **Imprimir**; al pie, el
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
  **En tu cuenta**: modo de inicio, tema y visibilidad de la dificultad del
  encuentro, guardados con `patchSettings`. `/v2/` abre el modo elegido.
  El orden y el favorito se muestran en Ajustes y se editan en la lista de
  personajes. El proveedor se elige en Retratos. **Tutoriales**: la fila
  «Tutoriales / Volver a verlos» de «En este navegador» borra lo visto. Los diez
  tutoriales (`src/ui/tutorials.tsx`) salen la primera vez que se entra a su
  pantalla: `welcome` en la lista de personajes, `sheet` en la ficha propia, y en
  el Modo DM uno por sección de la campaña y uno por Bestiario, Biblioteca de
  PNJ y Homebrew. Lo visto se guarda en `localStorage`, `milantus.tutorials`, con
  el formato de Flutter (nombres separados por coma, o `*`): lo visto en una
  versión vale para la otra. Pantalla encendida queda en Flutter.
- **Campañas** en `/v2/campanas` (`src/campaigns/`), **sin enlace en el menú
  de Jugador** (es del Modo DM; ver abajo): las mesas en las que juega la cuenta, de todos sus personajes en
  una lista (cada una con «Con <personaje>», que lleva a la pestaña Campaña de
  esa ficha). Es la **vista del jugador y nada más**: la misma consulta que la
  ficha (`GET /api/characters/:id/campaigns`), que el servidor ya poda con
  `Campaign.playerView()` y `EncounterLog.playerView()` —sin escenas de
  música, sin los capítulos pendientes ni el objetivo de los cerrados, sin las
  notas privadas del DM ni los PNJ—, y el bloque de cada mesa es el mismo
  componente que la pestaña (`CampaignBlock`). Lo que sí trae del DM: la tarjeta
  **Capítulo en curso** (nombre, objetivo y las notas «DM y Jugadores» de ese
  capítulo) y, bajo cada capítulo cerrado, «N notas de la mesa» plegado. **No hay Cuaderno, notas ni lista de miembros** porque en
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
  característica es `abilityModifier`. El del jugador es de solo lectura; el del
  DM suma al combate (6g7c) y, desde 7d1, las acciones del homebrew (abajo).
- **Campañas y Bestiario del jugador no están en el menú de Jugador**: se entra
  escribiendo la URL. Pertenecen al Modo DM, que ahora existe en parte (abajo): el
  panel DM enlaza el Bestiario.
- **El Modo DM** en `/v2/dm` (`src/dm/`), al que lleva «DM» del
  interruptor. Desde 6b escribe campañas y la Mesa y desde 6c capítulos,
  notas y el reparto de objetos y desde 6d las escenas de música (bloques de
  6b, 6c y 6d, abajo); el combate se **arma** acá desde 6g2 y se **empieza** desde 6g3; se **juega** desde 6g4, se le anotan efectos y defensas desde 6g5 y se **termina** desde 6g6
  (desde 6e1 los vínculos de un PNJ con sus campañas ya se escriben, desde 6e2
  se crea y se borra un PNJ sin ficha de personaje, desde 6f1 se crea uno con ficha, desde 6f2 se escribe su ficha, desde 6f3 se sube de nivel y se editan sus elecciones y desde 6e3 se escribe su texto
  desde 6e4 su bloque y desde 6e5 su retrato),
  y esas secciones se leen salvo eso. Se porta por
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
  (`MusicPlayer`, el `dm/music/` de Flutter): una pill
  «Música» flotante abajo a la derecha que se despliega con las escenas de la
  campaña (las del documento de `GET /api/campaigns`, que el servidor poda de la
  vista del jugador) y el reproductor de YouTube embebido, con pausar, reanudar,
  minimizar (que pausa: YouTube exige el reproductor a la vista) y «Abrir en
  YouTube» si el dueño no deja verlo afuera. El enlace lo interpreta el motor
  (`musicSource`, sobre `MusicSource.parse`): la pantalla nunca arma la dirección
  del iframe con lo que pegó el DM, y una escena que no es de YouTube se lista
  sin reproducirse. Vive en `DmPage` y no en una sección: cambiar de sección o
  abrir una herramienta de la cuenta no la corta; cambiar de campaña, sí. Crear,
  editar, mover y borrar escenas y marcar «ofrecer al iniciar un combate» son
  escrituras de 6d (bloque abajo). Desde 6g7a, al confirmar el primer guardado de
  «Armar combate», el reproductor ofrece las escenas marcadas y reproducibles.
  Si una de ellas ya está seleccionada, se omite la oferta. Elegir una escena
  la pone y «Ahora no» deja la música como estaba. La **Mesa** lista a los jugadores
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
  motor con `chapterGrants`). Crear, editar, empezar, cerrar y borrar capítulos es
  de 6c (abajo). La cabecera de la Mesa dice el capítulo en marcha. **Cuaderno**
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
  homebrew de **la cuenta** (el de otra no llega). Desde 6g7c, el perfil suma al
  combate de la última campaña abierta o, si todavía no se eligió una, de la
  campaña que abriría el Modo DM. El diálogo pide cantidad, PG y bando. El
  motor resuelve los PG, la numeración y la iniciativa, y el DM sigue en el
  perfil. «Editar una copia» sigue en Flutter.
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
  Diario porque en un PNJ son su trasfondo y sus notas, y escribible desde 6f2
  (PG, usos, descansos, inventario) y 6f3 (subir de nivel y demás pantallas de
  edición; ver abajo). Sale del mismo `GET /api/npcs/:id`. Un PNJ ajeno y uno
  inexistente dan la misma pantalla «No se encontró el PNJ» —también en su
  ficha, igual que un PNJ sin ficha—: el servidor los responde igual (404). Exportar e
  importar, desde 7c (menú «⋯» de la ficha y botón de la Biblioteca; el ZIP lo arma y lo lee
  el servidor; el estado por campaña se escribe desde 6e1; crear
  sin ficha y borrar, desde 6e2; crear con ficha de personaje, desde 6f1; nombre, voz, tags, trasfondo y notas, desde 6e3; el bloque, desde 6e4; el retrato, desde 6e5).
  **PNJ de la mesa** (`GET /api/campaigns/:id/npcs`): los PNJ vinculados a la
  campaña con su estado **en esa** campaña. Arriba, el conteo («2 PNJ · 1 vivo ·
  0 muertos · 1 desconocido») y las pills de tag; cada tarjeta lleva la
  identidad (que abre la ficha de la Biblioteca), la línea de tipo con los PG
  con que volvió del último combate de esa mesa («Bandido · CA 12 · PG 7/11»),
  sus tags y el estado en un selector; un muerto va tachado y atenuado. Los PG del herido los resuelve el motor (`npcViews` con `currentHp`
  y `status` de cada entrada), igual que en la Biblioteca. Cambiar el estado,
  traer de la biblioteca y quitar de la campaña se escriben desde 6e1; crear un
  PNJ nuevo (queda en la mesa) desde 6e2.
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
  vacía. Desde 7d1 se **importa y se exporta** todo (portada), se **borra** cualquier
  entrada propia y se **crean, editan y duplican criaturas** y, desde 7d2a y 7d2b,
  **dotes, especies, trasfondos** y, desde 7d3a y 7d3b, **armas, armaduras y
  objetos** y, desde 7d4, **conjuros**: las ocho categorías se editan desde `/v2`.
  **Combate** (`GET /api/campaigns/:id/encounter`, más los miembros, los PNJ de
  la mesa y el Cuaderno): el combate abierto, de solo lectura. Arriba, una placa
  con la ronda, «Turno N de M» y cuántos quedan en pie por bando (o «Armando el
  combate» mientras nadie tiró iniciativa); debajo, la planilla de Flutter
  —iniciativa con TURNO / ACTUÓ / SALTA, nombre con el bando y su línea, PG con
  barra y MALTRECHO, CA y efectos— y a su lado «Del turno», con el perfil del
  Bestiario del monstruo que juega, el perfil del PNJ (bloque, voz y trasfondo) o, si le
  toca a un jugador, que su ficha la lleva quien lo juega. Al pie, los combates
  cerrados redactados como en el Cuaderno. **Mientras se arma (6g2)** el DM
  puede escribir: «Armar combate» abre el encuentro, «Sumar al combate»
  (`dm/combat/AddCombatantDialog`) suma monstruos del Bestiario (de a varios,
  con los PG tirados o promedio) y PNJ de la campaña o de la biblioteca (con
  «Volvió» para uno muerto), la pill de bando de cada fila cambia el bando
  (`SideMenu`), la X saca sin confirmar, los jugadores que faltan se suman de a
  uno o todos juntos y «Descartar combate» lo borra. Cada acción la resuelve el
  motor (`encounterAct`) y se guarda entero por una cola (`encounterWriter.ts`,
  sobre `saveQueue.ts`); vincular un PNJ de la biblioteca a la campaña es un
  pedido aparte, antes de sumarlo. **Mientras se arma (6g3)** también se ve la
  **dificultad** (`DifficultyBand`, entre la placa y la planilla) y los **PX** de
  cada fila, si la preferencia de la cuenta lo permite (`showEncounterDifficulty`,
  prendida por defecto, se cambia en Ajustes), y
  «Tirar iniciativa» (`RollInitiativeDialog`, con las tiradas que propone el
  motor y sin dejar casilleros en blanco) lo **empieza** desde `/v2`. **6g4, ya en
  curso**: el DM pasa el turno («Siguiente turno»), daña y cura con la cifra
  compartida de la planilla (−n y +n en cada fila con PG; el valor se lee al
  tocar), corrige la iniciativa de cualquiera (`NumberPromptDialog`), suma tarde
  a los jugadores que faltan (con lo que tiraron) y PNJ nuevos (con su
  iniciativa), cambia el bando desde la fila o desde «Del turno» y saca. La
  planilla es una sola grilla y la fila se parte por el ancho de la planilla
  (`@container`). **La Mesa y el Combate releen los PG de los jugadores cada 5 s
  con un combate abierto** (`useCampaignMembers` con `live`; el encuentro en sí
  no se sondea porque lo escribe solo el DM). **6g5, efectos y defensas**: un botón
  de etiqueta por fila abre `EffectsDialog` (ventaja o desventaja, PG temporales,
  bono a la CA, efectos escritos y condiciones del libro; Guardar manda solo lo
  que cambió). **Ventaja o desventaja, temporales y bono a la CA son notas del DM
  que solo existen en /v2** y nunca le llegan al jugador; los temporales de un
  jugador se leen de su ficha y no se escriben. Las marcas se ven en la fila
  (pill de ventaja, `+N` dorado con la barra de PG, CA con escudo y `base +bono`),
  en «Del turno» y en el teléfono; las **legendarias** de un monstruo son
  círculos (acciones) y rombos (resistencias) que se tachan tocándolos, y la
  solapa **Efectos** junta los de toda la mesa. En Flutter, congelado, los −/+ no
  gastan temporales y no se ven las marcas. **6g6, terminar el combate**: si un
  bando se queda sin nadie en pie, un aviso ofrece abrir el mismo diálogo que
  «Terminar combate» en la placa. El DM puede guardar el combate en el Cuaderno
  o descartarlo. Al guardar se envían primero los cambios pendientes y el
  servidor marca muertos solo a los PNJ caídos que el DM eligió y conserva los
  PG de los demás para el próximo combate de esa campaña. **6g7b** suma
  «Convertir en PNJ…» al menú de bando de un monstruo con perfil. Guarda lo
  pendiente y luego crea, vincula y reemplaza la fila en una transacción. La
  conversión conserva el turno y el estado del combatiente. **Los PG salen de dos fuentes**,
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
  borrar un retrato se hace en la pantalla de retratos de la ficha propia
  (desde 5e9, abajo).
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
  Desde 5e1: en la tarjeta **Condiciones** los 13 estados son chips que se
  marcan (con su regla en el tooltip) y el **Cansancio** es un contador de 0 a
  6 con su regla en un diálogo; al 6 avisa que el personaje muere y no toca los
  PG; el nivel 5 avisa que otro nivel mata al personaje. Los **modos activos** (la Furia) son una franja a todo el ancho de la
  banda táctica, toda ella un botón —usos que quedan, «Activar» o «En curso ·
  Terminar», o el motivo del bloqueo— con un diálogo
  de variantes (casillas si admite varias); con el modo en curso la misma franja dice qué suma. Las reglas (marcar un estado que
  incapacita termina la concentración y los modos, el tope del cansancio, gastar
  el uso al activar) son `CombatOps`, por las acciones `setCondition`,
  `setExhaustion`, `activateMode` y `deactivateMode`; una activación rechazada
  devuelve la ficha intacta. `compute` aplica `applyExhaustion` sobre la ficha
  calculada, como Flutter: antes `/v2` mostraba descansado a quien no lo está.
  La tarjeta **Conjuros** ya no apila filas de espacios y listas: los espacios
  son una grilla (`SpellSlotGrid`) que elige un nivel, una fila dice lo que
  queda de él y, en la ficha propia, lo gasta o recupera; debajo, pestañas
  (Trucos, Siempre preparados, Conjuros o Conocidos, De rasgos) donde las dos
  del medio se filtran por ese nivel (el pacto, hasta él). Con una sola clase
  el botón de editar pasa a la cabecera. Un mago de nivel 20 llenaba la
  pantalla con la lista entera. **La ficha de `/v2` se aleja a propósito de la
  de Flutter en este punto**; no hay regla nueva, solo otra vista de lo mismo.
  Desde 5e2: en la tarjeta **Conjuros** de Combate, un botón por bloque de
  lanzamiento («Preparar conjuros» si la clase prepara, «Editar conjuros» si
  conoce) lleva a `/personajes/:id/conjuros/:clase`, el editor
  (`sheet/SpellEditor.tsx`): pestañas Trucos y conjuros, bandeja de chips,
  buscador, lista por nivel y el detalle a la derecha (en un teléfono, un
  diálogo). Con el cupo lleno una opción se atenúa pero responde y el pie dice
  por qué. Guardar es **una** acción `setClassSpells` (sin validar el tope, a
  propósito: una ficha pasada de cupo tiene que poder guardarse mientras se
  saca de a uno) y avisa con «Deshacer». La ruta se monta en `CharacterPage`
  como la subida, para que el aviso siga al volver. Qué se ofrece y los topes
  salen de `spellEdit` (`LevelUp.classSpells`); la tarjeta usa siempre el
  `classId` del bloque, no el de la ficha. El **truco innato** reemplazable
  (Alto Elfo) tiene «Cambiar truco» en el detalle de su fila: un diálogo con
  las opciones de `innateCantripOptions`, que se confirma con «Cambiar»
  (elegir no guarda) por la acción `setInnateCantrip`, que además comprueba
  que la opción sea válida. Ninguna de las dos acciones toca el combate. No se
  valida *cuándo* se puede preparar (descanso, grimorio): como Flutter.
  Desde 5e3, en **Inventario**: un botón por cupo de arma de un rasgo
  (`targetChoiceSlots`, el arma de pacto de Pacto del Filo) abre
  `sheet/EffectTargetDialog.tsx`, que vincula un ejemplar de la mochila o crea
  el arma con «Vincular» (elegir no guarda) por las acciones
  `setEffectTarget` y `createEffectTarget`; «Limpiar vínculo» es
  `clearEffectTargets`. Las tres dejan la ficha intacta si el cupo no existe,
  si la opción no es elegible o si el cupo está lleno y no es reemplazable. Lo
  que el rasgo creó sale de la mochila al cambiarlo (`createdByFeature`).
  Los **planos y réplicas del Artífice** (5e3) tienen su ruta,
  `/personajes/:id/planos` (`sheet/MagicItemPlans.tsx`), con el botón
  «Planos y réplicas (n/m)» de Inventario: pestañas Planos y Réplicas
  activas, bandeja de chips, lista por rareza y el detalle a la derecha (en un
  teléfono, un diálogo). **Se guarda al tocar, sin botón «Guardar»**: elegir un
  plano es `setMagicItemPlan`, crear una réplica es `replicateItem` (con la
  base, si la plantilla la pide, que sale de `magicBaseOptions`) y quitarla es
  `removeItem`. Sacar un plano se lleva su réplica, y eso (`removedReplica`) y
  quitar una réplica avisan con «Deshacer». Una réplica es un objeto real de la
  mochila: lleva la etiqueta «Réplica» y su menú tiene «Transmutar réplica…»
  (`sheet/TransmuteDialog.tsx`, acción `transmuteReplica`) si hay otro plano
  elegido. Las tres acciones dejan la ficha intacta si no hay cupo de planos o
  el motor rechaza la opción. Qué se ofrece y los topes salen de
  `magicItemPlans` (`sheet.itemChoiceSlots`); en Flutter, el cuadro llama a las
  mismas `InventoryOps.setMagicItemPlan` y `magicBaseOptions`.
  Desde 5e4, la **Forma Salvaje** se juega en la ficha propia. `compute`
  aplica la forma (`withWildShape`, antes del Cansancio) a quien tiene
  `combat.wildShapeCreatureId` en el catálogo, así que Combate muestra la CA, la
  velocidad, FUE/DES/CON y los ataques de la bestia, con sus rasgos debajo de
  Ataques y el aviso «no podés lanzar conjuros» en Conjuros (salvo que
  `canCast`). El tablero, la subida de nivel y la impresión miran al personaje
  y no a la bestia (`withoutForm`). La franja `WildShapeTile`, en la banda
  táctica, abre `WildShapeDialog` (elegir forma y «Transformarse», acción
  `enterWildShape`, con «Deshacer») y, transformado, vuelve con
  `leaveWildShape`. Las formas se anotan en `/personajes/:id/formas`
  (`sheet/WildShapeForms.tsx`), que guarda al tocar con `setWildShapeForm`; una
  forma que dejó de calificar queda guardada y se puede sacar. Transformarse
  **incapacitado se permite**, como en Flutter: el motor corta la forma al
  quedar incapacitado, no impide entrar. La ficha de un miembro transformado se
  ve en su forma, sin controles. El **combate del DM no muestra la forma** hasta
  el paso 6.
  Desde 5e6, la ficha **muestra lo que antes solo mostraba Flutter**, sin
  escribir nada. Del motor llegan las ventajas ya filtradas por tirada
  (`saveAdvantages`, `skillAdvantages`, `initiativeAdvantages`,
  `conditionalAdvantages`), `Attack.damageText` (que resuelve el «o» de un daño
  extra de dos tipos), la descripción de cada línea del inventario,
  `canLevelUp` y el rótulo `abilityRule`. En Combate, cada ataque lleva su
  maestría (se toca y abre su regla; un tooltip no existe en el teléfono), el
  bono de un estado activo, el crítico, la mano secundaria y la acción
  adicional; el Ataque Furtivo y similares van como filas de dados; las
  Salvaciones y Habilidades marcan «Ventaja» con su fuente; los recursos y los
  objetos con texto son un nombre-botón que lo abre; los conjuros dicen su
  bono al daño y con qué aptitud se lanzan. En Personaje, la tarjeta
  «Competencias e idiomas» y los sentidos al pie de Habilidades. Tocar una
  característica o la Iniciativa abre su desglose (`BreakdownDialog`), que
  lista lo que ya trae la ficha; la Velocidad suma sus otros modos y el
  Cansancio. En el nivel máximo, «Subir nivel» se apaga y la ruta del asistente
  vuelve a la ficha. Todo esto se ve también en la ficha de un miembro.
  Desde 5e5, los **compañeros** se invocan y se manejan en la ficha propia.
  La tarjeta `CompanionsCard` (`sheet/Companions.tsx`), bajo Defensa en Combate,
  lista los que están en juego, plegados de entrada: PG, CA, estados, daño,
  curación, PG temporales y «Despedir» (acciones `damageCompanion`,
  `healCompanion`, `companionTempHp`, `setCompanionCondition` y
  `dismissCompanion`), y su perfil. «Invocar» abre `SummonDialog`: opción,
  forma y con qué se paga, un espacio (también de pacto) o el uso gratis del
  conjuro (Corcel Fiel); acción `summonCompanion`, con «Deshacer». Qué se
  ofrece, a quién reemplaza y qué concentración corta lo lee el cliente de
  `companionsView` y `companionPreview` (`companion_view.dart`); el pago, los
  PG y la concentración los resuelve `SheetActions`. Un compañero cuyo conjuro
  ya no está preparado queda como huérfano y solo se puede despedir. Sin
  escritura (ficha de un miembro) no hay ningún control. Con 5e5 se arregló
  también al brujo puro: su tabla de pacto ya no se repite como espacios
  normales (`normalSpellSlotsByLevel` queda vacío) y la tarjeta Conjuros le
  muestra solo la celda de pacto. **Siguen en Flutter:** invocar en forma de
  bestia y el Defensor de Acero. El **Compañero Salvaje** cobra desde /v2: el
  rasgo declara `payWith` (la Forma Salvaje como alternativa a un espacio de
  nivel 1 o más, que el diálogo ofrece como el uso gratis) y `untilLongRest`,
  y el descanso largo lo despide (`companionsGone`). Flutter sigue
  invocándolo gratis y sin despedirlo al descansar, por estar congelado.
  Desde 5e8, la ficha propia **escribe el Diario** (`DiaryTab`). El trasfondo
  tiene editor (el borrador es local y `setBackground` se manda espaciado a
  400 ms, y al terminar, al salir del campo y al desmontar: cada acción
  recompila la ficha), e importar y exportar un `.md`. Las entradas se crean,
  editan, borran y reordenan con `saveDiaryEntry`, `removeDiaryEntry` y
  `moveDiaryEntry`; la fecha la pone el cliente (`at`). Las imágenes suben al
  almacén de retratos (`src/api/portraits.ts`, bajo el id del personaje) y un
  rechazo 400 o 413 dice las dos causas posibles, porque el servidor no
  distingue. Reordenar es `useReorder` (`src/ui/reorder.ts`): arrastre desde el
  ícono de mover o flechas del teclado, sin quitarle el desplazamiento a la
  pantalla táctil. `DiaryEntries` recibe `edit` desde `DiaryTab`; sin él (ficha
  ajena, notas del PNJ) no tiene ni un control, y las notas del PNJ se
  escriben recién en el paso 6.
  Desde 5e9, la ficha propia **maneja sus retratos** en `/personajes/:id/retrato`
  (`PortraitPage`, el `PortraitScreen` de Flutter; solo ficha propia, con el
  patrón de ruta de `WildShapeForms`). Subir un archivo, volver a un retrato
  guardado, ver el prompt con que se generó y borrarlo; y generar con el
  proveedor que el servidor tenga configurado (`GET /api/portraits/providers`,
  `POST /api/portraits/generate`), con estilo, detalles y, si el motor la
  acepta, una imagen de referencia. Las reglas son del motor: el orden y el
  borrado de los retratos son las acciones `addPortrait`, `restorePortrait` y
  `removePortrait`, y el prompt lo arma `portraitPrompt` (`portrait_prompt.dart`,
  movido de la app al engine); TypeScript solo pasa los textos. Cada acción
  **deja la pantalla abierta** y avisa (Flutter cerraba sola). Borrar saca
  primero el archivo del servidor y después la clave de la ficha. Elegir motor
  es el primer guardado de ajustes de `/v2` (`setImageProvider`: relee el
  documento y lo guarda entero con `imageProvider` cambiado, para no pisar
  favorito, orden ni tema); el resto de los ajustes llega en el paso 7. El
  taller de retratos del PNJ va en el paso 6: `buildNpcPortraitPrompt` ya está en
  el motor, falta solo la pantalla.
  Desde 5e7, la ficha propia **dice lo que el motor avisa y deja resolverlo**.
  `choicesView` (`character_choices.dart`) entrega las advertencias del
  validador y los cupos de rasgos, competencias, conjuros, idiomas y origen con
  sus opciones ya resueltas (requisito sin cumplir, bloqueos, pendientes); las
  acciones `setFeatureChoice`, `setProficiencyChoice`, `setSpellChoice`,
  `setLanguage`, `setSize`, `setLineage`, `setSpeciesAbility`,
  `setFeatAbility` y `setUnarmoredDefense` las escriben con las mismas
  condiciones que los editores de Flutter (sacar vale siempre). En Personaje,
  `WarningsStrip` (`sheet/Choices.tsx`) es una franja de la banda (solo en Personaje) y «Revisar» abre
  `WarningsDialog`, con «Resolver» hacia la pantalla de elecciones
  (`/personajes/:id/elecciones?tab=`, `ChoicesPage`), el editor de conjuros o
  Inventario; el mapa `code` → destino vive en la pantalla, como `_resolverFor`
  de Flutter. «Cambiar elecciones», en Identidad, abre la misma pantalla para
  revisar lo ya elegido; Defensa elige la fórmula sin armadura (Monje +
  Bárbaro). **Sin botón, como en Flutter:** los avisos de subclase, mejora de
  nivel y habilidades de clase.
  La banda táctica (PG, Iniciativa,
  Velocidad, Competencia; sin Armadura, que se lee en Defensa) solo va en
  Personaje y Combate, como en Flutter; el modo en curso lo dice su propia franja (con lo que suma), sin cartel aparte. Sin escritura, la ficha ajena
  sigue mostrando solo los estados puestos y el modo en curso.
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
  abierto) y «Comprar», apagado con «te faltan…» si la bolsa no alcanza. Una
  plantilla (`baseItemKind`) pide antes su objeto base, porque sin él se equipa
  pero no ataca; el motor rechaza agregarla o comprarla sin base, y la línea que
  ya estaba sin ella dice «Sin objeto base» y ofrece «Elegir objeto base…»
  (`setItemBase`).
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
  rechaza confirmar una subida a medias. Las piezas del circuito viven en
  `src/ui/wizard.tsx`, compartidas con el creador.
  **Creador de personajes** (5d). El diseño aprobado está en el
  lienzo «Creador de personajes»: las mismas piezas que la subida, nueve pasos
  (Especie, Clase, Trasfondo, Características, Competencias, Conjuros,
  Equipo, Detalles, Revisión), la clase en una fila y las características en
  una matriz. Desde 5d1 el borrador vive en el motor
  (`dnd_engine/lib/src/engine/character_creation.dart`, `CreationDraft`) y
  Flutter lo usa de ahí: lo que falta es un dato (`CreationPending`, por
  `CreationSection`) que cada cliente pone en texto, y lo que una elección
  arrastra (otra especie suelta el linaje, otra clase sus maestrías) está en
  sus métodos y no en el widget. Flutter conserva sus ocho pasos, que agrupan
  esas secciones. El puente es `creation(catálogo, borrador, acción)`: aplica
  la acción (`CreationDraft.apply`) con todas las podas y devuelve
  `viewJson` (borrador, pendientes, el personaje para «Así queda» y lo que
  deciden las reglas de cada paso). Los nueve pasos están en
  `/v2/personajes/nuevo` (`src/creation/`), y «Crear personaje» del tablero lleva
  ahí en las cuentas con `/v2`. El detalle sale de `codexEntries`, como en la
  subida, y «Así queda» compila el personaje que devuelve el motor. El alta es
  `creationConfirm` del motor, que rechaza un borrador incompleto, y
  `POST /api/characters`, cuya respuesta trae el id con que quedó guardado (el
  servidor lo reasigna si choca). Rehacer (5f) usa `creationConfirm` con el
  personaje que se rehace y `PUT` con `rebuilt: true`, que avisa a los DM; crear
  la ficha de un PNJ es de 6f1.
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
  - **Conflictos: el servidor rechaza una copia vieja.** La versión es
    `updated_at` de la ficha en microsegundos (`version` en la lista y en la
    respuesta del PUT, `expectedVersion` en el cuerpo). Si no coincide, el
    servidor responde 409 `character_stale` y no escribe; `characterSave.ts`
    descarta lo pendiente de esa ficha y `CharacterPage` vuelve a pedirla y
    avisa con un toast, sin diálogo ni «guardar la mía igual». Flutter no manda
    versión y sigue con «gana el último»: una pestaña de Flutter puede pisar a
    React, no al revés. Por eso la ficha también se vuelve a pedir al volver a
    la pestaña de `/v2`, **solo si no hay nada pendiente**, y una acción
    cancela el pedido de la lista que esté en vuelo.
  - **Qué se ve**: al pie del panel, en vez de «Solo lectura», la pill del
    guardado (`SaveStatusBadge`: Guardando… / Guardado / No se guardó con
    «Reintentar»). Si falla, lo local se conserva; cerrar o recargar con algo
    pendiente lo pregunta el navegador (`beforeunload`). Los avisos van en
    `Toast`.
- **Ningún enlace** desde Flutter hacia `/v2` y Flutter no lee `webV2`: se
  entra escribiendo la URL.

**Paso 6c: capítulos, notas, reparto de objetos y avisos** *(existe)*. Toca motor,
servidor (una tabla nueva) y un poco de Flutter. La frontera no cambia: **el DM
no escribe la ficha de otra cuenta**; el objeto repartido lo agrega el jugador
al aceptar.
- **Capítulos** (`ChapterEditorDialog`, `CloseChapterDialog`, `ItemPicker`):
  crear, editar (salvo cerrados), empezar —con otro en marcha avisa sin llamar
  al servidor— y borrar. Un `PUT` nunca cierra: cerrar tiene su ruta. El editor
  lista los objetos (`grantsCatalog`, esquema 2 de `Chapter`) con cantidad, y el
  texto libre de antes aparece como «Sin catálogo».
- **Cerrar con reparto**: una fila por objeto con un chip por personaje; nada se
  asigna solo y con un objeto sin nadie no se puede cerrar. Manda `allocations`;
  sin objetos, o con la mesa vacía, cierra sin cuerpo.
- **Cuaderno**: escribir, editar y borrar notas (solo las `note` tienen menú);
  `?capitulo=` abre en un capítulo y guardar salta al de la nota.
- **El jugador**: «El DM te dio» en Inventario (`ItemGrants`, solo ficha propia).
  Aceptar reclama, espera al catálogo si es homebrew, agrega por el motor y
  recién ahí saca la fila. Los avisos llegan también con la pantalla abierta
  (cada 30 s con la página visible) y al terminar un combate.
- **Servidor**: `item_grants` (migración 0015), las rutas de la bandeja y
  `encounter_finished`: ver `modo-dm.md`.

**Paso 6b: campañas y Mesa** *(existe)*. Es la parte del DM que escribe
primero, y no toca motor, servidor ni Flutter: las rutas ya existían. La
frontera sigue donde estaba: **el DM no escribe la ficha de otra cuenta**.
- **Campañas** (`CampaignEditorDialog`, `CampaignMenu`, `DmOnboarding`): crear
  desde «Nueva campaña» del panel o desde la bienvenida de quien no tiene
  ninguna; editar y borrar desde el menú de la cabecera de Mesa, Capítulos y
  Cuaderno (a propósito no en PNJ ni Combate, para que no quede a mano de lo que
  se toca jugando). Crear navega al id que **devuelve** el servidor. Editar
  **relee la campaña antes del PUT**: las escenas de música viven en ese
  documento y el PUT lo reemplaza entero. Borrar sale de la campaña antes de
  releer la lista, para no mostrar «No se encontró la campaña».
- **La Mesa** (`AddMemberDialog`, `MemberCard` con `actions`): sumar canjea el
  código del jugador; conceder Inspiración Heroica es un **aviso** del servidor
  (no escribe la ficha) y echar corta el vínculo tras confirmar. `MemberSheetView`
  sigue sin un solo control. No se pide el aviso de eventos tras cada acción
  (`_checkEventsSoon` de Flutter): decisión tomada, no un olvido.

**Paso 6f3: las pantallas de edición** *(existe)*. Toca solo `dnd_web`. Subir de
nivel, elecciones, editor de conjuros, planos del Artífice y formas salvajes son
las pantallas de la ficha propia, que dejan de asumir su URL: el `SheetWriter`
lleva `routes: SheetRoutes` (`ownSheetRoutes(id)` o `npcSheetRoutes(npcId)`) y
cada pantalla toma de ahí sus enlaces y sus «volver». Las del PNJ viven bajo
`/v2/dm/pnj/:id/ficha/` (`subir-nivel`, `conjuros/:clase`, `planos`, `elecciones`,
`formas`) y `NpcSheetView` las muestra con la prop `screen`, sin remontarse al
pasar de una a otra (su `key` es solo el id del PNJ), así que el guardado «al
salir» no se dispara entre pantallas. En la barra de la ficha, a la derecha del
estado de guardado, van «Subir nivel» (apagado en el nivel máximo) e «Imprimir
ficha». Sin renombrar ni regalos, que siguen siendo de `own`. Subir de nivel no
avisa a nadie: el servidor no ve esa ficha como un personaje. Sin rehacer ni
retrato desde ahí, como en Flutter.

**Paso 6f2: escribir la ficha de un PNJ** *(existe)*. Toca solo `dnd_web`. La
ficha completa de un PNJ (`NpcSheetView`) deja de ser de solo lectura: PG,
usos, descansos, inventario y demás pasan por el motor y se guardan por la
cola de la ficha propia (`characterSave.ts`, `PUT /api/characters/:id`), con
`useNpcSheetWriter`, que comparte con `useSheetWriter` el `buildWriter`. El
`SheetWriter` lleva `kind` (`own` o `npc`): lo que conecta con otra cuenta o
lleva a una pantalla de la ficha propia solo aparece con `own`. Arriba, una
barra con «volver» y el estado de guardado (`SaveStatusBadge`); al salir se
guarda primero y recién después se relee la biblioteca y las campañas. Borrar y
renombrar el PNJ descartan antes lo pendiente de su ficha (`dropPending`): el
`upsert` del servidor inserta sin `kind` y un guardado tardío la recrearía fuera
del PNJ. Sin renombrar desde la ficha (se hace en la pantalla del PNJ), sin
compartir ni regalos. Las pantallas de edición (conjuros, planos, elecciones,
formas y subir de nivel) son de 6f3.

**Paso 6f1: crear un PNJ con ficha** *(existe)*. Toca solo `dnd_web`: el motor, el
servidor y Flutter no cambian (`POST /api/npcs` ya aceptaba `{ npc, character }` y
los creaba en una transacción). La tercera opción de «Nuevo PNJ» deja de estar
apagada: no crea nada, sigue a `/v2/dm/pnj/nuevo?nombre=…&campana=…` (los datos
van en la URL para que recargar no los pierda), que es el creador de personajes
en modo PNJ —`CreationPage` con `npc`—: sale a la Biblioteca o a los PNJ de la
campaña, el pie es el del Modo DM y el botón final dice «Crear PNJ». El PNJ se crea
al final, con el nombre de la ficha (el DM pudo retocarlo en Detalles), y abre su
ficha. **Reintentar no duplica**: crear y vincular son dos pedidos, y si falla el
segundo el id queda guardado y el reintento solo vincula. La ficha **no entra en
la lista de personajes**: no se invalida `roster`. Escribir esa ficha es 6f2 y sus
pantallas de edición, 6f3.

**Paso 6e5: retrato y mostrar a la mesa** *(existe)*. Toca el motor y `dnd_web`;
Flutter, el servidor y la versión no cambian. En `/v2/dm/pnj/:id/retrato` el DM
genera, sube, restaura y borra los retratos de un PNJ con el mismo taller de la
ficha propia: `PortraitWorkshop` recibe un dueño (`PortraitOwner`) y no sabe de
fichas ni de PNJ. Un PNJ sin ficha (`none` y `block`) guarda retratos y prompts
en su documento (`addPortrait`, `restorePortrait`, `removePortrait` de
`NpcEdits`, con la lógica de `SheetActions`) y arma el prompt con
`npcPortraitPrompt`, que nunca lee trasfondo, notas ni voz; uno con ficha usa
`portraitPrompt` y escribe en su ficha (`actOn` y `saveCharacter`, el camino del
renombrado), con la ruta de retratos de la ficha porque la del PNJ le da 404.
**A diferencia de Flutter**, la «Apariencia» de un PNJ sin ficha se guarda al
salir del campo (`setAppearance`) y no solo al guardar un retrato; el medallón sigue
abriendo el visor y la cámara, junto a él, el taller. **Mostrar a la mesa**
(`NpcTableView`) es una capa sobre la pantalla, sin ruta ni estado guardado:
retrato y nombre a pantalla completa, con el nombre ocultable; la app no le
manda nada al jugador, es el DM quien gira la pantalla. Sin API de pantalla
completa del navegador.

**Paso 6e4: el editor del bloque** *(existe)*. Toca el motor y `dnd_web`;
Flutter, el servidor y la versión no cambian. En `/v2/dm/pnj/:id/bloque` el DM
edita el bloque de estadísticas de un PNJ de bloque: «Lo básico», Rasgos y
Acciones, con la vista previa (el mismo `CreatureProfile` del Bestiario) a la
derecha y, debajo de `lg`, en un diálogo con «Ver». El formulario lo arma
`CreatureDraft` (`formOf`, `build` y `errors`, por el puente `creatureForm`,
`creatureDraft` y `creatureFormOptions`): la UI no calcula nada, ni la línea de
tipo ni los rangos. Guardar es explícito y reemplaza el bloque entero con
`setBlock` (`NpcEdits`); los errores aparecen desde el primer intento de
guardar y salir con cambios pregunta. **A diferencia de Flutter**, conserva la
lista de conjuros de una acción, las salvaciones, las habilidades y la línea
del libro («(mago), neutral», los enjambres) cuando no se toca tipo ni tamaño:
el formulario de Flutter las pierde al guardar. Las invocaciones con fórmula
(CA «13+WIS») salen marcadas para que el DM escriba números, como en Flutter.

**Paso 6e3: el texto de la ficha** *(existe)*. Toca el motor y `dnd_web`; Flutter,
el servidor y la versión no cambian. En la ficha de un PNJ el DM escribe nombre,
voz, tags, trasfondo y notas. Toda edición la aplica el motor (`NpcEdits`, por
el puente `npcEdit`): tags normalizados, textos recortados y las reglas de las
notas, que son las del Diario y se extrajeron de `sheet_actions.dart` a
`DiaryOps` sin cambiarles la lógica (los tests de la ficha propia pasan sin
tocarse). El guardado (`npcSave.ts`, una instancia de `createSaveQueue` en
`saveQueue.ts`, la misma que usa el combate) tiene la forma del de la ficha
propia: se ve al instante en la caché, 400 ms de espera, una cola por PNJ y
siempre la última copia entera. **Un fallo no pierde lo escrito**: sale un aviso con
«Reintentar» y la copia sigue pendiente (Flutter relee y la pierde; un
trasfondo largo es lo que más duele perder). **Renombrar escribe dos
documentos**, el PNJ y su ficha si la tiene, y el diálogo no se cierra si uno
falla; reintentar repite los dos. `BackgroundEditor` y `DiaryEntries` son los
del Diario, con otro dueño; sin trasfondo dice «Origen desconocido». Borrar una
nota con imagen no ofrece «Deshacer»: el archivo se va.

**Paso 6e2: alta y borrado** *(existe)*. Toca el motor (`Npc.draft`, que Flutter
usa de ahí en vez de armar el documento en `npc_shared.dart`) y `dnd_web`; las
rutas ya existían (`POST /api/npcs`, `DELETE /api/npcs/:id`). «Nuevo PNJ»
(`NewNpcDialog`) está en la Biblioteca y en los PNJ de la mesa —desde ahí además
lo vincula—: sin estadísticas o con bloque, vacío o copiado de una criatura. El
documento lo arma `newNpc` del motor y el bloque es una copia, nunca una
referencia. Crear abre la ficha. **Reintentar no duplica**: crear y vincular son
dos pedidos, y si falla el segundo el id queda guardado y el reintento solo
vincula. Crear uno con ficha de personaje es de 6f1 (abajo). «Borrar PNJ» está en el ⋮ de la cabecera de la
ficha, con confirmación, y **no avisa después**: se vuelve a la Biblioteca y el
PNJ ya no está, que es la confirmación (un aviso local moriría con la pantalla).

**Paso 6e1: los vínculos** *(existe)*. No toca motor, servidor ni Flutter: las
rutas ya existían (`PUT` y `DELETE /api/campaigns/:id/npcs/:npcId`). El DM
cambia el estado de un PNJ por campaña (`NpcStatusSelector`, en la tarjeta de
la mesa y en «Campañas» de la ficha), lo trae de la biblioteca y lo suma a otra
campaña (`PickManyDialog`) y lo quita de la mesa. Cambiar el estado es
instantáneo: se actualiza la caché y se guarda **en fila** (`useNpcLinks`), y si
falla sale un `Toast` y se relee. Quitar **confirma**, aunque Flutter no lo haga:
borra la fila del vínculo, así que se pierden el estado y los PG guardados y no
hay ruta para restaurarlos (un «Deshacer» sería mentira). `linkMany` suma uno por
vez y es seguro de reintentar: sumar sin estado no toca un vínculo existente.
La frontera no se mueve: todo es del DM y nada viaja a un jugador.

**Paso 6d: escenas de música** *(existe)*. No toca motor, servidor ni Flutter:
las escenas viven en `Campaign.musicScenes` y el servidor ya las poda para el
jugador. En `MusicPlayer` el DM crea, edita, mueve y borra escenas (`MusicSceneDialog`
y el ⋮ de cada fila: Editar, «Ofrecerla al iniciar un combate», Abrir en
YouTube y Borrar) y, con el enlace que el dueño no deja ver afuera, puede
cambiarlo desde el aviso. Todo escribe con `editCampaign`, que relee la
campaña antes del PUT, y las escrituras van **en fila** (`updateScenes`): dos
toques seguidos releerían lo mismo y el segundo pisaría al primero. Borrar no
confirma: avisa **adentro del panel** (no con `Toast`, que saldría en la misma
esquina y taparía el reproductor) con «Deshacer» durante 8 s. Mover es tomar la fila
(`useHoldDrag` con `group: 'music'` y `axis: 'y'`; hoy una fila solo llega hasta
las cinco que se ven, marcado `ponytail:`). Un enlace que
`musicSource` no reconoce no se guarda. Si la escena que suena se borra, el
video se corta; si cambia su enlace, el iframe se recarga; si cambia solo el
nombre, no.

**Paso 6a: compartir, avisos y turno** *(existe)*. Es la parte del jugador del
paso 6, y no toca motor, servidor ni Flutter: las rutas ya existían.
- **Avisos de la cola** (`src/events/`): `PendingEvents` pide `GET /api/events`
  al entrar a la lista, al Modo DM o a una ficha (las subrutas de la ficha no
  cuentan, como en Flutter), los muestra de a uno con `Toast` (8 s y una X) y
  marca cada uno visto al mostrarlo; un `kind` desconocido se marca sin
  mostrar. `eventMessage` es el `messageForEvent` de Flutter y el botín lo
  nombra el motor (`chapterGrants`). Un fallo al pedir o al marcar se traga en
  silencio. Los avisos tienen **una sola columna**: `ToastProvider` y
  `ToastViewport` viven en `Enabled` (`App.tsx`), y ninguna pantalla monta los
  suyos.
- **Compartir** (`ShareDialog`): genera el código, lo copia (el aviso va en el
  botón, no flotante) y lista las campañas con las que está compartido, con el
  corte confirmado en un segundo diálogo. Lo abren «Compartir» del panel de la
  ficha y el vacío de la pestaña Campaña; el vacío de la pantalla Campañas,
  que no sabe de qué personaje, lleva a la lista. Las claves de las consultas
  (`characterShares`, `turn`) **no** empiezan con `'characters'`: ese prefijo
  es el de `roster`, que `writer.ts` cancela en cada acción.
- **Aviso de turno** (`TurnBanner`): solo en la ficha propia. Se consulta con
  `refetchInterval` (20 s fuera de combate, 5 s con uno abierto) y **no**
  por la cola de avisos: el turno es estado efímero. Con la pestaña oculta
  pausa. Dice «Preparate, seguís vos» o «Es tu turno» y nada más: nunca el
  orden ni quién sigue.

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
   la ficha completa de un miembro y la de un PNJ con ficha; la música; los retratos con su visor; las menciones `@Nombre` del Cuaderno
   como enlaces, e imprimir la ficha.
4. Escrituras de bajo riesgo *(existe)*: PG y salvaciones de muerte, usos de
   espacios, recursos y dados de golpe, y los descansos con «Deshacer», solo
   en la ficha propia.
5. Edición completa: creador de personajes, subida de nivel, inventario. Por
   partes: 5a, la Inspiración Heroica y la concentración *(existe)*; 5b1,
   editar la mochila desde la fila y las monedas *(existe)*; 5b2, catálogo,
   comprar y vender *(existe)*; 5c1, subida de nivel sin elecciones de rasgos,
   competencias ni conjuros *(existe)*; 5c2, esas elecciones de rasgos y
   competencias *(existe)*; 5c3, los conjuros *(existe)*; 5d, creador *(existe)*, en
   cuatro: 5d1, el borrador en el motor *(existe)*; 5d2, Especie, Clase,
   Trasfondo y Características *(existe)*; 5d3, Competencias, Conjuros y Equipo *(existe)*; 5d4,
   Detalles, Revisión y el alta *(existe)*; 5e, lo que falta escribir en la
   ficha propia, de menor a mayor riesgo porque ninguna de estas escrituras
   tiene todavía acción en `SheetActions.apply`, en cinco: 5e1, condiciones,
   cansancio y modos activos (Furia) *(existe)*; 5e2, preparar conjuros (el editor ya
   existe en la subida) y cambiar el truco innato *(existe)*; 5e3, los planos del Artífice
   y los objetivos de arma de un rasgo (Pacto del Filo) *(existe)*; 5e4, Forma Salvaje *(existe)*;
   5e5, compañeros, y con ellos lanzar gastando espacio o uso gratis *(existe)*;
   5e6, lo que la comparación de las dos fichas mostró que /v2 no decía:
   dados de Ataque Furtivo, maestrías, ventajas, competencias, idiomas,
   sentidos y desgloses, sin escrituras *(existe)*; 5e7, los avisos y
   «Resolver», con la Defensa sin armadura *(existe)*; 5e8, escribir el Diario *(existe)*; 5e9, los
   retratos *(existe)*. 5f, la lista de
   personajes: reordenar, marcar favorito, renombrar, borrar y rehacer, más el
   personaje de ejemplo *(existe)*. Van antes del paso 6 porque solo tocan
   datos de la propia cuenta.
6. Lo crítico, que toca datos de otras cuentas o de varias a la vez: Modo DM,
   combate, vínculos y códigos de campaña. Por partes: 6a, la del jugador:
   compartir, los avisos de la cola y el aviso de turno *(existe)*; 6b, las
   campañas y la Mesa *(existe)*; 6c, Capítulos y Cuaderno *(existe)*; 6d, la música *(existe)*; 6e, los PNJ, en cinco: 6e1, los vínculos con las campañas *(existe)*; 6e2,
   alta y borrado *(existe)*; 6e3, el texto de la ficha *(existe)*; 6e4, el editor del bloque *(existe)*; 6e5,
   retrato y mostrar a la mesa *(existe)*; 6f, la ficha de PNJ, en tres: 6f1,
   crearla *(existe)*; 6f2, escribirla *(existe)*; 6f3, sus pantallas de edición (subir de
   nivel, elecciones, conjuros, planos, formas e imprimir) *(existe)*; 6g, el combate, en siete: 6g1, el puente del motor *(existe)*; 6g2, armar *(existe)*; 6g3, dificultad e iniciativa *(existe)*; 6g4, jugar *(existe)*; 6g5, efectos, legendarias y defensas *(existe)*; 6g6, cerrar *(existe)*; 6g7a, ofrecer música *(existe)*; 6g7b, «Convertir en PNJ» *(existe)*; 6g7c, sumar desde el Bestiario *(existe)*. Importar y exportar PNJ es el paso 7c *(existe)*. Antes de portar esto es lectura
   obligatoria [Modo DM](modo-dm.md): la frontera «el DM no escribe la ficha de
   otra cuenta» es del servidor y vale igual para el cliente nuevo. Entra acá
   también la edición de la ficha completa de un PNJ (inventario, comprar y
   vender, y el resto de lo que ya se escribe en la ficha propia) y crearla:
   reutiliza las acciones del motor y la cola de guardado del paso 5, pero
   guarda por `PUT /api/characters/:id`: `PUT /api/npcs/:id` solo escribe el
   documento del PNJ, y `_upsertCharacterHandler` ya acepta esa ficha.
7. Ajustes, transferencias y Homebrew:
   - **7a · Ajustes de cuenta** *(existe)*. Modo de inicio, tema y dificultad del
     encuentro desde React. La lista de personajes tiene una ruta propia para
     volver a ella desde el Modo DM.
   - **7b · Personajes y respaldos** *(existe)*. Importar y exportar desde Mis
     personajes con los ZIP de Flutter (`dnd_bundle`). El menú de cada personaje ofrece
     su descarga. «Transferir» agrupa importar un ZIP y descargar un respaldo
     completo. Antes de exportar se espera el guardado de las fichas incluidas.
     `GET /api/export` arma el ZIP con el mismo escritor Dart que usa Flutter.
     Importar confirma el archivo y usa `POST /api/import`. Al terminar se
     recargan personajes, catálogo y ajustes. Verificar el ida y vuelta con
     Flutter, retratos, imágenes del diario, homebrew y ajustes portables,
     además de que un ZIP inválido o en conflicto no deje una carga parcial.
   - **7c · PNJ** *(existe)*. Exportar desde el menú «⋯» de la ficha
     (`ExportNpcDialog`: trasfondo y tags marcados, notas no) e importar desde
     la Biblioteca (`ImportNpcDialog`), con el ZIP `dnd_npc` de Flutter. Como
     en 7b, el ZIP lo arma y lo lee el **servidor**: el navegador no tiene
     lector de ZIP. `GET /api/npcs/:id/export?background=1&tags=1&notes=1`
     (un flag ausente es «no»: las notas nunca viajan por olvido),
     `POST /api/npcs/import/preview` (no escribe nada) y
     `POST /api/npcs/import`, que ahora acepta también el ZIP de **un**
     personaje exportado desde Mis personajes y lo adopta como PNJ con ficha
     en el mismo handler. El escritor del ZIP, `npcForExport`, la conversión
     personaje→PNJ (`adoptCharacterAsNpc`) y `missingOfficialContent` viven en
     el motor (`npc_bundle_export.dart`, `npc_import_check.dart`) y los
     comparten Flutter, el servidor y el cliente React (este último solo el
     último, vía `npcImportMissing`). Antes de exportar se espera el guardado
     del PNJ y de su ficha. Elegir el archivo muestra la vista previa; con
     contenido oficial que falta, «Importar» queda apagado y no se le pregunta
     al servidor. Al terminar se cierra, se actualiza la Biblioteca y sale un
     aviso. Importar desde la vista de PNJ de una campaña no existe (Flutter
     tampoco lo tiene).
   - **7d · Homebrew.** Gestión del catálogo propio y transferencia en JSON,
     partida en cuatro:
     - **7d1 · Transferir, borrar y criaturas** *(existe)*. Importar y exportar el
       JSON `dnd_homebrew` desde la portada del Homebrew, borrar cualquier
       entrada propia diciendo qué fichas de Mis personajes la usan, y crear,
       editar y duplicar criaturas propias (más «Editar una copia» de una
       oficial) con el `CreatureForm` de 6e4 en rutas del Homebrew
       (`/dm/homebrew/criaturas/nueva[?de=<id>]` y `/dm/homebrew/criaturas/<id>/editar`).
       **Sin rutas nuevas en el servidor**: a diferencia de 7b y 7c, el archivo es
       texto JSON y no ZIP, así que lo arma y lo lee el navegador por el puente del
       motor, y se escribe con las rutas que ya existían
       (`POST /api/homebrew/import`, `PUT` y `DELETE /api/homebrew/<categoría>/<id>`).
       La lógica se mudó de `dnd_app` al motor (`homebrew_transfer.dart`: el
       sobre y su lectura, los choques, la validación de ids de inventario,
       `homebrewId` y `homebrewCopy`, y la lista de categorías que usa también
       el servidor); Flutter delega sin cambiar sus firmas. Importar siempre pasa
       por una vista previa (`homebrewImportCheck`: valida contra el catálogo
       fusionado y cuenta los choques con lo propio, que piden «Sobrescribir»);
       borrar usa `charactersUsing` sobre Mis personajes. Quedan afuera la lista
       de entradas inválidas de Flutter (`loadIssues`; `ponytail:` en
       `HomebrewView.tsx`) y los formularios de las demás categorías.
     - **7d2a · El editor de efectos y las dotes** *(existe)*. El motor suma
       `EffectDraft` (`effect_draft.dart`: los 26 tipos de efecto de Flutter, en
       su orden, con sus campos, valores iniciales, unidades y opciones sacadas
       del catálogo fusionado, y `build`, que arma el efecto o dice qué campo
       falta; `effectParts`, que resuelve lo que cada efecto nombra) y
       `FeatDraft` (`feat_draft.dart`, el patrón de `CreatureDraft`: formulario,
       dote armada que conserva requisito, grupo exclusivo y los efectos que el
       editor no sabe armar, y errores). React **no escribe nunca el JSON de un
       efecto**: dibuja los campos que el motor declara y manda tipo y valores
       (`effectKinds`, `effectBuild`, `effectParts`, `featForm`, `featDraft`,
       `featNew` en el puente). La frase de un efecto la arma cada cliente con
       sus textos (`describeEffectParts`, traducción literal de `describeEffect`
       de Flutter, que no cambia). En pantalla: el `EffectEditor` y su diálogo
       «Agregar efecto» (`src/dm/homebrew/`), el `FeatForm` y las rutas
       `/dm/homebrew/dotes/nueva[?de=<id>]` y `/dm/homebrew/dotes/<id>/editar`
       (el view kind `homebrewEditor` generaliza al de criaturas). El Códice
       —también el del jugador— muestra los efectos descriptos, uno por línea, de
       una dote sin descripción ni rasgo (cierra el `ponytail` de `entries.ts`).
       Quedan afuera editar un efecto en el lugar, los efectos de elección o de
       clase, esconder tipos por formulario (`hiddenKinds`, que usan los objetos
       en 7d3) y editar el requisito. Sin cambios en el servidor ni en Flutter.
     - **7d2b · Especies y trasfondos** *(existe)*: cierra la 7d2. El motor suma
       `RaceDraft` y `BackgroundDraft` (el patrón de `FeatDraft`: formulario como
       texto, entrada armada que conserva emblema y, en el trasfondo, el equipo
       inicial, y errores; el tamaño a elegir con menos de dos marcados queda
       vacío, y el trasfondo pide exactamente tres características) y
       `homebrewFormOptions` (tamaños, habilidades, herramientas, características y
       dotes de origen con su rótulo en el idioma). En el puente: `raceForm`,
       `raceDraft`, `raceNew`, `backgroundForm`, `backgroundDraft`,
       `backgroundNew`. En pantalla: `HomebrewFormShell` (el armazón que se
       extrajo de `FeatForm`, que cumple su `ponytail`), `RaceForm`,
       `BackgroundForm` y la vista `HomebrewEntryEditorView`, que generaliza la de
       dotes (`EDITABLE_HOMEBREW` suma `races` y `backgrounds`). El Códice
       —también el del jugador— suma a la especie el dato «Habilidades» y, sin
       rasgos pasivos, sus efectos uno por línea, y al trasfondo una sección
       «Rasgos» con sus efectos. Quedan afuera editar el equipo inicial y el emblema, los linajes y esconder
       tipos de efecto. Sin cambios en el servidor ni en Flutter.
     - **7d3 · Armas, armaduras y objetos**, partida en dos:
     - **7d3a · Armas y armaduras** *(existe)*: el motor suma `WeaponDraft` y
       `ArmorDraft` (el patrón de `RaceDraft`, con los límites de Flutter: dado con
       formato, alcance 5–1000 y obligatorio con «A distancia» o «Arrojadiza», largo
       no menor que el normal, bonificador 0–3, CA 1–30, tope de DES 0–10, Fuerza
       1–30). Elegir la categoría de una armadura repone lo que suma la Destreza
       (`ArmorDraft.withCategory`, que es `_applyCategoryDex` hecho regla) y
       `acExamples` da la CA con DES +3 y +1 (`armorClassFor`, vacía en un escudo).
       `homebrewFormOptions` suma categorías, propiedades, maestrías y tipos de daño.
       En el puente: `weaponForm`, `weaponDraft`, `weaponNew`, `armorForm`,
       `armorDraft`, `armorNew`, `armorWithCategory`. En pantalla: `WeaponForm` y
       `ArmorForm` sobre `HomebrewFormShell`, con `EconomySection` en
       `homebrewFields`; `EDITABLE_HOMEBREW` suma `weapons` y `armor`. El Códice de
       armas —también el del jugador— suma el dato «Mágica» (`+N`). Quedan afuera
       editar «a dos manos salvo montado» (se
       conserva) y el precio en monedas (sigue en cobre). Sin cambios en el
       servidor ni en Flutter.
     - **7d3b · Objetos** *(existe; con esto la 7d3 queda cerrada)*: el motor suma
       `ItemDraft` (formulario como texto con los efectos en tres partes —CA,
       resistencias y «otros»—, que `build` junta en el orden de Flutter; límites de
       Flutter: CA y bonificador mágico de −5 a 10; `withRarity` apaga la
       sintonización sin rareza y `withBaseKind` vacía las bases; `baseOptions` por
       nombre del catálogo fusionado). En el puente: `itemForm`, `itemDraft`,
       `itemNew`, `itemWithRarity`, `itemWithBaseKind`, `itemBaseOptions`, y
       `homebrewFormOptions` suma `itemCategories`, `rarities` y `baseItemKinds`. En
       pantalla: `ItemForm`; `EffectEditor` gana `hiddenKinds` (cierra el `ponytail:`
       de la 7d2a) y `items` entra a `EDITABLE_HOMEBREW` con la ruta
       `/dm/homebrew/objetos/…`, un solo editor para las dos categorías del Códice
       (Objetos mágicos y Equipo). El Códice de objetos —también el del jugador—
       suma «Al equiparlo» y «Objeto base», y deja de cortar la primera línea de la
       descripción de un objeto propio. Quedan afuera editar cargas, recarga y
       paquete (se conservan) y el precio en monedas.
       Sin cambios en el servidor ni en Flutter.
     - **7d4 · Conjuros** *(existe; con esto la 7d queda cerrada)*: el motor suma
       `SpellDraft` (los componentes se guardan como una línea y el motor la separa
       en letras V, S, M y material, y la vuelve a armar; `castingTimes` y las
       nueve clases lanzadoras son datos del motor; solo el nombre es obligatorio) y
       su puente (`spellForm`, `spellDraft`, `spellNew`); `homebrewFormOptions`
       suma `spellLevels`, `spellSchools`, `castingTimes`, `spellClasses` y
       `spellComponents`. En pantalla: `SpellForm` sobre `HomebrewFormShell`
       (un tiempo de lanzamiento que la lista no trae se ofrece con su texto, y una
       clase de un pack se ve punteada con su id) y `spells` entra a
       `EDITABLE_HOMEBREW`. La vista previa es la ficha del Códice de conjuros, sin
       cambios. Se borra la rama «se crea en la aplicación principal» de
       `HomebrewView` y sus textos: ninguna categoría del Homebrew manda a Flutter.
       El **panel de reglas por campo** de Flutter llegó después a los ocho
       formularios (ver «Arreglos de front», parte F). Sin cambios en el servidor
       ni en Flutter.

   Acomodar las tarjetas de Combate y Personaje (sin equivalente en Flutter):
   el botón «Acomodar tarjetas» de cada pestaña abre un modo de edición
   (`ArrangeableColumns`, `src/sheet/`) donde cada tarjeta es una barra que se
   mueve arrastrándola o con flechas. El orden es una preferencia de quien mira
   la ficha, así que vive en los ajustes de la cuenta (`sheetLayout`, tres
   columnas de ids por pestaña, `null` = el de fábrica) y nunca en el
   personaje: vale para toda ficha que esa cuenta abra y no escribe ninguna.
   Para que un guardado de Flutter, con su lista cerrada de campos
   (`AppSettings.toJson`), no lo borre, el servidor **combina** los ajustes en
   vez de reemplazarlos (`account_settings.document || excluded.document`, de
   primer nivel): lo que llega pisa sus claves y las demás quedan. Ningún
   cliente puede borrar una clave mandando el documento sin ella.

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
   para el dado de golpe y la recarga al amanecer); los `puente-*` prueban las
   funciones de lectura del editor de conjuros (`spellEdit`,
   `innateCantripOptions`) y de los planos (`magicItemPlans`,
   `magicBaseOptions`, esta sin ficha: `withoutCharacter`), el alta de un PNJ
   (`newNpc`, también sin ficha) y su edición (`npcEdit`, que no lee ni ficha ni
   catálogo: `pure`), con la función y sus argumentos en el caso. Es también la red del tipo escrito a mano de
   `types.ts`: un campo nuevo en `ComputedSheet.toJson` rompe acá aunque el tipo
   no lo diga.
2. **Playwright** (job `web_e2e`). Pocas pruebas, con el criterio de `CLAUDE.md`
   §Tests: levanta el servidor real con repositorios en memoria y sesiones
   falsas (`dnd_server/test/e2e_server.dart`), sirve el `dist` de `/v2` con
   personajes, campañas y homebrew sembrados, y verifica tres cosas:
   - **Que una escritura mande lo que da el motor** y quede guardado: daño,
     salvaciones de muerte (con la cola que junta toques), espacios y usos, dado
     de golpe y descansos, Inspiración y concentración, mochila, compra y venta,
     subida de nivel, Furia, estados y cansancio, conjuros preparados y truco
     innato, arma de pacto, planos y réplicas del Artífice, y «Deshacer» donde lo hay (`e2e/escritura.spec.ts`, con una cuenta
     propia para no cambiar lo que leen las demás), más el alta del creador
     (`e2e/creador.spec.ts`).
   - **Que lo ajeno no se alcance:** otra cuenta recibe el mismo 404 que ante lo
     inexistente, en la API y en la pantalla, para campañas, combates, PNJ y
     homebrew; nada del DM llega a la vista del jugador; el retrato de un miembro
     se pide por el vínculo y no por la clave; la ficha ajena no tiene un solo
     control, y una cuenta sin `webV2` ve «No disponible» sin pedir sus datos
     (`e2e/acceso.spec.ts`, `campanas`, `combate`, `dm`, `homebrew` y `pnj`).
   - **Que la ficha muestre los números del motor,** incluido el ataque de un arma
     homebrew, que depende de `mergeHomebrew`, del cliente (`e2e/ficha.spec.ts`).

   Lo esperado se calcula con el mismo motor y la misma fusión (`e2e/helpers.ts`).
   Sin reintentos: no hay «a veces anda». Las de `escritura.spec.ts` corren en
   serie, así que una falla frena las que siguen.

   **Lo que Playwright no mira:** el resto de las pantallas de lectura (dashboard,
   Bestiario, Códice, Ajustes, Mesa, Capítulos, Cuaderno, Biblioteca de PNJ) y sus
   filtros. Sus reglas están en los tests del motor; el dibujo se compara a mano
   (nivel 3).

   **Trampa al volver escribible una pantalla:** las pruebas de lectura
   (`ficha.spec.ts`) entran con la cuenta de `TOKEN`, que es
   **dueña** de sus fichas, así que ven los controles nuevos. Una celda que
   antes mostraba «Sí» y ahora es una casilla las rompe sin que el cambio
   toque esos archivos (pasó con la columna «Equipado» del Inventario en 5b1:
   CI en rojo y el CD salteado). Antes de commitear, buscá en `e2e/` cada
   `data-field` y cada texto de la pantalla que cambió, y adaptá lo que lea
   como texto lo que ahora es un control. Si Playwright no corre en la máquina
   (ver la trampa del antivirus en `CLAUDE.md`), mirá el resultado de CI antes
   de seguir con el próximo cambio: CI en rojo llega igual a producción.
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

- Enlaces desde Flutter hacia `/v2` (la redirección de `/` ya existe).
- Tests de componentes y chequeo de literales sueltos en `dnd_web`.
- Un criterio medido de «paridad visual» con Flutter: hoy es la comparación
  manual.
- Retiro de Flutter: ver abajo; de los seis criterios están cumplidos el 4 y el 6.

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
   antes de borrar `dnd_app`, para poder volver atrás. *(Cumplido: el
   interruptor «Usar la versión anterior» de Ajustes, cookie `milantus_v1`.)*

Retirar Flutter implica además actualizar `CLAUDE.md`, la guía de diseño (cuyo
destino hoy sigue siendo Flutter) y el pipeline de CI/CD en el mismo cambio.
