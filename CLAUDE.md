# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Idioma

**Todo el proyecto está en español rioplatense**: nombres de tests, mensajes de
UI, comentarios, documentación y mensajes de commit. Escribí en español salvo
que el identificador sea de una API ajena.

Los comentarios explican **por qué**, no qué hace la línea. El código de este
repositorio está densamente comentado con las decisiones y sus motivos —
seguí ese registro y sumale el tuyo cuando tomes una decisión no obvia.

## Comandos

Los tres paquetes se prueban por separado. No hay comando raíz.

```bash
cd packages/dnd_engine && dart pub get && dart analyze && dart test
```

```bash
cd packages/dnd_app && flutter pub get && flutter analyze && flutter test
```

```bash
cd packages/dnd_server && dart pub get && dart analyze && dart test
```

Un archivo suelto, o un test por nombre:

```bash
cd packages/dnd_engine && dart test test/wild_shape_test.dart
```

```bash
cd packages/dnd_app && flutter test test/sheet_screen_test.dart --plain-name "Campaña"
```

Antes de cualquier commit, y obligatorio para que pase CI:

```bash
dart format .
```

```bash
cd packages/dnd_app && flutter build web --release
```

El build no es un trámite: lo que vive en `packages/dnd_app/lib/web/*_web.dart`
(iframes, `postMessage`, la pantalla encendida) se exporta condicionalmente, y
`flutter test` corre con el `*_stub.dart`. Ese código solo se compila acá.

CI verifica el formato **antes que nada**, así que un commit sin formatear falla
sin llegar a decir nada útil sobre el código. Conviene instalar el hook, que
formatea lo preparado antes de cada commit:

```bash
git config core.hooksPath .githooks
```

El hook solo toca los `.dart` preparados, y a los preparados a medias no los
formatea: los revisa y corta el commit. CI mira `lib test` en la app, `lib bin
test` en el servidor y todo el paquete en el engine (incluido `tool/`).

El stack completo (Postgres + Zitadel + servidor + cloudflared) se levanta con
`docker compose up -d --build`; el runbook está en
`docs/operaciones/despliegue.md`.

### Lo que ningún comando de arriba corre

- `feedback-worker/` (Worker de Cloudflare, solo Node) tiene su `npm test` y
  **CI no lo ejecuta**.
- `lib/l10n/app_localizations*.dart` **está versionado**: al tocar un `.arb`,
  `flutter pub get` (o cualquier build) lo regenera y los tres archivos van en
  el mismo commit.
- El esquema de Postgres vive en `packages/dnd_server/lib/src/db/migrations.dart`:
  solo se **agregan** migraciones al final, nunca se edita una publicada, y
  corren solas en cada arranque del servidor.

## Commits, versión y despliegue

`main` es el único tronco activo: se valida local, se commitea y se pushea
directo. Los mensajes siguen `tipo(paquete): resumen` en español
(`feat(dnd_app): los descansos se pueden deshacer`, `fix`, `test`, `ci`, `build`,
`docs`; sin paquete cuando cruza varios).

Cambiar `version` en un `pubspec.yaml` exige actualizar `CHANGELOG.md` en el
mismo commit, y un cambio grande (capacidad visible, esquema persistido, o que
cruza engine, cliente y servidor) sube la versión. El criterio y el formato
están en `docs/desarrollo/versionado-y-changelog.md`.

El push dispara CI (`.github/workflows/ci.yml`, en cualquier rama y en los pull
requests): formato, análisis y pruebas de los tres paquetes, con las pruebas de
la app en dos mitades en paralelo con el build web. CD (`cd.yml`) arranca recién
cuando CI termina en verde sobre `main`: **CI en rojo no llega a producción**
(el commit queda en `main` y se arregla con otro). Su job `gate` despliega solo
si cambió algo desplegable desde el último CD exitoso — `packages/**`,
`docker-compose.yml`, `postgres-init/**` o el propio `cd.yml`, sin contar
`packages/*/test/` ni `packages/*/tool/`, que tampoco entran a la imagen
(`.dockerignore`). Un commit de solo docs no despliega.

Dos cosas que muerden en el despliegue: la imagen base de Flutter solo publica
*minor* (`3.44.0`, nunca `3.44.8`), así que `environment.sdk` de `dnd_app` no
puede llevar una cota de patch; y `cd.yml` usa `clean: false` porque el `.env`
y las credenciales de cloudflared viven sin versionar en el directorio del
runner. Ambas razones están escritas en el `Dockerfile` y en `cd.yml`.

