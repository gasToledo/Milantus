import 'dart:math';

import '../domain/ability.dart';
import '../domain/character.dart';
import '../domain/computed_sheet.dart';
import '../domain/creature.dart';
import '../domain/effects.dart';
import '../domain/spell_slots.dart';
import 'dice.dart';

/// Operaciones de partida sobre el [CombatState]. Lógica pura y testeable;
/// mutan el estado in situ. La recuperación por descanso sigue reglas 2024
/// simplificadas para el MVP.
class CombatOps {
  /// La regla de daño en crudo: los PG temporales absorben primero y los PG no
  /// bajan de 0. Devuelve los valores nuevos.
  ///
  /// Vive suelta porque la aplican dos cosas distintas —el personaje y cada
  /// compañero invocado— y una copia por cada una es una copia que se puede
  /// desincronizar.
  static ({int hp, int tempHp}) _absorbDamage(int hp, int tempHp, int amount) {
    if (amount <= 0) return (hp: hp, tempHp: tempHp);
    var dmg = amount;
    var temp = tempHp;
    if (temp > 0) {
      final absorbed = min(temp, dmg);
      temp -= absorbed;
      dmg -= absorbed;
    }
    return (hp: max(0, hp - dmg), tempHp: temp);
  }

  /// Aplica daño: primero consume PG temporales, luego PG. No baja de 0
  /// (a 0 PG el personaje queda inconsciente y entran las salvaciones de muerte).
  /// La [sheet] dice qué estados activos sobreviven a quedar incapacitado.
  static void applyDamage(CombatState c, int amount, {ComputedSheet? sheet}) {
    final next = _absorbDamage(c.currentHp, c.tempHp, amount);
    c.currentHp = next.hp;
    c.tempHp = next.tempHp;
    // A 0 PG quedás Inconsciente, que incluye Incapacitado. Va acá y no en
    // la pantalla porque el daño entra por varios lados y una revisión por
    // cada uno es una revisión que alguno se olvida.
    if (c.currentHp <= 0) _incapacitate(c, sheet);
  }

  /// Cura PG hasta el máximo. Curar desde 0 o menos estabiliza y limpia las
  /// salvaciones de muerte.
  static void applyHealing(CombatState c, int maxHp, int amount) {
    if (amount <= 0) return;
    if (c.currentHp <= 0) {
      c.deathSuccesses = 0;
      c.deathFailures = 0;
    }
    c.currentHp = min(maxHp, c.currentHp + amount);
  }

  /// Fija los PG temporales (no se acumulan: se toma el mayor entre el actual
  /// y el nuevo, según las reglas).
  static void setTempHp(CombatState c, int value) {
    c.tempHp = max(0, max(c.tempHp, value));
  }

  /// Descanso corto: recupera por completo los recursos de recarga corta y la
  /// cantidad declarada por los recursos de recuperación parcial. Si el
  /// personaje usa Magia de Pacto (Brujo), también recupera sus espacios.
  static void shortRest(
    CombatState c,
    List<CharacterResource> resources, {
    Spellcasting? spellcasting,
  }) {
    for (final r in resources) {
      if (r.recharge == RechargeOn.shortRest) {
        c.resourceUsage[r.key] = 0;
      } else if (r.shortRestRecovery > 0) {
        final used = c.resourceUsage[r.key] ?? 0;
        c.resourceUsage[r.key] = max(0, used - r.shortRestRecovery);
      }
    }
    if (spellcasting?.progression == CasterProgression.pact) {
      c.pactSlotsUsed.clear();
    }
    // Un descanso corto dura una hora y ningún estado activable pasa de diez
    // minutos: si seguía prendido, ya terminó.
    c.activeModes.clear();
  }

