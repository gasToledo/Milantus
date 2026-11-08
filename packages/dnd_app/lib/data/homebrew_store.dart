// l10n-ignore-file: errores sin contexto de interfaz, en los dos idiomas con `localized` (siguen a `ContentLanguage`, que `main.dart` fija con el idioma de la interfaz).
import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_engine/homebrew_transfer.dart'
    show countHomebrewCollisions, validateHomebrewInventoryIds;

import '../api/api_client.dart';

export 'package:dnd_engine/homebrew_references.dart' show charactersUsing;
// La lógica del archivo de homebrew vive en el motor (la comparte el cliente
// web); estas dos las siguen usando los formularios por este import.
export 'package:dnd_engine/homebrew_transfer.dart'
    show homebrewCopy, homebrewId;

class HomebrewLoadIssue {
  final String category;
  final String id;
  final String message;

  const HomebrewLoadIssue({
    required this.category,
    required this.id,
    required this.message,
  });
}

/// Contenido homebrew de la cuenta, respaldado por la API: un mapa por
/// categoría, fusionable en un [ContentRepository].
class HomebrewStore {
  final ApiClient api;
  final Map<String, Weapon> weapons = {};
  final Map<String, Armor> armor = {};
  final Map<String, Item> items = {};
  final Map<String, Feat> feats = {};
  final Map<String, Race> races = {};
  final Map<String, Background> backgrounds = {};
  final Map<String, Spell> spells = {};
  final Map<String, Creature> creatures = {};
  final List<HomebrewLoadIssue> loadIssues = [];

  HomebrewStore(this.api);

  Future<void> load() async {
    final content = await api.listHomebrew();
    loadIssues.clear();
    _loadCategory(content, 'weapons', weapons, Weapon.fromJson);
    _loadCategory(content, 'armor', armor, Armor.fromJson);
    _loadCategory(content, 'items', items, Item.fromJson);
    _loadCategory(content, 'feats', feats, Feat.fromJson);
    _loadCategory(content, 'races', races, Race.fromJson);
    _loadCategory(content, 'backgrounds', backgrounds, Background.fromJson);
    _loadCategory(content, 'spells', spells, Spell.fromJson);
    _loadCategory(content, 'creatures', creatures, Creature.fromJson);
  }

  void _loadCategory<T>(
    Map<String, List<Map<String, dynamic>>> content,
    String category,
    Map<String, T> target,
    T Function(Map<String, dynamic>) parse,
  ) {
    target.clear();
    for (final document in content[category] ?? const []) {
      final rawId = document['id'];
      final issueId = rawId is String && rawId.isNotEmpty ? rawId : '(sin id)';
      try {
        if (rawId is! String || rawId.isEmpty) {
          throw FormatException(
            localized(
              'El id está ausente o vacío.',
              'The id is missing or empty.',
            ),
          );
        }
        if (document['source'] != 'homebrew') {
          throw FormatException(
            localized(
              'El origen debe ser homebrew.',
              'The source must be homebrew.',
            ),
          );
        }
        target[rawId] = parse(document);
      } catch (error) {
        loadIssues.add(
          HomebrewLoadIssue(
            category: category,
            id: issueId,
            message: error.toString(),
          ),
        );
      }
    }
  }

  /// Todo el contenido homebrew serializado a listas JSON por tipo, para
  /// exportarlo. Las claves coinciden con las categorías del servidor.
  Map<String, List<Map<String, dynamic>>> exportContent() => {
    'weapons': weapons.values.map((e) => e.toJson()).toList(),
    'armor': armor.values.map((e) => e.toJson()).toList(),
    'items': items.values.map((e) => e.toJson()).toList(),
    'feats': feats.values.map((e) => e.toJson()).toList(),
    'races': races.values.map((e) => e.toJson()).toList(),
    'backgrounds': backgrounds.values.map((e) => e.toJson()).toList(),
    'spells': spells.values.map((e) => e.toJson()).toList(),
    'creatures': creatures.values.map((e) => e.toJson()).toList(),
  };

