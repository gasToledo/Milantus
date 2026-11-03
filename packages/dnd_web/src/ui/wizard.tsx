import { Fragment, useState, type ReactNode } from 'react';
import { Check } from 'lucide-react';
import { fold, type CodexDetail } from '../codex/entries';
import type { Texts } from '../i18n/texts';
import { Button } from './Button';
import { cx } from './cx';
import { Eyebrow } from './data';

// Las piezas del circuito de los asistentes (subida de nivel y creador). El
// catálogo y cuándo usar cada una están en `docs/desarrollo/diseno-web-react.md`.

/** La columna derecha de un asistente. Sigue a la vista al bajar por los pasos
 *  largos: si no, explicar lo último que se tocó obligaba a volver a subir. El
 *  tope deja lugar al pie flotante, y si no entra se desplaza sola. */
export const WIZARD_ASIDE = 'flex min-w-0 flex-col gap-4 lg:sticky lg:top-4 lg:max-h-[calc(100vh-7rem)] lg:overflow-y-auto';

/** Un bloque de elección: título, un solo contador y las opciones. Entra con
 *  `step-in`, tanto al cambiar de paso como al aparecer por lo que se eligió. */
export function Block({ title, status, children }: { title: string; status?: ReactNode; children: ReactNode }) {
  return (
    <section className="step-in card flex min-w-0 flex-col gap-3 p-4">
      <div className="flex items-center justify-between gap-3">
        <h2 className="font-display text-[16px] text-on-surface">{title}</h2>
        {status}
      </div>
      {children}
    </section>
  );
}

/** Los tres estados de un bloque, y ningún otro: falta (con la cuenta si la
 *  hay), listo y automático. */
export function Status({
  ready = false,
  auto = false,
  count,
  label,
  t,
}: {
  ready?: boolean;
  auto?: boolean;
  count?: [number, number];
  /** Lo que falta dicho con palabras («Faltan 2»), cuando no es una cuenta de
   *  n de m. */
  label?: string;
  t: Texts;
}) {
  const pill = 'inline-flex items-center gap-1.5 rounded-[var(--radius-pill)] border border-hairline px-[9px] py-[2px] text-[11px] whitespace-nowrap';
  if (auto) return <span className={cx(pill, 'bg-plaque text-text-muted')}>{t.luAuto}</span>;
  if (ready)
    return (
      <span className={cx(pill, 'bg-gold-soft text-gold')}>
        <Check size={11} strokeWidth={3} aria-hidden="true" />
        {t.luReady}
      </span>
    );
  return (
    <span className={cx(pill, 'bg-plaque text-on-surface')}>
      <span aria-hidden="true" className="h-[7px] w-[7px] rounded-full border-[1.5px] border-current" />
      {label ?? (count ? t.luCount(count[0], count[1]) : t.luPending)}
    </span>
  );
}

/** La única forma de elegir: círculo si es una, cuadrado si son varias. */
export function Option({
  id,
  selected,
  multi = false,
  disabled = false,
  blocked = false,
  title,
  detail,
  trailing,
  onClick,
}: {
  /** El id de lo que se elige, en `data-option` (lo leen las pruebas). */
  id?: string;
  selected: boolean;
  multi?: boolean;
  disabled?: boolean;
  /** Atenuada como `disabled`, pero **responde al toque**: sirve para decir por
   *  qué no se puede elegir (el cupo está lleno) y mostrar su detalle. */
  blocked?: boolean;
  title: string;
  detail?: string;
  trailing?: ReactNode;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      role={multi ? 'checkbox' : 'radio'}
      aria-checked={selected}
      data-option={id}
      disabled={disabled}
      aria-disabled={blocked || undefined}
      onClick={onClick}
      className={cx(
        'flex min-h-12 w-full items-center gap-3 rounded-[var(--radius-card)] border px-3.5 py-2.5 text-left text-on-surface transition-colors duration-[120ms] disabled:cursor-default',
        selected ? 'border-gold bg-gold-soft' : 'border-hairline bg-plaque',
      )}
    >
      <span
        aria-hidden="true"
        className={cx(
          'flex h-[18px] w-[18px] shrink-0 items-center justify-center border-[1.5px]',
          multi ? 'rounded-[5px]' : 'rounded-full',
          selected ? (multi ? 'border-gold bg-gold' : 'border-gold') : 'border-text-muted',
          (disabled || blocked) && 'opacity-45',
        )}
      >
        {selected &&
          (multi ? (
            <Check size={12} strokeWidth={3.5} className="text-on-primary" />
          ) : (
            <span className="h-2 w-2 rounded-full bg-gold" />
          ))}
      </span>
      <span className="min-w-0 flex-1">
        <span className={cx('block font-medium', (disabled || blocked) && 'opacity-45')}>{title}</span>
        {detail && <span className="mt-0.5 block text-[12.5px] text-on-surface-variant">{detail}</span>}
      </span>
      {trailing}
    </button>
  );
}

