/// Qué significa cada elección de los formularios homebrew que no es un arma
/// (esas tienen su glosario en `weapon_properties.dart` y
/// `weapon_mastery.dart`).
///
/// Quien arma su primera armadura o su primer conjuro elige «Media» o
/// «Evocación» sin saber qué cambia, y el formulario se lo explica con estos
/// textos. Viven en el motor por el mismo motivo que los de arma: son reglas
/// del PHB 2024, no redacción de una pantalla, y así no se reparten por la UI.
/// Cada texto está en español y en inglés y se lee en el idioma activo.
///
/// Es **descriptivo**: el compilador no lee nada de acá. Las claves son los ids
/// que viajan en los datos (`medium`, `origin`, `Evocación`).
library;

import 'content_language.dart';

// ---------------------------------------------------------------- Armadura

Map<String, String> get armorCategoryRules => localized(
      const {
        'light':
            'Suma la Destreza entera. Ponérsela lleva 1 minuto y quitársela, otro.',
        'medium':
            'Suma la Destreza hasta un tope, que en el manual es +2. Ponérsela lleva '
                '5 minutos y quitársela, 1.',
        'heavy':
            'No suma Destreza, y suele exigir Fuerza. Ponérsela lleva 10 minutos y '
                'quitársela, 5.',
        'shield':
            'Se empuña en una mano y su CA se suma a la de la armadura. Ponérselo o '
                'quitárselo es la acción de Utilizar.',
      },
      const {
        'light':
            'Adds your full Dexterity. Donning it takes 1 minute, and doffing it another.',
        'medium':
            'Adds Dexterity up to a cap, which is +2 in the book. Donning it takes 5 minutes, and doffing it 1.',
        'heavy':
            'Adds no Dexterity, and often requires Strength. Donning it takes 10 minutes, and doffing it 5.',
        'shield':
            'Wielded in one hand, and its AC adds to the armor’s. Donning or doffing it takes the Utilize action.',
      },
    );

/// Lo que vale para las cuatro categorías de armadura.
String get armorTrainingRule => localized(
      'Sin entrenamiento con la categoría, toda prueba d20 con Fuerza o Destreza '
          'tiene desventaja y no se pueden lanzar conjuros.',
      'Without training in the category, every D20 Test that uses Strength or Dexterity has Disadvantage, and you can’t cast spells.',
    );

String get armorBaseAcRule => localized(
      'La CA de quien la lleva antes de sumar Destreza. Sin armadura, la base '
          'es 10.',
      'The wearer’s AC before adding Dexterity. Without armor, the base is 10.',
    );

String get shieldBaseAcRule => localized(
      'Lo que el escudo suma a la CA de quien lo empuña.',
      'What the shield adds to its wielder’s AC.',
    );

String get armorAddDexRule => localized(
      'Encendido, la CA suma el modificador de Destreza. Apagado, la CA es la '
          'base sola, como en una armadura pesada.',
      'On, the AC adds the Dexterity modifier. Off, the AC is the base alone, as with heavy armor.',
    );

String get armorMaxDexRule => localized(
      'La Destreza suma hasta este tope, nunca más. Vacío, suma entera, como en '
          'una armadura ligera.',
      'Dexterity adds up to this cap, never more. Empty, it adds in full, as with light armor.',
    );

String get armorStrengthRule => localized(
      'Quien la lleve puesta sin llegar a esa Fuerza pierde 10 pies de '
          'velocidad.',
      'Wearing it without that much Strength costs 10 feet of Speed.',
    );

String get armorStealthRule => localized(
      'Las pruebas de Destreza (Sigilo) de quien la lleve puesta tienen '
          'desventaja.',
      'The wearer’s Dexterity (Stealth) checks have Disadvantage.',
    );

// ----------------------------------------------------------------- Conjuro

String get spellCantripRule => localized(
      'Se lanza a voluntad, sin gastar espacios de conjuro. Suele hacer más '
          'daño a medida que el personaje sube de nivel.',
      'Cast at will, without expending spell slots. It usually deals more damage as the character levels up.',
    );

String spellLevelRule(int level) => localized(
      'Lanzarlo gasta un espacio de conjuro de nivel $level o superior. Muchos '
          'hacen más si se lanzan con un espacio mayor.',
      'Casting it expends a spell slot of level $level or higher. Many do more '
          'when cast with a higher slot.',
    );

