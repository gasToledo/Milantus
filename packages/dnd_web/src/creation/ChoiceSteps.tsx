import { useMemo, useState } from 'react';
import { Minus, Plus, Trash2 } from 'lucide-react';
import { nameOf } from '../api/catalog';
import { codexEntries } from '../codex/entries';
import {
  formatAmount,
  formatCost,
  type AbilityId,
  type Catalog,
  type CreationAction,
  type CreationView,
} from '../engine';
import type { Lang, Texts } from '../i18n/texts';
import { signed } from '../sheet/format';
import { catalogRows, coinLabels, FamilyFilter, type CatalogRow, type Family } from '../sheet/ItemCatalog';
import { Button } from '../ui/Button';
import { Block, Option, SearchableList, SpellPickBlock, Status } from '../ui/wizard';

/** Lo que explica el panel de la derecha: lo último que se tocó. */
export type Focus = {
  kind: 'race' | 'lineage' | 'class' | 'background' | 'feat' | 'weapon' | 'ability' | 'skill' | 'spell' | 'item';
  id: string;
} | null;

export interface StepProps {
  t: Texts;
  lang: Lang;
  catalog: Catalog;
  view: CreationView;
  act: (action: CreationAction) => void;
  setFocus: (f: Focus) => void;
}

/** Competencias: habilidades de clase y de especie, la dote del Humano, lo que
 *  pide una dote, Pericia e idiomas. Qué se puede tomar lo dice el motor. */
