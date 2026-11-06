import { useState, type ReactNode } from 'react';
import { ArrowDown, ArrowUp, CirclePlus, X } from 'lucide-react';
import type { EncounterAction } from '../../engine';
import { useLang, useTexts } from '../../i18n/context';
import { AppDialog } from '../../ui/AppDialog';
import { cx } from '../../ui/cx';
import { Eyebrow, SectionRule } from '../../ui/data';
import { Tooltip } from '../../ui/primitives';
import { conditionOfTag, storedLabel } from './conditions';

type Advantage = 'advantage' | 'disadvantage' | null;

/** Lo que el diálogo necesita saber del combatiente. */
export interface EffectsTarget {
  id: string;
  name: string;
  tags: string[];
  advantage: Advantage;
  tempHp: number;
  acBonus: number;
  /** Los PG temporales de un jugador son los de su ficha: se muestran, no se
   *  escriben (el DM no escribe la ficha de otra cuenta). `undefined` si no es
   *  un jugador. */
  playerTemp?: number;
  /** Un PNJ sin estadísticas no tiene PG: la columna de temporales no va. */
  hasHp: boolean;
  /** La CA tal como la imprime el perfil. */
  ac: string | null;
}

const digits = (v: string) => v.replace(/\D/g, '').slice(0, 3);
const fieldClass = 'h-[38px] w-16 rounded-[8px] border border-hairline bg-plaque text-center text-[14px] text-on-surface';
const chipClass = 'min-h-[30px] min-w-[34px] rounded-[var(--radius-pill)] border border-hairline px-[9px] text-[12.5px] text-on-surface';

/**
 * Efectos y defensas de un combatiente (lámina «Efectos y defensas»): ventaja o
 * desventaja, PG temporales, bono a la CA y los efectos escritos o del libro
 * (`combatant_tags_dialog.dart`). Es un borrador local: **Guardar** manda solo lo
 * que cambió, en este orden (`setAdvantage`, `setTempHp`, `setAcBonus`,
 * `setTags`); Cancelar no manda nada.
 *
 * Todo esto es del DM y no le llega al jugador. Los PG temporales de un jugador
 * se leen de su ficha y no se escriben acá.
 */
