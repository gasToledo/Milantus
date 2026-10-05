import 'package:flutter/widgets.dart';

import '../web/browser.dart' as browser;

/// Idiomas de interfaz, en el orden en que los ofrece el selector. El primero
/// es el que se usa cuando no hay otra pista.
const supportedLanguageCodes = ['es', 'en'];

/// Cómo se llama cada idioma **en ese idioma**. No pasa por el catálogo: quien
/// está en el idioma equivocado tiene que poder reconocer el suyo.
const languageNames = {'es': 'Español', 'en': 'English'};

/// El idioma con que arranca la interfaz: el guardado si es válido; si no, el
/// del navegador si lo soportamos (`en-US` y `en-GB` valen `en`); si no,
/// español.
Locale resolveLocale({String? stored, String? browser}) {
  final guardado = _soportado(stored);
  if (guardado != null) return Locale(guardado);
  return Locale(_soportado(browser) ?? supportedLanguageCodes.first);
}

/// El código base de [tag] (`en-US` → `en`) si es un idioma soportado.
String? _soportado(String? tag) {
  if (tag == null) return null;
  final base = tag.toLowerCase().split(RegExp('[-_]')).first;
  return supportedLanguageCodes.contains(base) ? base : null;
}

/// El idioma activo de la interfaz. Alimenta `MaterialApp.locale`, igual que
/// `AppThemeController` con el tema; a diferencia del tema, vive en el
/// navegador y no en la cuenta, así que se lee **sincrónicamente** al crearlo
/// y el primer cuadro ya sale en el idioma correcto.
class AppLocaleController extends ValueNotifier<Locale> {
  final void Function(String code) write;
  final void Function(String code) setDocumentLanguage;

  /// Los cuatro puntos de contacto con el navegador se inyectan para que los
  /// tests no dependan de él; por defecto son los reales de `browser.dart`.
  AppLocaleController({
    String? Function() read = browser.readStoredLocale,
    this.write = browser.writeStoredLocale,
    String? Function() browserLanguage = browser.browserLanguage,
    this.setDocumentLanguage = browser.setDocumentLanguage,
  }) : super(
         resolveLocale(
           stored: _seguro(read),
           browser: _seguro(browserLanguage),
         ),
       ) {
    setDocumentLanguage(value.languageCode);
  }

  /// Lo que hay que preparar antes de mostrar el idioma nuevo: el arranque lo
  /// usa para cargar el catálogo traducido (ver `main.dart`). Se espera
  /// **antes** de cambiar [value] para que la interfaz y el contenido cambien
  /// en el mismo cuadro, y no primero los rótulos y después los nombres.
  Future<void> Function(Locale locale)? beforeChange;

  Future<void> _pending = Future.value();

  /// Cambia el idioma, lo recuerda y actualiza `<html lang>`. Si el navegador
  /// bloquea el almacenamiento el cambio vale igual durante la sesión: lo único
  /// que se pierde es recordarlo.
  ///
  /// Los cambios se encadenan: elegir inglés y enseguida español, con el
  /// inglés todavía cargando, termina en español con el contenido en español,
  /// y no al revés según qué carga llegue última. Sin [beforeChange] el cambio
  /// es inmediato.
  Future<void> choose(Locale locale) {
    if (beforeChange == null && _queued == 0) {
      _set(locale);
      return Future.value();
    }
    _queued++;
    return _pending = _pending.then((_) async {
      try {
        if (locale != value) {
          await beforeChange?.call(locale);
        }
      } catch (_) {
        // Sin la traducción, el catálogo sigue en español, que es el respaldo;
        // la interfaz cambia igual.
      } finally {
        _queued--;
      }
      _set(locale);
    });
  }

  int _queued = 0;

  void _set(Locale locale) {
    if (locale == value) return;
    value = locale;
    setDocumentLanguage(locale.languageCode);
    try {
      write(locale.languageCode);
    } catch (_) {
      // Almacenamiento bloqueado: se sigue sin recordar.
    }
  }

  /// `null` si [leer] lanza: leer el almacenamiento bloqueado es «no hay nada»,
  /// no un error que deba impedir arrancar.
  static String? _seguro(String? Function() leer) {
    try {
      return leer();
    } catch (_) {
      return null;
    }
  }
}

/// Da el [AppLocaleController] a quien lo necesite sin pasarlo por los
/// constructores: `DisplayPreferences` se monta desde dos pantallas y llegar
/// hasta ahí por parámetros tocaría media aplicación. Va por encima de
/// `MaterialApp` (que es quien lo escucha para cambiar `locale`).
class AppLocaleScope extends InheritedNotifier<AppLocaleController> {
  const AppLocaleScope({
    super.key,
    required AppLocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  /// El controlador, o `null` si no hay scope. Sin scope no hay idioma que
  /// elegir y el selector muestra el activo sin menú (ver `LanguageSelector`).
  static AppLocaleController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLocaleScope>()?.notifier;
}
