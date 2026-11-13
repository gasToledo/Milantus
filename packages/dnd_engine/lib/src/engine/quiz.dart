import 'dart:math';

import '../data/content_repository.dart';
import '../domain/ability.dart';
import '../domain/character.dart';
import '../domain/content.dart';
import '../domain/content_language.dart';
import '../domain/content_vocabulary.dart';
import '../domain/damage_type.dart';
import '../domain/effects.dart';
import '../domain/proficiency_labels.dart';
import '../domain/skill.dart';
import '../domain/weapon_mastery.dart';
import '../domain/weapon_properties.dart';
import 'character_compiler.dart';

/// Tipos de pregunta del Quiz. El nombre (`name`) es lo que viaja a la UI,
/// que arma el enunciado con una plantilla por tipo.
enum QuizKind {
  classFeatureByText(QuizTopic.classTopic),
  classFeatureLevel(QuizTopic.classTopic),
  hitDie(QuizTopic.classTopic),
  savingThrows(QuizTopic.classTopic),
  speciesTraitByText(QuizTopic.species),
  backgroundSkills(QuizTopic.background),
  backgroundFeat(QuizTopic.background),
  spellCastingTime(QuizTopic.spells),
  spellRange(QuizTopic.spells),
  spellSchool(QuizTopic.spells),
  condition(QuizTopic.rules),
  skillAbility(QuizTopic.rules),
  masteryByText(QuizTopic.equipment),
  weaponMastery(QuizTopic.equipment),
  propertyByText(QuizTopic.equipment),
  weaponDamage(QuizTopic.equipment),
  armorAc(QuizTopic.equipment),
  armorCategory(QuizTopic.equipment);

  const QuizKind(this.topic);
  final QuizTopic topic;
}

/// El chip de la pregunta. `class` es palabra reservada: el id que viaja es
/// `class` (ver [wire]).
enum QuizTopic {
  classTopic('class'),
  species('species'),
  background('background'),
  spells('spells'),
  equipment('equipment'),
  rules('rules');

  const QuizTopic(this.wire);
  final String wire;
}

/// Una pregunta de opción múltiple, ya armada con el idioma del catálogo.
/// Las preguntas salen siempre del catálogo y del personaje; nada se escribe
/// a mano.
class QuizQuestion {
  final QuizKind kind;

  /// Identidad estable entre idiomas: la misma semilla elige las mismas
  /// claves, y la UI puede cambiar el texto sin cambiar de pregunta.
  final String key;

  /// Lo que se pregunta (rasgo, conjuro, clase…); null si el tipo no lo usa.
  final String? subject;

  /// El id que la UI necesita (`condition`: el estado; `spell*`: el conjuro;
  /// `classFeatureLevel`, `hitDie` y `savingThrows`: la clase).
  final String? subjectId;

  /// Solo en `classFeatureLevel`: el nivel correcto.
  final int? level;

  /// El texto a reconocer, en los tipos «por texto».
  final String? quote;

  /// Rótulos distintos. Cuatro, salvo la categoría de armadura, que son las
  /// tres que existen (ligera, media y pesada): un cuarto sería Escudos.
  final List<String> options;

  /// La identidad de cada opción, en el mismo orden que [options]. No depende
  /// del idioma: al cambiarlo se reescriben los rótulos y se dejan estos ids.
  final List<String> optionIds;

  /// Índice de la correcta en [options].
  final int answer;

  const QuizQuestion({
    required this.kind,
    required this.key,
    this.subject,
    this.subjectId,
    this.level,
    this.quote,
    required this.options,
    required this.optionIds,
    required this.answer,
  });

  QuizTopic get topic => kind.topic;

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'key': key,
        'topic': topic.wire,
        'subject': subject,
        'subjectId': subjectId,
        'level': level,
        'quote': quote,
        'options': options,
        'optionIds': optionIds,
        'answer': answer,
      };

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
        kind: QuizKind.values.byName(j['kind'] as String),
        key: j['key'] as String,
        subject: j['subject'] as String?,
        subjectId: j['subjectId'] as String?,
        level: j['level'] as int?,
        quote: j['quote'] as String?,
        options: (j['options'] as List).cast<String>(),
        optionIds: (j['optionIds'] as List).cast<String>(),
        answer: j['answer'] as int,
      );
}

/// Un rótulo largo (el «Reacción, que realizás al recibir daño…» de un solo
/// conjuro) delata la correcta entre opciones cortas: no se pregunta ni se
/// ofrece de distractor. El tope mira el texto en español, que es el que
/// guardan los dos catálogos: si mirara la traducción, una ronda en inglés
/// descartaría otros conjuros que la de español.
const _maxOptionLength = 40;

/// Una pregunta posible: su tema (para no repetirlo en la ronda) y cómo
/// armarla. Armar puede fallar (`null`) si no hay opciones distintas.
class _Candidate {
  final String key;
  final QuizQuestion? Function(Random rng) build;
  const _Candidate(this.key, this.build);
}

