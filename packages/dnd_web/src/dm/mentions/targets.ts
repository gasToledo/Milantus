import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useCampaignChapters, useCampaignMembers, useCampaignNotebook, useNpcs, useSheetCatalog } from '../../api/queries';
import { scenariosQuery, scenarioCharactersQuery, type Scenario } from '../../api/scenarios';
import { fold } from '../../codex/entries';
import { toRosterEntry, type RosterEntry } from '../../dashboard/roster';
import { npcViews, type NpcView } from '../../engine';
import { useLang, useTexts } from '../../i18n/context';
import { dmMemberHref, dmNpcsHref, dmScenariosHref } from '../../router';
import { mentionedNames } from '../../ui/mentions';
import { memberPortrait } from '../../ui/portrait';
import { npcPortrait } from '../npcs/npc';

interface Common {
  /** Única entre todas: el tipo y el id. */
  key: string;
  name: string;
  /** La línea de abajo en el selector. */
  sub: string;
  /** De esta campaña: va primero en el selector. */
  near: boolean;
  portrait: string | null;
  href: string;
}

/** A quién o a qué puede nombrar un texto de la campaña con `@`. */
export type MentionTarget =
  | (Common & { kind: 'player'; memberId: string; entry: RosterEntry })
  | (Common & { kind: 'npc'; view: NpcView })
  | (Common & { kind: 'scene'; scenario: Scenario });

/**
 * Todo lo que un texto de [campaignId] puede mencionar, en el orden en que se
 * ofrece y en el que gana cuando dos se llaman igual: los jugadores de la mesa,
 * los PNJ y escenarios de la campaña, y después el resto de la Biblioteca.
 *
 * Un escenario es «de la campaña» si ya se lo nombra en una nota o en el
 * objetivo de un capítulo, si fue el lugar de un combate o si tiene
 * personajes de esa mesa. Lo que no carga
 * no se ofrece ni se enlaza: el texto se lee igual.
 */
export function useMentionTargets(campaignId: string): MentionTarget[] {
  const t = useTexts();
  const lang = useLang();
  const members = useCampaignMembers(campaignId);
  const npcs = useNpcs();
  const chapters = useCampaignChapters(campaignId);
  const notebook = useCampaignNotebook(campaignId);
  const scenarios = useQuery(scenariosQuery);
  const characters = useQuery(scenarioCharactersQuery);
  const catalog = useSheetCatalog(lang);

  return useMemo(() => {
    const cat = catalog.data;
    if (!cat) return [];
    const players: MentionTarget[] = (members.data ?? []).map((m) => {
      const entry = toRosterEntry(m.character, '', cat);
      const classes = entry.classes.map((c) => `${c.name} ${c.level}`).join(' · ');
      return {
        kind: 'player',
        key: `player:${m.memberId}`,
        name: String(m.character.name ?? ''),
        sub: t.mentionFromTable([entry.raceName, classes].filter(Boolean).join(', ')),
        near: true,
        portrait: memberPortrait(campaignId, m.memberId, m.character),
        href: dmMemberHref(campaignId, m.memberId),
        memberId: m.memberId,
        entry,
      };
    });

    const stored = npcs.data ?? [];
    const views = stored.length > 0 ? npcViews(stored, cat) : [];
    const people: MentionTarget[] = stored.map((s, i) => {
      const near = s.campaigns.some((l) => l.campaignId === campaignId);
      return {
        kind: 'npc',
        key: `npc:${s.npc.id}`,
        name: String(s.npc.name ?? ''),
        sub: near ? t.mentionNpcInCampaign : t.mentionNpc,
        near,
        portrait: npcPortrait(s),
        href: dmNpcsHref(s.npc.id),
        view: views[i]!,
      };
    });

    // Lo que la campaña ya nombra: notas y objetivos de sus capítulos.
    const sceneNames = (scenarios.data ?? []).map((s) => s.name);
    const texts = [
      ...(notebook.data?.notes ?? []).map((n) => n.body ?? ''),
      ...(chapters.data ?? []).map((c) => c.summary ?? ''),
    ];
    const used = new Set(texts.flatMap((text) => mentionedNames(text, sceneNames)));
    // También cuenta el lugar de un combate ya jugado en la campaña.
    const fought = new Set((notebook.data?.encounterLogs ?? []).flatMap((l) => (l.scenarioId ? [l.scenarioId] : [])));
    const withCampaign = new Set(
      (characters.data ?? []).filter((c) => c.campaigns.some((x) => x.id === campaignId)).map((c) => c.key),
    );
    const places: MentionTarget[] = (scenarios.data ?? []).map((scenario) => ({
      kind: 'scene',
      key: `scene:${scenario.id}`,
      name: scenario.name,
      sub: t.mentionScene,
      near: used.has(scenario.name) || fought.has(scenario.id) || scenario.characterKeys.some((k) => withCampaign.has(k)),
      portrait: null,
      href: dmScenariosHref(scenario.id),
      scenario,
    }));

    const ordered = [
      ...players,
      ...people.filter((p) => p.near),
      ...places.filter((p) => p.near),
      ...people.filter((p) => !p.near),
      ...places.filter((p) => !p.near),
    ];
    // Un nombre, un destino: gana el primero en ese orden (el jugador sobre el
    // PNJ, como siempre en el Registro).
    const seen = new Set<string>();
    return ordered.filter((target) => {
      const key = fold(target.name.trim());
      if (key === '' || seen.has(key)) return false;
      seen.add(key);
      return true;
    });
  }, [catalog.data, members.data, npcs.data, scenarios.data, characters.data, notebook.data, chapters.data, campaignId, t]);
}
