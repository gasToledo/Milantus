import { useState } from 'react';
import { Plus, Shield } from 'lucide-react';
import { useTexts } from '../i18n/context';
import { Button } from '../ui/Button';
import { CampaignEditorDialog } from './CampaignEditorDialog';
import { useCreateCampaign } from './campaigns';

/**
 * La bienvenida de quien todavía no dirige ninguna campaña
 * (`_DmOnboardingState`): tres pasos y el botón que abre el editor. Sin
 * campañas no hay panel de secciones, así que esto es lo único a mano.
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
    <section className="card mx-auto mt-6 flex w-full max-w-[560px] flex-col gap-3.5 px-7 pt-[26px] pb-7">
      <Shield size={32} strokeWidth={1.7} aria-hidden="true" className="text-gold" />
      <h2 className="font-display text-[26px] leading-tight font-normal text-on-surface">{t.dmOnbTitle}</h2>
      <p className="mb-2 text-on-surface-variant">{t.dmOnbBody}</p>
      <ol className="flex flex-col gap-3.5">
        {steps.map(([title, detail], i) => (
          <li key={title} className="flex items-start gap-3">
            <span
              aria-hidden="true"
              className="font-display flex size-7 shrink-0 items-center justify-center rounded-[var(--radius-nav)] border border-hairline bg-gold-soft text-[14px] font-bold text-gold"
            >
              {i + 1}
            </span>
            <div>
              <p className="font-semibold text-on-surface">{title}</p>
              <p className="text-[12.5px] text-on-surface-variant">{detail}</p>
            </div>
          </li>
        ))}
      </ol>
      <Button icon={Plus} onClick={() => setCreating(true)} className="mt-2 min-h-11 self-start">
        {t.dmCreateCampaign}
      </Button>
      {creating && (
        <CampaignEditorDialog
          title={t.dmNewCampaign}
          initial={{ name: '', premise: '', state: 'active' }}
          onSubmit={create}
          onClose={() => setCreating(false)}
        />
      )}
    </section>
  );
}