Lo que solo se ve con el stack real (migraciones, túnel, caché del navegador) se
prueba a mano en producción y se anota en
`docs/operaciones/pruebas-en-produccion.md`, un registro privado que Git ignora:
puede no existir en otra máquina.

## Los tres paquetes

```
packages/dnd_engine   Dart puro. Cero dependencias de runtime, cero Flutter.
packages/dnd_app      Flutter web. Depende del engine.
packages/dnd_server   shelf + Postgres. Depende del engine.
```

La dirección es estricta: **el engine no depende del cliente ni del servidor**.
Los modelos y las reglas no usan Flutter ni `dart:io`. La única excepción de
entrada/salida es `lib/src/data/content_pack_loader_io.dart`: carga catálogos
desde un directorio y se importa condicionalmente. En web, el cliente carga
los assets con `loadOfficialContent` y usa el mismo `ContentRepository`.

## Lo que hay que entender antes de tocar nada

### El motor está dirigido por datos, no por código

El contenido de D&D vive en JSON (`packages/dnd_engine/lib/assets/srd_2024/`) y
declara listas de `Effect` (`domain/effects.dart`), que es una jerarquía sellada
y **serializable**. `CharacterCompiler` (`engine/character_compiler.dart`) los
interpreta y produce un `ComputedSheet`.

La consecuencia práctica: **agregar contenido es cargar JSON, no programar.** Una
dote homebrew pasa exactamente por la misma maquinaria que una del manual. Antes
de escribir un `if` para un rasgo nuevo, fijate si se puede expresar como efecto.

### La UI nunca recalcula una regla

Todo número que se muestra sale de `ComputedSheet`. Si una pantalla necesita un
cálculo que no está ahí, el cálculo va al engine con su test, no al widget.

### `schemaVersion` es solo para documentos de usuario

`Character`, `Campaign`, `Chapter`, `Note`, `Encounter`, `EncounterLog` y `Npc`
llevan `currentSchemaVersion` + `migrateJson`: se guardan en la base y hay que
poder migrarlos. El contrato es siempre el mismo — no mutar la entrada, y
**rechazar una versión futura** en vez de guardarla de vuelta perdiendo campos.
Cada tipo tiene su propio `schemaVersionOf`, así que cada uno lleva sus tests
de versión.

`Creature` (y el resto del catálogo) **no lo lleva, y está bien**: es contenido,
no un documento de nadie. Que una criatura pueda ser homebrew y vivir en la
base no lo cambia — el homebrew guarda contenido tal cual, igual que un arma o
un conjuro propios, y ninguno de esos lleva versión. No le agregues maquinaria
de migración.

### La autorización vive adentro del `WHERE`

En el servidor, la comprobación de propiedad va en la consulta, nunca en el
handler:

```sql
DELETE FROM campaign_members
WHERE id = @memberId AND (dm_user_id = @userId OR owner_user_id = @userId)
```

Así no existe forma de llamar a un repositorio y saltearse la autorización, ni
siquiera desde un handler nuevo escrito con prisa. Consecuencia: **lo ajeno y lo
inexistente responden igual** (404, mensajes inespecíficos). Distinguirlos
convertiría la API en una forma de averiguar qué hay en otras cuentas.

`campaign_members` es **la única puerta** por la que una cuenta alcanza datos de
otra, y esa fila solo existe si el dueño del personaje emitió un código y
alguien lo canjeó. Todo esto está explicado en `docs/arquitectura/modo-dm.md`,
que es lectura obligatoria antes de tocar rutas de campaña.

Hay una excepción al supuesto, y hay que conocerla: cuando un handler necesita
leer o avisarle a la otra cuenta (canje de código, corte del vínculo, retrato de
un miembro, aviso al DM cuando se borra un personaje), le pasa al repositorio un
`userId` que no es de quien pide. Es correcto **solo** porque ese id salió de una
fila de `campaign_members` que una consulta anterior ya autorizó; nunca de la
petición.

El conector MCP (`POST /mcp`, `lib/src/app_mcp.dart`) es una segunda entrada al
mismo servidor con la misma regla: llama a los repositorios con la cuenta del
token, y sus herramientas de escritura tampoco tocan fichas ajenas. Autorización
y herramientas: `docs/arquitectura/mcp.md`.

