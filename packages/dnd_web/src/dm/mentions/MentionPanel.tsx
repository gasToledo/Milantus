import type { ReactNode } from 'react';
import * as Dialog from '@radix-ui/react-dialog';
import { useQuery } from '@tanstack/react-query';
import { ExternalLink, X } from 'lucide-react';
import { scenarioCharacterPortrait, scenarioCharactersQuery, scenarioImageHref } from '../../api/scenarios';
import { useTexts } from '../../i18n/context';
import { signed } from '../../sheet/format';
import { ButtonLink } from '../../ui/Button';
import { Eyebrow, StatPlaque } from '../../ui/data';
import { MarkdownText } from '../../ui/MarkdownText';
import { Medallion } from '../../ui/Medallion';
import { Tooltip } from '../../ui/primitives';
import { Abbr } from '../MemberCard';
import { kindOf, npcTypeLine } from '../npcs/npc';
import type { MentionTarget } from './targets';

/**
 * La ficha corta de una mención, en un panel a la derecha: tocar un nombre no
 * cambia de pantalla, así no se pierde lo que se estaba leyendo ni el
 * borrador.
 *
 * Leyendo (el Registro, los capítulos) el panel **no es modal**: la página
 * sigue viva detrás, tocar otra mención cambia lo que muestra y solo se cierra
 * con la X, Esc o tocando la misma mención. Desde un editor [inEditor] es un
 * diálogo encima del diálogo: el borrador queda abajo, intacto, y el enlace a
 * la ficha completa abre otra pestaña para no llevárselo.
 */
