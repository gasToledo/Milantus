import { ApiError } from './client';

const MAX_BACKUP_BYTES = 256 * 1024 * 1024;

/** La API valida el ZIP. El navegador solo lo envía en el formato de Flutter. */
export async function importBackup(file: File): Promise<{ charactersImported: number; portraitsImported: number }> {
  const path = '/api/import';
  if (file.size > MAX_BACKUP_BYTES) throw new ApiError(413, path);
  const dataUrl = await new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result as string);
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(file);
  });
  const response = await fetch(path, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ bytes: dataUrl.slice(dataUrl.indexOf(',') + 1) }),
  });
  if (!response.ok) throw new ApiError(response.status, path);
  return response.json();
}

export async function downloadBackup(characterId?: string): Promise<void> {
  const path = characterId === undefined ? '/api/export' : `/api/export?${new URLSearchParams({ characterId })}`;
  const response = await fetch(path);
  if (!response.ok) throw new ApiError(response.status, path);
  const fileName = response.headers.get('content-disposition')?.match(/filename="([A-Za-z0-9._-]+\.zip)"/)?.[1];
  const url = URL.createObjectURL(await response.blob());
  const link = document.createElement('a');
  link.href = url;
  link.download = fileName ?? 'backup.zip';
  document.body.append(link);
  link.click();
  link.remove();
  // El navegador puede abrir el blob después de despachar el clic.
  setTimeout(() => URL.revokeObjectURL(url), 60_000);
}
