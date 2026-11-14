import 'content_language.dart';
import 'data_version.dart';

/// En qué punto de su vida está un capítulo.
///
/// El nombre "capítulo" y no "misión" es deliberado: describe una campaña que
/// avanza en el tiempo, no una lista de encargos paralelos que se cumplen o se
/// fallan. Por eso los estados son una línea y no un resultado.
enum ChapterState {
  planned('Planificado'),
  active('En marcha'),
  completed('Completado');

  const ChapterState(this.label);

  /// Nombre en español, para la UI.
  final String label;

  String toJson() => name;

  /// Tolerante: ausente o desconocido devuelve [ChapterState.planned], que es
  /// el estado en que nace todo capítulo.
  static ChapterState fromJson(String? v) {
    for (final s in ChapterState.values) {
      if (s.name == v) return s;
    }
    return ChapterState.planned;
  }
}

/// Un objeto del catálogo (o del homebrew del DM) que un capítulo reparte.
///
/// Guarda el [name] del momento de elegirlo: es lo que el aviso nombra aunque
/// el homebrew se borre después, y lo que ve quien no tiene ese contenido.
/// Como el resto del botín, **es un aviso**: el objeto lo agrega a su
/// inventario el jugador, nunca el DM.
class ChapterItem {
  /// Las tres categorías del catálogo de equipo donde vive un objeto.
  static const categories = {'weapons', 'armor', 'items'};

  final String category;
  final String itemId;
  final String name;

  /// Para una plantilla («Arma +1»): el objeto sobre el que se aplica.
  final String? baseItemId;

  /// Al menos 1.
  final int quantity;

  /// Si [itemId] es del homebrew del DM y no del catálogo oficial.
  final bool homebrew;

  const ChapterItem({
    required this.category,
    required this.itemId,
    required this.name,
    this.baseItemId,
    this.quantity = 1,
    this.homebrew = false,
  });

  /// «Poción de curación» o «Poción de curación ×2».
  String get label => quantity > 1 ? '$name ×$quantity' : name;

  Map<String, dynamic> toJson() => {
        'category': category,
        'itemId': itemId,
        'name': name,
        if (baseItemId != null) 'baseItemId': baseItemId,
        'quantity': quantity,
        'homebrew': homebrew,
      };

  /// `null` si lo escrito afuera no se puede leer: el capítulo no se rechaza
  /// entero por un objeto malformado, igual que con [Chapter.grantsItems].
  static ChapterItem? tryFromJson(Object? source) {
    if (source is! Map) return null;
    final category = source['category'];
    final itemId = source['itemId'];
    final name = source['name'];
    if (category is! String || !categories.contains(category)) return null;
    if (itemId is! String || itemId.trim().isEmpty) return null;
    if (name is! String || name.trim().isEmpty) return null;
    final base = source['baseItemId'];
    final quantity = source['quantity'];
    return ChapterItem(
      category: category,
      itemId: itemId.trim(),
      name: name.trim(),
      baseItemId: base is String && base.trim().isNotEmpty ? base.trim() : null,
      quantity: quantity is int && quantity > 1 ? quantity : 1,
      homebrew: source['homebrew'] == true,
    );
  }
}

/// Un tramo de una campaña, tal como lo planifica y lo cierra el DM.
///
/// Es el eje temporal del que va a colgar el cuaderno de campaña y el
/// archivado de los combates: por eso existe antes que ellos.
///
/// Igual que [Campaign], el documento **no** dice de quién es ni a qué campaña
/// pertenece: eso lo establece la fila que lo guarda, no el JSON.
class Chapter {
  /// Versión del formato de este documento. Mismo contrato que
  /// `Character.currentSchemaVersion` y `Campaign.currentSchemaVersion`.
  ///
  /// 2: suma [grantsCatalog]. Un capítulo de la versión 1 se lee igual, sin
  /// objetos del catálogo.
  /// 3: suma [entryOrder]. Uno anterior se lee sin orden propio: el Cuaderno
  /// lo muestra por fecha, como antes.
  static const int currentSchemaVersion = 3;

  final String id;
  final String name;