/// Las ocho escuelas, por su nombre en español: es lo que guarda
/// `Spell.school` en el catálogo.
Map<String, String> get spellSchoolRules => localized(
      const {
        'Abjuración': 'Protege, bloquea y destierra.',
        'Adivinación':
            'Revela información: lo oculto, lo lejano, lo que vendrá.',
        'Conjuración':
            'Trae criaturas u objetos, o traslada de un lugar a otro.',
        'Encantamiento': 'Influye en la mente de otros.',
        'Evocación':
            'Crea energía: fuego, relámpago, fuerza, también curación.',
        'Ilusionismo': 'Engaña los sentidos o la mente.',
        'Nigromancia': 'Manipula la vida y la muerte.',
        'Transmutación':
            'Cambia las propiedades de una criatura, un objeto o un '
                'lugar.',
      },
      const {
        'Abjuración': 'Protects, blocks, and banishes.',
        'Adivinación':
            'Reveals information: the hidden, the distant, what’s to come.',
        'Conjuración':
            'Brings creatures or objects, or moves from one place to another.',
        'Encantamiento': 'Influences the minds of others.',
        'Evocación': 'Creates energy: fire, lightning, force, and healing too.',
        'Ilusionismo': 'Deceives the senses or the mind.',
        'Nigromancia': 'Manipulates life and death.',
        'Transmutación':
            'Changes the properties of a creature, an object, or a place.',
      },
    );

String get spellSchoolNote => localized(
      'La escuela no cambia cómo funciona el conjuro, pero la miran algunas '
          'reglas y subclases.',
      'The school doesn’t change how the spell works, but some rules and subclasses look at it.',
    );

/// Tiempos de lanzamiento, por el texto que guarda `Spell.castingTime`.
///
/// Los que tardan más de un turno comparten [spellLongCastingRule].
Map<String, String> get spellCastingTimeRules => localized(
      const {
        'Acción': 'Ocupa la acción del turno.',
        'Acción Adicional':
            'Ocupa la acción adicional del turno. Ese turno no se puede gastar otro '
                'espacio de conjuro en otro conjuro.',
        'Reacción':
            'Se lanza fuera del turno propio, en respuesta a algo. Lo que lo '
                'dispara va en la descripción.',
      },
      const {
        'Acción': 'Takes the turn’s action.',
        'Acción Adicional':
            'Takes the turn’s Bonus Action. That turn you can’t expend a spell slot on another spell.',
        'Reacción':
            'Cast outside your own turn, in response to something. What triggers it is in the description.',
      },
    );

String get spellLongCastingRule => localized(
      'Tarda más que un turno: hay que mantener la concentración mientras se '
          'lanza, así que rara vez sirve en combate.',
      'It takes longer than a turn: you must keep Concentration while casting, so it rarely helps in combat.',
    );

Map<String, String> get spellComponentRules => localized(
      const {
        'V':
            'Hay que poder hablar: amordazado o en un silencio mágico, no se lanza.',
        'S': 'Hay que tener una mano libre para gesticular.',
        'M':
            'Hace falta el material nombrado, o en su lugar un canalizador o una '
                'bolsa de componentes, salvo que tenga precio o se consuma.',
      },
      const {
        'V':
            'You must be able to speak: gagged or in magical silence, you can’t cast it.',
        'S': 'You need a free hand to gesture.',
        'M':
            'You need the named material, or instead a Spellcasting Focus or a Component Pouch, unless it has a cost or is consumed.',
      },
    );

String get spellConcentrationRule => localized(
      'Mientras dura hay que concentrarse: recibir daño pide una salvación de '
          'Constitución, y empezar otro conjuro de concentración termina este.',
      'While it lasts you must concentrate: taking damage calls for a Constitution saving throw, and starting another Concentration spell ends this one.',
    );

String get spellRitualRule => localized(
      'Se puede lanzar como ritual: tarda 10 minutos más y no gasta espacio de '
          'conjuro.',
      'It can be cast as a Ritual: it takes 10 minutes longer and expends no spell slot.',
    );

String get spellClassesRule => localized(
      'Las clases en cuya lista aparece: solo esas lo pueden preparar.',
      'The classes whose list includes it: only they can prepare it.',
    );

// -------------------------------------------------------------------- Dote

Map<String, String> get featCategoryRules => localized(
      const {
        'origin':
            'La que concede un trasfondo a nivel 1. No tienen requisitos de nivel.',
        'general':
            'Se toman al subir de nivel desde el 4, en lugar del aumento de '
                'característica.',
        'fighting-style':
            'Solo para quien tiene el rasgo Estilo de combate: guerreros, paladines '
                'y exploradores.',
        'dragonmark':
            'Las marcas de Eberron. Se toman como dote de origen, en lugar de la '
                'del trasfondo.',
        'epic-boon': 'Para personajes de nivel 19 o más.',
      },
      const {
        'origin':
            'The one a background grants at level 1. They have no level requirements.',
        'general':
            'Taken when leveling up from level 4 on, instead of the Ability Score Improvement.',
        'fighting-style':
            'Only for someone with the Fighting Style feature: fighters, paladins, and rangers.',
        'dragonmark':
            'Eberron’s marks. Taken as an Origin feat, instead of the background’s.',
        'epic-boon': 'For characters of level 19 or higher.',
      },
    );

