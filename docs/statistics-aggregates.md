# GymApp statistics aggregates

Este documento describe los agregados estadisticos actuales de la PWA para que puedan replicarse despues en una app nativa de iPhone sin depender de React, IndexedDB ni detalles visuales.

Fuente principal de implementacion: `lib/trainingStats.ts`.

## Principios

- La fuente de verdad son eventos de series (`StoredSetEvent`) unidos al plan activo (`TrainingPlan`) por `sessionId` y `exerciseId`.
- Los agregados no modifican datos fuente. Solo resumen plan, eventos y metadata.
- Los timestamps internos usan ISO UTC. Para duraciones se comparan instantes absolutos, no horas locales formateadas.
- Las decisiones de progresion son conservadoras y explicables. No deben subir o bajar cargas de forma automatica sin que el usuario lo confirme.
- Swift debe poder reconstruir estos agregados desde el backup JSON completo.

## Inputs

Los calculos consumen:

- `TrainingSession[]`: sesiones explicitas del plan.
- `StoredSetEvent[]`: eventos de series guardados localmente.
- `StoredSessionMetadata[]`: inicio, fin, exportacion y decisiones por ejercicio.
- `todayIso`: fecha local actual en formato `YYYY-MM-DD` para encontrar proximas exposiciones.
- `recommendedSession`: sesion recomendada del dia o siguiente sesion pendiente.

## SessionHistorySummary

Funcion: `getSessionHistorySummaries`.

Una entrada resume una sesion que tiene al menos un evento registrado.

Campos calculados:

- `sessionId`, `sessionDate`, `weekNumber`, `sessionLabel`: salen de la sesion del plan.
- `estimatedMinutes`: valor manual del plan.
- `derivedEstimatedMinutes`: estimacion operativa calculada con `estimateSessionDurationFromSteps(session, buildExecutionSteps(session)).totalMinutes`.
- `attemptedSets`: numero total de eventos de la sesion, incluyendo series completadas y saltadas.
- `completedSets`: eventos con `status === 'completed'`.
- `totalSets`: numero de pasos reales de ejecucion calculados con `buildExecutionSteps`, incluyendo superseries.
- `schemaVersion`, `startedAt`, `finishedAt`, `exportedAt`: salen de metadata si existen.
- `firstPerformedAt`: primer evento de la sesion ordenado por `performedAt`.
- `lastPerformedAt`: ultimo evento de la sesion ordenado por `performedAt`.

Orden: descendente por `lastPerformedAt`.

Sesion completa:

- `isSessionHistoryComplete(summary)` devuelve `true` si existe `finishedAt` o si `attemptedSets >= totalSets`.

## Duracion

Funcion: `getDurationMinutes`.

Reglas:

- Requiere `startedAt` y `finishedAt`.
- Convierte ambos valores con `new Date(...).getTime()`.
- Si algun timestamp no es valido o el final es anterior al inicio, devuelve `undefined`.
- Si la duracion es valida, devuelve minutos redondeados con minimo 1 minuto.

Uso:

- La duracion real de entrenamiento empieza al iniciar la primera serie, no durante la movilidad previa.
- `deltaMinutes = actualMinutes - derivedEstimatedMinutes`.
- Valor positivo: entrenamiento mas largo que la estimacion.
- Valor negativo: entrenamiento mas rapido que la estimacion.

## TrainingStatsSummary

Funcion: `getTrainingStatsSummary`.

Resume la vista principal de estadisticas.

Campos calculados:

- `weekNumber`: semana de `recommendedSession`.
- `weekFocusLabel`: foco corto de la semana de `recommendedSession`.
- `weekCompletedSessions`: sesiones de la semana actual con `isSessionHistoryComplete`.
- `weekTotalSessions`: sesiones previstas en la semana de `recommendedSession`.
- `completedSessions`: sesiones historicas completas.
- `storedSessions`: sesiones historicas con algun evento.
- `durationSamples`: hasta 5 sesiones con `startedAt` y `finishedAt`, ordenadas como el historial recibido.
- `averageDurationMinutes`: media redondeada de `durationSamples.actualMinutes`.
- `averageDeltaMinutes`: media redondeada de `durationSamples.deltaMinutes`.
- `warningInsights`, `upInsights`, `downInsights`: particiones de senales de progresion por `tone`.
- `skippedSets`: suma de series saltadas presentes en insights.
- `painHits`: suma de marcas de molestias presentes en insights.

Nota de implementacion:

- En la PWA, los filtros de semana y ejercicio se aplican en UI sobre `SessionHistorySummary[]`, `durationSamples` reconstruidos y `ExerciseProgressionSummary[]`.
- En Swift conviene mantener la misma separacion: agregados globales puros primero; filtros de consulta despues.

## ExerciseProgressInsight

Funcion: `getExerciseProgressInsights`.

Agrupa eventos por `exerciseId` y genera una recomendacion conservadora.

Datos base por ejercicio:

- `sortedEvents`: eventos del ejercicio ordenados por `performedAt` ascendente.
- `lastEvent`: ultimo evento registrado del ejercicio.
- `lastSession`: sesion del ultimo evento, con fallback a la primera sesion del plan que contenga el ejercicio.
- `lastExercise`: ejercicio dentro de `lastSession`.
- `nextSession`: primera sesion con fecha `>= todayIso` que contenga el ejercicio.
- `nextExercise`: ejercicio dentro de `nextSession`.
- `completedEvents`: eventos con `status === 'completed'`.
- `skippedSets`: eventos con `status === 'skipped'`.
- `recentEvents`: ultimos 12 eventos del ejercicio.
- `painHits`: eventos recientes con alguna molestia mayor que cero.
- `sessionEvents`: eventos del ejercicio en la ultima sesion registrada.
- `completedSets`: completadas en la ultima sesion registrada.
- `attemptedSets`: intentadas en la ultima sesion registrada.
- `plannedSets`: series planificadas en `lastExercise`; si falta el plan, usa `attemptedSets`.
- `lastCompletedEvent`: ultimo evento completado del ejercicio.
- `lastDecision`: decision guardada en metadata para `exerciseId`.
- `avgRecentRir`: media de RIR de las ultimas tres series completadas, o 0 si no hay series completadas.