**Ojo:** los tests del servidor corren contra repositorios en memoria
(`test/fakes/in_memory_*`), que reimplementan ese `WHERE` en Dart. El SQL de
`lib/src/repositories/` no lo ejecuta ningún test: un `WHERE` mal escrito pasa
la suite entera. Al tocar una consulta de autorización, revisala a mano y
probala contra el stack real. Un repositorio nuevo trae su doble en memoria.

### El DM no escribe la ficha de otra cuenta

Es la frontera de diseño del Modo DM, y se sostuvo incluso donde parecía natural
cruzarla: subir de nivel, repartir oro, entregar objetos y conceder Inspiración
Heroica son **avisos**, no escrituras. El jugador los anota en su propia ficha.
Hay pruebas negativas que comparan el documento del personaje antes y después.

El DM escribe solo lo suyo: campañas, capítulos, cuaderno, combates, sus
monstruos, sus PNJ (con sus PG y su estado por campaña) y las escenas de
música. Los PG de los jugadores en combate salen del encuentro, no de la ficha.

Lo que el DM guarda dentro de la campaña (las escenas de música) no viaja a la
campaña que recibe el jugador: se poda en la consulta y en
`Campaign.playerView()`. Un campo nuevo del DM en `Campaign` pide la misma
doble poda y su prueba.

### El catálogo se prueba por reglas, no por conteos

`packages/dnd_engine/test/content_integrity_test.dart` no fija cuántas clases,
dotes o conjuros hay: un conteo solo falla cuando se agrega contenido a
propósito. Lo que fija son reglas — que toda referencia apunte a un id real,
que las fórmulas evalúen, el techo de VD del pozo de Forma Salvaje, la
procedencia SRD que decide la atribución CC BY. Si una se rompe, es un aviso y
no un test molesto.

Los catálogos grandes se generan con herramientas commiteadas en
`packages/dnd_engine/tool/`, y varias **parchean** en vez de generar: hay un
orden y un paso final (`apply_voseo.dart`, porque el SRD en español está en
tuteo) que quien regenera suele olvidar; `content_integrity_test` lo avisa. No
edites `creatures.json` a mano: corré `generate_bestiary.dart`. Ojo que el PDF
del SRD en español está **en metros** y el catálogo en pies. Orden, fuentes y
precedencia: `docs/desarrollo/contenido-y-reglas.md`.

El inglés del catálogo vive aparte, en `X.en.json` junto a cada `X.json`, y
se **corrige a mano**: es la excepción a no editar lo generado. Regenerar el
español deja huellas desfasadas que el test señala; cómo completarlo y
cuándo correr `translate_content.dart --refresh` está en
`docs/desarrollo/contenido-y-reglas.md` §Traducción al inglés. Un catálogo
nuevo se registra además en los assets de `packages/dnd_app/pubspec.yaml`.

## Frontend

La guía completa es `docs/desarrollo/diseno-web.md`, y su §8 es el catálogo de
componentes: **antes de crear un widget visual nuevo, buscá ahí**.

Lo que más se olvida:

- Los colores salen de `context.palette` (`AppPalette`, un `ThemeExtension`).
  **Nunca un hex literal**, nunca `Colors.red` / `Colors.grey`.
- Hay **tres niveles de fondo y no más**: `scaffold` → `surface` → `plaque`. La
  placa siempre se hunde, nunca se eleva. Sin `elevation`, sin sombras para
  separar superficies.
- Georgia solo para títulos y valores de plaqueta. Un número pensado para
  comparar contra el de al lado va en sans negrita con
  `FontFeature.tabularFigures()`.
- Radio 12 por defecto (tarjetas, placas) y 20 para pills; el resto de la
  escala está en `diseno-web.md` §5.1.
- Para medir el ancho disponible, `LayoutBuilder` y **nunca `MediaQuery.size`**:
  el panel lateral de 236 px es invisible para `MediaQuery`.
- Todo `IconButton` lleva `tooltip`.
- Los diálogos usan `AppDialog`, no `AlertDialog` ni `SimpleDialog`.
- **Subtítulos y explicaciones, los mínimos**: solo cuando sin ellos no se
  entiende qué hace la acción. El rótulo tiene que alcanzar solo. Ver
  `docs/desarrollo/textos.md` §Subtítulos y explicaciones.
