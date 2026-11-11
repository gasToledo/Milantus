import { useState } from 'react';
import { Bug, Lightbulb, type LucideIcon } from 'lucide-react';
import { sendFeedback } from '../api/client';
import { useAccount, useAppVersion } from '../api/queries';
import { useLang, useTexts } from '../i18n/context';
import { AppDialog } from './AppDialog';
import { cx } from './cx';
import { showNotice } from './notices';

/** Desde qué pantalla se abrió el diálogo. Viaja con el mensaje por su nombre:
 *  es un dato para quien lee el correo, no texto de la interfaz. */
export type FeedbackOrigin = 'dashboard' | 'errorView';
type Kind = 'idea' | 'bug';

/** El mismo tope que acepta el servidor: cortar acá evita escribir un mensaje
 *  largo para enterarse recién al enviarlo de que no entra. */
const MAX_CHARS = 5000;

/**
 * «Sugerencias y errores» (`showFeedbackDialog` de Flutter). Quien lo abre lo
 * monta y lo desmonta con [onClose]: así cada apertura arranca limpia.
 *
 * Si el envío falla, el diálogo **queda abierto con el texto intacto**: perder
 * lo escrito por un corte de red es la forma más rápida de que nadie vuelva a
 * escribir. [errorDetail] viaja en el correo y no se muestra: es el texto
 * técnico de la vista de error.
 */
export function FeedbackDialog({
  origin,
  initialKind = 'idea',
  errorDetail,
  onClose,
}: {
  origin: FeedbackOrigin;
  initialKind?: Kind;
  errorDetail?: string;
  onClose: () => void;
}) {
  const t = useTexts();
  const lang = useLang();
  // Las dos ya están en caché casi siempre: el panel las pide para dibujarse.
  const email = useAccount().data?.email;
  const version = useAppVersion(true).data;
  const [kind, setKind] = useState<Kind>(initialKind);
  const [message, setMessage] = useState('');
  const [sending, setSending] = useState(false);
  const [failed, setFailed] = useState(false);
  const canSend = !sending && message.trim() !== '';

  const send = async () => {
    setSending(true);
    setFailed(false);
    try {
      await sendFeedback({
        kind,
        message: message.trim(),
        // Lo que la app sabe y el servidor no, leído al enviar y no al abrir:
        // si cambia el tema con el diálogo abierto, vale el del momento.
        context: {
          ...(version ? { version } : {}),
          language: lang,
          theme: document.documentElement.dataset.theme === 'light' ? 'light' : 'dark',
          viewport: `${window.innerWidth}x${window.innerHeight}`,
          origin,
          // Para quien lee el correo: desde qué cliente llegó.
          client: 'v2',
          ...(errorDetail ? { errorDetail } : {}),
        },
      });
      showNotice(t.feedbackSent);
      onClose();
    } catch {
      setSending(false);
      setFailed(true);
    }
  };

  return (
    <AppDialog
      open
      // Mientras envía, todo queda quieto: ni Esc ni el velo cierran.
      onOpenChange={(open) => !open && !sending && onClose()}
      title={t.feedbackTitle}
      actions={[
        { label: t.cancel, disabled: sending },
        { label: t.feedbackSend, primary: true, closes: false, disabled: !canSend, onSelect: () => void send() },
      ]}
    >
      <div className="flex flex-col gap-3.5">
        <div role="radiogroup" aria-label={t.feedbackKindGroup} className="flex flex-wrap gap-2">
          <KindPill icon={Lightbulb} label={t.feedbackKindIdea} on={kind === 'idea'} disabled={sending} onPick={() => setKind('idea')} />
          <KindPill icon={Bug} label={t.feedbackKindBug} on={kind === 'bug'} disabled={sending} onPick={() => setKind('bug')} />
        </div>
        <label className="flex flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{t.feedbackMessageLabel}</span>
          <textarea
            data-field="feedback-message"
            autoFocus
            rows={5}
            maxLength={MAX_CHARS}
            disabled={sending}
            value={message}
            placeholder={kind === 'idea' ? t.feedbackHintIdea : t.feedbackHintBug}
            onChange={(e) => setMessage(e.target.value)}
            className="min-h-32 min-w-0 resize-y rounded-[var(--radius-input)] border border-hairline bg-plaque px-3 py-2.5 text-[14px] leading-[1.5] text-on-surface placeholder:text-text-muted disabled:opacity-60"
          />
        </label>
        {email && <p className="text-[12.5px] text-on-surface-variant">{t.feedbackReplyTo(email)}</p>}
        {/* Región viva: quien no ve el diálogo tiene que enterarse de que falló. */}
        <div role="status">{failed && <p className="text-[13px] text-crimson">{t.feedbackSendError}.</p>}</div>
      </div>
    </AppDialog>
  );
}

function KindPill({ icon: Icon, label, on, disabled, onPick }: { icon: LucideIcon; label: string; on: boolean; disabled: boolean; onPick: () => void }) {
  return (
    <button
      type="button"
      role="radio"
      aria-checked={on}
      aria-disabled={disabled ? true : undefined}
      onClick={disabled ? undefined : onPick}
      className={cx(
        'pick inline-flex h-8 items-center gap-1.5 rounded-[var(--radius-pill)] border px-3.5 text-[13.5px]',
        disabled && 'opacity-60',
        on ? 'border-gold bg-gold-soft text-gold' : 'border-hairline text-on-surface',
      )}
    >
      <Icon size={16} strokeWidth={1.8} aria-hidden="true" />
      {label}
    </button>
  );
}
