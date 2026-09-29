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

  test('el detector ve texto visible y no ve comentarios, claves ni URLs', () {
    List<String> ve(String linea) => literalesVisibles(linea);

    // Con acento, en cualquier lugar.
    expect(ve("final a = 'Guardá el personaje';"), hasLength(1));
    // Sin acento, pero en una posición de texto visible.
    expect(ve("Text('Guardar')"), hasLength(1));
    expect(ve("DialogAction('Cancelar', onPressed: f)"), hasLength(1));
    expect(ve("tooltip: 'Editar',"), hasLength(1));
    expect(ve("showAppMessage(context, 'Listo', tone: t)"), hasLength(1));
    // Una parte de un texto cortado en dos renglones hereda la posición.
    expect(ve("Text(\n  'Una parte '\n  'y otra',\n)"), hasLength(2));
    // Una frase suelta que empieza en mayúscula.
    expect(ve("final m = 'No se pudo cargar';"), hasLength(1));
    // Lo que no es texto para la persona.
    expect(ve("// Text('Guardar')"), isEmpty);
    expect(ve("final a = 1; // dice 'Guardá'"), isEmpty);
    expect(ve("ValueKey('codex-search')"), isEmpty);
    expect(ve("final ruta = '/api/personajes';"), isEmpty);
    expect(ve("final k = 'saved';"), isEmpty);
    expect(ve("Text('\$n')"), isEmpty);
    // La marca de excepción, por renglón y por archivo.
    expect(ve("Text('Solo para depurar') // l10n-ignore: log"), isEmpty);
    expect(
      ve("// l10n-ignore-file: errores técnicos\nText('Guardá')"),
      isEmpty,
    );
    // Sin motivo, la exención de archivo no vale.
    expect(ve("// l10n-ignore-file:\nText('Guardá')"), hasLength(1));
  });
}
