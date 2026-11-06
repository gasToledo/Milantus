import { CircleMinus, CirclePlus } from 'lucide-react';
import { useTexts } from '../../i18n/context';
import { Eyebrow } from '../../ui/data';
import { Option } from '../../ui/wizard';
import { SideSelector } from './SideSelector';

export interface MonsterDraft {
  count: number;
  rollHp: boolean;
  side: 'ally' | 'enemy' | 'neutral';
}

export function MonsterQuantity({ draft, onChange, hp, hitDice, disabled = false }: {
  draft: MonsterDraft;
  onChange: (draft: MonsterDraft) => void;
  hp: string;
  hitDice?: string | null;
  disabled?: boolean;
}) {
  const t = useTexts();
  const { count, rollHp, side } = draft;
  return (
    <>
      <div className="flex items-center justify-center gap-2.5">
        <button
          type="button"
          aria-label={t.dmOneFewer}
          disabled={disabled || count <= 1}
          onClick={() => onChange({ ...draft, count: count - 1 })}
          className="flex h-11 w-11 items-center justify-center rounded-[var(--radius-nav)] text-on-surface-variant hover:text-on-surface disabled:opacity-40"
        >
          <CircleMinus size={22} aria-hidden="true" />
        </button>
        <b className="num w-10 text-center text-[20px]" data-field="count">{count}</b>
        <button
          type="button"
          aria-label={t.dmOneMore}
          disabled={disabled}
          onClick={() => onChange({ ...draft, count: count + 1 })}
          className="flex h-11 w-11 items-center justify-center rounded-[var(--radius-nav)] text-on-surface-variant hover:text-on-surface disabled:opacity-40"
        >
          <CirclePlus size={22} aria-hidden="true" />
        </button>
      </div>
      {hitDice && (
        <Option
          multi
          selected={rollHp}
          disabled={disabled}
          title={t.dmRollEachHp}
          detail={rollHp ? t.dmEachRolls(hitDice) : t.dmAllStartWith(hp)}
          onClick={() => onChange({ ...draft, rollHp: !rollHp })}
        />
      )}
      <div>
        <Eyebrow className="mb-1.5">{t.dmWhichSide}</Eyebrow>
        <SideSelector value={side} onChange={(value) => onChange({ ...draft, side: value as MonsterDraft['side'] })} disabled={disabled} />
      </div>
    </>
  );
}
