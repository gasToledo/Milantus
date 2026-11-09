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
| `Select` | Selección única con rótulo visible | El rótulo no desaparece al elegir; `className` sobre el botón (un formulario lo estira con `w-full justify-between`); `labelAbove` no lo repite adentro (lo pone quien lo usa arriba, el `aria-label` queda) |
| `Switch` | Encendido/apagado con rótulo | El pulgar se mueve: el estado no depende solo del color |
| `ScrollArea` | Zona con scroll propio y barra fina (las nativas toman el mismo tema desde `index.css`: `scrollbar-color` con el filete) | La usa el panel lateral; un texto que crece hasta un tope lo lleva en `viewportClassName`, con `label` para que se enfoque con el teclado y `type="auto"` para que la barra avise que hay más (el trasfondo) |
| `Toast` / `ToastViewport` | Avisos (`showAppMessage`) | Ícono, color y texto; error 6 s, el resto 3 s. `action` es el «Deshacer» (`onUndo`) y alarga a 6 s. `duration` gana sobre ese cálculo y `closeLabel` dibuja una X para descartarlo. **Una sola columna, en `Enabled`**: ninguna pantalla monta su `ToastProvider` ni su viewport (dos fijos en la misma esquina se pisan); solo dibuja su `<Toast>` |
| `LinkTabs` / `TabPanel` | Pestañas **que son URLs** | Flechas para moverse, Enter para abrir; cada pestaña es un enlace real |
| `Accordion` | Lista de entradas plegables (rasgos, dotes) | Varias abiertas a la vez; el botón va dentro de un encabezado |

## Biblioteca (`src/ui/`)

Equivalente a la de Flutter (`diseno-web.md` §8). Ningún componente calcula
una regla: reciben el número ya resuelto por `computeSheet`.

### Estructura

