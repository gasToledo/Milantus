import '../domain/content.dart';
import '../domain/content_source.dart';
import 'draft_numbers.dart';

/// El borrador de una armadura que edita un formulario (mismo patrón que
/// `WeaponDraft`). Es el `_armor()`, `_applyCategoryDex` y los validadores de
/// `ArmorForm` de Flutter, llevados al motor.
class ArmorDraft {
  const ArmorDraft._();

  /// Las Destrezas con las que la vista previa muestra la CA: una que pasa el
  /// tope del manual y una que no.
  static const exampleDex = [3, 1];

  /// La plantilla de «Nueva armadura». El id es provisorio.
  static Armor empty() => const Armor(
        id: 'armadura-propia',
        name: '',
        source: ContentSource.homebrew,
        category: 'light',
        baseAc: 11,
        addDexMod: true,
      );

  /// Lo que el formulario edita, como texto. Un tope o una Fuerza que no hay
  /// viajan vacíos.
  static Map<String, dynamic> formOf(Armor a) => {
        'name': a.name,
        'category': a.category,
        'baseAc': '${a.baseAc}',
        'addDexMod': a.addDexMod,
        'maxDexBonus': a.maxDexBonus?.toString() ?? '',
        'strengthRequirement': a.strengthRequirement?.toString() ?? '',
        'stealthDisadvantage': a.stealthDisadvantage,
        'weight': weightText(a.weight),
        'costCp': '${a.costCp}',
        'description': a.description,
      };

  /// Arma la armadura sobre [original]. No lanza por datos inválidos.
  static Armor build(Armor original, Map<String, dynamic> form) => Armor(
        id: original.id,
        name: draftText(form['name']),
        source: ContentSource.homebrew,
        category: draftText(form['category']),
        baseAc: int.tryParse(draftText(form['baseAc'])) ?? 0,
        addDexMod: form['addDexMod'] == true,
        maxDexBonus: int.tryParse(draftText(form['maxDexBonus'])),
        strengthRequirement:
            int.tryParse(draftText(form['strengthRequirement'])),
        stealthDisadvantage: form['stealthDisadvantage'] == true,
        weight: double.tryParse(draftText(form['weight'])) ?? 0,
        costCp: int.tryParse(draftText(form['costCp'])) ?? 0,
        description: draftText(form['description']),
      );

  /// Campo → código de error; vacío si se puede guardar (los de
  /// `WeaponDraft.errors`).
  static Map<String, String> errors(Map<String, dynamic> form) {
    final out = <String, String>{};
    if (draftText(form['name']).isEmpty) out['name'] = 'required';
    checkInt(out, form, 'baseAc', 1, 30, optional: false);
    checkInt(out, form, 'maxDexBonus', 0, 10, optional: true);
    checkInt(out, form, 'strengthRequirement', 1, 30, optional: true);
    checkEconomy(out, form);
    return out;
  }

  /// Elegir la categoría trae la Destreza del manual: media hasta +2, pesada
  /// sin Destreza, ligera entera. Es un punto de partida y no un candado,
  /// porque el homebrew está para salirse del manual. El escudo no toca nada
  /// más, porque no suma Destreza.
  static Map<String, dynamic> withCategory(
    Map<String, dynamic> form,
    String category,
  ) {
    final out = {...form, 'category': category};
    switch (category) {
      case 'light':
        out['addDexMod'] = true;
        out['maxDexBonus'] = '';
      case 'medium':
        out['addDexMod'] = true;
        out['maxDexBonus'] = '2';
      case 'heavy':
        out['addDexMod'] = false;
        out['maxDexBonus'] = '';
    }
    return out;
  }

  /// La CA que va a quedar en la ficha con cada Destreza de ejemplo; vacío para
  /// un escudo, que suma a la CA de otra cosa.
  static List<({int dex, int ac})> acExamples(Armor a) => a.isShield
      ? const []
      : [for (final dex in exampleDex) (dex: dex, ac: a.armorClassFor(dex))];
}
