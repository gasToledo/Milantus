import 'dart:convert';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/homebrew_store.dart';
import '../data/transfer_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import '../web/browser.dart' as browser;
import '../l10n/l10n_context.dart';

part 'effect_editor.dart';
part 'forms/armor_form.dart';
part 'forms/background_form.dart';
part 'forms/creature_form.dart';
part 'forms/feat_form.dart';
part 'forms/form_widgets.dart';
part 'forms/item_form.dart';
part 'forms/race_form.dart';
part 'forms/spell_form.dart';
part 'forms/weapon_form.dart';
part 'homebrew_sections.dart';

// Los ids son el contrato con el motor de reglas y no cambian; lo que cambia
// es que dejan de estar a la vista. Las habilidades salen de `Skill`, que ya es
// la única fuente de la traducción (ver `skill.dart`) — repetirlas acá era
// arriesgarse a que las dos listas se separaran.
final _skillOptions = _sortedByLabel({
  for (final id in Skill.allIds) id: Skill.labelFor(id),
});

/// Tipos de daño por su nombre, en el mismo orden que [_skillOptions].
final _damageTypeOptions = _sortedByLabel({
  for (final t in DamageType.values) t.id: t.label,
});

/// Las opciones en orden alfabético castellano. Los ids vienen en el orden
/// del manual en inglés, y mostrados tal cual dejaban «Trato con Animales»
/// segunda y «Relámpago» antes de «Necrótico»: quien busca una opción en
/// castellano no la encuentra donde la espera.
Map<String, String> _sortedByLabel(Map<String, String> options) =>
    Map.fromEntries(
      options.entries.toList()
        ..sort((a, b) => _sortKey(a.value).compareTo(_sortKey(b.value))),
    );

