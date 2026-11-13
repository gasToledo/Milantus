import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// El borrador de un conjuro: que separar y juntar los componentes no cambie la
/// línea que trae el catálogo, y que M sea lo que decide si hay material.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  Spell withMaterial() =>
      repo.spells.values.firstWhere((s) => s.components.contains('('));

  test('separar los componentes en el formulario y juntarlos los deja igual',
      () {
    final spell = withMaterial();
    final form = SpellDraft.formOf(spell);
    expect(form['components'], contains('M'));
    expect(form['material'], isNotEmpty);
    expect(SpellDraft.build(spell, form).components, spell.components);
  });

  test('la mejora de nivel superior hace ida y vuelta, y vacía no se guarda',
      () {
    final spell = repo.spell('guiding-bolt')!;
    expect(spell.higherLevel, isNotEmpty);
    final form = SpellDraft.formOf(spell);
    expect(form['higherLevel'], spell.higherLevel);
    expect(SpellDraft.build(spell, form).higherLevel, spell.higherLevel);
    form['higherLevel'] = '  ';
    final built = SpellDraft.build(spell, form);
    expect(built.higherLevel, isEmpty);
    expect(built.toJson(), isNot(contains('higherLevel')));
  });

  test('sin M marcada el material no queda en la línea', () {
    final spell = withMaterial();
    final form = SpellDraft.formOf(spell);
    form['components'] = [
      for (final c in form['components'] as List)
        if (c != 'M') c,
    ];
    final built = SpellDraft.build(spell, form).components;
    expect(built, isNot(contains('M')));
    expect(built, isNot(contains('(')));
  });
}
