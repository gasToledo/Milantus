// Las primitivas de Radix UI con el estilo del sistema, en un solo lugar. Radix
// es «headless»: trae el comportamiento accesible (foco, teclado, roles ARIA,
// portales) y nada de estilo, así que el lenguaje visual sigue siendo el de
// Milantus y no el de un kit. Acá solo se les pone la placa, el filete y los
// colores de los tokens; quien las usa no repite esas clases.
//
// Lo que no se importa no entra al bundle (Vite descarta los módulos de Radix
// que nadie usa), así que tener la pieza lista no cuesta nada hasta usarla.
import type { ComponentProps, ReactNode } from 'react';
import * as DropdownMenuPrimitive from '@radix-ui/react-dropdown-menu';
import * as PopoverPrimitive from '@radix-ui/react-popover';
import * as ScrollAreaPrimitive from '@radix-ui/react-scroll-area';
import * as SelectPrimitive from '@radix-ui/react-select';
import * as SwitchPrimitive from '@radix-ui/react-switch';
import * as ToastPrimitive from '@radix-ui/react-toast';
import * as TooltipPrimitive from '@radix-ui/react-tooltip';
import { Check, ChevronDown, CircleAlert, CircleCheck, Info } from 'lucide-react';
import { cx } from './cx';

/** Placa flotante: la misma superficie que una tarjeta. Sin sombra: lo que la
 *  separa del fondo es el filete. */
const FLOATING = 'card z-50 p-1 text-[14px] text-on-surface';

// ── Tooltip ────────────────────────────────────────────────────────────────

export const TooltipProvider = TooltipPrimitive.Provider;

/**
 * Explicación corta al pasar el mouse **o** al enfocar con el teclado. No
 * reemplaza el nombre accesible: un botón de solo ícono lleva su
 * `aria-label` igual; el tooltip es para quien ve.
 */
export function Tooltip({ content, children }: { content: ReactNode; children: ReactNode }) {
  return (
    <TooltipPrimitive.Root>
      <TooltipPrimitive.Trigger asChild>{children}</TooltipPrimitive.Trigger>
      <TooltipPrimitive.Portal>
        <TooltipPrimitive.Content
          sideOffset={6}
          className="z-50 max-w-[260px] rounded-[var(--radius-nav)] border border-hairline bg-plaque px-2.5 py-1.5 text-[12px] text-on-surface"
        >
          {content}
        </TooltipPrimitive.Content>
      </TooltipPrimitive.Portal>
    </TooltipPrimitive.Root>
  );
}

// ── DropdownMenu ───────────────────────────────────────────────────────────

export const DropdownMenu = DropdownMenuPrimitive.Root;
export const DropdownMenuTrigger = DropdownMenuPrimitive.Trigger;

export function DropdownMenuContent(props: ComponentProps<typeof DropdownMenuPrimitive.Content>) {
  return (
    <DropdownMenuPrimitive.Portal>
      <DropdownMenuPrimitive.Content sideOffset={6} {...props} className={cx(FLOATING, 'min-w-[180px]', props.className)} />
    </DropdownMenuPrimitive.Portal>
  );
}

const ITEM =
  'flex cursor-pointer items-center gap-2 rounded-[var(--radius-nav)] px-2.5 py-2 outline-none data-[highlighted]:bg-plaque data-[disabled]:opacity-50';

export function DropdownMenuItem(props: ComponentProps<typeof DropdownMenuPrimitive.Item>) {
  return <DropdownMenuPrimitive.Item {...props} className={cx(ITEM, props.className)} />;
}

export const DropdownMenuRadioGroup = DropdownMenuPrimitive.RadioGroup;

/** Opción de un grupo excluyente: el tilde dorado dice cuál está elegida,
 *  y Radix lo anuncia como `menuitemradio` con `aria-checked`. */
export function DropdownMenuRadioItem({
  children,
  ...props
}: ComponentProps<typeof DropdownMenuPrimitive.RadioItem>) {
  return (
    <DropdownMenuPrimitive.RadioItem {...props} className={cx(ITEM, 'pr-8', props.className)}>
      {children}
      <DropdownMenuPrimitive.ItemIndicator className="ml-auto text-gold">
        <Check size={16} aria-hidden="true" />
      </DropdownMenuPrimitive.ItemIndicator>
    </DropdownMenuPrimitive.RadioItem>
  );
}

export function DropdownMenuLabel(props: ComponentProps<typeof DropdownMenuPrimitive.Label>) {
  return <DropdownMenuPrimitive.Label {...props} className={cx('eyebrow px-2.5 pt-1.5 pb-1', props.className)} />;
}

// ── Popover ────────────────────────────────────────────────────────────────

export const Popover = PopoverPrimitive.Root;
export const PopoverTrigger = PopoverPrimitive.Trigger;

export function PopoverContent(props: ComponentProps<typeof PopoverPrimitive.Content>) {
  return (
    <PopoverPrimitive.Portal>
      <PopoverPrimitive.Content
        sideOffset={6}
        collisionPadding={16}
        {...props}
        className={cx(FLOATING, 'max-w-[min(360px,calc(100vw-32px))] p-3', props.className)}
      />
    </PopoverPrimitive.Portal>
  );
}

// ── Select ─────────────────────────────────────────────────────────────────

/** Selección única con su rótulo visible (no un placeholder: el rótulo no
 *  desaparece al elegir). */
