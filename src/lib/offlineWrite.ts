/**
 * Generic offline-first write helpers.
 * When online: performs the Supabase mutation directly and updates local cache.
 * When offline: generates a temporary UUID (for inserts), updates local cache,
 * and queues the mutation to be replayed on reconnection.
 */
import { supabase } from '@/integrations/supabase/client';
import {
  STORES, addToSyncQueue, putItem, deleteItem, getItem,
} from '@/lib/offlineDb';

const TABLE_TO_STORE: Record<string, string> = {
  souscripteurs: STORES.SOUSCRIPTEURS,
  plantations: STORES.PLANTATIONS,
  paiements: STORES.PAIEMENTS,
  leads: STORES.LEADS,
  lead_relances: STORES.LEAD_RELANCES,
  proprietaires_terres: STORES.PROPRIETAIRES_TERRES,
  parcelles: STORES.PARCELLES,
};

function genUuid(): string {
  if (typeof crypto !== 'undefined' && 'randomUUID' in crypto) return (crypto as any).randomUUID();
  return 'off-' + Date.now() + '-' + Math.random().toString(16).slice(2);
}

export async function offlineInsert(table: string, values: any): Promise<{ data: any | null; error: any | null; offline: boolean }> {
  const store = TABLE_TO_STORE[table];
  if (navigator.onLine) {
    const { data, error } = await (supabase as any).from(table).insert(values).select().maybeSingle();
    if (!error && data && store) {
      try { await putItem(store, data); } catch {}
    }
    return { data, error, offline: false };
  }
  // Offline path
  const tempId = values?.id || genUuid();
  const record = {
    ...values,
    id: tempId,
    _offline: true,
    _pending: 'insert',
    created_at: values?.created_at || new Date().toISOString(),
    updated_at: new Date().toISOString(),
  };
  if (store) { try { await putItem(store, record); } catch {} }
  await addToSyncQueue({ table, operation: 'insert', record_id: tempId, data: values, timestamp: Date.now() });
  return { data: record, error: null, offline: true };
}

export async function offlineUpdate(table: string, id: string, values: any): Promise<{ error: any | null; offline: boolean }> {
  const store = TABLE_TO_STORE[table];
  if (navigator.onLine) {
    const { error } = await (supabase as any).from(table).update(values).eq('id', id);
    if (!error && store) {
      try {
        const existing = await getItem(store, id);
        await putItem(store, { ...(existing || { id }), ...values, updated_at: new Date().toISOString() });
      } catch {}
    }
    return { error, offline: false };
  }
  if (store) {
    try {
      const existing = await getItem(store, id);
      await putItem(store, { ...(existing || { id }), ...values, _offline: true, _pending: 'update', updated_at: new Date().toISOString() });
    } catch {}
  }
  await addToSyncQueue({ table, operation: 'update', record_id: id, data: values, timestamp: Date.now() });
  return { error: null, offline: true };
}

export async function offlineDelete(table: string, id: string): Promise<{ error: any | null; offline: boolean }> {
  const store = TABLE_TO_STORE[table];
  if (navigator.onLine) {
    const { error } = await (supabase as any).from(table).delete().eq('id', id);
    if (!error && store) { try { await deleteItem(store, id); } catch {} }
    return { error, offline: false };
  }
  if (store) { try { await deleteItem(store, id); } catch {} }
  await addToSyncQueue({ table, operation: 'delete', record_id: id, data: {}, timestamp: Date.now() });
  return { error: null, offline: true };
}
