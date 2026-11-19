import { useMemo, useState } from 'react';
import { Link } from '../../router';
import { cx } from '../../ui/cx';
import type { Mentions } from '../../ui/mentions';
import { MentionPanel } from './MentionPanel';
import { useMentionTargets, type MentionTarget } from './targets';

/**
 * Las menciones de un texto que se lee (el Cuaderno, los capítulos): cada
 * `@Nombre` es un enlace a su ficha, pero el clic simple la abre en el panel
 * lateral sin dejar la pantalla. Con un modificador, o con la rueda, sigue
 * siendo un enlace y abre la ficha en otra pestaña.
 *
 * Devuelve las [mentions] para `withMentions`/`MarkdownText`, el [panel], que
 * la pantalla dibuja una sola vez, y [readingClass]: con el panel abierto, la
 * pantalla le deja su lugar a la derecha para que no tape lo que se lee.
 */
export function useMentionReader(campaignId: string) {
  const targets = useMentionTargets(campaignId);
  const [open, setOpen] = useState<MentionTarget | null>(null);
  const mentions = useMemo((): Mentions => {
    const byName = new Map(targets.map((target) => [target.name, target]));
    return {
      names: targets.map((target) => target.name),
      render: (name, key) => {
        const target = byName.get(name)!;
        const on = open?.key === target.key;
        return (
          <Link
            key={key}
            href={target.href}
            data-mention={target.kind}
            aria-expanded={on}
            onClick={(event) => {
              if (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
              event.preventDefault();
              // La misma mención lo cierra; otra lo cambia.
              setOpen((current) => (current?.key === target.key ? null : target));
            }}
            className={cx(
              'rounded-[3px] font-semibold text-gold underline decoration-gold underline-offset-2',
              on && 'bg-gold-soft outline outline-[3px] outline-gold-soft',
            )}
          >
            {name}
          </Link>
        );
      },
    };
  }, [targets, open]);
  const panel = <MentionPanel target={open} onClose={() => setOpen(null)} />;
  const readingClass = cx('transition-[padding] duration-[180ms] ease-out', open && 'min-[1100px]:pr-[416px]');
  return { mentions, panel, readingClass };
}
