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
    /** El `code` estable del cuerpo `{ error, code }`, cuando el servidor lo
     *  manda: la pantalla traduce por él. */
    readonly code?: string,
    /** El mensaje del cuerpo `{ error }` cuando el servidor lo manda en un 400
     *  (validó y rechazó): se muestra tal cual. */
    readonly detail?: string,
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

/**
 * Guarda una ficha propia entera (`PUT /api/characters/:id`), como
 * `upsertCharacter` de Flutter. [character] es siempre lo que devolvió el
 * motor (`actOn`), nunca un documento armado acá; el servidor lo vuelve a
 * leer con `Character.fromJson`, que rechaza una versión futura.
 */
export async function saveCharacter(
  character: CharacterJson & { id: string },
  options?: { rebuilt?: boolean },
): Promise<void> {
  const path = `/api/characters/${encodeURIComponent(character.id)}`;
  const response = await fetch(path, {
    method: 'PUT',
    headers: { 'content-type': 'application/json' },
    // `rebuilt` lo marca quien rehace desde nivel 1 (el servidor no lo deduce):
    // es lo que avisa a los DM que tienen al personaje en una campaña.
    body: JSON.stringify(options?.rebuilt ? { character, rebuilt: true } : { character }),
  });
  if (!response.ok) throw new ApiError(response.status, path);
}

/** Borra un personaje propio (`DELETE /api/characters/:id`): el servidor se
 *  lleva también sus retratos. */
export async function deleteCharacter(id: string): Promise<void> {
  const path = `/api/characters/${encodeURIComponent(id)}`;
  const response = await fetch(path, { method: 'DELETE' });
  if (!response.ok) throw new ApiError(response.status, path);
}

/** Da de alta un personaje (`POST /api/characters`) y devuelve **su id**. Como
 *  al guardar, [character] es lo que devolvió el motor. El servidor puede
 *  reasignar el id si choca con otro de la cuenta: quien navega a la ficha usa
 *  este, no el que mandó. */
export async function createCharacter(character: CharacterJson & { id: string }): Promise<string> {
  const path = '/api/characters';
  const response = await fetch(path, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ character }),
  });
  if (!response.ok) throw new ApiError(response.status, path);
  return ((await response.json()) as { character: { id: string } }).character.id;
}

/** Lo que el dashboard lee de los ajustes de la cuenta (`AppSettings` en
 *  Flutter). Crudo: `sortMode` es el nombre del modo tal como se guardó. */
export interface RosterSettings {
  sortMode: string;
  favoriteCharacterId: string | null;
  characterOrder: string[];
  themeMode: string;
  /** Si la cuenta abre en el Modo DM (`AppSettings.startsInDmMode`). */
  startsInDmMode: boolean;
  /** Si el combate que se arma muestra su dificultad y los PX (`AppSettings.showEncounterDifficulty`). */
  showEncounterDifficulty: boolean;
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
    themeMode: settings?.themeMode ?? 'dark',
    startsInDmMode: settings?.startsInDmMode === true,
    // Prendida por defecto, igual que `AppSettings` de Flutter: solo un `false`
    // explícito la apaga (una cuenta sin ajustes guardados la ve).
    showEncounterDifficulty: settings?.showEncounterDifficulty !== false,
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
  /** El orden de la Mesa: ids de vínculo. Es del DM (`Campaign.playerView` lo saca). */
  memberOrder?: string[];
}

export interface MusicScene {
  id: string;
  name: string;
  /** El enlace tal cual lo pegó el DM; lo interpreta el motor (`musicSource`). */
  url: string;
  /** Si se ofrece al armar un combate. */
  offerOnCombat?: boolean;
}

/** Las campañas del DM, tal como las guarda el servidor. Un fallo se lanza: sin
 *  la lista no hay panel que mostrar. */
export async function fetchDmCampaigns(signal: AbortSignal): Promise<DmCampaign[]> {
  const { campaigns } = await getJson<{ campaigns: DmCampaign[] }>('/api/campaigns', signal);
  return campaigns;
}

/** Crea una campaña. El servidor devuelve la guardada: su `id` puede no ser el
 *  pedido (si choca con otra del DM, lo cambia), así que se usa el devuelto. */
export async function createCampaign(campaign: DmCampaign): Promise<DmCampaign> {
  const path = '/api/campaigns';
  const response = await fetch(path, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ campaign }),
  });
  if (!response.ok) throw new ApiError(response.status, path);
  return ((await response.json()) as { campaign: DmCampaign }).campaign;
}

