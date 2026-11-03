import { Hourglass, Zap } from 'lucide-react';
import { useTurnStatus } from '../api/queries';
import { useTexts } from '../i18n/context';

/**
 * El cartel de turno de la ficha propia (`_turnBanner` de Flutter): «Preparate,
 * seguís vos» o «Es tu turno».
 *
 * Deliberadamente no dice nada más: nunca el orden, nunca cuántos faltan,
 * nunca quién más está en la mesa. Verlo delataría cuántos enemigos hay antes
 * de que aparezcan — la misma frontera que separa al Modo DM del resto.
 *
 * La región viva está **siempre montada**: un lector de pantalla anuncia el
 * cambio solo si la región ya existía cuando el contenido apareció. Vacía no
 * ocupa lugar (`empty:hidden`), y es lo único que se pega arriba al scrollear.
 */
export function TurnBanner({ characterId }: { characterId: string }) {
  const t = useTexts();
  const turn = useTurnStatus(characterId, true).data ?? 'none';

  return (
    <div role="status" className="sticky top-[var(--topbar-height)] shell:top-0 z-20 empty:hidden">
      {turn === 'next' && (
        <div className="step-in flex min-h-12 items-center gap-2.5 rounded-[var(--radius-card)] border border-gold bg-gold-soft px-4 py-2 text-[16px] font-semibold text-gold">
          <Hourglass size={20} aria-hidden="true" className="shrink-0" />
          {t.turnNext}
        </div>
      )}
      {turn === 'active' && (
        <div className="step-in flex min-h-12 items-center gap-2.5 rounded-[var(--radius-card)] border border-verdant bg-verdant px-4 py-2 text-[16px] font-semibold text-on-primary">
          <Zap size={20} aria-hidden="true" className="shrink-0" />
          {t.turnActive}
        </div>
      )}
    </div>
  );
}
