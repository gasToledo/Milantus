import 'ability.dart';
import 'content_language.dart';
import 'name_sort.dart';

/// Las 18 habilidades de 5e (SRD 5.2), con su nombre en español y en inglés y
/// la característica que las gobierna.
///
/// El contenido (clases, especies, trasfondos) referencia habilidades por [id];
/// este enum es la única fuente de la traducción y del vínculo con la
/// característica, para que no se repartan por la UI.
enum Skill {
  acrobatics('acrobatics', 'Acrobacias', 'Acrobatics', Ability.dexterity),
  animalHandling(
    'animal-handling',
    'Trato con Animales',
    'Animal Handling',
    Ability.wisdom,
  ),
  arcana('arcana', 'Arcanos', 'Arcana', Ability.intelligence),
  athletics('athletics', 'Atletismo', 'Athletics', Ability.strength),
  deception('deception', 'Engaño', 'Deception', Ability.charisma),
  history('history', 'Historia', 'History', Ability.intelligence),
  insight('insight', 'Perspicacia', 'Insight', Ability.wisdom),
  intimidation(
    'intimidation',
    'Intimidación',
    'Intimidation',
    Ability.charisma,
  ),
  investigation(
    'investigation',
    'Investigación',
    'Investigation',
    Ability.intelligence,
  ),
  medicine('medicine', 'Medicina', 'Medicine', Ability.wisdom),
  nature('nature', 'Naturaleza', 'Nature', Ability.intelligence),
  perception('perception', 'Percepción', 'Perception', Ability.wisdom),
  performance('performance', 'Interpretación', 'Performance', Ability.charisma),
  persuasion('persuasion', 'Persuasión', 'Persuasion', Ability.charisma),
  religion('religion', 'Religión', 'Religion', Ability.intelligence),
  sleightOfHand(
    'sleight-of-hand',
    'Juego de Manos',
    'Sleight of Hand',
    Ability.dexterity,
  ),
  stealth('stealth', 'Sigilo', 'Stealth', Ability.dexterity),
  survival('survival', 'Supervivencia', 'Survival', Ability.wisdom);

  const Skill(this.id, this.labelEs, this.labelEn, this.ability);

  /// Id usado por el contenido JSON (p.ej. `sleight-of-hand`).
  final String id;

  final String labelEs;
  final String labelEn;

  /// Nombre en el idioma activo, para la UI.
  String get label => localized(labelEs, labelEn);

  /// Característica que gobierna la habilidad.
  final Ability ability;

  /// Todos los ids, en el orden del enum.
  static List<String> get allIds => [for (final s in Skill.values) s.id];

  /// Habilidad por id, o null si no es una de las 18 (p.ej. una inventada por
  /// contenido homebrew).
  static Skill? fromId(String id) {
    for (final s in Skill.values) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Nombre para mostrar. Si el id no está en el catálogo (homebrew), devuelve
  /// el id capitalizado en vez de fallar.
  static String labelFor(String id) => fromId(id)?.label ?? titleCaseId(id);
}
