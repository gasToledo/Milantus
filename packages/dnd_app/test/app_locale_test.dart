import 'package:dnd_app/l10n/app_locale.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveLocale', () {
    test('un idioma guardado válido gana sobre el del navegador', () {
      expect(resolveLocale(stored: 'en', browser: 'es-AR'), const Locale('en'));
    });

    test('un valor guardado inválido se ignora y decide el navegador', () {
      expect(resolveLocale(stored: 'fr', browser: 'en-US'), const Locale('en'));
      expect(resolveLocale(stored: '', browser: 'es'), const Locale('es'));
    });

    test('las variantes regionales valen su idioma base', () {
      expect(resolveLocale(browser: 'en-US'), const Locale('en'));
      expect(resolveLocale(browser: 'en-GB'), const Locale('en'));
      expect(resolveLocale(browser: 'EN_us'), const Locale('en'));
      expect(resolveLocale(browser: 'es-AR'), const Locale('es'));
    });

    test('un idioma no soportado o sin datos cae a español', () {
      expect(resolveLocale(browser: 'fr-FR'), const Locale('es'));
      expect(resolveLocale(), const Locale('es'));
    });
  });

  group('AppLocaleController', () {
    late String? guardado;
    late List<String> lang;

    AppLocaleController crear({String? navegador, bool bloqueado = false}) =>
        AppLocaleController(
          read: () => bloqueado ? throw StateError('bloqueado') : guardado,
          write: (c) =>
              bloqueado ? throw StateError('bloqueado') : guardado = c,
          browserLanguage: () => navegador,
          setDocumentLanguage: lang.add,
        );

    setUp(() {
      guardado = null;
      lang = [];
    });

    test('arranca en el idioma resuelto y marca <html lang>', () {
      final c = crear(navegador: 'en-US');
      expect(c.value, const Locale('en'));
      expect(lang, ['en']);
    });

    test(
      'choose recuerda la elección, actualiza lang y la próxima visita la lee',
      () {
        final c = crear();
        c.choose(const Locale('en'));
        expect(guardado, 'en');
        expect(lang, ['es', 'en']);
        expect(crear(navegador: 'es').value, const Locale('en'));
      },
    );

    test('elegir el idioma que ya está no escribe ni notifica', () {
      final c = crear();
      var avisos = 0;
      c.addListener(() => avisos++);
      c.choose(const Locale('es'));
      expect(avisos, 0);
      expect(guardado, isNull);
    });

    test('con el almacenamiento bloqueado arranca y cambia en memoria', () {
      final c = crear(bloqueado: true, navegador: 'es');
      expect(c.value, const Locale('es'));
      c.choose(const Locale('en'));
      expect(c.value, const Locale('en'));
      expect(lang.last, 'en');
    });
  });
}
