import { useEffect, useMemo, useState, type MutableRefObject, type ReactNode } from 'react';
import { Info } from 'lucide-react';
import { homebrewRules, type HomebrewRules } from '../../engine';
import { useLang, useTexts } from '../../i18n/context';
import { navigateBack } from '../../router';
import { AppDialog } from '../../ui/AppDialog';
import { Button } from '../../ui/Button';
import { cx } from '../../ui/cx';
import { Eyebrow } from '../../ui/data';
import type { CodexDetail } from '../../codex/entries';
import { DetailBody, WIZARD_ASIDE, WizardFooter } from '../../ui/wizard';
import { DmHeader } from '../DmHeader';

/** La ficha del Códice de lo que se está armando: es la vista previa de los
 *  tres formularios, la misma que lee el jugador. */
export function EntryPreview({ subtitle, name, detail, note }: { subtitle: string; name: string; detail: CodexDetail; note?: string | null }) {
  return (
    <div className="flex flex-col gap-2.5">
      <div className="card flex flex-col gap-2.5 p-4">
        <Eyebrow>{subtitle}</Eyebrow>
        <span className="font-display text-[20px] break-words text-on-surface">{name}</span>
        <DetailBody detail={detail} />
      </div>
      {note && <p className="text-[12.5px] leading-[1.5] text-on-surface-variant">{note}</p>}
    </div>
  );
}

/** Lo que se explica al tocar un campo (`_Explained` de Flutter): el rótulo
 *  chico, el valor tocado, la regla y, si hay, lo que vale para todo el grupo. */
export type Explained = { kicker: string; title: string; text: string; note?: string | null };

/** Los textos de regla del motor, en el idioma activo. */
export function useHomebrewRules(): HomebrewRules {
  const lang = useLang();
  return useMemo(() => homebrewRules(), [lang]);
}

/** La placa de una explicación: hundida, sin borde, con el kicker en oro. */
function ExplainPlaque({ explained, large }: { explained: Explained; large?: boolean }) {
  return (
    <div className="plaque flex flex-col gap-1.5 rounded-[var(--radius-card)] px-4 py-3.5">
      <span className="text-[12px] text-gold">{explained.kicker}</span>
      <span className={cx('font-display text-on-surface', large ? 'text-[20px]' : 'text-[18px]')}>{explained.title}</span>
      <p className="text-[13.5px] leading-[1.55] text-on-surface">{explained.text}</p>
      {explained.note && <p className="text-[12.5px] leading-[1.5] text-text-muted">{explained.note}</p>}
    </div>
  );
}

/**
 * La explicación debajo de la sección del campo tocado (`explainHere` de
 * Flutter), para donde la vista previa vive en un diálogo: se oculta desde
 * `lg` con CSS, que es donde el armazón la muestra al costado. [always] la deja
 * a todos los anchos (`CreatureForm`, que no usa el armazón). Sin
 * [explanation] no dibuja nada.
 */
export function ExplainHere({ explanation, always, className }: { explanation: Explained | null; always?: boolean; className?: string }) {
  if (!explanation) return null;
  return (
    <div aria-live="polite" className={cx(!always && 'lg:hidden', className)}>
      <ExplainPlaque explained={explanation} />
    </div>
  );
}

/**
 * El armazón de los formularios de una entrada propia del Homebrew con vista
 * previa (las ocho categorías menos las criaturas): cabecera, columna de secciones, vista
 * previa fija al costado (en un diálogo en pantallas chicas), pie con
 * Cancelar / Guardar y su mensaje, y la guardia de salida con cambios sin
 * guardar (el diálogo de descartar y el aviso del navegador al cerrar).
 *
 * No sabe de reglas ni de qué se edita: el formulario le dice si hay cambios
 * (`dirty`), qué mensaje mostrar y qué hacer al guardar. `CreatureForm` no lo
 * usa: lleva pestañas y su vista previa es otra.
 *
 * El panel de reglas (qué significa lo último que se tocó) va en el `aside`,
 * debajo de la vista previa; donde la vista previa vive en un diálogo, cada
 * formulario pone un [ExplainHere] bajo la sección tocada. Lo que se explica lo
 * arma el formulario con los textos del motor (`useHomebrewRules`).
 */