/** Reemplaza la campaña entera: quien llama manda el documento completo. */
export async function saveCampaign(campaign: DmCampaign): Promise<void> {
  const path = `/api/campaigns/${encodeURIComponent(campaign.id)}`;
  const response = await fetch(path, {
    method: 'PUT',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ campaign }),
  });
  if (!response.ok) throw new ApiError(response.status, path);
}

export async function deleteCampaign(id: string): Promise<void> {
  const path = `/api/campaigns/${encodeURIComponent(id)}`;
  const response = await fetch(path, { method: 'DELETE' });
  if (!response.ok) throw new ApiError(response.status, path);
}

/** Canjea el código que compartió un jugador. Un código inválido o vencido es
 *  un 404. */
export async function addCampaignMember(
  campaignId: string,
  code: string,
): Promise<{ memberId: string; character?: CharacterJson }> {
  const path = `/api/campaigns/${encodeURIComponent(campaignId)}/members`;
  const response = await fetch(path, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ code }),
  });
  if (!response.ok) throw new ApiError(response.status, path);
  return ((await response.json()) as { member: { memberId: string; character?: CharacterJson } }).member;
}

/** Un **aviso** para el jugador, no una escritura en su ficha: la marca la
 *  anota él (`modo-dm.md`). */
export async function grantHeroicInspiration(campaignId: string, memberId: string): Promise<void> {
  const path = `/api/campaigns/${encodeURIComponent(campaignId)}/members/${encodeURIComponent(memberId)}/heroic-inspiration`;
  const response = await fetch(path, { method: 'POST' });
  if (!response.ok) throw new ApiError(response.status, path);
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
  grantsCatalog?: ChapterItem[];
}

/** Los capítulos de la campaña [campaignId], en el orden de la campaña. */
export async function fetchCampaignChapters(campaignId: string, signal: AbortSignal): Promise<DmChapter[]> {
  const { chapters } = await getJson<{ chapters: DmChapter[] }>(
    `/api/campaigns/${encodeURIComponent(campaignId)}/chapters`,
    signal,
  );
  return chapters;
}

async function sendJson(method: 'POST' | 'PUT' | 'DELETE', path: string, body: unknown): Promise<void> {
  const response = await fetch(path, { method, headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) });
  if (!response.ok) throw new ApiError(response.status, path);
}

async function remove(path: string): Promise<void> {
  const response = await fetch(path, { method: 'DELETE' });
  if (!response.ok) throw new ApiError(response.status, path);
}

const chaptersPath = (campaignId: string) => `/api/campaigns/${encodeURIComponent(campaignId)}/chapters`;
const notesPath = (campaignId: string) => `/api/campaigns/${encodeURIComponent(campaignId)}/notes`;

/** Crea un capítulo. El estado no viaja de más: nace `planned`. */
export const createChapter = (campaignId: string, chapter: DmChapter) => sendJson('POST', chaptersPath(campaignId), { chapter });

/** Reemplaza el capítulo entero. Un `PUT` no puede cerrarlo (`completed` es un
 *  400): eso tiene su ruta, porque le avisa a otras cuentas. */
export const saveChapter = (campaignId: string, chapter: DmChapter) =>
  sendJson('PUT', `${chaptersPath(campaignId)}/${encodeURIComponent(chapter.id)}`, { chapter });

export const deleteChapter = (campaignId: string, chapterId: string) =>
  remove(`${chaptersPath(campaignId)}/${encodeURIComponent(chapterId)}`);

export const createNote = (campaignId: string, note: DmNote) => sendJson('POST', notesPath(campaignId), { note });

export const saveNote = (campaignId: string, note: DmNote) =>
  sendJson('PUT', `${notesPath(campaignId)}/${encodeURIComponent(note.id)}`, { note });

export const deleteNote = (campaignId: string, noteId: string) =>
  remove(`${notesPath(campaignId)}/${encodeURIComponent(noteId)}`);

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

const encounterPath = (campaignId: string) => `/api/campaigns/${encodeURIComponent(campaignId)}/encounter`;

/**
 * El combate abierto de la campaña (`GET /api/campaigns/:id/encounter`), crudo:
 * lo migra el motor (`encounterView`). `null` si no hay ninguno: el servidor
 * responde 404 tanto por eso como por una campaña ajena, y esta pantalla solo
 * pregunta por una campaña que ya está en la lista del DM.
 */
export async function fetchCampaignEncounter(campaignId: string, signal: AbortSignal): Promise<JsonObject | null> {
  try {
    const { encounter } = await getJson<{ encounter: JsonObject }>(encounterPath(campaignId), signal);
    return encounter;
  } catch (e) {
    if (e instanceof ApiError && e.status === 404) return null;
    throw e;
  }
}

/** Guarda el combate entero (`PUT`): lo arma el motor y gana el último que guarda. */
export const saveCampaignEncounter = (campaignId: string, encounter: JsonObject) => sendJson('PUT', encounterPath(campaignId), { encounter });

