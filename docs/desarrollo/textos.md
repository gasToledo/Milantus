# Textos de la interfaz

Cómo le habla la app a quien juega, en español y en inglés (ver «Español e
inglés» al final). Vale para todo texto visible: etiquetas,
avisos, diálogos, estados vacíos y los mensajes de error que devuelve el
servidor.

## Voz

- **Voseo rioplatense**, siempre: «Elegí», «Revisá», «podés», «tenés». Nunca
  «elige», «puedes» ni «usted».
- **Sin género para quien no lo eligió**: «Lo pega en su campaña», no «Él lo
  pega». El DM y los jugadores pueden ser cualquiera.

## Ayudas y explicaciones de reglas

- Primero el efecto práctico, después el nombre de la regla.
- Nada de definiciones circulares: «Pericia es tener pericia».
- En el flujo principal, bloques de tres frases como máximo; lo demás va a un
  «Más información».
- Una advertencia importante nunca vive solo en un tooltip, que en pantallas
  táctiles no se ve.

## Glosario

El término de referencia es el del catálogo SRD en español
(`packages/dnd_engine/lib/assets/srd_2024/`). Si la app y el catálogo dicen
cosas distintas, gana el catálogo.

| Se dice | No se dice | Nota |
| --- | --- | --- |
| especie | raza | Terminología de 2024. «Linaje» es la subdivisión de una especie, no un sinónimo. |
| bonificador | bonus | «Bonificador **por** competencia», no «de». |
| salvación | tirada de salvación, TS | «SALV» solo como abreviatura en plaquetas. |
| PG | HP | «Puntos de golpe» cuando hay lugar para la forma larga. |
| CA | AC | |
| maltrecho | bloodied, ensangrentado | Con la mitad de los PG o menos, como lo define el glosario del SRD. |
| conjuro | hechizo | |
| espacio de conjuro | ranura | |
| PNJ | NPC | La colección global es la «Biblioteca de PNJ»; «PNJ» a secas es la sección de una campaña. |
| mesa | — | Los jugadores de una campaña. Dentro de Combate se dice «combate»: «Sumar al combate», «Sacar del combate». |
| DM | máster, DJ | Es el nombre del modo: «Modo DM». |
| homebrew | contenido casero | En minúscula dentro de una frase. |
| archivo (al importar o exportar) | pack | Es lo que la persona ve en su disco. |
| iniciar sesión | login | |
| FUE, DES, CON, INT, SAB, CAR | STR, DEX, WIS, CHA | `Ability.abbr`. Los códigos en inglés quedan en `Ability.code`, solo para datos. |
| pies | ft | |
| conjunto estándar, coste en puntos | array estándar, compra de puntos | Los métodos de puntuación, como los nombra el SRD. |
| habilidades (lo que se elige en creación) | competencias de clase | Se gana *competencia* en una *habilidad*. |
| el orden de tus personajes | roster | |

Los nombres de reglas que vienen del catálogo («Ataque Adicional», «Acción
Adicional» como tiempo de lanzamiento) se muestran tal como están ahí.

## Acciones

| Acción | Etiqueta |
| --- | --- |
| Borrar algo | **Borrar**, y el título del diálogo «¿Borrar …?». Nunca «Eliminar». |
| Descartar un diálogo | **Cancelar** |
| Volver a probar | **Reintentar** |
| Guardar | **Guardar** |

## Errores

Todo error empieza con **«No se pudo …»**, nunca con «Error al …».

Cuando el aviso nace de una excepción, se arma con `failureMessage(qué, error)`
(`packages/dnd_app/lib/theme/app_widgets.dart`) y nunca interpolando `$e`.
Así solo aparece un motivo si la excepción trae un texto en castellano
(`ApiException`, `FormatException`, `UnsupportedDataVersionException`), y
cualquier otro error queda en la frase sola, sin jerga ni nombres de clases.

El detalle técnico, cuando sirve, va en «Ver detalles» de `AppErrorView`.

## Búsquedas sin resultados

- En una pantalla o una lista principal, la frase completa, con lo buscado:
  `Ningún personaje coincide con «Sagan».`
- En un diálogo o una lista chica dentro de un paso: `Sin coincidencias.`

Nunca «Sin resultados». Y «no hay nada todavía» es otro estado, con otra
acción: ver `AppEmptyState` en [Diseño web](diseno-web.md).

## Tipografía

- Comillas latinas «», también alrededor de lo que escribió el usuario.
- Puntos suspensivos con el carácter `…`, no con tres puntos.
- Plurales reales según la cantidad (`n == 1 ? '1 imagen' : '$n imágenes'`),
  nunca «imagen(es)».

## Español e inglés

La interfaz se ofrece en dos idiomas. El **español rioplatense es el idioma de
origen**: todo lo de arriba describe su voz, y el inglés se escribe a partir de
él. Qué idioma se usa lo decide la persona con el selector del panel lateral
(se recuerda en el navegador); sin elección se usa el del navegador y, si no es
uno de los dos, el español.

### Dónde viven los textos

- `packages/dnd_app/lib/l10n/app_es.arb` (plantilla) y `app_en.arb`. Toda clave
  existe en los dos, con los mismos marcadores: `test/l10n_parity_test.dart` lo
  verifica.
- En un widget se lee con `context.l10n.clave`. Una función sin contexto recibe
  `AppLocalizations l10n` como parámetro; no guarda textos en constantes.
- Un texto con datos lleva marcadores (`{name}`) y se declara en `app_es.arb`
  con su metadato `@clave`; un plural usa la sintaxis ICU
  (`{count, plural, =1{1 nota} other{{count} notas}}`), nunca `n == 1 ? …`.
