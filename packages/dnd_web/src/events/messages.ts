import { chapterGrants } from '../engine';
import type { UserEvent } from '../api/client';
import type { Texts } from '../i18n/texts';
import type { ToastTone } from '../ui/primitives';

/**
 * Catálogo de los mensajes de aviso (`messageForEvent` de Flutter). El servidor
 * guarda **qué pasó** (`kind` y el `payload`) y esto decide **cómo se dice**:
 * corregir una redacción es cambiar una línea acá, no migrar lo guardado.
 *
 * Un `kind` desconocido devuelve `null` en vez de romper: si el servidor se
 * actualiza antes que la pestaña abierta, el aviso se ignora en silencio.
 */
export function eventMessage(event: UserEvent, t: Texts): { text: string; tone: ToastTone } | null {
  const character = quoted(event.payload.characterName, t);
  const campaign = quoted(event.payload.campaignName, t, t.evtSomeCampaign);

  switch (event.kind) {
    case 'character_linked':
      return { text: t.evtLinked(character, campaign), tone: 'success' };
    case 'character_unlinked_by_dm':
      return { text: t.evtUnlinkedByDm(character, campaign), tone: 'info' };
    case 'character_unlinked_by_owner':
      return { text: t.evtUnlinkedByOwner(character, campaign), tone: 'info' };
    case 'character_deleted_by_owner':
      return { text: t.evtDeletedByOwner(character, campaign), tone: 'info' };
    // Informativo y no de alerta: el personaje sigue en la mesa, solo que con
    // otra ficha.
    case 'character_rebuilt':
      return { text: t.evtRebuiltByOwner(character, campaign), tone: 'info' };
    // El DM no le marcó nada en la ficha: el mensaje tiene que decirlo, o el
    // jugador espera encontrar la estrella ya prendida.
    case 'heroic_inspiration_granted':
      return { text: t.evtInspiration(campaign, character), tone: 'success' };
    case 'chapter_completed':
      return chapterCompleted(event, character, campaign, t);
    // Solo quién y dónde: lo que pasó en el combate es del Cuaderno del DM.
    case 'encounter_finished':
      return { text: t.evtCombatDone(character, campaign), tone: 'info' };
    default:
      return null;
  }
}

/** Cierre de un capítulo. Con nivel o botín el aviso lo dice y sube de tono: es
 *  lo único accionable que trae. Y traerlo es todo lo que hace: la app no sube
 *  a nadie de nivel ni le suma nada a la bolsa, es la nota del DM para que el
 *  jugador use su propio asistente. */
function chapterCompleted(event: UserEvent, character: string, campaign: string, t: Texts) {
  const chapter = quoted(event.payload.chapterName, t, t.evtSomeChapter);
  // Un aviso viejo no trae botín y uno de un servidor más nuevo podría traerlo
  // con otra forma: lo que no sea lo esperado se lee como que no hubo. El nivel
  // no se pasa al motor: es otra línea del aviso.
  const { grantsGold, grantsItems } = event.payload;
  const rewards = chapterGrants({
    id: 'aviso',
    grantsGold: typeof grantsGold === 'number' && grantsGold > 0 ? grantsGold : undefined,
    grantsItems: Array.isArray(grantsItems) ? grantsItems.filter((i) => typeof i === 'string') : undefined,
  });
  const lines = [
    t.evtChapterDone(character, chapter, campaign),
    ...(rewards ? [t.evtTakes(rewards)] : []),
    ...(event.payload.grantsLevel === true ? [t.evtCanLevelUp] : []),
    // Objetos esperando en la bandeja de Inventario. Flutter no la tiene: ve los nombres.
    ...(event.payload.hasGrants === true ? [t.evtItemsWaiting] : []),
  ];
  return { text: lines.join(' '), tone: lines.length > 1 ? ('success' as const) : ('info' as const) };
}

/** Nombre entre comillas, o un genérico si vino vacío (lo borraron entre que
 *  pasó y que se leyó) o no es texto. */
function quoted(value: unknown, t: Texts, fallback = t.evtSomeCharacter): string {
  const text = typeof value === 'string' ? value.trim() : '';
  return text === '' ? fallback : t.evtQuoted(text);
}