  /// Objetivo o premisa breve de este tramo de la historia. La escribe el DM
  /// y **no la ve ningún jugador** — de un capítulo solo se entera cuando ya
  /// está cerrado, y ni siquiera entonces se le muestra este texto.
  final String summary;

  final ChapterState state;

  /// Al cerrar este capítulo, a los personajes de la mesa les corresponde
  /// subir de nivel.
  ///
  /// Es **solo un aviso**: la app nunca sube a nadie de nivel. El nivel y los
  /// PG por nivel de un personaje son dos listas que el asistente de subida
  /// mantiene en sincronía, y ese asistente es del jugador. Que el DM lo
  /// ejecutara rompería tanto la ficha como la frontera de "el DM no toca
  /// construcción".
  final bool grantsLevel;

  /// Oro que le toca a **cada personaje** al cerrarse, ya repartido.
  ///
  /// Ya repartido porque la app no divide botín: no sabe cuántos jugadores
  /// hubo en la mesa esa noche ni cómo acordaron partirlo, y adivinarlo sería
  /// meterse en una discusión que es de la mesa.
  ///
  /// Mismo aviso que [grantsLevel]: **no se le suma a ninguna ficha**. La
  /// bolsa de un personaje la escribe su jugador; que la escribiera el DM
  /// cruzaría la misma frontera, y encima pisaría al jugador que justo está
  /// gastando en la taberna.
  final int grantsGold;

  /// Ítems que se llevan, por nombre libre.
  ///
  /// Texto y no ids del catálogo a propósito: medio botín de una mesa («el
  /// mapa del contrabandista», «tres gemas del cofre») no está en ningún
  /// catálogo, y como el aviso lo copia a mano el jugador en su ficha, un id
  /// no le ahorraría nada.
  final List<String> grantsItems;

  /// Los objetos del catálogo o del homebrew que se llevan, aparte del texto
  /// libre de [grantsItems]. A quién le toca cada uno se decide al cerrar y
  /// **no se guarda acá**: el capítulo cerrado dice qué se repartió, no a quién.
  final List<ChapterItem> grantsCatalog;

  /// El orden en que el DM acomodó las entradas de este capítulo en el
  /// Cuaderno: claves `note:<id>`, `fight:<id>` o `levelUp:<id>`. Lo que no
  /// figura (lo nuevo, o un capítulo que nunca se ordenó) va después, por
  /// fecha.
  ///
  /// Vive en el capítulo y no en cada fila porque mover una entrada es así una
  /// sola escritura, como el orden de la Mesa en `Campaign.memberOrder`. Es
  /// material del DM: **no viaja al jugador** (ver la poda del servidor).
  final List<String> entryOrder;

  const Chapter({
    required this.id,
    required this.name,
    this.summary = '',
    this.state = ChapterState.planned,
    this.grantsLevel = false,
    this.grantsGold = 0,
    this.grantsItems = const [],
    this.grantsCatalog = const [],
    this.entryOrder = const [],
  });

  /// Si el cierre reparte algo además del aviso de subir de nivel.
  bool get grantsRewards =>
      grantsGold > 0 || grantsItems.isNotEmpty || grantsCatalog.isNotEmpty;

  /// Los nombres de todo lo que se lleva: primero el texto libre y después los
  /// objetos del catálogo («Nombre» o «Nombre ×2»).
  List<String> get itemLabels => [
        ...grantsItems,
        for (final item in grantsCatalog) item.label,
      ];

  /// El botín en una línea, o vacío si no hay ninguno. Sin el nivel: en la
  /// lista de capítulos ese ya se ve como marca aparte.
  String get rewardsLabel => describeRewards(grantsGold, itemLabels);

  /// Todo lo que reparte al cerrarse, el nivel incluido, en una línea sola.
  String get grantsLabel =>
      describeRewards(grantsGold, itemLabels, level: grantsLevel);

