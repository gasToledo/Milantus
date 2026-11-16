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
/// que arma el enunciado con una plantilla por tipo. Un tipo nuevo cumple el
/// estándar de `docs/desarrollo/quiz.md`.
enum QuizKind {
  classFeatureByText(QuizTopic.classTopic),
  classFeatureLevel(QuizTopic.classTopic),
  hitDie(QuizTopic.classTopic),
  savingThrows(QuizTopic.classTopic),
  armorTraining(QuizTopic.classTopic),
  classSkillChoice(QuizTopic.classTopic),
  speciesTraitByText(QuizTopic.species),
  backgroundSkills(QuizTopic.background),
  backgroundFeat(QuizTopic.background),
  backgroundAbilities(QuizTopic.background),
  backgroundTool(QuizTopic.background),
  spellCastingTime(QuizTopic.spells),
  spellRange(QuizTopic.spells),
  spellMoveDistance(QuizTopic.spells),
  spellSchool(QuizTopic.spells),
  spellLevel(QuizTopic.spells),
  spellFlag(QuizTopic.spells),
  classSpellList(QuizTopic.spells),
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

  /// Contador de una fila de progresión (`classFeatureLevel`). El [subject]
  /// es el rasgo sin el paréntesis; la UI arma el enunciado con este tipo y
  /// este número. Null en la primera vez que se obtiene el rasgo.
  final QuizProgress? progress;

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
    this.progress,
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
        'progress': progress?.toJson(),
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
        progress: QuizProgress.fromJson(j['progress']),
      );
}

/// Qué cuenta la fila de progresión. No depende del idioma: la UI elige la
/// plantilla y el número entra tal cual («7», «+20», «2d10»).
enum QuizProgressKind {
  known,
  uses,
  forms,
  feet,
  weapons,
  spellLevel,
  dice,
  extraSkills,
}

class QuizProgress {
  final QuizProgressKind kind;
  final int n;

  /// Solo [QuizProgressKind.dice]: «2d10», igual en los dos idiomas.
  final String? dice;

  const QuizProgress({required this.kind, required this.n, this.dice});

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'n': n,
        'dice': dice,
      };

  static QuizProgress? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final j = raw.cast<String, dynamic>();
    final kind = j['kind'];
    final n = j['n'];
    if (kind is! String || n is! int) return null;
    return QuizProgress(
      kind: QuizProgressKind.values.byName(kind),
      n: n,
      dice: j['dice'] as String?,
    );
  }
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
/// No repite tema (el mismo rasgo o conjuro no sale dos veces) ni la misma
/// respuesta en un mismo tipo, y mezcla los tipos: hasta 3 del mismo, salvo
/// que haya pocos tipos y no alcancen para llegar a [count].
///
/// El sorteo elige primero el tema del chip y después el tipo: si sorteara
/// parejo por tipo, Equipo (seis de los ocho tipos de Reglas generales) se
/// quedaba con tres de cada cuatro preguntas.
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
  if (pools.isEmpty) return [];
  for (final c in pools.values) {
    c.shuffle(rng);
  }
  final cap = max(3, (count / pools.length).ceil());
  final topicCap =
      (count / {for (final k in pools.keys) k.topic}.length).ceil();

  final used = <String>{};
  final answers = <String>{};
  final taken = <QuizKind, int>{};
  final byTopic = <QuizTopic, int>{};
  var easyTaken = false;
  QuizTopic? last;
  final out = <QuizQuestion>[];
  while (out.length < count) {
    final open = [
      for (final e in pools.entries)
        if (e.value.isNotEmpty &&
            (taken[e.key] ?? 0) < cap &&
            !(easyTaken && _easy.contains(e.key)))
          e.key,
    ];
    if (open.isEmpty) break;
    // Dos por tipo y el tema repartido son preferencias, no reglas: si
    // dejarlos afuera corta la ronda antes de [count], se ignoran.
    final balanced = [
      for (final k in open)
        if ((taken[k] ?? 0) < 2 && (byTopic[k.topic] ?? 0) < topicCap) k,
    ];
    final pick = balanced.isEmpty ? open : balanced;
    final topics = {for (final k in pick) k.topic}.toList();
    if (topics.length > 1) topics.remove(last);
    final topic = topics[rng.nextInt(topics.length)];
    final kinds = [
      for (final k in pick)
        if (k.topic == topic) k,
    ];
    final kind = kinds[rng.nextInt(kinds.length)];
    final cand = pools[kind]!.removeLast();
    if (used.contains(cand.key)) continue;
    final q = cand.build(rng);
    if (q == null) continue;
    // «Conjuración» dos veces, o «nivel 1» para dos rasgos, se contesta la
    // segunda por descarte.
    if (!answers.add('${kind.name}:${q.optionIds[q.answer]}')) continue;
    used.add(cand.key);
    taken[kind] = (taken[kind] ?? 0) + 1;
    byTopic[kind.topic] = (byTopic[kind.topic] ?? 0) + 1;
    if (_easy.contains(kind)) easyTaken = true;
    last = kind.topic;
    out.add(q);
  }
  return out;
}

