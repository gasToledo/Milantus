# Estándar de calidad del Quiz

Toda pregunta del Quiz sale del catálogo y de la ficha. Ninguna se escribe a
mano: el motor la arma en `packages/dnd_engine/lib/src/engine/quiz.dart` y la
pantalla (`packages/dnd_web/src/quiz/QuizPage.tsx`) le pone el enunciado con
una plantilla por tipo (`quizAsk` en `src/i18n/texts.ts`). Por eso el estándar
se aplica **al tipo de pregunta**, no a preguntas sueltas. Un tipo nuevo
cumple todas las reglas de abajo, o no entra.

Cada regla dice cómo se controla: **test** (lo verifica
`packages/dnd_engine/test/quiz_test.dart`) o **revisión** (lo mira una persona
al sumar el tipo y al jugar).

## 1. Qué se pregunta

- **Una regla del juego, no el estado de la ficha.** «¿Qué CA da la cota de
  malla?» se puede preguntar; «¿qué CA tenés?» no, porque se contesta leyendo
  la ficha. *Revisión.*
- **Un dato que se usa en la mesa.** Costo, peso o página del libro no se
  preguntan. El criterio: saber la respuesta cambia lo que hacés en una
  partida. *Revisión.*
- **Un dato estable.** Se pregunta el valor del catálogo, no uno que cambia
  según dotes, objetos o reglas opcionales. La velocidad de una especie sí;
  la velocidad del personaje no. *Revisión.*
- **Reglas de 2024.** Si la regla de 2014 era otra, la respuesta es la de
  2024. Que la diferencia confunda está bien: sirve para aprender. *Test:*
  `verificar` contrasta la respuesta con el catálogo.
- **Ni trivial ni absurda.** Una pregunta que casi todos aciertan sin haber
  estudiado es fácil. Las fáciles comparten un solo lugar por ronda (`_easy`):
  hoy son la característica de una habilidad, el dado de golpe y las
  salvaciones de la clase. Un tipo nuevo así entra en ese grupo, o no entra.
  *Test.*

## 2. El enunciado

- **Se contesta sin ver las opciones.** Tapando las opciones, quien sabe la
  regla tiene que poder decir la respuesta. Si no puede, el enunciado es vago
  («¿qué sabés de X?»). *Revisión.*
- **Nombra al sujeto.** Se dice «el trasfondo Sabio», no «tu trasfondo»: la
  pregunta es del trasfondo, no de qué eligió el personaje. *Revisión.*
- **Pregunta una sola cosa.** Si hace falta aclarar algo («a dos manos», «en
  nivel 5»), la aclaración va en el enunciado y no en una opción. *Revisión.*
- **En positivo.** Nada de «¿cuál NO…?»: se lee mal y premia el descarte. El
  formato al revés («¿cuál de estos requiere concentración?») está bien
  porque pregunta en positivo. *Revisión.*
- **Sin pistas de gramática.** El enunciado no puede concordar en género o
  número solo con la correcta («¿Qué es una…?» con una sola opción femenina).
  Las plantillas evitan el artículo cuando las opciones no comparten género.
  *Revisión.*
- **Con los términos del manual.** Se usan las palabras del glosario de
  [Textos de la interfaz](textos.md), en voseo, y en las dos lenguas. *Revisión;
  `tsc` falla si falta la plantilla en un idioma.*
- **Cita sin la respuesta.** En las preguntas por texto, si la cita nombra la
  opción correcta («Furia» en el texto de Furia), no se pregunta. Si nombra un
  distractor, ese distractor no se ofrece (`_mentioned`). *Test.*

## 3. Las opciones

- **Cuatro opciones, salvo que el dato tenga menos valores.** La categoría de
  armadura tiene tres (ligera, media, pesada) y no se completa con una
  opción absurda. Nada de «todas las anteriores» ni «ninguna». *Revisión.*
