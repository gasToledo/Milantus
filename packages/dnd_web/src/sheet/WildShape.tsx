import { useMemo, useState } from 'react';
import { Info, PawPrint } from 'lucide-react';
import { asProfile, type CreatureProfile as Profile } from '../bestiary/creature';
import { CreatureProfile } from '../bestiary/CreatureProfile';
import { bestiary, type BestiaryRow } from '../engine';
import { useTexts } from '../i18n/context';
import { navigate, wildShapeFormsHref } from '../router';
import { AppDialog } from '../ui/AppDialog';
import { Button } from '../ui/Button';
import { cx } from '../ui/cx';
import { Option } from '../ui/wizard';
import { resourceLeft, type SheetModel } from './model';
import type { SheetWriter } from './writer';

/** El recurso que gasta la Forma Salvaje: el mismo `id` que declara el
 *  contenido y que usa `CombatOps.wildShapeResourceId` en el motor. */
const WILD_SHAPE_RESOURCE = 'wild_shape';

/**
 * El perfil de la bestia en que está transformado el personaje, o null. Mira
 * el catálogo y no solo el id guardado: si la bestia ya no está, `compute`
 * tampoco aplica la forma, y la ficha no tiene que decir que se transformó.
 */
export function activeForm(model: SheetModel): Profile | null {
  const id = model.character.combat?.wildShapeCreatureId;
  if (!id) return null;
  const raw = model.catalog.creatures.find((c) => c.id === id);
  return raw ? asProfile(raw) : null;
}

/**
 * La franja de la Forma Salvaje en la banda táctica, con la estructura de
 * `ActiveModeTile`: los usos que quedan y «Transformarse», o «En curso ·
 * Volver». Sin escritura solo se muestra transformado. No es un estado
 * activable del motor (la forma se elige y cambia la ficha entera), pero se
 * juega igual: desde cualquier pestaña, en el turno.
 */
export function WildShapeTile({ model }: { model: SheetModel }) {
  const t = useTexts();
  const { sheet, write } = model;
  const [open, setOpen] = useState(false);
  const slot = sheet.wildShape;
  const form = activeForm(model);
  if (!slot) return null;
  if (!write && !form) return null;

  const resource = sheet.resources.find((r) => r.id === WILD_SHAPE_RESOURCE);
  const max = resource?.max ?? 0;
  const left = resource ? resourceLeft(model, resource) : 0;
  const noForms = slot.chosen.length === 0;
  // Anotar formas es una pantalla de la ficha propia (6f3 la trae al PNJ): sin
  // formas y sin forma activa no hay nada que mostrar ni adónde llevar.
  if (write?.kind === 'npc' && noForms && !form) return null;
  const noUses = left === 0;

  const meta = form ? t.wsUses(left, max) : t.wsUsesForms(left, max, slot.chosen.length, slot.count);
  const action = form ? t.wsActionOn : noForms ? t.wsActionAdd : noUses ? t.wsActionNoUses : t.wsActionGo;
  // «Sin usos» se apaga pero el toque sigue abriendo el diálogo: se puede
  // anotar formas aunque hoy no haya con qué transformarse.
  const dim = !form && !noForms && noUses;
  const onClick = () => {
    if (!write) return;
    if (form) write.act({ type: 'leaveWildShape' });
    else if (noForms) navigate(wildShapeFormsHref(model.character.id));
    else setOpen(true);
  };

  const body = (
    <>
      <PawPrint size={22} aria-hidden="true" className={cx('shrink-0', dim ? 'text-text-muted' : 'text-gold')} />
      <span className="flex min-w-0 flex-1 flex-col gap-0.5">
        <span className={cx('text-[15px] font-semibold', form ? 'text-gold' : 'text-on-surface')}>
          {form ? t.wsTileTitle(form.name) : t.wsTitle}
        </span>
        <span className="text-[12.5px] text-on-surface-variant">{meta}</span>
      </span>
      <span className={cx('text-right text-[13px] font-semibold', dim ? 'text-text-muted' : 'text-gold')}>{action}</span>
    </>
  );
  const strip = cx(
    'plaque flex min-h-[60px] w-full items-center gap-3.5 px-4 py-2.5 text-left font-[family-name:var(--font-body)]',
    form && '!border-gold bg-gold-soft',
  );
  return (
    <div data-stat="wild-shape" className="min-w-0">
      <dt className="sr-only">{t.wsTitle}</dt>
      <dd>
        {write ? (
          <button type="button" onClick={onClick} className={cx(strip, 'cursor-pointer', dim && 'opacity-60')}>
            {body}
          </button>
        ) : (
          <div className={strip}>{body}</div>
        )}
      </dd>
      {open && write && <WildShapeDialog model={model} write={write} onClose={() => setOpen(false)} />}
    </div>
  );
}

