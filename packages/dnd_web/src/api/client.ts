// Mismo origen y rutas relativas a `/api`, como `api_client.dart`: la cookie
// `httpOnly` viaja sola y no hay `baseUrl`.
import type { CharacterJson, JsonObject } from '../engine';

/** Lo que `GET /api/me` devuelve. `webV2` lo decide el servidor por cuenta. */
export interface Account {
  userId: string;
  name?: string | null;
  email?: string | null;
  webV2?: boolean;
}

/** `unauthorized` (401) no es un fallo: es el estado «sin sesión». Todo lo
 *  demás que no sea 2xx se lanza y la pantalla lo muestra como error. */
export class ApiError extends Error {
  constructor(
    readonly status: number,
    path: string,
  ) {
    super(`${path} respondió ${status}`);
  }
}

async function getJson<T>(path: string, signal: AbortSignal): Promise<T> {
  const response = await fetch(path, { signal });
  if (!response.ok) throw new ApiError(response.status, path);
  return (await response.json()) as T;
}

/** `null` si no hay sesión. */
export async function fetchAccount(signal: AbortSignal): Promise<Account | null> {
  try {
    return await getJson<Account>('/api/me', signal);
  } catch (e) {
    if (e instanceof ApiError && e.status === 401) return null;
    throw e;
  }
}

/** Un elemento de `GET /api/characters`: el personaje y cuándo se creó (lo usa
 *  el orden «más recientes»). */
export interface StoredCharacter {
  character: CharacterJson;
  createdAt: string;
}

/** Todos los personajes de la cuenta, tal como los devuelve la API. */
export async function fetchRoster(signal: AbortSignal): Promise<StoredCharacter[]> {
  const { characters } = await getJson<{ characters: StoredCharacter[] }>(
    '/api/characters',
    signal,
  );
  return characters;
}

/** Lo que el dashboard lee de los ajustes de la cuenta (`AppSettings` en
 *  Flutter). Crudo: `sortMode` es el nombre del modo tal como se guardó. */
export interface RosterSettings {
  sortMode: string;
  favoriteCharacterId: string | null;
  characterOrder: string[];
  /** Si la cuenta abre en el Modo DM (`AppSettings.startsInDmMode`). */
  startsInDmMode: boolean;
}

/** Una cuenta que nunca guardó ajustes (`settings: null`) usa los valores por
 *  defecto de `AppSettings`. A diferencia del tema, un fallo se lanza: sin el
 *  favorito y el orden, la lista se mostraría en un orden que la cuenta no
 *  eligió y sin avisar. */
export async function fetchRosterSettings(signal: AbortSignal): Promise<RosterSettings> {
  const { settings } = await getJson<{ settings: Partial<RosterSettings> | null }>(
    '/api/settings',
    signal,
  );
  return {
    sortMode: settings?.sortMode ?? 'name',
    favoriteCharacterId: settings?.favoriteCharacterId ?? null,
    characterOrder: settings?.characterOrder ?? [],
    startsInDmMode: settings?.startsInDmMode === true,
  };
}

/** La versión del cliente de Flutter, que publica su propio build en
 *  `/version.json` (es la que lee `package_info_plus`). Es un adorno del panel:
 *  si no está (en desarrollo, en las pruebas), simplemente no se muestra. */
export async function fetchAppVersion(signal: AbortSignal): Promise<string | null> {
  try {
    const { version } = await getJson<{ version?: string }>('/version.json', signal);
    return version ?? null;
  } catch {
    return null;
  }
}

/** Tema elegido en los ajustes de la cuenta (`themeMode` de `AppSettings`).
 *  Es un adorno: si falla, se queda el oscuro, que es el que arranca. */
export async function fetchThemeMode(signal: AbortSignal): Promise<string> {
  try {
    const { settings } = await getJson<{ settings: { themeMode?: string } | null }>(
      '/api/settings',
      signal,
    );
    return settings?.themeMode ?? 'dark';
  } catch {
    return 'dark';
  }
}

/** Lo que `GET /api/characters/:id/campaigns` devuelve por cada campaña en la
 *  que está el personaje. El servidor ya podó lo que el jugador no ve: sin id
 *  de campaña, solo capítulos cerrados y sin su descripción, y las batallas
 *  con la vista del jugador (`EncounterLog.playerView`). */