/// Una opción antes de traducirse: el [id] no depende del idioma y el
/// [label] sí. Se barajan ids, así la misma semilla deja la correcta en el
/// mismo lugar en español y en inglés.
class _Choice {
  final String id;
  final String label;
  const _Choice(this.id, this.label);
}

/// Arma una ronda de [count] preguntas. Sin [character], de reglas generales.
/// La misma [seed] da la misma ronda: todo el azar sale de un `Random(seed)`,
/// los recorridos van por id (no por el nombre traducido) y las opciones se
/// eligen por id antes de escribir el rótulo.
///
/// No repite tema (el mismo rasgo o conjuro no sale dos veces) y mezcla los
/// tipos: hasta 3 del mismo, salvo que haya pocos tipos y no alcancen para
/// llegar a [count].
List<QuizQuestion> quizRound(
  Character? character,
  ContentRepository repo, {
  required int seed,
  int count = 10,
}) {
  final rng = Random(seed);
  final pools = <QuizKind, List<_Candidate>>{};
  if (character == null) {
    pools[QuizKind.condition] = _conditions();
    _generalPools(repo, pools, rng);
  } else {
    _characterPools(character, repo, pools, rng);
  }
  pools.removeWhere((_, c) => c.isEmpty);
  for (final c in pools.values) {
    c.shuffle(rng);
  }
  final cap = max(3, pools.isEmpty ? 3 : (count / pools.length).ceil());

  final used = <String>{};
  final taken = <QuizKind, int>{};
  final out = <QuizQuestion>[];
  while (out.length < count) {
    final eligible = [
      for (final e in pools.entries)
        if (e.value.isNotEmpty && (taken[e.key] ?? 0) < cap) e.key,
    ];
    if (eligible.isEmpty) break;
    final kind = eligible[rng.nextInt(eligible.length)];
    final cand = pools[kind]!.removeLast();
    if (used.contains(cand.key)) continue;
    final q = cand.build(rng);
    if (q == null) continue;
    used.add(cand.key);
    taken[kind] = (taken[kind] ?? 0) + 1;
    out.add(q);
  }
  return out;
}

// ---------------------------------------------------------------------------
// Armado de opciones
// ---------------------------------------------------------------------------

/// La correcta más distractores sacados de [pool] (distintos entre sí y de
/// la correcta), mezclados por id. Null si el pool no alcanza para [count].
(List<String>, List<String>, int)? _choose(
  String correctId,
  List<_Choice> pool,
  Random rng, {
  int count = 4,
  bool Function(String id)? allow,
}) {
  final labels = <String, String>{};
  for (final c in pool) {
    labels.putIfAbsent(c.id, () => c.label);
  }
  if (!labels.containsKey(correctId)) return null;
  if (allow != null && !allow(correctId)) return null;
  final correct = labels[correctId]!;
  final ids = [
    for (final id in labels.keys)
      if (id != correctId &&
          labels[id] != correct &&
          (allow == null || allow(id)))
        id,
  ]..shuffle(rng);
  if (ids.length < count - 1) return null;
  final picked = [correctId, ...ids.take(count - 1)]..shuffle(rng);
  return (
    [for (final id in picked) labels[id]!],
    picked,
    picked.indexOf(correctId),
  );
}

QuizQuestion? _question(
  QuizKind kind,
  String key,
  String correctId,
  List<_Choice> pool,
  Random rng, {
  int count = 4,
  bool Function(String id)? allow,
  String? subject,
  String? subjectId,
  int? level,
  String? quote,
}) {
  final o = _choose(correctId, pool, rng, count: count, allow: allow);
  if (o == null) return null;
  return QuizQuestion(
    kind: kind,
    key: key,
    subject: subject,
    subjectId: subjectId,
    level: level,
    quote: quote,
    options: o.$1,
    optionIds: o.$2,
    answer: o.$3,
  );
}

/// «Fuerza y Constitución», en el orden de [Ability.values] (o el de
/// [Skill.values] para las habilidades). Ordenar alfabético cambia con el
/// idioma: «Constitución y Fuerza» en español y «Constitution and Strength»
/// no son el mismo par escrito al revés, y además no es como las lista el
/// libro.
String _join(List<String> labels) => labels.join(localized(' y ', ' and '));

final _parens = RegExp(r'\s*\(([^)]*)\)');

String _baseName(String name) =>
    name.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();

/// El nombre sin el paréntesis, o lo de adentro, está en el texto. «Furia
/// (3 usos)» se nombra como «Furia», y «(+15 pies)» aparece tal cual en el
/// bono de velocidad: cualquiera de las dos delata la opción.
bool _mentioned(String name, String text) {
  final lower = text.toLowerCase();
  final base = _baseName(name).toLowerCase();
  if (base.length >= 3 && lower.contains(base)) return true;
  for (final m in _parens.allMatches(name)) {
    final inner = m.group(1)!.trim().toLowerCase();
    if (inner.length >= 3 && lower.contains(inner)) return true;
  }
  return false;
}

List<T> _byId<T>(Iterable<T> items, String Function(T) id) =>
    items.toList()..sort((a, b) => id(a).compareTo(id(b)));