| Componente | Qué hace | Cuándo |
| --- | --- | --- |
| `Shell` | El marco: panel de 236 px fijo desde 900 px, barra con cajón debajo; el contenido ocupa todo el ancho (sin máximo). `panel` y `footer` son de cada pantalla | Toda pantalla. Sin `panel` ni `footer`, solo la marca (sin sesión, no disponible) |
| `NavGroup`, `NavItem` | Grupo con nombre (`nav`) e ítem del panel: ícono, rótulo, activo en oro sobre `goldSoft` con `aria-current` | `internal` navega sin recargar; `external` avisa al lector que abre Flutter y muestra el ícono de enlace externo; `count` lleva la cifra tabular a la derecha (oro si está activo), `badge` es el aviso que pide atención (objetos esperando en Inventario): círculo de oro de 18 px que con dos cifras se estira a píldora, `muted` atenúa la categoría sin coincidencias en el Códice y `onSelect` en vez de `href` lo vuelve un botón para una acción de la pantalla (Imprimir) |
| `SidebarBack` | El «Atrás» de una pantalla de adentro, con la forma del interruptor de modo. `onClick` con `preventDefault` frena la salida para confirmar | Ficha, creador |
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
| `SpellTabs` | La tira de pestañas de los conjuros (una por cupo, con su `Status`; con `plain`, solo el título, para vías alternativas como generar o subir un retrato): elegir una no cambia lo demás ni avanza sola; `badge` suma una cifra al título y `alert` el borde carmesí con ícono, ambos visibles con `plain` | Conjuros del creador y editor de la ficha |
| Bandeja de elegidos | Los elegidos como chips que se sacan con ✕ (`data-chip`), sobre la lista, en vez de un texto «Elegidos:». Uno elegido que ya no está en la lista también sale ahí, con su id si no está en el catálogo. Vive en `sheet/SpellEditor.tsx` y `sheet/MagicItemPlans.tsx`, no es un componente suelto | Editor de conjuros de la ficha |
| `WildShapeTile`, `WildShapeDialog` | La franja de Forma Salvaje en la banda táctica (`data-stat="wild-shape"`, con la estructura de `ActiveModeTile`) y su diálogo: las formas anotadas como `Option` de elección única, el perfil a la derecha (debajo de `lg`, un botón `Info` lo muestra dentro del mismo diálogo). Elegir no transforma. Vive en `sheet/WildShape.tsx` | Banda de Personaje y Combate de un druida |
| `CompanionsCard`, `SummonDialog` | La tarjeta de compañeros en juego (`data-card="companions"`, `data-companion="n"`): cada fila plegada de entrada, varias abiertas a la vez, con PG, CA, estados y perfil; «Invocar» (`data-action="summon"`) abre el diálogo: `Select` de opción si hay más de una, formas como `Option` (con más de 6, en `SearchableList`), pago con el uso gratis (`data-free`) y `SpellSlotGrid`, y el perfil a la derecha (debajo de `lg`, un botón `Info` lo muestra dentro del mismo diálogo). Avisos en oro entre el cuerpo y la barra. Vive en `sheet/Companions.tsx` | Combate, columna de PG y Defensa |
| `AmountControls` | El campo de cantidad con Daño, Curar y PG temp (`sheet/CombatTab.tsx`); recibe `id` y `dataControls` para que el personaje y cada compañero tengan el suyo. `ConditionToggleList` es lo mismo para los estados (`data-condition` o `data-companion-condition`) | PG de la ficha y de cada compañero |
| `CreatureProfile` con `compact` | La misma ficha de criatura sin tarjeta propia ni píldoras y con título de panel (`font-display text-[16px]`): para el panel derecho y el diálogo de Forma Salvaje. Se mide con `@container` y no con la ventana (las seis características van en una fila desde 520 px de su lugar) | Mostrar una criatura dentro de otra superficie |
| `WIZARD_ASIDE` | Las clases de la columna derecha: sigue a la vista al bajar y, si no entra, se desplaza sola | Panel derecho de cada asistente |
| `SearchableList` | Buscador sin tildes y por palabras (`matchesQuery`), cuenta y scroll propio; `groupOf` pinta un `Eyebrow` a todo el ancho al cambiar de grupo (los conjuros por nivel, sin grupos vacíos al buscar) y `empty` dice qué pasa si el filtro no deja nada | Listas largas: especies, trasfondos, armas |
| `StepRail` | La tira de pasos; `progress` la cambia en un teléfono por «Paso n de m» y una barra | Arriba de cada asistente |
| `WizardFooter` | El pie: lo que falta y Atrás/Continuar, como tarjeta flotante; `above` a todo el ancho; `danger` pinta el mensaje en carmesí | Abajo de cada asistente |
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
| `NpcStatusSelector` (`src/dm/npcs/`) | Vivo · Muerto · Desconocido en una fila de botones `aria-pressed`; el elegido se rellena con el color de su estado (`STATUS_FILL`) | El muerto atenúa identidad y tags, **nunca** el selector: un control usable no puede verse apagado |
| `CreatureForm` (`src/dm/npcs/`) | El formulario del bloque de una criatura: pestañas Lo básico, Rasgos y Acciones (`SpellTabs plain` con `badge` y `alert`), filas plegables (`data-row`, todas plegadas de entrada, varias abiertas) y la vista previa de `CreatureProfile` a la derecha (en un teléfono, «Ver» la abre en un diálogo). El motor arma la criatura y los errores (`creatureDraft`) | Errores desde el primer intento de guardar; salir con cambios pregunta. Lo reusa el Homebrew (7d1), con `saveFailedText` propio |
| `BackgroundEditor` (`src/sheet/DiaryTab.tsx`) | El trasfondo con Markdown: lectura, editor, importar y exportar `.md`; recibe `saved`, `ownerName`, `onSave` y `notify`, así que sirve a la ficha propia y a un PNJ | El borrador es local y `onSave` va espaciado (400 ms) y al salir |
| `NpcSpeechDialog` y `NpcTagDialog` (`src/dm/npcs/NpcTextDialogs.tsx`) | La voz (textarea) y un tag nuevo, este con los de la biblioteca como atajo | Una voz vacía la borra; un tag vacío no se manda |
| `PickManyDialog` (`src/dm/npcs/`) | Marcar varios (`Option multi`) y «Sumar n» sobre `AppDialog`, con buscador o sin él | Si falla no se cierra y el botón pasa a «Reintentar» |
| `NewNpcDialog` (`src/dm/npcs/`) | «Nuevo PNJ»: nombre, qué ficha lleva (`Option`: sin estadísticas, con bloque y «Personaje jugable» apagado con su motivo) y, si es un bloque, de qué criatura parte; crear abre la ficha | El documento lo arma el motor (`newNpc`). Si falla no se cierra y reintentar no vuelve a crear. «Bloque vacío» va fuera de la lista para que el buscador no lo esconda |
| `ExportNpcDialog` (`src/dm/npcs/`) | «Exportar PNJ» sobre `AppDialog`: el nombre en Georgia, dos filas fijas con tilde («Nombre, retrato, apariencia y voz» y la que cambia con el tipo) y tres `Option multi` (Trasfondo, Tags con los tags de detalle, Notas «Son de tus mesas.»). «Descargar .zip» espera el guardado del PNJ y de su ficha y baja el ZIP | Abre con trasfondo y tags marcados y notas no. Mientras trabaja dice «Preparando…» y nada se toca; si falla no se cierra, error en carmesí y «Reintentar». Si sale bien se cierra sin aviso |
| `ImportHomebrewDialog` (`src/dm/`) | «Importar homebrew» sobre `AppDialog`: el nombre del archivo, «Lo que trae · N entradas» (una fila por categoría con nombres recortados y cantidad), aviso carmesí si pisa lo propio y error del motor si el archivo no sirve | Siempre vista previa: el motor valida en el navegador y nada se escribe hasta «Importar». Si pisa lo propio el botón pasa a «Sobrescribir» carmesí; un archivo inválido deja «Importar» apagado; si falla el servidor queda abierto con «Reintentar» (guarda todo o nada) |
| `DeleteHomebrewDialog` (`src/dm/`) | «¿Borrar arma «X»?» sobre `AppDialog`: la lista de fichas de Mis personajes que la usan (`charactersUsing`, con su línea de clase), la advertencia, «Esta acción no se puede deshacer.» y «Borrar» carmesí | Espera a la lista de personajes con `AppBusyLabel`; si no se pudo leer lo dice y deja borrar igual. Si falla queda abierto con «Reintentar» |
| `DuplicateFromCatalogDialog` (`src/dm/`) | «Duplicar criatura», «Duplicar dote», «Duplicar especie» o «Duplicar trasfondo» (prop `category`): buscador y lista de lo del catálogo que **no** es propio, con la línea de tipo y el VD del motor (criaturas) o la categoría del Códice (dotes) | Tocar una cierra y abre el editor con la copia |
| `EffectEditor` y `AddEffectDialog` (`src/dm/homebrew/`) | La lista de efectos de una entrada propia (una fila con su frase, «Quitar efecto» con `Tooltip`, «Agregar efecto» secundario con `Plus`) y su diálogo de 460: «Tipo» y los campos que el motor declara para ese tipo (`Select`, número en sans negrita tabular rotulado con su unidad, casilla como `Option multi`, texto). La frase sale de `effectParts` + `describeEffectParts`; el efecto lo arma `effectBuild`, nunca React | Sin efectos dice «Sin efectos.»; un efecto que el motor no describe se lista por su `type` con «se conserva». `hiddenKinds` (lista de ids, constante) saca tipos del diálogo sin tocar los efectos ya cargados: `ItemForm` esconde `acBonus` y `resistance`, que tienen su campo. Cambiar el tipo repone los valores; «Agregar» con un error (rasgo sin nombre) marca el campo en carmesí y no cierra; Cancelar y Esc no tocan nada |
| `HomebrewFormShell` y `EntryPreview` (`src/dm/homebrew/`) | El armazón de los formularios del Homebrew con vista previa (dote, especie y trasfondo): cabecera, columna de secciones, «Así la ve el jugador» fija al costado (en un diálogo en pantallas chicas), pie Cancelar / Guardar con su mensaje, guardia de salida y `beforeunload`. `EntryPreview` es la ficha del Códice de lo que se arma | El formulario le pasa `dirty`, el mensaje y `onSave`; no sabe de reglas. `CreatureForm`, con pestañas, no lo usa. `ponytail:` en `HomebrewFormShell.tsx`: falta el panel de reglas por campo de Flutter |
| `FeatForm`, `RaceForm`, `BackgroundForm` y `HomebrewEntryEditorView` (`src/dm/homebrew/`) | Los editores de una dote, una especie, un trasfondo, un arma y una armadura propios, sobre `HomebrewFormShell`. El motor arma la entrada y los errores (`featDraft`, `raceDraft`, `backgroundDraft`) y las opciones cerradas con su rótulo (`homebrewFormOptions`); la vista previa es la ficha del Códice armada en vivo. La vista (nueva, copia `?de=<id>` o editar) es una sola para todas | Secciones siempre abiertas; el error sale en carmesí bajo su campo, solo después de un intento de guardar. Elecciones múltiples con `PillGroup` (`FilterPill` con `aria-pressed`): al marcar tres características las demás quedan `aria-disabled`, y una herramienta que el glosario no conoce se ve punteada con su id. La dote conserva el requisito, la especie y el trasfondo el emblema y el equipo inicial (se avisa). Ajena, inexistente u oficial en «editar» dice «No se encontró» |
| `WeaponForm` y `ArmorForm` (`src/dm/homebrew/`) | Los editores de un arma y de una armadura propias, sobre `HomebrewFormShell` y con `EconomySection` (peso y precio en cobre) de `homebrewFields`. El motor arma y valida (`weaponDraft`, `armorDraft`) y da las opciones (`homebrewFormOptions`). **Arma:** las propiedades son `PillGroup`; el dado versátil aparece con «Versátil» y el alcance con «A distancia» o «Arrojadiza» (o si ya traen valor); la maestría es un `Select` que empieza por «Sin maestría». **Armadura:** cambiar la categoría llama a `armorWithCategory`; «Suma modificador de DES» y «Desventaja en Sigilo» son `Option multi`; el escudo oculta «Cómo suma la Destreza» (lo guardado se conserva) y rotula la CA «CA que suma». **«En la ficha»:** bajo la vista previa de una armadura, una placa con dos celdas (`acExamples` del motor: «CA con DES +3» y «CA con DES +1», cifra en Georgia por ser valor de plaqueta); un escudo no la muestra | Mismos errores que las otras categorías (carmesí bajo el campo, tras intentar guardar). El Códice de armas suma «Mágica +N» cuando el bonificador no es 0, y lo ve también el jugador. Una categoría o un tipo de daño que el motor no ofrece se conserva como opción |
| `ItemForm` (`src/dm/homebrew/`) | El editor de un objeto propio, sobre `HomebrewFormShell`. El motor arma y valida (`itemDraft`) y da las opciones (`homebrewFormOptions`: categorías, rarezas, familias de objeto base). Fila de arriba: Categoría, «Peso (lb)» y «Precio (pc)». **Magia:** rareza (`Select` que empieza por «Mundano») y «Requiere sintonización» (`Option multi`); con «Mundano» la fila queda `aria-disabled` (`blocked`), sin efecto al tocarla, y dice «Solo los objetos mágicos se sintonizan.» (`itemWithRarity` también la desmarca). **Efectos mientras esté equipado:** bonificador a la CA (número en sans negrita tabular), resistencias como `PillGroup` y «Otros efectos» con `EffectEditor` y `hiddenKinds`; el motor junta las tres partes al guardar. **Objeto base:** familia (`itemWithBaseKind` vacía las bases), bonificador mágico y, con familia, «Bases permitidas» como `PillGroup` con «Sin marcar ninguna…» / «Solo se va a poder usar…» debajo. La vista previa es `itemEntry`: la ficha de equipo o de objeto mágico del Códice | Mismos errores que las otras categorías. Las cargas, la recarga, el paquete y la propiedad de base se conservan (con cargas, «Conserva las cargas del objeto original.»). «Objetos mágicos» y «Equipo» son dos categorías del Códice y un solo editor (`/dm/homebrew/objetos/…`); al guardar vuelve al detalle de la que corresponda. El Códice de objetos —también el del jugador— suma «Al equiparlo» (rasgos pasivos o efectos uno por línea) y el dato «Objeto base»; en un objeto propio no se corta la primera línea de la descripción |
| `HomebrewCreatureView` y `HomebrewCreatureActions` (`src/dm/`) | El editor de una criatura propia (el `CreatureForm` en rutas del Homebrew) y las acciones del perfil del Bestiario del DM: «Editar», «Duplicar» y «Borrar» en una propia, «Editar una copia» en una oficial | Una criatura ajena, inexistente u oficial en «editar» dice «No se encontró»; la copia se calcula una sola vez al montar |
| `showNotice` y `AppNotices` (`src/ui/notices.tsx`) | Un aviso que se dispara desde cualquier lugar (cola del módulo, dibujada junto a los demás avisos de la app) | Para el que sale de una acción que además navega: el `Toast` local se perdería al desmontarse la pantalla |
| `ImportNpcDialog` (`src/dm/npcs/`) | «Importar PNJ» sobre `AppDialog`: campo de archivo `.zip`, «Leyendo el archivo…» (`AppBusyLabel`), placa hundida con medallón, nombre, línea de tipo del motor, tags y lo que trae, aviso de contenido que falta (`npcImportMissing`) y `Select` de campaña opcional | Elegir el archivo pide la vista previa enseguida; con contenido que falta «Importar» queda apagado y no hay selector. Si falla la importación no se cierra y pasa a «Reintentar». Los errores se traducen por el `code` del cuerpo (`ApiError.code`), no por el mensaje |
| `AppDialog` | El molde de diálogo: placa, velo, barra de acciones de 48 px al pie | 480 px por defecto, 560 si el cuerpo es una ficha; una acción con `disabled` se apaga (Comprar sin fondos) |
| `PortraitViewer` | El retrato original entero sobre el velo, con cerrar; `Esc` y clic afuera también cierran | Lo abre `Medallion` con `viewable` y la imagen de una entrada del Diario |
| `PortraitWorkshop` (`src/sheet/`) | El taller de retratos: generar con IA, subir, volver a uno guardado y borrar. Recibe un `PortraitOwner` (nombre, rótulo del detalle, retratos, `buildPrompt`, `upload`, `saveBase64`, `apply`, `notify`) | Lo arman `PortraitPage` (ficha propia) y `NpcPortraitView` (PNJ). `buildPrompt` va memoizado en quien lo arma; `commitDetails` solo para el PNJ sin ficha |
| `NpcTableView` (`src/dm/npcs/`) | «Mostrar a la mesa»: retrato y nombre a pantalla completa sobre `bg-scaffold`, con ojo para ocultar el nombre y cerrar | Tapa el panel a propósito; muestra solo retrato y nombre. El marco no cambia de tamaño al ocultar el nombre |
| `DiaryEntries` (`src/sheet/DiaryTab.tsx`) | Tarjeta de entradas en grilla (`minWidth`, 280 por defecto); con `edit` (un `DiaryEditor`: `save`, `remove`, `move`, `upload`) suma «+», editor, borrado y el ícono de mover | Sin `edit` es de solo lectura (ficha ajena) |
| `useReorder` (`src/ui/reorder.ts`) | Reordenar con el puntero (desde un ícono con `touch-action: none`) o con flechas; da `item(id)`, `grip(id)`, `dragging` y `over` | `onMove(desde, hasta)`; sin dependencias, lo usa el Diario |
| `useHoldDrag` (`src/ui/holdDrag.ts`) | Reordenar tomando la tarjeta entera, sin ícono: con el mouse, apretando y moviendo 6 px; con el dedo, sosteniendo 350 ms, para que deslizar siga desplazando. La tarjeta sigue al puntero, las demás se corren y la ventana se desplaza cerca de los bordes; `Escape` cancela. Da `item(id)`, `dragging`, `over` y `animated` | `canDrop(desde, hasta)` y `onMove(desde, hasta)`; `group` (la fila lleva `data-reorder-group` y el hook mide solo las de su grupo: sin él, solo las que no tienen grupo, así el panel de música no se mezcla con las tarjetas de la Mesa) y `axis: 'y'` (`dx` queda en 0, para una lista con scroll propio). Con «reducir movimiento» nada sigue al puntero: se atenúa y se marca. Con teclado, `Alt` más una flecha sobre la tarjeta enfocada la mueve al vecino (`canDrop` manda) y no dibuja nada |
| `RosterCard` (`src/dashboard/`) | La tarjeta de personaje: el nombre es el enlace y se estira con `::after`; a la derecha del nivel, el menú ⋮ de 40 × 40 (favorito, renombrar, rehacer, borrar). Se mueve tomándola entera (`useHoldDrag`) | El ⋮ lleva `relative z-10` o el enlace estirado lo tapa; el favorito y la lista filtrada no se mueven |
| `MusicSceneDialog` (`src/dm/`) | Crear o editar una escena de música sobre `AppDialog`: nombre, enlace y `Switch` «Ofrecerla al iniciar un combate». Con cada tecla, `musicSource` dice qué reconoció (tilde verde y «Video/Lista de YouTube») | Los errores aparecen al guardar y se apagan al escribir; un enlace no reconocido no se guarda. Enter en el enlace guarda; si `onSubmit` falla no se cierra y pasa a «Reintentar» |
| `AddCombatantDialog` (`src/dm/combat/`) | «Sumar al combate» sobre `AppDialog` de 820: `Segmented` PNJ / Bestiario y dos columnas (`lg:grid-cols-[minmax(0,1fr)_300px]`; en teléfono se apilan). Elegir solo llena el panel (`.plaque`); el botón de sumar está en la barra del diálogo (`closes: false`) y queda abierto, con una línea verde `role="status"` de lo último sumado. Las dos pestañas viven siempre: cambiar no pierde lo elegido | Un PNJ de la biblioteca o «Volvió» vinculan primero; si falla no se suma y el botón pasa a «Reintentar». El bando de un PNJ no tiene valor por defecto; sin estadísticas es neutral y fijo |
| `SideSelector`, `Segmented` (`src/dm/combat/SideSelector.tsx`) | Fila de botones `aria-pressed` con el aspecto `.seg` de la maqueta: `Segmented` es genérico (las pestañas del diálogo) y `SideSelector` es Aliado · Enemigo · Neutral encima de él. `value` `null` es «sin elegir» | `disabled` apaga los tres (PNJ sin estadísticas) |
| `DifficultyBand` (`src/dm/combat/`) | La dificultad del combate que se arma, en una `plaque`: veredicto a la izquierda (nombre del tier en `font-display`, carmesí solo si es Extrema), la regla del presupuesto al centro (`role="img"`, escala `highBudget × 1.25`, tres marcas con «Baja» a la derecha de la suya y las otras a la izquierda) y los PX a la derecha; debajo, un aviso por filete (`TriangleAlert` o `Info`). No calcula: recibe `EncounterDetails['difficulty']` | Solo mientras se arma, y si la cuenta lo permite |
| `RollInitiativeDialog` (`src/dm/combat/`) | «Tirar iniciativa»: `AppDialog` de 660 con dos columnas (Jugadores, Monstruos y PNJ) y un campo de 60 px por fila. Los monstruos y PNJ traen la tirada propuesta por el motor; un jugador, el campo vacío y su `d20 + n`. Un campo vacío o con solo «-» lleva `border-gold` y apaga «Empezar» | Al empezar el combate |
| `SideMenu` (`src/dm/combat/`) | La pill de bando de una fila de la planilla. Con `canChangeSide`, un `DropdownMenu` de tres `DropdownMenuRadioItem` cuyo disparador es la pill (`aria-label` «Bando de …»); sin él, la pill con un `Tooltip` «neutral fijo». Un jugador no lleva pill | Armando y en curso |
| `NumberPromptDialog` (`src/dm/combat/`) | `AppDialog` de 360 con un campo numérico (`title`, `label`, `initial?`, `onSubmit`, `onClose`): un `-` adelante y dígitos, Enter guarda, «Guardar» apagado mientras no sea un número. Exporta `NUMBER_FILTER` e `isWholeNumber` | Corregir la iniciativa y sumar tarde a un jugador en el combate en curso |
| `EffectsDialog` (`src/dm/combat/`) | `AppDialog` de 520, borrador local: Tiradas (Normal · Ventaja · Desventaja, `aria-pressed`, verde y carmesí rellenos), Defensas en dos columnas (PG temporales con `data-field="effects-temp"`, que en un jugador es solo lectura, y bono a la CA con vista previa que calcula el motor vía `previewAc`) y, tras un filete, efectos escritos y condiciones del libro. Guardar manda solo lo que cambió | Botón de efectos de cada fila |
| `EndCombatDialog` (`src/dm/combat/`) | `AppDialog` de 480, con un `Option multi` por PNJ caído, desmarcado al abrir. Acciones en orden: Cancelar, Descartar sin guardar (carmesí) y Terminar y guardar (verde). Si falla, muestra el error y la acción elegida pasa a «Reintentar» | Placa de la ronda y aviso de bando vencido |
| `ConvertNpcDialog` (`src/dm/combat/`) | `AppDialog` de 480, con el nombre actual editable y «Cancelar» y «Convertir». Si falla, conserva el nombre y ofrece «Reintentar» cuando la fila sigue disponible | «Convertir en PNJ…», debajo de los bandos de un monstruo con perfil |
| `HpBar` (`CombatView.tsx`) | `ThinBar` con los temporales pegados en oro: carmesí `actual/(máx+temp)`, dorado `temp/(máx+temp)`; `role="meter"` | PG de la planilla del combate |
| `conditions.ts` (`src/dm/combat/`) | `conditionOfTag` (id de la condición de un tag, en español o inglés), `tagLabel` (cómo se muestra) y `storedLabel` (se guarda siempre la etiqueta en español) | Efectos del combate |
| `TurnProfile` (`src/dm/combat/`) | El perfil de quien tiene el turno. Props opcionales: `profile` (sin él no hay rasgos ni acciones), `title` y `typeLine` (un PNJ lleva los suyos y no muestra procedencia), `titleExtra` (junto al nombre), `side` (entre la línea de tipo y las placas) y `children` (la voz y el trasfondo, entre el bando y las placas) | «Del turno» del combate en curso |
| `ConfirmDialog` (`src/ui/`) | Confirmar algo irreversible sobre `AppDialog`: `title`, `body` (con párrafos), `confirmLabel`, `errorText`, `onConfirm`. Con el patrón de `DeleteDialog`: si falla no se cierra y el botón pasa a «Reintentar» | Borrar campaña y echar de la mesa; `DeleteDialog` y `ShareDialog` aún tienen el suyo |
| `RenameDialog`, `DeleteDialog` (`src/dashboard/`) | «Editar nombre» y «¿Borrar a …?» sobre `AppDialog`; reciben una promesa y, si falla, **no se cierran**: error en carmesí y «Reintentar» | Los usan la lista y la ficha (el lápiz junto al nombre, solo en la ficha propia) |
| `patchSettings` (`src/api/settingsSave.ts`) | Cambia campos de `/api/settings` sin pisar el resto: cola de un guardado a la vez que combina parches | Todo guardado de ajustes pasa por acá; el documento viaja entero |
| `createSaveQueue` (`src/api/saveQueue.ts`) | La cola de un documento que se guarda entero: 400 ms de espera, un solo envío en vuelo por clave, lo fallido se conserva para `retry` y `drop` olvida lo pendiente antes de borrar. Devuelve `schedule`, `latest`, `retry`, `flush` y `drop` | Una instancia por tipo de documento: `npcSave.ts` (PNJ) y `dm/combat/encounterWriter.ts` (el combate, por campaña). La ficha propia tiene la suya (`characterSave.ts`) |
| `src/api/portraits.ts` | `uploadPortrait(id, file)` (base64 de a pedazos) y `deletePortrait(key)` (un 404 cuenta como hecho) | Imágenes de retratos y del Diario; 5e9 las reusa |

