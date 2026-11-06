import { useMemo } from 'react';
import { nameOf } from '../api/catalog';
import { savePortraitBase64, uploadPortrait } from '../api/portraits';
import { portraitPrompt, type CharacterJson } from '../engine';
import { useTexts } from '../i18n/context';
import { characterHref } from '../router';
import { accentFor, classesOf, type SheetModel } from './model';
import { PortraitWorkshop, type PortraitOwner } from './PortraitWorkshop';
import type { SheetWriter } from './writer';

/**
 * Los retratos de la ficha propia: el taller (`PortraitWorkshop`) con la ficha
 * como dueña. Lo que se escribe en la ficha pasa por el motor (`addPortrait`,
 * `restorePortrait`, `removePortrait`).
 */
export function PortraitPage({ model, write }: { model: SheetModel; write: SheetWriter }) {
  const t = useTexts();
  const { character, catalog } = model;
  const raw = character as unknown as CharacterJson;
  const buildPrompt = useMemo(
    () => (style: string, details: string, includeWeapon: boolean) => portraitPrompt(raw, catalog, style, details, includeWeapon),
    [raw, catalog],
  );
  const classes = classesOf(model);
  const caption = [
    nameOf(catalog.races, character.raceId),
    classes.map((c) => t.classLevel(c.name, c.level)).join(' / '),
    classes.flatMap((c) => (c.subclass ? [c.subclass] : [])).join(' / '),
  ]
    .filter(Boolean)
    .join(' · ');

  const owner: PortraitOwner = {
    name: character.name,
    caption,
    accent: accentFor(model),
    backHref: characterHref(character.id),
    paths: character.portraitPaths ?? [],
    prompts: character.portraitPrompts ?? {},
    detailsLabel: t.portraitExtraDetails,
    initialDetails: '',
    buildPrompt,
    upload: (file) => uploadPortrait(character.id, file),
    saveBase64: (base64) => savePortraitBase64(character.id, base64),
    apply: write.act,
    notify: write.notify,
  };
  return <PortraitWorkshop owner={owner} />;
}