export async function convertCampaignCombatant(campaignId: string, encounterId: string, combatantId: string, npc: JsonObject): Promise<JsonObject> {
  const path = `${encounterPath(campaignId)}/${encodeURIComponent(encounterId)}/combatants/${encodeURIComponent(combatantId)}/npc`;
  const response = await fetch(path, {
    method: 'PUT',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ npc }),
  });
  if (!response.ok) throw new ApiError(response.status, path);
  return ((await response.json()) as { encounter: JsonObject }).encounter;
}

/** Descarta el combate que se está armando: no queda registro. */
export const discardCampaignEncounter = (campaignId: string) => remove(`${encounterPath(campaignId)}?discard=true`);

/** Archiva el combate en el Cuaderno. El servidor marca muertos en la misma
 *  transacción solo a los PNJ que estaban en este combate y en esta campaña. */
export async function endCampaignEncounter(campaignId: string, deadNpcIds: string[]): Promise<void> {
  const path = encounterPath(campaignId);
  if (deadNpcIds.length === 0) return remove(path);
  return sendJson('DELETE', path, { deadNpcIds });
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

const campaignNpcPath = (campaignId: string, npcId: string) =>
  `/api/campaigns/${encodeURIComponent(campaignId)}/npcs/${encodeURIComponent(npcId)}`;

/** Suma un PNJ a la campaña o le cambia el estado. Sin [status], un vínculo
 *  nuevo nace vivo y uno existente queda como estaba: reintentar es seguro. */
export async function linkCampaignNpc(campaignId: string, npcId: string, status?: 'alive' | 'dead' | 'unknown'): Promise<void> {
  await sendJson('PUT', campaignNpcPath(campaignId, npcId), status ? { status } : {});
}

/** Quita el vínculo, y solo el vínculo: el PNJ sigue en la biblioteca. */
export async function unlinkCampaignNpc(campaignId: string, npcId: string): Promise<void> {
  await remove(campaignNpcPath(campaignId, npcId));
}

/** Crea un PNJ y devuelve el id que le asignó el servidor. Con [character] crea
 *  también su ficha, en la misma transacción. */
export async function createNpc(npc: JsonObject, character?: JsonObject): Promise<string> {
  const path = '/api/npcs';
  const response = await fetch(path, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ npc, ...(character ? { character } : {}) }),
  });
  if (!response.ok) throw new ApiError(response.status, path);
  return ((await response.json()) as { npc: { id: string } }).npc.id;
}

/** Borra un PNJ de la biblioteca y de todas sus campañas, con su ficha si tiene.
 *  Uno ajeno y uno inexistente responden igual, y el servidor no falla por eso. */
export async function deleteNpc(id: string): Promise<void> {
  await remove(`/api/npcs/${encodeURIComponent(id)}`);
}

/** Un aviso de la cola de la cuenta (`GET /api/events`): el servidor guarda
 *  **qué pasó** (`kind` y los datos del `payload`) y el cliente decide cómo se
 *  dice (`events/messages.ts`). */
export interface UserEvent {
  id: string;
  kind: string;
  payload: JsonObject;
}

/** Los avisos que esta cuenta todavía no vio. Sin `signal` a propósito: es una
 *  lectura que consume la cola, y abortarla al navegar dejaría al servidor con
 *  el aviso entregado y al cliente sin saberlo. */
export async function fetchUnseenEvents(): Promise<UserEvent[]> {
  const path = '/api/events';
  const response = await fetch(path);
  if (!response.ok) throw new ApiError(response.status, path);
  return ((await response.json()) as { events: UserEvent[] }).events;
}

/** Marca avisos como vistos: dejan de volver para siempre. */
export async function markEventsSeen(ids: string[]): Promise<void> {
  const path = '/api/events/seen';
  const response = await fetch(path, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ ids }),
  });
  if (!response.ok) throw new ApiError(response.status, path);
}

/** Emite un código de un solo uso para que un DM sume a [characterId] a su
 *  campaña (`POST /api/characters/:id/share`). Nace del lado del dueño: el
 *  acceso a una ficha solo puede empezar por su decisión. */
export async function createShareCode(characterId: string): Promise<{ code: string; expiresAt: string }> {
  const path = `/api/characters/${encodeURIComponent(characterId)}/share`;
  const response = await fetch(path, { method: 'POST' });
  if (!response.ok) throw new ApiError(response.status, path);
  return (await response.json()) as { code: string; expiresAt: string };
}

/** Una campaña con la que el personaje está compartido. */
export interface CharacterShare {
  memberId: string;
  campaignName: string;
}