/// Se contestan casi sin pensar (Acrobacias → Destreza, el dado de golpe, las
/// salvaciones de la clase): una por ronda entre todas.
const _easy = {QuizKind.skillAbility, QuizKind.hitDie, QuizKind.savingThrows};

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
  bool numeric = false,
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
  // Niveles, CA, dados y distancias se leen de menor a mayor: buscar el valor
  // no tiene que costar más que saberlo. Se ordena por id, no por rótulo, así
  // la correcta queda en el mismo lugar en los dos idiomas.
  if (numeric && picked.every((id) => _digits.hasMatch(id))) {
    picked.sort(_byNumbers);
  }
  return (
    [for (final id in picked) labels[id]!],
    picked,
    picked.indexOf(correctId),
  );
}

final _digits = RegExp(r'\d+');

/// «dex:12:max:2» antes que «flat:16», «1d6|piercing» antes que «1d8|…».
int _byNumbers(String a, String b) {
  final x = [for (final m in _digits.allMatches(a)) int.parse(m.group(0)!)];
  final y = [for (final m in _digits.allMatches(b)) int.parse(m.group(0)!)];
  for (var i = 0; i < min(x.length, y.length); i++) {
    if (x[i] != y[i]) return x[i].compareTo(y[i]);
  }
  return x.length != y.length ? x.length.compareTo(y.length) : a.compareTo(b);
}

QuizQuestion? _question(
  QuizKind kind,
  String key,
  String correctId,
  List<_Choice> pool,
  Random rng, {
  int count = 4,
  bool Function(String id)? allow,
  bool numeric = false,
  String? subject,
  String? subjectId,
  int? level,
  String? quote,
  QuizProgress? progress,
}) {
  final o = _choose(
    correctId,
    pool,
    rng,
    count: count,
    allow: allow,
    numeric: numeric,
  );
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
    progress: progress,
  );
}

/// «Fuerza y Constitución», en el orden de [Ability.values] (o el de
/// [Skill.values] para las habilidades). Ordenar alfabético cambia con el
/// idioma: «Constitución y Fuerza» en español y «Constitution and Strength»
/// no son el mismo par escrito al revés, y además no es como las lista el
/// libro. Con tres, «Fuerza, Destreza y Constitución»; ante «i» o «hi» la
/// conjunción es «e» («Destreza e Inteligencia», «Arcanos e Historia»).
String _join(List<String> labels) {
  if (labels.length < 2) return labels.join();
  final last = labels.last;
  final lower = last.toLowerCase();
  final e = (lower.startsWith('i') || lower.startsWith('hi')) &&
      !lower.startsWith('hie') &&
      !lower.startsWith('hia');
  final and = localized(e ? ' e ' : ' y ', ' and ');
  return '${labels.sublist(0, labels.length - 1).join(', ')}$and$last';
}

/// Entrenamiento con armadura de una clase: `light+medium+shield`, o `none`.
/// El rótulo es corto («Ligera, media y escudos») porque el enunciado ya dice
/// «armaduras»; los de la ficha («Armadura ligera») se repetirían tres veces.
const _armorTrainingOrder = ['light', 'medium', 'heavy', 'shield'];