String get featRepeatableRule => localized(
      'Se puede tomar más de una vez. Sin marcar, una vez elegida deja de '
          'ofrecerse.',
      'It can be taken more than once. Unchecked, once chosen it’s no longer offered.',
    );

// ------------------------------------------------------- Especie y trasfondo

String get raceCreatureTypeRule => localized(
      'Es lo que miran los conjuros y rasgos que solo afectan a un tipo, como '
          'Hechizar persona a los humanoides.',
      'It’s what spells and features that only affect one type look at, like Charm Person with Humanoids.',
    );

/// Tamaños de especie, por el texto que guarda `Race.size`.
Map<String, String> get raceSizeRules => localized(
      const {
        'Pequeño': 'Ocupa un espacio de 5 pies, como un Mediano.',
        'Mediano': 'Ocupa un espacio de 5 pies.',
        'Grande': 'Ocupa un espacio de 10 pies.',
      },
      const {
        'Pequeño': 'Takes up a 5-foot space, like a Medium creature.',
        'Mediano': 'Takes up a 5-foot space.',
        'Grande': 'Takes up a 10-foot space.',
      },
    );

String get sizeRule => localized(
      'El tamaño decide cuánto espacio ocupa y a quién puede agarrar o empujar: '
          'hasta un tamaño más grande que el propio.',
      'Size decides how much space it takes up and whom it can grapple or shove: up to one size larger than its own.',
    );

String get raceSpeedRule => localized(
      'Lo que se mueve en un turno, antes de que la armadura o un rasgo la '
          'cambien.',
      'How far it moves in a turn, before armor or a feature changes it.',
    );

String get raceSkillCountRule => localized(
      'Cuántas competencias en habilidad elige el jugador al crear el personaje.',
      'How many skill proficiencies the player chooses when creating the character.',
    );

String get raceSkillFromRule => localized(
      'Sin marcar ninguna, el jugador elige entre las 18. Marcando algunas, la '
          'elección queda limitada a esas.',
      'With none checked, the player chooses among all 18. Checking some limits the choice to those.',
    );

String get raceSizeOptionsRule => localized(
      'Marcando dos o más, el jugador elige el tamaño de su personaje. Con uno '
          'o ninguno vale el tamaño de arriba.',
      'With two or more checked, the player chooses their character’s size. With one or none, the size above applies.',
    );

String get skillProficiencyRule => localized(
      'Ser competente suma el bonificador por competencia a las pruebas de esa '
          'habilidad.',
      'Being proficient adds the Proficiency Bonus to checks with that skill.',
    );

String get toolProficiencyRule => localized(
      'Ser competente suma el bonificador por competencia a las pruebas con esa '
          'herramienta.',
      'Being proficient adds the Proficiency Bonus to checks with that tool.',
    );

String get backgroundAbilitiesRule => localized(
      'Al crear el personaje, el jugador reparte +2 a una y +1 a otra de estas '
          'tres, o +1 a cada una. Por eso tienen que ser exactamente tres.',
      'When creating the character, the player gives +2 to one and +1 to another of these three, or +1 to each. That’s why there must be exactly three.',
    );

String get backgroundOriginFeatRule => localized(
      'La dote que el trasfondo concede a nivel 1. Solo se ofrecen las de '
          'origen.',
      'The feat the background grants at level 1. Only Origin feats are offered.',
    );

// ------------------------------------------------------------------ Objeto

Map<String, String> get itemCategoryRules => localized(
      const {
        'gear': 'Equipo de aventurero: lo que no entra en otra familia.',
        'tool':
            'Se usa en pruebas de característica, y con competencia suma el '
                'bonificador.',
        'ammunition': 'Lo que gastan las armas con la propiedad Munición.',
        'focus':
            'Reemplaza los componentes materiales sin precio al lanzar conjuros.',
        'pack': 'Varios objetos que se compran juntos.',
        'container': 'Guarda otros objetos adentro.',
      },
      const {
        'gear': 'Adventuring Gear: whatever doesn’t fit another family.',
        'tool':
            'Used in ability checks, and with proficiency it adds the bonus.',
        'ammunition': 'What weapons with the Ammunition property expend.',
        'focus':
            'Replaces Material components without a cost when casting spells.',
        'pack': 'Several items bought together.',
        'container': 'Holds other items inside.',
      },
    );

String get itemCategoryNote => localized(
      'La categoría ordena el inventario. Lo que hace mágico a un objeto es la '
          'rareza.',
      'The category sorts the inventory. What makes an item magical is its rarity.',
    );

