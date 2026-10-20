import 'package:dnd_server/src/ai/portrait_provider.dart';
import 'package:dnd_server/src/config.dart';
import 'package:test/test.dart';

void main() {
  group('buildProviders', () {
    test(
      'Pollinations siempre está configurado; los de Azure necesitan key',
      () {
        final providers = buildProviders(
          const AiProvidersConfig(azureApiKey: '', azureOpenAiApiKey: ''),
        );

        final byId = {for (final p in providers) p.id: p};
        expect(byId['pollinations']!.isConfigured, isTrue);
        expect(byId['azure']!.isConfigured, isFalse);
        expect(byId['azure-gpt-image']!.isConfigured, isFalse);
      },
    );

    test('una key presente configura solo su proveedor', () {
      final providers = buildProviders(
        const AiProvidersConfig(
          azureApiKey: '',
          azureOpenAiApiKey: 'openai-key',
        ),
      );

      final byId = {for (final p in providers) p.id: p};
      expect(byId['azure']!.isConfigured, isFalse);
      expect(byId['azure-gpt-image']!.isConfigured, isTrue);
    });
  });

  group('availableProviders', () {
    test('excluye los proveedores sin credenciales configuradas', () {
      final providers = buildProviders(
        const AiProvidersConfig(azureApiKey: '', azureOpenAiApiKey: ''),
      );

      expect(availableProviders(providers).map((p) => p.id), ['pollinations']);
    });
  });

  group('resolveStoredProviderId', () {
    final providers = buildProviders(
      const AiProvidersConfig(azureApiKey: 'flux-key', azureOpenAiApiKey: ''),
    );

    test('un id nulo degrada a Pollinations', () {
      expect(resolveStoredProviderId(null, providers), 'pollinations');
    });

    test('un id retirado degrada a Pollinations', () {
      for (final retired in retiredProviderIds) {
        expect(resolveStoredProviderId(retired, providers), 'pollinations');
      }
    });

    test('un id desconocido degrada a Pollinations', () {
      expect(resolveStoredProviderId('inexistente', providers), 'pollinations');
    });

    test('un id conocido se conserva tal cual', () {
      expect(resolveStoredProviderId('azure', providers), 'azure');
    });
  });
}
