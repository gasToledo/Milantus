# Changelog

Cambios visibles del producto, agrupados por versión. El formato y el flujo de
actualización están definidos en [Versionado y changelog](docs/desarrollo/versionado-y-changelog.md).

## [0.11.0+1] - 2026-09-22

### Nuevo

- Multiclase de personajes: historia ordenada de clases, subclases por clase,
  competencias parciales, fórmulas alternativas de CA y bloques de magia por
  fuente.
- Subida de nivel con elección de clase secundaria, advertencias de requisitos
  y persistencia de elecciones por clase.

### Modificado

- El motor combina espacios normales según el nivel de lanzador y separa los
  espacios de Magia de Pacto.
- Dashboard, ficha, Modo DM, ficha de miembro y retratos muestran la
  combinación de clases y niveles.
- La subida de nivel y el editor de conjuros conservan las elecciones de cada
  clase al revisar o modificar una fuente distinta.
- Los personajes de esquema 23 se leen mediante migración automática a esquema
  24; los respaldos y la API conservan el mismo contrato JSON.

### Eliminado

- El supuesto de que una ficha solo puede tener una clase en los cálculos de
  nivel, rasgos, recursos, conjuros y dados de golpe.

## [0.12.0+1] - 2026-09-23

### Nuevo

- PNJ en el Modo DM: una biblioteca propia del DM con PNJ sin estadísticas,
  con bloque copiado de una criatura o con ficha de personaje completa, con
  «cómo habla», apariencia, trasfondo, notas fechadas, tags y retrato.
- Cada campaña tiene su sección de PNJ con el estado de cada uno en esa mesa
  (vivo, muerto o desconocido); quitar un PNJ de una campaña no lo borra de la
  biblioteca.
- «Mostrar a la mesa» proyecta el retrato del PNJ y, si el DM quiere, su
  nombre, sin ningún otro dato.
- Exportar un PNJ a un `.zip` e importarlo en otra cuenta como copia propia,
  con su ficha, su homebrew y sus retratos; las campañas nunca viajan.
- Importar como PNJ el personaje que un jugador exportó desde «Mis
  personajes»: entra como PNJ con ficha, y su trasfondo y su Diario pasan al
  PNJ.
- Bandos en el combate: aliado, enemigo o neutral para PNJ y monstruos, con
  cambio de bando a mitad de combate y conteos «en pie» por bando.
- «Convertir en PNJ» desde la fila de un monstruo, conservando su lugar, sus
  PG, su bando y sus efectos.
- Al terminar y guardar un combate se puede marcar qué PNJ caídos murieron.
- El Bestiario filtra por rango de valor de desafío («VD desde» / «VD
  hasta») y ordena por nombre o por VD.
- «Sumar al combate de <campaña>» desde el perfil del Bestiario: suma las
  copias al combate de la campaña seleccionada sin salir del Bestiario ni
  perder la búsqueda y los filtros.

### Modificado

- El buscador de «Sumar al combate» encuentra criaturas sin importar acentos
  ni mayúsculas, muestra el VD de cada una y ya no corta la lista en 30
  resultados.

- «Sumar monstruo» pasa a ser «Sumar al combate», con solapas de PNJ y
  Bestiario; un PNJ no entra sin que el DM le elija bando.
- La tirada automática de iniciativa sigue siendo solo del bestiario: la de un
  PNJ se carga a mano.
- El Cuaderno del DM muestra aliados y neutrales en líneas propias; «cayeron N
  de M» cuenta solo enemigos.
- Las batallas que ve el jugador muestran solo a los enemigos y nombran a los
  PNJ por su criatura de base, nunca por su nombre propio.
- `Encounter` y `EncounterLog` pasan al esquema 2; los combates y registros
  anteriores se leen con los jugadores como aliados y los monstruos como
  enemigos.

### Eliminado

- Sin cambios.

## [0.13.0+1] - 2026-09-24

### Nuevo

- Una cuenta sin personajes ofrece probar con uno de ejemplo: lo suma como
  personaje propio y abre su ficha, para recorrerla antes de crear el primero.
- Creación de personaje: con el conjunto estándar se ofrece aplicar de un
  toque el reparto que el SRD sugiere para la clase elegida.

### Modificado

- Los avisos de error ya no muestran el nombre técnico de la excepción: dicen
  qué no se pudo hacer y, cuando lo hay, el motivo en castellano.
- Textos unificados según un glosario: «especie» en lugar de «raza»
  (incluido el primer paso de creación), «bonificador» en lugar de «bonus»,
  «Borrar» en todas las acciones de borrado y «archivo» en lugar de «pack» al
  importar homebrew. Los conteos ya no usan plurales entre paréntesis.
- Las características se abrevian como en el SRD en castellano (FUE, DES,
  CON, INT, SAB, CAR) y las distancias dicen «pies» en todas partes.
- En el tema claro, el texto de los botones dorados pasa a blanco y llega al
  contraste mínimo de accesibilidad (antes quedaba por debajo).
- Un cambio de PG, en la ficha o en el combate del DM, se marca con un destello
  carmesí si bajó y verde si subió, y la barra de la ficha recorre el tramo en
  vez de saltar.
- En el combate del DM, la marca de turno pasa de una fila a la siguiente sin
  saltar, y la planilla se desplaza para que la fila del turno quede a la
  vista.
- El contenido del SRD, el homebrew, los personajes y los ajustes se piden en
  paralelo al abrir la aplicación: el arranque con sesión tarda la mitad.
- Creación de personaje: el paso «Aptitudes» pasa a llamarse
  «Competencias», los métodos de puntuación usan los nombres del SRD
  («Conjunto estándar», «Coste en puntos»), los modificadores dejan de verse
  en carmesí, el resumen incluye las habilidades que da el trasfondo y el
  pie dice qué falta sin cortarse.
