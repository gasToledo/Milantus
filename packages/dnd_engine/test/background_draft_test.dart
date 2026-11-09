import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// El borrador de un trasfondo: lo que el formulario conserva y lo que rechaza.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  test('un trasfondo del catálogo conserva su equipo inicial y su emblema', () {
    final base = repo.backgroundsSorted.firstWhere(
      (b) => b.startingEquipment.isNotEmpty && b.iconId != null,
    );
    final form = BackgroundDraft.formOf(base);
    expect(form['hasStartingEquipment'], isTrue);
    final built = BackgroundDraft.build(base, form);
    expect(built.source, ContentSource.homebrew);
    expect(
      built.startingEquipment.map((e) => e.toJson()),
      base.startingEquipment.map((e) => e.toJson()),
    );
    expect(built.iconId, base.iconId);
  });

  test('con dos características no se puede guardar', () {
    final form = BackgroundDraft.formOf(BackgroundDraft.empty());
    form['name'] = 'Contrabandista';
    expect(BackgroundDraft.errors(form), {'abilityOptions': 'three'});
    form['abilityOptions'] = ['dexterity', 'constitution'];
    expect(BackgroundDraft.errors(form), {'abilityOptions': 'three'});
    form['abilityOptions'] = ['intelligence', 'dexterity', 'constitution'];
    expect(BackgroundDraft.errors(form), isEmpty);
    // Salen en el orden de `Ability.values`, no en el que se marcaron.
    expect(
      BackgroundDraft.build(BackgroundDraft.empty(), form).abilityOptions,
      [Ability.dexterity, Ability.constitution, Ability.intelligence],
    );
  });

  test('una dote de origen vacía queda en null', () {
    final form = BackgroundDraft.formOf(BackgroundDraft.empty());
    expect(form['originFeatId'], '');
    expect(
      BackgroundDraft.build(BackgroundDraft.empty(), form).originFeatId,
      isNull,
    );
  });
}
