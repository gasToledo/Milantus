import { useTexts } from '../i18n/context';
import { Button } from '../ui/Button';
import { CelebrationHeading, CelebrationPills, CelebrationShell, celebrationDelay } from '../ui/celebration';
import { StatPlaque } from '../ui/data';
import { Medallion } from '../ui/Medallion';

/** Lo que dice la presentación de un personaje recién creado. Lo arma el
 *  creador con la ficha que acaba de salir del motor: acá no se calcula nada. */
export interface CreatedData {
  name: string;
  subtitle: string;
  initial: string;
  accent: string | null;
  stats: { label: string; value: string | number; key?: boolean }[];
  features: string[];
}

// El aviso viaja del creador a la ficha por la memoria del módulo, sin
// persistirse: recargar la ficha no tiene que repetir la presentación.
const announced = new Map<string, CreatedData>();

export function announceCreated(id: string, data: CreatedData) {
  announced.set(id, data);
}

/** No lo consume: el modo estricto de React llama dos veces al inicializador de
 *  `useState` que lo lee, y la segunda ya no lo encontraría. Lo borra
 *  `clearCreated`, al cerrar. */
export function createdFor(id: string): CreatedData | null {
  return announced.get(id) ?? null;
}

export function clearCreated() {
  announced.clear();
}

/**
 * La presentación al crear un personaje (el lienzo «Creador: el personaje toma
 * forma», lámina C), armada como la celebración de la subida de nivel: el
 * medallón cae con el acento de su clase, un aro se abre y lo que trae entra de
 * a uno. Un `Dialog` de Radix: el foco queda adentro y `Escape` la cierra.
 */
export function CreatedCelebration({ data, onClose }: { data: CreatedData; onClose: () => void }) {
  const t = useTexts();
  return (
    <CelebrationShell
      kind="created"
      onDismiss={onClose}
      title={t.crCelebrateTitle(data.name)}
      subtitle={data.subtitle}
      hero={
        <>
          <span className="cr-ring absolute size-20 rounded-full border-2" style={{ borderColor: data.accent ?? 'var(--gold)' }} />
          <span className="cr-med relative flex">
            <Medallion name={data.initial} accent={data.accent} size={80} />
          </span>
        </>
      }
      actions={
        <Button className="mt-[26px] min-h-11 w-full" onClick={onClose} data-action="created-close">
          {t.crCelebrateClose}
        </Button>
      }
    >
      {/* El escalonado sigue después del aro: las placas y los rasgos, en una cuenta. */}
      <CelebrationHeading label={t.crCelebrateStart} />
      <dl className="mt-2.5 grid grid-cols-4 gap-2">
        {data.stats.map((s, i) => (
          <StatPlaque
            key={s.label}
            label={s.label}
            value={s.value}
            valueClassName={s.key ? 'text-gold' : 'text-on-surface'}
            className="lv-up"
            style={celebrationDelay(i)}
          />
        ))}
      </dl>
      {data.features.length > 0 && (
        <>
          <CelebrationHeading label={t.crCelebrateBrings} spaced />
          <CelebrationPills items={data.features} start={data.stats.length} />
        </>
      )}
    </CelebrationShell>
  );
}
