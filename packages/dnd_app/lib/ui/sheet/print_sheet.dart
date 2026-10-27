// l10n-ignore-file: marcado HTML y CSS de la hoja impresa; todo texto visible sale de context.l10n.
part of '../sheet_screen.dart';

/// Ficha para imprimir: un documento HTML propio que se le pasa al diálogo de
/// impresión del navegador, que además ofrece «Guardar como PDF».
///
/// No se imprime la pantalla porque Flutter web dibuja en un canvas: el
/// navegador la pagina como una imagen cortada, con los fondos oscuros y sin
/// texto seleccionable. Y no se genera un PDF propio porque costaría una
/// dependencia y fuentes embebidas para lo que el navegador ya hace.
///
/// Es papel para jugar con lápiz: lo que cambia en la mesa (PG actuales,
/// espacios gastados, usos de recursos) sale **en blanco**, con el máximo al
/// lado y casillas para marcar. Los conjuros y rasgos van sin su texto: con
/// las descripciones, un mago de nivel 10 ocupa quince hojas.
extension _SheetPrint on _SheetScreenState {
  void _printSheet() => browser.printHtml(_printableSheet());

  String _printableSheet() {
    final l10n = context.l10n;
    // Se compila de nuevo y no se lee `sheet`: esa lleva encima la Forma
    // Salvaje y el Cansancio, que son estado de la partida. Imprimir
    // transformado en oso dejaría una hoja con la velocidad del oso.
    final s = CharacterCompiler(repo).compile(_c);
    final race = repo.race(_c.raceId)?.name ?? _c.raceId;
    final bg = repo.background(_c.backgroundId)?.name ?? '';

    final out = StringBuffer()
      ..write('<!doctype html><html lang="${l10n.localeName}"><head>')
      ..write('<meta charset="utf-8"><title>${_e(_c.name)}</title>')
      ..write('<style>$_printCss${_pageFooter()}</style></head><body>')
      ..write('<header><h1>${_e(_c.name)}</h1><p>')
      ..write(
        _e(
          [
            race,
            if (bg.isNotEmpty) bg,
            l10n.sheetClassSummary(_classSummary(), _c.totalLevel),
          ].join(' · '),
        ),
      )
      ..write('</p></header>');

    // ---------------------------------------------------------- Hoja 1
    final hitDice = s.hitDiceBySize.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    out
      ..write('<section class="stats">')
      ..write(
        _stat(
          l10n.hitPoints,
          '<i class="blank"></i> / ${s.maxHp}',
          raw: true,
          note: l10n.printCurrentHp,
          wide: true,
        ),
      )
      ..write(_stat(l10n.statArmor, '${s.armorClass}'))
      ..write(_stat(l10n.combatTempHp, '<i class="blank"></i>', raw: true))
      ..write(_stat(l10n.initiative, _signed(s.initiative)))
      ..write(_stat(l10n.creatureSpeed, '${s.speed}${l10n.unitFeetSuffix}'))
      ..write(_stat(l10n.statProficiency, '+${s.proficiencyBonus}'))
      ..write(_stat(l10n.passivePerception, '${s.passivePerception}'))
      ..write('</section>');

    out.write('<div class="cols"><div>');
    // Características y salvaciones en una tabla: es lo que más se compara,
    // y una cifra al lado de la otra se lee mejor que seis recuadros. El
    // modificador va grande porque es lo que se suma a cada tirada; la
    // puntuación casi no se consulta en la mesa.
    out
      ..write('<h2>${_e(l10n.abilitiesTitle)}</h2><table class="abilities">')
      ..write(
        '<tr><th></th><th class="num">${_e(l10n.printHeadModifier)}</th>'
        '<th class="num">${_e(l10n.printHeadScore)}</th><th></th>'
        '<th class="num">${_e(l10n.savesTitle)}</th></tr>',
      );
    for (final a in Ability.values) {
      // La marca de competencia en su propia columna: delante del número
      // corría la cifra y la columna de salvaciones dejaba de alinear.
      final prof = s.savingThrowProficiencies.contains(a);
      out.write(
        '<tr><td>${_e(a.label)}</td>'
        '<td class="num mod">${_signed(s.abilityModifiers[a]!)}</td>'
        '<td class="num muted">${s.abilityScores[a]}</td>'
        '<td>${prof ? '●' : ''}</td>'
        '<td class="num">${_signed(s.savingThrow(a))}</td></tr>',
      );
    }
    out.write('</table>');

    out.write(
      '<h2>${_e(l10n.deathSaves)}</h2>'
      '<p class="marks">✓ ${_boxes(3)}&emsp;✗ ${_boxes(3)}</p>',
    );
    if (hitDice.isNotEmpty) {
      out.write('<h2>${_e(l10n.printHitDice)}</h2>');
      for (final d in hitDice) {
        out.write(
          '<p class="marks">${d.value}d${d.key} ${_boxes(d.value)}</p>',
        );
      }
    }
    if (s.darkvision != null) {
      out.write(
        '<p>${_e(l10n.darkvision)}: '
        '${s.darkvision}${_e(l10n.unitFeetSuffix)}</p>',
      );
    }
    final resistances = [...s.resistances].map(DamageType.labelFor).toList()
      ..sort();
    final immunities = [...s.immunities].map(DamageType.labelFor).toList()
      ..sort();
    if (resistances.isNotEmpty) {
      out.write('<p>${_e(l10n.combatResistances(resistances.join(', ')))}</p>');
    }
    if (immunities.isNotEmpty) {
      out.write('<p>${_e(l10n.combatImmunities(immunities.join(', ')))}</p>');
    }

    out.write('</div><div>');
    // ○ sin competencia, ● competente, ◉ pericia: los mismos tres estados
    // que el punto de la ficha, en algo que se ve igual en blanco y negro.
    out.write('<h2>${_e(l10n.creatureSkills)}</h2><table>');
    // Por el nombre traducido: `Skill.values` sigue el alfabeto inglés, y en
    // papel se busca con el dedo.
    final skills = [...Skill.values]
      ..sort((a, b) => compareContentNames(a.label, b.label));
    for (final skill in skills) {
      final mark = s.expertiseSkills.contains(skill.id)
          ? '◉'
          : s.skillProficiencies.contains(skill.id)
          ? '●'
          : '○';
      out.write(
        '<tr><td>$mark ${_e(skill.label)} '
        '<span class="muted">${_e(skill.ability.abbr)}</span></td>'
        '<td class="num">${_signed(s.skillModifier(skill.id))}</td></tr>',
      );
    }
    out.write('</table></div></div>');

    if (s.attacks.isNotEmpty) {
      out
        ..write('<h2>${_e(l10n.combatAttacks)}</h2><table class="wide">')
        ..write(
          '<tr><th></th><th>${_e(l10n.printHeadBonus)}</th>'
          '<th>${_e(l10n.printHeadDamage)}</th>'
          '<th>${_e(l10n.commonRange)}</th></tr>',
        );
      for (final a in s.attacks) {
        out.write(
          '<tr><td>${_e(a.name)}</td><td class="num">${_signed(a.attackBonus)}</td>'
          '<td>${_e(a.damageText)}</td>'
          '<td>${_e(a.rangeLabel ?? '')}</td></tr>',
        );
      }
      out.write('${_emptyRows(4, 1)}</table>');
    }

    final profs = <String>[
      for (final id in s.armorProficiencies) armorTrainingLabel(id),
      for (final id in s.weaponProficiencies)
        repo.weapon(id)?.name ?? weaponProficiencyLabel(id),
      for (final id in s.toolProficiencies) toolProficiencyLabel(id),
    ]..sort(compareContentNames);
    final languages = [
      for (final id in s.languages)
        if (id != Language.universal.id) Language.labelFor(id),
    ]..sort(compareContentNames);
    out
      ..write('<div class="cols"><div>')
      ..write('<h2>${_e(l10n.proficienciesTitle)}</h2>')
      ..write('<p>${_e(profs.join(', '))}</p></div><div>')
      ..write('<h2>${_e(l10n.creatureLanguages)}</h2>')
      ..write(
        '<p>${_e([Language.labelFor(Language.universal.id), ...languages].join(', '))}</p>',
      )
      ..write('</div></div>');

    // Lo que la ficha en pantalla marca con un toque y en papel no tiene
    // dónde: la Inspiración, el Cansancio, las condiciones y lo que se anota.
    out
      ..write('<div class="cols"><div>')
      ..write('<h2>${_e(l10n.combatState)}</h2>')
      ..write(
        '<p class="marks">${_e(l10n.heroicInspiration)} ${_boxes(1)}&emsp;'
        '${_e(l10n.exhaustion)} ${_boxes(6)}</p>',
      )
      ..write('<p>${_e(l10n.conditionsTitle)}</p>${_lines(1)}</div><div>')
      ..write('<h2>${_e(l10n.printNotes)}</h2>${_lines(3)}</div></div>');

    // ---------------------------------------------------------- Hoja 2
    out.write('<div class="page">');
    if (s.resources.isNotEmpty) {
      out
        ..write('<h2>${_e(l10n.combatResourcesTitle)}</h2><table class="wide">')
        ..write(
          '<tr><th></th><th>${_e(l10n.printHeadUses)}</th>'
          '<th>${_e(l10n.printHeadRecharge)}</th><th></th></tr>',
        );
      for (final r in s.resources) {
        // Una reserva de 20 puntos son 20 casillas que nadie tacha: va con un
        // hueco para anotar lo que queda, como los PG.
        final uses = r.pool || r.max > 10
            ? '<i class="blank"></i> / ${r.max}'
            : _boxes(r.max);
        out.write(
          '<tr><td>${_e(r.name)}</td><td class="marks">$uses</td>'
          '<td>${_e(_rechargeLabel(r.recharge))}</td><td>${_e([if (r.saveDc case final dc?) r.saveAbility == null ? l10n.saveDc(dc) : l10n.saveDcAbility(dc, r.saveAbility!.abbr), ?r.damage].join(' · '))}</td></tr>',
        );
      }
      out.write('</table>');
    }

    if (s.passives.isNotEmpty) {
      out
        ..write('<h2>${_e(l10n.traitsAndFeatsTitle)}</h2><ul class="list">')
        ..writeAll([for (final p in s.passives) '<li>${_e(p.name)}</li>'])
        ..write('</ul>');
    }

    // La tabla sale aunque no haya nada: los renglones vacíos son para lo que
    // se consiga jugando.
    out
      ..write('<h2>${_e(l10n.invTitle)}</h2>')
      ..write(
        '<table class="wide"><tr><th>${_e(l10n.invHeadQty)}</th>'
        '<th>${_e(l10n.invHeadItem)}</th>'
        '<th>${_e(l10n.invHeadEquipped)}</th>'
        '<th class="num">${_e(l10n.invHeadWeight)}</th></tr>',
      );
    for (final e in _c.inventory) {
      final item = InventoryOps.resolve(e, repo);
      final weight = item.weight * e.quantity;
      out.write(
        '<tr><td class="num">${e.quantity}</td><td>${_e(item.name)}</td>'
        '<td>${InventoryOps.isEquipped(_c, e, repo) ? '●' : ''}</td>'
        '<td class="num">${weight == 0 ? '' : '${formatPounds(weight)} lb'}</td></tr>',
      );
    }
    out.write('${_emptyRows(4, 6)}</table>');
    // Las monedas y la carga cambian en cada sesión: van en blanco, como los
    // PG, y no con lo que había el día que se imprimió.
    out
      ..write('<p class="coins">')
      ..writeAll([
        for (final k in coinDenominations)
          '<span>${_e(coinAbbr(l10n, k))} <i class="blank"></i></span>',
      ])
      ..write('</p><p>${_e(l10n.invLoad)} <i class="blank"></i> / ')
      ..write('${s.carryingCapacity} lb</p>')
      ..write('</div>');

    // ---------------------------------------------------------- Hoja 3
    final sc = s.spellcasting;
    if (sc != null || s.innateSpells.isNotEmpty) {
      out.write('<div class="page"><h2>${_e(l10n.spellsTitle)}</h2>');
      if (sc != null) {
        // Con multiclase cada clase lanza con su característica: una línea
        // por bloque, como en Fuentes de la pestaña Conjuros.
        final blocks = s.spellcastingBlocks.length > 1
            ? [
                for (final b in s.spellcastingBlocks)
                  (
                    '${repo.characterClass(b.classId)?.name ?? b.classId}: ',
                    b.spellcasting,
                  ),
              ]
            : [('', sc)];
        for (final (prefix, block) in blocks) {
          out.write(
            '<p>${_e(prefix)}${_e(l10n.equipCasterLine(block.saveDc, _signed(block.attackBonus), block.ability.abbr))}</p>',
          );
        }
        final slotLevels = sc.progression == CasterProgression.pact
            ? <int>[]
            : (sc.slotsByLevel.keys.toList()..sort());
        if (slotLevels.isNotEmpty) {
          out.write('<h3>${_e(l10n.spellsSlots)}</h3>');
          for (final lv in slotLevels) {
            out.write(
              '<p class="marks">${_e(l10n.spellLevel(lv))} '
              '${_dots(sc.slotsByLevel[lv]!)}</p>',
            );
          }
        }
        for (final block in s.spellcastingBlocks.where(
          (b) => b.spellcasting.progression == CasterProgression.pact,
        )) {
          out.write('<h3>${_e(l10n.spellsPactSlots)}</h3>');
          for (final lv in block.spellcasting.slotsByLevel.keys) {
            out.write(
              '<p class="marks">${_e(l10n.spellLevel(lv))} '
              '${_dots(block.spellcasting.slotsByLevel[lv]!)}</p>',
            );
          }
        }

        // Los mismos conjuntos que la pestaña Conjuros, para que el papel no
        // diga otra cosa que la pantalla.
        List<Spell> spellsOf(Iterable<String> ids) =>
            ids.map(repo.spell).whereType<Spell>().toList()..sort(
              (a, b) => a.level != b.level
                  ? a.level.compareTo(b.level)
                  : compareContentNames(a.name, b.name),
            );
        _spellTable(
          out,
          l10n.spellsCantripsTitle,
          spellsOf({
            ..._c.cantripIds,
            for (final ids in _c.classCantripIds.values) ...ids,
          }),
        );
        _spellTable(
          out,
          l10n.spellsAlwaysPrepared,
          spellsOf(s.alwaysPreparedSpellIds),
        );
        // Quien prepara cambia la lista entre descansos: una casilla por
        // conjuro para marcar los de hoy sin reimprimir.
        final prepares = sc.preparation == SpellPreparation.prepared;
        _spellTable(
          out,
          prepares ? l10n.spellsPreparedTitle : l10n.spellsKnownTitle,
          spellsOf({
            ..._c.spellIds,
            for (final ids in _c.classSpellIds.values) ...ids,
          }),
          checkable: prepares,
        );
      }
      if (s.innateSpells.isNotEmpty) {
        out.write(
          '<h3>${_e(l10n.spellsFromFeatures)}</h3><table class="wide">',
        );
        for (final i in s.innateSpells) {
          out.write(
            '<tr><td>${_e(i.name)}</td><td>${_e(_innateUse(i))}</td>'
            '<td>${_e(l10n.saveDc(i.saveDc))} · '
            '${_e(l10n.creatureSpellAttack(_signed(i.attackBonus)))}</td></tr>',
          );
        }
        out.write('</table>');
      }
      out.write('</div>');
    }

    out.write('</body></html>');
    return out.toString();
  }