export function HomebrewFormShell({
  title,
  kicker,
  exitHref,
  leaveRef,
  dirty,
  message,
  failed,
  saving,
  saveAction,
  onSave,
  previewLabel,
  preview,
  explanation,
  children,
}: {
  title: string;
  kicker?: string;
  /** Adónde se vuelve al cancelar o descartar. */
  exitHref: string;
  /** Lo que llama el «volver» del panel lateral, que no vive acá. */
  leaveRef: MutableRefObject<(() => void) | null>;
  /** Hay cambios sin guardar: salir pregunta. */
  dirty: boolean;
  /** El mensaje del pie, o `null`; es de error (carmesí) cuando existe. */
  message: string | null;
  /** El último guardado falló: el botón pasa a «Reintentar». */
  failed: boolean;
  saving: boolean;
  /** El `data-action` del botón de guardar, para las pruebas. */
  saveAction: string;
  onSave: () => void;
  /** El rótulo de la vista previa, que además titula su diálogo. */
  previewLabel: string;
  preview: ReactNode;
  /** Lo que explica el campo tocado, o `null` mientras no se tocó nada. */
  explanation: Explained | null;
  children: ReactNode;
}) {
  const t = useTexts();
  const [discarding, setDiscarding] = useState(false);
  const [previewing, setPreviewing] = useState(false);

  // ponytail: el botón «atrás» del navegador no pregunta, igual que el de
  // criaturas; frenarlo pide interceptar el historial del router.
  const requestLeave = () => (dirty ? setDiscarding(true) : navigateBack(exitHref));
  useEffect(() => {
    leaveRef.current = requestLeave;
    return () => {
      leaveRef.current = null;
    };
  });
  // Cambios sin guardar: el navegador avisa antes de cerrar o recargar.
  useEffect(() => {
    if (!dirty) return;
    const warn = (e: BeforeUnloadEvent) => e.preventDefault();
    window.addEventListener('beforeunload', warn);
    return () => window.removeEventListener('beforeunload', warn);
  }, [dirty]);

  return (
    <>
      <DmHeader title={title} kicker={kicker} />
      <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_380px]">
        <div className="flex min-w-0 flex-col gap-3">
          {children}
          <WizardFooter message={message} danger={message !== null}>
            <Button tone="secondary" icon={Info} className="lg:hidden" onClick={() => setPreviewing(true)}>
              {t.blockPreview}
            </Button>
            <Button tone="secondary" onClick={requestLeave}>
              {t.cancel}
            </Button>
            <Button data-action={saveAction} disabled={saving} onClick={onSave}>
              {failed ? t.retry : t.blockSave}
            </Button>
          </WizardFooter>
        </div>
        <aside aria-label={previewLabel} className={cx(WIZARD_ASIDE, 'hidden lg:flex')}>
          <Eyebrow>{previewLabel}</Eyebrow>
          {preview}
          <div aria-live="polite">{explanation && <ExplainPlaque explained={explanation} large />}</div>
        </aside>
      </div>
      <AppDialog
        open={discarding}
        onOpenChange={setDiscarding}
        title={t.blockDiscardTitle}
        description={t.blockDiscardBody}
        actions={[
          { label: t.blockKeepEditing },
          { label: t.blockDiscard, primary: true, tone: 'crimson', onSelect: () => navigateBack(exitHref) },
        ]}
      />
      <AppDialog open={previewing} onOpenChange={setPreviewing} title={previewLabel} width={560} actions={[{ label: t.close }]}>
        {preview}
      </AppDialog>
    </>
  );
}