// ---------------------------------------------------------------------------
// Reglas generales
// ---------------------------------------------------------------------------

/// Quien incluye al estado que se pregunta: su regla también le cabe, así
/// que ofrecerlo sería una segunda respuesta correcta. Paralizado, petrificado
/// e inconsciente incluyen incapacitado; aturdido también, y a su vez ellos
/// lo incluyen. Inconsciente incluye además derribado.
const _conditionSupersets = {
  'incapacitated': ['stunned', 'paralyzed', 'petrified', 'unconscious'],
  'stunned': ['paralyzed', 'petrified', 'unconscious'],
  'paralyzed': ['unconscious'],
  'prone': ['unconscious'],
};

/// La cita nombra otro estado («Estás incapacitado», «derribado»). No se
/// ofrece ese rótulo al lado: sería señalar una opción.
const _conditionNamed = {
  'paralyzed': ['incapacitated'],
  'petrified': ['incapacitated', 'poisoned'],
  'stunned': ['incapacitated'],
  'unconscious': ['incapacitated', 'prone'],
};

List<_Candidate> _conditions() {
  final ids = conditionIds.toList();
  final pool = [for (final id in ids) _Choice(id, conditionLabel(id))];
  return [
    for (final id in ids)
      _Candidate(
        'condition:$id',
        (rng) => _question(
          QuizKind.condition,
          'condition:$id',
          id,
          pool,
          rng,
          allow: (other) =>
              !(_conditionSupersets[id]?.contains(other) ?? false) &&
              !(_conditionNamed[id]?.contains(other) ?? false),
          subject: conditionLabel(id),
          subjectId: id,
        ),
      ),
  ];
}

/// Lo que vale para cualquier personaje fuera de los estados: habilidades,
/// maestrías y propiedades de arma, armas y armaduras del catálogo.
void _generalPools(
  ContentRepository repo,
  Map<QuizKind, List<_Candidate>> pools,
  Random rng,
) {
  List<_Candidate> pool(QuizKind k) => pools.putIfAbsent(k, () => []);

  // Ninguna habilidad usa Constitución: ofrecerla es un distractor que no
  // puede ser la respuesta de ninguna pregunta de este tipo.
  final abilities = [
    for (final a in Ability.values)
      if (Skill.values.any((s) => s.ability == a)) _Choice(a.name, a.label),
  ];
  for (final s in Skill.values) {
    pool(QuizKind.skillAbility).add(
      _Candidate(
        'skill:${s.id}',
        (rng) => _question(
          QuizKind.skillAbility,
          'skill:${s.id}',
          s.ability.name,
          abilities,
          rng,
          subject: s.label,
          subjectId: s.id,
        ),
      ),
    );
  }

  // Por texto, como los rasgos: sin la que se nombra a sí misma en su regla.
  void byText(
    QuizKind kind,
    String prefix,
    List<(String, String, String)> all,
  ) {
    all.sort((a, b) => a.$1.compareTo(b.$1));
    final choices = [for (final (id, name, _) in all) _Choice(id, name)];
    for (final (id, name, text) in all) {
      if (_mentioned(name, text)) continue;
      pool(kind).add(
        _Candidate(
          '$prefix:$id',
          (rng) => _question(
            kind,
            '$prefix:$id',
            id,
            choices,
            rng,
            allow: (other) {
              final label = choices
                  .firstWhere((c) => c.id == other, orElse: () => choices.first)
                  .label;
              return other == id || !_mentioned(label, text);
            },
            subjectId: id,
            quote: text,
          ),
        ),
      );
    }
  }

  byText(QuizKind.masteryByText, 'mastery', [
    for (final m in weaponMasteries.values) (m.id, m.name, m.description),
  ]);
  byText(QuizKind.propertyByText, 'property', [
    for (final p in weaponProperties.values) (p.id, p.name, p.description),
  ]);

  // Un arma o una armadura sale una sola vez por ronda, sea cual sea la
  // pregunta: la clave es la misma.
  final weapons = _byId(repo.weapons.values, (w) => w.id);
  final masteryChoices = [
    for (final m in weaponMasteries.values) _Choice(m.id, m.name),
  ]..sort((a, b) => a.id.compareTo(b.id));
  String damageId(String dice, String type) => '$dice|$type';
  String damageLabel(String id) {
    final parts = id.split('|');
    return '${parts[0]} ${DamageType.labelFor(parts[1]).toLowerCase()}';
  }

  final damages = <_Choice>[];
  final seenDamage = <String>{};
  for (final w in weapons) {
    if (!w.damageDice.contains('d') || w.damageType.isEmpty) continue;
    final id = damageId(w.damageDice, w.damageType);
    if (seenDamage.add(id)) damages.add(_Choice(id, damageLabel(id)));
  }
  for (final w in weapons) {
    final mastery = w.mastery;
    if (mastery != null && weaponMasteries.containsKey(mastery)) {
      pool(QuizKind.weaponMastery).add(
        _Candidate(
          'weapon:${w.id}',
          (rng) => _question(
            QuizKind.weaponMastery,
            'weapon:${w.id}',
            mastery,
            masteryChoices,
            rng,
            subject: w.name,
            subjectId: w.id,
          ),
        ),
      );
    }
    if (w.damageDice.contains('d') && w.damageType.isNotEmpty) {
      final correct = damageId(w.damageDice, w.damageType);
      // El dado versátil es también un daño de esta arma. Si entra como
      // distractor (porque otra arma lo tiene de base), las dos opciones
      // son correctas. Se lo saca del pool en vez de escribir «1d8 (1d10 a
      // dos manos)»: ese paréntesis sería el único y delataría la respuesta.
      final versatile = w.versatileDice == null
          ? null
          : damageId(w.versatileDice!, w.damageType);
      pool(QuizKind.weaponDamage).add(
        _Candidate(
          'weapon:${w.id}',
          (rng) => _question(
            QuizKind.weaponDamage,
            'weapon:${w.id}',
            correct,
            damages,
            rng,
            allow: (id) => id != versatile,
            subject: w.name,
            subjectId: w.id,
          ),
        ),
      );
    }
  }

  // El escudo no entra: suma +2 en vez de dar una CA, y su categoría se
  // regala con el nombre. La categoría se pregunta con las tres que hay
  // (ligera, media, pesada), sin rellenar con Escudos.
  final armor = [
    for (final a in _byId(repo.armor.values, (a) => a.id))
      if (a.category != 'shield') a,
  ];
  final acs = <_Choice>[];
  final seenAc = <String>{};
  for (final a in armor) {
    final id = _acId(a);
    if (seenAc.add(id)) acs.add(_Choice(id, _acLabel(id)));
  }
  const categories = ['light', 'medium', 'heavy'];
  final categoryChoices = [
    for (final id in categories) _Choice(id, armorTrainingLabel(id)),
  ];
  for (final a in armor) {
    pool(QuizKind.armorAc).add(
      _Candidate(
        'armor:${a.id}',
        (rng) => _question(
          QuizKind.armorAc,
          'armor:${a.id}',
          _acId(a),
          acs,
          rng,
          subject: a.name,
          subjectId: a.id,
        ),
      ),
    );
    if (!categories.contains(a.category)) continue;
    pool(QuizKind.armorCategory).add(
      _Candidate(
        'armor:${a.id}',
        (rng) => _question(
          QuizKind.armorCategory,
          'armor:${a.id}',
          a.category,
          categoryChoices,
          rng,
          count: 3,
          subject: a.name,
          subjectId: a.id,
        ),
      ),
    );
  }
  // `rng` queda para el mismo consumo en las dos lenguas: hoy el equipo no
  // lo usa, y reservarlo acá evita que un desempate futuro desplace la ronda.
  rng.nextBool();
}

