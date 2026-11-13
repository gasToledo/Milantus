import 'dart:math';

import '../data/content_repository.dart';
import '../domain/character.dart';
import '../domain/content.dart';
import '../domain/content_language.dart';
import '../domain/content_vocabulary.dart';
import '../domain/damage_type.dart';
import '../domain/effects.dart';
import '../domain/skill.dart';
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
  condition(QuizTopic.rules);

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
  rules('rules');

  const QuizTopic(this.wire);
  final String wire;
}

/// Una pregunta de opción múltiple, ya armada con el idioma del catálogo.
/// Las preguntas salen siempre del catálogo y del personaje; nada se escribe
/// a mano.
class QuizQuestion {
  final QuizKind kind;

  /// Lo que se pregunta (rasgo, conjuro, clase…); null si el tipo no lo usa.
  final String? subject;

  /// El id que la UI necesita (`condition`: el estado; `spell*`: el conjuro).
  final String? subjectId;

  /// Solo en `classFeatureLevel`: el nivel correcto.
  final int? level;

  /// El texto a reconocer, en los tipos «por texto».
  final String? quote;

  /// Exactamente 4 rótulos distintos.
  final List<String> options;

  /// Índice de la correcta en [options].
  final int answer;

  const QuizQuestion({
    required this.kind,
    this.subject,
    this.subjectId,
    this.level,
    this.quote,
    required this.options,
    required this.answer,
  });

  QuizTopic get topic => kind.topic;

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'topic': topic.wire,
        'subject': subject,
        'subjectId': subjectId,
        'level': level,
        'quote': quote,
        'options': options,
        'answer': answer,
      };
}

/// Un rótulo largo (el «Reacción, que realizás al recibir daño…» de un solo
/// conjuro) delata la correcta entre opciones de dos palabras: no se pregunta
/// ni se ofrece de distractor.
const _maxOptionLength = 30;

/// Una pregunta posible: su tema (para no repetirlo en la ronda) y cómo
/// armarla. Armar puede fallar (`null`) si no hay 4 opciones distintas.
class _Candidate {
  final String key;
  final QuizQuestion? Function(Random rng) build;
  const _Candidate(this.key, this.build);
}

/// Arma una ronda de [count] preguntas. Sin [character], de reglas generales.
/// La misma [seed] da la misma ronda: todo el azar sale de un `Random(seed)` y
/// los recorridos del catálogo y de la ficha son de orden estable.
///
/// No repite tema (el mismo rasgo o conjuro no sale dos veces) y mezcla los
/// tipos: hasta 3 del mismo, salvo que haya pocos tipos y no alcancen para
/// llegar a [count] (la ronda de reglas es toda `condition`).
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
  } else {
    _characterPools(character, repo, pools);
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

/// La correcta más 3 distractores sacados de [pool] (distintos entre sí y de
/// la correcta), mezcladas. Null si el pool no alcanza.
(List<String>, int)? _options(
    String correct, Iterable<String> pool, Random rng) {
  final distractors = <String>{
    for (final p in pool)
      if (p != correct) p,
  }.toList()
    ..shuffle(rng);
  if (distractors.length < 3) return null;
  final options = [correct, ...distractors.take(3)]..shuffle(rng);
  return (options, options.indexOf(correct));
}

QuizQuestion? _question(
  QuizKind kind,
  String correct,
  Iterable<String> pool,
  Random rng, {
  String? subject,
  String? subjectId,
  int? level,
  String? quote,
}) {
  final o = _options(correct, pool, rng);
  if (o == null) return null;
  return QuizQuestion(
    kind: kind,
    subject: subject,
    subjectId: subjectId,
    level: level,
    quote: quote,
    options: o.$1,
    answer: o.$2,
  );
}

/// «A y B», con las dos partes ordenadas: «Sabiduría y Carisma» y «Carisma y
/// Sabiduría» son el mismo par y no pueden ser dos opciones.
String _pair(List<String> labels) {
  final sorted = [...labels]..sort();
  return sorted.join(localized(' y ', ' and '));
}

// ---------------------------------------------------------------------------
// Reglas generales
// ---------------------------------------------------------------------------

List<_Candidate> _conditions() {
  final labels = [for (final id in conditionIds) conditionLabel(id)];
  return [
    for (final id in conditionIds)
      _Candidate(
        'condition:$id',
        (rng) => _question(
          QuizKind.condition,
          conditionLabel(id),
          labels,
          rng,
          subject: conditionLabel(id),
          subjectId: id,
        ),
      ),
  ];
}

// ---------------------------------------------------------------------------
// Personaje
// ---------------------------------------------------------------------------

void _characterPools(
  Character c,
  ContentRepository repo,
  Map<QuizKind, List<_Candidate>> pools,
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
  }
  if (classes.isNotEmpty) _firstClass(classes.first.$1, repo, pool);

  final race = repo.race(c.raceId);
  if (race != null) {
    _speciesTraits(race, repo.lineage(c.lineageId ?? ''), c.totalLevel, repo,
        pool(QuizKind.speciesTraitByText));
  }
  final bg = repo.background(c.backgroundId);
  if (bg != null) _background(bg, repo, pool);

  _spells(c, repo, pool);
}

