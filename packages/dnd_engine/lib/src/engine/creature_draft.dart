import '../domain/ability.dart';
import '../domain/content_source.dart';
import '../domain/creature.dart';
import 'dice.dart';

/// El borrador de un bloque de criatura que edita un formulario: pasa una
/// [Creature] a texto plano (`formOf`), arma la criatura de vuelta (`build`) y
/// dice qué campos no se pueden guardar (`errors`).
///
/// Vive en el motor porque `dnd_web` no tiene reglas propias: qué rango tiene la
/// CA, cómo se compone la línea de tipo o qué es un desafío válido se decide
/// una vez, con su test, y los formularios (hoy el de un PNJ, mañana el
/// homebrew) lo comparten.
class CreatureDraft {
  const CreatureDraft._();

  static String _t(Object? v) => (v?.toString() ?? '').trim();

  static Map<String, dynamic> _map(Object? v) =>
      v is Map ? v.cast<String, dynamic>() : const {};

  static List<Map<String, dynamic>> _rows(Object? v) => [
        for (final r in (v as List? ?? const [])) _map(r),
      ];

  /// Todo texto salvo `from` (el índice de la acción en la criatura original,
  /// o null si es nueva), que `build` usa para devolverle su `spellcasting`.
  static Map<String, dynamic> formOf(Creature c) {
    return {
      'name': c.name,
      // Sin tipo y con `kind` escrito (enjambres, objetos) el bloque sale
      // «Como en el libro» (''); sin `kind` es un bloque vacío y arranca en
      // Monstruosidad, el mismo valor inicial que el formulario de Flutter.
      'type': c.creatureType?.id ?? (c.kind.isEmpty ? 'monstrosity' : ''),
      'size': c.creatureSize?.id ?? 'medium',
      'speed': c.speed,
      'ac': c.ac,
      'hp': c.hp,
      'hitDice': c.hitDice ?? '',
      'cr': c.challengeRatingText ?? '',
      'initiative': c.initiativeBonus?.toString() ?? '',
      'passive': c.passivePerceptionValue?.toString() ?? '',
      'legendary': c.legendaryActionsPerRound?.toString() ?? '',
      'senses': c.senses,
      'languages': c.languages,
      'defenses': c.defenses,
      'abilities': {
        for (final a in Ability.values)
          a.code.toLowerCase(): '${c.abilityScores[a] ?? 10}',
      },
      'traits': [
        for (final t in c.traits)
          {'name': t.name, 'description': t.description},
      ],
      'actions': [
        for (var i = 0; i < c.actions.length; i++)
          {
            'from': i,
            'name': c.actions[i].name,
            'description': c.actions[i].description,
            'attackBonus': c.actions[i].attackBonus ?? '',
            'reach': c.actions[i].reach,
            'damage': c.actions[i].damage ?? '',
            'damageType': c.actions[i].damageType ?? '',
            'kind': c.actions[i].kind.id,
          },
      ],
    };
  }

  /// Arma la criatura. No lanza por datos inválidos: también alimenta la vista
  /// previa mientras se escribe, y ahí un campo a medias es lo normal.
  static Creature build(Creature base, Map<String, dynamic> form) {
    final t = CreatureType.fromJson(_t(form['type']));
    final s = CreatureSize.fromJson(_t(form['size']));
    final before = formOf(base);
    final changed = _t(form['type']) != before['type'] ||
        _t(form['size']) != before['size'];
    // La línea se recompone solo si el bloque no tenía o si la persona tocó
    // tipo o tamaño. Flutter la pisa siempre: borra «(mago), neutral» del
    // Archimago y manda los enjambres a Monstruosidad. Acá lo que no se tocó
    // queda como lo escribió el libro.
    final compose = t != null && s != null && (base.kind.isEmpty || changed);

    final abilities = _map(form['abilities']);
    final hitDice = _t(form['hitDice']);
    return Creature(
      id: base.id,
      name: _t(form['name']),
      source: ContentSource.homebrew,
      kind: compose
          ? '${t.labelEs} ${t.feminine ? s.feminineLabelEs : s.labelEs}'
          : base.kind,
      type: compose ? t : base.type,
      size: compose ? s : base.size,
      ac: _t(form['ac']),
      hp: _t(form['hp']),
      hitDice: hitDice.isEmpty ? null : hitDice,
      speed: _t(form['speed']),
      abilityScores: {
        for (final a in Ability.values)
          a: int.tryParse(_t(abilities[a.code.toLowerCase()])) ?? 10,
      },
      // El formulario no las edita: se conservan, o editar un bloque importado
      // le vaciaría las competencias.
      savingThrows: base.savingThrows,
      skills: base.skills,
      senses: _t(form['senses']),
      languages: _t(form['languages']),
      passivePerception: int.tryParse(_t(form['passive'])),
      legendaryActionsPerRound: int.tryParse(_t(form['legendary'])),
      initiativeBonus: int.tryParse(_t(form['initiative'])),
      defenses: _t(form['defenses']),
      cr: _parseCr(_t(form['cr'])),
      scalesWithSpellLevel: base.scalesWithSpellLevel,
      availableToCharacters: base.availableToCharacters,
      traits: [
        for (final r in _rows(form['traits']))
          CreatureTrait(name: _t(r['name']), description: _t(r['description'])),
      ],
      actions: [for (final r in _rows(form['actions'])) _action(base, r)],
    );
  }