Reglas de recomendacion, en orden:

1. Si hay al menos 2 molestias recientes o la decision contiene `molestia`: `tone = warning`, `recommendation = Revisar tecnica o carga`.
2. Si la decision contiene `bajar`: `tone = down`, `recommendation = lastDecision` o `Bajar carga`.
3. Si la decision contiene `subir`: `tone = up`, `recommendation = lastDecision` o `Subir carga`.
4. Si hay al menos 2 series saltadas o no se completaron todas las series previstas de la ultima exposicion: `tone = warning`, `recommendation = Mantener hasta completar series`.
5. Si `avgRecentRir >= 2.5` y se completaron todas las series previstas: `tone = up`, `recommendation = Candidato a subir`.
6. En cualquier otro caso: `tone = neutral`, `recommendation = Mantener y observar`.

Campos de salida:

- `exerciseName`: nombre de `nextExercise`, con fallback a `lastExercise` o `exerciseId`.
- `target`: objetivo formateado desde el siguiente objetivo planificado, con fallback al ultimo.
- `lastLoadKg`, `lastReps`, `lastDurationSeconds`, `lastRir`: salen del ultimo evento completado si existe.
- `completedSets`, `attemptedSets`, `plannedSets`, `skippedSets`, `painHits`: resumen de la ultima exposicion y eventos recientes segun las reglas anteriores.

Orden:

- Primero `warning`, despues `up`, despues `down`, despues `neutral`.
- Dentro de cada tono, por `nextDate` ascendente.
- La PWA limita la lista a 8 insights.

## ExerciseProgressionSummary

Funcion: `getExerciseProgressionSummaries`.

Construye una vista consultable por ejercicio con exposiciones historicas.

Agrupacion:

- Agrupa todos los eventos por `exerciseId`.
- Dentro de cada ejercicio, agrupa por `sessionId`.

Cada `ExerciseProgressionExposure` representa un ejercicio dentro de una sesion.

Campos calculados por exposicion:

- `sessionId`, `sessionDate`, `sessionLabel`: salen de la sesion del plan.
- `target`: objetivo de ese ejercicio en esa sesion.
- `attemptedSets`: eventos registrados del ejercicio en la sesion.
- `completedSets`: eventos completados.
- `plannedSets`: series del ejercicio en el plan; si falta, usa `attemptedSets`.
- `skippedSets`: eventos saltados.
- `topLoadKg`: mayor `actualWeightKg` completado y mayor que 0.
- `totalReps`: suma de `actualReps` en eventos completados.
- `totalDurationSeconds`: suma de `actualDurationSeconds` en eventos completados.
- `averageRir`: media de `rirLast` en eventos completados, redondeada a un decimal.
- `painHits`: eventos de esa exposicion con alguna molestia mayor que cero.
- `decision`: decision guardada en metadata para ese ejercicio y sesion, si existe.
- `lastPerformedAt`: ultimo evento del ejercicio en esa sesion.

Orden:

- Las exposiciones se ordenan por `lastPerformedAt` descendente.
- La PWA conserva hasta 8 exposiciones por ejercicio.
- Los ejercicios se ordenan por tono (`warning`, `up`, `down`, `neutral`) y despues por nombre.

## Pain hits

Funcion interna: `getPainHits`.

Cuenta un evento si cualquiera de estos campos es mayor que cero:

- `painKnee`
- `painWrist`
- `painShoulder`
- `painLowerBack`
- `painOther`

## Filtros actuales de UI

Pantalla: `Ajustes > Estadisticas`.

Filtro por semana:

- Usa `SessionHistorySummary.weekNumber`.
- Filtra duracion, ultimas sesiones y exposiciones de progresion.
- No cambia el resumen de adherencia de la semana recomendada.

Filtro por ejercicio:

- Usa `exerciseId`.
- Filtra senales, series saltadas, molestias y progresion.
- Al elegir un ejercicio concreto, la tarjeta de progresion se abre automaticamente.

## Consideraciones para Swift

Modelo recomendado:

```swift
struct TrainingStatsSummary: Codable {
    let weekNumber: Int
    let weekFocusLabel: String
    let weekCompletedSessions: Int
    let weekTotalSessions: Int
    let completedSessions: Int
    let storedSessions: Int
    let averageDurationMinutes: Int?
    let averageDeltaMinutes: Int?
    let latestSessions: [SessionHistorySummary]
    let durationSamples: [DurationSample]
    let warningInsights: [ExerciseProgressInsight]
    let upInsights: [ExerciseProgressInsight]
    let downInsights: [ExerciseProgressInsight]
    let skippedSets: Int
    let painHits: Int
}
```

Recomendaciones de portabilidad:

- Mantener estas funciones como servicios puros que reciban arrays y devuelvan structs.
- No depender de orden fisico de almacenamiento; ordenar explicitamente por timestamps.
- Mantener `exerciseId` y `sessionId` como claves estables.
- Tratar `target` como texto de presentacion; los calculos deben usar `sets` y eventos.
- Mantener las reglas de recomendacion versionadas si se ajustan con uso real.
