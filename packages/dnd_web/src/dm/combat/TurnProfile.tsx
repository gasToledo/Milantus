import type { ReactNode } from 'react';
import { ACTION_KINDS, actionKindLabel, Spellcasting } from '../../bestiary/CreatureProfile';
import type { CreatureProfile as Profile } from '../../bestiary/creature';
import type { BestiaryRow, Catalog } from '../../engine';
import { useTexts } from '../../i18n/context';
import { Eyebrow } from '../../ui/data';

/**
 * El monstruo que tiene el turno, como en la lámina «Jugando» del lienzo del
 * combate: quién es, las cifras **de la mesa** ([stats]) y lo que se viene a
 * buscar en su turno, que son sus rasgos y sus acciones.
 *
 * No es el perfil del Bestiario achicado, a propósito. Características, datos de
 * línea y la banda de cifras del libro no entran en una columna de 300 px sin
 * romperse, y la banda repetía PG y CA que en la mesa ya no son ciertos. El
 * perfil entero sigue en el Bestiario.
 */
export function TurnProfile({ profile, row, catalog, stats }: { profile: Profile; row: BestiaryRow; catalog: Catalog; stats: ReactNode }) {
  const t = useTexts();
  const source = (t.sources as Record<string, string>)[profile.source ?? ''];
  return (
    <div className="flex flex-col gap-3" data-field="turn-creature">
      <p className="eyebrow text-verdant">{t.encTurnNow}</p>
      <div className="flex flex-wrap items-center gap-2">
        <span className="font-display text-[19px] text-on-surface">{profile.name}</span>
        {source && (
          <span className="rounded-[var(--radius-pill)] border border-hairline px-2 text-[11px] text-on-surface-variant">
            <span aria-hidden="true">{source}</span>
            <span className="sr-only">{t.sourceLabel(source)}</span>
          </span>
        )}
      </div>
      <p className="-mt-2 text-[12px] text-on-surface-variant">{row.kind}</p>
      {stats}
      {(profile.traits?.length ?? 0) > 0 && (
        <section>
          <Eyebrow className="mb-1.5">{t.creatureTraits}</Eyebrow>
          <ul className="flex flex-col gap-2.5">
            {profile.traits!.map((tr, i) => (
              <li key={`${tr.name}-${i}`}>
                <p className="font-medium text-on-surface">{tr.name}</p>
                {tr.description && <p className="mt-0.5 text-[12.5px] leading-[1.45] text-on-surface-variant">{tr.description}</p>}
              </li>
            ))}
          </ul>
        </section>
      )}
      {ACTION_KINDS.map((kind) => {
        const group = (profile.actions ?? []).filter((a) => (a.kind ?? 'action') === kind);
        if (group.length === 0) return null;
        return (
          <section key={kind} data-actions={kind}>
            <Eyebrow className="mb-1.5">{actionKindLabel(t, profile, kind)}</Eyebrow>
            <ul className="flex flex-col gap-2.5">
              {group.map((a, i) => {
                // Lo que se tira en chips chicos: en la columna del turno no
                // entran las placas rotuladas del Bestiario.
                const chips = a.attackBonus != null ? [`+${a.attackBonus}`, a.damage, a.reach].filter(Boolean) : [];
                return (
                  <li key={`${a.name}-${i}`}>
                    <p className="font-medium text-on-surface">{a.name}</p>
                    {chips.length > 0 && (
                      <p className="my-1 flex flex-wrap gap-1.5">
                        {chips.map((c) => (
                          <span key={c} className="num rounded-[8px] border border-hairline bg-plaque px-2 py-0.5 text-[12px]">
                            {c}
                          </span>
                        ))}
                      </p>
                    )}
                    {a.description && !a.spellcasting && <p className="mt-0.5 text-[12.5px] leading-[1.45] text-on-surface-variant">{a.description}</p>}
                    {a.spellcasting && <Spellcasting spellcasting={a.spellcasting} catalog={catalog} />}
                  </li>
                );
              })}
            </ul>
          </section>
        );
      })}
    </div>
  );
}