interface Form {
  id: string;
  profile: Profile;
  row: BestiaryRow;
}

/** Elegir en cuál transformarse. Elegir no transforma: lo hace la acción
 *  primaria. Anotar formas lleva a la ruta de las formas. */
function WildShapeDialog({ model, write, onClose }: { model: SheetModel; write: SheetWriter; onClose: () => void }) {
  const t = useTexts();
  const { sheet, catalog, character } = model;
  const slot = sheet.wildShape!;
  const resource = sheet.resources.find((r) => r.id === WILD_SHAPE_RESOURCE);
  const max = resource?.max ?? 0;
  const left = resource ? resourceLeft(model, resource) : 0;

  const forms = useMemo(() => {
    const rows = new Map(bestiary(catalog).map((r) => [r.id, r] as const));
    const raws = new Map(catalog.creatures.map((c) => [c.id as string, c] as const));
    return slot.chosen.flatMap((b): Form[] => {
      const row = rows.get(b.id);
      const raw = raws.get(b.id);
      return row && raw ? [{ id: b.id, profile: asProfile(raw), row }] : [];
    });
  }, [slot, catalog]);

  // Arranca marcada la primera forma. `peek` es, en teléfono, el perfil que
  // reemplaza a la lista dentro del mismo diálogo (sin anidar otro).
  const [pick, setPick] = useState<string | null>(forms[0]?.id ?? null);
  const [peek, setPeek] = useState<string | null>(null);
  const picked = forms.find((f) => f.id === pick);
  const peeked = forms.find((f) => f.id === peek);

  const transform = () => {
    if (!picked) return;
    const r = write.act({ type: 'enterWildShape', creature: picked.id });
    if (!r) return;
    if (r.outcome.entered) {
      write.notify(t.wsDone(picked.profile.name, r.outcome.tempHp ?? 0), { undo: () => write.restore(r.before) });
    } else {
      write.notify(t.wsNoUses, { tone: 'error' });
    }
  };

  const list = (
    <div role="radiogroup" aria-label={t.wsPickLabel} className="flex max-h-[420px] flex-col gap-2 overflow-y-auto pr-1">
      {forms.map((f) => (
        <div key={f.id} className="flex min-w-0 shrink-0 items-stretch gap-1.5">
          <div className="min-w-0 flex-1">
            <Option
              id={f.id}
              selected={f.id === pick}
              title={f.profile.name}
              detail={[
                f.row.crText !== null ? t.bestiaryCr(f.row.crText) : null,
                t.wsBeastDetail(f.profile.ac, f.profile.speed ?? ''),
              ]
                .filter(Boolean)
                .join(' · ')}
              onClick={() => setPick(f.id)}
            />
          </div>
          <Button
            tone="secondary"
            className="shrink-0 lg:hidden"
            aria-label={t.wsInfo(f.profile.name)}
            title={t.wsInfo(f.profile.name)}
            onClick={() => setPeek(f.id)}
          >
            <Info size={16} aria-hidden="true" />
          </Button>
        </div>
      ))}
    </div>
  );

  return (
    <AppDialog
      open
      onOpenChange={(v) => !v && onClose()}
      title={t.wsTitle}
      icon={PawPrint}
      description={t.wsUses(left, max)}
      width={860}
      actions={[
        // Anotar formas es de la ficha propia hasta 6f3.
        ...(write.kind === 'own' ? [{ label: t.wsActionAdd, onSelect: () => navigate(wildShapeFormsHref(character.id)) }] : []),
        { label: t.cancel },
        {
          label: left > 0 ? t.wsActionGo : t.wsActionNoUses,
          primary: true,
          tone: 'gold',
          disabled: left <= 0 || !picked,
          onSelect: transform,
        },
      ]}
    >
      {peeked ? (
        <div className="flex flex-col gap-3 lg:hidden">
          <Button tone="secondary" className="self-start" onClick={() => setPeek(null)}>
            {t.wsBackToList}
          </Button>
          <CreatureProfile profile={peeked.profile} row={peeked.row} catalog={catalog} compact />
        </div>
      ) : null}
      <div className={cx('gap-4 lg:grid lg:grid-cols-[minmax(0,1fr)_340px]', peeked ? 'hidden' : 'grid')}>
        {list}
        <div className="hidden lg:block">
          {picked && <CreatureProfile profile={picked.profile} row={picked.row} catalog={catalog} compact />}
        </div>
      </div>
    </AppDialog>
  );
}
