import { useMemo, useState, type ReactNode } from 'react';
import { ArrowLeft, Info, TriangleAlert } from 'lucide-react';
import { nameOf } from '../api/catalog';
import { codexEntries } from '../codex/entries';
import { choicesView, type AbilityId, type Catalog, type CharacterJson, type ChoicesView, type SheetWarning } from '../engine';
import { useLang, useTexts } from '../i18n/context';
import type { Lang, Texts } from '../i18n/texts';
import { characterHref, choicesHref, Link, navigate, spellEditHref } from '../router';
import { AppDialog } from '../ui/AppDialog';
import { Button, ButtonLink } from '../ui/Button';
import { cx } from '../ui/cx';
import { Eyebrow } from '../ui/data';
import { MarkdownText } from '../ui/MarkdownText';
import { AppEmptyState, Notice } from '../ui/status';
import { DetailBody, Option, SearchableList, SpellPickBlock, SpellTabs, Tag, WIZARD_ASIDE, WizardFooter } from '../ui/wizard';
import type { SheetModel } from './model';
import type { SheetWriter } from './writer';

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
 * En la banda de la pestaña Personaje de la ficha propia: lo que el motor avisa
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

// ── La pantalla de elecciones ───────────────────────────────────────────────

type TabKey = 'features' | 'proficiencies' | 'spells' | 'languages' | 'origin';
const TAB_ORDER: TabKey[] = ['features', 'proficiencies', 'spells', 'languages', 'origin'];

type Focus =
  | { kind: 'feature'; groupId: string; id: string }
  | { kind: 'spell'; id: string }
  | { kind: 'lineage'; id: string }
  | null;

type Group = { count: number; chosen: string[] };

/** Qué grupos entran en la pantalla: los que al abrir tenían algo pendiente o
 *  se podían reemplazar. Se guarda esa lista y no se recalcula, para que un
 *  grupo que se completa siga a la vista: nada se mueve solo. */
function keptKeys(v: ChoicesView): Set<string> {
  const keys = new Set<string>();
  for (const g of v.features) if (g.pending > 0 || g.replaceable) keys.add(`f:${g.groupId}`);
  for (const g of v.proficiencies) if (g.pending > 0 || g.replaceable) keys.add(`p:${g.groupId}`);
  for (const g of v.spells) if (g.pending > 0 || g.replaceable) keys.add(`s:${g.groupId}`);
  if (v.languages.chosenOrigin.length < v.languages.originCount) keys.add('l:origin');
  for (const g of v.languages.slots) if (g.pending > 0) keys.add(`l:${g.groupId}`);
  const o = v.origin;
  if (o.sizes.length > 0 && o.size === null) keys.add('o:size');
  if (o.lineages.length > 0 && !o.lineages.some((l) => l.id === o.lineage)) keys.add('o:lineage');
  if (o.speciesAbilityPending) keys.add('o:species');
  for (const f of o.featAbilities) if (f.chosen === null) keys.add(`o:feat:${f.feat}`);
  return keys;
}

/** Lo que se ve de cada pestaña con el estado de ahora de la ficha. */
function layoutOf(v: ChoicesView, kept: Set<string>) {
  const o = v.origin;
  const features = v.features.filter((g) => kept.has(`f:${g.groupId}`));
  const proficiencies = v.proficiencies.filter((g) => kept.has(`p:${g.groupId}`));
  const spells = v.spells.filter((g) => kept.has(`s:${g.groupId}`));
  const langSlots = v.languages.slots.filter((g) => kept.has(`l:${g.groupId}`));
  const showOrigin = kept.has('l:origin');
  const showSize = kept.has('o:size');
  const showLineage = kept.has('o:lineage');
  // La aptitud mágica aparece también si la pide lo recién elegido (un linaje
  // que lanza conjuros): es consecuencia de un toque, no algo que se mueva solo.
  const showSpecies = kept.has('o:species') || o.speciesAbilityPending;
  const feats = o.featAbilities.filter((f) => kept.has(`o:feat:${f.feat}`) || f.chosen === null);
  const langGroups: Group[] = [
    ...(showOrigin ? [{ count: v.languages.originCount, chosen: v.languages.chosenOrigin }] : []),
    ...langSlots,
  ];
  const sum = (gs: Group[]): [number, number] => [
    gs.reduce((n, g) => n + Math.min(g.chosen.length, g.count), 0),
    gs.reduce((n, g) => n + g.count, 0),
  ];
  const left = (gs: Group[]) => gs.reduce((n, g) => n + Math.max(0, g.count - g.chosen.length), 0);
  const originMissing =
    (showSize && o.size === null ? 1 : 0) +
    (showLineage && !o.lineages.some((l) => l.id === o.lineage) ? 1 : 0) +
    (showSpecies && o.speciesAbilityPending ? 1 : 0) +
    feats.filter((f) => f.chosen === null).length;
  const tabs: Record<TabKey, { has: boolean; count?: [number, number]; left: number }> = {
    features: { has: features.length > 0, count: sum(features), left: left(features) },
    proficiencies: { has: proficiencies.length > 0, count: sum(proficiencies), left: left(proficiencies) },
    spells: { has: spells.length > 0, count: sum(spells), left: left(spells) },
    languages: { has: langGroups.length > 0, count: sum(langGroups), left: left(langGroups) },
    origin: { has: showSize || showLineage || showSpecies || feats.length > 0, left: originMissing },
  };
  return { features, proficiencies, spells, langSlots, showOrigin, showSize, showLineage, showSpecies, feats, tabs };
}

