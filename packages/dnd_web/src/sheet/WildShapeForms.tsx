import { useMemo, useState } from 'react';
import { ArrowLeft, Info, X } from 'lucide-react';
import { asProfile, type CreatureProfile as Profile } from '../bestiary/creature';
import { CreatureProfile } from '../bestiary/CreatureProfile';
import { bestiary, type BestiaryRow } from '../engine';
import { useTexts } from '../i18n/context';
import { characterHref, Link } from '../router';
import { AppDialog } from '../ui/AppDialog';
import { Button, ButtonLink } from '../ui/Button';
import { Pill } from '../ui/data';
import { Notice } from '../ui/status';
import { Option, SearchableList, WIZARD_ASIDE, WizardFooter } from '../ui/wizard';
import type { SheetModel } from './model';
import type { SheetWriter } from './writer';

interface Beast {
  row: BestiaryRow;
  profile: Profile;
}

/**
 * Las formas anotadas de Forma Salvaje (`_editWildShapeForms` de Flutter, con
 * el circuito de los asistentes y la ruta propia de `MagicItemPlans`). Se
 * guarda al tocar: anotar o sacar una forma es la acción `setWildShapeForm`, y
 * no lleva «Deshacer» porque se revierte tocando de nuevo. Cuántas formas y de
 * qué bestias lo dice el motor (`sheet.wildShape`); acá no hay regla.
 *
 * Con el cupo lleno una bestia se ve atenuada pero responde: muestra su perfil
 * y el pie dice por qué no se anota.
 */