/// Rasgos con descripción, sin repetir nombre (el aasimar tiene dos «Manos
/// Sanadoras»: el segundo es el contador de usos) y sin el que se regala por
/// nombrarse a sí mismo en el texto.
List<ClassFeature> _readable(Iterable<ClassFeature> features) {
  final seen = <String>{};
  return [
    for (final f in features)
      if (f.description.trim().isNotEmpty &&
          !f.description.toLowerCase().contains(f.name.toLowerCase()) &&
          seen.add(f.name))
        f,
  ];
}

void _classFeatures(
  CharacterClass cls,
  int level,
  Subclass? sub,
  List<_Candidate> Function(QuizKind) pool,
) {
  final all = [...cls.features, ...?sub?.features];
  final names = [for (final f in all) f.name];
  for (final f in _readable(all.where((f) => f.level <= level))) {
    pool(QuizKind.classFeatureByText).add(_Candidate(
      'feature:${cls.id}:${f.name}',
      (rng) => _question(QuizKind.classFeatureByText, f.name, names, rng,
          subject: cls.name, quote: f.description),
    ));
  }

  // Solo rasgos de la clase cuyo nombre aparece una vez: «Mejora de
  // Puntuación de Característica» se repite en cada nivel y no tiene un
  // «nivel en que se obtiene».
  final counts = <String, int>{};
  for (final f in cls.features) {
    counts[f.name] = (counts[f.name] ?? 0) + 1;
  }
  final allLevels = {for (final f in cls.features) '${f.level}'};
  for (final f in cls.features) {
    if (f.level > level || counts[f.name] != 1) continue;
    pool(QuizKind.classFeatureLevel).add(_Candidate(
      // La misma clave que `classFeatureByText`: es el mismo rasgo.
      'feature:${cls.id}:${f.name}',
      (rng) => _question(
        QuizKind.classFeatureLevel,
        '${f.level}',
        allLevels,
        rng,
        subject: f.name,
        level: f.level,
      ),
    ));
  }
}