export function Tag({ children }: { children: ReactNode }) {
  return (
    <span className="shrink-0 rounded-[var(--radius-pill)] border border-hairline px-1.5 text-[10px] text-on-surface-variant">
      {children}
    </span>
  );
}

/** Si un texto entra en la búsqueda: sin tildes ni mayúsculas y palabra por
 *  palabra, en cualquier orden. */
export const matchesQuery = (query: string, text: string): boolean => {
  const haystack = fold(text);
  return fold(query)
    .split(/\s+/)
    .filter(Boolean)
    .every((w) => haystack.includes(w));
};

/** La tira de pestañas de los conjuros (el creador y el editor de la ficha):
 *  una por cupo, con el estado de cada una. Elegir una no cambia lo demás. */
export function SpellTabs({
  tabs,
  current,
  onSelect,
  label,
  t,
  plain = false,
}: {
  tabs: { key: string; title: string; ready: boolean; count?: [number, number]; label?: string }[];
  current: string;
  onSelect: (key: string) => void;
  label: string;
  t: Texts;
  /** Sin el estado de cada pestaña ni el alto de dos renglones: dos vías
   *  alternativas (generar o subir un retrato) que no «se completan». */
  plain?: boolean;
}) {
  return (
    <div role="tablist" aria-label={label} className="flex gap-2 overflow-x-auto pb-1">
      {tabs.map((x) => {
        const on = x.key === current;
        return (
          <button
            key={x.key}
            type="button"
            role="tab"
            aria-selected={on}
            data-tab={x.key}
            onClick={() => onSelect(x.key)}
            className={cx(
              'flex shrink-0 rounded-[var(--radius-card)] border text-left text-on-surface transition-colors duration-[120ms]',
              plain
                ? 'h-[38px] items-center px-3.5'
                : 'w-[148px] flex-col items-start gap-1 px-3 py-2.5 sm:w-auto sm:min-w-0 sm:flex-1',
              on ? 'border-gold bg-gold-soft' : 'border-hairline bg-plaque',
            )}
          >
            <span className="text-[13px] leading-[1.25] font-medium">{x.title}</span>
            {!plain && <Status ready={x.ready} count={x.count} label={x.label} t={t} />}
          </button>
        );
      })}
    </div>
  );
}

/** Una lista larga: buscador, cuenta y scroll propio. [children] arma cada fila
 *  de lo que deja pasar el filtro. */
export function SearchableList<T>({
  items,
  textOf,
  label,
  count,
  columns = 1,
  multi = false,
  height = 'max-h-[300px]',
  groupOf,
  empty,
  children,
}: {
  items: T[];
  textOf: (item: T) => string;
  /** El grupo de cada ítem (los conjuros por nivel): un `Eyebrow` a todo el
   *  ancho cada vez que cambia. Los grupos se arman sobre lo que deja pasar
   *  el filtro, así que buscar no deja encabezados vacíos. Los ítems vienen
   *  ya ordenados por grupo. */
  groupOf?: (item: T) => string;
  /** Lo que se dice si el filtro no deja nada. */
  empty?: string;
  /** El nombre del buscador y de la lista, para el lector de pantalla. */
  label: string;
  count?: string;
  columns?: 1 | 2;
  multi?: boolean;
  height?: string;
  children: (item: T) => ReactNode;
}) {
  const [query, setQuery] = useState('');
  const visible = items.filter((i) => matchesQuery(query, textOf(i)));
  return (
    <>
      <div className="flex items-center gap-3">
        <input
          type="search"
          autoComplete="off"
          aria-label={label}
          placeholder={label}
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          className="h-9 min-w-0 flex-1 rounded-[var(--radius-pill)] border border-hairline bg-plaque px-4 text-[13px] text-on-surface placeholder:text-text-muted"
        />
        {count && <span className="text-[12.5px] whitespace-nowrap text-on-surface-variant">{count}</span>}
      </div>
      <div
        role={multi ? 'group' : 'radiogroup'}
        aria-label={label}
        className={cx('grid auto-rows-max gap-2 overflow-y-auto pr-1', height, columns === 2 && 'sm:grid-cols-2')}
      >
        {visible.length === 0 && empty && <p className="text-[13px] text-on-surface-variant">{empty}</p>}
        {visible.map((item, i) => {
          const group = groupOf?.(item);
          const head = group !== undefined && (i === 0 || group !== groupOf!(visible[i - 1]!));
          return head ? (
            <Fragment key={group}>
              <Eyebrow className="col-span-full pt-0.5">{group}</Eyebrow>
              {children(item)}
            </Fragment>
          ) : (
            children(item)
          );
        })}
      </div>
    </>
  );
}

