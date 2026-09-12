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
  equipment?: string;
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
- `equipment` fija el material real previsto para calcular cargas montables: `barbell`, `multipower`, `dumbbell`, `cable`, `plate_loaded_machine`, `external` o `bodyweight`.
- `decisionOptions` usa etiquetas normalizadas para la decisión final del ejercicio. En ejercicios con carga: `Mantener`, `Subir peso`, `Bajar peso`, `Subir reps`, `Bajar reps`, `Marcar molestia`. En peso corporal sin carga: `Mantener`, `Subir reps`, `Bajar reps`, `Marcar molestia`. En ejercicios temporizados: `Mantener tiempo`, `Subir tiempo`, `Bajar tiempo`, `Mejorar posición`, `Marcar molestia`.
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
  plannedEquipment?: string;
  actualReps: number;
  actualWeightKg: number;
  actualDurationSeconds?: number;
  actualEquipment?: string;
  restSecondsPlanned: number;
  restSecondsActual: number;
  status: 'completed' | 'skipped';
  rirLast: number;
  painKnee: number;
  painWrist: number;
  painShoulder?: number;
  painLowerBack?: number;
  painOther: number;
  note: string;
};
```

Notas:

- Cada fila representa una serie registrada o saltada.
- `performedAt` se guarda como ISO UTC para ordenar y calcular duraciones sin depender del huso horario.
- `exerciseIndex` y `setIndex` son 0-based en la PWA.
- `roundNumber` se usa para reconstruir superseries.
- `actualWeightKg` debe interpretarse junto con el tipo de carga inferido del ejercicio: `total`, `external`, `per_dumbbell`, `machine` o `bodyweight`.
- `plannedEquipment` conserva el material previsto por el plan.
- `actualEquipment` conserva el material usado realmente durante la serie; si falta en registros antiguos, se debe usar `plannedEquipment` o `exercise.equipment`.
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
La implementación portable vive en `lib/sessionExport.ts`.
La secuencia real de ejecución de ejercicios, series y superseries vive en `lib/workoutSequence.ts`; una app nativa debe replicar esa regla para interpretar progreso, descansos y rondas de superserie de la misma forma.
La estimación operativa de duración vive en `lib/sessionDuration.js` y suma movilidad, ejecución aproximada, descansos, cambios entre ejercicios y feedback por serie.
La selección del entrenamiento recomendado y los entrenamientos de la semana vive en `lib/sessionSelection.ts`.
Los agregados estadísticos derivados del histórico están documentados en `docs/statistics-aggregates.md`.

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
- `events` contiene cada `StoredSetEvent` completo, incluido `performedAt` como timestamp ISO exacto de cada serie.
- `events` se ordena por `performedAt`.
- Al completar la exportación JSON, las sesiones incluidas se marcan con `exportedAt`.
- Este archivo debe ser el formato preferente para migración/importación en Swift.
- El alcance inicial de la app nativa y su flujo de importacion estan descritos en `docs/ios-native-plan.md`.

## CSV por serie

El CSV sigue siendo el formato práctico para Obsidian y análisis manual. No debe usarse como fuente principal para migrar a Swift porque pierde estructura.
La construcción del CSV vive en `lib/sessionExport.ts` para mantenerla fuera de la UI React.

Campos actuales:

```csv
date,performed_at,week,session,exercise,type,target,set_number,status,load_kg,load_type,planned_equipment,actual_equipment,reps,rir,pain_knee,pain_wrist,pain_shoulder,pain_lumbar,pain_other,set_note,exercise_decision,exercise_note,superset_id,superset_order,round_number
```

Notas:

- `performed_at` es el timestamp ISO local de Madrid con offset (`+02:00` en verano, `+01:00` en invierno) para revisar el CSV en Obsidian/Numbers sin perder la hora real del entrenamiento. Internamente `performedAt` sigue guardado en UTC.
- `set_number` es 1-based en CSV.
- `load_type` distingue carga total, lastre, mancuerna, máquina y peso corporal.
- `exercise_decision` y `exercise_note` solo se rellenan en la última fila exportada de cada ejercicio.

## CSV de estadísticas

Schema actual: `gymapp.statistics-export`, version `2`.

La PWA exporta un CSV derivado desde `Ajustes > Estadísticas > CSV`.
La implementación portable vive en `lib/statisticsExport.ts`.

Campos actuales:

```csv
schema_name,schema_version,exported_at,app_version,table,date,week,session_id,session,exercise_id,exercise,target,load_type,planned_equipment,actual_equipment,metric,value,value_2,status,tone,recommendation,notes
```

Tablas incluidas en el mismo archivo:

- `summary`: adherencia semanal, sesiones guardadas, sesiones completas, duración media, diferencia media, señales, series saltadas y molestias.
- `session_history`: una fila por sesión con duración real, estimación derivada, estado y series completadas.
- `exercise_insight`: señales conservadoras por ejercicio con recomendación, tono, último valor relevante y notas.
- `exercise_progression`: exposiciones históricas por ejercicio y sesión con carga máxima, trabajo total, series, RIR medio, molestias y decisión.

Notas:

- Este CSV es un formato de análisis y revisión, no sustituye al backup JSON completo.
- Desde la version 2, `exercise_insight` y `exercise_progression` conservan `load_type`, `planned_equipment` y `actual_equipment` cuando existen. Las filas globales dejan esos campos vacíos.
- Cada fila incluye `schema_name`, `schema_version`, `exported_at` y `app_version` para poder mezclar exports futuros sin perder trazabilidad.
- Las tablas se reconstruyen desde los agregados documentados en `docs/statistics-aggregates.md`.

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