## Datos

`src/api/queries.ts` tiene un `useQuery` por recurso (`useAccount`,
`useRoster`, `useRosterSettings`, `useCatalog`, `useThemeMode`,
`useAppVersion`). Un 4xx no se reintenta; un 5xx o la red, dos veces más. El
catálogo no vence nunca. Toda pantalla pasa por ahí: la caché es lo que hace
que ir del dashboard a la ficha no vuelva a pedir nada.

## Navegación

Los enlaces «Atrás» usan `Link back`. Vuelven a la pantalla desde la que se
entró, con su URL completa. Cambiar de pestaña dentro de una ficha conserva ese
origen y deja cada pestaña en el historial del navegador. Si se entró por URL
directa, el `href` del enlace indica el destino de respaldo.

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
- `PortraitPage` (`PortraitPage.tsx`, ruta `/personajes/:id/retrato`, solo ficha
  propia): a la izquierda el retrato grande 3:4 con escuadras doradas (o el
  medallón con la inicial si no hay), nombre y línea de especie y clase; la tira
  de resultados con «Usar este retrato»; la de guardados (tocar **solo mira**) y,
  sobre el guardado mirado, «Volver a este retrato», «Prompt usado» y «Borrar».
  A la derecha, `SpellTabs` en variante `plain` (sin estado por pestaña) con
  «Generar con IA» y «Subir imagen»; sin proveedores solo la segunda. Cada
  acción deja la pantalla abierta y avisa con un toast. Generar vela el retrato
  grande con un spinner y apaga los botones; el aporte propio del jugador se
  pinta en oro dentro del prompt automático.
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
  y el detalle trae «Atrás», con la lista como destino de respaldo.
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

