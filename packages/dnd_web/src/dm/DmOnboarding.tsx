import { useState } from 'react';
import { Plus, Shield } from 'lucide-react';
import { useTexts } from '../i18n/context';
import { Button } from '../ui/Button';
import { cx } from '../ui/cx';
import { CampaignEditorDialog } from './CampaignEditorDialog';
import { useCreateCampaign } from './campaigns';

/**
 * La bienvenida de quien todavía no dirige ninguna campaña
 * (`_DmOnboardingState`): tres pasos y el botón que abre el editor. Sin
 * campañas no hay panel de secciones, así que esto es lo único a mano.
 *
 * Ocupa todo el ancho (el lienzo «Bienvenida del Modo DM»): una tarjeta
 * angosta en el medio dejaba la pantalla vacía. Desde 760 px de contenedor la
 * presentación va a la izquierda y los pasos a la derecha, como una línea de
 * tiempo cuyo primer paso, el que toca, va en oro; más angosto se apilan.
 */
export function DmOnboarding() {
  const t = useTexts();
  const create = useCreateCampaign();
  const [creating, setCreating] = useState(false);
  const steps = [
    [t.dmOnb1Title, t.dmOnb1Detail],
    [t.dmOnb2Title, t.dmOnb2Detail],
    [t.dmOnb3Title, t.dmOnb3Detail],
  ];

  return (
    <div className="@container">
      <section className="card grid items-center gap-6 px-[18px] py-[22px] @[760px]:grid-cols-2 @[760px]:gap-12 @[760px]:px-10 @[760px]:py-9">
        <div className="flex flex-col items-start gap-3.5">
          {/* El escudo en el medallón de la marca: el aro dorado y el degradado
              que se hunde hacia la placa. */}
          <span
            aria-hidden="true"
            className="flex size-[46px] items-center justify-center rounded-full border-2 border-gold @[760px]:size-[54px]"
            style={{ background: 'radial-gradient(circle at 50% 35%, color-mix(in srgb, var(--gold) 33%, transparent), var(--plaque))' }}
          >
            <Shield size={24} strokeWidth={1.8} className="text-gold" />
          </span>
          <h2 className="font-display mt-1 text-[25px] leading-tight font-normal text-on-surface @[760px]:text-[32px]">
            {t.dmOnbTitle}
          </h2>
          <p className="text-[14px] leading-[1.55] text-on-surface-variant @[760px]:text-[15px]">{t.dmOnbBody}</p>
          {/* El `display` va en un envoltorio: sobre el botón competiría con el suyo. */}
          <div className="mt-2 hidden @[760px]:block">
            <Button icon={Plus} onClick={() => setCreating(true)} className="min-h-[46px] px-[22px] text-[15px]">
              {t.dmCreateCampaign}
            </Button>
          </div>
        </div>
        <ol className="relative flex flex-col gap-[18px] @[760px]:gap-[22px]">
          {/* La línea que une los pasos, del centro del primero al del último. */}
          <span aria-hidden="true" className="absolute top-4 bottom-4 left-[15px] w-0.5 bg-hairline @[760px]:top-[18px] @[760px]:bottom-[18px] @[760px]:left-[17px]" />
          {steps.map(([title, detail], i) => (
            <li key={title} className="step-in relative flex items-start gap-3.5 @[760px]:gap-4" style={{ animationDelay: `${i * 70}ms` }}>
              <span
                aria-hidden="true"
                className={cx(
                  'font-display flex size-8 shrink-0 items-center justify-center rounded-full border text-[15px] @[760px]:size-9 @[760px]:text-[16px]',
                  i === 0 ? 'border-gold bg-gold text-on-primary ring-4 ring-gold-soft' : 'border-hairline bg-plaque text-text-muted',
                )}
              >
                {i + 1}
              </span>
              <div>
                <p className="font-semibold text-on-surface @[760px]:text-[15px]">{title}</p>
                <p className="mt-0.5 text-[13px] text-on-surface-variant">{detail}</p>
              </div>
            </li>
          ))}
        </ol>
        {/* En angosto el botón va al final, después de los pasos y a todo el ancho. */}
        <div className="@[760px]:hidden">
          <Button icon={Plus} onClick={() => setCreating(true)} className="min-h-12 w-full justify-center text-[15px]">
            {t.dmCreateCampaign}
          </Button>
        </div>
      </section>
      {creating && (
        <CampaignEditorDialog
          title={t.dmNewCampaign}
          initial={{ name: '', premise: '', state: 'active' }}
          onSubmit={create}
          onClose={() => setCreating(false)}
        />
      )}
    </div>
  );
}