  Chapter copyWith({
    String? name,
    String? summary,
    ChapterState? state,
    bool? grantsLevel,
    int? grantsGold,
    List<String>? grantsItems,
    List<ChapterItem>? grantsCatalog,
    List<String>? entryOrder,
  }) =>
      Chapter(
        id: id,
        name: name ?? this.name,
        summary: summary ?? this.summary,
        state: state ?? this.state,
        grantsLevel: grantsLevel ?? this.grantsLevel,
        grantsGold: grantsGold ?? this.grantsGold,
        grantsItems: grantsItems ?? this.grantsItems,
        grantsCatalog: grantsCatalog ?? this.grantsCatalog,
        entryOrder: entryOrder ?? this.entryOrder,
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': currentSchemaVersion,
        'id': id,
        'name': name,
        'summary': summary,
        'state': state.toJson(),
        'grantsLevel': grantsLevel,
        'grantsGold': grantsGold,
        'grantsItems': grantsItems,
        'grantsCatalog': [for (final item in grantsCatalog) item.toJson()],
        if (entryOrder.isNotEmpty) 'entryOrder': entryOrder,
      };

  factory Chapter.fromJson(Map<String, dynamic> source) {
    final j = migrateJson(source);
    return Chapter(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      summary: j['summary'] as String? ?? '',
      state: ChapterState.fromJson(j['state'] as String?),
      grantsLevel: j['grantsLevel'] as bool? ?? false,
      // El botín se limpia acá y no en el constructor porque este es el único
      // borde por el que entra algo escrito afuera. Oro negativo y nombres en
      // blanco se descartan en vez de rechazar el capítulo entero: no hay
      // nada que un DM pueda arreglar leyendo un error sobre eso.
      grantsGold: switch (j['grantsGold']) {
        final int gold when gold > 0 => gold,
        _ => 0,
      },
      grantsItems: [
        for (final item in (j['grantsItems'] as List? ?? const []))
          if (item is String && item.trim().isNotEmpty) item.trim(),
      ],
      grantsCatalog: [
        for (final raw in (j['grantsCatalog'] as List? ?? const []))
          if (ChapterItem.tryFromJson(raw) case final item?) item,
      ],
      // Mismo criterio que el botín: una clave que no es texto se descarta, y
      // una repetida también (el orden la dejaría en dos lugares).
      entryOrder: [
        ...{
          for (final key in (j['entryOrder'] as List? ?? const []))
            if (key is String && key.isNotEmpty) key,
        },
      ],
    );
  }

  static int schemaVersionOf(Map<String, dynamic> json) {
    final value = json['schemaVersion'] ?? 1;
    if (value is! int || value < 1) {
      throw const FormatException(
        'La versión del capítulo debe ser un entero positivo.',
      );
    }
    return value;
  }

  /// Mismo contrato que `Campaign.migrateJson`: no muta la entrada, y rechaza
  /// una versión futura en vez de guardarla de vuelta perdiendo los campos que
  /// esta versión no entiende.
  static Map<String, dynamic> migrateJson(Map<String, dynamic> source) {
    final version = schemaVersionOf(source);
    if (version > currentSchemaVersion) {
      throw UnsupportedDataVersionException(
        dataType: 'capítulo',
        found: version,
        supported: currentSchemaVersion,
      );
    }
    // 1 → 2 y 2 → 3: cada una solo suma un campo opcional, así que migrar es
    // sellar la versión.
    return Map<String, dynamic>.from(source)
      ..['schemaVersion'] = currentSchemaVersion;
  }
}

/// «250 po, Espada larga +1 y Poción de curación»: cómo se nombra un botín en
/// una sola línea.
///
/// Suelta y no método de [Chapter] porque el aviso que le llega al jugador se
/// redacta desde el payload del evento, donde no hay ningún capítulo.
///
/// [level] pone «un nivel» al frente. Es una sola lista y no dos frases para
/// que no queden dos «y» seguidas: «un nivel y 250 po y una espada» se lee mal
/// en cualquier boca.
///
/// Sale en el idioma activo ([ContentLanguage.current]): se arma al mostrarlo,
/// no se guarda. En inglés la lista lleva la coma antes de «and».
String describeRewards(int gold, List<String> items, {bool level = false}) {
  final parts = [
    if (level) localized('un nivel', 'a level'),
    if (gold > 0) '$gold ${localized('po', 'gp')}',
    ...items,
  ];
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts.first;
  final head = parts.take(parts.length - 1).join(', ');
  return localized(
    '$head y ${parts.last}',
    parts.length == 2 ? '$head and ${parts.last}' : '$head, and ${parts.last}',
  );
}