- **Exactamente una correcta.** Ver la [regla 5](#5-una-sola-correcta).
  *Test.*
- **Del mismo campo y la misma granularidad.** Todas son escuelas, o todas
  son dados, o todas son distancias. Son valores reales del catálogo, nunca
  inventados, y cada una puede ser la correcta de otra pregunta del mismo
  tipo. Por eso Constitución no aparece en «¿qué característica usa la
  habilidad X?»: ninguna habilidad la usa. *Revisión.*
- **Distintas en los dos idiomas.** Dos opciones nunca tienen el mismo
  rótulo, ni en español ni en inglés. La identidad de la opción es su id, no
  el texto traducido (`_choose`). *Test:* `verificar` exige rótulos
  distintos y corre sobre rondas en los dos idiomas.
- **Ninguna se delata por la forma.** Las opciones tienen formato y largo
  parecidos: si una es mucho más larga, o es la única con paréntesis, se saca
  (`_maxOptionLength`, el dado versátil). *Revisión.*
- **Ninguna contiene a otra.** Si una opción incluye a otra («Incapacitado»
  dentro de «Paralizado»), las dos serían correctas. *Test*, con los casos de
  la regla 5.
- **Distractores cercanos cuando el dato lo permite.** Un distractor que
  confunde enseña más que uno al azar: la armadura de la misma categoría, el
  rasgo de la misma clase, el conjuro del mismo nivel. *Revisión.*
- **Los números van de menor a mayor.** Niveles, CA, dados y distancias se
  muestran ordenados: buscar el valor no tiene que costar más que saberlo. El
  lugar de la correcta sigue siendo al azar, porque lo deciden los valores.
  *Revisión.*
- **Los pares van en el orden del libro** («Fuerza y Constitución», ver
  `_join`), que no depende del idioma. *Revisión.*

## 4. La ronda

- **Un sujeto, una vez.** El mismo conjuro, rasgo, arma o armadura sale una
  sola vez, sin importar el tipo de pregunta (la `key` del candidato). *Test.*
- **Una respuesta, una vez por tipo.** Que «Conjuración» o «nivel 1» sea la
  correcta dos veces deja contestar la segunda por descarte. *Test.*
- **Dos preguntas por tipo, tres como techo.** Pasar de dos solo vale si sin
  eso la ronda no llega a diez. *Test* (el techo).
- **El sorteo reparte por tema, no por tipo.** Primero elige el tema (Clase,
  Especie, Trasfondo, Conjuros, Equipo, Reglas) y después el tipo, sin repetir
  el tema de la pregunta anterior si hay otro disponible. Si no, gana el tema
  que tiene más tipos. *Test:* Equipo no pasa de 6 en Reglas generales.
- **Se mezclan los formatos:** por nombre («¿qué escuela es X?»), por texto
  («¿qué rasgo se describe acá?») y al revés («¿cuál de estos…?»). Un tema que
  tiene un solo formato se nota a la tercera pregunta. *Revisión.*
- **Alcanza para varias rondas.** Cada clase de ronda (Reglas generales, o un
  personaje de nivel bajo) genera al menos **50 preguntas distintas**: con 27,
  en tres rondas ya salió todo. *Revisión:* se cuenta cada par
  sujeto–respuesta con 30 semillas y `count: 400`. Hoy el pícaro 3 da 95 y el
  guerrero 1 da 123.
- **La misma semilla da la misma ronda,** en los dos idiomas. *Test.*

## 5. Una sola correcta

Cada tipo anota en el código qué otras opciones también serían correctas, y
las saca de los distractores:

| Caso | Por qué serían dos correctas | Dónde se resuelve |
|---|---|---|
| Estados que incluyen a otro | Paralizado también es incapacitado | `_conditionSupersets` |
| La cita nombra otro estado | «Estás incapacitado» en el texto de Aturdido | `_conditionNamed` |
| Dado versátil | 1d8 y 1d10 son los dos daños de la espada larga | `weaponDamage` |
| Alcance «Personal» | Lo comparten casi todos los conjuros sobre uno mismo | `selfAmbiguous` |
| Fila de progresión | En el nivel 7 todavía tenés 3 usos de Furia | `_progressAt` |
| Dos rasgos con el mismo texto | Magia del Legado antes de nombrar el conjuro | `allow` de `classFeatureByText` |
| Dos duraciones iguales | «24 horas» y «1 día» | `_durationRank` en `spellDuration` |
| Dos valores con el mismo rótulo | Dos armaduras con la misma cuenta de CA | ids por valor (`_acId`) |

Los datos se cargan con la procedencia que pide
[Contenido y reglas](contenido-y-reglas.md). Si una respuesta del Quiz
discrepa con el libro, se corrige el catálogo, no el Quiz.

## 6. Después de contestar

- **Se muestra la correcta,** y la elegida si fue otra. *Revisión.*
- **Si el dato pide contexto, se muestra.** En los conjuros, la ficha del
  conjuro. *Revisión.*
- **«Para repasar» lista las falladas** con la respuesta correcta, para
  estudiarlas sin volver a jugar. *Revisión.*

## Antes de sumar un tipo

1. Revisá cada regla y anotá en el código cada caso de segunda correcta.
2. El dato sale de un campo del catálogo o de la ficha, ya validado por
   `content_integrity_test`.
3. Escribí la plantilla en español y en inglés, nombrando al sujeto y sin
   pistas de género.
4. Sumale su rama a `verificar` en `quiz_test.dart`. `verificarRonda` ya
   cubre sujeto y respuesta repetidos, el tope de fáciles y el tope por tipo:
   no hace falta un test aparte.
5. Medí cuántas preguntas distintas suma a una ronda de nivel bajo.
6. Jugá tres rondas en `/v2/quiz` con un personaje de nivel bajo y anotá lo
   que encuentres según este estándar.