- Creación de personaje en el teléfono: cada paso arranca arriba, el stepper
  sigue al paso activo, y elegir especie, clase o trasfondo baja hasta su
  detalle, donde están el linaje, el aumento de características y las
  maestrías. Al terminar se abre la ficha del personaje nuevo.
- Creación de personaje: las opciones de equipo inicial dicen qué trae cada
  una antes de elegirla, y las tarjetas de trasfondo muestran su dote de
  origen y las características a las que suma.
- `dnd_engine`: las clases del catálogo SRD declaran su reparto sugerido
  (`suggestedScores`), y `Ability.code` separa los códigos de datos en inglés
  de la abreviatura que se muestra.

### Eliminado

- Sin cambios.

## [0.13.1+1] - 2026-09-24

### Nuevo

- Sin cambios.

### Modificado

- Los estilos de combate Duelo y Tiro con Arco suman en la ficha: +2 al daño
  con un arma cuerpo a cuerpo a una mano y sin otra arma, y +2 al ataque con
  armas a distancia. Antes eran solo texto.
- Al subir de nivel, el editor de conjuros muestra los preparados en la
  creación (abría en «0 de N»), y cambiarlos desde la ficha o la subida
  reemplaza de verdad los anteriores en vez de sumarse a ellos.
- El editor de conjuros nombra la clase («Paladín») y no su identificador.
- Los estilos «Guerrero Bendito» y «Guerrero Druídico» aparecían en inglés.
- Creación de personaje: el pie de faltantes ya no deja un punto antes de
  «(y N cosas más)».
- `dnd_engine`: `WeaponRuleEffect` admite bonos fijos al ataque y al daño con
  la condición de empuñar el arma sola en una mano, y `Character` resuelve los
  conjuros por clase con `spellIdsFor`, `cantripIdsFor` y `withClassSpells`.

### Eliminado

- Sin cambios.

## [0.14.0+1] - 2026-09-24

### Nuevo

- El Códice: todo el contenido del juego para leer sin crear un personaje
  ni editar nada. Se abre desde el panel lateral; tiene búsqueda en todo el
  catálogo, una lista con filtro por categoría (nivel de conjuro, rareza,
  categoría de dote) y el detalle de cada entrada. Las criaturas usan el
  Bestiario y el perfil del Modo DM, sin nada de combate.
- Un recurso puede declarar la CD que impone y el daño que causa por tramo de
  nivel; la ficha los muestra ya calculados. El Ataque de Aliento del
  Draconato es el primero: «CD 12 de DES · 1d10».
- En un teléfono, «Subir nivel» está en la barra de la ficha, sin abrir el
  menú.
- En el inventario, el nombre de un objeto mágico o de un paquete abre su
  descripción. Hasta ahora qué hacía un objeto no se podía leer en la app.

### Modificado

- Creación de personaje: los nombres de especie, clase y trasfondo usan hasta
  dos líneas (los «Heredero de Casa…» de Eberron se cortaban); el Draconato
  muestra su Ataque de Aliento y su visión en la oscuridad.
- Subida de nivel: la subclase elegida muestra los rasgos que da en ese nivel.
- Todo el catálogo pasa a voseo: subclases, clases, dotes, especies, conjuros
  y objetos mágicos tenían «puedes», «ganas» y plurales de vosotros
  («tenéis», «podéis») mezclados con el resto, y los objetos mágicos del SRD
  estaban enteros en tuteo. `tool/apply_voseo.dart` lo vuelve a aplicar
  después de regenerar, y un test falla si vuelve el tuteo.
- Las descripciones de los objetos mágicos se vuelven a extraer del PDF: ya
  no hay palabras partidas («pue-des»), títulos metidos en medio de una
  oración ni texto de un objeto en otro, y se leen por párrafos. Vuelven las
  frases que se cortaban (el Anillo de calidez, la Baraja misteriosa entera) y
  los nombres en cursiva que faltaban. Los centímetros pasan a pies y
  pulgadas, con la escala del manual (30 cm = 1 pie, 2,5 cm = 1 pulgada), y
  los pesos a libras y onzas (0,5 kg = 1 libra, 30 g = 1 onza), que es la
  unidad de la barra de carga. Los viajes pasan a millas (1,5 km = 1 milla) y
  los volúmenes a pies cúbicos.
- Los objetos mágicos cuyo texto dice cuánto pesan suman ese peso a la carga
  (la Bolsa de contención y el morral, 5 libras; el espejo atrapavidas, 50).
  Pesaban todos 0; los que el SRD no pesa siguen en 0.
- Creación de personaje: con escudo ya no se ofrece empuñar a dos manos, y la
  mano secundaria solo aparece con dos armas; las elecciones de objeto dicen
  si son de la clase o del trasfondo; «Coste en puntos» avisa los puntos sin
  gastar; con más de una elección de competencias, cada lista dice de qué
  origen es; las características muestran su nombre completo y su ayuda ya no
  tapa el valor.
- Subida de nivel: el total de pasos no cambia al resolver una elección; los
  puntos de golpe y las elecciones de rasgos figuran como decisiones y no
  como cambios automáticos; antes de tirar no se muestra un total que parece
  el resultado; el paso de conjuros dice cuántos hay preparados y avisa los
  cupos libres; y se corrigieron textos (sin género para el personaje, sin
  «compilar», voseo en Arma Sagrada, «También ganás»).

### Eliminado

- Sin cambios.

## [0.15.0+1] - 2026-09-24

### Nuevo

- Pacto del Grimorio pide los tres trucos y los dos rituales del Libro de las
  Sombras, al crear el personaje, al subir de nivel y desde la ficha. Quedan
  siempre preparados sin ocupar cupo.
- Descarga Agónica pide a qué truco de Brujo se aplica, y la ficha muestra el
  bono al daño en ese truco y en su detalle («+4 al daño (Descarga
  Agónica)»).
- El asistente de creación pide la aptitud mágica de la dote de origen cuando
  la deja elegir (Iniciado en la Magia del Acólito, entre otros).

### Modificado

