import { ArrowDown, ArrowUp, EllipsisVertical, Pencil, RotateCcw, Star, Trash2 } from 'lucide-react';
import { useTexts } from '../i18n/context';
import { characterHref, Link } from '../router';
import { signed } from '../sheet/format';
import { HP_CRITICAL_RATIO, hpTone, StatPlaque, ThinBar } from '../ui/data';
import { Medallion } from '../ui/Medallion';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuSeparator, DropdownMenuTrigger, Tooltip } from '../ui/primitives';
import type { useHoldDrag } from '../ui/holdDrag';
import { ownPortrait } from '../ui/portrait';
import { isFallen, type RosterEntry } from './roster';

/**
 * Tarjeta de personaje: identidad arriba y datos de combate abajo, para no
 * abrir la ficha. Todo número viene de `ComputedSheet`; de la ficha cruda solo
 * se lee lo que no es un resultado de reglas (los PG actuales).
 *
 * La tarjeta entera es un enlace, pero el enlace es el nombre y se estira con
 * `::after` sobre toda la tarjeta: así el lector de pantalla anuncia «Brunilda
 * de Humo» y no la tarjeta entera leída de corrido, y el clic cae en cualquier
 * parte. La tarjeta también se toma entera para moverla (`useHoldDrag`), y el
 * menú ofrece lo mismo para quien no puede o no quiere arrastrar.
 */
export interface CardReorder {
  item: ReturnType<ReturnType<typeof useHoldDrag>['item']>;
  dragging: boolean;
  over: boolean;
  /** Con «reducir movimiento» no sigue al puntero: se atenúa y se marca. */
  animated: boolean;
  /** Sin vecino en su grupo, esa opción del menú se apaga. */
  moveBefore?: () => void;
  moveAfter?: () => void;
}

