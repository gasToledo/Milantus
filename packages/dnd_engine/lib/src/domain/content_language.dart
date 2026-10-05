/// Idioma en que el motor muestra su vocabulario de reglas: habilidades,
/// tipos de daño, competencias, el glosario de los formularios.
///
/// Los ids que viajan en los datos no cambian con el idioma; solo cambia el
/// texto que se muestra. El catálogo se traduce aparte, por superposición
/// (`content_translation.dart`).
enum ContentLanguage {
  es,
  en;

  /// El idioma activo. Por defecto español, que es la fuente.
  ///
  /// ponytail: estado global. Vale porque el cliente muestra un solo idioma a
  /// la vez —lo fija al cambiar el `Locale`— y el servidor nunca lo toca, así
  /// que queda en español. Techo: un proceso que necesite dos idiomas al
  /// mismo tiempo, por ejemplo un servidor que arme textos para cuentas en
  /// idiomas distintos. Salida: pasar el idioma como parámetro a cada
  /// `labelFor`. Un test que lo cambia lo restaura en `tearDown`.
  static ContentLanguage current = ContentLanguage.es;
}

/// [es] o [en] según [ContentLanguage.current].
T localized<T>(T es, T en) =>
    ContentLanguage.current == ContentLanguage.en ? en : es;
