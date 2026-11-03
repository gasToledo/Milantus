import { useTexts } from '../i18n/context';
import type { Advantage } from '../engine';
import type { Texts } from '../i18n/texts';
import { cx } from '../ui/cx';
import { Tooltip } from '../ui/primitives';
import { signed } from './format';
import { Tag } from './SpellList';

/** De dónde sale cada ventaja, sin repetir (`_advantageSources` de Flutter).
 *  Una fuente vacía es un rasgo sin nombre. */
export function advantageSources(advantages: Advantage[], t: Texts): string {
  return [...new Set(advantages.map((v) => v.source || t.advantageOtherTrait))].join(', ');
}

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
  advantage,
}: {
  id: string;
  kind: 'save' | 'skill';
  label: string;
  abbr?: string;
  modifier: number;
  proficient: boolean;
  expertise?: boolean;
  /** Las ventajas que valen en toda tirada de la fila, con su fuente. */
  advantage?: Advantage[];
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
      <span className="flex min-w-0 flex-1 items-center gap-1.5">
        <span className="truncate">
          {label}
          <span className="sr-only">{`, ${state}`}</span>
        </span>
        {advantage && advantage.length > 0 && <AdvantageMark advantages={advantage} />}
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

/** «Ventaja» al lado del nombre, con quién la da. El tooltip no existe en el
 *  teléfono, así que el mismo texto va también oculto para el lector. */
function AdvantageMark({ advantages }: { advantages: Advantage[] }) {
  const t = useTexts();
  const from = t.advantageFrom(advantageSources(advantages, t));
  return (
    <Tooltip content={from}>
      <span className="shrink-0">
        <Tag>{t.advantageTag}</Tag>
        <span className="sr-only">{`, ${from}`}</span>
      </span>
    </Tooltip>
  );
}
