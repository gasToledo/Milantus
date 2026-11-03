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
| `ScrollArea` | Zona con scroll propio y barra fina (las nativas toman el mismo tema desde `index.css`: `scrollbar-color` con el filete) | La usa el panel lateral; un texto que crece hasta un tope lo lleva en `viewportClassName`, con `label` para que se enfoque con el teclado y `type="auto"` para que la barra avise que hay más (el trasfondo) |
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
| `SidebarBack` | El «volver» de una pantalla de adentro, con la forma del interruptor de modo. `onClick` con `preventDefault` frena la salida para confirmar | Ficha, creador |
| `ModeSwitch` | «Jugador / DM»: el modo actual es un `span` con `aria-current` y el otro un enlace interno (`mode`, `playerHref`, `dmHref`) | Panel de cada modo |
| `NavCollapsible` (`ui/disclosure.tsx`) | Grupo del panel que se pliega: el rótulo es el botón | Campañas terminadas del Modo DM |
| `ThemeMenu`, `VersionLabel` | Selector de tema y versión, al pie del panel | Los dos pies |
| `Card` | Tarjeta de sección (`sheetCard`): ícono dorado, título Georgia 16, `trailing`; `collapsible` la pliega | Toda sección de la ficha. `id` único por pantalla |
| `SectionRule` | Filete con rombo dorado | Separar bloques dentro de una tarjeta |
| `Eyebrow` | Rótulo de sección en mayúsculas espaciadas | — |

### Asistentes (`src/ui/wizard.tsx`)

El circuito de la subida de nivel y el creador, tal como se aprobó en los
lienzos: **una sola forma de elegir y un estado por bloque**. Antes de sumar
un control a un asistente, buscá acá.

| Componente | Qué hace | Cuándo |
| --- | --- | --- |
| `Option` | La opción: círculo si se elige una, cuadrado (`multi`) si son varias. Apagada, con el motivo en `detail`, nunca escondida. `id` va en `data-option`. `blocked` la atenúa pero **responde** (`aria-disabled`, sin `disabled`): para decir por qué no se puede elegir (cupo lleno) y mostrar su detalle | Toda elección de un asistente |
| `Block` | Tarjeta de un grupo de opciones: título y un solo `status` | Cada grupo |
| `Status` | Los tres estados, y ningún otro: falta (`count` para «n de m»), `ready` y `auto` | En `Block` |
| `SpellPickBlock` | Un cupo de conjuros: buscador, scroll propio y `cap` (null para quien conoce en vez de preparar) | Conjuros de la subida y del creador |
| `SpellTabs` | La tira de pestañas de los conjuros (una por cupo, con su `Status`): elegir una no cambia lo demás ni avanza sola | Conjuros del creador y editor de la ficha |
| Bandeja de elegidos | Los elegidos como chips que se sacan con ✕ (`data-chip`), sobre la lista, en vez de un texto «Elegidos:». Uno elegido que ya no está en la lista también sale ahí, con su id si no está en el catálogo. Vive en `sheet/SpellEditor.tsx` y `sheet/MagicItemPlans.tsx`, no es un componente suelto | Editor de conjuros de la ficha |
| `WildShapeTile`, `WildShapeDialog` | La franja de Forma Salvaje en la banda táctica (`data-stat="wild-shape"`, con la estructura de `ActiveModeTile`) y su diálogo: las formas anotadas como `Option` de elección única, el perfil a la derecha (debajo de `lg`, un botón `Info` lo muestra dentro del mismo diálogo). Elegir no transforma. Vive en `sheet/WildShape.tsx` | Banda de Personaje y Combate de un druida |
| `CompanionsCard`, `SummonDialog` | La tarjeta de compañeros en juego (`data-card="companions"`, `data-companion="n"`): cada fila plegada de entrada, varias abiertas a la vez, con PG, CA, estados y perfil; «Invocar» (`data-action="summon"`) abre el diálogo: `Select` de opción si hay más de una, formas como `Option` (con más de 6, en `SearchableList`), pago con el uso gratis (`data-free`) y `SpellSlotGrid`, y el perfil a la derecha (debajo de `lg`, un botón `Info` lo muestra dentro del mismo diálogo). Avisos en oro entre el cuerpo y la barra. Vive en `sheet/Companions.tsx` | Combate, columna de PG y Defensa |
| `AmountControls` | El campo de cantidad con Daño, Curar y PG temp (`sheet/CombatTab.tsx`); recibe `id` y `dataControls` para que el personaje y cada compañero tengan el suyo. `ConditionToggleList` es lo mismo para los estados (`data-condition` o `data-companion-condition`) | PG de la ficha y de cada compañero |
| `CreatureProfile` con `compact` | La misma ficha de criatura sin tarjeta propia ni píldoras y con título de panel (`font-display text-[16px]`): para el panel derecho y el diálogo de Forma Salvaje | Mostrar una criatura dentro de otra superficie |
| `WIZARD_ASIDE` | Las clases de la columna derecha: sigue a la vista al bajar y, si no entra, se desplaza sola | Panel derecho de cada asistente |
| `SearchableList` | Buscador sin tildes y por palabras (`matchesQuery`), cuenta y scroll propio; `groupOf` pinta un `Eyebrow` a todo el ancho al cambiar de grupo (los conjuros por nivel, sin grupos vacíos al buscar) y `empty` dice qué pasa si el filtro no deja nada | Listas largas: especies, trasfondos, armas |
| `StepRail` | La tira de pasos; `progress` la cambia en un teléfono por «Paso n de m» y una barra | Arriba de cada asistente |
| `WizardFooter` | El pie: lo que falta y Atrás/Continuar, como tarjeta flotante; `above` a todo el ancho | Abajo de cada asistente |
| `DetailBody`, `TraitList` | La ficha del Códice (`CodexDetail`) y una lista de rasgos, para el panel derecho | Explicar lo último que se tocó |
| `AfterCard`, `AfterList` | «Así queda»: cada fila con el valor solo o «de → a» (`from`), `gold` para lo que cambió y `note` para una aclaración apagada | Panel derecho; `AfterList` suelta en el pie del teléfono |