/** Elegir lo que el motor deja elegir o revisar de la ficha propia
 *  (`_resolveFeatureChoices` y compañía, de Flutter): cada toque es una
 *  acción del motor que se guarda en el momento. No hay «Guardar» ni
 *  «Deshacer»: todo se revierte tocando de nuevo. Qué opciones hay, cuántas y
 *  cuáles están bloqueadas lo dice `choicesView`; acá no hay regla. */
export function ChoicesPage({ model, write }: { model: SheetModel; write: SheetWriter }) {
  const t = useTexts();
  const view = useChoicesView(model);
  if (!view) return <Notice title={t.notFoundTitle} body={t.notFoundBody} />;
  return <ChoicesScreen model={model} write={write} view={view} />;
}

function ChoicesScreen({ model, write, view }: { model: SheetModel; write: SheetWriter; view: ChoicesView }) {
  const t = useTexts();
  const lang = useLang();
  const { character, catalog } = model;
  const [kept] = useState(() => keptKeys(view));
  const L = layoutOf(view, kept);
  const available = TAB_ORDER.filter((k) => L.tabs[k].has);
  // Arranca en `?tab=` o en la primera con algo pendiente, y de ahí en más
  // solo la mueve quien toca una pestaña.
  const [tab, setTab] = useState<TabKey | null>(() => {
    const tabs = layoutOf(view, kept).tabs;
    const first = TAB_ORDER.filter((k) => tabs[k].has);
    const asked = new URLSearchParams(window.location.search).get('tab');
    return first.find((k) => k === asked) ?? first.find((k) => tabs[k].left > 0) ?? first[0] ?? null;
  });
  const [focus, setFocus] = useState<Focus>(null);
  const [full, setFull] = useState<string | null>(null);
  const [sheetFocus, setSheetFocus] = useState<Focus>(null);
  const current: TabKey | null = tab && available.includes(tab) ? tab : (available[0] ?? null);
  const back = characterHref(character.id);

  const titles: Record<TabKey, string> = {
    features: t.chTabFeatures,
    proficiencies: t.chTabProficiencies,
    spells: t.chTabSpells,
    languages: t.chTabLanguages,
    origin: t.chTabOrigin,
  };

  // Marcar o sacar una opción de un cupo. Con el cupo lleno y la opción sin
  // marcar no se manda nada: el pie dice por qué, y el motor lo rechazaría igual.
  const pick = (
    type: 'setFeatureChoice' | 'setProficiencyChoice',
    g: Group & { groupId: string; name: string },
    id: string,
  ) => {
    const on = g.chosen.includes(id);
    if (!on && g.chosen.length >= g.count) {
      setFull(t.chFull(g.name));
      return;
    }
    setFull(null);
    write.act({ type, group: g.groupId, id, value: !on });
  };
  const pickLanguage = (group: string | null, g: Group & { name: string }, id: string) => {
    const on = g.chosen.includes(id);
    if (!on && g.chosen.length >= g.count) {
      setFull(t.chFull(g.name));
      return;
    }
    setFull(null);
    write.act({ type: 'setLanguage', group, id, value: !on });
  };
  const infoButton = (name: string, f: Focus) => (
    <Button
      tone="secondary"
      className="shrink-0 lg:hidden"
      aria-label={t.chInfo(name)}
      title={t.chInfo(name)}
      onClick={() => setSheetFocus(f)}
    >
      <Info size={16} aria-hidden="true" />
    </Button>
  );
  const counted = (g: Group): [number, number] => [Math.min(g.chosen.length, g.count), g.count];
  const heading = (name: string, [n, m]: [number, number]) => (
    <Eyebrow>
      {name} · {t.luCount(n, m)}
    </Eyebrow>
  );

  let content: ReactNode = null;
  if (current === 'features') {
    content = L.features.map((g) => (
      <div key={g.groupId} className="flex flex-col gap-3" data-group={g.groupId}>
        {heading(g.name, counted(g))}
        <SearchableList
          items={g.options}
          textOf={(o) => o.name}
          label={t.crSearchOption(g.name)}
          count={t.chOptions(g.options.length)}
          columns={2}
          multi
          height="max-h-[420px]"
        >
          {(o) => {
            const on = g.chosen.includes(o.id);
            const f: Focus = { kind: 'feature', groupId: g.groupId, id: o.id };
            return (
              <div key={o.id} className="flex min-w-0 shrink-0 items-stretch gap-1.5">
                <div className="min-w-0 flex-1">
                  <Option
                    id={o.id}
                    multi
                    selected={on}
                    disabled={!on && o.unmet !== null}
                    blocked={!on && g.chosen.length >= g.count}
                    title={o.name}
                    detail={!on && o.unmet !== null ? t.luRequires(o.unmet) : undefined}
                    trailing={o.homebrew ? <Tag>{t.homebrewTag}</Tag> : undefined}
                    onClick={() => {
                      setFocus(f);
                      pick('setFeatureChoice', g, o.id);
                    }}
                  />
                </div>
                {infoButton(o.name, f)}
              </div>
            );
          }}
        </SearchableList>
      </div>
    ));
  } else if (current === 'proficiencies') {
    content = L.proficiencies.map((g) => (
      <div key={g.groupId} className="flex flex-col gap-3" data-group={g.groupId}>
        {heading(g.name, counted(g))}
        <div className="grid gap-2 sm:grid-cols-3" role="group" aria-label={g.name}>
          {g.options.map((o) => {
            const on = g.chosen.includes(o.id);
            return (
              <Option
                key={o.id}
                id={o.id}
                multi
                selected={on}
                disabled={!on && o.locked}
                blocked={!on && !o.locked && g.chosen.length >= g.count}
                title={o.label}
                detail={!on && o.locked ? t.luAlreadyHave : undefined}
                onClick={() => pick('setProficiencyChoice', g, o.id)}
              />
            );
          })}
        </div>
      </div>
    ));
  } else if (current === 'languages') {
    const lg = view.languages;
    content = (
      <>
        <div className="flex flex-col gap-3">
          <Eyebrow>{lg.universal.label}</Eyebrow>
          <Option multi selected disabled title={lg.universal.label} detail={t.chAlways} onClick={() => undefined} />
        </div>
        {L.showOrigin && (
          <div className="flex flex-col gap-3" data-group="origin">
            {heading(t.chFromOrigin, counted({ count: lg.originCount, chosen: lg.chosenOrigin }))}
            <div className="grid gap-2 sm:grid-cols-3" role="group" aria-label={t.chFromOrigin}>
              {lg.origin.map((o) => {
                const on = lg.chosenOrigin.includes(o.id);
                return (
                  <Option
                    key={o.id}
                    id={o.id}
                    multi
                    selected={on}
                    blocked={!on && lg.chosenOrigin.length >= lg.originCount}
                    title={o.label}
                    onClick={() =>
                      pickLanguage(null, { name: t.chFromOrigin, count: lg.originCount, chosen: lg.chosenOrigin }, o.id)
                    }
                  />
                );
              })}
            </div>
          </div>
        )}
        {L.langSlots.map((g) => (
          <div key={g.groupId} className="flex flex-col gap-3" data-group={g.groupId}>
            {heading(g.name, counted(g))}
            <div className="grid gap-2 sm:grid-cols-3" role="group" aria-label={g.name}>
              {g.options.map((o) => {
                const on = g.chosen.includes(o.id);
                return (
                  <Option
                    key={o.id}
                    id={o.id}
                    multi
                    selected={on}
                    blocked={!on && g.chosen.length >= g.count}
                    title={o.label}
                    onClick={() => pickLanguage(g.groupId, g, o.id)}
                  />
                );
              })}
            </div>
          </div>
        ))}
      </>
    );
  } else if (current === 'origin') {
    const o = view.origin;
    const abilities = (
      options: { id: AbilityId; label: string }[],
      chosen: AbilityId | null,
      onPick: (id: AbilityId) => void,
      label: string,
    ) => (
      <div className="grid gap-2 sm:grid-cols-3" role="radiogroup" aria-label={label}>
        {options.map((a) => (
          <Option key={a.id} id={a.id} selected={chosen === a.id} title={a.label} onClick={() => onPick(a.id)} />
        ))}
      </div>
    );
    content = (
      <>
        {L.showSize && (
          <div className="flex flex-col gap-3" data-group="size">
            <Eyebrow>{t.sizeLabel}</Eyebrow>
            <div className="grid gap-2 sm:grid-cols-3" role="radiogroup" aria-label={t.sizeLabel}>
              {o.sizes.map((s) => (
                <Option
                  key={s.id}
                  id={s.id}
                  selected={o.size === s.id}
                  title={s.label}
                  onClick={() => write.act({ type: 'setSize', size: s.id })}
                />
              ))}
            </div>
          </div>
        )}
        {L.showLineage && (
          <div className="flex flex-col gap-3" data-group="lineage">
            <Eyebrow>{t.chLineageOf(nameOf(catalog.races, character.raceId) ?? '')}</Eyebrow>
            <div className="flex flex-col gap-2" role="radiogroup">
              {o.lineages.map((l) => {
                const f: Focus = { kind: 'lineage', id: l.id };
                return (
                  <div key={l.id} className="flex min-w-0 items-stretch gap-1.5">
                    <div className="min-w-0 flex-1">
                      <Option
                        id={l.id}
                        selected={o.lineage === l.id}
                        title={l.name}
                        onClick={() => {
                          setFocus(f);
                          write.act({ type: 'setLineage', lineage: l.id });
                        }}
                      />
                    </div>
                    {infoButton(l.name, f)}
                  </div>
                );
              })}
            </div>
          </div>
        )}
        {L.showSpecies && (
          <div className="flex flex-col gap-3" data-group="species-ability">
            <Eyebrow>{t.chSpellAbility}</Eyebrow>
            {abilities(
              o.speciesAbilityOptions,
              o.speciesAbility,
              (id) => write.act({ type: 'setSpeciesAbility', ability: id }),
              t.chSpellAbility,
            )}
          </div>
        )}
        {L.feats.map((f) => (
          <div key={f.feat} className="flex flex-col gap-3" data-group={`feat-ability:${f.feat}`}>
            <Eyebrow>{t.chFeatAbility(f.name)}</Eyebrow>
            {abilities(f.options, f.chosen, (id) => write.act({ type: 'setFeatAbility', feat: f.feat, ability: id }), f.name)}
          </div>
        ))}
      </>
    );
  }

  const hasDetail = current === 'features' || current === 'origin' || current === 'spells';
  const left = current ? L.tabs[current].left : 0;
  const message = full ?? (left > 0 ? t.chLeft(left) : null);
  const dialogFocus = resolveFocus(sheetFocus, view, catalog, t, lang);

  return (
    <div className="flex min-h-full flex-col gap-4" data-page="choices">
      <header className="flex flex-col gap-1">
        <Link
          href={back}
          className="inline-flex min-h-9 items-center gap-1.5 self-start text-[13px] text-gold no-underline hover:text-on-surface"
        >
          <ArrowLeft size={14} aria-hidden="true" />
          {t.chBack}
        </Link>
        <h1 className="font-display text-[24px] text-on-surface">{t.chTitle}</h1>
      </header>

      {current === null ? (
        <AppEmptyState kind="empty" message={t.chEmpty} />
      ) : (
        <div className={cx('grid items-start gap-4', hasDetail && 'lg:grid-cols-[minmax(0,1fr)_360px]')}>
          <div className="flex min-w-0 flex-col gap-4">
            <section className="card flex min-w-0 flex-col gap-3 p-4">
              <SpellTabs
                label={t.chTabsLabel}
                t={t}
                current={current}
                onSelect={(k) => {
                  setTab(k as TabKey);
                  setFull(null);
                }}
                tabs={available.map((k) => ({
                  key: k,
                  title: titles[k],
                  ready: L.tabs[k].left === 0,
                  count: L.tabs[k].count,
                  label: k === 'origin' && L.tabs[k].left > 0 ? t.chMissing(L.tabs[k].left) : undefined,
                }))}
              />
              {current !== 'spells' && content}
            </section>
            {current === 'spells' &&
              L.spells.map((g) => (
                <SpellPickBlock
                  key={g.groupId}
                  title={g.name}
                  note={g.grantsSpells ? undefined : t.chKnownSpellHint}
                  options={g.options}
                  chosen={g.chosen}
                  cap={g.count}
                  ready={g.pending === 0}
                  t={t}
                  onChange={(ids, touched) => {
                    setFull(null);
                    write.act({ type: 'setSpellChoice', group: g.groupId, id: touched, value: ids.includes(touched) });
                  }}
                  onFocus={(id) => setFocus({ kind: 'spell', id })}
                />
              ))}
          </div>
          {hasDetail && (
            <aside className={cx(WIZARD_ASIDE, 'max-lg:hidden')}>
              <section className="card flex flex-col gap-2.5 p-4" aria-live="polite" data-field="choices-detail">
                <FocusDetail focus={focus} view={view} catalog={catalog} lang={lang} />
              </section>
            </aside>
          )}
        </div>
      )}

      <WizardFooter message={message}>
        <ButtonLink href={back} internal className="flex-1 sm:flex-none">
          {t.chDone}
        </ButtonLink>
      </WizardFooter>

      {dialogFocus && (
        <AppDialog open onOpenChange={(v) => !v && setSheetFocus(null)} title={dialogFocus.title} actions={[{ label: t.close }]}>
          <FocusDetail focus={sheetFocus} view={view} catalog={catalog} lang={lang} bare />
        </AppDialog>
      )}
    </div>
  );
}

