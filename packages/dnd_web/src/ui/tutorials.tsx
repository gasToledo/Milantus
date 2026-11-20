import { useEffect, useRef, useState } from 'react';
import {
  ArrowLeftRight,
  AtSign,
  BookOpen,
  Dices,
  Eye,
  Flag,
  Flame,
  GraduationCap,
  IdCard,
  ListChecks,
  Music,
  Pencil,
  PawPrint,
  Repeat,
  Share,
  Shield,
  SlidersHorizontal,
  Smile,
  Sparkles,
  Swords,
  User,
  Users,
  type LucideIcon,
} from 'lucide-react';
import { patchSettings } from '../api/settingsSave';
import { useTexts } from '../i18n/context';
import { AppDialog } from './AppDialog';
import { cx } from './cx';

/**
 * Los tutoriales. El nombre de cada uno es lo que se guarda para recordar que
 * ya se vio, **el mismo que usaba la versión anterior**: lo visto entonces
 * sigue contando, así que renombrarlo lo vuelve a mostrar. `welcome` sale al
 * entrar a la app; el resto, la primera vez
 * que se abre su sección. Los textos viven en `texts.ts` (`tutorials`).
 */
export type Tutorial =
  | 'welcome'
  | 'sheet'
  | 'dmTable'
  | 'dmChapters'
  | 'dmNotebook'
  | 'dmNpcs'
  | 'dmCombat'
  | 'bestiary'
  | 'npcLibrary'
  | 'homebrew'
  | 'quiz';

/** Un ícono por página, en el orden de los textos. */
const ICONS: Record<Tutorial, LucideIcon[]> = {
  welcome: [Smile, Dices, User, GraduationCap, Shield],
  sheet: [IdCard, Swords, Share],
  dmTable: [Users, Eye],
  dmChapters: [BookOpen, Flag],
  dmNotebook: [BookOpen, AtSign],
  dmNpcs: [Users, SlidersHorizontal],
  dmCombat: [Flame, Repeat, Music],
  bestiary: [PawPrint, Pencil],
  npcLibrary: [Users, ArrowLeftRight],
  homebrew: [Sparkles, Share],
  quiz: [GraduationCap, ListChecks],
};

// --- Qué se vio -------------------------------------------------------------
// Lo visto es de la cuenta (`tutorialsSeen` en los ajustes); acá queda la copia
// local, para saber qué mostrar antes de que lleguen los ajustes y cuando no hay
// sesión. Clave y formato de la versión anterior: los nombres separados por
// coma, o `*` si
// se eligió «Saltar todos».
const KEY = 'milantus.tutorials';
const ALL = '*';

let seen: Set<string> | null = null;

function loaded(): Set<string> {
  if (seen) return seen;
  try {
    seen = new Set((localStorage.getItem(KEY) ?? '').split(',').filter(Boolean));
  } catch {
    // Almacenamiento bloqueado: se muestran, y saltarlos vale para la sesión.
    seen = new Set();
  }
  return seen;
}

function save(change: (s: Set<string>) => void) {
  const s = loaded();
  change(s);
  try {
    localStorage.setItem(KEY, [...s].join(','));
  } catch {
    // Sin almacenamiento vale igual durante la sesión; solo no se recuerda.
  }
}

const isPending = (tutorial: Tutorial) => !loaded().has(ALL) && !loaded().has(tutorial);

/** Lo que llega de la cuenta reemplaza a lo visto local (también la copia). */
export function adoptSeen(list: string[]) {
  save((s) => {
    s.clear();
    list.forEach((n) => s.add(n));
  });
}

/** Cerrar un tutorial lo manda a la cuenta, sin aviso: si falla queda local y
 *  sale en el próximo cierre (que manda la lista entera). */
function pushSeen() {
  patchSettings({ tutorialsSeen: [...loaded()] }).catch(() => {});
}

/** Uno a la vez: si ya hay uno abierto, el otro espera a la próxima entrada.
 *  Guarda quién lo tiene para que soltarlo no libere el de otro. */
let owner: symbol | null = null;

/**
 * Muestra [tutorial] la primera vez que se monta, si todavía no se vio. No
 * dibuja nada más. Cerrarlo de cualquier forma (Esc, velo, «Saltar»,
 * «Entendido») lo marca visto: uno que vuelve cada vez que se toca afuera es
 * peor que no tenerlo. «Saltar todos» guarda `*`.
 */
export function TutorialGate({ tutorial }: { tutorial: Tutorial }) {
  const [open, setOpen] = useState(false);
  const me = useRef(Symbol(tutorial));
  const release = () => {
    if (owner === me.current) owner = null;
  };
  useEffect(() => {
    if (owner !== null || !isPending(tutorial)) return;
    owner = me.current;
    setOpen(true);
    return release;
  }, [tutorial]);
  if (!open) return null;
  return (
    <TutorialDialog
      tutorial={tutorial}
      onClose={() => {
        release();
        setOpen(false);
      }}
    />
  );
}

function TutorialDialog({ tutorial, onClose }: { tutorial: Tutorial; onClose: () => void }) {
  const t = useTexts();
  const pages = t.tutorials[tutorial];
  const [index, setIndex] = useState(0);
  const skipAll = useRef(false);
  const page = pages[index]!;
  const Icon = ICONS[tutorial][index]!;
  const last = index === pages.length - 1;

  return (
    <AppDialog
      open
      bare
      onOpenChange={(open) => {
        if (open) return;
        if (skipAll.current) save((s) => s.add(ALL));
        else save((s) => s.add(tutorial));
        pushSeen();
        onClose();
      }}
      title={page.title}
      actions={[
        { label: t.tutSkipAll, onSelect: () => (skipAll.current = true) },
        ...(last ? [] : [{ label: t.tutSkip }]),
        last
          ? { label: t.tutDone, primary: true }
          : { label: t.tutNext, primary: true, closes: false, onSelect: () => setIndex(index + 1) },
      ]}
    >
      <div className="flex flex-col gap-3.5" data-tutorial={tutorial}>
        <span className="flex size-12 items-center justify-center rounded-full border border-hairline bg-gold-soft">
          <Icon size={24} strokeWidth={1.8} aria-hidden="true" className="text-gold" />
        </span>
        <h2 aria-hidden="true" className="font-display text-[20px] text-on-surface">
          {page.title}
        </h2>
        <p className="min-h-[116px] text-[14.5px] leading-[1.6] text-on-surface-variant">{page.body}</p>
        <div className="flex items-center gap-1.5">
          {pages.map((_, i) => (
            <span
              key={i}
              aria-hidden="true"
              className={cx('size-[7px] rounded-full transition-colors duration-[120ms]', i === index ? 'bg-gold' : 'bg-hairline')}
            />
          ))}
          <span className="ml-2 text-[12px] text-text-muted tabular-nums">{t.tutPageOf(index + 1, pages.length)}</span>
        </div>
      </div>
    </AppDialog>
  );
}
