import type { ReactNode } from 'react';
import { withMentions, type Mentions } from './mentions';

/**
 * El Markdown que usa una mesa (`MarkdownText` de Flutter, en
 * `ui/diary_cards.dart`), con el mismo subconjunto para que un trasfondo se
 * lea igual en los dos clientes: títulos (`#`, `##`, `###`), viñetas (`-`,
 * `*`), párrafos separados por una línea en blanco, y **negrita** e *itálica*
 * dentro de la línea.
 *
 * Con [mentions], cada `@Nombre` de uno de ellos se dibuja como ellos digan
 * (el Cuaderno: un enlace a la ficha; ver `withMentions`).
 *
 * Arma elementos de React y nunca HTML: el texto lo escribe una persona y
 * viaja tal cual, así que no hay forma de que una etiqueta suya llegue al DOM.
 *
 * ponytail: subconjunto a mano, como en Flutter. No entiende enlaces, código,
 * citas, tablas ni listas anidadas; si un día hacen falta, la salida es una
 * librería de Markdown con el HTML apagado, en los dos clientes a la vez.
 */
export function MarkdownText({ text, className, mentions }: { text: string; className?: string; mentions?: Mentions }) {
  const blocks: ReactNode[] = [];
  let paragraph: string[] = [];
  let bullets: string[] = [];

  const flushParagraph = () => {
    if (paragraph.length === 0) return;
    blocks.push(
      <p key={blocks.length} className="mb-3 last:mb-0">
        {inline(paragraph.join('\n'), mentions)}
      </p>,
    );
    paragraph = [];
  };
  const flushBullets = () => {
    if (bullets.length === 0) return;
    blocks.push(
      <ul key={blocks.length} className="mb-3 list-disc pl-5 last:mb-0 marker:text-gold">
        {bullets.map((b, i) => (
          <li key={i} className="mb-1">
            {inline(b, mentions)}
          </li>
        ))}
      </ul>,
    );
    bullets = [];
  };

  for (const raw of text.split('\n')) {
    const line = raw.trimEnd();
    const heading = /^(#{1,3})\s+(.*)$/.exec(line);
    const bullet = /^\s*[-*]\s+(.*)$/.exec(line);
    if (line.trim() === '') {
      flushParagraph();
      flushBullets();
    } else if (heading) {
      flushParagraph();
      flushBullets();
      // Adentro de una tarjeta que ya tiene su `h2`: los títulos del texto
      // bajan a `h3`/`h4` para no romper el orden de la pantalla.
      const level = heading[1]!.length;
      const Tag = level === 1 ? 'h3' : 'h4';
      blocks.push(
        <Tag key={blocks.length} className={`font-display mt-1 mb-2 text-on-surface ${level === 1 ? 'text-[18px]' : 'text-[16px]'}`}>
          {inline(heading[2]!, mentions)}
        </Tag>,
      );
    } else if (bullet) {
      flushParagraph();
      bullets.push(bullet[1]!);
    } else {
      flushBullets();
      paragraph.push(line);
    }
  }
  flushParagraph();
  flushBullets();

  return <div className={`whitespace-pre-line ${className ?? ''}`}>{blocks}</div>;
}

/** **Negrita** e *itálica* (o _itálica_) dentro de una línea. Lo que no cierra
 *  queda como texto: un asterisco suelto no se come el resto del párrafo. */
function inline(text: string, mentions: Mentions | undefined): ReactNode[] {
  const out: ReactNode[] = [];
  const pattern = /\*\*(.+?)\*\*|\*(.+?)\*|_(.+?)_/g;
  let last = 0;
  for (const m of text.matchAll(pattern)) {
    if (m.index > last) out.push(...withMentions(text.slice(last, m.index), mentions, `${last}`));
    const inner = withMentions(m[1] ?? m[2] ?? m[3] ?? '', mentions, `${m.index}`);
    out.push(m[1] !== undefined ? <strong key={m.index}>{inner}</strong> : <em key={m.index}>{inner}</em>);
    last = m.index + m[0].length;
  }
  if (last < text.length) out.push(...withMentions(text.slice(last), mentions, `${last}`));
  return out;
}
