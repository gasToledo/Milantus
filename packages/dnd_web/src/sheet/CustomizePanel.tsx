import { useContext, useId } from 'react';
import { useRosterSettings } from '../api/queries';
import type { SheetStyle } from '../engine';
import { useTexts } from '../i18n/context';
import { Button } from '../ui/Button';
import { cx } from '../ui/cx';
import { Eyebrow } from '../ui/data';
import { Switch } from '../ui/primitives';
import { classesOf, type SheetModel } from './model';
import { SheetCustomizeContext } from './sheetCustomize';
import { classAccent, ORNAMENT_COLORS, ornamentColor, resolveSheetStyle } from './sheetStyle';
import { useCardLayoutSaver } from './useCardLayoutSaver';

/**
 * El panel «Personalizar ficha». Arriba, lo que viaja con el personaje (lo ve
 * igual el DM) y solo cambia quien puede escribirlo; abajo, lo que es de quien
 * mira y vale para todas sus fichas.
 */
export function CustomizePanel({ model, tab }: { model: SheetModel; tab: 'combate' | 'personaje' }) {
  const t = useTexts();
  const { setOpen } = useContext(SheetCustomizeContext);
  const { save, saveSpellList, toast } = useCardLayoutSaver(tab);
  const fullList = useRosterSettings().data?.spellListFull === true;
  const fullListId = useId();
  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between gap-3">
        <h2 className="font-display text-[18px] leading-tight">{t.customizeSheet}</h2>
        <Button tone="primary" shape="pill" onClick={() => setOpen(false)}>
          {t.arrangeDone}
        </Button>
      </div>
      {model.write ? (
        <OwnStyle model={model} write={model.write} />
      ) : (
        <div className="flex flex-col gap-2">
          <Eyebrow>{t.thisSheet}</Eyebrow>
          <p className="text-[14px] text-on-surface-variant">{t.sheetStyleOwnerOnly}</p>
        </div>
      )}
      <div className="h-px bg-hairline" />
      <div className="flex flex-col gap-3">
        <Eyebrow>{t.allMySheets}</Eyebrow>
        <div className="flex items-center gap-3">
          <span className="min-w-0 flex-1 text-[14px] font-medium">{t.cardOrder}</span>
          <Button tone="secondary" shape="pill" onClick={() => void save(null)}>
            {t.arrangeRestore}
          </Button>
        </div>
        <div className="flex items-center gap-3">
          <span id={`${fullListId}-label`} className="min-w-0 flex-1 text-[14px] font-medium">
            {t.fullSpellList}
          </span>
          <Switch
            id={fullListId}
            label={t.fullSpellList}
            labelledBy={`${fullListId}-label`}
            checked={fullList}
            onCheckedChange={(full) => void saveSpellList(full)}
          />
        </div>
      </div>
      {toast}
    </div>
  );
}

function OwnStyle({ model, write }: { model: SheetModel; write: NonNullable<SheetModel['write']> }) {
  const t = useTexts();
  const switchId = useId();
  const look = resolveSheetStyle(model);
  const classes = classesOf(model);
  const stored = model.character.sheetStyle;
  const corner = (key: 'tl' | 'br') => ({
    classId: stored?.[key]?.classId ?? null,
    color: stored?.[key]?.color ?? null,
  });
  // Cada toque guarda el estilo entero, como el resto de la ficha: sin «Guardar».
  const send = (patch: SheetStyle) =>
    void write.act({ type: 'setSheetStyle', style: { ornaments: look.on, tl: corner('tl'), br: corner('br'), ...patch } });
  // Apagados no se ocultan (nada se pliega): se atenúan y no hacen nada.
  const off = !look.on && 'opacity-45';
  // La paleta vive en `index.css`; se lee de ahí para no repetir sus colores.
  const css = getComputedStyle(document.documentElement);

  return (
    <div className="flex flex-col gap-[18px]">
      <Eyebrow>{t.thisSheet}</Eyebrow>
      <div className="flex items-center gap-3">
        <span id={`${switchId}-label`} className="min-w-0 flex-1 text-[14px] font-medium">
          {t.classOrnaments}
        </span>
        <Switch
          id={switchId}
          label={t.classOrnaments}
          labelledBy={`${switchId}-label`}
          checked={look.on}
          onCheckedChange={(ornaments) => send({ ornaments })}
        />
      </div>
      {(['tl', 'br'] as const).map((key) => {
        const shown = look[key];
        if (!shown) return null;
        const chosen = corner(key);
        const chosenClass = classes.some((c) => c.id === chosen.classId) ? chosen.classId : null;
        const own = classAccent(model.catalog, shown.classId);
        // La muestra que repite el color de la clase no se ofrece dos veces.
        const palette = ORNAMENT_COLORS.filter(
          (c) => css.getPropertyValue(`--orn-${c}`).trim().toLowerCase() !== own.toLowerCase(),
        );
        const stock = ornamentColor(chosen.color);
        const chosenColor = stock && palette.includes(stock) ? stock : null;
        const title = key === 'tl' ? t.cornerTopLeft : t.cornerBottomRight;
        const autoName = classes.find((c) => c.id === look.auto[key])?.name ?? '';
        return (
          <div key={key} role="group" aria-label={title} className="flex flex-col gap-2.5">
            <p className="text-[14px] font-medium">{title}</p>
            <div className="flex flex-wrap gap-2">
              {[{ id: null, name: t.cornerAuto(autoName) }, ...classes].map((c) => (
                <button
                  key={c.id ?? 'auto'}
                  type="button"
                  aria-pressed={chosenClass === c.id}
                  aria-disabled={!look.on}
                  onClick={() => look.on && send({ [key]: { ...chosen, classId: c.id } })}
                  className={cx(
                    'min-h-9 cursor-pointer rounded-[var(--radius-pill)] border px-3.5 text-[13px]',
                    chosenClass === c.id ? 'border-gold bg-gold-soft text-gold' : 'border-hairline text-on-surface',
                    off,
                  )}
                >
                  {c.name}
                </button>
              ))}
            </div>
            <div className="flex flex-wrap gap-2.5">
              {[null, ...palette].map((color) => {
                const name = color ? t.ornamentColors[color] : t.classColor;
                const selected = chosenColor === color;
                return (
                  <button
                    key={color ?? 'class'}
                    type="button"
                    title={name}
                    aria-label={name}
                    aria-pressed={selected}
                    aria-disabled={!look.on}
                    onClick={() => look.on && send({ [key]: { ...chosen, color } })}
                    className={cx(
                      'h-9 w-9 cursor-pointer rounded-full border border-hairline',
                      selected && 'outline-2 outline-offset-[3px] outline-on-surface outline-solid',
                      off,
                    )}
                    // El color es un dato (catálogo o paleta), no una utilidad.
                    style={{ background: color ? `var(--orn-${color})` : own }}
                  />
                );
              })}
            </div>
          </div>
        );
      })}
    </div>
  );
}
