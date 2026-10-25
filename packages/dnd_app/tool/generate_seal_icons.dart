// Genera el favicon y los íconos de la PWA con el sello de Milantus en su
// versión de disco (ver docs/desarrollo/diseno-web.md §2, «La marca»).
//
//   cd packages/dnd_app && dart run tool/generate_seal_icons.dart
//
// Escribe sobre web/favicon.png y web/icons/*.png. Es Dart puro y sin
// dependencias a propósito: rasteriza y codifica el PNG a mano para que
// regenerar los íconos no pida Python, Inkscape ni un paquete de imágenes.
// La salida es determinista: correrlo sin cambiar nada no deja diff.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

// Los oscuros de AppPalette: los íconos viven fuera de la app y no tienen tema.
const _gold = [0xC9, 0xA2, 0x4B];
const _plaque = [0x12, 0x10, 0x0C];
const _scaffold = [0x15, 0x12, 0x10];

/// El disco y la M, sobre el lienzo de 120 del sello.
class _Disc {
  final double radius;
  final double stroke;
  final List<Point<double>> m;

  _Disc(this.radius, this.stroke, List<List<num>> points)
    : m = [for (final p in points) Point(p[0].toDouble(), p[1].toDouble())];
}

// Desde 192 px. La M es la misma que la del sello de línea.
final _large = _Disc(56, 10, [
  [36, 84],
  [36, 38],
  [60, 64],
  [84, 38],
  [84, 84],
]);

// El favicon: disco a sangre y M más gruesa, que a 16 px de pestaña la de
// arriba se empasta.
final _small = _Disc(60, 16, [
  [34, 88],
  [34, 34],
  [60, 64],
  [86, 34],
  [86, 88],
]);

Point<double> _unit(Point<double> v) => v * (1 / v.magnitude);
Point<double> _normal(Point<double> v) => Point(-v.y, v.x);

/// El contorno del trazo con uniones en inglete y remates cuadrados, como lo
/// pinta `_SealPainter` (`StrokeJoin.miter`, `StrokeCap.square`).
List<Point<double>> _outline(List<Point<double>> p, double width) {
  final h = width / 2;
  List<Point<double>> side(double s) => [
    for (var i = 0; i < p.length; i++)
      if (i == 0 || i == p.length - 1)
        () {
          final d = _unit(i == 0 ? p[1] - p[0] : p[i] - p[i - 1]);
          return p[i] + _normal(d) * (s * h) + d * (i == 0 ? -h : h);
        }()
      else
        () {
          final n0 = _normal(_unit(p[i] - p[i - 1]));
          final n1 = _normal(_unit(p[i + 1] - p[i]));
          final miter = _unit(n0 + n1);
          final length = h / (miter.x * n0.x + miter.y * n0.y);
          return p[i] + miter * (s * length);
        }(),
  ];
  return [...side(1), ...side(-1).reversed];
}

bool _inside(List<Point<double>> poly, double x, double y) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final a = poly[i], b = poly[j];
    if ((a.y > y) != (b.y > y) &&
        x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x) {
      inside = !inside;
    }
  }
  return inside;
}

/// [diameter] es el del disco sobre el lado del ícono. Con [background] el
/// fondo va lleno, que es lo que piden los íconos maskable.
Uint8List _render(
  int size,
  _Disc disc,
  double diameter,
  List<int>? background,
) {
  final m = _outline(disc.m, disc.stroke);
  final k = size * diameter / (2 * disc.radius);
  // 5×5 muestras por píxel: alcanza para que el borde del disco no se vea
  // escalonado a 16 px.
  const ss = 5;
  final rgba = Uint8List(size * size * 4);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      var gold = 0, ink = 0;
      for (var sy = 0; sy < ss; sy++) {
        for (var sx = 0; sx < ss; sx++) {
          final ux = (x + (sx + .5) / ss - size / 2) / k + 60;
          final uy = (y + (sy + .5) / ss - size / 2) / k + 60;
          final dx = ux - 60, dy = uy - 60;
          if (dx * dx + dy * dy > disc.radius * disc.radius) continue;
          _inside(m, ux, uy) ? ink++ : gold++;
        }
      }
      final alpha = (gold + ink) / (ss * ss);
      final o = (y * size + x) * 4;
      for (var c = 0; c < 3; c++) {
        final fg = alpha == 0
            ? 0.0
            : (_gold[c] * gold + _plaque[c] * ink) / (gold + ink);
        rgba[o + c] = background == null
            ? fg.round()
            : (fg * alpha + background[c] * (1 - alpha)).round();
      }
      rgba[o + 3] = background == null ? (alpha * 255).round() : 255;
    }
  }
  return _png(size, rgba);
}

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c ^= b;
    for (var i = 0; i < 8; i++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
    }
  }
  return c ^ 0xFFFFFFFF;
}

Uint8List _png(int size, Uint8List rgba) {
  final raw = BytesBuilder();
  for (var y = 0; y < size; y++) {
    raw
      ..addByte(0)
      ..add(rgba.sublist(y * size * 4, (y + 1) * size * 4));
  }
  final out = BytesBuilder()..add([137, 80, 78, 71, 13, 10, 26, 10]);
  void chunk(String type, List<int> data) {
    final body = [...type.codeUnits, ...data];
    out
      ..add((ByteData(4)..setUint32(0, data.length)).buffer.asUint8List())
      ..add(body)
      ..add((ByteData(4)..setUint32(0, _crc32(body))).buffer.asUint8List());
  }

  final header = ByteData(13)
    ..setUint32(0, size)
    ..setUint32(4, size)
    ..setUint8(8, 8) // 8 bits por canal
    ..setUint8(9, 6); // RGBA
  chunk('IHDR', header.buffer.asUint8List());
  chunk('IDAT', ZLibCodec(level: 9).encode(raw.toBytes()));
  chunk('IEND', const []);
  return out.toBytes();
}

void main() {
  void write(String path, Uint8List bytes) =>
      File('web/$path').writeAsBytesSync(bytes);

  write('favicon.png', _render(32, _small, 1, null));
  write('icons/Icon-192.png', _render(192, _large, 0.94, null));
  write('icons/Icon-512.png', _render(512, _large, 0.94, null));
  // La zona segura de un ícono maskable es un círculo del 80 % del lado: el
  // disco al 72 % deja aire para cualquier forma que le aplique el sistema.
  write('icons/Icon-maskable-192.png', _render(192, _large, 0.72, _scaffold));
  write('icons/Icon-maskable-512.png', _render(512, _large, 0.72, _scaffold));
}
