import { useEffect, useState, type MutableRefObject, type ReactNode } from 'react';
import { Info } from 'lucide-react';
import { useTexts } from '../../i18n/context';
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

/**
 * El armazón de los formularios de una entrada propia del Homebrew con vista
 * previa (dote, especie, trasfondo): cabecera, columna de secciones, vista
 * previa fija al costado (en un diálogo en pantallas chicas), pie con
 * Cancelar / Guardar y su mensaje, y la guardia de salida con cambios sin
 * guardar (el diálogo de descartar y el aviso del navegador al cerrar).
 *
 * No sabe de reglas ni de qué se edita: el formulario le dice si hay cambios
 * (`dirty`), qué mensaje mostrar y qué hacer al guardar. `CreatureForm` no lo
 * usa: lleva pestañas y su vista previa es otra.
 *
 * ponytail: Flutter abre un panel de reglas al tocar un campo (qué significa
 * ese número en el juego); en React todavía no existe y sirve a todos los
 * formularios, así que pide su propio diseño. Cuando llegue, se suma acá.
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
