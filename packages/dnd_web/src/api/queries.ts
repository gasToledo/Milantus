// La capa de datos: un `useQuery` por recurso de la API, y nada más. TanStack
// Query da lo que antes cada pantalla hacía a mano (cargando / error /
// reintentar, abortar al desmontar) y además caché entre pantallas: el
// catálogo y la lista de personajes que bajó el dashboard sirven tal cual
// para la ficha. El contrato de la API no cambia: las funciones de
// `client.ts` siguen siendo las que piden.
import { QueryClient, useQuery } from '@tanstack/react-query';
import type { Lang } from '../i18n/texts';
import { loadCatalog } from './catalog';
import {
  ApiError,
  fetchAccount,
  fetchAppVersion,
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
  appVersion: ['app-version'] as const,
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