export function ProficienciesStep({ t, lang, catalog, view, act, setFocus }: StepProps) {
  const d = view.draft;
  const p = view.proficiencies;
  const classSkills = d.classSkills ?? [];
  const raceSkills = d.raceSkills ?? [];
  const languages = d.languages ?? [];
  const feats = useMemo(() => codexEntries('feats', catalog, t, lang), [catalog, t, lang]);
  const subtitleOf = (id: string) => feats.find((f) => f.id === id)?.subtitle;

  const skillBlock = (
    title: string,
    block: CreationView['proficiencies']['classSkills'],
    chosen: string[],
    pick: 'classSkill' | 'speciesSkill',
    prefix: string,
  ) => {
    const single = block.count === 1;
    const full = chosen.length >= block.count;
    return (
      <Block
        title={title}
        status={<Status ready={full} count={single ? undefined : [chosen.length, block.count]} t={t} />}
      >
        <div className="grid gap-2 sm:grid-cols-3" role={single ? 'radiogroup' : 'group'} aria-label={title}>
          {block.options.map((o) => {
            const on = chosen.includes(o.id);
            return (
              <Option
                key={o.id}
                id={`${prefix}-${o.id}`}
                multi={!single}
                selected={on}
                disabled={!on && (o.taken || (full && !single))}
                title={o.label}
                detail={
                  !on && o.taken
                    ? t.crTakenElsewhere
                    : `${o.ability ? t.abilityAbbr[o.ability as AbilityId] : ''} · ${signed(o.base)} → ${signed(o.withProficiency)}`
                }
                onClick={() => {
                  act({ type: 'toggle', pick, id: o.id });
                  setFocus({ kind: 'skill', id: o.id });
                }}
              />
            );
          })}
        </div>
      </Block>
    );
  };

  return (
    <>
      {p.classSkills.count > 0 && skillBlock(t.crClassSkills, p.classSkills, classSkills, 'classSkill', 'class')}
      {p.speciesSkills.options.length > 0 &&
        skillBlock(t.crSpeciesSkills, p.speciesSkills, raceSkills, 'speciesSkill', 'species')}

      {p.grantsOriginFeat && (
        <Block title={t.codexOriginFeat} status={<Status ready={!!d.raceFeatId} t={t} />}>
          <SearchableList
            items={p.originFeats}
            textOf={(f) => f.name}
            label={t.crSearchOption(t.codexOriginFeat)}
            columns={2}
          >
            {(f) => (
              <Option
                key={f.id}
                id={f.id}
                selected={d.raceFeatId === f.id}
                title={f.name}
                detail={subtitleOf(f.id)}
                onClick={() => {
                  act({ type: 'toggleRaceFeat', id: f.id });
                  setFocus({ kind: 'feat', id: f.id });
                }}
              />
            )}
          </SearchableList>
        </Block>
      )}

      {p.slots.map((slot) => {
        const single = slot.count === 1;
        const full = slot.chosen.length >= slot.count;
        return (
          <Block
            key={slot.groupId}
            title={slot.expertise ? `${t.crExpertise} · ${slot.name}` : slot.name}
            status={<Status ready={full} count={single ? undefined : [slot.chosen.length, slot.count]} t={t} />}
          >
            <div className="grid gap-2 sm:grid-cols-3" role={single ? 'radiogroup' : 'group'} aria-label={slot.name}>
              {slot.options.map((o) => {
                const on = slot.chosen.includes(o.id);
                return (
                  <Option
                    key={o.id}
                    id={`prof-${o.id}`}
                    multi={!single}
                    selected={on}
                    disabled={!on && (o.taken || (full && !single))}
                    title={o.label}
                    detail={!on && o.taken ? t.luAlreadyHave : undefined}
                    onClick={() => act({ type: 'toggle', pick: 'proficiency', id: o.id, group: slot.groupId })}
                  />
                );
              })}
            </div>
          </Block>
        );
      })}

      <Block
        title={t.crLanguages}
        status={<Status ready={languages.length >= p.languages.count} count={[languages.length, p.languages.count]} t={t} />}
      >
        <div className="grid gap-2 sm:grid-cols-3" role="group" aria-label={t.crLanguages}>
          <Option multi selected disabled title={p.languages.universal} detail={t.crKnownByAll} onClick={() => undefined} />
          {p.languages.options.map((l) => {
            const on = languages.includes(l.id);
            return (
              <Option
                key={l.id}
                id={`lang-${l.id}`}
                multi
                selected={on}
                disabled={!on && languages.length >= p.languages.count}
                title={l.label}
                onClick={() => act({ type: 'toggle', pick: 'language', id: l.id })}
              />
            );
          })}
        </div>
      </Block>

      {p.languageSlots.map((slot) => {
        const full = slot.chosen.length >= slot.count;
        return (
          <Block key={slot.groupId} title={slot.name} status={<Status ready={full} count={[slot.chosen.length, slot.count]} t={t} />}>
            <div className="grid gap-2 sm:grid-cols-3" role="group" aria-label={slot.name}>
              {slot.options.map((l) => {
                const on = slot.chosen.includes(l.id);
                return (
                  <Option
                    key={l.id}
                    id={`lang-${l.id}`}
                    multi
                    selected={on}
                    disabled={!on && full}
                    title={l.label}
                    onClick={() => act({ type: 'toggle', pick: 'featureLanguage', id: l.id, group: slot.groupId })}
                  />
                );
              })}
            </div>
          </Block>
        );
      })}

      {(p.backgroundSkills.length > 0 || p.backgroundTools.length > 0) && (
        <Block title={t.crFromBackground} status={<Status auto t={t} />}>
          <p className="text-[13px] text-on-surface-variant">{[...p.backgroundSkills, ...p.backgroundTools].join(' · ')}</p>
        </Block>
      )}
    </>
  );
}

/** Conjuros: primero los que da un rasgo o una dote, que quedan preparados y
 *  salen del pozo de abajo; preguntarlo después haría preparar uno que se está
 *  por recibir gratis. */