  void _spellTable(
    StringBuffer out,
    String title,
    List<Spell> spells, {
    bool checkable = false,
  }) {
    if (spells.isEmpty) return;
    final l10n = context.l10n;
    final check = checkable ? '<th></th>' : '';
    out
      ..write('<h3>${_e(title)}</h3><table class="wide spells">')
      ..write(
        '<tr>$check<th></th><th></th><th>${_e(l10n.spellCastingTime)}</th>'
        '<th>${_e(l10n.commonRange)}</th><th>${_e(l10n.spellComponents)}</th>'
        '<th>${_e(l10n.spellDuration)}</th></tr>',
      );
    for (final sp in spells) {
      // (C) y (R), como el «(R)» de la pestaña Conjuros: entran en la celda
      // del nombre y se leen sin leyenda.
      final flags = [
        if (sp.concentration) ' (C)',
        if (sp.ritual) ' (R)',
      ].join();
      out.write(
        '<tr>${checkable ? '<td class="check">${_boxes(1)}</td>' : ''}'
        '<td class="name">${_e(sp.name)}$flags</td>'
        '<td>${_e(sp.isCantrip ? l10n.spellCantrip : l10n.spellLevel(sp.level))}</td>'
        '<td>${_e(vocabularyLabel(VocabularyField.castingTime, sp.castingTime))}</td>'
        '<td>${_e(vocabularyLabel(VocabularyField.range, sp.range))}</td>'
        '<td>${_e(sp.components)}</td>'
        '<td>${_e(vocabularyLabel(VocabularyField.duration, sp.duration))}</td></tr>',
      );
    }
    out.write('</table>');
  }

