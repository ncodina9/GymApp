# Plan para app nativa iOS

Este documento define el alcance inicial de una futura app nativa de iPhone en Swift/SwiftUI. La PWA actual sigue siendo el prototipo funcional y el banco de pruebas, pero las decisiones nuevas deben facilitar que el producto pueda migrar sin reinterpretar datos ni flujo.

## Objetivo

Crear una primera app iOS nativa que replique el flujo esencial validado en la PWA:

- cargar el plan real desde `trainingPlan.json`
- recomendar el entrenamiento del dia
- previsualizar ejercicios, series, reps, tiempos y cargas
- ejecutar una sesion serie a serie
- registrar feedback despues de cada serie
- guiar descansos y transiciones
- guardar eventos localmente
- consultar historial basico
- importar un backup JSON completo exportado desde la PWA
- exportar CSV por serie y JSON estructurado

La primera version nativa debe buscar paridad funcional, no acumular integraciones iOS avanzadas desde el inicio.

## Principios

- El contrato de datos manda sobre la UI: `trainingPlan.json`, eventos de serie, metadata y export JSON deben ser compatibles con Swift `Codable`.
- La app nativa debe interpretar superseries, descansos, progreso y duracion con las mismas reglas que la PWA.
- La experiencia debe seguir siendo tactil y directa: numeros grandes, botones grandes, sin teclado durante el entrenamiento.
- La PWA no debe incorporar complejidad web-only que despues haya que descartar.
- El CSV es formato de analisis; el JSON completo es formato de migracion.

## Alcance v1 SwiftUI

Incluido:

- proyecto iOS SwiftUI iPhone-only
- carga local de `trainingPlan.json` desde el bundle de la app
- importacion manual de un backup JSON desde Archivos
- pantalla Hoy
- pantalla Preview con scroll
- pantalla Ejecucion de serie sin scroll
- pantalla Feedback sin scroll
- pantalla Descanso con temporizador circular
- pantalla Transicion entre ejercicios
- pantalla Finalizado con duracion real vs estimada
- pantalla Ajustes con importacion/exportacion
- historial simple de sesiones
- persistencia local mediante SwiftData

Fuera de v1:

- Apple Watch
- HealthKit
- Live Activities
- widgets
- iCloud/CloudKit
- notificaciones locales
- editor de plan
- autenticacion o backend
- soporte Android o web desde la app nativa

## Mapa de pantallas SwiftUI

| PWA actual | SwiftUI propuesto        | Responsabilidad                                                     |
| ---------- | ------------------------ | ------------------------------------------------------------------- |
| Hoy        | `TodayView`              | Entrenamiento recomendado, semana/foco, selector semanal y reanudar |
| Preview    | `SessionPreviewView`     | Preparar material antes de empezar, con scroll permitido            |
| Ejecucion  | `SetExecutionView`       | Serie actual, reps/peso/tiempo, controles tactiles                  |
| Feedback   | `SetFeedbackView`        | RIR, molestias, nota breve y estado OK por defecto                  |
| Descanso   | `RestTimerView`          | Cuenta atras circular, continuar y ajustes de descanso              |
| Transicion | `ExerciseTransitionView` | Notas y decision al cerrar ejercicio o superserie                   |
| Finalizado | `WorkoutFinishedView`    | Duracion real, comparacion estimada, exportacion                    |
| Ajustes    | `SettingsView`           | Tema, pantalla activa, datos locales, import/export                 |
| Historial  | `HistoryView`            | Sesiones guardadas, detalle y reexportacion                         |
| Progresion | `ProgressionView`        | Tendencias y proximas recomendaciones                               |

## Modelo de datos inicial

Modelos `Codable` para plan e importacion:

- `TrainingPlan`
- `TrainingSession`
- `Exercise`
- `TrainingSet`
- `FullTrainingDataExport`
- `ExportedSession`

Modelos persistidos con SwiftData:

- `SetEventRecord`
- `SessionMetadataRecord`
- `ExerciseDecisionRecord`
- `AppSettingsRecord`
- `ImportedPlanSnapshot`

Campos que deben ser enums Swift:

- `TrainingSet.type`: `working`, `timed`
- `StoredSetEvent.status`: `completed`, `skipped`
- `AppearanceTheme`: `system`, `light`, `dark`
- `WorkoutPhase`: `today`, `preview`, `set`, `feedback`, `rest`, `transition`, `done`, `settings`
- `LoadType`: `total`, `external`, `per_dumbbell`, `machine`, `bodyweight`

El plan puede seguir estando en JSON plano. SwiftData debe guardar el historico y los datos vivos, no sustituir el plan como fuente de verdad.

## Persistencia

Decision inicial: usar SwiftData para la primera app iOS.

Motivo:

- encaja bien con iPhone-only
- reduce codigo de infraestructura frente a SQLite manual
- permite evolucionar historial, busquedas y progresion sin backend
- mantiene una ruta natural hacia iCloud/CloudKit mas adelante