export async function fetchCharacterShares(characterId: string, signal: AbortSignal): Promise<CharacterShare[]> {
  const { shares } = await getJson<{ shares: CharacterShare[] }>(
    `/api/characters/${encodeURIComponent(characterId)}/shares`,
    signal,
  );
  return shares;
}

/** Corta un vínculo (`DELETE /api/campaign-links/:memberId`): el DM deja de ver
 *  la ficha. Lo puede hacer el dueño del personaje o el DM de la campaña. */
export async function deleteCampaignLink(memberId: string): Promise<void> {
  const path = `/api/campaign-links/${encodeURIComponent(memberId)}`;
  const response = await fetch(path, { method: 'DELETE' });
  if (!response.ok) throw new ApiError(response.status, path);
}

/** Dónde está el personaje en el combate abierto de alguna mesa (`none`: en
 *  ninguno). `waiting` es un combate abierto que no es su turno ni el que
 *  sigue. */
export type TurnStatus = 'none' | 'waiting' | 'next' | 'active';

/** Un valor que este cliente no conoce se lee como `none`: el servidor puede
 *  ser más nuevo que la pestaña abierta. */
export async function fetchTurn(characterId: string, signal: AbortSignal): Promise<TurnStatus> {
  const { turn } = await getJson<{ turn: string }>(`/api/characters/${encodeURIComponent(characterId)}/turn`, signal);
  return turn === 'waiting' || turn === 'next' || turn === 'active' ? turn : 'none';
}

/** Un objeto del catálogo (o del homebrew del DM) que un capítulo reparte
 *  (`ChapterItem.toJson`). `name` es el del momento de elegirlo. */
export interface ChapterItem {
  category: 'weapons' | 'armor' | 'items';
  itemId: string;
  name: string;
  baseItemId?: string;
  quantity: number;
  homebrew: boolean;
}

/** A quién va cada objeto al cerrar un capítulo. `items` son los del catálogo
 *  y `freeItems` el texto libre, que llega solo como aviso. */
export interface Allocation {
  memberId: string;
  items: ChapterItem[];
  freeItems: string[];
}

/** Cierra el capítulo y avisa a la mesa. Con [allocations] además reparte
 *  objetos a personajes concretos; el servidor valida todo antes de escribir y
 *  el DM no toca ninguna ficha (`modo-dm.md`). */
export async function closeChapter(campaignId: string, chapterId: string, allocations?: Allocation[]): Promise<void> {
  await sendJson('POST', `${chaptersPath(campaignId)}/${encodeURIComponent(chapterId)}/close`, allocations ? { allocations } : {});
}

/** Un objeto que el DM le dio a este personaje y que todavía no aceptó
 *  (`ItemGrant.toPublicJson`): sin el documento del homebrew. */
export interface ItemGrant {
  id: string;
  campaignName: string;
  chapterName: string;
  category: 'weapons' | 'armor' | 'items';
  itemId: string;
  name: string;
  baseItemId: string | null;
  quantity: number;
  homebrew: boolean;
}

export async function fetchItemGrants(characterId: string, signal: AbortSignal): Promise<ItemGrant[]> {
  const { grants } = await getJson<{ grants: ItemGrant[] }>(
    `/api/characters/${encodeURIComponent(characterId)}/item-grants`,
    signal,
  );
  return grants;
}

/** Acepta el regalo: devuelve con qué id agregarlo (un homebrew pasa a ser una
 *  copia en esta cuenta). **No** lo saca de la bandeja. */
export async function claimItemGrant(id: string): Promise<{ itemId: string; baseItemId: string | null; quantity: number }> {
  const path = `/api/item-grants/${encodeURIComponent(id)}/claim`;
  const response = await fetch(path, { method: 'POST' });
  if (!response.ok) throw new ApiError(response.status, path);
  return response.json();
}

/** Saca el regalo de la bandeja (aceptado o descartado). */
export const resolveItemGrant = (id: string) => remove(`/api/item-grants/${encodeURIComponent(id)}`);

/** Le da objetos a un personaje de la mesa fuera de un capítulo. Es un **aviso
 *  más un regalo en su bandeja**: el DM no escribe la ficha (`modo-dm.md`). */
export const giveItems = (campaignId: string, memberId: string, items: ChapterItem[]) =>
  sendJson(
    'POST',
    `/api/campaigns/${encodeURIComponent(campaignId)}/members/${encodeURIComponent(memberId)}/item-grants`,
    { items },
  );

/** Guarda el documento entero de un PNJ. */
export async function saveNpc(npc: JsonObject & { id: string }): Promise<void> {
  await sendJson('PUT', `/api/npcs/${encodeURIComponent(npc.id)}`, { npc });
}
