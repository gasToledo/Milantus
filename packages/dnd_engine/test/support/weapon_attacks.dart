import 'package:dnd_engine/dnd_engine.dart';

/// Los ataques que salen de armas en la mano, sin el golpe sin armas que
/// todo personaje tiene. Las pruebas de armas preguntan por «el» ataque del
/// arma, y con el puño siempre en la lista `attacks.single` dejaría de
/// significar eso.
extension WeaponAttacks on ComputedSheet {
  List<Attack> get weaponAttacks => [
        for (final a in attacks)
          if (a.baseWeaponId != unarmedStrikeId) a
      ];
}
