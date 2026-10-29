import type { ReactNode } from 'react';
import { fold } from '../codex/entries';

/** A quiénes puede nombrar un texto con `@Nombre`, y cómo se dibuja cada uno. */
export interface Mentions {
  names: readonly string[];
  /** [name] es el nombre tal como está en [names], no como se escribió. */
  render: (name: string, key: string) => ReactNode;
}

const LETTER = /[\p{L}\p{N}]/u;

/**
 * Corta [text] en cada `@` seguida de uno de los nombres de [mentions]
 * (`_conMenciones` de `diary_cards.dart`, con el mismo criterio):
 *
 * - Sin delimitador de cierre: gana el nombre **más largo** que siga a la `@`,
 *   así «@Mirra la Tabernera» no se queda en «Mirra» si existen las dos.
 * - El nombre tiene que terminar ahí: «@Mirraela» no es Mirra.
 * - Sin distinguir mayúsculas ni tildes, como el buscador: «@Ines» es Inés.
 *   Plegar no cambia el largo de un nombre, así que se corta sobre el original.
 * - Una `@` que no coincide con nadie queda como texto.
 */
export function withMentions(text: string, mentions: Mentions | undefined, keyPrefix = ''): ReactNode[] {
  if (!mentions || mentions.names.length === 0 || !text.includes('@')) return [text];
  // Un nombre guardado con un espacio de más al final no coincidiría nunca con
  // «@Nombre,»: se compara recortado y se le pasa a `render` el original.
  const names = mentions.names
    .filter((n) => n.trim() !== '')
    .map((original) => ({ original, key: fold(original.trim()), length: original.trim().length }))
    .sort((a, b) => b.length - a.length);
  const out: ReactNode[] = [];
  let loose = 0;
  let at = text.indexOf('@');
  while (at >= 0) {
    const name = names.find((n) => {
      const end = at + 1 + n.length;
      if (fold(text.slice(at + 1, end)) !== n.key) return false;
      return end >= text.length || !LETTER.test(text[end]!);
    });
    if (!name) {
      at = text.indexOf('@', at + 1);
      continue;
    }
    if (at > loose) out.push(text.slice(loose, at));
    out.push(mentions.render(name.original, `${keyPrefix}@${at}`));
    loose = at + 1 + name.length;
    at = text.indexOf('@', loose);
  }
  if (loose < text.length) out.push(text.slice(loose));
  return out;
}
