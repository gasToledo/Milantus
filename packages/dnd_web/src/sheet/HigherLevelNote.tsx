import { useTexts } from '../i18n/context';

/**
 * El párrafo de mejora de un conjuro. El catálogo guarda solo el texto: el
 * rótulo lo elige el nivel, porque un truco escala con el personaje y un
 * conjuro con nivel escala con el espacio. Es el mismo párrafo en la ficha,
 * en el Códice y al cambiar un truco innato.
 */
export function HigherLevelNote({
  text,
  level,
  label,
  className = 'mt-2',
}: {
  text: string;
  /** Si no viene [label], el nivel elige el rótulo. */
  level?: number;
  label?: string;
  className?: string;
}) {
  const t = useTexts();
  if (!text) return null;
  const shown = label ?? ((level ?? 0) === 0 ? t.cantripUpgrade : t.spellHigherLevel);
  return (
    <p className={className}>
      <b className="font-semibold text-on-surface">{shown}</b> {text}
    </p>
  );
}
