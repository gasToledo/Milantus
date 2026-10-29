// Mismo origen y rutas relativas a `/api`, como `api_client.dart`: la cookie
// `httpOnly` viaja sola y no hay `baseUrl`.
import type { CharacterJson } from '../engine';

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

/**
 * El personaje [id] de la cuenta, o `null`. La API no tiene `GET` por id (el
 * cliente de Flutter tampoco: carga la lista, `listCharacters`), y lo ajeno y
 * lo inexistente son lo mismo para ella; acá también.
 */
export async function fetchCharacter(
  id: string,
  signal: AbortSignal,
): Promise<CharacterJson | null> {
  const { characters } = await getJson<{ characters: { character: CharacterJson }[] }>(
    '/api/characters',
    signal,
  );
  return characters.find((c) => c.character.id === id)?.character ?? null;
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