Dos `Card` en una grilla que se adapta sola (`auto-fit`). «En este navegador»
usa `Select` para el tema local y el idioma. «En tu cuenta» usa `Select` para
el modo de inicio y el tema, y `Switch` para la dificultad del encuentro.
Cada cambio de cuenta muestra el estado del guardado. El orden y el favorito
se muestran en una lista de definición (`dl`) y se editan en Mis personajes.

### Compartir, avisos y turno

- `ShareDialog` (`src/sheet/`): el diálogo de Compartir, sobre `AppDialog` con una sola acción («Cerrar»). El aviso de «copiado» va **en el botón** y el de «ya no se comparte» debajo de la lista: un aviso flotante queda detrás del velo. Cortar un vínculo abre un segundo `AppDialog` con el patrón de `DeleteDialog`: si falla no se cierra y el botón pasa a «Reintentar».
- `PendingEvents` (`src/events/`): la cola de avisos al entrar a la lista, al Modo DM o a una ficha, de a uno y marcados vistos al mostrarse. Se monta una vez, en `Enabled`.
- `TurnBanner` (`src/sheet/`): región `role="status"` siempre montada, para que el lector anuncie el cambio; dibuja la franja solo con `next` o `active`. Nunca muestra el orden ni quién sigue.

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

En el Modo DM, el encabezado del perfil lleva «Sumar al combate de
{campaña}». Abre un `AppDialog` de 440 px con la criatura ya elegida y los
mismos controles de cantidad, PG y bando que usa Combate (`MonsterQuantity`).
Arranca con una copia enemiga y los PG promedio del libro. El aviso de
guardado confirma la tanda desde el perfil.

