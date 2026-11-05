import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Velocidades además de caminar y sentidos además de la visión en la
/// oscuridad (SRD 5.2.1 y PHB 2024).
void main() {
  late ContentRepository repo;
  late CharacterCompiler compiler;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    compiler = CharacterCompiler(repo);
  });

  ComputedSheet ficha(
    String classId,
    int level, {
    String raceId = 'human',
    String? subclassId,
    int strength = 12,
    List<InventoryEntry> inventory = const [],
  }) =>
      compiler.compile(Character(
        id: 'p',
        name: 'Prueba',
        raceId: raceId,
        classId: classId,
        subclassId: subclassId,
        backgroundId: 'soldier',
        level: level,
        assignedScores: {
          for (final a in Ability.values)
            a: a == Ability.strength ? strength : 12,
        },
        hpPerLevel: List.filled(level, 6),
        inventory: inventory,
      ));

  test('la armadura resta 10 pies solo si está puesta y falta Fuerza', () {
    final base = ficha('fighter', 1).speed;
    for (final armor in repo.armor.values.where(
      (a) => a.strengthRequirement != null,
    )) {
      final required = armor.strengthRequirement!;
      for (final equipped in [false, true]) {
        for (final strength in [required - 1, required, required + 1]) {
          final sheet = ficha('fighter', 1, strength: strength, inventory: [
            InventoryEntry(
                entryId: 'armadura', itemId: armor.id, equipped: equipped),
          ]);
          expect(sheet.speed, base - (equipped && strength < required ? 10 : 0),
              reason: '${armor.id}, FUE $strength, equipada $equipped');
        }
      }
    }
    expect(
        ficha('fighter', 1, strength: 8, inventory: const [
          InventoryEntry(entryId: 'cuero', itemId: 'leather', equipped: true),
        ]).speed,
        base);
  });

  test('las velocidades iguales a caminar reciben la penalización de armadura',
      () {
    const inventory = [
      InventoryEntry(entryId: 'placas', itemId: 'plate', equipped: true),
    ];
    final base = ficha('ranger', 6, strength: 15, inventory: inventory);
    final armored = ficha('ranger', 6, inventory: inventory);
    expect(armored.speed, base.speed - 10);
    expect(armored.speeds[MovementMode.climb], armored.speed);
    expect(armored.speeds[MovementMode.swim], armored.speed);
  });

  test('la armadura mágica usa el requisito de su base y no baja de cero', () {
    repo.races['lenta'] = const Race(
        id: 'lenta', name: 'Prueba', source: ContentSource.homebrew, speed: 5);
    repo.items['armadura-prueba'] = const Item(
      id: 'armadura-prueba',
      name: 'Armadura de prueba +1',
      source: ContentSource.homebrew,
      category: 'magic',
      magicBonus: 1,
      baseItemKind: 'armor',
      eligibleBaseItemIds: ['plate'],
    );
    addTearDown(() {
      repo.races.remove('lenta');
      repo.items.remove('armadura-prueba');
    });
    const inventory = [
      InventoryEntry(
          entryId: 'magica',
          itemId: 'armadura-prueba',
          baseItemId: 'plate',
          equipped: true),
    ];
    expect(ficha('fighter', 1, inventory: inventory).speed,
        ficha('fighter', 1, strength: 15, inventory: inventory).speed - 10);
    expect(ficha('fighter', 1, raceId: 'lenta', inventory: inventory).speed, 0);
  });

  test('«igual a tu velocidad» se resuelve con la velocidad final', () {
    // Errante suma 10 a caminar y da trepar y nado iguales: 40, no 30.
    final explorador = ficha('ranger', 6);
    expect(explorador.speed, 40);
    expect(explorador.speeds[MovementMode.climb], 40);
    expect(explorador.speeds[MovementMode.swim], 40);
    // El Cansancio resta a todas, no solo a caminar.
    final cansado = applyExhaustion(explorador, 2);
    expect(cansado.speeds[MovementMode.climb], 30);

    expect(ficha('ranger', 18).senses[Sense.blindsight], 30);
  });

  test('la visión en la oscuridad que se suma no depende de la especie', () {
    // Vista Umbral: 60 a quien no tenía; +60 a quien ya tenía.
    expect(ficha('ranger', 3, subclassId: 'gloom-stalker').darkvision, 60);
    final base = ficha('ranger', 3, raceId: 'dwarf').darkvision!;
    final enano =
        ficha('ranger', 3, raceId: 'dwarf', subclassId: 'gloom-stalker');
    expect(enano.darkvision, base + 60);
  });

  test('la telepatía del Kalashtar crece con el nivel', () {
    expect(
        ficha('fighter', 3, raceId: 'kalashtar').senses[Sense.telepathy], 30);
  });

  test('la Forma Salvaje toma las velocidades y sentidos de la bestia', () {
    final trepadora = repo.creatures.values.firstWhere(
        (c) => c.isBeast && c.otherSpeeds.containsKey(MovementMode.climb));
    final druida = ficha('druid', 2);
    final bestia = applyWildShape(druida, trepadora);
    expect(bestia.speeds, trepadora.otherSpeeds);
    expect(bestia.senses, trepadora.otherSenses);
  });
}
