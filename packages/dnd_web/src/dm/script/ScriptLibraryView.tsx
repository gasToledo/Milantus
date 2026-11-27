import { useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { ArrowLeft, Copy, Pencil, Plus, Search, Trash2 } from 'lucide-react';
import { ApiError, createScript, deleteScript, duplicateScript, type DmScript, type DmStoredScript } from '../../api/client';
import { queryKeys, useScript, useScripts } from '../../api/queries';
import { dropScriptSave, flushScriptSave } from '../../api/scriptSave';
import { fold } from '../../codex/entries';
import { scriptNew } from '../../engine';
import { useTexts } from '../../i18n/context';
import { dmScriptsHref, Link, navigate } from '../../router';
import { Button } from '../../ui/Button';
import { ConfirmDialog } from '../../ui/ConfirmDialog';
import { useDeferredFocus } from '../../ui/focus';
import { Toast, Tooltip } from '../../ui/primitives';
import { AppBusyLabel, AppEmptyState, AppErrorView } from '../../ui/status';
import { DmHeader } from '../DmHeader';
import { LibraryTabs } from '../LibraryTabs';
import { MoreMenu } from './MilestoneCard';
import { ScriptNameDialog } from './ScriptDialogs';
import { ScriptEditor } from './ScriptEditor';
import { useScriptWriter } from './scriptWriter';

export function ScriptLibraryView({ scriptId }: { scriptId: string | null }) {
  return scriptId === null ? <ScriptList /> : <ScriptPage id={scriptId} />;
}

const countMilestones = (script: DmScript) => script.steps.reduce((n, s) => n + (s.type === 'fork' ? s.paths.length : 1), 0);

// La lista sigue a la de Escenarios: la misma cabecera y el buscador en pill.
function ScriptList() {
  const t = useTexts();
  const client = useQueryClient();
  const scripts = useScripts();
  const [query, setQuery] = useState('');
  const [creating, setCreating] = useState(false);
  const [deleting, setDeleting] = useState<DmStoredScript | null>(null);
  const [failures, setFailures] = useState(0);
  const setFocusTarget = useDeferredFocus(scripts.data);

  const refresh = () => client.invalidateQueries({ queryKey: queryKeys.scripts });
  const visible = scripts.data?.filter((s) => fold(s.script.name).includes(fold(query.trim())));

  const duplicate = async ({ script }: DmStoredScript) => {
    try {
      await flushScriptSave(script.id);
      await duplicateScript(script.id, { id: crypto.randomUUID(), name: t.scCopyName(script.name) });
      await refresh();
    } catch {
      setFailures((n) => n + 1);
    }
  };
  const remove = async (id: string) => {
    // Un guardado pendiente no puede llegar después del borrado.
    await dropScriptSave(id);
    await deleteScript(id);
    client.setQueryData<DmStoredScript[]>(queryKeys.scripts, (old) => old?.filter((s) => s.script.id !== id));
    client.removeQueries({ queryKey: queryKeys.script(id) });
    void refresh();
    // Los capítulos que lo usaban se quedaron sin guion.
    void client.invalidateQueries({ queryKey: queryKeys.dmCampaigns });
    setFocusTarget('[data-dm-title]');
  };

  const create = (
    <Button icon={Plus} data-action="new-script" onClick={() => setCreating(true)}>
      {t.scNewScript}
    </Button>
  );
  const empty = scripts.data?.length === 0;

  return (
    <div className="flex flex-col gap-5">
      <DmHeader title={t.dmLibrary} actions={scripts.data && !empty ? create : undefined} />
      <LibraryTabs active="scripts">
        {scripts.isError ? (
          <AppErrorView title={t.scReadFail} message={t.errorBody} onRetry={() => scripts.refetch()} />
        ) : !visible ? (
          <AppBusyLabel label={t.scLoading} />
        ) : empty ? (
          <AppEmptyState kind="empty" message={t.scScriptsEmpty} actions={create} />
        ) : (
          <>
            <div role="search" className="relative w-full max-w-[280px]">
              <label htmlFor="script-search" className="sr-only">
                {t.dmSearchByName}
              </label>
              <Search size={16} aria-hidden="true" className="pointer-events-none absolute top-2.5 left-3 text-text-muted" />
              <input
                id="script-search"
                type="search"
                autoComplete="off"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder={t.dmSearchByName}
                className="h-9 w-full rounded-[var(--radius-pill)] border border-hairline bg-plaque pr-3 pl-9 text-[13px] text-on-surface placeholder:text-text-muted"
              />
            </div>
            {visible.length === 0 ? (
              <AppEmptyState
                kind="no-match"
                message={t.scScriptsNoMatch(query.trim())}
                actions={
                  <Button tone="secondary" onClick={() => setQuery('')}>
                    {t.codexClearFilters}
                  </Button>
                }
              />
            ) : (
              <ul aria-label={t.scLibraryTab} className="grid grid-cols-[repeat(auto-fill,minmax(min(280px,100%),1fr))] gap-3.5">
                {visible.map((stored) => (
                  <li key={stored.script.id} className="card roster-card relative flex min-w-0 items-start gap-2 p-3.5" data-script={stored.script.id}>
                    <div className="flex min-w-0 flex-1 flex-col gap-1">
                      {/* El `::after` estira el enlace a toda la tarjeta. */}
                      <Link
                        href={dmScriptsHref(stored.script.id)}
                        className="font-display text-[17px] leading-tight break-words text-on-surface after:absolute after:inset-0 after:rounded-[var(--radius-card)]"
                      >
                        {stored.script.name}
                      </Link>
                      <span className="text-[12.5px] text-text-muted">
                        {t.scCardLine(countMilestones(stored.script), stored.campaigns)}
                      </span>
                    </div>
                    <MoreMenu
                      label={t.scScriptOptions}
                      action="script-menu"
                      className="relative z-10 -mt-1 -mr-1"
                      items={[
                        { label: t.scDuplicate, icon: Copy, onSelect: () => void duplicate(stored) },
                        { label: t.commonDelete, icon: Trash2, danger: true, onSelect: () => setDeleting(stored) },
                      ]}
                    />
                  </li>
                ))}
              </ul>
            )}
          </>
        )}
      </LibraryTabs>
      {creating && (
        <ScriptNameDialog
          title={t.scNewScript}
          confirmLabel={t.scCreate}
          onSubmit={async (name) => {
            const script = await createScript(scriptNew(crypto.randomUUID(), name));
            void refresh();
            navigate(dmScriptsHref(script.id));
          }}
          onClose={() => setCreating(false)}
        />
      )}
      {deleting && (
        <ConfirmDialog
          title={t.scDeleteScriptTitle(deleting.script.name)}
          body={t.scDeleteScriptBody(deleting.campaigns)}
          confirmLabel={t.scDeleteScript}
          errorText={t.scActionError}
          onConfirm={() => remove(deleting.script.id)}
          onClose={() => setDeleting(null)}
        />
      )}
      {failures > 0 && (
        <Toast key={failures} tone="error" message={t.scActionError} open onOpenChange={(o) => !o && setFailures(0)} />
      )}
    </div>
  );
}

/** Un guion abierto desde la Biblioteca: el mismo editor, sin capítulo. */
function ScriptPage({ id }: { id: string }) {
  const t = useTexts();
  const client = useQueryClient();
  const query = useScript(id);
  const [renaming, setRenaming] = useState(false);
  const [renameFailed, setRenameFailed] = useState(false);
  const writer = useScriptWriter(id, () => setRenameFailed(true));

  const back = (
    <Link back href={dmScriptsHref()} className="inline-flex items-center gap-1.5 self-start text-[13px] text-on-surface-variant hover:text-gold">
      <ArrowLeft size={16} aria-hidden="true" className="text-gold" />
      {t.luBack}
    </Link>
  );

  if (!query.data) {
    return (
      <div className="flex flex-col gap-4">
        {back}
        {query.isError ? (
          <AppErrorView
            as="h1"
            title={query.error instanceof ApiError && query.error.status === 404 ? t.scNotFound : t.scReadFail}
            onRetry={() => query.refetch()}
          />
        ) : (
          <>
            <h1 className="sr-only">{t.scLibraryTab}</h1>
            <AppBusyLabel label={t.scLoading} />
          </>
        )}
      </div>
    );
  }

  const { script, campaigns } = query.data;
  return (
    <>
      <ScriptEditor
        script={script}
        campaigns={campaigns}
        view={null}
        chapter={null}
        onDuplicated={async (copy) => {
          await client.invalidateQueries({ queryKey: queryKeys.scripts });
          navigate(dmScriptsHref(copy.id));
        }}
        layout={(actions, body) => (
          <div className="flex flex-col gap-5">
            {back}
            <DmHeader
              title={script.name}
              actions={
                <>
                  <Tooltip content={t.scRename}>
                    <button
                      type="button"
                      aria-label={t.scRename}
                      data-action="rename-script"
                      onClick={() => setRenaming(true)}
                      className="inline-flex size-11 shrink-0 items-center justify-center rounded-[var(--radius-nav)] text-text-muted hover:text-gold"
                    >
                      <Pencil size={18} aria-hidden="true" />
                    </button>
                  </Tooltip>
                  {actions}
                </>
              }
            />
            {body}
          </div>
        )}
      />
      {renaming && (
        <ScriptNameDialog
          title={t.scRename}
          initial={script.name}
          confirmLabel={t.commonSave}
          onSubmit={async (name) => {
            if (!writer.edit({ type: 'setName', name })) throw new Error('El motor rechazó el nombre');
          }}
          onClose={() => setRenaming(false)}
        />
      )}
      {renameFailed && (
        <Toast tone="error" message={t.scSaveError} open onOpenChange={(o) => !o && setRenameFailed(false)} />
      )}
    </>
  );
}