export function SpellsStep({ t, view, act, setFocus }: StepProps) {
  const { slots, class: cs } = view.spells;
  const focus = (id: string) => setFocus({ kind: 'spell', id });
  const missingSpells = view.pending.some((p) => p.kind === 'spells');
  const granted = cs ? [...cs.grantedCantrips, ...cs.grantedSpells] : [];
  return (
    <>
      {slots.map((slot) => (
        <SpellPickBlock
          key={slot.groupId}
          title={slot.name}
          options={slot.options}
          chosen={slot.chosen}
          cap={slot.count}
          ready={slot.chosen.length >= slot.count}
          t={t}
          onChange={(_, id) => act({ type: 'toggle', pick: 'featureSpell', id, group: slot.groupId })}
          onFocus={focus}
        />
      ))}
      {cs && cs.cantripsKnown > 0 && (
        <SpellPickBlock
          title={t.luCantripsTitle}
          options={cs.cantrips}
          chosen={cs.chosenCantrips}
          cap={cs.cantripsKnown}
          ready={cs.chosenCantrips.length >= cs.cantripsKnown}
          t={t}
          onChange={(_, id) => act({ type: 'toggle', pick: 'cantrip', id })}
          onFocus={focus}
        />
      )}
      {cs && (
        <SpellPickBlock
          title={cs.prepared ? t.luPreparedTitle : t.luKnownTitle}
          options={cs.spells}
          chosen={cs.chosenSpells}
          // Un lanzador que prepara tiene tope; el que conoce, no (como en
          // Flutter): lo que falta lo cuenta el motor.
          cap={cs.prepared ? cs.preparedCount : null}
          ready={!missingSpells}
          t={t}
          onChange={(_, id) => act({ type: 'toggle', pick: 'spell', id })}
          onFocus={focus}
        />
      )}
      {granted.length > 0 && (
        <Block title={t.crGrantedSpells} status={<Status auto t={t} />}>
          <p className="text-[13px] text-on-surface-variant">{granted.join(' · ')}</p>
        </Block>
      )}
    </>
  );
}

type PackageOption = CreationView['equipment']['classOptions'][number];

/** Equipo: los paquetes, lo que se compra con su oro y lo que se lleva puesto.
 *  Lo comprado se paga al crear el personaje: hasta entonces se puede rehacer. */