/// `flat:18`, `dex:11` o `dex:14:max:2`. El rótulo se arma después, así dos
/// armaduras con la misma cuenta no son dos opciones.
String _acId(Armor a) {
  if (!a.addDexMod) return 'flat:${a.baseAc}';
  if (a.maxDexBonus == null) return 'dex:${a.baseAc}';
  return 'dex:${a.baseAc}:max:${a.maxDexBonus}';
}

String _acLabel(String id) {
  final parts = id.split(':');
  if (parts.first == 'flat') return parts[1];
  final ac = parts[1];
  if (parts.length == 2) {
    return localized(
      '$ac + tu modificador de Destreza',
      '$ac + your Dexterity modifier',
    );
  }
  final max = parts[3];
  return localized(
    '$ac + tu modificador de Destreza (máx. $max)',
    '$ac + your Dexterity modifier (max $max)',
  );
}

// ---------------------------------------------------------------------------
// Personaje
// ---------------------------------------------------------------------------

void _characterPools(
  Character c,
  ContentRepository repo,
  Map<QuizKind, List<_Candidate>> pools,
  Random rng,
) {
  List<_Candidate> pool(QuizKind k) => pools.putIfAbsent(k, () => []);

  // Clases en el orden en que el personaje las tomó, con su nivel en cada una.
  final levels = <String, int>{};
  for (final id in c.classHistory) {
    levels[id] = (levels[id] ?? 0) + 1;
  }
  if (levels.isEmpty) levels[c.classId] = c.totalLevel < 1 ? 1 : c.totalLevel;
  final classes = <(CharacterClass, int, Subclass?)>[];
  for (final e in levels.entries) {
    final cls = repo.characterClass(e.key);
    if (cls == null) continue;
    final subId =
        c.subclassIds[e.key] ?? (e.key == c.classId ? c.subclassId : null);
    classes.add((cls, e.value, subId == null ? null : repo.subclass(subId)));
  }

  for (final (cls, level, sub) in classes) {
    _classFeatures(cls, level, sub, pool);
    // El dado y las salvaciones son de esa clase, no «de tu clase»: en
    // multiclase la primera no responde por las otras.
    _classBasics(cls, repo, pool);
  }

  final race = repo.race(c.raceId);
  if (race != null) {
    _speciesTraits(
      race,
      repo.lineage(c.lineageId ?? ''),
      c.totalLevel,
      repo,
      pool(QuizKind.speciesTraitByText),
    );
  }
  final bg = repo.background(c.backgroundId);
  if (bg != null) _background(bg, repo, pool);

  _spells(c, repo, pool, rng);
}