  String _innateUse(InnateSpell i) => switch (i.use) {
    InnateSpellUse.atWill => context.l10n.creatureAtWill,
    InnateSpellUse.oncePerLongRest => context.l10n.spellsUseLongRest,
    InnateSpellUse.oncePerShortRest => context.l10n.spellsUseShortRest,
    InnateSpellUse.proficiencyBonusPerLongRest =>
      context.l10n.spellsUseProficiency,
    InnateSpellUse.abilityModifierPerLongRest =>
      context.l10n.spellsUseAbilityMod(i.freeUses, i.ability.abbr),
  };

  String _rechargeLabel(RechargeOn r) => switch (r) {
    RechargeOn.shortRest => context.l10n.restShortLower,
    RechargeOn.longRest => context.l10n.restLongLower,
    RechargeOn.none => '',
  };

  String _stat(
    String label,
    String value, {
    bool raw = false,
    String? note,
    bool wide = false,
  }) =>
      '<div class="stat${wide ? ' wide' : ''}"><span>${_e(label)}</span>'
      '<b>${raw ? value : _e(value)}</b>'
      '${note == null ? '' : '<small>${_e(note)}</small>'}</div>';

  /// Nombre y «Hoja N de M» al pie de cada hoja, en el margen que dibuja el
  /// navegador (Chrome 131+; el que no lo soporta imprime sin pie). Las hojas
  /// salen de la paginación del navegador y no se pueden contar acá.
  String _pageFooter() {
    final page = context.l10n.printPageOf('\u0000', '\u0001');
    final counters = _cssString(page)
        .replaceFirst('\u0000', '" counter(page) "')
        .replaceFirst('\u0001', '" counter(pages) "');
    return '@page { @bottom-left { content: "${_cssString(_c.name)}"; } '
        '@bottom-right { content: "$counters"; } }';
  }
}

