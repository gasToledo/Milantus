import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// El editor de efectos del motor: lo que ofrece, lo que arma y cómo lo nombra.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  test(
      'con sus valores iniciales cada tipo arma un efecto que sobrevive al '
      'viaje por JSON, salvo el rasgo pasivo, que pide nombre', () {
    final kinds = EffectDraft.kinds(repo);
    expect(kinds.length, EffectKind.values.length);
    for (final kind in EffectKind.values) {
      final entry = kinds.firstWhere((k) => k['id'] == kind.id);
      final values = {
        for (final f in entry['fields'] as List)
          (f as Map)['id'] as String: f['default'],
      };
      if (kind == EffectKind.passive) {
        expect(
          () => EffectDraft.build(kind, values),
          throwsA(isA<EffectFieldError>()),
        );
        continue;
      }
      final built = EffectDraft.build(kind, values);
      final again = Effect.fromJson(built.toJson());
      expect(again.toJson(), built.toJson(), reason: kind.id);
    }
  });

  test('un rasgo pasivo sin nombre falla en el campo del nombre', () {
    expect(
      () => EffectDraft.build(EffectKind.passive, {
        'traitName': '  ',
        'traitDescription': 'algo',
      }),
      throwsA(
        isA<EffectFieldError>().having((e) => e.field, 'field', 'traitName'),
      ),
    );
  });

  test('«a elección» deja la dote concedida en null', () {
    final built =
        EffectDraft.build(EffectKind.grantFeat, {'feat': anyFeatChoice})
            as GrantFeatEffect;
    expect(built.featId, isNull);
  });

  test('un conjuro que ya no existe se nombra por su id', () {
    final parts = effectParts(
      const AlwaysPreparedSpellEffect(spellId: 'conjuro-borrado'),
      repo,
    );
    expect(parts?['name'], 'conjuro-borrado');
  });
}
