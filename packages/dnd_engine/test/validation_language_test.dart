import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Un Guerrero de nivel 3 sin subclase: dispara `subclass_pending`.
final _guerrero = Character(
  id: 'probe',
  name: 'Prueba',
  raceId: 'human',
  classId: 'fighter',
  backgroundId: 'soldier',
  level: 3,
  hpPerLevel: [10, 6, 6],
  assignedScores: {
    Ability.strength: 15,
    Ability.dexterity: 14,
    Ability.constitution: 14,
    Ability.intelligence: 12,
    Ability.wisdom: 10,
    Ability.charisma: 8,
  },
);

void main() {
  late ContentRepository es;
  late ContentRepository en;

  setUpAll(() async {
    es = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    en = await ContentRepository.loadFromDirectory(
      'lib/assets/srd_2024',
      translation: 'en',
    );
  });

  tearDown(() => ContentLanguage.current = ContentLanguage.es);

  ValidationWarning pendiente(ContentRepository repo) => CharacterValidator(
        repo,
      ).validate(_guerrero).firstWhere((w) => w.code == 'subclass_pending');

  test('el aviso sigue al idioma, con el nombre del catálogo traducido', () {
    final enEspanol = pendiente(es);
    expect(enEspanol.message, contains(es.characterClass('fighter')!.name));
    expect(enEspanol.message, contains('subclase'));

    ContentLanguage.current = ContentLanguage.en;
    final enIngles = pendiente(en);
    expect(enIngles.message, contains(en.characterClass('fighter')!.name));
    expect(enIngles.message, contains('subclass'));
    // El código no cambia con el idioma: la app resuelve por código.
    expect(enIngles.code, enEspanol.code);
  });

  test('los mismos avisos salen en los dos idiomas', () {
    final codigosEs =
        CharacterValidator(es).validate(_guerrero).map((w) => w.code).toList();
    ContentLanguage.current = ContentLanguage.en;
    final codigosEn =
        CharacterValidator(en).validate(_guerrero).map((w) => w.code).toList();
    expect(codigosEn, codigosEs);
  });
}
