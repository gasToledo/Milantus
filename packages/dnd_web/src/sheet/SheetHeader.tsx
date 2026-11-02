import type { ReactNode } from 'react';
import { Footprints, Heart, Medal, Zap } from 'lucide-react';
import { nameOf } from '../api/catalog';
import { useTexts } from '../i18n/context';
import { hpTone, Pill, SectionRule, StatTile, ThinBar } from '../ui/data';
import { signed } from './format';
import { ActiveModeBanners, ActiveModeTile } from './ActiveModes';
import { classesOf, type SheetModel } from './model';

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
}: {
  model: SheetModel;
  leading?: ReactNode;
  /** La banda solo va donde se juega (Personaje y Combate): en Inventario,
   *  Campaña y Diario ocupa lugar sin aportar. El cartel del modo activo sí
   *  se queda: dice por qué cambiaron los números, y eso vale en todas. */
  showBand?: boolean;
}) {
  const t = useTexts();
  const { character, sheet, catalog } = model;
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
            <h1 className="font-display text-[28px] leading-[1.1] break-words text-on-surface">{character.name}</h1>
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

      <ActiveModeBanners model={model} />

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
          <StatTile id="initiative" icon={Zap} label={t.initiative} value={signed(sheet.initiative)} />
          <StatTile id="speed" icon={Footprints} label={t.speed} value={sheet.speed} suffix={t.feet} />
          <StatTile id="proficiency" icon={Medal} label={t.proficiency} value={signed(sheet.proficiencyBonus)} />
          {/* Los estados activables viven en la banda y no en una tarjeta de
              Combate: se prenden en el turno desde cualquier pestaña. Sin
              escritura, solo el que está en curso. */}
          {sheet.activeModes
            .filter((m) => model.write || m.active)
            .map((m) => (
              <ActiveModeTile key={m.id} model={model} mode={m} />
            ))}
        </dl>
      </section>
      )}

      <SectionRule className="my-1" />
    </>
  );
}
