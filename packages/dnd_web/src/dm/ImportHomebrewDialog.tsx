import { useEffect, useMemo, useRef, useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { CircleAlert, TriangleAlert, Upload } from 'lucide-react';
import { ApiError } from '../api/client';
import { CATEGORIES, importHomebrew, type Category } from '../api/homebrew';
import { queryKeys, useSheetCatalog } from '../api/queries';
import { homebrewImportCheck, type HomebrewImportCheck } from '../engine';
import { useLang, useTexts } from '../i18n/context';
import { AppDialog } from '../ui/AppDialog';
import { showNotice } from '../ui/notices';
import { AppBusyLabel } from '../ui/status';

/**
 * «Importar homebrew» (`_importHomebrew` de Flutter), con vista previa. Elegir el
 * archivo abre esto: el motor lo lee y lo valida en el navegador contra el
 * catálogo fusionado (`homebrewImportCheck`), sin pedirle nada al servidor, y
 * recién «Importar» escribe algo. Si el archivo pisa entradas propias, la
 * pregunta de Flutter («¿Sobrescribir?») queda dentro del mismo diálogo: el aviso
 * y el botón pasan a carmesí. Un archivo inválido muestra el mensaje del motor y
 * no ofrece importar.
 *
 * Si el servidor falla el diálogo queda abierto con la vista previa y
 * «Reintentar»: guarda todo o nada, así que reintentar no duplica.
 */
export function ImportHomebrewDialog({ file, onClose }: { file: File; onClose: () => void }) {
  const t = useTexts();
  const lang = useLang();
  const client = useQueryClient();
  const catalog = useSheetCatalog(lang);
  const [text, setText] = useState<string | null>(null);
  const [unreadable, setUnreadable] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string>();
  const closed = useRef(false);
  useEffect(() => () => void (closed.current = true), []);

  useEffect(() => {
    let current = true;
    file
      .text()
      .then((value) => current && setText(value))
      .catch(() => current && setUnreadable(true));
    return () => void (current = false);
  }, [file]);

  const check = useMemo<HomebrewImportCheck | null>(() => {
    if (unreadable) return { ok: false, error: t.hbImportFailed };
    return text !== null && catalog.data ? homebrewImportCheck(text, catalog.data) : null;
  }, [text, catalog.data, unreadable, t]);

  const submit = async () => {
    if (!check?.ok || busy) return;
    setBusy(true);
    setError(undefined);
    try {
      const count = await importHomebrew(check.content);
      // El catálogo fusionado se arma con el homebrew: sin releerlo, lo importado
      // no aparecería en el Bestiario ni en las fichas.
      await client.invalidateQueries({ queryKey: queryKeys.homebrew });
      showNotice(t.hbImported(count));
      onClose();
    } catch (e) {
      if (closed.current) return;
      setError(e instanceof ApiError && e.detail ? e.detail : t.hbImportFailed);
      setBusy(false);
    }
  };

  const label = (c: Category) =>
    c === 'items' ? t.hbCategoryItems : c === 'creatures' ? t.dmHomebrewCreatures : t.codexCategories[c];
  const rows = check?.ok ? CATEGORIES.filter((c) => check.counts[c] > 0) : [];
  const total = check?.ok ? rows.reduce((n, c) => n + check.counts[c], 0) : 0;
  const collisions = check?.ok ? check.collisions : 0;
  const problem = check && !check.ok ? check.error : undefined;
  const overwrite = collisions > 0;

  return (
    <AppDialog
      open
      onOpenChange={(open) => {
        if (!open && !busy) onClose();
      }}
      title={t.hbImportTitle}
      icon={Upload}
      actions={[
        { label: t.cancel, disabled: busy },
        {
          label: error ? t.retry : overwrite ? t.hbOverwrite : t.transferConfirm,
          primary: true,
          tone: overwrite ? 'crimson' : undefined,
          closes: false,
          disabled: !check?.ok || total === 0 || busy,
          onSelect: () => void submit(),
        },
      ]}
    >
      <div className="flex flex-col gap-3">
        <span className="text-[13px] break-all text-text-muted">{file.name}</span>

        {!check && <AppBusyLabel label={t.dmHomebrewLoading} />}

        {check?.ok && (
          <>
            <span className="text-[11px] tracking-[0.14em] text-text-muted uppercase">{t.hbImportBrings(total)}</span>
            <ul className="plaque flex flex-col rounded-[var(--radius-card)] border border-hairline py-1" data-field="homebrew-import-preview">
              {rows.map((c) => (
                <li key={c} className="flex items-baseline gap-2.5 px-3.5 py-2" data-category={c}>
                  <span className="text-[14px] text-on-surface">{label(c)}</span>
                  <span className="min-w-0 flex-1 truncate text-[12.5px] text-text-muted">{check.names[c].join(', ')}</span>
                  <span className="num min-w-[18px] text-right text-[14px] font-bold text-on-surface">{check.counts[c]}</span>
                </li>
              ))}
            </ul>
          </>
        )}

        {overwrite && (
          <p role="alert" className="flex items-start gap-2 text-[13px] leading-normal text-crimson">
            <TriangleAlert size={16} aria-hidden="true" className="mt-0.5 shrink-0" />
            {t.hbImportCollide(collisions)}
          </p>
        )}

        {problem && (
          <p role="alert" className="flex items-start gap-2 text-[13px] leading-normal text-crimson">
            <CircleAlert size={16} aria-hidden="true" className="mt-0.5 shrink-0" />
            {problem}
          </p>
        )}

        {busy && <AppBusyLabel label={t.hbImporting} />}

        {error && (
          <p role="alert" className="flex items-start gap-2 text-[13px] leading-normal text-crimson">
            <CircleAlert size={16} aria-hidden="true" className="mt-0.5 shrink-0" />
            {error}
          </p>
        )}
      </div>
    </AppDialog>
  );
}
