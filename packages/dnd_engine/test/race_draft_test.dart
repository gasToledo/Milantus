import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// El borrador de una especie: lo que el formulario conserva y lo que rechaza.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  test('con un solo tamaño marcado no hay elección: sizeOptions queda vacío',
      () {
    final form = RaceDraft.formOf(RaceDraft.empty());
    form['sizeOptions'] = ['Mediano'];
    expect(RaceDraft.build(RaceDraft.empty(), form).sizeOptions, isEmpty);
    // Con dos o más se guardan en el orden Pequeño, Mediano, Grande.
    form['sizeOptions'] = ['Grande', 'Pequeño'];
    expect(
      RaceDraft.build(RaceDraft.empty(), form).sizeOptions,
      ['Pequeño', 'Grande'],
    );
  });

  test('una especie del catálogo conserva su emblema y sus efectos raros', () {
    final base = repo.racesSorted.firstWhere(
      (r) =>
          r.iconId != null &&
          r.effects.any((e) => effectParts(e, repo) == null),
    );
    final built = RaceDraft.build(base, RaceDraft.formOf(base));
    expect(built.source, ContentSource.homebrew);
    expect(built.iconId, base.iconId);
    expect(
      built.effects.map((e) => e.toJson()),
      base.effects.map((e) => e.toJson()),
    );
  });

  test('la velocidad fuera de 0–120 y el nombre vacío no se pueden guardar',
      () {
    final form = RaceDraft.formOf(RaceDraft.empty());
    expect(RaceDraft.errors(form), {'name': 'required'});
    form['name'] = 'Orco de las cumbres';
    form['speed'] = '121';
    expect(RaceDraft.errors(form), {'speed': 'range:0:120'});
    form['speed'] = '30';
    form['skillChoiceCount'] = '19';
    expect(RaceDraft.errors(form), {'skillChoiceCount': 'range:0:18'});
    form['skillChoiceCount'] = '2';
    expect(RaceDraft.errors(form), isEmpty);
  });
}
