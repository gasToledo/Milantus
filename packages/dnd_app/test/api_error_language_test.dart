import 'dart:convert';

import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_app/api/api_exception.dart';
import 'package:dnd_app/l10n/app_localizations.dart';
import 'package:dnd_app/theme/app_widgets.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Un cliente que responde siempre el mismo error, como lo arma el servidor:
/// el mensaje en castellano y el código.
ApiClient _respondiendo(Map<String, dynamic> body, int status) => ApiClient(
  client: MockClient(
    (_) async => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    ),
  ),
);

Future<ApiException> _error(ApiClient api) async {
  try {
    await api.deleteCharacter('x');
  } on ApiException catch (e) {
    return e;
  }
  fail('se esperaba un error');
}

void main() {
  tearDown(() => ContentLanguage.current = ContentLanguage.es);
  final en = lookupAppLocalizations(const Locale('en'));

  test(
    'en inglés, un error con código conocido se lee entero en inglés',
    () async {
      ContentLanguage.current = ContentLanguage.en;
      final e = await _error(
        _respondiendo({
          'error': 'Campaña no encontrada.',
          'code': 'campaign_not_found',
        }, 404),
      );
      expect(e.code, 'campaign_not_found');
      expect(e.message, 'Campaign not found.');
      expect(
        failureMessage(en.dmSaveCombatFailed, e),
        '${en.dmSaveCombatFailed}: Campaign not found.',
      );
    },
  );

  test('en español se muestra el mensaje del servidor tal cual', () async {
    final e = await _error(
      _respondiendo({
        'error': 'Personaje inválido: falta el nombre.',
        'code': 'invalid_data',
      }, 400),
    );
    expect(e.message, 'Personaje inválido: falta el nombre.');
  });

  test(
    'un código que el cliente no conoce deja el mensaje del servidor',
    () async {
      ContentLanguage.current = ContentLanguage.en;
      final e = await _error(
        _respondiendo({'error': 'Algo nuevo.', 'code': 'something_new'}, 409),
      );
      expect(e.code, 'something_new');
      expect(e.message, 'Algo nuevo.');
    },
  );

  test('sin conexión, el aviso propio sale en el idioma activo', () async {
    ContentLanguage.current = ContentLanguage.en;
    final api = ApiClient(
      client: MockClient((_) async => throw http.ClientException('caído')),
    );
    final e = await _error(api);
    expect(e.isOffline, isTrue);
    expect(e.message, 'Could not connect to the server.');
  });
}
