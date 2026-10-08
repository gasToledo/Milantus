import 'package:dnd_app/l10n/app_localizations.dart';
import 'package:dnd_app/ui/item_catalog.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/localized_app.dart';

void main() {
  test('un objeto fuera del catálogo se rotula en el idioma de la interfaz', () {
    // El id huérfano (homebrew borrado) llega a la fila con esta familia. Antes
    // la fila mostraba el texto en español aunque la interfaz estuviera en
    // inglés: la traducción solo la hacía el título del grupo.
    const family = 'No está en el catálogo';
    final en = lookupAppLocalizations(const Locale('en'));

    expect(itemKindText(en, family), en.catalogNotInCatalog);
    expect(en.catalogNotInCatalog, isNot(family));
    expect(itemKindText(l10nEs, family), l10nEs.catalogNotInCatalog);
  });
}