export function Select({
  label,
  value,
  onValueChange,
  options,
}: {
  label: string;
  value: string;
  onValueChange: (value: string) => void;
  options: { value: string; label: string }[];
}) {
  return (
    <SelectPrimitive.Root value={value} onValueChange={onValueChange}>
      <SelectPrimitive.Trigger
        aria-label={label}
        className="plaque inline-flex min-h-9 items-center gap-2 rounded-[var(--radius-nav)] px-3 text-[13px] text-on-surface"
      >
        <span className="text-text-muted">{label}:</span>
        <SelectPrimitive.Value />
        <SelectPrimitive.Icon>
          <ChevronDown size={16} aria-hidden="true" className="text-text-muted" />
        </SelectPrimitive.Icon>
      </SelectPrimitive.Trigger>
      <SelectPrimitive.Portal>
        <SelectPrimitive.Content position="popper" sideOffset={6} className={FLOATING}>
          <SelectPrimitive.Viewport>
            {options.map((o) => (
              <SelectPrimitive.Item key={o.value} value={o.value} className={cx(ITEM, 'pr-8')}>
                <SelectPrimitive.ItemText>{o.label}</SelectPrimitive.ItemText>
                <SelectPrimitive.ItemIndicator className="ml-auto text-gold">
                  <Check size={16} aria-hidden="true" />
                </SelectPrimitive.ItemIndicator>
              </SelectPrimitive.Item>
            ))}
          </SelectPrimitive.Viewport>
        </SelectPrimitive.Content>
      </SelectPrimitive.Portal>
    </SelectPrimitive.Root>
  );
}

// ── Switch ─────────────────────────────────────────────────────────────────

/** Interruptor con su rótulo al lado, que también lo activa. Encendido es
 *  oro; el pulgar se mueve, así que el estado no depende solo del color. */
export function Switch({
  id,
  label,
  checked,
  onCheckedChange,
}: {
  id: string;
  label: string;
  checked: boolean;
  onCheckedChange: (checked: boolean) => void;
}) {
  return (
    <span className="inline-flex items-center gap-2.5">
      <SwitchPrimitive.Root
        id={id}
        checked={checked}
        onCheckedChange={onCheckedChange}
        className="relative h-6 w-11 shrink-0 rounded-[var(--radius-pill)] border border-hairline bg-plaque data-[state=checked]:border-gold data-[state=checked]:bg-gold-soft"
      >
        <SwitchPrimitive.Thumb className="block h-[18px] w-[18px] translate-x-[2px] rounded-full bg-text-muted transition-transform data-[state=checked]:translate-x-[22px] data-[state=checked]:bg-gold" />
      </SwitchPrimitive.Root>
      <label htmlFor={id} className="text-[14px] text-on-surface">
        {label}
      </label>
    </span>
  );
}

// ── ScrollArea ─────────────────────────────────────────────────────────────

/** Zona con scroll propio y barra fina del sistema (la del navegador, en
 *  tema oscuro, es un bloque gris que rompe el panel).
 *
 *  Sin alto fijo del contenedor (un trasfondo que crece hasta un tope), el
 *  tope va en [viewportClassName]: es el viewport el que scrollea. Con [label]
 *  la zona se puede enfocar con el teclado para scrollearla, y tiene nombre. */
export function ScrollArea({
  children,
  className,
  viewportClassName,
  label,
  type = 'hover',
}: {
  children: ReactNode;
  className?: string;
  viewportClassName?: string;
  label?: string;
  /** `auto`: la barra se ve siempre que haya algo más que leer. */
  type?: 'hover' | 'auto';
}) {
  return (
    <ScrollAreaPrimitive.Root type={type} className={cx('min-h-0 overflow-hidden', className)}>
      <ScrollAreaPrimitive.Viewport
        className={cx('h-full w-full [&>div]:!block', viewportClassName, label && 'focus-visible:outline-2 focus-visible:outline-gold')}
        {...(label ? { tabIndex: 0, role: 'region', 'aria-label': label } : {})}
      >
        {children}
      </ScrollAreaPrimitive.Viewport>
      <ScrollAreaPrimitive.Scrollbar orientation="vertical" className="flex w-1.5 touch-none p-px select-none">
        <ScrollAreaPrimitive.Thumb className="relative flex-1 rounded-full bg-hairline" />
      </ScrollAreaPrimitive.Scrollbar>
    </ScrollAreaPrimitive.Root>
  );
}

// ── Toast ──────────────────────────────────────────────────────────────────

export type ToastTone = 'info' | 'success' | 'error';

const TOAST_ICON = { info: Info, success: CircleCheck, error: CircleAlert } as const;
const TOAST_COLOR = { info: 'text-gold', success: 'text-verdant', error: 'text-crimson' } as const;
/** Las duraciones de `showAppMessage`: el error se lee con más calma. */
const TOAST_MS = { info: 3000, success: 3000, error: 6000 } as const;

export const ToastProvider = ToastPrimitive.Provider;

/** El lugar fijo de los avisos, abajo y a lo ancho en teléfono. */
export function ToastViewport() {
  return (
    <ToastPrimitive.Viewport className="fixed right-4 bottom-4 z-50 flex w-[min(380px,calc(100vw-32px))] flex-col gap-2 outline-none" />
  );
}

/** Un aviso (`showAppMessage`): ícono, color **y** texto, los tres; Radix lo
 *  anuncia como región viva. */
export function Toast({
  tone,
  message,
  open,
  onOpenChange,
}: {
  tone: ToastTone;
  message: string;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const Icon = TOAST_ICON[tone];
  return (
    <ToastPrimitive.Root
      open={open}
      onOpenChange={onOpenChange}
      duration={TOAST_MS[tone]}
      className="card flex items-center gap-2.5 px-4 py-3"
    >
      <Icon size={20} aria-hidden="true" className={cx('shrink-0', TOAST_COLOR[tone])} />
      <ToastPrimitive.Description className="text-[14px] text-on-surface">{message}</ToastPrimitive.Description>
    </ToastPrimitive.Root>
  );
}
