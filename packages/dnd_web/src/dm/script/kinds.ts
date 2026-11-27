// El ícono y el color de cada tipo de nota y de vínculo, los de la lámina.
import { BookOpen, Box, Dices, EyeOff, Lightbulb, Map, MessageSquareQuote, Music, Swords, User, Zap, type LucideIcon } from 'lucide-react';
import type { DmScriptLink, ScriptNoteKind } from '../../api/client';

/** Las clases van enteras: Tailwind no ve las que se arman por partes. Leer en
 *  voz alta es casi blanco y se separa con el filete de siempre. */
export const NOTE_STYLE: Record<ScriptNoteKind, { icon: LucideIcon; text: string; border: string }> = {
  readAloud: { icon: MessageSquareQuote, text: 'text-n-voz', border: 'border-hairline' },
  lore: { icon: BookOpen, text: 'text-n-lore', border: 'border-n-lore' },
  secret: { icon: EyeOff, text: 'text-n-secreto', border: 'border-n-secreto' },
  check: { icon: Dices, text: 'text-n-tirada', border: 'border-n-tirada' },
  reaction: { icon: Zap, text: 'text-n-reaccion', border: 'border-n-reaccion' },
  idea: { icon: Lightbulb, text: 'text-n-idea', border: 'border-n-idea' },
};

export type ScriptLinkType = DmScriptLink['type'];

/** En el orden del menú «Agregar al hito». */
export const LINK_ICONS: Record<ScriptLinkType, LucideIcon> = {
  npc: User,
  scenario: Map,
  item: Box,
  encounter: Swords,
  music: Music,
};
