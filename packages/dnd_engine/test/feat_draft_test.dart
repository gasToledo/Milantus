import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// El borrador de una dote: lo que el formulario conserva y lo que rechaza.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  Feat armar(Feat base, [void Function(Map<String, dynamic>)? edit]) {
    final form = FeatDraft.formOf(base);
    edit?.call(form);
    return FeatDraft.build(base, form);
  }

  test(
      'una dote del catálogo pasa por el formulario sin perder el requisito '
      'ni el grupo exclusivo', () {
    final base = repo.feat('resilient-wisdom')!;
    expect(base.prerequisite, isNotNull);
    expect(base.exclusiveGroup, isNotNull);
    final built = armar(base);
    expect(built.source, ContentSource.homebrew);
    expect(built.prerequisite?.toJson(), base.prerequisite?.toJson());
    expect(built.exclusiveGroup, base.exclusiveGroup);
    expect(FeatDraft.formOf(base)['hasPrerequisite'], isTrue);
  });

  test('un efecto que el editor no describe viaja intacto', () {
    final base = repo.feat('agonizing-blast')!;
    final raro = base.effects.where((e) => effectParts(e, repo) == null);
    expect(raro, isNotEmpty);
    final built = armar(base);
    expect(
      built.effects.map((e) => e.toJson()),
      base.effects.map((e) => e.toJson()),
    );
  });

  test('sin nombre no se puede guardar', () {
    final form = FeatDraft.formOf(FeatDraft.empty());
    expect(FeatDraft.errors(form), {'name': 'required'});
    form['name'] = ' Mano firme ';
    expect(FeatDraft.errors(form), isEmpty);
    expect(FeatDraft.build(FeatDraft.empty(), form).name, 'Mano firme');
  });
}
