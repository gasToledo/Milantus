import { useState } from 'react';
import { useTexts } from '../../i18n/context';
import { AppDialog } from '../../ui/AppDialog';
import { AppBusyLabel, AppErrorView } from '../../ui/status';
import { Option, SearchableList } from '../../ui/wizard';

export interface PickItem {
  id: string;
  title: string;
  detail?: string;
}

/**
 * Marcar varios y sumarlos, sobre `AppDialog`. Lo comparten «Traer de la
 * biblioteca» y «Sumar a una campaña». Si [onSubmit] falla no se cierra y el
 * botón pasa a «Reintentar». Lo marcado sobrevive al buscador.
 */
export function PickManyDialog({
  title,
  searchLabel,
  items,
  loading,
  onRetryLoad,
  loadError,
  emptyText,
  errorText,
  onSubmit,
  onClose,
}: {
  title: string;
  /** Con esto lleva buscador. Sin esto es una lista simple: las campañas son pocas. */
  searchLabel?: string;
  items: PickItem[];
  loading: boolean;
  loadError?: string;
  onRetryLoad?: () => void;
  emptyText: string;
  errorText: string;
  onSubmit: (ids: string[]) => Promise<void>;
  onClose: () => void;
}) {
  const t = useTexts();
  const [picked, setPicked] = useState<ReadonlySet<string>>(new Set());
  const [busy, setBusy] = useState(false);
  const [failed, setFailed] = useState(false);

  const toggle = (id: string) =>
    setPicked((old) => {
      const next = new Set(old);
      if (!next.delete(id)) next.add(id);
      return next;
    });

  const submit = async () => {
    if (busy || picked.size === 0) return;
    setBusy(true);
    try {
      await onSubmit([...picked]);
      onClose();
    } catch {
      setFailed(true);
      setBusy(false);
    }
  };

  const option = (item: PickItem) => (
    <Option key={item.id} id={item.id} multi selected={picked.has(item.id)} title={item.title} detail={item.detail} onClick={() => toggle(item.id)} />
  );

  let body;
  if (loadError) body = <AppErrorView title={loadError} message={t.errorBody} onRetry={onRetryLoad} />;
  else if (loading) body = <AppBusyLabel label={t.dmNpcsLoading} />;
  else if (items.length === 0) body = <p className="text-on-surface-variant">{emptyText}</p>;
  else if (searchLabel)
    body = (
      <SearchableList items={items} textOf={(i) => i.title} label={searchLabel} multi empty={t.dmNoMatchesShort}>
        {option}
      </SearchableList>
    );
  else
    body = (
      <div role="group" aria-label={title} className="grid gap-2">
        {items.map(option)}
      </div>
    );

  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={title}
      actions={[
        { label: t.cancel },
        {
          label: failed ? t.retry : picked.size <= 1 ? t.dmAddShort : t.dmAddCount(picked.size),
          primary: true,
          closes: false,
          disabled: busy || picked.size === 0,
          onSelect: () => void submit(),
        },
      ]}
    >
      <div className="flex flex-col gap-3">
        {body}
        {failed && (
          <p role="alert" className="text-[13px] text-crimson">
            {errorText}
          </p>
        )}
      </div>
    </AppDialog>
  );
}