export function WildShapeForms({ model, write }: { model: SheetModel; write: SheetWriter }) {
  const t = useTexts();
  const { character, sheet, catalog } = model;
  const slot = sheet.wildShape;

  // Lo último que se tocó, para el panel de la derecha, y la bestia que se
  // tocó con el cupo lleno.
  const [focus, setFocus] = useState<string | null>(null);
  const [blocked, setBlocked] = useState<string | null>(null);
  const [sheetId, setSheetId] = useState<string | null>(null);

  const beasts = useMemo(() => {
    if (!slot) return [];
    const byId = new Map(catalog.creatures.map((c) => [c.id as string, c] as const));
    const rows = new Map(bestiary(catalog).map((r) => [r.id, r] as const));
    const found = slot.options.flatMap((o): Beast[] => {
      const row = rows.get(o.id);
      const raw = byId.get(o.id);
      return row && raw ? [{ row, profile: asProfile(raw) }] : [];
    });
    // Por desafío, de menor a mayor; dentro de uno, como los trae el motor
    // (por nombre). `sort` es estable.
    return found.sort((a, b) => (a.row.cr ?? Infinity) - (b.row.cr ?? Infinity));
  }, [slot, catalog]);

  if (!slot) return <Notice title={t.notFoundTitle} body={t.notFoundBody} />;

  const byId = new Map(beasts.map((b) => [b.row.id, b] as const));
  const chosenIds = new Set(slot.chosen.map((b) => b.id));
  const full = slot.chosen.length >= slot.count;
  // Todo lo guardado, también lo que dejó de calificar: tiene que poder
  // sacarse aunque la lista ya no lo ofrezca.
  const nameOfForm = (id: string) =>
    byId.get(id)?.profile.name ?? (catalog.creatures.find((c) => c.id === id)?.name as string | undefined) ?? id;
  const saved = character.wildShapeForms ?? [];

  const set = (id: string, value: boolean) => write.act({ type: 'setWildShapeForm', creature: id, value });
  const toggle = (id: string) => {
    setFocus(id);
    if (chosenIds.has(id)) {
      setBlocked(null);
      set(id, false);
    } else if (full) {
      setBlocked(id);
    } else {
      setBlocked(null);
      set(id, true);
    }
  };

  const message =
    blocked && !chosenIds.has(blocked) ? t.wsFull(slot.chosen.length, slot.count, nameOfForm(blocked)) : null;
  const focused = focus ? byId.get(focus) : undefined;
  const sheetBeast = sheetId ? byId.get(sheetId) : undefined;
  const back = characterHref(character.id, 'combate');

  return (
    <div className="flex min-h-full flex-col gap-4" data-page="wild-shape-forms">
      <header className="flex flex-col gap-1">
        <Link
          href={back}
          className="inline-flex min-h-9 items-center gap-1.5 self-start text-[13px] text-gold no-underline hover:text-on-surface"
        >
          <ArrowLeft size={14} aria-hidden="true" />
          {t.wsBack}
        </Link>
        <div className="flex flex-wrap items-center gap-3">
          <h1 className="font-display text-[24px] text-on-surface">{t.wsFormsTitle}</h1>
          <Pill highlighted={full}>{t.luCount(slot.chosen.length, slot.count)}</Pill>
        </div>
      </header>

      <div className="grid items-start gap-4 lg:grid-cols-[minmax(0,1fr)_360px]">
        <section className="card flex min-w-0 flex-col gap-3 p-4">
          <ul aria-label={t.wsChosenLabel} className="flex min-h-9 flex-wrap items-center gap-1.5">
            {saved.length === 0 && <li className="text-[12.5px] text-on-surface-variant">{t.crNoneYet}</li>}
            {saved.map((id) => (
              <li key={id}>
                <button
                  type="button"
                  data-chip={id}
                  aria-label={t.wsRemoveForm(nameOfForm(id))}
                  onClick={() => {
                    setBlocked(null);
                    set(id, false);
                  }}
                  className="inline-flex h-9 items-center gap-1.5 rounded-[var(--radius-pill)] border border-gold bg-gold-soft pr-2 pl-3 text-[12.5px] whitespace-nowrap text-on-surface"
                >
                  {nameOfForm(id)}
                  <X size={14} strokeWidth={2.5} aria-hidden="true" className="text-gold" />
                </button>
              </li>
            ))}
          </ul>
          <SearchableList
            items={beasts}
            textOf={(b) => b.profile.name}
            label={t.wsSearch}
            count={t.wsCount(beasts.length)}
            columns={2}
            multi
            height="max-h-[396px]"
            groupOf={(b) => (b.row.crText !== null ? t.bestiaryCr(b.row.crText) : '')}
          >
            {(b) => {
              const on = chosenIds.has(b.row.id);
              return (
                <div key={b.row.id} className="flex min-w-0 shrink-0 items-stretch gap-1.5">
                  <div className="min-w-0 flex-1">
                    <Option
                      id={b.row.id}
                      multi
                      selected={on}
                      blocked={!on && full}
                      title={b.profile.name}
                      detail={t.wsBeastDetail(b.profile.ac, b.profile.speed ?? '')}
                      onClick={() => toggle(b.row.id)}
                    />
                  </div>
                  <Button
                    tone="secondary"
                    className="shrink-0 lg:hidden"
                    aria-label={t.wsInfo(b.profile.name)}
                    title={t.wsInfo(b.profile.name)}
                    onClick={() => setSheetId(b.row.id)}
                  >
                    <Info size={16} aria-hidden="true" />
                  </Button>
                </div>
              );
            }}
          </SearchableList>
        </section>

        <aside className={WIZARD_ASIDE}>
          {focused && (
            <section className="card p-4">
              <CreatureProfile profile={focused.profile} row={focused.row} catalog={catalog} compact />
            </section>
          )}
        </aside>
      </div>

      <WizardFooter message={message}>
        <ButtonLink href={back} internal className="flex-1 sm:flex-none">
          {t.wsReady}
        </ButtonLink>
      </WizardFooter>

      {sheetBeast && (
        <AppDialog
          open
          onOpenChange={(v) => !v && setSheetId(null)}
          title={sheetBeast.profile.name}
          actions={[{ label: t.close }]}
        >
          <CreatureProfile profile={sheetBeast.profile} row={sheetBeast.row} catalog={catalog} compact />
        </AppDialog>
      )}
    </div>
  );
}
