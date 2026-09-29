import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `gen_l10n` solo avisa cuando al idioma que no es plantilla le falta una
/// clave, y un aviso no rompe el build: el inglés saldría con un hueco.
/// Esto lo convierte en fallo, y además compara los marcadores (`{nombre}`,
/// `{count}`), porque una traducción que perdió uno muestra el texto sin el
/// dato.
Map<String, String> _mensajes(String archivo) {
  final json =
      jsonDecode(File('lib/l10n/$archivo').readAsStringSync())
          as Map<String, dynamic>;
  return {
    for (final e in json.entries)
      // `@clave` es metadato y `@@locale` es la cabecera: no son mensajes.
      if (!e.key.startsWith('@')) e.key: e.value as String,
  };
}

/// Nombres de marcador de un mensaje ICU: `{nombre}` y `{n, plural, ...}`.
/// Las ramas de un plural (`=1{cosa}`, `other{...}`) no cuentan: van pegadas al
/// selector, y una rama de una sola palabra parecería un marcador.
Set<String> _marcadores(String mensaje) => {
  for (final m in RegExp(
    r'(?<!(?:=\d+|other|one|zero|two|few|many))\{(\w+)(?=[,}])',
  ).allMatches(mensaje))
    m.group(1)!,
};

void main() {
  final es = _mensajes('app_es.arb');
  final en = _mensajes('app_en.arb');

  test('el inglés tiene todas las claves del español y ninguna de más', () {
    expect(
      es.keys.toSet().difference(en.keys.toSet()),
      isEmpty,
      reason: 'claves sin traducir al inglés',
    );
    expect(
      en.keys.toSet().difference(es.keys.toSet()),
      isEmpty,
      reason: 'claves del inglés que el español (plantilla) no define',
    );
  });

  test('cada mensaje usa los mismos marcadores en los dos idiomas', () {
    final distintos = [
      for (final clave in es.keys)
        if (en.containsKey(clave) &&
            !_marcadores(es[clave]!).containsAll(_marcadores(en[clave]!)) |
                !_marcadores(en[clave]!).containsAll(_marcadores(es[clave]!)))
          clave,
    ];
    expect(distintos, isEmpty);
  });

  test('un mensaje vacío no pasa por traducido', () {
    expect([
      for (final e in [...es.entries, ...en.entries])
        if (e.value.trim().isEmpty) e.key,
    ], isEmpty);
  });

  test('el comparador de marcadores distingue plurales de ramas', () {
    expect(_marcadores('Hola {nombre}'), {'nombre'});
    expect(
      _marcadores(
        '{count, plural, one{{count} objeto} other{{count} objetos}}',
      ),
      {'count'},
    );
    expect(_marcadores('Sin marcadores'), isEmpty);
    // Una rama de una sola palabra no es un marcador.
    expect(_marcadores('{n, plural, =1{thing} other{things}}'), {'n'});
  });
}
