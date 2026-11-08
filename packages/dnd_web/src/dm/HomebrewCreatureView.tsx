import { useRef, type MutableRefObject } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { saveHomebrew } from '../api/homebrew';
import { queryKeys, useSheetCatalog } from '../api/queries';
import { homebrewCopy, homebrewId, homebrewNewCreature, type JsonObject } from '../engine';
import { useLang, useTexts } from '../i18n/context';
import { dmBestiaryHref, dmHomebrewHref, navigate } from '../router';
import { showNotice } from '../ui/notices';
import { AppBusyLabel, AppErrorView, Notice } from '../ui/status';
import { DmHeader } from './DmHeader';
import { CreatureForm } from './npcs/CreatureForm';

/** Adónde se vuelve al salir: una criatura que se edita, a su perfil; una nueva
 *  (vacía o copia), a la lista de criaturas propias. */
export const creatureEditorExit = (creatureId: string | null): string =>
  creatureId === null ? dmHomebrewHref('creatures') : dmBestiaryHref(creatureId);

/** Lo que se edita: el bloque de partida y cómo se llama la pantalla. */
interface Start {
  initial: JsonObject;
  title: string;
  kicker?: string;
}

/**
 * El editor de una criatura propia del Homebrew (`/dm/homebrew/criaturas/nueva`
 * y `/dm/homebrew/criaturas/<id>/editar`): el `CreatureForm` de los PNJ de
 * bloque, con otra salida. Tres entradas:
 *
 * - **Nueva**: el bloque vacío del motor; al guardar se le da su id (`homebrewId`).
 * - **Copia** (`?de=<id>`, de una propia o de una oficial): `homebrewCopy` del
 *   motor, con id y nombre nuevos; el kicker dice de cuál.
 * - **Editar**: solo una criatura que es de esta cuenta. Una ajena, una
 *   inexistente y una oficial dicen lo mismo, «No se encontró»: nunca un
 *   formulario vacío.
 *
 * Guardar es un `PUT` y vuelve al perfil de la criatura en el Bestiario del DM.
 */
export function HomebrewCreatureView({ creatureId, leaveRef }: { creatureId: string | null; leaveRef: MutableRefObject<(() => void) | null> }) {
  const t = useTexts();
  const lang = useLang();
  const client = useQueryClient();
  const catalog = useSheetCatalog(lang);
  // La copia lleva un id con la hora: se calcula **una vez** y el formulario
  // ve siempre el mismo bloque, aunque el catálogo se relea mientras se edita.
  const start = useRef<Start | 'missing' | null>(null);
  const from = useRef(new URLSearchParams(window.location.search).get('de'));

  const failed = catalog.queries.filter((q) => q.isError);
  if (failed.length > 0) {
    return <AppErrorView as="h1" title={t.dmHomebrewReadFail} message={t.errorBody} onRetry={() => failed.forEach((q) => q.refetch())} />;
  }
  if (!catalog.data) {
    return (
      <>
        <DmHeader title={t.hbNewCreature} />
        <AppBusyLabel label={t.dmHomebrewLoading} />
      </>
    );
  }
  const data = catalog.data;
  if (start.current === null) {
    const find = (id: string) => data.creatures.find((c) => c.id === id);
    if (creatureId !== null) {
      const own = find(creatureId);
      start.current = own?.source === 'homebrew' ? { initial: own, title: String(own.name ?? '') } : 'missing';
    } else if (from.current) {
      const original = find(from.current);
      start.current = original
        ? { initial: homebrewCopy(original), title: t.hbNewCreature, kicker: t.hbCopyOf(String(original.name ?? '')) }
        : 'missing';
    } else {
      start.current = { initial: homebrewNewCreature(), title: t.hbNewCreature };
    }
  }
  if (start.current === 'missing') return <Notice title={t.hbCreatureNotFound} body={t.hbCreatureNotFoundBody} />;
  const { initial, title, kicker } = start.current;

  const save = async (creature: JsonObject) => {
    const name = String(creature.name ?? '');
    // La plantilla vacía trae un id provisorio: el definitivo sale del nombre.
    const id = creature.id === initial.id && creatureId === null && !from.current ? homebrewId(name) : String(creature.id);
    await saveHomebrew('creatures', { ...creature, id });
    // El catálogo se arma con el homebrew: hasta releerlo, el perfil al que se
    // vuelve no encontraría la criatura.
    await client.invalidateQueries({ queryKey: queryKeys.homebrew });
    showNotice(t.hbSaved(name));
    navigate(dmBestiaryHref(id));
  };

  return (
    <CreatureForm
      initial={initial}
      catalog={data}
      title={title}
      kicker={kicker}
      exitHref={creatureEditorExit(creatureId)}
      onSave={save}
      saveFailedText={t.hbSaveError}
      leaveRef={leaveRef}
    />
  );
}