export function EquipmentStep({ t, lang, catalog, view, act, setFocus }: StepProps) {
  const [shopping, setShopping] = useState(false);
  const e = view.equipment;
  const d = view.draft;
  const labels = coinLabels(t);
  const className = nameOf(catalog.classes, d.classId);
  const backgroundName = nameOf(catalog.backgrounds, d.backgroundId);

  if (shopping) {
    return <ShopBlock t={t} lang={lang} catalog={catalog} view={view} act={act} setFocus={setFocus} onDone={() => setShopping(false)} />;
  }

  /** Cada opción dice qué trae: «Opción A» a secas obligaba a elegir a ciegas. */
  const contents = (o: PackageOption) =>
    [
      ...o.items.map((i) => (i.quantity > 1 ? `${i.name} ×${i.quantity}` : i.name)),
      ...o.choices.map((names) =>
        names.length <= 3 ? names.join(` ${t.wordOr} `) : `${names.slice(0, 2).join(', ')} ${t.crOrOther}`,
      ),
      ...Object.entries(o.coins).map(([coin, n]) => `${n} ${labels[coin] ?? coin}`),
    ].join(' · ');

  const packages = (title: string, options: PackageOption[], selected: string | null | undefined, type: 'setClassEquipment' | 'setBackgroundEquipment', prefix: string) =>
    options.length > 0 && (
      <Block title={title} status={<Status ready={!!selected} t={t} />}>
        <div className="flex flex-col gap-2" role="radiogroup" aria-label={title}>
          {options.map((o) => (
            <Option
              key={o.id}
              id={`${prefix}-${o.id}`}
              selected={selected === o.id}
              title={o.label}
              detail={contents(o)}
              onClick={() => act({ type, id: o.id })}
            />
          ))}
        </div>
      </Block>
    );

  const canBuy = e.grantedCp > 0 || e.purchases.length > 0;
  return (
    <>
      <div className="grid items-start gap-4 xl:grid-cols-2">
        {packages(t.crEquipmentOf(className ?? ''), e.classOptions, d.classEquipmentOptionId, 'setClassEquipment', 'class-pack')}
        {packages(t.crEquipmentOf(backgroundName ?? ''), e.backgroundOptions, d.backgroundEquipmentOptionId, 'setBackgroundEquipment', 'background-pack')}
      </div>

      {e.choices.map((c) => (
        <Block
          key={c.key}
          title={c.fromClass ? t.crPickClassItem : t.crPickBackgroundItem}
          status={<Status ready={!!c.chosen} t={t} />}
        >
          <div className="grid gap-2 sm:grid-cols-2" role="radiogroup">
            {c.options.map((o) => (
              <Option
                key={o.id}
                id={`choice-${o.id}`}
                selected={c.chosen === o.id}
                title={o.name}
                onClick={() => {
                  act({ type: 'setEquipmentChoice', key: c.key, id: o.id });
                  setFocus({ kind: 'item', id: o.id });
                }}
              />
            ))}
          </div>
        </Block>
      ))}

      <Block
        title={t.crPurchases}
        status={
          canBuy ? (
            <span className="num text-[13px] font-bold tabular-nums" data-field="gold-left">
              {e.goldLeftCp < 0
                ? t.crShort(formatAmount(-e.goldLeftCp, labels))
                : t.crGoldLeft(formatAmount(e.goldLeftCp, labels), formatAmount(e.grantedCp, labels))}
            </span>
          ) : undefined
        }
      >
        {!canBuy ? (
          <p className="text-[13px] text-on-surface-variant">{t.crPickPackFirst}</p>
        ) : (
          <>
            {e.purchases.length > 0 && (
              <ul className="plaque divide-y divide-hairline px-3.5" data-field="purchases">
                {e.purchases.map((p) => (
                  <li key={p.id} className="flex flex-wrap items-center gap-2.5 py-2" data-item={p.id}>
                    <span className="min-w-0 flex-[1_1_160px]">
                      <span className="block font-medium">{p.name}</span>
                      <span className="block text-[12.5px] text-on-surface-variant">
                        {p.bundleSize > 1
                          ? t.crCostPerBundle(formatCost(p.unitCp, labels), p.bundleSize)
                          : t.crCostEach(formatCost(p.unitCp, labels))}
                      </span>
                    </span>
                    <Button
                      tone="secondary"
                      aria-label={t.crOneLess(p.name)}
                      title={t.crOneLess(p.name)}
                      disabled={p.quantity <= 1}
                      onClick={() => act({ type: 'setPurchase', id: p.id, quantity: p.quantity - 1 })}
                    >
                      <Minus size={16} aria-hidden="true" />
                    </Button>
                    <span className="num w-6 text-center font-bold tabular-nums">{p.quantity}</span>
                    <Button
                      tone="secondary"
                      aria-label={t.crOneMore(p.name)}
                      title={t.crOneMore(p.name)}
                      onClick={() => act({ type: 'setPurchase', id: p.id, quantity: p.quantity + 1 })}
                    >
                      <Plus size={16} aria-hidden="true" />
                    </Button>
                    <Button
                      tone="secondary"
                      aria-label={t.crRemovePurchase(p.name)}
                      title={t.crRemovePurchase(p.name)}
                      onClick={() => act({ type: 'setPurchase', id: p.id, quantity: 0 })}
                    >
                      <Trash2 size={16} aria-hidden="true" />
                    </Button>
                  </li>
                ))}
              </ul>
            )}
            <div>
              <Button tone="secondary" icon={Plus} onClick={() => setShopping(true)}>
                {t.crBuyFromCatalog}
              </Button>
            </div>
          </>
        )}
      </Block>

      {(e.armor.length > 0 || e.weapons.length > 0) && (
        <Block title={t.crWorn}>
          <div className="grid gap-2 sm:grid-cols-3" role="group" aria-label={t.crWorn}>
            {e.armor.map((a) => (
              <Option
                key={a.id}
                id={`worn-${a.id}`}
                multi
                selected={a.worn}
                title={a.name}
                onClick={() => {
                  act({ type: 'setArmorWorn', id: a.id, on: !a.worn });
                  setFocus({ kind: 'item', id: a.id });
                }}
              />
            ))}
            {e.weapons.map((w) => (
              <Option
                key={w.id}
                id={`worn-${w.id}`}
                multi
                selected={w.wielded}
                title={w.name}
                onClick={() => {
                  act({ type: 'setWeaponWielded', id: w.id, on: !w.wielded });
                  setFocus({ kind: 'item', id: w.id });
                }}
              />
            ))}
          </div>
          {e.grips.length > 0 && (
            <div className="grid gap-2 sm:grid-cols-3" role="group" aria-label={t.crGrip}>
              {e.grips.flatMap((g) => [
                ...(g.canOffHand
                  ? [
                      <Option
                        key={`off-${g.id}`}
                        id={`off-${g.id}`}
                        multi
                        selected={g.offHand}
                        title={t.crOffHand(g.name)}
                        onClick={() => act({ type: 'setOffHand', id: g.id, on: !g.offHand })}
                      />,
                    ]
                  : []),
                ...(g.canTwoHanded
                  ? [
                      <Option
                        key={`two-${g.id}`}
                        id={`two-${g.id}`}
                        multi
                        selected={g.twoHanded}
                        title={t.crTwoHanded(g.name)}
                        onClick={() => act({ type: 'setTwoHanded', id: g.id, on: !g.twoHanded })}
                      />,
                    ]
                  : []),
              ])}
            </div>
          )}
        </Block>
      )}
    </>
  );
}

