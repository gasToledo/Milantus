import type { ReactNode } from 'react';
import * as AccordionPrimitive from '@radix-ui/react-accordion';
import * as CollapsiblePrimitive from '@radix-ui/react-collapsible';
import * as TabsPrimitive from '@radix-ui/react-tabs';
import { ChevronDown, type LucideIcon } from 'lucide-react';
import { Link, navigate } from '../router';

/**
 * Pestañas **enlazables**: cada una es una URL propia (se comparte, se abre en
 * otra pestaña, «atrás» vuelve a la anterior), y además se manejan como
 * pestañas (flechas, Inicio/Fin, `role="tab"` con `aria-selected`), que es lo
 * que Radix Tabs pone. `manual`: mover el foco con las flechas no navega;
 * Enter o Espacio sí. Cambiar de página por solo enfocar sería un tirón.
 *
 * El panel lo dibuja quien llama con `TabPanel`, solo el de la pestaña activa:
 * el resto ni se monta.
 */
export function LinkTabs({
  label,
  value,
  tabs,
  listClassName,
  children,
}: {
  label: string;
  value: string;
  /** Para ocultar la tira donde otra navegación ya hace de pestañas (el panel
   *  lateral de la ficha desde 900 px). */
  listClassName?: string;
  tabs: { value: string; label: string; href: string; icon?: LucideIcon }[];
  children: ReactNode;
}) {
  return (
    <TabsPrimitive.Root
      value={value}
      activationMode="manual"
      onValueChange={(next) => {
        const tab = tabs.find((t) => t.value === next);
        if (tab) navigate(tab.href);
      }}
    >
      <TabsPrimitive.List
        aria-label={label}
        className={`flex gap-1 overflow-x-auto border-b border-hairline ${listClassName ?? ''}`}
      >
        {tabs.map(({ value: v, label: l, href, icon: Icon }) => (
          <TabsPrimitive.Trigger key={v} value={v} asChild>
            <Link
              href={href}
              className="-mb-px flex shrink-0 items-center gap-2 border-b-2 border-transparent px-3 py-2.5 text-[14px] text-on-surface-variant hover:text-on-surface data-[state=active]:border-gold data-[state=active]:font-semibold data-[state=active]:text-gold"
            >
              {Icon && <Icon size={16} aria-hidden="true" />}
              {l}
            </Link>
          </TabsPrimitive.Trigger>
        ))}
      </TabsPrimitive.List>
      {children}
    </TabsPrimitive.Root>
  );
}

export function TabPanel({
  value,
  className = 'pt-4',
  children,
}: {
  value: string;
  className?: string;
  children: ReactNode;
}) {
  return (
    <TabsPrimitive.Content value={value} className={`focus-visible:outline-offset-4 ${className}`}>
      {children}
    </TabsPrimitive.Content>
  );
}

/**
 * Lista de entradas plegables (rasgos, dotes): varias abiertas a la vez, todas
 * cerradas al empezar. Radix pone el botón con `aria-expanded` dentro de un
 * encabezado de nivel [headingLevel], así que la lista se recorre por
 * títulos.
 */
export function Accordion({
  items,
  headingLevel = 3,
}: {
  items: { id: string; title: ReactNode; meta?: ReactNode; content: ReactNode }[];
  headingLevel?: 3 | 4;
}) {
  return (
    <AccordionPrimitive.Root type="multiple" className="divide-y divide-hairline">
      {items.map((item) => {
        const trigger = (
          <AccordionPrimitive.Trigger className="group flex w-full items-center gap-2 rounded-[var(--radius-nav)] py-2 text-left">
            <span className="min-w-0 flex-1 font-medium break-words text-on-surface">{item.title}</span>
            {item.meta}
            <ChevronDown
              size={16}
              aria-hidden="true"
              className="shrink-0 text-text-muted transition-transform group-data-[state=open]:rotate-180"
            />
          </AccordionPrimitive.Trigger>
        );
        return (
        <AccordionPrimitive.Item key={item.id} value={item.id} className="py-0.5">
          <AccordionPrimitive.Header asChild>
            {headingLevel === 3 ? <h3 className="flex">{trigger}</h3> : <h4 className="flex">{trigger}</h4>}
          </AccordionPrimitive.Header>
          <AccordionPrimitive.Content className="pb-2.5 text-[13px] whitespace-pre-line text-on-surface-variant">
            {item.content}
          </AccordionPrimitive.Content>
        </AccordionPrimitive.Item>
        );
      })}
    </AccordionPrimitive.Root>
  );
}

/**
 * Un grupo del panel que se pliega (las campañas terminadas del Modo DM): el
 * rótulo es el botón, con `aria-expanded` de Radix, y lleva la misma voz que
 * el rótulo de un `NavGroup`. [defaultOpen] solo vale al montar: quien la
 * usa cambia la `key` si necesita que vuelva a abrirse.
 */
export function NavCollapsible({
  label,
  defaultOpen = false,
  children,
}: {
  label: string;
  defaultOpen?: boolean;
  children: ReactNode;
}) {
  return (
    <CollapsiblePrimitive.Root defaultOpen={defaultOpen}>
      <CollapsiblePrimitive.Trigger className="group eyebrow flex w-full items-center gap-1 rounded-[var(--radius-nav)] px-3 pt-1 pb-1.5 text-left">
        <span className="min-w-0 flex-1">{label}</span>
        <ChevronDown
          size={14}
          aria-hidden="true"
          className="shrink-0 text-text-muted transition-transform group-data-[state=open]:rotate-180"
        />
      </CollapsiblePrimitive.Trigger>
      <CollapsiblePrimitive.Content>{children}</CollapsiblePrimitive.Content>
    </CollapsiblePrimitive.Root>
  );
}