  /// Descanso largo: PG al máximo, se limpian PG temporales y salvaciones de
  /// muerte, baja 1 el agotamiento, se recupera la mitad de los dados de golpe,
  /// se recargan todos los recursos, se recuperan los espacios de conjuro y
  /// termina la concentración.
  ///
  /// [companionMaxHp] resuelve los PG máximos de cada compañero invocado, que
  /// dependen del catálogo y del nivel del espacio con que se lo convocó. Si no
  /// se pasa, los compañeros quedan como estaban.
  ///
  /// ponytail: el descanso largo deja a los compañeros activos a tope y no
  /// despide a ninguno. El Cañón Arcano dura una hora por regla y tendría que
  /// desaparecer solo; queda para el botón Despedir hasta que algún compañero
  /// necesite de verdad una duración modelada.
  static void longRest(
    CombatState c,
    int maxHp,
    List<CharacterResource> resources,
    int hitDiceMax, {
    int Function(CompanionInstance)? companionMaxHp,
    bool grantsHeroicInspiration = false,
  }) {
    c.currentHp = maxHp;
    c.tempHp = 0;
    c.deathSuccesses = 0;
    c.deathFailures = 0;
    if (c.exhaustion > 0) c.exhaustion -= 1;
    // Se gana, no se acumula: nunca hay más de una, así que quien ya la tenía
    // la desperdicia. Por eso es una asignación y no un contador.
    if (grantsHeroicInspiration) c.heroicInspiration = true;
    _recoverHitDice(c, max(1, hitDiceMax ~/ 2));
    for (final r in resources) {
      c.resourceUsage[r.key] = 0;
    }
    c.spellSlotsUsed.clear();
    c.pactSlotsUsed.clear();
    c.wildShapeCreatureId = null;
    c.activeModes.clear();
    // Por la misma vía que el botón de terminar: el descanso corta la
    // concentración, y con ella se van los espíritus invocados.
    endConcentration(c);
    if (companionMaxHp != null) {
      for (final companion in c.companions) {
        companion.currentHp = companionMaxHp(companion);
        companion.tempHp = 0;
        companion.conditions.clear();
      }
    }
  }

  /// Gasta un espacio de conjuro del [slotLevel] indicado. Devuelve false si no
  /// quedan espacios disponibles de ese nivel.
  static bool spendSpellSlot(CombatState c, Spellcasting sc, int slotLevel) =>
      spendSlot(
        c,
        sc.slotsByLevel,
        slotLevel,
        pact: sc.progression == CasterProgression.pact,
      );

  /// Lo mismo que [spendSpellSlot] contra una tabla de espacios suelta: la de
  /// `ComputedSheet.normalSpellSlotsByLevel` o `pactSlotsByLevel`, que es lo
  /// que la ficha muestra también a un multiclase.
  static bool spendSlot(
    CombatState c,
    Map<int, int> slotsByLevel,
    int slotLevel, {
    bool pact = false,
  }) {
    final available = slotsByLevel[slotLevel] ?? 0;
    final usedMap = pact ? c.pactSlotsUsed : c.spellSlotsUsed;
    final used = usedMap[slotLevel] ?? 0;
    if (used >= available) return false;
    usedMap[slotLevel] = used + 1;
    return true;
  }

  /// Fija los usos gastados de [r] dentro de [0, máximo]. En una reserva lo que
  /// se pide puede pasarse de lo que queda, y recuperar de más no deja usos
  /// negativos.
  static void setResourceUsed(CombatState c, CharacterResource r, int used) =>
      c.resourceUsage[r.key] = used.clamp(0, r.max);

  /// Recupera manualmente un espacio de conjuro del [slotLevel] indicado.
  static void recoverSpellSlot(
    CombatState c,
    int slotLevel, {
    bool pact = false,
  }) {
    final usedMap = pact ? c.pactSlotsUsed : c.spellSlotsUsed;
    final used = usedMap[slotLevel] ?? 0;
    if (used > 0) usedMap[slotLevel] = used - 1;
  }

  /// Espacios de conjuro disponibles (no gastados) del [slotLevel] indicado.
  static int spellSlotsRemaining(
      CombatState c, Spellcasting sc, int slotLevel) {
    final available = sc.slotsByLevel[slotLevel] ?? 0;
    final used = sc.progression == CasterProgression.pact
        ? c.pactSlotsUsed[slotLevel] ?? 0
        : c.spellSlotsUsed[slotLevel] ?? 0;
    return max(0, available - used);
  }

  /// Inicia (o reemplaza) la concentración en un conjuro. Reemplazarla rompe la
  /// anterior, así que se lleva puestos a los compañeros que la sostenían.
  static void startConcentration(CombatState c, String spell) {
    _dismissConcentrationCompanions(c);
    c.concentratingOn = spell;
  }

  /// Termina la concentración actual y despide a lo que dependía de ella.
  static void endConcentration(CombatState c) {
    _dismissConcentrationCompanions(c);
    c.concentratingOn = null;
  }

  /// Los compañeros que sostiene un conjuro de concentración desaparecen con
  /// ella. Los que no dependen de ninguna —el cañón, el defensor, el familiar—
  /// se quedan donde están.
  static void _dismissConcentrationCompanions(CombatState c) {
    c.companions.removeWhere((i) => i.concentration);
  }