String get itemMundaneRule => localized(
      'Sin rareza es un objeto común y corriente, y no se puede sintonizar.',
      'Without a rarity it’s an ordinary item, and it can’t be attuned.',
    );

String get itemRarityRule => localized(
      'Tener rareza es lo que lo hace mágico. Orienta cuánto vale y a qué nivel '
          'conviene entregarlo.',
      'Having a rarity is what makes it magical. It guides how much it’s worth and at what level to hand it out.',
    );

String get itemAttunementRule => localized(
      'Solo da sus efectos a quien se sintonizó con él, en un descanso corto. '
          'Cada personaje mantiene hasta tres objetos sintonizados a la vez.',
      'It only grants its effects to someone attuned to it, during a Short Rest. Each character keeps up to three attuned items at a time.',
    );

String get itemAcBonusRule => localized(
      'Suma a la Clase de Armadura mientras esté equipado, y sintonizado si lo '
          'exige.',
      'Adds to Armor Class while equipped, and attuned if it requires it.',
    );

String get itemResistanceRule => localized(
      'Con las mismas condiciones, el daño de ese tipo que recibe el personaje '
          'se reduce a la mitad.',
      'Under the same conditions, damage of that type the character takes is halved.',
    );

String get itemBaseRule => localized(
      'Con base, el objeto es una plantilla: al agregarlo se elige el arma, la '
          'armadura o el escudo sobre el que va, y hereda sus números.',
      'With a base, the item is a template: when adding it you choose the weapon, armor, or shield it goes on, and it inherits their numbers.',
    );

String get itemMagicBonusRule => localized(
      'Se suma al ataque y al daño del arma base, o a la CA de la armadura o el '
          'escudo.',
      'Added to the base weapon’s attack and damage, or to the armor’s or shield’s AC.',
    );

// ---------------------------------------------------------------- Criatura

String get creatureTypeRule => localized(
      'Es lo que miran los conjuros y rasgos que afectan a un tipo de criatura.',
      'It’s what spells and features that affect a creature type look at.',
    );

String get creatureBeastNote => localized(
      'Es el único tipo que puede aparecer entre las formas de Forma Salvaje del '
          'druida.',
      'It’s the only type that can show up among the druid’s Wild Shape forms.',
    );

/// Espacio que ocupa cada tamaño, por el id de `CreatureSize`.
Map<String, String> get creatureSizeRules => localized(
      const {
        'tiny': 'Ocupa un espacio de 2,5 pies.',
        'small': 'Ocupa un espacio de 5 pies.',
        'medium': 'Ocupa un espacio de 5 pies.',
        'large': 'Ocupa un espacio de 10 pies.',
        'huge': 'Ocupa un espacio de 15 pies.',
        'gargantuan': 'Ocupa un espacio de 20 pies o más.',
      },
      const {
        'tiny': 'Takes up a 2½-foot space.',
        'small': 'Takes up a 5-foot space.',
        'medium': 'Takes up a 5-foot space.',
        'large': 'Takes up a 10-foot space.',
        'huge': 'Takes up a 15-foot space.',
        'gargantuan': 'Takes up a 20-foot space or larger.',
      },
    );

String get creatureCrRule => localized(
      'Cuán peligrosa es: una de VD igual al nivel del grupo es un combate '
          'parejo para cuatro personajes. Fija su bonificador por competencia y la '
          'experiencia que da.',
      'How dangerous it is: one with a CR equal to the party’s level is an even fight for four characters. It sets its Proficiency Bonus and the experience it grants.',
    );

String get creatureAttackBonusRule => localized(
      'Lo que se suma al d20 para acertar. Vacío si la acción no es un ataque '
          '—un aliento con salvación, un aullido—: el perfil la muestra como texto.',
      'What’s added to the d20 to hit. Empty if the action isn’t an attack —a breath with a saving throw, a howl—: the stat block shows it as text.',
    );

/// Cuándo se usa una acción de criatura, por el id de `CreatureActionKind`.
Map<String, String> get creatureActionKindRules => localized(
      const {
        'action': 'Ocupa la acción del turno.',
        'bonus': 'Ocupa la acción adicional del turno.',
        'reaction': 'Se usa fuera del turno propio, en respuesta a algo.',
        'legendary':
            'Se usa al terminar el turno de otra criatura, gastando de las acciones '
                'legendarias por ronda.',
      },
      const {
        'action': 'Takes the turn’s action.',
        'bonus': 'Takes the turn’s Bonus Action.',
        'reaction': 'Used outside its own turn, in response to something.',
        'legendary':
            'Used at the end of another creature’s turn, spending from the Legendary Actions per round.',
      },
    );