export function MentionPanel({ target, onClose, inEditor = false }: {
  target: MentionTarget | null;
  onClose: () => void;
  inEditor?: boolean;
}) {
  const t = useTexts();
  const kindLabel = !target ? '' : target.kind === 'scene' ? t.mentionKindScene : target.kind === 'npc' ? t.mentionKindNpc : t.mentionKindPlayer;
  const open = !target ? '' : target.kind === 'scene' ? t.mentionOpenScene : target.kind === 'npc' ? t.mentionOpenNpc : t.mentionOpenPlayer;
  return (
    <Dialog.Root open={target !== null} onOpenChange={(next) => !next && onClose()} modal={inEditor}>
      <Dialog.Portal>
        <Dialog.Content
          aria-describedby={undefined}
          // Sin modal, tocar afuera no lo cierra: se sigue leyendo con el panel
          // abierto, y otra mención lo cambia en vez de cerrarlo y reabrirlo.
          onInteractOutside={(event) => {
            if (!inEditor) event.preventDefault();
          }}
          className={`mention-panel fixed inset-y-0 right-0 flex w-[min(400px,100vw)] flex-col border-l border-hairline bg-surface ${inEditor ? 'z-[60]' : 'z-40'}`}
          data-mention-panel={target?.kind}
        >
          {target && (
            <>
              <div className="flex items-center gap-2 border-b border-hairline py-2.5 pr-3 pl-5">
                <span className="eyebrow flex-1">{kindLabel}</span>
                <Tooltip content={t.close}>
                  <Dialog.Close
                    aria-label={t.close}
                    className="inline-flex size-10 items-center justify-center rounded-[var(--radius-nav)] text-text-muted hover:text-gold"
                  >
                    <X size={18} aria-hidden="true" />
                  </Dialog.Close>
                </Tooltip>
              </div>
              <div key={target.key} className="fade-in flex flex-1 flex-col gap-4 overflow-y-auto px-5 py-[18px]">
                {target.kind === 'scene' ? <SceneBody target={target} /> : <PersonBody target={target} />}
              </div>
              <div className="border-t border-hairline px-5 pt-3.5 pb-[18px]">
                <ButtonLink tone="secondary" icon={ExternalLink} href={target.href} internal={!inEditor} newTab={inEditor}>
                  {inEditor ? t.mentionOpenNewTab(open) : open}
                </ButtonLink>
              </div>
            </>
          )}
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}

function SceneBody({ target }: { target: Extract<MentionTarget, { kind: 'scene' }> }) {
  const t = useTexts();
  const { scenario } = target;
  const characters = useQuery({ ...scenarioCharactersQuery, enabled: scenario.characterKeys.length > 0 });
  const people = (characters.data ?? []).filter((c) => scenario.characterKeys.includes(c.key));
  return (
    <>
      {scenario.hasImage && (
        <img
          src={scenarioImageHref(scenario)}
          alt={t.dmScenarioCoverOf(scenario.name)}
          className="aspect-video w-full rounded-[var(--radius-card)] border border-hairline bg-plaque object-cover"
        />
      )}
      <Dialog.Title className="font-display text-[24px] leading-tight font-normal break-words text-on-surface">{scenario.name}</Dialog.Title>
      {scenario.description && (
        <p className="text-[14px] leading-[1.6] break-words whitespace-pre-wrap text-on-surface">{scenario.description}</p>
      )}
      {people.length > 0 && (
        <div>
          <Eyebrow className="mb-1.5">{t.dmScenarioCharacters}</Eyebrow>
          <ul className="flex flex-col">
            {people.map((c) => (
              <li key={c.key} className="flex items-center gap-2.5 py-1.5">
                <Medallion name={c.name} accent={null} size={30} portrait={scenarioCharacterPortrait(c)} />
                <span className="min-w-0">
                  <span className="block text-[13.5px] break-words text-on-surface">{c.name}</span>
                  <span className="block text-[12px] text-text-muted">{c.campaignName ?? t.dmLibraryNpcs}</span>
                </span>
              </li>
            ))}
          </ul>
        </div>
      )}
    </>
  );
}

function PersonBody({ target }: { target: Extract<MentionTarget, { kind: 'player' | 'npc' }> }) {
  const t = useTexts();
  let line: string;
  let stats: { id: string; label: ReactNode; value: ReactNode }[] = [];
  let speech = '';
  let background = '';
  if (target.kind === 'player') {
    const { entry } = target;
    line = [entry.raceName, entry.classes.map((c) => `${c.name} ${c.level}`).join(' · ')].filter(Boolean).join(' · ');
    if (entry.sheet) {
      stats = [
        { id: 'ac', label: <Abbr short={t.acShort} full={t.acFull} />, value: entry.sheet.armorClass },
        { id: 'hp', label: <Abbr short={t.hp} full={t.hitPoints} />, value: `${entry.character.combat?.currentHp ?? entry.sheet.maxHp}/${entry.sheet.maxHp}` },
        { id: 'init', label: <Abbr short={t.initiativeShort} full={t.initiative} />, value: signed(entry.sheet.initiative) },
      ];
    }
    background = String((entry.character as { background?: unknown }).background ?? '');
  } else {
    const { view } = target;
    line = npcTypeLine(view, t);
    const kind = kindOf(view);
    if (kind === 'block' && view.block) {
      stats = [
        { id: 'ac', label: <Abbr short={t.acShort} full={t.acFull} />, value: view.block.ac },
        { id: 'hp', label: <Abbr short={t.hp} full={t.hitPoints} />, value: view.block.hp },
        ...(view.block.crText !== null ? [{ id: 'cr', label: t.creatureCr, value: view.block.crText }] : []),
      ];
    } else if (kind === 'character' && view.sheet) {
      stats = [
        { id: 'ac', label: <Abbr short={t.acShort} full={t.acFull} />, value: view.sheet.armorClass },
        { id: 'hp', label: <Abbr short={t.hp} full={t.hitPoints} />, value: view.sheet.maxHp },
        { id: 'init', label: <Abbr short={t.initiativeShort} full={t.initiative} />, value: signed(view.sheet.initiative) },
      ];
    }
    speech = view.npc.speech?.trim() ?? '';
    background = view.npc.background ?? '';
  }
  return (
    <>
      <div className="flex items-center gap-3.5">
        <Medallion name={target.name} accent={target.kind === 'player' ? target.entry.accent : null} size={64} portrait={target.portrait} />
        <div className="min-w-0">
          <Dialog.Title className="font-display text-[24px] leading-tight font-normal break-words text-on-surface">{target.name}</Dialog.Title>
          {line && <p className="mt-1 text-[12.5px] text-text-muted">{line}</p>}
        </div>
      </div>
      {stats.length > 0 && (
        <dl className="grid grid-cols-3 gap-2">
          {stats.map((s) => <StatPlaque key={s.id} id={s.id} dense label={s.label} value={s.value} />)}
        </dl>
      )}
      {speech && (
        <blockquote className="flex gap-2" aria-label={t.npcSpeech}>
          <span aria-hidden="true" className="font-display text-[32px] leading-[0.9] text-gold">“</span>
          <span className="pt-1 text-[15px] leading-normal text-on-surface italic">{speech}</span>
        </blockquote>
      )}
      {background.trim() && (
        <div>
          <Eyebrow className="mb-1.5">{t.diaryBackground}</Eyebrow>
          <MarkdownText text={background} className="text-[14px] leading-[1.6] text-on-surface" />
        </div>
      )}
    </>
  );
}
