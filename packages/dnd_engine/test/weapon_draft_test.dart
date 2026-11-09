import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// El borrador de un arma: las reglas del alcance y lo que se conserva.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  Map<String, dynamic> form() =>
      WeaponDraft.formOf(WeaponDraft.empty())..['name'] = 'Jabalina';

  test('un arma arrojadiza o a distancia sin alcance no se puede guardar', () {
    final f = form()..['properties'] = ['thrown'];
    expect(WeaponDraft.errors(f), containsPair('rangeNormal', 'number'));
    expect(WeaponDraft.errors(f), containsPair('rangeLong', 'number'));
    // Sin esas propiedades el alcance es opcional.
    expect(WeaponDraft.errors(form()), isEmpty);
  });

  test('un alcance largo menor que el normal no se puede guardar', () {
    final f = form()
      ..['properties'] = ['ranged']
      ..['rangeNormal'] = '80'
      ..['rangeLong'] = '40';
    expect(WeaponDraft.errors(f), {'rangeLong': 'rangeLongMin'});
    f['rangeLong'] = '320';
    expect(WeaponDraft.errors(f), isEmpty);
  });

  test('la lanza de caballería conserva «a dos manos salvo montado»', () {
    final lance = repo.weapon('lance')!;
    expect(lance.twoHandedUnlessMounted, isTrue);
    final built = WeaponDraft.build(lance, WeaponDraft.formOf(lance));
    expect(built.twoHandedUnlessMounted, isTrue);
    expect(built.source, ContentSource.homebrew);
  });
}