/// El dado de golpe y las salvaciones los da la primera clase.
void _firstClass(
  CharacterClass cls,
  ContentRepository repo,
  List<_Candidate> Function(QuizKind) pool,
) {
  pool(QuizKind.hitDie).add(_Candidate(
    'hitDie:${cls.id}',
    (rng) => _question(
      QuizKind.hitDie,
      'd${cls.hitDie}',
      [
        for (final d in const [6, 8, 10, 12]) 'd$d'
      ],
      rng,
      subject: cls.name,
      subjectId: cls.id,
    ),
  ));

  String? pairOf(CharacterClass k) => k.savingThrows.length == 2
      ? _pair([for (final a in k.savingThrows) a.label])
      : null;
  final mine = pairOf(cls);
  if (mine == null) return;
  pool(QuizKind.savingThrows).add(_Candidate(
    'saves:${cls.id}',
    (rng) => _question(
      QuizKind.savingThrows,
      mine,
      [
        for (final k in repo.classesSorted)
          if (pairOf(k) case final p?) p,
      ],
      rng,
      subject: cls.name,
      subjectId: cls.id,
    ),
  ));
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
  final ownNames = [for (final t in own) t.name];
  // Si los de su especie no alcanzan para 3 distractores, se completa con los
  // de otras.
  final others = [
    for (final r in repo.racesSorted)
      if (r.id != race.id)
        for (final t in _traitsOf(r, null, 20)) t.name,
  ];
  for (final t in _readable(own.where((t) => t.level <= level))) {
    out.add(_Candidate(
      'trait:${race.id}:${t.name}',
      (rng) {
        final fromOwn = _options(t.name, ownNames, rng);
        // Distractores propios primero; si no alcanzan, el pool se amplía.
        return _question(
          QuizKind.speciesTraitByText,
          t.name,
          fromOwn != null ? ownNames : [...ownNames, ...others],
          rng,
          subject: race.name,
          quote: t.description,
        );
      },
    ));
  }
}

void _background(
  Background bg,
  ContentRepository repo,
  List<_Candidate> Function(QuizKind) pool,
) {
  String? skillsOf(Background b) => b.skillProficiencies.length == 2
      ? _pair([for (final s in b.skillProficiencies) Skill.labelFor(s)])
      : null;
  final mine = skillsOf(bg);
  if (mine != null) {
    pool(QuizKind.backgroundSkills).add(_Candidate(
      'bgSkills:${bg.id}',
      (rng) => _question(
        QuizKind.backgroundSkills,
        mine,
        [
          for (final b in repo.backgroundsSorted)
            if (skillsOf(b) case final p?) p,
        ],
        rng,
        subject: bg.name,
        subjectId: bg.id,
      ),
    ));
  }

  Feat? featOf(Background b) =>
      b.originFeatId == null ? null : repo.feat(b.originFeatId!);
  final feat = featOf(bg);
  if (feat != null) {
    pool(QuizKind.backgroundFeat).add(_Candidate(
      'bgFeat:${bg.id}',
      (rng) => _question(
        QuizKind.backgroundFeat,
        feat.name,
        [
          for (final b in repo.backgroundsSorted)
            if (featOf(b) case final f?) f.name,
        ],
        rng,
        subject: bg.name,
        subjectId: bg.id,
      ),
    ));
  }
}

void _spells(
  Character c,
  ContentRepository repo,
  List<_Candidate> Function(QuizKind) pool,
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
    for (final id in ids)
      if (repo.spell(id) case final s?) s,
  ];

  // Los valores se leen en el idioma activo, pero el catálogo los guarda en
  // español: se traducen antes de compararlos, o «Touch» y «Toque» serían dos
  // opciones del mismo valor.
  String castingTime(Spell s) =>
      vocabularyLabel(VocabularyField.castingTime, s.castingTime);
  String range(Spell s) => vocabularyLabel(VocabularyField.range, s.range);
  String school(Spell s) => vocabularyLabel(VocabularyField.school, s.school);
  Iterable<String> values(String Function(Spell) of) => {
        for (final s in repo.spellsSorted)
          if (of(s).isNotEmpty && of(s).length <= _maxOptionLength) of(s),
      };
  final times = values(castingTime);
  final ranges = values(range);
  final schools = values(school);

  void add(QuizKind kind, Spell s, String correct, Iterable<String> pool_) {
    if (correct.isEmpty || correct.length > _maxOptionLength) return;
    pool(kind).add(_Candidate(
      'spell:${s.id}',
      (rng) => _question(kind, correct, pool_, rng,
          subject: s.name, subjectId: s.id),
    ));
  }

  for (final s in spells) {
    add(QuizKind.spellCastingTime, s, castingTime(s), times);
    add(QuizKind.spellRange, s, range(s), ranges);
    add(QuizKind.spellSchool, s, school(s), schools);
  }
}
