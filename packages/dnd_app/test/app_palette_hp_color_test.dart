import 'package:dnd_app/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const pal = AppPalette.dark;

  test('hpColor: verde, dorado y carmesí según el tramo', () {
    expect(pal.hpColor(1), pal.verdant);
    expect(pal.hpColor(0.51), pal.verdant);
    expect(pal.hpColor(0.4), pal.gold);
    expect(pal.hpColor(0.1), pal.crimson);
    expect(pal.hpColor(0), pal.crimson);
  });

  test('hpColor: en los bordes la mitad es dorado y un cuarto es carmesí', () {
    expect(pal.hpColor(0.5), pal.gold);
    expect(pal.hpColor(0.25), pal.crimson);
  });
}