export interface PlayerCampaign {
  memberId: string;
  campaign: { name?: string; premise?: string; state?: string };
  /** Los otros personajes de la mesa, sin este. */
  party?: string[];
  /** Capítulos cerrados, en el orden de la campaña. */
  chapters?: (JsonObject & { id: string; name?: string })[];
  /** Combates cerrados, del más nuevo al más viejo. */
  battles?: PlayerBattle[];
}

export interface PlayerBattle {
  id?: string;
  chapterId?: string | null;
  rounds?: number;
  players?: string[];
  /** Solo enemigos, agrupados por nombre visible; un PNJ sin criatura de base
   *  llega con el nombre vacío. */
  monsters?: { name?: string; count?: number; defeated?: number; creatureId?: string | null }[];
}

/** Las campañas del personaje [characterId] de esta cuenta. Cuelga de
 *  `/api/characters` porque es el jugador quien pregunta por su ficha. */
export async function fetchPlayerCampaigns(characterId: string, signal: AbortSignal): Promise<PlayerCampaign[]> {
  const { campaigns } = await getJson<{ campaigns: PlayerCampaign[] }>(
    `/api/characters/${encodeURIComponent(characterId)}/campaigns`,
    signal,
  );
  return campaigns;
}

/** Una campaña que dirige la cuenta (`GET /api/campaigns`, el documento del
 *  DM). Solo se tipa lo que el Modo DM de React lee. */
export interface DmCampaign {
  id: string;
  name: string;
  premise?: string;
  /** `CampaignState.name`: `active`, `paused` o `finished`. */
  state?: string;
  /** Las escenas de música (`MusicScene.toJson`). Son del DM: el servidor las
   *  poda de la campaña que recibe el jugador (`Campaign.playerView`). */
  musicScenes?: MusicScene[];
}

export interface MusicScene {
  id: string;
  name: string;
  /** El enlace tal cual lo pegó el DM; lo interpreta el motor (`musicSource`). */
  url: string;
  /** Si Flutter la ofrece al iniciar un combate. */
  offerOnCombat?: boolean;
}

/** Las campañas del DM, tal como las guarda el servidor. Un fallo se lanza: sin
 *  la lista no hay panel que mostrar. */
export async function fetchDmCampaigns(signal: AbortSignal): Promise<DmCampaign[]> {
  const { campaigns } = await getJson<{ campaigns: DmCampaign[] }>('/api/campaigns', signal);
  return campaigns;
}

/** Un personaje vinculado a la campaña. `character` es la ficha **real** del
 *  jugador en este momento, no una copia (`modo-dm.md`): el DM la lee y no la
 *  escribe. */
export interface CampaignMember {
  memberId: string;
  character: CharacterJson;
}

/** Los jugadores vinculados a la campaña [campaignId]. Una campaña ajena y una
 *  inexistente responden igual (404). */
export async function fetchCampaignMembers(campaignId: string, signal: AbortSignal): Promise<CampaignMember[]> {
  const { members } = await getJson<{ members: CampaignMember[] }>(
    `/api/campaigns/${encodeURIComponent(campaignId)}/members`,
    signal,
  );
  return members;
}

/** Un capítulo tal como lo ve su DM (`Chapter.toJson`). `summary` es el objetivo
 *  que el DM escribe: **no viaja a ningún jugador** y por eso solo se lee con la
 *  cuenta del DM (`modo-dm.md`). */
export interface DmChapter extends JsonObject {
  id: string;
  name: string;
  summary?: string;
  /** `planned`, `active` o `completed`. */
  state?: string;
  grantsLevel?: boolean;
  grantsGold?: number;
  grantsItems?: string[];
}

/** Los capítulos de la campaña [campaignId], en el orden de la campaña. */
export async function fetchCampaignChapters(campaignId: string, signal: AbortSignal): Promise<DmChapter[]> {
  const { chapters } = await getJson<{ chapters: DmChapter[] }>(
    `/api/campaigns/${encodeURIComponent(campaignId)}/chapters`,
    signal,
  );
  return chapters;
}

/** Una nota del DM (`Note.toJson`): texto plano con el Markdown chico de la mesa.
 *  Sin `updatedAt` es una nota que nunca se guardó con fecha. */
export interface DmNote {
  id: string;
  chapterId: string;
  title: string;
  body?: string;
  updatedAt?: string;
}

