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

export type StoredSessionMetadata = {
  sessionId: string;
  schemaVersion?: number;
  startedAt?: string;
  finishedAt?: string;
  exportedAt?: string;
};

const dbName = 'gymapp-local-training';
const dbVersion = 2;
const setEventsStoreName = 'setEvents';
const sessionMetadataStoreName = 'sessionMetadata';

const openDatabase = () =>
  new Promise<IDBDatabase>((resolve, reject) => {
    const request = indexedDB.open(dbName, dbVersion);

    request.onupgradeneeded = () => {
      const db = request.result;

      if (!db.objectStoreNames.contains(setEventsStoreName)) {
        const store = db.createObjectStore(setEventsStoreName, {
          keyPath: 'id',
        });
        store.createIndex('sessionId', 'sessionId', { unique: false });
        store.createIndex('performedAt', 'performedAt', { unique: false });
      }

      if (!db.objectStoreNames.contains(sessionMetadataStoreName)) {
        db.createObjectStore(sessionMetadataStoreName, {
          keyPath: 'sessionId',
        });
      }
    };

    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });

export async function saveSetEvent(event: StoredSetEvent) {
  const db = await openDatabase();

  await new Promise<void>((resolve, reject) => {
    const transaction = db.transaction(setEventsStoreName, 'readwrite');
    transaction.objectStore(setEventsStoreName).put(event);
    transaction.oncomplete = () => resolve();
    transaction.onerror = () => reject(transaction.error);
  });

  db.close();
}

export async function loadSessionEvents(sessionId: string) {
  const db = await openDatabase();

  const events = await new Promise<StoredSetEvent[]>((resolve, reject) => {
    const transaction = db.transaction(setEventsStoreName, 'readonly');
    const index = transaction
      .objectStore(setEventsStoreName)
      .index('sessionId');
    const request = index.getAll(sessionId);

    request.onsuccess = () => resolve(request.result as StoredSetEvent[]);
    request.onerror = () => reject(request.error);
  });

  db.close();

  return events.sort((a, b) => a.performedAt.localeCompare(b.performedAt));
}

export async function loadAllSessionEvents() {
  const db = await openDatabase();

  const events = await new Promise<StoredSetEvent[]>((resolve, reject) => {
    const transaction = db.transaction(setEventsStoreName, 'readonly');
    const request = transaction.objectStore(setEventsStoreName).getAll();

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
    const transaction = db.transaction(
      [setEventsStoreName, sessionMetadataStoreName],
      'readwrite',
    );
    const store = transaction.objectStore(setEventsStoreName);
    events.forEach((event) => store.delete(event.id));
    transaction.objectStore(sessionMetadataStoreName).delete(sessionId);
    transaction.oncomplete = () => resolve();
    transaction.onerror = () => reject(transaction.error);
  });

  db.close();
}

export async function clearAllSessionEvents() {
  const db = await openDatabase();

  await new Promise<void>((resolve, reject) => {
    const transaction = db.transaction(
      [setEventsStoreName, sessionMetadataStoreName],
      'readwrite',
    );
    transaction.objectStore(setEventsStoreName).clear();
    transaction.objectStore(sessionMetadataStoreName).clear();
    transaction.oncomplete = () => resolve();
    transaction.onerror = () => reject(transaction.error);
  });

  db.close();
}

export async function loadSessionMetadata() {
  const db = await openDatabase();

  const metadata = await new Promise<StoredSessionMetadata[]>(
    (resolve, reject) => {
      const transaction = db.transaction(sessionMetadataStoreName, 'readonly');
      const request = transaction
        .objectStore(sessionMetadataStoreName)
        .getAll();

      request.onsuccess = () =>
        resolve(request.result as StoredSessionMetadata[]);
      request.onerror = () => reject(request.error);
    },
  );

  db.close();

  return metadata;
}

async function updateSessionMetadata(
  sessionId: string,
  patch: Omit<StoredSessionMetadata, 'sessionId'>,
) {
  const db = await openDatabase();

  await new Promise<void>((resolve, reject) => {
    const transaction = db.transaction(sessionMetadataStoreName, 'readwrite');
    const store = transaction.objectStore(sessionMetadataStoreName);
    const request = store.get(sessionId);

    request.onsuccess = () => {
      store.put({
        ...((request.result as StoredSessionMetadata | undefined) ?? {
          sessionId,
        }),
        ...patch,
      });
    };
    request.onerror = () => reject(request.error);
    transaction.oncomplete = () => resolve();
    transaction.onerror = () => reject(transaction.error);
  });

  db.close();
}

export async function markSessionStarted(sessionId: string, startedAt: string) {
  await updateSessionMetadata(sessionId, {
    schemaVersion: 1,
    startedAt,
    finishedAt: undefined,
    exportedAt: undefined,
  });
}

export async function markSessionFinished(
  sessionId: string,
  finishedAt: string,
) {
  await updateSessionMetadata(sessionId, {
    schemaVersion: 1,
    finishedAt,
  });
}

export async function markSessionExported(
  sessionId: string,
  exportedAt: string,
) {
  await updateSessionMetadata(sessionId, {
    schemaVersion: 1,
    exportedAt,
  });
}

export async function purgeExportedSessionsOlderThan(days: number) {
  const cutoff = Date.now() - days * 24 * 60 * 60 * 1000;
  const metadata = await loadSessionMetadata();
  const sessionIds = metadata
    .filter(
      (item) =>
        item.exportedAt !== undefined &&
        new Date(item.exportedAt).getTime() < cutoff,
    )
    .map((item) => item.sessionId);

  if (sessionIds.length === 0) {
    return;
  }

  const db = await openDatabase();

  await new Promise<void>((resolve, reject) => {
    const transaction = db.transaction(
      [setEventsStoreName, sessionMetadataStoreName],
      'readwrite',
    );
    const eventStore = transaction.objectStore(setEventsStoreName);
    const metadataStore = transaction.objectStore(sessionMetadataStoreName);

    sessionIds.forEach((sessionId) => {
      const index = eventStore.index('sessionId');
      const request = index.openKeyCursor(IDBKeyRange.only(sessionId));

      request.onsuccess = () => {
        const cursor = request.result;

        if (!cursor) {
          return;
        }

        eventStore.delete(cursor.primaryKey);
        cursor.continue();
      };

      metadataStore.delete(sessionId);
    });

    transaction.oncomplete = () => resolve();
    transaction.onerror = () => reject(transaction.error);
  });

  db.close();
}
