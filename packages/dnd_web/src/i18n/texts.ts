// Todos los textos visibles viven acá: un componente nunca lleva un literal.
// Mismas reglas que `docs/desarrollo/textos.md` (glosario, voseo en español,
// términos del SRD en inglés). Las dos lenguas son del mismo tipo, así que
// `tsc` falla si a una le falta una clave que la otra tiene.

export type Lang = 'es' | 'en';

const es = {
  appName: 'Milantus',
  appTagline: 'Compendio de aventuras',
  navLabel: 'Navegación principal',
  navSheet: 'Ficha',
  skipToContent: 'Saltar al contenido',
  panelLabel: 'Panel lateral',
  closeMenu: 'Cerrar el menú',
  opensFlutter: 'se abre en la aplicación principal',
  themeLabel: 'Tema',
  themeModes: { dark: 'Oscuro', light: 'Claro', system: 'Sistema' },
  backToCharacters: 'Mis personajes',
  sheetNavLabel: 'Secciones de la ficha',

  loading: 'Cargando la ficha…',
  loadingSession: 'Comprobando la sesión…',
  signedOutTitle: 'No hay sesión iniciada',
  signedOutBody: 'Iniciá sesión para ver tus personajes.',
  signIn: 'Iniciar sesión',
  unavailableTitle: 'No disponible',
  unavailableBody: 'Esta página no está disponible.',
  errorTitle: 'No se pudo cargar la ficha',
  sessionErrorTitle: 'No se pudo comprobar la sesión',
  computeErrorTitle: 'No se pudo calcular la ficha',
  computeErrorBody: 'Puede que la ficha sea de una versión más nueva. Abrila en la aplicación principal.',
  errorBody: 'Revisá tu conexión e intentá de nuevo.',
  retry: 'Reintentar',
  notFoundTitle: 'No se encontró el personaje',
  notFoundBody: 'No existe o no es tuyo.',
  notFoundTitleRoute: 'Página no encontrada',

  // Panel lateral (las cadenas salen de `app_es.arb` de dnd_app).
  menu: 'Menú',
  modeSwitchLabel: 'Modo',
  modePlayer: 'Jugador',
  modeDm: 'DM',
  navCharacters: 'Personajes',
  navCodex: 'Códice',
  navHomebrew: 'Homebrew',
  settings: 'Ajustes',
  feedback: 'Sugerencias y errores',
  signOut: 'Cerrar sesión',

  // Dashboard.
  rosterTitle: 'Mis personajes',
  rosterCount: (n: number) => (n === 1 ? '1 personaje' : `${n} personajes`),
  rosterFallen: (n: number) => (n === 1 ? '1 caído' : `${n} caídos`),
  rosterSearchLabel: 'Buscar personajes',
  rosterSearchHint: 'Buscar por nombre, clase o especie…',
  rosterClearSearch: 'Limpiar búsqueda',
  rosterEmpty: 'Todavía no hay personajes en esta cuenta.',
  rosterEmptyHint: 'Creá el primero desde la aplicación principal.',
  rosterNoMatch: (query: string) => `Ningún personaje coincide con «${query}».`,
  rosterNoMatchHint: 'Se busca por nombre, clase y especie.',
  rosterCreate: 'Crear personaje',
  rosterLoading: 'Cargando tus personajes…',
  rosterErrorTitle: 'No se pudieron cargar los personajes',
  sortLabel: 'Orden',
  sortModes: {
    manual: 'Manual',
    dateAdded: 'Más recientes',
    name: 'Nombre',
    level: 'Nivel',
    klass: 'Clase',
  },
  favorite: 'Favorito',
  fallenBadge: 'CAÍDO',
  hpLabelNormal: 'PUNTOS DE GOLPE',
  hpLabelCritical: 'PG CRÍTICOS',
  hpLabelFallen: 'SIN PUNTOS DE GOLPE',
  acShort: 'CA',
  speedShort: 'VEL',
  initiativeShort: 'INIC',
  acFull: 'Clase de armadura',
  levelWord: 'Nivel',

  hp: 'PG',
  tempHp: (n: number) => `+${n} temporales`,
  ac: 'CA',
  initiative: 'Iniciativa',
  speed: 'Velocidad',
  feet: 'pies',
  proficiency: 'Competencia',
  passivePerception: 'Percepción pasiva',
  scoreLabel: (n: number) => `Punt. ${n}`,
  save: 'SALV',
  tacticalBand: 'Cifras de combate',
  abilitiesHeading: 'Características',
  attacksHeading: 'Ataques',
  noAttacks: 'Sin ataques.',
  resourcesHeading: 'Recursos',
  noResources: 'Sin recursos.',
  featuresHeading: 'Rasgos',
  noFeatures: 'Sin rasgos.',
  savesHeading: 'Salvaciones',
  skillsHeading: 'Habilidades',
  proficient: 'Competente',
  expertise: 'Pericia',
  notProficient: 'Sin competencia',
  pipsLabel: (name: string, left: number, max: number) =>
    `${name}: ${left} de ${max} usos disponibles`,
  levelOf: (name: string, level: number) => `${name} nivel ${level}`,

  abilities: {
    strength: 'Fuerza',
    dexterity: 'Destreza',
    constitution: 'Constitución',
    intelligence: 'Inteligencia',
    wisdom: 'Sabiduría',
    charisma: 'Carisma',
  },
  abilityAbbr: {
    strength: 'FUE',
    dexterity: 'DES',
    constitution: 'CON',
    intelligence: 'INT',
    wisdom: 'SAB',
    charisma: 'CAR',
  },
  skills: {
    acrobatics: 'Acrobacias',
    'animal-handling': 'Trato con Animales',
    arcana: 'Arcanos',
    athletics: 'Atletismo',
    deception: 'Engaño',
    history: 'Historia',
    insight: 'Perspicacia',
    intimidation: 'Intimidación',
    investigation: 'Investigación',
    medicine: 'Medicina',
    nature: 'Naturaleza',
    perception: 'Percepción',
    performance: 'Interpretación',
    persuasion: 'Persuasión',
    religion: 'Religión',
    'sleight-of-hand': 'Juego de Manos',
    stealth: 'Sigilo',
    survival: 'Supervivencia',
  },
  // `ComputedSheet.size` viene en español (vocabulario cerrado del catálogo,
  // que Flutter traduce al mostrarlo con `vocabularyLabel`): la clave es ese
  // rótulo.
  sizes: {
    Diminuto: 'Diminuto',
    Pequeño: 'Pequeño',
    Mediano: 'Mediano',
    Grande: 'Grande',
    Enorme: 'Enorme',
    Gargantuesco: 'Gargantuesco',
  },
  damageTypes: {
    acid: 'Ácido',
    bludgeoning: 'Contundente',
    cold: 'Frío',
    fire: 'Fuego',
    force: 'Fuerza',
    lightning: 'Relámpago',
    necrotic: 'Necrótico',
    piercing: 'Perforante',
    poison: 'Veneno',
    psychic: 'Psíquico',
    radiant: 'Radiante',
    slashing: 'Cortante',
    thunder: 'Trueno',
  },
};

