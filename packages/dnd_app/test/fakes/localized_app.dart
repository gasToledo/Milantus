import 'package:dnd_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// `MaterialApp` con los delegates de localización, para los tests que montan
/// un widget suelto en vez de `DndApp`.
///
/// Sin esto, cualquier pantalla que lea `AppLocalizations.of(context)` falla
/// en el test aunque no tenga nada que ver con el idioma. El locale por
/// defecto es español —el idioma de origen— para que los `find.text` de los
/// tests existentes sigan valiendo; un test de inglés lo pasa explícito.
MaterialApp localizedApp({
  ThemeData? theme,
  ThemeData? darkTheme,
  ThemeMode themeMode = ThemeMode.system,
  Locale locale = const Locale('es'),
  Widget? home,
  TransitionBuilder? builder,
}) => MaterialApp(
  theme: theme,
  darkTheme: darkTheme,
  themeMode: themeMode,
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
  builder: builder,
);

/// Los textos en español, para los tests que llaman a funciones que reciben
/// `AppLocalizations` (por ejemplo `describeEffect`) sin montar un árbol.
AppLocalizations get l10nEs => lookupAppLocalizations(const Locale('es'));
