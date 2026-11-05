import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// El borrador de un bloque: lo que el formulario conserva, compone y rechaza.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  Creature armar(Creature base, [void Function(Map<String, dynamic>)? edit]) {
    final form = CreatureDraft.formOf(base);
    edit?.call(form);
    return CreatureDraft.build(base, form);
  }

  test('pasar el Archimago por el formulario sin tocar nada conserva todo', () {
    final base = repo.creature('archmage')!;
    final built = armar(base);
    expect(built.kind, base.kind);
    expect(built.savingThrows, base.savingThrows);
    expect(built.skills, base.skills);
    expect(
      built.actions.map((a) => a.spellcasting?.toJson()),
      base.actions.map((a) => a.spellcasting?.toJson()),
    );
    expect(base.actions.any((a) => a.spellcasting != null), isTrue);
  });

  test('toda criatura del catálogo se puede guardar tal como está', () {
    // Las invocaciones con fórmula (CA «13+WIS», PG «5+5*level») dependen de
    // quien las invoca: el editor las marca para que el DM escriba números,
    // igual que el validador de Flutter.
    final fijas = repo.creaturesSorted.where(
      (c) => int.tryParse(c.ac) != null && int.tryParse(c.hp) != null,
    );
    expect(fijas, isNotEmpty);
    for (final c in fijas) {
      expect(
        CreatureDraft.errors(CreatureDraft.formOf(c)),
        isEmpty,
        reason: c.id,
      );
    }
  });

  test('cambiar el tipo compone la línea con su concordancia', () {
    final base = repo.creature('archmage')!;
    expect(
      armar(base, (f) {
        f['type'] = 'beast';
        f['size'] = 'medium';
      }).kind,
      'Bestia Mediana',
    );
    expect(
      armar(base, (f) {
        f['type'] = 'giant';
        f['size'] = 'large';
      }).kind,
      'Gigante Grande',
    );
  });

  test('un enjambre sin tipo conserva su línea aunque cambie el tamaño', () {
    final swarm =
        repo.creaturesSorted.firstWhere((c) => c.creatureType == null);
    final built = armar(swarm, (f) {
      f['type'] = '';
      f['size'] = 'huge';
    });
    expect(built.kind, swarm.kind);
  });

  test('un bloque vacío arranca como monstruosidad mediana y pide CA y PG', () {
    final empty = Npc.emptyBlock('Rurik');
    final form = CreatureDraft.formOf(empty);
    expect(form['type'], 'monstrosity');
    expect(form['size'], 'medium');
    final errors = CreatureDraft.errors(form);
    expect(errors['ac'], 'range:1:40');
    expect(errors['hp'], 'range:1:999');
    form['ac'] = '12';
    form['hp'] = '10';
    expect(CreatureDraft.errors(form), isEmpty);
    expect(CreatureDraft.build(empty, form).kind, 'Monstruosidad Mediana');
  });

  test('desafío, dados y fórmulas se validan', () {
    final base = repo.creature('archmage')!;
    Map<String, dynamic> con(void Function(Map<String, dynamic>) edit) {
      final f = CreatureDraft.formOf(base);
      edit(f);
      return f;
    }

    expect(armar(base, (f) => f['cr'] = '1/4').cr, 0.25);
    expect(CreatureDraft.errors(con((f) => f['cr'] = 'abc'))['cr'], 'cr');
    expect(
      CreatureDraft.errors(con((f) => f['hitDice'] = 'x'))['hitDice'],
      'dice',
    );
    expect(
      CreatureDraft.errors(
        con((f) => (f['traits'] as List)[0]['description'] = 'abre {'),
      )['traits.0.description'],
      'formula',
    );
  });
}