String _armorTrainingId(List<String> categories) {
  final ids = [
    for (final c in _armorTrainingOrder)
      if (categories.contains(c)) c,
  ];
  return ids.isEmpty ? 'none' : ids.join('+');
}

String _armorTrainingLabel(String id) {
  if (id == 'none') return localized('Ninguna', 'None');
  final words = [
    for (final c in id.split('+'))
      switch (c) {
        'light' => localized('ligera', 'light'),
        'medium' => localized('media', 'medium'),
        'heavy' => localized('pesada', 'heavy'),
        'shield' => localized('escudos', 'shields'),
        _ => c,
      },
  ];
  final text = _join(words);
  return text[0].toUpperCase() + text.substring(1);
}

final _parens = RegExp(r'\s*\(([^)]*)\)');

String _baseName(String name) =>
    name.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();

/// El paréntesis de una fila de progresión («7 conocidas», «+20 pies»,
/// «2d10»), en el idioma del catálogo activo. El nombre sin paréntesis no es
/// una progresión: es la primera vez que se obtiene el rasgo.
QuizProgress? _progressOf(String name) {
  final inner = _parens.firstMatch(name)?.group(1)?.trim().toLowerCase();
  if (inner == null || inner.isEmpty) return null;
  if (inner == 'dos usos' || inner == 'two uses') {
    return const QuizProgress(kind: QuizProgressKind.uses, n: 2);
  }
  if (inner == 'dos habilidades más' || inner == 'two more skills') {
    return const QuizProgress(kind: QuizProgressKind.extraSkills, n: 2);
  }
  final dice = RegExp(r'^(\d+)d(\d+)$').firstMatch(inner);
  if (dice != null) {
    return QuizProgress(
      kind: QuizProgressKind.dice,
      n: int.parse(dice.group(1)!),
      dice: dice.group(0),
    );
  }
  final feet = RegExp(r'^\+(\d+) (pies|feet)$').firstMatch(inner);
  if (feet != null) {
    return QuizProgress(
      kind: QuizProgressKind.feet,
      n: int.parse(feet.group(1)!),
    );
  }
  final spell = RegExp(
    r'^(?:conjuro de nivel|level) (\d+)(?: spell)?$',
  ).firstMatch(inner);
  if (spell != null) {
    return QuizProgress(
      kind: QuizProgressKind.spellLevel,
      n: int.parse(spell.group(1)!),
    );
  }
  final counted = RegExp(r'^(\d+) ([a-záéíóúñ ]+)$').firstMatch(inner);
  if (counted == null) return null;
  final n = int.parse(counted.group(1)!);
  final kind = switch (counted.group(2)) {
    'conocidas' || 'known' => QuizProgressKind.known,
    'usos' || 'uses' => QuizProgressKind.uses,
    'formas' || 'forms' => QuizProgressKind.forms,
    'armas' || 'weapons' => QuizProgressKind.weapons,
    _ => null,
  };
  return kind == null ? null : QuizProgress(kind: kind, n: n);
}

bool _sameProgress(QuizProgress a, QuizProgress b) =>
    a.kind == b.kind && a.n == b.n && a.dice == b.dice;

