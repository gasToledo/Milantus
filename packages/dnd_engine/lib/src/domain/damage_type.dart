import 'content_language.dart';
import 'name_sort.dart';

/// Los 13 tipos de daño de 5e, con su nombre según la tabla "Tipos de daño"
/// del PHB 2024, en español y en inglés.
///
/// El contenido los referencia por [id] en inglés, que es la clave estable que
/// viaja en los JSON y en los personajes guardados; este enum es la única
/// fuente de la traducción, para que no se repartan por la UI.
enum DamageType {
  acid(
    'acid',
    ('Ácido', 'Acid'),
    (
      'Líquidos corrosivos y enzimas digestivas.',
      'Corrosive liquids and digestive enzymes.',
    ),
  ),
  bludgeoning(
    'bludgeoning',
    ('Contundente', 'Bludgeoning'),
    (
      'Golpes con objetos romos, constricción y caídas.',
      'Blunt objects, constriction, and falling.',
    ),
  ),
  cold(
    'cold',
    ('Frío', 'Cold'),
    ('Agua helada y ráfagas gélidas.', 'Freezing water and icy blasts.'),
  ),
  fire(
    'fire',
    ('Fuego', 'Fire'),
    ('Llamas y calor insoportable.', 'Flames and unbearable heat.'),
  ),
  force(
    'force',
    ('Fuerza', 'Force'),
    ('Energía mágica pura.', 'Pure magical energy.'),
  ),
  lightning(
    'lightning',
    ('Relámpago', 'Lightning'),
    ('Electricidad.', 'Electricity.'),
  ),
  necrotic(
    'necrotic',
    ('Necrótico', 'Necrotic'),
    ('Energía que drena la vida.', 'Life-draining energy.'),
  ),
  piercing(
    'piercing',
    ('Perforante', 'Piercing'),
    ('Colmillos y objetos punzantes.', 'Fangs and puncturing objects.'),
  ),
  poison(
    'poison',
    ('Veneno', 'Poison'),
    ('Gases tóxicos y venenos.', 'Toxic gas and venom.'),
  ),
  psychic(
    'psychic',
    ('Psíquico', 'Psychic'),
    ('Energía que desgarra la mente.', 'Mind-rending energy.'),
  ),
  radiant(
    'radiant',
    ('Radiante', 'Radiant'),
    (
      'Energía sagrada y radiación abrasadora.',
      'Holy energy and searing radiation.',
    ),
  ),
  slashing(
    'slashing',
    ('Cortante', 'Slashing'),
    ('Garras y objetos filosos.', 'Claws and cutting objects.'),
  ),
  thunder(
    'thunder',
    ('Trueno', 'Thunder'),
    (
      'Sonido que golpea como una onda expansiva.',
      'Concussive sound that hits like a shock wave.',
    ),
  );

  const DamageType(this.id, this._label, this._description);
  final String id;
  final (String, String) _label;
  final (String, String) _description;

  /// Nombre en el idioma activo.
  String get label => localized(_label.$1, _label.$2);

  /// Qué lo causa, con los ejemplos de la tabla del PHB. Sirve para elegir el
  /// tipo de un arma o de un conjuro propio: el nombre solo («Necrótico») no
  /// dice de dónde sale.
  String get description => localized(_description.$1, _description.$2);

  static DamageType? fromId(String id) {
    for (final t in values) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Nombre para mostrar. Si el id no está en el catálogo devuelve el id
  /// capitalizado en vez de fallar: `ImmunityEffect` también se usa hoy para
  /// inmunidad a **estados** (el Artífice es inmune a `poisoned`), y el
  /// homebrew puede traer cualquier cosa.
  static String labelFor(String id) =>
      fromId(id)?.label ??
      localized(_conditionLabels, _conditionLabelsEn)[id] ??
      titleCaseId(id);
}

/// Lo que el tipo de daño cambia en la mesa, que vale igual para los trece: no
/// va en cada [DamageType.description] para no repetirlo trece veces.
String get damageTypeRule => localized(
      'No cambia cuánto pega, sino a quién le entra: hay criaturas que lo '
          'resisten y reciben la mitad, otras inmunes y otras vulnerables, que '
          'reciben el doble.',
      'It doesn’t change how hard it hits, but whom it gets through to: some '
          'creatures resist it and take half, others are immune, and '
          'vulnerable ones take double.',
    );

/// Estados que hoy viajan por el mismo campo que los tipos de daño. Separarlos
/// en un efecto propio exigiría migrar contenido y personajes; mientras tanto,
/// al menos se muestran en el idioma de la interfaz.
const _conditionLabels = <String, String>{
  'blinded': 'Cegado',
  'charmed': 'Hechizado',
  'deafened': 'Ensordecido',
  'frightened': 'Asustado',
  'grappled': 'Agarrado',
  'incapacitated': 'Incapacitado',
  'paralyzed': 'Paralizado',
  'petrified': 'Petrificado',
  'poisoned': 'Envenenado',
  'prone': 'Derribado',
  'restrained': 'Apresado',
  'stunned': 'Aturdido',
  'unconscious': 'Inconsciente',
};

const _conditionLabelsEn = <String, String>{
  'blinded': 'Blinded',
  'charmed': 'Charmed',
  'deafened': 'Deafened',
  'frightened': 'Frightened',
  'grappled': 'Grappled',
  'incapacitated': 'Incapacitated',
  'paralyzed': 'Paralyzed',
  'petrified': 'Petrified',
  'poisoned': 'Poisoned',
  'prone': 'Prone',
  'restrained': 'Restrained',
  'stunned': 'Stunned',
  'unconscious': 'Unconscious',
};
