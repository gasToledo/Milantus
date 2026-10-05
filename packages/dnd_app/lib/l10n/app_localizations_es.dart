// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Milantus — Asistente de Aventuras';

  @override
  String languageSelectorLabel(String name) {
    return 'Idioma: $name';
  }

  @override
  String get languageSelectorTooltip => 'Cambiar el idioma';

  @override
  String get settingsLoadError => 'No se pudo cargar la configuración';

  @override
  String get settingsSaveError => 'No se pudieron guardar los ajustes';

  @override
  String get settingsTitle => 'Ajustes · Generación de imágenes';

  @override
  String get settingsLoading => 'Cargando ajustes…';

  @override
  String get settingsNoProviders =>
      'Este servidor no tiene ningún proveedor de generación configurado. Igual podés subir tu propio retrato desde la ficha.';

  @override
  String get settingsProviderLabel => 'Proveedor de retratos:';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonSaving => 'Guardando…';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonUndo => 'Deshacer';

  @override
  String get saveStateFailed => 'No se guardó';

  @override
  String get saveStateSaved => 'Guardado';

  @override
  String saveStateLabel(String state) {
    return 'Estado del guardado: $state';
  }

  @override
  String get commonUse => 'Usar';

  @override
  String get commonRestore => 'Restaurar';

  @override
  String get commonRange => 'Alcance';

  @override
  String get themeLight => 'Tema claro';

  @override
  String get themeSystem => 'Seguir el tema del sistema';

  @override
  String get themeDark => 'Tema oscuro';

  @override
  String get errorShowDetails => 'Ver detalles';

  @override
  String get renameTitle => 'Editar nombre';

  @override
  String get renameLabel => 'Nombre del personaje';

  @override
  String armorClassLabel(Object value) {
    return 'Clase de armadura: $value';
  }

  @override
  String abilityTile(String name, String mod, Object score) {
    return '$name: modificador $mod, puntuación $score';
  }

  @override
  String abilityTileProficient(String name, String mod, Object score) {
    return '$name: modificador $mod, puntuación $score, competente en salvación';
  }

  @override
  String abilityScoreShort(Object score) {
    return 'Punt. $score';
  }

  @override
  String get saveShort => 'SALV';

  @override
  String saveShortValue(String bonus) {
    return 'SALV $bonus';
  }

  @override
  String emblemLabel(String name) {
    return 'Emblema de $name';
  }

  @override
  String portraitLabel(String name) {
    return 'Retrato de $name';
  }

  @override
  String helpWhatItDoes(String name) {
    return 'Ver qué hace $name';
  }

  @override
  String usesAvailable(int filled, int max) {
    return '$filled de $max usos disponibles';
  }

  @override
  String get sourceHomebrew => 'Propio';

  @override
  String sourceBadgeLabel(String source) {
    return 'Procedencia: $source';
  }

  @override
  String get innateAtWill => 'a voluntad';

  @override
  String get innateOncePerLongRest => 'una vez por descanso largo';

  @override
  String get innateOncePerShortRest => 'una vez por descanso corto';

  @override
  String get innateProficiencyBonus =>
      'tantas veces como tu bono de competencia';

  @override
  String get innateAbilityModifier =>
      'tantas veces como el modificador de la característica';

  @override
  String effectProficiency(String name) {
    return 'Competencia: $name';
  }

  @override
  String effectSave(String ability) {
    return 'Salvación: $ability';
  }

  @override
  String effectSaves(String parts) {
    return 'Salvaciones $parts';
  }

  @override
  String effectModOf(String ability) {
    return '+ mod. de $ability';
  }

  @override
  String get effectProficiencyBonusPart => '+ bonif. por competencia';

  @override
  String effectLanguage(String name) {
    return 'Idioma: $name';
  }

  @override
  String effectResistance(String name) {
    return 'Resistencia: $name';
  }

  @override
  String effectImmunity(String name) {
    return 'Inmunidad: $name';
  }

  @override
  String effectDarkvision(Object range) {
    return 'Visión en la oscuridad: $range pies';
  }

  @override
  String effectSpeedBonus(Object feet) {
    return 'Velocidad +$feet pies';
  }

  @override
  String effectSpeedSet(Object feet) {
    return 'Velocidad = $feet pies';
  }

  @override
  String effectAcBonus(Object amount) {
    return 'CA +$amount';
  }

  @override
  String effectInitiative(String parts) {
    return 'Iniciativa $parts';
  }

  @override
  String effectMaxHpPerLevel(Object perLevel) {
    return 'PG máx +$perLevel por nivel';
  }

  @override
  String effectMaxHpFlat(Object amount) {
    return 'PG máx +$amount';
  }

  @override
  String effectPassive(String name) {
    return 'Pasiva: $name';
  }

  @override
  String effectWeaponMastery(Object count) {
    return 'Maestrías de arma: $count';
  }

  @override
  String effectExtraAttack(Object extra) {
    return 'Ataque adicional +$extra';
  }

  @override
  String effectFeat(String name) {
    return 'Dote: $name';
  }

  @override
  String get effectFeatChoice => 'a elección';

  @override
  String effectSpell(String name, String use) {
    return 'Conjuro: $name ($use)';
  }

  @override
  String effectAlwaysPrepared(String name) {
    return 'Siempre preparado: $name';
  }

  @override
  String effectAddedToList(String name) {
    return 'Se suma a tu lista: $name';
  }

  @override
  String get spellActionAction => 'Acción';

  @override
  String get spellActionBonus => 'Acción adicional';

  @override
  String get spellActionReaction => 'Reacción';

  @override
  String get spellCantrip => 'Truco';

  @override
  String spellLevel(Object level) {
    return 'Nivel $level';
  }

  @override
  String get spellCastingTime => 'Lanzamiento';

  @override
  String get spellComponents => 'Componentes';

  @override
  String get spellDuration => 'Duración';

  @override
  String creatureSpellWith(String name) {
    return 'Con $name';
  }

  @override
  String get creatureActions => 'Acciones';

  @override
  String get creatureBonusActions => 'Acciones adicionales';

  @override
  String get creatureReactions => 'Reacciones';

  @override
  String get creatureLegendaryActions => 'Acciones legendarias';

  @override
  String creatureLegendaryActionsPerRound(Object uses) {
    return 'Acciones legendarias · $uses por ronda';
  }

  @override
  String get creatureAcShort => 'CA';

  @override
  String get hitPoints => 'Puntos de golpe';

  @override
  String get hitPointsShort => 'PG';

  @override
  String hitPointsLabel(Object value) {
    return 'Puntos de golpe: $value';
  }

  @override
  String get initiative => 'Iniciativa';

  @override
  String get challengeRating => 'Valor de desafío';

  @override
  String get challengeRatingShort => 'VD';

  @override
  String challengeRatingSemantics(String value) {
    return 'Valor de desafío: $value';
  }

  @override
  String get passivePerceptionShort => 'Perc. pasiva';

  @override
  String passivePerceptionLabel(Object value) {
    return 'Percepción pasiva: $value';
  }

  @override
  String get creatureSpeed => 'Velocidad';

  @override
  String get creatureSkills => 'Habilidades';

  @override
  String get creatureSenses => 'Sentidos';

  @override
  String get creatureLanguages => 'Idiomas';

  @override
  String get creatureDefenses => 'Defensas';

  @override
  String get creatureTraits => 'Rasgos';

  @override
  String get creatureToHit => 'Acierto';

  @override
  String get creatureDamage => 'Daño';

  @override
  String creatureSpellSaveDc(Object dc) {
    return 'CD $dc';
  }

  @override
  String creatureSpellAttack(String bonus) {
    return 'Ataque $bonus';
  }

  @override
  String get creatureAtWill => 'A voluntad';

  @override
  String creatureUsesPerDay(Object uses) {
    return '$uses/día cada uno';
  }

  @override
  String creatureCastAtLevel(Object level) {
    return 'Se lanza a nivel $level';
  }

  @override
  String get commonCannotUndo => 'Esta acción no se puede deshacer.';

  @override
  String get commonDelete => 'Borrar';

  @override
  String get commonImport => 'Importar';

  @override
  String commonLevel(Object level) {
    return 'Nivel $level';
  }

  @override
  String get transferTitle => 'Importar / Exportar';

  @override
  String get transferImport => 'Importar…';

  @override
  String get transferExportBackup => 'Exportar respaldo completo';

  @override
  String deleteCharacterTitle(String name) {
    return '¿Borrar a $name?';
  }

  @override
  String get exportingCharacter => 'Exportando personaje…';

  @override
  String get exportCharacterError => 'No se pudo exportar el personaje';

  @override
  String get creatingBackup => 'Creando respaldo…';

  @override
  String get backupError => 'No se pudo crear el respaldo';

  @override
  String get importPickTitle => 'Elegí un respaldo (.zip)';

  @override
  String get importBackupTitle => 'Importar respaldo';

  @override
  String importBackupBody(String fileName) {
    return 'Se van a agregar los personajes (y el homebrew y las preferencias, si el respaldo los incluye) de \"$fileName\" a esta cuenta. Los personajes existentes no se tocan; un id repetido se guarda como copia nueva.';
  }

  @override
  String get importingBackup => 'Importando respaldo…';

  @override
  String importDone(int characters, int images) {
    String _temp0 = intl.Intl.pluralLogic(
      characters,
      locale: localeName,
      other: '$characters personajes',
      one: '1 personaje',
    );
    String _temp1 = intl.Intl.pluralLogic(
      images,
      locale: localeName,
      other: '$images imágenes',
      one: '1 imagen',
    );
    return 'Importados $_temp0 y $_temp1.';
  }

  @override
  String get importError => 'No se pudo importar';

  @override
  String get operationBusy => 'Ya hay una operación en curso.';

  @override
  String get rosterEmpty =>
      'Todavía no hay personajes en esta cuenta.\nCreá el primero, traé los que ya tenías, o mirá cómo es una ficha con uno de ejemplo.';

  @override
  String get rosterCreate => 'Crear personaje';

  @override
  String get rosterTryExample => 'Probar con uno de ejemplo';

  @override
  String rosterNoMatch(String query) {
    return 'Ningún personaje coincide con «$query».\nSe busca por nombre, clase y especie.';
  }

  @override
  String get rosterClearSearch => 'Limpiar búsqueda';

  @override
  String get rosterTitle => 'Mis personajes';

  @override
  String rosterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personajes',
      one: '1 personaje',
    );
    return '$_temp0';
  }

  @override
  String rosterFallen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count caídos',
      one: '1 caído',
    );
    return '$_temp0';
  }

  @override
  String get rosterSearchHint => 'Buscar por nombre, clase o especie…';

  @override
  String get rosterSort => 'Ordenar';

  @override
  String get sortManual => 'Manual';

  @override
  String get sortRecent => 'Más recientes';

  @override
  String get sortName => 'Nombre';

  @override
  String get sortLevel => 'Nivel';

  @override
  String get sortClass => 'Clase';

  @override
  String get sortSaveError => 'No se pudo guardar el orden de tus personajes';

  @override
  String get sortManualHint =>
      'Orden manual: usá «Mover antes» y «Mover después» en el menú de cada tarjeta, o arrastrala sobre otra.';

  @override
  String get saveLatestError => 'No se pudieron guardar los últimos cambios';

  @override
  String get sessionExpiredTitle => 'La sesión terminó';

  @override
  String get sessionExpiredBody =>
      'Los cambios que todavía no se pudieron guardar siguen en pantalla. Iniciá sesión de nuevo para seguir editando.';

  @override
  String get sessionSignIn => 'Iniciar sesión';

  @override
  String get appTagline => 'Asistente de Aventuras';

  @override
  String get navCharacters => 'Personajes';

  @override
  String get navCodex => 'Códice';

  @override
  String get dmModeButton => 'Modo DM';

  @override
  String get accountSignOut => 'Cerrar sesión';

  @override
  String get signOutError => 'No se pudo cerrar la sesión';

  @override
  String get characterFallenBadge => 'CAÍDO';

  @override
  String get hpLabelFallen => 'SIN PUNTOS DE GOLPE';

  @override
  String get hpLabelCritical => 'PG CRÍTICOS';

  @override
  String get hpLabelNormal => 'PUNTOS DE GOLPE';

  @override
  String cardActionsTooltip(String name) {
    return 'Acciones de $name';
  }

  @override
  String get cardFavorite => 'Marcar como favorito';

  @override
  String get cardUnfavorite => 'Quitar de favorito';

  @override
  String get cardMoveBefore => 'Mover antes';

  @override
  String get cardMoveAfter => 'Mover después';

  @override
  String get cardRename => 'Renombrar';

  @override
  String get cardExport => 'Exportar';

  @override
  String get statSpeedShort => 'VEL';

  @override
  String get unitFeetSuffix => ' pies';

  @override
  String statSpeedLabel(Object speed) {
    return 'Velocidad: $speed pies';
  }

  @override
  String get statInitiativeShort => 'INIC';

  @override
  String statInitiativeLabel(String bonus) {
    return 'Iniciativa: $bonus';
  }

  @override
  String get tabCharacter => 'Personaje';

  @override
  String get tabCombat => 'Combate';

  @override
  String get tabInventory => 'Inventario';

  @override
  String get tabCampaign => 'Campaña';

  @override
  String get tabJournal => 'Diario';

  @override
  String sheetHeaderTitle(String name, Object level) {
    return '$name · Nivel $level';
  }

  @override
  String get levelUpAction => 'Subir nivel';

  @override
  String get levelMaxReached => 'Nivel máximo';

  @override
  String get portraitClose => 'Cerrar el retrato';

  @override
  String get navBackToNpc => 'Volver al PNJ';

  @override
  String sheetClassSummary(String summary, Object level) {
    return '$summary · nivel $level';
  }

  @override
  String get navPortrait => 'Retrato';

  @override
  String get navShare => 'Compartir';

  @override
  String get turnNext => 'Preparate, seguís vos.';

  @override
  String get turnActive => 'Es tu turno.';

  @override
  String get commonExpand => 'Desplegar';

  @override
  String get commonCollapse => 'Plegar';

  @override
  String get campaignStateActive => 'En curso';

  @override
  String get campaignStatePaused => 'En pausa';

  @override
  String get campaignStateFinished => 'Terminada';

  @override
  String get campaignsLoadError => 'No se pudieron leer tus campañas.';

  @override
  String get campaignsLoading => 'Cargando tus campañas…';

  @override
  String get campaignEmpty =>
      'Este personaje todavía no está en ninguna campaña.\nCompartilo con tu DM y acá va a aparecer lo que jueguen.';

  @override
  String campaignPartyAlso(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'En la mesa también juegan $names.',
      one: 'En la mesa también juega $names.',
    );
    return '$_temp0';
  }

  @override
  String get campaignNoChapter => 'Sin capítulo';

  @override
  String get campaignBattles => 'Batallas';

  @override
  String roundsCount(int rounds) {
    String _temp0 = intl.Intl.pluralLogic(
      rounds,
      locale: localeName,
      other: '$rounds rondas',
      one: '1 ronda',
    );
    return '$_temp0';
  }

  @override
  String get campaignNoBattles => 'Todavía no pelearon ninguna.';

  @override
  String get battleAlone => 'Solo';

  @override
  String battleWith(String names) {
    return 'Con $names';
  }

  @override
  String get battleGeneric => 'Una pelea';

  @override
  String battleAgainst(String names) {
    return 'Contra $names';
  }

  @override
  String get enemyOne => 'un enemigo';

  @override
  String enemiesCount(Object count) {
    return '$count enemigos';
  }

  @override
  String get battleNoEnemies => 'sin enemigos';

  @override
  String get battleNoneDown => 'no cayó ninguno';

  @override
  String get battleOneDown => 'cayó';

  @override
  String get battleAllDown => 'cayeron todos';

  @override
  String battleSomeDown(Object down, Object total) {
    return 'cayeron $down de $total';
  }

  @override
  String get campaignClosedChapters => 'Capítulos cerrados';

  @override
  String get campaignNoClosedChapters =>
      'Todavía no cerraron ninguno. Cuando pase, acá va a quedar anotado lo que se repartió.';

  @override
  String get campaignNoRewards => 'Sin recompensas';

  @override
  String campaignYouTook(String grants) {
    return 'Te llevaste $grants';
  }

  @override
  String listAnd(String head, String last) {
    return '$head y $last';
  }

  @override
  String get commonBack => 'Volver';

  @override
  String hpMaxSuffix(Object max) {
    return '/ $max PG';
  }

  @override
  String get deathSaves => 'Salvaciones de muerte';

  @override
  String get combatAmount => 'Cantidad';

  @override
  String get combatHeal => 'Curar';

  @override
  String get combatTempHp => 'PG temp';

  @override
  String get combatStabilized => '¡Estabilizado!';

  @override
  String get combatSuccessPlus => '+Éxito';

  @override
  String get combatCharacterDied => 'El personaje ha muerto.';

  @override
  String get combatFailurePlus => '+Fallo';

  @override
  String get combatNoArmor => 'Sin armadura';

  @override
  String get combatShield => 'escudo';

  @override
  String get combatDefense => 'Defensa';

  @override
  String combatResistances(String list) {
    return 'Resistencias: $list';
  }

  @override
  String combatImmunities(String list) {
    return 'Inmunidades: $list';
  }

  @override
  String get shortRestNoRestore =>
      'Descanso corto. No cura PG: gastá dados de golpe para curarte.';

  @override
  String shortRestRestored(String list) {
    return 'Descanso corto: recuperaste $list. Para curarte, gastá dados de golpe.';
  }

  @override
  String get longRestBase => 'PG al máximo y recursos recargados';

  @override
  String longRestExhaustion(Object level) {
    return 'cansancio a nivel $level';
  }

  @override
  String get longRestInspiration => 'ganaste Inspiración Heroica';

  @override
  String longRestItemsRecharged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count objetos mágicos recuperaron cargas',
      one: '1 objeto mágico recuperó cargas',
    );
    return '$_temp0';
  }

  @override
  String longRestSummary(String list) {
    return 'Descanso largo: $list.';
  }

  @override
  String get combatResourcesTitle => 'Recursos y descansos';

  @override
  String get combatRestExplainer =>
      'El descanso corto no cura PG: recarga recursos de recarga corta. Para curarte, gastá dados de golpe.';

  @override
  String get restShort => 'Descanso corto';

  @override
  String get restLong => 'Descanso largo';

  @override
  String combatHitDie(Object left, Object total) {
    return 'Dado de golpe ($left/$total)';
  }

  @override
  String saveDc(Object dc) {
    return 'CD $dc';
  }

  @override
  String saveDcAbility(Object dc, String ability) {
    return 'CD $dc de $ability';
  }

  @override
  String combatPointsOf(Object left, Object max) {
    return '$left de $max puntos';
  }

  @override
  String get verbSpend => 'gastar';

  @override
  String get verbRecover => 'recuperar';

  @override
  String combatPointsPrompt(String verb, Object limit) {
    return 'Puntos a $verb (hasta $limit)';
  }

  @override
  String get combatAttacks => 'Ataques';

  @override
  String combatMastery(String name) {
    return 'Maestría: $name';
  }

  @override
  String combatRangeValue(String range) {
    return 'Alcance $range';
  }

  @override
  String get combatOffHand => 'Mano secundaria';

  @override
  String wildShapeAs(String name) {
    return 'Transformado en $name';
  }

  @override
  String get wildShapeTitle => 'Forma Salvaje';

  @override
  String get wildShapeAddForms => 'Anotar';

  @override
  String get wildShapeNoForms => 'Todavía no anotaste ninguna forma.';

  @override
  String creatureLine3(String kind, Object ac, String speed) {
    return '$kind · CA $ac · $speed';
  }

  @override
  String creatureLine2(String kind, Object ac) {
    return '$kind · CA $ac';
  }

  @override
  String get wildShapeTransform => 'Transformarse';

  @override
  String wildShapeDone(String name, Object level) {
    return 'Te transformaste en $name: +$level PG temporales.';
  }

  @override
  String get wildShapeNoUses => 'No te quedan usos de Forma Salvaje.';

  @override
  String wildShapeKnownTitle(Object chosen, Object total) {
    return 'Formas conocidas ($chosen/$total)';
  }

  @override
  String get companionsTitle => 'Compañeros';

  @override
  String get companionHpAmount => 'Cantidad de PG';

  @override
  String get companionSummon => 'Invocar';

  @override
  String get companionSummonAnother => 'Invocar otro';

  @override
  String get companionNone => 'No hay ninguno invocado.';

  @override
  String get companionSummonAnyway => 'Invocar igual';

  @override
  String get companionLimitOneTitle => 'Ya tenés uno en juego';

  @override
  String get companionLimitMaxTitle => 'Llegaste al máximo';

  @override
  String companionLimitOneBody(String going) {
    return 'Invocar otro hace desaparecer a $going, con los puntos de golpe que tenga.';
  }

  @override
  String companionLimitMaxBody(Object max, String going) {
    return 'Ya tenés $max. Invocar otro hace desaparecer al más viejo, $going.';
  }

  @override
  String get companionPickForm => 'Elegí la forma';

  @override
  String companionNoSlots(Object level) {
    return 'No te quedan espacios de nivel $level o más.';
  }

  @override
  String get companionHowSummon => 'Cómo lo invocás';

  @override
  String get companionNoSlotSpend => 'Sin gastar espacio';

  @override
  String companionFreeLeft(String name, Object left, Object max) {
    return '$name: quedan $left de $max';
  }

  @override
  String companionSlotsAvailable(Object left, Object total) {
    return '$left de $total disponibles';
  }

  @override
  String companionNoteSlot(Object level) {
    return 'gastaste un espacio de nivel $level';
  }

  @override
  String companionNoteFree(String name) {
    return 'sin gastar espacio, por $name';
  }

  @override
  String get companionNoteBroke => 'perdiste la concentración anterior';

  @override
  String get companionNoteConcentrating => 'quedás concentrado en él';

  @override
  String companionSummoned(String name) {
    return '$name invocado.';
  }

  @override
  String companionSummonedNotes(String name, String notes) {
    return '$name invocado: $notes.';
  }

  @override
  String get companionGone => 'Esta criatura ya no está en el catálogo.';

  @override
  String get companionDismiss => 'Despedir';

  @override
  String acValue(Object value) {
    return 'CA $value';
  }

  @override
  String companionSlotLevel(Object level) {
    return 'Espacio de nivel $level';
  }

  @override
  String get concentration => 'Concentración';

  @override
  String hpFraction(Object current, Object max) {
    return '$current / $max PG';
  }

  @override
  String companionDestroyed(String name) {
    return '$name fue destruido.';
  }

  @override
  String get savesTitle => 'Salvaciones';

  @override
  String get exhaustion => 'Cansancio';

  @override
  String exhaustionRules(Object max) {
    return 'Cada nivel resta 2 a las pruebas de característica, salvaciones, tiradas de ataque e iniciativa, y 5 pies a la velocidad. Al nivel $max el personaje muere.\n\nLa ficha ya trae la penalización aplicada en todos sus números: no la restes de nuevo. También le entra a las salvaciones de muerte, aunque esas no lleven número.\n\nUn descanso largo baja un nivel.';
  }

  @override
  String get combatState => 'Estado';

  @override
  String exhaustionPenalty(Object rolls, Object feet) {
    return '−$rolls a las tiradas · −$feet pies';
  }

  @override
  String get exhaustionLower => 'Bajar un nivel de cansancio';

  @override
  String get exhaustionRaise => 'Subir un nivel de cansancio';

  @override
  String exhaustionDeath(Object max) {
    return 'Cansancio nivel $max: tu personaje muere.';
  }

  @override
  String exhaustionNote(Object max) {
    return 'Nivel $max: tu personaje muere. La ficha no lo aplica ni te toca los PG — esa decisión es de la mesa.';
  }

  @override
  String get inspirationUse =>
      'Repetí un dado apenas lo tirás y quedate con el resultado nuevo';

  @override
  String get inspirationLongRest =>
      'La recuperás al terminar un descanso largo';

  @override
  String get inspirationGrant => 'Marcala cuando el DM te la dé';

  @override
  String get inspirationSpend => 'Gastar la Inspiración Heroica';

  @override
  String get inspirationMark => 'Marcar que la tenés';

  @override
  String get heroicInspiration => 'Inspiración Heroica';

  @override
  String get inspirationHave => 'LA TENÉS';

  @override
  String get inspirationSpent => 'GASTADA';

  @override
  String get conditionsTitle => 'Condiciones';

  @override
  String combatHitDieHealed(Object hp) {
    return 'Recuperaste $hp PG (dado de golpe)';
  }

  @override
  String wildShapeUses(Object left, Object max) {
    return 'Usos: $left de $max';
  }

  @override
  String wildShapeForms(Object chosen, Object total) {
    return 'Formas: $chosen de $total';
  }

  @override
  String exhaustionLevelOf(Object level, Object max) {
    return 'Cansancio: nivel $level de $max';
  }

  @override
  String get replaceProficiency => 'Competencia reemplazable';

  @override
  String get replaceChoice => 'Elección reemplazable';

  @override
  String get replaceSpells => 'Conjuros reemplazables';

  @override
  String get sheetWarnings => 'Advertencias';

  @override
  String get sheetResolve => 'Resolver';

  @override
  String get replaceableNoticeBody =>
      'Este rasgo permite cambiar la elección que ya hiciste.';

  @override
  String get sheetChange => 'Cambiar';

  @override
  String get pickExpertiseTitle => 'Elegir Pericia';

  @override
  String get pickProficienciesTitle => 'Elegir competencias';

  @override
  String get pickProficienciesHint =>
      'Las opciones que ya tenés por otra vía quedan bloqueadas. En los cupos de Pericia es al revés: solo se ofrecen las habilidades en las que ya sos competente, y duplicás el bonificador en ellas.';

  @override
  String get pickSizeTitle => 'Elegir tamaño';

  @override
  String get pickSizeHint =>
      'Esta especie abarca cuerpos de tamaños distintos: elegí el de tu personaje.';

  @override
  String get pickLineageTitle => 'Elegir linaje';

  @override
  String get pickLineageHint =>
      'El linaje decide los rasgos que aporta la especie.';

  @override
  String get pickSpellAbilityTitle => 'Elegir aptitud mágica';

  @override
  String get pickLineageSpellAbilityHint =>
      'Se usa para la CD y los ataques de los conjuros del linaje.';

  @override
  String pickFeatSpellAbilityTitle(String name) {
    return 'Aptitud mágica de $name';
  }

  @override
  String get pickFeatSpellAbilityHint =>
      'Se usa para la CD y los ataques de los conjuros de esta dote.';

  @override
  String get pickFeaturesTitle => 'Elegir rasgos';

  @override
  String get pickNoOptions => 'No hay opciones disponibles todavía.';

  @override
  String get pickSpellsTitle => 'Elegir conjuros';

  @override
  String get pickKnownSpellHint =>
      'Elegí uno que ya conocés: no se suma a tus conjuros, le agrega el bono al daño.';

  @override
  String get pickNoSpells => 'No hay conjuros disponibles para este rasgo.';

  @override
  String get pickLanguagesTitle => 'Elegir idiomas';

  @override
  String pickLanguagesIntro(String language) {
    return 'Todo personaje sabe $language, que no ocupa una elección.';
  }

  @override
  String pickLanguagesOrigin(Object chosen, Object total) {
    return 'De tu origen ($chosen/$total)';
  }

  @override
  String get identityAlignment => 'Alineamiento';

  @override
  String get identityCreatureType => 'Tipo de criatura';

  @override
  String get identitySize => 'Tamaño';

  @override
  String get identityBackground => 'Trasfondo';

  @override
  String get identityTrait => 'Rasgo';

  @override
  String get identityTitle => 'Identidad';

  @override
  String get abilitiesTitle => 'Características';

  @override
  String get abilitiesHintLead => 'La cifra grande es el modificador. ';

  @override
  String get abilitiesHintTail =>
      ' marca las salvaciones competentes; tocá una placa para ver de dónde sale.';

  @override
  String get unarmoredTitle => 'Defensa sin armadura';

  @override
  String get unarmoredFormula => 'Fórmula de CA';

  @override
  String get proficienciesTitle => 'Competencias';

  @override
  String get armorUpper => 'ARMADURA';

  @override
  String get passivePerception => 'Percepción pasiva';

  @override
  String get darkvision => 'Visión en la oscuridad';

  @override
  String get skillsLegendProficient => 'Competente';

  @override
  String get skillsLegendExpertise => 'Pericia · bonificador duplicado';

  @override
  String get skillExpertiseBadge => 'PERICIA';

  @override
  String get traitsAndFeatsTitle => 'Rasgos y dotes';

  @override
  String get statArmor => 'Armadura';

  @override
  String exhaustionSpeed(Object feet) {
    return 'Cansancio −$feet pies';
  }

  @override
  String get statProficiency => 'Competencia';

  @override
  String get breakdownWhereFrom => 'De dónde sale';

  @override
  String get breakdownDexModifier => 'Modificador de Destreza';

  @override
  String get breakdownOtherTrait => 'Otro rasgo';

  @override
  String exhaustionLevel(Object level) {
    return 'Cansancio nivel $level';
  }

  @override
  String get breakdownAssigned => 'Asignada en la creación';

  @override
  String get breakdownScore => 'Puntuación';

  @override
  String get breakdownModifier => 'Modificador';

  @override
  String get breakdownWhatToRoll => 'Qué se tira con esto';

  @override
  String get breakdownSave => 'Salvación';

  @override
  String get breakdownSaveProficient => 'Salvación (competente)';

  @override
  String breakdownSkillExpertise(String skill) {
    return '$skill (pericia)';
  }

  @override
  String breakdownIncludes(String amount, String source) {
    return 'incluye $amount de $source';
  }

  @override
  String get breakdownAbilityChecks => 'Pruebas de característica';

  @override
  String breakdownExhaustion(Object penalty, Object level) {
    return 'incluye −$penalty por cansancio nivel $level';
  }

  @override
  String get breakdownSpellAttack => 'Ataque con conjuros';

  @override
  String get breakdownSaveDc => 'CD de salvación';

  @override
  String breakdownFooter(Object bonus, Object level, String check) {
    return 'Competencia +$bonus a nivel $level, ya incluida arriba. Solo se listan las habilidades en las que sos competente: el resto tira con la prueba de característica ($check).';
  }

  @override
  String get commonAdd => 'Agregar';

  @override
  String get commonBuy => 'Comprar';

  @override
  String get commonSell => 'Vender';

  @override
  String get commonBag => 'Bolsa';

  @override
  String get kindWeapon => 'Arma';

  @override
  String get kindArmor => 'Armadura';

  @override
  String get kindAmmunition => 'Munición';

  @override
  String get kindFocus => 'Canalizador';

  @override
  String get kindMagicItem => 'Objeto mágico';

  @override
  String get kindTool => 'Herramienta';

  @override
  String get kindContainer => 'Contenedor';

  @override
  String get kindPack => 'Paquete';

  @override
  String get kindGear => 'Equipo';

  @override
  String get kindShield => 'Escudo';

  @override
  String get groupWeapons => 'Armas';

  @override
  String get groupArmor => 'Armaduras';

  @override
  String get groupFocuses => 'Canalizadores';

  @override
  String get groupMagicItems => 'Objetos mágicos';

  @override
  String get groupTools => 'Herramientas';

  @override
  String get groupContainers => 'Contenedores';

  @override
  String get groupPacks => 'Paquetes';

  @override
  String get catalogNotInCatalog => 'No está en el catálogo';

  @override
  String get filterAll => 'Todos';

  @override
  String get filterEquipped => 'Equipados';

  @override
  String get filterMagic => 'Mágicos';

  @override
  String get coinCopper => 'cobre';

  @override
  String get coinSilver => 'plata';

  @override
  String get coinElectrum => 'electro';

  @override
  String get coinGold => 'oro';

  @override
  String get coinPlatinum => 'platino';

  @override
  String get coinAbbrCopper => 'pc';

  @override
  String get coinAbbrSilver => 'pp';

  @override
  String get coinAbbrElectrum => 'pe';

  @override
  String get coinAbbrGold => 'po';

  @override
  String get coinAbbrPlatinum => 'ppt';

  @override
  String catalogBundleOf(Object size) {
    return 'paquete de $size';
  }

  @override
  String get catalogAttunement => 'sintonización';

  @override
  String catalogMissing(String amount) {
    return 'te faltan $amount';
  }

  @override
  String catalogShortBy(String amount) {
    return 'Faltan $amount';
  }

  @override
  String get catalogAddTitle => 'Agregar objeto';

  @override
  String get catalogSearchHint => 'Buscar objeto…';

  @override
  String get catalogNoMatches => 'Sin coincidencias.';

  @override
  String catalogAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count objetos agregados a la mochila.',
      one: '1 objeto agregado a la mochila.',
    );
    return '$_temp0';
  }

  @override
  String get tradeUnitBundle => 'paquete';

  @override
  String get tradeUnitItem => 'unidad';

  @override
  String tradeBundles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paquetes',
      one: '1 paquete',
    );
    return '$_temp0';
  }

  @override
  String tradeUnitsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unidades',
      one: '1 unidad',
    );
    return '$_temp0';
  }

  @override
  String get tradeQuantity => 'Cantidad';

  @override
  String tradeTotalUnits(Object count) {
    return '$count en total';
  }

  @override
  String tradeLeft(Object count) {
    return 'te quedan $count';
  }

  @override
  String get tradeOneLess => 'Uno menos';

  @override
  String get tradeOneMore => 'Uno más';

  @override
  String tradeBuyPrice(String unit) {
    return 'Precio por $unit';
  }

  @override
  String tradeSellPrice(String unit) {
    return 'Te pagan por $unit';
  }

  @override
  String tradeCatalogPrice(String price) {
    return 'Catálogo: $price';
  }

  @override
  String tradeSuggested(String price) {
    return 'Sugerido: la mitad del catálogo, $price.';
  }

  @override
  String get tradeBackCatalog => 'Volver al del catálogo';

  @override
  String get tradeBackSuggested => 'Volver al sugerido';

  @override
  String get tradeTotalBuy => 'TOTAL';

  @override
  String get tradeTotalSell => 'COBRÁS';

  @override
  String tradeShort(String amount) {
    return 'Te faltan $amount. Si el DM te lo regala o te lo fía, cerrá y usá «Agregar».';
  }

  @override
  String tradePaidFrom(String coins) {
    return 'Sale de la bolsa: $coins.';
  }

  @override
  String tradeChange(String coins) {
    return 'Te vuelven $coins.';
  }

  @override
  String tradeBagAfter(String amount) {
    return 'La bolsa queda en $amount.';
  }

  @override
  String tradeBagAfterCoins(String amount, String coins) {
    return 'La bolsa queda en $amount ($coins).';
  }

  @override
  String get commonDone => 'Listo';

  @override
  String get invCoins => 'Monedas';

  @override
  String get invCoinsEquals => 'Equivale a ';

  @override
  String get invCoinsWeigh => ' po · pesan ';

  @override
  String invCoinLabel(String name, String abbr) {
    return 'Monedas de $name ($abbr)';
  }

  @override
  String get invLoad => 'Carga';

  @override
  String invLoadPercent(Object percent) {
    return '$percent% de la capacidad';
  }

  @override
  String invLoadItems(String weight) {
    return 'Objetos $weight lb';
  }

  @override
  String invLoadCoins(String weight) {
    return 'Monedas $weight lb';
  }

  @override
  String get invOverCapacity =>
      'Pasás tu capacidad de carga. En 2024 no hay penalización de reglas: es un aviso, no un bloqueo.';

  @override
  String get invAttunementUpper => 'SINTONIZACIÓN';

  @override
  String get invAttunementHint =>
      'Se sintoniza desde el menú de cada objeto; acá se ve cuántos cupos quedan y con qué están ocupados.';

  @override
  String get invAttuneSlotFree => 'Cupo de sintonización libre';

  @override
  String invAttunedName(String name) {
    return '$name — sintonizado';
  }

  @override
  String get invSlotFree => 'Cupo libre';

  @override
  String get invTitle => 'Inventario';

  @override
  String get invEmpty => 'La mochila está vacía.';

  @override
  String invPlansButton(Object chosen, Object total) {
    return 'Planos y réplicas ($chosen/$total)';
  }

  @override
  String get invSearchHint => 'Buscar en la mochila…';

  @override
  String get invNoMatches => 'Ningún objeto coincide con ese filtro.';

  @override
  String get invHeadItem => 'OBJETO';

  @override
  String get invHeadQty => 'CANT.';

  @override
  String get invHeadEquipped => 'EQUIPADO';

  @override
  String get invHeadWeight => 'PESO';

  @override
  String get invNoWeight => 'Sin peso';

  @override
  String invRemoveOne(String name) {
    return 'Quitar una unidad de $name';
  }

  @override
  String invAddOne(String name) {
    return 'Agregar una unidad de $name';
  }

  @override
  String invCharges(Object left) {
    return '$left cargas';
  }

  @override
  String invChargesOf(Object left, Object max) {
    return 'Cargas $left/$max';
  }

  @override
  String invSpendCharge(String name) {
    return 'Gastar una carga de $name';
  }

  @override
  String invRecoverCharge(String name) {
    return 'Recuperar una carga de $name';
  }

  @override
  String get invSeeWhatItDoes => 'Ver qué hace';

  @override
  String get invAttuned => 'Sintonizado';

  @override
  String get invReplica => 'Réplica';

  @override
  String get invNotEquippable => 'No se equipa';

  @override
  String get invEquipped => 'Equipado';

  @override
  String get invExactQuantity => 'Cantidad exacta…';

  @override
  String get invNote => 'Nota…';

  @override
  String get invUnattune => 'Quitar sintonización';

  @override
  String get invAttune => 'Sintonizar';

  @override
  String get invTwoHanded => 'A dos manos';

  @override
  String get invTransmute => 'Transmutar réplica…';

  @override
  String get invSellMenu => 'Vender…';

  @override
  String get invRemove => 'Quitar';

  @override
  String invBundlesOf(Object size) {
    return 'Paquetes de $size';
  }

  @override
  String get invUnits => 'Unidades';

  @override
  String get invNoteTitle => 'Nota';

  @override
  String get invNoteLabel => 'Qué dice, de dónde salió, para qué sirve';

  @override
  String invRemoved(String name) {
    return 'Quitaste $name.';
  }

  @override
  String get invTransmuteInto => 'Transmutar en';

  @override
  String get invCatalogHint =>
      'Agregar es gratis y deja seguir sumando; comprar paga de la bolsa.';

  @override
  String invBuyTitle(String name) {
    return 'Comprar $name';
  }

  @override
  String invBought(Object quantity, String name, String amount) {
    return 'Compraste $quantity × $name por $amount.';
  }

  @override
  String invSellTitle(String name) {
    return 'Vender $name';
  }

  @override
  String invSellDetail(Object quantity, String price) {
    return 'Tenés $quantity · catálogo $price';
  }

  @override
  String invSold(Object quantity, String name, String amount) {
    return 'Vendiste $quantity × $name por $amount.';
  }

  @override
  String get invTargetHint =>
      'Elegí un ejemplar de la mochila o creá uno de los permitidos por el rasgo.';

  @override
  String get invInPack => 'En la mochila';

  @override
  String get invNoEligible => 'No hay ejemplares elegibles.';

  @override
  String get invCreatedByFeature => 'Creada por este rasgo';

  @override
  String get invCreateWeapon => 'Crear arma';

  @override
  String get invAddAndEquip => 'Agregar y equipar';

  @override
  String get invClearLink => 'Limpiar vínculo';

  @override
  String invPlansIntro(int count, int active) {
    String _temp0 = intl.Intl.pluralLogic(
      active,
      locale: localeName,
      other: '$active réplicas activas',
      one: '1 réplica activa',
    );
    return 'Elegís $count planos. Después decidís cuál replicar: podés tener $_temp0 a la vez.';
  }

  @override
  String get invActiveReplicas => 'Réplicas activas';

  @override
  String invPlansMissing(Object count) {
    return 'Falta elegir $count.';
  }

  @override
  String get invPickBlueprint => 'Elegí un plano para poder replicarlo.';

  @override
  String invReplicaSlotsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Quedan $count cupos libres.',
      one: 'Queda 1 cupo libre.',
    );
    return '$_temp0';
  }

  @override
  String get invReplicaNoSlots =>
      'Sin cupos libres: quitá una réplica para crear otra.';

  @override
  String invRemoveReplica(String name) {
    return 'Quitar la réplica de $name';
  }

  @override
  String invCreateReplica(String name) {
    return 'Crear la réplica de $name';
  }

  @override
  String get invNoReplicaSlots => 'No quedan cupos de réplica';

  @override
  String get invPickBase => 'Elegí el objeto base';

  @override
  String invRangeHint(String range) {
    return 'alcance $range';
  }

  @override
  String get invTwoHandedMounted => 'exige dos manos salvo montado';

  @override
  String get invTwoHandedHint => 'exige dos manos';

  @override
  String get commonEdit => 'Editar';

  @override
  String get diaryImportMd => 'Importar un .md';

  @override
  String get diaryExportMd => 'Exportar como .md';

  @override
  String get diaryFinishEditing => 'Terminar de editar';

  @override
  String get diaryEditBackground => 'Editar el trasfondo';

  @override
  String get diaryBackgroundHint =>
      'De dónde viene, qué dejó atrás, qué le debe a quién…';

  @override
  String get diaryMarkdownHint =>
      'Acepta Markdown: # para títulos, **negrita**, *itálica* y - para viñetas.';

  @override
  String get diaryUnknownOrigin => 'Origen desconocido';

  @override
  String diaryUnknownOriginBody(String name) {
    return 'Todavía nadie escribió de dónde viene $name. Podés escribirlo acá, o traer un .md que ya tengas afuera.';
  }

  @override
  String get diaryWriteBackground => 'Escribir el trasfondo';

  @override
  String get diaryImportMdShort => 'Importar .md';

  @override
  String get diaryPickMd => 'Elegir un archivo .md';

  @override
  String get diaryOpenError => 'No se pudo abrir el archivo';

  @override
  String get diaryReplaceTitle => 'Reemplazar el trasfondo';

  @override
  String get diaryReplaceBody =>
      'Lo que hay escrito se pierde y queda en su lugar el contenido del archivo. No hay forma de recuperarlo.';

  @override
  String get diaryReplace => 'Reemplazar';

  @override
  String get diaryNotUtf8 => 'El archivo no parece texto en UTF-8.';

  @override
  String get diaryImported => 'Trasfondo importado.';

  @override
  String get diaryFileSuffix => 'trasfondo';

  @override
  String get diaryFileFallback => 'personaje';

  @override
  String get diaryEntries => 'Entradas';

  @override
  String get diaryAddEntryTooltip => 'Agregar una entrada';

  @override
  String diaryEmpty(String name) {
    return 'El diario de $name todavía está en blanco.\nSumá arte, una historia corta, una manía — lo que te guste de este personaje.';
  }

  @override
  String get diaryAddEntry => 'Agregar entrada';

  @override
  String diaryDeleted(String title) {
    return 'Borraste «$title».';
  }

  @override
  String diaryDeleteBody(String title) {
    return '«$title» se va del diario.';
  }

  @override
  String diaryDeleteBodyImage(String title) {
    return '«$title» se va del diario, y la imagen que subiste se borra con ella. No hay forma de recuperarla.';
  }

  @override
  String get diaryUntitled => 'Sin título';

  @override
  String get diaryDragHint => 'Mantené apretado para reordenar';

  @override
  String get diaryNoImage => 'Sin imagen.';

  @override
  String get diaryKindText => 'Texto';

  @override
  String get diaryKindImage => 'Imagen';

  @override
  String get diaryKindLink => 'Enlace';

  @override
  String diaryEditedOn(String date, String edited) {
    return '$date · editada $edited';
  }

  @override
  String get diaryEntryNoImage => 'Esta entrada no tiene imagen.';

  @override
  String get diarySeeFullImage => 'Ver la imagen completa';

  @override
  String get diaryImageGone => 'La imagen ya no está en el almacén.';

  @override
  String get diaryDeleteTitle => 'Borrar la entrada';

  @override
  String get diaryPickImage => 'Elegir una imagen';

  @override
  String get diaryUploadError => 'No se pudo subir la imagen';

  @override
  String get diaryNewEntry => 'Nueva entrada';

  @override
  String get diaryEditEntry => 'Editar entrada';

  @override
  String get diaryTitleLabel => 'Título';

  @override
  String get diaryEntryType => 'Tipo de entrada';

  @override
  String get diaryBodyHint => 'Lo que quieras contar de este personaje…';

  @override
  String get diaryUploading => 'Subiendo la imagen…';

  @override
  String get diaryChooseImage => 'Elegir imagen';

  @override
  String get diaryChangeImage => 'Cambiar imagen';

  @override
  String get diaryImageFormats =>
      'PNG, JPEG o WEBP. Mismo límite de tamaño que los retratos.';

  @override
  String get spellsTitle => 'Conjuros';

  @override
  String get spellsPrepare => 'Preparar';

  @override
  String get spellsSaveDcShort => 'CD SALV.';

  @override
  String spellsSaveDcSemantics(Object dc) {
    return 'Clase de dificultad de las salvaciones contra tus conjuros: $dc';
  }

  @override
  String get spellsAttackUpper => 'ATAQUE';

  @override
  String get spellsAbilityUpper => 'APTITUD';

  @override
  String spellsAbilitySemantics(String name) {
    return 'Aptitud mágica: $name';
  }

  @override
  String spellsPrepared(Object count, Object max) {
    return 'Preparados: $count / $max';
  }

  @override
  String spellsKnown(Object count) {
    return 'Conocidos: $count';
  }

  @override
  String spellsCantrips(Object count, Object max) {
    return 'Trucos: $count / $max';
  }

  @override
  String get spellsSources => 'Fuentes de lanzamiento';

  @override
  String spellsSourcePrepared(Object level, String ability) {
    return '$level° nivel · $ability · preparados';
  }

  @override
  String spellsSourceKnown(Object level, String ability) {
    return '$level° nivel · $ability · conocidos';
  }

  @override
  String get spellsFromFeatures => 'Conjuros de rasgos';

  @override
  String spellsWildShapeBlock(String name) {
    return 'En forma de $name no podés lanzar conjuros.';
  }

  @override
  String spellsConcentratingOn(String spell) {
    return 'Concentrándote en $spell';
  }

  @override
  String get spellsEndConcentration => 'Terminar';

  @override
  String get spellsSlots => 'Espacios de conjuro';

  @override
  String get spellsPactSlots => 'Espacios de Pacto';

  @override
  String get spellsCantripsTitle => 'Trucos';

  @override
  String get spellsAlwaysPrepared => 'Siempre preparados';

  @override
  String get spellsAlwaysPreparedHint =>
      'Los concede un rasgo y no ocupan cupo: se lanzan con tus espacios de conjuro como cualquier preparado.';

  @override
  String get spellsPreparedTitle => 'Conjuros preparados';

  @override
  String get spellsKnownTitle => 'Conjuros conocidos';

  @override
  String get spellsNoneChosen =>
      'Todavía no elegiste conjuros. Editá al subir de nivel o al crear.';

  @override
  String get spellsUseLongRest => '1/descanso largo';

  @override
  String get spellsUseShortRest => '1/descanso corto';

  @override
  String get spellsUseProficiency => 'Competencia/descanso largo';

  @override
  String spellsUseAbilityMod(Object uses, String ability) {
    return '$uses/descanso largo ($ability)';
  }

  @override
  String get spellsSwapTooltip => 'Cambiar tras un descanso largo';

  @override
  String get spellsConcentrate => 'Concentrar';

  @override
  String get spellsCutTitle => 'Cortar la concentración';

  @override
  String spellsCutBody(String spell, String previous, int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'se van',
      one: 'se va',
    );
    return 'Concentrarte en $spell termina $previous, y con ella $_temp0 $names.';
  }

  @override
  String get spellsCurrentConcentration => 'tu concentración actual';

  @override
  String get spellsConcentrateAnyway => 'Concentrar igual';

  @override
  String spellsSwitched(String spell, String previous) {
    return 'Te concentrás en $spell: dejaste $previous.';
  }

  @override
  String spellsSwitchedDeps(
    String spell,
    String previous,
    int count,
    String names,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'se van',
      one: 'se va',
    );
    return 'Te concentrás en $spell: dejaste $previous y $_temp0 $names.';
  }

  @override
  String spellsSwapTitle(String name) {
    return 'Cambiar $name';
  }

  @override
  String spellsSwapBody(String lists) {
    return 'Al terminar un descanso largo podés cambiarlo por otro truco de $lists.';
  }

  @override
  String get spellsSwapOriginal => 'El del rasgo';

  @override
  String spellsListOf(String name) {
    return 'la lista de $name';
  }

  @override
  String listOr(String head, String last) {
    return '$head o $last';
  }

  @override
  String get spellsSpendSlot => 'Gastar espacio';

  @override
  String get spellsRecoverSlot => 'Recuperar espacio';

  @override
  String get spellsWithCharacter => 'Con este personaje';

  @override
  String spellsCastWith(String ability, String mod, String attack, Object dc) {
    return 'Lanzás con $ability ($mod). Ataque de conjuro $attack · CD de salvación $dc.';
  }

  @override
  String spellsDamageBonus(String bonus, String sources) {
    return '$bonus al daño ($sources)';
  }

  @override
  String get stepSpecies => 'Especie';

  @override
  String get stepClass => 'Clase';

  @override
  String get stepBackground => 'Trasfondo';

  @override
  String get stepScores => 'Puntuaciones';

  @override
  String get stepProficiencies => 'Competencias';

  @override
  String get stepEquipment => 'Equipo';

  @override
  String get stepDetails => 'Detalles';

  @override
  String get stepSummary => 'Resumen';

  @override
  String get pendingPickSpecies => 'Elegí una especie.';

  @override
  String get pendingPickLineage => 'Elegí un linaje de especie.';

  @override
  String get pendingPickLineageAbility => 'Elegí la aptitud mágica del linaje.';

  @override
  String get pendingPickSize => 'Elegí el tamaño de la especie.';

  @override
  String get pendingPickClass => 'Elegí una clase.';

  @override
  String pendingSlotProgress(String name, Object chosen, Object total) {
    return '$name: $chosen/$total.';
  }

  @override
  String pendingWeaponMastery(Object chosen, Object total) {
    return 'Maestría de armas: $chosen/$total.';
  }

  @override
  String get pendingPickBackground => 'Elegí un trasfondo.';

  @override
  String pendingPickFeatAbility(String name) {
    return 'Elegí la aptitud mágica de $name.';
  }

  @override
  String get pendingSpread => 'Asigná el +2 y el +1 de característica.';

  @override
  String pendingAssignScores(Object count) {
    return 'Asigná las 6 características ($count/6).';
  }

  @override
  String pendingClassSkills(Object chosen, Object total) {
    return 'Habilidades de clase: $chosen/$total.';
  }

  @override
  String pendingSpeciesSkills(Object chosen, Object total) {
    return 'Habilidades de especie: $chosen/$total.';
  }

  @override
  String get pendingPickOriginFeat => 'Elegí una dote de origen.';

  @override
  String pendingProficiencies(Object count) {
    return 'Competencias pendientes: $count.';
  }

  @override
  String pendingExpertise(Object count) {
    return 'Pericias pendientes: $count.';
  }

  @override
  String pendingLanguages(Object chosen, Object total) {
    return 'Idiomas: $chosen/$total.';
  }

  @override
  String pendingLanguageChoices(Object count) {
    return 'Idiomas por rasgo pendientes: $count.';
  }

  @override
  String get pendingClassEquipment => 'Elegí el equipo de clase.';

  @override
  String get pendingBackgroundEquipment => 'Elegí el equipo de trasfondo.';

  @override
  String get pendingEquipmentChoices =>
      'Completá las elecciones internas de equipo.';

  @override
  String pendingOverspent(String amount) {
    return 'Las compras superan el oro de partida por $amount.';
  }

  @override
  String pendingSpellChoices(Object count) {
    return 'Conjuros a elección: $count.';
  }

  @override
  String pendingCantrips(Object chosen, Object total) {
    return 'Trucos: $chosen/$total.';
  }

  @override
  String pendingSpells(Object chosen, Object total) {
    return 'Conjuros: $chosen/$total.';
  }

  @override
  String get characterUnnamed => 'Sin nombre';

  @override
  String get wizardCreateNpc => 'Crear PNJ';

  @override
  String get wizardDiscardNpc => '¿Descartar este PNJ?';

  @override
  String get wizardDiscardCharacter => '¿Descartar este personaje?';

  @override
  String get wizardDiscardBody =>
      'Las elecciones realizadas en el asistente se perderán.';

  @override
  String get wizardKeepCreating => 'Seguir creando';

  @override
  String get wizardDiscard => 'Descartar';

  @override
  String get wizardProgress => 'Progreso';

  @override
  String wizardStepOf(Object step, Object total) {
    return 'Paso $step de $total';
  }

  @override
  String wizardStepSemantics(String name, Object step, Object total) {
    return '$name, paso $step de $total';
  }

  @override
  String get wizardFinishPrevious => 'Completá los pasos anteriores';

  @override
  String get wizardProgressSemantics => 'Progreso de creación';

  @override
  String get wizardBack => 'Atrás';

  @override
  String wizardMissing(String item) {
    return 'Falta: $item';
  }

  @override
  String wizardMissingMore(String first, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'cosas',
      one: 'cosa',
    );
    return 'Falta: $first (y $count $_temp0 más).';
  }

  @override
  String get wizardNext => 'Siguiente';

  @override
  String get detailsEmblem => 'Emblema';

  @override
  String detailsEmblemBody(String klass) {
    return 'Hasta que le pongas un retrato, tu personaje usa el emblema de $klass.';
  }

  @override
  String get detailsYourClass => 'su clase';

  @override
  String get detailsPortraitLater =>
      'Podés generar o elegir un retrato después, desde la ficha.';

  @override
  String get detailsName => 'Nombre';

  @override
  String get detailsUndefined => 'Sin definir';

  @override
  String get detailsTrait => 'Rasgo de personalidad';

  @override
  String get detailsTraitHint =>
      'Una línea que lo defina. Ej: \"Nunca deja una deuda sin pagar.\"';

  @override
  String get weaponSimple => 'Simples';

  @override
  String get weaponMartial => 'Marciales';

  @override
  String get weaponUnarmed => 'Sin arma (puños)';

  @override
  String get weaponSearchHint => 'Buscar arma…';

  @override
  String get summaryEquipped => 'puesto';

  @override
  String get summaryTitle => 'Revisá y confirmá';

  @override
  String summaryLine(String species, String klass, String background) {
    return '$species · $klass · $background · Nivel 1';
  }

  @override
  String get summaryInCombat => 'En combate';

  @override
  String get summaryFeats => 'Dotes';

  @override
  String get identityCreatureTypeShort => 'Tipo';

  @override
  String get pickSpeciesHint => 'Elegí una especie para ver su detalle.';

  @override
  String get factToChoose => 'a elegir';

  @override
  String feetValue(Object feet) {
    return '$feet pies';
  }

  @override
  String factChoose(Object count) {
    return '$count a elegir';
  }

  @override
  String get raceLineageTitle => 'Linaje de especie';

  @override
  String get raceLineageRequired => 'Esta especie requiere elegir un linaje.';

  @override
  String get raceLineageLevel1 => 'Lo que te da a nivel 1';

  @override
  String get speciesSpellAbility => 'Aptitud mágica';

  @override
  String get pickClassHint => 'Elegí una clase para ver su detalle.';

  @override
  String get factHitDie => 'Dado de golpe';

  @override
  String classChooseCount(String name, Object count) {
    return '$name (elegí $count)';
  }

  @override
  String classWeaponMasteryTitle(Object count) {
    return 'Maestría de armas (elegí $count)';
  }

  @override
  String classWeaponMasteryBody(String klass) {
    return 'Dominás el arma lo suficiente como para sacarle un efecto extra cada vez que acertás —derribar, entorpecer, rozar—, sin gastar nada. Solo armas con las que $klass es competente.';
  }

  @override
  String get pickBackgroundHint => 'Elegí un trasfondo para ver su detalle.';

  @override
  String get factOriginFeat => 'Dote de origen';

  @override
  String get bgOriginFeatGives => 'Qué te da su dote de origen';

  @override
  String get bgFeatAbilityHint =>
      'Se usa para la CD y los ataques de los conjuros de la dote.';

  @override
  String get bgAbilityIncrease => 'Aumento de característica';

  @override
  String bgEachPlusOne(String list) {
    return 'Cada una de $list recibe +1.';
  }

  @override
  String get aptHelpTitle => 'Qué es una competencia';

  @override
  String get aptHelpBody =>
      'Ser competente en algo te deja sumar tu bonificador por competencia cuando tirás con eso: una habilidad, un arma, una herramienta o una salvación. Acá elegís las tuyas entre las que ofrecen tu clase, tu especie y tu trasfondo; las que ya vienen dadas aparecen bloqueadas.';

  @override
  String get aptClassSkills => 'Habilidades de clase';

  @override
  String get aptSpeciesSkills => 'Habilidades de especie';

  @override
  String get aptGrantedByBackground => 'Estas ya te las da el trasfondo:';

  @override
  String creationChosen(Object count, Object total) {
    return '$count / $total elegidas';
  }

  @override
  String creationChosenM(Object count, Object total) {
    return '$count / $total elegidos';
  }

  @override
  String get creationNotChosen => 'sin elegir';

  @override
  String get creationOneChosen => '1 elegida';

  @override
  String aptOriginFeatNote(String species) {
    return 'En 2024 las dotes de nivel 1 vienen del origen: $species te concede una a elección.';
  }

  @override
  String get aptProfChoices => 'Competencias a elección';

  @override
  String aptFeatChoose(String name, Object count) {
    return '$name: elegí $count';
  }

  @override
  String get aptExpertise => 'Pericia';

  @override
  String get aptExpertiseHint =>
      'Duplica tu bonificador por competencia en la habilidad elegida.';

  @override
  String get scoresMethod => 'Método';

  @override
  String get scoresHelpTitle => '¿Qué método conviene?';

  @override
  String get scoresHelpBody =>
      'Los cuatro generan las seis puntuaciones del personaje, con distinto grado de azar. El conjunto estándar reparte valores fijos y equilibrados: es el camino corto. Tirar 4d6 los sortea. El coste en puntos te deja armarlos con un presupuesto. Escribir a mano sirve si ya los tenés decididos.';

  @override
  String get scoresStandardArray => 'Conjunto estándar';

  @override
  String get scoresRoll4d6 => 'Tirar 4d6';

  @override
  String get scoresPointBuy => 'Coste en puntos';

  @override
  String get scoresManual => 'Escribir a mano';

  @override
  String scoresManualHelp(Object min, Object max) {
    return 'Escribí la puntuación base de cada característica ($min a $max), sin contar el aumento del trasfondo. Si alguna queda fuera del rango habitual de generación (3 a 18) la ficha lo va a señalar como aviso, pero no te impide seguir.';
  }

  @override
  String scoresSuggested(String klass) {
    return 'Reparto sugerido para $klass';
  }

  @override
  String get scoresUseSuggested => 'Usar este reparto';

  @override
  String get scoresUnassigned => 'Valores sin asignar';

  @override
  String get scoresNoneLeft => 'Ninguno: ya están las 6.';

  @override
  String get scoresRollAgain => 'Tirar de nuevo';

  @override
  String get scoresClear => 'Limpiar';

  @override
  String get scoresPointsLeft => 'Puntos restantes';

  @override
  String scoresOfBudget(Object left, Object budget) {
    return '$left de $budget';
  }

  @override
  String get scoresBudgetDone => 'Presupuesto completo.';

  @override
  String get scoresOneUnspent =>
      'Te queda 1 punto sin gastar: si seguís, se pierde.';

  @override
  String scoresUnspent(Object count) {
    return 'Te quedan $count puntos sin gastar: si seguís, se pierden.';
  }

  @override
  String scoresAllStartAt(Object min) {
    return 'Todas empiezan en $min: subí las que más te importan con «+».';
  }

  @override
  String scoresCostNote(Object min, Object max) {
    return 'Cada característica va de $min a $max. Los últimos dos escalones cuestan el doble: 14 vale 7 puntos y 15 vale 9, no 6 y 7.';
  }

  @override
  String scoresLower(String ability) {
    return 'Bajar $ability';
  }

  @override
  String scoresRaise(String ability) {
    return 'Subir $ability';
  }

  @override
  String scoresAtMax(Object spent) {
    return 'al máximo · gastados $spent';
  }

  @override
  String scoresNextCost(Object cost, Object spent) {
    return 'subir cuesta $cost · gastados $spent';
  }

  @override
  String get scoresUnassignedShort => 'sin asignar';

  @override
  String scoresBase(Object score) {
    return 'base $score';
  }

  @override
  String get scoresPickValue => 'Elegir valor';

  @override
  String get scoresModEmpty => 'MOD —';

  @override
  String scoresMod(String value) {
    return 'MOD $value';
  }

  @override
  String get scoresValue => 'Valor';

  @override
  String scoresTaken(String abilities) {
    return 'en $abilities';
  }

  @override
  String scoresTakenFree(String abilities, int free) {
    String _temp0 = intl.Intl.pluralLogic(
      free,
      locale: localeName,
      other: 'quedan $free',
      one: 'queda 1',
    );
    return 'en $abilities · $_temp0';
  }

  @override
  String get wordOr => 'o';

  @override
  String get equipReceivedTitle => 'Equipo puesto';

  @override
  String get equipStartingTitle => 'Equipo inicial';

  @override
  String get equipPickClassItem => 'Elegí un objeto del equipo de clase';

  @override
  String get equipPickBackgroundItem =>
      'Elegí un objeto del equipo de trasfondo';

  @override
  String get equipNoStartingClass => 'Esta clase no trae equipo inicial.';

  @override
  String get equipNoStartingBackground =>
      'Este trasfondo no trae equipo inicial.';

  @override
  String get equipOptionClass => 'Opción de clase';

  @override
  String get equipOptionBackground => 'Opción de trasfondo';

  @override
  String get equipOrOther => 'u otro';

  @override
  String get equipShopTitle => 'Comprar equipo';

  @override
  String get equipLeftShort => 'Quedan';

  @override
  String get equipShopHint =>
      'Cada toque suma uno a tus compras. La cantidad se ajusta en la lista del paso.';

  @override
  String get equipPurchases => 'Compras';

  @override
  String get equipPickFirst =>
      'Primero elegí las opciones de equipo: el oro para comprar sale de ahí.';

  @override
  String equipLeft(String amount) {
    return 'Quedan $amount';
  }

  @override
  String get equipNoGold => 'Las opciones elegidas no traen oro para comprar.';

  @override
  String get equipGoldExplainer =>
      'Lo que no traés en el paquete lo comprás con el oro de partida, al precio del manual. Lo que sobre queda en la bolsa.';

  @override
  String get equipStartingGold => 'Oro de partida';

  @override
  String get equipInPurchases => 'En compras';

  @override
  String get equipShortLabel => 'Faltan';

  @override
  String get equipYouHaveLeft => 'Te quedan';

  @override
  String get equipOverspent =>
      'Las compras superan el oro de partida: sacá algo o elegí otra opción de equipo.';

  @override
  String get equipBuyItems => 'Comprar objetos';

  @override
  String equipOneLess(String name) {
    return 'Uno menos de $name';
  }

  @override
  String equipOneMore(String name) {
    return 'Uno más de $name';
  }

  @override
  String equipRemovePurchase(String name) {
    return 'Sacar $name de las compras';
  }

  @override
  String get equipTapPiece => 'Tocá una pieza para sacártela o ponértela.';

  @override
  String get equipNothingToWear =>
      'El paquete elegido no trae equipo para vestir o empuñar.';

  @override
  String get equipGrip => 'Cómo las empuñás';

  @override
  String get equipOffHandNote =>
      'El ataque de mano secundaria es una acción adicional y no suma tu modificador al daño, salvo con el estilo Combate con Dos Armas.';

  @override
  String get equipOffHandShort => 'Secundaria';

  @override
  String get equipNoSpellsTitle => 'Tu clase no lanza conjuros';

  @override
  String get equipNoSpellsBody =>
      'Confiás en el acero y la maña. Seguí al próximo paso.';

  @override
  String get equipNoPreparedSlot => 'No ocupan cupo de preparados.';

  @override
  String equipCantripSuffix(String name) {
    return '$name (truco)';
  }

  @override
  String equipLevelShort(String name, Object level) {
    return '$name (Nv $level)';
  }

  @override
  String equipCasterLine(Object dc, String attack, String ability) {
    return 'CD de salvación $dc · Ataque de conjuro $attack ($ability)';
  }

  @override
  String get equipMagicTitle => 'Cómo funciona tu magia';

  @override
  String get equipMagicCantrips =>
      'Los trucos se lanzan siempre y no gastan nada.';

  @override
  String get equipMagicPrepared =>
      'Los conjuros preparados son los que dejás listos para usar; podés cambiarlos al descansar.';

  @override
  String get equipMagicKnown =>
      'Los conjuros conocidos son los que aprendiste y quedan disponibles para lanzar.';

  @override
  String get equipMagicSlots =>
      'Cada vez que lanzás uno gastás un espacio de conjuro, que es un recurso aparte: los espacios dicen cuántas veces podés lanzar, no cuántos conjuros tenés.';

  @override
  String equipGrantedCantripOne(String name) {
    return 'Ya tenés $name por otro rasgo: no ocupa un cupo de truco de clase.';
  }

  @override
  String equipGrantedCantripMany(String names) {
    return 'Ya tenés $names por otros rasgos: no ocupan cupos de truco de clase.';
  }

  @override
  String equipGrantedLeveled(String names) {
    return 'Ya tenés $names siempre preparado por otro rasgo: no ocupa un cupo.';
  }

  @override
  String equipMaxLevel(Object level) {
    return 'Podés preparar conjuros de hasta nivel $level.';
  }

  @override
  String get wordAnd => 'y';

  @override
  String get luStepSubclass => 'Subclase';

  @override
  String get luStepAsi => 'Mejora o dote';

  @override
  String get luStepChoices => 'Elecciones';

  @override
  String get luStepSpellChoices => 'Conjuros a elección';

  @override
  String get luStepReview => 'Revisión';

  @override
  String get luPendingHp => 'Tirá el dado o elegí el promedio para continuar.';

  @override
  String get luPendingSubclass => 'Elegí una subclase para continuar.';

  @override
  String get luPendingImprove => 'Completá la mejora de características.';

  @override
  String get luPendingFeat => 'Elegí una dote para continuar.';

  @override
  String get luPendingFeatAbility =>
      'Elegí a qué característica va el +1 de la dote.';

  @override
  String luPendingChoices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Te faltan $count elecciones para continuar.',
      one: 'Te falta una elección para continuar.',
    );
    return '$_temp0';
  }

  @override
  String luPendingExpertise(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Elegí $count habilidades para tu Pericia.',
      one: 'Elegí una habilidad para tu Pericia.',
    );
    return '$_temp0';
  }

  @override
  String luPendingProficiency(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Te faltan $count competencias para continuar.',
      one: 'Te falta una competencia para continuar.',
    );
    return '$_temp0';
  }

  @override
  String luPendingSpellChoices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Te faltan $count conjuros para continuar.',
      one: 'Te falta elegir un conjuro para continuar.',
    );
    return '$_temp0';
  }

  @override
  String get luOneCantrip => 'un truco';

  @override
  String luCantrips(Object count) {
    return '$count trucos';
  }

  @override
  String get luOneSpell => 'un conjuro';

  @override
  String luSpells(Object count) {
    return '$count conjuros';
  }

  @override
  String luPendingClassSpells(String parts) {
    return 'Te falta elegir $parts para continuar.';
  }

  @override
  String luTitle(Object level) {
    return 'Subir a nivel $level';
  }

  @override
  String get luStatAttacks => 'Ataques/acción';

  @override
  String get luStatMasteries => 'Maestrías';

  @override
  String get luStatDarkvision => 'Visión osc.';

  @override
  String get luSummaryTitle => 'Subida de nivel';

  @override
  String luHpMax(Object hp) {
    return '+$hp PG máximos';
  }

  @override
  String get luHpCurrent => 'Tus PG actuales suben lo mismo.';

  @override
  String get luNewProficiencies => 'Nuevas competencias';

  @override
  String luSavShort(String ability) {
    return 'Salv. $ability';
  }

  @override
  String get luNewFeatures => 'Rasgos de clase ganados';

  @override
  String get luAlsoGain => 'También ganás';

  @override
  String get luNewResources => 'Recursos nuevos';

  @override
  String luResourceLine(Object max, String recharge) {
    return 'Usos: $max · recarga: $recharge';
  }

  @override
  String get restShortLower => 'descanso corto';

  @override
  String get restLongLower => 'descanso largo';

  @override
  String get luNewCompanions => 'Compañeros nuevos';

  @override
  String get luCompanionOne => 'Se invoca desde la pestaña Combate.';

  @override
  String luCompanionMany(Object count) {
    return '$count formas a elegir, desde la pestaña Combate.';
  }

  @override
  String luFormsMore(Object count) {
    return '$count formas más';
  }

  @override
  String get luFormsNote => 'Anotá las nuevas desde la pestaña Combate.';

  @override
  String get luDone => '¡Listo!';

  @override
  String luLeveled(Object level) {
    return '¡Subiste a nivel $level!';
  }

  @override
  String get luConfirm => 'Confirmar';

  @override
  String luConfirmLevel(Object level) {
    return 'Confirmar nivel $level';
  }

  @override
  String get luContinue => 'Continuar';

  @override
  String luGrants(String list) {
    return 'Concede: $list';
  }

  @override
  String get luRepeatable => 'Se puede tomar más de una vez.';

  @override
  String luLevelCount(Object level, Object count) {
    return 'Nv $level  ×$count';
  }

  @override
  String get luComplete =>
      'Ya están completas. Tocá una elegida para soltarla y poder cambiarla.';

  @override
  String luRemoveOne(String name) {
    return 'Quitar una de $name';
  }

  @override
  String get luNoExpertiseTargets =>
      'No tenés competencias sobre las que aplicar Pericia.';

  @override
  String get luNoProficiencies =>
      'No quedan competencias disponibles para este rasgo.';

  @override
  String get luChooseEyebrow => 'Elegís vos';

  @override
  String get luSubclassIntroTitle => 'Tu camino dentro de la clase';

  @override
  String get luSubclassIntroBody =>
      'La subclase define nuevos rasgos y decisiones para los próximos niveles. Revisá cada opción antes de continuar.';

  @override
  String get luAsiIntroTitle => 'Mejora tu personaje';

  @override
  String get luAsiIntroBody =>
      'Aumentá tus características o elegí una dote. La decisión se previsualiza antes de modificar la ficha.';

  @override
  String get luChoicesIntroTitle => 'Tus elecciones de este nivel';

  @override
  String get luChoicesIntroBody =>
      'Algunos rasgos te dejan elegir entre varias opciones. Podés revisarlas acá antes de confirmar la subida.';

  @override
  String get luProfBodyExpertise =>
      'Duplicás tu bonificador por competencia en las habilidades que elijas. Solo se ofrecen las habilidades en las que ya sos competente.';

  @override
  String get luProfBody =>
      'Lo que ya tenés por otra vía queda bloqueado, para no gastar el cupo en algo que ya sabés hacer. En los cupos de Pericia es al revés: solo se ofrecen las habilidades en las que ya sos competente.';

  @override
  String get luAlwaysPreparedTitle => 'Conjuros que quedan siempre preparados';

  @override
  String get luAlwaysPreparedBody =>
      'Estos conjuros no ocupan cupo de preparados y no se pueden desmarcar desde el editor. El pozo ya viene filtrado por lo que el rasgo permite.';

  @override
  String get luMagicEyebrow => 'Magia';

  @override
  String luYourSpellsAt(Object level) {
    return 'Tus conjuros a nivel $level';
  }

  @override
  String get luMagicBody =>
      'Revisá los espacios y la cantidad de conjuros preparados. Podés actualizar tu selección sin salir de la subida de nivel.';

  @override
  String get luClassOfLevel => 'Clase del nivel';

  @override
  String get luClassHelper =>
      'Podés continuar con tu clase actual o comenzar una nueva.';

  @override
  String get luWhichClass => '¿En qué clase avanzás?';

  @override
  String luClassLevelLine(Object level, String name, Object die) {
    return '$level° nivel de $name · dado d$die';
  }

  @override
  String luMulticlassReq(String requirement) {
    return 'No cumplís el requisito de multiclase: $requirement. La mesa puede autorizarlo.';
  }

  @override
  String luOverviewHp(Object die) {
    return 'Elegís el promedio o tirás tu d$die; la Constitución se suma sola.';
  }

  @override
  String get luTagYouChoose => 'ELEGÍS VOS';

  @override
  String get luTagOptional => 'OPCIONAL';

  @override
  String get luTagAuto => 'AUTOMÁTICO';

  @override
  String get luFeatureChoicesTitle => 'Elecciones de rasgos';

  @override
  String get luFeatureChoicesBody =>
      'Un rasgo de este nivel te deja elegir entre varias opciones.';

  @override
  String get luChooseSubclass => 'Elegir subclase';

  @override
  String get luChooseSubclassBody =>
      'Define la especialización del personaje y sus rasgos futuros.';

  @override
  String get luAsiCardBody =>
      'Repartí una mejora de características o incorporá una dote.';

  @override
  String get luReviewSpells => 'Revisar conjuros';

  @override
  String get luReviewSpellsBody =>
      'Comprobá tus espacios y actualizá los conjuros preparados.';

  @override
  String get luLevelUpper => 'NIVEL';

  @override
  String luCharacterLevels(String name, Object level) {
    return '$name sube a nivel $level';
  }

  @override
  String get luOverviewIntro =>
      'Primero revisaremos qué cambia automáticamente y después resolveremos tus decisiones.';

  @override
  String get luOverviewHelp =>
      'Solo aparecen los pasos que le tocan a este personaje en este nivel, así que la lista es distinta cada vez. Nada se guarda en la ficha hasta que confirmes la subida, así que podés rehacer cualquier elección antes de terminar.';

  @override
  String get luAutoChanges => 'Cambios automáticos';

  @override
  String get luDecisions => 'Decisiones de esta subida';

  @override
  String get luMoreHpTitle => 'Más puntos de golpe';

  @override
  String luMoreHpBody(Object die) {
    return 'Elegí el promedio seguro o tirá tu dado de golpe d$die. La Constitución se suma sola.';
  }

  @override
  String luHitDie(Object die) {
    return 'Dado de golpe d$die';
  }

  @override
  String get luNoResult => 'Todavía no hay un resultado.';

  @override
  String luBaseGain(Object hp) {
    return 'Ganancia base del nivel: +$hp PG.';
  }

  @override
  String get luHpMaxTitle => 'PG máximos';

  @override
  String get luRollToSee => 'Tirá el dado para ver la cuenta.';

  @override
  String luHpDie(Object hp) {
    return '+$hp del dado';
  }

  @override
  String luHpCon(String value) {
    return '$value de Constitución';
  }

  @override
  String luHpFeatures(String value) {
    return '$value de tus rasgos';
  }

  @override
  String luHpTotal(String parts, String total) {
    return '$parts = $total PG.';
  }

  @override
  String get luHpRecalc => 'Si subís Constitución más adelante, se recalcula.';

  @override
  String luAverage(Object value) {
    return 'Promedio ($value)';
  }

  @override
  String get luRoll => 'Tirar';

  @override
  String get luRollDie => 'Tirar el dado';

  @override
  String get luRollAgain => 'Volver a tirar';

  @override
  String get luChosenEarlier => 'Elegidos en niveles anteriores';

  @override
  String get luChangeOrKeep => 'Podés cambiarlos o dejarlos como están.';

  @override
  String get luAutoEyebrow => 'Automático';

  @override
  String luFeaturesAt(Object level) {
    return 'Rasgos ganados a nivel $level';
  }

  @override
  String get luFeaturesBody =>
      'Estos rasgos provienen de tu clase y subclase. Se aplicarán automáticamente cuando confirmes la subida.';

  @override
  String get luResource => 'Recurso';

  @override
  String get luClassResource => 'Recurso de clase';

  @override
  String get luReviewMaxHp => 'Puntos de golpe máximos';

  @override
  String luReviewHpNote(Object hp) {
    return '+$hp en esta subida';
  }

  @override
  String get luReviewProfBonus => 'Bonificador por competencia';

  @override
  String get luReviewProfBonusNote =>
      'Se aplica a todas las competencias relevantes';

  @override
  String get luReviewSlotsNote => 'Por nivel de conjuro';

  @override
  String get luReviewPreparedNote => 'Capacidad del repertorio';

  @override
  String get luReviewCantripsNote => 'Se lanzan sin gastar espacios';

  @override
  String get luReviewAttacks => 'Ataques por acción';

  @override
  String get luReviewExtraAttack => 'Ataque Adicional';

  @override
  String get luReviewMasteries => 'Maestrías de armas';

  @override
  String get luReviewMasteriesNote => 'Opciones disponibles';

  @override
  String get luReviewSubclassNote => 'Nueva especialización';

  @override
  String get luFeat => 'Dote';

  @override
  String get luReviewFeatNote => 'Nueva capacidad';

  @override
  String get luReviewImproveNote => 'Mejora permanente';

  @override
  String get luReviewChosenSpells => 'Trucos y conjuros elegidos';

  @override
  String get luReviewChosenNote => 'Selección actualizada';

  @override
  String get luFinalEyebrow => 'Revisión final';

  @override
  String luFinalTitle(String name) {
    return 'Así queda $name';
  }

  @override
  String get luFinalBody =>
      'Revisá los cambios antes de escribirlos en la ficha. Podés volver a cualquier paso disponible desde la barra superior.';

  @override
  String get luIncorporated => 'Rasgos incorporados';

  @override
  String luSlotLine(Object level, Object count) {
    return 'Nv$level ×$count';
  }

  @override
  String luSubclassAt(Object level) {
    return 'Subclase (nivel $level)';
  }

  @override
  String luSpellsEyebrow(Object level) {
    return 'Conjuros a nivel $level';
  }

  @override
  String luPrepare(Object count) {
    return 'Preparás $count conjuros';
  }

  @override
  String luCantripsOf(Object chosen, Object total) {
    return 'Trucos: $chosen de $total';
  }

  @override
  String luMissingCantrips(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Te falta elegir $count trucos.',
      one: 'Te falta elegir un truco.',
    );
    return '$_temp0';
  }

  @override
  String luPreparedOf(Object chosen, Object total) {
    return 'Preparados: $chosen de $total';
  }

  @override
  String luMissingPrepare(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Te falta preparar $count conjuros.',
      one: 'Te falta preparar un conjuro.',
    );
    return '$_temp0';
  }

  @override
  String get luSpellsUpdated => 'Conjuros actualizados';

  @override
  String get luPrepareSpells => 'Preparar conjuros';

  @override
  String luAsiAt(Object level) {
    return 'Mejora de característica (nivel $level)';
  }

  @override
  String get luImproveAbilities => 'Mejorar características';

  @override
  String get luTakeFeat => 'Tomar dote';

  @override
  String luFeatRaises(Object amount) {
    return 'La dote sube una característica (+$amount)';
  }

  @override
  String luFeatCap(Object max) {
    return 'Esta dote llega hasta $max, no hasta 20 como una mejora normal.';
  }

  @override
  String get luPlusTwo => '+2 a una';

  @override
  String get luPlusOneTwo => '+1 a dos';

  @override
  String get luPickOneAbility =>
      'Elegí una característica para sumar 2 puntos.';

  @override
  String get luPickTwoAbilities =>
      'Elegí dos características distintas para sumar 1 punto a cada una.';

  @override
  String get luNoFeats => 'No quedan dotes disponibles.';

  @override
  String get luSearchFeat => 'Buscar dote';

  @override
  String get luNameOrEffect => 'Nombre o efecto';

  @override
  String luAvailable(Object count) {
    return '$count disponibles';
  }

  @override
  String luNoFeatMatch(String query) {
    return 'Ninguna dote coincide con «$query».';
  }

  @override
  String get luPickFeatTitle => 'Elegí una dote';

  @override
  String get luPickFeatBody =>
      'Cada dote cambia cómo se juega el personaje. Seleccioná una para revisar su efecto completo.';

  @override
  String get catRaces => 'Especies';

  @override
  String get catLineages => 'Linajes';

  @override
  String get catClasses => 'Clases';

  @override
  String get catSubclasses => 'Subclases';

  @override
  String get catBackgrounds => 'Trasfondos';

  @override
  String get catFeats => 'Dotes';

  @override
  String get codexGroupCharacter => 'Personaje';

  @override
  String get codexGroupGear => 'Magia y equipo';

  @override
  String get codexSearchTitle => 'Códice · Búsqueda';

  @override
  String codexSectionTitle(String section) {
    return 'Códice · $section';
  }

  @override
  String get codexCategoriesTooltip => 'Categorías del Códice';

  @override
  String get codexSearchAll => 'Buscar en todo el Códice';

  @override
  String get codexHome => 'Portada';

  @override
  String get codexIntro =>
      'Todo el contenido del juego para leer, sin crear un personaje ni editar nada. Tu homebrew aparece mezclado con el resto, con su marca de procedencia.';

  @override
  String codexNoMatch(String query) {
    return 'Nada del Códice coincide con «$query».';
  }

  @override
  String codexSeeAll(Object count, String category) {
    return 'Ver las $count coincidencias en $category';
  }

  @override
  String get codexPickEntry => 'Elegí una entrada para leerla.';

  @override
  String codexSearchIn(String category) {
    return 'Buscar en $category';
  }

  @override
  String get codexNothingMatches => 'Nada coincide con lo que buscaste.';

  @override
  String get codexClearFilters => 'Limpiar filtros';

  @override
  String get codexBackToList => 'Volver al listado';

  @override
  String codexLineageOf(String race) {
    return 'Linaje de $race';
  }

  @override
  String codexLevelN(Object level) {
    return 'nivel $level';
  }

  @override
  String codexPickAny(Object count) {
    return 'elegí $count, cualquiera';
  }

  @override
  String codexPickFrom(Object count, String list) {
    return 'elegí $count entre $list';
  }

  @override
  String codexSubclassOf(String klass) {
    return 'Subclase de $klass';
  }

  @override
  String get commonYes => 'Sí';

  @override
  String get codexCategory => 'Categoría';

  @override
  String get codexRequirements => 'Requisitos';

  @override
  String get codexRepeatable => 'Repetible';

  @override
  String codexRitual(String time) {
    return '$time o ritual';
  }

  @override
  String codexConcentration(String duration) {
    return 'Concentración, $duration';
  }

  @override
  String get codexCanPrepare => 'Lo pueden preparar';

  @override
  String codexRarityAttune(String rarity) {
    return '$rarity · sintonización';
  }

  @override
  String get codexRarity => 'Rareza';

  @override
  String get codexAttunement => 'Sintonización';

  @override
  String get codexRequires => 'Requiere';

  @override
  String get codexNotRequired => 'No requiere';

  @override
  String get codexCharges => 'Cargas';

  @override
  String get codexWeight => 'Peso';

  @override
  String get codexPrice => 'Precio';

  @override
  String get codexMastery => 'Maestría';

  @override
  String get codexProperties => 'Propiedades';

  @override
  String codexAcDex(Object ac) {
    return '$ac + mod. DES';
  }

  @override
  String codexAcDexMax(Object ac, Object max) {
    return '$ac + mod. DES (máx. $max)';
  }

  @override
  String codexArmorSubtitle(String category, String ac) {
    return '$category · CA $ac';
  }

  @override
  String get codexStrength => 'Fuerza';

  @override
  String get codexStealth => 'Sigilo';

  @override
  String get codexDisadvantage => 'Desventaja';

  @override
  String get codexPackOf => 'Paquete de';

  @override
  String codexPrereqFeat(String category) {
    return 'una dote de $category';
  }

  @override
  String get codexPrereqCast => 'lanzar conjuros';

  @override
  String codexPrereqProf(String proficiency) {
    return 'competencia: $proficiency';
  }

  @override
  String get styleDigitalFantasy => 'Arte digital de fantasía';

  @override
  String get styleClassicOil => 'Óleo clásico';

  @override
  String get styleComic => 'Ilustración de cómic';

  @override
  String get styleCinematic => 'Realista cinematográfico';

  @override
  String get styleWatercolor => 'Acuarela';

  @override
  String get stylePixelArt => 'Pixel art';

  @override
  String get stylePencilSketch => 'Boceto a lápiz';

  @override
  String get styleCustom => 'Personalizado';

  @override
  String get portraitDefaultError =>
      'No se pudo fijar como predeterminado, pero vale para esta sesión.';

  @override
  String get portraitOffline =>
      'Sin conexión con el servidor. La generación requiere red.';

  @override
  String portraitGenerateError(String message) {
    return 'No se pudo generar: $message';
  }

  @override
  String get portraitGenerateFailed => 'No se pudo generar';

  @override
  String get portraitPickReference => 'Elegir imagen de referencia';

  @override
  String get portraitReferenceError =>
      'No se pudo elegir la imagen de referencia';

  @override
  String get portraitPickImage => 'Elegir imagen de retrato';

  @override
  String get portraitImportError => 'No se pudo importar la imagen';

  @override
  String get portraitSaveError => 'No se pudo guardar el retrato';

  @override
  String get portraitSaved => 'Retrato guardado.';

  @override
  String get portraitRestored => 'Retrato restaurado.';

  @override
  String get portraitDeleteTitle => 'Borrar retrato';

  @override
  String get portraitDeleteBody =>
      'El retrato se borra para siempre y no se puede recuperar.';

  @override
  String get portraitDeleteError => 'No se pudo borrar el retrato';

  @override
  String get portraitDeleted => 'Retrato borrado.';

  @override
  String get portraitBackToThis => 'Volver a este retrato';

  @override
  String get portraitDeleteThis => 'Borrar este retrato';

  @override
  String get portraitCurrent => 'Retrato actual';

  @override
  String portraitPrevious(Object index) {
    return 'Retrato anterior $index';
  }

  @override
  String get portraitLoadingSettings => 'Cargando configuración…';

  @override
  String get portraitUseThis => 'Usar este retrato';

  @override
  String get portraitSavedTitle => 'Retratos guardados';

  @override
  String get portraitSummoning => 'INVOCANDO';

  @override
  String get portraitBaseDescription => 'DESCRIPCIÓN BASE · AUTOMÁTICA';

  @override
  String get portraitUsedPrompt => 'PROMPT USADO';

  @override
  String get portraitGenerateAi => 'Generar con IA';

  @override
  String get portraitUpload => 'Subir imagen';

  @override
  String get portraitNoProviders =>
      'Este servidor no tiene ningún proveedor de generación configurado. Todavía podés subir tu propio retrato.';

  @override
  String get portraitEngine => 'Motor de generación';

  @override
  String get portraitStyle => 'Estilo';

  @override
  String get portraitCustomStyle => 'Estilo personalizado';

  @override
  String get portraitExtraDetails => 'Detalles adicionales';

  @override
  String get portraitAppearance => 'Apariencia';

  @override
  String get portraitDetailsHint => 'Color de pelo, cicatrices, actitud…';

  @override
  String get portraitReference => 'Imagen de referencia · opcional';

  @override
  String get portraitChooseImage => 'Elegir imagen…';

  @override
  String get portraitRemoveReference => 'Quitar referencia';

  @override
  String get portraitGenerating => 'Generando…';

  @override
  String get portraitGenerate => 'Generar';

  @override
  String get portraitGenerateAgain => 'Generar otra vez';

  @override
  String get portraitFreeNote =>
      'El servicio gratuito puede tardar hasta ~1 min y genera 2 variantes de a una. Si aparece un error de límite (429), esperá unos segundos y reintentá.';

  @override
  String get portraitImporting => 'Importando…';

  @override
  String get portraitImportTitle => 'Importar imagen desde archivo';

  @override
  String get portraitImportHint => 'Tocá para elegirla. PNG, JPG o WEBP.';

  @override
  String get portraitImportNote =>
      'La imagen pasa a ser el retrato del personaje. Podés volver a generar con IA cuando quieras.';

  @override
  String get portraitAcceptsReference => 'Acepta referencia';

  @override
  String get portraitTextOnly => 'Solo texto';

  @override
  String get portraitPickStyle => 'Elegir estilo';

  @override
  String get spellEditTitle => 'Editar conjuros';

  @override
  String spellEditTitleClass(String klass) {
    return 'Editar conjuros · $klass';
  }

  @override
  String spellEditCantrips(Object count, Object max) {
    return 'Trucos ($count/$max)';
  }

  @override
  String get spellEditGrantedCantrips =>
      'Los trucos que ya tenés por otro rasgo no aparecen acá: no ocupan un cupo de truco de clase.';

  @override
  String spellEditPrepared(Object count, Object max) {
    return 'Conjuros preparados ($count/$max)';
  }

  @override
  String spellEditKnown(Object count) {
    return 'Conjuros conocidos ($count)';
  }

  @override
  String spellEditUpTo(Object level) {
    return 'Hasta nivel $level.';
  }

  @override
  String get hbSimple => 'Simple';

  @override
  String get hbMartial => 'Marcial';

  @override
  String get hbNoMastery => 'Sin maestría';

  @override
  String get hbLight => 'Ligera';

  @override
  String get hbMedium => 'Media';

  @override
  String get hbHeavy => 'Pesada';

  @override
  String get hbMundane => 'Mundano';

  @override
  String get hbFeatOrigin => 'De origen';

  @override
  String get hbFeatGeneral => 'General';

  @override
  String get hbFeatFighting => 'Estilo de combate';

  @override
  String get hbFeatDragonmark => 'Marca dracónica';

  @override
  String get hbFeatEpic => 'Don épico';

  @override
  String get sizeSmall => 'Pequeño';

  @override
  String get sizeMedium => 'Mediano';

  @override
  String get sizeLarge => 'Grande';

  @override
  String get catItems => 'Objetos';

  @override
  String get catCreatures => 'Criaturas';

  @override
  String get hbAddWeapon => 'Agregar arma';

  @override
  String get hbAddArmor => 'Agregar armadura';

  @override
  String get hbAddFeat => 'Agregar dote';

  @override
  String get hbAddSpecies => 'Agregar especie';

  @override
  String get hbAddBackground => 'Agregar trasfondo';

  @override
  String get hbAddSpell => 'Agregar conjuro';

  @override
  String get hbAddCreature => 'Agregar criatura';

  @override
  String hbSaved(String name) {
    return '«$name» se guardó.';
  }

  @override
  String get hbNoChanges => 'No se guardó ningún cambio.';

  @override
  String get hbSaveError => 'No se pudo guardar el contenido homebrew';

  @override
  String get hbNothingToExport => 'No hay contenido homebrew para exportar.';

  @override
  String hbExported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entradas',
      one: '1 entrada',
    );
    return 'Homebrew exportado ($_temp0).';
  }

  @override
  String get hbPickFile => 'Elegí un archivo de homebrew (.json)';

  @override
  String get hbOverwriteTitle => 'Sobrescribir homebrew';

  @override
  String hbOverwriteBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entradas del archivo comparten',
      one: '1 entrada del archivo comparte',
    );
    return '$_temp0 id con contenido que ya tenés. Al importar se reemplazarán. ¿Continuar?';
  }

  @override
  String get hbOverwrite => 'Sobrescribir';

  @override
  String hbImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se importaron $count entradas de homebrew.',
      one: 'Se importó 1 entrada de homebrew.',
    );
    return '$_temp0';
  }

  @override
  String get hbImportError => 'No se pudo importar el homebrew';

  @override
  String hbLoadIssues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entradas no se pudieron cargar',
      one: '1 entrada no se pudo cargar',
    );
    return '$_temp0';
  }

  @override
  String hbSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se omitieron',
      one: 'Se omitió',
    );
    return '$_temp0 al iniciar. El resto de tu homebrew está intacto.';
  }

  @override
  String get hbDeleteInvalid => 'Borrar entrada inválida';

  @override
  String get hbCategoriesTooltip => 'Categorías de homebrew';

  @override
  String get hbTitleSearch => 'Homebrew · Búsqueda';

  @override
  String hbTitleSection(String section) {
    return 'Homebrew · $section';
  }

  @override
  String get hbSearch => 'Buscar';

  @override
  String get hbMatches => 'Coincidencias';

  @override
  String get hbYourContent => 'Tu contenido';

  @override
  String get hbImportFile => 'Importar archivo';

  @override
  String get hbExportAll => 'Exportar todo';

  @override
  String hbNoMatch(String query) {
    return 'Nada de tu contenido coincide con «$query».';
  }

  @override
  String hbResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resultados',
      one: '1 resultado',
    );
    return '$_temp0';
  }

  @override
  String hbFor(String query) {
    return 'para «$query»';
  }

  @override
  String get hbWorkshop => 'Tu taller';

  @override
  String hbWorkshopIntro(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entradas propias',
      one: '1 entrada propia',
    );
    return '$_temp0. Todo lo que crees acá se suma al catálogo: aparece en la creación de personajes y en las fichas, igual que el contenido oficial.';
  }

  @override
  String get hbCategories => 'Categorías';

  @override
  String get hbNothingYet => 'Nada todavía.';

  @override
  String get hbWorkshopEmpty => 'Tu taller está vacío';

  @override
  String get hbWorkshopEmptyBody =>
      'Homebrew es contenido tuyo: un arma, un conjuro, una criatura. Se guarda en tu cuenta y se suma al catálogo, al lado del oficial. Armas, armaduras, objetos, conjuros, dotes, especies y trasfondos aparecen en la creación de personajes y en las fichas; las criaturas, en el Bestiario y en Combate.';

  @override
  String get hbStartWeapon => 'Empezar por un arma';

  @override
  String get hbImportAFile => 'Importar un archivo';

  @override
  String get hbDuplicateFromCatalog => 'Duplicar del catálogo';

  @override
  String hbNothingIn(String category) {
    return 'Todavía no agregaste nada en $category.';
  }

  @override
  String hbDuplicateTitle(String title) {
    return 'Duplicar $title';
  }

  @override
  String hbDeleteTooltip(String title) {
    return 'Borrar $title';
  }

  @override
  String get hbEffects => 'Efectos';

  @override
  String get hbRitual => 'Ritual';

  @override
  String get hbAvailableToCharacters => 'Disponible para personajes';

  @override
  String get hbKindWeapon => 'el arma';

  @override
  String get hbKindArmor => 'la armadura';

  @override
  String get hbKindItem => 'el objeto';

  @override
  String get hbKindFeat => 'la dote';

  @override
  String get hbKindSpecies => 'la especie';

  @override
  String get hbKindBackground => 'el trasfondo';

  @override
  String get hbKindSpell => 'el conjuro';

  @override
  String get hbKindCreature => 'la criatura';

  @override
  String hbDeleteTitle(String kind, String name) {
    return '¿Borrar $kind «$name»?';
  }

  @override
  String get hbNoUsers => 'Ninguna de tus fichas lo está usando.';

  @override
  String hbUsers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Lo usan $count fichas:',
      one: 'Lo usa 1 ficha:',
    );
    return '$_temp0';
  }

  @override
  String hbUsersWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Van a quedar con una advertencia en sus fichas.',
      one: 'Va a quedar con una advertencia en su ficha.',
    );
    return '$_temp0';
  }

  @override
  String hbDeleted(String name) {
    return '$name se borró.';
  }

  @override
  String hbDuplicateDialog(String category) {
    return 'Duplicar $category';
  }

  @override
  String get hbSearchCatalog => 'Buscar en el catálogo';

  @override
  String hbCatalogNoMatch(String query) {
    return 'Nada del catálogo coincide con «$query».';
  }

  @override
  String get hbLeaveTitle => '¿Salir sin guardar?';

  @override
  String hbLeaveBody(String title) {
    return 'Lo que escribiste en «$title» se pierde.';
  }

  @override
  String get hbKeepEditing => 'Seguir editando';

  @override
  String get hbLeave => 'Salir sin guardar';

  @override
  String get hbFixFields =>
      'No se guardó nada: revisá los campos marcados en rojo.';

  @override
  String get hbOptionalRule => 'Lo demás es opcional';

  @override
  String get hbAlreadyChosen => 'Lo que ya elegiste';

  @override
  String get hbNoNameYet => 'Todavía sin nombre';

  @override
  String get hbGrantsNothing => 'Todavía no concede nada.';

  @override
  String get hbDiceRequired => 'Escribí un dado, por ejemplo 1d8.';

  @override
  String get hbDiceInvalid =>
      'Formato de dado inválido: se espera algo como 1d8.';

  @override
  String get hbNumberRequired => 'Escribí un número.';

  @override
  String get hbIntInvalid => 'Tiene que ser un número entero.';

  @override
  String hbRange(Object min, Object max) {
    return 'Tiene que estar entre $min y $max.';
  }

  @override
  String get hbWeightRequired => 'Escribí un peso, 0 si no cuenta.';

  @override
  String get hbNumberInvalid => 'Tiene que ser un número.';

  @override
  String get hbNegative => 'No puede ser negativo.';

  @override
  String get hbDamageType => 'Tipo de daño';

  @override
  String hbUnknownValue(String value) {
    return '$value (desconocido)';
  }

  @override
  String get hbRangeLongMin => 'No puede ser menor que el normal.';

  @override
  String get hbNoMasteryRule =>
      'Al que tiene el rasgo Maestría con armas no le suma nada.';

  @override
  String get hbNoRange => 'Sin alcance';

  @override
  String hbRangeFeet(String normal, String long) {
    return '$normal/$long pies';
  }

  @override
  String get hbProperty => 'Propiedad';

  @override
  String get hbNone => 'ninguna';

  @override
  String get hbNoMasteryLower => 'sin maestría';

  @override
  String get hbPreviewTitle => 'Así queda en tu lista';

  @override
  String get hbWeaponHint =>
      'Tocá la categoría, el tipo de daño, una propiedad o la maestría para ver qué hace.';

  @override
  String get hbReqWeaponName => 'Escribí el nombre del arma.';

  @override
  String get hbDamageDie => 'Dado de daño';

  @override
  String get hbVersatile => 'Dado versátil (p.ej. 1d10)';

  @override
  String get hbRangeNormal => 'Alcance normal (pies)';

  @override
  String get hbRangeLong => 'Alcance largo (pies)';

  @override
  String get hbMasteryMagic => 'Maestría y magia';

  @override
  String get hbMagicBonus => 'Bonificador mágico (+0 a +3)';

  @override
  String get hbLegendWeapon => 'Descripción (la leyenda del arma)';

  @override
  String get hbEconomy => 'Economía';

  @override
  String get hbNotSet => 'sin cargar';

  @override
  String get hbWeightLabel => 'Peso en libras (0 si no cuenta)';

  @override
  String get hbPriceLabel => 'Precio en piezas de cobre (1 po = 100)';

  @override
  String get hbLegend => 'Leyenda';

  @override
  String get hbLoaded => 'cargada';

  @override
  String get hbArmorBaseAc => 'CA base';

  @override
  String get hbNotFilled => 'Sin cargar';

  @override
  String get hbDexterity => 'Destreza';

  @override
  String get hbAddsDex => 'Suma Destreza';

  @override
  String get hbNoDex => 'Sin Destreza';

  @override
  String get hbDexCap => 'Tope de Destreza';

  @override
  String get hbNoCap => 'Sin tope';

  @override
  String hbUpTo(String cap) {
    return 'Hasta +$cap';
  }

  @override
  String get hbDemand => 'Exigencia';

  @override
  String get hbNoStrReq => 'Sin requisito de Fuerza';

  @override
  String hbStrength(String score) {
    return 'Fuerza $score';
  }

  @override
  String get hbStealthDisadv => 'Sigilo con desventaja';

  @override
  String get hbNoStealthDisadv => 'Sin desventaja en Sigilo';

  @override
  String get hbNoDexLower => 'sin Destreza';

  @override
  String get hbFullDex => 'Destreza entera';

  @override
  String hbUpToLower(String cap) {
    return 'hasta +$cap';
  }

  @override
  String get hbOnSheet => 'En la ficha';

  @override
  String hbAcWithDex(Object dex) {
    return 'CA con DES +$dex';
  }

  @override
  String get hbArmorHint =>
      'Tocá la categoría, la CA o cómo suma la Destreza para ver qué cambia.';

  @override
  String get hbReqArmorName => 'Escribí el nombre de la armadura.';

  @override
  String get hbShieldAc => 'CA que suma';

  @override
  String get hbHowDex => 'Cómo suma la Destreza';

  @override
  String get hbAddsDexMod => 'Suma modificador de DES';

  @override
  String get hbDexCapLabel => 'Tope de DES (vacío = sin tope)';

  @override
  String get hbDemands => 'Exigencias';

  @override
  String get hbStrReqLabel => 'Requisito de Fuerza (opcional)';

  @override
  String get hbStealthLabel => 'Desventaja en Sigilo';

  @override
  String get hbLegendArmor => 'Descripción (la leyenda de la armadura)';

  @override
  String get hbNoneCap => 'Ninguno';

  @override
  String get hbMagic => 'Magia';

  @override
  String get hbNoAttunement => 'Sin sintonización';

  @override
  String get hbEffect => 'Efecto';

  @override
  String get hbBaseItem => 'Objeto base';

  @override
  String hbBonusValue(String value) {
    return 'Bonificador $value';
  }

  @override
  String hbMoreEffects(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count efectos más',
      one: '1 efecto más',
    );
    return '$_temp0';
  }

  @override
  String get hbNoneM => 'ninguno';

  @override
  String get hbItem => 'Objeto';

  @override
  String get hbItemHint =>
      'Tocá la categoría, la rareza o un efecto para ver qué hace el objeto en la ficha.';

  @override
  String get hbReqItemName => 'Escribí el nombre del objeto.';

  @override
  String get hbWeightShort => 'Peso (lb)';

  @override
  String get hbPriceCp => 'Precio (pc)';

  @override
  String get hbMundaneLower => 'mundano';

  @override
  String get hbRequiresAttunement => 'Requiere sintonización';

  @override
  String get hbOnlyMagicAttune => 'Solo los objetos mágicos se sintonizan.';

  @override
  String get hbEffectsEquipped => 'Efectos mientras esté equipado';

  @override
  String get hbAcBonusLabel => 'Bonificador a la Clase de Armadura';

  @override
  String get hbResistances => 'Resistencias';

  @override
  String get hbOtherEffects => 'Otros efectos';

  @override
  String get hbMagicBonusShort => 'Bonificador mágico';

  @override
  String get hbAllowedBases => 'Bases permitidas';

  @override
  String get hbAnyBase =>
      'Sin marcar ninguna, sirve cualquiera de la familia elegida.';

  @override
  String get hbOnlyMarked => 'Solo se va a poder usar lo que marques acá.';

  @override
  String get hbDescription => 'Descripción';

  @override
  String get hbRepetition => 'Repetición';

  @override
  String get hbOnce => 'Una sola vez';

  @override
  String get hbFeatPreview => 'Así la ve el jugador';

  @override
  String get hbFeatNoDescription =>
      'Sin descripción, el jugador solo ve lo que concede. Una línea que diga qué la hace distinta ayuda a elegirla.';

  @override
  String get hbFeatHint =>
      'Tocá la categoría para ver quién puede tomar la dote.';

  @override
  String get hbReqFeatName => 'Escribí el nombre de la dote.';

  @override
  String get hbFeatDistinct => 'Qué la hace distinta';

  @override
  String get hbGrants => 'Qué concede';

  @override
  String get hbPrereqRepeat => 'Requisitos y repetición';

  @override
  String get hbNoPrereq => 'sin requisitos';

  @override
  String get hbWithPrereq => 'con requisitos';

  @override
  String get hbRepeatableLower => 'repetible';

  @override
  String get hbOnceLower => 'una vez';

  @override
  String get hbRepeatSwitch => 'Se puede tomar más de una vez';

  @override
  String get hbKeepPrereq => 'Conserva el requisito de la dote original.';

  @override
  String hbEffectsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count efectos',
      one: '1 efecto',
      zero: 'sin efectos',
    );
    return '$_temp0';
  }

  @override
  String get hbNoType => 'Sin tipo';

  @override
  String get hbAmongWhichChooses => 'Entre cuáles elige';

  @override
  String get hbSizeToChoose => 'Tamaño a elegir';

  @override
  String hbAmongAll(Object count) {
    return '$count entre todas';
  }

  @override
  String hbAmongN(Object count, Object n) {
    return '$count entre $n';
  }

  @override
  String get hbRacePreview => 'Cómo se va a ver al crear un personaje';

  @override
  String get hbRaceHint =>
      'Tocá el tipo, el tamaño, la velocidad o las habilidades para ver qué implican.';

  @override
  String get hbReqRaceName => 'Escribí el nombre de la especie.';

  @override
  String get hbSpeedFeet => 'Velocidad (pies)';

  @override
  String get hbPresentation => 'Presentación';

  @override
  String get hbTaglineLower => 'lema';

  @override
  String get hbDescriptionLower => 'descripción';

  @override
  String get hbTaglineLabel => 'Lema (una línea, se ve al elegirla)';

  @override
  String get hbHowMany => 'Cuántas elige';

  @override
  String get hbAmongWhich => 'Entre cuáles';

  @override
  String hbOnlySize(String size) {
    return 'solo $size';
  }

  @override
  String get hbAllThree => 'Las tres del aumento';

  @override
  String get hbNoOriginFeat => 'Sin dote de origen';

  @override
  String get hbNoneF => 'Ninguna';

  @override
  String get hbIncrease => 'Aumento';

  @override
  String get hbBgHint =>
      'Tocá las características o la dote de origen para ver qué le dan al personaje.';

  @override
  String get hbReqBgName => 'Escribí el nombre del trasfondo.';

  @override
  String get hbThreeAbilities => 'Elegí exactamente tres características.';

  @override
  String get hbPick3 => 'Características · elegí 3';

  @override
  String get hbNoneParen => '(ninguna)';

  @override
  String get hbTaglineLabelM => 'Lema (una línea, se ve al elegirlo)';

  @override
  String get hbExtraEffects => 'Efectos adicionales';

  @override
  String get classWizard => 'Mago';

  @override
  String get classSorcerer => 'Hechicero';

  @override
  String get classCleric => 'Clérigo';

  @override
  String get classDruid => 'Druida';

  @override
  String get classBard => 'Bardo';

  @override
  String get classWarlock => 'Brujo';

  @override
  String get classPaladin => 'Paladín';

  @override
  String get classRanger => 'Explorador';

  @override
  String get classArtificer => 'Artífice';

  @override
  String get compVerbal => 'Verbal';

  @override
  String get compSomatic => 'Somático';

  @override
  String get compMaterial => 'Material';

  @override
  String get hbSchool => 'Escuela';

  @override
  String get hbCastingTime => 'Tiempo de lanzamiento';

  @override
  String get hbClassLists => 'Listas de clase';

  @override
  String get hbComponent => 'Componente';

  @override
  String get hbSpell => 'Conjuro';

  @override
  String get hbSpellPreview => 'Cómo se va a ver en la ficha';

  @override
  String get hbSpellHint =>
      'Tocá el nivel, la escuela, el tiempo de lanzamiento o un componente para ver qué implica.';

  @override
  String get hbReqSpellName => 'Escribí el nombre del conjuro.';

  @override
  String get hbNoSchool => 'Sin escuela';

  @override
  String get hbRangeExample => 'Alcance (p.ej. 60 pies)';

  @override
  String get hbMaterialExample => 'Material (p.ej. una pizca de ceniza)';

  @override
  String get hbConcRitual => 'Concentración y ritual';

  @override
  String get hbConcentrationLower => 'concentración';

  @override
  String get hbRitualLower => 'ritual';

  @override
  String get hbSpellDoes => 'Qué hace el conjuro';

  @override
  String get hbHitDice => 'Dados de golpe';

  @override
  String get hbHitDiceRule =>
      'Con dados de golpe cargados, al sumarla a un combate se puede pedir que cada copia tire los suyos.';

  @override
  String get hbChallenge => 'Desafío';

  @override
  String get hbNoCr => 'Sin VD';

  @override
  String hbCrValue(String value) {
    return 'VD $value';
  }

  @override
  String get hbOutOfCombat => 'Fuera de combate';

  @override
  String get hbAlsoCharacters => 'También para personajes';

  @override
  String get hbOnlyYourCombats => 'Solo en tus combates';

  @override
  String get hbAvailableRule =>
      'Hoy solo lo mira el pozo de Forma Salvaje: una bestia con valor de desafío puede aparecer entre las formas del druida. Apagado, la criatura vive únicamente en tus combates.';

  @override
  String get hbAttackBonus => 'Bonificador de ataque';

  @override
  String get hbWhenUsed => 'Cuándo se usa';

  @override
  String get hbCreature => 'Criatura';

  @override
  String get hbCreaturePreview => 'Cómo se va a ver en el Bestiario';

  @override
  String get hbCreatureHint =>
      'Tocá el tipo, el tamaño o una acción para ver qué cambia en la mesa.';

  @override
  String get hbReqCreatureName => 'Escribí el nombre de la criatura.';

  @override
  String get hbSpeedHint => 'p.ej. 30 pies, volar 60 pies';

  @override
  String hbWillRead(String kind) {
    return 'Se va a leer «$kind».';
  }

  @override
  String get hbHitDiceOptional => 'Dados de golpe (opcional)';

  @override
  String get hbDiceExample => 'p.ej. 2d6 + 2';

  @override
  String get hbProfile => 'Perfil';

  @override
  String get hbCrExample => 'p.ej. 1/4 o 5';

  @override
  String get hbInitHint => 'Vacío: el mod. de DES';

  @override
  String get hbPassiveOptional => 'Percepción pasiva (opcional)';

  @override
  String get hbPerRound => 'Por ronda';

  @override
  String get hbSensesHint => 'p.ej. visión en la oscuridad 60 pies';

  @override
  String get hbDefenses => 'Resistencias, inmunidades y vulnerabilidades';

  @override
  String get hbNoTraits => 'sin rasgos';

  @override
  String get hbTrait => 'Rasgo';

  @override
  String get hbReqTraitName => 'Escribí el nombre del rasgo.';

  @override
  String get hbAddTrait => 'Agregar rasgo';

  @override
  String hbActionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count acciones',
      one: '1 acción',
      zero: 'sin acciones',
    );
    return '$_temp0';
  }

  @override
  String get hbAddAction => 'Agregar acción';

  @override
  String get hbAlsoCharactersLower => 'también para personajes';

  @override
  String get hbOnlyYourCombatsLower => 'solo en tus combates';

  @override
  String get hbAvailableSwitch => 'Disponible en la construcción de personajes';

  @override
  String get hbReqActionName => 'Escribí el nombre de la acción.';

  @override
  String get hbAttackBonusLabel =>
      'Bonificador de ataque (vacío = no es ataque)';

  @override
  String get hbReachLabel => 'Alcance (p.ej. 5 pies)';

  @override
  String get hbDamageLabel => 'Daño (p.ej. 1d8 + 3)';

  @override
  String get hbNoDamage => 'Sin daño';

  @override
  String get hbActionDescription => 'Descripción (lo que pasa además del daño)';

  @override
  String get hbCrInvalid => 'Se espera un número o una fracción, como 1/4 o 5.';

  @override
  String get hbHitDiceInvalid =>
      'Formato inválido: se espera algo como 2d6 + 2.';

  @override
  String get effNone => 'Sin efectos.';

  @override
  String get effRemove => 'Quitar efecto';

  @override
  String get effAdd => 'Agregar efecto';

  @override
  String get effKindAbilityBonus => 'Bonificador a característica';

  @override
  String get effKindSetAbility => 'Fijar una característica';

  @override
  String get effKindHpPerLevel => 'PG máx por nivel';

  @override
  String get effKindHpFlat => 'PG máx, una vez';

  @override
  String get effKindAcBonus => 'Bonificador a la CA';

  @override
  String get effKindInitiative => 'Bonificador a la iniciativa';

  @override
  String get effKindSpeedBonus => 'Bonificador de velocidad';

  @override
  String get effKindSetSpeed => 'Fijar la velocidad';

  @override
  String get effKindSkillProf => 'Competencia en habilidad';

  @override
  String get effKindSaveProf => 'Competencia en salvación';

  @override
  String get effKindSaveBonus => 'Bonificador a las salvaciones';

  @override
  String get effKindWeaponProf => 'Competencia con armas';

  @override
  String get effKindArmorProf => 'Competencia con armadura';

  @override
  String get effKindToolProf => 'Competencia con herramienta';

  @override
  String get effLanguage => 'Idioma';

  @override
  String get effKindResistance => 'Resistencia a daño';

  @override
  String get effKindImmunity => 'Inmunidad a daño';

  @override
  String get effKindGrantSpell => 'Conceder un conjuro';

  @override
  String get effKindAlwaysPrepared => 'Conjuro siempre preparado';

  @override
  String get effKindSpellList => 'Sumar un conjuro a tu lista';

  @override
  String get effKindGrantFeat => 'Conceder una dote';

  @override
  String get effKindPassive => 'Rasgo pasivo';

  @override
  String get effUnitFeet => 'Pies';

  @override
  String get effUnitRangeFeet => 'Alcance en pies';

  @override
  String get effUnitValue => 'Valor';

  @override
  String get effAddsProfBonus => 'Suma el bonificador por competencia';

  @override
  String get effSkill => 'Habilidad';

  @override
  String get effHowUsed => 'Cómo se usa';

  @override
  String get effCastAbility => 'Característica para lanzarlo';

  @override
  String get effPlayerChoice => 'A elección del jugador';

  @override
  String get effTraitName => 'Nombre del rasgo';

  @override
  String effSpellLevel(String name, Object level) {
    return '$name (nivel $level)';
  }

  @override
  String get effAbility => 'Característica';

  @override
  String get dmCampaignNameRequired => 'Poné un nombre para guardarla.';

  @override
  String get dmCampaignName => 'Nombre de la campaña';

  @override
  String get dmPremise => 'Premisa';

  @override
  String get dmPremiseHint => 'El conflicto que pone esta historia en marcha…';

  @override
  String get dmNoteTitleRequired => 'Poné un título para guardarla.';

  @override
  String get dmChapter => 'Capítulo';

  @override
  String get dmNoteTitleHelper => 'Es lo que se ve en el listado y al buscar.';

  @override
  String get dmChapterNameRequired => 'Poné un nombre para guardarlo.';

  @override
  String get dmChapterName => 'Nombre del capítulo';

  @override
  String get dmChapterGoal => 'Objetivo del capítulo';

  @override
  String get dmChapterGoalHint => 'Qué debería lograr o descubrir la mesa…';

  @override
  String get dmChapterGoalHelper =>
      'Una guía breve; el relato va en el Cuaderno.';

  @override
  String get dmOnCloseCarry => 'Al cerrarlo se llevan';

  @override
  String get dmOneLevel => 'Un nivel';

  @override
  String get dmLevelUpNote => 'La subida la hace cada jugador en su ficha.';

  @override
  String get dmGoldEach => 'Oro para cada personaje';

  @override
  String get dmGoldHelper => 'Ya repartido: la app no divide el botín.';

  @override
  String get dmItems => 'Ítems';

  @override
  String get dmItemsHint => 'Uno por línea…';

  @override
  String get dmItemsHelper => 'Se los anota cada jugador en su inventario.';

  @override
  String dmEffectsOf(String name) {
    return 'Efectos de $name';
  }

  @override
  String get dmNoteEffect => 'Anotar un efecto';

  @override
  String get dmNoteEffectHint => 'Marcado por el pícaro…';

  @override
  String dmRemoveTag(String tag) {
    return 'Sacar «$tag»';
  }

  @override
  String get dmBookConditions => 'Condiciones del libro';

  @override
  String get dmEffectsArePrivate =>
      'Los efectos son tuyos: al jugador no le llega nada, se lo decís en la mesa.';

  @override
  String get dmRollInitiative => 'Tirar iniciativa';

  @override
  String get dmPlayers => 'Jugadores';

  @override
  String get dmNoPlayers => 'Ningún jugador.';

  @override
  String get dmMonstersAndNpcs => 'Monstruos y PNJ';

  @override
  String get dmNoMonstersOrNpcs => 'Ningún monstruo ni PNJ.';

  @override
  String get dmRoundOneStarts => 'Al confirmar arranca la ronda 1.';

  @override
  String dmInitiativeMissing(String names) {
    return 'Falta la iniciativa de $names. Si alguien no vino, sacalo del combate: cuando llegue se suma con su tirada.';
  }

  @override
  String get dmStart => 'Empezar';

  @override
  String evtLinked(String character, String campaign) {
    return '$character se sumó a la campaña $campaign.';
  }

  @override
  String evtUnlinkedByDm(String character, String campaign) {
    return '$character ya no forma parte de $campaign.';
  }

  @override
  String evtUnlinkedByOwner(String character, String campaign) {
    return '$character salió de tu campaña $campaign.';
  }

  @override
  String evtDeletedByOwner(String character, String campaign) {
    return '$character ya no está disponible en $campaign.';
  }

  @override
  String evtInspiration(String campaign, String character) {
    return 'El DM te concedió Inspiración Heroica en $campaign. Marcala en la ficha de $character.';
  }

  @override
  String evtChapterDone(String character, String chapter, String campaign) {
    return '$character terminó el capítulo $chapter en $campaign.';
  }

  @override
  String evtTakes(String rewards) {
    return 'Se lleva $rewards.';
  }

  @override
  String get evtCanLevelUp => 'Podés subir de nivel.';

  @override
  String get evtSomeCharacter => 'Un personaje';

  @override
  String get evtSomeChapter => 'Un capítulo';

  @override
  String get evtSomeCampaign => 'Una campaña';

  @override
  String evtQuoted(String text) {
    return '«$text»';
  }

  @override
  String get sideAlly => 'Aliado';

  @override
  String get sideEnemy => 'Enemigo';

  @override
  String get sideNeutral => 'Neutral';

  @override
  String get kindPlayer => 'Jugador';

  @override
  String get kindMonster => 'Monstruo';

  @override
  String get kindNpc => 'PNJ';

  @override
  String get npcKindNone => 'Sin estadísticas';

  @override
  String get npcKindBlock => 'Bloque propio';

  @override
  String get npcKindCharacter => 'Ficha de personaje';

  @override
  String get npcAlive => 'Vivo';

  @override
  String get npcDead => 'Muerto';

  @override
  String get npcUnknown => 'Desconocido';

  @override
  String npcBlockLine(String base, String ac, String hp) {
    return '$base · CA $ac · PG $hp';
  }

  @override
  String npcCharacterLine(String classes) {
    return 'Ficha de personaje · $classes';
  }

  @override
  String get npcNew => 'Nuevo PNJ';

  @override
  String get npcWhichSheet => '¿Qué ficha lleva?';

  @override
  String get npcNewNone => 'PNJ sin estadísticas';

  @override
  String get npcNewBlock => 'PNJ con bloque';

  @override
  String get npcNewCharacter => 'Personaje jugable';

  @override
  String get npcNewNoneHint =>
      'Solo nombre, trasfondo y notas. El tabernero, el alcalde.';

  @override
  String get npcNewBlockHint =>
      'Un bloque propio como los del bestiario: copiá el de una criatura y retocalo, o arrancá vacío.';

  @override
  String get npcNewCharacterHint =>
      'Pasa por el creador de personajes: especie, clase, niveles y dotes. El villano de un trasfondo.';

  @override
  String get npcStartFromCreature => 'Partir de una criatura (opcional)';

  @override
  String get npcEmptyBlock => 'Bloque vacío';

  @override
  String get npcFillLater => 'Lo completás después.';

  @override
  String npcAcHp(String ac, String hp) {
    return 'CA $ac · PG $hp';
  }

  @override
  String get npcTypeFixed =>
      'El tipo no se cambia después: define con qué se edita.';

  @override
  String get npcContinueToCreator => 'Continuar al creador';

  @override
  String get npcCreate => 'Crear';

  @override
  String get shareStop => 'Dejar de compartir';

  @override
  String shareStopBody(String campaign, String character) {
    return 'El DM de «$campaign» deja de ver a $character. Tu ficha no se toca.';
  }

  @override
  String shareStopped(String campaign) {
    return 'Ya no se comparte con $campaign.';
  }

  @override
  String shareTitle(String name) {
    return 'Compartir a $name';
  }

  @override
  String get shareIntro =>
      'Generá un código y pasáselo a tu DM. Lo pega en su campaña y ve tu ficha; nunca puede editarla.';

  @override
  String get shareGenerating => 'Generando…';

  @override
  String get shareGenerate => 'Generar código';

  @override
  String get shareSharedWith => 'Compartido con';

  @override
  String get shareCodeNote => 'Sirve una sola vez y vence en 24 horas.';

  @override
  String get shareCopied => 'Código copiado.';

  @override
  String get commonCopy => 'Copiar';

  @override
  String get commonSearching => 'Buscando…';

  @override
  String get shareNone => 'Todavía no lo compartiste con ninguna campaña.';

  @override
  String shareStopWith(String campaign) {
    return 'Dejar de compartir con $campaign';
  }

  @override
  String get dmAddToCombat => 'Sumar al combate';

  @override
  String get dmBestiary => 'Bestiario';

  @override
  String get dmAddShort => 'Sumar';

  @override
  String get dmSearchBestiary => 'Buscar en el bestiario';

  @override
  String get dmDeadHere => 'Muerto en esta campaña';

  @override
  String get dmAlsoJoinsCampaign => 'al sumarlo, entra también a la campaña';

  @override
  String get dmAlreadyInCombat => 'Ya está en el combate';

  @override
  String get dmSearchNpcs => 'Buscar PNJ';

  @override
  String get dmInThisCampaign => 'En esta campaña';

  @override
  String get dmNoneDot => 'Ninguno.';

  @override
  String get dmFromLibrary => 'De tu biblioteca · no están en esta campaña';

  @override
  String get dmLoadingLibrary => 'Cargando tu biblioteca…';

  @override
  String dmDeadNote(String name) {
    return '$name está muerto en esta campaña. Sumarlo al combate no cambia eso.';
  }

  @override
  String get dmRevive => 'Volvió: marcarlo vivo otra vez';

  @override
  String get dmWhichSide => '¿De qué lado pelea?';

  @override
  String get dmSide => 'Bando';

  @override
  String get dmStatlessSide =>
      'Sin estadísticas no tiene PG que bajar: entra neutral, con su turno, y no cuenta para ningún bando.';

  @override
  String get dmNoDefaultSide =>
      'Sin valor por defecto: el mismo PNJ puede ser aliado hoy y enemigo la sesión que viene. Un neutral tiene turno y puede tomar partido durante el combate.';

  @override
  String get dmOneFewer => 'Una copia menos';

  @override
  String get dmOneMore => 'Una copia más';

  @override
  String get dmRollEachHp => 'Tirar los PG de cada uno';

  @override
  String dmEachRolls(Object formula) {
    return 'Cada copia tira $formula por su cuenta.';
  }

  @override
  String dmAllStartWith(Object hp) {
    return 'Todas arrancan con $hp, el promedio del libro.';
  }

  @override
  String dmAddToCombatOf(String campaign) {
    return 'Sumar al combate de $campaign';
  }

  @override
  String get chapterStatePlanned => 'Próximamente';

  @override
  String get chapterStateActive => 'En marcha';

  @override
  String get chapterStateCompleted => 'Completado';

  @override
  String dmAddedToCombat(String what, String campaign) {
    return 'Sumaste $what al combate de $campaign.';
  }

  @override
  String get dmAddToCombatFailed => 'No se pudo sumar al combate';

  @override
  String get dmPickCreature => 'Elegí una criatura para ver su perfil.';

  @override
  String get dmAny => 'Cualquiera';

  @override
  String get dmSearchCreature => 'Buscar criatura';

  @override
  String get dmAllTypes => 'Todos los tipos';

  @override
  String get dmCrFrom => 'VD desde';

  @override
  String get dmCrTo => 'VD hasta';

  @override
  String get dmNoCreatureMatches =>
      'Ninguna criatura coincide con lo que buscaste.';

  @override
  String get dmCreateCampaignFirst =>
      'Para sumarla a un combate, primero creá una campaña.';

  @override
  String get dmChaptersReadFail => 'No se pudieron leer los capítulos.';

  @override
  String get dmChaptersLoading => 'Cargando los capítulos…';

  @override
  String get dmChaptersEmpty =>
      'Todavía no dividiste esta campaña en capítulos. Sirven para llevar por dónde va la historia.';

  @override
  String dmCloseChapterBody(String name) {
    return '«$name» pasa a completado y a cada jugador de la mesa le llega el aviso.';
  }

  @override
  String dmCloseChapterBodyRewards(String name, String rewards) {
    return '«$name» pasa a completado y a cada jugador de la mesa le llega el aviso, con que se llevan $rewards. Eso lo anota cada uno en su ficha: la app no se lo aplica a nadie.';
  }

  @override
  String get dmCloseChapter => 'Cerrar capítulo';

  @override
  String get dmDeleteChapter => 'Borrar capítulo';

  @override
  String dmDeleteChapterBody(String name) {
    return 'Se borra «$name» y lo que hayas escrito en él. A los jugadores no les llega nada.';
  }

  @override
  String get dmLevelsUp => 'Sube de nivel';

  @override
  String dmGoalLine(String goal) {
    return 'Objetivo: $goal';
  }

  @override
  String dmRewardsTook(String rewards) {
    return 'Se llevaron $rewards';
  }

  @override
  String dmRewardsTake(String rewards) {
    return 'Se llevan $rewards';
  }

  @override
  String get dmViewInNotebook => 'Ver en Cuaderno';

  @override
  String get dmNotebookReadFail => 'No se pudo leer el cuaderno.';

  @override
  String get dmNotebookLoading => 'Cargando el cuaderno…';

  @override
  String get dmNotebookNeedsChapter =>
      'El cuaderno se ordena por capítulo, así que primero hay que crear uno. Desde Capítulos.';

  @override
  String get dmSearchNotebook => 'Buscar en el cuaderno';

  @override
  String get dmNoChapter => 'Sin capítulo';

  @override
  String get dmLooseFights =>
      'Combates que se jugaron sin ningún capítulo en marcha.';

  @override
  String get dmDeleteNote => 'Borrar nota';

  @override
  String dmDeleteNoteBody(String title) {
    return 'Se borra «$title» y no se puede deshacer.';
  }

  @override
  String get dmCombat => 'Combate';

  @override
  String dmCombatAgainst(String enemies) {
    return 'Combate contra $enemies';
  }

  @override
  String dmDistributed(String grants) {
    return 'Se repartió $grants.';
  }

  @override
  String get dmNothingNoted => 'Todavía no hay nada anotado en este capítulo.';

  @override
  String get dmNoEntries => 'Sin entradas';

  @override
  String dmNotesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notas',
      one: '1 nota',
    );
    return '$_temp0';
  }

  @override
  String dmFightsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count combates',
      one: '1 combate',
    );
    return '$_temp0';
  }

  @override
  String get dmNoteActions => 'Acciones de la nota';

  @override
  String dmRounds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rondas',
      one: '1 ronda',
    );
    return '$_temp0';
  }

  @override
  String get dmToday => 'hoy';

  @override
  String get dmYesterday => 'ayer';

  @override
  String dmDaysAgo(int days) {
    return 'hace $days días';
  }

  @override
  String get dmTheTable => 'La mesa';

  @override
  String dmLogAllies(String names) {
    return 'Aliados: $names.';
  }

  @override
  String dmLogNeutrals(String names) {
    return 'Neutrales: $names.';
  }

  @override
  String dmLogNoEnemies(String who) {
    return '$who peleó sin enemigos cargados.';
  }

  @override
  String get dmLogNoneFell => 'No cayó ningún enemigo.';

  @override
  String get dmLogAllFell => 'Cayeron todos los enemigos.';

  @override
  String dmLogSomeFell(int defeated, int total) {
    return 'Cayeron $defeated de $total enemigos.';
  }

  @override
  String dmLogAgainst(String who, String against, String fell) {
    return '$who contra $against. $fell';
  }

  @override
  String get dmSheetReadFail => 'No se pudo leer la ficha.';

  @override
  String get dmSheetGone =>
      'Ya no ves esta ficha. Puede que te hayan cortado el vínculo.';

  @override
  String get dmSheetLoading => 'Cargando la ficha…';

  @override
  String get dmAbbrInit => 'Inic';

  @override
  String get dmAbbrSpeed => 'Vel';

  @override
  String get dmAbbrPerception => 'Perc.';

  @override
  String get dmActiveConditions => 'Condiciones activas';

  @override
  String get dmProficientSkills => 'Habilidades competentes';

  @override
  String get dmNoneDotF => 'Ninguna.';

  @override
  String get dmNoAttacks => 'No tiene ataques cargados.';

  @override
  String get dmNpcsReadFail => 'No se pudieron leer los PNJ de la campaña.';

  @override
  String get dmNpcsLoading => 'Cargando los PNJ…';

  @override
  String get dmNpcsEmpty =>
      'Esta campaña todavía no tiene PNJ. Traé los de tu biblioteca o creá uno nuevo.';

  @override
  String get dmBringFromLibrary => 'Traer de la biblioteca';

  @override
  String get dmTagsCaps => 'TAGS';

  @override
  String get dmNoNpcWithTag => 'Ningún PNJ de esta campaña tiene ese tag.';

  @override
  String get dmClearFilter => 'Limpiar filtro';

  @override
  String dmStatusOf(String name) {
    return 'Estado de $name';
  }

  @override
  String dmActionsOf(String name) {
    return 'Acciones de $name';
  }

  @override
  String get dmOpenSheet => 'Abrir ficha';

  @override
  String get dmRemoveFromCampaign => 'Quitar de esta campaña';

  @override
  String get dmRemoveFromCampaignNote =>
      'Sigue en tu biblioteca y en tus otras campañas.';

  @override
  String get dmLibraryReadFail => 'No se pudo leer tu biblioteca de PNJ.';

  @override
  String get dmLibraryLoading => 'Cargando tus PNJ…';

  @override
  String get dmLibraryEmpty =>
      'Tu biblioteca de PNJ está vacía. Creá el primero o importá uno: el de otro DM, o un personaje que exportó un jugador.';

  @override
  String get dmNoNpcMatches => 'Ningún PNJ coincide con los filtros.';

  @override
  String get dmNpcLibrary => 'Biblioteca de PNJ';

  @override
  String dmLibraryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personajes · compartidos entre tus campañas',
      one: '1 personaje · compartido entre tus campañas',
    );
    return '$_temp0';
  }

  @override
  String get dmImportNpc => 'Importar PNJ';

  @override
  String get dmSearchByName => 'Buscar por nombre';

  @override
  String get dmAllF => 'Todas';

  @override
  String get dmNoCampaign => 'Sin campaña';

  @override
  String get dmNoCampaignYet => 'Sin campaña todavía';

  @override
  String get dmShowName => 'Mostrar el nombre';

  @override
  String get dmHideName => 'Ocultar el nombre';

  @override
  String get npcExportTitle => 'Exportar PNJ';

  @override
  String get npcExportWhatTravels => 'Qué viaja en el archivo';

  @override
  String get npcExportAlways => 'Nombre, retrato, apariencia y «cómo habla»';

  @override
  String get npcExportNone => 'Su tipo: sin estadísticas';

  @override
  String get npcExportBlock => 'Su bloque';

  @override
  String get npcExportCharacter =>
      'Su ficha de personaje y el homebrew que usa';

  @override
  String get npcTagsWord => 'Tags';

  @override
  String get npcNotesWord => 'Notas';

  @override
  String get npcNotesNote => 'Son de tus mesas.';

  @override
  String get npcExportNever =>
      'Nunca viaja en qué campañas está ni si vive o murió en cada una. Quien lo importe recibe su propia copia: lo que cambie después no te llega.';

  @override
  String get npcDownloadZip => 'Descargar .zip';

  @override
  String get npcPickFile => 'Elegir el archivo del PNJ o del personaje';

  @override
  String get npcNewerVersion =>
      'El archivo viene de una versión más nueva de la app.';

  @override
  String get npcImportedHomebrewLate =>
      'El PNJ se importó, pero su homebrew aparece recién al recargar la página.';

  @override
  String npcPortraitsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count retratos',
      one: '1 retrato',
    );
    return '$_temp0';
  }

  @override
  String get npcBackgroundLower => 'trasfondo';

  @override
  String npcNotesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notas',
      one: '1 nota',
    );
    return '$_temp0';
  }

  @override
  String npcHomebrewList(String names) {
    return 'homebrew: $names';
  }

  @override
  String npcCannotImport(String missing) {
    return 'No se puede importar: su ficha usa contenido que esta instalación no tiene ($missing).';
  }

  @override
  String get npcAlsoAddToCampaign => 'Sumarlo también a una campaña (opcional)';

  @override
  String get npcNoCampaignOption => 'Ninguna: queda sin campaña';

  @override
  String get npcImportNeverReplaces =>
      'Importar nunca reemplaza nada: si ya tenés un PNJ con ese nombre, quedan los dos.';

  @override
  String get npcImporting => 'Importando…';

  @override
  String get npcSaveFailed => 'No se pudo guardar el cambio';

  @override
  String get npcEditName => 'Editar nombre';

  @override
  String get npcNameLabel => 'Nombre del PNJ';

  @override
  String get npcNewNote => 'Nueva nota';

  @override
  String get npcAddToCampaign => 'Sumar a una campaña';

  @override
  String get npcInAllCampaigns => 'Ya está en todas tus campañas.';

  @override
  String get npcDeleteBodyLibrary =>
      'Se borra de tu biblioteca, con su ficha, su trasfondo, sus notas y sus retratos. No se puede deshacer.';

  @override
  String npcDeleteBodyCampaigns(String campaigns) {
    return 'Se borra de tu biblioteca y de $campaigns, con su ficha, su trasfondo, sus notas y sus retratos. No se puede deshacer.';
  }

  @override
  String npcDeleteTitle(String name) {
    return 'Borrar a $name';
  }

  @override
  String get npcDeletePastBattles =>
      'Las batallas pasadas lo siguen nombrando en el Cuaderno. Si está en un combate abierto, su fila queda con el nombre y sin perfil.';

  @override
  String get npcDeleteJustUnlink =>
      '¿Solo querés sacarlo de una campaña? Usá «Quitar de esta campaña» desde la lista de PNJ de esa campaña.';

  @override
  String get npcDelete => 'Borrar PNJ';

  @override
  String npcDeleted(String name) {
    return '$name se borró.';
  }

  @override
  String get npcDeleteFailed => 'No se pudo borrar el PNJ';

  @override
  String get npcShowTable => 'Mostrar a la mesa';

  @override
  String get npcMoreActions => 'Más acciones';

  @override
  String get npcExport => 'Exportar';

  @override
  String get npcReadFail => 'No se pudo leer el PNJ.';

  @override
  String get npcLoading => 'Cargando el PNJ…';

  @override
  String get npcGone => 'Este PNJ ya no existe.';

  @override
  String get npcSpeech => 'Cómo habla';

  @override
  String get npcSpeechHint => 'Una o dos líneas para interpretarlo';

  @override
  String get npcSpeechEmpty => 'Todavía no dice cómo habla.';

  @override
  String get npcNoBackground => 'Sin trasfondo.';

  @override
  String get npcPortrait => 'Retrato';

  @override
  String npcRemoveTag(String tag) {
    return 'Quitar «$tag»';
  }

  @override
  String get npcTagWord => 'Tag';

  @override
  String npcEditTitle(String title) {
    return 'Editar $title';
  }

  @override
  String get npcAddNote => 'Agregar nota';

  @override
  String get npcNoNotes => 'Sin notas.';

  @override
  String get npcStats => 'Estadísticas';

  @override
  String get npcNoStatsNote =>
      'Sin estadísticas. En combate entra como neutral, con turno y sin PG.';

  @override
  String get npcBlockTitle => 'Bloque';

  @override
  String npcBasedOn(String name) {
    return 'basado en $name';
  }

  @override
  String get dmAbbrHp => 'PG';

  @override
  String get npcEditBlock => 'Editar bloque';

  @override
  String get npcBlockCopyNote =>
      'Es una copia: si la criatura del bestiario cambia, este bloque no se toca.';

  @override
  String get npcSheetTitle => 'Ficha';

  @override
  String get npcSheetReadFail => 'No se pudo leer su ficha.';

  @override
  String get npcOpenFullSheet => 'Abrir ficha completa';

  @override
  String get npcFullSheetNote =>
      'Nombre, retrato, trasfondo y notas se editan acá; la ficha completa es para estadísticas, equipo y niveles.';

  @override
  String get npcInCampaigns => 'En tus campañas';

  @override
  String get npcNoCampaignsYet => 'Todavía no está en ninguna campaña.';

  @override
  String npcStatusIn(String campaign) {
    return 'Estado en $campaign';
  }

  @override
  String get npcAddToAnother => 'Sumar a otra campaña';

  @override
  String get npcAddTag => 'Agregar tag';

  @override
  String get encReadFail => 'No se pudo leer el combate.';

  @override
  String get encLoading => 'Cargando el combate…';

  @override
  String get encNone => 'No hay ningún combate en curso.';

  @override
  String get encEmptyOrder =>
      'Todavía no hay nadie en el orden. Sumá jugadores, PNJ o monstruos para arrancar.';

  @override
  String get encPreparing => 'Armando el combate';

  @override
  String get encPreparingNote =>
      'Todavía nadie tiró iniciativa, y a los jugadores no les aparece nada en su ficha.';

  @override
  String get encRound => 'Ronda';

  @override
  String encTurnOf(int turn, int total) {
    return 'Turno $turn de $total';
  }

  @override
  String encStandingSemantics(String what, int up, int total) {
    return '$what: $up de $total en pie';
  }

  @override
  String get encStanding => 'En pie';

  @override
  String get encAllies => 'Aliados';

  @override
  String get encEnemies => 'Enemigos';

  @override
  String encNeutralsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neutrales',
      one: '1 neutral',
    );
    return '$_temp0';
  }

  @override
  String get encAmountExplain =>
      'Es el número que aplican los botones de dañar y curar de cualquier fila. Vale para todo el combate.';

  @override
  String get encDamageOrHeal => 'Daño o curación';

  @override
  String encSetAmount(int n) {
    return 'Poner $n';
  }

  @override
  String get encDiscard => 'Descartar combate';

  @override
  String get encFinish => 'Terminar combate';

  @override
  String get encDiscardTitle => '¿Descartar el combate?';

  @override
  String get encDiscardBody =>
      'Todavía no empezó: se borra lo que armaste y no queda registro.';

  @override
  String get encDiscardShort => 'Descartar';

  @override
  String encInitiativeOf(String name) {
    return 'Iniciativa de $name';
  }

  @override
  String get encWhatTheyGot => 'Lo que sacó';

  @override
  String get encCombatant => 'Combatiente';

  @override
  String get encEffects => 'Efectos';

  @override
  String get encDamageHeal => 'Daño o cura';

  @override
  String get encOfTurn => 'Del turno';

  @override
  String get encNobodyTurn => 'Todavía no le toca a nadie.';

  @override
  String encPlayerTurn(String name) {
    return 'Le toca a $name, y su ficha la lleva quien lo juega.';
  }

  @override
  String encNoProfile(String name) {
    return 'No hay perfil cargado para $name.';
  }

  @override
  String get encTurnNow => 'Le toca ahora';

  @override
  String encSideOf(String name) {
    return 'Bando de $name';
  }

  @override
  String get encNeutralNoStats => 'Neutral · sin estadísticas';

  @override
  String encBackgroundOf(String name) {
    return 'Trasfondo de $name';
  }

  @override
  String get encConvertToNpc => 'Convertir en PNJ';

  @override
  String get encNoEffects =>
      'Nadie tiene efectos anotados. Se anotan desde la fila de cada combatiente.';

  @override
  String encRemoveEffect(String tag, String name) {
    return 'Sacar «$tag» de $name';
  }

  @override
  String get encNobodyStanding => 'No queda nadie en pie.';

  @override
  String get encNoEnemyStanding => 'No queda ningún enemigo en pie.';

  @override
  String get encNoAllyStanding => 'No queda ningún aliado en pie.';

  @override
  String get encWrapUp => '¿Damos el encuentro por terminado?';

  @override
  String get encNotInCombat => 'Todavía no están en el combate';

  @override
  String get encJoinedLate => 'Se sumaron tarde';

  @override
  String get encAddAll => 'Sumar a todos';

  @override
  String get encAddToInitiative => 'Sumar a la iniciativa';

  @override
  String get encWhatTheyRolled => 'Lo que tiró en la mesa';

  @override
  String get encCloseExplain =>
      'Se borra el orden de turnos en los dos casos. Si lo terminás queda un registro liviano de lo que pasó (sin PG ni daños: eso lo lleva cada jugador en su ficha). Si lo descartás no queda nada, como si nunca hubiera empezado.';

  @override
  String get encAnyDied => '¿Alguno murió?';

  @override
  String get encFellNote =>
      'Quedaron a 0 PG. Los que marques pasan a muertos en esta campaña al terminar y guardar.';

  @override
  String get encDiscardNoSave => 'Descartar sin guardar';

  @override
  String get encFinishAndSave => 'Terminar y guardar';

  @override
  String get encSkips => 'Salta';

  @override
  String get encTurnWord => 'Turno';

  @override
  String get encActed => 'Actuó';

  @override
  String get encFixInitiative => 'Corregir iniciativa';

  @override
  String get encDownMeta => 'Caído · se salta su turno';

  @override
  String get encFixedNeutral => 'Sin estadísticas: neutral fijo';

  @override
  String get encConvertToNpcEllipsis => 'Convertir en PNJ…';

  @override
  String encPlayerMeta(String race, String klass, int level) {
    return '$race · $klass · nv $level';
  }

  @override
  String get encBloodied => 'MALTRECHO';

  @override
  String get encOnTheirSheet => 'en su ficha';

  @override
  String get encHurt => 'Dañar';

  @override
  String get encHeal => 'Curar';

  @override
  String get encRemoveFromCombat => 'Sacar del combate';

  @override
  String get dmNewCampaign => 'Nueva campaña';

  @override
  String get dmEditCampaign => 'Editar campaña';

  @override
  String get dmDeleteCampaign => 'Borrar campaña';

  @override
  String dmDeleteCampaignBody(String name) {
    return 'Se borra «$name» con sus capítulos, las notas del Cuaderno, el combate abierto y el historial de combates. No se puede deshacer.\n\nLos personajes que los jugadores le compartieron se sueltan, y sus fichas siguen siendo de sus dueños. Los PNJ se quedan en tu biblioteca.';
  }

  @override
  String get dmHomebrew => 'Homebrew';

  @override
  String get dmFinishedGroup => 'Terminadas';

  @override
  String get dmCurrentCampaign => 'Campaña actual';

  @override
  String get dmTable => 'Mesa';

  @override
  String get dmChapters => 'Capítulos';

  @override
  String get dmNotebook => 'Cuaderno';

  @override
  String get dmPlayerMode => 'Modo Jugador';

  @override
  String get dmCampaignsLoadFail => 'No se pudieron cargar tus campañas.';

  @override
  String get dmOffline => 'No hay conexión con el servidor.';

  @override
  String get dmOfflineHint =>
      'Tus campañas están a salvo; solo no se pueden leer ahora.';

  @override
  String get dmCampaignsLoading => 'Cargando campañas…';

  @override
  String get dmOnbTitle => 'Prepará tu primera mesa';

  @override
  String get dmOnbBody =>
      'Todavía no dirigís ninguna campaña. Este espacio reúne lo que necesitás antes y durante la partida.';

  @override
  String get dmOnb1Title => 'Creá la campaña';

  @override
  String get dmOnb1Detail => 'Poné nombre a la mesa y resumí su premisa.';

  @override
  String get dmOnb2Title => 'Sumá los personajes';

  @override
  String get dmOnb2Detail => 'Cada jugador te comparte su ficha con un código.';

  @override
  String get dmOnb3Title => 'Dirigí la sesión';

  @override
  String get dmOnb3Detail =>
      'Organizá capítulos y llevá la iniciativa del combate.';

  @override
  String get dmCreateCampaign => 'Crear campaña';

  @override
  String get dmAddMember => 'Sumar personaje';

  @override
  String get dmMemberCodeLabel => 'Código que te pasó el jugador';

  @override
  String dmMemberAdded(String name, String campaign) {
    return '$name se sumó a $campaign.';
  }

  @override
  String get dmRemoveMember => 'Echar personaje';

  @override
  String dmRemoveMemberBody(String name, String campaign) {
    return '$name sale de «$campaign» y dejás de ver su ficha. El personaje sigue siendo de su dueño y no se toca; puede volver con un código nuevo.';
  }

  @override
  String dmMemberLeft(String name) {
    return '$name salió de la mesa.';
  }

  @override
  String dmInspirationSent(String name) {
    return 'Le avisamos a $name. La marca en su ficha.';
  }

  @override
  String get dmWriteNote => 'Escribir nota';

  @override
  String get dmEditNote => 'Editar nota';

  @override
  String get dmNewChapter => 'Nuevo capítulo';

  @override
  String get dmEditChapter => 'Editar capítulo';

  @override
  String dmChapterClosed(String name) {
    return 'Se cerró «$name». Les llega el aviso a los jugadores.';
  }

  @override
  String get dmSaveCombatFailed => 'No se pudo guardar el combate';

  @override
  String get dmNoProfileToCopy => 'No hay perfil de esa criatura para copiar.';

  @override
  String dmNowNpc(String name) {
    return '$name ya es un PNJ de tu biblioteca y de esta campaña.';
  }

  @override
  String get dmCombatPreparing => 'Combate en preparación';

  @override
  String dmCombatRound(int round) {
    return 'Combate · ronda $round';
  }

  @override
  String get dmCampaignActions => 'Acciones de campaña';

  @override
  String get dmAddingMember => 'Sumando personaje…';

  @override
  String get dmSetUpCombat => 'Armar combate';

  @override
  String get dmNextTurn => 'Siguiente turno';

  @override
  String get dmTableLoading => 'Cargando la mesa…';

  @override
  String get dmNobodyShared => 'Todavía nadie compartió su personaje.';

  @override
  String dmCharactersAtTable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personajes en la mesa',
      one: '1 personaje en la mesa',
    );
    return '$_temp0';
  }

  @override
  String get dmTableReadFail => 'No se pudo leer la mesa.';

  @override
  String get dmTableEmpty =>
      'Pedile a cada jugador que abra su personaje, toque Compartir y te pase el código.';

  @override
  String dmHpSemantics(int current, int max) {
    return 'Puntos de golpe: $current de $max';
  }

  @override
  String dmHpShort(int current, int max) {
    return 'PG $current/$max';
  }

  @override
  String get dmGrantInspiration => 'Conceder Inspiración Heroica';

  @override
  String get dmRemoveFromTable => 'Echar de la mesa';

  @override
  String get dmAllNpcsInCampaign =>
      'Todos tus PNJ ya están en esta campaña, o todavía no creaste ninguno.';

  @override
  String dmAddCount(int count) {
    return 'Sumar $count';
  }

  @override
  String get bootThemeSaveFailed =>
      'El tema cambió, pero no se pudo guardar la preferencia.';

  @override
  String get bootLoading => 'Cargando datos…';

  @override
  String get bootFailed => 'No se pudo iniciar la aplicación.';

  @override
  String get bootFailedHint =>
      'Suele ser un problema momentáneo de conexión. Probá de nuevo; si sigue igual, recargá la página.';

  @override
  String get bootOffline => 'No se pudo conectar con el servidor.';

  @override
  String get bootOfflineHint =>
      'Tus personajes están a salvo: no se pudieron leer, pero no se perdió nada. Revisá la conexión y reintentá.';

  @override
  String invItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count objetos',
      one: '1 objeto',
    );
    return '$_temp0';
  }

  @override
  String invShownOf(Object shown, Object total) {
    return '$shown de $total';
  }

  @override
  String luClassFeatures(Object count) {
    return '$count rasgos de clase';
  }

  @override
  String get luUnchanged => 'SIN CAMBIOS';

  @override
  String equipCostPerBundle(String cost, Object size) {
    return '$cost el paquete de $size';
  }

  @override
  String equipCostEach(String cost) {
    return '$cost c/u';
  }

  @override
  String sheetSubclassAtLevel(Object level) {
    return 'subclase en nivel $level';
  }

  @override
  String codexEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entradas',
      one: '1 entrada',
    );
    return '$_temp0';
  }

  @override
  String bestiaryCreatureCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count criaturas',
      one: '1 criatura',
    );
    return '$_temp0';
  }

  @override
  String npcCountTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count PNJ',
      one: '1 PNJ',
    );
    return '$_temp0';
  }

  @override
  String npcCountAlive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vivos',
      one: '1 vivo',
    );
    return '$_temp0';
  }

  @override
  String npcCountDead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count muertos',
      one: '1 muerto',
    );
    return '$_temp0';
  }

  @override
  String npcCountUnknown(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count desconocidos',
      one: '1 desconocido',
    );
    return '$_temp0';
  }

  @override
  String get creatureLegendaryAction => 'Acción legendaria';

  @override
  String get feedbackButton => 'Sugerencias y errores';

  @override
  String get feedbackTitle => 'Sugerencias y errores';

  @override
  String get feedbackKindIdea => 'Una idea';

  @override
  String get feedbackKindBug => 'Un error';

  @override
  String get feedbackMessageLabel => 'Mensaje';

  @override
  String get feedbackHintIdea =>
      '¿Qué te gustaría poder hacer, y para qué lo usarías en tu mesa?';

  @override
  String get feedbackHintBug =>
      '¿Qué estabas haciendo, qué esperabas y qué pasó?';

  @override
  String feedbackReplyTo(String email) {
    return 'Te respondemos a $email.';
  }

  @override
  String get feedbackSend => 'Enviar';

  @override
  String get feedbackSendError => 'No se pudo enviar el mensaje';

  @override
  String get feedbackSent => '¡Gracias! Recibimos tu mensaje.';

  @override
  String get errorReport => 'Reportar este error';
}