## El Modo DM (`src/dm/`)

La oferta de música (6g7a) es una `card` encima del reproductor flotante de
360 px, con el mismo ancho y margen al borde. Incluye un `Eyebrow`, la pregunta
y botones que se envuelven. Con una escena el botón dice «Poner», con varias
cada botón lleva el nombre de la escena. «Ahora no» es secundario. La oferta
no toma el foco ni bloquea el combate.

Cada sección es una ruta bajo `/v2/dm/campanas/:id/` (el Bestiario, la Biblioteca de PNJ y el Homebrew, herramientas de la cuenta, bajo `/v2/dm/bestiario`, `/v2/dm/pnj` y `/v2/dm/homebrew`) y comparte tres piezas:
`DmPanel` (el panel: interruptor, herramientas, campañas, secciones),
`DmHeader` (título Georgia 30, pill con el estado, `actions` a su derecha y la regla ornamental; el
`h1` es el título) y `DmPage`, que resuelve la campaña por id y es la única que
sabe distinguir «cargando», «error» y «no se encontró» (una campaña ajena y una
inexistente son la misma pantalla). Desde 6b escribe campañas y la Mesa y desde 6c capítulos, notas y el reparto de objetos (abajo); lo demás sigue de solo lectura.

- **Mesa** (`MesaView`, `MemberCard`): las tarjetas se mueven tomándolas enteras (`useHoldDrag`, con las clases de `RosterCard`; el orden es `Campaign.memberOrder`, que `editCampaign` guarda releyendo la campaña y la caché cambia al instante). Grilla `auto-fill` de tarjetas con
  `toRosterEntry` (`dashboard/roster.ts`, la misma cuenta que el dashboard). La
  CD sale de los bloques de lanzamiento del motor y, con varias clases
  lanzadoras, se muestran todas.
