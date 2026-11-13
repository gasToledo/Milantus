import { useState } from 'react';
import { CircleAlert } from 'lucide-react';
import type { CombatantJson } from '../../engine';
import { useLang, useTexts } from '../../i18n/context';
import { Link } from '../../router';
import { AppDialog } from '../../ui/AppDialog';
import { cx } from '../../ui/cx';
import { Eyebrow } from '../../ui/data';

/**
 * La tirada de iniciativa de toda la mesa, de una (`roll_initiative_dialog.dart`):
 * es la transición de armar el combate a jugarlo, y al confirmar arranca la
 * ronda 1.
 *
 * **A los monstruos les llega el número ya tirado** (d20 + su modificador) y el
 * DM lo puede corregir; a los jugadores, en blanco, porque el número lo cantan
 * ellos desde la mesa. Los PNJ van con los monstruos y como ellos. Todos los
 * valores son el **final** —dado más modificador—, que es lo que se dice en voz
 * alta.
 *
 * **No arranca con casilleros en blanco.** Antes un blanco entraba como cero: el
 * combatiente quedaba último sin aviso y el DM se enteraba recién cuando le
 * tocaba. El que no vino se saca de la mesa y, cuando llega, se suma con su
 * tirada.
 *
 * **El capítulo no bloquea.** Si no hay uno en marcha (`chapterWarning`), una
 * nota arriba lo dice con un enlace a Capítulos: el servidor archiva un combate
 * sin capítulo y el DM no se entera hasta que lo busca. «Empezar» sigue igual.
 *
 * `suggested` lo calcula quien abre el diálogo **una sola vez**: si se
 * recalculara en cada redibujo, los dados volverían a tirar.
 */
export function RollInitiativeDialog({
  combatants,
  suggested,
  playerModifiers,
  chapterWarning,
  chaptersHref,
  onStart,
  onClose,
}: {
  combatants: CombatantJson[];
  suggested: Record<string, number>;
  /** Modificador de iniciativa de cada jugador con ficha, por id de combatiente. */
  playerModifiers: Record<string, number>;
  chapterWarning: 'none' | 'noActive' | null;
  /** Adónde lleva «Ir a Capítulos». */
  chaptersHref: string;
  onStart: (values: Record<string, number>) => void;
  onClose: () => void;
}) {
  const t = useTexts();
  const lang = useLang();
  const [text, setText] = useState<Record<string, string>>(() =>
    Object.fromEntries(combatants.map((c) => [c.id, c.kind === 'player' || suggested[c.id] === undefined ? '' : String(suggested[c.id])])),
  );

  // Un «-» solo tampoco es un número.
  const values: Record<string, number> = {};
  for (const c of combatants) if (/^-?\d+$/.test(text[c.id] ?? '')) values[c.id] = Number(text[c.id]);
  const missing = combatants.filter((c) => !(c.id in values));

  const players = combatants.filter((c) => c.kind === 'player');
  const monsters = combatants.filter((c) => c.kind !== 'player');
  // Un bando vacío solo se muestra si el otro también lo está: en un combate
  // solo de PNJ, media caja diciendo «Ningún jugador» no le dice nada nuevo al DM.
  const sides = [
    ...(players.length > 0 || monsters.length === 0 ? [{ title: t.dmPlayers, list: players, empty: t.dmNoPlayers }] : []),
    ...(monsters.length > 0 || players.length === 0 ? [{ title: t.dmMonstersAndNpcs, list: monsters, empty: t.dmNoMonstersOrNpcs }] : []),
  ];

  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={t.dmRollInitiative}
      width={660}
      actions={[
        { label: t.cancel },
        { label: t.dmStart, primary: true, tone: 'verdant', disabled: missing.length > 0, onSelect: () => onStart(values) },
      ]}
    >
      <div className="flex flex-col gap-3.5">
        {chapterWarning && (
          <div role="note" className="flex items-start gap-2.5 rounded-[var(--radius-card)] border border-gold bg-gold-soft px-3 py-2.5">
            <CircleAlert size={18} aria-hidden="true" className="mt-px shrink-0 text-gold" />
            <p className="min-w-0 flex-1 text-[13.5px] leading-[1.45] text-on-surface">
              {chapterWarning === 'none' ? t.dmNoChapters : t.dmNoActiveChapter}
            </p>
            <Link href={chaptersHref} className="shrink-0 px-0.5 text-[13.5px] font-semibold text-gold">
              {t.dmGoToChapters}
            </Link>
          </div>
        )}
        <div className={cx('grid grid-cols-1 gap-5', sides.length > 1 && 'sm:grid-cols-2')}>
          {sides.map((s) => (
            <div key={s.title} className="min-w-0">
              <Eyebrow className="mb-1">{s.title}</Eyebrow>
              {s.list.length === 0 ? (
                <p className="text-[13px] text-text-muted">{s.empty}</p>
              ) : (
                s.list.map((c) => {
                  const mod = playerModifiers[c.id];
                  return (
                    <label key={c.id} className="flex min-h-11 items-center gap-2">
                      <span className="min-w-0 flex-1 truncate">{c.name}</span>
                      {mod !== undefined && (
                        // Notación de dados, igual en todos los idiomas.
                        <span className="num text-[12px] font-normal text-text-muted">{`d20 ${mod >= 0 ? '+' : '−'} ${Math.abs(mod)}`}</span>
                      )}
                      <input
                        type="text"
                        inputMode="numeric"
                        aria-label={`${t.dmRollInitiative}: ${c.name}`}
                        data-initiative={c.id}
                        value={text[c.id] ?? ''}
                        // Un menos adelante y nada más: una Destreza baja resta.
                        onChange={(e) => /^-?\d*$/.test(e.target.value) && setText({ ...text, [c.id]: e.target.value })}
                        className={cx('h-9 w-[60px] rounded-[8px] border bg-plaque text-center text-[14px] text-on-surface', (text[c.id] ?? '') === '' || text[c.id] === '-' ? 'border-gold' : 'border-hairline')}
                      />
                    </label>
                  );
                })
              )}
            </div>
          ))}
        </div>
        {/* El aviso va en el cuerpo: en el pie, entre celdas que se tocan, un texto se lee como un botón muerto. */}
        <p className={cx('text-[12px]', missing.length === 0 ? 'text-text-muted' : 'text-gold')}>
          {missing.length === 0 ? t.dmRoundOneStarts : t.dmInitiativeMissing(new Intl.ListFormat(lang, { type: 'conjunction' }).format(missing.map((c) => c.name)))}
        </p>
      </div>
    </AppDialog>
  );
}