export function RosterCard({
  entry,
  favorite,
  onToggleFavorite,
  onRename,
  onRebuild,
  onDelete,
  reorder,
}: {
  entry: RosterEntry;
  favorite: boolean;
  onToggleFavorite: () => void;
  onRename: () => void;
  onRebuild: () => void;
  onDelete: () => void;
  /** Sin esto la tarjeta no se puede mover: el favorito, o la lista filtrada. */
  reorder?: CardReorder;
}) {
  const t = useTexts();
  const { character, sheet } = entry;
  const fallen = isFallen(entry);
  const hp = character.combat?.currentHp ?? 0;
  const maxHp = sheet?.maxHp ?? 0;
  const ratio = maxHp === 0 ? 0 : Math.min(1, Math.max(0, hp / maxHp));
  // Un cuarto de los PG: a partir de ahí el rótulo lo dice con todas las
  // letras en vez de dejarlo librado a lo corta que se ve la barra.
  const critical = !fallen && ratio <= HP_CRITICAL_RATIO;
  const hpLabel = fallen ? t.hpLabelFallen : critical ? t.hpLabelCritical : t.hpLabelNormal;

  const classes = entry.classes
    .map((c) => (entry.classes.length > 1 ? `${c.name} ${c.level}` : c.name))
    .join(' · ');

  return (
    <li
      className={`roster-card card relative flex flex-col p-4 ${
        // Sostenerla no puede seleccionar el texto ni abrir el menú del teléfono.
        reorder ? 'select-none [-webkit-touch-callout:none]' : ''
      } ${
        reorder?.dragging
          ? reorder.animated
            ? 'cursor-grabbing border-gold [&_*]:cursor-grabbing'
            : 'opacity-40'
          : ''
      } ${reorder?.over && !reorder.animated ? 'outline-2 outline-offset-1 outline-gold' : ''}`}
      data-character={character.id}
      data-favorite={favorite}
      {...reorder?.item}
    >
      <div className="flex items-start gap-3">
        <Medallion name={character.name} accent={entry.accent} size={64} muted={fallen} portrait={ownPortrait(character)} />
        <div className="min-w-0 flex-1">
          <h2 className="flex items-center gap-1.5 font-display text-[18px] leading-tight">
            {favorite && (
              <span role="img" aria-label={t.favorite} className="flex shrink-0">
                <Star size={15} aria-hidden="true" className="fill-gold text-gold" />
              </span>
            )}
            <Link
              href={characterHref(character.id)}
              draggable={false}
              className={`truncate after:absolute after:inset-0 after:rounded-[var(--radius-card)] after:content-[''] ${
                fallen ? 'text-on-surface-variant' : 'text-on-surface'
              }`}
            >
              {character.name}
            </Link>
            {fallen && (
              <span className="shrink-0 rounded-[var(--radius-pill)] border border-crimson px-[7px] font-body text-[9.5px] font-semibold tracking-[0.6px] text-crimson">
                {t.fallenBadge}
              </span>
            )}
          </h2>
          <p className="mt-0.5 truncate text-[12.5px] text-on-surface-variant">
            {[entry.raceName, classes].filter(Boolean).join(' · ')}
          </p>
        </div>
        {sheet && (
          <div className="shrink-0 text-right" data-field="level">
            <p className="eyebrow">{t.levelWord}</p>
            <p className="stat-value mt-1" data-stat="level">
              {sheet.level}
            </p>
          </div>
        )}
        {/* Margen negativo para no correr el medallón, y `relative z-10`
            porque el enlace del nombre se estira sobre toda la tarjeta y lo
            taparía. */}
        <DropdownMenu>
          <Tooltip content={t.cardActionsTooltip(character.name)}>
            <DropdownMenuTrigger asChild>
              <button
                type="button"
                aria-label={t.cardActionsTooltip(character.name)}
                className="relative z-10 -mt-2 -mr-2.5 -ml-1 inline-flex size-10 shrink-0 items-center justify-center rounded-[var(--radius-nav)] text-text-muted hover:text-gold data-[state=open]:bg-gold-soft data-[state=open]:text-gold"
              >
                <EllipsisVertical size={20} aria-hidden="true" />
              </button>
            </DropdownMenuTrigger>
          </Tooltip>
          <DropdownMenuContent align="end">
            <DropdownMenuItem onSelect={onToggleFavorite}>
              <Star size={15} aria-hidden="true" className="text-text-muted" />
              {favorite ? t.cardUnfavorite : t.cardFavorite}
            </DropdownMenuItem>
            <DropdownMenuItem onSelect={onRename}>
              <Pencil size={15} aria-hidden="true" className="text-text-muted" />
              {t.cardRename}
            </DropdownMenuItem>
            <DropdownMenuItem onSelect={onRebuild}>
              <RotateCcw size={15} aria-hidden="true" className="text-text-muted" />
              {t.cardRebuild}
            </DropdownMenuItem>
            {reorder && (
              <>
                <DropdownMenuItem disabled={!reorder.moveBefore} onSelect={reorder.moveBefore}>
                  <ArrowUp size={15} aria-hidden="true" className="text-text-muted" />
                  {t.cardMoveBefore}
                </DropdownMenuItem>
                <DropdownMenuItem disabled={!reorder.moveAfter} onSelect={reorder.moveAfter}>
                  <ArrowDown size={15} aria-hidden="true" className="text-text-muted" />
                  {t.cardMoveAfter}
                </DropdownMenuItem>
              </>
            )}
            <DropdownMenuSeparator />
            <DropdownMenuItem onSelect={onDelete} className="text-crimson">
              <Trash2 size={15} aria-hidden="true" />
              {t.cardDelete}
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>

      {sheet && (
        <>
          <div className="my-3 h-px bg-hairline" />
          <div className="flex items-baseline gap-2">
            <p
              className={`min-w-0 flex-1 truncate text-[9.5px] tracking-[1px] ${
                fallen || critical ? 'font-semibold text-crimson' : 'text-text-muted'
              }`}
            >
              {hpLabel}
            </p>
            {/* Sans negrita con cifras tabulares: se compara con la tarjeta de
                al lado. */}
            <p className="num text-[14px]" data-stat="hp">
              <span className={fallen || critical ? 'text-crimson' : 'text-on-surface'}>{hp}</span>
              <span className="font-normal text-text-muted"> / {maxHp}</span>
            </p>
          </div>
          {/* Recorre el tramo y cambia de color como en Flutter (verde, oro,
              carmesí); su `aria-label` dice lo mismo que la cifra de arriba. */}
          <div className="mt-1.5">
            <ThinBar
              value={fallen ? 0 : hp}
              max={maxHp}
              label={t.hp}
              valueText={`${hp} / ${maxHp}`}
              colorClassName={hpTone(ratio).bar}
              height={6}
            />
          </div>

          {/* Tres placas cortas dentro de la tarjeta: es el caso de
              `StatPlaque` (rótulo y valor en Georgia sobre la placa). El
              rótulo corto se ve; el completo se lee. */}
          <dl className="mt-3.5 grid grid-cols-3 gap-2">
            <StatPlaque id="ac" label={<Abbr short={t.acShort} full={t.acFull} />} value={sheet.armorClass} />
            <StatPlaque
              id="speed"
              label={<Abbr short={t.speedShort} full={t.speed} />}
              value={
                <>
                  {sheet.speed}
                  <span className="sr-only"> {t.feet}</span>
                </>
              }
            />
            <StatPlaque
              id="initiative"
              label={<Abbr short={t.initiativeShort} full={t.initiative} />}
              value={signed(sheet.initiative)}
            />
          </dl>
        </>
      )}
    </li>
  );
}

function Abbr({ short, full }: { short: string; full: string }) {
  return (
    <>
      <span aria-hidden="true">{short}</span>
      <span className="sr-only">{full}</span>
    </>
  );
}
