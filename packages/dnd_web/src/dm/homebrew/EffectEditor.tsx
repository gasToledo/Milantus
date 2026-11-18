import { useMemo, useState } from 'react';
import { Plus, Trash2 } from 'lucide-react';
import { describeEffectParts } from '../../codex/effectText';
import { effectParts, type Catalog, type JsonObject } from '../../engine';
import { useTexts } from '../../i18n/context';
import { Tooltip } from '../../ui/primitives';
import { AddEffectDialog } from './AddEffectDialog';

/**
 * La lista de efectos de una entrada propia (`EffectEditor` de Flutter): los
 * lista con su frase, quita y agrega. Un efecto **no se edita en el lugar**: se
 * quita y se vuelve a agregar.
 *
 * Los efectos son JSON del motor y acá se tratan como tales: la frase sale de
 * `effectParts` y los nuevos los arma `effectBuild`. Uno que el motor no
 * describe (elecciones, maquinaria de clase) se lista por su `type` con la marca
 * «se conserva» y se guarda tal cual: al jugador lo que no se puede describir no
 * se le muestra, pero acá mira quien arma el contenido, y ocultarlo escondería
 * un efecto que igual se guarda.
 *
 * `hiddenKinds` saca tipos del diálogo «Agregar efecto»: los objetos esconden la
 * CA y la resistencia, que tienen su campo arriba. Es presentación, no una
 * regla, y no toca los efectos que ya están en la lista. Tiene que ser una
 * constante: el diálogo la usa como dependencia.
 *
 * ponytail: no ofrece los efectos de **elección** ni la maquinaria de clase (un
 * subformulario con su propia lista de opciones). Se siguen cargando por JSON o
 * importando el pack.
 */
export function EffectEditor({
  effects,
  catalog,
  onChange,
  hiddenKinds,
}: {
  effects: JsonObject[];
  catalog: Catalog;
  onChange: (effects: JsonObject[]) => void;
  /** Ids de tipo de efecto que el diálogo no ofrece. */
  hiddenKinds?: string[];
}) {
  const t = useTexts();
  const [adding, setAdding] = useState(false);
  const rows = useMemo(
    () =>
      effectParts(effects, catalog).map((r) => ({
        type: r.type,
        text: r.parts ? describeEffectParts(r.parts, t) : null,
      })),
    [effects, catalog, t],
  );

  return (
    <div className="flex flex-col gap-2.5">
      {rows.length === 0 ? (
        <p className="text-[14px] text-on-surface-variant">{t.effNone}</p>
      ) : (
        <ul className="rounded-[var(--radius-card)] border border-hairline bg-plaque py-0.5" data-field="effects-list">
          {rows.map((row, i) => (
            // La clave no es solo el índice: al quitar uno, los de abajo no
            // repiten la entrada de los que siguen siendo los mismos.
            <li key={`${i}|${row.type}|${row.text}`} className="step-in flex min-h-11 items-center gap-2.5 border-t border-hairline py-1 pr-1.5 pl-3 first:border-t-0">
              <span aria-hidden="true" className="size-[7px] shrink-0 rotate-45 rounded-[1px] bg-gold" />
              <span className="min-w-0 flex-1 text-[14px] text-on-surface" data-effect={row.type}>
                {row.text ?? row.type}
              </span>
              {row.text === null && <span className="shrink-0 text-[12px] text-text-muted">{t.effKept}</span>}
              <Tooltip content={t.effRemove}>
                <button
                  type="button"
                  aria-label={t.effRemove}
                  onClick={() => onChange(effects.filter((_, j) => j !== i))}
                  className="inline-flex size-[34px] shrink-0 items-center justify-center rounded-[var(--radius-nav)] text-on-surface-variant hover:text-crimson"
                >
                  <Trash2 size={16} aria-hidden="true" />
                </button>
              </Tooltip>
            </li>
          ))}
        </ul>
      )}
      <button
        type="button"
        data-action="effect-add"
        onClick={() => setAdding(true)}
        className="flex min-h-[42px] w-full items-center justify-center gap-2 rounded-[var(--radius-card)] border border-dashed border-[color-mix(in_srgb,var(--gold)_35%,var(--hairline))] text-[13.5px] text-on-surface-variant transition-colors duration-[120ms] hover:border-gold hover:text-gold"
      >
        <Plus size={16} aria-hidden="true" />
        {t.effAdd}
      </button>
      {adding && <AddEffectDialog catalog={catalog} hiddenKinds={hiddenKinds} onAdd={(effect) => onChange([...effects, effect])} onClose={() => setAdding(false)} />}
    </div>
  );
}