  static CreatureAction _action(Creature base, Map<String, dynamic> r) {
    final bonus = _t(r['attackBonus']);
    final damage = _t(r['damage']);
    final damageType = _t(r['damageType']);
    final from = r['from'];
    final original = from is int && from >= 0 && from < base.actions.length
        ? base.actions[from]
        : null;
    return CreatureAction(
      name: _t(r['name']),
      description: _t(r['description']),
      // Vacío significa «no es un ataque», no «bono cero».
      attackBonus: bonus.isEmpty ? null : bonus,
      damage: damage.isEmpty ? null : damage,
      damageType: damage.isEmpty || damageType.isEmpty ? null : damageType,
      reach: _t(r['reach']),
      kind: CreatureActionKind.fromJson(_t(r['kind'])),
      // La lista de conjuros, la salvación, los PG temporales o recuperados y
      // el área no se editan, y el formulario de Flutter los pierde al
      // guardar: acá viajan con su acción original.
      spellcasting: original?.spellcasting,
      save: original?.save,
      tempHp: original?.tempHp,
      healing: original?.healing,
      area: original?.area ?? false,
    );
  }

  /// Campo → código de error; vacío si se puede guardar. Los códigos son
  /// `required`, `number`, `integer`, `range:a:b`, `cr`, `negative`, `dice` y
  /// `formula`: el cliente los traduce a texto.
  static Map<String, String> errors(Map<String, dynamic> form) {
    final out = <String, String>{};

    void integer(
      String key,
      Object? raw,
      int min,
      int max, {
      required bool optional,
    }) {
      final text = _t(raw);
      if (text.isEmpty) {
        if (!optional) out[key] = 'number';
        return;
      }
      final n = int.tryParse(text);
      if (n == null) {
        out[key] = 'integer';
      } else if (n < min || n > max) {
        out[key] = 'range:$min:$max';
      }
    }

    // Una llave mal cerrada hace que `NpcStats` deje al PNJ con 0 PG sin
    // avisar: la fórmula se evalúa recién al combatir. Se prueba acá con una
    // bolsa vacía, que alcanza para cazar la sintaxis.
    void formula(String key, Object? raw) {
      try {
        resolveCreatureFormula(_t(raw), const CreatureVars({}));
      } on CreatureFormulaException {
        out[key] = 'formula';
      }
    }

    if (_t(form['name']).isEmpty) out['name'] = 'required';
    integer('ac', form['ac'], 1, 40, optional: false);
    integer('hp', form['hp'], 1, 999, optional: false);
    final abilities = _map(form['abilities']);
    for (final a in Ability.values) {
      final k = a.code.toLowerCase();
      integer('abilities.$k', abilities[k], 1, 30, optional: false);
    }
    integer('initiative', form['initiative'], -10, 20, optional: true);
    integer('passive', form['passive'], 1, 40, optional: true);
    integer('legendary', form['legendary'], 1, 10, optional: true);

    final cr = _t(form['cr']);
    if (cr.isNotEmpty) {
      final v = _parseCr(cr);
      if (v == null) {
        out['cr'] = 'cr';
      } else if (v < 0) {
        out['cr'] = 'negative';
      }
    }
    final dice = _t(form['hitDice']);
    if (dice.isNotEmpty && DiceFormula.tryParse(dice) == null) {
      out['hitDice'] = 'dice';
    }
    formula('speed', form['speed']);
    formula('senses', form['senses']);

    final traits = _rows(form['traits']);
    for (var i = 0; i < traits.length; i++) {
      if (_t(traits[i]['name']).isEmpty) out['traits.$i.name'] = 'required';
      formula('traits.$i.description', traits[i]['description']);
    }
    final actions = _rows(form['actions']);
    for (var i = 0; i < actions.length; i++) {
      final r = actions[i];
      if (_t(r['name']).isEmpty) out['actions.$i.name'] = 'required';
      integer(
        'actions.$i.attackBonus',
        r['attackBonus'],
        -10,
        30,
        optional: true,
      );
      formula('actions.$i.description', r['description']);
      formula('actions.$i.damage', r['damage']);
    }
    return out;
  }

  /// El desafío como se lee en el libro: `1/4`, `1/2`, `5`. Se guarda como
  /// número. Denominador 0 es inválido (null), no infinito.
  static num? _parseCr(String text) {
    if (text.isEmpty) return null;
    final fraction = RegExp(r'^(\d+)\s*/\s*(\d+)$').firstMatch(text);
    if (fraction != null) {
      final d = int.parse(fraction[2]!);
      return d == 0 ? null : int.parse(fraction[1]!) / d;
    }
    return num.tryParse(text);
  }
}