- **Todo texto visible sale de `context.l10n`** (`lib/l10n/app_es.arb` y
  `app_en.arb`, las dos claves en el mismo commit): la interfaz se ofrece en
  español e inglés. Nunca un literal suelto en un widget:
  `test/l10n_no_literals_test.dart` falla, y `l10n_parity_test.dart` si falta
  una clave en un idioma. Cómo agregar un texto y el glosario en inglés:
  `docs/desarrollo/textos.md`.
- Los rótulos del motor (`label`) siguen a `ContentLanguage.current`, un estado
  global: un test que lo cambia lo restaura en `tearDown`.

Los widgets de estado ya existen y se usan siempre los mismos: `AppErrorView`
(con `onRetry`), `AppBusyLabel` (el texto es obligatorio) y `AppEmptyState`,
que distingue «no hay nada» de «nada coincide con la búsqueda» — son
situaciones distintas y piden acciones distintas.

## Tests

Un test entra si su falla significa que una regla o una funcionalidad está
rota. No entran: conteos del catálogo, nombres o prosa transcriptos del
manual, correcciones de OCR ya aplicadas, constantes comparadas consigo mismas,
layout y estilo (anchos, desbordes, colores, animaciones: eso lo mira una
persona) ni tests de las herramientas de `tool/`, cuya salida ya valida
`content_integrity_test`.

**Evitá rigurosamente crear tests innecesarios o temporales.** Antes de sumar
uno, fijate si ya hay otro que cubra la misma regla, y no escribas tests para
verificar un arreglo puntual, explorar un comportamiento o dejar constancia de
un dato: eso se comprueba una vez y no se commitea. Cada test que entra se
paga en cada corrida de CI y en cada despliegue.

Los tests de widget montan el árbol real contra `FakeApiServer`
(`packages/dnd_app/test/fakes/fake_api_server.dart`), un doble en memoria que
reproduce el **contrato observable** de cada endpoint. Cuando agregues una ruta
al servidor, agregala también ahí — y con las mismas podas, porque un doble más
permisivo deja pasar una pantalla que muestra lo que no debe.

Convenciones del repositorio: nombres de test en español, contenido SRD real
cargado en `setUpAll` con `ContentRepository.loadFromDirectory`, valores
esperados **derivados del catálogo** (`repo.creature('...')!`) y no literales, y
`expect(tester.takeException(), isNull)` al cierre.

## Deuda marcada

Buscá `ponytail:` en el código: son simplificaciones deliberadas, cada una con
su techo y su camino de salida escritos al lado. Antes de "arreglar" una,
leela — puede ser una decisión y no un olvido. Las que más se tropiezan:

- Los formularios de homebrew (`lib/homebrew/forms/`) **no editan** todos los
  campos —prerrequisito de una dote, cargas de un objeto, salvaciones de una
  criatura, equipo de un trasfondo—: los conservan del original. Un campo nuevo
  en esos modelos no aparece en el formulario por sí solo.
- `tool/l10n_literals.dart` es una heurística sobre el texto fuente: no ve
  cadenas multilínea ni texto armado por partes, así que un `flutter test` en
  verde no prueba que no haya texto suelto. Si sobra, `// l10n-ignore: motivo`.

## Documentación

El mapa y la convención de mantenimiento están en `docs/README.md`. No copies
acá contenido de esas guías: enlazalo para que exista una sola fuente vigente.
Si el código y una guía discrepan, manda el código y la guía se corrige en el
mismo cambio.

- `docs/arquitectura/modo-dm.md` — seguridad y contratos del Modo DM.
- `docs/arquitectura/mcp.md` — el conector de Claude: autorización y herramientas.
- `docs/desarrollo/contenido-y-reglas.md` — fuentes, catálogo y validación.
- `docs/desarrollo/diseno-web.md` — sistema visual y componentes.
- `docs/desarrollo/textos.md` — glosario y convenciones de los textos visibles,
  en español e inglés.
- `docs/desarrollo/versionado-y-changelog.md` — versión visible y `CHANGELOG.md`.
- `docs/operaciones/despliegue.md` — runbook del stack y CI/CD.

Fuera de Git, y solo en las máquinas que los tengan:
`docs/arquitectura/multiclase.md` (borrador del modelo de la multiclase) y
`docs/operaciones/pruebas-en-produccion.md` (registro de pruebas manuales). Se
consultan si están, pero no se citan como requisito.

Los cambios planificados con OpenSpec viven en `openspec/`, que Git ignora: es
local de cada máquina (`specs/` vigentes, `changes/archive/` hechos) y su
`config.yaml` resume estas mismas reglas. No lo enlaces como requisito.
