import 'package:flutter_test/flutter_test.dart';

import '../tool/l10n_literals.dart';

/// Nada de texto visible fuera del catálogo de mensajes.
///
/// Recorre `lib/` (menos `lib/l10n/`, que es el catálogo) y falla si aparece un
/// literal que parece texto para la persona. El texto nuevo va a `app_es.arb` y
/// `app_en.arb`, y se lee con `context.l10n`: la interfaz se ofrece en los dos
/// idiomas, así que un texto suelto en un widget queda en español aunque la
/// persona haya elegido inglés.
///
/// Cuando el detector se equivoca por sobrar (un id, una tipografía, un prompt),
/// el renglón se marca con `l10n-ignore: motivo`, y un archivo entero de datos o
/// errores técnicos con `l10n-ignore-file: motivo` al principio. El motivo es
/// obligatorio a propósito: es lo que la fase 2 (catálogo y errores) lee para
/// saber qué falta.
///
/// Cómo se detecta y hasta dónde llega la heurística: `tool/l10n_literals.dart`.
/// Para ver qué sobra: `dart run tool/l10n_literals.dart -v`.
void main() {
  test('no hay texto visible fuera del catálogo', () {
    final hallados = literalesPorArchivo();
    expect(
      {for (final e in hallados.entries) e.key: e.value.length},
      isEmpty,
      reason:
          'Texto visible fuera del catálogo: pasalo a lib/l10n/app_es.arb y '
          'app_en.arb y usá context.l10n. Si no es texto para la persona, '
          'marcá el renglón con «l10n-ignore: motivo».',
    );
  });
}
