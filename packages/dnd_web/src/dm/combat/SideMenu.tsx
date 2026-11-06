import { useTexts } from '../../i18n/context';
import { cx } from '../../ui/cx';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuRadioGroup, DropdownMenuRadioItem, DropdownMenuSeparator, DropdownMenuTrigger, Tooltip } from '../../ui/primitives';

export const SIDE_TONE: Record<string, string> = {
  ally: 'border-verdant text-verdant',
  enemy: 'border-crimson text-crimson',
  neutral: 'border-text-muted text-text-muted',
};

const PILL = 'shrink-0 rounded-[var(--radius-pill)] border px-2 text-[11px]';

/** El bando de una fila. Con [canChange] la pill abre el menú para cambiarlo; sin
 *  él (un PNJ sin estadísticas) es neutral fijo y lo dice. */
export function SideMenu({ side, name, canChange, onChange, onConvert }: { side: string; name: string; canChange: boolean; onChange: (side: string) => void; onConvert?: () => void }) {
  const t = useTexts();
  const tone = SIDE_TONE[side] ?? SIDE_TONE.neutral;
  const word = t.encSides[side] ?? side;
  if (!canChange) {
    return (
      <Tooltip content={t.encFixedNeutral}>
        <span className={cx(PILL, tone)} data-field="side">
          {word}
        </span>
      </Tooltip>
    );
  }
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <button type="button" aria-label={t.encSideOf(name)} className={cx(PILL, tone, 'data-[state=open]:outline-2 data-[state=open]:outline-offset-2 data-[state=open]:outline-gold')} data-field="side">
          {word}
        </button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="start">
        <DropdownMenuRadioGroup value={side} onValueChange={(s) => s !== side && onChange(s)}>
          {['ally', 'enemy', 'neutral'].map((s) => (
            <DropdownMenuRadioItem key={s} value={s}>
              {t.encSides[s]}
            </DropdownMenuRadioItem>
          ))}
        </DropdownMenuRadioGroup>
        {onConvert && (
          <>
            <DropdownMenuSeparator />
            <DropdownMenuItem onSelect={onConvert}>{t.encConvertToNpcEllipsis}</DropdownMenuItem>
          </>
        )}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