/// Cadena CSS entre comillas dobles. `<` se escapa porque la regla va dentro
/// de un `<style>`, y un nombre con `</style>` cerraría el bloque.
String _cssString(String v) => v
    .replaceAll(r'\', r'\\')
    .replaceAll('"', r'\"')
    .replaceAll('<', r'\3C ')
    .replaceAll('\n', r'\A ');

/// Modo `element`: todo lo que se escapa va como texto de un elemento, y el
/// modo por defecto convertía cada «/» de «actuales / máx.» en `&#47;`.
String _e(String v) => const HtmlEscape(HtmlEscapeMode.element).convert(v);

String _boxes(int n) => '<i class="box"></i>' * n;

String _dots(int n) => '<i class="dot"></i>' * n;

String _lines(int n) => '<div class="lines">${'<i></i>' * n}</div>';

String _emptyRows(int cols, int n) =>
    '<tr class="empty">${'<td></td>' * cols}</tr>' * n;

/// Blanco y negro a propósito: casi nadie imprime en color, y la paleta de la
/// app pensada para pantalla sale gris sobre gris en una láser.
const _printCss = '''
@page { margin: 20mm 14mm; }
@page { @bottom-left, @bottom-right { font: 8pt system-ui, sans-serif; color: #555; } }
* { box-sizing: border-box; }
body { font: 10pt/1.35 system-ui, sans-serif; color: #000; margin: 0; }
h1, h2, h3 { font-family: Georgia, serif; font-weight: normal; margin: 0; }
h1 { font-size: 20pt; }
h2 { font-size: 12pt; border-bottom: 1px solid #000; margin: 9px 0 3px; }
h3 { font-size: 10.5pt; margin: 10px 0 3px; }
header p { margin: 2px 0 8px; }
p { margin: 3px 0; }
table { border-collapse: collapse; width: 100%; }
td, th { padding: 2px 4px; text-align: left; vertical-align: top; }
th { font-size: 8pt; text-transform: uppercase; font-weight: 600; }
tr { break-inside: avoid; }
table.wide tr + tr td { border-top: 1px solid #ccc; }
.num { text-align: right; font-variant-numeric: tabular-nums; white-space: nowrap; }
.muted { font-size: 8pt; color: #555; }
.abilities td { vertical-align: middle; }
.mod { font: 15pt Georgia, serif; }
/* Columnas fijas para que las cajas no queden de anchos distintos; los PG
   ocupan dos porque son lo que más se reescribe. */
.stats { display: grid; grid-template-columns: repeat(8, minmax(0, 1fr)); gap: 6px; }
.stat { border: 1px solid #000; border-radius: 6px; padding: 4px 5px; text-align: center; }
.stat.wide { grid-column: span 2; }
.stat span, .stat small { display: block; font-size: 8pt; line-height: 1.2; }
.stat b { display: block; font-size: 15pt; font-family: Georgia, serif; font-weight: normal; }
.stat .blank { width: 13mm; }
.stat.wide .blank { width: 24mm; }
.cols { display: grid; grid-template-columns: 1fr 1fr; gap: 0 16px; }
.marks { white-space: nowrap; }
.box, .dot { display: inline-block; width: 10px; height: 10px; border: 1px solid #000; margin-right: 3px; vertical-align: -1px; }
.dot { border-radius: 50%; }
/* 20 mm: lo justo para un número tachado y el nuevo al lado. */
.blank { display: inline-block; width: 20mm; border-bottom: 1px solid #000; height: 1em; }
tr.empty td { height: 15pt; }
.lines i { display: block; height: 16pt; border-bottom: 1px solid #888; }
.coins { display: flex; flex-wrap: wrap; gap: 4px 16px; }
.list { columns: 2; margin: 0; padding-left: 16px; }
.page { break-before: page; }
.spells td.name { font-weight: 600; }
.spells td.check { width: 14px; padding-right: 0; }
''';
