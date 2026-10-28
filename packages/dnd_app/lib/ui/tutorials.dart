import 'package:flutter/material.dart';

import '../l10n/l10n_context.dart';
import '../theme/app_widgets.dart';
import '../web/browser.dart' as browser;

/// Una página de un tutorial: ícono, título y un párrafo.
typedef TutorialPage = (IconData icon, String title, String body);

/// Los tutoriales de la app. El nombre de cada valor es lo que se guarda en el
/// navegador para recordar que ya se vio, así que renombrarlo lo vuelve a
/// mostrar.
///
/// [welcome] es el panorama general (los dos modos) y sale al entrar por
/// primera vez; el resto sale la primera vez que se abre esa sección.
enum Tutorial {
  welcome,
  sheet,
  dmTable,
  dmChapters,
  dmNotebook,
  dmNpcs,
  dmCombat,
  bestiary,
  npcLibrary,
  homebrew;

  List<TutorialPage> pages(AppLocalizations l10n) => switch (this) {
    Tutorial.welcome => [
      (Icons.waving_hand_outlined, l10n.tutWelcomeTitle, l10n.tutWelcomeBody),
      (Icons.casino_outlined, l10n.tutNewToDndTitle, l10n.tutNewToDndBody),
      (Icons.person_outline, l10n.tutPlayerTitle, l10n.tutPlayerBody),
      (Icons.shield_moon_outlined, l10n.tutDmTitle, l10n.tutDmBody),
    ],
    Tutorial.sheet => [
      (Icons.badge_outlined, l10n.tutSheet1Title, l10n.tutSheet1Body),
      (Icons.sports_martial_arts, l10n.tutSheet2Title, l10n.tutSheet2Body),
      (Icons.ios_share, l10n.tutSheet3Title, l10n.tutSheet3Body),
    ],
    Tutorial.dmTable => [
      (Icons.groups_outlined, l10n.tutDmTable1Title, l10n.tutDmTable1Body),
      (Icons.visibility_outlined, l10n.tutDmTable2Title, l10n.tutDmTable2Body),
    ],
    Tutorial.dmChapters => [
      (
        Icons.auto_stories_outlined,
        l10n.tutDmChapters1Title,
        l10n.tutDmChapters1Body,
      ),
      (Icons.flag_outlined, l10n.tutDmChapters2Title, l10n.tutDmChapters2Body),
    ],
    Tutorial.dmNotebook => [
      (
        Icons.menu_book_outlined,
        l10n.tutDmNotebook1Title,
        l10n.tutDmNotebook1Body,
      ),
      (
        Icons.alternate_email,
        l10n.tutDmNotebook2Title,
        l10n.tutDmNotebook2Body,
      ),
    ],
    Tutorial.dmNpcs => [
      (Icons.groups_2_outlined, l10n.tutDmNpcs1Title, l10n.tutDmNpcs1Body),
      (Icons.tune, l10n.tutDmNpcs2Title, l10n.tutDmNpcs2Body),
    ],
    Tutorial.dmCombat => [
      (
        Icons.local_fire_department_outlined,
        l10n.tutDmCombat1Title,
        l10n.tutDmCombat1Body,
      ),
      (Icons.repeat, l10n.tutDmCombat2Title, l10n.tutDmCombat2Body),
      (
        Icons.music_note_outlined,
        l10n.tutDmCombat3Title,
        l10n.tutDmCombat3Body,
      ),
    ],
    Tutorial.bestiary => [
      (Icons.pets_outlined, l10n.tutBestiary1Title, l10n.tutBestiary1Body),
      (Icons.edit_outlined, l10n.tutBestiary2Title, l10n.tutBestiary2Body),
    ],
    Tutorial.npcLibrary => [
      (
        Icons.contacts_outlined,
        l10n.tutNpcLibrary1Title,
        l10n.tutNpcLibrary1Body,
      ),
      (Icons.swap_horiz, l10n.tutNpcLibrary2Title, l10n.tutNpcLibrary2Body),
    ],
    Tutorial.homebrew => [
      (Icons.auto_fix_high, l10n.tutHomebrew1Title, l10n.tutHomebrew1Body),
      (Icons.ios_share, l10n.tutHomebrew2Title, l10n.tutHomebrew2Body),
    ],
  };
}

