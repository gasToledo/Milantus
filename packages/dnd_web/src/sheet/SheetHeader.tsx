import { useState, type ReactNode } from 'react';
import { Footprints, Heart, Medal, Pencil, Zap } from 'lucide-react';
import { nameOf } from '../api/catalog';
import { useTexts } from '../i18n/context';
import { labelOf } from '../i18n/texts';
import { RenameDialog } from '../dashboard/RenameDialog';
import { hpTone, Pill, SectionRule, StatTile, ThinBar } from '../ui/data';
import { Tooltip } from '../ui/primitives';
import { BreakdownDialog } from './BreakdownDialog';
import { signed } from './format';
import { ActiveModeTile } from './ActiveModes';
import { useChoicesView, WarningsStrip } from './Choices';
import { WildShapeTile } from './WildShape';
import { classesOf, type SheetModel } from './model';
import { advantageSources } from './rows';

/**
 * La cabecera de la ficha: nombre (el `h1` de la pantalla) con especie y
 * trasfondo en línea, las pills de nivel y clases, y la **banda táctica**:
 * las cinco cifras que se miran de reojo en la mesa. La percepción pasiva NO
 * va en la banda: es de la pestaña Personaje (Habilidades), y una sexta placa
 * le quita ancho a los PG, que son los que cambian.
 */