/** Lo último que se tocó, resuelto contra la ficha de ahora. Un conjuro se
 *  describe con la misma ficha del Códice (`codexEntries`): armarla dos veces
 *  dejaría dos versiones. */
function resolveFocus(focus: Focus, view: ChoicesView, catalog: Catalog, t: Texts, lang: Lang) {
  if (!focus) return null;
  if (focus.kind === 'feature') {
    const o = view.features.find((g) => g.groupId === focus.groupId)?.options.find((x) => x.id === focus.id);
    return o
      ? { title: o.name, meta: o.unmet ? t.luRequires(o.unmet) : null, body: o.description, homebrew: o.homebrew, detail: null }
      : null;
  }
  if (focus.kind === 'lineage') {
    const l = view.origin.lineages.find((x) => x.id === focus.id);
    return l ? { title: l.name, meta: null, body: l.description, homebrew: false, detail: null } : null;
  }
  const entry = codexEntries('spells', catalog, t, lang).find((e) => e.id === focus.id);
  return entry
    ? { title: entry.name, meta: entry.subtitle || null, body: null, homebrew: false, detail: entry.detail() }
    : null;
}

function FocusDetail({
  focus,
  view,
  catalog,
  lang,
  bare = false,
}: {
  focus: Focus;
  view: ChoicesView;
  catalog: Catalog;
  lang: Lang;
  /** Sin título: el diálogo ya lo lleva. */
  bare?: boolean;
}) {
  const t = useTexts();
  const r = resolveFocus(focus, view, catalog, t, lang);
  if (!r) return <p className="text-[13px] text-text-muted">{t.luDetailEmpty}</p>;
  return (
    <>
      {!bare && (
        <div className="flex items-center justify-between gap-2.5">
          <h2 className="font-display text-[18px] text-on-surface">{r.title}</h2>
          {r.homebrew && <Tag>{t.homebrewTag}</Tag>}
        </div>
      )}
      {r.meta && <p className="text-[12.5px] text-crimson">{r.meta}</p>}
      {r.detail && <DetailBody detail={r.detail} />}
      {r.body && (
        <div className="text-[13.5px]">
          <MarkdownText text={r.body} />
        </div>
      )}
    </>
  );
}
