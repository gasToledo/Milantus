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
| `ScrollArea` | Zona con scroll propio y barra fina | La usa el panel lateral |
| `Toast` / `ToastViewport` | Avisos (`showAppMessage`) | Ícono, color y texto; error 6 s, el resto 3 s. Sin uso hasta que React escriba |
| `LinkTabs` / `TabPanel` | Pestañas **que son URLs** | Flechas para moverse, Enter para abrir; cada pestaña es un enlace real |
| `Accordion` | Lista de entradas plegables (rasgos, dotes) | Varias abiertas a la vez; el botón va dentro de un encabezado |

## Biblioteca (`src/ui/`)

Equivalente a la de Flutter (`diseno-web.md` §8). Ningún componente calcula
una regla: reciben el número ya resuelto por `computeSheet`.

### Estructura

| Componente | Qué hace | Cuándo |
| --- | --- | --- |
| `Shell` | El marco: panel de 236 px fijo desde 900 px, barra con cajón debajo; el contenido ocupa todo el ancho (sin máximo). `panel` y `footer` son de cada pantalla | Toda pantalla. Sin `panel` ni `footer`, solo la marca (sin sesión, no disponible) |
| `NavGroup`, `NavItem` | Grupo con nombre (`nav`) e ítem del panel: ícono, rótulo, activo en oro sobre `goldSoft` con `aria-current` | `internal` navega sin recargar; `external` avisa al lector que abre Flutter |
| `SidebarBack` | El «volver» de una pantalla de adentro, con la forma del interruptor de modo | Ficha |
| `ModeSwitch` | «Jugador / DM» | Menú principal. «DM» lleva a Flutter |
| `ThemeMenu`, `VersionLabel` | Selector de tema y versión, al pie del panel | Los dos pies |
| `Card` | Tarjeta de sección (`sheetCard`): ícono dorado, título Georgia 16, `trailing`; `collapsible` la pliega | Toda sección de la ficha. `id` único por pantalla |
| `SectionRule` | Filete con rombo dorado | Separar bloques dentro de una tarjeta |
| `Eyebrow` | Rótulo de sección en mayúsculas espaciadas | — |

### Datos de personaje (`src/ui/data.tsx`)

| Componente | Qué hace | Cuándo |
| --- | --- | --- |
| `StatTile` | Placa de la banda táctica: ícono + rótulo, cifra en sans negrita tabular, `suffix` y `footer` | Solo la banda táctica. Va dentro de un `<dl>` |
| `StatPlaque` | Rótulo y valor en Georgia, centrado; `dense` | Tiras cortas dentro de una tarjeta (CD, ataque de conjuro) |
| `ShieldBadge` | La CA dentro de un escudo, con `aria-label` | **Solo CA**, y solo donde la CA es el tema (Defensa) |
| `Pill` | Cápsula de radio 20; `highlighted={false}` neutra | Clase, subclase, nivel |
| `Pips` | Usos restantes, llenos en oro; `label` dice la cuenta | Recursos, espacios de conjuro |
| `ThinBar` + `hpTone` | Barra fina (`role="meter"`, con `aria-label` y valor); `hpTone` da verde/oro/carmesí según el cociente de PG (`AppPalette.hpColor`) | PG |
| `Medallion` | Aro del color de clase con la inicial | Tarjeta y panel |
| `Seal` | El sello de la marca | Solo la marca |

### Estados y acciones

| Componente | Qué hace | Regla |
| --- | --- | --- |
| `AppBusyLabel` | Spinner + texto, región viva | El texto es obligatorio |
| `AppErrorView` | Ícono, título, mensaje, detalle copiable y «Reintentar» | `onRetry` siempre que reintentar pueda arreglarlo; `as="h1"` si ocupa la pantalla |
| `AppEmptyState` | «No hay nada» (`empty`) o «nada coincide» (`no-match`), con ícono distinto | Son situaciones distintas y piden acciones distintas |
| `Notice` | Pantalla de un solo mensaje con su `h1` | Sin sesión, no disponible, no encontrado |
| `Button`, `ButtonLink` | `primary` (oro, uno por vista), `secondary`, `danger` (carmesí, lo irreversible) | `ButtonLink internal` navega sin recargar |
| `AppDialog` | El molde de diálogo: placa, velo, barra de acciones de 48 px al pie | 480 px por defecto, 560 si el cuerpo es una ficha |

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
  catálogo con homebrew. Todo componente de la ficha recibe solo eso.
- Desde 900 px las pestañas viven en el panel (`NavItem` con `aria-current`);
  debajo, como `LinkTabs` arriba del contenido, para no tener que abrir el
  cajón. El panel de la pestaña se monta una sola vez.
- Columnas: `COLUMNS` (`CharacterTab.tsx`), tantas de 300 px como entren y una
  en un teléfono, con `items-start`.
- Rótulos que necesitan vocabulario del motor (la característica de cada
  habilidad, si un conjuro es una reacción) salen de `vocabulary.ts`, que
  copia el enum del motor y lo dice; ningún número sale de ahí.

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
