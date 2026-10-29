import { createContext, useContext, type ReactNode } from 'react';
import { textsFor, type Lang, type Texts } from './texts';

const LangContext = createContext<Lang>('es');

export function LangProvider({ lang, children }: { lang: Lang; children: ReactNode }) {
  return <LangContext.Provider value={lang}>{children}</LangContext.Provider>;
}

export function useLang(): Lang {
  return useContext(LangContext);
}

export function useTexts(): Texts {
  return textsFor(useLang());
}