/// Rasgos con descripción que no se nombran en su propio texto. El paréntesis
/// no cuenta: «Furia (3 usos)» se nombra igual que «Furia».
bool _readable(ClassFeature f) =>
    f.description.trim().isNotEmpty && !_mentioned(f.name, f.description);

void _classFeatures(
  CharacterClass cls,
  int level,
  Subclass? sub,
  List<_Candidate> Function(QuizKind) pool,
) {
  // `clase:cN` y `subclase:sN`: el id alcanza para reescribir el rótulo en
  // el otro idioma sin volver a sortear.
  final indexed = <(String, ClassFeature)>[
    for (var i = 0; i < cls.features.length; i++)
      ('${cls.id}:c$i', cls.features[i]),
    if (sub != null)
      for (var i = 0; i < sub.features.length; i++)
        ('${sub.id}:s$i', sub.features[i]),
  ];
  final choices = <_Choice>[];
  final seen = <String>{};
  for (final (slot, f) in indexed) {
    final bare = _baseName(f.name);
    if (bare.isEmpty || !seen.add(bare.toLowerCase())) continue;
    choices.add(_Choice(slot, f.name));
  }
  final descriptions = <String, String>{
    for (final (slot, f) in indexed) slot: f.description,
  };

  for (final (slot, f) in indexed) {
    if (f.level > level || !_readable(f)) continue;
    final id = slot;
    pool(QuizKind.classFeatureByText).add(
      _Candidate(
        'feature:$id',
        (rng) => _question(
          QuizKind.classFeatureByText,
          'feature:$id',
          id,
          choices,
          rng,
          allow: (other) {
            if (other == id) return true;
            final label = choices
                .cast<_Choice?>()
                .firstWhere((c) => c!.id == other, orElse: () => null)
                ?.label;
            if (label != null && _mentioned(label, f.description)) return false;
            final otherText = descriptions[other];
            // Dos rasgos con la misma descripción (la Magia del Legado del
            // tiefling, antes de nombrar el conjuro) serían las dos correctas.
            return otherText == null ||
                otherText.trim() != f.description.trim();
          },
          subject: cls.name,
          subjectId: cls.id,
          quote: f.description,
        ),
      ),
    );
  }

  // Solo rasgos de la clase cuyo nombre aparece una vez: «Mejora de
  // Puntuación de Característica» se repite en cada nivel y no tiene un
  // «nivel en que se obtiene». Entran también los que el personaje todavía
  // no alcanzó: la pregunta es de la clase, no de lo que ya tiene.
  final counts = <String, int>{};
  for (final f in cls.features) {
    counts[f.name] = (counts[f.name] ?? 0) + 1;
  }
  final allLevels = <_Choice>[
    for (final n in {for (final f in cls.features) f.level}.toList()..sort())
      _Choice('$n', '$n'),
  ];
  for (var i = 0; i < cls.features.length; i++) {
    final f = cls.features[i];
    if (counts[f.name] != 1) continue;
    pool(QuizKind.classFeatureLevel).add(
      _Candidate(
        // La misma clave que `classFeatureByText`: es el mismo rasgo.
        'feature:${cls.id}:c$i',
        (rng) => _question(
          QuizKind.classFeatureLevel,
          'feature:${cls.id}:c$i',
          '${f.level}',
          allLevels,
          rng,
          subject: f.name,
          subjectId: cls.id,
          level: f.level,
        ),
      ),
    );
  }
}

/// El dado de golpe y las salvaciones de [cls], nombrada en la pregunta.
void _classBasics(
  CharacterClass cls,
  ContentRepository repo,
  List<_Candidate> Function(QuizKind) pool,
) {
  pool(QuizKind.hitDie).add(
    _Candidate(
      'hitDie:${cls.id}',
      (rng) => _question(
        QuizKind.hitDie,
        'hitDie:${cls.id}',
        'd${cls.hitDie}',
        [
          for (final d in const [6, 8, 10, 12]) _Choice('d$d', 'd$d'),
        ],
        rng,
        subject: cls.name,
        subjectId: cls.id,
      ),
    ),
  );

  String? saveId(CharacterClass k) {
    final ids = [
      for (final a in Ability.values)
        if (k.savingThrows.contains(a)) a.name,
    ];
    return ids.length == 2 ? ids.join('+') : null;
  }

  String saveLabel(String id) => _join([
        for (final name in id.split('+')) Ability.values.byName(name).label,
      ]);
  final mine = saveId(cls);
  if (mine == null) return;
  final saves = <_Choice>[];
  final seen = <String>{};
  for (final k in _byId(repo.classes.values, (k) => k.id)) {
    final id = saveId(k);
    if (id != null && seen.add(id)) saves.add(_Choice(id, saveLabel(id)));
  }
  pool(QuizKind.savingThrows).add(
    _Candidate(
      'saves:${cls.id}',
      (rng) => _question(
        QuizKind.savingThrows,
        'saves:${cls.id}',
        mine,
        saves,
        rng,
        subject: cls.name,
        subjectId: cls.id,
      ),
    ),
  );
}