/// El contador de [kind] vigente en [level]: la última fila de ese rasgo y
/// ese tipo con nivel menor o igual. Las filas no están ordenadas.
QuizProgress? _progressAt(
  CharacterClass cls,
  String base,
  QuizProgressKind kind,
  int level,
) {
  final key = base.toLowerCase();
  ClassFeature? best;
  QuizProgress? progress;
  for (final f in cls.features) {
    if (f.level > level) continue;
    final row = _progressOf(f.name);
    if (row == null || row.kind != kind) continue;
    if (_baseName(f.name).toLowerCase() != key) continue;
    if (best == null || f.level >= best.level) {
      best = f;
      progress = row;
    }
  }
  return progress;
}

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
            numeric: true,
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
          numeric: true,
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
    // «Furia (4 usos)» no se obtiene en ese nivel: Furia se obtiene en el 1
    // y ahí pasan a ser 4 usos. El paréntesis se parte en tipo y número para
    // que la UI no tenga que leer el nombre. Mientras ese número siga
    // vigente, el otro nivel también sería correcto: no se ofrece.
    final progress = _progressOf(f.name);
    final base = _baseName(f.name);
    pool(QuizKind.classFeatureLevel).add(
      _Candidate(
        // La misma clave que `classFeatureByText`: es el mismo rasgo.
        'feature:${cls.id}:c$i',
        (rng) => _question(
          numeric: true,
          QuizKind.classFeatureLevel,
          'feature:${cls.id}:c$i',
          '${f.level}',
          allLevels,
          rng,
          allow: progress == null
              ? null
              : (id) {
                  final level = int.tryParse(id);
                  if (level == null || level == f.level) return true;
                  final at = _progressAt(cls, base, progress.kind, level);
                  return at == null || !_sameProgress(at, progress);
                },
          subject: progress == null ? f.name : base,
          subjectId: cls.id,
          level: f.level,
          progress: progress,
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
        numeric: true,
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

  // Cinco combinaciones en todo el catálogo: alcanzan para cuatro opciones.
  final armorChoices = <_Choice>[];
  final seenArmor = <String>{};
  for (final k in _byId(repo.classes.values, (k) => k.id)) {
    final id = _armorTrainingId(k.armorProficiencies);
    if (seenArmor.add(id)) {
      armorChoices.add(_Choice(id, _armorTrainingLabel(id)));
    }
  }
  pool(QuizKind.armorTraining).add(
    _Candidate(
      'armorTraining:${cls.id}',
      (rng) => _question(
        QuizKind.armorTraining,
        'armorTraining:${cls.id}',
        _armorTrainingId(cls.armorProficiencies),
        armorChoices,
        rng,
        subject: cls.name,
        subjectId: cls.id,
      ),
    ),
  );

  // Al revés: una habilidad de su lista contra tres de afuera. Un candidato
  // por habilidad, todos con la misma clave: sale una por ronda, pero cada
  // ronda puede preguntar por otra. El bardo elige entre todas y no entra.
  final from = cls.skillChoiceFrom.toSet();
  if (from.isNotEmpty && from.length < Skill.values.length - 2) {
    final skills = [for (final s in Skill.values) _Choice(s.id, s.label)];
    for (final s in Skill.values) {
      if (!from.contains(s.id)) continue;
      pool(QuizKind.classSkillChoice).add(
        _Candidate(
          'classSkills:${cls.id}',
          (rng) => _question(
            QuizKind.classSkillChoice,
            'classSkills:${cls.id}',
            s.id,
            skills,
            rng,
            allow: (id) => id == s.id || !from.contains(id),
            subject: cls.name,
            subjectId: cls.id,
          ),
        ),
      );
    }
  }

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

  String? abilitiesId(Background b) => b.abilityOptions.length != 3
      ? null
      : [
          for (final a in Ability.values)
            if (b.abilityOptions.contains(a)) a.name,
        ].join('+');
  final abilities = abilitiesId(bg);
  if (abilities != null) {
    final trios = <_Choice>[];
    final seen = <String>{};
    for (final b in _byId(repo.backgrounds.values, (b) => b.id)) {
      final id = abilitiesId(b);
      if (id != null && seen.add(id)) {
        trios.add(_Choice(id, _pairLabel(id, _abilityLabel)));
      }
    }
    final mine = abilities.split('+').toSet();
    pool(QuizKind.backgroundAbilities).add(
      _Candidate('bgAbilities:${bg.id}', (rng) {
        QuizQuestion? ask(bool Function(String id)? allow) => _question(
              QuizKind.backgroundAbilities,
              'bgAbilities:${bg.id}',
              abilities,
              trios,
              rng,
              allow: allow,
              subject: bg.name,
              subjectId: bg.id,
            );
        // Distractores que comparten dos de las tres: uno al azar se descarta
        // sabiendo una sola característica.
        return ask(
              (id) => id.split('+').where(mine.contains).length >= 2,
            ) ??
            ask(null);
      }),
    );
  }

  // `gaming-set`, `musical-instrument` y `artisans-tools` son «uno a tu
  // elección», no una herramienta: «Juego» como respuesta no enseña nada, y
  // como distractor sería la única opción genérica.
  const generic = {'gaming-set', 'musical-instrument', 'artisans-tools'};
  String? toolOf(Background b) => b.toolProficiencies.length == 1 &&
          !generic.contains(b.toolProficiencies.first)
      ? b.toolProficiencies.first
      : null;
  final tool = toolOf(bg);
  if (tool != null) {
    final tools = <_Choice>[];
    final seen = <String>{};
    for (final b in _byId(repo.backgrounds.values, (b) => b.id)) {
      final id = toolOf(b);
      if (id != null && seen.add(id)) {
        tools.add(_Choice(id, toolProficiencyLabel(id)));
      }
    }
    pool(QuizKind.backgroundTool).add(
      _Candidate(
        'bgTool:${bg.id}',
        (rng) => _question(
          QuizKind.backgroundTool,
          'bgTool:${bg.id}',
          tool,
          tools,
          rng,
          subject: bg.name,
          subjectId: bg.id,
        ),
      ),
    );
  }
}

String _abilityLabel(String name) => Ability.values.byName(name).label;

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
  final levels = [
    for (var n = 0; n <= 9; n++) _Choice('$n', _spellLevelLabel('$n')),
  ];

  // Dos conjuros tienen una distancia fija de movimiento. Los distractores
  // salen de los alcances «N pies» del catálogo: son distancias del libro, y
  // con dos valores no alcanza para cuatro opciones.
  final moves = <_Choice>[];
  final seenMove = <String>{};
  void addMove(String raw) {
    if (!RegExp(r'^\d+ pies$').hasMatch(raw) || raw.length > _maxOptionLength) {
      return;
    }
    if (seenMove.add(raw)) {
      moves.add(_Choice(raw, vocabularyLabel(VocabularyField.range, raw)));
    }
  }

  for (final s in _byId(repo.spells.values, (s) => s.id)) {
    final feet = s.moveFeet;
    if (feet != null) addMove('$feet pies');
    addMove(s.range);
  }

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
    bool numeric = false,
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
          numeric: numeric,
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
    // «¿Cuál es el alcance?» con respuesta «Personal» a secas no distingue
    // nada: casi cualquier conjuro sobre uno mismo la comparte. Con área
    // («Personal (emanación de 10 pies)») sí se pregunta, y el distractor
    // pelado sigue afuera para que no se confundan.
    if (s.range != 'Personal') {
      add(
        QuizKind.spellRange,
        s,
        s.range,
        range(s),
        ranges,
        allow: (other) => !selfAmbiguous(s.range, other),
        numeric: true,
      );
    }
    final feet = s.moveFeet;
    if (feet != null) {
      final raw = '$feet pies';
      add(
        QuizKind.spellMoveDistance,
        s,
        raw,
        vocabularyLabel(VocabularyField.range, raw),
        moves,
        numeric: true,
      );
    }
    add(QuizKind.spellSchool, s, s.school, school(s), schools);
    // Niveles a tres o menos del correcto: «9» como distractor de un conjuro
    // de nivel 1 se descarta sin saber nada.
    add(
      QuizKind.spellLevel,
      s,
      '${s.level}',
      _spellLevelLabel('${s.level}'),
      levels,
      allow: (id) => (int.parse(id) - s.level).abs() <= 3,
      numeric: true,
    );
  }

  // Concentración, ritual y lista de la clase miran la lista entera de cada
  // clase con la que lanza, no solo lo que conoce: con lo suyo no alcanza
  // para tres distractores. Hasta el nivel más alto que ya conoce, para no
  // preguntar por conjuros que todavía no puede lanzar.
  if (spells.isEmpty) return;
  final maxLevel = spells.fold(0, (m, s) => max(m, s.level));
  final classIds = {...c.classHistory, c.classId};
  final listed = <String, List<Spell>>{
    for (final id in classIds)
      id: [
        for (final s in _byId(repo.spells.values, (s) => s.id))
          if (s.classes.contains(id) &&
              s.level <= maxLevel &&
              s.name.length <= _maxOptionLength)
            s,
      ],
  }..removeWhere((_, l) => l.isEmpty);
  List<_Choice> names(Iterable<Spell> l) =>
      [for (final s in l) _Choice(s.id, s.name)];

  // Concentración y ritual son un solo tipo: si fueran dos, la ronda podía
  // traer tres «¿cuál de estos conjuros…?» seguidos con la lista de la clase.
  for (final l in listed.values) {
    final choices = names(l);
    final byId = {for (final s in l) s.id: s};
    for (final (flag, has) in [
      ('concentration', (Spell s) => s.concentration),
      ('ritual', (Spell s) => s.ritual),
    ]) {
      for (final s in l) {
        if (!has(s)) continue;
        pool(QuizKind.spellFlag).add(
          _Candidate(
            'spell:${s.id}',
            (rng) => _question(
              QuizKind.spellFlag,
              'spell:${s.id}:${QuizKind.spellFlag.name}',
              s.id,
              choices,
              rng,
              allow: (id) => id == s.id || !has(byId[id]!),
              subjectId: flag,
            ),
          ),
        );
      }
    }
  }

  // Al revés: un conjuro de la lista contra tres del mismo nivel que no
  // están. Los que el personaje tiene por otra vía (el patrón, la especie)
  // no se ofrecen: no son de la lista, pero los ve en su ficha.
  for (final MapEntry(key: classId, value: l) in listed.entries) {
    final cls = repo.characterClass(classId);
    if (cls == null) continue;
    for (final s in l) {
      final others = [
        for (final o in _byId(repo.spells.values, (o) => o.id))
          if (o.level == s.level &&
              !o.classes.contains(classId) &&
              !ids.contains(o.id) &&
              o.name.length <= _maxOptionLength)
            o,
      ];
      pool(QuizKind.classSpellList).add(
        _Candidate(
          'spellList:$classId',
          (rng) => _question(
            QuizKind.classSpellList,
            'spellList:$classId',
            s.id,
            names([s, ...others]),
            rng,
            subject: cls.name,
            subjectId: classId,
          ),
        ),
      );
    }
  }
}