type Texts = typeof es;

const en: Texts = {
  appName: 'Milantus',
  appTagline: 'Adventure compendium',
  navLabel: 'Main navigation',
  navSheet: 'Sheet',
  skipToContent: 'Skip to content',
  panelLabel: 'Side panel',
  closeMenu: 'Close the menu',
  opensFlutter: 'opens in the main app',
  themeLabel: 'Theme',
  themeModes: { dark: 'Dark', light: 'Light', system: 'System' },
  backToCharacters: 'My characters',
  sheetNavLabel: 'Sheet sections',

  loading: 'Loading the sheet…',
  loadingSession: 'Checking the session…',
  signedOutTitle: 'You are signed out',
  signedOutBody: 'Sign in to see your characters.',
  signIn: 'Sign in',
  unavailableTitle: 'Not available',
  unavailableBody: 'This page is not available.',
  errorTitle: 'Could not load the sheet',
  sessionErrorTitle: 'Could not check the session',
  computeErrorTitle: 'Could not compute the sheet',
  computeErrorBody: 'The sheet may come from a newer version. Open it in the main app.',
  errorBody: 'Check your connection and try again.',
  retry: 'Retry',
  notFoundTitle: 'Character not found',
  notFoundBody: 'It does not exist or is not yours.',
  notFoundTitleRoute: 'Page not found',

  menu: 'Menu',
  modeSwitchLabel: 'Mode',
  modePlayer: 'Player',
  modeDm: 'DM',
  navCharacters: 'Characters',
  navCodex: 'Codex',
  navHomebrew: 'Homebrew',
  settings: 'Settings',
  feedback: 'Ideas & bug reports',
  signOut: 'Sign out',

  rosterTitle: 'My characters',
  rosterCount: (n: number) => (n === 1 ? '1 character' : `${n} characters`),
  rosterFallen: (n: number) => `${n} down`,
  rosterSearchLabel: 'Search characters',
  rosterSearchHint: 'Search by name, class or species…',
  rosterClearSearch: 'Clear search',
  rosterEmpty: 'There are no characters in this account yet.',
  rosterEmptyHint: 'Create the first one from the main app.',
  rosterNoMatch: (query: string) => `No character matches “${query}”.`,
  rosterNoMatchHint: 'Search looks at name, class and species.',
  rosterCreate: 'Create character',
  rosterLoading: 'Loading your characters…',
  rosterErrorTitle: 'Could not load the characters',
  sortLabel: 'Sort',
  sortModes: {
    manual: 'Manual',
    dateAdded: 'Most recent',
    name: 'Name',
    level: 'Level',
    klass: 'Class',
  },
  favorite: 'Favorite',
  fallenBadge: 'DOWN',
  hpLabelNormal: 'HIT POINTS',
  hpLabelCritical: 'CRITICAL HP',
  hpLabelFallen: 'NO HIT POINTS',
  acShort: 'AC',
  speedShort: 'SPD',
  initiativeShort: 'INIT',
  acFull: 'Armor Class',
  levelWord: 'Level',

  hp: 'HP',
  tempHp: (n: number) => `+${n} temporary`,
  ac: 'AC',
  initiative: 'Initiative',
  speed: 'Speed',
  feet: 'ft',
  proficiency: 'Proficiency',
  passivePerception: 'Passive Perception',
  scoreLabel: (n: number) => `Score ${n}`,
  save: 'SAVE',
  tacticalBand: 'Combat numbers',
  abilitiesHeading: 'Abilities',
  attacksHeading: 'Attacks',
  noAttacks: 'No attacks.',
  resourcesHeading: 'Resources',
  noResources: 'No resources.',
  featuresHeading: 'Features',
  noFeatures: 'No features.',
  savesHeading: 'Saving Throws',
  skillsHeading: 'Skills',
  proficient: 'Proficient',
  expertise: 'Expertise',
  notProficient: 'Not proficient',
  pipsLabel: (name: string, left: number, max: number) =>
    `${name}: ${left} of ${max} uses available`,
  levelOf: (name: string, level: number) => `${name} level ${level}`,

  abilities: {
    strength: 'Strength',
    dexterity: 'Dexterity',
    constitution: 'Constitution',
    intelligence: 'Intelligence',
    wisdom: 'Wisdom',
    charisma: 'Charisma',
  },
  abilityAbbr: {
    strength: 'STR',
    dexterity: 'DEX',
    constitution: 'CON',
    intelligence: 'INT',
    wisdom: 'WIS',
    charisma: 'CHA',
  },
  skills: {
    acrobatics: 'Acrobatics',
    'animal-handling': 'Animal Handling',
    arcana: 'Arcana',
    athletics: 'Athletics',
    deception: 'Deception',
    history: 'History',
    insight: 'Insight',
    intimidation: 'Intimidation',
    investigation: 'Investigation',
    medicine: 'Medicine',
    nature: 'Nature',
    perception: 'Perception',
    performance: 'Performance',
    persuasion: 'Persuasion',
    religion: 'Religion',
    'sleight-of-hand': 'Sleight of Hand',
    stealth: 'Stealth',
    survival: 'Survival',
  },
  sizes: {
    Diminuto: 'Tiny',
    Pequeño: 'Small',
    Mediano: 'Medium',
    Grande: 'Large',
    Enorme: 'Huge',
    Gargantuesco: 'Gargantuan',
  },
  damageTypes: {
    acid: 'Acid',
    bludgeoning: 'Bludgeoning',
    cold: 'Cold',
    fire: 'Fire',
    force: 'Force',
    lightning: 'Lightning',
    necrotic: 'Necrotic',
    piercing: 'Piercing',
    poison: 'Poison',
    psychic: 'Psychic',
    radiant: 'Radiant',
    slashing: 'Slashing',
    thunder: 'Thunder',
  },
};