#### Reglas para toda pantalla nueva con elecciones

Salieron de revisar el creador en uso. Valen para cualquier pantalla donde se
elige algo, sea o no un asistente:

1. **Nada se mueve solo.** Un bloque no se pliega al completarse y un cupo
   completo no salta al siguiente: lo recién elegido se está leyendo en el panel
   derecho y no puede irse de abajo del dedo. Plegar o avanzar lo decide quien
   usa la pantalla.
2. **La explicación siempre a la vista.** Si hay detalle de lo que se toca, no
   puede obligar a subir para leerlo: la columna derecha es fija al bajar
   (`WIZARD_ASIDE`).
3. **Una pantalla, no un rollo.** Varios grupos de listas largas no se apilan:
   uno a la vez, en pestañas con el estado de cada uno (Conjuros). Las listas
   largas llevan buscador y su propio scroll (`SearchableList`). Antes de sumar
   un bloque, mirá cuánto hay que bajar con el caso más cargado.
4. **Lo repetido se ve repetido.** Cada cosa elegible es su propia opción: dos
   valores iguales son dos columnas (`ScoreMatrix`). Juntarlos parece un error
   porque falta una elección.
5. **Cada opción dice qué es, sin depender de un encabezado.** El valor va en
   todas las celdas, y el estado se distingue por algo más que el color: libre,
   tomada (en gris y con borde punteado) y elegida (rellena). La fila que falta
   se marca y el pie la nombra: decir qué hacer, no cuántas cosas faltan.
6. **En el teléfono, leer no obliga a elegir.** Sin panel al costado, tocar elige
   y un botón aparte abre el detalle en un diálogo (`AppDialog`).
7. **Probá con el caso difícil,** no con el cómodo: la clase con más cupos, la
   tirada con valores repetidos, el mago con todos sus conjuros. Los problemas de
   arriba no se veían con el ejemplo del lienzo.

**Movimiento.** Suave y eficaz, como pide `diseno-web.md` §10: nada aparece de
golpe, porque lo brusco se siente inacabado. Lo que aparece (un paso, un bloque
que abre una elección, el detalle) entra con `.step-in` (`index.css`, 160 ms de
opacidad y 4 px), y las opciones y la tira cambian de color en 120 ms. Solo CSS,
y se apaga con «reducir movimiento». Usá estas mismas clases en cualquier
pantalla nueva. Un paso nuevo tiene que remontar sus bloques: si son del mismo
tipo, lleva `key` con el paso.

El creador (`src/creation/CreationWizard.tsx`) suma dos piezas propias, que por
ahora solo usa él: la fila de clases (`ClassCard`, scroll horizontal) y la
matriz de características (`ScoreMatrix`: una columna por dado, así dos 14 son
dos columnas; una fila es una elección de una; la cabecera dice qué queda libre
y quién tiene cada dado; tocar uno ocupado los intercambia y el propio lo suelta;
mide su contenedor y debajo de 540 px apila cada característica en dos líneas).
En compra de puntos y a mano no hay dados: es `ScoreRow`, con −/+ o un campo. Conjuros muestra un cupo a la vez, en pestañas con su estado; en un teléfono cada
conjuro abre su detalle en un diálogo. Sus pasos de elecciones viven en
`src/creation/ChoiceSteps.tsx`; el catálogo de compras reusa `catalogRows` y
`FamilyFilter` de `src/sheet/ItemCatalog.tsx`, sin el diálogo de pago.

### Datos de personaje (`src/ui/data.tsx`)

