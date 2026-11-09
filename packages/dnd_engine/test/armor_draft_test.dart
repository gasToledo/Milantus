import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// El borrador de una armadura: qué hace la categoría con la Destreza.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  test('elegir la categoría repone lo que suma la Destreza', () {
    final form = ArmorDraft.formOf(ArmorDraft.empty());
    final medium = ArmorDraft.withCategory(form, 'medium');
    expect(medium['addDexMod'], isTrue);
    expect(medium['maxDexBonus'], '2');
    final heavy = ArmorDraft.withCategory(medium, 'heavy');
    expect(heavy['addDexMod'], isFalse);
    expect(heavy['maxDexBonus'], '');
    // El escudo no toca la Destreza que traía.
    final shield = ArmorDraft.withCategory(medium, 'shield');
    expect(shield['addDexMod'], medium['addDexMod']);
    expect(shield['maxDexBonus'], medium['maxDexBonus']);
  });

  test('la CA de ejemplo respeta el tope y un escudo no la muestra', () {
    final medium = repo.armor.values.firstWhere(
      (a) => a.category == 'medium' && a.maxDexBonus == 2,
    );
    expect(ArmorDraft.acExamples(medium), [
      (dex: 3, ac: medium.baseAc + 2),
      (dex: 1, ac: medium.baseAc + 1),
    ]);
    final shield = repo.armor.values.firstWhere((a) => a.isShield);
    expect(ArmorDraft.acExamples(shield), isEmpty);
  });
}
