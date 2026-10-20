import 'package:dnd_server/src/config.dart';
import 'package:test/test.dart';

void main() {
  const dbEnv = {
    'DND_DB_PASSWORD': 'secreto',
    'DND_OIDC_ISSUER_URL': 'https://auth.example.com',
    'DND_OIDC_CLIENT_ID': 'dnd-app',
    'DND_OIDC_CLIENT_SECRET': 'oidc-secreto',
    'DND_PUBLIC_BASE_URL': 'https://fichas.example.com',
  };

  group('ServerConfig.fromEnvironment', () {
    test('un puerto no numérico falla con un error comprensible', () {
      expect(
        () => ServerConfig.fromEnvironment({
          ...dbEnv,
          'DND_SERVER_PORT': 'no-es-un-numero',
        }),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'sin contraseña de base de datos falla al construir la configuración',
      () {
        expect(
          () => ServerConfig.fromEnvironment(const {}),
          throwsA(isA<StateError>()),
        );
      },
    );
  });

  group('DatabaseConfig.fromEnvironment', () {});

  group('OidcConfig.fromEnvironment', () {
    test('calcula la URI de callback a partir de la base pública', () {
      final config = OidcConfig.fromEnvironment(dbEnv);

      expect(
        config.redirectUri.toString(),
        'https://fichas.example.com/auth/callback',
      );
    });

    test('sin issuer configurado falla al construir', () {
      expect(
        () => OidcConfig.fromEnvironment({
          'DND_OIDC_CLIENT_ID': 'x',
          'DND_OIDC_CLIENT_SECRET': 'x',
          'DND_PUBLIC_BASE_URL': 'https://x.example.com',
        }),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('PortraitsConfig.fromEnvironment', () {});

  group('AiProvidersConfig.fromEnvironment', () {});

  group('WebConfig.fromEnvironment', () {});

  group('requireEnv', () {
    test('falla con un mensaje que nombra la variable faltante', () {
      expect(
        () => requireEnv(const {}, 'DND_DB_PASSWORD'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'mensaje',
            contains('DND_DB_PASSWORD'),
          ),
        ),
      );
    });

    test('un valor vacío se trata como ausente', () {
      expect(
        () => requireEnv(const {'X': ''}, 'X'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
