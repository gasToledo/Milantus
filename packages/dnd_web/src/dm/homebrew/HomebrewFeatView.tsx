import { useRef, type MutableRefObject } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { saveHomebrew } from '../../api/homebrew';
import { queryKeys, useSheetCatalog } from '../../api/queries';
import { homebrewCopy, homebrewId, featNew, type JsonObject } from '../../engine';
import { useLang, useTexts } from '../../i18n/context';
import { dmHomebrewHref, navigate } from '../../router';
import { showNotice } from '../../ui/notices';
import { AppBusyLabel, AppErrorView, Notice } from '../../ui/status';
import { DmHeader } from '../DmHeader';
import { FeatForm } from './FeatForm';

/** Adónde se vuelve al salir: una dote que se edita, a su detalle; una nueva
 *  (vacía o copia), a la lista de dotes propias. */
export const featEditorExit = (featId: string | null): string =>
  featId === null ? dmHomebrewHref('feats') : dmHomebrewHref('feats', featId);

/** Lo que se edita: la dote de partida y cómo se llama la pantalla. */
interface Start {
  initial: JsonObject;
  title: string;
  kicker?: string;
}

/**
 * El editor de una dote propia del Homebrew (`/dm/homebrew/dotes/nueva` y
 * `/dm/homebrew/dotes/<id>/editar`). Tres entradas, como las criaturas:
 *
 * - **Nueva**: la plantilla del motor (`featNew`); al guardar toma su id del nombre.
 * - **Copia** (`?de=<id>`, de una propia o de una oficial): `homebrewCopy` del
 *   motor; el kicker dice de cuál.
 * - **Editar**: solo una dote que es de esta cuenta. Una ajena, una inexistente
 *   y una oficial dicen lo mismo, «No se encontró»: nunca un formulario vacío.
 *
 * Guardar es un `PUT` y vuelve al detalle de la dote en Homebrew › Dotes.
 */
export function HomebrewFeatView({ featId, leaveRef }: { featId: string | null; leaveRef: MutableRefObject<(() => void) | null> }) {
  const t = useTexts();
  const lang = useLang();
  const client = useQueryClient();
  const catalog = useSheetCatalog(lang);
  // La copia lleva un id con la hora: se calcula **una vez** y el formulario ve
  // siempre la misma dote, aunque el catálogo se relea mientras se edita.
  const start = useRef<Start | 'missing' | null>(null);
  const from = useRef(new URLSearchParams(window.location.search).get('de'));

  const failed = catalog.queries.filter((q) => q.isError);
  if (failed.length > 0) {
    return <AppErrorView as="h1" title={t.dmHomebrewReadFail} message={t.errorBody} onRetry={() => failed.forEach((q) => q.refetch())} />;
  }
  if (!catalog.data) {
    return (
      <>
        <DmHeader title={t.hbNewFeat} />
        <AppBusyLabel label={t.dmHomebrewLoading} />
      </>
    );
  }
  const data = catalog.data;
  if (start.current === null) {
    const find = (id: string) => data.feats.find((f) => f.id === id);
    if (featId !== null) {
      const own = find(featId);
      start.current = own?.source === 'homebrew' ? { initial: own, title: String(own.name ?? '') } : 'missing';
    } else if (from.current) {
      const original = find(from.current);
      start.current = original
        ? { initial: homebrewCopy(original), title: t.hbNewFeat, kicker: t.hbCopyOf(String(original.name ?? '')) }
        : 'missing';
    } else {
      start.current = { initial: featNew(), title: t.hbNewFeat };
    }
  }
  if (start.current === 'missing') return <Notice title={t.hbFeatNotFound} body={t.hbFeatNotFoundBody} />;
  const { initial, title, kicker } = start.current;

  const save = async (feat: JsonObject) => {
    const name = String(feat.name ?? '');
    // La plantilla y la copia traen un id provisorio: el definitivo sale del nombre.
    const id = featId === null ? homebrewId(name) : String(feat.id);
    await saveHomebrew('feats', { ...feat, id });
    // El catálogo se arma con el homebrew: hasta releerlo, el detalle al que se
    // vuelve no encontraría la dote.
    await client.invalidateQueries({ queryKey: queryKeys.homebrew });
    showNotice(t.hbSaved(name));
    navigate(dmHomebrewHref('feats', id));
  };

  return <FeatForm initial={initial} catalog={data} title={title} kicker={kicker} exitHref={featEditorExit(featId)} onSave={save} leaveRef={leaveRef} />;
}