- Pasos del Feérico da tantos usos gratis de Paso Brumoso como el modificador
  de Carisma (mínimo uno), como dice la regla. Daba el bonificador por
  competencia: 2 usos a un Brujo con +3.
- La subida de nivel no se confirma con un truco o un conjuro nuevo sin
  elegir, y el resumen marca la revisión de conjuros como decisión cuando el
  nivel trae cupo nuevo. La ficha avisa si faltan trucos o conjuros
  preparados.
- Las elecciones de conjuros de una invocación tomada en la misma subida
  aparecen en el paso de conjuros a elección; antes no se veían hasta
  confirmar.
- El equipo inicial arranca puesto: armadura, escudo y armas del paquete con
  los que la clase es competente. El paso lo explica y respeta lo que el
  jugador cambie a mano.
- Las opciones de conjuros con botón de información ya no desbordan la línea
  con nombres largos.

### Eliminado

- Sin cambios.

## [0.16.0+1] - 2026-09-26

### Nuevo

- La placa de Iniciativa de la ficha se toca y dice de dónde sale el número:
  la Destreza, cada bono con su fuente (Alerta, Emboscador Temible) y el
  Cansancio si lo hay.
- Al tirar iniciativa, cada jugador muestra su modificador junto al casillero
  («d20 + 4»), para ver si el número que canta cierra.

### Modificado

- El paso de conjuros de la subida de nivel muestra el cupo de trucos junto al
  de preparados y dice qué falta elegir. Con el conjuro listo y el truco
  pendiente decía «Conjuros actualizados» y el truco solo aparecía en el aviso
  del pie.
- La revisión final de la subida cuenta bien los trucos y conjuros elegidos:
  después de pasar por el editor mostraba «4 → 0».
- En el paso de conjuros a elección de la subida, los cupos que el nivel trae
  sin llenar van primero y los ya elegidos quedan abajo, bajo «Elegidos en
  niveles anteriores». El truco de Descarga Agónica aparecía al fondo, debajo
  del Libro de las Sombras y de Iniciado en la Magia ya completos.
- Homebrew es una sección del Modo DM, junto al Bestiario y los PNJ, y ya no
  está en el panel del jugador: crear contenido es trabajo del DM. El homebrew
  sigue siendo de la cuenta y se usa igual en sus personajes. En pantallas
  angostas sus categorías se abren desde la barra de la sección, y el menú del
  Modo DM sigue arriba para ir a otra.
- En pantallas angostas el Códice tiene la flecha de volver a la izquierda y
  las categorías en un botón a la derecha. El menú de categorías ocupaba el
  lugar de la flecha y no había forma de salir. La barra dice en qué categoría
  se está («Códice · Dotes»).
- En Homebrew, el botón de categorías usa otro ícono que el menú del Modo DM:
  en un teléfono eran dos ☰ iguales, uno encima del otro.
- Importar un PNJ con ficha suma su homebrew al catálogo en el momento. Se
  guardaba en la cuenta, pero la ficha mostraba esos objetos como «No está en
  el catálogo» hasta recargar la página.
- La dote Alerta suma el bonificador por competencia a la iniciativa, y el
  Emboscador Temible del Acechador en la Penumbra suma el modificador de
  Sabiduría. Los dos eran solo texto: un Guardia con DES +2 mostraba +2 en vez
  de +4. En Forma Salvaje el druida conserva esos bonos sobre la Destreza de
  la bestia.
- El paso Clase de la creación arranca sin clase elegida, igual que la
  especie. Mostraba al Guerrero marcado sin que nadie lo eligiera, también al
  crear un PNJ jugable.
- Las píldoras elegibles ya no llevan tilde al elegirlas: las ensanchaba, la
  fila se reacomodaba y el toque siguiente caía en otra opción (estilos de
  combate, idiomas, maestrías). La selección se sigue viendo por el borde, el
  fondo y el texto dorados.
- Borrar una campaña avisa todo lo que se pierde —capítulos, notas del
  Cuaderno, combate abierto e historial de combates— y que los PNJ se quedan en
  la biblioteca. Antes solo hablaba de los personajes, que no se pierden.
- En la lista de PNJ de la campaña, tocar el nombre abre el PNJ, como en la
  biblioteca. Antes solo se llegaba por ⋯ → «Abrir ficha».
- El creador de un PNJ jugable dice «Crear PNJ» y «¿Descartar este PNJ?» en
  vez de hablar de un personaje.
- Las filas del combate rotulan la CA; el número suelto no decía qué era.
- Los monstruos repetidos llevan todos número: con dos esqueletos quedan
  «Esqueleto 1» y «Esqueleto 2», y el que estaba solo pasa a ser el 1. La
  numeración sigue desde el número más alto, así que sacar uno no hace que el
  siguiente repita un número en uso.

### Eliminado

- El Códice ya no muestra las criaturas: lo abre cualquier jugador y los
  perfiles de los monstruos son del DM. Se siguen leyendo en el Bestiario del
  Modo DM.

## [0.17.0+1] - 2026-09-27

### Nuevo

- El editor de efectos del homebrew ofrece «Bonificador a la iniciativa», con
  un valor fijo y la opción de sumar el bonificador por competencia, como
  Alerta. Una dote propia que mejorara la iniciativa solo se podía cargar por
  JSON.
- Los objetos homebrew tienen «Otros efectos», con el mismo editor que las
  dotes: además de CA y resistencias, ya se puede armar una Capa de protección
  (salvaciones) o unos Guanteletes de fuerza de ogro (fijar la Fuerza).

### Modificado

- Elegir la categoría de una armadura homebrew trae la Destreza del manual:
  media hasta +2, pesada sin Destreza. Una armadura media se guardaba sumando
  la Destreza entera y la ficha daba un punto de CA de más con DES +3.
- En el editor de efectos, los valores dicen su unidad («Alcance en pies»,
  «Pies») y arrancan en el número del manual: la visión en la oscuridad nacía
  de un pie.