- **Escritura de 6b**: `CampaignEditorDialog` (nombre, premisa y `Select` de
  estado con `className="w-full justify-between"`; sin nombre no cierra y, si
  `onSubmit` falla, queda abierto con «Reintentar»), `CampaignMenu` (el ⋮ de 44 × 44
  con Editar y Borrar, solo en Mesa, Capítulos y Cuaderno), `DmOnboarding` (la
  bienvenida sin campañas: tres pasos y «Crear campaña»), `AddMemberDialog` (campo del
  código centrado, 18 px y mayúsculas; un 404 dice «Código inválido o vencido» y
  conserva el código) y `MemberCard` con `actions`: un ⋮ de 40 × 40 con `relative z-10`
  (conceder Inspiración Heroica, echar). Las acciones son sobre el vínculo y los
  avisos, nunca sobre la ficha del jugador.
- **Capítulos** (`ChaptersView`): lista ordenada de tarjetas `card`; el abierto
  lleva `border-2 border-gold`, el estado va en una pill con el color del estado
  (oro, apagado, neutro) y lo que reparte en `StatPlaque`. Cada tarjeta tiene un
  ⋮ de 40 × 40 (`chapter-actions`: «Editar», salvo cerrado, y «Borrar»), «Empezar»
  o «Cerrar capítulo» según el estado, y el enlace «Ver en el Cuaderno».