/** Una lista de conjuros para elegir, con scroll propio y buscador: un mago
 *  alto tiene decenas. [cap] null es sin tope (el que conoce conjuros). */
export function SpellPickBlock({
  title,
  note,
  options,
  chosen,
  cap,
  ready,
  t,
  onChange,
  onFocus,
}: {
  title: string;
  /** Si el bloque está completo: lo dice el motor, que también sabe cuántos
   *  conjuros conoce quien no los prepara. */
  ready: boolean;
  note?: string;
  options: { id: string; name: string; level?: number }[];
  chosen: string[];
  cap: number | null;
  t: Texts;
  /** Las elegidas después del toque, y cuál se tocó. */
  onChange: (ids: string[], touched: string) => void;
  onFocus: (id: string) => void;
}) {
  const [query, setQuery] = useState('');
  const visible = options.filter((o) => matchesQuery(query, o.name));
  const full = cap !== null && chosen.length >= cap;
  return (
    <Block
      title={title}
      status={<Status ready={ready} count={cap === null || ready ? undefined : [chosen.length, cap]} t={t} />}
    >
      {note && <p className="text-[12.5px] text-on-surface-variant">{note}</p>}
      <input
        type="search"
        autoComplete="off"
        aria-label={t.luSpellSearch}
        placeholder={t.luSpellSearch}
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        className="h-9 rounded-[var(--radius-pill)] border border-hairline bg-plaque px-4 text-[13px] text-on-surface placeholder:text-text-muted"
      />
      <div className="grid max-h-[360px] gap-2 overflow-y-auto pr-1 sm:grid-cols-2" role="group" aria-label={title}>
        {visible.map((o) => {
          const on = chosen.includes(o.id);
          return (
            <Option
              key={o.id}
              id={o.id}
              multi
              selected={on}
              disabled={!on && full}
              title={o.name}
              detail={!o.level ? t.cantrip : t.spellLevelShort(o.level)}
              onClick={() => {
                onChange(on ? chosen.filter((x) => x !== o.id) : [...chosen, o.id], o.id);
                onFocus(o.id);
              }}
            />
          );
        })}
      </div>
    </Block>
  );
}

/** La tira de pasos. Se llega a un paso solo si los anteriores están
 *  completos; [progress] la cambia en un teléfono por «Paso n de m» y una barra,
 *  para que nueve pasos no ocupen media pantalla. */
export function StepRail({
  steps,
  index,
  reachable,
  onSelect,
  label,
  progress,
}: {
  steps: { id: string; label: string }[];
  index: number;
  reachable: (i: number) => boolean;
  onSelect: (id: string) => void;
  label: string;
  progress?: string;
}) {
  return (
    <>
      {progress && (
        <div className="flex flex-col gap-2 sm:hidden">
          <span className="text-[12.5px] text-on-surface-variant">{progress}</span>
          <div aria-hidden="true" className="flex gap-[3px]">
            {steps.map((s, i) => (
              <span key={s.id} className={cx('h-1 flex-1 rounded-[2px]', i <= index ? 'bg-gold' : 'bg-hairline')} />
            ))}
          </div>
        </div>
      )}
      <nav aria-label={label} className={cx(progress && 'hidden sm:block')}>
        <ol className="flex flex-wrap gap-1.5">
          {steps.map((s, i) => {
            const done = i < index;
            const cur = i === index;
            return (
              <li key={s.id}>
                <button
                  type="button"
                  aria-current={cur ? 'step' : undefined}
                  disabled={!reachable(i)}
                  onClick={() => onSelect(s.id)}
                  className={cx(
                    'flex items-center gap-2 rounded-[var(--radius-pill)] border py-1.5 pr-3 pl-1.5 text-[13px] transition-colors duration-[120ms] disabled:cursor-default',
                    cur ? 'border-gold bg-gold-soft font-medium text-gold' : 'border-hairline text-on-surface-variant',
                  )}
                >
                  <span
                    aria-hidden="true"
                    className={cx(
                      'flex h-[22px] w-[22px] items-center justify-center rounded-full text-[12px] font-bold',
                      cur ? 'bg-gold text-on-primary' : done ? 'bg-gold-soft text-gold' : 'border border-hairline bg-plaque',
                    )}
                  >
                    {done ? <Check size={12} strokeWidth={3} /> : i + 1}
                  </span>
                  {s.label}
                </button>
              </li>
            );
          })}
        </ol>
      </nav>
    </>
  );
}