/// Sin tildes y en minúscula, para que «Ácido» no quede después de la z.
// l10n-ignore: tabla de acentos para ordenar, no texto de la interfaz.
String _sortKey(String label) => label.toLowerCase().replaceAllMapped(
  RegExp('[áéíóúü]'),
  (m) =>
      const {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u'}[m[0]]!,
);

/// Propiedades de arma, tomadas del glosario del motor: la misma fuente que
/// explica cada una en el formulario, así el nombre y la regla no se separan.
final _weaponPropOptions = {
  for (final p in weaponProperties.values) p.id: p.name,
};

Map<String, String> _weaponCategories(AppLocalizations l10n) => {
  'simple': l10n.hbSimple,
  'martial': l10n.hbMartial,
};

/// Maestrías con arma, tomadas del glosario del motor: es la única fuente de
/// la traducción y la ficha ya la usa para la píldora del ataque. La cadena
/// vacía significa "sin maestría" por el mismo motivo que [_mundane]: el
/// desplegable no acepta una opción nula.
Map<String, String> _masteryOptions(AppLocalizations l10n) => {
  '': l10n.hbNoMastery,
  for (final m in weaponMasteries.values) m.id: m.name,
};

Map<String, String> _armorCategories(AppLocalizations l10n) => {
  'light': l10n.hbLight,
  'medium': l10n.hbMedium,
  'heavy': l10n.hbHeavy,
  'shield': l10n.kindShield,
};

/// Familias de objeto. `magic` no está: lo que hace mágico a un objeto es
/// tener rareza, y ofrecer las dos cosas dejaría guardar un objeto de categoría
/// mágica sin rareza, que el motor trata como mundano.
Map<String, String> _itemCategories(AppLocalizations l10n) => {
  'gear': l10n.kindGear,
  'tool': l10n.kindTool,
  'ammunition': l10n.kindAmmunition,
  'focus': l10n.kindFocus,
  'pack': l10n.kindPack,
  'container': l10n.kindContainer,
};

/// Valor del desplegable de rareza que significa "no es mágico". Va como texto
/// y no como null porque el desplegable no acepta una opción nula.
const _mundane = 'mundane';

Map<String, String> _itemRarities(AppLocalizations l10n) => {
  _mundane: l10n.hbMundane,
  ...itemRarityLabels,
};

Map<String, String> _featCategories(AppLocalizations l10n) => {
  'origin': l10n.hbFeatOrigin,
  'general': l10n.hbFeatGeneral,
  'fighting-style': l10n.hbFeatFighting,
  'dragonmark': l10n.hbFeatDragonmark,
  'epic-boon': l10n.hbFeatEpic,
};

/// Tamaños que el contenido oficial usa. A diferencia del resto, acá el valor
/// guardado ya está en español (`Race.size`), así que id y etiqueta coinciden.
// l10n-ignore: los ids son el valor guardado (`Race.size`), no texto.
Map<String, String> _raceSizes(AppLocalizations l10n) => {
  'Pequeño': l10n.sizeSmall,
  'Mediano': l10n.sizeMedium,
  'Grande': l10n.sizeLarge,
};

/// Las ocho categorías de contenido propio, en el orden en que se muestran.
///
/// Tenerlas acá —con su rótulo, su ícono y el verbo de agregar— es lo que
/// mantiene juntos el panel, la portada y el contenido: sumar una categoría es
/// sumar un valor y su `case`, no acordarse de tres listas paralelas que
/// después se separan (que es lo que pasaba con las ocho pestañas escritas a
/// mano al lado de las ocho vistas).
enum _Category {
  weapons(Icons.hardware),
  armor(Icons.shield_outlined),
  items(Icons.inventory_2_outlined),
  feats(Icons.military_tech),
  races(Icons.diversity_3),
  backgrounds(Icons.history_edu),
  spells(Icons.auto_stories),
  creatures(Icons.pets_outlined);

  final IconData icon;

  const _Category(this.icon);

  /// El nombre de la categoría en el idioma activo.
  String label(AppLocalizations l10n) => switch (this) {
    _Category.weapons => l10n.groupWeapons,
    _Category.armor => l10n.groupArmor,
    _Category.items => l10n.catItems,
    _Category.feats => l10n.catFeats,
    _Category.races => l10n.catRaces,
    _Category.backgrounds => l10n.catBackgrounds,
    _Category.spells => l10n.spellsTitle,
    _Category.creatures => l10n.catCreatures,
  };

  /// El rótulo del botón que agrega una entrada de esta categoría.
  String addLabel(AppLocalizations l10n) => switch (this) {
    _Category.weapons => l10n.hbAddWeapon,
    _Category.armor => l10n.hbAddArmor,
    _Category.items => l10n.catalogAddTitle,
    _Category.feats => l10n.hbAddFeat,
    _Category.races => l10n.hbAddSpecies,
    _Category.backgrounds => l10n.hbAddBackground,
    _Category.spells => l10n.hbAddSpell,
    _Category.creatures => l10n.hbAddCreature,
  };
}

/// Editor de contenido homebrew, una sección del Modo DM. Lo creado se fusiona
/// en el [ContentRepository] compartido, así queda disponible de inmediato en
/// el wizard y la ficha.
class HomebrewView extends StatefulWidget {
  final ContentRepository repo;
  final HomebrewStore store;

  /// Las fichas de la cuenta, para poder decir quién usa lo que se va a
  /// borrar. Es una foto y no un controlador porque desde acá no se puede
  /// tocar un personaje: mientras esta pantalla está abierta, la lista no
  /// cambia.
  final List<Character> characters;

  const HomebrewView({
    super.key,
    required this.repo,
    required this.store,
    this.characters = const [],
  });

  @override
  State<HomebrewView> createState() => _HomebrewViewState();
}

class _HomebrewViewState extends State<HomebrewView> {
  /// Ancho a partir del cual el panel de categorías entra al lado del
  /// contenido. Es el mismo corte que el Modo DM y el dashboard.
  static const double _wideBreakpoint = 900;

  ContentRepository get repo => widget.repo;
  HomebrewStore get store => widget.store;

  /// Categoría abierta, o **null para la portada**.
  ///
  /// La portada es la entrada por defecto y no una categoría más: no tiene
  /// lista ni botón de agregar, y representarla como la ausencia de categoría
  /// evita darle a `_Category` un valor que ninguna de las ocho vistas sabría
  /// atender. Es el mismo trato que le da el Modo DM al Bestiario.
  _Category? _section;

  /// Lo que se está buscando, **en todas las categorías a la vez**.
  ///
  /// Con contenido propio uno se acuerda del nombre, no de en qué categoría lo
  /// guardó, así que la búsqueda no vive dentro de una sección: mientras haya
  /// texto, el contenido son los resultados y el panel cuenta coincidencias.
  final _searchController = TextEditingController();
  String _query = '';

  String get _needle => _query.trim();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  /// Abre una categoría, o la portada con `null`. Vive en el estado y no en la
  /// extensión porque `setState` es protegido: desde afuera de la clase no se
  /// puede llamar.
  ///
  /// Elegir una sección **cancela la búsqueda**: pedir una categoría y seguir
  /// viendo resultados mezclados sería contestar otra cosa.
  void _open(_Category? section) {
    _searchController.clear();
    setState(() {
      _section = section;
      _query = '';
    });
  }

  void _search(String value) => setState(() => _query = value);

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  /// Confirma un guardado. Sin este aviso, guardar y salir del formulario se
  /// ve igual que cancelar: se vuelve a la misma lista.
  void _saved(String name) {
    _refresh();
    if (mounted) {
      showAppMessage(
        context,
        context.l10n.hbSaved(name),
        tone: AppMessageTone.success,
      );
    }
  }

  /// Y su contrario: salir del formulario sin guardar tiene que decirlo, o
  /// queda la duda de si el cambio entró.
  void _discarded() {
    if (mounted) showAppMessage(context, context.l10n.hbNoChanges);
  }

  /// Ejecuta una escritura en disco del store homebrew; si falla (permisos,
  /// disco lleno) lo muestra en vez de dejar la excepción sin capturar.
  Future<bool> _persist(Future<void> Function() write) async {
    try {
      await write();
      return true;
    } catch (e) {
      if (mounted) {
        showAppMessage(
          context,
          failureMessage(context.l10n.hbSaveError, e),
          tone: AppMessageTone.error,
        );
      }
      return false;
    }
  }

  Future<void> _exportHomebrew() async {
    final content = store.exportContent();
    final total = content.values.fold<int>(0, (s, l) => s + l.length);
    if (total == 0) {
      showAppMessage(context, context.l10n.hbNothingToExport);
      return;
    }
    final transfer = TransferService(store.api);
    browser.downloadBytes(
      transfer.exportHomebrew(content),
      fileName: transfer.homebrewExportFileName(),
      mimeType: 'application/json',
    );
    showAppMessage(
      context,
      context.l10n.hbExported(total),
      tone: AppMessageTone.success,
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> _importHomebrew() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
      dialogTitle: context.l10n.hbPickFile,
    );
    final file = picked?.files.singleOrNull;
    if (file?.bytes == null || !mounted) return;
    try {
      final content = TransferService.parseHomebrewImport(
        utf8.decode(file!.bytes!),
      );
      if (!mounted) return;
      // No pisar homebrew existente sin avisar: si hay ids en colisión, pedir
      // confirmación antes de sobrescribir.
      final collisions = store.countCollisions(content);
      if (collisions > 0) {
        final overwrite = await showDialog<bool>(
          context: context,
          builder: (ctx) => AppDialog(
            icon: Icons.warning_amber_rounded,
            iconColor: context.palette.crimson,
            title: context.l10n.hbOverwriteTitle,
            content: Text(context.l10n.hbOverwriteBody(collisions)),
            actions: [
              DialogAction(
                context.l10n.commonCancel,
                keyHint: 'Esc',
                onPressed: () => Navigator.pop(ctx, false),
              ),
              DialogAction(
                context.l10n.hbOverwrite,
                primary: true,
                color: context.palette.crimson,
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        );
        if (overwrite != true || !mounted) return;
      }
      final count = await store.importContent(content, repository: repo);
      // Fusiona lo importado en el repo compartido, así queda disponible de
      // inmediato en el wizard y las fichas (igual que al guardar un ítem).
      repo.addAll(store.toRepository());
      if (!mounted) return;
      setState(() {});
      showAppMessage(
        context,
        context.l10n.hbImported(count),
        tone: AppMessageTone.success,
      );
    } catch (e) {
      if (mounted) {
        showAppMessage(
          context,
          failureMessage(context.l10n.hbImportError, e),
          tone: AppMessageTone.error,
        );
      }
    }
  }

  Future<void> _deleteInvalid(HomebrewLoadIssue issue) async {
    final deleted = await _persist(() => store.deleteInvalid(issue));
    if (deleted && mounted) setState(() {});
  }

  /// Aviso de lo que no se pudo cargar.
  ///
  /// Es una placa hundida con filete y el carmesí solo en el ícono, y no la
  /// banda `errorContainer` de Material que era: el problema es de dos
  /// entradas, no de la pantalla, y pintarla entera de rojo le daba el peso de
  /// una falla general.
  Widget _loadIssues() {
    final pal = context.palette;
    final n = store.loadIssues.length;
    return Container(
      decoration: BoxDecoration(
        color: pal.plaque,
        border: Border(bottom: BorderSide(color: pal.hairline)),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(Icons.warning_amber_rounded, color: pal.crimson),
        iconColor: pal.textMuted,
        collapsedIconColor: pal.textMuted,
        title: Text(
          context.l10n.hbLoadIssues(n),
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: Text(
          context.l10n.hbSkipped(n),
          style: TextStyle(fontSize: 13, color: pal.textMuted),
        ),
        children: [
          for (final issue in store.loadIssues)
            ListTile(
              dense: true,
              title: Text('${issue.category} · ${issue.id}'),
              subtitle: Text(issue.message),
              trailing: IconButton(
                tooltip: context.l10n.hbDeleteInvalid,
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteInvalid(issue),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // `LayoutBuilder` y no `MediaQuery`: es una sección del Modo DM, que ya se
    // comió 236 px de panel que `MediaQuery` no descuenta.
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= _wideBreakpoint;
        return Scaffold(
          // Angosto, el panel de categorías se pliega a un Drawer que se abre
          // desde esta barra. No es la barra de la app: la del Modo DM queda
          // arriba con su propio menú, que es por donde se sale de acá. Por
          // eso el botón dice qué abre en vez de heredar el «menú» genérico,
          // y no usa el mismo ícono: dos ☰ apilados no se distinguían.
          appBar: wide
              ? null
              : AppBar(
                  primary: false,
                  toolbarHeight: 48,
                  leading: Builder(
                    builder: (context) => IconButton(
                      tooltip: context.l10n.hbCategoriesTooltip,
                      icon: const Icon(Icons.category_outlined),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  title: Text(
                    _needle.isNotEmpty
                        ? context.l10n.hbTitleSearch
                        : context.l10n.hbTitleSection(
                            _section?.label(context.l10n) ??
                                context.l10n.codexHome,
                          ),
                  ),
                ),
          drawer: wide
              ? null
              : Drawer(child: SafeArea(child: _rail(context, inDrawer: true))),
          body: Column(
            children: [
              // El aviso va arriba de todo y a lo ancho: habla del contenido
              // entero, no de la categoría que se esté mirando.
              if (store.loadIssues.isNotEmpty) _loadIssues(),
              Expanded(
                child: wide
                    ? Row(
                        children: [
                          _rail(context),
                          Expanded(child: _content()),
                        ],
                      )
                    : _content(),
              ),
            ],
          ),
        );
      },
    );
  }
}
