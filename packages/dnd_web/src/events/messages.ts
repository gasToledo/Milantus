import { Coins, CircleArrowUp, Package, type LucideIcon } from 'lucide-react';
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
/** El fin de capítulo se dibuja como diálogo y no como tostada: lleva su
 *  contenido estructurado además del `text` de siempre. */
export interface ChapterNotice {
  title: string;
  campaign: string;
  /** «{personaje} cerró el capítulo con la mesa.», ya armado: el nombre va sin comillas. */
  by: string;
  lines: { icon: LucideIcon; text: string }[];
  characterId?: string;
}

export function eventMessage(
  event: UserEvent,
  t: Texts,
): { text: string; tone: ToastTone; chapter?: ChapterNotice } | null {
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
    // Un objeto dado fuera de un capítulo: llega a la bandeja de Inventario.
    case 'item_granted': {
      const { grantsItems } = event.payload;
      const items = Array.isArray(grantsItems) ? grantsItems.filter((i): i is string => typeof i === 'string') : [];
      const text = [
        items.length > 0 ? t.evtItemGranted(items.join(', '), character, campaign) : null,
        t.evtItemsWaiting,
      ]
        .filter(Boolean)
        .join(' ');
      return { text, tone: 'success' };
    }
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
  const details = [
    ...(rewards ? [{ icon: Coins, text: t.evtTakes(rewards) }] : []),
    ...(event.payload.grantsLevel === true ? [{ icon: CircleArrowUp, text: t.evtCanLevelUp }] : []),
    // Objetos esperando en la bandeja de Inventario. Flutter no la tiene: ve los nombres.
    ...(event.payload.hasGrants === true ? [{ icon: Package, text: t.evtItemsWaiting }] : []),
  ];
  const text = [t.evtChapterDone(character, chapter, campaign), ...details.map((d) => d.text)].join(' ');
  // Sin comillas: el diálogo las pone en el título (es) o no las lleva (en).
  const plain = (value: unknown, fallback: string) => (typeof value === 'string' && value.trim() !== '' ? value.trim() : fallback);
  const { characterId } = event.payload;
  return {
    text,
    tone: details.length > 0 ? ('success' as const) : ('info' as const),
    chapter: {
      title: t.evtChapterDoneTitle(plain(event.payload.chapterName, t.evtSomeChapter)),
      campaign: plain(event.payload.campaignName, t.evtSomeCampaign),
      by: t.evtChapterDoneBy(plain(event.payload.characterName, t.evtSomeCharacter)),
      lines: details,
      // Un aviso viejo no lo trae: sin él no se ofrece «Ir a Inventario».
      ...(typeof characterId === 'string' && characterId !== '' ? { characterId } : {}),
    },
  };
}

/** Nombre entre comillas, o un genérico si vino vacío (lo borraron entre que
 *  pasó y que se leyó) o no es texto. */
function quoted(value: unknown, t: Texts, fallback = t.evtSomeCharacter): string {
  const text = typeof value === 'string' ? value.trim() : '';
  return text === '' ? fallback : t.evtQuoted(text);
}