  /// Gasta un dado de golpe para curarse (tirada + mod. de CON). Devuelve los
  /// PG recuperados, o 0 si no quedan dados. `hitDiceMax` = nivel de personaje.
  static int spendHitDie(
    CombatState c,
    ComputedSheet sheet,
    int hitDiceMax, {
    Dice? dice,
  }) {
    _moveLegacyHitDiceTo(c, sheet.hitDie);
    if (_totalHitDiceUsed(c) >= hitDiceMax) return 0;
    final roll = (dice ?? Dice()).rollHitDie(sheet.hitDie);
    final conMod = sheet.abilityModifiers[Ability.constitution] ?? 0;
    final heal = max(0, roll + conMod);
    c.hitDiceUsed[sheet.hitDie] = (c.hitDiceUsed[sheet.hitDie] ?? 0) + 1;
    applyHealing(c, sheet.maxHp, heal);
    return heal;
  }

  static int _totalHitDiceUsed(CombatState c) =>
      c.hitDiceUsed.values.fold(0, (sum, used) => sum + used);

  static void _moveLegacyHitDiceTo(CombatState c, int dieSize) {
    final legacy = c.hitDiceUsed.remove(0);
    if (legacy == null || legacy <= 0) return;
    c.hitDiceUsed[dieSize] = (c.hitDiceUsed[dieSize] ?? 0) + legacy;
  }

  static void _recoverHitDice(CombatState c, int amount) {
    var remaining = amount;
    final sizes = c.hitDiceUsed.keys.toList()..sort();
    for (final size in sizes) {
      if (remaining == 0) break;
      final used = c.hitDiceUsed[size] ?? 0;
      final recovered = min(used, remaining);
      final next = used - recovered;
      if (next == 0) {
        c.hitDiceUsed.remove(size);
      } else {
        c.hitDiceUsed[size] = next;
      }
      remaining -= recovered;
    }
  }

  // ------------------------------------------------------------ Compañeros

  /// Invoca un compañero con los PG al máximo y lo devuelve.
  ///
  /// El nivel del espacio sale de [vars], no de un parámetro aparte: es el
  /// mismo número que resuelve los PG del Corcel Sobrenatural, y tenerlo dos
  /// veces es tenerlo mal una vez.
  ///
  /// Si ya se llegó a [CompanionOption.maxActive], el más viejo se reemplaza en
  /// lugar de rechazar la invocación. Es lo que dicen las reglas: volver a
  /// lanzar Encontrar Familiar le cambia la forma al que había, y solo puede
  /// haber un cañón a la vez.
  ///
  /// [concentration] marca que lo sostiene un conjuro de concentración, y hace
  /// dos cosas: el compañero se va cuando la concentración termina, y empezarla
  /// rompe la anterior (con lo que se lleva puesto al compañero que hubiera).
  static CompanionInstance summonCompanion(
    CombatState c,
    CompanionOption option,
    Creature form,
    CreatureVars vars, {
    bool concentration = false,
    String concentratingOn = '',
  }) {
    // Antes de nada: empezar una concentración nueva rompe la que hubiera, y
    // eso puede llevarse por delante a un compañero que ya estaba en juego.
    if (concentration) startConcentration(c, concentratingOn);

    final active = c.companions.where((i) => i.optionId == option.id).toList();
    // Se retiran los más viejos hasta dejar un lugar libre para el nuevo.
    for (var i = 0; i <= active.length - option.maxActive; i++) {
      c.companions.remove(active[i]);
    }
    final instance = CompanionInstance(
      optionId: option.id,
      creatureId: form.id,
      spellLevel: vars['spellLevel'] ?? 0,
      concentration: concentration,
      currentHp: resolveCreatureInt(form.hp, vars),
    );
    c.companions.add(instance);
    return instance;
  }

  /// Las variables con que se resuelven las fórmulas de un compañero (sus PG,
  /// su ataque): las de la ficha más el nivel del espacio con que se lo
  /// convocó.
  static CreatureVars companionVars(ComputedSheet s, {int spellLevel = 0}) =>
      CreatureVars.from(
        level: s.level,
        proficiencyBonus: s.proficiencyBonus,
        abilityModifiers: s.abilityModifiers,
        spellAttackBonus: s.spellcasting?.attackBonus ?? 0,
        spellSaveDc: s.spellcasting?.saveDc ?? 0,
        spellLevel: spellLevel,
      );