String _spellLevelLabel(String id) =>
    id == '0' ? localized('Truco', 'Cantrip') : id;

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
      case QuizKind.armorTraining:
        return _armorTrainingLabel(id);
      case QuizKind.classSkillChoice:
        return Skill.labelFor(id);
      case QuizKind.backgroundAbilities:
        return _pairLabel(id, _abilityLabel);
      case QuizKind.backgroundTool:
        return toolProficiencyLabel(id);
      case QuizKind.spellCastingTime:
        return vocabularyLabel(VocabularyField.castingTime, id);
      case QuizKind.spellRange:
      case QuizKind.spellMoveDistance:
        return vocabularyLabel(VocabularyField.range, id);
      case QuizKind.spellSchool:
        return vocabularyLabel(VocabularyField.school, id);
      case QuizKind.spellLevel:
        return _spellLevelLabel(id);
      case QuizKind.spellFlag:
      case QuizKind.classSpellList:
        return repo.spell(id)?.name ?? id;
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
      final name = _featureBySlot(repo, slot)?.name;
      // Con contador, el enunciado usa el rasgo pelado: el número viaja en
      // [QuizQuestion.progress] y no se relee del nombre traducido.
      subject = name == null
          ? subject
          : q.progress == null
              ? name
              : _baseName(name);
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
    case QuizKind.backgroundAbilities:
    case QuizKind.backgroundTool:
      subject = repo.background(q.subjectId ?? '')?.name ?? subject;
    case QuizKind.armorTraining:
    case QuizKind.classSkillChoice:
      subject = repo.characterClass(q.subjectId ?? '')?.name ?? subject;
    case QuizKind.spellCastingTime:
    case QuizKind.spellRange:
    case QuizKind.spellMoveDistance:
    case QuizKind.spellSchool:
    case QuizKind.spellLevel:
      subject = repo.spell(q.subjectId ?? '')?.name ?? subject;
    case QuizKind.spellFlag:
      break;
    case QuizKind.classSpellList:
      subject = repo.characterClass(q.subjectId ?? '')?.name ?? subject;
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
    progress: q.progress,
  );
}

String _damageLabel(String id) {
  final parts = id.split('|');
  if (parts.length != 2) return id;
  return '${parts[0]} ${DamageType.labelFor(parts[1]).toLowerCase()}';
}
