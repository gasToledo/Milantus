// ignore_for_file: avoid_print
// Detector de texto visible fuera del catálogo de mensajes.
//
// Lo usan dos cosas: `test/l10n_no_literals_test.dart` y este mismo archivo
// como herramienta, para ver dónde hay texto suelto:
//
//   dart run tool/l10n_literals.dart        # resumen por archivo
//   dart run tool/l10n_literals.dart -v     # cada literal
//
// ponytail: es una heurística sobre el texto fuente, no un análisis del árbol.
// Ve una cadena de un solo renglón si (1) lleva letras acentuadas o `¿¡`,
// (2) está en una posición de texto visible (`Text(...)`, `label:`,
// `tooltip:`, `showAppMessage(ctx, ...)`…) o (3) es una frase suelta que
// empieza en mayúscula. No ve cadenas multilínea ni texto armado por partes
// sin ninguna de esas pistas. Cuando se equivoca por sobrar, se marca el
// renglón con `l10n-ignore: <motivo>` (o el archivo entero, con
// `l10n-ignore-file: <motivo>` al principio). El techo, si molesta, es una regla de
// análisis propia (`custom_lint`) que sí mire el árbol.
import 'dart:io';

// Una cadena de un solo renglón, con comillas simples o dobles y escapes.
final _literal = RegExp(
  r'''\x27(?:[^\x27\\\n]|\\.)*\x27|"(?:[^"\\\n]|\\.)*"''',
);
final _espanol = RegExp('[áéíóúñüÁÉÍÓÚÑÜ¿¡]');

// Lo que hay justo antes de un literal que lo hace texto de interfaz.
final _posicionUi = RegExp(
  r'(?:\b(?:Text|SelectableText|AppBusyLabel|DialogAction|failureMessage)\(\s*|'
  r'\b(?:label|labelText|title|tooltip|hintText|hint|helperText|errorText|'
  r'semanticLabel|semanticsLabel|subtitle|message|text|description|caption|'
  r'heading|placeholder|prefixText|suffixText|emptyLabel):\s*|'
  r'\bshowAppMessage\(\s*\w+(?:\.\w+)*,\s*)$',
);

/// El código sin comentarios de línea ni renglones exentos.
///
/// Un renglón queda exento si lleva `l10n-ignore`, o si va después de un
/// comentario `// l10n-ignore: motivo`: en ese caso lo queda toda la sentencia,
/// hasta el primer renglón que termina en `;` (el formateador mueve los
/// comentarios finales y parte las sentencias largas, así que el de arriba es
/// el que aguanta).
String _sinComentarios(String fuente) {
  var exentoElProximo = false;
  return fuente
      .split('\n')
      .map((linea) {
        final t = linea.trimLeft();
        if (t.startsWith('//') || t.startsWith('*')) {
          if (t.contains('l10n-ignore') && !t.contains('l10n-ignore-file')) {
            exentoElProximo = true;
          }
          return '';
        }
        if (exentoElProximo && t.isNotEmpty) {
          if (t.endsWith(';')) exentoElProximo = false;
          return '';
        }
        if (linea.contains('l10n-ignore')) return '';
        // ` //` con espacio delante: `https://` no lo dispara.
        final corte = linea.indexOf(' //');
        return corte < 0 ? linea : linea.substring(0, corte);
      })
      .join('\n');
}

/// El texto de un literal, sin comillas ni interpolaciones.
String _cuerpo(String literal) => literal
    .substring(1, literal.length - 1)
    .replaceAll(RegExp(r'\$\{[^}]*\}|\$\w+'), '')
    // Sin la interpolación quedan espacios dobles que rompen «palabra palabra».
    .replaceAll(RegExp(r'\s+'), ' ');

bool _esTexto(String literal, {required bool enPosicionUi}) {
  final c = _cuerpo(literal).trim();
  if (_espanol.hasMatch(c)) return true;
  if (!RegExp('[A-Za-z]{2}').hasMatch(c)) return false;
  // Identificadores, rutas y claves: minúsculas pegadas, sin espacios.
  if (RegExp(r'^[a-z0-9_\-./:#@]+$').hasMatch(c)) return false;
  if (enPosicionUi) return true;
  // Una frase suelta: empieza en mayúscula y sigue con más palabras.
  // También una palabra sola («Guardado») o con puntuación final.
  return RegExp(
    r'^[A-Z][a-z]+[:,]?( \S+)+|^[A-Z][a-z]{3,}[….!?:]?$',
  ).hasMatch(c);
}

/// Los literales de [fuente] que parecen texto visible.
/// Si se pasa [lineas], se llena con el renglón (desde 1) de cada literal.
List<String> literalesVisibles(String fuente, [List<int>? lineas]) {
  // Un archivo entero puede quedar fuera con `// l10n-ignore-file: motivo`
  // (errores técnicos, prompts, datos): el motivo obliga a escribirlo, y es lo
  // que la fase 2 lee para saber qué falta.
  if (RegExp(
    r'^\s*//\s*l10n-ignore-file:[ \t]*\S',
    multiLine: true,
  ).hasMatch(fuente)) {
    return [];
  }
  final t = _sinComentarios(fuente);
  final salida = <String>[];
  var finPrevio = -1;
  var uiPrevio = false;
  for (final m in _literal.allMatches(t)) {
    final antes = t.substring(m.start < 90 ? 0 : m.start - 90, m.start);
    // `'una parte '\n 'y otra'`: la segunda hereda la posición de la primera.
    final continua =
        finPrevio >= 0 && t.substring(finPrevio, m.start).trim().isEmpty;
    final ui = continua ? uiPrevio : _posicionUi.hasMatch(antes);
    finPrevio = m.end;
    uiPrevio = ui;
    // Un nombre de tipografía no es texto para la persona.
    final tipografia = RegExp(r'fontFamily:\s*$').hasMatch(antes);
    if (!tipografia && _esTexto(m.group(0)!, enPosicionUi: ui)) {
      salida.add(m.group(0)!);
      lineas?.add(RegExp('\n').allMatches(t.substring(0, m.start)).length + 1);
    }
  }
  return salida;
}

/// Ruta → literales, para todo `lib/` salvo el catálogo (`lib/l10n/`).
Map<String, List<String>> literalesPorArchivo([String raiz = 'lib']) {
  final r = <String, List<String>>{};
  for (final f in Directory(raiz).listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    final ruta = f.path.replaceAll(r'\', '/');
    if (ruta.startsWith('lib/l10n/')) continue;
    final lits = literalesVisibles(f.readAsStringSync());
    if (lits.isNotEmpty) r[ruta] = lits;
  }
  return r;
}

void main(List<String> args) {
  final por = literalesPorArchivo();
  final rutas = por.keys.toList()..sort();
  for (final r in rutas) {
    print('${por[r]!.length.toString().padLeft(4)}  $r');
    if (args.contains('-v')) {
      final lineas = <int>[];
      final lits = literalesVisibles(File(r).readAsStringSync(), lineas);
      for (var i = 0; i < lits.length; i++) {
        print('  ${lineas[i].toString().padLeft(6)}: ${lits[i]}');
      }
    }
  }
  final total = por.values.fold<int>(0, (a, b) => a + b.length);
  print('literales: $total en ${por.length} archivos');
}