/// Qué tutoriales ya se vieron. Va en el navegador y no en la cuenta, como el
/// idioma: guardarlo en la cuenta pedía esquema, ruta y migración para algo
/// que, si reaparece en otro dispositivo, se cierra con un toque.
class Tutorials {
  final void Function(String value) write;

  /// Lo guardado es la lista de nombres separada por comas, o `*` cuando la
  /// persona eligió «Saltar todos».
  final Set<String> _seen;

  static const _all = '*';

  /// Los puntos de contacto con el navegador se inyectan para los tests; por
  /// defecto son los reales de `browser.dart`.
  Tutorials({
    String? Function() read = browser.readStoredTutorials,
    this.write = browser.writeStoredTutorials,
  }) : _seen = _safeRead(read);

  static Set<String> _safeRead(String? Function() read) {
    try {
      return {...?read()?.split(',').where((s) => s.isNotEmpty)};
    } catch (_) {
      // Almacenamiento bloqueado: se muestran, y saltarlos vale para la
      // sesión. Es lo mismo que pasaría la primera vez.
      return {};
    }
  }

  bool isPending(Tutorial t) =>
      !_seen.contains(_all) && !_seen.contains(t.name);

  void markSeen(Tutorial t) => _save(() => _seen.add(t.name));

  void skipAll() => _save(() => _seen.add(_all));

  /// Lo que ofrece Ajustes: vuelven a salir todos, cada uno en su sección.
  void reset() => _save(_seen.clear);

  void _save(void Function() change) {
    change();
    try {
      write(_seen.join(','));
    } catch (_) {
      // Sin almacenamiento vale igual durante la sesión; solo no se recuerda.
    }
  }
}

/// La única instancia de la app: lo visto es de la pestaña entera.
final tutorials = Tutorials();

/// Muestra [tutorial] si todavía no se vio. Uno a la vez: si ya hay otro
/// abierto, este espera a la próxima vez que se entre a su sección.
Future<void> showTutorialIfPending(
  BuildContext context,
  Tutorial tutorial, {
  Tutorials? store,
}) async {
  final s = store ?? tutorials;
  if (_showing || !s.isPending(tutorial)) return;
  _showing = true;
  try {
    final skipAll = await showDialog<bool>(
      context: context,
      builder: (_) => _TutorialDialog(tutorial),
    );
    // Cerrarlo de cualquier forma cuenta como visto: un tutorial que vuelve
    // cada vez que se toca afuera es peor que no tenerlo.
    if (skipAll == true) {
      s.skipAll();
    } else {
      s.markSeen(tutorial);
    }
  } finally {
    _showing = false;
  }
}

bool _showing = false;

/// Muestra el tutorial de una sección la primera vez que se monta. Va con
/// `key` por sección: cambiar de sección crea otro estado y vuelve a mirar.
class TutorialGate extends StatefulWidget {
  final Tutorial tutorial;
  final Widget child;

  const TutorialGate({super.key, required this.tutorial, required this.child});

  @override
  State<TutorialGate> createState() => _TutorialGateState();
}

class _TutorialGateState extends State<TutorialGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showTutorialIfPending(context, widget.tutorial);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Devuelve `true` si se eligió «Saltar todos».
class _TutorialDialog extends StatefulWidget {
  final Tutorial tutorial;

  const _TutorialDialog(this.tutorial);

  @override
  State<_TutorialDialog> createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<_TutorialDialog> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pages = widget.tutorial.pages(l10n);
    final (icon, title, body) = pages[_page];
    final last = _page == pages.length - 1;
    return AppDialog(
      icon: icon,
      title: title,
      // El paso solo cuando hay más de uno: «1/1» no dice nada.
      titleTrailing: pages.length > 1
          ? GoldPill('${_page + 1}/${pages.length}')
          : null,
      content: Text(body),
      actions: [
        DialogAction(
          l10n.tutSkipAll,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        // «Saltar» y «Entendido» harían lo mismo en la última página.
        if (!last)
          DialogAction(
            l10n.tutSkip,
            keyHint: 'Esc',
            onPressed: () => Navigator.of(context).pop(false),
          ),
        DialogAction(
          last ? l10n.tutDone : l10n.tutNext,
          primary: true,
          onPressed: last
              ? () => Navigator.of(context).pop(false)
              : () => setState(() => _page++),
        ),
      ],
    );
  }
}
