# GymApp data schemas

Este documento describe los contratos de datos que deben mantenerse estables mientras la PWA siga actuando como prototipo y banco de pruebas para una futura app nativa de iPhone.

Los nombres de campos se mantienen en `camelCase` para que puedan traducirse de forma directa a modelos Swift `Codable`.

## Principios de compatibilidad

- Todo formato exportado debe incluir `schemaVersion`.
- Los campos nuevos deben ser opcionales para no romper importadores futuros.
- Los campos existentes no deben cambiar de significado sin subir la version del schema.
- `trainingPlan.json` es la fuente de verdad del plan que ejecuta la app.
- IndexedDB y `localStorage` son detalles de la PWA, no contratos de la futura app iOS.
- La app nativa debe poder importar un JSON exportado desde la PWA sin depender de React, IndexedDB ni Safari.

## TrainingPlan

Fuente: `data/trainingPlan.json`.

```ts
type TrainingPlan = {
  planId: string;
  startsOn: string;
  endsOn: string;
  durationWeeks: number;
  sessions: TrainingSession[];
};
```

Notas:

- `planId` identifica el ciclo completo de entrenamiento.
- `startsOn` y `endsOn` usan formato ISO `YYYY-MM-DD`.
- `sessions` contiene sesiones concretas por fecha. No se debe calcular el plan en runtime a partir de una semana tipo.

## TrainingSession

```ts
type TrainingSession = {
  sessionId: string;
  date: string;
  week: number;
  weekday: string;
  sessionLabel: string;
  label: string;
  estimatedMinutes: number;
  focus: string;
  weekFocusLabel: string;
  weekFocus: string;
  exercises: Exercise[];
};
```

Notas:

- `sessionId` es la clave usada para unir plan, eventos de series y metadata local.
- `weekFocusLabel` es una etiqueta corta para UI, por ejemplo `Acumulación técnica`.
- `weekFocus` conserva la explicación larga del foco semanal.
- `estimatedMinutes` es el objetivo manual del plan; la app puede calcular una estimación derivada adicional.

## Exercise

```ts
type Exercise = {
  exerciseId: string;
  name: string;
  type: string;
  block: string;
  supersetId?: string;
  supersetOrder?: number;
  phase: string;
  notes: string;
  target: string;
  decisionOptions: string[];
  sets: TrainingSet[];
};
```

Notas:

- `exerciseId` debe mantenerse estable entre versiones del plan para poder analizar progresión.
- `block` conserva el orden de planificación, por ejemplo `A`, `B`, `E1`, `E2`.
- `supersetId` agrupa ejercicios vinculados.
- `supersetOrder` define el orden dentro de una superserie.
- `target` es texto de presentación; para lógica debe usarse `sets`.

## TrainingSet

```ts
type TrainingSet = {
  setIndex: number;
  targetReps?: number;
  targetWeightKg: number;
  targetDurationSeconds?: number;
  restSeconds: number;
  type: 'working' | 'timed';
};
```

Notas:

- `setIndex` es 1-based en el JSON del plan.
- En eventos registrados, `setIndex` se guarda 0-based por compatibilidad con el estado actual de la PWA. Los importadores deben respetar el schema de cada fuente.
- `type: 'timed'` indica ejercicios como planchas, donde manda `targetDurationSeconds`.
- `targetWeightKg: 0` representa peso corporal cuando `loadType` se infiere como `bodyweight`.

## StoredSetEvent

Fuente: IndexedDB `setEvents`.

```ts
type StoredSetEvent = {
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
```

Notas:

- Cada fila representa una serie registrada o saltada.
- `performedAt` usa ISO datetime.
- `exerciseIndex` y `setIndex` son 0-based en la PWA.
- `roundNumber` se usa para reconstruir superseries.
- `actualWeightKg` debe interpretarse junto con el tipo de carga inferido del ejercicio: `total`, `external`, `per_dumbbell`, `machine` o `bodyweight`.
- Si `status` es `skipped`, los campos de resultado pueden contener valores de contexto, pero el importador debe tratar la serie como no completada.

## StoredSessionMetadata

Fuente: IndexedDB `sessionMetadata`.

```ts
type StoredSessionMetadata = {
  sessionId: string;
  schemaVersion?: number;
  startedAt?: string;
  finishedAt?: string;
  exportedAt?: string;
  decisions?: Record<string, string>;
};
```

Notas:

- `schemaVersion` actual: `1`.
- `decisions` usa `exerciseId` como clave.
- `exportedAt` indica que la sesión fue incluida en una exportación CSV o JSON.

## Exportación JSON completa

Schema actual: `gymapp.full-training-data-export`, version `1`.

La PWA exporta un backup completo desde `Ajustes > Datos locales > Exportar backup JSON`.

```ts
type FullTrainingDataExport = {
  schemaName: 'gymapp.full-training-data-export';
  schemaVersion: 1;
  exportedAt: string;
  app: {
    name: string;
    version: string;
  };
  source: {
    platform: 'pwa';
    localStores: string[];
  };
  plan: TrainingPlan;
  settings: {
    appearanceTheme: 'system' | 'light' | 'dark';
    keepScreenAwake: boolean;
  };
  activeWorkout: {
    selectedSessionId: string;
    phase: string;
    exerciseIndex: number;
    setIndex: number;
    startedAt?: string;
    finishedAt?: string;
  };
  sessions: ExportedSession[];
};
```

```ts
type ExportedSession = {
  sessionId: string;
  sessionDate: string;
  sessionLabel: string;
  planSession: TrainingSession;
  summary: SessionHistorySummary;
  metadata?: StoredSessionMetadata;
  decisions: Record<string, string>;
  events: StoredSetEvent[];
};
```

Notas:

- El JSON incluye el plan completo para que sea autocontenido.
- `sessions` solo incluye sesiones con datos locales: eventos o metadata.
- `events` se ordena por `performedAt`.
- Al completar la exportación JSON, las sesiones incluidas se marcan con `exportedAt`.
- Este archivo debe ser el formato preferente para migración/importación en Swift.

## CSV por serie

El CSV sigue siendo el formato práctico para Obsidian y análisis manual. No debe usarse como fuente principal para migrar a Swift porque pierde estructura.

Campos actuales:

```csv
date,week,session,exercise,type,target,set_number,status,load_kg,load_type,reps,rir,pain_knee,pain_wrist,pain_other,set_note,exercise_decision,exercise_note,superset_id,superset_order,round_number
```

Notas:

- `set_number` es 1-based en CSV.
- `load_type` distingue carga total, lastre, mancuerna, máquina y peso corporal.
- `exercise_decision` y `exercise_note` solo se rellenan en la última fila exportada de cada ejercicio.

## Consideraciones para Swift

Primera importación recomendada:

1. Decodificar `FullTrainingDataExport`.
2. Validar `schemaName` y `schemaVersion`.
3. Guardar `plan` como snapshot importado.
4. Crear sesiones locales desde `sessions`.
5. Crear eventos de serie desde `events`.
6. Guardar decisiones desde `metadata.decisions` o `decisions`.
7. Ignorar campos desconocidos para permitir evolución del schema.

Campos que conviene modelar como enums en Swift:

- `TrainingSet.type`
- `StoredSetEvent.status`
- `AppearanceTheme`
- `phase`, si la app nativa decide importar sesión en curso
- `loadType`, si se materializa en futuras versiones del JSON