/** El pie del paso: lo que falta y los botones, como una tarjeta flotando. Con
 *  fondo, filete y radio como las de arriba, y despegada del borde: una franja
 *  a sangre se leía como parte de otra pantalla. En un teléfono el mensaje va
 *  arriba y los botones se reparten el ancho. [above] va encima, a todo el
 *  ancho («Así queda» plegado en un teléfono). */
export function WizardFooter({
  message,
  above,
  children,
}: {
  message?: string | null;
  above?: ReactNode;
  children: ReactNode;
}) {
  return (
    <footer className="card sticky bottom-3 mt-auto flex flex-wrap items-center gap-x-4 gap-y-2.5 px-4 py-3">
      {above}
      {message && (
        <span className="min-w-0 flex-[1_1_240px] text-[13px] text-on-surface-variant" role="status">
          {message}
        </span>
      )}
      <span className="ml-auto flex w-full gap-2 sm:w-auto">{children}</span>
    </footer>
  );
}

/** La ficha de una entrada del Códice en el panel derecho: datos, prosa y
 *  rasgos, la misma información que el Códice para no tener dos versiones. */
export function DetailBody({ detail }: { detail: CodexDetail }) {
  return (
    <div className="flex flex-col gap-3 border-t border-hairline pt-3 text-[13.5px]">
      {detail.facts.flat().length > 0 && (
        <dl className="flex flex-col gap-1 text-[12.5px]">
          {detail.facts.flat().map((f) => (
            <div key={f.label} className="flex gap-2">
              <dt className="text-text-muted">{f.label}</dt>
              <dd className="text-on-surface">{f.value}</dd>
            </div>
          ))}
        </dl>
      )}
      {detail.prose && <p className="leading-[1.55] whitespace-pre-line">{detail.prose}</p>}
      {detail.sections.map((sec) => (
        <section key={sec.title}>
          <Eyebrow className="mb-1.5">{sec.title}</Eyebrow>
          <TraitList traits={sec.traits} />
        </section>
      ))}
    </div>
  );
}

export function TraitList({ traits }: { traits: { name: string; description?: string }[] }) {
  return (
    <ul className="flex flex-col gap-2">
      {traits.map((tr, i) => (
        <li key={`${tr.name}-${i}`}>
          <p className="font-medium">{tr.name}</p>
          {tr.description && <p className="mt-0.5 leading-[1.5] whitespace-pre-line text-on-surface-variant">{tr.description}</p>}
        </li>
      ))}
    </ul>
  );
}

/** Una fila de la revisión final: qué se eligió y cómo volver a ese paso. */
export function ReviewRow({ label, value, onChange, t }: { label: string; value: string; onChange: () => void; t: Texts }) {
  return (
    <div className="flex items-center gap-3.5 border-t border-hairline py-2.5 first:border-t-0">
      <span className="min-w-0 flex-1">
        <span className="block font-medium">{label}</span>
        <span className="mt-0.5 block text-[12.5px] text-on-surface-variant">{value}</span>
      </span>
      <Button tone="secondary" onClick={onChange}>
        {t.luChange}
      </Button>
    </div>
  );
}

/** Una fila de «Así queda». Sin [from], el valor solo; con él, «de → a». */
export interface AfterRow {
  label: string;
  from?: number;
  to: ReactNode;
  /** En oro: es lo que acaba de cambiar. */
  gold?: boolean;
  /** Una aclaración apagada al lado del valor («+ CON»). */
  note?: string;
}

/** Las filas de «Así queda». Los números salen del motor; ninguno se calcula
 *  acá. */
export function AfterList({ rows }: { rows: AfterRow[] }) {
  return (
    <dl className="plaque divide-y divide-hairline px-3.5 py-0.5 text-[13px]">
      {rows.map((r) => (
        <div key={r.label} className="flex items-baseline justify-between gap-3 py-2">
          <dt className="shrink-0">{r.label}</dt>
          <dd className="num text-right font-bold tabular-nums">
            {r.from === undefined || r.from === r.to ? (
              <span className={cx(r.gold && 'text-gold')}>{r.to}</span>
            ) : (
              <>
                {r.from} → <span className="text-gold">{r.to}</span>
              </>
            )}
            {r.note && <span className="ml-1.5 font-normal text-text-muted">{r.note}</span>}
          </dd>
        </div>
      ))}
    </dl>
  );
}

/** A la derecha, abajo: cómo queda la ficha. */
export function AfterCard({
  rows,
  heading,
  field,
  className,
}: {
  rows: AfterRow[];
  heading: string;
  /** El `data-field` de la tarjeta (lo leen las pruebas). */
  field: string;
  className?: string;
}) {
  return (
    <section className={cx('card p-4', className)} aria-label={heading} data-field={field}>
      <Eyebrow className="mb-2">{heading}</Eyebrow>
      <AfterList rows={rows} />
    </section>
  );
}
