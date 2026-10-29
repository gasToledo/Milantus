import { useMemo } from 'react';
import { ScrollText } from 'lucide-react';
import { useAppVersion, useCatalog, useRoster } from '../api/queries';
import { computeSheet, type CharacterFields } from '../engine';
import { useLang, useTexts } from '../i18n/context';
import { rosterHref } from '../router';
import { NavGroup, NavItem, Shell, SidebarBack, ThemeMenu, VersionLabel } from '../ui/Shell';
import { AppBusyLabel, AppErrorView, Notice } from '../ui/status';
import { CharacterSheet } from './CharacterSheet';

/**
 * La ficha de [id]. La API no tiene `GET` por id (el cliente de Flutter
 * tampoco: carga la lista), así que se busca en `/api/characters`; con la
 * caché, si se viene del dashboard, ni siquiera se vuelve a pedir. Lo ajeno y
 * lo inexistente son lo mismo para la API; acá también.
 */
export function CharacterPage({ id }: { id: string }) {
  const t = useTexts();
  const lang = useLang();
  const roster = useRoster();
  const catalog = useCatalog(lang);
  const version = useAppVersion(true);

  const raw = roster.data?.find((c) => c.character.id === id)?.character ?? null;
  // La ficha se calcula con el motor de Dart compilado a JS: el mismo que usan
  // el servidor y Flutter. Acá no se recalcula ninguna regla.
  const computed = useMemo(() => {
    if (!raw || !catalog.data) return null;
    try {
      return { ok: true as const, sheet: computeSheet(raw, catalog.data) };
    } catch (e) {
      return { ok: false as const, detail: String(e) };
    }
  }, [raw, catalog.data]);

  const failed = [roster, catalog].filter((q) => q.isError);
  let body;
  if (failed.length > 0) {
    body = (
      <AppErrorView as="h1" title={t.errorTitle} message={t.errorBody} onRetry={() => failed.forEach((q) => q.refetch())} />
    );
  } else if (roster.data && !raw) {
    body = <Notice title={t.notFoundTitle} body={t.notFoundBody} />;
  } else if (!computed) {
    body = <AppBusyLabel label={t.loading} />;
  } else if (!computed.ok) {
    // Un esquema más nuevo que este cliente, o una ficha que el motor no
    // entiende: se dice, en vez de mostrar números a medias.
    body = <AppErrorView as="h1" title={t.computeErrorTitle} message={t.computeErrorBody} detail={computed.detail} />;
  } else {
    body = (
      <CharacterSheet
        // `raw` es un `Character.toJson` que el servidor ya validó al guardarlo;
        // `CharacterFields` es el subconjunto que esta pantalla lee.
        character={raw as unknown as CharacterFields}
        sheet={computed.sheet}
        catalog={catalog.data!}
      />
    );
  }

  return (
    <Shell
      panel={
        <>
          <SidebarBack href={rosterHref()} label={t.backToCharacters} />
          <NavGroup label={t.sheetNavLabel}>
            <li>
              <NavItem href="#contenido" icon={ScrollText} label={t.navSheet} active />
            </li>
          </NavGroup>
        </>
      }
      footer={
        <div className="flex items-center justify-between gap-2">
          <ThemeMenu />
          <VersionLabel version={version.data} />
        </div>
      }
    >
      {body}
    </Shell>
  );
}
