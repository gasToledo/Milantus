import { ApiError } from './client';
import type { CharacterJson, JsonObject } from '../engine';

const MAX_BACKUP_BYTES = 256 * 1024 * 1024;
/** Lo mismo que `NpcBundleCodec.maxArchiveBytes` del servidor: un archivo más
 *  grande se descarta acá, sin subirlo. */
const MAX_NPC_BYTES = 64 * 1024 * 1024;

/** El fallo de una respuesta, con el `code` estable que manda el servidor
 *  (`{ error, code }`): la pantalla traduce por él y no por el mensaje en
 *  castellano. Un cuerpo que no se puede leer deja `code` sin valor. */
async function failure(response: Response, path: string): Promise<ApiError> {
  let code: string | undefined;
  try {
    const body = (await response.json()) as { code?: unknown };
    if (typeof body.code === 'string') code = body.code;
  } catch {
    code = undefined;
  }
  return new ApiError(response.status, path, code);
}

/** El archivo como base64, que es como la API recibe un ZIP. */
async function base64Of(file: File): Promise<string> {
  const dataUrl = await new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result as string);
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(file);
  });
  return dataUrl.slice(dataUrl.indexOf(',') + 1);
}

async function postZip(path: string, file: File, extra: Record<string, string> = {}): Promise<Response> {
  const response = await fetch(path, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ bytes: await base64Of(file), ...extra }),
  });
  if (!response.ok) throw await failure(response, path);
  return response;
}

/** La API valida el ZIP. El navegador solo lo envía en el formato de Flutter. */
export async function importBackup(file: File): Promise<{ charactersImported: number; portraitsImported: number }> {
  const path = '/api/import';
  if (file.size > MAX_BACKUP_BYTES) throw new ApiError(413, path);
  return (await postZip(path, file)).json();
}

/** Baja un ZIP que arma el servidor: el nombre lo manda él en
 *  `content-disposition`, y [fallbackName] es el de respaldo. */
async function downloadZip(path: string, fallbackName: string): Promise<void> {
  const response = await fetch(path);
  if (!response.ok) throw await failure(response, path);
  const fileName = response.headers.get('content-disposition')?.match(/filename="([A-Za-z0-9._-]+\.zip)"/)?.[1];
  const url = URL.createObjectURL(await response.blob());
  const link = document.createElement('a');
  link.href = url;
  link.download = fileName ?? fallbackName;
  document.body.append(link);
  link.click();
  link.remove();
  // El navegador puede abrir el blob después de despachar el clic.
  setTimeout(() => URL.revokeObjectURL(url), 60_000);
}

export const downloadBackup = (characterId?: string): Promise<void> =>
  downloadZip(characterId === undefined ? '/api/export' : `/api/export?${new URLSearchParams({ characterId })}`, 'backup.zip');

/** Qué viaja además de lo que va siempre. Se manda como `1` o `0`: el servidor
 *  toma como «no» todo lo que no sea `1`, así que las notas nunca salen por
 *  un olvido de quien arma el pedido. */
export interface NpcExportOptions {
  background: boolean;
  tags: boolean;
  notes: boolean;
}

/** `GET /api/npcs/:id/export`: el servidor arma el ZIP (`dnd_npc`). */
export function exportNpc(id: string, options: NpcExportOptions): Promise<void> {
  const flag = (on: boolean) => (on ? '1' : '0');
  const query = new URLSearchParams({ background: flag(options.background), tags: flag(options.tags), notes: flag(options.notes) });
  return downloadZip(`/api/npcs/${encodeURIComponent(id)}/export?${query}`, 'pnj.zip');
}

/** Lo que trae un archivo de PNJ, tal como lo lee el servidor (que sirve igual
 *  para el ZIP de un PNJ y para el de **un** personaje exportado). */
export interface NpcImportPreview {
  npc: JsonObject;
  character?: CharacterJson;
  homebrew: Record<string, JsonObject[]>;
  portraitCount: number;
}

/** `POST /api/npcs/import/preview`: no escribe nada. */
export async function previewNpcImport(file: File): Promise<NpcImportPreview> {
  const path = '/api/npcs/import/preview';
  if (file.size > MAX_NPC_BYTES) throw new ApiError(413, path);
  return (await postZip(path, file)).json();
}

/** `POST /api/npcs/import`: crea siempre una copia nueva, nunca reemplaza. */
export async function importNpc(file: File, campaignId?: string): Promise<{ npc: JsonObject & { id: string; name?: string } }> {
  const path = '/api/npcs/import';
  if (file.size > MAX_NPC_BYTES) throw new ApiError(413, path);
  return (await postZip(path, file, campaignId ? { campaignId } : {})).json();
}
