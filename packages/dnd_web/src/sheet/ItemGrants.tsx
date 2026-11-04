import { useEffect, useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { Gift } from 'lucide-react';
import { claimItemGrant, resolveItemGrant, type ItemGrant } from '../api/client';
import { nameOf } from '../api/catalog';
import { queryKeys, useItemGrants } from '../api/queries';
import { useTexts } from '../i18n/context';
import { Button } from '../ui/Button';
import { Card } from '../ui/Card';
import type { SheetModel } from './model';
import type { SheetWriter } from './writer';

/** Lo que falta para terminar de aceptar un regalo de homebrew: la copia ya
 *  está en la cuenta, pero hay que esperar a que el catálogo de la ficha la
 *  traiga antes de que el motor pueda agregarla. */
type Waiting = { grant: ItemGrant; itemId: string; base: string | null };

/**
 * «El DM te dio» (`Jugador` del Diseño): la bandeja de objetos que el DM
 * repartió al cerrar un capítulo, arriba de la pestaña Inventario y solo en la
 * ficha propia. **El DM no escribe la ficha**: el objeto lo agrega el jugador
 * acá, con su sesión, por la misma acción del motor que usa «Agregar objeto».
 * Descartar no pide confirmación: es una bandeja, no una pérdida.
 *
 * Aceptar va en un orden que no pierde nada si algo falla: reclamar (el
 * servidor deja la fila y, si es homebrew, crea la copia), esperar al catálogo,
 * agregar al inventario y recién entonces sacar la fila. Un fallo antes del
 * último paso deja el regalo a la vista para reintentar. «Deshacer» no existe:
 * el objeto se saca desde la mochila.
 */
export function ItemGrants({ model }: { model: SheetModel }) {
  const t = useTexts();
  const client = useQueryClient();
  const { write, catalog, character } = model;
  const grants = useItemGrants(character.id, write !== undefined);
  const [busy, setBusy] = useState<string | null>(null);
  const [waiting, setWaiting] = useState<Waiting | null>(null);

  const finish = async (w: SheetWriter, grant: ItemGrant, itemId: string, base: string | null) => {
    try {
      // Una vez por unidad: la acción del motor suma de a un objeto.
      for (let i = 0; i < grant.quantity; i++) {
        if (!w.act({ type: 'addItem', item: itemId, ...(base ? { base } : {}) })) throw new Error('addItem');
      }
      await resolveItemGrant(grant.id);
      await client.invalidateQueries({ queryKey: queryKeys.itemGrants(character.id) });
      w.notify(t.grantsAdded(grant.name), { tone: 'success' });
    } catch {
      w.notify(t.grantsAddError, { tone: 'error' });
    } finally {
      setBusy(null);
    }
  };

  // Un homebrew recién copiado todavía no está en el catálogo de la ficha.
  // ponytail: si el catálogo nunca lo trae (el homebrew no cargó) el regalo
  // queda esperando con el botón apagado hasta recargar; el servidor conserva la
  // fila, así que no se pierde nada. Sumar un tope de tiempo si molesta.
  useEffect(() => {
    if (!waiting || !write) return;
    const list = catalog[waiting.grant.category] as { id?: unknown }[];
    if (!list.some((e) => e.id === waiting.itemId)) return;
    setWaiting(null);
    void finish(write, waiting.grant, waiting.itemId, waiting.base);
  }, [waiting, catalog, write]);

  if (!write || !grants.data || grants.data.length === 0) return null;

  const accept = async (grant: ItemGrant) => {
    setBusy(grant.id);
    try {
      const claimed = await claimItemGrant(grant.id);
      if (grant.homebrew) {
        await client.invalidateQueries({ queryKey: queryKeys.homebrew });
        setWaiting({ grant, itemId: claimed.itemId, base: claimed.baseItemId });
      } else {
        await finish(write, grant, claimed.itemId, claimed.baseItemId);
      }
    } catch {
      write.notify(t.grantsAddError, { tone: 'error' });
      setBusy(null);
    }
  };

  const discard = async (grant: ItemGrant) => {
    setBusy(grant.id);
    try {
      await resolveItemGrant(grant.id);
      await client.invalidateQueries({ queryKey: queryKeys.itemGrants(character.id) });
    } catch {
      write.notify(t.grantsDiscardError, { tone: 'error' });
    } finally {
      setBusy(null);
    }
  };

  return (
    <Card id="item-grants" title={t.grantsTitle} icon={Gift}>
      <ul className="flex flex-col divide-y divide-hairline">
        {grants.data.map((g) => (
          <li key={g.id} className="flex flex-wrap items-center gap-x-3 gap-y-2 py-2.5" data-grant={g.id}>
            <span className="min-w-0 flex-[1_1_220px]">
              <b className="block text-[14px] font-medium break-words text-on-surface">
                {/* Del catálogo si está; un homebrew del DM no está en el de esta cuenta. */}
                {nameOf(catalog[g.category], g.itemId) === g.itemId ? g.name : nameOf(catalog[g.category], g.itemId)}
                {g.quantity > 1 && <span className="num ml-1.5 font-normal text-on-surface-variant">×{g.quantity}</span>}
                {g.homebrew && (
                  <i className="ml-2 rounded-[var(--radius-pill)] border border-gold px-2 text-[11px] font-normal text-gold not-italic">
                    {t.grantsFromDm}
                  </i>
                )}
              </b>
              <small className="block text-[12px] text-text-muted">{`${g.campaignName} · ${g.chapterName}`}</small>
            </span>
            <Button data-action="accept-grant" disabled={busy !== null} onClick={() => void accept(g)}>
              {t.grantsAdd}
            </Button>
            <Button tone="secondary" data-action="discard-grant" disabled={busy !== null} onClick={() => void discard(g)}>
              {t.grantsDiscard}
            </Button>
          </li>
        ))}
      </ul>
    </Card>
  );
}