Uso recomendado:

- `trainingPlan.json` vive en el bundle y se decodifica con `JSONDecoder`
- un backup importado desde la PWA puede guardar tambien un snapshot del plan
- cada serie registrada se guarda inmediatamente como `SetEventRecord`
- metadata de sesion guarda `startedAt`, `finishedAt`, `exportedAt`, `schemaVersion`
- ajustes de app viven en un registro unico de settings
- el borrador de sesion activa puede guardarse en SwiftData o `AppStorage`; si se importa desde PWA, debe conservar `activeWorkout`

Alternativas descartadas para v1:

- Core Data: robusto, pero mas pesado para este alcance
- SQLite manual: buen control, mas coste inicial
- JSON local como unica persistencia: sencillo, pero peor para historial y consultas

## Importacion desde la PWA

Flujo recomendado:

1. En la PWA, abrir `Ajustes > Datos locales`.
2. Exportar `backup JSON`.
3. En la app iOS, elegir `Importar backup`.
4. Seleccionar el archivo desde Archivos.
5. Validar `schemaName === "gymapp.full-training-data-export"`.
6. Validar `schemaVersion`.
7. Decodificar `plan`, `settings`, `activeWorkout` y `sessions`.
8. Crear o actualizar snapshot del plan.
9. Insertar sesiones, eventos y decisiones evitando duplicados por `id`.
10. Marcar el origen como `pwa`.
11. Mostrar resumen de importacion: sesiones, series, ultima fecha y errores ignorados.

Reglas:

- campos desconocidos se ignoran
- schemas futuros deben fallar de forma explicita si no son compatibles
- eventos duplicados se ignoran, no se duplican
- el CSV no se usa para importar historico

## Logica portable desde la PWA

Reglas ya separadas:

- `lib/sessionExport.ts`: CSV, JSON completo, nombres de archivo e inferencia de tipo de carga
- `lib/workoutSequence.ts`: pasos de ejercicios, series y superseries
- `lib/sessionDuration.js`: estimacion operativa de duracion
- `lib/sessionSelection.ts`: seleccion del entrenamiento recomendado, resolucion por id y entrenamientos de la semana

Reglas pendientes de separar antes de crear el prototipo SwiftUI:

- progreso de sesion y resumen historico
- recomendaciones conservadoras de progresion
- reglas de material disponible y siguiente carga
- limpieza/purga de sesiones exportadas

## Equivalencia de flujo

Secuencia normal:

1. `TodayView`
2. `SessionPreviewView`
3. `SetExecutionView`
4. `SetFeedbackView`
5. `RestTimerView`
6. repetir hasta cerrar ejercicio
7. `ExerciseTransitionView`
8. repetir hasta cerrar sesion
9. `WorkoutFinishedView`

Secuencia temporizada:

1. `SetExecutionView` muestra timer circular
2. iniciar cuenta atras
3. al llegar a cero, estado visual verde y mensaje `Ejercicio terminado`
4. continuar a feedback

Secuencia de superserie:

1. ejecutar ejercicio A1 ronda 1
2. feedback de A1
3. transicion interna sin descanso largo
4. ejecutar A2 ronda 1
5. feedback de A2
6. descanso al cerrar la ronda completa
7. repetir rondas

## Capacidades iOS posteriores

Prioridad alta despues de v1:

- notificacion local al terminar descanso
- Live Activity para descanso y sesion activa
- haptics nativos en registro, descanso terminado y errores

Prioridad media:

- HealthKit para guardar entrenamientos completados
- widgets con proximo entrenamiento y progreso semanal
- iCloud/CloudKit para backup y sincronizacion

Prioridad posterior:

- Apple Watch companion app
- Atajos/Siri
- editor nativo del plan

## Validacion del prototipo SwiftUI

El primer prototipo se considera util cuando:

- carga el mismo `trainingPlan.json` que la PWA
- muestra correctamente la sesion recomendada del dia
- ejecuta una sesion completa sin scroll en pantallas de entrenamiento
- respeta superseries y descansos como la PWA
- guarda cada serie como evento
- permite cerrar y reabrir la app conservando sesion activa
- importa un backup JSON real exportado desde la PWA
- exporta CSV con la misma estructura por serie

## Estructura recomendada de repo

Mantener la app nativa dentro del mismo repositorio mientras comparta plan y scripts:

```text
GymApp/
  app/                    PWA actual
  data/trainingPlan.json  Plan fuente de verdad
  docs/
  ios/GymAppNative/       Futuro proyecto SwiftUI
  lib/                    Reglas TypeScript/JavaScript portables
  scripts/                Generacion y validacion del plan
```

Si la app iOS crece lo suficiente, se podra extraer a un repositorio propio conservando `data/trainingPlan.json` y los schemas como contrato.