- **Escritura de 6c**: `ChapterEditorDialog` (el estado no se edita: guarda
  `{ ...capítulo, cambios }` y nunca manda `completed`; lista de objetos con − y +),
  `NoteEditorDialog` (`Select` de capítulo con el rótulo adentro), `ItemPicker`
  (`AppDialog` con buscador, `FamilyFilter` más «Propios» y filas de `catalogRows`;
  agregar no cierra y la fila pasa a «Agregado»; solo se entrega lo que existe, sin texto libre (los capítulos viejos que lo tienen lo conservan como «Sin catálogo»); una plantilla pide base con el
  `BaseDialog` de `MagicItemPlans`, que acepta `exclude` para no ofrecer el
  homebrew) y `ChapterItemsField` (la lista de objetos con cantidad, quitar y «Agregar objeto» que comparten el editor de capítulos y `GiveItemDialog`), `GiveItemDialog` («Dar objeto a …» desde el ⋮ de `MemberCard`, con «Dar» apagado sin objetos) y `CloseChapterDialog` (como `ConfirmDialog` pero con el botón en oro
  y sin ícono de alerta; un chip `aria-pressed` por personaje en cada objeto,
  nada marcado de entrada, y apagado con `dmCloseMissing` si falta alguien).
  `ItemGrants` es la tarjeta «El DM te dio» de Inventario (`data-card="item-grants"`),
  solo en la ficha propia. `CatalogRow` (`sheet/ItemCatalog.tsx`) suma `category`
  (`weapons`, `armor` o `items`, la lista donde vive) y `homebrew`
  (`source === 'homebrew'`); quienes ya lo usaban no cambian.
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
  Georgia 28 con su lápiz, la línea de tipo en `Pill` oro y los tags neutros
  con su ✕ y un «Tag» al final, la voz como cita con la comilla en oro y su
  lápiz) y debajo dos columnas: Trasfondo (`Card`) y Notas
  (`DiaryEntries`, el mismo de la pestaña Diario, a dos columnas) a la izquierda,
  Estadísticas y Campañas a la derecha; la tarjeta de un PNJ de bloque termina con
  «Editar bloque» (`soft`, `data-action="edit-block"`), que abre el editor. En Campañas, cada una lleva su
  `NpcStatusSelector` y la tarjeta un «Sumar» (`PickManyDialog` con las campañas
  que faltan). «Nuevo PNJ» es la acción primaria (`Button` oro lleno) de la
  cabecera —o del estado vacío, nunca en los dos—, y un ⋮ de 44 px en la
  cabecera de la ficha lleva «Borrar PNJ» (con confirmación; es la única opción
  por ahora y deja lo irreversible a un paso). La
  línea de tipo la arma `npcTypeLine` con lo que da `npcViews`: ningún número se
  calcula acá. El tablero es «Modo DM — Biblioteca de PNJ, PNJ de la mesa,
  Homebrew y Combate» del Design.
- **PNJ de la mesa** (`npcs/CampaignNpcsView`): la grilla `auto-fill` de `card`
  de 280 px con la misma `FilterPill` de tag que la Biblioteca (exportada de
  `NpcLibraryView`) y el conteo por estado a su izquierda. La tarjeta no es un
  enlace entero: lo es la identidad (medallón de 36 y nombre), porque así es en
  Flutter, donde el resto de la tarjeta lleva controles. El estado va al pie con
  `NpcStatusSelector`; un muerto se tacha y atenúa en identidad y tags, no en el
  selector. Un ⋮ de 44 px abre la ficha o quita de la campaña (con confirmación),
  y «Traer de la biblioteca» (`soft`) y «Nuevo PNJ» (primaria) van en la cabecera
  —o en el estado vacío, nunca en los dos—.
