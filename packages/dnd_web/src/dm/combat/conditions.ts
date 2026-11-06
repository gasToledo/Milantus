import { textsFor, type Texts } from '../../i18n/texts';

type Rules = Record<string, { label: string; rule: string }>;
const rules = (lang: 'es' | 'en') => textsFor(lang).conditionRules as Rules;

/** El id de la condición (`blinded`…) a la que se refiere un tag, o `null` si es
 *  texto libre (`conditionForTag` de Flutter). Se reconoce la etiqueta española
 *  y la inglesa, sin distinguir mayúsculas. */
export function conditionOfTag(tag: string): string | null {
  const x = tag.trim().toLowerCase();
  const es = rules('es');
  const en = rules('en');
  for (const id of Object.keys(es)) {
    if (es[id]!.label.toLowerCase() === x || en[id]?.label.toLowerCase() === x) return id;
  }
  return null;
}

/** Cómo se muestra un tag: una condición en el idioma activo, y lo escrito a mano
 *  tal como se escribió. */
export function tagLabel(t: Texts, tag: string): string {
  const id = conditionOfTag(tag);
  return id ? ((t.conditionRules as Rules)[id]?.label ?? tag) : tag;
}

/** Lo que se guarda al marcar una condición: **siempre la etiqueta española**, en
 *  cualquier idioma, como Flutter. Es lo que reconocen los combates ya guardados
 *  y lo que `tagLabel` traduce al mostrarlo. */
export const storedLabel = (id: string): string => rules('es')[id]!.label;
