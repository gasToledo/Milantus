import 'package:dnd_app/l10n/l10n_context.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Los precios y montos llevan las abreviaturas del idioma activo. En inglés
/// «pp» es platino: con las del motor, un bastón de 2 piezas de plata se leía
/// «2 pp» y parecía costar cien veces más.
void main() {
  test('en inglés, plata es sp y oro es gp', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.cost(20), '2 sp');
    expect(en.amount(750), '7 gp 5 sp');
    expect(en.coins({'gp': 3, 'pp': 1}), '1 pp, 3 gp');
  });

  test('en español siguen las de siempre', () {
    final es = lookupAppLocalizations(const Locale('es'));
    expect(es.cost(20), '2 pp');
    expect(es.amount(750), '7 po 5 pp');
    expect(es.coins({'gp': 3, 'pp': 1}), '1 ppt, 3 po');
  });
}