- En un mensaje con marcadores no se usa el apóstrofo recto (`'`): en ICU es
  un escape. En inglés se escribe `’` (por ejemplo «{name}’s turn»).
- Los ids que viajan como datos (tipos, bandos, estilos guardados) **no** se
  traducen: se traducen al mostrarlos.

### Cómo agregar un texto

1. Agregá la clave a `app_es.arb` y a `app_en.arb`, en el mismo commit.
2. Usala con `context.l10n.clave`. `flutter pub get` o cualquier build
   regenera `lib/l10n/app_localizations*.dart`.
3. Corré `flutter test test/l10n_parity_test.dart test/l10n_no_literals_test.dart`.

`test/l10n_no_literals_test.dart` recorre `lib/` y falla ante cualquier texto
visible suelto en un widget. Si el detector se equivoca por sobrar (un id, una
tipografía, un prompt), se marca el renglón con `// l10n-ignore: motivo`; un
archivo entero de datos o errores técnicos, con `// l10n-ignore-file: motivo`
al principio. El motivo es obligatorio. Para ver qué detecta:
`dart run tool/l10n_literals.dart -v`.

Un idioma nuevo es agregar su código a `supportedLanguageCodes` y su nombre a
`languageNames` (`lib/l10n/app_locale.dart`) y un `app_xx.arb`: el selector lo
ofrece solo. Cada idioma se muestra **con su propio nombre**, fuera del
catálogo.

### Voz en inglés

- Directa y sin florituras, en segunda persona («Pick a creature», «Your
  campaigns are safe»). Sin género para quien no lo eligió: «they», «their».
- Botones y títulos en *sentence case* («Add character», «Delete campaign»).
- Las mismas acciones de siempre: **Cancel**, **Save**, **Delete** (nunca
  «Remove» para borrar; «Remove» es sacar de un grupo o una lista), **Retry**.
- Comillas curvas “ ” alrededor de lo que escribió la persona, `…` para los
  puntos suspensivos y plurales reales, igual que en español.
- Los errores empiezan con «… could not be …» o «Could not …», no con
  «Error …».

### Glosario en inglés

El término de referencia es el del SRD 5.2 en inglés (5e 2024). Si la app y
el SRD dicen cosas distintas, gana el SRD.

| Español | Inglés | Nota |
| --- | --- | --- |
| especie | species | No «race». |
| PG, puntos de golpe | HP, Hit Points | |
| CA | AC, Armor Class | |
| maltrecho | Bloodied | |
| conjuro, espacio de conjuro | spell, spell slot | |
| bonificador por competencia | Proficiency Bonus | |
| salvación | saving throw | «Saves» solo como abreviatura. |
| característica | ability | «Ability score» para el valor. |
| dote, dote de origen | feat, origin feat | |
| trasfondo | background | |
| iniciativa | initiative | |
| Inspiración Heroica | Heroic Inspiration | |
| PNJ, Biblioteca de PNJ | NPC, NPC library | |
| Modo DM, Modo Jugador | DM Mode, Player Mode | |
| mesa | table | Los jugadores de una campaña. |
| en curso, en pausa, terminada | in progress, paused, finished | Estados de una campaña. |
| pies | feet, ft | |
| po, pp, pe, pc, pl | gp, sp, ep, cp, pp | Monedas: el SRD en inglés las nombra así. |
| FUE, DES, CON, INT, SAB, CAR | STR, DEX, CON, INT, WIS, CHA | `Ability.abbr`. |
| habilidad (Juego de Manos, Trato con Animales…) | skill (Sleight of Hand, Animal Handling…) | `Skill.labelEn`. |
| tipos de daño (Contundente, Relámpago…) | Bludgeoning, Lightning… | `DamageType`. |
| condiciones (Derribado, Apresado…) | Prone, Restrained… | |
| entrenamiento con armadura, armas simples/marciales | armor training, Simple/Martial weapons | `proficiency_labels.dart`. |
| herramientas (Herramientas de ladrón…) | tools (Thieves' Tools…) | Con mayúsculas, como el SRD. |
| propiedades y maestrías de arma (Sutil, Derribar…) | weapon properties and masteries (Finesse, Topple…) | «A distancia» es «Range». |
| idiomas (Jerga de ladrones…) | languages (Thieves' Cant…) | |
| escuelas (Ilusionismo, Nigromancia…) | schools (Illusion, Necromancy…) | `content_vocabulary.dart`. |
| Acción, Acción Adicional, Reacción | Action, Bonus Action, Reaction | Tiempo de lanzamiento. |
| Personal, Toque | Self, Touch | Alcance de un conjuro. |
| tipos de criatura (Feérico, Infernal, Muerto viviente…) | Fey, Fiend, Undead… | «Autómata» también es «Construct». |

La fuente de cada término es su tabla en el motor; esta lista es para
encontrarlos, no una segunda fuente. `vocabulary_language_test` exige que
cada rótulo tenga su inglés.

### Qué sigue en español

La fase 2 (change `add-english-content`) lleva al inglés el vocabulario del
motor, el catálogo y los errores. Mientras se completa, lo que todavía no se
traduce lo declara su `l10n-ignore` con el motivo «fase 2»: los errores
técnicos de red y de archivos (`api_client.dart`, `lib/data/*`), el prompt
del generador de retratos y el catálogo que aún no tiene su `X.en.json`.

El vocabulario del motor ya está en los dos idiomas: se lee con `label`
(sigue a `ContentLanguage.current`) y nunca con un texto copiado en un widget.
Lo que una persona escribe —homebrew, notas, nombres— se muestra tal como se
escribió, en cualquier idioma.