- Habilidades y tipos de daño salen en orden alfabético castellano en todo el
  homebrew; seguían el orden del manual en inglés.
- El formulario de criatura usa rótulos cortos con el ejemplo dentro del
  campo, y dice «Bonificador de ataque» e «Iniciativa» en vez de «Bono». Se
  cortaban en «Valor de desafío (p.ej. 1/4 o …». En la vista previa angosta,
  las placas dicen «PG» y «VD» en vez de «PUNTOS DE GO…».
- Las características de una criatura homebrew se cargan en dos filas de tres;
  quedaban cinco y Carisma sola abajo.
- La especie homebrew dice «Velocidad (pies)» en vez de «(ft)», y el lema
  aclara que se ve al elegirla.
- Un conjuro sin escuela ya no muestra «Truco ·» con el separador colgando.
- Los menús desplegables se abren con el fondo de las tarjetas, en toda la
  aplicación. Tenían el fondo violeta de Material.
- En los formularios del homebrew, el resumen de cada sección plegada queda
  contra el borde derecho; cambiaba de lugar según el largo del título.
- El Cuaderno resume un combate como «contra Esqueleto ×2»; decía «contra
  2 Esqueleto», sin plural.

### Eliminado

- Sin cambios.

## [0.18.0+1] - 2026-09-28

### Nuevo

- Comprar y vender con las monedas de la ficha. En «Agregar objeto» cada
  fila suma «Comprar» junto a «Agregar» (que sigue siendo gratis, para el
  botín), y arriba se ve la bolsa. Comprar pide la cantidad y el precio —el
  del catálogo, corregible en po · pp · pc—, muestra qué monedas salen, el
  vuelto y cómo queda la bolsa, y si no alcanza se deshabilita diciendo
  cuánto falta. «Vender…», en el menú de cada objeto, sugiere la mitad del
  precio. Las dos se deshacen desde el cartel y quedan anotadas en una
  entrada «Cuentas» del Diario, que se crea sola.
- Imponer las Manos es una reserva en Combate: 5 × nivel de Paladín, que se
  ve como «restantes / máximo» y se gasta o recupera en cantidades. Era solo
  texto.

### Modificado

- Un personaje de nivel 20 ya no puede subir a 21: la flecha de la barra y
  el ítem del panel dicen «Nivel máximo».
- El resumen de la subida de nivel ya no anuncia «Estilo de Combate — ELEGÍS
  VOS» en cada nivel cuando no hay nada que elegir; solo cuando falta elegir
  o se puede revisar. Una mejora de características completa ya no muestra
  en rojo «Elegí una dote para continuar».
- El Aura de Protección suma el mod. de Carisma (mínimo +1) a todas las
  salvaciones, y los Golpes Radiantes suman 1d8 radiante a las armas cuerpo
  a cuerpo, en la ficha y en la vista del DM. Las Auras de Entrega y de
  Coraje figuran en «Inmunidades».
- El estado hechizado dice «Hechizado» también en «Inmunidades», donde decía
  «Encantado».
- Don de la Fortaleza y Bendición de Siberys aparecen con su nombre en
  «Rasgos y dotes»; figuraban como «Mejora de Característica», que es otra
  dote. Maestro de Armas y Marca Dracónica Potente ya no repiten su +1 como
  un rasgo más.
- Don del Ataque Imparable ofrece su +1 solo en Fuerza o Destreza, y Don del
  Recuerdo de Conjuros solo en Inteligencia, Sabiduría o Carisma, como dice
  su texto. La ficha avisa si una elección anterior quedó en otra.
- La revisión de la subida de nivel dice «Recurso» para el Ataque de Aliento;
  decía «Recurso de clase».
- Las fichas de una sola clase guardadas antes de la multiclase ya no avisan
  que su Estilo de Combate «no se puede elegir más de una vez» ni que tienen
  elecciones de «un rasgo que ya no tenés». La migración había dejado una
  copia de cada elección por clase, y la validación la contaba como una
  segunda. Tampoco la suma el compilador: si el jugador cambiaba de estilo, la
  copia vieja seguía aplicando su dote.
- La creación de personajes ya no exige elegir el equipo de un trasfondo (o
  una clase) que no trae ninguno: con un trasfondo homebrew el paso pedía
  elegir en un desplegable vacío y no se podía terminar. Ahora dice que no
  trae equipo inicial.
- Toda dote tomada aparece en «Rasgos y dotes». Las homebrew, y Duro y tres de
  las Resilientes del catálogo, se aplicaban sin figurar en la ficha; ahora se
  muestran con su nombre y su descripción. Un rasgo sin descripción ya no abre
  un panel vacío.
- Al elegir una dote en la subida de nivel, el detalle dice qué concede
  («Concede: SAB +1 · Competencia: Percepción») cuando la dote no lo cuenta
  en un rasgo: las homebrew mostraban solo su descripción.
- El detalle de un trasfondo en la creación nombra las herramientas que da,
  que no se eligen en ningún paso.
- Un objeto homebrew con rareza se rotula «Objeto mágico» en el inventario y
  el buscador; decía «Equipo» y quedaba entre las mochilas.
- El aviso de una elección que quedó sin rasgo nombra el rasgo («Estilo de
  Combate (Guerrero)») en vez de su id interno.
- Los textos de reglas escritos en la app dicen «bonificador por
  competencia», como pide el glosario.
- Un montón de armas equipado es un ataque y un arma en la mano: ocho
  jabalinas eran ocho filas iguales en Ataques. Las armas ligeras siguen
  contando hasta dos, una por mano.

### Eliminado

- Sin cambios.

## [0.19.0+1] - 2026-09-28

### Nuevo

- La creación de personaje deja gastar el oro de partida. En el paso Equipo,
  entre «Equipo inicial» y «Equipo puesto», la sección «Compras» dice cuánto
  queda y abre el catálogo en modo compra: cada toque suma uno, sin diálogo,
  al precio del manual. La lista permite ajustar la cantidad o sacar algo, y
  lo comprado aparece en «Equipo puesto» (puesto si el personaje sabe
  usarlo). El Paladín que elegía 150 po nacía con el oro y sin forma de
  gastarlo hasta terminar.

### Modificado

- En la creación, el resumen de «Equipo inicial» muestra lo que traen las
  opciones, sin las compras. Si cambiar de opción deja compras que el oro ya
  no cubre, no se borran: el paso avisa cuánto falta y no se puede cerrar
  hasta ajustarlas.

### Eliminado

- Sin cambios.

## [0.20.0+1] - 2026-09-29

### Nuevo

- La aplicación se puede usar en inglés. El panel lateral tiene un selector de
  idioma (Español · English) sobre el de tema: la elección se recuerda en el
  navegador y, si no hay ninguna, se usa el idioma del navegador. Cambia toda
  la interfaz al instante —fichas, creación, subida de nivel, códice, homebrew
  y Modo DM—, el título de la pestaña y el idioma que declara la página, sin
  perder lo que se estaba escribiendo.
- Todo texto nuevo de la interfaz nace en los dos idiomas: un test falla si
  aparece texto visible suelto en un widget, y otro si una clave existe en un
  idioma y no en el otro.

### Modificado

- Los nombres del catálogo del reglamento (clases, dotes, conjuros, criaturas,
  condiciones), los avisos técnicos de red y de archivos, y el prompt del
  generador de retratos siguen en español por ahora: es la segunda etapa de
  este trabajo.
- Los tooltips propios de Material (menú de navegación, calendario) salen en el
  idioma elegido.
- En la creación, «Compras» pide elegir primero las opciones de equipo en vez
  de decir que no traen oro, y el catálogo ya no ofrece objetos mágicos.
- Un monto en cero se lee «0 po» en vez de «0 pc».
- En ancho de teléfono, el catálogo de objetos muestra los filtros en un solo
  renglón que se desliza, y los objetos sin peso ya no muestran una raya
  suelta entre los datos.
- El equipo recibido en la creación se pone solo hasta llenar las dos manos:
  el Guerrero ya no nace empuñando cuatro armas a la vez.

### Eliminado

- Sin cambios.

## [0.21.0+1] - 2026-10-06

### Nuevo

- Con la interfaz en inglés, el contenido del reglamento también está en
  inglés: nombres y descripciones de clases, subclases, especies, linajes,
  trasfondos, dotes, conjuros, criaturas, armas, armaduras y objetos, con los
  términos del SRD 5.2 en inglés. Cambiar de idioma rehace el catálogo al
  instante, con la ficha, el Códice o un combate abiertos.
- Los perfiles de criaturas muestran en inglés tipo, tamaño, sentidos,
  velocidad, idiomas, defensas, acciones y rasgos, y siguen sirviendo para
  Forma Salvaje, combate y planos del Artífice igual que en español.

### Modificado

- Los avisos de validación de la ficha, las líneas nuevas del diario de
  compras y ventas, las recompensas de capítulo y los errores (del servidor,
  de red y de archivos) salen en el idioma elegido.
- El prompt del generador de retratos va siempre en inglés, con cualquier
  idioma de interfaz.
- Los formularios homebrew y los filtros del Códice muestran escuela, tiempo
  de lanzamiento, tamaño y tipo en el idioma elegido; lo guardado no cambia.

### Eliminado

- Sin cambios.

## [0.22.0+1] - 2026-10-13

### Nuevo

- Dificultad del encuentro en el Modo DM: mientras se arma un combate, una
  banda dice si es de dificultad baja, moderada, alta o extrema según el
  presupuesto de PX del SRD 5.2.1, con el nivel de los personajes que
  entraron y el VD de cada enemigo. Cada fila muestra los PX que suma.
- Los aliados cuentan: un PNJ aliado con ficha suma su nivel al presupuesto,
  y una criatura aliada resta sus PX de los enemigos.
- Dos avisos del SRD acompañan al número: más de dos enemigos por personaje,
  y un enemigo cuyo VD supera el nivel más bajo de la mesa.
- Exportar un personaje incluye el homebrew que usa su ficha, y al
  importarlo ese homebrew entra con él. Si un id ya existe en la cuenta con
  otro contenido, no se importa nada y se explica por qué.
- El Códice muestra los efectos de cada dote («+1 CAR», el conjuro que
  concede) junto a su descripción.
- Las criaturas homebrew muestran su tipo y tamaño en el idioma de la
  interfaz.

### Modificado

- Dos armas iguales se reparten entre la mano principal y la secundaria; el
  aviso de combate con dos armas vuelve a funcionar, y las marcas de mano
  secundaria y a dos manos valen también para armas mágicas.
- Bestiario: los ataques conservan su daño extra («más 5 (2d4) de daño
  radiante»), los perfiles ya no arrastran títulos de grupo ni acciones de
  otra criatura, y las salvaciones en inglés nombran la característica
  entera.
- Rociada venenosa, Rayo nauseabundo, Shillelagh e Infligir heridas dicen lo
  que dice el SRD 5.2.1.
- Las dotes separadas por característica ya no repiten «(+1 a X o Y)».
- Con la interfaz en inglés, el Cuaderno, las batallas de la pestaña Campaña
  y la criatura de base de un PNJ nombran las criaturas en inglés; la fecha
  del diario sigue el orden de cada idioma.
- Revisión de los textos en inglés: «Hit Point Die», «bundle of N», errores
  que empiezan con «Could not», «Reach» y «Range» separados en el bestiario,
  y ocho nombres de objetos mágicos como los escribe el libro.
- La banda de cifras del bestiario ya no corta sus rótulos en pantallas
  angostas.
- El lector de pantalla anuncia una sola vez la insignia de procedencia y el
  cartel de guardado, y nombra el retrato con el nombre entero.
- La importación de un PNJ cuyo homebrew choca con el de la cuenta responde
  409 `homebrew_conflict` en lugar de 400 (`dnd_server`).
- `dnd_engine`: `encounterDifficulty` y `xpForChallengeRating`.

### Eliminado

- Sin cambios.

## [0.23.0+1] - 2026-10-13

### Nuevo

- Ajustes es una sección propia, que se abre desde el panel lateral en el
  Modo Jugador y en el Modo DM. Cada cambio se guarda al tocarlo.
- «Al abrir Milantus»: se puede elegir que la aplicación arranque en el Modo
  DM en lugar del roster de personajes.
- «Mostrar la dificultad del encuentro»: apagado, el Modo DM no muestra la
  banda de dificultad ni los PX de cada fila. Viene prendido.
- Un interruptor «Jugador | DM» en lo alto del panel lateral cambia de modo
  desde cualquiera de los dos.

### Modificado

- El panel lateral es el mismo en los dos modos. El del Modo DM recupera la
  marca, «Sugerencias y errores», la cuenta con «Cerrar sesión» y la versión,
  que antes solo estaban en el Modo Jugador.
- El tema y el idioma pasan del pie del panel a Ajustes. En la ficha siguen
  donde estaban.
- En el Modo DM, «Nueva campaña» pasa a ser una fila al pie de la lista de
  campañas. En una ventana baja la navegación del DM se desplaza para llegar
  a las secciones de la campaña.
- Dificultad del encuentro: un PNJ enemigo con ficha de personaje ya cuenta.
  Descuenta su nivel del presupuesto, igual que un aliado con ficha lo suma;
  antes quedaba fuera de la cuenta con el aviso «Sin VD».
- En un teléfono, los PX de la banda de dificultad quedan alineados al borde
  derecho.

### Eliminado

- Los botones «Modo DM» y «Modo Jugador» del pie del panel: los reemplaza el
  interruptor de arriba.
- El diálogo de Ajustes con «Cancelar» y «Guardar»: lo reemplaza la sección.

## [0.24.0+1] - 2026-10-13

### Nuevo

- Sin cambios.

### Modificado

- Los paneles de la ficha, el Códice y la creación de personaje arrancan como
  el menú principal: la marca arriba y, en el lugar del interruptor de modo,
  un «← Mis personajes» para volver. Al pie muestran la versión.
- En la ficha, el cartel de guardado pasa al pie del panel, junto a la
  versión.
- El buscador del Códice toma la forma de pill del resto del panel.

### Eliminado

- El tema y el idioma del panel de la ficha: se cambian desde Ajustes, en el
  menú principal.
- La barra superior del Códice en pantalla ancha: la salida está en el panel.
  En pantalla angosta sigue estando.

## [0.25.0+1] - 2026-10-14

### Nuevo

- «Pantalla encendida» en Ajustes: con una ficha o el Modo DM abiertos, el
  dispositivo no apaga la pantalla. Se recuerda en cada dispositivo por
  separado y se ofrece donde el navegador lo permite.

### Modificado

- Menos subtítulos en toda la app: Ajustes, la subida de nivel, el Códice,
  Homebrew, los formularios de homebrew y varios diálogos del Modo DM. Los
  que quedan explican algo que el rótulo no dice, y varios se acortaron.
- En el teléfono, la barra de arriba del Modo DM es la misma que la del Modo
  Jugador: la marca, sin «Modo DM» ni el botón de nueva campaña, que sigue en
  el menú lateral.
- En la subida de nivel, lo elegido se puede cambiar antes de confirmar.
- En un cupo de una sola opción, tocar otra opción reemplaza la elegida en vez
  de pedir que se desmarque primero.

### Eliminado

- El apartado «Retratos» de Ajustes: el proveedor se elige en la pantalla de
  retratos, que es donde se usa.

## [0.26.0+1] - 2026-10-20

### Nuevo

- El Cuaderno de campaña muestra cuándo un personaje vinculado subió de nivel:
  quién, a qué nivel y en qué clase, dentro del capítulo en marcha.
- Un retrato propio o una imagen del Diario pueden ser un GIF animado. Se
  anima en el retrato grande y en la entrada abierta; en los medallones, las
  listas y la grilla del Diario se ve quieto, con su primer cuadro.

### Modificado

- Sin cambios.

### Eliminado

- Sin cambios.

## [0.27.0+1] - 2026-10-22

### Nuevo

- La ficha se puede imprimir o guardar como PDF desde «Imprimir ficha», en el
  panel: tres hojas en blanco y negro para jugar con lápiz, con los PG, los
  espacios y los usos en blanco para marcar, y los conjuros sin su texto.

### Modificado

- Sin cambios.

### Eliminado

- Sin cambios.

## [0.28.0+1] - 2026-10-23

### Nuevo

- Música en el Modo DM: cada campaña guarda escenas enlazadas desde YouTube
  o Spotify, que suenan desde un reproductor que acompaña todas las secciones
  y se minimiza. Al armar un combate pregunta si poner la música de combate.
  Los jugadores no ven nada de esto.

### Modificado

- La ficha impresa deja más lugar para el lápiz: margen vertical más amplio,
  huecos más anchos, renglones vacíos en ataques e inventario, monedas y carga
  en blanco, casillas de Inspiración Heroica, Cansancio y conjuros preparados,
  y espacio para condiciones y notas. Las habilidades van en orden alfabético
  del idioma, el modificador de cada característica se lee primero y cada
  hoja lleva al pie el nombre y su número.
- En ventanas de poco alto, como las de una notebook, el panel lateral del
  Modo DM deja fijas al pie las secciones de la campaña en curso, y los
  paneles que scrollean (Modo DM, Códice, Homebrew) muestran su barra.
- Las campañas pasan a la versión 2 de su documento, que suma las escenas de
  música; las guardadas antes se leen sin escenas.

### Eliminado

- Sin cambios.

## [0.29.0+1] - 2026-10-23

### Nuevo

- Sin cambios.

### Modificado

- Las escenas de música aceptan enlaces de YouTube Music, además de los de
  YouTube.

### Eliminado

- Las escenas de Spotify. Su reproductor embebido pasa solo vistas previas de
  30 segundos aunque el DM tenga la sesión iniciada, y sonar completo exige
  conectar la cuenta con Premium y un tope de cinco cuentas. Una escena de
  Spotify ya guardada queda sin reproducir, para cambiarle el enlace o
  borrarla.

## [0.30.0+1] - 2026-10-26

### Nuevo

- La ficha cuenta los usos de rasgos que antes eran solo texto: Inspiración
  Bárdica (con su dado, que sube con el nivel), Indómito, Golpe de Suerte,
  Recuperación Arcana, Recuperación Mágica, Astucia Mágica, veintiún rasgos de
  subclase con usos por descanso y los de especie (Afinidad con la Piedra,
  Descarga de Adrenalina, Aguante Incansable, Vuelo Dracónico, Forma Grande,
  Revelación Celestial y Resistencia al Letargo).
- Se eligen el segundo Estilo de Combate del Campeón, las tres Competencias
  Adicionales del Colegio del Saber, los conjuros del Arcanum Místico, la
  habilidad de Ajeno a los Sueños del Kalashtar y el Aspecto de lo Salvaje del
  Corazón Salvaje.

### Modificado

- Furia, Canalizar Divinidad, Forma Salvaje y Energía Psiónica recuperan un
  uso tras un descanso corto y todos tras uno largo, como dice la regla; antes
  el descanso corto los devolvía todos. Sacerdote Guerrero se recupera también
  con el descanso corto.
- El Colegio de la Danza calcula su Defensa sin Armadura con Carisma.

### Eliminado

- Sin cambios.

## [0.31.0+1] - 2026-10-26

### Nuevo

- Todo personaje tiene el golpe sin armas en sus ataques: 1 + Fuerza
  contundente, con competencia.
- Artes Marciales: el Monje sin armadura ni escudo, desarmado o con solo armas
  de monje, usa Destreza y el dado de Artes Marciales (1d6 a 1d12 según el
  nivel) para el golpe sin armas y sus armas de monje, y suma el golpe sin
  armas como acción adicional. Golpes Potenciados ofrece el daño de fuerza.
- El golpe sin armas también aprovecha el Daño Bárdico del Colegio de la Danza,
  el 1d4 del Matón de Taberna, el 1d6 de Combate sin Armas y el 1d8 radiante de
  los Golpes Radiantes del Paladín.

### Modificado

- El aviso «No hay arma equipada» mira si hay alguna arma en la mano, ya que la
  lista de ataques siempre tiene el golpe sin armas.

### Eliminado

- Sin cambios.

## [0.32.0+1] - 2026-10-26

### Nuevo

- La ficha marca las ventajas permanentes: «VENTAJA» en la salvación, la
  habilidad o la iniciativa que la tiene, con el rasgo que la da, y al pie de
  Salvaciones las que valen contra un estado, contra conjuros o en las
  salvaciones de muerte (Astucia Gnoma, Resistencia Enana, Sentir el Peligro,
  Instinto Salvaje, Atleta Sobresaliente y otras).
- Aprendiz de Mucho: el Bardo suma la mitad de su bonificador por competencia
  a las habilidades en las que no es competente, Percepción pasiva incluida.
- El tope de objetos sintonizados sube con los rasgos que lo dicen: el
  Artífice llega a 4, 5 y 6 y el Ladrón a 4. El inventario y el aviso de
  exceso usan el tope del personaje.
- Los ataques del Campeón muestran su rango de crítico: 19–20 con Crítico
  Mejorado y 18–20 con Crítico Superior, con armas y sin armas.
- Los dados que crecen con el nivel se ven en la ficha: el Ataque Furtivo
  (1d6 a 10d6) en la tarjeta de ataques, y el dado de superioridad del
  Maestro de Batalla y los dados psiónicos debajo de sus usos.

### Modificado

- Fulgor Protector y Fulgor Protector Mejorado (Dominio de la Luz) describen
  la regla 2024: ya no conceden el truco Luz y la mejora da PG temporales al
  objetivo del ataque.
- El golpe sin armas se muestra con las manos vacías o cuando un rasgo lo
  mejora; al lado de un arma común ya no aparece.
- Los dados de un recurso de clase (Inspiración Bárdica, superioridad,
  psiónicos) crecen con el nivel de esa clase y no con el total del
  personaje, que en un multiclase daba de más.

### Eliminado

- Sin cambios.

## [0.33.0+1] - 2026-10-26

### Nuevo

- La Furia del Bárbaro se prende desde la banda táctica de la ficha, en
  cualquier pestaña: una placa con los usos que quedan, que gasta uno al
  activarla y se pone en dorado mientras dura. Con armadura pesada o sin usos
  no se puede activar.
- En Furia, la ficha la aplica entera (resistencia a contundente, perforante
  y cortante, ventaja en pruebas y salvaciones de FUE y +2/+3/+4 al daño con
  Fuerza) y lo dice: un cartel arriba con lo que cambia y «Terminar», «FURIA
  +2» en cada ataque afectado y la Furia al lado de sus resistencias.
- La Furia termina sola al caer a 0 PG y al descansar.

### Modificado

- El golpe sin armas no aparece al lado de un arma por un bono fijo al daño o
  al crítico: solo cuando un rasgo le cambia el dado, la característica o le
  suma dados propios.

### Eliminado

- Sin cambios.

## [0.34.0+1] - 2026-10-26

### Nuevo

- La placa de Velocidad dice al pie las otras velocidades: trepar, nadar,
  volar o excavar. Errante del Explorador, el Ladrón, Afinidad Acuática del
  Círculo del Mar, Pantera y Salmón del Corazón Salvaje, Atleta y Don de las
  Profundidades las dan.
- La tarjeta Sentidos suma visión ciega, sentir vibraciones, visión
  verdadera y telepatía: Sentidos Salvajes, Acechador, Lucha a Ciegas,
  Visión Bruja, Don de la Visión Verdadera, Telepático y la telepatía del
  Kalashtar (10 × nivel).
- En Forma Salvaje, la ficha toma las velocidades y los sentidos de la
  bestia.

### Modificado

- La visión en la oscuridad que se gana «o aumenta 60 si ya la tenías»
  (Vista Umbral, Artes Sombrías, el Búho) ahora suma sobre la de la especie.
  Vista Umbral daba 90 pies, que era la regla de 2014.
- El Cansancio resta también a trepar, nadar y volar, no solo a caminar.

### Eliminado

- Sin cambios.

## [0.35.0+1] - 2026-10-26

### Nuevo

- Las subclases del Bárbaro cambian la Furia:
  - Corazón Salvaje: al entrar en Furia se elige Oso (resistencia a todo
    salvo fuerza, necrótico, psíquico y radiante), Águila o Lobo, y el cartel
    dice cuál.
  - Árbol del Mundo: PG temporales iguales al nivel de Bárbaro al entrar en
    Furia.
  - Berserker: en Furia, inmune a asustado y hechizado, y entrar en Furia los
    termina.
  - Fanático: 1d6 + la mitad del nivel de daño necrótico o radiante en los
    ataques mientras dura, y la reserva de dados de Guerrero de los Dioses.

### Modificado

- Marcar Incapacitado, o un estado que lo incluye (Paralizado, Petrificado,
  Aturdido, Inconsciente), termina la Furia y la Forma Salvaje, y la Furia no
  se puede volver a prender mientras dure. Quitarlo vuelve a habilitarla sin
  recargar la ficha.
- Quedar incapacitado o caer a 0 PG corta la concentración, y con ella se van
  los compañeros invocados que la sostenían.

### Eliminado

- Sin cambios.

## [0.36.0+1] - 2026-10-27

### Nuevo

- Las transformaciones de especie se prenden desde la ficha, como la Furia:
  - Draconato: Vuelo Dracónico da velocidad volando igual a la de caminar.
  - Goliat: Forma Grande suma 10 pies de velocidad y ventaja en las pruebas
    de Fuerza.
  - Aasimar: Revelación Celestial pregunta Alas Celestiales, Resplandor
    Interior o Sudario Necrótico; las Alas dan velocidad volando.
  - Cambiante: la Transformación da PG temporales iguales al doble del
    bonificador por competencia, más lo de su naturaleza bestial (+1 a la CA,
    mordisco de 1d6 perforante como acción adicional, 10 pies de velocidad o
    ventaja en las pruebas de Sabiduría).

### Modificado

- Quedar incapacitado ya no termina todo estado activo: la Forma Grande, la
  Revelación Celestial y la Transformación siguen; la Furia y el Vuelo
  Dracónico terminan.

### Eliminado

- Sin cambios.

## [0.37.0+1] - 2026-10-27

### Nuevo

- Más transformaciones se prenden desde la ficha:
  - Hechicería Dracónica: Alas de Dragón dan 60 pies de vuelo.
  - Círculo de las Estrellas: Forma Estelar gasta un uso de Forma Salvaje y
    pregunta Arquero, Cáliz o Dragón; en nivel 10 el Dragón vuela y en nivel
    14 la forma da resistencia a contundente, perforante y cortante.
  - Círculo del Mar: Ira de los Mares gasta Forma Salvaje; en nivel 10 da
    vuelo y resistencia a frío, relámpago y trueno.
  - Juramento de Entrega: Arma Sagrada suma el Carisma (mínimo +1) al ataque
    cuerpo a cuerpo y deja elegir daño radiante.
  - Las formas de nivel 20 del Paladín: Halo Sagrado, Campeón Ancestral,
    Leyenda Viviente (ventaja en Carisma) y Ángel Vengador (60 pies de
    vuelo).
  - Trance de Orden, El Tercer Ojo (con visión en la oscuridad de 120 pies)
    y Afinidad con la Piedra del Enano (sentido del temblor de 60 pies).

### Modificado

- Corregidos a las reglas 2024 los textos de Ira de los Mares, Forma
  Estelar, Constelaciones Centelleantes, Arma Sagrada, Campeón Ancestral,
  Leyenda Viviente y Ángel Vengador.

### Eliminado

- Sin cambios.

## [0.38.0+1] - 2026-10-27

### Nuevo

- Las Formas del Círculo de la Luna cambian la Forma Salvaje: el valor de
  desafío máximo es el nivel de Druida entre 3, la CA es 13 + SAB si le gana
  a la de la bestia y transformarse da PG temporales iguales al triple del
  nivel. Desde el nivel 6, los ataques de la bestia pueden hacer daño
  radiante y la SAB se suma a las salvaciones de CON.
- Paso de Luz Lunar lleva la cuenta de sus usos (tantos como el mod. de SAB).
- El Hechicero elige sus opciones de Metamagia (2, 4 y 6 en los niveles 2, 10
  y 17) y el Maestro de Batalla sus maniobras (3, 5, 7 y 9 en los niveles 3,
  7, 10 y 15), con el texto de cada una en la ficha. Se pueden cambiar al
  subir de nivel.
- La ficha del miembro que ve el DM muestra la Forma Salvaje y los estados
  activos (con sus números ya aplicados) y marca las ventajas en salvaciones
  y habilidades.

### Modificado

- Corregido a las reglas 2024 el texto de Paso de Luz Lunar, y los Dados de
  Superioridad ya no nombran maniobras de 2014.
- El aviso al transformarse dice los PG temporales que de verdad se ganaron.
- Con muchos cupos de sintonización (el Artífice llega a seis), en el celular
  las casillas se reparten en filas y el nombre del objeto ya no se corta.

### Eliminado

- Sin cambios.

## [Unreleased]

### Nuevo

- Sin cambios.

### Modificado

- Sin cambios.

### Eliminado

- Sin cambios.
