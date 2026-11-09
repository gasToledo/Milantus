import '../domain/content.dart';
import '../domain/content_source.dart';
import '../domain/damage_type.dart';
import 'draft_numbers.dart';

/// El borrador de un arma que edita un formulario (ver `RaceDraft`, el mismo
/// patrón). Es el `_weapon()` y los validadores de `WeaponForm` de Flutter,
/// llevados al motor para que `dnd_web` no tenga reglas propias.
class WeaponDraft {
  const WeaponDraft._();

  static final _dice = RegExp(r'^\d+d\d+$');

  /// La plantilla de «Nueva arma». El id es provisorio: el definitivo sale del
  /// nombre al guardar.
  static Weapon empty() => Weapon(
        id: 'arma-propia',
        name: '',
        source: ContentSource.homebrew,
        category: 'simple',
        damageDice: '1d6',
        damageType: DamageType.slashing.id,
      );

  /// Lo que el formulario edita, como texto. El alcance en 0 («sin alcance»)
  /// viaja vacío, que en el campo se lee mejor.
  static Map<String, dynamic> formOf(Weapon w) => {
        'name': w.name,
        'category': w.category,
        'damageDice': w.damageDice,
        'damageType': w.damageType,
        'properties': [...w.properties],
        'versatileDice': w.versatileDice ?? '',
        'rangeNormal': w.rangeNormal > 0 ? '${w.rangeNormal}' : '',
        'rangeLong': w.rangeLong > 0 ? '${w.rangeLong}' : '',
        'mastery': w.mastery ?? '',
        'magicBonus': '${w.magicBonus}',
        'weight': weightText(w.weight),
        'costCp': '${w.costCp}',
        'description': w.description,
      };

  /// Arma el arma sobre [original]. No lanza por datos inválidos: también
  /// alimenta la vista previa mientras se escribe, y un número a medio tipear
  /// cae en 0.
  ///
  /// Lo que el formulario no muestra se conserva del original (`id` y
  /// `twoHandedUnlessMounted`), para que editar o duplicar la Lanza de
  /// caballería no le cambie la regla.
  static Weapon build(Weapon original, Map<String, dynamic> form) {
    final versatile = draftText(form['versatileDice']);
    final mastery = draftText(form['mastery']);
    return Weapon(
      id: original.id,
      name: draftText(form['name']),
      source: ContentSource.homebrew,
      category: draftText(form['category']),
      damageDice: draftText(form['damageDice']),
      damageType: draftText(form['damageType']),
      properties: [
        for (final p in (form['properties'] as List? ?? const [])) p.toString(),
      ],
      twoHandedUnlessMounted: original.twoHandedUnlessMounted,
      rangeNormal: int.tryParse(draftText(form['rangeNormal'])) ?? 0,
      rangeLong: int.tryParse(draftText(form['rangeLong'])) ?? 0,
      versatileDice: versatile.isEmpty ? null : versatile,
      mastery: mastery.isEmpty ? null : mastery,
      weight: double.tryParse(draftText(form['weight'])) ?? 0,
      costCp: int.tryParse(draftText(form['costCp'])) ?? 0,
      magicBonus: int.tryParse(draftText(form['magicBonus'])) ?? 0,
      description: draftText(form['description']),
    );
  }

  /// Campo → código de error; vacío si se puede guardar. Los códigos son los de
  /// `CreatureDraft` (`required`, `number`, `integer`, `range:a:b`, `dice`), más
  /// `rangeLongMin` (el alcance largo es menor que el normal) y los del peso.
  static Map<String, String> errors(Map<String, dynamic> form) {
    final out = <String, String>{};
    if (draftText(form['name']).isEmpty) out['name'] = 'required';

    final dice = draftText(form['damageDice']);
    if (dice.isEmpty) {
      out['damageDice'] = 'required';
    } else if (!_dice.hasMatch(dice)) {
      out['damageDice'] = 'dice';
    }
    final versatile = draftText(form['versatileDice']);
    if (versatile.isNotEmpty && !_dice.hasMatch(versatile)) {
      out['versatileDice'] = 'dice';
    }

    // A distancia o arrojadiza, un arco sin alcance no tiene a quién pegarle:
    // los dos números son obligatorios. Sin ellas, opcionales pero en rango.
    final props = {
      for (final p in (form['properties'] as List? ?? const [])) p.toString(),
    };
    final needsRange = props.contains('ranged') || props.contains('thrown');
    checkInt(out, form, 'rangeNormal', 5, 1000, optional: !needsRange);
    checkInt(out, form, 'rangeLong', 5, 1000, optional: !needsRange);
    if (!out.containsKey('rangeLong')) {
      final normal = int.tryParse(draftText(form['rangeNormal']));
      final long = int.tryParse(draftText(form['rangeLong']));
      if (normal != null && long != null && long < normal) {
        out['rangeLong'] = 'rangeLongMin';
      }
    }

    checkInt(out, form, 'magicBonus', 0, 3, optional: false);
    checkEconomy(out, form);
    return out;
  }
}
