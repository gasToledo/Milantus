import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// Título de la aplicación (pestaña del navegador y conmutador de tareas).
  ///
  /// In es, this message translates to:
  /// **'Milantus — Asistente de Aventuras'**
  String get appTitle;

  /// Lo que anuncia un lector de pantalla para el selector de idioma; {name} es el nombre del idioma activo en su propio idioma.
  ///
  /// In es, this message translates to:
  /// **'Idioma: {name}'**
  String languageSelectorLabel(String name);

  /// Tooltip del selector de idioma del panel lateral.
  ///
  /// In es, this message translates to:
  /// **'Cambiar el idioma'**
  String get languageSelectorTooltip;

  /// No description provided for @settingsLoadError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar la configuración'**
  String get settingsLoadError;

  /// No description provided for @settingsSaveError.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron guardar los ajustes'**
  String get settingsSaveError;

  /// No description provided for @settingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Ajustes · Generación de imágenes'**
  String get settingsTitle;

  /// No description provided for @settingsLoading.
  ///
  /// In es, this message translates to:
  /// **'Cargando ajustes…'**
  String get settingsLoading;

  /// No description provided for @settingsNoProviders.
  ///
  /// In es, this message translates to:
  /// **'Este servidor no tiene ningún proveedor de generación configurado. Igual podés subir tu propio retrato desde la ficha.'**
  String get settingsNoProviders;

  /// No description provided for @settingsProviderLabel.
  ///
  /// In es, this message translates to:
  /// **'Proveedor de retratos:'**
  String get settingsProviderLabel;

  /// No description provided for @commonCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get commonSave;

  /// No description provided for @commonSaving.
  ///
  /// In es, this message translates to:
  /// **'Guardando…'**
  String get commonSaving;

  /// No description provided for @commonRetry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get commonRetry;

  /// No description provided for @commonClose.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get commonClose;

  /// No description provided for @commonUndo.
  ///
  /// In es, this message translates to:
  /// **'Deshacer'**
  String get commonUndo;

  /// No description provided for @saveStateFailed.
  ///
  /// In es, this message translates to:
  /// **'No se guardó'**
  String get saveStateFailed;

  /// No description provided for @saveStateSaved.
  ///
  /// In es, this message translates to:
  /// **'Guardado'**
  String get saveStateSaved;

  /// Lo que anuncia un lector de pantalla; {state} es «Guardando…», «Guardado» o «No se guardó».
  ///
  /// In es, this message translates to:
  /// **'Estado del guardado: {state}'**
  String saveStateLabel(String state);

  /// No description provided for @commonUse.
  ///
  /// In es, this message translates to:
  /// **'Usar'**
  String get commonUse;

  /// No description provided for @commonRestore.
  ///
  /// In es, this message translates to:
  /// **'Restaurar'**
  String get commonRestore;

  /// No description provided for @commonRange.
  ///
  /// In es, this message translates to:
  /// **'Alcance'**
  String get commonRange;

  /// No description provided for @creatureReach.
  ///
  /// In es, this message translates to:
  /// **'Alcance'**
  String get creatureReach;

  /// No description provided for @themeLight.
  ///
  /// In es, this message translates to:
  /// **'Tema claro'**
  String get themeLight;

  /// No description provided for @themeSystem.
  ///
  /// In es, this message translates to:
  /// **'Seguir el tema del sistema'**
  String get themeSystem;

  /// No description provided for @themeDark.
  ///
  /// In es, this message translates to:
  /// **'Tema oscuro'**
  String get themeDark;

  /// No description provided for @errorShowDetails.
  ///
  /// In es, this message translates to:
  /// **'Ver detalles'**
  String get errorShowDetails;

  /// No description provided for @renameTitle.
  ///
  /// In es, this message translates to:
  /// **'Editar nombre'**
  String get renameTitle;

  /// No description provided for @renameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre del personaje'**
  String get renameLabel;

  /// No description provided for @armorClassLabel.
  ///
  /// In es, this message translates to:
  /// **'Clase de armadura: {value}'**
  String armorClassLabel(Object value);

  /// No description provided for @abilityTile.
  ///
  /// In es, this message translates to:
  /// **'{name}: modificador {mod}, puntuación {score}'**
  String abilityTile(String name, String mod, Object score);

  /// No description provided for @abilityTileProficient.
  ///
  /// In es, this message translates to:
  /// **'{name}: modificador {mod}, puntuación {score}, competente en salvación'**
  String abilityTileProficient(String name, String mod, Object score);

  /// No description provided for @abilityScoreShort.
  ///
  /// In es, this message translates to:
  /// **'Punt. {score}'**
  String abilityScoreShort(Object score);

  /// No description provided for @saveShort.
  ///
  /// In es, this message translates to:
  /// **'SALV'**
  String get saveShort;

  /// No description provided for @saveShortValue.
  ///
  /// In es, this message translates to:
  /// **'SALV {bonus}'**
  String saveShortValue(String bonus);

  /// No description provided for @emblemLabel.
  ///
  /// In es, this message translates to:
  /// **'Emblema de {name}'**
  String emblemLabel(String name);

  /// No description provided for @portraitLabel.
  ///
  /// In es, this message translates to:
  /// **'Retrato de {name}'**
  String portraitLabel(String name);

  /// No description provided for @helpWhatItDoes.
  ///
  /// In es, this message translates to:
  /// **'Ver qué hace {name}'**
  String helpWhatItDoes(String name);

  /// No description provided for @usesAvailable.
  ///
  /// In es, this message translates to:
  /// **'{filled} de {max} usos disponibles'**
  String usesAvailable(int filled, int max);

  /// No description provided for @sourceHomebrew.
  ///
  /// In es, this message translates to:
  /// **'Propio'**
  String get sourceHomebrew;

  /// No description provided for @sourceBadgeLabel.
  ///
  /// In es, this message translates to:
  /// **'Procedencia: {source}'**
  String sourceBadgeLabel(String source);

  /// No description provided for @innateAtWill.
  ///
  /// In es, this message translates to:
  /// **'a voluntad'**
  String get innateAtWill;

  /// No description provided for @innateOncePerLongRest.
  ///
  /// In es, this message translates to:
  /// **'una vez por descanso largo'**
  String get innateOncePerLongRest;

  /// No description provided for @innateOncePerShortRest.
  ///
  /// In es, this message translates to:
  /// **'una vez por descanso corto'**
  String get innateOncePerShortRest;

  /// No description provided for @innateProficiencyBonus.
  ///
  /// In es, this message translates to:
  /// **'tantas veces como tu bono de competencia'**
  String get innateProficiencyBonus;

  /// No description provided for @innateAbilityModifier.
  ///
  /// In es, this message translates to:
  /// **'tantas veces como el modificador de la característica'**
  String get innateAbilityModifier;

  /// No description provided for @effectProficiency.
  ///
  /// In es, this message translates to:
  /// **'Competencia: {name}'**
  String effectProficiency(String name);

  /// No description provided for @effectSave.
  ///
  /// In es, this message translates to:
  /// **'Salvación: {ability}'**
  String effectSave(String ability);

  /// No description provided for @effectSaves.
  ///
  /// In es, this message translates to:
  /// **'Salvaciones {parts}'**
  String effectSaves(String parts);

  /// No description provided for @effectModOf.
  ///
  /// In es, this message translates to:
  /// **'+ mod. de {ability}'**
  String effectModOf(String ability);

  /// No description provided for @effectProficiencyBonusPart.
  ///
  /// In es, this message translates to:
  /// **'+ bonif. por competencia'**
  String get effectProficiencyBonusPart;

  /// No description provided for @effectLanguage.
  ///
  /// In es, this message translates to:
  /// **'Idioma: {name}'**
  String effectLanguage(String name);

  /// No description provided for @effectResistance.
  ///
  /// In es, this message translates to:
  /// **'Resistencia: {name}'**
  String effectResistance(String name);

  /// No description provided for @effectImmunity.
  ///
  /// In es, this message translates to:
  /// **'Inmunidad: {name}'**
  String effectImmunity(String name);

  /// No description provided for @effectDarkvision.
  ///
  /// In es, this message translates to:
  /// **'Visión en la oscuridad: {range} pies'**
  String effectDarkvision(Object range);

  /// No description provided for @effectSpeedBonus.
  ///
  /// In es, this message translates to:
  /// **'Velocidad +{feet} pies'**
  String effectSpeedBonus(Object feet);

  /// No description provided for @effectSpeedSet.
  ///
  /// In es, this message translates to:
  /// **'Velocidad = {feet} pies'**
  String effectSpeedSet(Object feet);

  /// No description provided for @effectAcBonus.
  ///
  /// In es, this message translates to:
  /// **'CA +{amount}'**
  String effectAcBonus(Object amount);

  /// No description provided for @effectInitiative.
  ///
  /// In es, this message translates to:
  /// **'Iniciativa {parts}'**
  String effectInitiative(String parts);

  /// No description provided for @effectMaxHpPerLevel.
  ///
  /// In es, this message translates to:
  /// **'PG máx +{perLevel} por nivel'**
  String effectMaxHpPerLevel(Object perLevel);

  /// No description provided for @effectMaxHpFlat.
  ///
  /// In es, this message translates to:
  /// **'PG máx +{amount}'**
  String effectMaxHpFlat(Object amount);

  /// No description provided for @effectPassive.
  ///
  /// In es, this message translates to:
  /// **'Pasiva: {name}'**
  String effectPassive(String name);

  /// No description provided for @effectWeaponMastery.
  ///
  /// In es, this message translates to:
  /// **'Maestrías de arma: {count}'**
  String effectWeaponMastery(Object count);

  /// No description provided for @effectExtraAttack.
  ///
  /// In es, this message translates to:
  /// **'Ataque adicional +{extra}'**
  String effectExtraAttack(Object extra);

  /// No description provided for @effectFeat.
  ///
  /// In es, this message translates to:
  /// **'Dote: {name}'**
  String effectFeat(String name);

  /// No description provided for @effectFeatChoice.
  ///
  /// In es, this message translates to:
  /// **'a elección'**
  String get effectFeatChoice;

  /// No description provided for @effectSpell.
  ///
  /// In es, this message translates to:
  /// **'Conjuro: {name} ({use})'**
  String effectSpell(String name, String use);

  /// No description provided for @effectAlwaysPrepared.
  ///
  /// In es, this message translates to:
  /// **'Siempre preparado: {name}'**
  String effectAlwaysPrepared(String name);

  /// No description provided for @effectAddedToList.
  ///
  /// In es, this message translates to:
  /// **'Se suma a tu lista: {name}'**
  String effectAddedToList(String name);

  /// No description provided for @spellActionAction.
  ///
  /// In es, this message translates to:
  /// **'Acción'**
  String get spellActionAction;

  /// No description provided for @spellActionBonus.
  ///
  /// In es, this message translates to:
  /// **'Acción adicional'**
  String get spellActionBonus;

  /// No description provided for @spellActionReaction.
  ///
  /// In es, this message translates to:
  /// **'Reacción'**
  String get spellActionReaction;

  /// No description provided for @spellCantrip.
  ///
  /// In es, this message translates to:
  /// **'Truco'**
  String get spellCantrip;

  /// No description provided for @spellLevel.
  ///
  /// In es, this message translates to:
  /// **'Nivel {level}'**
  String spellLevel(Object level);

  /// No description provided for @spellCastingTime.
  ///
  /// In es, this message translates to:
  /// **'Lanzamiento'**
  String get spellCastingTime;

  /// No description provided for @spellComponents.
  ///
  /// In es, this message translates to:
  /// **'Componentes'**
  String get spellComponents;

  /// No description provided for @spellDuration.
  ///
  /// In es, this message translates to:
  /// **'Duración'**
  String get spellDuration;

  /// No description provided for @creatureSpellWith.
  ///
  /// In es, this message translates to:
  /// **'Con {name}'**
  String creatureSpellWith(String name);

  /// No description provided for @creatureActions.
  ///
  /// In es, this message translates to:
  /// **'Acciones'**
  String get creatureActions;

  /// No description provided for @creatureBonusActions.
  ///
  /// In es, this message translates to:
  /// **'Acciones adicionales'**
  String get creatureBonusActions;

  /// No description provided for @creatureReactions.
  ///
  /// In es, this message translates to:
  /// **'Reacciones'**
  String get creatureReactions;

  /// No description provided for @creatureLegendaryActions.
  ///
  /// In es, this message translates to:
  /// **'Acciones legendarias'**
  String get creatureLegendaryActions;

  /// No description provided for @creatureLegendaryActionsPerRound.
  ///
  /// In es, this message translates to:
  /// **'Acciones legendarias · {uses} por ronda'**
  String creatureLegendaryActionsPerRound(Object uses);

  /// No description provided for @creatureAcShort.
  ///
  /// In es, this message translates to:
  /// **'CA'**
  String get creatureAcShort;

  /// No description provided for @hitPoints.
  ///
  /// In es, this message translates to:
  /// **'Puntos de golpe'**
  String get hitPoints;

  /// No description provided for @hitPointsShort.
  ///
  /// In es, this message translates to:
  /// **'PG'**
  String get hitPointsShort;

  /// No description provided for @hitPointsLabel.
  ///
  /// In es, this message translates to:
  /// **'Puntos de golpe: {value}'**
  String hitPointsLabel(Object value);

  /// No description provided for @initiative.
  ///
  /// In es, this message translates to:
  /// **'Iniciativa'**
  String get initiative;

  /// No description provided for @challengeRating.
  ///
  /// In es, this message translates to:
  /// **'Valor de desafío'**
  String get challengeRating;

  /// No description provided for @challengeRatingShort.
  ///
  /// In es, this message translates to:
  /// **'VD'**
  String get challengeRatingShort;

  /// No description provided for @challengeRatingSemantics.
  ///
  /// In es, this message translates to:
  /// **'Valor de desafío: {value}'**
  String challengeRatingSemantics(String value);

  /// No description provided for @passivePerceptionShort.
  ///
  /// In es, this message translates to:
  /// **'Perc. pasiva'**
  String get passivePerceptionShort;

  /// No description provided for @passivePerceptionLabel.
  ///
  /// In es, this message translates to:
  /// **'Percepción pasiva: {value}'**
  String passivePerceptionLabel(Object value);

  /// No description provided for @creatureSpeed.
  ///
  /// In es, this message translates to:
  /// **'Velocidad'**
  String get creatureSpeed;

  /// No description provided for @creatureSkills.
  ///
  /// In es, this message translates to:
  /// **'Habilidades'**
  String get creatureSkills;

  /// No description provided for @creatureSenses.
  ///
  /// In es, this message translates to:
  /// **'Sentidos'**
  String get creatureSenses;

  /// No description provided for @creatureLanguages.
  ///
  /// In es, this message translates to:
  /// **'Idiomas'**
  String get creatureLanguages;

  /// No description provided for @creatureDefenses.
  ///
  /// In es, this message translates to:
  /// **'Defensas'**
  String get creatureDefenses;

  /// No description provided for @creatureTraits.
  ///
  /// In es, this message translates to:
  /// **'Rasgos'**
  String get creatureTraits;

  /// No description provided for @creatureToHit.
  ///
  /// In es, this message translates to:
  /// **'Acierto'**
  String get creatureToHit;

  /// No description provided for @creatureDamage.
  ///
  /// In es, this message translates to:
  /// **'Daño'**
  String get creatureDamage;

  /// No description provided for @creatureSpellSaveDc.
  ///
  /// In es, this message translates to:
  /// **'CD {dc}'**
  String creatureSpellSaveDc(Object dc);

  /// No description provided for @creatureSpellAttack.
  ///
  /// In es, this message translates to:
  /// **'Ataque {bonus}'**
  String creatureSpellAttack(String bonus);

  /// No description provided for @creatureAtWill.
  ///
  /// In es, this message translates to:
  /// **'A voluntad'**
  String get creatureAtWill;

  /// No description provided for @creatureUsesPerDay.
  ///
  /// In es, this message translates to:
  /// **'{uses}/día cada uno'**
  String creatureUsesPerDay(Object uses);

  /// No description provided for @creatureCastAtLevel.
  ///
  /// In es, this message translates to:
  /// **'Se lanza a nivel {level}'**
  String creatureCastAtLevel(Object level);

  /// No description provided for @commonCannotUndo.
  ///
  /// In es, this message translates to:
  /// **'Esta acción no se puede deshacer.'**
  String get commonCannotUndo;

  /// No description provided for @commonDelete.
  ///
  /// In es, this message translates to:
  /// **'Borrar'**
  String get commonDelete;

  /// No description provided for @commonImport.
  ///
  /// In es, this message translates to:
  /// **'Importar'**
  String get commonImport;

  /// No description provided for @commonLevel.
  ///
  /// In es, this message translates to:
  /// **'Nivel {level}'**
  String commonLevel(Object level);

  /// No description provided for @transferTitle.
  ///
  /// In es, this message translates to:
  /// **'Importar / Exportar'**
  String get transferTitle;

  /// No description provided for @transferImport.
  ///
  /// In es, this message translates to:
  /// **'Importar…'**
  String get transferImport;

  /// No description provided for @transferExportBackup.
  ///
  /// In es, this message translates to:
  /// **'Exportar respaldo completo'**
  String get transferExportBackup;

  /// No description provided for @deleteCharacterTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Borrar a {name}?'**
  String deleteCharacterTitle(String name);

  /// No description provided for @exportingCharacter.
  ///
  /// In es, this message translates to:
  /// **'Exportando personaje…'**
  String get exportingCharacter;

  /// No description provided for @exportCharacterError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo exportar el personaje'**
  String get exportCharacterError;

  /// No description provided for @creatingBackup.
  ///
  /// In es, this message translates to:
  /// **'Creando respaldo…'**
  String get creatingBackup;

  /// No description provided for @backupError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo crear el respaldo'**
  String get backupError;

  /// No description provided for @importPickTitle.
  ///
  /// In es, this message translates to:
  /// **'Elegí un respaldo (.zip)'**
  String get importPickTitle;

  /// No description provided for @importBackupTitle.
  ///
  /// In es, this message translates to:
  /// **'Importar respaldo'**
  String get importBackupTitle;

  /// No description provided for @importBackupBody.
  ///
  /// In es, this message translates to:
  /// **'Se van a agregar los personajes (y el homebrew y las preferencias, si el respaldo los incluye) de \"{fileName}\" a esta cuenta. Los personajes existentes no se tocan; un id repetido se guarda como copia nueva.'**
  String importBackupBody(String fileName);

  /// No description provided for @importingBackup.
  ///
  /// In es, this message translates to:
  /// **'Importando respaldo…'**
  String get importingBackup;

  /// «imágenes» y no «retratos»: la cuenta incluye las imágenes del Diario, que van al mismo almacén sin ser retratos.
  ///
  /// In es, this message translates to:
  /// **'Importados {characters, plural, =1{1 personaje} other{{characters} personajes}} y {images, plural, =1{1 imagen} other{{images} imágenes}}.'**
  String importDone(int characters, int images);

  /// No description provided for @importError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo importar'**
  String get importError;

  /// No description provided for @operationBusy.
  ///
  /// In es, this message translates to:
  /// **'Ya hay una operación en curso.'**
  String get operationBusy;

  /// No description provided for @rosterEmpty.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay personajes en esta cuenta.\nCreá el primero, traé los que ya tenías, o mirá cómo es una ficha con uno de ejemplo.'**
  String get rosterEmpty;

  /// No description provided for @rosterCreate.
  ///
  /// In es, this message translates to:
  /// **'Crear personaje'**
  String get rosterCreate;

  /// No description provided for @rosterTryExample.
  ///
  /// In es, this message translates to:
  /// **'Probar con uno de ejemplo'**
  String get rosterTryExample;

  /// No description provided for @rosterNoMatch.
  ///
  /// In es, this message translates to:
  /// **'Ningún personaje coincide con «{query}».\nSe busca por nombre, clase y especie.'**
  String rosterNoMatch(String query);

  /// No description provided for @rosterClearSearch.
  ///
  /// In es, this message translates to:
  /// **'Limpiar búsqueda'**
  String get rosterClearSearch;

  /// No description provided for @rosterTitle.
  ///
  /// In es, this message translates to:
  /// **'Mis personajes'**
  String get rosterTitle;

  /// No description provided for @rosterCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 personaje} other{{count} personajes}}'**
  String rosterCount(int count);

  /// No description provided for @rosterFallen.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 caído} other{{count} caídos}}'**
  String rosterFallen(int count);

  /// No description provided for @rosterSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar por nombre, clase o especie…'**
  String get rosterSearchHint;

  /// No description provided for @rosterSort.
  ///
  /// In es, this message translates to:
  /// **'Ordenar'**
  String get rosterSort;

  /// No description provided for @sortManual.
  ///
  /// In es, this message translates to:
  /// **'Manual'**
  String get sortManual;

  /// No description provided for @sortRecent.
  ///
  /// In es, this message translates to:
  /// **'Más recientes'**
  String get sortRecent;

  /// No description provided for @sortName.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get sortName;

  /// No description provided for @sortLevel.
  ///
  /// In es, this message translates to:
  /// **'Nivel'**
  String get sortLevel;

  /// No description provided for @sortClass.
  ///
  /// In es, this message translates to:
  /// **'Clase'**
  String get sortClass;

  /// No description provided for @sortSaveError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar el orden de tus personajes'**
  String get sortSaveError;

  /// No description provided for @sortManualHint.
  ///
  /// In es, this message translates to:
  /// **'Orden manual: usá «Mover antes» y «Mover después» en el menú de cada tarjeta, o arrastrala sobre otra.'**
  String get sortManualHint;

  /// No description provided for @saveLatestError.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron guardar los últimos cambios'**
  String get saveLatestError;

  /// No description provided for @sessionExpiredTitle.
  ///
  /// In es, this message translates to:
  /// **'La sesión terminó'**
  String get sessionExpiredTitle;

  /// No description provided for @sessionExpiredBody.
  ///
  /// In es, this message translates to:
  /// **'Los cambios que todavía no se pudieron guardar siguen en pantalla. Iniciá sesión de nuevo para seguir editando.'**
  String get sessionExpiredBody;

  /// No description provided for @sessionSignIn.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get sessionSignIn;

  /// No description provided for @appTagline.
  ///
  /// In es, this message translates to:
  /// **'Asistente de Aventuras'**
  String get appTagline;

  /// No description provided for @navCharacters.
  ///
  /// In es, this message translates to:
  /// **'Personajes'**
  String get navCharacters;

  /// No description provided for @navCodex.
  ///
  /// In es, this message translates to:
  /// **'Códice'**
  String get navCodex;

  /// No description provided for @dmModeButton.
  ///
  /// In es, this message translates to:
  /// **'Modo DM'**
  String get dmModeButton;

  /// No description provided for @accountSignOut.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get accountSignOut;

  /// No description provided for @signOutError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cerrar la sesión'**
  String get signOutError;

  /// No description provided for @characterFallenBadge.
  ///
  /// In es, this message translates to:
  /// **'CAÍDO'**
  String get characterFallenBadge;

  /// No description provided for @hpLabelFallen.
  ///
  /// In es, this message translates to:
  /// **'SIN PUNTOS DE GOLPE'**
  String get hpLabelFallen;

  /// No description provided for @hpLabelCritical.
  ///
  /// In es, this message translates to:
  /// **'PG CRÍTICOS'**
  String get hpLabelCritical;

  /// No description provided for @hpLabelNormal.
  ///
  /// In es, this message translates to:
  /// **'PUNTOS DE GOLPE'**
  String get hpLabelNormal;

  /// No description provided for @cardActionsTooltip.
  ///
  /// In es, this message translates to:
  /// **'Acciones de {name}'**
  String cardActionsTooltip(String name);

  /// No description provided for @cardFavorite.
  ///
  /// In es, this message translates to:
  /// **'Marcar como favorito'**
  String get cardFavorite;

  /// No description provided for @cardUnfavorite.
  ///
  /// In es, this message translates to:
  /// **'Quitar de favorito'**
  String get cardUnfavorite;

  /// No description provided for @cardMoveBefore.
  ///
  /// In es, this message translates to:
  /// **'Mover antes'**
  String get cardMoveBefore;

  /// No description provided for @cardMoveAfter.
  ///
  /// In es, this message translates to:
  /// **'Mover después'**
  String get cardMoveAfter;

  /// No description provided for @cardRename.
  ///
  /// In es, this message translates to:
  /// **'Renombrar'**
  String get cardRename;

  /// No description provided for @cardExport.
  ///
  /// In es, this message translates to:
  /// **'Exportar'**
  String get cardExport;

  /// No description provided for @statSpeedShort.
  ///
  /// In es, this message translates to:
  /// **'VEL'**
  String get statSpeedShort;

  /// No description provided for @unitFeetSuffix.
  ///
  /// In es, this message translates to:
  /// **' pies'**
  String get unitFeetSuffix;

  /// No description provided for @statSpeedLabel.
  ///
  /// In es, this message translates to:
  /// **'Velocidad: {speed} pies'**
  String statSpeedLabel(Object speed);

  /// No description provided for @statInitiativeShort.
  ///
  /// In es, this message translates to:
  /// **'INIC'**
  String get statInitiativeShort;

  /// No description provided for @statInitiativeLabel.
  ///
  /// In es, this message translates to:
  /// **'Iniciativa: {bonus}'**
  String statInitiativeLabel(String bonus);

  /// No description provided for @tabCharacter.
  ///
  /// In es, this message translates to:
  /// **'Personaje'**
  String get tabCharacter;

  /// No description provided for @tabCombat.
  ///
  /// In es, this message translates to:
  /// **'Combate'**
  String get tabCombat;

  /// No description provided for @tabInventory.
  ///
  /// In es, this message translates to:
  /// **'Inventario'**
  String get tabInventory;

  /// No description provided for @tabCampaign.
  ///
  /// In es, this message translates to:
  /// **'Campaña'**
  String get tabCampaign;

  /// No description provided for @tabJournal.
  ///
  /// In es, this message translates to:
  /// **'Diario'**
  String get tabJournal;

  /// No description provided for @sheetHeaderTitle.
  ///
  /// In es, this message translates to:
  /// **'{name} · Nivel {level}'**
  String sheetHeaderTitle(String name, Object level);

  /// No description provided for @levelUpAction.
  ///
  /// In es, this message translates to:
  /// **'Subir nivel'**
  String get levelUpAction;

  /// No description provided for @levelMaxReached.
  ///
  /// In es, this message translates to:
  /// **'Nivel máximo'**
  String get levelMaxReached;

  /// No description provided for @portraitClose.
  ///
  /// In es, this message translates to:
  /// **'Cerrar el retrato'**
  String get portraitClose;

  /// No description provided for @navBackToNpc.
  ///
  /// In es, this message translates to:
  /// **'Volver al PNJ'**
  String get navBackToNpc;

  /// No description provided for @sheetClassSummary.
  ///
  /// In es, this message translates to:
  /// **'{summary} · nivel {level}'**
  String sheetClassSummary(String summary, Object level);

  /// No description provided for @navPortrait.
  ///
  /// In es, this message translates to:
  /// **'Retrato'**
  String get navPortrait;

  /// No description provided for @navShare.
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get navShare;

  /// No description provided for @turnNext.
  ///
  /// In es, this message translates to:
  /// **'Preparate, seguís vos.'**
  String get turnNext;

  /// No description provided for @turnActive.
  ///
  /// In es, this message translates to:
  /// **'Es tu turno.'**
  String get turnActive;

  /// No description provided for @commonExpand.
  ///
  /// In es, this message translates to:
  /// **'Desplegar'**
  String get commonExpand;

  /// No description provided for @commonCollapse.
  ///
  /// In es, this message translates to:
  /// **'Plegar'**
  String get commonCollapse;

  /// No description provided for @campaignStateActive.
  ///
  /// In es, this message translates to:
  /// **'En curso'**
  String get campaignStateActive;

  /// No description provided for @campaignStatePaused.
  ///
  /// In es, this message translates to:
  /// **'En pausa'**
  String get campaignStatePaused;

  /// No description provided for @campaignStateFinished.
  ///
  /// In es, this message translates to:
  /// **'Terminada'**
  String get campaignStateFinished;

  /// No description provided for @campaignsLoadError.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron leer tus campañas.'**
  String get campaignsLoadError;

  /// No description provided for @campaignsLoading.
  ///
  /// In es, this message translates to:
  /// **'Cargando tus campañas…'**
  String get campaignsLoading;

  /// No description provided for @campaignEmpty.
  ///
  /// In es, this message translates to:
  /// **'Este personaje todavía no está en ninguna campaña.\nCompartilo con tu DM y acá va a aparecer lo que jueguen.'**
  String get campaignEmpty;

  /// No description provided for @campaignPartyAlso.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{En la mesa también juega {names}.} other{En la mesa también juegan {names}.}}'**
  String campaignPartyAlso(int count, String names);

  /// No description provided for @campaignNoChapter.
  ///
  /// In es, this message translates to:
  /// **'Sin capítulo'**
  String get campaignNoChapter;

  /// No description provided for @campaignBattles.
  ///
  /// In es, this message translates to:
  /// **'Batallas'**
  String get campaignBattles;

  /// No description provided for @roundsCount.
  ///
  /// In es, this message translates to:
  /// **'{rounds, plural, =1{1 ronda} other{{rounds} rondas}}'**
  String roundsCount(int rounds);

  /// No description provided for @campaignNoBattles.
  ///
  /// In es, this message translates to:
  /// **'Todavía no pelearon ninguna.'**
  String get campaignNoBattles;

  /// No description provided for @battleAlone.
  ///
  /// In es, this message translates to:
  /// **'Solo'**
  String get battleAlone;

  /// No description provided for @battleWith.
  ///
  /// In es, this message translates to:
  /// **'Con {names}'**
  String battleWith(String names);

  /// No description provided for @battleGeneric.
  ///
  /// In es, this message translates to:
  /// **'Una pelea'**
  String get battleGeneric;

  /// No description provided for @battleAgainst.
  ///
  /// In es, this message translates to:
  /// **'Contra {names}'**
  String battleAgainst(String names);

  /// No description provided for @enemyOne.
  ///
  /// In es, this message translates to:
  /// **'un enemigo'**
  String get enemyOne;

  /// No description provided for @enemiesCount.
  ///
  /// In es, this message translates to:
  /// **'{count} enemigos'**
  String enemiesCount(Object count);

  /// No description provided for @battleNoEnemies.
  ///
  /// In es, this message translates to:
  /// **'sin enemigos'**
  String get battleNoEnemies;

  /// No description provided for @battleNoneDown.
  ///
  /// In es, this message translates to:
  /// **'no cayó ninguno'**
  String get battleNoneDown;

  /// No description provided for @battleOneDown.
  ///
  /// In es, this message translates to:
  /// **'cayó'**
  String get battleOneDown;

  /// No description provided for @battleAllDown.
  ///
  /// In es, this message translates to:
  /// **'cayeron todos'**
  String get battleAllDown;

  /// No description provided for @battleSomeDown.
  ///
  /// In es, this message translates to:
  /// **'cayeron {down} de {total}'**
  String battleSomeDown(Object down, Object total);

  /// No description provided for @campaignClosedChapters.
  ///
  /// In es, this message translates to:
  /// **'Capítulos cerrados'**
  String get campaignClosedChapters;

  /// No description provided for @campaignNoClosedChapters.
  ///
  /// In es, this message translates to:
  /// **'Todavía no cerraron ninguno. Cuando pase, acá va a quedar anotado lo que se repartió.'**
  String get campaignNoClosedChapters;

  /// No description provided for @campaignNoRewards.
  ///
  /// In es, this message translates to:
  /// **'Sin recompensas'**
  String get campaignNoRewards;

  /// No description provided for @campaignYouTook.
  ///
  /// In es, this message translates to:
  /// **'Te llevaste {grants}'**
  String campaignYouTook(String grants);

  /// Une una lista: «Mirna, Bardo y Yina».
  ///
  /// In es, this message translates to:
  /// **'{head} y {last}'**
  String listAnd(String head, String last);

  /// No description provided for @commonBack.
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get commonBack;

  /// No description provided for @hpMaxSuffix.
  ///
  /// In es, this message translates to:
  /// **'/ {max} PG'**
  String hpMaxSuffix(Object max);

  /// No description provided for @deathSaves.
  ///
  /// In es, this message translates to:
  /// **'Salvaciones de muerte'**
  String get deathSaves;

  /// No description provided for @combatAmount.
  ///
  /// In es, this message translates to:
  /// **'Cantidad'**
  String get combatAmount;

  /// No description provided for @combatHeal.
  ///
  /// In es, this message translates to:
  /// **'Curar'**
  String get combatHeal;

  /// No description provided for @combatTempHp.
  ///
  /// In es, this message translates to:
  /// **'PG temp'**
  String get combatTempHp;

  /// No description provided for @combatStabilized.
  ///
  /// In es, this message translates to:
  /// **'¡Estabilizado!'**
  String get combatStabilized;

  /// No description provided for @combatSuccessPlus.
  ///
  /// In es, this message translates to:
  /// **'+Éxito'**
  String get combatSuccessPlus;

  /// No description provided for @combatCharacterDied.
  ///
  /// In es, this message translates to:
  /// **'El personaje ha muerto.'**
  String get combatCharacterDied;

  /// No description provided for @combatFailurePlus.
  ///
  /// In es, this message translates to:
  /// **'+Fallo'**
  String get combatFailurePlus;

  /// No description provided for @combatNoArmor.
  ///
  /// In es, this message translates to:
  /// **'Sin armadura'**
  String get combatNoArmor;

  /// No description provided for @combatShield.
  ///
  /// In es, this message translates to:
  /// **'escudo'**
  String get combatShield;

  /// No description provided for @combatDefense.
  ///
  /// In es, this message translates to:
  /// **'Defensa'**
  String get combatDefense;

  /// No description provided for @combatResistances.
  ///
  /// In es, this message translates to:
  /// **'Resistencias: {list}'**
  String combatResistances(String list);

  /// No description provided for @combatImmunities.
  ///
  /// In es, this message translates to:
  /// **'Inmunidades: {list}'**
  String combatImmunities(String list);

  /// No description provided for @shortRestNoRestore.
  ///
  /// In es, this message translates to:
  /// **'Descanso corto. No cura PG: gastá dados de golpe para curarte.'**
  String get shortRestNoRestore;

  /// No description provided for @shortRestRestored.
  ///
  /// In es, this message translates to:
  /// **'Descanso corto: recuperaste {list}. Para curarte, gastá dados de golpe.'**
  String shortRestRestored(String list);

  /// No description provided for @longRestBase.
  ///
  /// In es, this message translates to:
  /// **'PG al máximo y recursos recargados'**
  String get longRestBase;

  /// No description provided for @longRestExhaustion.
  ///
  /// In es, this message translates to:
  /// **'cansancio a nivel {level}'**
  String longRestExhaustion(Object level);

  /// No description provided for @longRestInspiration.
  ///
  /// In es, this message translates to:
  /// **'ganaste Inspiración Heroica'**
  String get longRestInspiration;

  /// No description provided for @longRestItemsRecharged.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 objeto mágico recuperó cargas} other{{count} objetos mágicos recuperaron cargas}}'**
  String longRestItemsRecharged(int count);

  /// No description provided for @longRestSummary.
  ///
  /// In es, this message translates to:
  /// **'Descanso largo: {list}.'**
  String longRestSummary(String list);

  /// No description provided for @combatResourcesTitle.
  ///
  /// In es, this message translates to:
  /// **'Recursos y descansos'**
  String get combatResourcesTitle;

  /// No description provided for @combatRestExplainer.
  ///
  /// In es, this message translates to:
  /// **'El descanso corto no cura PG: recarga recursos de recarga corta. Para curarte, gastá dados de golpe.'**
  String get combatRestExplainer;

  /// No description provided for @restShort.
  ///
  /// In es, this message translates to:
  /// **'Descanso corto'**
  String get restShort;

  /// No description provided for @restLong.
  ///
  /// In es, this message translates to:
  /// **'Descanso largo'**
  String get restLong;

  /// No description provided for @combatHitDie.
  ///
  /// In es, this message translates to:
  /// **'Dado de golpe ({left}/{total})'**
  String combatHitDie(Object left, Object total);

  /// No description provided for @saveDc.
  ///
  /// In es, this message translates to:
  /// **'CD {dc}'**
  String saveDc(Object dc);

  /// No description provided for @saveDcAbility.
  ///
  /// In es, this message translates to:
  /// **'CD {dc} de {ability}'**
  String saveDcAbility(Object dc, String ability);

  /// No description provided for @combatPointsOf.
  ///
  /// In es, this message translates to:
  /// **'{left} de {max} puntos'**
  String combatPointsOf(Object left, Object max);

  /// No description provided for @verbSpend.
  ///
  /// In es, this message translates to:
  /// **'gastar'**
  String get verbSpend;

  /// No description provided for @verbRecover.
  ///
  /// In es, this message translates to:
  /// **'recuperar'**
  String get verbRecover;

  /// No description provided for @combatPointsPrompt.
  ///
  /// In es, this message translates to:
  /// **'Puntos a {verb} (hasta {limit})'**
  String combatPointsPrompt(String verb, Object limit);

  /// No description provided for @combatAttacks.
  ///
  /// In es, this message translates to:
  /// **'Ataques'**
  String get combatAttacks;

  /// No description provided for @combatMastery.
  ///
  /// In es, this message translates to:
  /// **'Maestría: {name}'**
  String combatMastery(String name);

  /// No description provided for @combatRangeValue.
  ///
  /// In es, this message translates to:
  /// **'Alcance {range}'**
  String combatRangeValue(String range);

  /// No description provided for @combatOffHand.
  ///
  /// In es, this message translates to:
  /// **'Mano secundaria'**
  String get combatOffHand;

  /// No description provided for @wildShapeAs.
  ///
  /// In es, this message translates to:
  /// **'Transformado en {name}'**
  String wildShapeAs(String name);

  /// No description provided for @wildShapeTitle.
  ///
  /// In es, this message translates to:
  /// **'Forma Salvaje'**
  String get wildShapeTitle;

  /// No description provided for @wildShapeAddForms.
  ///
  /// In es, this message translates to:
  /// **'Anotar'**
  String get wildShapeAddForms;

  /// No description provided for @wildShapeNoForms.
  ///
  /// In es, this message translates to:
  /// **'Todavía no anotaste ninguna forma.'**
  String get wildShapeNoForms;

  /// No description provided for @creatureLine3.
  ///
  /// In es, this message translates to:
  /// **'{kind} · CA {ac} · {speed}'**
  String creatureLine3(String kind, Object ac, String speed);

  /// No description provided for @creatureLine2.
  ///
  /// In es, this message translates to:
  /// **'{kind} · CA {ac}'**
  String creatureLine2(String kind, Object ac);

  /// No description provided for @wildShapeTransform.
  ///
  /// In es, this message translates to:
  /// **'Transformarse'**
  String get wildShapeTransform;

  /// No description provided for @wildShapeDone.
  ///
  /// In es, this message translates to:
  /// **'Te transformaste en {name}: +{level} PG temporales.'**
  String wildShapeDone(String name, Object level);

  /// No description provided for @wildShapeNoUses.
  ///
  /// In es, this message translates to:
  /// **'No te quedan usos de Forma Salvaje.'**
  String get wildShapeNoUses;

  /// No description provided for @wildShapeKnownTitle.
  ///
  /// In es, this message translates to:
  /// **'Formas conocidas ({chosen}/{total})'**
  String wildShapeKnownTitle(Object chosen, Object total);

  /// No description provided for @companionsTitle.
  ///
  /// In es, this message translates to:
  /// **'Compañeros'**
  String get companionsTitle;

  /// No description provided for @companionHpAmount.
  ///
  /// In es, this message translates to:
  /// **'Cantidad de PG'**
  String get companionHpAmount;

  /// No description provided for @companionSummon.
  ///
  /// In es, this message translates to:
  /// **'Invocar'**
  String get companionSummon;

  /// No description provided for @companionSummonAnother.
  ///
  /// In es, this message translates to:
  /// **'Invocar otro'**
  String get companionSummonAnother;

  /// No description provided for @companionNone.
  ///
  /// In es, this message translates to:
  /// **'No hay ninguno invocado.'**
  String get companionNone;

  /// No description provided for @companionSummonAnyway.
  ///
  /// In es, this message translates to:
  /// **'Invocar igual'**
  String get companionSummonAnyway;

  /// No description provided for @companionLimitOneTitle.
  ///
  /// In es, this message translates to:
  /// **'Ya tenés uno en juego'**
  String get companionLimitOneTitle;

  /// No description provided for @companionLimitMaxTitle.
  ///
  /// In es, this message translates to:
  /// **'Llegaste al máximo'**
  String get companionLimitMaxTitle;

  /// No description provided for @companionLimitOneBody.
  ///
  /// In es, this message translates to:
  /// **'Invocar otro hace desaparecer a {going}, con los puntos de golpe que tenga.'**
  String companionLimitOneBody(String going);

  /// No description provided for @companionLimitMaxBody.
  ///
  /// In es, this message translates to:
  /// **'Ya tenés {max}. Invocar otro hace desaparecer al más viejo, {going}.'**
  String companionLimitMaxBody(Object max, String going);

  /// No description provided for @companionPickForm.
  ///
  /// In es, this message translates to:
  /// **'Elegí la forma'**
  String get companionPickForm;

  /// No description provided for @companionNoSlots.
  ///
  /// In es, this message translates to:
  /// **'No te quedan espacios de nivel {level} o más.'**
  String companionNoSlots(Object level);

  /// No description provided for @companionHowSummon.
  ///
  /// In es, this message translates to:
  /// **'Cómo lo invocás'**
  String get companionHowSummon;

  /// No description provided for @companionNoSlotSpend.
  ///
  /// In es, this message translates to:
  /// **'Sin gastar espacio'**
  String get companionNoSlotSpend;

  /// No description provided for @companionFreeLeft.
  ///
  /// In es, this message translates to:
  /// **'{name}: quedan {left} de {max}'**
  String companionFreeLeft(String name, Object left, Object max);

  /// No description provided for @companionSlotsAvailable.
  ///
  /// In es, this message translates to:
  /// **'{left} de {total} disponibles'**
  String companionSlotsAvailable(Object left, Object total);

  /// No description provided for @companionNoteSlot.
  ///
  /// In es, this message translates to:
  /// **'gastaste un espacio de nivel {level}'**
  String companionNoteSlot(Object level);

  /// No description provided for @companionNoteFree.
  ///
  /// In es, this message translates to:
  /// **'sin gastar espacio, por {name}'**
  String companionNoteFree(String name);

  /// No description provided for @companionNoteBroke.
  ///
  /// In es, this message translates to:
  /// **'perdiste la concentración anterior'**
  String get companionNoteBroke;

  /// No description provided for @companionNoteConcentrating.
  ///
  /// In es, this message translates to:
  /// **'quedás concentrado en él'**
  String get companionNoteConcentrating;

  /// No description provided for @companionSummoned.
  ///
  /// In es, this message translates to:
  /// **'{name} invocado.'**
  String companionSummoned(String name);

  /// No description provided for @companionSummonedNotes.
  ///
  /// In es, this message translates to:
  /// **'{name} invocado: {notes}.'**
  String companionSummonedNotes(String name, String notes);

  /// No description provided for @companionGone.
  ///
  /// In es, this message translates to:
  /// **'Esta criatura ya no está en el catálogo.'**
  String get companionGone;

  /// No description provided for @companionDismiss.
  ///
  /// In es, this message translates to:
  /// **'Despedir'**
  String get companionDismiss;

  /// No description provided for @acValue.
  ///
  /// In es, this message translates to:
  /// **'CA {value}'**
  String acValue(Object value);

  /// No description provided for @companionSlotLevel.
  ///
  /// In es, this message translates to:
  /// **'Espacio de nivel {level}'**
  String companionSlotLevel(Object level);

  /// No description provided for @concentration.
  ///
  /// In es, this message translates to:
  /// **'Concentración'**
  String get concentration;

  /// No description provided for @hpFraction.
  ///
  /// In es, this message translates to:
  /// **'{current} / {max} PG'**
  String hpFraction(Object current, Object max);

  /// No description provided for @companionDestroyed.
  ///
  /// In es, this message translates to:
  /// **'{name} fue destruido.'**
  String companionDestroyed(String name);

  /// No description provided for @savesTitle.
  ///
  /// In es, this message translates to:
  /// **'Salvaciones'**
  String get savesTitle;

  /// No description provided for @exhaustion.
  ///
  /// In es, this message translates to:
  /// **'Cansancio'**
  String get exhaustion;

  /// No description provided for @exhaustionRules.
  ///
  /// In es, this message translates to:
  /// **'Cada nivel resta 2 a las pruebas de característica, salvaciones, tiradas de ataque e iniciativa, y 5 pies a la velocidad. Al nivel {max} el personaje muere.\n\nLa ficha ya trae la penalización aplicada en todos sus números: no la restes de nuevo. También le entra a las salvaciones de muerte, aunque esas no lleven número.\n\nUn descanso largo baja un nivel.'**
  String exhaustionRules(Object max);

  /// No description provided for @combatState.
  ///
  /// In es, this message translates to:
  /// **'Estado'**
  String get combatState;

  /// No description provided for @exhaustionPenalty.
  ///
  /// In es, this message translates to:
  /// **'−{rolls} a las tiradas · −{feet} pies'**
  String exhaustionPenalty(Object rolls, Object feet);

  /// No description provided for @exhaustionLower.
  ///
  /// In es, this message translates to:
  /// **'Bajar un nivel de cansancio'**
  String get exhaustionLower;

  /// No description provided for @exhaustionRaise.
  ///
  /// In es, this message translates to:
  /// **'Subir un nivel de cansancio'**
  String get exhaustionRaise;

  /// No description provided for @exhaustionDeath.
  ///
  /// In es, this message translates to:
  /// **'Cansancio nivel {max}: tu personaje muere.'**
  String exhaustionDeath(Object max);

  /// No description provided for @exhaustionNote.
  ///
  /// In es, this message translates to:
  /// **'Nivel {max}: tu personaje muere. La ficha no lo aplica ni te toca los PG — esa decisión es de la mesa.'**
  String exhaustionNote(Object max);

  /// No description provided for @inspirationUse.
  ///
  /// In es, this message translates to:
  /// **'Repetí un dado apenas lo tirás y quedate con el resultado nuevo'**
  String get inspirationUse;

  /// No description provided for @inspirationLongRest.
  ///
  /// In es, this message translates to:
  /// **'La recuperás al terminar un descanso largo'**
  String get inspirationLongRest;

  /// No description provided for @inspirationGrant.
  ///
  /// In es, this message translates to:
  /// **'Marcala cuando el DM te la dé'**
  String get inspirationGrant;

  /// No description provided for @inspirationSpend.
  ///
  /// In es, this message translates to:
  /// **'Gastar la Inspiración Heroica'**
  String get inspirationSpend;

  /// No description provided for @inspirationMark.
  ///
  /// In es, this message translates to:
  /// **'Marcar que la tenés'**
  String get inspirationMark;

  /// No description provided for @heroicInspiration.
  ///
  /// In es, this message translates to:
  /// **'Inspiración Heroica'**
  String get heroicInspiration;

  /// No description provided for @inspirationHave.
  ///
  /// In es, this message translates to:
  /// **'LA TENÉS'**
  String get inspirationHave;

  /// No description provided for @inspirationSpent.
  ///
  /// In es, this message translates to:
  /// **'GASTADA'**
  String get inspirationSpent;

  /// No description provided for @conditionsTitle.
  ///
  /// In es, this message translates to:
  /// **'Condiciones'**
  String get conditionsTitle;

  /// No description provided for @combatHitDieHealed.
  ///
  /// In es, this message translates to:
  /// **'Recuperaste {hp} PG (dado de golpe)'**
  String combatHitDieHealed(Object hp);

  /// No description provided for @wildShapeUses.
  ///
  /// In es, this message translates to:
  /// **'Usos: {left} de {max}'**
  String wildShapeUses(Object left, Object max);

  /// No description provided for @wildShapeForms.
  ///
  /// In es, this message translates to:
  /// **'Formas: {chosen} de {total}'**
  String wildShapeForms(Object chosen, Object total);

  /// No description provided for @exhaustionLevelOf.
  ///
  /// In es, this message translates to:
  /// **'Cansancio: nivel {level} de {max}'**
  String exhaustionLevelOf(Object level, Object max);

  /// No description provided for @replaceProficiency.
  ///
  /// In es, this message translates to:
  /// **'Competencia reemplazable'**
  String get replaceProficiency;

  /// No description provided for @replaceChoice.
  ///
  /// In es, this message translates to:
  /// **'Elección reemplazable'**
  String get replaceChoice;

  /// No description provided for @replaceSpells.
  ///
  /// In es, this message translates to:
  /// **'Conjuros reemplazables'**
  String get replaceSpells;

  /// No description provided for @sheetWarnings.
  ///
  /// In es, this message translates to:
  /// **'Advertencias'**
  String get sheetWarnings;

  /// No description provided for @sheetResolve.
  ///
  /// In es, this message translates to:
  /// **'Resolver'**
  String get sheetResolve;

  /// No description provided for @replaceableNoticeBody.
  ///
  /// In es, this message translates to:
  /// **'Este rasgo permite cambiar la elección que ya hiciste.'**
  String get replaceableNoticeBody;

  /// No description provided for @sheetChange.
  ///
  /// In es, this message translates to:
  /// **'Cambiar'**
  String get sheetChange;

  /// No description provided for @pickExpertiseTitle.
  ///
  /// In es, this message translates to:
  /// **'Elegir Pericia'**
  String get pickExpertiseTitle;

  /// No description provided for @pickProficienciesTitle.
  ///
  /// In es, this message translates to:
  /// **'Elegir competencias'**
  String get pickProficienciesTitle;

  /// No description provided for @pickProficienciesHint.
  ///
  /// In es, this message translates to:
  /// **'Las opciones que ya tenés por otra vía quedan bloqueadas. En los cupos de Pericia es al revés: solo se ofrecen las habilidades en las que ya sos competente, y duplicás el bonificador en ellas.'**
  String get pickProficienciesHint;

  /// No description provided for @pickSizeTitle.
  ///
  /// In es, this message translates to:
  /// **'Elegir tamaño'**
  String get pickSizeTitle;

  /// No description provided for @pickSizeHint.
  ///
  /// In es, this message translates to:
  /// **'Esta especie abarca cuerpos de tamaños distintos: elegí el de tu personaje.'**
  String get pickSizeHint;

  /// No description provided for @pickLineageTitle.
  ///
  /// In es, this message translates to:
  /// **'Elegir linaje'**
  String get pickLineageTitle;

  /// No description provided for @pickLineageHint.
  ///
  /// In es, this message translates to:
  /// **'El linaje decide los rasgos que aporta la especie.'**
  String get pickLineageHint;

  /// No description provided for @pickSpellAbilityTitle.
  ///
  /// In es, this message translates to:
  /// **'Elegir aptitud mágica'**
  String get pickSpellAbilityTitle;

  /// No description provided for @pickLineageSpellAbilityHint.
  ///
  /// In es, this message translates to:
  /// **'Se usa para la CD y los ataques de los conjuros del linaje.'**
  String get pickLineageSpellAbilityHint;

  /// No description provided for @pickFeatSpellAbilityTitle.
  ///
  /// In es, this message translates to:
  /// **'Aptitud mágica de {name}'**
  String pickFeatSpellAbilityTitle(String name);

  /// No description provided for @pickFeatSpellAbilityHint.
  ///
  /// In es, this message translates to:
  /// **'Se usa para la CD y los ataques de los conjuros de esta dote.'**
  String get pickFeatSpellAbilityHint;

  /// No description provided for @pickFeaturesTitle.
  ///
  /// In es, this message translates to:
  /// **'Elegir rasgos'**
  String get pickFeaturesTitle;

  /// No description provided for @pickNoOptions.
  ///
  /// In es, this message translates to:
  /// **'No hay opciones disponibles todavía.'**
  String get pickNoOptions;

  /// No description provided for @pickSpellsTitle.
  ///
  /// In es, this message translates to:
  /// **'Elegir conjuros'**
  String get pickSpellsTitle;

  /// No description provided for @pickKnownSpellHint.
  ///
  /// In es, this message translates to:
  /// **'Elegí uno que ya conocés: no se suma a tus conjuros, le agrega el bono al daño.'**
  String get pickKnownSpellHint;

  /// No description provided for @pickNoSpells.
  ///
  /// In es, this message translates to:
  /// **'No hay conjuros disponibles para este rasgo.'**
  String get pickNoSpells;

  /// No description provided for @pickLanguagesTitle.
  ///
  /// In es, this message translates to:
  /// **'Elegir idiomas'**
  String get pickLanguagesTitle;

  /// No description provided for @pickLanguagesIntro.
  ///
  /// In es, this message translates to:
  /// **'Todo personaje sabe {language}, que no ocupa una elección.'**
  String pickLanguagesIntro(String language);

  /// No description provided for @pickLanguagesOrigin.
  ///
  /// In es, this message translates to:
  /// **'De tu origen ({chosen}/{total})'**
  String pickLanguagesOrigin(Object chosen, Object total);

  /// No description provided for @identityAlignment.
  ///
  /// In es, this message translates to:
  /// **'Alineamiento'**
  String get identityAlignment;

  /// No description provided for @identityCreatureType.
  ///
  /// In es, this message translates to:
  /// **'Tipo de criatura'**
  String get identityCreatureType;

  /// No description provided for @identitySize.
  ///
  /// In es, this message translates to:
  /// **'Tamaño'**
  String get identitySize;

  /// No description provided for @identityBackground.
  ///
  /// In es, this message translates to:
  /// **'Trasfondo'**
  String get identityBackground;

  /// No description provided for @identityTrait.
  ///
  /// In es, this message translates to:
  /// **'Rasgo'**
  String get identityTrait;

  /// No description provided for @identityTitle.
  ///
  /// In es, this message translates to:
  /// **'Identidad'**
  String get identityTitle;

  /// No description provided for @abilitiesTitle.
  ///
  /// In es, this message translates to:
  /// **'Características'**
  String get abilitiesTitle;

  /// No description provided for @abilitiesHintLead.
  ///
  /// In es, this message translates to:
  /// **'La cifra grande es el modificador. '**
  String get abilitiesHintLead;

  /// No description provided for @abilitiesHintTail.
  ///
  /// In es, this message translates to:
  /// **' marca las salvaciones competentes; tocá una placa para ver de dónde sale.'**
  String get abilitiesHintTail;

  /// No description provided for @unarmoredTitle.
  ///
  /// In es, this message translates to:
  /// **'Defensa sin armadura'**
  String get unarmoredTitle;

  /// No description provided for @unarmoredFormula.
  ///
  /// In es, this message translates to:
  /// **'Fórmula de CA'**
  String get unarmoredFormula;

  /// No description provided for @proficienciesTitle.
  ///
  /// In es, this message translates to:
  /// **'Competencias'**
  String get proficienciesTitle;

  /// No description provided for @armorUpper.
  ///
  /// In es, this message translates to:
  /// **'ARMADURA'**
  String get armorUpper;

  /// No description provided for @passivePerception.
  ///
  /// In es, this message translates to:
  /// **'Percepción pasiva'**
  String get passivePerception;

  /// No description provided for @darkvision.
  ///
  /// In es, this message translates to:
  /// **'Visión en la oscuridad'**
  String get darkvision;

  /// No description provided for @skillsLegendProficient.
  ///
  /// In es, this message translates to:
  /// **'Competente'**
  String get skillsLegendProficient;

  /// No description provided for @skillsLegendExpertise.
  ///
  /// In es, this message translates to:
  /// **'Pericia · bonificador duplicado'**
  String get skillsLegendExpertise;

  /// No description provided for @skillExpertiseBadge.
  ///
  /// In es, this message translates to:
  /// **'PERICIA'**
  String get skillExpertiseBadge;

  /// No description provided for @traitsAndFeatsTitle.
  ///
  /// In es, this message translates to:
  /// **'Rasgos y dotes'**
  String get traitsAndFeatsTitle;

  /// No description provided for @statArmor.
  ///
  /// In es, this message translates to:
  /// **'Armadura'**
  String get statArmor;

  /// No description provided for @exhaustionSpeed.
  ///
  /// In es, this message translates to:
  /// **'Cansancio −{feet} pies'**
  String exhaustionSpeed(Object feet);

  /// No description provided for @statProficiency.
  ///
  /// In es, this message translates to:
  /// **'Competencia'**
  String get statProficiency;

  /// No description provided for @breakdownWhereFrom.
  ///
  /// In es, this message translates to:
  /// **'De dónde sale'**
  String get breakdownWhereFrom;

  /// No description provided for @breakdownDexModifier.
  ///
  /// In es, this message translates to:
  /// **'Modificador de Destreza'**
  String get breakdownDexModifier;

  /// No description provided for @breakdownOtherTrait.
  ///
  /// In es, this message translates to:
  /// **'Otro rasgo'**
  String get breakdownOtherTrait;

  /// No description provided for @exhaustionLevel.
  ///
  /// In es, this message translates to:
  /// **'Cansancio nivel {level}'**
  String exhaustionLevel(Object level);

  /// No description provided for @breakdownAssigned.
  ///
  /// In es, this message translates to:
  /// **'Asignada en la creación'**
  String get breakdownAssigned;

  /// No description provided for @breakdownScore.
  ///
  /// In es, this message translates to:
  /// **'Puntuación'**
  String get breakdownScore;

  /// No description provided for @breakdownModifier.
  ///
  /// In es, this message translates to:
  /// **'Modificador'**
  String get breakdownModifier;

  /// No description provided for @breakdownWhatToRoll.
  ///
  /// In es, this message translates to:
  /// **'Qué se tira con esto'**
  String get breakdownWhatToRoll;

  /// No description provided for @breakdownSave.
  ///
  /// In es, this message translates to:
  /// **'Salvación'**
  String get breakdownSave;

  /// No description provided for @breakdownSaveProficient.
  ///
  /// In es, this message translates to:
  /// **'Salvación (competente)'**
  String get breakdownSaveProficient;

  /// No description provided for @breakdownSkillExpertise.
  ///
  /// In es, this message translates to:
  /// **'{skill} (pericia)'**
  String breakdownSkillExpertise(String skill);

  /// No description provided for @breakdownIncludes.
  ///
  /// In es, this message translates to:
  /// **'incluye {amount} de {source}'**
  String breakdownIncludes(String amount, String source);

  /// No description provided for @breakdownAbilityChecks.
  ///
  /// In es, this message translates to:
  /// **'Pruebas de característica'**
  String get breakdownAbilityChecks;

  /// No description provided for @breakdownExhaustion.
  ///
  /// In es, this message translates to:
  /// **'incluye −{penalty} por cansancio nivel {level}'**
  String breakdownExhaustion(Object penalty, Object level);

  /// No description provided for @breakdownSpellAttack.
  ///
  /// In es, this message translates to:
  /// **'Ataque con conjuros'**
  String get breakdownSpellAttack;

  /// No description provided for @breakdownSaveDc.
  ///
  /// In es, this message translates to:
  /// **'CD de salvación'**
  String get breakdownSaveDc;

  /// No description provided for @breakdownFooter.
  ///
  /// In es, this message translates to:
  /// **'Competencia +{bonus} a nivel {level}, ya incluida arriba. Solo se listan las habilidades en las que sos competente: el resto tira con la prueba de característica ({check}).'**
  String breakdownFooter(Object bonus, Object level, String check);

  /// No description provided for @commonAdd.
  ///
  /// In es, this message translates to:
  /// **'Agregar'**
  String get commonAdd;

  /// No description provided for @commonBuy.
  ///
  /// In es, this message translates to:
  /// **'Comprar'**
  String get commonBuy;

  /// No description provided for @commonSell.
  ///
  /// In es, this message translates to:
  /// **'Vender'**
  String get commonSell;

  /// No description provided for @commonBag.
  ///
  /// In es, this message translates to:
  /// **'Bolsa'**
  String get commonBag;

  /// No description provided for @kindWeapon.
  ///
  /// In es, this message translates to:
  /// **'Arma'**
  String get kindWeapon;

  /// No description provided for @kindArmor.
  ///
  /// In es, this message translates to:
  /// **'Armadura'**
  String get kindArmor;

  /// No description provided for @kindAmmunition.
  ///
  /// In es, this message translates to:
  /// **'Munición'**
  String get kindAmmunition;

  /// No description provided for @kindFocus.
  ///
  /// In es, this message translates to:
  /// **'Canalizador'**
  String get kindFocus;

  /// No description provided for @kindMagicItem.
  ///
  /// In es, this message translates to:
  /// **'Objeto mágico'**
  String get kindMagicItem;

  /// No description provided for @kindTool.
  ///
  /// In es, this message translates to:
  /// **'Herramienta'**
  String get kindTool;

  /// No description provided for @kindContainer.
  ///
  /// In es, this message translates to:
  /// **'Contenedor'**
  String get kindContainer;

  /// No description provided for @kindPack.
  ///
  /// In es, this message translates to:
  /// **'Paquete'**
  String get kindPack;

  /// No description provided for @kindGear.
  ///
  /// In es, this message translates to:
  /// **'Equipo'**
  String get kindGear;

  /// No description provided for @kindShield.
  ///
  /// In es, this message translates to:
  /// **'Escudo'**
  String get kindShield;

  /// No description provided for @groupWeapons.
  ///
  /// In es, this message translates to:
  /// **'Armas'**
  String get groupWeapons;

  /// No description provided for @groupArmor.
  ///
  /// In es, this message translates to:
  /// **'Armaduras'**
  String get groupArmor;

  /// No description provided for @groupFocuses.
  ///
  /// In es, this message translates to:
  /// **'Canalizadores'**
  String get groupFocuses;

  /// No description provided for @groupMagicItems.
  ///
  /// In es, this message translates to:
  /// **'Objetos mágicos'**
  String get groupMagicItems;

  /// No description provided for @groupTools.
  ///
  /// In es, this message translates to:
  /// **'Herramientas'**
  String get groupTools;

  /// No description provided for @groupContainers.
  ///
  /// In es, this message translates to:
  /// **'Contenedores'**
  String get groupContainers;

  /// No description provided for @groupPacks.
  ///
  /// In es, this message translates to:
  /// **'Paquetes'**
  String get groupPacks;

  /// No description provided for @catalogNotInCatalog.
  ///
  /// In es, this message translates to:
  /// **'No está en el catálogo'**
  String get catalogNotInCatalog;

  /// No description provided for @filterAll.
  ///
  /// In es, this message translates to:
  /// **'Todos'**
  String get filterAll;

  /// No description provided for @filterEquipped.
  ///
  /// In es, this message translates to:
  /// **'Equipados'**
  String get filterEquipped;

  /// No description provided for @filterMagic.
  ///
  /// In es, this message translates to:
  /// **'Mágicos'**
  String get filterMagic;

  /// No description provided for @coinCopper.
  ///
  /// In es, this message translates to:
  /// **'cobre'**
  String get coinCopper;

  /// No description provided for @coinSilver.
  ///
  /// In es, this message translates to:
  /// **'plata'**
  String get coinSilver;

  /// No description provided for @coinElectrum.
  ///
  /// In es, this message translates to:
  /// **'electro'**
  String get coinElectrum;

  /// No description provided for @coinGold.
  ///
  /// In es, this message translates to:
  /// **'oro'**
  String get coinGold;

  /// No description provided for @coinPlatinum.
  ///
  /// In es, this message translates to:
  /// **'platino'**
  String get coinPlatinum;

  /// No description provided for @coinAbbrCopper.
  ///
  /// In es, this message translates to:
  /// **'pc'**
  String get coinAbbrCopper;

  /// No description provided for @coinAbbrSilver.
  ///
  /// In es, this message translates to:
  /// **'pp'**
  String get coinAbbrSilver;

  /// No description provided for @coinAbbrElectrum.
  ///
  /// In es, this message translates to:
  /// **'pe'**
  String get coinAbbrElectrum;

  /// No description provided for @coinAbbrGold.
  ///
  /// In es, this message translates to:
  /// **'po'**
  String get coinAbbrGold;

  /// No description provided for @coinAbbrPlatinum.
  ///
  /// In es, this message translates to:
  /// **'ppt'**
  String get coinAbbrPlatinum;

  /// No description provided for @catalogBundleOf.
  ///
  /// In es, this message translates to:
  /// **'paquete de {size}'**
  String catalogBundleOf(Object size);

  /// No description provided for @catalogAttunement.
  ///
  /// In es, this message translates to:
  /// **'sintonización'**
  String get catalogAttunement;

  /// No description provided for @catalogMissing.
  ///
  /// In es, this message translates to:
  /// **'te faltan {amount}'**
  String catalogMissing(String amount);

  /// No description provided for @catalogShortBy.
  ///
  /// In es, this message translates to:
  /// **'Faltan {amount}'**
  String catalogShortBy(String amount);

  /// No description provided for @catalogAddTitle.
  ///
  /// In es, this message translates to:
  /// **'Agregar objeto'**
  String get catalogAddTitle;

  /// No description provided for @catalogSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar objeto…'**
  String get catalogSearchHint;

  /// No description provided for @catalogNoMatches.
  ///
  /// In es, this message translates to:
  /// **'Sin coincidencias.'**
  String get catalogNoMatches;

  /// No description provided for @catalogAdded.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 objeto agregado a la mochila.} other{{count} objetos agregados a la mochila.}}'**
  String catalogAdded(int count);

  /// No description provided for @tradeUnitBundle.
  ///
  /// In es, this message translates to:
  /// **'paquete'**
  String get tradeUnitBundle;

  /// No description provided for @tradeUnitItem.
  ///
  /// In es, this message translates to:
  /// **'unidad'**
  String get tradeUnitItem;

  /// No description provided for @tradeBundles.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 paquete} other{{count} paquetes}}'**
  String tradeBundles(int count);

  /// No description provided for @tradeUnitsCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 unidad} other{{count} unidades}}'**
  String tradeUnitsCount(int count);

  /// No description provided for @tradeQuantity.
  ///
  /// In es, this message translates to:
  /// **'Cantidad'**
  String get tradeQuantity;

  /// No description provided for @tradeTotalUnits.
  ///
  /// In es, this message translates to:
  /// **'{count} en total'**
  String tradeTotalUnits(Object count);

  /// No description provided for @tradeLeft.
  ///
  /// In es, this message translates to:
  /// **'te quedan {count}'**
  String tradeLeft(Object count);

  /// No description provided for @tradeOneLess.
  ///
  /// In es, this message translates to:
  /// **'Uno menos'**
  String get tradeOneLess;

  /// No description provided for @tradeOneMore.
  ///
  /// In es, this message translates to:
  /// **'Uno más'**
  String get tradeOneMore;

  /// No description provided for @tradeBuyPrice.
  ///
  /// In es, this message translates to:
  /// **'Precio por {unit}'**
  String tradeBuyPrice(String unit);

  /// No description provided for @tradeSellPrice.
  ///
  /// In es, this message translates to:
  /// **'Te pagan por {unit}'**
  String tradeSellPrice(String unit);

  /// No description provided for @tradeCatalogPrice.
  ///
  /// In es, this message translates to:
  /// **'Catálogo: {price}'**
  String tradeCatalogPrice(String price);

  /// No description provided for @tradeSuggested.
  ///
  /// In es, this message translates to:
  /// **'Sugerido: la mitad del catálogo, {price}.'**
  String tradeSuggested(String price);

  /// No description provided for @tradeBackCatalog.
  ///
  /// In es, this message translates to:
  /// **'Volver al del catálogo'**
  String get tradeBackCatalog;

  /// No description provided for @tradeBackSuggested.
  ///
  /// In es, this message translates to:
  /// **'Volver al sugerido'**
  String get tradeBackSuggested;

  /// No description provided for @tradeTotalBuy.
  ///
  /// In es, this message translates to:
  /// **'TOTAL'**
  String get tradeTotalBuy;

  /// No description provided for @tradeTotalSell.
  ///
  /// In es, this message translates to:
  /// **'COBRÁS'**
  String get tradeTotalSell;

  /// No description provided for @tradeShort.
  ///
  /// In es, this message translates to:
  /// **'Te faltan {amount}. Si el DM te lo regala o te lo fía, cerrá y usá «Agregar».'**
  String tradeShort(String amount);

  /// No description provided for @tradePaidFrom.
  ///
  /// In es, this message translates to:
  /// **'Sale de la bolsa: {coins}.'**
  String tradePaidFrom(String coins);

  /// No description provided for @tradeChange.
  ///
  /// In es, this message translates to:
  /// **'Te vuelven {coins}.'**
  String tradeChange(String coins);

  /// No description provided for @tradeBagAfter.
  ///
  /// In es, this message translates to:
  /// **'La bolsa queda en {amount}.'**
  String tradeBagAfter(String amount);

  /// No description provided for @tradeBagAfterCoins.
  ///
  /// In es, this message translates to:
  /// **'La bolsa queda en {amount} ({coins}).'**
  String tradeBagAfterCoins(String amount, String coins);

  /// No description provided for @commonDone.
  ///
  /// In es, this message translates to:
  /// **'Listo'**
  String get commonDone;

  /// No description provided for @invCoins.
  ///
  /// In es, this message translates to:
  /// **'Monedas'**
  String get invCoins;

  /// No description provided for @invCoinsEquals.
  ///
  /// In es, this message translates to:
  /// **'Equivale a '**
  String get invCoinsEquals;

  /// No description provided for @invCoinsWeigh.
  ///
  /// In es, this message translates to:
  /// **' po · pesan '**
  String get invCoinsWeigh;

  /// No description provided for @invCoinLabel.
  ///
  /// In es, this message translates to:
  /// **'Monedas de {name} ({abbr})'**
  String invCoinLabel(String name, String abbr);

  /// No description provided for @invLoad.
  ///
  /// In es, this message translates to:
  /// **'Carga'**
  String get invLoad;

  /// No description provided for @invLoadPercent.
  ///
  /// In es, this message translates to:
  /// **'{percent}% de la capacidad'**
  String invLoadPercent(Object percent);

  /// No description provided for @invLoadItems.
  ///
  /// In es, this message translates to:
  /// **'Objetos {weight} lb'**
  String invLoadItems(String weight);

  /// No description provided for @invLoadCoins.
  ///
  /// In es, this message translates to:
  /// **'Monedas {weight} lb'**
  String invLoadCoins(String weight);

  /// No description provided for @invOverCapacity.
  ///
  /// In es, this message translates to:
  /// **'Pasás tu capacidad de carga. En 2024 no hay penalización de reglas: es un aviso, no un bloqueo.'**
  String get invOverCapacity;

  /// No description provided for @invAttunementUpper.
  ///
  /// In es, this message translates to:
  /// **'SINTONIZACIÓN'**
  String get invAttunementUpper;

  /// No description provided for @invAttunementHint.
  ///
  /// In es, this message translates to:
  /// **'Se sintoniza desde el menú de cada objeto; acá se ve cuántos cupos quedan y con qué están ocupados.'**
  String get invAttunementHint;

  /// No description provided for @invAttuneSlotFree.
  ///
  /// In es, this message translates to:
  /// **'Cupo de sintonización libre'**
  String get invAttuneSlotFree;

  /// No description provided for @invAttunedName.
  ///
  /// In es, this message translates to:
  /// **'{name} — sintonizado'**
  String invAttunedName(String name);

  /// No description provided for @invSlotFree.
  ///
  /// In es, this message translates to:
  /// **'Cupo libre'**
  String get invSlotFree;

  /// No description provided for @invTitle.
  ///
  /// In es, this message translates to:
  /// **'Inventario'**
  String get invTitle;

  /// No description provided for @invEmpty.
  ///
  /// In es, this message translates to:
  /// **'La mochila está vacía.'**
  String get invEmpty;

  /// No description provided for @invPlansButton.
  ///
  /// In es, this message translates to:
  /// **'Planos y réplicas ({chosen}/{total})'**
  String invPlansButton(Object chosen, Object total);

  /// No description provided for @invSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar en la mochila…'**
  String get invSearchHint;

  /// No description provided for @invNoMatches.
  ///
  /// In es, this message translates to:
  /// **'Ningún objeto coincide con ese filtro.'**
  String get invNoMatches;

  /// No description provided for @invHeadItem.
  ///
  /// In es, this message translates to:
  /// **'OBJETO'**
  String get invHeadItem;

  /// No description provided for @invHeadQty.
  ///
  /// In es, this message translates to:
  /// **'CANT.'**
  String get invHeadQty;

  /// No description provided for @invHeadEquipped.
  ///
  /// In es, this message translates to:
  /// **'EQUIPADO'**
  String get invHeadEquipped;

  /// No description provided for @invHeadWeight.
  ///
  /// In es, this message translates to:
  /// **'PESO'**
  String get invHeadWeight;

  /// No description provided for @invNoWeight.
  ///
  /// In es, this message translates to:
  /// **'Sin peso'**
  String get invNoWeight;

  /// No description provided for @invRemoveOne.
  ///
  /// In es, this message translates to:
  /// **'Quitar una unidad de {name}'**
  String invRemoveOne(String name);

  /// No description provided for @invAddOne.
  ///
  /// In es, this message translates to:
  /// **'Agregar una unidad de {name}'**
  String invAddOne(String name);

  /// No description provided for @invCharges.
  ///
  /// In es, this message translates to:
  /// **'{left} cargas'**
  String invCharges(Object left);

  /// No description provided for @invChargesOf.
  ///
  /// In es, this message translates to:
  /// **'Cargas {left}/{max}'**
  String invChargesOf(Object left, Object max);

  /// No description provided for @invSpendCharge.
  ///
  /// In es, this message translates to:
  /// **'Gastar una carga de {name}'**
  String invSpendCharge(String name);

  /// No description provided for @invRecoverCharge.
  ///
  /// In es, this message translates to:
  /// **'Recuperar una carga de {name}'**
  String invRecoverCharge(String name);

  /// No description provided for @invSeeWhatItDoes.
  ///
  /// In es, this message translates to:
  /// **'Ver qué hace'**
  String get invSeeWhatItDoes;

  /// No description provided for @invAttuned.
  ///
  /// In es, this message translates to:
  /// **'Sintonizado'**
  String get invAttuned;

  /// No description provided for @invReplica.
  ///
  /// In es, this message translates to:
  /// **'Réplica'**
  String get invReplica;

  /// No description provided for @invNotEquippable.
  ///
  /// In es, this message translates to:
  /// **'No se equipa'**
  String get invNotEquippable;

  /// No description provided for @invEquipped.
  ///
  /// In es, this message translates to:
  /// **'Equipado'**
  String get invEquipped;

  /// No description provided for @invExactQuantity.
  ///
  /// In es, this message translates to:
  /// **'Cantidad exacta…'**
  String get invExactQuantity;

  /// No description provided for @invNote.
  ///
  /// In es, this message translates to:
  /// **'Nota…'**
  String get invNote;

  /// No description provided for @invUnattune.
  ///
  /// In es, this message translates to:
  /// **'Quitar sintonización'**
  String get invUnattune;

  /// No description provided for @invAttune.
  ///
  /// In es, this message translates to:
  /// **'Sintonizar'**
  String get invAttune;

  /// No description provided for @invTwoHanded.
  ///
  /// In es, this message translates to:
  /// **'A dos manos'**
  String get invTwoHanded;

  /// No description provided for @invTransmute.
  ///
  /// In es, this message translates to:
  /// **'Transmutar réplica…'**
  String get invTransmute;

  /// No description provided for @invSellMenu.
  ///
  /// In es, this message translates to:
  /// **'Vender…'**
  String get invSellMenu;

  /// No description provided for @invRemove.
  ///
  /// In es, this message translates to:
  /// **'Quitar'**
  String get invRemove;

  /// No description provided for @invBundlesOf.
  ///
  /// In es, this message translates to:
  /// **'Paquetes de {size}'**
  String invBundlesOf(Object size);

  /// No description provided for @invUnits.
  ///
  /// In es, this message translates to:
  /// **'Unidades'**
  String get invUnits;

  /// No description provided for @invNoteTitle.
  ///
  /// In es, this message translates to:
  /// **'Nota'**
  String get invNoteTitle;

  /// No description provided for @invNoteLabel.
  ///
  /// In es, this message translates to:
  /// **'Qué dice, de dónde salió, para qué sirve'**
  String get invNoteLabel;

  /// No description provided for @invRemoved.
  ///
  /// In es, this message translates to:
  /// **'Quitaste {name}.'**
  String invRemoved(String name);

  /// No description provided for @invTransmuteInto.
  ///
  /// In es, this message translates to:
  /// **'Transmutar en'**
  String get invTransmuteInto;

  /// No description provided for @invCatalogHint.
  ///
  /// In es, this message translates to:
  /// **'Agregar es gratis y deja seguir sumando; comprar paga de la bolsa.'**
  String get invCatalogHint;

  /// No description provided for @invBuyTitle.
  ///
  /// In es, this message translates to:
  /// **'Comprar {name}'**
  String invBuyTitle(String name);

  /// No description provided for @invBought.
  ///
  /// In es, this message translates to:
  /// **'Compraste {quantity} × {name} por {amount}.'**
  String invBought(Object quantity, String name, String amount);

  /// No description provided for @invSellTitle.
  ///
  /// In es, this message translates to:
  /// **'Vender {name}'**
  String invSellTitle(String name);

  /// No description provided for @invSellDetail.
  ///
  /// In es, this message translates to:
  /// **'Tenés {quantity} · catálogo {price}'**
  String invSellDetail(Object quantity, String price);

  /// No description provided for @invSold.
  ///
  /// In es, this message translates to:
  /// **'Vendiste {quantity} × {name} por {amount}.'**
  String invSold(Object quantity, String name, String amount);

  /// No description provided for @invTargetHint.
  ///
  /// In es, this message translates to:
  /// **'Elegí un ejemplar de la mochila o creá uno de los permitidos por el rasgo.'**
  String get invTargetHint;

  /// No description provided for @invInPack.
  ///
  /// In es, this message translates to:
  /// **'En la mochila'**
  String get invInPack;

  /// No description provided for @invNoEligible.
  ///
  /// In es, this message translates to:
  /// **'No hay ejemplares elegibles.'**
  String get invNoEligible;

  /// No description provided for @invCreatedByFeature.
  ///
  /// In es, this message translates to:
  /// **'Creada por este rasgo'**
  String get invCreatedByFeature;

  /// No description provided for @invCreateWeapon.
  ///
  /// In es, this message translates to:
  /// **'Crear arma'**
  String get invCreateWeapon;

  /// No description provided for @invAddAndEquip.
  ///
  /// In es, this message translates to:
  /// **'Agregar y equipar'**
  String get invAddAndEquip;

  /// No description provided for @invClearLink.
  ///
  /// In es, this message translates to:
  /// **'Limpiar vínculo'**
  String get invClearLink;

  /// No description provided for @invPlansIntro.
  ///
  /// In es, this message translates to:
  /// **'Elegís {count} planos. Después decidís cuál replicar: podés tener {active, plural, =1{1 réplica activa} other{{active} réplicas activas}} a la vez.'**
  String invPlansIntro(int count, int active);

  /// No description provided for @invActiveReplicas.
  ///
  /// In es, this message translates to:
  /// **'Réplicas activas'**
  String get invActiveReplicas;

  /// No description provided for @invPlansMissing.
  ///
  /// In es, this message translates to:
  /// **'Falta elegir {count}.'**
  String invPlansMissing(Object count);

  /// No description provided for @invPickBlueprint.
  ///
  /// In es, this message translates to:
  /// **'Elegí un plano para poder replicarlo.'**
  String get invPickBlueprint;

  /// No description provided for @invReplicaSlotsLeft.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Queda 1 cupo libre.} other{Quedan {count} cupos libres.}}'**
  String invReplicaSlotsLeft(int count);

  /// No description provided for @invReplicaNoSlots.
  ///
  /// In es, this message translates to:
  /// **'Sin cupos libres: quitá una réplica para crear otra.'**
  String get invReplicaNoSlots;

  /// No description provided for @invRemoveReplica.
  ///
  /// In es, this message translates to:
  /// **'Quitar la réplica de {name}'**
  String invRemoveReplica(String name);

  /// No description provided for @invCreateReplica.
  ///
  /// In es, this message translates to:
  /// **'Crear la réplica de {name}'**
  String invCreateReplica(String name);

  /// No description provided for @invNoReplicaSlots.
  ///
  /// In es, this message translates to:
  /// **'No quedan cupos de réplica'**
  String get invNoReplicaSlots;

  /// No description provided for @invPickBase.
  ///
  /// In es, this message translates to:
  /// **'Elegí el objeto base'**
  String get invPickBase;

  /// No description provided for @invRangeHint.
  ///
  /// In es, this message translates to:
  /// **'alcance {range}'**
  String invRangeHint(String range);

  /// No description provided for @invTwoHandedMounted.
  ///
  /// In es, this message translates to:
  /// **'exige dos manos salvo montado'**
  String get invTwoHandedMounted;

  /// No description provided for @invTwoHandedHint.
  ///
  /// In es, this message translates to:
  /// **'exige dos manos'**
  String get invTwoHandedHint;

  /// No description provided for @commonEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get commonEdit;

  /// No description provided for @diaryImportMd.
  ///
  /// In es, this message translates to:
  /// **'Importar un .md'**
  String get diaryImportMd;

  /// No description provided for @diaryExportMd.
  ///
  /// In es, this message translates to:
  /// **'Exportar como .md'**
  String get diaryExportMd;

  /// No description provided for @diaryFinishEditing.
  ///
  /// In es, this message translates to:
  /// **'Terminar de editar'**
  String get diaryFinishEditing;

  /// No description provided for @diaryEditBackground.
  ///
  /// In es, this message translates to:
  /// **'Editar el trasfondo'**
  String get diaryEditBackground;

  /// No description provided for @diaryBackgroundHint.
  ///
  /// In es, this message translates to:
  /// **'De dónde viene, qué dejó atrás, qué le debe a quién…'**
  String get diaryBackgroundHint;

  /// No description provided for @diaryMarkdownHint.
  ///
  /// In es, this message translates to:
  /// **'Acepta Markdown: # para títulos, **negrita**, *itálica* y - para viñetas.'**
  String get diaryMarkdownHint;

  /// No description provided for @diaryUnknownOrigin.
  ///
  /// In es, this message translates to:
  /// **'Origen desconocido'**
  String get diaryUnknownOrigin;

  /// No description provided for @diaryUnknownOriginBody.
  ///
  /// In es, this message translates to:
  /// **'Todavía nadie escribió de dónde viene {name}. Podés escribirlo acá, o traer un .md que ya tengas afuera.'**
  String diaryUnknownOriginBody(String name);

  /// No description provided for @diaryWriteBackground.
  ///
  /// In es, this message translates to:
  /// **'Escribir el trasfondo'**
  String get diaryWriteBackground;

  /// No description provided for @diaryImportMdShort.
  ///
  /// In es, this message translates to:
  /// **'Importar .md'**
  String get diaryImportMdShort;

  /// No description provided for @diaryPickMd.
  ///
  /// In es, this message translates to:
  /// **'Elegir un archivo .md'**
  String get diaryPickMd;

  /// No description provided for @diaryOpenError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el archivo'**
  String get diaryOpenError;

  /// No description provided for @diaryReplaceTitle.
  ///
  /// In es, this message translates to:
  /// **'Reemplazar el trasfondo'**
  String get diaryReplaceTitle;

  /// No description provided for @diaryReplaceBody.
  ///
  /// In es, this message translates to:
  /// **'Lo que hay escrito se pierde y queda en su lugar el contenido del archivo. No hay forma de recuperarlo.'**
  String get diaryReplaceBody;

  /// No description provided for @diaryReplace.
  ///
  /// In es, this message translates to:
  /// **'Reemplazar'**
  String get diaryReplace;

  /// No description provided for @diaryNotUtf8.
  ///
  /// In es, this message translates to:
  /// **'El archivo no parece texto en UTF-8.'**
  String get diaryNotUtf8;

  /// No description provided for @diaryImported.
  ///
  /// In es, this message translates to:
  /// **'Trasfondo importado.'**
  String get diaryImported;

  /// No description provided for @diaryFileSuffix.
  ///
  /// In es, this message translates to:
  /// **'trasfondo'**
  String get diaryFileSuffix;

  /// No description provided for @diaryFileFallback.
  ///
  /// In es, this message translates to:
  /// **'personaje'**
  String get diaryFileFallback;

  /// No description provided for @diaryEntries.
  ///
  /// In es, this message translates to:
  /// **'Entradas'**
  String get diaryEntries;

  /// No description provided for @diaryAddEntryTooltip.
  ///
  /// In es, this message translates to:
  /// **'Agregar una entrada'**
  String get diaryAddEntryTooltip;

  /// No description provided for @diaryEmpty.
  ///
  /// In es, this message translates to:
  /// **'El diario de {name} todavía está en blanco.\nSumá arte, una historia corta, una manía — lo que te guste de este personaje.'**
  String diaryEmpty(String name);

  /// No description provided for @diaryAddEntry.
  ///
  /// In es, this message translates to:
  /// **'Agregar entrada'**
  String get diaryAddEntry;

  /// No description provided for @diaryDeleted.
  ///
  /// In es, this message translates to:
  /// **'Borraste «{title}».'**
  String diaryDeleted(String title);

  /// No description provided for @diaryDeleteBody.
  ///
  /// In es, this message translates to:
  /// **'«{title}» se va del diario.'**
  String diaryDeleteBody(String title);

  /// No description provided for @diaryDeleteBodyImage.
  ///
  /// In es, this message translates to:
  /// **'«{title}» se va del diario, y la imagen que subiste se borra con ella. No hay forma de recuperarla.'**
  String diaryDeleteBodyImage(String title);

  /// No description provided for @diaryUntitled.
  ///
  /// In es, this message translates to:
  /// **'Sin título'**
  String get diaryUntitled;

  /// No description provided for @diaryDragHint.
  ///
  /// In es, this message translates to:
  /// **'Mantené apretado para reordenar'**
  String get diaryDragHint;

  /// No description provided for @diaryNoImage.
  ///
  /// In es, this message translates to:
  /// **'Sin imagen.'**
  String get diaryNoImage;

  /// No description provided for @diaryKindText.
  ///
  /// In es, this message translates to:
  /// **'Texto'**
  String get diaryKindText;

  /// No description provided for @diaryKindImage.
  ///
  /// In es, this message translates to:
  /// **'Imagen'**
  String get diaryKindImage;

  /// No description provided for @diaryKindLink.
  ///
  /// In es, this message translates to:
  /// **'Enlace'**
  String get diaryKindLink;

  /// No description provided for @diaryEditedOn.
  ///
  /// In es, this message translates to:
  /// **'{date} · editada {edited}'**
  String diaryEditedOn(String date, String edited);

  /// No description provided for @diaryEntryNoImage.
  ///
  /// In es, this message translates to:
  /// **'Esta entrada no tiene imagen.'**
  String get diaryEntryNoImage;

  /// No description provided for @diarySeeFullImage.
  ///
  /// In es, this message translates to:
  /// **'Ver la imagen completa'**
  String get diarySeeFullImage;

  /// No description provided for @diaryImageGone.
  ///
  /// In es, this message translates to:
  /// **'La imagen ya no está en el almacén.'**
  String get diaryImageGone;

  /// No description provided for @diaryDeleteTitle.
  ///
  /// In es, this message translates to:
  /// **'Borrar la entrada'**
  String get diaryDeleteTitle;

  /// No description provided for @diaryPickImage.
  ///
  /// In es, this message translates to:
  /// **'Elegir una imagen'**
  String get diaryPickImage;

  /// No description provided for @diaryUploadError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo subir la imagen'**
  String get diaryUploadError;

  /// No description provided for @diaryNewEntry.
  ///
  /// In es, this message translates to:
  /// **'Nueva entrada'**
  String get diaryNewEntry;

  /// No description provided for @diaryEditEntry.
  ///
  /// In es, this message translates to:
  /// **'Editar entrada'**
  String get diaryEditEntry;

  /// No description provided for @diaryTitleLabel.
  ///
  /// In es, this message translates to:
  /// **'Título'**
  String get diaryTitleLabel;

  /// No description provided for @diaryEntryType.
  ///
  /// In es, this message translates to:
  /// **'Tipo de entrada'**
  String get diaryEntryType;

  /// No description provided for @diaryBodyHint.
  ///
  /// In es, this message translates to:
  /// **'Lo que quieras contar de este personaje…'**
  String get diaryBodyHint;

  /// No description provided for @diaryUploading.
  ///
  /// In es, this message translates to:
  /// **'Subiendo la imagen…'**
  String get diaryUploading;

  /// No description provided for @diaryChooseImage.
  ///
  /// In es, this message translates to:
  /// **'Elegir imagen'**
  String get diaryChooseImage;

  /// No description provided for @diaryChangeImage.
  ///
  /// In es, this message translates to:
  /// **'Cambiar imagen'**
  String get diaryChangeImage;

  /// No description provided for @diaryImageFormats.
  ///
  /// In es, this message translates to:
  /// **'PNG, JPEG o WEBP. Mismo límite de tamaño que los retratos.'**
  String get diaryImageFormats;

  /// No description provided for @spellsTitle.
  ///
  /// In es, this message translates to:
  /// **'Conjuros'**
  String get spellsTitle;

  /// No description provided for @spellsPrepare.
  ///
  /// In es, this message translates to:
  /// **'Preparar'**
  String get spellsPrepare;

  /// No description provided for @spellsSaveDcShort.
  ///
  /// In es, this message translates to:
  /// **'CD SALV.'**
  String get spellsSaveDcShort;

  /// No description provided for @spellsSaveDcSemantics.
  ///
  /// In es, this message translates to:
  /// **'Clase de dificultad de las salvaciones contra tus conjuros: {dc}'**
  String spellsSaveDcSemantics(Object dc);

  /// No description provided for @spellsAttackUpper.
  ///
  /// In es, this message translates to:
  /// **'ATAQUE'**
  String get spellsAttackUpper;

  /// No description provided for @spellsAbilityUpper.
  ///
  /// In es, this message translates to:
  /// **'APTITUD'**
  String get spellsAbilityUpper;

  /// No description provided for @spellsAbilitySemantics.
  ///
  /// In es, this message translates to:
  /// **'Aptitud mágica: {name}'**
  String spellsAbilitySemantics(String name);

  /// No description provided for @spellsPrepared.
  ///
  /// In es, this message translates to:
  /// **'Preparados: {count} / {max}'**
  String spellsPrepared(Object count, Object max);

  /// No description provided for @spellsKnown.
  ///
  /// In es, this message translates to:
  /// **'Conocidos: {count}'**
  String spellsKnown(Object count);

  /// No description provided for @spellsCantrips.
  ///
  /// In es, this message translates to:
  /// **'Trucos: {count} / {max}'**
  String spellsCantrips(Object count, Object max);

  /// No description provided for @spellsSources.
  ///
  /// In es, this message translates to:
  /// **'Fuentes de lanzamiento'**
  String get spellsSources;

  /// No description provided for @spellsSourcePrepared.
  ///
  /// In es, this message translates to:
  /// **'{level}° nivel · {ability} · preparados'**
  String spellsSourcePrepared(Object level, String ability);

  /// No description provided for @spellsSourceKnown.
  ///
  /// In es, this message translates to:
  /// **'{level}° nivel · {ability} · conocidos'**
  String spellsSourceKnown(Object level, String ability);

  /// No description provided for @spellsFromFeatures.
  ///
  /// In es, this message translates to:
  /// **'Conjuros de rasgos'**
  String get spellsFromFeatures;

  /// No description provided for @spellsWildShapeBlock.
  ///
  /// In es, this message translates to:
  /// **'En forma de {name} no podés lanzar conjuros.'**
  String spellsWildShapeBlock(String name);

  /// No description provided for @spellsConcentratingOn.
  ///
  /// In es, this message translates to:
  /// **'Concentrándote en {spell}'**
  String spellsConcentratingOn(String spell);

  /// No description provided for @spellsEndConcentration.
  ///
  /// In es, this message translates to:
  /// **'Terminar'**
  String get spellsEndConcentration;

  /// No description provided for @spellsSlots.
  ///
  /// In es, this message translates to:
  /// **'Espacios de conjuro'**
  String get spellsSlots;

  /// No description provided for @spellsPactSlots.
  ///
  /// In es, this message translates to:
  /// **'Espacios de Pacto'**
  String get spellsPactSlots;

  /// No description provided for @spellsCantripsTitle.
  ///
  /// In es, this message translates to:
  /// **'Trucos'**
  String get spellsCantripsTitle;

  /// No description provided for @spellsAlwaysPrepared.
  ///
  /// In es, this message translates to:
  /// **'Siempre preparados'**
  String get spellsAlwaysPrepared;

  /// No description provided for @spellsAlwaysPreparedHint.
  ///
  /// In es, this message translates to:
  /// **'Los concede un rasgo y no ocupan cupo: se lanzan con tus espacios de conjuro como cualquier preparado.'**
  String get spellsAlwaysPreparedHint;

  /// No description provided for @spellsPreparedTitle.
  ///
  /// In es, this message translates to:
  /// **'Conjuros preparados'**
  String get spellsPreparedTitle;

  /// No description provided for @spellsKnownTitle.
  ///
  /// In es, this message translates to:
  /// **'Conjuros conocidos'**
  String get spellsKnownTitle;

  /// No description provided for @spellsNoneChosen.
  ///
  /// In es, this message translates to:
  /// **'Todavía no elegiste conjuros. Editá al subir de nivel o al crear.'**
  String get spellsNoneChosen;

  /// No description provided for @spellsUseLongRest.
  ///
  /// In es, this message translates to:
  /// **'1/descanso largo'**
  String get spellsUseLongRest;

  /// No description provided for @spellsUseShortRest.
  ///
  /// In es, this message translates to:
  /// **'1/descanso corto'**
  String get spellsUseShortRest;

  /// No description provided for @spellsUseProficiency.
  ///
  /// In es, this message translates to:
  /// **'Competencia/descanso largo'**
  String get spellsUseProficiency;

  /// No description provided for @spellsUseAbilityMod.
  ///
  /// In es, this message translates to:
  /// **'{uses}/descanso largo ({ability})'**
  String spellsUseAbilityMod(Object uses, String ability);

  /// No description provided for @spellsSwapTooltip.
  ///
  /// In es, this message translates to:
  /// **'Cambiar tras un descanso largo'**
  String get spellsSwapTooltip;

  /// No description provided for @spellsConcentrate.
  ///
  /// In es, this message translates to:
  /// **'Concentrar'**
  String get spellsConcentrate;

  /// No description provided for @spellsCutTitle.
  ///
  /// In es, this message translates to:
  /// **'Cortar la concentración'**
  String get spellsCutTitle;

  /// No description provided for @spellsCutBody.
  ///
  /// In es, this message translates to:
  /// **'Concentrarte en {spell} termina {previous}, y con ella {count, plural, =1{se va} other{se van}} {names}.'**
  String spellsCutBody(String spell, String previous, int count, String names);

  /// No description provided for @spellsCurrentConcentration.
  ///
  /// In es, this message translates to:
  /// **'tu concentración actual'**
  String get spellsCurrentConcentration;

  /// No description provided for @spellsConcentrateAnyway.
  ///
  /// In es, this message translates to:
  /// **'Concentrar igual'**
  String get spellsConcentrateAnyway;

  /// No description provided for @spellsSwitched.
  ///
  /// In es, this message translates to:
  /// **'Te concentrás en {spell}: dejaste {previous}.'**
  String spellsSwitched(String spell, String previous);

  /// No description provided for @spellsSwitchedDeps.
  ///
  /// In es, this message translates to:
  /// **'Te concentrás en {spell}: dejaste {previous} y {count, plural, =1{se va} other{se van}} {names}.'**
  String spellsSwitchedDeps(
    String spell,
    String previous,
    int count,
    String names,
  );

  /// No description provided for @spellsSwapTitle.
  ///
  /// In es, this message translates to:
  /// **'Cambiar {name}'**
  String spellsSwapTitle(String name);

  /// No description provided for @spellsSwapBody.
  ///
  /// In es, this message translates to:
  /// **'Al terminar un descanso largo podés cambiarlo por otro truco de {lists}.'**
  String spellsSwapBody(String lists);

  /// No description provided for @spellsSwapOriginal.
  ///
  /// In es, this message translates to:
  /// **'El del rasgo'**
  String get spellsSwapOriginal;

  /// No description provided for @spellsListOf.
  ///
  /// In es, this message translates to:
  /// **'la lista de {name}'**
  String spellsListOf(String name);

  /// No description provided for @listOr.
  ///
  /// In es, this message translates to:
  /// **'{head} o {last}'**
  String listOr(String head, String last);

  /// No description provided for @spellsSpendSlot.
  ///
  /// In es, this message translates to:
  /// **'Gastar espacio'**
  String get spellsSpendSlot;

  /// No description provided for @spellsRecoverSlot.
  ///
  /// In es, this message translates to:
  /// **'Recuperar espacio'**
  String get spellsRecoverSlot;

  /// No description provided for @spellsWithCharacter.
  ///
  /// In es, this message translates to:
  /// **'Con este personaje'**
  String get spellsWithCharacter;

  /// No description provided for @spellsCastWith.
  ///
  /// In es, this message translates to:
  /// **'Lanzás con {ability} ({mod}). Ataque de conjuro {attack} · CD de salvación {dc}.'**
  String spellsCastWith(String ability, String mod, String attack, Object dc);

  /// No description provided for @spellsDamageBonus.
  ///
  /// In es, this message translates to:
  /// **'{bonus} al daño ({sources})'**
  String spellsDamageBonus(String bonus, String sources);

  /// No description provided for @stepSpecies.
  ///
  /// In es, this message translates to:
  /// **'Especie'**
  String get stepSpecies;

  /// No description provided for @stepClass.
  ///
  /// In es, this message translates to:
  /// **'Clase'**
  String get stepClass;

  /// No description provided for @stepBackground.
  ///
  /// In es, this message translates to:
  /// **'Trasfondo'**
  String get stepBackground;

  /// No description provided for @stepScores.
  ///
  /// In es, this message translates to:
  /// **'Puntuaciones'**
  String get stepScores;

  /// No description provided for @stepProficiencies.
  ///
  /// In es, this message translates to:
  /// **'Competencias'**
  String get stepProficiencies;

  /// No description provided for @stepEquipment.
  ///
  /// In es, this message translates to:
  /// **'Equipo'**
  String get stepEquipment;

  /// No description provided for @stepDetails.
  ///
  /// In es, this message translates to:
  /// **'Detalles'**
  String get stepDetails;

  /// No description provided for @stepSummary.
  ///
  /// In es, this message translates to:
  /// **'Resumen'**
  String get stepSummary;

  /// No description provided for @pendingPickSpecies.
  ///
  /// In es, this message translates to:
  /// **'Elegí una especie.'**
  String get pendingPickSpecies;

  /// No description provided for @pendingPickLineage.
  ///
  /// In es, this message translates to:
  /// **'Elegí un linaje de especie.'**
  String get pendingPickLineage;

  /// No description provided for @pendingPickLineageAbility.
  ///
  /// In es, this message translates to:
  /// **'Elegí la aptitud mágica del linaje.'**
  String get pendingPickLineageAbility;

  /// No description provided for @pendingPickSize.
  ///
  /// In es, this message translates to:
  /// **'Elegí el tamaño de la especie.'**
  String get pendingPickSize;

  /// No description provided for @pendingPickClass.
  ///
  /// In es, this message translates to:
  /// **'Elegí una clase.'**
  String get pendingPickClass;

  /// No description provided for @pendingSlotProgress.
  ///
  /// In es, this message translates to:
  /// **'{name}: {chosen}/{total}.'**
  String pendingSlotProgress(String name, Object chosen, Object total);

  /// No description provided for @pendingWeaponMastery.
  ///
  /// In es, this message translates to:
  /// **'Maestría de armas: {chosen}/{total}.'**
  String pendingWeaponMastery(Object chosen, Object total);

  /// No description provided for @pendingPickBackground.
  ///
  /// In es, this message translates to:
  /// **'Elegí un trasfondo.'**
  String get pendingPickBackground;

  /// No description provided for @pendingPickFeatAbility.
  ///
  /// In es, this message translates to:
  /// **'Elegí la aptitud mágica de {name}.'**
  String pendingPickFeatAbility(String name);

  /// No description provided for @pendingSpread.
  ///
  /// In es, this message translates to:
  /// **'Asigná el +2 y el +1 de característica.'**
  String get pendingSpread;

  /// No description provided for @pendingAssignScores.
  ///
  /// In es, this message translates to:
  /// **'Asigná las 6 características ({count}/6).'**
  String pendingAssignScores(Object count);

  /// No description provided for @pendingClassSkills.
  ///
  /// In es, this message translates to:
  /// **'Habilidades de clase: {chosen}/{total}.'**
  String pendingClassSkills(Object chosen, Object total);

  /// No description provided for @pendingSpeciesSkills.
  ///
  /// In es, this message translates to:
  /// **'Habilidades de especie: {chosen}/{total}.'**
  String pendingSpeciesSkills(Object chosen, Object total);

  /// No description provided for @pendingPickOriginFeat.
  ///
  /// In es, this message translates to:
  /// **'Elegí una dote de origen.'**
  String get pendingPickOriginFeat;

  /// No description provided for @pendingProficiencies.
  ///
  /// In es, this message translates to:
  /// **'Competencias pendientes: {count}.'**
  String pendingProficiencies(Object count);

  /// No description provided for @pendingExpertise.
  ///
  /// In es, this message translates to:
  /// **'Pericias pendientes: {count}.'**
  String pendingExpertise(Object count);

  /// No description provided for @pendingLanguages.
  ///
  /// In es, this message translates to:
  /// **'Idiomas: {chosen}/{total}.'**
  String pendingLanguages(Object chosen, Object total);

  /// No description provided for @pendingLanguageChoices.
  ///
  /// In es, this message translates to:
  /// **'Idiomas por rasgo pendientes: {count}.'**
  String pendingLanguageChoices(Object count);

  /// No description provided for @pendingClassEquipment.
  ///
  /// In es, this message translates to:
  /// **'Elegí el equipo de clase.'**
  String get pendingClassEquipment;

  /// No description provided for @pendingBackgroundEquipment.
  ///
  /// In es, this message translates to:
  /// **'Elegí el equipo de trasfondo.'**
  String get pendingBackgroundEquipment;

  /// No description provided for @pendingEquipmentChoices.
  ///
  /// In es, this message translates to:
  /// **'Completá las elecciones internas de equipo.'**
  String get pendingEquipmentChoices;

  /// No description provided for @pendingOverspent.
  ///
  /// In es, this message translates to:
  /// **'Las compras superan el oro de partida por {amount}.'**
  String pendingOverspent(String amount);

  /// No description provided for @pendingSpellChoices.
  ///
  /// In es, this message translates to:
  /// **'Conjuros a elección: {count}.'**
  String pendingSpellChoices(Object count);

  /// No description provided for @pendingCantrips.
  ///
  /// In es, this message translates to:
  /// **'Trucos: {chosen}/{total}.'**
  String pendingCantrips(Object chosen, Object total);

  /// No description provided for @pendingSpells.
  ///
  /// In es, this message translates to:
  /// **'Conjuros: {chosen}/{total}.'**
  String pendingSpells(Object chosen, Object total);

  /// No description provided for @characterUnnamed.
  ///
  /// In es, this message translates to:
  /// **'Sin nombre'**
  String get characterUnnamed;

  /// No description provided for @wizardCreateNpc.
  ///
  /// In es, this message translates to:
  /// **'Crear PNJ'**
  String get wizardCreateNpc;

  /// No description provided for @wizardDiscardNpc.
  ///
  /// In es, this message translates to:
  /// **'¿Descartar este PNJ?'**
  String get wizardDiscardNpc;

  /// No description provided for @wizardDiscardCharacter.
  ///
  /// In es, this message translates to:
  /// **'¿Descartar este personaje?'**
  String get wizardDiscardCharacter;

  /// No description provided for @wizardDiscardBody.
  ///
  /// In es, this message translates to:
  /// **'Las elecciones realizadas en el asistente se perderán.'**
  String get wizardDiscardBody;

  /// No description provided for @wizardKeepCreating.
  ///
  /// In es, this message translates to:
  /// **'Seguir creando'**
  String get wizardKeepCreating;

  /// No description provided for @wizardDiscard.
  ///
  /// In es, this message translates to:
  /// **'Descartar'**
  String get wizardDiscard;

  /// No description provided for @wizardProgress.
  ///
  /// In es, this message translates to:
  /// **'Progreso'**
  String get wizardProgress;

  /// No description provided for @wizardStepOf.
  ///
  /// In es, this message translates to:
  /// **'Paso {step} de {total}'**
  String wizardStepOf(Object step, Object total);

  /// No description provided for @wizardStepSemantics.
  ///
  /// In es, this message translates to:
  /// **'{name}, paso {step} de {total}'**
  String wizardStepSemantics(String name, Object step, Object total);

  /// No description provided for @wizardFinishPrevious.
  ///
  /// In es, this message translates to:
  /// **'Completá los pasos anteriores'**
  String get wizardFinishPrevious;

  /// No description provided for @wizardProgressSemantics.
  ///
  /// In es, this message translates to:
  /// **'Progreso de creación'**
  String get wizardProgressSemantics;

  /// No description provided for @wizardBack.
  ///
  /// In es, this message translates to:
  /// **'Atrás'**
  String get wizardBack;

  /// No description provided for @wizardMissing.
  ///
  /// In es, this message translates to:
  /// **'Falta: {item}'**
  String wizardMissing(String item);

  /// No description provided for @wizardMissingMore.
  ///
  /// In es, this message translates to:
  /// **'Falta: {first} (y {count} {count, plural, =1{cosa} other{cosas}} más).'**
  String wizardMissingMore(String first, int count);

  /// No description provided for @wizardNext.
  ///
  /// In es, this message translates to:
  /// **'Siguiente'**
  String get wizardNext;

  /// No description provided for @detailsEmblem.
  ///
  /// In es, this message translates to:
  /// **'Emblema'**
  String get detailsEmblem;

  /// No description provided for @detailsEmblemBody.
  ///
  /// In es, this message translates to:
  /// **'Hasta que le pongas un retrato, tu personaje usa el emblema de {klass}.'**
  String detailsEmblemBody(String klass);

  /// No description provided for @detailsYourClass.
  ///
  /// In es, this message translates to:
  /// **'su clase'**
  String get detailsYourClass;

  /// No description provided for @detailsPortraitLater.
  ///
  /// In es, this message translates to:
  /// **'Podés generar o elegir un retrato después, desde la ficha.'**
  String get detailsPortraitLater;

  /// No description provided for @detailsName.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get detailsName;

  /// No description provided for @detailsUndefined.
  ///
  /// In es, this message translates to:
  /// **'Sin definir'**
  String get detailsUndefined;

  /// No description provided for @detailsTrait.
  ///
  /// In es, this message translates to:
  /// **'Rasgo de personalidad'**
  String get detailsTrait;

  /// No description provided for @detailsTraitHint.
  ///
  /// In es, this message translates to:
  /// **'Una línea que lo defina. Ej: \"Nunca deja una deuda sin pagar.\"'**
  String get detailsTraitHint;

  /// No description provided for @weaponSimple.
  ///
  /// In es, this message translates to:
  /// **'Simples'**
  String get weaponSimple;

  /// No description provided for @weaponMartial.
  ///
  /// In es, this message translates to:
  /// **'Marciales'**
  String get weaponMartial;

  /// No description provided for @weaponUnarmed.
  ///
  /// In es, this message translates to:
  /// **'Sin arma (puños)'**
  String get weaponUnarmed;

  /// No description provided for @weaponSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar arma…'**
  String get weaponSearchHint;

  /// No description provided for @summaryEquipped.
  ///
  /// In es, this message translates to:
  /// **'puesto'**
  String get summaryEquipped;

  /// No description provided for @summaryTitle.
  ///
  /// In es, this message translates to:
  /// **'Revisá y confirmá'**
  String get summaryTitle;

  /// No description provided for @summaryLine.
  ///
  /// In es, this message translates to:
  /// **'{species} · {klass} · {background} · Nivel 1'**
  String summaryLine(String species, String klass, String background);

  /// No description provided for @summaryInCombat.
  ///
  /// In es, this message translates to:
  /// **'En combate'**
  String get summaryInCombat;

  /// No description provided for @summaryFeats.
  ///
  /// In es, this message translates to:
  /// **'Dotes'**
  String get summaryFeats;

  /// No description provided for @identityCreatureTypeShort.
  ///
  /// In es, this message translates to:
  /// **'Tipo'**
  String get identityCreatureTypeShort;

  /// No description provided for @pickSpeciesHint.
  ///
  /// In es, this message translates to:
  /// **'Elegí una especie para ver su detalle.'**
  String get pickSpeciesHint;

  /// No description provided for @factToChoose.
  ///
  /// In es, this message translates to:
  /// **'a elegir'**
  String get factToChoose;

  /// No description provided for @feetValue.
  ///
  /// In es, this message translates to:
  /// **'{feet} pies'**
  String feetValue(Object feet);

  /// No description provided for @factChoose.
  ///
  /// In es, this message translates to:
  /// **'{count} a elegir'**
  String factChoose(Object count);

  /// No description provided for @raceLineageTitle.
  ///
  /// In es, this message translates to:
  /// **'Linaje de especie'**
  String get raceLineageTitle;

  /// No description provided for @raceLineageRequired.
  ///
  /// In es, this message translates to:
  /// **'Esta especie requiere elegir un linaje.'**
  String get raceLineageRequired;

  /// No description provided for @raceLineageLevel1.
  ///
  /// In es, this message translates to:
  /// **'Lo que te da a nivel 1'**
  String get raceLineageLevel1;

  /// No description provided for @speciesSpellAbility.
  ///
  /// In es, this message translates to:
  /// **'Aptitud mágica'**
  String get speciesSpellAbility;

  /// No description provided for @pickClassHint.
  ///
  /// In es, this message translates to:
  /// **'Elegí una clase para ver su detalle.'**
  String get pickClassHint;

  /// No description provided for @factHitDie.
  ///
  /// In es, this message translates to:
  /// **'Dado de golpe'**
  String get factHitDie;

  /// No description provided for @classChooseCount.
  ///
  /// In es, this message translates to:
  /// **'{name} (elegí {count})'**
  String classChooseCount(String name, Object count);

  /// No description provided for @classWeaponMasteryTitle.
  ///
  /// In es, this message translates to:
  /// **'Maestría de armas (elegí {count})'**
  String classWeaponMasteryTitle(Object count);

  /// No description provided for @classWeaponMasteryBody.
  ///
  /// In es, this message translates to:
  /// **'Dominás el arma lo suficiente como para sacarle un efecto extra cada vez que acertás —derribar, entorpecer, rozar—, sin gastar nada. Solo armas con las que {klass} es competente.'**
  String classWeaponMasteryBody(String klass);

  /// No description provided for @pickBackgroundHint.
  ///
  /// In es, this message translates to:
  /// **'Elegí un trasfondo para ver su detalle.'**
  String get pickBackgroundHint;

  /// No description provided for @factOriginFeat.
  ///
  /// In es, this message translates to:
  /// **'Dote de origen'**
  String get factOriginFeat;

  /// No description provided for @bgOriginFeatGives.
  ///
  /// In es, this message translates to:
  /// **'Qué te da su dote de origen'**
  String get bgOriginFeatGives;

  /// No description provided for @bgFeatAbilityHint.
  ///
  /// In es, this message translates to:
  /// **'Se usa para la CD y los ataques de los conjuros de la dote.'**
  String get bgFeatAbilityHint;

  /// No description provided for @bgAbilityIncrease.
  ///
  /// In es, this message translates to:
  /// **'Aumento de característica'**
  String get bgAbilityIncrease;

  /// No description provided for @bgEachPlusOne.
  ///
  /// In es, this message translates to:
  /// **'Cada una de {list} recibe +1.'**
  String bgEachPlusOne(String list);

  /// No description provided for @aptHelpTitle.
  ///
  /// In es, this message translates to:
  /// **'Qué es una competencia'**
  String get aptHelpTitle;

  /// No description provided for @aptHelpBody.
  ///
  /// In es, this message translates to:
  /// **'Ser competente en algo te deja sumar tu bonificador por competencia cuando tirás con eso: una habilidad, un arma, una herramienta o una salvación. Acá elegís las tuyas entre las que ofrecen tu clase, tu especie y tu trasfondo; las que ya vienen dadas aparecen bloqueadas.'**
  String get aptHelpBody;

  /// No description provided for @aptClassSkills.
  ///
  /// In es, this message translates to:
  /// **'Habilidades de clase'**
  String get aptClassSkills;

  /// No description provided for @aptSpeciesSkills.
  ///
  /// In es, this message translates to:
  /// **'Habilidades de especie'**
  String get aptSpeciesSkills;

  /// No description provided for @aptGrantedByBackground.
  ///
  /// In es, this message translates to:
  /// **'Estas ya te las da el trasfondo:'**
  String get aptGrantedByBackground;

  /// No description provided for @creationChosen.
  ///
  /// In es, this message translates to:
  /// **'{count} / {total} elegidas'**
  String creationChosen(Object count, Object total);

  /// No description provided for @creationChosenM.
  ///
  /// In es, this message translates to:
  /// **'{count} / {total} elegidos'**
  String creationChosenM(Object count, Object total);

  /// No description provided for @creationNotChosen.
  ///
  /// In es, this message translates to:
  /// **'sin elegir'**
  String get creationNotChosen;

  /// No description provided for @creationOneChosen.
  ///
  /// In es, this message translates to:
  /// **'1 elegida'**
  String get creationOneChosen;

  /// No description provided for @aptOriginFeatNote.
  ///
  /// In es, this message translates to:
  /// **'En 2024 las dotes de nivel 1 vienen del origen: {species} te concede una a elección.'**
  String aptOriginFeatNote(String species);

  /// No description provided for @aptProfChoices.
  ///
  /// In es, this message translates to:
  /// **'Competencias a elección'**
  String get aptProfChoices;

  /// No description provided for @aptFeatChoose.
  ///
  /// In es, this message translates to:
  /// **'{name}: elegí {count}'**
  String aptFeatChoose(String name, Object count);

  /// No description provided for @aptExpertise.
  ///
  /// In es, this message translates to:
  /// **'Pericia'**
  String get aptExpertise;

  /// No description provided for @aptExpertiseHint.
  ///
  /// In es, this message translates to:
  /// **'Duplica tu bonificador por competencia en la habilidad elegida.'**
  String get aptExpertiseHint;

  /// No description provided for @scoresMethod.
  ///
  /// In es, this message translates to:
  /// **'Método'**
  String get scoresMethod;

  /// No description provided for @scoresHelpTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Qué método conviene?'**
  String get scoresHelpTitle;

  /// No description provided for @scoresHelpBody.
  ///
  /// In es, this message translates to:
  /// **'Los cuatro generan las seis puntuaciones del personaje, con distinto grado de azar. El conjunto estándar reparte valores fijos y equilibrados: es el camino corto. Tirar 4d6 los sortea. El coste en puntos te deja armarlos con un presupuesto. Escribir a mano sirve si ya los tenés decididos.'**
  String get scoresHelpBody;

  /// No description provided for @scoresStandardArray.
  ///
  /// In es, this message translates to:
  /// **'Conjunto estándar'**
  String get scoresStandardArray;

  /// No description provided for @scoresRoll4d6.
  ///
  /// In es, this message translates to:
  /// **'Tirar 4d6'**
  String get scoresRoll4d6;

  /// No description provided for @scoresPointBuy.
  ///
  /// In es, this message translates to:
  /// **'Coste en puntos'**
  String get scoresPointBuy;

  /// No description provided for @scoresManual.
  ///
  /// In es, this message translates to:
  /// **'Escribir a mano'**
  String get scoresManual;

  /// No description provided for @scoresManualHelp.
  ///
  /// In es, this message translates to:
  /// **'Escribí la puntuación base de cada característica ({min} a {max}), sin contar el aumento del trasfondo. Si alguna queda fuera del rango habitual de generación (3 a 18) la ficha lo va a señalar como aviso, pero no te impide seguir.'**
  String scoresManualHelp(Object min, Object max);

  /// No description provided for @scoresSuggested.
  ///
  /// In es, this message translates to:
  /// **'Reparto sugerido para {klass}'**
  String scoresSuggested(String klass);

  /// No description provided for @scoresUseSuggested.
  ///
  /// In es, this message translates to:
  /// **'Usar este reparto'**
  String get scoresUseSuggested;

  /// No description provided for @scoresUnassigned.
  ///
  /// In es, this message translates to:
  /// **'Valores sin asignar'**
  String get scoresUnassigned;

  /// No description provided for @scoresNoneLeft.
  ///
  /// In es, this message translates to:
  /// **'Ninguno: ya están las 6.'**
  String get scoresNoneLeft;

  /// No description provided for @scoresRollAgain.
  ///
  /// In es, this message translates to:
  /// **'Tirar de nuevo'**
  String get scoresRollAgain;

  /// No description provided for @scoresClear.
  ///
  /// In es, this message translates to:
  /// **'Limpiar'**
  String get scoresClear;

  /// No description provided for @scoresPointsLeft.
  ///
  /// In es, this message translates to:
  /// **'Puntos restantes'**
  String get scoresPointsLeft;

  /// No description provided for @scoresOfBudget.
  ///
  /// In es, this message translates to:
  /// **'{left} de {budget}'**
  String scoresOfBudget(Object left, Object budget);

  /// No description provided for @scoresBudgetDone.
  ///
  /// In es, this message translates to:
  /// **'Presupuesto completo.'**
  String get scoresBudgetDone;

  /// No description provided for @scoresOneUnspent.
  ///
  /// In es, this message translates to:
  /// **'Te queda 1 punto sin gastar: si seguís, se pierde.'**
  String get scoresOneUnspent;

  /// No description provided for @scoresUnspent.
  ///
  /// In es, this message translates to:
  /// **'Te quedan {count} puntos sin gastar: si seguís, se pierden.'**
  String scoresUnspent(Object count);

  /// No description provided for @scoresAllStartAt.
  ///
  /// In es, this message translates to:
  /// **'Todas empiezan en {min}: subí las que más te importan con «+».'**
  String scoresAllStartAt(Object min);

  /// No description provided for @scoresCostNote.
  ///
  /// In es, this message translates to:
  /// **'Cada característica va de {min} a {max}. Los últimos dos escalones cuestan el doble: 14 vale 7 puntos y 15 vale 9, no 6 y 7.'**
  String scoresCostNote(Object min, Object max);

  /// No description provided for @scoresLower.
  ///
  /// In es, this message translates to:
  /// **'Bajar {ability}'**
  String scoresLower(String ability);

  /// No description provided for @scoresRaise.
  ///
  /// In es, this message translates to:
  /// **'Subir {ability}'**
  String scoresRaise(String ability);

  /// No description provided for @scoresAtMax.
  ///
  /// In es, this message translates to:
  /// **'al máximo · gastados {spent}'**
  String scoresAtMax(Object spent);

  /// No description provided for @scoresNextCost.
  ///
  /// In es, this message translates to:
  /// **'subir cuesta {cost} · gastados {spent}'**
  String scoresNextCost(Object cost, Object spent);

  /// No description provided for @scoresUnassignedShort.
  ///
  /// In es, this message translates to:
  /// **'sin asignar'**
  String get scoresUnassignedShort;

  /// No description provided for @scoresBase.
  ///
  /// In es, this message translates to:
  /// **'base {score}'**
  String scoresBase(Object score);

  /// No description provided for @scoresPickValue.
  ///
  /// In es, this message translates to:
  /// **'Elegir valor'**
  String get scoresPickValue;

  /// No description provided for @scoresModEmpty.
  ///
  /// In es, this message translates to:
  /// **'MOD —'**
  String get scoresModEmpty;

  /// No description provided for @scoresMod.
  ///
  /// In es, this message translates to:
  /// **'MOD {value}'**
  String scoresMod(String value);

  /// No description provided for @scoresValue.
  ///
  /// In es, this message translates to:
  /// **'Valor'**
  String get scoresValue;

  /// No description provided for @scoresTaken.
  ///
  /// In es, this message translates to:
  /// **'en {abilities}'**
  String scoresTaken(String abilities);

  /// No description provided for @scoresTakenFree.
  ///
  /// In es, this message translates to:
  /// **'en {abilities} · {free, plural, =1{queda 1} other{quedan {free}}}'**
  String scoresTakenFree(String abilities, int free);

  /// No description provided for @wordOr.
  ///
  /// In es, this message translates to:
  /// **'o'**
  String get wordOr;

  /// No description provided for @equipReceivedTitle.
  ///
  /// In es, this message translates to:
  /// **'Equipo puesto'**
  String get equipReceivedTitle;

  /// No description provided for @equipStartingTitle.
  ///
  /// In es, this message translates to:
  /// **'Equipo inicial'**
  String get equipStartingTitle;

  /// No description provided for @equipPickClassItem.
  ///
  /// In es, this message translates to:
  /// **'Elegí un objeto del equipo de clase'**
  String get equipPickClassItem;

  /// No description provided for @equipPickBackgroundItem.
  ///
  /// In es, this message translates to:
  /// **'Elegí un objeto del equipo de trasfondo'**
  String get equipPickBackgroundItem;

  /// No description provided for @equipNoStartingClass.
  ///
  /// In es, this message translates to:
  /// **'Esta clase no trae equipo inicial.'**
  String get equipNoStartingClass;

  /// No description provided for @equipNoStartingBackground.
  ///
  /// In es, this message translates to:
  /// **'Este trasfondo no trae equipo inicial.'**
  String get equipNoStartingBackground;

  /// No description provided for @equipOptionClass.
  ///
  /// In es, this message translates to:
  /// **'Opción de clase'**
  String get equipOptionClass;

  /// No description provided for @equipOptionBackground.
  ///
  /// In es, this message translates to:
  /// **'Opción de trasfondo'**
  String get equipOptionBackground;

  /// No description provided for @equipOrOther.
  ///
  /// In es, this message translates to:
  /// **'u otro'**
  String get equipOrOther;

  /// No description provided for @equipShopTitle.
  ///
  /// In es, this message translates to:
  /// **'Comprar equipo'**
  String get equipShopTitle;

  /// No description provided for @equipLeftShort.
  ///
  /// In es, this message translates to:
  /// **'Quedan'**
  String get equipLeftShort;

  /// No description provided for @equipShopHint.
  ///
  /// In es, this message translates to:
  /// **'Cada toque suma uno a tus compras. La cantidad se ajusta en la lista del paso.'**
  String get equipShopHint;

  /// No description provided for @equipPurchases.
  ///
  /// In es, this message translates to:
  /// **'Compras'**
  String get equipPurchases;

  /// No description provided for @equipPickFirst.
  ///
  /// In es, this message translates to:
  /// **'Primero elegí las opciones de equipo: el oro para comprar sale de ahí.'**
  String get equipPickFirst;

  /// No description provided for @equipLeft.
  ///
  /// In es, this message translates to:
  /// **'Quedan {amount}'**
  String equipLeft(String amount);

  /// No description provided for @equipNoGold.
  ///
  /// In es, this message translates to:
  /// **'Las opciones elegidas no traen oro para comprar.'**
  String get equipNoGold;

  /// No description provided for @equipGoldExplainer.
  ///
  /// In es, this message translates to:
  /// **'Lo que no traés en el paquete lo comprás con el oro de partida, al precio del manual. Lo que sobre queda en la bolsa.'**
  String get equipGoldExplainer;

  /// No description provided for @equipStartingGold.
  ///
  /// In es, this message translates to:
  /// **'Oro de partida'**
  String get equipStartingGold;

  /// No description provided for @equipInPurchases.
  ///
  /// In es, this message translates to:
  /// **'En compras'**
  String get equipInPurchases;

  /// No description provided for @equipShortLabel.
  ///
  /// In es, this message translates to:
  /// **'Faltan'**
  String get equipShortLabel;

  /// No description provided for @equipYouHaveLeft.
  ///
  /// In es, this message translates to:
  /// **'Te quedan'**
  String get equipYouHaveLeft;

  /// No description provided for @equipOverspent.
  ///
  /// In es, this message translates to:
  /// **'Las compras superan el oro de partida: sacá algo o elegí otra opción de equipo.'**
  String get equipOverspent;

  /// No description provided for @equipBuyItems.
  ///
  /// In es, this message translates to:
  /// **'Comprar objetos'**
  String get equipBuyItems;

  /// No description provided for @equipOneLess.
  ///
  /// In es, this message translates to:
  /// **'Uno menos de {name}'**
  String equipOneLess(String name);

  /// No description provided for @equipOneMore.
  ///
  /// In es, this message translates to:
  /// **'Uno más de {name}'**
  String equipOneMore(String name);

  /// No description provided for @equipRemovePurchase.
  ///
  /// In es, this message translates to:
  /// **'Sacar {name} de las compras'**
  String equipRemovePurchase(String name);

  /// No description provided for @equipTapPiece.
  ///
  /// In es, this message translates to:
  /// **'Tocá una pieza para sacártela o ponértela.'**
  String get equipTapPiece;

  /// No description provided for @equipNothingToWear.
  ///
  /// In es, this message translates to:
  /// **'El paquete elegido no trae equipo para vestir o empuñar.'**
  String get equipNothingToWear;

  /// No description provided for @equipGrip.
  ///
  /// In es, this message translates to:
  /// **'Cómo las empuñás'**
  String get equipGrip;

  /// No description provided for @equipOffHandNote.
  ///
  /// In es, this message translates to:
  /// **'El ataque de mano secundaria es una acción adicional y no suma tu modificador al daño, salvo con el estilo Combate con Dos Armas.'**
  String get equipOffHandNote;

  /// No description provided for @equipOffHandShort.
  ///
  /// In es, this message translates to:
  /// **'Secundaria'**
  String get equipOffHandShort;

  /// No description provided for @equipNoSpellsTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu clase no lanza conjuros'**
  String get equipNoSpellsTitle;

  /// No description provided for @equipNoSpellsBody.
  ///
  /// In es, this message translates to:
  /// **'Confiás en el acero y la maña. Seguí al próximo paso.'**
  String get equipNoSpellsBody;

  /// No description provided for @equipNoPreparedSlot.
  ///
  /// In es, this message translates to:
  /// **'No ocupan cupo de preparados.'**
  String get equipNoPreparedSlot;

  /// No description provided for @equipCantripSuffix.
  ///
  /// In es, this message translates to:
  /// **'{name} (truco)'**
  String equipCantripSuffix(String name);

  /// No description provided for @equipLevelShort.
  ///
  /// In es, this message translates to:
  /// **'{name} (Nv {level})'**
  String equipLevelShort(String name, Object level);

  /// No description provided for @equipCasterLine.
  ///
  /// In es, this message translates to:
  /// **'CD de salvación {dc} · Ataque de conjuro {attack} ({ability})'**
  String equipCasterLine(Object dc, String attack, String ability);

  /// No description provided for @equipMagicTitle.
  ///
  /// In es, this message translates to:
  /// **'Cómo funciona tu magia'**
  String get equipMagicTitle;

  /// No description provided for @equipMagicCantrips.
  ///
  /// In es, this message translates to:
  /// **'Los trucos se lanzan siempre y no gastan nada.'**
  String get equipMagicCantrips;

  /// No description provided for @equipMagicPrepared.
  ///
  /// In es, this message translates to:
  /// **'Los conjuros preparados son los que dejás listos para usar; podés cambiarlos al descansar.'**
  String get equipMagicPrepared;

  /// No description provided for @equipMagicKnown.
  ///
  /// In es, this message translates to:
  /// **'Los conjuros conocidos son los que aprendiste y quedan disponibles para lanzar.'**
  String get equipMagicKnown;

  /// No description provided for @equipMagicSlots.
  ///
  /// In es, this message translates to:
  /// **'Cada vez que lanzás uno gastás un espacio de conjuro, que es un recurso aparte: los espacios dicen cuántas veces podés lanzar, no cuántos conjuros tenés.'**
  String get equipMagicSlots;

  /// No description provided for @equipGrantedCantripOne.
  ///
  /// In es, this message translates to:
  /// **'Ya tenés {name} por otro rasgo: no ocupa un cupo de truco de clase.'**
  String equipGrantedCantripOne(String name);

  /// No description provided for @equipGrantedCantripMany.
  ///
  /// In es, this message translates to:
  /// **'Ya tenés {names} por otros rasgos: no ocupan cupos de truco de clase.'**
  String equipGrantedCantripMany(String names);

  /// No description provided for @equipGrantedLeveled.
  ///
  /// In es, this message translates to:
  /// **'Ya tenés {names} siempre preparado por otro rasgo: no ocupa un cupo.'**
  String equipGrantedLeveled(String names);

  /// No description provided for @equipMaxLevel.
  ///
  /// In es, this message translates to:
  /// **'Podés preparar conjuros de hasta nivel {level}.'**
  String equipMaxLevel(Object level);

  /// No description provided for @wordAnd.
  ///
  /// In es, this message translates to:
  /// **'y'**
  String get wordAnd;

  /// No description provided for @luStepSubclass.
  ///
  /// In es, this message translates to:
  /// **'Subclase'**
  String get luStepSubclass;

  /// No description provided for @luStepAsi.
  ///
  /// In es, this message translates to:
  /// **'Mejora o dote'**
  String get luStepAsi;

  /// No description provided for @luStepChoices.
  ///
  /// In es, this message translates to:
  /// **'Elecciones'**
  String get luStepChoices;

  /// No description provided for @luStepSpellChoices.
  ///
  /// In es, this message translates to:
  /// **'Conjuros a elección'**
  String get luStepSpellChoices;

  /// No description provided for @luStepReview.
  ///
  /// In es, this message translates to:
  /// **'Revisión'**
  String get luStepReview;

  /// No description provided for @luPendingHp.
  ///
  /// In es, this message translates to:
  /// **'Tirá el dado o elegí el promedio para continuar.'**
  String get luPendingHp;

  /// No description provided for @luPendingSubclass.
  ///
  /// In es, this message translates to:
  /// **'Elegí una subclase para continuar.'**
  String get luPendingSubclass;

  /// No description provided for @luPendingImprove.
  ///
  /// In es, this message translates to:
  /// **'Completá la mejora de características.'**
  String get luPendingImprove;

  /// No description provided for @luPendingFeat.
  ///
  /// In es, this message translates to:
  /// **'Elegí una dote para continuar.'**
  String get luPendingFeat;

  /// No description provided for @luPendingFeatAbility.
  ///
  /// In es, this message translates to:
  /// **'Elegí a qué característica va el +1 de la dote.'**
  String get luPendingFeatAbility;

  /// No description provided for @luPendingChoices.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Te falta una elección para continuar.} other{Te faltan {count} elecciones para continuar.}}'**
  String luPendingChoices(int count);

  /// No description provided for @luPendingExpertise.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Elegí una habilidad para tu Pericia.} other{Elegí {count} habilidades para tu Pericia.}}'**
  String luPendingExpertise(int count);

  /// No description provided for @luPendingProficiency.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Te falta una competencia para continuar.} other{Te faltan {count} competencias para continuar.}}'**
  String luPendingProficiency(int count);

  /// No description provided for @luPendingSpellChoices.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Te falta elegir un conjuro para continuar.} other{Te faltan {count} conjuros para continuar.}}'**
  String luPendingSpellChoices(int count);

  /// No description provided for @luOneCantrip.
  ///
  /// In es, this message translates to:
  /// **'un truco'**
  String get luOneCantrip;

  /// No description provided for @luCantrips.
  ///
  /// In es, this message translates to:
  /// **'{count} trucos'**
  String luCantrips(Object count);

  /// No description provided for @luOneSpell.
  ///
  /// In es, this message translates to:
  /// **'un conjuro'**
  String get luOneSpell;

  /// No description provided for @luSpells.
  ///
  /// In es, this message translates to:
  /// **'{count} conjuros'**
  String luSpells(Object count);

  /// No description provided for @luPendingClassSpells.
  ///
  /// In es, this message translates to:
  /// **'Te falta elegir {parts} para continuar.'**
  String luPendingClassSpells(String parts);

  /// No description provided for @luTitle.
  ///
  /// In es, this message translates to:
  /// **'Subir a nivel {level}'**
  String luTitle(Object level);

  /// No description provided for @luStatAttacks.
  ///
  /// In es, this message translates to:
  /// **'Ataques/acción'**
  String get luStatAttacks;

  /// No description provided for @luStatMasteries.
  ///
  /// In es, this message translates to:
  /// **'Maestrías'**
  String get luStatMasteries;

  /// No description provided for @luStatDarkvision.
  ///
  /// In es, this message translates to:
  /// **'Visión osc.'**
  String get luStatDarkvision;

  /// No description provided for @luSummaryTitle.
  ///
  /// In es, this message translates to:
  /// **'Subida de nivel'**
  String get luSummaryTitle;

  /// No description provided for @luHpMax.
  ///
  /// In es, this message translates to:
  /// **'+{hp} PG máximos'**
  String luHpMax(Object hp);

  /// No description provided for @luHpCurrent.
  ///
  /// In es, this message translates to:
  /// **'Tus PG actuales suben lo mismo.'**
  String get luHpCurrent;

  /// No description provided for @luNewProficiencies.
  ///
  /// In es, this message translates to:
  /// **'Nuevas competencias'**
  String get luNewProficiencies;

  /// No description provided for @luSavShort.
  ///
  /// In es, this message translates to:
  /// **'Salv. {ability}'**
  String luSavShort(String ability);

  /// No description provided for @luNewFeatures.
  ///
  /// In es, this message translates to:
  /// **'Rasgos de clase ganados'**
  String get luNewFeatures;

  /// No description provided for @luAlsoGain.
  ///
  /// In es, this message translates to:
  /// **'También ganás'**
  String get luAlsoGain;

  /// No description provided for @luNewResources.
  ///
  /// In es, this message translates to:
  /// **'Recursos nuevos'**
  String get luNewResources;

  /// No description provided for @luResourceLine.
  ///
  /// In es, this message translates to:
  /// **'Usos: {max} · recarga: {recharge}'**
  String luResourceLine(Object max, String recharge);

  /// No description provided for @restShortLower.
  ///
  /// In es, this message translates to:
  /// **'descanso corto'**
  String get restShortLower;

  /// No description provided for @restLongLower.
  ///
  /// In es, this message translates to:
  /// **'descanso largo'**
  String get restLongLower;

  /// No description provided for @luNewCompanions.
  ///
  /// In es, this message translates to:
  /// **'Compañeros nuevos'**
  String get luNewCompanions;

  /// No description provided for @luCompanionOne.
  ///
  /// In es, this message translates to:
  /// **'Se invoca desde la pestaña Combate.'**
  String get luCompanionOne;

  /// No description provided for @luCompanionMany.
  ///
  /// In es, this message translates to:
  /// **'{count} formas a elegir, desde la pestaña Combate.'**
  String luCompanionMany(Object count);

  /// No description provided for @luFormsMore.
  ///
  /// In es, this message translates to:
  /// **'{count} formas más'**
  String luFormsMore(Object count);

  /// No description provided for @luFormsNote.
  ///
  /// In es, this message translates to:
  /// **'Anotá las nuevas desde la pestaña Combate.'**
  String get luFormsNote;

  /// No description provided for @luDone.
  ///
  /// In es, this message translates to:
  /// **'¡Listo!'**
  String get luDone;

  /// No description provided for @luLeveled.
  ///
  /// In es, this message translates to:
  /// **'¡Subiste a nivel {level}!'**
  String luLeveled(Object level);

  /// No description provided for @luConfirm.
  ///
  /// In es, this message translates to:
  /// **'Confirmar'**
  String get luConfirm;

  /// No description provided for @luConfirmLevel.
  ///
  /// In es, this message translates to:
  /// **'Confirmar nivel {level}'**
  String luConfirmLevel(Object level);

  /// No description provided for @luContinue.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get luContinue;

  /// No description provided for @luGrants.
  ///
  /// In es, this message translates to:
  /// **'Concede: {list}'**
  String luGrants(String list);

  /// No description provided for @luRepeatable.
  ///
  /// In es, this message translates to:
  /// **'Se puede tomar más de una vez.'**
  String get luRepeatable;

  /// No description provided for @luLevelCount.
  ///
  /// In es, this message translates to:
  /// **'Nv {level}  ×{count}'**
  String luLevelCount(Object level, Object count);

  /// No description provided for @luComplete.
  ///
  /// In es, this message translates to:
  /// **'Ya están completas. Tocá una elegida para soltarla y poder cambiarla.'**
  String get luComplete;

  /// No description provided for @luRemoveOne.
  ///
  /// In es, this message translates to:
  /// **'Quitar una de {name}'**
  String luRemoveOne(String name);

  /// No description provided for @luNoExpertiseTargets.
  ///
  /// In es, this message translates to:
  /// **'No tenés competencias sobre las que aplicar Pericia.'**
  String get luNoExpertiseTargets;

  /// No description provided for @luNoProficiencies.
  ///
  /// In es, this message translates to:
  /// **'No quedan competencias disponibles para este rasgo.'**
  String get luNoProficiencies;

  /// No description provided for @luChooseEyebrow.
  ///
  /// In es, this message translates to:
  /// **'Elegís vos'**
  String get luChooseEyebrow;

  /// No description provided for @luSubclassIntroTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu camino dentro de la clase'**
  String get luSubclassIntroTitle;

  /// No description provided for @luSubclassIntroBody.
  ///
  /// In es, this message translates to:
  /// **'La subclase define nuevos rasgos y decisiones para los próximos niveles. Revisá cada opción antes de continuar.'**
  String get luSubclassIntroBody;

  /// No description provided for @luAsiIntroTitle.
  ///
  /// In es, this message translates to:
  /// **'Mejora tu personaje'**
  String get luAsiIntroTitle;

  /// No description provided for @luAsiIntroBody.
  ///
  /// In es, this message translates to:
  /// **'Aumentá tus características o elegí una dote. La decisión se previsualiza antes de modificar la ficha.'**
  String get luAsiIntroBody;

  /// No description provided for @luChoicesIntroTitle.
  ///
  /// In es, this message translates to:
  /// **'Tus elecciones de este nivel'**
  String get luChoicesIntroTitle;

  /// No description provided for @luChoicesIntroBody.
  ///
  /// In es, this message translates to:
  /// **'Algunos rasgos te dejan elegir entre varias opciones. Podés revisarlas acá antes de confirmar la subida.'**
  String get luChoicesIntroBody;

  /// No description provided for @luProfBodyExpertise.
  ///
  /// In es, this message translates to:
  /// **'Duplicás tu bonificador por competencia en las habilidades que elijas. Solo se ofrecen las habilidades en las que ya sos competente.'**
  String get luProfBodyExpertise;

  /// No description provided for @luProfBody.
  ///
  /// In es, this message translates to:
  /// **'Lo que ya tenés por otra vía queda bloqueado, para no gastar el cupo en algo que ya sabés hacer. En los cupos de Pericia es al revés: solo se ofrecen las habilidades en las que ya sos competente.'**
  String get luProfBody;

  /// No description provided for @luAlwaysPreparedTitle.
  ///
  /// In es, this message translates to:
  /// **'Conjuros que quedan siempre preparados'**
  String get luAlwaysPreparedTitle;

  /// No description provided for @luAlwaysPreparedBody.
  ///
  /// In es, this message translates to:
  /// **'Estos conjuros no ocupan cupo de preparados y no se pueden desmarcar desde el editor. El pozo ya viene filtrado por lo que el rasgo permite.'**
  String get luAlwaysPreparedBody;

  /// No description provided for @luMagicEyebrow.
  ///
  /// In es, this message translates to:
  /// **'Magia'**
  String get luMagicEyebrow;

  /// No description provided for @luYourSpellsAt.
  ///
  /// In es, this message translates to:
  /// **'Tus conjuros a nivel {level}'**
  String luYourSpellsAt(Object level);

  /// No description provided for @luMagicBody.
  ///
  /// In es, this message translates to:
  /// **'Revisá los espacios y la cantidad de conjuros preparados. Podés actualizar tu selección sin salir de la subida de nivel.'**
  String get luMagicBody;

  /// No description provided for @luClassOfLevel.
  ///
  /// In es, this message translates to:
  /// **'Clase del nivel'**
  String get luClassOfLevel;

  /// No description provided for @luClassHelper.
  ///
  /// In es, this message translates to:
  /// **'Podés continuar con tu clase actual o comenzar una nueva.'**
  String get luClassHelper;

  /// No description provided for @luWhichClass.
  ///
  /// In es, this message translates to:
  /// **'¿En qué clase avanzás?'**
  String get luWhichClass;

  /// No description provided for @luClassLevelLine.
  ///
  /// In es, this message translates to:
  /// **'{level}° nivel de {name} · dado d{die}'**
  String luClassLevelLine(Object level, String name, Object die);

  /// No description provided for @luMulticlassReq.
  ///
  /// In es, this message translates to:
  /// **'No cumplís el requisito de multiclase: {requirement}. La mesa puede autorizarlo.'**
  String luMulticlassReq(String requirement);

  /// No description provided for @luOverviewHp.
  ///
  /// In es, this message translates to:
  /// **'Elegís el promedio o tirás tu d{die}; la Constitución se suma sola.'**
  String luOverviewHp(Object die);

  /// No description provided for @luTagYouChoose.
  ///
  /// In es, this message translates to:
  /// **'ELEGÍS VOS'**
  String get luTagYouChoose;

  /// No description provided for @luTagOptional.
  ///
  /// In es, this message translates to:
  /// **'OPCIONAL'**
  String get luTagOptional;

  /// No description provided for @luTagAuto.
  ///
  /// In es, this message translates to:
  /// **'AUTOMÁTICO'**
  String get luTagAuto;

  /// No description provided for @luFeatureChoicesTitle.
  ///
  /// In es, this message translates to:
  /// **'Elecciones de rasgos'**
  String get luFeatureChoicesTitle;

  /// No description provided for @luFeatureChoicesBody.
  ///
  /// In es, this message translates to:
  /// **'Un rasgo de este nivel te deja elegir entre varias opciones.'**
  String get luFeatureChoicesBody;

  /// No description provided for @luChooseSubclass.
  ///
  /// In es, this message translates to:
  /// **'Elegir subclase'**
  String get luChooseSubclass;

  /// No description provided for @luChooseSubclassBody.
  ///
  /// In es, this message translates to:
  /// **'Define la especialización del personaje y sus rasgos futuros.'**
  String get luChooseSubclassBody;

  /// No description provided for @luAsiCardBody.
  ///
  /// In es, this message translates to:
  /// **'Repartí una mejora de características o incorporá una dote.'**
  String get luAsiCardBody;

  /// No description provided for @luReviewSpells.
  ///
  /// In es, this message translates to:
  /// **'Revisar conjuros'**
  String get luReviewSpells;

  /// No description provided for @luReviewSpellsBody.
  ///
  /// In es, this message translates to:
  /// **'Comprobá tus espacios y actualizá los conjuros preparados.'**
  String get luReviewSpellsBody;

  /// No description provided for @luLevelUpper.
  ///
  /// In es, this message translates to:
  /// **'NIVEL'**
  String get luLevelUpper;

  /// No description provided for @luCharacterLevels.
  ///
  /// In es, this message translates to:
  /// **'{name} sube a nivel {level}'**
  String luCharacterLevels(String name, Object level);

  /// No description provided for @luOverviewIntro.
  ///
  /// In es, this message translates to:
  /// **'Primero revisaremos qué cambia automáticamente y después resolveremos tus decisiones.'**
  String get luOverviewIntro;

  /// No description provided for @luOverviewHelp.
  ///
  /// In es, this message translates to:
  /// **'Solo aparecen los pasos que le tocan a este personaje en este nivel, así que la lista es distinta cada vez. Nada se guarda en la ficha hasta que confirmes la subida, así que podés rehacer cualquier elección antes de terminar.'**
  String get luOverviewHelp;

  /// No description provided for @luAutoChanges.
  ///
  /// In es, this message translates to:
  /// **'Cambios automáticos'**
  String get luAutoChanges;

  /// No description provided for @luDecisions.
  ///
  /// In es, this message translates to:
  /// **'Decisiones de esta subida'**
  String get luDecisions;

  /// No description provided for @luMoreHpTitle.
  ///
  /// In es, this message translates to:
  /// **'Más puntos de golpe'**
  String get luMoreHpTitle;

  /// No description provided for @luMoreHpBody.
  ///
  /// In es, this message translates to:
  /// **'Elegí el promedio seguro o tirá tu dado de golpe d{die}. La Constitución se suma sola.'**
  String luMoreHpBody(Object die);

  /// No description provided for @luHitDie.
  ///
  /// In es, this message translates to:
  /// **'Dado de golpe d{die}'**
  String luHitDie(Object die);

  /// No description provided for @luNoResult.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay un resultado.'**
  String get luNoResult;

  /// No description provided for @luBaseGain.
  ///
  /// In es, this message translates to:
  /// **'Ganancia base del nivel: +{hp} PG.'**
  String luBaseGain(Object hp);

  /// No description provided for @luHpMaxTitle.
  ///
  /// In es, this message translates to:
  /// **'PG máximos'**
  String get luHpMaxTitle;

  /// No description provided for @luRollToSee.
  ///
  /// In es, this message translates to:
  /// **'Tirá el dado para ver la cuenta.'**
  String get luRollToSee;

  /// No description provided for @luHpDie.
  ///
  /// In es, this message translates to:
  /// **'+{hp} del dado'**
  String luHpDie(Object hp);

  /// No description provided for @luHpCon.
  ///
  /// In es, this message translates to:
  /// **'{value} de Constitución'**
  String luHpCon(String value);

  /// No description provided for @luHpFeatures.
  ///
  /// In es, this message translates to:
  /// **'{value} de tus rasgos'**
  String luHpFeatures(String value);

  /// No description provided for @luHpTotal.
  ///
  /// In es, this message translates to:
  /// **'{parts} = {total} PG.'**
  String luHpTotal(String parts, String total);

  /// No description provided for @luHpRecalc.
  ///
  /// In es, this message translates to:
  /// **'Si subís Constitución más adelante, se recalcula.'**
  String get luHpRecalc;

  /// No description provided for @luAverage.
  ///
  /// In es, this message translates to:
  /// **'Promedio ({value})'**
  String luAverage(Object value);

  /// No description provided for @luRoll.
  ///
  /// In es, this message translates to:
  /// **'Tirar'**
  String get luRoll;

  /// No description provided for @luRollDie.
  ///
  /// In es, this message translates to:
  /// **'Tirar el dado'**
  String get luRollDie;

  /// No description provided for @luRollAgain.
  ///
  /// In es, this message translates to:
  /// **'Volver a tirar'**
  String get luRollAgain;

  /// No description provided for @luChosenEarlier.
  ///
  /// In es, this message translates to:
  /// **'Elegidos en niveles anteriores'**
  String get luChosenEarlier;

  /// No description provided for @luChangeOrKeep.
  ///
  /// In es, this message translates to:
  /// **'Podés cambiarlos o dejarlos como están.'**
  String get luChangeOrKeep;

  /// No description provided for @luAutoEyebrow.
  ///
  /// In es, this message translates to:
  /// **'Automático'**
  String get luAutoEyebrow;

  /// No description provided for @luFeaturesAt.
  ///
  /// In es, this message translates to:
  /// **'Rasgos ganados a nivel {level}'**
  String luFeaturesAt(Object level);

  /// No description provided for @luFeaturesBody.
  ///
  /// In es, this message translates to:
  /// **'Estos rasgos provienen de tu clase y subclase. Se aplicarán automáticamente cuando confirmes la subida.'**
  String get luFeaturesBody;

  /// No description provided for @luResource.
  ///
  /// In es, this message translates to:
  /// **'Recurso'**
  String get luResource;

  /// No description provided for @luClassResource.
  ///
  /// In es, this message translates to:
  /// **'Recurso de clase'**
  String get luClassResource;

  /// No description provided for @luReviewMaxHp.
  ///
  /// In es, this message translates to:
  /// **'Puntos de golpe máximos'**
  String get luReviewMaxHp;

  /// No description provided for @luReviewHpNote.
  ///
  /// In es, this message translates to:
  /// **'+{hp} en esta subida'**
  String luReviewHpNote(Object hp);

  /// No description provided for @luReviewProfBonus.
  ///
  /// In es, this message translates to:
  /// **'Bonificador por competencia'**
  String get luReviewProfBonus;

  /// No description provided for @luReviewProfBonusNote.
  ///
  /// In es, this message translates to:
  /// **'Se aplica a todas las competencias relevantes'**
  String get luReviewProfBonusNote;

  /// No description provided for @luReviewSlotsNote.
  ///
  /// In es, this message translates to:
  /// **'Por nivel de conjuro'**
  String get luReviewSlotsNote;

  /// No description provided for @luReviewPreparedNote.
  ///
  /// In es, this message translates to:
  /// **'Capacidad del repertorio'**
  String get luReviewPreparedNote;

  /// No description provided for @luReviewCantripsNote.
  ///
  /// In es, this message translates to:
  /// **'Se lanzan sin gastar espacios'**
  String get luReviewCantripsNote;

  /// No description provided for @luReviewAttacks.
  ///
  /// In es, this message translates to:
  /// **'Ataques por acción'**
  String get luReviewAttacks;

  /// No description provided for @luReviewExtraAttack.
  ///
  /// In es, this message translates to:
  /// **'Ataque Adicional'**
  String get luReviewExtraAttack;

  /// No description provided for @luReviewMasteries.
  ///
  /// In es, this message translates to:
  /// **'Maestrías de armas'**
  String get luReviewMasteries;

  /// No description provided for @luReviewMasteriesNote.
  ///
  /// In es, this message translates to:
  /// **'Opciones disponibles'**
  String get luReviewMasteriesNote;

  /// No description provided for @luReviewSubclassNote.
  ///
  /// In es, this message translates to:
  /// **'Nueva especialización'**
  String get luReviewSubclassNote;

  /// No description provided for @luFeat.
  ///
  /// In es, this message translates to:
  /// **'Dote'**
  String get luFeat;

  /// No description provided for @luReviewFeatNote.
  ///
  /// In es, this message translates to:
  /// **'Nueva capacidad'**
  String get luReviewFeatNote;

  /// No description provided for @luReviewImproveNote.
  ///
  /// In es, this message translates to:
  /// **'Mejora permanente'**
  String get luReviewImproveNote;

  /// No description provided for @luReviewChosenSpells.
  ///
  /// In es, this message translates to:
  /// **'Trucos y conjuros elegidos'**
  String get luReviewChosenSpells;

  /// No description provided for @luReviewChosenNote.
  ///
  /// In es, this message translates to:
  /// **'Selección actualizada'**
  String get luReviewChosenNote;

  /// No description provided for @luFinalEyebrow.
  ///
  /// In es, this message translates to:
  /// **'Revisión final'**
  String get luFinalEyebrow;

  /// No description provided for @luFinalTitle.
  ///
  /// In es, this message translates to:
  /// **'Así queda {name}'**
  String luFinalTitle(String name);

  /// No description provided for @luFinalBody.
  ///
  /// In es, this message translates to:
  /// **'Revisá los cambios antes de escribirlos en la ficha. Podés volver a cualquier paso disponible desde la barra superior.'**
  String get luFinalBody;

  /// No description provided for @luIncorporated.
  ///
  /// In es, this message translates to:
  /// **'Rasgos incorporados'**
  String get luIncorporated;

  /// No description provided for @luSlotLine.
  ///
  /// In es, this message translates to:
  /// **'Nv{level} ×{count}'**
  String luSlotLine(Object level, Object count);

  /// No description provided for @luSubclassAt.
  ///
  /// In es, this message translates to:
  /// **'Subclase (nivel {level})'**
  String luSubclassAt(Object level);

  /// No description provided for @luSpellsEyebrow.
  ///
  /// In es, this message translates to:
  /// **'Conjuros a nivel {level}'**
  String luSpellsEyebrow(Object level);

  /// No description provided for @luPrepare.
  ///
  /// In es, this message translates to:
  /// **'Preparás {count} conjuros'**
  String luPrepare(Object count);

  /// No description provided for @luCantripsOf.
  ///
  /// In es, this message translates to:
  /// **'Trucos: {chosen} de {total}'**
  String luCantripsOf(Object chosen, Object total);

  /// No description provided for @luMissingCantrips.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Te falta elegir un truco.} other{Te falta elegir {count} trucos.}}'**
  String luMissingCantrips(int count);

  /// No description provided for @luPreparedOf.
  ///
  /// In es, this message translates to:
  /// **'Preparados: {chosen} de {total}'**
  String luPreparedOf(Object chosen, Object total);

  /// No description provided for @luMissingPrepare.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Te falta preparar un conjuro.} other{Te falta preparar {count} conjuros.}}'**
  String luMissingPrepare(int count);

  /// No description provided for @luSpellsUpdated.
  ///
  /// In es, this message translates to:
  /// **'Conjuros actualizados'**
  String get luSpellsUpdated;

  /// No description provided for @luPrepareSpells.
  ///
  /// In es, this message translates to:
  /// **'Preparar conjuros'**
  String get luPrepareSpells;

  /// No description provided for @luAsiAt.
  ///
  /// In es, this message translates to:
  /// **'Mejora de característica (nivel {level})'**
  String luAsiAt(Object level);

  /// No description provided for @luImproveAbilities.
  ///
  /// In es, this message translates to:
  /// **'Mejorar características'**
  String get luImproveAbilities;

  /// No description provided for @luTakeFeat.
  ///
  /// In es, this message translates to:
  /// **'Tomar dote'**
  String get luTakeFeat;

  /// No description provided for @luFeatRaises.
  ///
  /// In es, this message translates to:
  /// **'La dote sube una característica (+{amount})'**
  String luFeatRaises(Object amount);

  /// No description provided for @luFeatCap.
  ///
  /// In es, this message translates to:
  /// **'Esta dote llega hasta {max}, no hasta 20 como una mejora normal.'**
  String luFeatCap(Object max);

  /// No description provided for @luPlusTwo.
  ///
  /// In es, this message translates to:
  /// **'+2 a una'**
  String get luPlusTwo;

  /// No description provided for @luPlusOneTwo.
  ///
  /// In es, this message translates to:
  /// **'+1 a dos'**
  String get luPlusOneTwo;

  /// No description provided for @luPickOneAbility.
  ///
  /// In es, this message translates to:
  /// **'Elegí una característica para sumar 2 puntos.'**
  String get luPickOneAbility;

  /// No description provided for @luPickTwoAbilities.
  ///
  /// In es, this message translates to:
  /// **'Elegí dos características distintas para sumar 1 punto a cada una.'**
  String get luPickTwoAbilities;

  /// No description provided for @luNoFeats.
  ///
  /// In es, this message translates to:
  /// **'No quedan dotes disponibles.'**
  String get luNoFeats;

  /// No description provided for @luSearchFeat.
  ///
  /// In es, this message translates to:
  /// **'Buscar dote'**
  String get luSearchFeat;

  /// No description provided for @luNameOrEffect.
  ///
  /// In es, this message translates to:
  /// **'Nombre o efecto'**
  String get luNameOrEffect;

  /// No description provided for @luAvailable.
  ///
  /// In es, this message translates to:
  /// **'{count} disponibles'**
  String luAvailable(Object count);

  /// No description provided for @luNoFeatMatch.
  ///
  /// In es, this message translates to:
  /// **'Ninguna dote coincide con «{query}».'**
  String luNoFeatMatch(String query);

  /// No description provided for @luPickFeatTitle.
  ///
  /// In es, this message translates to:
  /// **'Elegí una dote'**
  String get luPickFeatTitle;

  /// No description provided for @luPickFeatBody.
  ///
  /// In es, this message translates to:
  /// **'Cada dote cambia cómo se juega el personaje. Seleccioná una para revisar su efecto completo.'**
  String get luPickFeatBody;

  /// No description provided for @catRaces.
  ///
  /// In es, this message translates to:
  /// **'Especies'**
  String get catRaces;

  /// No description provided for @catLineages.
  ///
  /// In es, this message translates to:
  /// **'Linajes'**
  String get catLineages;

  /// No description provided for @catClasses.
  ///
  /// In es, this message translates to:
  /// **'Clases'**
  String get catClasses;

  /// No description provided for @catSubclasses.
  ///
  /// In es, this message translates to:
  /// **'Subclases'**
  String get catSubclasses;

  /// No description provided for @catBackgrounds.
  ///
  /// In es, this message translates to:
  /// **'Trasfondos'**
  String get catBackgrounds;

  /// No description provided for @catFeats.
  ///
  /// In es, this message translates to:
  /// **'Dotes'**
  String get catFeats;

  /// No description provided for @codexGroupCharacter.
  ///
  /// In es, this message translates to:
  /// **'Personaje'**
  String get codexGroupCharacter;

  /// No description provided for @codexGroupGear.
  ///
  /// In es, this message translates to:
  /// **'Magia y equipo'**
  String get codexGroupGear;

  /// No description provided for @codexSearchTitle.
  ///
  /// In es, this message translates to:
  /// **'Códice · Búsqueda'**
  String get codexSearchTitle;

  /// No description provided for @codexSectionTitle.
  ///
  /// In es, this message translates to:
  /// **'Códice · {section}'**
  String codexSectionTitle(String section);

  /// No description provided for @codexCategoriesTooltip.
  ///
  /// In es, this message translates to:
  /// **'Categorías del Códice'**
  String get codexCategoriesTooltip;

  /// No description provided for @codexSearchAll.
  ///
  /// In es, this message translates to:
  /// **'Buscar en todo el Códice'**
  String get codexSearchAll;

  /// No description provided for @codexHome.
  ///
  /// In es, this message translates to:
  /// **'Portada'**
  String get codexHome;

  /// No description provided for @codexIntro.
  ///
  /// In es, this message translates to:
  /// **'Todo el contenido del juego para leer, sin crear un personaje ni editar nada. Tu homebrew aparece mezclado con el resto, con su marca de procedencia.'**
  String get codexIntro;

  /// No description provided for @codexNoMatch.
  ///
  /// In es, this message translates to:
  /// **'Nada del Códice coincide con «{query}».'**
  String codexNoMatch(String query);

  /// No description provided for @codexSeeAll.
  ///
  /// In es, this message translates to:
  /// **'Ver las {count} coincidencias en {category}'**
  String codexSeeAll(Object count, String category);

  /// No description provided for @codexPickEntry.
  ///
  /// In es, this message translates to:
  /// **'Elegí una entrada para leerla.'**
  String get codexPickEntry;

  /// No description provided for @codexSearchIn.
  ///
  /// In es, this message translates to:
  /// **'Buscar en {category}'**
  String codexSearchIn(String category);

  /// No description provided for @codexNothingMatches.
  ///
  /// In es, this message translates to:
  /// **'Nada coincide con lo que buscaste.'**
  String get codexNothingMatches;

  /// No description provided for @codexClearFilters.
  ///
  /// In es, this message translates to:
  /// **'Limpiar filtros'**
  String get codexClearFilters;

  /// No description provided for @codexBackToList.
  ///
  /// In es, this message translates to:
  /// **'Volver al listado'**
  String get codexBackToList;

  /// No description provided for @codexLineageOf.
  ///
  /// In es, this message translates to:
  /// **'Linaje de {race}'**
  String codexLineageOf(String race);

  /// No description provided for @codexLevelN.
  ///
  /// In es, this message translates to:
  /// **'Nivel {level}'**
  String codexLevelN(Object level);

  /// No description provided for @codexPickAny.
  ///
  /// In es, this message translates to:
  /// **'elegí {count}, cualquiera'**
  String codexPickAny(Object count);

  /// No description provided for @codexPickFrom.
  ///
  /// In es, this message translates to:
  /// **'elegí {count} entre {list}'**
  String codexPickFrom(Object count, String list);

  /// No description provided for @codexSubclassOf.
  ///
  /// In es, this message translates to:
  /// **'Subclase de {klass}'**
  String codexSubclassOf(String klass);

  /// No description provided for @commonYes.
  ///
  /// In es, this message translates to:
  /// **'Sí'**
  String get commonYes;

  /// No description provided for @codexCategory.
  ///
  /// In es, this message translates to:
  /// **'Categoría'**
  String get codexCategory;

  /// No description provided for @codexRequirements.
  ///
  /// In es, this message translates to:
  /// **'Requisitos'**
  String get codexRequirements;

  /// No description provided for @codexRepeatable.
  ///
  /// In es, this message translates to:
  /// **'Repetible'**
  String get codexRepeatable;

  /// No description provided for @codexRitual.
  ///
  /// In es, this message translates to:
  /// **'{time} o ritual'**
  String codexRitual(String time);

  /// No description provided for @codexConcentration.
  ///
  /// In es, this message translates to:
  /// **'Concentración, {duration}'**
  String codexConcentration(String duration);

  /// No description provided for @codexCanPrepare.
  ///
  /// In es, this message translates to:
  /// **'Lo pueden preparar'**
  String get codexCanPrepare;

  /// No description provided for @codexRarityAttune.
  ///
  /// In es, this message translates to:
  /// **'{rarity} · sintonización'**
  String codexRarityAttune(String rarity);

  /// No description provided for @codexRarity.
  ///
  /// In es, this message translates to:
  /// **'Rareza'**
  String get codexRarity;

  /// No description provided for @codexAttunement.
  ///
  /// In es, this message translates to:
  /// **'Sintonización'**
  String get codexAttunement;

  /// No description provided for @codexRequires.
  ///
  /// In es, this message translates to:
  /// **'Requiere'**
  String get codexRequires;

  /// No description provided for @codexNotRequired.
  ///
  /// In es, this message translates to:
  /// **'No requiere'**
  String get codexNotRequired;

  /// No description provided for @codexCharges.
  ///
  /// In es, this message translates to:
  /// **'Cargas'**
  String get codexCharges;

  /// No description provided for @codexWeight.
  ///
  /// In es, this message translates to:
  /// **'Peso'**
  String get codexWeight;

  /// No description provided for @codexPrice.
  ///
  /// In es, this message translates to:
  /// **'Precio'**
  String get codexPrice;

  /// No description provided for @codexMastery.
  ///
  /// In es, this message translates to:
  /// **'Maestría'**
  String get codexMastery;

  /// No description provided for @codexProperties.
  ///
  /// In es, this message translates to:
  /// **'Propiedades'**
  String get codexProperties;

  /// No description provided for @codexAcDex.
  ///
  /// In es, this message translates to:
  /// **'{ac} + mod. DES'**
  String codexAcDex(Object ac);

  /// No description provided for @codexAcDexMax.
  ///
  /// In es, this message translates to:
  /// **'{ac} + mod. DES (máx. {max})'**
  String codexAcDexMax(Object ac, Object max);

  /// No description provided for @codexArmorSubtitle.
  ///
  /// In es, this message translates to:
  /// **'{category} · CA {ac}'**
  String codexArmorSubtitle(String category, String ac);

  /// No description provided for @codexStrength.
  ///
  /// In es, this message translates to:
  /// **'Fuerza'**
  String get codexStrength;

  /// No description provided for @codexStealth.
  ///
  /// In es, this message translates to:
  /// **'Sigilo'**
  String get codexStealth;

  /// No description provided for @codexDisadvantage.
  ///
  /// In es, this message translates to:
  /// **'Desventaja'**
  String get codexDisadvantage;

  /// No description provided for @codexPackOf.
  ///
  /// In es, this message translates to:
  /// **'Paquete de'**
  String get codexPackOf;

  /// No description provided for @codexPrereqFeat.
  ///
  /// In es, this message translates to:
  /// **'una dote de {category}'**
  String codexPrereqFeat(String category);

  /// No description provided for @codexPrereqCast.
  ///
  /// In es, this message translates to:
  /// **'lanzar conjuros'**
  String get codexPrereqCast;

  /// No description provided for @codexPrereqProf.
  ///
  /// In es, this message translates to:
  /// **'competencia: {proficiency}'**
  String codexPrereqProf(String proficiency);

  /// No description provided for @styleDigitalFantasy.
  ///
  /// In es, this message translates to:
  /// **'Arte digital de fantasía'**
  String get styleDigitalFantasy;

  /// No description provided for @styleClassicOil.
  ///
  /// In es, this message translates to:
  /// **'Óleo clásico'**
  String get styleClassicOil;

  /// No description provided for @styleComic.
  ///
  /// In es, this message translates to:
  /// **'Ilustración de cómic'**
  String get styleComic;

  /// No description provided for @styleCinematic.
  ///
  /// In es, this message translates to:
  /// **'Realista cinematográfico'**
  String get styleCinematic;

  /// No description provided for @styleWatercolor.
  ///
  /// In es, this message translates to:
  /// **'Acuarela'**
  String get styleWatercolor;

  /// No description provided for @stylePixelArt.
  ///
  /// In es, this message translates to:
  /// **'Pixel art'**
  String get stylePixelArt;

  /// No description provided for @stylePencilSketch.
  ///
  /// In es, this message translates to:
  /// **'Boceto a lápiz'**
  String get stylePencilSketch;

  /// No description provided for @styleCustom.
  ///
  /// In es, this message translates to:
  /// **'Personalizado'**
  String get styleCustom;

  /// No description provided for @portraitDefaultError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo fijar como predeterminado, pero vale para esta sesión.'**
  String get portraitDefaultError;

  /// No description provided for @portraitOffline.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión con el servidor. La generación requiere red.'**
  String get portraitOffline;

  /// No description provided for @portraitGenerateError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo generar: {message}'**
  String portraitGenerateError(String message);

  /// No description provided for @portraitGenerateFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo generar'**
  String get portraitGenerateFailed;

  /// No description provided for @portraitPickReference.
  ///
  /// In es, this message translates to:
  /// **'Elegir imagen de referencia'**
  String get portraitPickReference;

  /// No description provided for @portraitReferenceError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo elegir la imagen de referencia'**
  String get portraitReferenceError;

  /// No description provided for @portraitPickImage.
  ///
  /// In es, this message translates to:
  /// **'Elegir imagen de retrato'**
  String get portraitPickImage;

  /// No description provided for @portraitImportError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo importar la imagen'**
  String get portraitImportError;

  /// No description provided for @portraitSaveError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar el retrato'**
  String get portraitSaveError;

  /// No description provided for @portraitSaved.
  ///
  /// In es, this message translates to:
  /// **'Retrato guardado.'**
  String get portraitSaved;

  /// No description provided for @portraitRestored.
  ///
  /// In es, this message translates to:
  /// **'Retrato restaurado.'**
  String get portraitRestored;

  /// No description provided for @portraitDeleteTitle.
  ///
  /// In es, this message translates to:
  /// **'Borrar retrato'**
  String get portraitDeleteTitle;

  /// No description provided for @portraitDeleteBody.
  ///
  /// In es, this message translates to:
  /// **'El retrato se borra para siempre y no se puede recuperar.'**
  String get portraitDeleteBody;

  /// No description provided for @portraitDeleteError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo borrar el retrato'**
  String get portraitDeleteError;

  /// No description provided for @portraitDeleted.
  ///
  /// In es, this message translates to:
  /// **'Retrato borrado.'**
  String get portraitDeleted;

  /// No description provided for @portraitBackToThis.
  ///
  /// In es, this message translates to:
  /// **'Volver a este retrato'**
  String get portraitBackToThis;

  /// No description provided for @portraitDeleteThis.
  ///
  /// In es, this message translates to:
  /// **'Borrar este retrato'**
  String get portraitDeleteThis;

  /// No description provided for @portraitCurrent.
  ///
  /// In es, this message translates to:
  /// **'Retrato actual'**
  String get portraitCurrent;

  /// No description provided for @portraitPrevious.
  ///
  /// In es, this message translates to:
  /// **'Retrato anterior {index}'**
  String portraitPrevious(Object index);

  /// No description provided for @portraitLoadingSettings.
  ///
  /// In es, this message translates to:
  /// **'Cargando configuración…'**
  String get portraitLoadingSettings;

  /// No description provided for @portraitUseThis.
  ///
  /// In es, this message translates to:
  /// **'Usar este retrato'**
  String get portraitUseThis;

  /// No description provided for @portraitSavedTitle.
  ///
  /// In es, this message translates to:
  /// **'Retratos guardados'**
  String get portraitSavedTitle;

  /// No description provided for @portraitSummoning.
  ///
  /// In es, this message translates to:
  /// **'INVOCANDO'**
  String get portraitSummoning;

  /// No description provided for @portraitBaseDescription.
  ///
  /// In es, this message translates to:
  /// **'DESCRIPCIÓN BASE · AUTOMÁTICA'**
  String get portraitBaseDescription;

  /// No description provided for @portraitUsedPrompt.
  ///
  /// In es, this message translates to:
  /// **'PROMPT USADO'**
  String get portraitUsedPrompt;

  /// No description provided for @portraitGenerateAi.
  ///
  /// In es, this message translates to:
  /// **'Generar con IA'**
  String get portraitGenerateAi;

  /// No description provided for @portraitUpload.
  ///
  /// In es, this message translates to:
  /// **'Subir imagen'**
  String get portraitUpload;

  /// No description provided for @portraitNoProviders.
  ///
  /// In es, this message translates to:
  /// **'Este servidor no tiene ningún proveedor de generación configurado. Todavía podés subir tu propio retrato.'**
  String get portraitNoProviders;

  /// No description provided for @portraitEngine.
  ///
  /// In es, this message translates to:
  /// **'Motor de generación'**
  String get portraitEngine;

  /// No description provided for @portraitStyle.
  ///
  /// In es, this message translates to:
  /// **'Estilo'**
  String get portraitStyle;

  /// No description provided for @portraitCustomStyle.
  ///
  /// In es, this message translates to:
  /// **'Estilo personalizado'**
  String get portraitCustomStyle;

  /// No description provided for @portraitExtraDetails.
  ///
  /// In es, this message translates to:
  /// **'Detalles adicionales'**
  String get portraitExtraDetails;

  /// No description provided for @portraitAppearance.
  ///
  /// In es, this message translates to:
  /// **'Apariencia'**
  String get portraitAppearance;

  /// No description provided for @portraitDetailsHint.
  ///
  /// In es, this message translates to:
  /// **'Color de pelo, cicatrices, actitud…'**
  String get portraitDetailsHint;

  /// No description provided for @portraitReference.
  ///
  /// In es, this message translates to:
  /// **'Imagen de referencia · opcional'**
  String get portraitReference;

  /// No description provided for @portraitChooseImage.
  ///
  /// In es, this message translates to:
  /// **'Elegir imagen…'**
  String get portraitChooseImage;

  /// No description provided for @portraitRemoveReference.
  ///
  /// In es, this message translates to:
  /// **'Quitar referencia'**
  String get portraitRemoveReference;

  /// No description provided for @portraitGenerating.
  ///
  /// In es, this message translates to:
  /// **'Generando…'**
  String get portraitGenerating;

  /// No description provided for @portraitGenerate.
  ///
  /// In es, this message translates to:
  /// **'Generar'**
  String get portraitGenerate;

  /// No description provided for @portraitGenerateAgain.
  ///
  /// In es, this message translates to:
  /// **'Generar otra vez'**
  String get portraitGenerateAgain;

  /// No description provided for @portraitFreeNote.
  ///
  /// In es, this message translates to:
  /// **'El servicio gratuito puede tardar hasta ~1 min y genera 2 variantes de a una. Si aparece un error de límite (429), esperá unos segundos y reintentá.'**
  String get portraitFreeNote;

  /// No description provided for @portraitImporting.
  ///
  /// In es, this message translates to:
  /// **'Importando…'**
  String get portraitImporting;

  /// No description provided for @portraitImportTitle.
  ///
  /// In es, this message translates to:
  /// **'Importar imagen desde archivo'**
  String get portraitImportTitle;

  /// No description provided for @portraitImportHint.
  ///
  /// In es, this message translates to:
  /// **'Tocá para elegirla. PNG, JPG o WEBP.'**
  String get portraitImportHint;

  /// No description provided for @portraitImportNote.
  ///
  /// In es, this message translates to:
  /// **'La imagen pasa a ser el retrato del personaje. Podés volver a generar con IA cuando quieras.'**
  String get portraitImportNote;

  /// No description provided for @portraitAcceptsReference.
  ///
  /// In es, this message translates to:
  /// **'Acepta referencia'**
  String get portraitAcceptsReference;

  /// No description provided for @portraitTextOnly.
  ///
  /// In es, this message translates to:
  /// **'Solo texto'**
  String get portraitTextOnly;

  /// No description provided for @portraitPickStyle.
  ///
  /// In es, this message translates to:
  /// **'Elegir estilo'**
  String get portraitPickStyle;

  /// No description provided for @spellEditTitle.
  ///
  /// In es, this message translates to:
  /// **'Editar conjuros'**
  String get spellEditTitle;

  /// No description provided for @spellEditTitleClass.
  ///
  /// In es, this message translates to:
  /// **'Editar conjuros · {klass}'**
  String spellEditTitleClass(String klass);

  /// No description provided for @spellEditCantrips.
  ///
  /// In es, this message translates to:
  /// **'Trucos ({count}/{max})'**
  String spellEditCantrips(Object count, Object max);

  /// No description provided for @spellEditGrantedCantrips.
  ///
  /// In es, this message translates to:
  /// **'Los trucos que ya tenés por otro rasgo no aparecen acá: no ocupan un cupo de truco de clase.'**
  String get spellEditGrantedCantrips;

  /// No description provided for @spellEditPrepared.
  ///
  /// In es, this message translates to:
  /// **'Conjuros preparados ({count}/{max})'**
  String spellEditPrepared(Object count, Object max);

  /// No description provided for @spellEditKnown.
  ///
  /// In es, this message translates to:
  /// **'Conjuros conocidos ({count})'**
  String spellEditKnown(Object count);

  /// No description provided for @spellEditUpTo.
  ///
  /// In es, this message translates to:
  /// **'Hasta nivel {level}.'**
  String spellEditUpTo(Object level);

  /// No description provided for @hbSimple.
  ///
  /// In es, this message translates to:
  /// **'Simple'**
  String get hbSimple;

  /// No description provided for @hbMartial.
  ///
  /// In es, this message translates to:
  /// **'Marcial'**
  String get hbMartial;

  /// No description provided for @hbNoMastery.
  ///
  /// In es, this message translates to:
  /// **'Sin maestría'**
  String get hbNoMastery;

  /// No description provided for @hbLight.
  ///
  /// In es, this message translates to:
  /// **'Ligera'**
  String get hbLight;

  /// No description provided for @hbMedium.
  ///
  /// In es, this message translates to:
  /// **'Media'**
  String get hbMedium;

  /// No description provided for @hbHeavy.
  ///
  /// In es, this message translates to:
  /// **'Pesada'**
  String get hbHeavy;

  /// No description provided for @hbMundane.
  ///
  /// In es, this message translates to:
  /// **'Mundano'**
  String get hbMundane;

  /// No description provided for @hbFeatOrigin.
  ///
  /// In es, this message translates to:
  /// **'De origen'**
  String get hbFeatOrigin;

  /// No description provided for @hbFeatGeneral.
  ///
  /// In es, this message translates to:
  /// **'General'**
  String get hbFeatGeneral;

  /// No description provided for @hbFeatFighting.
  ///
  /// In es, this message translates to:
  /// **'Estilo de combate'**
  String get hbFeatFighting;

  /// No description provided for @hbFeatDragonmark.
  ///
  /// In es, this message translates to:
  /// **'Marca dracónica'**
  String get hbFeatDragonmark;

  /// No description provided for @hbFeatEpic.
  ///
  /// In es, this message translates to:
  /// **'Don épico'**
  String get hbFeatEpic;

  /// No description provided for @sizeSmall.
  ///
  /// In es, this message translates to:
  /// **'Pequeño'**
  String get sizeSmall;

  /// No description provided for @sizeMedium.
  ///
  /// In es, this message translates to:
  /// **'Mediano'**
  String get sizeMedium;

  /// No description provided for @sizeLarge.
  ///
  /// In es, this message translates to:
  /// **'Grande'**
  String get sizeLarge;

  /// No description provided for @catItems.
  ///
  /// In es, this message translates to:
  /// **'Objetos'**
  String get catItems;

  /// No description provided for @catCreatures.
  ///
  /// In es, this message translates to:
  /// **'Criaturas'**
  String get catCreatures;

  /// No description provided for @hbAddWeapon.
  ///
  /// In es, this message translates to:
  /// **'Agregar arma'**
  String get hbAddWeapon;

  /// No description provided for @hbAddArmor.
  ///
  /// In es, this message translates to:
  /// **'Agregar armadura'**
  String get hbAddArmor;

  /// No description provided for @hbAddFeat.
  ///
  /// In es, this message translates to:
  /// **'Agregar dote'**
  String get hbAddFeat;

  /// No description provided for @hbAddSpecies.
  ///
  /// In es, this message translates to:
  /// **'Agregar especie'**
  String get hbAddSpecies;

  /// No description provided for @hbAddBackground.
  ///
  /// In es, this message translates to:
  /// **'Agregar trasfondo'**
  String get hbAddBackground;

  /// No description provided for @hbAddSpell.
  ///
  /// In es, this message translates to:
  /// **'Agregar conjuro'**
  String get hbAddSpell;

  /// No description provided for @hbAddCreature.
  ///
  /// In es, this message translates to:
  /// **'Agregar criatura'**
  String get hbAddCreature;

  /// No description provided for @hbSaved.
  ///
  /// In es, this message translates to:
  /// **'«{name}» se guardó.'**
  String hbSaved(String name);

  /// No description provided for @hbNoChanges.
  ///
  /// In es, this message translates to:
  /// **'No se guardó ningún cambio.'**
  String get hbNoChanges;

  /// No description provided for @hbSaveError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar el contenido homebrew'**
  String get hbSaveError;

  /// No description provided for @hbNothingToExport.
  ///
  /// In es, this message translates to:
  /// **'No hay contenido homebrew para exportar.'**
  String get hbNothingToExport;

  /// No description provided for @hbExported.
  ///
  /// In es, this message translates to:
  /// **'Homebrew exportado ({count, plural, =1{1 entrada} other{{count} entradas}}).'**
  String hbExported(int count);

  /// No description provided for @hbPickFile.
  ///
  /// In es, this message translates to:
  /// **'Elegí un archivo de homebrew (.json)'**
  String get hbPickFile;

  /// No description provided for @hbOverwriteTitle.
  ///
  /// In es, this message translates to:
  /// **'Sobrescribir homebrew'**
  String get hbOverwriteTitle;

  /// No description provided for @hbOverwriteBody.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 entrada del archivo comparte} other{{count} entradas del archivo comparten}} id con contenido que ya tenés. Al importar se reemplazarán. ¿Continuar?'**
  String hbOverwriteBody(int count);

  /// No description provided for @hbOverwrite.
  ///
  /// In es, this message translates to:
  /// **'Sobrescribir'**
  String get hbOverwrite;

  /// No description provided for @hbImported.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Se importó 1 entrada de homebrew.} other{Se importaron {count} entradas de homebrew.}}'**
  String hbImported(int count);

  /// No description provided for @hbImportError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo importar el homebrew'**
  String get hbImportError;

  /// No description provided for @hbLoadIssues.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 entrada no se pudo cargar} other{{count} entradas no se pudieron cargar}}'**
  String hbLoadIssues(int count);

  /// No description provided for @hbSkipped.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Se omitió} other{Se omitieron}} al iniciar. El resto de tu homebrew está intacto.'**
  String hbSkipped(int count);

  /// No description provided for @hbDeleteInvalid.
  ///
  /// In es, this message translates to:
  /// **'Borrar entrada inválida'**
  String get hbDeleteInvalid;

  /// No description provided for @hbCategoriesTooltip.
  ///
  /// In es, this message translates to:
  /// **'Categorías de homebrew'**
  String get hbCategoriesTooltip;

  /// No description provided for @hbTitleSearch.
  ///
  /// In es, this message translates to:
  /// **'Homebrew · Búsqueda'**
  String get hbTitleSearch;

  /// No description provided for @hbTitleSection.
  ///
  /// In es, this message translates to:
  /// **'Homebrew · {section}'**
  String hbTitleSection(String section);

  /// No description provided for @hbSearch.
  ///
  /// In es, this message translates to:
  /// **'Buscar'**
  String get hbSearch;

  /// No description provided for @hbMatches.
  ///
  /// In es, this message translates to:
  /// **'Coincidencias'**
  String get hbMatches;

  /// No description provided for @hbYourContent.
  ///
  /// In es, this message translates to:
  /// **'Tu contenido'**
  String get hbYourContent;

  /// No description provided for @hbImportFile.
  ///
  /// In es, this message translates to:
  /// **'Importar archivo'**
  String get hbImportFile;

  /// No description provided for @hbExportAll.
  ///
  /// In es, this message translates to:
  /// **'Exportar todo'**
  String get hbExportAll;

  /// No description provided for @hbNoMatch.
  ///
  /// In es, this message translates to:
  /// **'Nada de tu contenido coincide con «{query}».'**
  String hbNoMatch(String query);

  /// No description provided for @hbResults.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 resultado} other{{count} resultados}}'**
  String hbResults(int count);

  /// No description provided for @hbFor.
  ///
  /// In es, this message translates to:
  /// **'para «{query}»'**
  String hbFor(String query);

  /// No description provided for @hbWorkshop.
  ///
  /// In es, this message translates to:
  /// **'Tu taller'**
  String get hbWorkshop;

  /// No description provided for @hbWorkshopIntro.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 entrada propia} other{{count} entradas propias}}. Todo lo que crees acá se suma al catálogo: aparece en la creación de personajes y en las fichas, igual que el contenido oficial.'**
  String hbWorkshopIntro(int count);

  /// No description provided for @hbCategories.
  ///
  /// In es, this message translates to:
  /// **'Categorías'**
  String get hbCategories;

  /// No description provided for @hbNothingYet.
  ///
  /// In es, this message translates to:
  /// **'Nada todavía.'**
  String get hbNothingYet;

  /// No description provided for @hbWorkshopEmpty.
  ///
  /// In es, this message translates to:
  /// **'Tu taller está vacío'**
  String get hbWorkshopEmpty;

  /// No description provided for @hbWorkshopEmptyBody.
  ///
  /// In es, this message translates to:
  /// **'Homebrew es contenido tuyo: un arma, un conjuro, una criatura. Se guarda en tu cuenta y se suma al catálogo, al lado del oficial. Armas, armaduras, objetos, conjuros, dotes, especies y trasfondos aparecen en la creación de personajes y en las fichas; las criaturas, en el Bestiario y en Combate.'**
  String get hbWorkshopEmptyBody;

  /// No description provided for @hbStartWeapon.
  ///
  /// In es, this message translates to:
  /// **'Empezar por un arma'**
  String get hbStartWeapon;

  /// No description provided for @hbImportAFile.
  ///
  /// In es, this message translates to:
  /// **'Importar un archivo'**
  String get hbImportAFile;

  /// No description provided for @hbDuplicateFromCatalog.
  ///
  /// In es, this message translates to:
  /// **'Duplicar del catálogo'**
  String get hbDuplicateFromCatalog;

  /// No description provided for @hbNothingIn.
  ///
  /// In es, this message translates to:
  /// **'Todavía no agregaste nada en {category}.'**
  String hbNothingIn(String category);

  /// No description provided for @hbDuplicateTitle.
  ///
  /// In es, this message translates to:
  /// **'Duplicar {title}'**
  String hbDuplicateTitle(String title);

  /// No description provided for @hbDeleteTooltip.
  ///
  /// In es, this message translates to:
  /// **'Borrar {title}'**
  String hbDeleteTooltip(String title);

  /// No description provided for @hbEffects.
  ///
  /// In es, this message translates to:
  /// **'Efectos'**
  String get hbEffects;

  /// No description provided for @hbRitual.
  ///
  /// In es, this message translates to:
  /// **'Ritual'**
  String get hbRitual;

  /// No description provided for @hbAvailableToCharacters.
  ///
  /// In es, this message translates to:
  /// **'Disponible para personajes'**
  String get hbAvailableToCharacters;

  /// No description provided for @hbKindWeapon.
  ///
  /// In es, this message translates to:
  /// **'el arma'**
  String get hbKindWeapon;

  /// No description provided for @hbKindArmor.
  ///
  /// In es, this message translates to:
  /// **'la armadura'**
  String get hbKindArmor;

  /// No description provided for @hbKindItem.
  ///
  /// In es, this message translates to:
  /// **'el objeto'**
  String get hbKindItem;

  /// No description provided for @hbKindFeat.
  ///
  /// In es, this message translates to:
  /// **'la dote'**
  String get hbKindFeat;

  /// No description provided for @hbKindSpecies.
  ///
  /// In es, this message translates to:
  /// **'la especie'**
  String get hbKindSpecies;

  /// No description provided for @hbKindBackground.
  ///
  /// In es, this message translates to:
  /// **'el trasfondo'**
  String get hbKindBackground;

  /// No description provided for @hbKindSpell.
  ///
  /// In es, this message translates to:
  /// **'el conjuro'**
  String get hbKindSpell;

  /// No description provided for @hbKindCreature.
  ///
  /// In es, this message translates to:
  /// **'la criatura'**
  String get hbKindCreature;

  /// No description provided for @hbDeleteTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Borrar {kind} «{name}»?'**
  String hbDeleteTitle(String kind, String name);

  /// No description provided for @hbNoUsers.
  ///
  /// In es, this message translates to:
  /// **'Ninguna de tus fichas lo está usando.'**
  String get hbNoUsers;

  /// No description provided for @hbUsers.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Lo usa 1 ficha:} other{Lo usan {count} fichas:}}'**
  String hbUsers(int count);

  /// No description provided for @hbUsersWarning.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Va a quedar con una advertencia en su ficha.} other{Van a quedar con una advertencia en sus fichas.}}'**
  String hbUsersWarning(int count);

  /// No description provided for @hbDeleted.
  ///
  /// In es, this message translates to:
  /// **'{name} se borró.'**
  String hbDeleted(String name);

  /// No description provided for @hbDuplicateDialog.
  ///
  /// In es, this message translates to:
  /// **'Duplicar {category}'**
  String hbDuplicateDialog(String category);

  /// No description provided for @hbSearchCatalog.
  ///
  /// In es, this message translates to:
  /// **'Buscar en el catálogo'**
  String get hbSearchCatalog;

  /// No description provided for @hbCatalogNoMatch.
  ///
  /// In es, this message translates to:
  /// **'Nada del catálogo coincide con «{query}».'**
  String hbCatalogNoMatch(String query);

  /// No description provided for @hbLeaveTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Salir sin guardar?'**
  String get hbLeaveTitle;

  /// No description provided for @hbLeaveBody.
  ///
  /// In es, this message translates to:
  /// **'Lo que escribiste en «{title}» se pierde.'**
  String hbLeaveBody(String title);

  /// No description provided for @hbKeepEditing.
  ///
  /// In es, this message translates to:
  /// **'Seguir editando'**
  String get hbKeepEditing;

  /// No description provided for @hbLeave.
  ///
  /// In es, this message translates to:
  /// **'Salir sin guardar'**
  String get hbLeave;

  /// No description provided for @hbFixFields.
  ///
  /// In es, this message translates to:
  /// **'No se guardó nada: revisá los campos marcados en rojo.'**
  String get hbFixFields;

  /// No description provided for @hbOptionalRule.
  ///
  /// In es, this message translates to:
  /// **'Lo demás es opcional'**
  String get hbOptionalRule;

  /// No description provided for @hbAlreadyChosen.
  ///
  /// In es, this message translates to:
  /// **'Lo que ya elegiste'**
  String get hbAlreadyChosen;

  /// No description provided for @hbNoNameYet.
  ///
  /// In es, this message translates to:
  /// **'Todavía sin nombre'**
  String get hbNoNameYet;

  /// No description provided for @hbGrantsNothing.
  ///
  /// In es, this message translates to:
  /// **'Todavía no concede nada.'**
  String get hbGrantsNothing;

  /// No description provided for @hbDiceRequired.
  ///
  /// In es, this message translates to:
  /// **'Escribí un dado, por ejemplo 1d8.'**
  String get hbDiceRequired;

  /// No description provided for @hbDiceInvalid.
  ///
  /// In es, this message translates to:
  /// **'Formato de dado inválido: se espera algo como 1d8.'**
  String get hbDiceInvalid;

  /// No description provided for @hbNumberRequired.
  ///
  /// In es, this message translates to:
  /// **'Escribí un número.'**
  String get hbNumberRequired;

  /// No description provided for @hbIntInvalid.
  ///
  /// In es, this message translates to:
  /// **'Tiene que ser un número entero.'**
  String get hbIntInvalid;

  /// No description provided for @hbRange.
  ///
  /// In es, this message translates to:
  /// **'Tiene que estar entre {min} y {max}.'**
  String hbRange(Object min, Object max);

  /// No description provided for @hbWeightRequired.
  ///
  /// In es, this message translates to:
  /// **'Escribí un peso, 0 si no cuenta.'**
  String get hbWeightRequired;

  /// No description provided for @hbNumberInvalid.
  ///
  /// In es, this message translates to:
  /// **'Tiene que ser un número.'**
  String get hbNumberInvalid;

  /// No description provided for @hbNegative.
  ///
  /// In es, this message translates to:
  /// **'No puede ser negativo.'**
  String get hbNegative;

  /// No description provided for @hbDamageType.
  ///
  /// In es, this message translates to:
  /// **'Tipo de daño'**
  String get hbDamageType;

  /// No description provided for @hbUnknownValue.
  ///
  /// In es, this message translates to:
  /// **'{value} (desconocido)'**
  String hbUnknownValue(String value);

  /// No description provided for @hbRangeLongMin.
  ///
  /// In es, this message translates to:
  /// **'No puede ser menor que el normal.'**
  String get hbRangeLongMin;

  /// No description provided for @hbNoMasteryRule.
  ///
  /// In es, this message translates to:
  /// **'Al que tiene el rasgo Maestría con armas no le suma nada.'**
  String get hbNoMasteryRule;

  /// No description provided for @hbNoRange.
  ///
  /// In es, this message translates to:
  /// **'Sin alcance'**
  String get hbNoRange;

  /// No description provided for @hbRangeFeet.
  ///
  /// In es, this message translates to:
  /// **'{normal}/{long} pies'**
  String hbRangeFeet(String normal, String long);

  /// No description provided for @hbProperty.
  ///
  /// In es, this message translates to:
  /// **'Propiedad'**
  String get hbProperty;

  /// No description provided for @hbNone.
  ///
  /// In es, this message translates to:
  /// **'ninguna'**
  String get hbNone;

  /// No description provided for @hbNoMasteryLower.
  ///
  /// In es, this message translates to:
  /// **'sin maestría'**
  String get hbNoMasteryLower;

  /// No description provided for @hbPreviewTitle.
  ///
  /// In es, this message translates to:
  /// **'Así queda en tu lista'**
  String get hbPreviewTitle;

  /// No description provided for @hbWeaponHint.
  ///
  /// In es, this message translates to:
  /// **'Tocá la categoría, el tipo de daño, una propiedad o la maestría para ver qué hace.'**
  String get hbWeaponHint;

  /// No description provided for @hbReqWeaponName.
  ///
  /// In es, this message translates to:
  /// **'Escribí el nombre del arma.'**
  String get hbReqWeaponName;

  /// No description provided for @hbDamageDie.
  ///
  /// In es, this message translates to:
  /// **'Dado de daño'**
  String get hbDamageDie;

  /// No description provided for @hbVersatile.
  ///
  /// In es, this message translates to:
  /// **'Dado versátil (p.ej. 1d10)'**
  String get hbVersatile;

  /// No description provided for @hbRangeNormal.
  ///
  /// In es, this message translates to:
  /// **'Alcance normal (pies)'**
  String get hbRangeNormal;

  /// No description provided for @hbRangeLong.
  ///
  /// In es, this message translates to:
  /// **'Alcance largo (pies)'**
  String get hbRangeLong;

  /// No description provided for @hbMasteryMagic.
  ///
  /// In es, this message translates to:
  /// **'Maestría y magia'**
  String get hbMasteryMagic;

  /// No description provided for @hbMagicBonus.
  ///
  /// In es, this message translates to:
  /// **'Bonificador mágico (+0 a +3)'**
  String get hbMagicBonus;

  /// No description provided for @hbLegendWeapon.
  ///
  /// In es, this message translates to:
  /// **'Descripción (la leyenda del arma)'**
  String get hbLegendWeapon;

  /// No description provided for @hbEconomy.
  ///
  /// In es, this message translates to:
  /// **'Economía'**
  String get hbEconomy;

  /// No description provided for @hbNotSet.
  ///
  /// In es, this message translates to:
  /// **'sin cargar'**
  String get hbNotSet;

  /// No description provided for @hbWeightLabel.
  ///
  /// In es, this message translates to:
  /// **'Peso en libras (0 si no cuenta)'**
  String get hbWeightLabel;

  /// No description provided for @hbPriceLabel.
  ///
  /// In es, this message translates to:
  /// **'Precio en piezas de cobre (1 po = 100)'**
  String get hbPriceLabel;

  /// No description provided for @hbLegend.
  ///
  /// In es, this message translates to:
  /// **'Leyenda'**
  String get hbLegend;

  /// No description provided for @hbLoaded.
  ///
  /// In es, this message translates to:
  /// **'cargada'**
  String get hbLoaded;

  /// No description provided for @hbArmorBaseAc.
  ///
  /// In es, this message translates to:
  /// **'CA base'**
  String get hbArmorBaseAc;

  /// No description provided for @hbNotFilled.
  ///
  /// In es, this message translates to:
  /// **'Sin cargar'**
  String get hbNotFilled;

  /// No description provided for @hbDexterity.
  ///
  /// In es, this message translates to:
  /// **'Destreza'**
  String get hbDexterity;

  /// No description provided for @hbAddsDex.
  ///
  /// In es, this message translates to:
  /// **'Suma Destreza'**
  String get hbAddsDex;

  /// No description provided for @hbNoDex.
  ///
  /// In es, this message translates to:
  /// **'Sin Destreza'**
  String get hbNoDex;

  /// No description provided for @hbDexCap.
  ///
  /// In es, this message translates to:
  /// **'Tope de Destreza'**
  String get hbDexCap;

  /// No description provided for @hbNoCap.
  ///
  /// In es, this message translates to:
  /// **'Sin tope'**
  String get hbNoCap;

  /// No description provided for @hbUpTo.
  ///
  /// In es, this message translates to:
  /// **'Hasta +{cap}'**
  String hbUpTo(String cap);

  /// No description provided for @hbDemand.
  ///
  /// In es, this message translates to:
  /// **'Exigencia'**
  String get hbDemand;

  /// No description provided for @hbNoStrReq.
  ///
  /// In es, this message translates to:
  /// **'Sin requisito de Fuerza'**
  String get hbNoStrReq;

  /// No description provided for @hbStrength.
  ///
  /// In es, this message translates to:
  /// **'Fuerza {score}'**
  String hbStrength(String score);

  /// No description provided for @hbStealthDisadv.
  ///
  /// In es, this message translates to:
  /// **'Sigilo con desventaja'**
  String get hbStealthDisadv;

  /// No description provided for @hbNoStealthDisadv.
  ///
  /// In es, this message translates to:
  /// **'Sin desventaja en Sigilo'**
  String get hbNoStealthDisadv;

  /// No description provided for @hbNoDexLower.
  ///
  /// In es, this message translates to:
  /// **'sin Destreza'**
  String get hbNoDexLower;

  /// No description provided for @hbFullDex.
  ///
  /// In es, this message translates to:
  /// **'Destreza entera'**
  String get hbFullDex;

  /// No description provided for @hbUpToLower.
  ///
  /// In es, this message translates to:
  /// **'hasta +{cap}'**
  String hbUpToLower(String cap);

  /// No description provided for @hbOnSheet.
  ///
  /// In es, this message translates to:
  /// **'En la ficha'**
  String get hbOnSheet;

  /// No description provided for @hbAcWithDex.
  ///
  /// In es, this message translates to:
  /// **'CA con DES +{dex}'**
  String hbAcWithDex(Object dex);

  /// No description provided for @hbArmorHint.
  ///
  /// In es, this message translates to:
  /// **'Tocá la categoría, la CA o cómo suma la Destreza para ver qué cambia.'**
  String get hbArmorHint;

  /// No description provided for @hbReqArmorName.
  ///
  /// In es, this message translates to:
  /// **'Escribí el nombre de la armadura.'**
  String get hbReqArmorName;

  /// No description provided for @hbShieldAc.
  ///
  /// In es, this message translates to:
  /// **'CA que suma'**
  String get hbShieldAc;

  /// No description provided for @hbHowDex.
  ///
  /// In es, this message translates to:
  /// **'Cómo suma la Destreza'**
  String get hbHowDex;

  /// No description provided for @hbAddsDexMod.
  ///
  /// In es, this message translates to:
  /// **'Suma modificador de DES'**
  String get hbAddsDexMod;

  /// No description provided for @hbDexCapLabel.
  ///
  /// In es, this message translates to:
  /// **'Tope de DES (vacío = sin tope)'**
  String get hbDexCapLabel;

  /// No description provided for @hbDemands.
  ///
  /// In es, this message translates to:
  /// **'Exigencias'**
  String get hbDemands;

  /// No description provided for @hbStrReqLabel.
  ///
  /// In es, this message translates to:
  /// **'Requisito de Fuerza (opcional)'**
  String get hbStrReqLabel;

  /// No description provided for @hbStealthLabel.
  ///
  /// In es, this message translates to:
  /// **'Desventaja en Sigilo'**
  String get hbStealthLabel;

  /// No description provided for @hbLegendArmor.
  ///
  /// In es, this message translates to:
  /// **'Descripción (la leyenda de la armadura)'**
  String get hbLegendArmor;

  /// No description provided for @hbNoneCap.
  ///
  /// In es, this message translates to:
  /// **'Ninguno'**
  String get hbNoneCap;

  /// No description provided for @hbMagic.
  ///
  /// In es, this message translates to:
  /// **'Magia'**
  String get hbMagic;

  /// No description provided for @hbNoAttunement.
  ///
  /// In es, this message translates to:
  /// **'Sin sintonización'**
  String get hbNoAttunement;

  /// No description provided for @hbEffect.
  ///
  /// In es, this message translates to:
  /// **'Efecto'**
  String get hbEffect;

  /// No description provided for @hbBaseItem.
  ///
  /// In es, this message translates to:
  /// **'Objeto base'**
  String get hbBaseItem;

  /// No description provided for @hbBonusValue.
  ///
  /// In es, this message translates to:
  /// **'Bonificador {value}'**
  String hbBonusValue(String value);

  /// No description provided for @hbMoreEffects.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 efecto más} other{{count} efectos más}}'**
  String hbMoreEffects(int count);

  /// No description provided for @hbNoneM.
  ///
  /// In es, this message translates to:
  /// **'ninguno'**
  String get hbNoneM;

  /// No description provided for @hbItem.
  ///
  /// In es, this message translates to:
  /// **'Objeto'**
  String get hbItem;

  /// No description provided for @hbItemHint.
  ///
  /// In es, this message translates to:
  /// **'Tocá la categoría, la rareza o un efecto para ver qué hace el objeto en la ficha.'**
  String get hbItemHint;

  /// No description provided for @hbReqItemName.
  ///
  /// In es, this message translates to:
  /// **'Escribí el nombre del objeto.'**
  String get hbReqItemName;

  /// No description provided for @hbWeightShort.
  ///
  /// In es, this message translates to:
  /// **'Peso (lb)'**
  String get hbWeightShort;

  /// No description provided for @hbPriceCp.
  ///
  /// In es, this message translates to:
  /// **'Precio (pc)'**
  String get hbPriceCp;

  /// No description provided for @hbMundaneLower.
  ///
  /// In es, this message translates to:
  /// **'mundano'**
  String get hbMundaneLower;

  /// No description provided for @hbRequiresAttunement.
  ///
  /// In es, this message translates to:
  /// **'Requiere sintonización'**
  String get hbRequiresAttunement;

  /// No description provided for @hbOnlyMagicAttune.
  ///
  /// In es, this message translates to:
  /// **'Solo los objetos mágicos se sintonizan.'**
  String get hbOnlyMagicAttune;

  /// No description provided for @hbEffectsEquipped.
  ///
  /// In es, this message translates to:
  /// **'Efectos mientras esté equipado'**
  String get hbEffectsEquipped;

  /// No description provided for @hbAcBonusLabel.
  ///
  /// In es, this message translates to:
  /// **'Bonificador a la Clase de Armadura'**
  String get hbAcBonusLabel;

  /// No description provided for @hbResistances.
  ///
  /// In es, this message translates to:
  /// **'Resistencias'**
  String get hbResistances;

  /// No description provided for @hbOtherEffects.
  ///
  /// In es, this message translates to:
  /// **'Otros efectos'**
  String get hbOtherEffects;

  /// No description provided for @hbMagicBonusShort.
  ///
  /// In es, this message translates to:
  /// **'Bonificador mágico'**
  String get hbMagicBonusShort;

  /// No description provided for @hbAllowedBases.
  ///
  /// In es, this message translates to:
  /// **'Bases permitidas'**
  String get hbAllowedBases;

  /// No description provided for @hbAnyBase.
  ///
  /// In es, this message translates to:
  /// **'Sin marcar ninguna, sirve cualquiera de la familia elegida.'**
  String get hbAnyBase;

  /// No description provided for @hbOnlyMarked.
  ///
  /// In es, this message translates to:
  /// **'Solo se va a poder usar lo que marques acá.'**
  String get hbOnlyMarked;

  /// No description provided for @hbDescription.
  ///
  /// In es, this message translates to:
  /// **'Descripción'**
  String get hbDescription;

  /// No description provided for @hbRepetition.
  ///
  /// In es, this message translates to:
  /// **'Repetición'**
  String get hbRepetition;

  /// No description provided for @hbOnce.
  ///
  /// In es, this message translates to:
  /// **'Una sola vez'**
  String get hbOnce;

  /// No description provided for @hbFeatPreview.
  ///
  /// In es, this message translates to:
  /// **'Así la ve el jugador'**
  String get hbFeatPreview;

  /// No description provided for @hbFeatNoDescription.
  ///
  /// In es, this message translates to:
  /// **'Sin descripción, el jugador solo ve lo que concede. Una línea que diga qué la hace distinta ayuda a elegirla.'**
  String get hbFeatNoDescription;

  /// No description provided for @hbFeatHint.
  ///
  /// In es, this message translates to:
  /// **'Tocá la categoría para ver quién puede tomar la dote.'**
  String get hbFeatHint;

  /// No description provided for @hbReqFeatName.
  ///
  /// In es, this message translates to:
  /// **'Escribí el nombre de la dote.'**
  String get hbReqFeatName;

  /// No description provided for @hbFeatDistinct.
  ///
  /// In es, this message translates to:
  /// **'Qué la hace distinta'**
  String get hbFeatDistinct;

  /// No description provided for @hbGrants.
  ///
  /// In es, this message translates to:
  /// **'Qué concede'**
  String get hbGrants;

  /// No description provided for @hbPrereqRepeat.
  ///
  /// In es, this message translates to:
  /// **'Requisitos y repetición'**
  String get hbPrereqRepeat;

  /// No description provided for @hbNoPrereq.
  ///
  /// In es, this message translates to:
  /// **'sin requisitos'**
  String get hbNoPrereq;

  /// No description provided for @hbWithPrereq.
  ///
  /// In es, this message translates to:
  /// **'con requisitos'**
  String get hbWithPrereq;

  /// No description provided for @hbRepeatableLower.
  ///
  /// In es, this message translates to:
  /// **'repetible'**
  String get hbRepeatableLower;

  /// No description provided for @hbOnceLower.
  ///
  /// In es, this message translates to:
  /// **'una vez'**
  String get hbOnceLower;

  /// No description provided for @hbRepeatSwitch.
  ///
  /// In es, this message translates to:
  /// **'Se puede tomar más de una vez'**
  String get hbRepeatSwitch;

  /// No description provided for @hbKeepPrereq.
  ///
  /// In es, this message translates to:
  /// **'Conserva el requisito de la dote original.'**
  String get hbKeepPrereq;

  /// No description provided for @hbEffectsCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{sin efectos} =1{1 efecto} other{{count} efectos}}'**
  String hbEffectsCount(int count);

  /// No description provided for @hbNoType.
  ///
  /// In es, this message translates to:
  /// **'Sin tipo'**
  String get hbNoType;

  /// No description provided for @hbAmongWhichChooses.
  ///
  /// In es, this message translates to:
  /// **'Entre cuáles elige'**
  String get hbAmongWhichChooses;

  /// No description provided for @hbSizeToChoose.
  ///
  /// In es, this message translates to:
  /// **'Tamaño a elegir'**
  String get hbSizeToChoose;

  /// No description provided for @hbAmongAll.
  ///
  /// In es, this message translates to:
  /// **'{count} entre todas'**
  String hbAmongAll(Object count);

  /// No description provided for @hbAmongN.
  ///
  /// In es, this message translates to:
  /// **'{count} entre {n}'**
  String hbAmongN(Object count, Object n);

  /// No description provided for @hbRacePreview.
  ///
  /// In es, this message translates to:
  /// **'Cómo se va a ver al crear un personaje'**
  String get hbRacePreview;

  /// No description provided for @hbRaceHint.
  ///
  /// In es, this message translates to:
  /// **'Tocá el tipo, el tamaño, la velocidad o las habilidades para ver qué implican.'**
  String get hbRaceHint;

  /// No description provided for @hbReqRaceName.
  ///
  /// In es, this message translates to:
  /// **'Escribí el nombre de la especie.'**
  String get hbReqRaceName;

  /// No description provided for @hbSpeedFeet.
  ///
  /// In es, this message translates to:
  /// **'Velocidad (pies)'**
  String get hbSpeedFeet;

  /// No description provided for @hbPresentation.
  ///
  /// In es, this message translates to:
  /// **'Presentación'**
  String get hbPresentation;

  /// No description provided for @hbTaglineLower.
  ///
  /// In es, this message translates to:
  /// **'lema'**
  String get hbTaglineLower;

  /// No description provided for @hbDescriptionLower.
  ///
  /// In es, this message translates to:
  /// **'descripción'**
  String get hbDescriptionLower;

  /// No description provided for @hbTaglineLabel.
  ///
  /// In es, this message translates to:
  /// **'Lema (una línea, se ve al elegirla)'**
  String get hbTaglineLabel;

  /// No description provided for @hbHowMany.
  ///
  /// In es, this message translates to:
  /// **'Cuántas elige'**
  String get hbHowMany;

  /// No description provided for @hbAmongWhich.
  ///
  /// In es, this message translates to:
  /// **'Entre cuáles'**
  String get hbAmongWhich;

  /// No description provided for @hbOnlySize.
  ///
  /// In es, this message translates to:
  /// **'solo {size}'**
  String hbOnlySize(String size);

  /// No description provided for @hbAllThree.
  ///
  /// In es, this message translates to:
  /// **'Las tres del aumento'**
  String get hbAllThree;

  /// No description provided for @hbNoOriginFeat.
  ///
  /// In es, this message translates to:
  /// **'Sin dote de origen'**
  String get hbNoOriginFeat;

  /// No description provided for @hbNoneF.
  ///
  /// In es, this message translates to:
  /// **'Ninguna'**
  String get hbNoneF;

  /// No description provided for @hbIncrease.
  ///
  /// In es, this message translates to:
  /// **'Aumento'**
  String get hbIncrease;

  /// No description provided for @hbBgHint.
  ///
  /// In es, this message translates to:
  /// **'Tocá las características o la dote de origen para ver qué le dan al personaje.'**
  String get hbBgHint;

  /// No description provided for @hbReqBgName.
  ///
  /// In es, this message translates to:
  /// **'Escribí el nombre del trasfondo.'**
  String get hbReqBgName;

  /// No description provided for @hbThreeAbilities.
  ///
  /// In es, this message translates to:
  /// **'Elegí exactamente tres características.'**
  String get hbThreeAbilities;

  /// No description provided for @hbPick3.
  ///
  /// In es, this message translates to:
  /// **'Características · elegí 3'**
  String get hbPick3;

  /// No description provided for @hbNoneParen.
  ///
  /// In es, this message translates to:
  /// **'(ninguna)'**
  String get hbNoneParen;

  /// No description provided for @hbTaglineLabelM.
  ///
  /// In es, this message translates to:
  /// **'Lema (una línea, se ve al elegirlo)'**
  String get hbTaglineLabelM;

  /// No description provided for @hbExtraEffects.
  ///
  /// In es, this message translates to:
  /// **'Efectos adicionales'**
  String get hbExtraEffects;

  /// No description provided for @classWizard.
  ///
  /// In es, this message translates to:
  /// **'Mago'**
  String get classWizard;

  /// No description provided for @classSorcerer.
  ///
  /// In es, this message translates to:
  /// **'Hechicero'**
  String get classSorcerer;

  /// No description provided for @classCleric.
  ///
  /// In es, this message translates to:
  /// **'Clérigo'**
  String get classCleric;

  /// No description provided for @classDruid.
  ///
  /// In es, this message translates to:
  /// **'Druida'**
  String get classDruid;

  /// No description provided for @classBard.
  ///
  /// In es, this message translates to:
  /// **'Bardo'**
  String get classBard;

  /// No description provided for @classWarlock.
  ///
  /// In es, this message translates to:
  /// **'Brujo'**
  String get classWarlock;

  /// No description provided for @classPaladin.
  ///
  /// In es, this message translates to:
  /// **'Paladín'**
  String get classPaladin;

  /// No description provided for @classRanger.
  ///
  /// In es, this message translates to:
  /// **'Explorador'**
  String get classRanger;

  /// No description provided for @classArtificer.
  ///
  /// In es, this message translates to:
  /// **'Artífice'**
  String get classArtificer;

  /// No description provided for @compVerbal.
  ///
  /// In es, this message translates to:
  /// **'Verbal'**
  String get compVerbal;

  /// No description provided for @compSomatic.
  ///
  /// In es, this message translates to:
  /// **'Somático'**
  String get compSomatic;

  /// No description provided for @compMaterial.
  ///
  /// In es, this message translates to:
  /// **'Material'**
  String get compMaterial;

  /// No description provided for @hbSchool.
  ///
  /// In es, this message translates to:
  /// **'Escuela'**
  String get hbSchool;

  /// No description provided for @hbCastingTime.
  ///
  /// In es, this message translates to:
  /// **'Tiempo de lanzamiento'**
  String get hbCastingTime;

  /// No description provided for @hbClassLists.
  ///
  /// In es, this message translates to:
  /// **'Listas de clase'**
  String get hbClassLists;

  /// No description provided for @hbComponent.
  ///
  /// In es, this message translates to:
  /// **'Componente'**
  String get hbComponent;

  /// No description provided for @hbSpell.
  ///
  /// In es, this message translates to:
  /// **'Conjuro'**
  String get hbSpell;

  /// No description provided for @hbSpellPreview.
  ///
  /// In es, this message translates to:
  /// **'Cómo se va a ver en la ficha'**
  String get hbSpellPreview;

  /// No description provided for @hbSpellHint.
  ///
  /// In es, this message translates to:
  /// **'Tocá el nivel, la escuela, el tiempo de lanzamiento o un componente para ver qué implica.'**
  String get hbSpellHint;

  /// No description provided for @hbReqSpellName.
  ///
  /// In es, this message translates to:
  /// **'Escribí el nombre del conjuro.'**
  String get hbReqSpellName;

  /// No description provided for @hbNoSchool.
  ///
  /// In es, this message translates to:
  /// **'Sin escuela'**
  String get hbNoSchool;

  /// No description provided for @hbRangeExample.
  ///
  /// In es, this message translates to:
  /// **'Alcance (p.ej. 60 pies)'**
  String get hbRangeExample;

  /// No description provided for @hbMaterialExample.
  ///
  /// In es, this message translates to:
  /// **'Material (p.ej. una pizca de ceniza)'**
  String get hbMaterialExample;

  /// No description provided for @hbConcRitual.
  ///
  /// In es, this message translates to:
  /// **'Concentración y ritual'**
  String get hbConcRitual;

  /// No description provided for @hbConcentrationLower.
  ///
  /// In es, this message translates to:
  /// **'concentración'**
  String get hbConcentrationLower;

  /// No description provided for @hbRitualLower.
  ///
  /// In es, this message translates to:
  /// **'ritual'**
  String get hbRitualLower;

  /// No description provided for @hbSpellDoes.
  ///
  /// In es, this message translates to:
  /// **'Qué hace el conjuro'**
  String get hbSpellDoes;

  /// No description provided for @hbHitDice.
  ///
  /// In es, this message translates to:
  /// **'Dados de golpe'**
  String get hbHitDice;

  /// No description provided for @hbHitDiceRule.
  ///
  /// In es, this message translates to:
  /// **'Con dados de golpe cargados, al sumarla a un combate se puede pedir que cada copia tire los suyos.'**
  String get hbHitDiceRule;

  /// No description provided for @hbChallenge.
  ///
  /// In es, this message translates to:
  /// **'Desafío'**
  String get hbChallenge;

  /// No description provided for @hbNoCr.
  ///
  /// In es, this message translates to:
  /// **'Sin VD'**
  String get hbNoCr;

  /// No description provided for @hbCrValue.
  ///
  /// In es, this message translates to:
  /// **'VD {value}'**
  String hbCrValue(String value);

  /// No description provided for @hbOutOfCombat.
  ///
  /// In es, this message translates to:
  /// **'Fuera de combate'**
  String get hbOutOfCombat;

  /// No description provided for @hbAlsoCharacters.
  ///
  /// In es, this message translates to:
  /// **'También para personajes'**
  String get hbAlsoCharacters;

  /// No description provided for @hbOnlyYourCombats.
  ///
  /// In es, this message translates to:
  /// **'Solo en tus combates'**
  String get hbOnlyYourCombats;

  /// No description provided for @hbAvailableRule.
  ///
  /// In es, this message translates to:
  /// **'Hoy solo lo mira el pozo de Forma Salvaje: una bestia con valor de desafío puede aparecer entre las formas del druida. Apagado, la criatura vive únicamente en tus combates.'**
  String get hbAvailableRule;

  /// No description provided for @hbAttackBonus.
  ///
  /// In es, this message translates to:
  /// **'Bonificador de ataque'**
  String get hbAttackBonus;

  /// No description provided for @hbWhenUsed.
  ///
  /// In es, this message translates to:
  /// **'Cuándo se usa'**
  String get hbWhenUsed;

  /// No description provided for @hbCreature.
  ///
  /// In es, this message translates to:
  /// **'Criatura'**
  String get hbCreature;

  /// No description provided for @hbCreaturePreview.
  ///
  /// In es, this message translates to:
  /// **'Cómo se va a ver en el Bestiario'**
  String get hbCreaturePreview;

  /// No description provided for @hbCreatureHint.
  ///
  /// In es, this message translates to:
  /// **'Tocá el tipo, el tamaño o una acción para ver qué cambia en la mesa.'**
  String get hbCreatureHint;

  /// No description provided for @hbReqCreatureName.
  ///
  /// In es, this message translates to:
  /// **'Escribí el nombre de la criatura.'**
  String get hbReqCreatureName;

  /// No description provided for @hbSpeedHint.
  ///
  /// In es, this message translates to:
  /// **'p.ej. 30 pies, volar 60 pies'**
  String get hbSpeedHint;

  /// No description provided for @hbWillRead.
  ///
  /// In es, this message translates to:
  /// **'Se va a leer «{kind}».'**
  String hbWillRead(String kind);

  /// No description provided for @hbHitDiceOptional.
  ///
  /// In es, this message translates to:
  /// **'Dados de golpe (opcional)'**
  String get hbHitDiceOptional;

  /// No description provided for @hbDiceExample.
  ///
  /// In es, this message translates to:
  /// **'p.ej. 2d6 + 2'**
  String get hbDiceExample;

  /// No description provided for @hbProfile.
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get hbProfile;

  /// No description provided for @hbCrExample.
  ///
  /// In es, this message translates to:
  /// **'p.ej. 1/4 o 5'**
  String get hbCrExample;

  /// No description provided for @hbInitHint.
  ///
  /// In es, this message translates to:
  /// **'Vacío: el mod. de DES'**
  String get hbInitHint;

  /// No description provided for @hbPassiveOptional.
  ///
  /// In es, this message translates to:
  /// **'Percepción pasiva (opcional)'**
  String get hbPassiveOptional;

  /// No description provided for @hbPerRound.
  ///
  /// In es, this message translates to:
  /// **'Por ronda'**
  String get hbPerRound;

  /// No description provided for @hbSensesHint.
  ///
  /// In es, this message translates to:
  /// **'p.ej. visión en la oscuridad 60 pies'**
  String get hbSensesHint;

  /// No description provided for @hbDefenses.
  ///
  /// In es, this message translates to:
  /// **'Resistencias, inmunidades y vulnerabilidades'**
  String get hbDefenses;

  /// No description provided for @hbNoTraits.
  ///
  /// In es, this message translates to:
  /// **'sin rasgos'**
  String get hbNoTraits;

  /// No description provided for @hbTrait.
  ///
  /// In es, this message translates to:
  /// **'Rasgo'**
  String get hbTrait;

  /// No description provided for @hbReqTraitName.
  ///
  /// In es, this message translates to:
  /// **'Escribí el nombre del rasgo.'**
  String get hbReqTraitName;

  /// No description provided for @hbAddTrait.
  ///
  /// In es, this message translates to:
  /// **'Agregar rasgo'**
  String get hbAddTrait;

  /// No description provided for @hbActionsCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{sin acciones} =1{1 acción} other{{count} acciones}}'**
  String hbActionsCount(int count);

  /// No description provided for @hbAddAction.
  ///
  /// In es, this message translates to:
  /// **'Agregar acción'**
  String get hbAddAction;

  /// No description provided for @hbAlsoCharactersLower.
  ///
  /// In es, this message translates to:
  /// **'también para personajes'**
  String get hbAlsoCharactersLower;

  /// No description provided for @hbOnlyYourCombatsLower.
  ///
  /// In es, this message translates to:
  /// **'solo en tus combates'**
  String get hbOnlyYourCombatsLower;

  /// No description provided for @hbAvailableSwitch.
  ///
  /// In es, this message translates to:
  /// **'Disponible en la construcción de personajes'**
  String get hbAvailableSwitch;

  /// No description provided for @hbReqActionName.
  ///
  /// In es, this message translates to:
  /// **'Escribí el nombre de la acción.'**
  String get hbReqActionName;

  /// No description provided for @hbAttackBonusLabel.
  ///
  /// In es, this message translates to:
  /// **'Bonificador de ataque (vacío = no es ataque)'**
  String get hbAttackBonusLabel;

  /// No description provided for @hbReachLabel.
  ///
  /// In es, this message translates to:
  /// **'Alcance (p.ej. 5 pies)'**
  String get hbReachLabel;

  /// No description provided for @hbDamageLabel.
  ///
  /// In es, this message translates to:
  /// **'Daño (p.ej. 1d8 + 3)'**
  String get hbDamageLabel;

  /// No description provided for @hbNoDamage.
  ///
  /// In es, this message translates to:
  /// **'Sin daño'**
  String get hbNoDamage;

  /// No description provided for @hbActionDescription.
  ///
  /// In es, this message translates to:
  /// **'Descripción (lo que pasa además del daño)'**
  String get hbActionDescription;

  /// No description provided for @hbCrInvalid.
  ///
  /// In es, this message translates to:
  /// **'Se espera un número o una fracción, como 1/4 o 5.'**
  String get hbCrInvalid;

  /// No description provided for @hbHitDiceInvalid.
  ///
  /// In es, this message translates to:
  /// **'Formato inválido: se espera algo como 2d6 + 2.'**
  String get hbHitDiceInvalid;

  /// No description provided for @effNone.
  ///
  /// In es, this message translates to:
  /// **'Sin efectos.'**
  String get effNone;

  /// No description provided for @effRemove.
  ///
  /// In es, this message translates to:
  /// **'Quitar efecto'**
  String get effRemove;

  /// No description provided for @effAdd.
  ///
  /// In es, this message translates to:
  /// **'Agregar efecto'**
  String get effAdd;

  /// No description provided for @effKindAbilityBonus.
  ///
  /// In es, this message translates to:
  /// **'Bonificador a característica'**
  String get effKindAbilityBonus;

  /// No description provided for @effKindSetAbility.
  ///
  /// In es, this message translates to:
  /// **'Fijar una característica'**
  String get effKindSetAbility;

  /// No description provided for @effKindHpPerLevel.
  ///
  /// In es, this message translates to:
  /// **'PG máx por nivel'**
  String get effKindHpPerLevel;

  /// No description provided for @effKindHpFlat.
  ///
  /// In es, this message translates to:
  /// **'PG máx, una vez'**
  String get effKindHpFlat;

  /// No description provided for @effKindAcBonus.
  ///
  /// In es, this message translates to:
  /// **'Bonificador a la CA'**
  String get effKindAcBonus;

  /// No description provided for @effKindInitiative.
  ///
  /// In es, this message translates to:
  /// **'Bonificador a la iniciativa'**
  String get effKindInitiative;

  /// No description provided for @effKindSpeedBonus.
  ///
  /// In es, this message translates to:
  /// **'Bonificador de velocidad'**
  String get effKindSpeedBonus;

  /// No description provided for @effKindSetSpeed.
  ///
  /// In es, this message translates to:
  /// **'Fijar la velocidad'**
  String get effKindSetSpeed;

  /// No description provided for @effKindSkillProf.
  ///
  /// In es, this message translates to:
  /// **'Competencia en habilidad'**
  String get effKindSkillProf;

  /// No description provided for @effKindSaveProf.
  ///
  /// In es, this message translates to:
  /// **'Competencia en salvación'**
  String get effKindSaveProf;

  /// No description provided for @effKindSaveBonus.
  ///
  /// In es, this message translates to:
  /// **'Bonificador a las salvaciones'**
  String get effKindSaveBonus;

  /// No description provided for @effKindWeaponProf.
  ///
  /// In es, this message translates to:
  /// **'Competencia con armas'**
  String get effKindWeaponProf;

  /// No description provided for @effKindArmorProf.
  ///
  /// In es, this message translates to:
  /// **'Competencia con armadura'**
  String get effKindArmorProf;

  /// No description provided for @effKindToolProf.
  ///
  /// In es, this message translates to:
  /// **'Competencia con herramienta'**
  String get effKindToolProf;

  /// No description provided for @effLanguage.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get effLanguage;

  /// No description provided for @effKindResistance.
  ///
  /// In es, this message translates to:
  /// **'Resistencia a daño'**
  String get effKindResistance;

  /// No description provided for @effKindImmunity.
  ///
  /// In es, this message translates to:
  /// **'Inmunidad a daño'**
  String get effKindImmunity;

  /// No description provided for @effKindGrantSpell.
  ///
  /// In es, this message translates to:
  /// **'Conceder un conjuro'**
  String get effKindGrantSpell;

  /// No description provided for @effKindAlwaysPrepared.
  ///
  /// In es, this message translates to:
  /// **'Conjuro siempre preparado'**
  String get effKindAlwaysPrepared;

  /// No description provided for @effKindSpellList.
  ///
  /// In es, this message translates to:
  /// **'Sumar un conjuro a tu lista'**
  String get effKindSpellList;

  /// No description provided for @effKindGrantFeat.
  ///
  /// In es, this message translates to:
  /// **'Conceder una dote'**
  String get effKindGrantFeat;

  /// No description provided for @effKindPassive.
  ///
  /// In es, this message translates to:
  /// **'Rasgo pasivo'**
  String get effKindPassive;

  /// No description provided for @effUnitFeet.
  ///
  /// In es, this message translates to:
  /// **'Pies'**
  String get effUnitFeet;

  /// No description provided for @effUnitRangeFeet.
  ///
  /// In es, this message translates to:
  /// **'Alcance en pies'**
  String get effUnitRangeFeet;

  /// No description provided for @effUnitValue.
  ///
  /// In es, this message translates to:
  /// **'Valor'**
  String get effUnitValue;

  /// No description provided for @effAddsProfBonus.
  ///
  /// In es, this message translates to:
  /// **'Suma el bonificador por competencia'**
  String get effAddsProfBonus;

  /// No description provided for @effSkill.
  ///
  /// In es, this message translates to:
  /// **'Habilidad'**
  String get effSkill;

  /// No description provided for @effHowUsed.
  ///
  /// In es, this message translates to:
  /// **'Cómo se usa'**
  String get effHowUsed;

  /// No description provided for @effCastAbility.
  ///
  /// In es, this message translates to:
  /// **'Característica para lanzarlo'**
  String get effCastAbility;

  /// No description provided for @effPlayerChoice.
  ///
  /// In es, this message translates to:
  /// **'A elección del jugador'**
  String get effPlayerChoice;

  /// No description provided for @effTraitName.
  ///
  /// In es, this message translates to:
  /// **'Nombre del rasgo'**
  String get effTraitName;

  /// No description provided for @effSpellLevel.
  ///
  /// In es, this message translates to:
  /// **'{name} (nivel {level})'**
  String effSpellLevel(String name, Object level);

  /// No description provided for @effAbility.
  ///
  /// In es, this message translates to:
  /// **'Característica'**
  String get effAbility;

  /// No description provided for @dmCampaignNameRequired.
  ///
  /// In es, this message translates to:
  /// **'Poné un nombre para guardarla.'**
  String get dmCampaignNameRequired;

  /// No description provided for @dmCampaignName.
  ///
  /// In es, this message translates to:
  /// **'Nombre de la campaña'**
  String get dmCampaignName;

  /// No description provided for @dmPremise.
  ///
  /// In es, this message translates to:
  /// **'Premisa'**
  String get dmPremise;

  /// No description provided for @dmPremiseHint.
  ///
  /// In es, this message translates to:
  /// **'El conflicto que pone esta historia en marcha…'**
  String get dmPremiseHint;

  /// No description provided for @dmNoteTitleRequired.
  ///
  /// In es, this message translates to:
  /// **'Poné un título para guardarla.'**
  String get dmNoteTitleRequired;

  /// No description provided for @dmChapter.
  ///
  /// In es, this message translates to:
  /// **'Capítulo'**
  String get dmChapter;

  /// No description provided for @dmNoteTitleHelper.
  ///
  /// In es, this message translates to:
  /// **'Es lo que se ve en el listado y al buscar.'**
  String get dmNoteTitleHelper;

  /// No description provided for @dmChapterNameRequired.
  ///
  /// In es, this message translates to:
  /// **'Poné un nombre para guardarlo.'**
  String get dmChapterNameRequired;

  /// No description provided for @dmChapterName.
  ///
  /// In es, this message translates to:
  /// **'Nombre del capítulo'**
  String get dmChapterName;

  /// No description provided for @dmChapterGoal.
  ///
  /// In es, this message translates to:
  /// **'Objetivo del capítulo'**
  String get dmChapterGoal;

  /// No description provided for @dmChapterGoalHint.
  ///
  /// In es, this message translates to:
  /// **'Qué debería lograr o descubrir la mesa…'**
  String get dmChapterGoalHint;

  /// No description provided for @dmChapterGoalHelper.
  ///
  /// In es, this message translates to:
  /// **'Una guía breve; el relato va en el Cuaderno.'**
  String get dmChapterGoalHelper;

  /// No description provided for @dmOnCloseCarry.
  ///
  /// In es, this message translates to:
  /// **'Al cerrarlo se llevan'**
  String get dmOnCloseCarry;

  /// No description provided for @dmOneLevel.
  ///
  /// In es, this message translates to:
  /// **'Un nivel'**
  String get dmOneLevel;

  /// No description provided for @dmLevelUpNote.
  ///
  /// In es, this message translates to:
  /// **'La subida la hace cada jugador en su ficha.'**
  String get dmLevelUpNote;

  /// No description provided for @dmGoldEach.
  ///
  /// In es, this message translates to:
  /// **'Oro para cada personaje'**
  String get dmGoldEach;

  /// No description provided for @dmGoldHelper.
  ///
  /// In es, this message translates to:
  /// **'Ya repartido: la app no divide el botín.'**
  String get dmGoldHelper;

  /// No description provided for @dmItems.
  ///
  /// In es, this message translates to:
  /// **'Ítems'**
  String get dmItems;

  /// No description provided for @dmItemsHint.
  ///
  /// In es, this message translates to:
  /// **'Uno por línea…'**
  String get dmItemsHint;

  /// No description provided for @dmItemsHelper.
  ///
  /// In es, this message translates to:
  /// **'Se los anota cada jugador en su inventario.'**
  String get dmItemsHelper;

  /// No description provided for @dmEffectsOf.
  ///
  /// In es, this message translates to:
  /// **'Efectos de {name}'**
  String dmEffectsOf(String name);

  /// No description provided for @dmNoteEffect.
  ///
  /// In es, this message translates to:
  /// **'Anotar un efecto'**
  String get dmNoteEffect;

  /// No description provided for @dmNoteEffectHint.
  ///
  /// In es, this message translates to:
  /// **'Marcado por el pícaro…'**
  String get dmNoteEffectHint;

  /// No description provided for @dmRemoveTag.
  ///
  /// In es, this message translates to:
  /// **'Sacar «{tag}»'**
  String dmRemoveTag(String tag);

  /// No description provided for @dmBookConditions.
  ///
  /// In es, this message translates to:
  /// **'Condiciones del libro'**
  String get dmBookConditions;

  /// No description provided for @dmEffectsArePrivate.
  ///
  /// In es, this message translates to:
  /// **'Los efectos son tuyos: al jugador no le llega nada, se lo decís en la mesa.'**
  String get dmEffectsArePrivate;

  /// No description provided for @dmRollInitiative.
  ///
  /// In es, this message translates to:
  /// **'Tirar iniciativa'**
  String get dmRollInitiative;

  /// No description provided for @dmPlayers.
  ///
  /// In es, this message translates to:
  /// **'Jugadores'**
  String get dmPlayers;

  /// No description provided for @dmNoPlayers.
  ///
  /// In es, this message translates to:
  /// **'Ningún jugador.'**
  String get dmNoPlayers;

  /// No description provided for @dmMonstersAndNpcs.
  ///
  /// In es, this message translates to:
  /// **'Monstruos y PNJ'**
  String get dmMonstersAndNpcs;

  /// No description provided for @dmNoMonstersOrNpcs.
  ///
  /// In es, this message translates to:
  /// **'Ningún monstruo ni PNJ.'**
  String get dmNoMonstersOrNpcs;

  /// No description provided for @dmRoundOneStarts.
  ///
  /// In es, this message translates to:
  /// **'Al confirmar arranca la ronda 1.'**
  String get dmRoundOneStarts;

  /// No description provided for @dmInitiativeMissing.
  ///
  /// In es, this message translates to:
  /// **'Falta la iniciativa de {names}. Si alguien no vino, sacalo del combate: cuando llegue se suma con su tirada.'**
  String dmInitiativeMissing(String names);

  /// No description provided for @dmStart.
  ///
  /// In es, this message translates to:
  /// **'Empezar'**
  String get dmStart;

  /// No description provided for @evtLinked.
  ///
  /// In es, this message translates to:
  /// **'{character} se sumó a la campaña {campaign}.'**
  String evtLinked(String character, String campaign);

  /// No description provided for @evtUnlinkedByDm.
  ///
  /// In es, this message translates to:
  /// **'{character} ya no forma parte de {campaign}.'**
  String evtUnlinkedByDm(String character, String campaign);

  /// No description provided for @evtUnlinkedByOwner.
  ///
  /// In es, this message translates to:
  /// **'{character} salió de tu campaña {campaign}.'**
  String evtUnlinkedByOwner(String character, String campaign);

  /// No description provided for @evtDeletedByOwner.
  ///
  /// In es, this message translates to:
  /// **'{character} ya no está disponible en {campaign}.'**
  String evtDeletedByOwner(String character, String campaign);

  /// No description provided for @evtInspiration.
  ///
  /// In es, this message translates to:
  /// **'El DM te concedió Inspiración Heroica en {campaign}. Marcala en la ficha de {character}.'**
  String evtInspiration(String campaign, String character);

  /// No description provided for @evtChapterDone.
  ///
  /// In es, this message translates to:
  /// **'{character} terminó el capítulo {chapter} en {campaign}.'**
  String evtChapterDone(String character, String chapter, String campaign);

  /// No description provided for @evtTakes.
  ///
  /// In es, this message translates to:
  /// **'Se lleva {rewards}.'**
  String evtTakes(String rewards);

  /// No description provided for @evtCanLevelUp.
  ///
  /// In es, this message translates to:
  /// **'Podés subir de nivel.'**
  String get evtCanLevelUp;

  /// No description provided for @evtSomeCharacter.
  ///
  /// In es, this message translates to:
  /// **'Un personaje'**
  String get evtSomeCharacter;

  /// No description provided for @evtSomeChapter.
  ///
  /// In es, this message translates to:
  /// **'Un capítulo'**
  String get evtSomeChapter;

  /// No description provided for @evtSomeCampaign.
  ///
  /// In es, this message translates to:
  /// **'Una campaña'**
  String get evtSomeCampaign;

  /// No description provided for @evtQuoted.
  ///
  /// In es, this message translates to:
  /// **'«{text}»'**
  String evtQuoted(String text);

  /// No description provided for @sideAlly.
  ///
  /// In es, this message translates to:
  /// **'Aliado'**
  String get sideAlly;

  /// No description provided for @sideEnemy.
  ///
  /// In es, this message translates to:
  /// **'Enemigo'**
  String get sideEnemy;

  /// No description provided for @sideNeutral.
  ///
  /// In es, this message translates to:
  /// **'Neutral'**
  String get sideNeutral;

  /// No description provided for @kindPlayer.
  ///
  /// In es, this message translates to:
  /// **'Jugador'**
  String get kindPlayer;

  /// No description provided for @kindMonster.
  ///
  /// In es, this message translates to:
  /// **'Monstruo'**
  String get kindMonster;

  /// No description provided for @kindNpc.
  ///
  /// In es, this message translates to:
  /// **'PNJ'**
  String get kindNpc;

  /// No description provided for @dmNpcsSection.
  ///
  /// In es, this message translates to:
  /// **'PNJ'**
  String get dmNpcsSection;

  /// No description provided for @npcKindNone.
  ///
  /// In es, this message translates to:
  /// **'Sin estadísticas'**
  String get npcKindNone;

  /// No description provided for @npcKindBlock.
  ///
  /// In es, this message translates to:
  /// **'Bloque propio'**
  String get npcKindBlock;

  /// No description provided for @npcKindCharacter.
  ///
  /// In es, this message translates to:
  /// **'Ficha de personaje'**
  String get npcKindCharacter;

  /// No description provided for @npcAlive.
  ///
  /// In es, this message translates to:
  /// **'Vivo'**
  String get npcAlive;

  /// No description provided for @npcDead.
  ///
  /// In es, this message translates to:
  /// **'Muerto'**
  String get npcDead;

  /// No description provided for @npcUnknown.
  ///
  /// In es, this message translates to:
  /// **'Desconocido'**
  String get npcUnknown;

  /// No description provided for @npcBlockLine.
  ///
  /// In es, this message translates to:
  /// **'{base} · CA {ac} · PG {hp}'**
  String npcBlockLine(String base, String ac, String hp);

  /// No description provided for @npcCharacterLine.
  ///
  /// In es, this message translates to:
  /// **'Ficha de personaje · {classes}'**
  String npcCharacterLine(String classes);

  /// No description provided for @npcNew.
  ///
  /// In es, this message translates to:
  /// **'Nuevo PNJ'**
  String get npcNew;

  /// No description provided for @npcWhichSheet.
  ///
  /// In es, this message translates to:
  /// **'¿Qué ficha lleva?'**
  String get npcWhichSheet;

  /// No description provided for @npcNewNone.
  ///
  /// In es, this message translates to:
  /// **'PNJ sin estadísticas'**
  String get npcNewNone;

  /// No description provided for @npcNewBlock.
  ///
  /// In es, this message translates to:
  /// **'PNJ con bloque'**
  String get npcNewBlock;

  /// No description provided for @npcNewCharacter.
  ///
  /// In es, this message translates to:
  /// **'Personaje jugable'**
  String get npcNewCharacter;

  /// No description provided for @npcNewNoneHint.
  ///
  /// In es, this message translates to:
  /// **'Solo nombre, trasfondo y notas. El tabernero, el alcalde.'**
  String get npcNewNoneHint;

  /// No description provided for @npcNewBlockHint.
  ///
  /// In es, this message translates to:
  /// **'Un bloque propio como los del bestiario: copiá el de una criatura y retocalo, o arrancá vacío.'**
  String get npcNewBlockHint;

  /// No description provided for @npcNewCharacterHint.
  ///
  /// In es, this message translates to:
  /// **'Pasa por el creador de personajes: especie, clase, niveles y dotes. El villano de un trasfondo.'**
  String get npcNewCharacterHint;

  /// No description provided for @npcStartFromCreature.
  ///
  /// In es, this message translates to:
  /// **'Partir de una criatura (opcional)'**
  String get npcStartFromCreature;

  /// No description provided for @npcEmptyBlock.
  ///
  /// In es, this message translates to:
  /// **'Bloque vacío'**
  String get npcEmptyBlock;

  /// No description provided for @npcFillLater.
  ///
  /// In es, this message translates to:
  /// **'Lo completás después.'**
  String get npcFillLater;

  /// No description provided for @npcAcHp.
  ///
  /// In es, this message translates to:
  /// **'CA {ac} · PG {hp}'**
  String npcAcHp(String ac, String hp);

  /// No description provided for @npcTypeFixed.
  ///
  /// In es, this message translates to:
  /// **'El tipo no se cambia después: define con qué se edita.'**
  String get npcTypeFixed;

  /// No description provided for @npcContinueToCreator.
  ///
  /// In es, this message translates to:
  /// **'Continuar al creador'**
  String get npcContinueToCreator;

  /// No description provided for @npcCreate.
  ///
  /// In es, this message translates to:
  /// **'Crear'**
  String get npcCreate;

  /// No description provided for @shareStop.
  ///
  /// In es, this message translates to:
  /// **'Dejar de compartir'**
  String get shareStop;

  /// No description provided for @shareStopBody.
  ///
  /// In es, this message translates to:
  /// **'El DM de «{campaign}» deja de ver a {character}. Tu ficha no se toca.'**
  String shareStopBody(String campaign, String character);

  /// No description provided for @shareStopped.
  ///
  /// In es, this message translates to:
  /// **'Ya no se comparte con {campaign}.'**
  String shareStopped(String campaign);

  /// No description provided for @shareTitle.
  ///
  /// In es, this message translates to:
  /// **'Compartir a {name}'**
  String shareTitle(String name);

  /// No description provided for @shareIntro.
  ///
  /// In es, this message translates to:
  /// **'Generá un código y pasáselo a tu DM. Lo pega en su campaña y ve tu ficha; nunca puede editarla.'**
  String get shareIntro;

  /// No description provided for @shareGenerating.
  ///
  /// In es, this message translates to:
  /// **'Generando…'**
  String get shareGenerating;

  /// No description provided for @shareGenerate.
  ///
  /// In es, this message translates to:
  /// **'Generar código'**
  String get shareGenerate;

  /// No description provided for @shareSharedWith.
  ///
  /// In es, this message translates to:
  /// **'Compartido con'**
  String get shareSharedWith;

  /// No description provided for @shareCodeNote.
  ///
  /// In es, this message translates to:
  /// **'Sirve una sola vez y vence en 24 horas.'**
  String get shareCodeNote;

  /// No description provided for @shareCopied.
  ///
  /// In es, this message translates to:
  /// **'Código copiado.'**
  String get shareCopied;

  /// No description provided for @commonCopy.
  ///
  /// In es, this message translates to:
  /// **'Copiar'**
  String get commonCopy;

  /// No description provided for @commonSearching.
  ///
  /// In es, this message translates to:
  /// **'Buscando…'**
  String get commonSearching;

  /// No description provided for @shareNone.
  ///
  /// In es, this message translates to:
  /// **'Todavía no lo compartiste con ninguna campaña.'**
  String get shareNone;

  /// No description provided for @shareStopWith.
  ///
  /// In es, this message translates to:
  /// **'Dejar de compartir con {campaign}'**
  String shareStopWith(String campaign);

  /// No description provided for @dmAddToCombat.
  ///
  /// In es, this message translates to:
  /// **'Sumar al combate'**
  String get dmAddToCombat;

  /// No description provided for @dmBestiary.
  ///
  /// In es, this message translates to:
  /// **'Bestiario'**
  String get dmBestiary;

  /// No description provided for @dmAddShort.
  ///
  /// In es, this message translates to:
  /// **'Sumar'**
  String get dmAddShort;

  /// No description provided for @dmSearchBestiary.
  ///
  /// In es, this message translates to:
  /// **'Buscar en el bestiario'**
  String get dmSearchBestiary;

  /// No description provided for @dmDeadHere.
  ///
  /// In es, this message translates to:
  /// **'Muerto en esta campaña'**
  String get dmDeadHere;

  /// No description provided for @dmAlsoJoinsCampaign.
  ///
  /// In es, this message translates to:
  /// **'al sumarlo, entra también a la campaña'**
  String get dmAlsoJoinsCampaign;

  /// No description provided for @dmAlreadyInCombat.
  ///
  /// In es, this message translates to:
  /// **'Ya está en el combate'**
  String get dmAlreadyInCombat;

  /// No description provided for @dmSearchNpcs.
  ///
  /// In es, this message translates to:
  /// **'Buscar PNJ'**
  String get dmSearchNpcs;

  /// No description provided for @dmInThisCampaign.
  ///
  /// In es, this message translates to:
  /// **'En esta campaña'**
  String get dmInThisCampaign;

  /// No description provided for @dmNoneDot.
  ///
  /// In es, this message translates to:
  /// **'Ninguno.'**
  String get dmNoneDot;

  /// No description provided for @dmFromLibrary.
  ///
  /// In es, this message translates to:
  /// **'De tu biblioteca · no están en esta campaña'**
  String get dmFromLibrary;

  /// No description provided for @dmLoadingLibrary.
  ///
  /// In es, this message translates to:
  /// **'Cargando tu biblioteca…'**
  String get dmLoadingLibrary;

  /// No description provided for @dmDeadNote.
  ///
  /// In es, this message translates to:
  /// **'{name} está muerto en esta campaña. Sumarlo al combate no cambia eso.'**
  String dmDeadNote(String name);

  /// No description provided for @dmRevive.
  ///
  /// In es, this message translates to:
  /// **'Volvió: marcarlo vivo otra vez'**
  String get dmRevive;

  /// No description provided for @dmWhichSide.
  ///
  /// In es, this message translates to:
  /// **'¿De qué lado pelea?'**
  String get dmWhichSide;

  /// No description provided for @dmSide.
  ///
  /// In es, this message translates to:
  /// **'Bando'**
  String get dmSide;

  /// No description provided for @dmStatlessSide.
  ///
  /// In es, this message translates to:
  /// **'Sin estadísticas no tiene PG que bajar: entra neutral, con su turno, y no cuenta para ningún bando.'**
  String get dmStatlessSide;

  /// No description provided for @dmNoDefaultSide.
  ///
  /// In es, this message translates to:
  /// **'Sin valor por defecto: el mismo PNJ puede ser aliado hoy y enemigo la sesión que viene. Un neutral tiene turno y puede tomar partido durante el combate.'**
  String get dmNoDefaultSide;

  /// No description provided for @dmOneFewer.
  ///
  /// In es, this message translates to:
  /// **'Una copia menos'**
  String get dmOneFewer;

  /// No description provided for @dmOneMore.
  ///
  /// In es, this message translates to:
  /// **'Una copia más'**
  String get dmOneMore;

  /// No description provided for @dmRollEachHp.
  ///
  /// In es, this message translates to:
  /// **'Tirar los PG de cada uno'**
  String get dmRollEachHp;

  /// No description provided for @dmEachRolls.
  ///
  /// In es, this message translates to:
  /// **'Cada copia tira {formula} por su cuenta.'**
  String dmEachRolls(Object formula);

  /// No description provided for @dmAllStartWith.
  ///
  /// In es, this message translates to:
  /// **'Todas arrancan con {hp}, el promedio del libro.'**
  String dmAllStartWith(Object hp);

  /// No description provided for @dmAddToCombatOf.
  ///
  /// In es, this message translates to:
  /// **'Sumar al combate de {campaign}'**
  String dmAddToCombatOf(String campaign);

  /// No description provided for @chapterStatePlanned.
  ///
  /// In es, this message translates to:
  /// **'Próximamente'**
  String get chapterStatePlanned;

  /// No description provided for @chapterStateActive.
  ///
  /// In es, this message translates to:
  /// **'En marcha'**
  String get chapterStateActive;

  /// No description provided for @chapterStateCompleted.
  ///
  /// In es, this message translates to:
  /// **'Completado'**
  String get chapterStateCompleted;

  /// No description provided for @dmAddedToCombat.
  ///
  /// In es, this message translates to:
  /// **'Sumaste {what} al combate de {campaign}.'**
  String dmAddedToCombat(String what, String campaign);

  /// No description provided for @dmAddToCombatFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo sumar al combate'**
  String get dmAddToCombatFailed;

  /// No description provided for @dmPickCreature.
  ///
  /// In es, this message translates to:
  /// **'Elegí una criatura para ver su perfil.'**
  String get dmPickCreature;

  /// No description provided for @dmAny.
  ///
  /// In es, this message translates to:
  /// **'Cualquiera'**
  String get dmAny;

  /// No description provided for @dmSearchCreature.
  ///
  /// In es, this message translates to:
  /// **'Buscar criatura'**
  String get dmSearchCreature;

  /// No description provided for @dmAllTypes.
  ///
  /// In es, this message translates to:
  /// **'Todos los tipos'**
  String get dmAllTypes;

  /// No description provided for @dmCrFrom.
  ///
  /// In es, this message translates to:
  /// **'VD desde'**
  String get dmCrFrom;

  /// No description provided for @dmCrTo.
  ///
  /// In es, this message translates to:
  /// **'VD hasta'**
  String get dmCrTo;

  /// No description provided for @dmNoCreatureMatches.
  ///
  /// In es, this message translates to:
  /// **'Ninguna criatura coincide con lo que buscaste.'**
  String get dmNoCreatureMatches;

  /// No description provided for @dmCreateCampaignFirst.
  ///
  /// In es, this message translates to:
  /// **'Para sumarla a un combate, primero creá una campaña.'**
  String get dmCreateCampaignFirst;

  /// No description provided for @dmChaptersReadFail.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron leer los capítulos.'**
  String get dmChaptersReadFail;

  /// No description provided for @dmChaptersLoading.
  ///
  /// In es, this message translates to:
  /// **'Cargando los capítulos…'**
  String get dmChaptersLoading;

  /// No description provided for @dmChaptersEmpty.
  ///
  /// In es, this message translates to:
  /// **'Todavía no dividiste esta campaña en capítulos. Sirven para llevar por dónde va la historia.'**
  String get dmChaptersEmpty;

  /// No description provided for @dmCloseChapterBody.
  ///
  /// In es, this message translates to:
  /// **'«{name}» pasa a completado y a cada jugador de la mesa le llega el aviso.'**
  String dmCloseChapterBody(String name);

  /// No description provided for @dmCloseChapterBodyRewards.
  ///
  /// In es, this message translates to:
  /// **'«{name}» pasa a completado y a cada jugador de la mesa le llega el aviso, con que se llevan {rewards}. Eso lo anota cada uno en su ficha: la app no se lo aplica a nadie.'**
  String dmCloseChapterBodyRewards(String name, String rewards);

  /// No description provided for @dmCloseChapter.
  ///
  /// In es, this message translates to:
  /// **'Cerrar capítulo'**
  String get dmCloseChapter;

  /// No description provided for @dmDeleteChapter.
  ///
  /// In es, this message translates to:
  /// **'Borrar capítulo'**
  String get dmDeleteChapter;

  /// No description provided for @dmDeleteChapterBody.
  ///
  /// In es, this message translates to:
  /// **'Se borra «{name}» y lo que hayas escrito en él. A los jugadores no les llega nada.'**
  String dmDeleteChapterBody(String name);

  /// No description provided for @dmLevelsUp.
  ///
  /// In es, this message translates to:
  /// **'Sube de nivel'**
  String get dmLevelsUp;

  /// No description provided for @dmGoalLine.
  ///
  /// In es, this message translates to:
  /// **'Objetivo: {goal}'**
  String dmGoalLine(String goal);

  /// No description provided for @dmRewardsTook.
  ///
  /// In es, this message translates to:
  /// **'Se llevaron {rewards}'**
  String dmRewardsTook(String rewards);

  /// No description provided for @dmRewardsTake.
  ///
  /// In es, this message translates to:
  /// **'Se llevan {rewards}'**
  String dmRewardsTake(String rewards);

  /// No description provided for @dmViewInNotebook.
  ///
  /// In es, this message translates to:
  /// **'Ver en Cuaderno'**
  String get dmViewInNotebook;

  /// No description provided for @dmNotebookReadFail.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer el cuaderno.'**
  String get dmNotebookReadFail;

  /// No description provided for @dmNotebookLoading.
  ///
  /// In es, this message translates to:
  /// **'Cargando el cuaderno…'**
  String get dmNotebookLoading;

  /// No description provided for @dmNotebookNeedsChapter.
  ///
  /// In es, this message translates to:
  /// **'El cuaderno se ordena por capítulo, así que primero hay que crear uno. Desde Capítulos.'**
  String get dmNotebookNeedsChapter;

  /// No description provided for @dmSearchNotebook.
  ///
  /// In es, this message translates to:
  /// **'Buscar en el cuaderno'**
  String get dmSearchNotebook;

  /// No description provided for @dmNoChapter.
  ///
  /// In es, this message translates to:
  /// **'Sin capítulo'**
  String get dmNoChapter;

  /// No description provided for @dmLooseFights.
  ///
  /// In es, this message translates to:
  /// **'Combates que se jugaron sin ningún capítulo en marcha.'**
  String get dmLooseFights;

  /// No description provided for @dmDeleteNote.
  ///
  /// In es, this message translates to:
  /// **'Borrar nota'**
  String get dmDeleteNote;

  /// No description provided for @dmDeleteNoteBody.
  ///
  /// In es, this message translates to:
  /// **'Se borra «{title}» y no se puede deshacer.'**
  String dmDeleteNoteBody(String title);

  /// No description provided for @dmCombat.
  ///
  /// In es, this message translates to:
  /// **'Combate'**
  String get dmCombat;

  /// No description provided for @dmCombatAgainst.
  ///
  /// In es, this message translates to:
  /// **'Combate contra {enemies}'**
  String dmCombatAgainst(String enemies);

  /// No description provided for @dmDistributed.
  ///
  /// In es, this message translates to:
  /// **'Se repartió {grants}.'**
  String dmDistributed(String grants);

  /// No description provided for @dmNothingNoted.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay nada anotado en este capítulo.'**
  String get dmNothingNoted;

  /// No description provided for @dmNoEntries.
  ///
  /// In es, this message translates to:
  /// **'Sin entradas'**
  String get dmNoEntries;

  /// No description provided for @dmNotesCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 nota} other{{count} notas}}'**
  String dmNotesCount(int count);

  /// No description provided for @dmFightsCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 combate} other{{count} combates}}'**
  String dmFightsCount(int count);

  /// No description provided for @dmNoteActions.
  ///
  /// In es, this message translates to:
  /// **'Acciones de la nota'**
  String get dmNoteActions;

  /// No description provided for @dmRounds.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 ronda} other{{count} rondas}}'**
  String dmRounds(int count);

  /// No description provided for @dmToday.
  ///
  /// In es, this message translates to:
  /// **'hoy'**
  String get dmToday;

  /// No description provided for @dmYesterday.
  ///
  /// In es, this message translates to:
  /// **'ayer'**
  String get dmYesterday;

  /// No description provided for @dmDaysAgo.
  ///
  /// In es, this message translates to:
  /// **'hace {days} días'**
  String dmDaysAgo(int days);

  /// No description provided for @dmTheTable.
  ///
  /// In es, this message translates to:
  /// **'La mesa'**
  String get dmTheTable;

  /// No description provided for @dmLogAllies.
  ///
  /// In es, this message translates to:
  /// **'Aliados: {names}.'**
  String dmLogAllies(String names);

  /// No description provided for @dmLogNeutrals.
  ///
  /// In es, this message translates to:
  /// **'Neutrales: {names}.'**
  String dmLogNeutrals(String names);

  /// No description provided for @dmLogNoEnemies.
  ///
  /// In es, this message translates to:
  /// **'{who} peleó sin enemigos cargados.'**
  String dmLogNoEnemies(String who);

  /// No description provided for @dmLogNoneFell.
  ///
  /// In es, this message translates to:
  /// **'No cayó ningún enemigo.'**
  String get dmLogNoneFell;

  /// No description provided for @dmLogAllFell.
  ///
  /// In es, this message translates to:
  /// **'Cayeron todos los enemigos.'**
  String get dmLogAllFell;

  /// No description provided for @dmLogSomeFell.
  ///
  /// In es, this message translates to:
  /// **'Cayeron {defeated} de {total} enemigos.'**
  String dmLogSomeFell(int defeated, int total);

  /// No description provided for @dmLogAgainst.
  ///
  /// In es, this message translates to:
  /// **'{who} contra {against}. {fell}'**
  String dmLogAgainst(String who, String against, String fell);

  /// No description provided for @dmSheetReadFail.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer la ficha.'**
  String get dmSheetReadFail;

  /// No description provided for @dmSheetGone.
  ///
  /// In es, this message translates to:
  /// **'Ya no ves esta ficha. Puede que te hayan cortado el vínculo.'**
  String get dmSheetGone;

  /// No description provided for @dmSheetLoading.
  ///
  /// In es, this message translates to:
  /// **'Cargando la ficha…'**
  String get dmSheetLoading;

  /// No description provided for @dmAbbrInit.
  ///
  /// In es, this message translates to:
  /// **'Inic'**
  String get dmAbbrInit;

  /// No description provided for @dmAbbrSpeed.
  ///
  /// In es, this message translates to:
  /// **'Vel'**
  String get dmAbbrSpeed;

  /// No description provided for @dmAbbrPerception.
  ///
  /// In es, this message translates to:
  /// **'Perc.'**
  String get dmAbbrPerception;

  /// No description provided for @dmActiveConditions.
  ///
  /// In es, this message translates to:
  /// **'Condiciones activas'**
  String get dmActiveConditions;

  /// No description provided for @dmProficientSkills.
  ///
  /// In es, this message translates to:
  /// **'Habilidades competentes'**
  String get dmProficientSkills;

  /// No description provided for @dmNoneDotF.
  ///
  /// In es, this message translates to:
  /// **'Ninguna.'**
  String get dmNoneDotF;

  /// No description provided for @dmNoAttacks.
  ///
  /// In es, this message translates to:
  /// **'No tiene ataques cargados.'**
  String get dmNoAttacks;

  /// No description provided for @dmNpcsReadFail.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron leer los PNJ de la campaña.'**
  String get dmNpcsReadFail;

  /// No description provided for @dmNpcsLoading.
  ///
  /// In es, this message translates to:
  /// **'Cargando los PNJ…'**
  String get dmNpcsLoading;

  /// No description provided for @dmNpcsEmpty.
  ///
  /// In es, this message translates to:
  /// **'Esta campaña todavía no tiene PNJ. Traé los de tu biblioteca o creá uno nuevo.'**
  String get dmNpcsEmpty;

  /// No description provided for @dmBringFromLibrary.
  ///
  /// In es, this message translates to:
  /// **'Traer de la biblioteca'**
  String get dmBringFromLibrary;

  /// No description provided for @dmTagsCaps.
  ///
  /// In es, this message translates to:
  /// **'TAGS'**
  String get dmTagsCaps;

  /// No description provided for @dmNoNpcWithTag.
  ///
  /// In es, this message translates to:
  /// **'Ningún PNJ de esta campaña tiene ese tag.'**
  String get dmNoNpcWithTag;

  /// No description provided for @dmClearFilter.
  ///
  /// In es, this message translates to:
  /// **'Limpiar filtro'**
  String get dmClearFilter;

  /// No description provided for @dmStatusOf.
  ///
  /// In es, this message translates to:
  /// **'Estado de {name}'**
  String dmStatusOf(String name);

  /// No description provided for @dmActionsOf.
  ///
  /// In es, this message translates to:
  /// **'Acciones de {name}'**
  String dmActionsOf(String name);

  /// No description provided for @dmOpenSheet.
  ///
  /// In es, this message translates to:
  /// **'Abrir ficha'**
  String get dmOpenSheet;

  /// No description provided for @dmRemoveFromCampaign.
  ///
  /// In es, this message translates to:
  /// **'Quitar de esta campaña'**
  String get dmRemoveFromCampaign;

  /// No description provided for @dmRemoveFromCampaignNote.
  ///
  /// In es, this message translates to:
  /// **'Sigue en tu biblioteca y en tus otras campañas.'**
  String get dmRemoveFromCampaignNote;

  /// No description provided for @dmLibraryReadFail.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer tu biblioteca de PNJ.'**
  String get dmLibraryReadFail;

  /// No description provided for @dmLibraryLoading.
  ///
  /// In es, this message translates to:
  /// **'Cargando tus PNJ…'**
  String get dmLibraryLoading;

  /// No description provided for @dmLibraryEmpty.
  ///
  /// In es, this message translates to:
  /// **'Tu biblioteca de PNJ está vacía. Creá el primero o importá uno: el de otro DM, o un personaje que exportó un jugador.'**
  String get dmLibraryEmpty;

  /// No description provided for @dmNoNpcMatches.
  ///
  /// In es, this message translates to:
  /// **'Ningún PNJ coincide con los filtros.'**
  String get dmNoNpcMatches;

  /// No description provided for @dmNpcLibrary.
  ///
  /// In es, this message translates to:
  /// **'Biblioteca de PNJ'**
  String get dmNpcLibrary;

  /// No description provided for @dmLibraryCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 personaje · compartido entre tus campañas} other{{count} personajes · compartidos entre tus campañas}}'**
  String dmLibraryCount(int count);

  /// No description provided for @dmImportNpc.
  ///
  /// In es, this message translates to:
  /// **'Importar PNJ'**
  String get dmImportNpc;

  /// No description provided for @dmSearchByName.
  ///
  /// In es, this message translates to:
  /// **'Buscar por nombre'**
  String get dmSearchByName;

  /// No description provided for @dmAllF.
  ///
  /// In es, this message translates to:
  /// **'Todas'**
  String get dmAllF;

  /// No description provided for @dmNoCampaign.
  ///
  /// In es, this message translates to:
  /// **'Sin campaña'**
  String get dmNoCampaign;

  /// No description provided for @dmNoCampaignYet.
  ///
  /// In es, this message translates to:
  /// **'Sin campaña todavía'**
  String get dmNoCampaignYet;

  /// No description provided for @dmShowName.
  ///
  /// In es, this message translates to:
  /// **'Mostrar el nombre'**
  String get dmShowName;

  /// No description provided for @dmHideName.
  ///
  /// In es, this message translates to:
  /// **'Ocultar el nombre'**
  String get dmHideName;

  /// No description provided for @npcExportTitle.
  ///
  /// In es, this message translates to:
  /// **'Exportar PNJ'**
  String get npcExportTitle;

  /// No description provided for @npcExportWhatTravels.
  ///
  /// In es, this message translates to:
  /// **'Qué viaja en el archivo'**
  String get npcExportWhatTravels;

  /// No description provided for @npcExportAlways.
  ///
  /// In es, this message translates to:
  /// **'Nombre, retrato, apariencia y «cómo habla»'**
  String get npcExportAlways;

  /// No description provided for @npcExportNone.
  ///
  /// In es, this message translates to:
  /// **'Su tipo: sin estadísticas'**
  String get npcExportNone;

  /// No description provided for @npcExportBlock.
  ///
  /// In es, this message translates to:
  /// **'Su bloque'**
  String get npcExportBlock;

  /// No description provided for @npcExportCharacter.
  ///
  /// In es, this message translates to:
  /// **'Su ficha de personaje y el homebrew que usa'**
  String get npcExportCharacter;

  /// No description provided for @npcTagsWord.
  ///
  /// In es, this message translates to:
  /// **'Tags'**
  String get npcTagsWord;

  /// No description provided for @npcNotesWord.
  ///
  /// In es, this message translates to:
  /// **'Notas'**
  String get npcNotesWord;

  /// No description provided for @npcNotesNote.
  ///
  /// In es, this message translates to:
  /// **'Son de tus mesas.'**
  String get npcNotesNote;

  /// No description provided for @npcExportNever.
  ///
  /// In es, this message translates to:
  /// **'Nunca viaja en qué campañas está ni si vive o murió en cada una. Quien lo importe recibe su propia copia: lo que cambie después no te llega.'**
  String get npcExportNever;

  /// No description provided for @npcDownloadZip.
  ///
  /// In es, this message translates to:
  /// **'Descargar .zip'**
  String get npcDownloadZip;

  /// No description provided for @npcPickFile.
  ///
  /// In es, this message translates to:
  /// **'Elegir el archivo del PNJ o del personaje'**
  String get npcPickFile;

  /// No description provided for @npcNewerVersion.
  ///
  /// In es, this message translates to:
  /// **'El archivo viene de una versión más nueva de la app.'**
  String get npcNewerVersion;

  /// No description provided for @npcImportedHomebrewLate.
  ///
  /// In es, this message translates to:
  /// **'El PNJ se importó, pero su homebrew aparece recién al recargar la página.'**
  String get npcImportedHomebrewLate;

  /// No description provided for @npcPortraitsCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 retrato} other{{count} retratos}}'**
  String npcPortraitsCount(int count);

  /// No description provided for @npcBackgroundLower.
  ///
  /// In es, this message translates to:
  /// **'trasfondo'**
  String get npcBackgroundLower;

  /// No description provided for @npcNotesCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 nota} other{{count} notas}}'**
  String npcNotesCount(int count);

  /// No description provided for @npcHomebrewList.
  ///
  /// In es, this message translates to:
  /// **'homebrew: {names}'**
  String npcHomebrewList(String names);

  /// No description provided for @npcCannotImport.
  ///
  /// In es, this message translates to:
  /// **'No se puede importar: su ficha usa contenido que esta instalación no tiene ({missing}).'**
  String npcCannotImport(String missing);

  /// No description provided for @npcAlsoAddToCampaign.
  ///
  /// In es, this message translates to:
  /// **'Sumarlo también a una campaña (opcional)'**
  String get npcAlsoAddToCampaign;

  /// No description provided for @npcNoCampaignOption.
  ///
  /// In es, this message translates to:
  /// **'Ninguna: queda sin campaña'**
  String get npcNoCampaignOption;

  /// No description provided for @npcImportNeverReplaces.
  ///
  /// In es, this message translates to:
  /// **'Importar nunca reemplaza nada: si ya tenés un PNJ con ese nombre, quedan los dos.'**
  String get npcImportNeverReplaces;

  /// No description provided for @npcImporting.
  ///
  /// In es, this message translates to:
  /// **'Importando…'**
  String get npcImporting;

  /// No description provided for @npcSaveFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar el cambio'**
  String get npcSaveFailed;

  /// No description provided for @npcEditName.
  ///
  /// In es, this message translates to:
  /// **'Editar nombre'**
  String get npcEditName;

  /// No description provided for @npcNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre del PNJ'**
  String get npcNameLabel;

  /// No description provided for @npcNewNote.
  ///
  /// In es, this message translates to:
  /// **'Nueva nota'**
  String get npcNewNote;

  /// No description provided for @npcAddToCampaign.
  ///
  /// In es, this message translates to:
  /// **'Sumar a una campaña'**
  String get npcAddToCampaign;

  /// No description provided for @npcInAllCampaigns.
  ///
  /// In es, this message translates to:
  /// **'Ya está en todas tus campañas.'**
  String get npcInAllCampaigns;

  /// No description provided for @npcDeleteBodyLibrary.
  ///
  /// In es, this message translates to:
  /// **'Se borra de tu biblioteca, con su ficha, su trasfondo, sus notas y sus retratos. No se puede deshacer.'**
  String get npcDeleteBodyLibrary;

  /// No description provided for @npcDeleteBodyCampaigns.
  ///
  /// In es, this message translates to:
  /// **'Se borra de tu biblioteca y de {campaigns}, con su ficha, su trasfondo, sus notas y sus retratos. No se puede deshacer.'**
  String npcDeleteBodyCampaigns(String campaigns);

  /// No description provided for @npcDeleteTitle.
  ///
  /// In es, this message translates to:
  /// **'Borrar a {name}'**
  String npcDeleteTitle(String name);

  /// No description provided for @npcDeletePastBattles.
  ///
  /// In es, this message translates to:
  /// **'Las batallas pasadas lo siguen nombrando en el Cuaderno. Si está en un combate abierto, su fila queda con el nombre y sin perfil.'**
  String get npcDeletePastBattles;

  /// No description provided for @npcDeleteJustUnlink.
  ///
  /// In es, this message translates to:
  /// **'¿Solo querés sacarlo de una campaña? Usá «Quitar de esta campaña» desde la lista de PNJ de esa campaña.'**
  String get npcDeleteJustUnlink;

  /// No description provided for @npcDelete.
  ///
  /// In es, this message translates to:
  /// **'Borrar PNJ'**
  String get npcDelete;

  /// No description provided for @npcDeleted.
  ///
  /// In es, this message translates to:
  /// **'{name} se borró.'**
  String npcDeleted(String name);

  /// No description provided for @npcDeleteFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo borrar el PNJ'**
  String get npcDeleteFailed;

  /// No description provided for @npcShowTable.
  ///
  /// In es, this message translates to:
  /// **'Mostrar a la mesa'**
  String get npcShowTable;

  /// No description provided for @npcMoreActions.
  ///
  /// In es, this message translates to:
  /// **'Más acciones'**
  String get npcMoreActions;

  /// No description provided for @npcExport.
  ///
  /// In es, this message translates to:
  /// **'Exportar'**
  String get npcExport;

  /// No description provided for @npcReadFail.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer el PNJ.'**
  String get npcReadFail;

  /// No description provided for @npcLoading.
  ///
  /// In es, this message translates to:
  /// **'Cargando el PNJ…'**
  String get npcLoading;

  /// No description provided for @npcGone.
  ///
  /// In es, this message translates to:
  /// **'Este PNJ ya no existe.'**
  String get npcGone;

  /// No description provided for @npcSpeech.
  ///
  /// In es, this message translates to:
  /// **'Cómo habla'**
  String get npcSpeech;

  /// No description provided for @npcSpeechHint.
  ///
  /// In es, this message translates to:
  /// **'Una o dos líneas para interpretarlo'**
  String get npcSpeechHint;

  /// No description provided for @npcSpeechEmpty.
  ///
  /// In es, this message translates to:
  /// **'Todavía no dice cómo habla.'**
  String get npcSpeechEmpty;

  /// No description provided for @npcNoBackground.
  ///
  /// In es, this message translates to:
  /// **'Sin trasfondo.'**
  String get npcNoBackground;

  /// No description provided for @npcPortrait.
  ///
  /// In es, this message translates to:
  /// **'Retrato'**
  String get npcPortrait;

  /// No description provided for @npcRemoveTag.
  ///
  /// In es, this message translates to:
  /// **'Quitar «{tag}»'**
  String npcRemoveTag(String tag);

  /// No description provided for @npcTagWord.
  ///
  /// In es, this message translates to:
  /// **'Tag'**
  String get npcTagWord;

  /// No description provided for @npcEditTitle.
  ///
  /// In es, this message translates to:
  /// **'Editar {title}'**
  String npcEditTitle(String title);

  /// No description provided for @npcAddNote.
  ///
  /// In es, this message translates to:
  /// **'Agregar nota'**
  String get npcAddNote;

  /// No description provided for @npcNoNotes.
  ///
  /// In es, this message translates to:
  /// **'Sin notas.'**
  String get npcNoNotes;

  /// No description provided for @npcStats.
  ///
  /// In es, this message translates to:
  /// **'Estadísticas'**
  String get npcStats;

  /// No description provided for @npcNoStatsNote.
  ///
  /// In es, this message translates to:
  /// **'Sin estadísticas. En combate entra como neutral, con turno y sin PG.'**
  String get npcNoStatsNote;

  /// No description provided for @npcBlockTitle.
  ///
  /// In es, this message translates to:
  /// **'Bloque'**
  String get npcBlockTitle;

  /// No description provided for @npcBasedOn.
  ///
  /// In es, this message translates to:
  /// **'basado en {name}'**
  String npcBasedOn(String name);

  /// No description provided for @dmAbbrHp.
  ///
  /// In es, this message translates to:
  /// **'PG'**
  String get dmAbbrHp;

  /// No description provided for @npcEditBlock.
  ///
  /// In es, this message translates to:
  /// **'Editar bloque'**
  String get npcEditBlock;

  /// No description provided for @npcBlockCopyNote.
  ///
  /// In es, this message translates to:
  /// **'Es una copia: si la criatura del bestiario cambia, este bloque no se toca.'**
  String get npcBlockCopyNote;

  /// No description provided for @npcSheetTitle.
  ///
  /// In es, this message translates to:
  /// **'Ficha'**
  String get npcSheetTitle;

  /// No description provided for @npcSheetReadFail.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer su ficha.'**
  String get npcSheetReadFail;

  /// No description provided for @npcOpenFullSheet.
  ///
  /// In es, this message translates to:
  /// **'Abrir ficha completa'**
  String get npcOpenFullSheet;

  /// No description provided for @npcFullSheetNote.
  ///
  /// In es, this message translates to:
  /// **'Nombre, retrato, trasfondo y notas se editan acá; la ficha completa es para estadísticas, equipo y niveles.'**
  String get npcFullSheetNote;

  /// No description provided for @npcInCampaigns.
  ///
  /// In es, this message translates to:
  /// **'En tus campañas'**
  String get npcInCampaigns;

  /// No description provided for @npcNoCampaignsYet.
  ///
  /// In es, this message translates to:
  /// **'Todavía no está en ninguna campaña.'**
  String get npcNoCampaignsYet;

  /// No description provided for @npcStatusIn.
  ///
  /// In es, this message translates to:
  /// **'Estado en {campaign}'**
  String npcStatusIn(String campaign);

  /// No description provided for @npcAddToAnother.
  ///
  /// In es, this message translates to:
  /// **'Sumar a otra campaña'**
  String get npcAddToAnother;

  /// No description provided for @npcAddTag.
  ///
  /// In es, this message translates to:
  /// **'Agregar tag'**
  String get npcAddTag;

  /// No description provided for @encReadFail.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer el combate.'**
  String get encReadFail;

  /// No description provided for @encLoading.
  ///
  /// In es, this message translates to:
  /// **'Cargando el combate…'**
  String get encLoading;

  /// No description provided for @encNone.
  ///
  /// In es, this message translates to:
  /// **'No hay ningún combate en curso.'**
  String get encNone;

  /// No description provided for @encEmptyOrder.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay nadie en el orden. Sumá jugadores, PNJ o monstruos para arrancar.'**
  String get encEmptyOrder;

  /// No description provided for @encPreparing.
  ///
  /// In es, this message translates to:
  /// **'Armando el combate'**
  String get encPreparing;

  /// No description provided for @encPreparingNote.
  ///
  /// In es, this message translates to:
  /// **'Todavía nadie tiró iniciativa, y a los jugadores no les aparece nada en su ficha.'**
  String get encPreparingNote;

  /// No description provided for @encRound.
  ///
  /// In es, this message translates to:
  /// **'Ronda'**
  String get encRound;

  /// No description provided for @encTurnOf.
  ///
  /// In es, this message translates to:
  /// **'Turno {turn} de {total}'**
  String encTurnOf(int turn, int total);

  /// No description provided for @encStandingSemantics.
  ///
  /// In es, this message translates to:
  /// **'{what}: {up} de {total} en pie'**
  String encStandingSemantics(String what, int up, int total);

  /// No description provided for @encStanding.
  ///
  /// In es, this message translates to:
  /// **'En pie'**
  String get encStanding;

  /// No description provided for @encAllies.
  ///
  /// In es, this message translates to:
  /// **'Aliados'**
  String get encAllies;

  /// No description provided for @encEnemies.
  ///
  /// In es, this message translates to:
  /// **'Enemigos'**
  String get encEnemies;

  /// No description provided for @encNeutralsCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 neutral} other{{count} neutrales}}'**
  String encNeutralsCount(int count);

  /// No description provided for @encAmountExplain.
  ///
  /// In es, this message translates to:
  /// **'Es el número que aplican los botones de dañar y curar de cualquier fila. Vale para todo el combate.'**
  String get encAmountExplain;

  /// No description provided for @encDamageOrHeal.
  ///
  /// In es, this message translates to:
  /// **'Daño o curación'**
  String get encDamageOrHeal;

  /// No description provided for @encSetAmount.
  ///
  /// In es, this message translates to:
  /// **'Poner {n}'**
  String encSetAmount(int n);

  /// No description provided for @encDiscard.
  ///
  /// In es, this message translates to:
  /// **'Descartar combate'**
  String get encDiscard;

  /// No description provided for @encFinish.
  ///
  /// In es, this message translates to:
  /// **'Terminar combate'**
  String get encFinish;

  /// No description provided for @encDiscardTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Descartar el combate?'**
  String get encDiscardTitle;

  /// No description provided for @encDiscardBody.
  ///
  /// In es, this message translates to:
  /// **'Todavía no empezó: se borra lo que armaste y no queda registro.'**
  String get encDiscardBody;

  /// No description provided for @encDiscardShort.
  ///
  /// In es, this message translates to:
  /// **'Descartar'**
  String get encDiscardShort;

  /// No description provided for @encInitiativeOf.
  ///
  /// In es, this message translates to:
  /// **'Iniciativa de {name}'**
  String encInitiativeOf(String name);

  /// No description provided for @encWhatTheyGot.
  ///
  /// In es, this message translates to:
  /// **'Lo que sacó'**
  String get encWhatTheyGot;

  /// No description provided for @encCombatant.
  ///
  /// In es, this message translates to:
  /// **'Combatiente'**
  String get encCombatant;

  /// No description provided for @encEffects.
  ///
  /// In es, this message translates to:
  /// **'Efectos'**
  String get encEffects;

  /// No description provided for @encDamageHeal.
  ///
  /// In es, this message translates to:
  /// **'Daño o cura'**
  String get encDamageHeal;

  /// No description provided for @encOfTurn.
  ///
  /// In es, this message translates to:
  /// **'Del turno'**
  String get encOfTurn;

  /// No description provided for @encNobodyTurn.
  ///
  /// In es, this message translates to:
  /// **'Todavía no le toca a nadie.'**
  String get encNobodyTurn;

  /// No description provided for @encPlayerTurn.
  ///
  /// In es, this message translates to:
  /// **'Le toca a {name}, y su ficha la lleva quien lo juega.'**
  String encPlayerTurn(String name);

  /// No description provided for @encNoProfile.
  ///
  /// In es, this message translates to:
  /// **'No hay perfil cargado para {name}.'**
  String encNoProfile(String name);

  /// No description provided for @encTurnNow.
  ///
  /// In es, this message translates to:
  /// **'Le toca ahora'**
  String get encTurnNow;

  /// No description provided for @encSideOf.
  ///
  /// In es, this message translates to:
  /// **'Bando de {name}'**
  String encSideOf(String name);

  /// No description provided for @encNeutralNoStats.
  ///
  /// In es, this message translates to:
  /// **'Neutral · sin estadísticas'**
  String get encNeutralNoStats;

  /// No description provided for @encBackgroundOf.
  ///
  /// In es, this message translates to:
  /// **'Trasfondo de {name}'**
  String encBackgroundOf(String name);

  /// No description provided for @encConvertToNpc.
  ///
  /// In es, this message translates to:
  /// **'Convertir en PNJ'**
  String get encConvertToNpc;

  /// No description provided for @encNoEffects.
  ///
  /// In es, this message translates to:
  /// **'Nadie tiene efectos anotados. Se anotan desde la fila de cada combatiente.'**
  String get encNoEffects;

  /// No description provided for @encRemoveEffect.
  ///
  /// In es, this message translates to:
  /// **'Sacar «{tag}» de {name}'**
  String encRemoveEffect(String tag, String name);

  /// No description provided for @encNobodyStanding.
  ///
  /// In es, this message translates to:
  /// **'No queda nadie en pie.'**
  String get encNobodyStanding;

  /// No description provided for @encNoEnemyStanding.
  ///
  /// In es, this message translates to:
  /// **'No queda ningún enemigo en pie.'**
  String get encNoEnemyStanding;

  /// No description provided for @encNoAllyStanding.
  ///
  /// In es, this message translates to:
  /// **'No queda ningún aliado en pie.'**
  String get encNoAllyStanding;

  /// No description provided for @encWrapUp.
  ///
  /// In es, this message translates to:
  /// **'¿Damos el encuentro por terminado?'**
  String get encWrapUp;

  /// No description provided for @encNotInCombat.
  ///
  /// In es, this message translates to:
  /// **'Todavía no están en el combate'**
  String get encNotInCombat;

  /// No description provided for @encJoinedLate.
  ///
  /// In es, this message translates to:
  /// **'Se sumaron tarde'**
  String get encJoinedLate;

  /// No description provided for @encAddAll.
  ///
  /// In es, this message translates to:
  /// **'Sumar a todos'**
  String get encAddAll;

  /// No description provided for @encAddToInitiative.
  ///
  /// In es, this message translates to:
  /// **'Sumar a la iniciativa'**
  String get encAddToInitiative;

  /// No description provided for @encWhatTheyRolled.
  ///
  /// In es, this message translates to:
  /// **'Lo que tiró en la mesa'**
  String get encWhatTheyRolled;

  /// No description provided for @encCloseExplain.
  ///
  /// In es, this message translates to:
  /// **'Se borra el orden de turnos en los dos casos. Si lo terminás queda un registro liviano de lo que pasó, y los PNJ conservan sus PG para el próximo combate (los jugadores llevan los suyos en su ficha). Si lo descartás no queda nada, como si nunca hubiera empezado.'**
  String get encCloseExplain;

  /// No description provided for @encAnyDied.
  ///
  /// In es, this message translates to:
  /// **'¿Alguno murió?'**
  String get encAnyDied;

  /// No description provided for @encFellNote.
  ///
  /// In es, this message translates to:
  /// **'Quedaron a 0 PG. Los que marques pasan a muertos en esta campaña al terminar y guardar.'**
  String get encFellNote;

  /// No description provided for @encDiscardNoSave.
  ///
  /// In es, this message translates to:
  /// **'Descartar sin guardar'**
  String get encDiscardNoSave;

  /// No description provided for @encFinishAndSave.
  ///
  /// In es, this message translates to:
  /// **'Terminar y guardar'**
  String get encFinishAndSave;

  /// No description provided for @encSkips.
  ///
  /// In es, this message translates to:
  /// **'Salta'**
  String get encSkips;

  /// No description provided for @encTurnWord.
  ///
  /// In es, this message translates to:
  /// **'Turno'**
  String get encTurnWord;

  /// No description provided for @encActed.
  ///
  /// In es, this message translates to:
  /// **'Actuó'**
  String get encActed;

  /// No description provided for @encFixInitiative.
  ///
  /// In es, this message translates to:
  /// **'Corregir iniciativa'**
  String get encFixInitiative;

  /// No description provided for @encDownMeta.
  ///
  /// In es, this message translates to:
  /// **'Caído · se salta su turno'**
  String get encDownMeta;

  /// No description provided for @encFixedNeutral.
  ///
  /// In es, this message translates to:
  /// **'Sin estadísticas: neutral fijo'**
  String get encFixedNeutral;

  /// No description provided for @encConvertToNpcEllipsis.
  ///
  /// In es, this message translates to:
  /// **'Convertir en PNJ…'**
  String get encConvertToNpcEllipsis;

  /// No description provided for @encPlayerMeta.
  ///
  /// In es, this message translates to:
  /// **'{race} · {klass} · nv {level}'**
  String encPlayerMeta(String race, String klass, int level);

  /// No description provided for @encBloodied.
  ///
  /// In es, this message translates to:
  /// **'MALTRECHO'**
  String get encBloodied;

  /// No description provided for @encOnTheirSheet.
  ///
  /// In es, this message translates to:
  /// **'en su ficha'**
  String get encOnTheirSheet;

  /// No description provided for @encHurt.
  ///
  /// In es, this message translates to:
  /// **'Dañar'**
  String get encHurt;

  /// No description provided for @encHeal.
  ///
  /// In es, this message translates to:
  /// **'Curar'**
  String get encHeal;

  /// No description provided for @encRemoveFromCombat.
  ///
  /// In es, this message translates to:
  /// **'Sacar del combate'**
  String get encRemoveFromCombat;

  /// No description provided for @dmNewCampaign.
  ///
  /// In es, this message translates to:
  /// **'Nueva campaña'**
  String get dmNewCampaign;

  /// No description provided for @dmEditCampaign.
  ///
  /// In es, this message translates to:
  /// **'Editar campaña'**
  String get dmEditCampaign;

  /// No description provided for @dmDeleteCampaign.
  ///
  /// In es, this message translates to:
  /// **'Borrar campaña'**
  String get dmDeleteCampaign;

  /// No description provided for @dmDeleteCampaignBody.
  ///
  /// In es, this message translates to:
  /// **'Se borra «{name}» con sus capítulos, las notas del Cuaderno, el combate abierto y el historial de combates. No se puede deshacer.\n\nLos personajes que los jugadores le compartieron se sueltan, y sus fichas siguen siendo de sus dueños. Los PNJ se quedan en tu biblioteca.'**
  String dmDeleteCampaignBody(String name);

  /// No description provided for @dmHomebrew.
  ///
  /// In es, this message translates to:
  /// **'Homebrew'**
  String get dmHomebrew;

  /// No description provided for @dmFinishedGroup.
  ///
  /// In es, this message translates to:
  /// **'Terminadas'**
  String get dmFinishedGroup;

  /// No description provided for @dmCurrentCampaign.
  ///
  /// In es, this message translates to:
  /// **'Campaña actual'**
  String get dmCurrentCampaign;

  /// No description provided for @dmTable.
  ///
  /// In es, this message translates to:
  /// **'Mesa'**
  String get dmTable;

  /// No description provided for @dmChapters.
  ///
  /// In es, this message translates to:
  /// **'Capítulos'**
  String get dmChapters;

  /// No description provided for @dmNotebook.
  ///
  /// In es, this message translates to:
  /// **'Cuaderno'**
  String get dmNotebook;

  /// No description provided for @dmPlayerMode.
  ///
  /// In es, this message translates to:
  /// **'Modo Jugador'**
  String get dmPlayerMode;

  /// No description provided for @dmCampaignsLoadFail.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar tus campañas.'**
  String get dmCampaignsLoadFail;

  /// No description provided for @dmOffline.
  ///
  /// In es, this message translates to:
  /// **'No hay conexión con el servidor.'**
  String get dmOffline;

  /// No description provided for @dmOfflineHint.
  ///
  /// In es, this message translates to:
  /// **'Tus campañas están a salvo; solo no se pueden leer ahora.'**
  String get dmOfflineHint;

  /// No description provided for @dmCampaignsLoading.
  ///
  /// In es, this message translates to:
  /// **'Cargando campañas…'**
  String get dmCampaignsLoading;

  /// No description provided for @dmOnbTitle.
  ///
  /// In es, this message translates to:
  /// **'Prepará tu primera mesa'**
  String get dmOnbTitle;

  /// No description provided for @dmOnbBody.
  ///
  /// In es, this message translates to:
  /// **'Todavía no dirigís ninguna campaña. Este espacio reúne lo que necesitás antes y durante la partida.'**
  String get dmOnbBody;

  /// No description provided for @dmOnb1Title.
  ///
  /// In es, this message translates to:
  /// **'Creá la campaña'**
  String get dmOnb1Title;

  /// No description provided for @dmOnb1Detail.
  ///
  /// In es, this message translates to:
  /// **'Poné nombre a la mesa y resumí su premisa.'**
  String get dmOnb1Detail;

  /// No description provided for @dmOnb2Title.
  ///
  /// In es, this message translates to:
  /// **'Sumá los personajes'**
  String get dmOnb2Title;

  /// No description provided for @dmOnb2Detail.
  ///
  /// In es, this message translates to:
  /// **'Cada jugador te comparte su ficha con un código.'**
  String get dmOnb2Detail;

  /// No description provided for @dmOnb3Title.
  ///
  /// In es, this message translates to:
  /// **'Dirigí la sesión'**
  String get dmOnb3Title;

  /// No description provided for @dmOnb3Detail.
  ///
  /// In es, this message translates to:
  /// **'Organizá capítulos y llevá la iniciativa del combate.'**
  String get dmOnb3Detail;

  /// No description provided for @dmCreateCampaign.
  ///
  /// In es, this message translates to:
  /// **'Crear campaña'**
  String get dmCreateCampaign;

  /// No description provided for @dmAddMember.
  ///
  /// In es, this message translates to:
  /// **'Sumar personaje'**
  String get dmAddMember;

  /// No description provided for @dmMemberCodeLabel.
  ///
  /// In es, this message translates to:
  /// **'Código que te pasó el jugador'**
  String get dmMemberCodeLabel;

  /// No description provided for @dmMemberAdded.
  ///
  /// In es, this message translates to:
  /// **'{name} se sumó a {campaign}.'**
  String dmMemberAdded(String name, String campaign);

  /// No description provided for @dmRemoveMember.
  ///
  /// In es, this message translates to:
  /// **'Echar personaje'**
  String get dmRemoveMember;

  /// No description provided for @dmRemoveMemberBody.
  ///
  /// In es, this message translates to:
  /// **'{name} sale de «{campaign}» y dejás de ver su ficha. El personaje sigue siendo de su dueño y no se toca; puede volver con un código nuevo.'**
  String dmRemoveMemberBody(String name, String campaign);

  /// No description provided for @dmMemberLeft.
  ///
  /// In es, this message translates to:
  /// **'{name} salió de la mesa.'**
  String dmMemberLeft(String name);

  /// No description provided for @dmInspirationSent.
  ///
  /// In es, this message translates to:
  /// **'Le avisamos a {name}. La marca en su ficha.'**
  String dmInspirationSent(String name);

  /// No description provided for @dmWriteNote.
  ///
  /// In es, this message translates to:
  /// **'Escribir nota'**
  String get dmWriteNote;

  /// No description provided for @dmEditNote.
  ///
  /// In es, this message translates to:
  /// **'Editar nota'**
  String get dmEditNote;

  /// No description provided for @dmNewChapter.
  ///
  /// In es, this message translates to:
  /// **'Nuevo capítulo'**
  String get dmNewChapter;

  /// No description provided for @dmEditChapter.
  ///
  /// In es, this message translates to:
  /// **'Editar capítulo'**
  String get dmEditChapter;

  /// No description provided for @dmChapterClosed.
  ///
  /// In es, this message translates to:
  /// **'Se cerró «{name}». Les llega el aviso a los jugadores.'**
  String dmChapterClosed(String name);

  /// No description provided for @dmSaveCombatFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar el combate'**
  String get dmSaveCombatFailed;

  /// No description provided for @dmNoProfileToCopy.
  ///
  /// In es, this message translates to:
  /// **'No hay perfil de esa criatura para copiar.'**
  String get dmNoProfileToCopy;

  /// No description provided for @dmNowNpc.
  ///
  /// In es, this message translates to:
  /// **'{name} ya es un PNJ de tu biblioteca y de esta campaña.'**
  String dmNowNpc(String name);

  /// No description provided for @dmCombatPreparing.
  ///
  /// In es, this message translates to:
  /// **'Combate en preparación'**
  String get dmCombatPreparing;

  /// No description provided for @dmCombatRound.
  ///
  /// In es, this message translates to:
  /// **'Combate · ronda {round}'**
  String dmCombatRound(int round);

  /// No description provided for @dmCampaignActions.
  ///
  /// In es, this message translates to:
  /// **'Acciones de campaña'**
  String get dmCampaignActions;

  /// No description provided for @dmAddingMember.
  ///
  /// In es, this message translates to:
  /// **'Sumando personaje…'**
  String get dmAddingMember;

  /// No description provided for @dmSetUpCombat.
  ///
  /// In es, this message translates to:
  /// **'Armar combate'**
  String get dmSetUpCombat;

  /// No description provided for @dmNextTurn.
  ///
  /// In es, this message translates to:
  /// **'Siguiente turno'**
  String get dmNextTurn;

  /// No description provided for @dmTableLoading.
  ///
  /// In es, this message translates to:
  /// **'Cargando la mesa…'**
  String get dmTableLoading;

  /// No description provided for @dmNobodyShared.
  ///
  /// In es, this message translates to:
  /// **'Todavía nadie compartió su personaje.'**
  String get dmNobodyShared;

  /// No description provided for @dmCharactersAtTable.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 personaje en la mesa} other{{count} personajes en la mesa}}'**
  String dmCharactersAtTable(int count);

  /// No description provided for @dmTableReadFail.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer la mesa.'**
  String get dmTableReadFail;

  /// No description provided for @dmTableEmpty.
  ///
  /// In es, this message translates to:
  /// **'Pedile a cada jugador que abra su personaje, toque Compartir y te pase el código.'**
  String get dmTableEmpty;

  /// No description provided for @dmHpSemantics.
  ///
  /// In es, this message translates to:
  /// **'Puntos de golpe: {current} de {max}'**
  String dmHpSemantics(int current, int max);

  /// No description provided for @dmHpShort.
  ///
  /// In es, this message translates to:
  /// **'PG {current}/{max}'**
  String dmHpShort(int current, int max);

  /// No description provided for @dmGrantInspiration.
  ///
  /// In es, this message translates to:
  /// **'Conceder Inspiración Heroica'**
  String get dmGrantInspiration;

  /// No description provided for @dmRemoveFromTable.
  ///
  /// In es, this message translates to:
  /// **'Echar de la mesa'**
  String get dmRemoveFromTable;

  /// No description provided for @dmAllNpcsInCampaign.
  ///
  /// In es, this message translates to:
  /// **'Todos tus PNJ ya están en esta campaña, o todavía no creaste ninguno.'**
  String get dmAllNpcsInCampaign;

  /// No description provided for @dmAddCount.
  ///
  /// In es, this message translates to:
  /// **'Sumar {count}'**
  String dmAddCount(int count);

  /// No description provided for @bootThemeSaveFailed.
  ///
  /// In es, this message translates to:
  /// **'El tema cambió, pero no se pudo guardar la preferencia.'**
  String get bootThemeSaveFailed;

  /// No description provided for @bootLoading.
  ///
  /// In es, this message translates to:
  /// **'Cargando datos…'**
  String get bootLoading;

  /// No description provided for @bootFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo iniciar la aplicación.'**
  String get bootFailed;

  /// No description provided for @bootFailedHint.
  ///
  /// In es, this message translates to:
  /// **'Suele ser un problema momentáneo de conexión. Probá de nuevo; si sigue igual, recargá la página.'**
  String get bootFailedHint;

  /// No description provided for @bootOffline.
  ///
  /// In es, this message translates to:
  /// **'No se pudo conectar con el servidor.'**
  String get bootOffline;

  /// No description provided for @bootOfflineHint.
  ///
  /// In es, this message translates to:
  /// **'Tus personajes están a salvo: no se pudieron leer, pero no se perdió nada. Revisá la conexión y reintentá.'**
  String get bootOfflineHint;

  /// No description provided for @invItemCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 objeto} other{{count} objetos}}'**
  String invItemCount(int count);

  /// No description provided for @invShownOf.
  ///
  /// In es, this message translates to:
  /// **'{shown} de {total}'**
  String invShownOf(Object shown, Object total);

  /// No description provided for @luClassFeatures.
  ///
  /// In es, this message translates to:
  /// **'{count} rasgos de clase'**
  String luClassFeatures(Object count);

  /// No description provided for @luUnchanged.
  ///
  /// In es, this message translates to:
  /// **'SIN CAMBIOS'**
  String get luUnchanged;

  /// No description provided for @equipCostPerBundle.
  ///
  /// In es, this message translates to:
  /// **'{cost} el paquete de {size}'**
  String equipCostPerBundle(String cost, Object size);

  /// No description provided for @equipCostEach.
  ///
  /// In es, this message translates to:
  /// **'{cost} c/u'**
  String equipCostEach(String cost);

  /// No description provided for @sheetSubclassAtLevel.
  ///
  /// In es, this message translates to:
  /// **'subclase en nivel {level}'**
  String sheetSubclassAtLevel(Object level);

  /// No description provided for @codexEntries.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 entrada} other{{count} entradas}}'**
  String codexEntries(int count);

  /// No description provided for @bestiaryCreatureCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 criatura} other{{count} criaturas}}'**
  String bestiaryCreatureCount(int count);

  /// No description provided for @npcCountTotal.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 PNJ} other{{count} PNJ}}'**
  String npcCountTotal(int count);

  /// No description provided for @npcCountAlive.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 vivo} other{{count} vivos}}'**
  String npcCountAlive(int count);

  /// No description provided for @npcCountDead.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 muerto} other{{count} muertos}}'**
  String npcCountDead(int count);

  /// No description provided for @npcCountUnknown.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 desconocido} other{{count} desconocidos}}'**
  String npcCountUnknown(int count);

  /// No description provided for @creatureLegendaryAction.
  ///
  /// In es, this message translates to:
  /// **'Acción legendaria'**
  String get creatureLegendaryAction;

  /// No description provided for @feedbackButton.
  ///
  /// In es, this message translates to:
  /// **'Sugerencias y errores'**
  String get feedbackButton;

  /// No description provided for @feedbackTitle.
  ///
  /// In es, this message translates to:
  /// **'Sugerencias y errores'**
  String get feedbackTitle;

  /// No description provided for @feedbackKindIdea.
  ///
  /// In es, this message translates to:
  /// **'Una idea'**
  String get feedbackKindIdea;

  /// No description provided for @feedbackKindBug.
  ///
  /// In es, this message translates to:
  /// **'Un error'**
  String get feedbackKindBug;

  /// No description provided for @feedbackMessageLabel.
  ///
  /// In es, this message translates to:
  /// **'Mensaje'**
  String get feedbackMessageLabel;

  /// No description provided for @feedbackHintIdea.
  ///
  /// In es, this message translates to:
  /// **'¿Qué te gustaría poder hacer, y para qué lo usarías en tu mesa?'**
  String get feedbackHintIdea;

  /// No description provided for @feedbackHintBug.
  ///
  /// In es, this message translates to:
  /// **'¿Qué estabas haciendo, qué esperabas y qué pasó?'**
  String get feedbackHintBug;

  /// Debajo del mensaje; {email} es el correo de la cuenta con la que se entró.
  ///
  /// In es, this message translates to:
  /// **'Te respondemos a {email}.'**
  String feedbackReplyTo(String email);

  /// No description provided for @feedbackSend.
  ///
  /// In es, this message translates to:
  /// **'Enviar'**
  String get feedbackSend;

  /// No description provided for @feedbackSendError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo enviar el mensaje'**
  String get feedbackSendError;

  /// No description provided for @feedbackSent.
  ///
  /// In es, this message translates to:
  /// **'¡Gracias! Recibimos tu mensaje.'**
  String get feedbackSent;

  /// No description provided for @errorReport.
  ///
  /// In es, this message translates to:
  /// **'Reportar este error'**
  String get errorReport;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