/** El catálogo de compras, en el lugar del paso: se arma el equipo entero sin
 *  volver a abrirlo y el panel derecho sigue explicando lo que se toca. Sin
 *  objetos mágicos, como en Flutter, y al precio del manual: todavía no hay DM
 *  con quien regatear. */
function ShopBlock({ t, lang, catalog, view, act, setFocus, onDone }: StepProps & { onDone: () => void }) {
  const labels = coinLabels(t);
  const rows = useMemo(() => catalogRows(catalog, t, lang).filter((r) => r.family !== 'magic'), [catalog, t, lang]);
  const [family, setFamily] = useState<Family | 'all'>('all');
  const left = view.equipment.goldLeftCp;
  const bought = (id: string) => view.equipment.purchases.find((p) => p.id === id)?.quantity ?? 0;
  const visible = family === 'all' ? rows : rows.filter((r) => r.family === family);
  return (
    <Block
      title={t.crCatalog}
      status={
        <span className="num text-[13px] font-bold tabular-nums" data-field="gold-left">
          {t.crGoldLeft(formatAmount(Math.max(left, 0), labels), formatAmount(view.equipment.grantedCp, labels))}
        </span>
      }
    >
      <FamilyFilter rows={rows} family={family} onChange={setFamily} label={t.crCatalog} t={t} />
      <SearchableList
        items={visible}
        textOf={(r: CatalogRow) => `${r.name} ${r.detail}`}
        label={t.catalogSearchHint}
        count={t.crCountItems(visible.length)}
        multi
        height="max-h-[420px]"
      >
        {(r: CatalogRow) => {
          const missing = r.costCp - left;
          const n = bought(r.id);
          return (
            <div key={r.id} className="flex flex-wrap items-center gap-x-3 gap-y-1 border-b border-hairline py-2 last:border-b-0" data-item={r.id}>
              <button
                type="button"
                className="min-w-0 flex-[1_1_180px] text-left hover:text-gold"
                onClick={() => setFocus({ kind: 'item', id: r.id })}
              >
                <span className="block text-[14px] text-on-surface">{r.name}</span>
                <span className="block text-[12.5px] text-on-surface-variant">
                  {[r.detail, n > 0 ? t.crInPurchases(n) : null].filter(Boolean).join(' · ')}
                </span>
              </button>
              <span className="w-16 text-right text-[12.5px] text-gold tabular-nums">{formatCost(r.costCp, labels)}</span>
              <Button
                tone="soft"
                aria-label={t.catalogBuyLabel(r.name)}
                disabled={missing > 0}
                onClick={() => {
                  act({ type: 'buy', id: r.id });
                  setFocus({ kind: 'item', id: r.id });
                }}
              >
                {missing > 0 ? t.crMissingShort(formatAmount(missing, labels)) : t.catalogBuy}
              </Button>
            </div>
          );
        }}
      </SearchableList>
      <div>
        <Button tone="secondary" onClick={onDone}>
          {t.crBackToEquipment}
        </Button>
      </div>
    </Block>
  );
}