Iterable<ClassFeature> _traitsOf(Race race, Lineage? lineage, int level) sync* {
  Iterable<ClassFeature> walk(List<Effect> effects, int minLevel) sync* {
    for (final e in effects) {
      if (e is PassiveTraitEffect) {
        yield ClassFeature(
          level: minLevel,
          name: e.name,
          description: e.description,
        );
      } else if (e is LeveledEffect) {
        yield* walk(e.effects, e.minLevel);
      }
    }
  }

  yield* walk(race.effects, 1);
  if (lineage != null) yield* lineage.features;
}

void _speciesTraits(
  Race race,
  Lineage? lineage,
  int level,
  ContentRepository repo,
  List<_Candidate> out,
) {
  final own = _traitsOf(race, lineage, level).toList();
  final ownChoices = <_Choice>[];
  final seen = <String>{};
  for (var i = 0; i < own.length; i++) {
    final name = own[i].name;
    if (isCreatureTypeName(name)) continue;
    if (!seen.add(_baseName(name).toLowerCase())) continue;
    ownChoices.add(_Choice('$i', name));
  }
  // Si los de su especie no alcanzan para 3 distractores, se completa con los
  // de otras. El orden es por id de especie, no por el nombre traducido.
  final others = <_Choice>[];
  final seenOther = <String>{...seen};
  for (final r in _byId(repo.races.values, (r) => r.id)) {
    if (r.id == race.id) continue;
    final traits = _traitsOf(r, null, 20).toList();
    for (var i = 0; i < traits.length; i++) {
      final name = traits[i].name;
      if (isCreatureTypeName(name)) continue;
      if (!seenOther.add(_baseName(name).toLowerCase())) continue;
      others.add(_Choice('${r.id}:$i', name));
    }
  }
  for (var i = 0; i < own.length; i++) {
    final t = own[i];
    if (t.level > level || !_readable(t) || isCreatureTypeName(t.name)) {
      continue;
    }
    out.add(
      _Candidate('trait:${race.id}:$i', (rng) {
        final fromOwn = _choose('$i', ownChoices, Random(0));
        final pool = fromOwn != null ? ownChoices : [...ownChoices, ...others];
        return _question(
          QuizKind.speciesTraitByText,
          'trait:${race.id}:$i',
          '$i',
          pool,
          rng,
          allow: (other) {
            if (other == '$i') return true;
            final label = pool
                .cast<_Choice?>()
                .firstWhere((c) => c!.id == other, orElse: () => null)
                ?.label;
            if (label != null && _mentioned(label, t.description)) return false;
            final otherIndex = int.tryParse(other);
            if (otherIndex == null || otherIndex >= own.length) return true;
            return own[otherIndex].description.trim() != t.description.trim();
          },
          subject: race.name,
          // Especie y linaje, para reescribir el rasgo sin el personaje.
          subjectId: '${race.id}|${lineage?.id ?? ''}',
          quote: t.description,
        );
      }),
    );
  }
}

void _background(
  Background bg,
  ContentRepository repo,
  List<_Candidate> Function(QuizKind) pool,
) {
  String? skillsId(Background b) {
    final ids = [
      for (final s in Skill.values)
        if (b.skillProficiencies.contains(s.id)) s.name,
    ];
    return ids.length == 2 ? ids.join('+') : null;
  }

  String skillsLabel(String id) => _join([
        for (final name in id.split('+')) Skill.values.byName(name).label,
      ]);
  final mine = skillsId(bg);
  if (mine != null) {
    final skills = <_Choice>[];
    final seen = <String>{};
    for (final b in _byId(repo.backgrounds.values, (b) => b.id)) {
      final id = skillsId(b);
      if (id != null && seen.add(id)) {
        skills.add(_Choice(id, skillsLabel(id)));
      }
    }
    pool(QuizKind.backgroundSkills).add(
      _Candidate(
        'bgSkills:${bg.id}',
        (rng) => _question(
          QuizKind.backgroundSkills,
          'bgSkills:${bg.id}',
          mine,
          skills,
          rng,
          subject: bg.name,
          subjectId: bg.id,
        ),
      ),
    );
  }

  Feat? featOf(Background b) =>
      b.originFeatId == null ? null : repo.feat(b.originFeatId!);
  final feat = featOf(bg);
  if (feat != null) {
    final feats = <_Choice>[];
    final seen = <String>{};
    for (final b in _byId(repo.backgrounds.values, (b) => b.id)) {
      final f = featOf(b);
      if (f != null && seen.add(f.id)) feats.add(_Choice(f.id, f.name));
    }
    pool(QuizKind.backgroundFeat).add(
      _Candidate(
        'bgFeat:${bg.id}',
        (rng) => _question(
          QuizKind.backgroundFeat,
          'bgFeat:${bg.id}',
          feat.id,
          feats,
          rng,
          subject: bg.name,
          subjectId: bg.id,
        ),
      ),
    );
  }
}

