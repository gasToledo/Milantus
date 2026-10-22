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
      ..write('<style>$_printCss</style></head><body>')
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
      ..write(_stat(l10n.statArmor, '${s.armorClass}'))
      ..write(
        _stat(
          l10n.hitPoints,
          '<i class="blank"></i> / ${s.maxHp}',
          raw: true,
          note: l10n.printCurrentHp,
        ),
      )
      ..write(_stat(l10n.combatTempHp, '<i class="blank"></i>', raw: true))
      ..write(_stat(l10n.initiative, _signed(s.initiative)))
      ..write(_stat(l10n.creatureSpeed, '${s.speed}${l10n.unitFeetSuffix}'))
      ..write(_stat(l10n.statProficiency, '+${s.proficiencyBonus}'))
      ..write(_stat(l10n.passivePerception, '${s.passivePerception}'))
      ..write('</section>');

    out.write('<div class="cols"><div>');
    // Características y salvaciones en una tabla: es lo que más se compara,
    // y una cifra al lado de la otra se lee mejor que seis recuadros.
    out
      ..write('<h2>${_e(l10n.abilitiesTitle)}</h2><table>')
      ..write(
        '<tr><th></th><th></th><th></th>'
        '<th>${_e(l10n.savesTitle)}</th></tr>',
      );
    for (final a in Ability.values) {
      final prof = s.savingThrowProficiencies.contains(a);
      out.write(
        '<tr><td>${_e(a.label)}</td><td class="num">${s.abilityScores[a]}</td>'
        '<td class="num strong">${_signed(s.abilityModifiers[a]!)}</td>'
        '<td class="num">${prof ? '● ' : ''}${_signed(s.savingThrow(a))}</td>'
        '</tr>',
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
    for (final skill in Skill.values) {
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
          '<td>${_e(repo.weapon(a.baseWeaponId)?.rangeLabel ?? '')}</td></tr>',
        );
      }
      out.write('</table>');
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
      ..write('<h2>${_e(l10n.proficienciesTitle)}</h2>')
      ..write('<p>${_e(profs.join(', '))}</p>')
      ..write('<h2>${_e(l10n.creatureLanguages)}</h2>')
      ..write(
        '<p>${_e([Language.labelFor(Language.universal.id), ...languages].join(', '))}</p>',
      );

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

    out.write('<h2>${_e(l10n.invTitle)}</h2>');
    if (_c.inventory.isNotEmpty) {
      out.write(
        '<table class="wide"><tr><th>${_e(l10n.invHeadQty)}</th>'
        '<th>${_e(l10n.invHeadItem)}</th>'
        '<th>${_e(l10n.invHeadEquipped)}</th>'
        '<th>${_e(l10n.invHeadWeight)}</th></tr>',
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
      out.write('</table>');
    }
    // Solo las denominaciones que hay: cinco ceros seguidos no dicen nada.
    final coins = [
      for (final k in coinDenominations)
        if ((_c.coins[k] ?? 0) > 0) '${_c.coins[k]} ${coinAbbr(l10n, k)}',
    ];
    out
      ..write('<p>')
      ..write(coins.isEmpty ? '' : '${_e(coins.join(' · '))} — ')
      ..write('${_e(l10n.invLoad)} ${formatPounds(s.carriedWeight)} / ')
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
        _spellTable(
          out,
          sc.preparation == SpellPreparation.prepared
              ? l10n.spellsPreparedTitle
              : l10n.spellsKnownTitle,
          spellsOf({
            ..._c.spellIds,
            for (final ids in _c.classSpellIds.values) ...ids,
          }),
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

  void _spellTable(StringBuffer out, String title, List<Spell> spells) {
    if (spells.isEmpty) return;
    final l10n = context.l10n;
    out
      ..write('<h3>${_e(title)}</h3><table class="wide spells">')
      ..write(
        '<tr><th></th><th></th><th>${_e(l10n.spellCastingTime)}</th>'
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
        '<tr><td>${_e(sp.name)}$flags</td>'
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

  String _stat(String label, String value, {bool raw = false, String? note}) =>
      '<div class="stat"><span>${_e(label)}</span>'
      '<b>${raw ? value : _e(value)}</b>'
      '${note == null ? '' : '<small>${_e(note)}</small>'}</div>';
}

/// Modo `element`: todo lo que se escapa va como texto de un elemento, y el
/// modo por defecto convertía cada «/» de «actuales / máx.» en `&#47;`.
String _e(String v) => const HtmlEscape(HtmlEscapeMode.element).convert(v);

String _boxes(int n) => '<i class="box"></i>' * n;

String _dots(int n) => '<i class="dot"></i>' * n;

/// Blanco y negro a propósito: casi nadie imprime en color, y la paleta de la
/// app pensada para pantalla sale gris sobre gris en una láser.
const _printCss = '''
@page { margin: 14mm; }
* { box-sizing: border-box; }
body { font: 10pt/1.35 system-ui, sans-serif; color: #000; margin: 0; }
h1, h2, h3 { font-family: Georgia, serif; font-weight: normal; margin: 0; }
h1 { font-size: 20pt; }
h2 { font-size: 12pt; border-bottom: 1px solid #000; margin: 12px 0 4px; }
h3 { font-size: 10.5pt; margin: 10px 0 3px; }
header p { margin: 2px 0 8px; }
p { margin: 3px 0; }
table { border-collapse: collapse; width: 100%; }
td, th { padding: 2px 4px; text-align: left; vertical-align: top; }
th { font-size: 8pt; text-transform: uppercase; font-weight: 600; }
tr { break-inside: avoid; }
table.wide tr + tr td { border-top: 1px solid #ccc; }
.num { text-align: right; font-variant-numeric: tabular-nums; white-space: nowrap; }
.strong { font-weight: 700; }
.muted { font-size: 8pt; color: #555; }
.stats { display: flex; flex-wrap: wrap; gap: 6px; }
.stat { border: 1px solid #000; border-radius: 6px; padding: 4px 8px; min-width: 22mm; text-align: center; }
.stat span, .stat small { display: block; font-size: 7.5pt; text-transform: uppercase; }
.stat b { display: block; font-size: 15pt; font-family: Georgia, serif; font-weight: normal; }
.cols { display: grid; grid-template-columns: 1fr 1fr; gap: 0 16px; }
.marks { white-space: nowrap; }
.box, .dot { display: inline-block; width: 10px; height: 10px; border: 1px solid #000; margin-right: 3px; vertical-align: -1px; }
.dot { border-radius: 50%; }
.blank { display: inline-block; width: 12mm; border-bottom: 1px solid #000; height: 1em; }
.list { columns: 2; margin: 0; padding-left: 16px; }
.page { break-before: page; }
.spells td:first-child { font-weight: 600; }
''';
