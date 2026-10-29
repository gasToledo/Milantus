// La capa de datos: un `useQuery` por recurso de la API, y nada más. TanStack
// Query da lo que antes cada pantalla hacía a mano (cargando / error /
// reintentar, abortar al desmontar) y además caché entre pantallas: el
// catálogo y la lista de personajes que bajó el dashboard sirven tal cual
// para la ficha. El contrato de la API no cambia: las funciones de
// `client.ts` siguen siendo las que piden.
import { QueryClient, useQueries, useQuery, type UseQueryResult } from '@tanstack/react-query';
import type { Catalog } from '../engine';
import type { Lang } from '../i18n/texts';
import { loadCatalog } from './catalog';
import { fetchHomebrew, mergeHomebrew, type HomebrewContent } from './homebrew';
import {
  ApiError,
  fetchAccount,
  fetchAppVersion,
  fetchCampaignMembers,
  fetchDmCampaigns,
  fetchPlayerCampaigns,
  fetchRoster,
  fetchRosterSettings,
  fetchThemeMode,
} from './client';

export function createQueryClient(): QueryClient {
  return new QueryClient({
    defaultOptions: {
      queries: {
        // Un 4xx no se arregla reintentando (sin sesión, no es tuyo): se
        // muestra enseguida. Un 5xx o la red caída, dos intentos más con la
        // espera creciente de fábrica: el túnel a veces corta un pedido.
        retry: (failures, error) =>
          !(error instanceof ApiError && error.status < 500) && failures < 2,
        // Solo lectura y una sola pestaña: volver a la ventana no tiene por
        // qué disparar pedidos. Lo que cambie en Flutter se ve al recargar o
        // al pasar el minuto de `staleTime`.
        refetchOnWindowFocus: false,
        staleTime: 60_000,
      },
    },
  });
}

export const queryKeys = {
  account: ['account'] as const,
  themeMode: ['settings', 'theme'] as const,
  rosterSettings: ['settings', 'roster'] as const,
  roster: ['characters'] as const,
  catalog: (lang: Lang) => ['catalog', lang] as const,
  homebrew: ['homebrew'] as const,
  playerCampaigns: (characterId: string) => ['characters', characterId, 'campaigns'] as const,
  appVersion: ['app-version'] as const,
  dmCampaigns: ['dm', 'campaigns'] as const,
  campaignMembers: (campaignId: string) => ['dm', 'campaigns', campaignId, 'members'] as const,
};

/** `null` = sin sesión (un 401 no es un error, ver `fetchAccount`). */
export const useAccount = () =>
  useQuery({ queryKey: queryKeys.account, queryFn: ({ signal }) => fetchAccount(signal) });

export const useThemeMode = (enabled: boolean) =>
  useQuery({
    queryKey: queryKeys.themeMode,
    queryFn: ({ signal }) => fetchThemeMode(signal),
    enabled,
  });

export const useRoster = () =>
  useQuery({ queryKey: queryKeys.roster, queryFn: ({ signal }) => fetchRoster(signal) });

export const useRosterSettings = () =>
  useQuery({
    queryKey: queryKeys.rosterSettings,
    queryFn: ({ signal }) => fetchRosterSettings(signal),
  });

/** El SRD no cambia mientras la página está abierta (cambia con un
 *  despliegue, que recarga): no vence nunca. */
export const useCatalog = (lang: Lang) =>
  useQuery({
    queryKey: queryKeys.catalog(lang),
    queryFn: ({ signal }) => loadCatalog(lang, signal),
    staleTime: Infinity,
  });

/** La versión del panel: adorno, sin reintentos ni error a la vista. */
export const useAppVersion = (enabled: boolean) =>
  useQuery({
    queryKey: queryKeys.appVersion,
    queryFn: ({ signal }) => fetchAppVersion(signal),
    enabled,
    staleTime: Infinity,
    retry: false,
  });

/** Solo se pide al abrir la pestaña Campaña: es lo único que la usa. */
export const usePlayerCampaigns = (characterId: string) =>
  useQuery({
    queryKey: queryKeys.playerCampaigns(characterId),
    queryFn: ({ signal }) => fetchPlayerCampaigns(characterId, signal),
  });

/** Las campañas de cada uno de [characterIds], en el mismo orden. Comparte
 *  clave con `usePlayerCampaigns`: lo que bajó la pestaña Campaña de una ficha
 *  no se vuelve a pedir acá. */
export const usePlayerCampaignsOf = (characterIds: string[]) =>
  useQueries({
    queries: characterIds.map((id) => ({
      queryKey: queryKeys.playerCampaigns(id),
      queryFn: ({ signal }: { signal: AbortSignal }) => fetchPlayerCampaigns(id, signal),
    })),
  });

/** Las campañas que dirige la cuenta: el panel del Modo DM y su contenido. Solo
 *  se piden dentro del Modo DM: el Modo Jugador no las necesita. */
export const useDmCampaigns = () =>
  useQuery({ queryKey: queryKeys.dmCampaigns, queryFn: ({ signal }) => fetchDmCampaigns(signal) });

/** La Mesa: las fichas vinculadas a [campaignId], leídas en vivo del jugador. */
export const useCampaignMembers = (campaignId: string) =>
  useQuery({
    queryKey: queryKeys.campaignMembers(campaignId),
    queryFn: ({ signal }) => fetchCampaignMembers(campaignId, signal),
  });

export const useHomebrew = () =>
  useQuery({ queryKey: queryKeys.homebrew, queryFn: ({ signal }) => fetchHomebrew(signal) });

/**
 * El catálogo con el que se calcula una ficha: el SRD en [lang] con el
 * homebrew de la cuenta encima, como en Flutter. Toda pantalla que llame a
 * `computeSheet` usa este y no `useCatalog`: con el oficial solo, un
 * personaje con un arma propia pierde ese ataque. La fusión se hace una vez
 * por par de datos (ver `merged`).
 */
// La última fusión, compartida entre pantallas: el motor reconoce el catálogo
// por identidad del objeto (`catalogJson` en `engine/index.ts`), y fusionar de
// nuevo al pasar del dashboard a la ficha le haría serializar 1,5 MB otra vez.
let lastMerge: { catalog: Catalog; homebrew: HomebrewContent; merged: Catalog } | null = null;
function merged(catalog: Catalog, homebrew: HomebrewContent): Catalog {
  if (lastMerge?.catalog !== catalog || lastMerge.homebrew !== homebrew) {
    lastMerge = { catalog, homebrew, merged: mergeHomebrew(catalog, homebrew) };
  }
  return lastMerge.merged;
}

export function useSheetCatalog(lang: Lang): {
  data: Catalog | undefined;
  queries: UseQueryResult<unknown>[];
} {
  const catalog = useCatalog(lang);
  const homebrew = useHomebrew();
  const data = catalog.data && homebrew.data ? merged(catalog.data, homebrew.data) : undefined;
  return { data, queries: [catalog, homebrew] };
}