/** Un combate cerrado, **con** lo que el DM sí ve y el jugador no: los tres
 *  bandos y el nombre propio de cada PNJ (`EncounterLog.toJson`). */
export interface DmEncounterLog {
  id?: string;
  chapterId?: string | null;
  rounds?: number;
  players?: string[];
  monsters?: {
    name: string;
    count?: number;
    defeated?: number;
    /** `ally`, `enemy` o `neutral`. */
    side?: string;
    npc?: boolean;
    creatureId?: string | null;
  }[];
  endedAt?: string;
}

/** Un nivel que ganó un personaje vinculado, anotado por el servidor al guardar
 *  el jugador su ficha: una fila por nivel (`LevelUpLog.toJson`). */
export interface DmLevelUp {
  id: string;
  chapterId?: string | null;
  characterName: string;
  level: number;
  classId: string;
  classLevel: number;
  at: string;
}

export interface DmNotebook {
  notes: DmNote[];
  encounterLogs: DmEncounterLog[];
  levelUps: DmLevelUp[];
}

/** El Cuaderno entero de la campaña en un solo pedido, como en Flutter: las
 *  notas, los combates y las subidas de nivel se intercalan por capítulo. */
export async function fetchCampaignNotebook(campaignId: string, signal: AbortSignal): Promise<DmNotebook> {
  return getJson<DmNotebook>(`/api/campaigns/${encodeURIComponent(campaignId)}/notebook`, signal);
}

/** En qué campaña está un PNJ de la biblioteca y cómo está **en esa** campaña
 *  (`NpcCampaignLink.toJson`): el mismo PNJ puede estar muerto en una mesa y
 *  vivo en otra. */
export interface NpcCampaignLink {
  campaignId: string;
  campaignName: string;
  /** `alive`, `dead` o `unknown`. */
  status?: string;
}

/** Un PNJ de la biblioteca del DM tal como lo devuelve la API: el documento
 *  `Npc` crudo, sus campañas y, si es un PNJ con ficha, la ficha. **Nada de
 *  esto viaja a ningún jugador** (`modo-dm.md`, «PNJ»). */
export interface StoredNpc {
  npc: JsonObject & { id: string; name?: string };
  campaigns: NpcCampaignLink[];
  character?: CharacterJson;
}

/** La biblioteca entera de la cuenta, estén o no en alguna campaña. */
export async function fetchNpcs(signal: AbortSignal): Promise<StoredNpc[]> {
  const { npcs } = await getJson<{ npcs: StoredNpc[] }>('/api/npcs', signal);
  return npcs;
}

/**
 * El combate abierto de la campaña (`GET /api/campaigns/:id/encounter`), crudo:
 * lo migra el motor (`encounterView`). `null` si no hay ninguno: el servidor
 * responde 404 tanto por eso como por una campaña ajena, y esta pantalla solo
 * pregunta por una campaña que ya está en la lista del DM.
 */
export async function fetchCampaignEncounter(campaignId: string, signal: AbortSignal): Promise<JsonObject | null> {
  try {
    const { encounter } = await getJson<{ encounter: JsonObject }>(
      `/api/campaigns/${encodeURIComponent(campaignId)}/encounter`,
      signal,
    );
    return encounter;
  } catch (e) {
    if (e instanceof ApiError && e.status === 404) return null;
    throw e;
  }
}

/** Un PNJ de una campaña (`GET /api/campaigns/:id/npcs`): el documento, su
 *  estado **en esa** campaña, los PG con que volvió del último combate (sin
 *  `currentHp` está entero) y su ficha si la tiene. */
export interface CampaignNpc {
  npc: JsonObject & { id: string; name?: string };
  status?: string;
  currentHp?: number;
  character?: CharacterJson;
}

/** Los PNJ de la campaña [campaignId]. Una ajena y una inexistente responden
 *  igual (404). */
export async function fetchCampaignNpcs(campaignId: string, signal: AbortSignal): Promise<CampaignNpc[]> {
  const { npcs } = await getJson<{ npcs: CampaignNpc[] }>(`/api/campaigns/${encodeURIComponent(campaignId)}/npcs`, signal);
  return npcs;
}

/** Un PNJ de la cuenta. Uno ajeno y uno inexistente responden igual (404). */
export async function fetchNpc(id: string, signal: AbortSignal): Promise<StoredNpc> {
  return getJson<StoredNpc>(`/api/npcs/${encodeURIComponent(id)}`, signal);
}