| Componente | Qué hace | Cuándo |
| --- | --- | --- |
| `StatTile` | Placa de la banda táctica, **centrada**: ícono + rótulo arriba, cifra en sans negrita tabular con su `suffix` en la misma línea, `footer` a todo el ancho y `caption` debajo | Solo la banda táctica, dentro de `.tactical-band` (`index.css`): columnas fijas medidas con *container query*, PG más ancha, sin placas huérfanas. Con `onClick` toda la placa es un `button` con ícono `Info` en el rótulo (la Iniciativa abre su desglose) y deja de ser un par `dt`/`dd` |
| `StatPlaque` | Rótulo y valor en Georgia, centrado; `dense`. El rótulo puede ser un nodo (abreviatura visible, palabra completa para el lector) | Tiras cortas dentro de una tarjeta (CD, ataque de conjuro, CA/VEL/INIC de la tarjeta del dashboard) |
| `ShieldBadge` | La CA dentro de un escudo, con `aria-label` | **Solo CA**, y solo donde la CA es el tema (Defensa) |
| `Pill` | Cápsula de radio 20; `highlighted={false}` neutra, `danger` carmesí | Clase, subclase, nivel; `danger` solo para un estado malo (envenenado) |
| `Pips` | Usos restantes, llenos en oro; `label` dice la cuenta; `tone="crimson"` para lo que cuenta en contra | Recursos, espacios de conjuro; carmesí solo en los fallos de muerte |
| `SpendRecoverButtons` | Gastar y recuperar un uso: dos botones de ícono (−/+) con `aria-label` y tooltip; sin `onSpend`/`onRecover`, deshabilitado y en su lugar | Solo en la ficha propia (`model.write`), al lado de los `Pips` de cada espacio o recurso |
| `SpellSlotGrid` (`sheet/SpellSlots.tsx`) | Grilla de 3 columnas, una celda por nivel con el número y los `Pips` (la de pacto dice «Pacto, nivel n»; sin espacios, «Sin espacios»). Elige el nivel: filtra la lista de conjuros y decide qué espacio gasta `SpellSlotAction`. Es lectura, así que responde también en la ficha ajena | Tarjeta Conjuros de Combate |
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
| `Button`, `ButtonLink` | `primary` (oro lleno, uno por vista), `soft` (oro sobre `goldSoft` con filete: el verbo de una barra de herramientas), `secondary`, `danger` (carmesí, lo irreversible); `shape="pill"` en una fila de pills; `disabled` lo atenúa | `ButtonLink internal` navega sin recargar |
| `SaveStatusBadge` | La pill del guardado automático (`SaveStatusIndicator`): Guardando… / Guardado / No se guardó con «Reintentar» | Al pie del panel de una pantalla que escribe, en lugar de «Solo lectura» |
| `AppDialog` | El molde de diálogo: placa, velo, barra de acciones de 48 px al pie | 480 px por defecto, 560 si el cuerpo es una ficha; una acción con `disabled` se apaga (Comprar sin fondos) |
| `PortraitViewer` | El retrato original entero sobre el velo, con cerrar; `Esc` y clic afuera también cierran | Lo abre `Medallion` con `viewable` y la imagen de una entrada del Diario |
| `DiaryEntries` (`src/sheet/DiaryTab.tsx`) | Tarjeta de entradas en grilla (`minWidth`, 280 por defecto); con `edit` (un `DiaryEditor`: `save`, `remove`, `move`, `upload`) suma «+», editor, borrado y el ícono de mover | Sin `edit` es de solo lectura (ficha ajena, notas del PNJ) |
| `useReorder` (`src/ui/reorder.ts`) | Reordenar con el puntero (desde un ícono con `touch-action: none`) o con flechas; da `item(id)`, `grip(id)`, `dragging` y `over` | `onMove(desde, hasta)`; sin dependencias, lo reusa la lista de personajes (5f) |
| `src/api/portraits.ts` | `uploadPortrait(id, file)` (base64 de a pedazos) y `deletePortrait(key)` (un 404 cuenta como hecho) | Imágenes de retratos y del Diario; 5e9 las reusa |

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
- `BreakdownDialog` (`BreakdownDialog.tsx`): el «de dónde sale» de una
  característica o de la Iniciativa, en un `AppDialog` de filas rótulo / cifra
  (total en negrita, filete encima). Solo lista lo que trae `sheet`: no suma.
  Se abre también sin `write`.
- `InfoName` (`InfoName.tsx`): un nombre que, si tiene texto, es un botón con
  ícono `Info` que lo abre en un `AppDialog` (recursos, objetos). Sin texto es
  el nombre solo. Un texto que hay que poder leer en el teléfono no va en un
  `Tooltip`.
- `WarningsStrip` y `WarningsDialog` (`Choices.tsx`): las advertencias del
  motor, solo en la ficha propia, como una franja más de la banda táctica y solo en la pestaña Personaje. Con
  algún `warning` el borde y el ícono son carmesí; con solo `info` (cosas por
  elegir) van en oro. «Resolver» sale del mapa `code` → destino de
  `destinationOf`; un código sin destino no lleva botón.
- `ChoicesPage` (`Choices.tsx`, ruta `/elecciones?tab=`): `SpellTabs` con
  Rasgos, Competencias, Conjuros, Idiomas y Origen, solo las que tienen grupos.
  Los grupos se fijan al abrir (pendientes o reemplazables): uno que se
  completa sigue a la vista. Cada toque guarda una acción del motor, sin
  «Guardar» ni «Deshacer»; con el cupo lleno el pie dice por qué y no manda
  nada. El detalle va a la derecha desde 1024 px y en un `AppDialog` (botón
  `Info`) debajo.
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