  /// Cuántas entradas de [content] tienen un id que **ya existe** en el store
  /// (es decir, que un [importContent] sobrescribiría). Cero = import
  /// puramente aditivo. La UI lo usa para pedir confirmación antes de pisar
  /// homebrew.
  int countCollisions(Map<String, List<Map<String, dynamic>>> content) {
    return countHomebrewCollisions(content, {
      'weapons': weapons.keys.toSet(),
      'armor': armor.keys.toSet(),
      'items': items.keys.toSet(),
      'feats': feats.keys.toSet(),
      'races': races.keys.toSet(),
      'backgrounds': backgrounds.keys.toSet(),
      'spells': spells.keys.toSet(),
      'creatures': creatures.keys.toSet(),
    });
  }

  /// Importa contenido homebrew (mismo formato que [exportContent])
  /// fusionándolo por id: una entrada con id existente se sobrescribe. El
  /// servidor valida el pack completo y lo guarda en una sola transacción.
  /// Devuelve la cantidad total de entradas importadas.
  Future<int> importContent(
    Map<String, List<Map<String, dynamic>>> content, {
    required ContentRepository repository,
  }) async {
    validateHomebrewInventoryIds(content, repository);
    final count = await api.importHomebrew(content);
    await load();
    return count;
  }

  Future<void> deleteInvalid(HomebrewLoadIssue issue) async {
    await api.deleteHomebrew(issue.category, issue.id);
    loadIssues.remove(issue);
  }

  /// Copia del contenido homebrew como repositorio, para fusionar con el oficial.
  ContentRepository toRepository() => ContentRepository(
    weapons: Map.of(weapons),
    armor: Map.of(armor),
    items: Map.of(items),
    feats: Map.of(feats),
    races: Map.of(races),
    backgrounds: Map.of(backgrounds),
    spells: Map.of(spells),
    creatures: Map.of(creatures),
  );

  Future<void> saveWeapon(Weapon w) async {
    await api.upsertHomebrew('weapons', w.toJson());
    weapons[w.id] = w;
  }

  Future<void> saveArmor(Armor a) async {
    await api.upsertHomebrew('armor', a.toJson());
    armor[a.id] = a;
  }

  Future<void> saveItem(Item i) async {
    await api.upsertHomebrew('items', i.toJson());
    items[i.id] = i;
  }

  Future<void> saveFeat(Feat f) async {
    await api.upsertHomebrew('feats', f.toJson());
    feats[f.id] = f;
  }

  Future<void> saveRace(Race r) async {
    await api.upsertHomebrew('races', r.toJson());
    races[r.id] = r;
  }

  Future<void> saveBackground(Background b) async {
    await api.upsertHomebrew('backgrounds', b.toJson());
    backgrounds[b.id] = b;
  }

  Future<void> saveSpell(Spell s) async {
    await api.upsertHomebrew('spells', s.toJson());
    spells[s.id] = s;
  }

  Future<void> saveCreature(Creature c) async {
    await api.upsertHomebrew('creatures', c.toJson());
    creatures[c.id] = c;
  }

  Future<void> deleteWeapon(String id) async {
    await api.deleteHomebrew('weapons', id);
    weapons.remove(id);
  }

  Future<void> deleteArmor(String id) async {
    await api.deleteHomebrew('armor', id);
    armor.remove(id);
  }

  Future<void> deleteItem(String id) async {
    await api.deleteHomebrew('items', id);
    items.remove(id);
  }

  Future<void> deleteFeat(String id) async {
    await api.deleteHomebrew('feats', id);
    feats.remove(id);
  }

  Future<void> deleteRace(String id) async {
    await api.deleteHomebrew('races', id);
    races.remove(id);
  }

  Future<void> deleteBackground(String id) async {
    await api.deleteHomebrew('backgrounds', id);
    backgrounds.remove(id);
  }

  Future<void> deleteSpell(String id) async {
    await api.deleteHomebrew('spells', id);
    spells.remove(id);
  }

  Future<void> deleteCreature(String id) async {
    await api.deleteHomebrew('creatures', id);
    creatures.remove(id);
  }
}
