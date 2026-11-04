import { useTexts } from '../../i18n/context';
import { cx } from '../../ui/cx';
import { NPC_STATUSES, STATUS_FILL, type NpcStatus } from './npc';

/**
 * Vivo · Muerto · Desconocido en una sola fila. La palabra siempre está: quien
 * no distingue el verde del rojo tiene que saber igual si el PNJ sigue vivo.
 */
export function NpcStatusSelector({ status, label, onChange }: { status: NpcStatus; label: string; onChange: (status: NpcStatus) => void }) {
  const t = useTexts();
  return (
    <div role="group" aria-label={label} className="flex w-full overflow-hidden rounded-[var(--radius-nav)] border border-hairline">
      {NPC_STATUSES.map((s, i) => (
        <button
          key={s}
          type="button"
          aria-pressed={s === status}
          data-status-option={s}
          onClick={() => s !== status && onChange(s)}
          className={cx(
            'min-h-11 min-w-0 flex-1 px-1 text-[12px] transition-colors duration-[120ms]',
            i > 0 && 'border-l border-hairline',
            s === status ? STATUS_FILL[s] : 'text-on-surface-variant hover:bg-plaque hover:text-on-surface',
          )}
        >
          {t.npcStatus[s]}
        </button>
      ))}
    </div>
  );
}