  /// PG máximos de un compañero invocado, o null si su forma ya no está en el
  /// catálogo.
  static int? companionMaxHp(ComputedSheet s, CompanionInstance instance) {
    for (final option in s.companions) {
      if (option.id != instance.optionId) continue;
      final form = option.form(instance.creatureId);
      if (form == null) return null;
      return resolveCreatureInt(
        form.hp,
        companionVars(s, spellLevel: instance.spellLevel),
      );
    }
    return null;
  }

  /// Despide un compañero (o lo retira cuando fue destruido).
  static void dismissCompanion(CombatState c, CompanionInstance instance) {
    c.companions.removeWhere((i) => identical(i, instance));
  }

  /// Daña a un compañero con la misma regla que al personaje. Devuelve true si
  /// el daño lo destruyó.
  ///
  /// A 0 PG desaparece, que es lo que dicen las reglas: el Cañón Arcano, el
  /// familiar, el corcel y el homúnculo se desvanecen. Un compañero destruido
  /// no se cura ni se lleva más: se vuelve a invocar.
  ///
  /// ponytail: el Defensor de Acero se puede revivir gastando un espacio de
  /// conjuro dentro de la hora, y acá también se va. Volver a invocarlo deja el
  /// mismo resultado en la ficha; modelar el revivir pide llevar la cuenta de
  /// cuándo murió, que hoy no existe.
  static bool damageCompanion(
    CombatState c,
    CompanionInstance i,
    int amount,
  ) {
    final next = _absorbDamage(i.currentHp, i.tempHp, amount);
    i.currentHp = next.hp;
    i.tempHp = next.tempHp;
    if (i.currentHp > 0) return false;
    dismissCompanion(c, i);
    return true;
  }

  static void healCompanion(CompanionInstance i, int maxHp, int amount) {
    if (amount <= 0) return;
    i.currentHp = min(maxHp, i.currentHp + amount);
  }

  /// PG temporales de un compañero (el modo Protector del Cañón Arcano). No se
  /// acumulan, igual que los del personaje.
  static void setCompanionTempHp(CompanionInstance i, int value) {
    i.tempHp = max(0, max(i.tempHp, value));
  }

  // --------------------------------------------------------- Forma Salvaje

  /// Recurso que gasta la Forma Salvaje. El contenido lo declara con este id en
  /// los tres escalones del rasgo (niveles 2, 6 y 17).
  static const String wildShapeResourceId = 'wild_shape';

  /// Se transforma en [beast] gastando un uso de Forma Salvaje y sumando PG
  /// temporales iguales al nivel de druida, o los de Formas de Círculo.
  /// Devuelve false si no quedan usos.
  ///
  /// Solo cambia el estado: los números de la ficha los reemplaza
  /// `applyWildShape`, que es una función pura sobre la ficha ya compilada.
  static bool enterWildShape(
    CombatState c,
    ComputedSheet sheet,
    Creature beast,
  ) {
    final resource =
        sheet.resources.where((r) => r.id == wildShapeResourceId).firstOrNull;
    if (resource == null) return false;
    final used = c.resourceUsage[wildShapeResourceId] ?? 0;
    if (used >= resource.max) return false;
    c.resourceUsage[wildShapeResourceId] = used + 1;
    c.wildShapeCreatureId = beast.id;
    setTempHp(c, sheet.wildShape?.tempHpOnEnter ?? sheet.level);
    return true;
  }

  /// Estados que incluyen Incapacitado (SRD 5.2.1, glosario): Paralizado,
  /// Petrificado, Aturdido e Inconsciente dicen «tienes el estado de
  /// incapacitado».
  static const incapacitatingConditions = {
    'incapacitated',
    'paralyzed',
    'petrified',
    'stunned',
    'unconscious',
  };

  static bool isIncapacitated(CombatState c) =>
      c.conditions.any(incapacitatingConditions.contains);

  /// Marca o quita un estado del personaje. Uno que incapacita hace lo mismo
  /// que caer a 0 PG: ver [_incapacitate].
  ///
  /// Va acá y no en los chips de la ficha por lo mismo que el daño: el estado
  /// puede entrar por más de un lado, y la regla tiene que valer en todos.
  static void setCondition(
    CombatState c,
    String id,
    bool on, {
    ComputedSheet? sheet,
  }) {
    if (!on) {
      c.conditions.remove(id);
      return;
    }
    c.conditions.add(id);
    if (incapacitatingConditions.contains(id)) _incapacitate(c, sheet);
  }

