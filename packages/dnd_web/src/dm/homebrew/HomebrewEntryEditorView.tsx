import { useRef, type MutableRefObject } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { saveHomebrew } from '../../api/homebrew';
import { queryKeys, useSheetCatalog } from '../../api/queries';
import { armorNew, backgroundNew, featNew, homebrewCopy, homebrewId, raceNew, weaponNew, type Catalog, type JsonObject } from '../../engine';
import { useLang, useTexts } from '../../i18n/context';
import type { Texts } from '../../i18n/texts';
import { dmHomebrewHref, navigate } from '../../router';
import { showNotice } from '../../ui/notices';
import { AppBusyLabel, AppErrorView, Notice } from '../../ui/status';
import { DmHeader } from '../DmHeader';
import { ArmorForm } from './ArmorForm';
import { BackgroundForm } from './BackgroundForm';
import { FeatForm } from './FeatForm';
import { RaceForm } from './RaceForm';
import { WeaponForm } from './WeaponForm';

/** Las categorías de entrada propia que se editan con un formulario con vista previa. */
export type EntryCategory = 'feats' | 'races' | 'backgrounds' | 'weapons' | 'armor';

/** Adónde se vuelve al salir: una entrada que se edita, a su detalle; una nueva
 *  (vacía o copia), a la lista de su categoría. */
export const entryEditorExit = (category: EntryCategory, entryId: string | null): string =>
  entryId === null ? dmHomebrewHref(category) : dmHomebrewHref(category, entryId);

/** Lo que cambia de una categoría a otra: de dónde sale la plantilla y cómo se llama. */
const KINDS: Record<
  EntryCategory,
  {
    template: () => JsonObject;
    list: (catalog: Catalog) => JsonObject[];
    newTitle: (t: Texts) => string;
    notFound: (t: Texts) => [string, string];
  }
> = {
  feats: {
    template: featNew,
    list: (c) => c.feats,
    newTitle: (t) => t.hbNewFeat,
    notFound: (t) => [t.hbFeatNotFound, t.hbFeatNotFoundBody],
  },
  races: {
    template: raceNew,
    list: (c) => c.races,
    newTitle: (t) => t.hbNewRace,
    notFound: (t) => [t.hbRaceNotFound, t.hbRaceNotFoundBody],
  },
  backgrounds: {
    template: backgroundNew,
    list: (c) => c.backgrounds,
    newTitle: (t) => t.hbNewBackground,
    notFound: (t) => [t.hbBackgroundNotFound, t.hbBackgroundNotFoundBody],
  },
  weapons: {
    template: weaponNew,
    list: (c) => c.weapons,
    newTitle: (t) => t.hbNewWeapon,
    notFound: (t) => [t.hbWeaponNotFound, t.hbWeaponNotFoundBody],
  },
  armor: {
    template: armorNew,
    list: (c) => c.armor,
    newTitle: (t) => t.hbNewArmor,
    notFound: (t) => [t.hbArmorNotFound, t.hbArmorNotFoundBody],
  },
};

/** Lo que se edita: la entrada de partida y cómo se llama la pantalla. */
interface Start {
  initial: JsonObject;
  title: string;
  kicker?: string;
}

/**
 * El editor de una dote, especie, trasfondo, arma o armadura propia del Homebrew
 * (`/dm/homebrew/<categoría>/nueva` y `/dm/homebrew/<categoría>/<id>/editar`).
 * Tres entradas, como las criaturas:
 *
 * - **Nueva**: la plantilla del motor; al guardar toma su id del nombre.
 * - **Copia** (`?de=<id>`, de una propia o de una oficial): `homebrewCopy` del
 *   motor; el kicker dice de cuál.
 * - **Editar**: solo una entrada que es de esta cuenta. Una ajena, una
 *   inexistente y una oficial dicen lo mismo, «No se encontró»: nunca un
 *   formulario vacío.
 *
 * Guardar es un `PUT` y vuelve al detalle de la entrada en su categoría.
 */
export function HomebrewEntryEditorView({
  category,
  entryId,
  leaveRef,
}: {
  category: EntryCategory;
  entryId: string | null;
  leaveRef: MutableRefObject<(() => void) | null>;
}) {
  const t = useTexts();
  const lang = useLang();
  const client = useQueryClient();
  const catalog = useSheetCatalog(lang);
  const kind = KINDS[category];
  // La copia lleva un id con la hora: se calcula **una vez** y el formulario ve
  // siempre la misma entrada, aunque el catálogo se relea mientras se edita.
  const start = useRef<Start | 'missing' | null>(null);
  const from = useRef(new URLSearchParams(window.location.search).get('de'));

  const failed = catalog.queries.filter((q) => q.isError);
  if (failed.length > 0) {
    return <AppErrorView as="h1" title={t.dmHomebrewReadFail} message={t.errorBody} onRetry={() => failed.forEach((q) => q.refetch())} />;
  }
  if (!catalog.data) {
    return (
      <>
        <DmHeader title={kind.newTitle(t)} />
        <AppBusyLabel label={t.dmHomebrewLoading} />
      </>
    );
  }
  const data = catalog.data;
  if (start.current === null) {
    const find = (id: string) => kind.list(data).find((e) => e.id === id);
    if (entryId !== null) {
      const own = find(entryId);
      start.current = own?.source === 'homebrew' ? { initial: own, title: String(own.name ?? '') } : 'missing';
    } else if (from.current) {
      const original = find(from.current);
      start.current = original
        ? { initial: homebrewCopy(original), title: kind.newTitle(t), kicker: t.hbCopyOf(String(original.name ?? '')) }
        : 'missing';
    } else {
      start.current = { initial: kind.template(), title: kind.newTitle(t) };
    }
  }
  if (start.current === 'missing') {
    const [title, body] = kind.notFound(t);
    return <Notice title={title} body={body} />;
  }
  const { initial, title, kicker } = start.current;

  const save = async (entry: JsonObject) => {
    const name = String(entry.name ?? '');
    // La plantilla y la copia traen un id provisorio: el definitivo sale del nombre.
    const id = entryId === null ? homebrewId(name) : String(entry.id);
    await saveHomebrew(category, { ...entry, id });
    // El catálogo se arma con el homebrew: hasta releerlo, el detalle al que se
    // vuelve no encontraría la entrada.
    await client.invalidateQueries({ queryKey: queryKeys.homebrew });
    showNotice(t.hbSaved(name));
    navigate(dmHomebrewHref(category, id));
  };

  const props = { initial, catalog: data, title, kicker, exitHref: entryEditorExit(category, entryId), onSave: save, leaveRef };
  if (category === 'races') return <RaceForm {...props} />;
  if (category === 'backgrounds') return <BackgroundForm {...props} />;
  if (category === 'weapons') return <WeaponForm {...props} />;
  if (category === 'armor') return <ArmorForm {...props} />;
  return <FeatForm {...props} />;
}
