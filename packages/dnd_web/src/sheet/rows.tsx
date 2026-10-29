import { useTexts } from '../i18n/context';
import { cx } from '../ui/cx';
import { signed } from './format';

/**
 * Una habilidad o una salvación: punto, nombre, (abreviatura de la
 * característica) y valor. Con competencia la fila entera va en oro sobre
 * `goldSoft`: es lo que se busca de un vistazo. Con pericia el punto es un
 * aro. El color no es el único portador: el estado se dice en texto oculto.
 */
export function ProficiencyRow({
  id,
  kind,
  label,
  abbr,
  modifier,
  proficient,
  expertise = false,
}: {
  id: string;
  kind: 'save' | 'skill';
  label: string;
  abbr?: string;
  modifier: number;
  proficient: boolean;
  expertise?: boolean;
}) {
  const t = useTexts();
  const on = proficient || expertise;
  const state = expertise ? t.expertise : on ? t.proficient : t.notProficient;
  return (
    <li
      data-row={`${kind}-${id}`}
      className={cx(
        'flex items-center gap-2.5 rounded-[8px] px-2 py-1.5 text-[14px]',
        on ? 'bg-gold-soft text-gold' : 'text-on-surface',
      )}
    >
      <span aria-hidden="true" className="flex h-3 w-3 shrink-0 items-center justify-center">
        <span
          className={
            expertise
              ? 'h-3 w-3 rounded-full border-[3px] border-gold'
              : cx('h-2 w-2 rounded-full', on ? 'bg-gold' : 'bg-hairline')
          }
        />
      </span>
      <span className="min-w-0 flex-1 truncate">
        {label}
        <span className="sr-only">{`, ${state}`}</span>
      </span>
      {abbr && (
        <span aria-hidden="true" className="text-[10px] tracking-[1px] text-text-muted uppercase">
          {abbr}
        </span>
      )}
      <span className="num w-9 shrink-0 text-right" data-field="modifier">
        {signed(modifier)}
      </span>
    </li>
  );
}
