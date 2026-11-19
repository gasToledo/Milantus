import { queryOptions } from '@tanstack/react-query';
import { ApiError } from './client';

export interface Scenario {
  id: string;
  name: string;
  description: string;
  characterKeys: string[];
  hasImage: boolean;
  updatedAt: string;
}

export interface ScenarioCharacter {
  key: string;
  name: string;
  campaignId: string | null;
  campaignName: string | null;
}

const base = '/api/scenarios';
const pathFor = (id: string) => base + '/' + encodeURIComponent(id);

async function read<T>(path: string, signal: AbortSignal): Promise<T> {
  const response = await fetch(path, { signal });
  if (!response.ok) throw new ApiError(response.status, path);
  return response.json() as Promise<T>;
}

export const scenariosQuery = queryOptions({
  queryKey: ['dmScenarios'] as const,
  queryFn: async ({ signal }) => (await read<{ scenarios: Scenario[] }>(base, signal)).scenarios,
});

export const scenarioQuery = (id: string) => queryOptions({
  queryKey: ['dmScenario', id] as const,
  queryFn: ({ signal }) => read<Scenario>(pathFor(id), signal),
});

export const scenarioCharactersQuery = queryOptions({
  queryKey: ['dmScenarioCharacters'] as const,
  queryFn: async ({ signal }) =>
    (await read<{ characters: ScenarioCharacter[] }>(base + '/characters', signal)).characters,
});

interface ScenarioInput {
  name: string;
  description: string;
  characterKeys?: string[];
  image?: string | null;
}

export async function saveScenario(id: string | undefined, input: ScenarioInput): Promise<Scenario> {
  const path = id ? pathFor(id) : base;
  const response = await fetch(path, {
    method: id ? 'PUT' : 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(input),
  });
  if (!response.ok) throw new ApiError(response.status, path);
  return response.json() as Promise<Scenario>;
}

export async function deleteScenario(id: string): Promise<void> {
  const path = pathFor(id);
  const response = await fetch(path, { method: 'DELETE' });
  if (!response.ok) throw new ApiError(response.status, path);
}

export function scenarioImageHref(scenario: Scenario): string {
  return pathFor(scenario.id) + '/image?v=' + encodeURIComponent(scenario.updatedAt);
}
