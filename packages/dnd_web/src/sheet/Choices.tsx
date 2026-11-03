import { useMemo, useState } from 'react';
import { TriangleAlert } from 'lucide-react';
import { choicesView, type CharacterJson, type ChoicesView, type SheetWarning } from '../engine';
import { useTexts } from '../i18n/context';
import { characterHref, choicesHref, navigate, spellEditHref } from '../router';
import { AppDialog } from '../ui/AppDialog';
import { Button } from '../ui/Button';
import { cx } from '../ui/cx';
import type { SheetModel } from './model';

/** Lo que el motor deja elegir o revisar de la ficha: sus avisos y sus cupos.
 *  Se recalcula con cada cambio del personaje; no hay regla acá. */
export function useChoicesView(model: SheetModel): ChoicesView | null {
  const raw = model.character as unknown as CharacterJson;
  const own = model.write !== undefined;
  return useMemo(() => (own ? choicesView(raw, model.catalog) : null), [own, raw, model.catalog]);
}

/**
 * A dónde lleva «Resolver» cada aviso, o `null` si no hay nada que abrir.
 *
 * El mapa vive en la pantalla y no en el motor, igual que `_resolverFor` de
 * Flutter: `code` ya es el identificador estable —lo fijan los tests del
 * motor— y agregarle un campo sería un segundo identificador paralelo, con el
 * motor opinando sobre pantallas que no conoce. Un código nuevo no trae botón
 * hasta que se le escriba uno. Los avisos de subclase, mejora de nivel y
 * habilidades de clase tampoco lo tienen: en Flutter tampoco.
 */
function destinationOf(code: string, model: SheetModel, view: ChoicesView): string | null {
  const id = model.character.id;
  const tab = (name: string) => choicesHref(id, name);
  switch (code) {
    case 'size_pending':
    case 'size_invalid':
    case 'species_spellcasting_ability_pending':
    case 'feat_spellcasting_ability_pending':
      return tab('origin');
    // Un linaje ausente, inexistente o de otra especie se arregla igual:
    // eligiendo uno válido. Si la especie no ofrece ninguno no hay qué elegir.
    case 'lineage_pending':
    case 'lineage_missing':
    case 'lineage_wrong_race':
      return view.origin.lineages.length > 0 ? tab('origin') : null;
    case 'feature_choice_pending':
      return tab('features');
    case 'spell_choice_pending':
      return tab('spells');
    // Los del origen y los que deja elegir un rasgo se arreglan en el mismo
    // lugar: para el jugador son lo mismo, qué habla su personaje.
    case 'language_choice_pending':
    case 'language_choice_pending_feature':
    case 'too_many_languages':
    case 'language_duplicate':
    case 'language_universal_chosen':
    case 'language_not_standard':
      return tab('languages');
    // El mismo código sale cuando sobran competencias sin rasgo que las
    // conceda: ahí no hay nada que elegir y la pantalla saldría vacía.
    case 'proficiency_choice_count':
      return view.proficiencies.length > 0 ? tab('proficiencies') : null;
    case 'cantrips_pending':
    case 'prepared_pending':
    case 'too_many_cantrips':
    case 'too_many_prepared':
      return spellEditHref(id, model.character.classId);
    // La mochila no se arregla con un diálogo: hay que decidir qué se suelta o
    // qué se desintoniza mirando la lista entera.
    case 'encumbered':
    case 'attunement_over_limit':
      return characterHref(id, 'inventario');
    default:
      return null;
  }
}

/** Los `warning` primero y, dentro de cada gravedad, el orden del motor. */
const bySeverity = (warnings: SheetWarning[]): SheetWarning[] => [
  ...warnings.filter((w) => w.severity === 'warning'),
  ...warnings.filter((w) => w.severity !== 'warning'),
];

/**
 * Arriba de la pestaña Personaje de la ficha propia: lo que el motor avisa
 * (`CharacterValidator`) en una sola franja, y «Revisar» abre el detalle. Con
 * algún `warning` va en carmesí; con solo `info` —cosas por elegir, no una
 * ficha rota— en oro, para que una elección pendiente no parezca un error.
 * Sin avisos no se muestra.
 */
export function WarningsStrip({ model, view }: { model: SheetModel; view: ChoicesView }) {
  const t = useTexts();
  const [open, setOpen] = useState(false);
  const warnings = bySeverity(view.warnings);
  if (warnings.length === 0) return null;
  const serious = warnings.filter((w) => w.severity === 'warning').length;
  const title = serious > 0 ? t.chReviewCount(warnings.length) : t.chPendingCount(warnings.length);
  return (
    <>
      <button
        type="button"
        data-action="review-warnings"
        onClick={() => setOpen(true)}
        className={cx(
          'plaque flex min-h-[60px] w-full cursor-pointer items-center gap-3.5 px-4 py-2.5 text-left font-[family-name:var(--font-body)]',
          serious > 0 ? '!border-crimson' : '!border-gold',
        )}
      >
        <TriangleAlert size={22} aria-hidden="true" className={cx('shrink-0', serious > 0 ? 'text-crimson' : 'text-gold')} />
        <span className="flex min-w-0 flex-1 flex-col gap-0.5">
          <span className="text-[15px] font-semibold text-on-surface">{title}</span>
          {serious > 0 && <span className="text-[12.5px] text-on-surface-variant">{t.chReviewDetail(serious)}</span>}
        </span>
        <span className={cx('text-right text-[13px] font-semibold', serious > 0 ? 'text-crimson' : 'text-gold')}>
          {t.chReview}
        </span>
      </button>
      {open && <WarningsDialog model={model} view={view} warnings={warnings} title={title} onClose={() => setOpen(false)} />}
    </>
  );
}

function WarningsDialog({
  model,
  view,
  warnings,
  title,
  onClose,
}: {
  model: SheetModel;
  view: ChoicesView;
  warnings: SheetWarning[];
  title: string;
  onClose: () => void;
}) {
  const t = useTexts();
  return (
    <AppDialog open onOpenChange={(v) => !v && onClose()} title={title} width={640} actions={[{ label: t.close }]}>
      <ul className="flex flex-col divide-y divide-hairline">
        {warnings.map((w, i) => {
          const href = destinationOf(w.code, model, view);
          return (
            <li key={`${w.code}-${i}`} className="flex items-start gap-3 py-2.5">
              <span
                aria-hidden="true"
                className={cx('mt-[7px] h-2 w-2 shrink-0 rounded-full', w.severity === 'warning' ? 'bg-crimson' : 'bg-gold')}
              />
              <span className="min-w-0 flex-1 text-[14px] text-on-surface">{w.message}</span>
              {href && (
                <Button
                  tone="secondary"
                  data-resolve={w.code}
                  className="shrink-0"
                  onClick={() => {
                    onClose();
                    navigate(href);
                  }}
                >
                  {t.chResolve}
                </Button>
              )}
            </li>
          );
        })}
      </ul>
    </AppDialog>
  );
}

/** «Cambiar elecciones» en la tarjeta Identidad: lo ya elegido que el juego
 *  deja cambiar (`replaceable` del motor), aunque no quede nada pendiente. */
export function ChangeChoicesButton({ id }: { id: string }) {
  const t = useTexts();
  return (
    <Button tone="secondary" data-action="change-choices" onClick={() => navigate(choicesHref(id))}>
      {t.chChangeChoices}
    </Button>
  );
}
