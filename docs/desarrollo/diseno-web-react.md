# Diseño web en React — `packages/dnd_web`

Estado: guía vigente del cliente React (`/v2`). El lenguaje visual es el mismo
de [Diseño web](diseno-web.md): esta guía no lo repite, dice **cómo se aplica
en React** y cuál es la pieza de `src/ui/` para cada cosa. Antes de crear un
componente visual nuevo, buscá acá; si el código y esta guía discrepan, manda
el código.

## Tokens y tema

- Todos los colores, radios y fuentes viven en `src/index.css` como variables
  CSS, con los valores del [Apéndice B](diseno-web.md#apéndice-b--equivalencia-en-css)
  (más `--verdant`, de §3.1, y `--scrim`, el velo de los diálogos).
- Cada color es también una utilidad de Tailwind (`bg-surface`, `text-gold`,
  `border-hairline`). La paleta por defecto de Tailwind **está borrada**
  (`--color-*: initial`): `bg-red-500` no existe, así que no hay forma de colar
  un color por fuera del sistema. Los radios van como
  `rounded-[var(--radius-card)]` (12), `--radius-pill` (20) y `--radius-nav` (9).
- El tema claro es `data-theme="light"` en `<html>`. Lo maneja
  `src/theme/theme.tsx`: oscuro por defecto, lo elegido en el navegador
  (`localStorage`, clave `milantus.v2.theme`) antes que lo de la cuenta
  (`themeMode` de `/api/settings`). Un script en `index.html` lo aplica antes
  del primer cuadro para que no destelle.
- El breakpoint de marco es `shell:` (900 px). Todo lo demás se resuelve con
  grillas que se adaptan solas (`auto-fill`, `minmax`), no con más breakpoints.
- La única sombra es el hover de la tarjeta de personaje (`.roster-card`).

## Primitivas

Comportamiento accesible de [Radix UI](https://www.radix-ui.com/) (headless:
foco, teclado, roles ARIA, portales; ningún estilo propio), íconos de
`lucide-react` y datos con TanStack Query. Las versiones están fijadas
exactas en `package.json`. Los envoltorios con el estilo del sistema están en
`src/ui/primitives.tsx` y `src/ui/disclosure.tsx`; un componente no importa
Radix directo salvo para algo que esos envoltorios no cubran.

| Pieza | Para qué | Notas |
| --- | --- | --- |
| `Tooltip` | Explicación corta al pasar el mouse o enfocar | No reemplaza el `aria-label` de un botón de ícono |
| `DropdownMenu*` | Menú de opciones (el selector de tema) | `RadioItem` con tilde dorado para opciones excluyentes |
| `Popover*` | Contenido flotante que se lee y se cierra | Topeado al ancho de la ventana |
| `Select` | Selección única con rótulo visible | El rótulo no desaparece al elegir |
| `Switch` | Encendido/apagado con rótulo | El pulgar se mueve: el estado no depende solo del color |
| `ScrollArea` | Zona con scroll propio y barra fina (nunca la del navegador, que en oscuro es un bloque gris) | La usa el panel lateral; un texto que crece hasta un tope lo lleva en `viewportClassName`, con `label` para que se enfoque con el teclado y `type="auto"` para que la barra avise que hay más (el trasfondo) |
| `Toast` / `ToastViewport` | Avisos (`showAppMessage`) | Ícono, color y texto; error 6 s, el resto 3 s. `action` es el «Deshacer» (`onUndo`) y alarga a 6 s. Hoy los usa la ficha propia (`CharacterPage`) |
| `LinkTabs` / `TabPanel` | Pestañas **que son URLs** | Flechas para moverse, Enter para abrir; cada pestaña es un enlace real |
| `Accordion` | Lista de entradas plegables (rasgos, dotes) | Varias abiertas a la vez; el botón va dentro de un encabezado |

## Biblioteca (`src/ui/`)

Equivalente a la de Flutter (`diseno-web.md` §8). Ningún componente calcula
una regla: reciben el número ya resuelto por `computeSheet`.

### Estructura

| Componente | Qué hace | Cuándo |
| --- | --- | --- |
| `Shell` | El marco: panel de 236 px fijo desde 900 px, barra con cajón debajo; el contenido ocupa todo el ancho (sin máximo). `panel` y `footer` son de cada pantalla | Toda pantalla. Sin `panel` ni `footer`, solo la marca (sin sesión, no disponible) |
| `NavGroup`, `NavItem` | Grupo con nombre (`nav`) e ítem del panel: ícono, rótulo, activo en oro sobre `goldSoft` con `aria-current` | `internal` navega sin recargar; `external` avisa al lector que abre Flutter y muestra el ícono de enlace externo; `count` lleva la cifra tabular a la derecha (oro si está activo), `muted` atenúa la categoría sin coincidencias en el Códice y `onSelect` en vez de `href` lo vuelve un botón para una acción de la pantalla (Imprimir) |
| `SidebarBack` | El «volver» de una pantalla de adentro, con la forma del interruptor de modo | Ficha |
| `ModeSwitch` | «Jugador / DM»: el modo actual es un `span` con `aria-current` y el otro un enlace interno (`mode`, `playerHref`, `dmHref`) | Panel de cada modo |
| `NavCollapsible` (`ui/disclosure.tsx`) | Grupo del panel que se pliega: el rótulo es el botón | Campañas terminadas del Modo DM |
| `ThemeMenu`, `VersionLabel` | Selector de tema y versión, al pie del panel | Los dos pies |
| `Card` | Tarjeta de sección (`sheetCard`): ícono dorado, título Georgia 16, `trailing`; `collapsible` la pliega | Toda sección de la ficha. `id` único por pantalla |
| `SectionRule` | Filete con rombo dorado | Separar bloques dentro de una tarjeta |
| `Eyebrow` | Rótulo de sección en mayúsculas espaciadas | — |

### Datos de personaje (`src/ui/data.tsx`)

| Componente | Qué hace | Cuándo |
| --- | --- | --- |
| `StatTile` | Placa de la banda táctica, **centrada**: ícono + rótulo arriba, cifra en sans negrita tabular con su `suffix` en la misma línea, `footer` a todo el ancho y `caption` debajo | Solo la banda táctica, dentro de `.tactical-band` (`index.css`): columnas fijas medidas con *container query*, PG más ancha, sin placas huérfanas |
| `StatPlaque` | Rótulo y valor en Georgia, centrado; `dense`. El rótulo puede ser un nodo (abreviatura visible, palabra completa para el lector) | Tiras cortas dentro de una tarjeta (CD, ataque de conjuro, CA/VEL/INIC de la tarjeta del dashboard) |
| `ShieldBadge` | La CA dentro de un escudo, con `aria-label` | **Solo CA**, y solo donde la CA es el tema (Defensa) |
| `Pill` | Cápsula de radio 20; `highlighted={false}` neutra, `danger` carmesí | Clase, subclase, nivel; `danger` solo para un estado malo (envenenado) |
| `Pips` | Usos restantes, llenos en oro; `label` dice la cuenta; `tone="crimson"` para lo que cuenta en contra | Recursos, espacios de conjuro; carmesí solo en los fallos de muerte |
| `ThinBar` + `hpTone` | Barra fina (`role="meter"`, con `aria-label` y valor); `hpTone` da verde/oro/carmesí según el cociente de PG (`AppPalette.hpColor`) | PG |
| `MarkdownText` | El Markdown de una mesa (títulos, viñetas, negrita, itálica), armado como elementos y nunca como HTML | Trasfondo y entradas del Diario |
| `Medallion` | Aro del color de clase con el retrato (miniatura de su tamaño) o, si no hay o no carga, la inicial sobre un degradado del acento hacia la placa (`color-mix`, sin colores inventados). `viewable` lo vuelve botón que abre el visor | Tarjeta y panel; `viewable` solo fuera de un enlace |
| `Seal` | El sello de la marca | Solo la marca |

### Estados y acciones

| Componente | Qué hace | Regla |
| --- | --- | --- |
| `AppBusyLabel` | Spinner + texto, región viva | El texto es obligatorio |
| `AppErrorView` | Ícono, título, mensaje, detalle copiable y «Reintentar» | `onRetry` siempre que reintentar pueda arreglarlo; `as="h1"` si ocupa la pantalla |
| `AppEmptyState` | «No hay nada» (`empty`) o «nada coincide» (`no-match`), con ícono distinto | Son situaciones distintas y piden acciones distintas |
| `Notice` | Pantalla de un solo mensaje con su `h1` | Sin sesión, no disponible, no encontrado |
| `Button`, `ButtonLink` | `primary` (oro lleno, uno por vista), `soft` (oro sobre `goldSoft` con filete: el verbo de una barra de herramientas), `secondary`, `danger` (carmesí, lo irreversible); `shape="pill"` en una fila de pills | `ButtonLink internal` navega sin recargar |
| `SaveStatusBadge` | La pill del guardado automático (`SaveStatusIndicator`): Guardando… / Guardado / No se guardó con «Reintentar» | Al pie del panel de una pantalla que escribe, en lugar de «Solo lectura» |
| `AppDialog` | El molde de diálogo: placa, velo, barra de acciones de 48 px al pie | 480 px por defecto, 560 si el cuerpo es una ficha |
| `PortraitViewer` | El retrato original entero sobre el velo, con cerrar; `Esc` y clic afuera también cierran | Lo abre `Medallion` con `viewable` |

## Datos

`src/api/queries.ts` tiene un `useQuery` por recurso (`useAccount`,
`useRoster`, `useRosterSettings`, `useCatalog`, `useThemeMode`,
`useAppVersion`). Un 4xx no se reintenta; un 5xx o la red, dos veces más. El
catálogo no vence nunca. Toda pantalla pasa por ahí: la caché es lo que hace
que ir del dashboard a la ficha no vuelva a pedir nada.

## Navegación

`src/router.tsx`: `useRoute()` y `Link` (un `<a href>` de verdad que, con
clic simple, navega sin recargar). Los enlaces a Flutter son `<a>` comunes.
Una pestaña que el usuario querría compartir o recargar es una ruta
(`/personajes/:id/combate`), no estado de React.

## La ficha (`src/sheet/`)

La pantalla de referencia de cómo se arma una vista con la biblioteca:

- `SheetModel` (`model.ts`): el personaje **migrado**, la ficha del motor y el
  catálogo con homebrew. Todo componente de la ficha recibe solo eso, más
  `write` en la ficha propia: un control que escribe se muestra **solo si
  `model.write` existe**, y cada acción pasa por `write.act` (el motor) y
  nunca suma ni resta en el componente.
- Desde 900 px las pestañas viven en el panel (`NavItem` con `aria-current`);
  debajo, como `LinkTabs` arriba del contenido, para no tener que abrir el
  cajón. El panel de la pestaña se monta una sola vez.
- Columnas: `COLUMNS` (`CharacterTab.tsx`), tantas de 300 px como entren y una
  en un teléfono, con `items-start`.
- Rótulos que necesitan vocabulario del motor (la característica de cada
  habilidad, si un conjuro es una reacción) salen de `vocabulary.ts`, que
  copia el enum del motor y lo dice; ningún número sale de ahí.

## El Códice (`src/codex/`)

- `entries.ts` traduce cada categoría del catálogo a `CodexEntry` (nombre,
  subtítulo, procedencia, faceta) con el detalle armado a pedido: la lista de
  392 conjuros no arma 392 fichas.
- Lista y detalle van en `.codex-split` (`index.css`), medido con *container
  query* y no con el viewport, porque el panel le come ancho: desde 760 px son
  dos columnas con la lista pegajosa y su propio scroll; debajo se ve una sola
  y el detalle trae «volver a la lista».
- La búsqueda ignora tildes y mayúsculas (`fold`), igual en el panel y en la
  categoría.
- El glosario cambia tres cosas porque se lee en orden: la lista va agrupada y
  numerada sin filtros (`EntryList`), el detalle abre con el grupo y una pista
  de una muesca por término (`ReadingTrack`) y cierra con anterior y siguiente
  (`ReadingSteps`). El ejemplo de cada término va hundido en una placa.
- Las guías se leen igual, con la lista numerada sin grupos ni buscador y
  «Guía N de 4» en lugar de la pista. El primer combate va en pasos unidos por
  una línea, y la de la ficha, pestaña por pestaña con `TAB_ICONS`.

## Ajustes (`src/settings/`)

Dos `Card` en una grilla que se adapta sola (`auto-fit`). La primera lleva
controles (`Select` para el tema y el idioma) y la segunda una lista de
definición (`dl`) de solo lectura, con un `ButtonLink` a Flutter para cambiar
lo que se guarda en la cuenta. Esa separación es la regla de la pantalla: lo que
vive en el navegador se edita ahí; lo que vive en la cuenta se muestra hasta
que React escriba.

## Campañas (`src/campaigns/`)

La lista reutiliza `CampaignBlock` (`src/sheet/CampaignTab.tsx`), el bloque de
una mesa de la pestaña Campaña: recibe el catálogo y el nombre del personaje
en lugar del `SheetModel` justamente para poder usarse fuera de una ficha.
Cada bloque va debajo de un enlace «Con <personaje>». Una pantalla nueva con
datos de campaña pasa por ahí y por `usePlayerCampaignsOf`, nunca por una
consulta propia: la poda del jugador es del servidor.

## El Bestiario (`src/bestiary/`)

Reutiliza el marco lista + detalle del Códice (`.codex-split`, `.codex-list`,
`.codex-detail`, `.codex-back`), pero con su propia barra de herramientas: búsqueda
en pill, tres `Select` con rótulo visible (tipo, VD desde, VD hasta) y un
par de botones `aria-pressed` para el orden, que no es un filtro y por eso
«Limpiar filtros» no lo toca. El perfil (`CreatureProfile`) arma las cifras en
placas con `.plaque-label` y `.num` (carmesí los PG, oro el VD), las
características en seis celdas con su salvación reservando el alto, los datos de
línea como lista de definición y las acciones agrupadas con acierto, daño y
alcance en placas. Una criatura nueva en el catálogo no pide código: sale sola.
Lo que el perfil necesita y no es un dato del catálogo se agrega a `bestiary()`
del motor, nunca se calcula acá.

## El Modo DM (`src/dm/`)

Cada sección es una ruta bajo `/v2/dm/campanas/:id/` (el Bestiario, la Biblioteca de PNJ y el Homebrew, herramientas de la cuenta, bajo `/v2/dm/bestiario`, `/v2/dm/pnj` y `/v2/dm/homebrew`) y comparte tres piezas:
`DmPanel` (el panel: interruptor, herramientas, campañas, secciones),
`DmHeader` (título Georgia 30, pill con el estado y la regla ornamental; el
`h1` es el título) y `DmPage`, que resuelve la campaña por id y es la única que
sabe distinguir «cargando», «error» y «no se encontró» (una campaña ajena y una
inexistente son la misma pantalla). **Solo lectura**: ninguna sección tiene un
control que escriba, y el e2e comprueba que no sale ningún pedido que no sea
`GET`.

- **Mesa** (`MesaView`, `MemberCard`): grilla `auto-fill` de tarjetas con
  `toRosterEntry` (`dashboard/roster.ts`, la misma cuenta que el dashboard). La
  CD sale de los bloques de lanzamiento del motor y, con varias clases
  lanzadoras, se muestran todas.
- **Capítulos** (`ChaptersView`): lista ordenada de tarjetas `card`; el abierto
  lleva `border-2 border-gold`, el estado va en una pill con el color del estado
  (oro, apagado, neutro) y lo que reparte en `StatPlaque`.
- **Cuaderno** (`NotebookView`, `notebook.ts`): pills `aria-pressed` por
  capítulo (la selección es estado local, no ruta), buscador en pill como el del
  Bestiario y entradas en `card` con `border-l-[3px]` del color del tipo. Titular,
  redactar un combate y buscar son presentación y viven en `notebook.ts`; los
  nombres salen del catálogo.
- **Bestiario** (`BestiaryPage dm`): la pantalla del jugador montada con el panel
  del DM; no hay un segundo navegador. `dm` cambia la cabecera (`DmHeader`, con
  «Solo lectura» y el conteo) y las URL (`dmBestiaryHref`).
- **Biblioteca de PNJ** (`npcs/NpcLibraryView`, `npcs/NpcDetailView`,
  `npcs/npc.ts`): la lista es una grilla `auto-fill` de `card` enlazadas, con el
  buscador en pill y dos filas de pills `aria-pressed` con su conteo —campaña,
  más grandes, y tag, más chicas: la jerarquía es la de Flutter— que son estado
  local. La ficha abre con la identidad a todo el ancho (medallón de 76, `h1`
  Georgia 28, la línea de tipo en `Pill` oro y los tags neutros, la voz como
  cita con la comilla en oro) y debajo dos columnas: Trasfondo (`Card`) y Notas
  (`DiaryEntries`, el mismo de la pestaña Diario, a dos columnas) a la izquierda,
  Estadísticas y Campañas a la derecha. El estado por campaña es una pill con la
  palabra y el color del estado (`STATUS_TONE`: verde, carmesí, apagado). La
  línea de tipo la arma `npcTypeLine` con lo que da `npcViews`: ningún número se
  calcula acá. El tablero es «Modo DM — Biblioteca de PNJ, PNJ de la mesa,
  Homebrew y Combate» del Design.
- **PNJ de la mesa** (`npcs/CampaignNpcsView`): la grilla `auto-fill` de `card`
  de 280 px con la misma `FilterPill` de tag que la Biblioteca (exportada de
  `NpcLibraryView`) y el conteo por estado a su izquierda. La tarjeta no es un
  enlace entero: lo es la identidad (medallón de 36 y nombre), porque así es en
  Flutter, donde el resto de la tarjeta lleva controles. El estado va al pie con
  `STATUS_TONE`, y un muerto se tacha y atenúa además del color.
- **Homebrew** (`HomebrewView`): la portada repite las tarjetas de la portada del
  Códice (ícono, nombre, cifra y muestra), atenuadas cuando la categoría está
  vacía, con un buscador en pill que reemplaza la grilla por una lista de
  resultados. Una categoría monta `CategoryView` del Códice, exportada con dos
  props: `header` (la cabecera del Modo DM en lugar del `h1` del Códice) y
  `hrefOf` (las URL de cada entrada). No hay una segunda ficha: una entrada nueva
  del catálogo se ve igual en los dos.
- **Combate** (`CombatView`): una placa (`plaque`) con ronda, turno y en pie, y
  debajo la planilla en `card` con cinco columnas fijas (`LEDGER`), que con poco
  ancho se desplaza dentro de su caja en vez de partirse. El turno es una barra
  verde al filo izquierdo de la fila sobre `goldSoft` (no un borde alrededor) y
  la palabra bajo la iniciativa; lo ya jugado se atenúa y un caído se tacha.
  Los PG van en carmesí con `ThinBar`, y el bando en una pill con la palabra
  (verde, carmesí, apagado). «Del turno» va a la derecha: una `card` con tres
  placas (Inic, PG, CA) y, debajo, el `CreatureProfile` del Bestiario como su
  propia tarjeta, para no anidar una dentro de otra.

## Reglas que más se olvidan

- Ningún color, radio ni fuente sueltos: variables o utilidades.
- Georgia solo en títulos y valores de placa (`font-display`, `StatPlaque`).
  Un número que se compara con el de al lado, `.num` (sans negrita,
  `tabular-nums`).
- Un `h1` por pantalla, también mientras carga.
- Todo `aria-label` y todo texto visible salen de `useTexts()`.
- Nada de `max-width` centrado en el contenido: el marco ya da el ancho.
- 360 px de ancho sin scroll horizontal: `min-w-0` en los hijos de grilla y
  `minmax(min(Xpx,100%),1fr)` en las grillas.