void _spells(
  Character c,
  ContentRepository repo,
  List<_Candidate> Function(QuizKind) pool,
  Random rng,
) {
  final sheet = CharacterCompiler(repo).compile(c);
  final ids = <String>{
    ...c.cantripIds,
    ...c.spellIds,
    for (final l in c.classCantripIds.values) ...l,
    for (final l in c.classSpellIds.values) ...l,
    ...sheet.alwaysPreparedSpellIds,
    for (final i in sheet.innateSpells) i.spellId,
  };
  final spells = [
    for (final id in ids.toList()..sort())
      if (repo.spell(id) case final s?) s,
  ];

  // Los valores se leen en el idioma activo, pero el catálogo los guarda en
  // español: se traducen antes de mostrarlos, o «Touch» y «Toque» serían dos
  // opciones del mismo valor. La identidad de la opción es el español.
  String castingTime(Spell s) =>
      vocabularyLabel(VocabularyField.castingTime, s.castingTime);
  String range(Spell s) => vocabularyLabel(VocabularyField.range, s.range);
  String school(Spell s) => vocabularyLabel(VocabularyField.school, s.school);
  List<_Choice> values(
    String Function(Spell) source,
    String Function(Spell) label,
  ) {
    final out = <_Choice>[];
    final seen = <String>{};
    for (final s in _byId(repo.spells.values, (s) => s.id)) {
      final raw = source(s);
      if (raw.isEmpty || raw.length > _maxOptionLength) continue;
      if (seen.add(raw)) out.add(_Choice(raw, label(s)));
    }
    return out;
  }

  final times = values((s) => s.castingTime, castingTime);
  final ranges = values((s) => s.range, range);
  final schools = values((s) => s.school, school);

  bool selfAmbiguous(String correct, String other) {
    const bare = 'Personal';
    final correctBare = correct == bare;
    final otherBare = other == bare;
    final correctQualified = correct.startsWith('$bare (');
    final otherQualified = other.startsWith('$bare (');
    return (correctBare && otherQualified) || (correctQualified && otherBare);
  }

  void add(
    QuizKind kind,
    Spell s,
    String raw,
    String label,
    List<_Choice> choices, {
    bool Function(String id)? allow,
  }) {
    if (raw.isEmpty || raw.length > _maxOptionLength) return;
    if (!choices.any((c) => c.id == raw)) return;
    pool(kind).add(
      _Candidate(
        'spell:${s.id}',
        (rng) => _question(
          kind,
          'spell:${s.id}:${kind.name}',
          raw,
          choices,
          rng,
          allow: allow,
          subject: s.name,
          subjectId: s.id,
        ),
      ),
    );
  }

  // Casi todo conjuro es una acción: si se sortea parejo, «Acción» gana tres
  // de cada cuatro. Se dejan todos los que no lo son y, de las acciones,
  // tantas como esos, para que el sorteo no se quede en la acción.
  final actions = <Spell>[];
  final others = <Spell>[];
  for (final s in spells) {
    if (s.actionType == SpellActionType.action) {
      actions.add(s);
    } else {
      others.add(s);
    }
  }
  actions.shuffle(rng);
  final casting = [
    ...others,
    ...actions.take(others.isEmpty ? actions.length : others.length),
  ];

  for (final s in casting) {
    add(QuizKind.spellCastingTime, s, s.castingTime, castingTime(s), times);
  }
  for (final s in spells) {
    add(
      QuizKind.spellRange,
      s,
      s.range,
      range(s),
      ranges,
      allow: (other) => !selfAmbiguous(s.range, other),
    );
    add(QuizKind.spellSchool, s, s.school, school(s), schools);
  }
}

/// Reescribe una ronda ya armada en el idioma activo. No sortea de nuevo: al
/// cambiar de idioma a mitad de ronda las preguntas siguen siendo las mismas
/// y solo cambia el texto.
List<QuizQuestion> quizLocalize(
  List<Map<String, dynamic>> questions,
  ContentRepository repo,
) =>
    [for (final raw in questions) _localize(QuizQuestion.fromJson(raw), repo)];

ClassFeature? _featureBySlot(ContentRepository repo, String slot) {
  final cut = slot.indexOf(':');
  if (cut < 0 || cut == slot.length - 1) return null;
  final owner = slot.substring(0, cut);
  final which = slot.substring(cut + 1);
  final index = int.tryParse(which.substring(1));
  if (index == null) return null;
  final features = which.startsWith('c')
      ? repo.characterClass(owner)?.features
      : which.startsWith('s')
          ? repo.subclass(owner)?.features
          : null;
  if (features == null || index >= features.length) return null;
  return features[index];
}