const TEXTS: Record<Lang, Texts> = { es, en };

export function textsFor(lang: Lang): Texts {
  return TEXTS[lang];
}

export type { Texts };

/** Etiqueta de un id del motor, o el id tal cual si el módulo no lo conoce:
 *  un id nuevo del catálogo se ve crudo antes que desaparecer. */
export function labelOf(table: Record<string, string>, id: string): string {
  return table[id] ?? id;
}

const STORAGE_KEY = 'milantus.locale';

/** El idioma de la interfaz, resuelto como `resolveLocale` de Flutter
 *  (`l10n/app_locale.dart`): el guardado si es válido; si no, el del
 *  navegador si lo soportamos (`en-US` vale `en`); si no, español. Flutter lo
 *  guarda en `localStorage`, y `/v2` comparte origen, así que es el mismo. */
export function resolveLang(): Lang {
  const base = (tag: string | null | undefined): Lang | null => {
    const code = tag?.toLowerCase().split(/[-_]/)[0];
    return code === 'es' || code === 'en' ? code : null;
  };
  let stored: string | null = null;
  try {
    stored = window.localStorage.getItem(STORAGE_KEY);
  } catch {
    // El almacenamiento bloqueado equivale a «no hay idioma guardado».
  }
  return base(stored) ?? base(navigator.language) ?? 'es';
}