- **Homebrew** (`HomebrewView`): la portada repite las tarjetas de la portada del
  Códice (ícono, nombre, cifra y muestra), atenuadas cuando la categoría está
  vacía, con un buscador en pill que reemplaza la grilla por una lista de
  resultados. Una categoría monta `CategoryView` del Códice, exportada con dos
  props que usa el Homebrew: `header` (la cabecera del Modo DM en lugar del `h1` del
  Códice), `hrefOf` (las URL de cada entrada) y, desde 7d1, `detailActions`
  (`(entrada) => ReactNode`: los botones arriba a la derecha de la ficha abierta;
  «Borrar», y desde 7d2a, en una dote propia, «Editar» y «Duplicar» a su izquierda;
  7d2b–7d4 suman los de las demás). La cabecera de Dotes suma «Duplicar del
  catálogo» (`DuplicateFromCatalogDialog`) y «Nueva dote». El Códice no la pasa y
  su ficha no cambia. No hay una segunda ficha: una entrada nueva
  del catálogo se ve igual en los dos.
- **Combate** (`CombatView`): mientras se arma, la placa suma a la derecha «Sumar al combate» (`soft`) y «Descartar combate» (`secondary`, con `ConfirmDialog`), la planilla es de seis columnas (`LEDGER`) y bajo ella una `plaque` lista a los jugadores que faltan. Entre la placa y la planilla va `DifficultyBand` (y cada fila con PX los antepone a su línea: «25 PX ·», «−25 PX ·» si es aliado), ambos solo si la cuenta tiene prendida `showEncounterDifficulty`; en la cabecera, «Tirar iniciativa» (`Button` con `Dices`, `data-action="roll-initiative"`) abre `RollInitiativeDialog` y empieza el combate. Cada fila lleva `SideMenu` y una X que saca sin confirmar; un jugador, además, «Abrir ficha» (o «En su ficha» si ya no está en la mesa). **En curso (6g4)**: la placa de la ronda suma a la derecha el mismo «Sumar al combate» y, a su lado, «Siguiente turno» (`Button` primario con `SkipForward`, `data-action="next-turn"`); «Abrir ficha» es una pill con borde oro, no texto suelto; los jugadores que faltan van en la misma `plaque` como «Se sumaron tarde», sin «Sumar a todos» y con `NumberPromptDialog` para su iniciativa. Una placa (`plaque`) con ronda, turno y en pie, y
  debajo la planilla en `card` con **una sola grilla de seis columnas** (`LEDGER`, cabecera; `ROW`, fila) armando y en curso. Es `@container`: desde 760 px de ancho **de la planilla** (no de la ventana) es la grilla de la lámina; debajo, cada fila se parte como la lámina «Teléfono» (tres columnas: iniciativa, nombre y CA arriba, PG y efectos en `col-span-2`, acciones en una línea propia con botones de 48 px), la cabecera no se dibuja y no hay desplazamiento de costado. En curso, las dos últimas columnas de la cabecera llevan la **cifra de daño o curación** (`AmountControl`: campo de 52 px, solo dígitos, hasta tres, y los atajos 1, 5 y 10; es una sola para todo el combate, `data-field="amount"`; con la fila partida va en su propia barra sobre las filas). Cada fila con PG (menos un jugador y un PNJ sin estadísticas) lleva −n y +n (`data-action="hurt"` y `"heal"`), la iniciativa es un botón que abre `NumberPromptDialog` (`data-action="fix-initiative"`) y la fila activa se lleva la vista cuando cambia el turno. La línea de un jugador antepone su Forma Salvaje y los modos activos. El turno es una barra
  verde al filo izquierdo de la fila sobre `goldSoft` (no un borde alrededor) y
  la palabra bajo la iniciativa; lo ya jugado atenúa sus datos pero **no sus botones** (se le sigue pegando, y un botón gris se lee como apagado), y un caído se tacha y se atenúa entero; una fila con marcas (ventaja, temporales, bono a la CA) o con legendarias no se atenúa aunque haya jugado. **6g5**: junto al nombre, la pill rellena de ventaja (verde) o desventaja (carmesí); los temporales, `+N` dorado tras los PG con `HpBar`; el bono a la CA, el total en oro con un `Shield` y `base +bono` debajo; cada efecto es una chip con su ✕; el botón `Tag` (`data-action="effects"`, dorado y relleno si hay algo) abre `EffectsDialog`; y bajo el nombre, las marcas legendarias (`data-legendary`). Los PG van en carmesí con `HpBar`, y el bando en una pill con la palabra
  (verde, carmesí, apagado). «Del turno» va a la derecha, en una sola `card`:
  para un monstruo o un PNJ, `TurnProfile` (`dm/combat/`), como la lámina «Jugando»:
  «Le toca ahora» en verde, nombre y procedencia (un PNJ no la lleva y suma el
  enlace a su ficha), la línea de tipo, el bando (`SideSelector`, o «Neutral · sin
  estadísticas»), la voz y el trasfondo de un PNJ, tres placas
  de la mesa (Inic y CA de 56 px, PG con el resto) y solo rasgos y acciones,
  con lo que se tira en chips chicos. No es el perfil del Bestiario achicado: sus
  características y su banda de cifras no entran en 300 px, y los PG del libro
  dejan de ser ciertos en el primer golpe. La card lleva arriba dos solapas (`role="tablist"`): «Del turno» y «Efectos», con todos los efectos de la mesa y una ✕ de 44 × 44 por cada uno; la elegida lleva borde oro, color **y** negrita.
  **6g6**: la placa muestra «Sumar al combate», «Terminar combate» (`soft`, `CheckCheck`, `data-action="finish-combat"`) y «Siguiente turno» primario, en ese orden. Si un bando se queda sin nadie en pie, entre la placa y la planilla va un aviso con borde oro. Su texto y su botón primario «Terminar combate» (`data-action="finish-combat-banner"`) pueden pasar a líneas separadas. El botón de la placa y el del aviso abren `EndCombatDialog`.

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