export function EffectsDialog({
  target,
  previewAc,
  act,
  onClose,
}: {
  target: EffectsTarget;
  /** La CA con ese bono, calculada por el motor sin guardar nada. La pantalla no
   *  suma: el total es una regla. */
  previewAc: (bonus: number) => number | null;
  act: (a: EncounterAction) => void;
  onClose: () => void;
}) {
  const t = useTexts();
  const lang = useLang();
  const [advantage, setAdvantage] = useState<Advantage>(target.advantage);
  const [temp, setTemp] = useState(String(target.tempHp));
  const [bonus, setBonus] = useState(String(target.acBonus));
  const [tags, setTags] = useState<string[]>(target.tags);
  const [typed, setTyped] = useState('');
  const rules = t.conditionRules as Record<string, { label: string; rule: string }>;

  const has = (id: string) => tags.some((x) => conditionOfTag(x) === id);
  const toggle = (id: string) => setTags((cur) => (cur.some((x) => conditionOfTag(x) === id) ? cur.filter((x) => conditionOfTag(x) !== id) : [...cur, storedLabel(id)]));
  const addTyped = () => {
    const text = typed.trim();
    // Escribir el nombre de una condición es marcarla: se guarda como desde el
    // atajo, en español, y un repetido no se suma.
    const id = conditionOfTag(text);
    const repeated = id ? has(id) : tags.some((x) => x.toLowerCase() === text.toLowerCase());
    if (text && !repeated) setTags((cur) => [...cur, id ? storedLabel(id) : text]);
    setTyped('');
  };

  const save = () => {
    const c = target.id;
    if (advantage !== target.advantage) act({ type: 'setAdvantage', combatantId: c, advantage });
    if (target.playerTemp === undefined && target.hasHp && Number(temp) !== target.tempHp) act({ type: 'setTempHp', combatantId: c, value: Number(temp) || 0 });
    if (Number(bonus) !== target.acBonus) act({ type: 'setAcBonus', combatantId: c, value: Number(bonus) || 0 });
    if (tags.join('\n') !== target.tags.join('\n')) act({ type: 'setTags', combatantId: c, tags });
  };

  const bonusN = Number(bonus) || 0;
  const total = bonusN > 0 && target.ac !== null ? previewAc(bonusN) : null;
  const freeTags = tags.filter((x) => conditionOfTag(x) === null);
  const ids = Object.keys(rules).sort((a, b) => rules[a]!.label.localeCompare(rules[b]!.label, lang));

  const roll = (value: Advantage, label: string, icon: ReactNode, on: string) => (
    <button
      type="button"
      aria-pressed={advantage === value}
      data-roll={value ?? 'normal'}
      onClick={() => setAdvantage(value)}
      className={cx(
        'inline-flex min-h-[34px] min-w-0 flex-1 items-center justify-center gap-1 rounded-[7px] px-2 text-[12.5px] transition-colors duration-[120ms]',
        advantage === value ? on : 'text-on-surface-variant hover:text-on-surface',
      )}
    >
      {icon}
      {label}
    </button>
  );

  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={t.dmEffectsOf(target.name)}
      width={520}
      actions={[{ label: t.cancel }, { label: t.commonSave, primary: true, onSelect: save }]}
    >
      <div className="flex flex-col gap-3.5">
        <div>
          <Eyebrow className="mb-1.5">{t.encRolls}</Eyebrow>
          <div role="group" aria-label={t.encRolls} className="flex gap-[3px] rounded-[var(--radius-nav)] border border-hairline bg-plaque p-[3px]">
            {roll(null, t.encNormal, null, 'bg-gold-soft font-semibold text-gold')}
            {roll('advantage', t.encAdvantage, <ArrowUp size={13} strokeWidth={2.5} aria-hidden="true" />, 'bg-verdant font-bold text-on-primary')}
            {roll('disadvantage', t.encDisadvantage, <ArrowDown size={13} strokeWidth={2.5} aria-hidden="true" />, 'bg-crimson font-bold text-on-primary')}
          </div>
        </div>

        <div className="grid grid-cols-2 gap-3">
          {target.playerTemp !== undefined ? (
            <div>
              <Eyebrow className="mb-1.5">{t.encTempHp}</Eyebrow>
              <div className="num text-[20px] leading-[38px] text-gold">+{target.playerTemp}</div>
              <p className="text-[12px] text-text-muted">{t.encTempOnSheet}</p>
            </div>
          ) : (
            target.hasHp && (
              <div>
                <Eyebrow className="mb-1.5">{t.encTempHp}</Eyebrow>
                <div className="flex items-center gap-1.5">
                  <input type="text" inputMode="numeric" aria-label={t.encTempHp} data-field="effects-temp" value={temp} onChange={(e) => setTemp(digits(e.target.value))} className={fieldClass} />
                  <button type="button" className={chipClass} onClick={() => setTemp('0')}>
                    0
                  </button>
                </div>
              </div>
            )
          )}
          <div>
            <Eyebrow className="mb-1.5">{t.encAcBonus}</Eyebrow>
            <div className="flex items-center gap-1.5">
              <input type="text" inputMode="numeric" aria-label={t.encAcBonus} data-field="effects-ac-bonus" value={bonus} onChange={(e) => setBonus(digits(e.target.value))} className={fieldClass} />
              {[2, 5].map((n) => (
                <button key={n} type="button" className={chipClass} onClick={() => setBonus(String(n))}>
                  +{n}
                </button>
              ))}
            </div>
            {total !== null && <p className="num mt-[5px] text-[12.5px] text-gold">{t.encAcPreview(target.ac!, bonusN, total)}</p>}
          </div>
        </div>

        <SectionRule className="my-0.5!" />

        <div className="flex items-center gap-1.5">
          <input
            type="text"
            aria-label={t.dmNoteEffect}
            placeholder={t.dmNoteEffectHint}
            value={typed}
            onChange={(e) => setTyped(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && addTyped()}
            className="h-10 min-w-0 flex-1 rounded-[8px] border border-hairline bg-plaque px-3 text-[14px] text-on-surface"
          />
          <Tooltip content={t.dmNoteEffect}>
            <button type="button" aria-label={t.dmNoteEffect} onClick={addTyped} className="flex h-9 w-9 items-center justify-center rounded-[var(--radius-nav)] text-on-surface-variant hover:text-on-surface">
              <CirclePlus size={22} aria-hidden="true" />
            </button>
          </Tooltip>
        </div>
        {freeTags.length > 0 && (
          <div className="flex flex-wrap gap-[5px]">
            {freeTags.map((tag) => (
              <span key={tag} className="plaque inline-flex items-center gap-1 rounded-[var(--radius-pill)] py-px pr-1 pl-[9px] text-[11.5px] text-on-surface">
                {tag}
                <button type="button" aria-label={t.dmRemoveTag(tag)} onClick={() => setTags((cur) => cur.filter((x) => x !== tag))} className="text-on-surface-variant hover:text-on-surface">
                  <X size={12} strokeWidth={2.5} aria-hidden="true" />
                </button>
              </span>
            ))}
          </div>
        )}

        <div>
          <Eyebrow className="mb-2">{t.dmBookConditions}</Eyebrow>
          <div className="flex flex-wrap gap-1.5">
            {ids.map((id) => (
              <Tooltip key={id} content={rules[id]!.rule}>
                <button
                  type="button"
                  aria-pressed={has(id)}
                  onClick={() => toggle(id)}
                  className={cx(
                    'min-h-8 rounded-[var(--radius-pill)] border px-2.5 text-[12.5px]',
                    has(id) ? 'border-gold bg-gold-soft text-gold' : 'border-hairline text-on-surface',
                  )}
                >
                  {rules[id]!.label}
                </button>
              </Tooltip>
            ))}
          </div>
        </div>

        <p className="text-[12px] text-text-muted">{t.encEffectsPrivate}</p>
      </div>
    </AppDialog>
  );
}
