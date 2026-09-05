export type StoredSetEvent = {
  id: string;
  performedAt: string;
  planId: string;
  sessionId: string;
  sessionDate: string;
  exerciseId: string;
  exerciseIndex: number;
  setIndex: number;
  supersetId?: string;
  supersetOrder?: number;
  roundNumber?: number;
  plannedReps: number;
  plannedWeightKg: number;
  plannedDurationSeconds?: number;
  actualReps: number;
  actualWeightKg: number;
  actualDurationSeconds?: number;
  restSecondsPlanned: number;
  restSecondsActual: number;
  status: 'completed' | 'skipped';
  rirLast: number;
  painKnee: number;
  painWrist: number;
  painOther: number;
  note: string;
};

const dbName = 'gymapp-local-training';
const dbVersion = 1;
const storeName = 'setEvents';

const openDatabase = () =>
  new Promise<IDBDatabase>((resolve, reject) => {
    const request = indexedDB.open(dbName, dbVersion);

    request.onupgradeneeded = () => {
      const db = request.result;

      if (!db.objectStoreNames.contains(storeName)) {
        const store = db.createObjectStore(storeName, { keyPath: 'id' });
        store.createIndex('sessionId', 'sessionId', { unique: false });
        store.createIndex('performedAt', 'performedAt', { unique: false });
      }
    };

    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });

export async function saveSetEvent(event: StoredSetEvent) {
  const db = await openDatabase();

  await new Promise<void>((resolve, reject) => {
    const transaction = db.transaction(storeName, 'readwrite');
    transaction.objectStore(storeName).put(event);
    transaction.oncomplete = () => resolve();
    transaction.onerror = () => reject(transaction.error);
  });

  db.close();
}

export async function loadSessionEvents(sessionId: string) {
  const db = await openDatabase();

  const events = await new Promise<StoredSetEvent[]>((resolve, reject) => {
    const transaction = db.transaction(storeName, 'readonly');
    const index = transaction.objectStore(storeName).index('sessionId');
    const request = index.getAll(sessionId);

    request.onsuccess = () => resolve(request.result as StoredSetEvent[]);
    request.onerror = () => reject(request.error);
  });

  db.close();

  return events.sort((a, b) => a.performedAt.localeCompare(b.performedAt));
}

export async function clearSessionEvents(sessionId: string) {
  const db = await openDatabase();

  const events = await loadSessionEvents(sessionId);

  await new Promise<void>((resolve, reject) => {
    const transaction = db.transaction(storeName, 'readwrite');
    const store = transaction.objectStore(storeName);
    events.forEach((event) => store.delete(event.id));
    transaction.oncomplete = () => resolve();
    transaction.onerror = () => reject(transaction.error);
  });

  db.close();
}