export function SheetHeader({
  model,
  leading,
  showBand = true,
  warnings = false,
}: {
  model: SheetModel;
  leading?: ReactNode;
  /** La banda solo va donde se juega (Personaje y Combate): en Inventario,
   *  Campaña y Diario ocupa lugar sin aportar. */
  showBand?: boolean;
  /** La franja de avisos del motor en la banda: solo en Personaje y solo en
   *  la ficha propia (sin `write` el modelo no pide los avisos). */
  warnings?: boolean;
}) {
  const t = useTexts();
  const [initiativeOpen, setInitiativeOpen] = useState(false);
  const [renaming, setRenaming] = useState(false);
  const choices = useChoicesView(model);
  const { character, sheet, catalog } = model;
  const exhaustion = character.combat?.exhaustion ?? 0;
  // Las otras velocidades (trepar, nadar, volar) van al pie: es donde se mira
  // en el turno, y la placa está en todas las pestañas.
  const otherSpeeds = Object.entries(sheet.speeds).map(([mode, feet]) => t.speedOther(labelOf(t.movementModes, mode), feet));
  const currentHp = character.combat?.currentHp ?? 0;
  const tempHp = character.combat?.tempHp ?? 0;
  const ratio = sheet.maxHp <= 0 ? 0 : Math.min(1, Math.max(0, currentHp / sheet.maxHp));
  const tone = hpTone(ratio);
  const origin = [nameOf(catalog.races, character.raceId), nameOf(catalog.backgrounds, character.backgroundId)]
    .filter(Boolean)
    .join(' · ');

  return (
    <>
      <header className="flex items-center gap-4">
        {leading}
        <div className="flex min-w-0 flex-1 flex-col gap-2.5">
          <div className="flex flex-wrap items-baseline gap-x-3.5 gap-y-1">
            <h1 className="font-display text-[28px] leading-[1.1] break-words text-on-surface">
              {character.name}
              {/* Solo en la ficha propia: sin `write` (la de otra cuenta, un
                  PNJ) no hay ni el control. */}
              {model.write && (
                <Tooltip content={t.renameTitle}>
                  <button
                    type="button"
                    aria-label={t.renameTitle}
                    onClick={() => setRenaming(true)}
                    className="ml-0.5 inline-flex h-7 w-7 items-center justify-center rounded-[var(--radius-nav)] align-middle text-text-muted hover:text-gold"
                  >
                    <Pencil size={15} aria-hidden="true" />
                  </button>
                </Tooltip>
              )}
            </h1>
            {origin && <p className="text-[14px] text-on-surface-variant">{origin}</p>}
          </div>
          <ul className="flex flex-wrap gap-1.5">
            <Pill as="li">{t.levelPill(sheet.level)}</Pill>
            {classesOf(model).map((c) => (
              <Pill as="li" key={c.id} highlighted={false}>
                <span className="font-bold text-on-surface">{t.classLevel(c.name, c.level)}</span>
                {c.subclass && <span>{c.subclass}</span>}
              </Pill>
            ))}
          </ul>
        </div>
      </header>
      {renaming && model.write && (
        <RenameDialog
          current={character.name}
          onSubmit={async (name) => void model.write?.act({ type: 'rename', name })}
          onClose={() => setRenaming(false)}
        />
      )}

      {showBand && (
      <section aria-label={t.tacticalBand} className="tactical-band">
        <dl>
          <StatTile
            id="hp"
            icon={Heart}
            label={t.hitPoints}
            caption={t.hpPercent(Math.round(ratio * 100))}
            value={currentHp}
            valueClassName={tone.text}
            suffix={`/ ${sheet.maxHp}`}
            footer={
              <>
                <ThinBar
                  value={currentHp}
                  max={sheet.maxHp}
                  label={t.hitPoints}
                  valueText={t.hpValueText(currentHp, sheet.maxHp)}
                  colorClassName={tone.bar}
                />
                {tempHp > 0 && <p className="mt-1.5 text-[11px] text-on-surface-variant">{t.tempHp(tempHp)}</p>}
              </>
            }
          />
          <StatTile
            id="initiative"
            icon={Zap}
            label={t.initiative}
            value={signed(sheet.initiative)}
            onClick={() => setInitiativeOpen(true)}
            footer={
              sheet.initiativeAdvantages.length > 0 ? (
                <span className="text-[11px] text-gold" title={advantageSources(sheet.initiativeAdvantages, t)}>
                  {t.advantageWith}
                </span>
              ) : undefined
            }
          />
          <StatTile
            id="speed"
            icon={Footprints}
            label={t.speed}
            value={sheet.speed}
            suffix={t.feet}
            footer={
              otherSpeeds.length > 0 || exhaustion > 0 ? (
                <>
                  {otherSpeeds.length > 0 && <p className="text-[11px] text-on-surface-variant">{otherSpeeds.join(' · ')}</p>}
                  {/* El motor ya restó la velocidad; esto solo dice cuánto. El 5
                      es el de Flutter (`5 * exhaustion`): la ficha no trae la
                      cifra aparte. */}
                  {exhaustion > 0 && <p className="text-[11px] text-crimson">{t.exhaustionSpeed(5 * exhaustion)}</p>}
                </>
              ) : undefined
            }
          />
          <StatTile id="proficiency" icon={Medal} label={t.proficiency} value={signed(sheet.proficiencyBonus)} />
          {/* Los avisos del motor: una franja de la banda. Con espacio va en la
              fila de las cifras, a la derecha (`data-warnings`, ver
              `.tactical-band`); debajo, a todo el ancho. Va antes de los
              estados para que el autoflujo la suba a la primera fila. */}
          {warnings && choices && choices.warnings.length > 0 && (
            <div data-warnings className="min-w-0">
              <WarningsStrip model={model} view={choices} />
            </div>
          )}
          {/* Los estados activables viven en la banda y no en una tarjeta de
              Combate: se prenden en el turno desde cualquier pestaña. Sin
              escritura, solo el que está en curso. */}
          <WildShapeTile model={model} />
          {sheet.activeModes
            .filter((m) => model.write || m.active)
            .map((m) => (
              <ActiveModeTile key={m.id} model={model} mode={m} />
            ))}
        </dl>
      </section>
      )}

      {initiativeOpen && <BreakdownDialog model={model} target="initiative" onClose={() => setInitiativeOpen(false)} />}

      <SectionRule className="my-1" />
    </>
  );
}
