# Guía de Diseño Web — Milantus, Asistente de Aventuras

Estado: guía vigente de la aplicación web.

El **lenguaje visual** de Milantus: dirección de arte, marca, color,
tipografía, forma, layout, movimiento y accesibilidad. Cómo se aplica en
`packages/dnd_web` y cuál es la pieza de `src/ui/` para cada cosa está en
[Diseño web en React](diseno-web-react.md); esta guía no lo repite.

> **Regla de oro**: cada valor de acá sale del código (`src/index.css` para los
> tokens). Si el código y esta guía discrepan, gana el código y la guía se
> corrige.

## Cómo usar esta guía

**Si diseñás o revisás pantallas**: leé [Dirección de arte](#2-dirección-de-arte),
[Color](#3-color), [Tipografía](#4-tipografía) y
[Anti-patrones](#12-anti-patrones), y después el catálogo de componentes de
[Diseño web en React](diseno-web-react.md).

**Si generás propuestas o código de UI**: los tokens están en el
[Apéndice B](#apéndice-b--equivalencia-en-css). Usá esos valores literales; no
inventes intermedios ni «aproximaciones de marca». Las prohibiciones duras están
en [Anti-patrones](#12-anti-patrones).

### Flujo de un cambio visible

1. Leer la pantalla, los componentes compartidos y las pruebas afectadas antes
   de proponer el cambio.
2. Contrastar la propuesta con esta guía y reutilizar componentes y tokens
   existentes antes de crear otros.
3. Mantener las reglas de D&D en `dnd_engine`: la UI recibe resultados de
   `computeSheet` y se limita a presentación y orquestación.
4. Contemplar tema oscuro y claro, estado vacío, texto largo y los anchos de
   [Layout](#7-layout-y-responsividad), desde un teléfono de 360 px.
5. Validar como pide `CLAUDE.md` (tipos, build, e2e afectadas) y pushear a
   `main`.
6. Seguir CI y CD hasta el final y mirar el cambio en la web desplegada: un
   build local exitoso no sustituye la revisión visual.

---

## 1. Stack del frontend

React + Vite + TypeScript + Tailwind en `packages/dnd_web`, con primitivas
accesibles de Radix UI e íconos de `lucide-react`. El detalle (versiones,
envoltorios, datos) está en [Diseño web en React](diseno-web-react.md). Las
reglas de D&D no viven en el cliente: llegan del motor compilado a JS.

---

## 2. Dirección de arte

**Híbrido: base oscura moderna + heráldica de fantasía.**

La aplicación es una herramienta de mesa que se usa durante horas, muchas veces
en penumbra. La lectura manda sobre la ambientación. La fantasía entra por
**acento y ornamento discreto** —oro heráldico, siluetas de escudo, un rombo
como separador— nunca por textura, ruido, pergamino simulado ni tipografías
góticas.

Los cuatro compromisos que definen el estilo:

1. **El oscuro es el tema prioritario y el que arranca.** El claro existe y es
   completo, pero es la variante.
2. **Superficies planas, jerarquía por borde.** La profundidad se comunica con
   una línea de 1 px (`hairline`) y con un fondo más hundido (`plaque`), no con
   sombras. La única sombra del sistema es la de *hover* de la tarjeta de
   personaje.
3. **El oro es información, no decoración.** Marca lo activo, lo seleccionado y
   los números clave (CA, características, recursos). Si algo está en oro y no
   es ninguna de esas tres cosas, está mal.
4. **Densidad alta, tipografía tranquila.** Una ficha de D&D es una tabla de
   números. Se privilegia ver mucho de un vistazo antes que respirar.

### Vocabulario visual propietario

Cuatro formas son marca del producto y hay que reusarlas en vez de inventar
equivalentes:

- **El sello**: el logotipo, en [La marca](#la-marca-el-sello).
- **El rombo** (cuadrado rotado 45°): separador ornamental y los cuatro puntos
  cardinales del sello.
- **El escudo**: silueta que contiene la Clase de Armadura, y solo la CA.
- **El medallón**: círculo con aro dorado de 2 px para retratos y emblemas. El
  sello no es un medallón: los rombos del aro son lo que los distingue.

### La marca: el sello

El logotipo de Milantus es **el sello**: un aro de oro con un rombo en cada
punto cardinal y una M de esquinas vivas adentro. Junto al nombre y al
subtítulo forma el logotipo completo de la cabecera del panel.

**Por qué esta forma.** Salió de relevar las marcas de las herramientas de
D&D (D&D Beyond, Roll20, Foundry, Nivel20, World Anvil, LegendKeeper y otras).
Casi todas se apoyan en un d20, en el rojo, o en los dos; el rojo además es el
de D&D, y acercarse a él es acercarse a una marca ajena. Las que no, se reparten
entre la estética de software con colores eléctricos y la fantasía recargada de
pergamino. La heráldica sobria en oro sobre carbón estaba libre. El sello la
ocupa sin inventar nada: está hecho del rombo y del aro que la app ya usaba.

#### Anatomía

Las coordenadas son sobre un lienzo de 120 × 120 (`src/ui/Seal.tsx`).

| Parte | Geometría | Por qué |
| --- | --- | --- |
| Aro | Círculo de radio 53, trazo 5 | Un aro y no dos: a 30 px el interior se pegaba al exterior |
| Rombos cardinales | Centro en (60, 7), (113, 60), (60, 113), (7, 60); semidiagonal 7 | Lo que distingue al sello del medallón de retrato |
| Filete de los rombos | Trazo 3 **del color del fondo** | Corta el aro en vez de apoyarse encima: el rombo se lee como pieza, no como bulto |
| M | Polilínea (37, 82) → (37, 38) → (60, 62) → (83, 38) → (83, 82), trazo 9 | Esquinas en inglete y remate cuadrado: una M dibujada, no la de una fuente |

#### Las dos versiones

- **Sello de línea** (`Seal`): en la cabecera del panel y en la barra de arriba
  en ventana angosta. Su color es `--gold`, así que cambia con el tema.
- **Disco**: oro macizo con la M rellena en el color de la placa, para el
  favicon y el ícono de inicio (`public/favicon.png`,
  `public/apple-touch-icon.png`). La M va **rellena y no calada**: calada, en
  una pestaña de tema claro quedaría blanca sobre oro, que no contrasta. Son
  archivos fijos: el generador vivía en el cliente de Flutter, y un cambio de
  marca los vuelve a dibujar con la anatomía de arriba.

#### Reglas de uso

- **El filete de los rombos es el color del fondo** sobre el que se dibuja. Si
  el sello va sobre otro fondo, el filete se cambia con él.
- **Por debajo de 24 px se usa el disco.** El sello de línea a ese tamaño
  pierde los rombos y el aro se vuelve una mancha.
- **El logotipo completo** es el sello, el nombre en Georgia 18 y el subtítulo
  en sans 11 dorada.
- No lleva texto alrededor del aro, ni sombra, ni degradado, ni rotación. Esas
  son las formas en que se parecería a cualquier otro sello.
- No se usa como medallón de personaje ni el medallón como logo.

---

## 3. Color

### 3.1 Tokens

Viven en `src/index.css` como variables CSS y como utilidades de Tailwind
(`bg-surface`, `text-gold`).

| Token | Oscuro | Claro | Qué significa |
| --- | --- | --- | --- |
| `scaffold` | `#151210` | `#F3ECDD` | Fondo de página |
| `surface` | `#1E1915` | `#FBF7EC` | Tarjetas, panel lateral, diálogos |
| `plaque` | `#12100C` | `#EBE0C9` | Fondo de placas: **más hundido** que `surface` |
| `on-surface` | `#EFE7DA` | `#2A2118` | Texto principal |
| `on-surface-variant` | `#A2937E` | `#6E5F49` | Texto secundario |
| `text-muted` | `#9C8B6E` | `#6E6047` | Rótulos, eyebrows, hints, pips vacíos |
| `gold` | `#C9A24B` | `#8A6A1E` | Acento heráldico: activo, seleccionado, números clave |
| `gold-soft` | `#2E2617` | `#EEE1BF` | Relleno suave de pills doradas y del ítem de navegación activo |
| `crimson` | `#D4665A` | `#A6392E` | Puntos de golpe, daño, error y acción destructiva |
| `verdant` | `#6FA85C` | `#3E7A33` | La salida esperada que conserva algo; PG que sobran |
| `act-action` | `#6FA85C` | 55 % + `on-surface` | Ícono de Acción (círculo) |
| `act-bonus` | `#D9834A` | 55 % + `on-surface` | Ícono de Acción adicional (triángulo) |
| `act-reaction` | `#A78BD6` | 55 % + `on-surface` | Ícono de Reacción (flecha que vuelve) |
| `act-long` | `#5FA3C7` | 55 % + `on-surface` | Ícono de tiempo largo (reloj de arena) |
| `hairline` | `#3A2F25` | `#D9C9A8` | Bordes finos de 1 px; toda la jerarquía estructural |
| `on-primary` | `#201A10` | `#FFFFFF` | Texto sobre oro y sobre carmesí |

Los que llevan texto están elegidos para llegar a **4.5:1 contra los dos fondos
sobre los que se dibujan**, `surface` y `plaque`. El carmesí oscuro es más claro
que el rojo de marca original (`#C24A3E`, 3.6:1) justamente por eso: lleva los
PG, que son texto chico. La consecuencia es que sobre ese carmesí el blanco ya
no contrasta, así que en el tema oscuro lo que va encima es el mismo casi-negro
que va sobre el oro.

Los `--act-*` pintan solo esos íconos. Llevan color propio para leer una lista
de un vistazo, sin usar el carmesí (daño) ni el oro (números e información); la
forma dice lo mismo sin color.

### 3.2 Los tres fondos

**Hay tres niveles de fondo y no más**: `scaffold` (página) → `surface`
(tarjeta) → `plaque` (placa dentro de tarjeta). La placa siempre se hunde,
nunca se eleva, en los dos temas.

### 3.3 Acentos de contenido (colores de clase)

Cada clase declara su `accentColor` **en el JSON del catálogo**, no en el
código (`packages/dnd_engine/lib/assets/srd_2024/classes.json`). El cliente lo
lee con `accentOf` (`src/api/catalog.ts`) y cae al oro si falta o no es
`#RRGGBB`. Por eso el homebrew usa el mismo mecanismo, y es la única excepción
a «ningún hex fuera de `index.css`»: es un dato, no un color de diseño.

| Clase | Hex | | Clase | Hex |
| --- | --- | --- | --- | --- |
| Guerrero | `#B8BEC8` | | Brujo | `#59C2A0` |
| Bárbaro | `#D9834A` | | Paladín | `#E3CF9A` |
| Pícaro | `#9AA5C8` | | Explorador | `#9FA65A` |
| Monje | `#E3A542` | | Bardo | `#A78BD6` |
| Mago | `#6F8FE0` | | Hechicero | `#D0609A` |
| Clérigo | `#D9E4F0` | | Artífice | `#B08D57` |
| Druida | `#6FA85C` | | | |

**Alcance del acento de clase**: el aro y el fondo del medallón sin retrato, el
ícono de clase, y el borde y los adornos de las cuatro placas de la banda
táctica (Puntos de golpe, Iniciativa, Velocidad y Competencia). En el tema
claro, el borde y los adornos mezclan el acento con `on-surface`
(`--class-ink`): varios acentos son pálidos. En la ficha, el color puede venir
del estilo del personaje, por esquina: la clase elegida o una de la paleta de
adornos (`--orn-crimson`, `sky`, `violet`, `teal`, `green`, `silver`, `ember`);
el borde va en diagonal del color de arriba al de abajo, y el medallón y el rombo
del separador de la cabecera toman el de arriba (el rombo vuelve al oro con los
adornos apagados). No tiñe fondos, botones ni texto
de cuerpo. Una clase no reemplaza el oro del sistema.

### 3.4 Semántica de estado

| Estado | Tratamiento |
| --- | --- |
| Activo / seleccionado | Texto y/o ícono en `gold`; fondo `gold-soft` si es un ítem de navegación |
| Hover (tarjeta de personaje) | Borde `gold` de 1 px + traslación −2 px + la única sombra (`--shadow-card-hover`) |
| Hover (placa que se elige) | Borde dorado y fondo tibio (`.pick`) |
| Favorito | Borde `gold` de **2 px** + estrella dorada junto al nombre |
| Error | `crimson` + ícono de error |
| Éxito | `verdant` + ícono de tilde |
| Info | `gold` + ícono de información |

**El color nunca es el único portador de significado.** El favorito lleva borde
*y* estrella; el guardado lleva color *y* ícono *y* texto. Quien no distingue el
oro del gris tiene que poder usar la app.

---

## 4. Tipografía

### 4.1 Las dos familias

| Rol | Familia | Variable |
| --- | --- | --- |
| **Display / títulos / valores de plaqueta** | Georgia (serif) | `--font-display` |
| **Cuerpo / interfaz** | Roboto, con la sans del sistema detrás | `--font-body` |

Georgia no se descarga: se pide por nombre y **el navegador cae al serif
genérico si no está**. Está en Windows y macOS; en Linux y Android típicamente
no. Ver [Deuda conocida](#13-deuda-conocida).

**Georgia se usa para exactamente cuatro cosas**: el nombre del personaje, los
títulos de tarjeta y pantalla, los valores de plaqueta y de escudo, y la marca
en la cabecera del panel. Todo lo demás es la sans.

**Un número que se compara con el de al lado va en sans negrita, no en
Georgia** (`.num`). En la banda táctica de la ficha, en las características y
en la columna de habilidades, las cifras se leen en columna y de un vistazo, y
el serif las vuelve más lentas de barrer. Georgia queda para el número que *es*
el título de su caja (`.stat-value`).

### 4.2 Medidas de referencia

Cuerpo 14 px. Eyebrow 11 px en mayúsculas con 1.6 px de espaciado, peso 500,
`text-muted` (`.eyebrow`). Rótulo de plaqueta 10 px con 1.2 px (`.plaque-label`).
Valor de plaqueta Georgia 24 px. Nombre de marca Georgia 18 y subtítulo sans 11
dorada. La escala no es modular: los tamaños se eligieron por caso, y no hay
ratio que derivar.

### 4.3 Reglas tipográficas

- **Todo número que se compara en columna lleva cifras tabulares**
  (`font-variant-numeric: tabular-nums`). Sin eso, un `18` y un `11` no
  alinean y la ficha parece temblar al cambiar de personaje.
- **Los rótulos van en mayúsculas con espaciado positivo**, y el espaciado
  crece cuando el tamaño baja. Nunca mayúsculas sin espaciado.
- **Los modificadores se firman siempre** (`+3`, `−1`), nunca `3`.

---

## 5. Forma, borde y elevación

### 5.1 Radios

| Radio | Variable | Aplicación |
| --- | --- | --- |
| `5` | `--radius-mark` | Tecla dibujada junto a un rótulo, rombos |
| `9` | `--radius-nav` | Ítems de navegación, placas densas |
| `12` | `--radius-card` | **Tarjetas**, placas, diálogos |
| `20` | `--radius-pill` | Pills, chips |
| circular | — | Medallones, pips |

El radio por defecto para una superficie nueva es **12**.

### 5.2 Bordes

- **1 px de `hairline` es el borde estándar.** Toda tarjeta, placa, pill, chip,
  contenedor de filas y separación de paneles lo usa.
- **2 px de `gold` significa «esto es especial»**: favorito, aro del medallón,
  destino de arrastre, estado encendido.

### 5.3 Elevación

No hay elevación: **la única sombra del sistema** es la de hover de la tarjeta
de personaje (`--shadow-card-hover`). Lo que separa un diálogo del fondo es el
velo (`--scrim`), no una sombra.

---

## 6. Espaciado

Subconjunto canónico, y desviarse solo con motivo:

| Paso | Uso típico |
| --- | --- |
| `4` | Separación intra-elemento (ícono ↔ texto muy junto) |
| `8` | Separación entre chips |
| `12` | Padding vertical de placas, bloques cortos |
| `16` | **Espacio entre tarjetas y padding interno de tarjeta** — el más común |
| `20` | Padding horizontal del cuerpo de página |
| `24` | Estados vacíos y de error |
| `32` | Márgenes de página en pantalla ancha |

---

## 7. Layout y responsividad

### 7.1 Anatomía general

```
┌──────────────┬────────────────────────────────────────────┐
│  Panel       │  Contenido                                 │
│  lateral     │  ┌──────────────────────────────────────┐  │
│  236 px      │  │ Barra de acciones (buscar, orden, +) │  │
│              │  ├──────────────────────────────────────┤  │
│  · marca     │  │                                      │  │
│  · modo      │  │   Grilla de tarjetas / cuerpo        │  │
│  · nav       │  │   de la ficha                        │  │
│  · ajustes   │  │                                      │  │
│  · cuenta    │  └──────────────────────────────────────┘  │
│  · versión   │                                            │
└──────────────┴────────────────────────────────────────────┘
```

El **panel lateral mide 236 px fijos** (`--sidebar-width`, `Shell`). No es
flexible: los textos que no entran se recortan con elipsis.

El Modo Jugador y el Modo DM comparten **el mismo marco**: marca, interruptor de
modo, y al pie Ajustes, sugerencias, la cuenta con «Cerrar sesión» y la
versión. Lo único propio de cada modo es la navegación del medio. El pie no se
rediseña por modo: quien solo dirige tiene que poder salir de su cuenta sin
pasar por una pantalla que no usa.

Las pantallas de adentro —ficha, Códice, creación— ponen su «volver» donde el
menú principal tiene el interruptor, con la misma forma, para que la salida
esté siempre en el mismo sitio.

### 7.2 Breakpoints

**Hay uno solo de marco: 900 px** (`shell:` en Tailwind). Desde ahí el panel
lateral queda fijo; debajo, barra superior y cajón con el mismo panel. Todo lo
demás se resuelve con grillas que se adaptan solas (`auto-fill`, `minmax`), no
con más breakpoints. El piso es un teléfono de 360 px: nada puede empujar un
scroll horizontal.

### 7.3 La grilla del dashboard

Columnas de al menos 300 px que llenan todo el ancho, tantas como entren
(`repeat(auto-fill, minmax(min(300px, 100%), 1fr))`), con 16 px de separación.
El `min(…, 100%)` es lo que deja una sola columna en un teléfono sin
desbordar. Las listas de tarjetas del Modo DM siguen la misma idea.

### 7.4 Reordenamiento

Las tarjetas se reordenan arrastrando (`src/ui/holdDrag.ts`). En pantalla
táctil el arrastre **arranca al sostener el dedo**: la tarjeta entera ya es un
enlace, y desplazar la grilla no puede terminar moviendo personajes. Con el
mouse alcanza con moverse unos píxeles.

---

## 8. Principios de componentes

El catálogo de piezas (`src/ui/`) está en
[Diseño web en React](diseno-web-react.md): **antes de crear un componente
visual nuevo, buscá ahí**. Acá van las reglas que valen para todos.

### Retroalimentación

- Un aviso lleva ícono, color y texto; el error dura más que el resto, y
  «Deshacer» solo se ofrece si se restaura entero con lo que hay en memoria.
- Lo que cambia solo se anuncia solo (región viva).
- Un spinner nunca va solo: el texto de qué está pasando es obligatorio.
- Un error de carga ofrece **Reintentar**; el detalle técnico se puede copiar.
- Un estado vacío distingue **«no hay nada»** de **«nada coincide con la
  búsqueda»**: son situaciones distintas y piden acciones distintas.
- Una ayuda en pantalla informa y nada más: sin botón, sin cierre, sin «Más
  información».

### El molde de diálogo

Un diálogo es **una placa del sistema**, no una superficie nueva: `surface`,
filete `hairline` de 1 px, radio 12 y cero elevación. Lo que separa del fondo
es el velo, no una sombra.

- **La medida de lectura.** Sin tope, un párrafo largo estira el diálogo hasta
  el ancho de la ventana: 480 px por defecto (unos 66 caracteres), más ancho
  solo cuando el cuerpo es una ficha y no prosa.
- **La barra de acciones.** Celdas de 48 px sobre `plaque`, separadas por
  filete, que llegan al borde del diálogo. Cancelar primero, el verbo de la
  acción último y en negrita. El cuerpo scrollea solo y el pie queda fijo.
- **La tecla dibujada** junto a un rótulo se pone solo cuando es cierta (`Esc`
  donde el diálogo se cierra con Escape, `↵` donde alguien la ató).
- **En la barra solo van celdas que se tocan.** Un texto suelto entre botones
  —«Falta elegir 2», «Al confirmar arranca la ronda 1»— va al final del cuerpo:
  en una fila de celdas se lee como un botón muerto.

#### Color de las acciones

El carmesí queda para el camino irreversible y nada más; `verdant` para la
salida esperada que conserva algo (terminar un combate guardando el registro,
empezar la ronda); oro para todo lo demás. Un diálogo destructivo además abre
con un ícono de advertencia en carmesí.

---

## 9. Iconografía

**`lucide-react`**, sin set propio ni SVG sueltos (salvo el sello). El
contenido declara su ícono con un **id de texto** (`iconId` en el JSON) que el
cliente traduce a un ícono con un mapa fijo; un id que no está en el mapa cae a
un ícono genérico del dominio, distinto para clase y para especie.

Tamaños en uso: 14 (en línea con metadatos), 16–18 (cabeceras, navegación),
20 (avisos, prefijos de campo), 40–44 (estados vacíos y de error).

---

## 10. Movimiento

Las animaciones son **suaves y eficaces**: evitan la brusquedad y la sensación de
cosa inacabada que da una pantalla donde todo aparece de golpe, sin cobrarle
espera a una herramienta que se abre cincuenta veces por sesión. Lo que aparece
o cambia entra con una transición corta (hasta unos 200 ms), con opacidad,
color o un desplazamiento mínimo:

| Animación | Duración |
| --- | --- |
| Hover de tarjeta (traslación, sombra, borde) | 120 ms |
| Lo que aparece (`.step-in`) | 160 ms |
| Barra de PG al cambiar | 220 ms |

Todo se apaga con «reducir movimiento», del sistema o de Ajustes
(`src/ui/motion.ts`). Lo animado nunca lleva información que no esté ya en su
valor final: el número de PG cambia en el primer cuadro y la barra solo
acompaña.

**Sin parallax ni efectos largos o decorativos,** y nada que trabe la respuesta
al toque: una entrada de 300 ms ya es un peaje.

---

## 11. Accesibilidad

### 11.1 Lo que se exige

- **Los datos se anuncian con su contexto**: una característica dice «FUE:
  modificador +3, puntuación 16, competente en salvación», en el orden en que
  se ve; la CA, «Clase de armadura: 17»; los usos, «3 de 5 usos disponibles».
- **Regiones vivas** en avisos y en lo que carga: lo que cambia solo se anuncia
  solo.
- **El color nunca va solo** (ver [3.4](#34-semántica-de-estado)).
- **Todo botón de ícono lleva nombre** (`aria-label`) y, si hace falta, un
  `Tooltip`; el tooltip no reemplaza el nombre.
- Los retratos anuncian «Retrato de X» o «Emblema de X». Un retrato que no
  carga deja el medallón sin imagen y no rompe la pantalla.
- Los objetivos táctiles no bajan de 44 px.

### 11.2 Contraste medido (WCAG 2.1)

Ratios calculados sobre los tokens de [3.1](#31-tokens). ✅ = AA para texto
normal (≥ 4.5); ⚠️ = solo texto grande o elementos no textuales (≥ 3.0).

**Tema oscuro**

| Combinación | Ratio | |
| --- | --- | --- |
| `on-surface` sobre `surface` | 14.20 | ✅ |
| `gold` sobre `plaque` | 7.92 | ✅ |
| `gold` sobre `surface` | 7.26 | ✅ |
| `on-primary` sobre `gold` | 7.19 | ✅ |
| `verdant` sobre `surface` | 6.17 | ✅ |
| `on-surface-variant` sobre `surface` | 5.82 | ✅ |
| `text-muted` sobre `plaque` | 5.73 | ✅ |
| `crimson` sobre `plaque` | 5.29 | ✅ |
| `text-muted` sobre `surface` | 5.25 | ✅ |
| `crimson` sobre `surface` | 4.85 | ✅ |
| `on-primary` sobre `crimson` | 4.81 | ✅ |

**Tema claro**

| Combinación | Ratio | |
| --- | --- | --- |
| `on-surface` sobre `surface` | 14.76 | ✅ |
| `on-primary` sobre `crimson` | 6.47 | ✅ |
| `crimson` sobre `surface` | 6.04 | ✅ |
| `on-surface-variant` sobre `surface` | 5.78 | ✅ |
| `text-muted` sobre `surface` | 5.72 | ✅ |
| `on-primary` sobre `gold` | 5.05 | ✅ |
| `crimson` sobre `plaque` | 4.94 | ✅ |
| `verdant` sobre `surface` | 4.86 | ✅ |
| `gold` sobre `surface` | 4.71 | ✅ |
| `text-muted` sobre `plaque` | 4.68 | ✅ |
| `gold` sobre `plaque` | 3.85 | ⚠️ solo texto grande |

### 11.3 Reglas que se derivan

1. **`gold` sobre `plaque` en tema claro solo vale a 24 px o más.** El valor de
   plaqueta normal pasa; uno chico, no.
2. **Lo que va sobre un acento se invierte con el tema.** En el oscuro, oro y
   carmesí son claros y llevan casi-negro encima; en el claro son oscuros y
   llevan blanco (`on-primary`).

---

## 12. Anti-patrones

| ❌ No hacer | ✅ En su lugar | Por qué |
| --- | --- | --- |
| Calcular una regla de D&D en un componente | Leerla de `computeSheet` | El motor es la fuente de verdad; la UI que recalcula se desincroniza |
| Un hex suelto o un color de la paleta de Tailwind | Una variable de `index.css` o su utilidad (`bg-surface`) | El tema claro deja de funcionar; la paleta por defecto ni existe |
| Sombra para separar superficies | Borde `hairline` de 1 px | El sistema es plano por decisión |
| Un cuarto nivel de fondo | `scaffold` → `surface` → `plaque` | La placa se hunde; nada se eleva |
| Un componente visual nuevo dentro de una pantalla | Buscar en `src/ui/` y, si se repite, sumarlo ahí | Es la biblioteca compartida |
| Medir la ventana para decidir layout | Grillas `auto-fill` / `minmax`, o el breakpoint `shell:` | El panel lateral resta 236 px que la ventana no sabe |
| Texto largo sin recorte en el panel | Elipsis en una línea | El panel mide 236 px fijos |
| Un logo propio en una pantalla nueva, o el rombo como logo | `Seal` | El sello es uno solo; un segundo emblema parte la marca |
| Rojo o un d20 en una pieza de marca | El sello en `gold` | Es lo que usa toda la competencia, y el rojo es el de D&D |

---

## 13. Deuda conocida

1. **Georgia no se descarga.** En sistemas sin la fuente, toda la capa display
   cae al serif genérico y la métrica cambia. La alternativa sería una serif
   libre servida como asset.
2. **El nombre del logotipo no tiene letra propia.** «Milantus» va en Georgia,
   que no es exclusiva. El camino es un lettering en versalitas sobre una serif
   libre empaquetada (no Cinzel: es la de casi todo el contenido de fans de
   D&D).
3. **El favicon y el ícono de inicio son archivos fijos**: su generador se fue
   con el cliente de Flutter. Si la marca cambia, se vuelven a dibujar.

---

## Apéndice B — Equivalencia en CSS

Los tokens viven en `packages/dnd_web/src/index.css`, que es la fuente: este
bloque los resume para una maqueta HTML que tenga que verse como el producto.

```css
:root {
  --scaffold: #151210;  --surface: #1E1915;  --plaque: #12100C;
  --on-surface: #EFE7DA; --on-surface-variant: #A2937E; --text-muted: #9C8B6E;
  --gold: #C9A24B; --gold-soft: #2E2617; --crimson: #D4665A; --verdant: #6FA85C;
  --hairline: #3A2F25; --on-primary: #201A10;

  --font-display: Georgia, 'Times New Roman', serif;
  --font-body: Roboto, system-ui, sans-serif;

  --radius-card: 12px; --radius-pill: 20px; --radius-nav: 9px; --radius-mark: 5px;
  --border-hairline: 1px solid var(--hairline);
  --sidebar-width: 236px;
  --shadow-card-hover: 0 10px 26px #00000046;
}

:root[data-theme="light"] {
  --scaffold: #F3ECDD;  --surface: #FBF7EC;  --plaque: #EBE0C9;
  --on-surface: #2A2118; --on-surface-variant: #6E5F49; --text-muted: #6E6047;
  --gold: #8A6A1E; --gold-soft: #EEE1BF; --crimson: #A6392E; --verdant: #3E7A33;
  --hairline: #D9C9A8; --on-primary: #FFFFFF;
}

.card   { background: var(--surface); border: var(--border-hairline);
          border-radius: var(--radius-card); }
.plaque { background: var(--plaque); border: var(--border-hairline);
          border-radius: var(--radius-card); }
.stat-value { font-family: var(--font-display); font-size: 24px; line-height: 1;
              color: var(--gold); font-variant-numeric: tabular-nums; }
.eyebrow { font-size: 11px; letter-spacing: 1.6px; font-weight: 500;
           text-transform: uppercase; color: var(--text-muted); }
```