ClassFeature? _traitById(
  ContentRepository repo,
  String subjectId,
  String optionId,
) {
  if (optionId.contains(':')) {
    final cut = optionId.indexOf(':');
    final race = repo.race(optionId.substring(0, cut));
    final index = int.tryParse(optionId.substring(cut + 1));
    if (race == null || index == null) return null;
    final traits = _traitsOf(race, null, 20).toList();
    return index < traits.length ? traits[index] : null;
  }
  final parts = subjectId.split('|');
  final race = parts.isEmpty ? null : repo.race(parts.first);
  if (race == null) return null;
  final lineage =
      parts.length > 1 && parts[1].isNotEmpty ? repo.lineage(parts[1]) : null;
  final index = int.tryParse(optionId);
  if (index == null) return null;
  final traits = _traitsOf(race, lineage, 20).toList();
  return index < traits.length ? traits[index] : null;
}

String _pairLabel(String id, String Function(String name) label) =>
    _join([for (final name in id.split('+')) label(name)]);

QuizQuestion _localize(QuizQuestion q, ContentRepository repo) {
  String labelOf(String id) {
    switch (q.kind) {
      case QuizKind.condition:
        return conditionLabel(id);
      case QuizKind.skillAbility:
        return Ability.values.byName(id).label;
      case QuizKind.masteryByText:
      case QuizKind.weaponMastery:
        return weaponMasteries[id]?.name ?? id;
      case QuizKind.propertyByText:
        return weaponProperties[id]?.name ?? id;
      case QuizKind.weaponDamage:
      case QuizKind.armorAc:
        return q.kind == QuizKind.armorAc ? _acLabel(id) : _damageLabel(id);
      case QuizKind.armorCategory:
        return armorTrainingLabel(id);
      case QuizKind.classFeatureByText:
        return _featureBySlot(repo, id)?.name ?? id;
      case QuizKind.classFeatureLevel:
      case QuizKind.hitDie:
        return id;
      case QuizKind.savingThrows:
        return _pairLabel(id, (name) => Ability.values.byName(name).label);
      case QuizKind.speciesTraitByText:
        return _traitById(repo, q.subjectId ?? '', id)?.name ?? id;
      case QuizKind.backgroundSkills:
        return _pairLabel(id, (name) => Skill.values.byName(name).label);
      case QuizKind.backgroundFeat:
        return repo.feat(id)?.name ?? id;
      case QuizKind.spellCastingTime:
        return vocabularyLabel(VocabularyField.castingTime, id);
      case QuizKind.spellRange:
        return vocabularyLabel(VocabularyField.range, id);
      case QuizKind.spellSchool:
        return vocabularyLabel(VocabularyField.school, id);
    }
  }

  String? subject = q.subject;
  String? quote = q.quote;
  switch (q.kind) {
    case QuizKind.condition:
      subject = q.subjectId == null ? subject : conditionLabel(q.subjectId!);
    case QuizKind.skillAbility:
      subject = Skill.fromId(q.subjectId ?? '')?.label ?? subject;
    case QuizKind.weaponMastery:
    case QuizKind.weaponDamage:
      subject = repo.weapon(q.subjectId ?? '')?.name ?? subject;
    case QuizKind.armorAc:
    case QuizKind.armorCategory:
      subject = repo.armorPiece(q.subjectId ?? '')?.name ?? subject;
    case QuizKind.classFeatureByText:
      subject = repo.characterClass(q.subjectId ?? '')?.name ?? subject;
      quote = _featureBySlot(repo, q.optionIds.elementAtOrNull(q.answer) ?? '')
              ?.description ??
          quote;
    case QuizKind.classFeatureLevel:
      final slot = q.key.startsWith('feature:') ? q.key.substring(8) : '';
      subject = _featureBySlot(repo, slot)?.name ?? subject;
    case QuizKind.hitDie:
    case QuizKind.savingThrows:
      subject = repo.characterClass(q.subjectId ?? '')?.name ?? subject;
    case QuizKind.speciesTraitByText:
      final raceId = (q.subjectId ?? '').split('|').first;
      subject = repo.race(raceId)?.name ?? subject;
      quote = _traitById(
            repo,
            q.subjectId ?? '',
            q.optionIds.elementAtOrNull(q.answer) ?? '',
          )?.description ??
          quote;
    case QuizKind.backgroundSkills:
    case QuizKind.backgroundFeat:
      subject = repo.background(q.subjectId ?? '')?.name ?? subject;
    case QuizKind.spellCastingTime:
    case QuizKind.spellRange:
    case QuizKind.spellSchool:
      subject = repo.spell(q.subjectId ?? '')?.name ?? subject;
    case QuizKind.masteryByText:
      quote = weaponMasteries[q.subjectId]?.description ?? quote;
    case QuizKind.propertyByText:
      quote = weaponProperties[q.subjectId]?.description ?? quote;
  }

  return QuizQuestion(
    kind: q.kind,
    key: q.key,
    subject: subject,
    subjectId: q.subjectId,
    level: q.level,
    quote: quote,
    options: [for (final id in q.optionIds) labelOf(id)],
    optionIds: q.optionIds,
    answer: q.answer,
  );
}

String _damageLabel(String id) {
  final parts = id.split('|');
  if (parts.length != 2) return id;
  return '${parts[0]} ${DamageType.labelFor(parts[1]).toLowerCase()}';
}
