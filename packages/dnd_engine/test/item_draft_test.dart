import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// El borrador de un objeto: que separar y juntar los efectos no pierda nada, y
/// las dos reglas que antes vivían en el widget de Flutter.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  List<Map<String, dynamic>> effectsOf(Item i) => [
        for (final e in i.effects) e.toJson(),
      ];

  test('separar los efectos en el formulario y juntarlos no pierde ninguno',
      () {
    // CA + salvaciones (un efecto «otro») y una resistencia: entre los dos
    // cubren las tres partes.
    for (final id in ['capa-de-proteccion', 'anillo-de-calidez']) {
      final item = repo.item(id)!;
      final rebuilt = ItemDraft.build(item, ItemDraft.formOf(item));
      expect(effectsOf(rebuilt), effectsOf(item), reason: id);
    }
    final cape = ItemDraft.formOf(repo.item('capa-de-proteccion')!);
    expect(cape['acBonus'], isNot('0'));
    expect(cape['otherEffects'], isNotEmpty);
  });

  test('un objeto con cargas las conserva al editarlo', () {
    final charged = repo.items.values.firstWhere((i) => i.maxCharges != null);
    final form = ItemDraft.formOf(charged);
    expect(form['hasCharges'], isTrue);
    final rebuilt = ItemDraft.build(charged, form);
    expect(rebuilt.maxCharges, charged.maxCharges);
    expect(rebuilt.rechargeAmount, charged.rechargeAmount);
  });

  test('sin rareza no hay sintonización, ni armando el objeto', () {
    final cape = repo.item('capa-de-proteccion')!;
    final form = {...ItemDraft.formOf(cape), 'requiresAttunement': true};
    expect(ItemDraft.withRarity(form, '')['requiresAttunement'], isFalse);
    expect(ItemDraft.withRarity(form, 'rare')['requiresAttunement'], isTrue);
    // La defensa: un formulario que no pasó por withRarity.
    final mundane = ItemDraft.build(cape, {...form, 'rarity': ''});
    expect(mundane.rarity, isNull);
    expect(mundane.requiresAttunement, isFalse);
  });

  test('cambiar la familia del objeto base vacía las bases marcadas', () {
    final form = {
      ...ItemDraft.formOf(ItemDraft.empty()),
      'baseItemKind': 'weapon',
      'eligibleBaseItemIds': ['espada-larga'],
    };
    final shield = ItemDraft.withBaseKind(form, 'shield');
    expect(shield['baseItemKind'], 'shield');
    expect(shield['eligibleBaseItemIds'], isEmpty);
    expect(
      [for (final o in ItemDraft.baseOptions('shield', repo)) o.id],
      [
        for (final a in repo.armorSorted)
          if (a.isShield) a.id
      ],
    );
  });
}
