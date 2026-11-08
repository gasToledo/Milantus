import { useMemo, useState } from 'react';
import { Plus, Trash2 } from 'lucide-react';
import { describeEffectParts } from '../../codex/effectText';
import { effectParts, type Catalog, type JsonObject } from '../../engine';
import { useTexts } from '../../i18n/context';
import { Button } from '../../ui/Button';
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
 * ponytail: no ofrece los efectos de **elección** ni la maquinaria de clase (un
 * subformulario con su propia lista de opciones), ni esconde tipos por
 * formulario (`hiddenKinds` de Flutter, que usan los objetos: 7d3). Todo eso se
 * sigue cargando por JSON o importando el pack.
 */
export function EffectEditor({
  effects,
  catalog,
  onChange,
}: {
  effects: JsonObject[];
  catalog: Catalog;
  onChange: (effects: JsonObject[]) => void;
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
        <ul className="rounded-[var(--radius-card)] border border-hairline bg-plaque" data-field="effects-list">
          {rows.map((row, i) => (
            <li key={i} className="flex min-h-10 items-center gap-2.5 border-t border-hairline py-1 pr-1.5 pl-3.5 first:border-t-0">
              <span className="min-w-0 flex-1 text-[14px] text-on-surface" data-effect={row.type}>
                {row.text ?? row.type}
              </span>
              {row.text === null && <span className="shrink-0 text-[12px] text-text-muted">{t.effKept}</span>}
              <Tooltip content={t.effRemove}>
                <button
                  type="button"
                  aria-label={t.effRemove}
                  onClick={() => onChange(effects.filter((_, j) => j !== i))}
                  className="inline-flex size-9 shrink-0 items-center justify-center rounded-[var(--radius-nav)] text-on-surface-variant hover:text-crimson"
                >
                  <Trash2 size={16} aria-hidden="true" />
                </button>
              </Tooltip>
            </li>
          ))}
        </ul>
      )}
      <div>
        <Button tone="secondary" icon={Plus} data-action="effect-add" onClick={() => setAdding(true)}>
          {t.effAdd}
        </Button>
      </div>
      {adding && <AddEffectDialog catalog={catalog} onAdd={(effect) => onChange([...effects, effect])} onClose={() => setAdding(false)} />}
    </div>
  );
}