  /// Lo que termina al quedar incapacitado (SRD 5.2.1): la Forma Salvaje, los
  /// estados activables («la Furia termina si recibes el estado de
  /// incapacitado») y la concentración («pierdes la concentración»), que se
  /// lleva a los compañeros que la sostenían.
  ///
  /// Quitar el estado después no devuelve nada: el conjuro terminó, como en
  /// la mesa.
  ///
  /// Los estados que no terminan así (la Forma Grande) siguen. Saber cuáles
  /// pide la [sheet]; sin ella se apagan todos, que es lo que pasa con la
  /// Furia y nunca deja un estado prendido de más.
  static void _incapacitate(CombatState c, ComputedSheet? sheet) {
    c.wildShapeCreatureId = null;
    final survive = {
      for (final m in sheet?.activeModes ?? const <ActiveMode>[])
        if (!m.endsWhenIncapacitated) m.id,
    };
    c.activeModes.removeWhere((id, _) => !survive.contains(id));
    endConcentration(c);
  }

  /// Prende el estado activable [modeId] (la Furia), con la [variant] elegida
  /// si tiene. Gasta un uso de su recurso; devuelve false sin tocar nada si
  /// no quedan usos, si el estado no está disponible (armadura pesada) o si
  /// el personaje no lo tiene.
  ///
  /// Prenderlo de nuevo estando prendido no gasta otro uso: solo cambia la
  /// variante, que es lo que haría alguien que se equivocó de animal.
  ///
  /// Un estado de varias variantes ([ActiveMode.multiSelect]) las recibe en
  /// [variants], gasta un uso por cada una y no se cambia una vez prendido:
  /// la Revelación en Carne se elige al transformarse.
  static bool activateMode(
    CombatState c,
    ComputedSheet sheet,
    String modeId, {
    String? variant,
    List<String> variants = const [],
  }) {
    final mode = sheet.activeModes.where((m) => m.id == modeId).firstOrNull;
    if (mode == null || !mode.available) return false;
    final chosen = {if (variant != null) variant, ...variants}.toList();
    if (chosen.any((id) => !mode.variants.any((v) => v.id == id))) {
      return false;
    }
    if (mode.multiSelect) {
      if (chosen.isEmpty || c.activeModes.containsKey(modeId)) return false;
    } else if (chosen.length > 1) {
      return false;
    }
    final cost = mode.multiSelect ? chosen.length : 1;
    if (!c.activeModes.containsKey(modeId)) {
      // Lo que pasa al activarlo, solo la primera vez: cambiar de variante
      // con el estado ya prendido no da PG temporales de nuevo.
      setTempHp(c, mode.tempHpOnActivate);
      c.conditions.removeAll(mode.endsConditions);
      final key = mode.resourceKey;
      if (key != null) {
        final resource = sheet.resources.where((r) => r.key == key).firstOrNull;
        if (resource == null) return false;
        final used = c.resourceUsage[key] ?? 0;
        if (used + cost > resource.max) return false;
        c.resourceUsage[key] = used + cost;
      }
    }
    c.activeModes[modeId] = chosen.isEmpty ? null : chosen.join(',');
    return true;
  }

  /// Apaga el estado. No devuelve el uso: la Furia terminada antes de tiempo
  /// sigue gastada. Con la [sheet] apaga también los que dependen de él (el
  /// Poder de lo Salvaje termina con la Furia); sin ella esos quedan
  /// guardados pero la ficha los muestra apagados.
  static void deactivateMode(
    CombatState c,
    String modeId, {
    ComputedSheet? sheet,
  }) {
    c.activeModes.remove(modeId);
    for (final m in sheet?.activeModes ?? const <ActiveMode>[]) {
      if (m.requiresMode == modeId) c.activeModes.remove(m.id);
    }
  }

  /// Vuelve a la forma propia. Los PG temporales no se quitan: son PG
  /// temporales normales y duran hasta que se gastan o hasta el descanso largo.
  static void leaveWildShape(CombatState c) => c.wildShapeCreatureId = null;

  /// Marca una salvación de muerte (éxito o fallo). Devuelve un resultado:
  /// 'stable' a 3 éxitos, 'dead' a 3 fallos, o null si sigue en juego.
  static String? recordDeathSave(CombatState c, {required bool success}) {
    if (success) {
      c.deathSuccesses = min(3, c.deathSuccesses + 1);
      if (c.deathSuccesses >= 3) {
        c.deathSuccesses = 0;
        c.deathFailures = 0;
        return 'stable';
      }
    } else {
      c.deathFailures = min(3, c.deathFailures + 1);
      if (c.deathFailures >= 3) return 'dead';
    }
    return null;
  }
}
