# Roadmap companion app de entrenamiento

## Objetivo

Crear una companion app para iPhone orientada a ejecutar el entrenamiento en el gimnasio con el mínimo rozamiento posible. La app debe decir claramente que toca hacer ahora, permitir ajustar carga y repeticiones con controles tactiles rapidos, registrar la serie y guiar el descanso hasta la siguiente accion.

La PWA actual debe servir como prototipo funcional y banco de pruebas del producto. El objetivo final, si el uso real confirma el flujo, es evolucionar hacia una app nativa de iPhone en Swift/SwiftUI para aprovechar mejor iOS: HealthKit, Apple Watch, Live Activities, notificaciones locales, haptics, widgets, Atajos e iCloud.

El plan de entrenamiento no debe ser una plantilla generica de 4 dias repetida. El JSON de planificacion debe contener todas las sesiones del trimestre, dia por dia, con pesos, repeticiones, descansos, notas y decisiones ya ajustadas para la semana concreta del plan.

## Principios de producto

- La pantalla principal debe priorizar la accion inmediata del entrenamiento que toca hoy.
- Los numeros importantes deben ser grandes: ejercicio actual, reps objetivo, peso objetivo y descanso.
- Algunos ejercicios se miden por tiempo, no por reps y peso. En esos casos la pantalla de serie debe mostrar un timer tactil con cuenta atras visible.
- La interaccion debe evitar selectores, formularios largos y teclado en mitad del entrenamiento.
- Los ajustes de peso y reps deben resolverse con controles tactiles directos: botones grandes de sumar/restar, steppers, swipes o ruedas propias.
- La app debe aprovechar la pantalla del iPhone mejor que una app pensada para Apple Watch, tomando como referencia la fluidez tactil de GymBook Watch.
- El registro explicito de todo lo completado no es prioritario durante la sesion. Debe bastar con progreso visual claro y confianza en que se esta guardando.
- Cada serie debe poder saltarse con un boton pequeno y deliberadamente secundario para evitar pulsaciones accidentales.
- La app debe ser offline-first: usable en el gimnasio sin cobertura, con guardado local inmediato tras cada accion relevante.
- La sincronizacion/exportacion puede venir despues. No debe bloquear el flujo principal.
- Aunque la primera version sea PWA, las decisiones de datos y arquitectura deben facilitar una futura migracion a app nativa de iPhone.
- La logica de dominio no debe quedar acoplada innecesariamente a React ni a APIs web si puede expresarse como reglas puras y portables.
- Todo dato local importante debe poder exportarse en un formato estructurado, versionado y compatible con una futura importacion en Swift.

## Flujo principal

1. Abrir la app.
2. Ver el entrenamiento que teoricamente toca ese dia.
3. Poder cambiar a cualquier entrenamiento planificado para esa semana.
4. Entrar en la previsualizacion del entrenamiento seleccionado.
5. Revisar ejercicios, series, cargas y descansos para preparar material.
6. Empezar la sesion.
7. Ver el ejercicio actual con:
   - nombre del ejercicio
   - serie actual y series totales
   - reps objetivo
   - peso objetivo
   - descanso propuesto
   - notas breves si aplican
8. Ajustar reps o peso sin teclado.
9. Registrar la serie.
10. Lanzar automaticamente una pantalla de cuenta atras del descanso.
11. Al terminar el descanso, permitir pasar a la siguiente serie.
12. Al finalizar un ejercicio, mostrar notas y decisiones proximas como opciones pulsables.
13. Pasar al siguiente ejercicio hasta cerrar la sesion.
14. Guardar el resultado localmente y preparar exportacion posterior.

## Pantallas iniciales

### Hoy

Primera pantalla de la app. Debe mostrar:

- entrenamiento recomendado para hoy
- dia del plan y semana del ciclo
- estado simple: pendiente, en curso o completado
- acceso a los demas entrenamientos de la semana
- boton principal para revisar el entrenamiento antes de empezar
- accion de reanudar si hay un entrenamiento en curso

### Previsualizacion de entrenamiento

Pantalla previa al inicio real de la sesion. Puede tener scroll porque se usa antes de entrenar, no durante una serie.

- resumen del entrenamiento seleccionado
- listado de ejercicios en orden
- series previstas por ejercicio
- reps, tiempos y pesos previstos
- indicacion clara de superseries y orden dentro del bloque
- boton principal para empezar entrenamiento

### Ejecucion de serie

Pantalla central del producto. Debe mostrar un ejercicio cada vez:

- nombre del ejercicio
- marcador visual de series mediante circulos: rellenos para series hechas, vacios para series pendientes
- reps objetivo en grande
- peso objetivo en grande
- controles tactiles para subir/bajar reps y peso
- si la serie es temporizada, cuenta atras grande con boton de iniciar/pausar y reinicio
- boton principal para registrar serie
- boton secundario pequeno para saltar serie

### Descanso

Pantalla posterior al registro de una serie:

- cuenta atras grande
- circulo de progreso que se vacia conforme avanza el descanso
- siguiente accion visible
- opcion de acortar o alargar descanso con controles tactiles
- boton para continuar cuando el descanso termine

### Transicion de ejercicio

Pantalla breve al completar todas las series de un ejercicio:

- resumen minimo del ejercicio completado
- notas utiles del siguiente ejercicio
- decision proxima como opciones pulsables, por ejemplo:
  - mantener carga
  - subir carga
  - bajar carga
  - marcar molestia
  - saltar ejercicio

## Datos de planificacion

El plan trimestral debe estar materializado en JSON con sesiones completas. No basta con guardar una definicion semanal y calcular todo en runtime.

Estructura conceptual:

```json
{
  "planId": "training-plan-2026-q4",
  "startsOn": "2026-09-07",
  "durationWeeks": 12,
  "sessions": [
    {
      "date": "2026-09-07",
      "week": 1,
      "weekday": "monday",
      "label": "Torso fuerza",
      "estimatedMinutes": 60,
      "exercises": [
        {
          "exerciseId": "dumbbell-bench-press",
          "name": "Press de banca con mancuernas",
          "notes": "Mantener escapulas fijadas y recorrido estable.",
          "sets": [
            {
              "setIndex": 1,
              "targetReps": 8,
              "targetWeightKg": 62.5,
              "restSeconds": 120,
              "type": "working"
            },
            {
              "setIndex": 2,
              "targetWeightKg": 0,
              "targetDurationSeconds": 45,
              "restSeconds": 45,
              "type": "timed"
            }
          ]
        }
      ]
    }
  ]
}
```

Campos que deben existir desde la primera version funcional:

- `date`
- `week`
- `weekday`
- `sessionLabel`
- `exerciseId`
- `exerciseName`
- `setIndex`
- `targetReps`
- `targetWeightKg`
- `targetDurationSeconds` para series por tiempo
- `restSeconds`
- `notes`
- `decisionOptions`

## Datos de registro

El registro debe guardar cada serie como evento, no solo como resumen final.

Campos minimos:

- `performedAt`
- `planId`
- `sessionDate`
- `sessionId`
- `exerciseId`
- `setIndex`
- `supersetId` si aplica
- `supersetOrder` si aplica
- `roundNumber` si aplica
- `plannedReps`
- `plannedWeightKg`
- `plannedDurationSeconds` si aplica
- `actualReps`
- `actualWeightKg`
- `actualDurationSeconds` si aplica
- `restSecondsPlanned`
- `restSecondsActual`
- `status`: `completed` o `skipped`
- `rirLast`
- `painKnee`
- `painWrist`
- `painOther`
- `note`

Mas adelante se podran anadir calidad tecnica, tempo, velocidad percibida o notas estructuradas por ejercicio.

## Entrenamiento base

Contexto confirmado en la conversacion previa:

- Frecuencia habitual: 4 dias por semana.
- Dias preferidos: lunes, martes, jueves y viernes.
- Duracion objetivo: 1 hora por sesion.
- Material confirmado: multipower, rack y polea simple.
- Ejercicios relevantes para el plan: press de banca, elevaciones laterales, sentadillas, hip thrust, curl de biceps, peso muerto y dominadas.
- Historial disponible: exportacion de GymBook de aproximadamente los ultimos 3 meses.
- Referencias recientes inferidas del historial:
  - hip thrust / puente con barra: hasta 90 kg x 12
  - peso muerto rumano con barra: hasta 70 kg x 12
  - sentadilla con barra: hasta 70 kg x 10
  - press banca con mancuernas: hasta 70 kg x 10
  - press inclinado con mancuernas: hasta 55 kg x 10
  - remo inclinado con barra: hasta 55 kg x 10
  - press militar de pie: entorno 38-40 kg x 10
  - curl biceps mancuernas: hasta 17.5 kg x 10-12
  - dominadas: series de hasta 10 reps con peso corporal

Pendiente de confirmar antes de cerrar pesos definitivos:

- objetivo principal del trimestre
- molestias o ejercicios a evitar
- interpretacion exacta de pesos en ejercicios con mancuernas
- material disponible completo
- intensidad real de las mejores series recientes

## Arquitectura propuesta

Primera version como PWA offline-first. Esta PWA no se considera necesariamente el producto final, sino la forma mas rapida de validar el flujo real de entrenamiento antes de invertir en una app nativa iOS.

Stack inicial recomendado:

- React + TypeScript + Vite
- CSS propio o Tailwind si se decide priorizar velocidad de UI
- IndexedDB para registros locales
- JSON versionado para planificacion
- service worker para funcionamiento offline
- exportacion Markdown/CSV en una fase posterior

La app debe poder alojarse como sitio estatico. No hace falta Northflank para la primera version si no hay backend. Un alojamiento estatico con soporte HTTPS es suficiente para instalarla como PWA en iPhone. Si despues necesitamos sincronizacion multi-dispositivo, cuentas de usuario o backups automaticos, se reevaluara backend.

Preparacion para iOS nativo:

- mantener `trainingPlan.json` como contrato de datos estable y compatible con `Codable`
- documentar versiones de esquema para plan, eventos, metadata, ajustes y exportaciones
- separar reglas de dominio de la UI: seleccion de sesion, secuenciador, progreso, estimaciones, recomendaciones y exportacion
- evitar dependencias profundas de APIs web para logica que despues deba vivir en Swift
- anadir exportacion JSON completa para migrar historico local desde IndexedDB a una futura app SwiftUI
- conservar los scripts de generacion del plan como pipeline externo mientras aporten valor

## Hitos

### Resumen operativo

| Hito | Estado    | Urgencia | Complejidad | Descripcion                                                                      |
| ---- | --------- | -------- | ----------- | -------------------------------------------------------------------------------- |
| 0    | Cerrado   | Baja     | Baja        | Repositorio y base de proyecto.                                                  |
| 1    | Cerrado   | Baja     | Media       | Prototipo navegable del flujo principal de entrenamiento.                        |
| 2    | Cerrado   | Baja     | Alta        | Plan JSON trimestral completo y explicito por fecha.                             |
| 3    | Cerrado   | Baja     | Media       | Persistencia local de entrenamientos y series.                                   |
| 4    | Parcial   | Media    | Media       | Exportacion CSV y puente con Obsidian; Markdown queda pendiente si aporta valor. |
| 5    | Cerrado   | Baja     | Media       | PWA instalable en iPhone con cache basica.                                       |
| 5a   | Cerrado   | Baja     | Baja        | Prueba local en iPhone desde red local.                                          |
| 6    | Cerrado   | Baja     | Baja        | Despliegue privado mediante GitHub/Vercel.                                       |
| 7    | Cerrado   | Baja     | Alta        | Superseries v1 en secuenciador, preview y CSV.                                   |
| 8    | Cerrado   | Baja     | Alta        | Planning ajustado a planchas de 60 s y material real.                            |
| 9    | Cerrado   | Baja     | Baja        | Textos visibles con acentos y eñes.                                              |
| 10   | Cerrado   | Baja     | Media       | Pantalla siempre encendida cuando el navegador lo soporta.                       |
| 11   | En curso  | Alta     | Media       | Validacion continua con uso real en gimnasio.                                    |
| 12   | Parcial   | Media    | Media       | Pulido tactil y visual de controles.                                             |
| 13   | Cerrado   | Baja     | Alta        | Robustez de persistencia, exportacion y purga de historico.                      |
| 14   | Cerrado   | Baja     | Media       | Duracion real y estimacion operativa del entrenamiento.                          |
| 14b  | Cerrado   | Baja     | Alta        | Planning reajustado a 60-70 min estimados.                                       |
| 14c  | Cerrado   | Baja     | Alta        | Ajustes tras primera sesion real.                                                |
| 14d  | Cerrado   | Baja     | Media       | Consulta de proximos entrenamientos desde Ajustes.                               |
| 15   | Cerrado   | Baja     | Alta        | Superseries v2 con validacion automatica.                                        |
| 16   | Parcial   | Media    | Media       | Progresion asistida conservadora dentro de Ajustes.                              |
| 17   | Cerrado   | Baja     | Media       | Instalacion/offline mas solida y estado de service worker.                       |
| 18   | Pendiente | Baja     | Media       | Layout movil horizontal; de momento la app bloquea vertical.                     |
| 19   | Parcial   | Media    | Media       | Historial dentro de la app con exportacion y borrado.                            |
| 20   | Parcial   | Alta     | Alta        | Preparacion PWA -> app nativa iOS y contrato JSON completo.                      |
| 21   | En pausa  | Baja     | Alta        | Estadisticas y graficos locales, retirados temporalmente de la UI PWA.           |
| 22   | Pendiente | Media    | Alta        | Generador guiado de planes desde la app.                                         |
| 23   | Pendiente | Baja     | Alta        | Capa opcional de IA para planificacion y analisis.                               |
| 24   | Parcial   | Alta     | Alta        | Selector de material por ejercicio y dia con redondeo de cargas.                 |

Estados usados:

- `Pendiente`: no empezado.
- `En curso`: se valida o ajusta de forma recurrente.
- `Parcial`: hay una v1 funcional, pero quedan tareas definidas.
- `Cerrado`: cumple el criterio actual y solo recibiria mejoras futuras.

### Estado actual

Ya esta implementada una primera version funcional de la app:

- proyecto versionado en GitHub y conectado con Vercel
- app React/Vinext con UI tactil orientada a iPhone
- cabecera compacta con semana y foco semanal del bloque
- pantalla Hoy con recomendacion de entrenamiento y seleccion semanal
- reanudacion de entrenamiento iniciado
- previsualizacion previa con ejercicios, series, reps/tiempo y pesos
- pantalla de serie sin teclado, con controles grandes de reps/peso
- ajuste de peso segun material real del ejercicio
- soporte para ejercicios temporizados con cuenta atras circular
- feedback despues de cada serie, antes del descanso
- descanso con cuenta atras horizontal y ajuste de `-15s` / `+15s`
- persistencia local con IndexedDB y recuperacion del borrador desde `localStorage`
- ajustes organizados por secciones: apariencia, entrenamiento, instalacion, datos locales, estadisticas e historial
- temas claro y oscuro minimalistas
- iconos PWA y manifest para instalacion en iPhone
- service worker basico
- exportacion CSV por serie
- plan trimestral real en `data/trainingPlan.json`
- generador del plan en `scripts/generate-training-plan.mjs`
- superseries v1 mediante bloques `E1/E2`, `F1/F2`, etc.
- planchas ajustadas a series de 60 s
- cargas del plan ajustadas al material disponible: barra, multipower, mancuernas, discos y polea
- equipamiento elegido por ejercicio en el JSON para evitar alternativas ambiguas y calcular cargas montables
- textos visibles de la app con acentos y eñes
- ajuste opcional para mantener la pantalla encendida cuando el navegador lo soporte
- colores ligeros por tipo de acción secundaria en controles táctiles

Validaciones habituales antes de publicar:

```bash
npm --cache /private/tmp/gymapp-npm-cache run format
npm --cache /private/tmp/gymapp-npm-cache run lint
npm --cache /private/tmp/gymapp-npm-cache run build
npm --cache /private/tmp/gymapp-npm-cache run build:vercel
```

### Hito 0: Repositorio y base de proyecto

Objetivo: dejar el proyecto listo para iterar.

Entregables:

- inicializar repositorio Git local
- crear proyecto React/Vite
- definir estructura de carpetas
- anadir README minimo
- dejar este roadmap versionado

Criterio de aceptacion:

- la app arranca en local
- hay una pantalla inicial vacia o placeholder
- el repositorio esta listo para subirse a GitHub

### Hito 1: Prototipo navegable del flujo de entrenamiento

Objetivo: validar la experiencia tactil antes de construir persistencia completa.

Entregables:

- pantalla Hoy
- selector simple de entrenamientos de la semana
- previsualizacion del entrenamiento antes de empezar
- pantalla de ejecucion de serie
- circulos de progreso de series
- controles tactiles de reps y peso
- boton de registrar serie
- boton secundario para saltar serie
- pantalla de descanso
- avance a siguiente serie y ejercicio

Criterio de aceptacion:

- se puede completar una sesion ficticia de principio a fin sin teclado
- los numeros principales son legibles de un vistazo en iPhone
- saltar serie requiere una accion clara y no domina la pantalla

### Hito 2: Plan JSON trimestral completo

Objetivo: convertir el plan de entrenamiento en datos consumibles por la app.

Entregables:

- esquema JSON del plan
- generacion manual o semiautomatica de 12 semanas x 4 dias
- pesos, reps y descansos definidos por fecha
- notas por ejercicio
- opciones de decision al finalizar ejercicios clave

Criterio de aceptacion:

- la app puede leer el entrenamiento correcto para una fecha concreta
- se puede cambiar a cualquier entrenamiento de la misma semana
- no hay calculo implicito de cargas por semana dentro de la UI

### Hito 3: Persistencia local de sesiones

Objetivo: que el entrenamiento no se pierda aunque se cierre Safari o falle la conexion.

Entregables:

- almacenamiento local de sesion en curso
- guardado de cada serie como evento
- reanudacion de sesion empezada
- estado completado por sesion

Criterio de aceptacion:

- cerrar y reabrir la app mantiene el punto exacto de la sesion
- cada serie registrada queda guardada con reps, peso, descanso y estado

### Hito 4: Exportacion y puente con Obsidian

Objetivo: sacar los registros en formatos utiles para analisis personal.

Entregables:

- exportacion CSV
- exportacion Markdown por sesion
- formato compatible con futuras graficas en Obsidian
- documentacion del flujo de importacion

Criterio de aceptacion:

- al terminar una sesion se puede generar una nota legible
- los datos tabulares permiten graficar volumen, cargas y adherencia

### Hito 5: PWA instalable en iPhone

Objetivo: probar la app en el gimnasio en condiciones reales.

Entregables:

- manifest PWA
- service worker
- iconos basicos
- cache offline de app y plan
- build estatico desplegable

Criterio de aceptacion:

- la app se instala en el iPhone
- abre sin red despues de haber cargado una vez
- el flujo de entrenamiento sigue funcionando offline

### Hito 5a: Prueba local en iPhone antes de PWA

Objetivo: validar tacto, altura real de Safari iOS y exportacion antes de invertir en instalacion/offline.

Entregables:

- script `dev:host` para servir la app en la red local
- guia de prueba en iPhone real
- checklist de pantallas criticas

Criterio de aceptacion:

- el iPhone abre la app desde `http://IP_DEL_MAC:3000/`
- las pantallas de serie, feedback, descanso y serie temporizada funcionan sin scroll indeseado
- se puede validar el guardado/exportacion CSV desde Safari iOS

### Hito 6: Despliegue privado

Objetivo: acceder a la app desde el iPhone sin depender del ordenador.

Entregables:

- despliegue privado o URL no indexada
- instrucciones minimas para instalar en pantalla de inicio
- verificacion en iPhone

Criterio de aceptacion:

- la app se abre desde una URL HTTPS
- se puede instalar como PWA
- el plan y el registro local funcionan en el dispositivo

### Hito 7: Superseries v1

Objetivo: permitir bloques vinculados en los que un ejercicio lleva al siguiente y el descanso se inicia al completar la ronda.

Entregables:

- deteccion de superseries desde bloques `E1/E2`, `F1/F2`, etc.
- secuenciador de entrenamiento por pasos, compatible con ejercicios normales y superseries
- avance alterno dentro de una superserie: `A1 serie 1 -> A2 serie 1 -> descanso -> A1 serie 2`
- pantalla de preview con indicacion de superserie y orden dentro del bloque
- pantalla de decision compatible con varios ejercicios al cerrar una superserie
- exportacion CSV con `superset_id`, `superset_order` y `round_number`

Criterio de aceptacion:

- los entrenamientos sin superseries mantienen el flujo actual
- al terminar el primer ejercicio de una superserie no aparece descanso
- al terminar el ultimo ejercicio de la ronda aparece el descanso
- al cerrar la ultima ronda se pueden registrar decisiones para los ejercicios vinculados
- el CSV conserva el orden real de registro y permite reconstruir la superserie

## Siguientes hitos

### Hito 8: Planning ajustado a material real

Prioridad: 1.

Objetivo: que el plan que ve la app use cargas realmente montables con el material disponible.

Tareas:

- fijar las planchas a duraciones de 60 s siempre
- redondear mancuernas a la lista disponible: `5`, `6`, `7.5`, `8`, `9`, `10`, `12.5`, `15`, `17.5`, `20`, `22.5`, `25`, `27.5`, `30`
- redondear barra a combinaciones simétricas de barra de 20 kg y discos disponibles
- redondear multipower a combinaciones simétricas de barra de 18 kg y discos disponibles
- redondear lastre a combinaciones de discos disponibles
- redondear polea a saltos de 5 kg hasta 100 kg cuando haya carga conocida
- regenerar `data/trainingPlan.json` desde `scripts/generate-training-plan.mjs`
- validar que no quedan pesos no montables ni planchas de 45 s

Criterio de aceptacion:

- todas las planchas del JSON muestran `60s`
- todo `targetWeightKg` no nulo corresponde a una carga disponible
- los ejercicios con varias variantes de material quedan fijados a una opcion concreta en el plan
- las opciones de subir/bajar carga proponen también pesos disponibles

### Hito 9: Textos completos en español

Prioridad: 2.

Objetivo: que los textos visibles de la app y del plan usen acentos y eñes correctamente.

Tareas:

- revisar labels de la app: configuración, preparación, después, muñeca, máquina, etc.
- revisar nombres y notas generados en el plan
- revisar metadatos y manifest de la PWA
- mantener slugs e ids sin acentos cuando deban ser estables o técnicos

Criterio de aceptacion:

- no quedan textos visibles sin acento por limitacion tecnica inexistente
- ids, rutas y claves siguen siendo estables y ASCII cuando conviene

### Hito 10: Pantalla siempre encendida

Prioridad: 3.

Objetivo: permitir que el iPhone no se bloquee durante el entrenamiento cuando el navegador lo soporte.

Tareas:

- añadir una preferencia en Ajustes para mantener pantalla encendida
- guardar la preferencia localmente
- solicitar `screen wake lock` mientras la app está visible
- liberar el bloqueo al desactivar la preferencia o cerrar la app
- degradar sin error si Safari/iOS no soporta la API

Criterio de aceptacion:

- el ajuste aparece en la pantalla de configuración
- activar o desactivar el ajuste no interrumpe el entrenamiento
- en navegadores compatibles la pantalla se mantiene encendida
- en navegadores no compatibles la app sigue funcionando normalmente

Estado: cerrado tras prueba real en iPhone. El ajuste muestra `Activa en este dispositivo` y evita el bloqueo durante el entrenamiento.

### Hito 11: Validación real en iPhone

Objetivo: probar la app como se usara en el gimnasio y corregir fricciones de uso real.

Tareas:

- instalar la PWA desde la URL de Vercel en el iPhone
- completar una sesion normal de principio a fin
- completar una sesion con superserie de principio a fin
- probar cierre y reapertura durante una sesion iniciada
- probar uso con poca o ninguna cobertura despues de haber cargado la app
- exportar un CSV desde iPhone y guardarlo en Archivos
- revisar altura disponible en Safari/PWA instalada
- anotar pantallas donde aparezca scroll no deseado durante serie, feedback o descanso

Criterio de aceptacion:

- se puede entrenar sin depender del Mac
- no se pierde el progreso al cerrar la app
- la exportacion CSV se puede guardar desde el iPhone
- el flujo de superseries se entiende sin tener que pensarlo

### Hito 12: Pulido táctil y visual de controles

Objetivo: que la app se sienta más cómoda en mano durante el entrenamiento.

Tareas:

- ajustar el selector de incremento de peso según el tipo de carga del ejercicio
- en barra/multipower, cambiar peso usando discos por lado: `1.25`, `2.5` o `5 kg`
- en lastre, cambiar peso con discos sueltos: `1.25`, `2.5` o `5 kg`
- en mancuernas, ocultar selector central y saltar directamente a la siguiente mancuerna disponible
- en polea, usar saltos fijos de `5 kg`
- homogeneizar alturas y radios de todos los botones inferiores
- revisar separación respecto al borde inferior y `safe-area-inset-bottom`
- aplicar colores ligeros diferenciados para acciones secundarias: volver, saltar, reset, `+`, `-`, `+15s`, `-15s`
- asegurar que esos colores funcionan en tema claro y oscuro
- revisar tamaños de fuente de reps, peso y timers en iPhone real
- mejorar estados activos/pulsados para que el tacto sea evidente
- evitar truncado de pesos con decimales en preview y pantalla de serie

Criterio de aceptacion:

- todos los botones principales y secundarios tienen una jerarquía clara
- los controles son fáciles de pulsar con una mano
- no hay texto importante cortado en iPhone
- los cambios de peso propuestos durante la serie respetan el material disponible

### Hito 13: Robustez de persistencia y exportacion

Objetivo: hacer mas fiable el ciclo registro local -> CSV -> Obsidian/Archivos.

Tareas:

- [x] mostrar estado simple de guardado local despues de registrar una serie
- [x] proteger contra doble pulsacion accidental en `Registrar serie`
- [x] permitir reexportar un entrenamiento terminado sin perder datos
- [x] listar entrenamientos con datos locales desde Ajustes
- [x] borrar los datos de una sesion concreta sin borrar todo el historico local
- [x] marcar sesiones exportadas con `exportedAt`
- [x] purgar automaticamente sesiones exportadas cuando cumplan el periodo de retencion local
- [x] no purgar sesiones sin exportar para evitar perdida silenciosa de datos
- [x] mostrar progreso de historial como series registradas / series planificadas
- [x] sustituir chips numericos ambiguos por estado: en curso, completo o exportado
- [x] guardar metadata basica de sesion: `schemaVersion`, `startedAt`, `finishedAt`, `exportedAt`
- [x] bloquear el registro mientras se guarda una serie para evitar doble pulsacion
- [x] definir si se guarda también un resumen por ejercicio además del CSV por serie
- [x] documentar el flujo recomendado para guardar el CSV en una ruta de Archivos del iPhone
- [x] revisar compatibilidad del CSV con el fichero maestro de Obsidian
- [x] decidir si el CSV debe incluir version de esquema
- [x] valorar importacion o concatenacion posterior de varios CSV

Criterio de aceptacion:

- cada serie registrada queda persistida una sola vez
- el usuario entiende donde queda el CSV y como moverlo al repositorio personal
- los campos exportados permiten analizar volumen, carga, RIR, molestias y superseries

Estado: cerrado para el alcance actual.

- historial local visible desde Ajustes, con scroll permitido en esa pantalla
- exportacion CSV de sesiones con datos sin depender de estar en la pantalla final
- CSV por serie ampliado con `performed_at` para comparar tiempos reales entre series y ejercicios
- feedback de molestias ampliado con hombro y lumbar
- borrado de una sesion concreta desde Ajustes
- al cerrar un entrenamiento y volver a hoy, se conserva la sesion finalizada para exportarla despues
- sesiones exportadas marcadas en IndexedDB con `exportedAt`
- purga automatica de sesiones exportadas con mas de 30 dias de antiguedad
- las tarjetas de historial muestran `series registradas / series planificadas`
- chip de historial cambiado a estado legible: en curso, completo o exportado
- registro de serie protegido contra doble pulsacion con bloqueo visual y bloqueo interno
- metadata local de sesion ampliada con `schemaVersion`, `startedAt`, `finishedAt` y `exportedAt`
- estado contextual `Guardando`/`Guardado` visible tras registrar una serie
- flujo de guardado en Archivos documentado en `docs/vercel-pwa-testing.md`
- decision cerrada: el CSV por serie no incluye columnas `schema_name` ni `schema_version` por fila para seguir siendo apendable al maestro de Obsidian; el contrato actual queda documentado como `gymapp.workout-set-export` version 2 y el importador mantiene compatibilidad con exports v1
- decision cerrada: no se genera un segundo resumen por ejercicio desde el flujo principal porque el CSV estadistico y el backup JSON completo ya cubren ese analisis sin duplicar fuentes

### Hito 14: Duracion real del entrenamiento

Objetivo: medir cuanto dura una sesion y compararlo con la estimacion del plan.

Tareas:

- guardar `startedAt` al pulsar `Empezar entrenamiento`
- guardar `finishedAt` al cerrar la sesion
- mostrar duracion real al finalizar
- comparar duracion real contra `estimatedMinutes`
- calcular una estimacion derivada desde el plan con movilidad previa, ejecucion de series, descansos, feedback y cambios entre ejercicios
- mostrar en la preview si la sesion parece ajustada o si conviene revisar el planning
- incluir duracion real en el CSV o en un futuro resumen de sesion
- decidir si las pausas manuales o interrupciones cuentan dentro del tiempo total

Criterio de aceptacion:

- al terminar se ve el tiempo real invertido
- la app indica si la sesion fue mas corta, similar o mas larga que lo previsto
- la informacion queda disponible para revision posterior

Estado parcial:

- `startedAt` se guarda al empezar entrenamiento
- `finishedAt` se guarda al cerrar entrenamiento
- al finalizar se muestra la duracion real, el tiempo estimado de entrenamiento sin movilidad y la diferencia
- el historial muestra la duracion de las sesiones cerradas cuando existe metadata suficiente
- la estimacion operativa ya no depende solo del campo manual `estimatedMinutes`
- la preview desglosa movilidad, trabajo, cambios/feedback y marca sesiones que superan claramente el objetivo de 60 min
- la movilidad previa se mantiene dentro de la estimacion global de la preview, pero se excluye de la comparacion final de tiempo real porque el entrenamiento empieza al entrar en la primera serie

Formula actual de estimacion derivada:

- movilidad previa: 9 min
- ejecucion de serie temporizada: duracion objetivo de la serie
- ejecucion de serie por reps: `max(20 s, reps objetivo x 4 s)`
- feedback por serie: 8 s
- descanso: descansos planificados del secuenciador, sin descanso entre ejercicios vinculados de una misma ronda de superserie
- cambio entre ejercicios independientes: 45 s
- transicion interna dentro de superserie: 15 s

Auditoria inicial del plan actual con esta formula:

- sesiones totales: 51
- sesiones estimadas en 65 min o menos: 14
- sesiones estimadas por encima de 65 min: 37
- sesiones estimadas por encima de 75 min: 30
- peor caso detectado: `2026-12-10 Torso volumen y potencia`, 115 min estimados, 36 series

Estado: cerrado para la app. Queda como decision futura si la duracion total debe anadirse tambien al CSV por serie o a un resumen independiente de sesion. Las sesiones estimadas por encima de 75 min deben revisarse porque probablemente no caben en una hora real de gimnasio.

### Hito 14c: Ajustes tras primera sesion real

Objetivo: incorporar fricciones detectadas entrenando en gimnasio real sin romper la filosofia de pantallas sin scroll durante serie, feedback y descanso.

Tareas:

- mostrar en descanso la siguiente serie con `serie x/total`, reps/tiempo y peso
- pedir decision de ejercicio antes del descanso largo entre ejercicios
- ampliar molestias con hombro y lumbar
- hacer temporizadores resilientes a perdida de foco usando hora objetivo en vez de decremento por intervalos
- aumentar tamano de botones inferiores de navegacion
- redisenar modificacion puntual de reps/peso en pantalla propia con confirmar/cancelar
- hacer los cuadros de reps/peso clicables y mas bajos tras retirar los botones `+/-`
- marcar en Hoy los entrenamientos completados de la semana
- cuando todos los entrenamientos de la semana esten completos, mostrar por defecto la semana siguiente

Criterio de aceptacion:

- durante el descanso se puede preparar la siguiente carga sin volver a preview
- al cerrar un ejercicio se puede decidir subir, bajar o mantener antes del descanso
- bloquear y desbloquear el iPhone no reinicia ni desfasa el descanso o temporizador de ejercicio
- el registro sigue siendo rapido si no se necesita modificar el peso o las reps recomendadas

Estado parcial:

- descanso muestra siguiente serie con metrics compactas
- decision de ejercicio se solicita antes del descanso entre ejercicios
- feedback de molestias incluye hombro y lumbar
- temporizadores recalculan por `endsAt` al recuperar foco
- comparacion final de duracion usa estimacion sin movilidad previa
- cuadros de reps/peso en pantalla de serie son clicables y no muestran `+/-`
- modificacion puntual de reps/peso se hace en pantalla propia con confirmar/cancelar
- mancuernas saltan directamente a la siguiente mancuerna disponible; barra/lastre/polea siguen usando saltos segun material real
- Hoy marca entrenamientos completados en la semana visible
- si la semana recomendada por fecha esta completa, Hoy salta por defecto a la primera sesion pendiente de la semana siguiente

### Hito 14d: Consulta de proximos entrenamientos

Objetivo: poder consultar desde Ajustes los entrenamientos futuros del planning activo sin iniciar una sesion.

Tareas:

- anadir una seccion `Proximos` en el menu de Ajustes
- listar las sesiones con fecha igual o posterior a hoy
- permitir seleccionar cualquier sesion futura
- desplegar bajo la sesion seleccionada sus ejercicios con series, reps/tiempo y peso
- reutilizar el formato visual de la preview para mantener consistencia

Criterio de aceptacion:

- se puede revisar material, pesos y reps de un entrenamiento futuro desde la app
- la consulta no cambia el entrenamiento seleccionado en Hoy ni crea sesion local
- la seccion permite scroll porque forma parte de Ajustes

Estado: implementado.

### Hito 14b: Ajuste del planning a 60-70 minutos

Objetivo: revisar el plan como entrenador personal para que las sesiones quepan en 60-70 min reales, incluyendo 8-10 min de movilidad previa, ejecucion, descansos, feedback y cambios entre ejercicios.

Tareas:

- mantener la estructura principal definida en `Plan entrenamiento 3 meses.md`
- conservar los básicos principales como prioridad de cada dia
- recortar primero accesorios y cardio opcional
- usar superseries de accesorios para compactar sin perder estimulo
- evitar que intensificacion y realizacion aumenten de forma automatica todas las series de todos los básicos
- regenerar `data/trainingPlan.json` desde `scripts/generate-training-plan.mjs`
- auditar todas las sesiones con la estimacion derivada
- actualizar el documento fuente de Obsidian para que coincida con el JSON

Criterio de aceptacion:

- ninguna sesion queda por encima de 70 min estimados
- las semanas de descarga/test pueden quedar por debajo de 60 min
- el foco de cada dia se mantiene reconocible
- el plan sigue respetando molestias de rodilla y preferencia de torso

Estado: cerrado. El plan generado queda con 51 sesiones: 17 por debajo de 60 min, 34 entre 60 y 70 min, 0 por encima de 70 min. La sesion mas larga queda en 70 min estimados.

### Hito 15: Superseries v2

Objetivo: mejorar la primera version de superseries para cubrir casos menos regulares.

Tareas:

- decidir politica para superseries con distinto numero de series
- mostrar mejor en la pantalla de serie que se esta dentro de una superserie
- mostrar progreso de ronda: por ejemplo `Ronda 2/4`
- revisar si conviene una transicion breve entre ejercicios vinculados o avance directo
- permitir descanso propio de superserie si difiere del descanso de cada ejercicio
- validar que decisiones de ejercicios vinculados no ocupan demasiado en movil
- incluir validacion automatica del secuenciador con casos normales, superseries y casos limite

Criterio de aceptacion:

- la app representa claramente ejercicio, orden y ronda dentro de la superserie
- los casos irregulares estan definidos y no generan comportamiento ambiguo
- el secuenciador queda protegido con validacion automatica reproducible

Estado: cerrado como v2 funcional. La pantalla de serie muestra si el ejercicio pertenece a una superserie, su posicion dentro del bloque, la ronda actual y el siguiente ejercicio vinculado cuando no toca descanso. Se anade `scripts/validate-training-plan.mjs` y `npm run validate:plan` para comprobar que el plan genera el numero correcto de pasos, que las superseries respetan orden por ronda, que no se introduce descanso entre ejercicios vinculados de la misma ronda, que las planchas mantienen 60 s y que ninguna sesion supera 70 min estimados.

Decision actual para casos irregulares: si dos ejercicios vinculados tienen distinto numero de series, el secuenciador ejecuta las rondas comunes de forma alterna y despues completa las series restantes del ejercicio que tenga mas series, descansando al dejar de existir pareja en esa ronda. No se usara de forma habitual en el plan, pero queda definido para evitar comportamiento ambiguo.

Pendiente futuro: si una superserie necesita un descanso propio distinto al descanso de sus ejercicios, anadir el campo al JSON del plan y usarlo al cerrar la ronda.

### Hito 16: Plan y progresion asistida

Objetivo: usar los registros para facilitar decisiones futuras sin automatizar demasiado pronto.

Tareas:

- revisar decisiones registradas por ejercicio: mantener, subir, bajar, molestia
- generar una vista simple de recomendaciones para la proxima exposicion del ejercicio
- detectar ejercicios con molestias repetidas
- detectar series sistematicamente saltadas
- preparar una exportacion resumida por ejercicio y sesion
- decidir si el plan JSON se modifica manualmente o si se genera una nueva version desde registros

Criterio de aceptacion:

- despues de varias sesiones se puede ver que ejercicios conviene subir, mantener o revisar
- las molestias y saltos quedan visibles sin analizar el CSV a mano
- el plan sigue siendo explicito por fecha, sin calculos ocultos en la UI

Estado: v1 implementada. La app guarda las decisiones por ejercicio en los metadatos locales de sesion y muestra en Ajustes una seccion de `Progresion` con recomendaciones conservadoras por ejercicio registrado. La recomendacion combina decision marcada, series completadas/saltadas, molestias recientes, ultima carga/reps/RIR y proxima exposicion planificada. No modifica `trainingPlan.json`; el plan sigue siendo explicito por fecha.

Actualizacion v0.1.3: la decision final del ejercicio queda normalizada por tipo de ejercicio. Los ejercicios con carga muestran `Mantener`, `Subir peso`, `Bajar peso`, `Subir reps`, `Bajar reps` y `Marcar molestia`; los de peso corporal sin carga usan reps; los temporizados usan tiempo, posicion y molestia. La opcion por defecto se guarda aunque el usuario pulse continuar sin tocar nada.

Actualizacion v0.1.5: la seccion de estadisticas separa visualmente la senal calculada por la app de la decision registrada por el usuario. Las senales se calculan para todos los ejercicios registrados y no solo para los primeros 8. Estas senales no modifican el planning automaticamente; sirven como entrada para la revision semanal del plan.

Pendiente futuro: convertir estas senales en una vista de revision semanal y preparar una exportacion resumida por ejercicio/sesion para Obsidian.

### Hito 17: Instalacion/offline mas solida

Objetivo: reducir riesgos de uso en gimnasio sin red.

Tareas:

- [x] revisar estrategia de cache del service worker
- [x] mostrar version/build visible en ajustes
- [x] anadir boton de comprobacion offline o estado de app instalada
- [x] documentar como forzar actualizacion de la PWA en iPhone
- [x] validar que `trainingPlan.json`, iconos y assets quedan cacheados
- [x] decidir si hace falta aviso cuando hay una version nueva disponible
- [x] subir `package.json` y `package-lock.json` en cada iteracion desplegable para que Ajustes identifique la version servida

Criterio de aceptacion:

- la app abre y funciona sin conexion despues de haber cargado una vez
- el usuario puede comprobar que version esta usando
- actualizar la app no borra datos locales

Estado: cerrado. El service worker cachea la ruta principal, manifest e iconos base, limpia caches antiguas y responde con version/cache para que Ajustes pueda mostrar el estado de uso sin conexion. La pantalla de Ajustes incluye comprobacion manual de caché, version del worker, recursos base y boton de actualizacion cuando hay una version esperando. En `localhost` se permite registrar el worker para pruebas; en una URL `http://IP-del-Mac:3000` iOS no lo tratara como contexto seguro, por lo que la prueba real de gimnasio debe hacerse desde la URL HTTPS de Vercel instalada en pantalla de inicio.

Actualizacion v0.1.24: `docs/vercel-pwa-testing.md` documenta el flujo para forzar actualizacion de la PWA en iPhone sin borrar datos locales, incluyendo comprobacion de caché desde Ajustes, reapertura, recarga desde Safari y reinstalacion solo como ultimo recurso con backup previo.

### Hito 18: Layout movil horizontal

Objetivo: adaptar la app a iPhone en horizontal sin degradar el flujo vertical.

Estado previo: hasta acometer este hito, la app queda bloqueada en vertical. El manifest declara `orientation: portrait`, la app intenta solicitar bloqueo nativo cuando el navegador lo permite y se muestra una pantalla de aviso si el iPhone se gira en horizontal.

Tareas:

- [ ] definir distribucion horizontal para pantalla de serie
- [ ] colocar ejercicio/progreso y controles en columnas sin scroll
- [ ] adaptar pantalla de descanso para que el circulo y botones respiren
- [ ] revisar feedback en horizontal
- [ ] probar iPhone normal y Pro Max

Criterio de aceptacion:

- girar el movil no rompe el layout
- los controles siguen siendo tactiles y legibles
- no se introduce scroll durante serie, feedback o descanso

### Hito 19: Historial dentro de la app

Objetivo: consultar sesiones anteriores sin depender del CSV exportado.

Tareas:

- [x] listar sesiones guardadas en el dispositivo
- [x] permitir ver resumen simple de una sesion terminada
- [x] permitir exportar de nuevo una sesion anterior
- [x] permitir borrar una sesion concreta
- [x] distinguir sesion en curso, completada y abandonada

Criterio de aceptacion:

- se puede recuperar un entrenamiento anterior desde ajustes o una pantalla dedicada
- exportar no depende de estar justo en la pantalla final
- borrar datos es deliberado y claro

### Hito 20: Preparacion para app nativa iOS

Objetivo: dejar la PWA actual preparada para que una futura app SwiftUI pueda reutilizar el modelo de producto, importar datos existentes y replicar el flujo sin reinterpretarlo desde cero.

Tareas:

- [x] documentar el schema de `trainingPlan.json` con versiones y compatibilidad esperada para Swift `Codable`
- [x] documentar el schema de eventos de serie, metadata de sesion, decisiones, ajustes locales y exportaciones
- [x] anadir exportacion JSON completa del historico local, no solo CSV por serie
- [x] incluir `schemaVersion`, `exportedAt`, `appVersion` y timestamps relevantes en la exportacion estructurada
- [ ] separar de `app/page.tsx` toda la logica de dominio que no depende de React
- [x] separar seleccion de entrenamiento recomendado
- [x] separar secuenciador de ejercicios, series y superseries
- [x] separar calculo de progreso de sesion
- [x] separar transiciones principales del flujo de entrenamiento
- [x] separar preparacion de objetivos de serie y redondeo por material disponible
- [x] separar estimacion derivada de duracion
- [x] separar resumen historico
- [x] separar recomendaciones conservadoras de progresion
- [x] definir un mapa preliminar de pantallas SwiftUI equivalente al flujo actual: Hoy, Preview, Ejecucion, Feedback, Descanso, Transicion, Historial, Progresion y Ajustes
- [x] identificar que funcionalidades de la PWA son temporales por limitaciones web y cuales deben migrar tal cual a iOS
- [x] crear `docs/ios-native-plan.md` con alcance de una primera version nativa
- [x] decidir estrategia inicial de persistencia iOS: SwiftData, Core Data, SQLite o JSON local
- [x] definir el flujo de importacion desde la PWA a la app nativa mediante archivo JSON

Criterio de aceptacion:

- existe una especificacion clara de datos y pantallas para construir el primer prototipo SwiftUI
- el historico local de la PWA se puede exportar en JSON estructurado y versionado
- las reglas principales de entrenamiento estan aisladas de la UI web o documentadas para su traduccion
- una app iOS futura puede cargar el plan y los registros sin depender de IndexedDB ni de detalles internos de React

Estado parcial:

- `docs/data-schemas.md` documenta `TrainingPlan`, sesiones, ejercicios, series, eventos, metadata, CSV y exportacion JSON completa pensando en Swift `Codable`
- `Ajustes > Datos locales` permite exportar un backup JSON completo del historico local
- el JSON exportado incluye `schemaName`, `schemaVersion`, `exportedAt`, version de app, plan completo, ajustes relevantes, sesion activa, metadata, decisiones y eventos de series ordenados con `performedAt`
- las sesiones incluidas en el backup JSON se marcan con `exportedAt`
- la logica de exportacion CSV/JSON, nombres de archivo e inferencia de tipo de carga vive en `lib/sessionExport.ts`
- el CSV por serie `gymapp.workout-set-export` version 2 separa `exercise_id`, `base_exercise_id`, `exercise`, `base_exercise` y `variant_label` sin reescribir exports ya guardados
- el secuenciador de ejercicios, series y superseries vive en `lib/workoutSequence.ts`
- el calculo de progreso de sesion vive en `lib/workoutProgress.ts`: paso actual, siguiente paso, progreso global, progreso por ejercicio y sesion empezada
- las transiciones principales del flujo viven en `lib/workoutFlow.ts`: avance de serie, descanso directo, transicion tras ejercicio o superserie, salto de serie y cierre de entrenamiento
- la preparacion de objetivos de la siguiente serie vive en `lib/workoutTargets.ts`: reps, peso redondeado segun material, duracion, timer inicial y conversion entre barra, multipower, mancuernas, polea, discos, lastre y peso corporal
- la estimacion derivada de duracion vive en `lib/sessionDuration.js` y se comparte entre la PWA y `npm run validate:plan`
- la seleccion del entrenamiento recomendado, resolucion de sesion por id y entrenamientos de la semana vive en `lib/sessionSelection.ts`
- los resumenes de historial, estadisticas y recomendaciones conservadoras de progresion viven en `lib/trainingStats.ts`
- las exposiciones estadisticas por ejercicio conservan `loadType`, `plannedEquipment` y `actualEquipment`, para que Swift no tenga que inferir material desde nombres de ejercicios
- `docs/ios-native-plan.md` define alcance v1 SwiftUI, mapa de pantallas, persistencia inicial con SwiftData e importacion desde backup JSON
- las nuevas decisiones de desarrollo y diseno deben tratar la PWA como prototipo validado y la app nativa de iPhone como destino final

Capacidades iOS candidatas para fases posteriores:

- Live Activity para descanso o sesion activa
- notificaciones locales al terminar descansos
- HealthKit para guardar entrenamientos y leer metricas relevantes
- app companion para Apple Watch
- haptics nativos para confirmaciones y avisos
- widgets con proximo entrenamiento y progreso semanal
- sincronizacion mediante iCloud/CloudKit
- integracion con Atajos de iOS y Siri

### Hito 21: Estadisticas y graficos dentro de la app

Objetivo: que la app deje de depender de Obsidian para consultar la evolucion basica y avanzada del entrenamiento. Obsidian debe quedar como archivo, backup o entorno de analisis personal, no como requisito para entender el progreso.

Enfoque:

- calcular metricas de forma determinista desde el historico local y desde el backup JSON completo
- mantener los datos fuente por serie como verdad principal
- evitar graficas o conclusiones que no puedan trazarse hasta eventos concretos
- disenar la capa de estadisticas pensando en portarla despues a Swift/SwiftUI

Tareas:

- [x] crear una vista de resumen semanal con sesiones completadas, sesiones pendientes y adherencia
- [x] mostrar duracion real por sesion y compararla con la estimacion operativa sin movilidad previa
- [x] mostrar volumen por ejercicio y por grupo muscular cuando el plan incluya esa taxonomia
- [x] mostrar progresion por ejercicio con vista consultable: carga, reps, RIR, saltos y decisiones tomadas
- [x] detectar tendencias simples: estancamiento, subidas sostenidas, molestias repetidas y series saltadas
- [x] anadir filtros iniciales por semana y ejercicio
- [x] anadir filtros por bloque del plan, tipo de ejercicio y grupo muscular cuando el plan incluya esa taxonomia
- [x] permitir exportar las tablas estadisticas principales en CSV reutilizable
- [ ] permitir exportar graficas principales cuando existan visualizaciones nativas en la app
- [ ] las gráficas nativas deberán ser interactivas: selección de rango, consulta de cada punto y filtros sin perder trazabilidad con las series fuente
- [x] definir que las primeras graficas se generan en la PWA desde agregados exportables
- [x] documentar los agregados estadisticos para poder replicarlos en Swift

Criterio de aceptacion:

- desde la app se puede responder rapidamente: que he hecho esta semana, como evoluciona un ejercicio y donde aparecen molestias
- las metricas no dependen de Obsidian ni de calculos manuales externos
- cualquier grafica puede reconstruirse desde el JSON/CSV exportado
- la implementacion no compromete el rendimiento aunque crezca el historico local

Estado parcial:

- `Ajustes > Estadisticas` muestra una primera vista local sin depender de Obsidian
- resumen de la semana actual con adherencia de sesiones completadas sobre previstas
- conteo de sesiones guardadas y sesiones completas
- duracion media reciente y diferencia media contra la estimacion operativa sin movilidad previa
- listado de ultimas sesiones con fecha, series registradas y duracion cuando esta cerrada
- bloque unificado de senales y progresion con ejercicios a revisar, candidatos a subir, candidatos a bajar, series saltadas y molestias registradas
- la implementacion reutiliza los resumenes locales ya calculados desde IndexedDB, evitando una lectura adicional del historico
- los agregados de historial, progresion y estadisticas estan extraidos a `lib/trainingStats.ts`
- vista consultable de progresion por ejercicio con tarjetas colapsables en una columna, ultimas exposiciones, carga, reps/tiempo, RIR, molestias y decision tomada
- las tarjetas cerradas de progresion priorizan el nombre del ejercicio y usan color sutil para la senal; la recomendacion textual completa solo aparece al desplegar el detalle
- las senales de progresion distinguen visualmente candidatos/avisos en amarillo y bajadas de carga en rojo suave
- `Ajustes > Estadisticas` permite filtrar por semana y por ejercicio sin depender de calculos externos, sin duplicar una seccion separada de `Progresion`
- `docs/statistics-aggregates.md` documenta los calculos de historial, duracion, adherencia, senales y progresion para futura replica en Swift
- `Ajustes > Estadisticas > CSV` exporta tablas derivadas de resumen, historial, senales y progresion con schema versionado
- Actualizacion v0.1.8: el CSV estadistico pasa a `gymapp.statistics-export` version 2 e incluye `load_type`, `planned_equipment` y `actual_equipment` en filas por ejercicio. La vista de progresion muestra el material usado dentro del detalle desplegado.
- Actualizacion v0.1.9: `Revisión del plan` se simplifica para leerse como revision descriptiva. El detalle de cada ejercicio separa ultimo registro, decision manual del usuario y señal calculada por la app. La vista deja claro que las señales no modifican automaticamente el planning.
- `Ajustes > Estadisticas` muestra un primer grafico de duracion real vs estimada por sesion, con estado vacio visible hasta que haya dos sesiones cerradas
- Actualizacion v0.1.11: `Ajustes > Estadisticas` queda dividido en secciones compactas: Resumen, Duracion, Revision, Progresion y Exportar. La revision muestra solo senales accionables y un resumen azul de ejercicios a mantener; el detalle completo queda en Progresion para reducir saturacion en movil.
- Actualizacion v0.1.12: `Revision` muestra todas las senales activas, alinea el contador con las filas visibles y compacta las tarjetas para evitar scroll horizontal en iPhone.
- Actualizacion v0.1.13: el plan incorpora taxonomia por ejercicio (`trainingBlock`, `movementPattern`, `primaryMuscles`, `secondaryMuscles`). Estadisticas añade seccion `Volumen`, filtros por bloque, patron y musculo, y CSV estadistico schema v3 con filas de volumen por musculo y ejercicio.
- Actualizacion v0.1.14: `Volumen` pasa a calcularse desde exposiciones por sesion y ejercicio, permitiendo filtrar con precision por semana y sesion. El CSV estadistico sube a schema v4 e incluye `exercise_volume_exposure`.
- Actualizacion v0.1.15: el puente de Obsidian genera `data/Estadisticas entrenamiento.csv` desde el maestro serie-a-serie con schema estadistico v4. El dashboard de Obsidian consume `exercise_volume_exposure` cuando existe y conserva fallback al registro serie-a-serie.
- Actualizacion v0.1.16: se consolida Obsidian en `Entrenamiento/00 Dashboard.md` como unica entrada principal. `Dashboard entrenamiento.md` deja de generarse y se elimina en `sync:obsidian`; `00 Dashboard` y `02 Estadisticas` consumen `Estadisticas entrenamiento.csv` v4 para volumen cuando esta disponible.
- Actualizacion v0.1.17: `Ajustes > Estadisticas > Volumen` añade tarjetas desplegables por ejercicio. Cada tarjeta muestra volumen, series, reps/tiempo y, al abrirla, las exposiciones por sesion que componen el total filtrado.
- Actualizacion v0.1.18: los agregados de volumen agrupan variantes estadisticas equivalentes bajo un ejercicio base, por ejemplo `Elevaciones laterales` y `Triceps en polea`, aunque el plan conserve ids separados por contexto de programacion.
- Actualizacion v0.1.19: `trainingPlan.json` separa `baseExerciseId`, `baseExerciseName` y `variantLabel`. La UI usa el nombre base como titulo visible y muestra el material/variante como contexto secundario en la previsualizacion. No migra ni modifica exports historicos: el CSV por serie conserva `exerciseId`, `exercise` y `actual_equipment` para compatibilidad con Obsidian.
- Actualizacion v0.1.20: el CSV por serie sube a contrato `gymapp.workout-set-export` version 2 con columnas explicitas `exercise_id`, `base_exercise_id`, `base_exercise` y `variant_label`. El importador de Obsidian acepta exports v1 y v2, y rellena los campos nuevos desde `trainingPlan.json` cuando faltan. Los agregados locales de volumen usan `baseExerciseId` y `baseExerciseName` del plan como agrupacion preferente.
- Actualizacion v0.1.21: `Revisión` y `Progresión` pasan a agrupar por `baseExerciseId` y `baseExerciseName`, igual que `Volumen`, conservando las decisiones y el material de cada exposicion concreta.
- Actualizacion v0.1.22: la pantalla de serie limpia las metricas centrales: `reps` y `peso` quedan como etiquetas inferiores, el peso mantiene `kg` solo en el numero grande y los cuadros clicables usan un borde primario suave en vez de texto de ayuda.

Pendiente de nomenclatura:

- [x] revisar nombres visibles del plan para separar ejercicio base y material usado: por ejemplo `Press banca` como nombre base, con selector de material `barra`, `multipower` o `mancuernas`
- [x] mantener ids estables para no romper historico, pero anadir si hace falta campos explicitos tipo `baseExerciseId`, `baseExerciseName` o `variantLabel`
- [x] actualizar exportaciones, Obsidian y futura app Swift para leer esa separacion sin depender de strings

### Hito 22: Generador guiado de planes de entrenamiento

Objetivo: permitir crear o versionar planes desde la propia app mediante un flujo guiado, manteniendo planes explicitos por fecha y compatibles con el JSON actual.

Enfoque:

- la app debe preguntar primero la informacion relevante al usuario
- el resultado debe ser un plan completo, revisable y editable antes de activarse
- el motor debe validar material, duracion, volumen, descansos y progresion antes de aceptar el plan
- cada cambio importante debe crear una nueva version del plan, no mutar silenciosamente el historico

Informacion inicial que debe solicitar:

- objetivo principal: fuerza, hipertrofia, recomposicion, salud, rendimiento mixto
- dias disponibles por semana y dias preferidos
- duracion maxima por sesion y si incluye movilidad previa
- material disponible: barras, discos, mancuernas, poleas, maquinas, banco, rack, accesorios
- pesos disponibles concretos y reglas de carga
- nivel, marcas recientes y ejercicios de referencia
- molestias, restricciones y ejercicios vetados
- ejercicios preferidos y ejercicios sustituibles
- fechas especiales: viajes, semanas de descarga, cierres de gimnasio o competiciones

Tareas:

- [ ] definir el cuestionario inicial y sus respuestas estructuradas
- [ ] crear un perfil de material reutilizable por la app
- [ ] generar una propuesta de calendario con sesiones completas por fecha
- [ ] validar que cada carga propuesta se puede montar con el material disponible
- [ ] validar que las sesiones caben en el tiempo objetivo con la formula de estimacion derivada
- [ ] permitir revisar el plan antes de activarlo
- [ ] permitir editar ejercicios, series, reps, tiempos, pesos y descansos en una interfaz tactil
- [ ] guardar `planVersion`, fecha de creacion, origen del plan y razon de los cambios
- [ ] exportar el plan generado en el mismo formato que consume actualmente la app

Criterio de aceptacion:

- se puede crear un plan nuevo sin editar scripts ni JSON a mano
- el plan resultante es explicito por fecha, no una plantilla semanal con reglas ocultas
- las cargas respetan el material real
- el usuario confirma el plan antes de que sustituya al activo

### Hito 23: Capa de IA para planificacion y analisis

Objetivo: usar IA como asistente de revision, generacion y explicacion, sin delegar en ella reglas criticas ni decisiones opacas durante el entrenamiento.

Opinion de producto:

- la IA puede aportar mucho valor al proponer planes, resumir semanas, detectar patrones y explicar ajustes
- la app no debe depender de IA para funcionar en el gimnasio
- las recomendaciones deben pasar por validadores deterministas antes de mostrarse como accionables
- las decisiones finales de cambiar cargas, volumen o ejercicios deben requerir confirmacion del usuario

Casos deseables:

- [ ] generar un borrador de plan a partir del cuestionario del Hito 22
- [ ] explicar por que una semana sube, mantiene o baja volumen
- [ ] proponer ajustes semanales usando cumplimiento, RIR, molestias y duracion real
- [ ] convertir la `Revision del plan` en un analisis semanal guiado que separe claramente tres capas: datos registrados, decision manual del usuario y propuesta inteligente de ajuste
- [ ] sugerir sustituciones de ejercicios cuando falta material o aparece molestia
- [ ] resumir una sesion o semana en lenguaje natural
- [ ] convertir notas libres o dictadas en etiquetas estructuradas
- [ ] ayudar a detectar incoherencias del plan: exceso de duracion, volumen mal distribuido o progresiones demasiado agresivas

Limites:

- [ ] no decidir pesos serie a serie en tiempo real sin reglas visibles
- [ ] no modificar el plan activo sin una pantalla de revision y confirmacion
- [ ] no presentar el feedback final de ejercicio como si fuera una recomendacion calculada; debe tratarse como dato de entrada para el analisis semanal
- [ ] no mezclar datos estimados con datos registrados sin indicarlo
- [ ] no bloquear el uso offline de la app
- [ ] no depender de respuestas no versionadas para reconstruir el historico

Arquitectura propuesta:

- [ ] motor determinista local para calculos, validaciones y recomendaciones conservadoras
- [ ] IA opcional para generar propuestas, explicaciones y resumenes
- [ ] salida de IA siempre en JSON versionado y validado antes de entrar en el plan
- [ ] esquema de revision semanal con entradas trazables: cumplimiento real, cargas, RIR, molestias, duracion, saltos, feedback del usuario y recomendacion propuesta
- [ ] registro de `aiSuggestionId`, modelo/proveedor si aplica, fecha y decision del usuario cuando una sugerencia se acepta
- [ ] posibilidad de desactivar IA sin perder ninguna funcionalidad principal de registro

Criterio de aceptacion:

- la IA mejora la planificacion y el analisis, pero la app sigue siendo fiable sin conexion
- toda sugerencia queda trazada, validada y aprobada antes de modificar datos
- el esquema de datos permite migrar estas capacidades a la app nativa sin rehacer el historico

### Hito 24: Selector de material por ejercicio

Objetivo: permitir escoger el material usado en una serie o ejercicio cuando el gimnasio obliga a cambiar la variante prevista, manteniendo cargas montables y datos exportables.

Tareas:

- [x] definir `plannedEquipment` y `actualEquipment` sin romper el schema actual
- [x] mostrar un selector segmentado tactil, estilo iOS, encima del cuadro de peso solo en ejercicios con variantes permitidas
- [x] recalcular el peso al cambiar material usando la carga montable mas cercana
- [x] guardar el material elegido en eventos de serie y exportaciones CSV/JSON
- [x] distinguir correctamente `load_type`: `total`, `external`, `per_dumbbell`, `machine` y `bodyweight`
- [x] definir variantes permitidas por ejercicio, no globales, para evitar opciones que no tienen sentido
- [x] validar que la futura app nativa puede cargar el mismo contrato de datos sin inferir desde el nombre
- [x] migrar exports antiguos de Obsidian para anadir `planned_equipment` y `actual_equipment`

Criterio de aceptacion:

- si la barra, multipower o mancuernas estan ocupadas, se puede cambiar la variante del dia sin teclado ni selector nativo
- la variante elegida la primera vez se mantiene durante todas las series restantes del ejercicio
- el peso mostrado queda redondeado al material real disponible
- el historico conserva que variante se uso realmente
- el plan base no se modifica por una sustitucion puntual

Estado: v1 implementada en PWA. El plan actual fija un material por ejercicio y la pantalla de serie permite sustituciones puntuales en ejercicios con variantes reales. La variante seleccionada se guarda en el borrador del entrenamiento y se mantiene durante el resto del ejercicio. CSV, backup JSON, CSV estadistico, roadmap y plan Swift documentan `plannedEquipment`/`actualEquipment`. Pendiente validar ergonomia en iPhone con mas sesiones reales.

### Hito 25: Segunda validación real en gimnasio

Objetivo: ajustar el flujo probado en dos semanas sin añadir analítica móvil que no aporte valor antes de SwiftUI.

Prioridad 1:

- [x] retirar de Ajustes la sección de estadísticas, progresión y señales; se conserva la exportación y el cálculo para Obsidian y futura app nativa
- [x] normalizar los nombres visibles para que el título describa solo el ejercicio y el material aparezca siempre como chip
- [x] rediseñar el descanso con barra horizontal, controles `-15s`/`+15s` debajo y acción táctil al terminar
- [x] mostrar el material elegido en la tarjeta de próxima serie durante el descanso
- [x] resaltar el material seleccionado en la pantalla de serie con el color principal del tema
- [x] permitir, tras un descanso entre ejercicios, elegir otro ejercicio pendiente sin registrar como saltadas las series no realizadas
- [x] propagar automáticamente cambios manuales de reps, carga o duración a las series homogéneas pendientes; detener la propagación cuando el planning cambie el objetivo
- [x] conservar una referencia de carga al cambiar de material para que un redondeo puntual no altere el objetivo al volver a barra o multipower; deshabilitar en rojo las variantes sin carga disponible suficiente
- [x] usar mancuernas como material propuesto para press militar sentado hasta 30 kg por mancuerna; a partir de 60 kg totales, pasar automáticamente a barra y conservar multipower como alternativa

Prioridad 2:

- [x] blindar la pantalla de feedback de superseries contra nombres de más de una línea, con un patrón compacto que no requiera scroll
- [x] mostrar todos los ejercicios vinculados al bloque de una superserie en las tarjetas de próxima acción, tanto durante el descanso como en la transición de ejercicio
- [ ] sustituir los SF Symbols provisionales por Heroicons locales al cerrar la paridad visual de SwiftUI; no invertir más trabajo de iconografía en la PWA
- [x] revisar en dispositivo real los temporizadores con la app en segundo plano y documentar la limitación de PWA que solo se resolverá del todo de forma nativa

Prioridad 3:

- [x] para barra y multipower, mostrar discos necesarios por lado a partir de la carga y el material seleccionado

Decisiones de compatibilidad:

- los nombres visibles se normalizan mediante `baseExerciseName`; los identificadores, cargas, material planeado y material real de exports no cambian
- la analítica se mantiene en librerías y exportaciones para Obsidian, pero no se muestra en la PWA hasta que tenga una presentación adecuada en SwiftUI
- el cambio de orden pendiente debe vivir en el secuenciador y registrarse como orden real de ejecución, nunca simularse como una serie saltada

Estado: cerrado mediante uso continuado en gimnasio real. Las incidencias menores que aparezcan durante ese uso se tratarán como correcciones del flujo nativo, no como una nueva fase de validación.

### Hito 26: Base nativa verificable

Objetivo: iniciar la migración con una capa Swift verificable que decodifique el plan de producción y fijar el primer punto de entrada SwiftUI sobre ese contrato.

Prioridad 1:

- [x] crear un paquete Swift `GymAppNativeCore` dentro de `ios/`
- [x] modelar `TrainingPlan`, sesión, ejercicio, serie y material con `Codable` y enums explícitos
- [x] cargar y validar el `trainingPlan.json` compartido desde una prueba automatizada
- [x] documentar la incorporación de este paquete en el futuro proyecto Xcode y el copiado del JSON como recurso del bundle
- [x] crear el proyecto iPhone-only `GymAppNative` y enlazar `GymAppNativeCore` como paquete local
- [x] empaquetar el `trainingPlan.json` compartido sin duplicar su fuente de verdad y mostrar `TodayView` en simulador

Prioridad 2:

- [ ] modelar el backup JSON completo de la PWA y validar una importación de ejemplo sin persistir todavía
- [ ] portar como reglas Swift puras el selector de sesión y el secuenciador de superseries, con tests equivalentes a los del plan JavaScript

Fuera de este hito:

- SwiftData, flujo de registro, navegación completa y paridad visual
- instalación en dispositivo o firma de Xcode
- iconografía: los nuevos iconos nativos usarán Heroicons como assets locales; los SF Symbols actuales son provisionales

Estado: `ios/GymAppNativeCore` contiene los modelos, el decodificador y pruebas contra el JSON de producción. `swift test` pasa con Xcode y valida las 51 sesiones, una superserie, ejercicios temporizados y el material planificado. `ios/GymAppNative` es un proyecto SwiftUI iPhone-only que enlaza ese paquete, incluye el JSON mediante un enlace a la fuente de verdad y ejecuta `TodayView` correctamente en un simulador de iPhone.

Actualización v0.1.42: `TodayView` navega a `SessionPreviewView`. La previsualización permite scroll, agrupa superseries, muestra el nombre base de cada ejercicio y presenta material, series, repeticiones o duración y carga sin depender del nombre histórico del ejercicio.

Actualización v0.1.43: se retiran los bloques normales de la previsualización nativa. Cada ejercicio se resume en una tarjeta plana de nombre, material y objetivo; solo las superseries mantienen un contenedor común visible.

Actualización v0.1.44: la previsualización nativa recupera la jerarquía de tarjetas validada en React: indicador de orden, nombre, material y tres métricas de series, reps o tiempo y peso. Se mantienen eliminados los encabezados de bloque normales.

Actualización v0.1.45: `TodayView` adopta la composición de la PWA: semana y foco, tarjeta fija de entrenamiento recomendado, métricas de fecha/estimado/bloques, sesiones semanales apiladas y navegación inferior estable. Este lenguaje visual será la referencia de todas las pantallas SwiftUI.

Actualización v0.1.46: cada tarjeta de la previsualización recupera su borde separador. `SessionPreviewView` permite empezar el entrenamiento y `SetExecutionView` resuelve la primera serie en memoria con progreso, ejercicio, material, objetivos grandes, notas, descanso y navegación inferior. Registrar, feedback y temporizador quedan para el siguiente tramo del flujo.

Actualización v0.1.47: fecha de `Hoy toca` pasa a ancho completo y estimado/bloques se muestran debajo en dos columnas, tanto en React como en SwiftUI. La app nativa requiere iOS 26 para adoptar Liquid Glass en selectores y botones. `SetExecutionView` incorpora selector de material basado en las variantes existentes de la PWA y destaca los objetivos de reps y peso como controles editables. La equivalencia y el redondeo de cargas entre materiales se portarán junto con las reglas de carga, antes de habilitar su persistencia.

Actualización v0.1.48: las notas compartidas del plan dejan de anticipar futuras subidas o bajadas; ahora describen exclusivamente la ejecucion de cada ejercicio y se regeneran para React y SwiftUI desde la misma fuente. `Hoy toca` mantiene fecha a ancho completo y permite desplazar de forma contenida semanas de cuatro o mas sesiones sin invadir la navegacion inferior. La previsualizacion nativa fija `Atrás` y `Empezar entrenamiento` flotando sobre su contenido, oculta la flecha de navegacion duplicada y vuelve realmente a `Hoy`. La pantalla de serie sustituye el menu de material por una pildora horizontal de variantes, equivalente a la PWA y construida con Liquid Glass.

Actualización v0.1.49: las pantallas nativas de previsualizacion y serie ocultan por completo la barra superior; toda vuelta ocurre abajo a la izquierda y esta regla queda establecida para las futuras pantallas del flujo. El selector de material se convierte en un control segmentado real: una superficie compartida y un unico indicador de Liquid Glass que se desliza entre opciones. La iconografia nativa se estandariza en Heroicons locales para los proximos desarrollos; los SF Symbols actuales permanecen solo como sustitutos temporales.

Actualización v0.1.50: el selector segmentado de material permite arrastrar directamente el indicador de Liquid Glass y encaja en el segmento mas cercano al soltarlo; el toque en cada segmento se mantiene como alternativa.

Actualización v0.1.51: el gesto de arrastre pasa a toda la superficie segmentada, eliminando la capa transparente que podia interceptar una opcion al cambiar varias veces de material. Los toques y el arrastre se separan con un umbral minimo para que siempre se pueda volver a cualquier segmento.

Actualización v0.1.52: el contraste del selector segmentado se sincroniza con la posicion visual del indicador durante el arrastre: el texto blanco siempre acompaña a la superficie de Liquid Glass y no queda camuflado sobre el fondo.

Actualización v0.1.53: `GymAppNativeCore` incorpora reglas puras de carga equivalentes a las de la PWA. Barra (20 kg), multipower (18 kg), mancuernas de 5 a 30 kg, polea y discos usan el inventario real para redondear objetivos. La pantalla de serie muestra el peso convertido de la variante activa y deshabilita en rojo las opciones que no alcanzan la carga equivalente; las reglas se cubren con pruebas Swift.

Actualización v0.1.54: `WorkoutSessionDraft` concentra el estado de ejecucion nativo en memoria. El material seleccionado se conserva durante todo el ejercicio y los objetivos se recalculan desde una carga equivalente estable, sin encadenar redondeos entre variantes. Los cambios de reps o peso se propagan automaticamente solo a las series consecutivas que eran identicas en el plan; los cambios de objetivo ya previstos por el planning se respetan. Queda preparado para conectarse con el flujo real de serie, feedback y descanso.

Actualización v0.1.55: la app nativa ejecuta ya una sesión completa en memoria: serie, feedback, registro temporal, descanso y siguiente serie. `WorkoutExecutionState` construye el orden de trabajo, alterna los ejercicios de cada superserie por rondas y evita descansos entre ejercicios vinculados. Al cerrar una ronda o una serie normal muestra el temporizador y el resumen de la siguiente serie; al terminar muestra el cierre de entrenamiento. La persistencia y recuperación de este estado quedan como siguiente tramo.

Actualización v0.1.56: se corrige la pantalla nativa de feedback para trasladar la referencia PWA: encabezado compacto con ejercicio, serie, superserie y material; métricas de la serie; RIR cuando procede; controles de rodilla, muñeca, hombro y lumbar; y notas rápidas `OK`, `Pesado`, `Técnica` y `Molestia`. El registro en memoria conserva ahora esos campos detallados. Se establece explícitamente que toda pantalla nueva de SwiftUI debe replicar la jerarquía visual e interacción validada en la PWA, salvo los detalles nativos necesarios.

Actualización v0.1.57: el encabezado del feedback nativo reutiliza los círculos de progreso de la pantalla de serie en lugar del chip textual de serie. El material pasa bajo el nombre del ejercicio como chip de lectura más grande, manteniendo la superserie como información secundaria.

Actualización v0.1.58: la pantalla de serie elimina el texto redundante `Serie x de y` y conserva solo sus círculos de progreso para ganar altura útil. El material de feedback adopta el mismo chip neutro de la previsualización, evitando usar el color de acción para una etiqueta informativa.

Actualización v0.1.59: el nombre del ejercicio abre ahora el encabezado de la pantalla de serie y admite dos líneas a todo el ancho disponible. Los círculos de progreso ocupan una fila propia debajo, alineada a la derecha, para que nunca se solapen ni resten espacio a nombres largos.

Actualización v0.1.60: el encabezado de feedback nativo se alinea con el de serie: nombre prioritario de hasta dos líneas, material y superserie como información secundaria y progreso en una fila separada. Al cambiar material, la carga de peso usa una transición numérica nativa breve para que el redondeo a la carga disponible sea legible.

El trabajo nativo pasa a seguir el checklist operativo `docs/ios-native-checklist.md`, que complementa este roadmap narrativo con tareas acotadas, prioridad, coste y criterios verificables.

Actualización v0.1.61: el chip de material de feedback ocupa una columna secundaria encima de los puntos de progreso, sin competir con el título de dos líneas. Los puntos conservan el mismo borde derecho que en serie. Las fases internas de ejecución adoptan una transición horizontal común: el avance entra desde la derecha y el retroceso entra desde la izquierda; esta es la referencia para toda navegación futura de la app nativa.

Actualización v0.1.62: SwiftData guarda una única instantánea de la sesión activa, incluyendo orden de superseries, series ya registradas, material real, objetivos recalculados, feedback en curso, fase, inicio y fin de descanso. `Hoy` muestra `Reanudar entrenamiento` cuando esa instantánea es válida. Completar la sesión la elimina; el histórico definitivo se implementará como entidad separada en el siguiente bloque de paridad.

Actualización v0.1.63: se corrige la dirección de las transiciones internas de serie, feedback, descanso y finalización. Descanso adopta la composición de la PWA: barra de progreso vaciable, botones `-15s` y `+15s`, tarjeta de próxima serie con métricas y todas las integrantes de una superserie, y avance temprano solo desde `Siguiente`. `Hoy` pasa directamente a previsualización, usa bordes de resalte en vez de rellenos y marca el borrador activo en ámbar. La previsualización concentra `Casa`, `Reanudar` y `Empezar`, este último con confirmación si existe un borrador. La marca verde de sesiones finalizadas queda ligada al hito de historial, que persistirá resultados definitivos.

Actualización v0.1.64: la transición nativa entre serie y feedback se determina por la pareja origen-destino, no por un estado visual reutilizado: feedback entra por la derecha y el regreso a serie entra por la izquierda. Serie incorpora salto persistente con estado `skipped`, indicador de superserie y puntos de progreso con borde y relleno del mismo acento. El temporizador de ejercicios temporizados queda operativo, pausado/reiniciable y persistente, con barra horizontal vaciable. La barra de descanso se recorta por su contenedor para conservar las esquinas y fija texto blanco durante todo el vaciado. El plan fuente declara `equipmentOptions` para Hip thrust, incluyendo multipower, y ambas apps lo consumen. El cierre nativo incorpora recompensa visual y háptica, además de exportación CSV por serie mediante la hoja de compartir de iOS; historial, decisiones finales y backup JSON siguen siendo un bloque separado.

Actualización v0.1.65: `Hoy` elimina la tarjeta principal redundante y muestra toda la semana mediante tarjetas de sesión con día, fecha, foco, estimado y bloques, conservando bordes de estado. Completar la sesión vacía explícitamente la pila de navegación y vuelve a `Hoy`, en lugar de reaparecer en la previsualización. La serie abre una hoja inferior nativa para editar reps o peso; los controles recorren el inventario real del material y respetan la propagación ya definida hacia series homogéneas. Los temporizados admiten ajuste directo de `±15 s` y comienzo al tocar su tiempo, usando la misma barra vaciable que el descanso. Barra y multipower muestran una propuesta de discos por lado junto al peso. Tras la última serie de un ejercicio, o la última ronda de una superserie, aparece la evaluación personal antes del descanso; sus decisiones se conservan incluso al reanudar. Los puntos de progreso de serie y feedback reutilizan exactamente el mismo componente, el material de feedback se integra bajo el peso y la posición de superserie se calcula dentro de su grupo, corrigiendo indicadores como `4/2`.

Actualización v0.1.66: `Hoy` usa una tipografía homogénea para día y fecha. El resumen de discos nativo se desplaza a la franja superior lateral del objetivo de peso y escala cada pieza para diferenciar con claridad `1,25`, `2,5`, `5`, `10`, `15` y `20 kg` sin ocultar la cifra. Las hojas de ajuste sustituyen los textos de confirmar y descartar por controles circulares Liquid Glass con check y cruz. La evaluación personal gana bordes de contraste y símbolos consistentes: `=`, `↗`, `↘` y `×`. Descanso reduce la altura de su contador y, al terminar, permite priorizar un bloque aún no iniciado; este movimiento reordena el flujo sin registrar nada como saltado. Los temporizados reutilizan la barra vaciable de descanso, sitúan `±15 s` encima, deshabilitan iniciar/pausar al acabar y avanzan a feedback al tocar el tiempo terminado. La dirección de transición vuelve a respetar explícitamente la intención de la navegación, corrigiendo el avance de feedback a la siguiente integrante de una superserie. La PWA mueve `Reanudar` al lateral de la tarjeta activa para que una semana de cuatro sesiones no expulse su navegación inferior. El plan compartido declara también multipower como variante de sentadilla.

Actualización v0.1.67: SwiftData separa el borrador único de entrenamiento de las marcas de sesiones completadas. Al acabar una sesión, `Hoy` muestra borde verde y chip `Completado`, y no existe ninguna vía de reanudación para ella. Confirmar el inicio de un entrenamiento nuevo elimina el borrador anterior antes de crear el nuevo, por lo que el estado ámbar `En curso` no queda huérfano. `Hoy` mantiene scroll para semanas largas y coloca un acceso circular Liquid Glass a futuras opciones sobre el contenido, abajo a la derecha. Todos los descansos usan la misma altura contenida de temporizador, controles y tarjeta siguiente. El bloque de próxima serie o superserie tiene borde propio; para una serie simple, el selector de bloque queda contiguo y para superseries conserva más altura y scroll. Durante la ejecución, una barra horizontal de progreso global se ancla al borde superior de la app y se completa de izquierda a derecha con las series registradas.

Actualización v0.1.68: la pantalla nativa cierra la sesión de forma transaccional después de la evaluación final, guardando su marca `Completado` antes de limpiar el borrador activo. El CTA de esa evaluación pasa a `Finalizar`. Las transiciones de flujo conservan una dirección única para la pantalla entrante y desvanecen la saliente, incluyendo la primera ronda de superserie. Las barras de descanso se unifican en una altura compacta de aproximadamente el 20% de la pantalla; el borde solo agrupa la tarjeta de próxima serie o superserie. La barra de progreso global ocupa la zona segura superior sin animación vertical. En series temporizadas, los ajustes de duración preservan el temporizador en marcha y el avance manual queda bloqueado hasta que termine para evitar registros duplicados.

Actualización v0.1.69: la raíz de ejecución ocupa toda la ventana nativa y fija la barra global de progreso en la zona de estado, con el fondo natural de la app y altura completa de esa zona. El descanso reserva el espacio flexible antes de su navegación inferior para que `Siguiente` vuelva a la parte baja tanto en series simples como en superseries. Al priorizar un bloque alternativo, el secuenciador mueve el bloque completo de sus series pendientes en lugar de intercambiar solo la primera, evitando saltar a otro ejercicio antes de completarlo. Las series temporizadas notifican su finalización al CTA inferior, que se activa al llegar a cero; los ajustes temporales son locales a la serie modificada y no cambian las siguientes.

Actualización v0.1.70: la barra global de progreso anima solo el avance horizontal. En descansos con próxima serie simple, la lista de bloques alternativos usa el espacio disponible hasta la navegación inferior. La pantalla nativa de finalización muestra el tiempo real desde la entrada en la primera serie y la diferencia frente al estimado del plan. El CSV nativo respeta exactamente `gymapp.workout-set-export` v2, conserva la cabecera compatible con Obsidian y añade la decisión final solo en la última serie exportada de cada ejercicio. El backup JSON nativo sigue pendiente.

Actualización v0.1.71: `Hoy` incorpora acceso a Opciones. La configuración nativa separa Apariencia (tema persistente y pantalla activa), Próximos entrenamientos (consulta de sesiones futuras pendientes con previsualización bloqueada para inicio) y Exportación (CSV por sesión nativa guardada, backup JSON de SwiftData y borrado total con confirmación). Las sesiones completadas conservan instantánea de ejecución y decisiones para poder reexportarlas fuera de la pantalla final.

Actualización v0.1.72: Próximos elimina la cabecera de navegación nativa, usa el título visual de la ejecución y sitúa Atrás como control Liquid Glass flotante inferior. Exportación enumera todas las sesiones completadas: las que tienen detalle persistido permiten CSV individual; los marcadores históricos anteriores permanecen visibles y explican por qué no se pueden reexportar.

Actualización v0.1.73: Opciones, Próximos y Exportación comparten barra superior nativa visible con desenfoque de iOS, título principal de la tipografía de la app y vuelta explícita abajo a la izquierda. El gesto lateral de navegación sigue siendo complementario y debe comprobarse en simulador y dispositivo al ocultar el botón estándar de la barra.

Actualización v0.1.74: Apariencia adopta la misma barra superior, control de vuelta inferior y selector segmentado Liquid Glass que el material de la pantalla de serie. La navegación principal se mantiene en `NavigationStack`; las fases internas de entrenamiento usan transiciones de flujo y no se comportan como destinos apilados.

Pendiente P2: avisos de finalización para descanso y series temporizadas. En primer plano, el fin combina sonido corto y respuesta háptica. Al pasar la app a segundo plano queda programar una notificación local; debe funcionar aunque el permiso de notificaciones sea denegado y no depende de infraestructura push remota.

Actualización v0.1.75: el selector Liquid Glass se extrae como componente genérico compartido. Tema y Material usan la misma interacción por toque y arrastre; las opciones de material no disponibles siguen visibles en rojo y bloquean tanto el toque como el desplazamiento hacia ellas.

Actualización v0.1.76: la app nativa exporta e importa `gymapp.full-training-data-export` v1. El backup conserva plan, ajustes, estado resumido de la sesión activa y sesiones terminadas; la importación valida `schemaName` y versión, evita duplicados por `sessionId` y conserva el payload de las sesiones importadas para poder reexportarlas sin pérdida.

Actualización v0.1.77: Apariencia nativa adopta un sistema de cuatro temas inspirado en los principios de tokens de EightShapes: `White`, `Light`, `Dark` y `Black`. El selector principal mantiene Sistema/Claro/Oscuro; Sistema guarda una variante clara y otra oscura, mientras que Claro y Oscuro solo muestran sus dos alternativas relevantes. Canvas, superficies y color de realce comparten tokens para evitar decisiones de color dispersas. Opciones muestra una versión discreta al final de la lista.

Actualización v0.1.78: los canvas de tema se resuelven mediante una vista SwiftUI reactiva para que White/Light y Dark/Black cambien el fondo visible al seleccionar la variante. Los estados semánticos comparten tokens propios: éxito verde profundo, aviso amarillo ocre y error rojo moderado, sustituyendo los colores de sistema demasiado saturados en la finalización de descansos y series temporizadas.

Actualización v0.1.79: cambiar de tema ya no reconstruye la jerarquía de navegación ni devuelve a Hoy. White, Light, Dark y Black actualizan el canvas de la app sin reiniciar la pantalla actual; iOS 26 mantiene sus regiones de sistema superior e inferior bajo control del sistema y no expone todavía una API pública para teñirlas con el canvas de la aplicación. La instantánea persistida del entrenamiento activo pasa a `GymAppNativeCore` y cuenta con pruebas de recuperación para una serie normal, una superserie y un descanso caducado.

Actualización v0.1.80: el proyecto nativo requiere iOS 27. La barra de estado adopta la preferencia oficial de contraste del tema. Para asegurar continuidad visual también cuando el sistema conserva su propio fondo en los extremos, los temas claros comparten canvas blanco puro y los oscuros canvas negro puro; las variantes White/Light y Dark/Black siguen distinguiéndose mediante superficies y color de realce.

Actualización v0.1.81: Próximos entrenamientos elimina el título duplicado del contenido y conserva la cabecera nativa. La previsualización fija el contexto de semana, sesión y estimación en una cabecera translúcida, mientras los ejercicios permanecen como contenido desplazable.

Actualización v0.1.82: se corrige la asignación de superficies en los temas claros. White usa superficies blancas y Light superficies gris claro, manteniendo el canvas blanco común que asegura la continuidad con las regiones de sistema.

Actualización v0.1.83: Opciones observa las preferencias de apariencia y reconstruye únicamente su contenido al volver desde Apariencia. Los cambios White/Light y Dark/Black ya se aplican de inmediato sin reiniciar la navegación ni regresar a Hoy.

Actualización v0.1.84: la app nativa conserva dos decimales en cargas de discos, por lo que valores como 31,25 kg se muestran y exportan sin truncarse. El peso muerto rumano queda normalizado como nombre de ejercicio y el plan declara Barra y Multipower como materiales seleccionables para PWA y nativo. Al terminar un descanso o una serie temporizada en primer plano se emite un sonido corto y respuesta háptica. La lista de CSV nativa muestra también la fecha planificada de cada entrenamiento.

Actualización v0.1.85: las tarjetas de sesiones en Exportación muestran una línea independiente con la fecha planificada y el nombre del entrenamiento. El mismo identificador se conserva para sesiones importadas desde la PWA, aunque estas se mantengan como historial sin CSV nativo regenerable.

Actualización v0.1.86: el importador nativo acepta los valores históricos numéricos de `painOther` generados por la PWA, además de texto y valores nulos. El backup de transición mantiene así su estructura original al volver a exportarse y las sesiones completadas pueden importarse sin descartar el archivo completo.

Actualización v0.1.87: Exportación sitúa backup, importación y borrado confirmado antes del historial de sesiones. `Hoy` deja de depender de la fecha exacta del día y presenta siempre la primera semana incompleta del plan; al completar todas las sesiones de una semana, pasa automáticamente a la siguiente.

Actualización v0.1.88: se registra como pendiente P1 la recuperación del gesto nativo de volver deslizando desde el borde izquierdo en destinos de `NavigationStack`. El botón inferior de vuelta sigue siendo el acceso explícito y no se sustituye.

Actualización v0.1.89: se valida en dispositivo la importación del backup real de las dos primeras semanas desde la PWA y el avance de `Hoy` a la semana 3. Se incorpora el Hito 27 de companion Apple Watch: la primera versión tendrá el iPhone como estado autoritativo y el reloj resolverá la interacción inmediata de serie, salto y descanso con respuesta háptica.

Actualización v0.1.90: Exportación muestra, solo cuando existe un borrador, la acción confirmada `Descartar entrenamiento en curso`. Elimina exclusivamente la instantánea activa de SwiftData y conserva sesiones finalizadas, sesiones importadas y backups ya creados.

Actualización v0.1.91: la evaluación final nativa adopta la jerarquía semántica de la PWA: mantener usa el acento, subir verde y bajar o molestia rojo, con fondos, bordes y objetivos táctiles reforzados. El feedback de serie separa RIR de molestias; RIR tiene controles de 56 pt y las cuatro molestias viven en un bloque desplazable independiente. El selector segmentado conserva el contenedor Liquid Glass, pero su indicador se pinta con el mismo token de acento que progreso y acciones primarias, sin la aclaración automática del tinte de vidrio. La estimación de Hoy, previsualización, cierre y backup se obtiene ya con el algoritmo de la PWA: movilidad, ejecución de cada serie, descansos, cambios entre ejercicios, transiciones de superserie y feedback.

Actualización v0.1.92: el selector nativo `Cambiar siguiente bloque` modela cada superserie como una sola alternativa, igual que la acción que ejecuta. La tarjeta enumera sus integrantes con `+`, mantiene el chip `Superserie` y resume los materiales implicados; no vuelve a ofrecer el bloque ya anunciado en `Próxima superserie` ni bloques parcialmente realizados.

Actualización v0.1.93: el control de RIR abandona el área de toque implícita de sus iconos y declara dos zonas táctiles de 76 × 64 pt, con `contentShape`, etiqueta de accesibilidad y acciones separadas. La evaluación nativa incorpora una cabecera fija de jerarquía equivalente a la pantalla de serie: `Evaluar ejercicio` o `Evaluar superserie` y el nombre del ejercicio o conjunto; sus decisiones se mantienen como contenido desplazable, evitando perder contexto en nombres largos.

Actualización v0.1.94: el feedback de serie gana la cabecera fija `Evaluar serie` y el nombre de ejercicio a 31 pt, alineando su jerarquía con la evaluación final. Los controles secundarios de RIR, molestias y nota refuerzan su borde y contraste en temas oscuros para leerse inequívocamente como botones sin competir con la acción principal `Registrar serie`.

Actualización v0.1.95: las pantallas nativas ajenas a la ejecución adoptan `AccentHeaderCard`: tarjeta superior de color de resalte, texto centrado de contraste blanco y radio inferior continuo de 36 pt. Hoy centra semana y foco; la previsualización prioriza el nombre de entrenamiento sobre el contexto; Opciones, Apariencia, Próximos y Exportación dejan de usar la barra de navegación nativa. Las vistas de serie, feedback, descanso y cierre conservan su propia jerarquía de sesión.

Actualización v0.1.96: la tarjeta superior de las vistas de consulta prolonga su lienzo de color de resalte por detrás de la zona segura superior, hasta el borde físico del iPhone. El contenido permanece dentro del área segura y la curvatura se mantiene exclusivamente en el borde inferior de la tarjeta.

Actualización v0.1.97: se simplifica Apariencia en dos decisiones independientes: `Sistema`, `Claro` u `Oscuro` para el lienzo y las superficies; y `Azul`, `Rojo oscuro` o `Ámbar` para el color de resalte. Se retiran las variantes White, Light, Dark y Black, por lo que el modo claro conserva siempre el gris sutil de fondo. El acento elegido alimenta cabeceras, controles, progreso y una segunda variante desaturada para los fondos de las barras temporizadas y agrupaciones secundarias. Las copias JSON incluyen opcionalmente el color para preservar la preferencia sin incompatibilizar backups existentes. La curvatura inferior de las cabeceras aumenta a 48 pt.

Actualización v0.1.98: los colores del tema se resuelven directamente desde las preferencias persistentes durante el dibujado, por lo que cambiar Azul, Rojo oscuro o Ámbar actualiza de inmediato cabeceras, selectores, controles, progreso y barras temporizadas sin tener que salir de la pantalla ni cambiar la apariencia. El lienzo de aplicación y las zonas seguras superior e inferior vuelven a blanco puro para apariencia clara y negro puro para apariencia oscura.

Actualización v0.1.99: las superficies interactivas recuperan en apariencia clara un gris azulado muy sutil, mientras el lienzo global permanece blanco puro. Los colores de tema dejan de cachearse como instancias estáticas, de modo que un cambio de resalte crea colores dinámicos nuevos en el mismo render. Opciones se organiza en grupos de lista para Entrenamiento, Personalización y Datos locales, conservando las mismas acciones y preparando el menú para nuevos apartados.

Actualización v0.1.100: las superficies de tarjetas, métricas y controles pasan a usar una versión tenue de cada color de resalte, en lugar de un gris genérico. Apariencia sustituye el selector lineal de color por tarjetas de previsualización para Azul, Rojo oscuro, Ámbar y Grafito. Cada selección recrea solo el contenido de Apariencia, sin reiniciar la navegación, para actualizar cabecera, selector y controles de manera inmediata.

Pendiente de apariencia: animar de forma coordinada la expansión y reducción vertical de la tarjeta superior de acento al navegar entre pantallas. Requiere una capa de cabecera compartida por el `NavigationStack`, por lo que se abordará cuando se consolide la navegación nativa y sus transiciones.

Actualización v0.1.101: Hoy observa explícitamente el color de resalte persistido y recrea solo su contenido visual al cambiar la preferencia. El `NavigationStack` conserva su identidad y estado, evitando que modificar el color desde Apariencia expulse al usuario de Ajustes o altere su navegación.

Actualización v0.1.102: cada fila de Opciones ocupa y responde en toda la anchura de su tarjeta agrupada, incluidos los espacios vacíos alrededor de título, descripción y flecha.

Actualización v0.1.103: se documentan los próximos desarrollos de personalización inicial, análisis inteligente y molestias para orientar el modelo de datos nativo más allá de la integración actual con Obsidian.

Actualización v0.1.104: la app nativa programa avisos locales con sonido para el final de descanso y de serie temporizada, además de conservar el sonido corto y la respuesta háptica cuando está en primer plano. Cada programación queda versionada internamente para que ajustar, cancelar o finalizar un temporizador no pueda dejar una notificación obsoleta pendiente. Este avance deja la tarea de avisos como parcial hasta validarla en iPhone físico con permisos concedidos y denegados, y con la app en segundo plano. Se mantienen como opción los cinco esquemas premium, complementarios a las apariencias Sistema/Claro/Oscuro y a los cuatro colores base; el sistema de tokens aplica su lienzo, superficie y realce de forma consistente.

Actualización v0.1.105: la previsualización nativa refleja el estado de cada ejercicio de una sesión activa: completado en verde, en curso en naranja y pendiente sin marcar. Los ejercicios completados no son interactivos; los iniciados reanudan el flujo y los pendientes solo pueden priorizarse al comenzar un bloque válido, con confirmación explícita. Se incorpora un calentamiento opcional configurable desde Ajustes: inicia el tiempo real de la sesión, se guarda en el borrador activo, no crea series ni feedback y vuelve a la previsualización al terminar o continuar manualmente. Queda validarlo en iPhone físico junto con la recuperación tras cerrar la app.

Actualización v0.1.106: las acciones de avisos y presentaciones nativas usan un color de sistema accesible, independiente del color de realce y de los esquemas premium. Así, confirmar, cancelar o aceptar se mantiene legible sobre el material translúcido de iOS en apariencia clara, oscura y sistema; los colores de marca siguen reservados para controles y contenido de la app.

Actualización v0.1.107: la barra de progreso global de la sesión usa el realce opaco en todas las paletas. Antes, las opciones simples aplicaban un relleno translúcido sobre blanco o negro y podían parecer ausentes; el tramo pendiente sigue mostrando el lienzo de la apariencia activa.

Actualización v0.1.108: primera entrega de la cabecera de ejecución nativa. Serie, evaluación de serie y evaluación de ejercicio comparten una composición centrada; las series usan píldoras redondeadas de estado y el progreso global pasa a una barra compacta en la safe area inferior. Se incorpora el modelo de histórico nativo por ejercicio y material, con récords de carga, repeticiones y RM estimado por Epley, gráfica básica y registros fechados. En previsualización se consulta mediante pulsación prolongada, preservando el toque normal para iniciar o reanudar; en serie, un arrastre descendente desde la cabecera abre la consulta. Queda pendiente en este hito convertir esa consulta en panel expandido integrado en la propia cabecera y trasladar el temporizador de descanso a su variante de cabecera.

Actualización v0.1.109: se crea la base de la companion watchOS. El iPhone publica por `WatchConnectivity` una instantánea versionada de la sesión activa; el reloj muestra ejercicio, serie, objetivos, descanso y progreso, y puede ajustar el descanso en tiempo real mediante `±15 s`. El registro de series continúa siendo autoritativo en el iPhone hasta definir un flujo de feedback completo e idempotente para la muñeca.

Actualización v0.1.110: la companion comparte el contrato de estado y comandos con el núcleo nativo. Las órdenes del reloj se identifican y confirman para descartar reintentos; permite registrar u omitir series normales, controlar una serie temporizada y ajustar el descanso. Las superseries muestran sus ejercicios vinculados y el reloj avisa hápticamente al confirmar una orden o terminar una temporizada. El feedback detallado y la cola offline siguen pendientes.

Actualización v0.1.111: la exportación opcional a Apple Salud migra de la construcción de `HKWorkout` obsoleta a `HKWorkoutBuilder`. Conserva fuerza tradicional, duración real, metadatos de GymApp y UUID externo por sesión. La siguiente etapa será una sesión viva iniciada desde el Apple Watch para recoger métricas del reloj sin duplicar el registro final del iPhone.

Actualización v0.1.112: se define el flujo visual de la companion Apple Watch para cubrir la sesión completa sin trasladar la interfaz del iPhone. El reloj recibirá también los entrenamientos disponibles, no solo el borrador activo: selección equivalente a Hoy, previsualización navegable de ejercicios y primera/siguiente serie, ejecución de serie con edición mediante Digital Crown, descanso con cuenta atrás y próxima serie, y finalización compacta. Todos los lienzos, superficies, realce, estado de descanso terminado y contraste seguirán los tokens de apariencia y color elegidos en el iPhone. Por ahora se excluyen pulsaciones e imágenes de ejercicios. Queda por decidir explícitamente el papel del calentamiento y el comportamiento exacto de superseries y finalización para cerrar el contrato de navegación antes de construir las pantallas.

Actualización v0.1.113: se confirman calentamiento desde Watch, superseries como bloque indivisible, cierre compacto y necesidad temporal de iPhone alcanzable. El contrato de WatchConnectivity pasa a distribuir catálogo, sesiones completadas, estado activo y tema; el reloj puede iniciar o priorizar un entrenamiento, iniciar y terminar el calentamiento, editar el objetivo de reps o peso mediante Digital Crown y registrar, omitir o controlar temporizadas sin que la app de iPhone tenga que estar en la pantalla de serie. Las acciones se enrutan a la vista de ejecución si esta está abierta, o al borrador persistido si no lo está, para no duplicar series. Falta validación visual y funcional en simulador emparejado y en reloj físico.

Actualización v0.1.114: la companion adopta una regla de navegación estricta: ninguna pantalla usará scroll salvo la selección de entrenamientos equivalente a Hoy y la previsualización. Cuando una pantalla de Watch necesite más contenido, se dividirá en páginas verticales nativas, reconocibles por los indicadores junto a la Digital Crown. La primera página de ejecución debe contener siempre, sin desplazamiento, atrás, identidad compacta, métricas de serie y acciones de omitir/registrar.

Actualización v0.1.115: el cierre temprano nativo conserva las series hechas y marca explícitamente las pendientes como omitidas; progreso y finalización muestran ambos estados por separado. Cada sesión terminada mantiene la ejecución completa como fuente editable para la futura corrección de reps, peso o duración. La sincronización opcional con Apple Salud persiste ahora estado, fecha e incidencia por sesión, reintenta al abrir la app los envíos no confirmados y conserva el vínculo de sesiones ya exportadas para evitar reenvíos normales.

Actualización v0.1.116: las variantes de curl de bíceps, elevación de gemelos, peso muerto rumano y elevaciones laterales comparten un nombre y una familia de historial, manteniendo la variante concreta como contexto de ejecución. Serie muestra una tarjeta de indicaciones de dos líneas que prioriza recomendaciones técnicas; una pulsación larga abre una ventana flotante sobre fondo desenfocado con variante y objetivo cualitativo del bloque, sin repetir reps o peso ni reutilizar prescripciones obsoletas. Descanso refleja el material seleccionado en curso y permite ciclar desde el chip o el peso por las alternativas que el inventario admite, ajustando la carga con las mismas reglas de conversión. Press cerrado añade mancuernas y peso muerto rumano añade Multipower como alternativas. Calentar ya no abre una pantalla separada: el temporizador ocupa la cabecera de Preview y extiende su animación de vaciado por detrás de la zona de estado mientras se elige el siguiente ejercicio; Empezar termina el calentamiento para entrar directamente en ese bloque. Grafito incrementa su contraste en apariencia oscura.

Planificado para el siguiente bloque nativo: una cabecera común y centrada para las fases de ejecución. En Serie y Evaluar serie mostrará el ejercicio y píldoras de progreso sin material; en Descanso mostrará exclusivamente la cuenta atrás y no abrirá historial; en finalización solo dirá «Entrenamiento completado». El histórico por ejercicio se desplegará desde el borde inferior discreto de cabeceras con nombre, sin usar el gesto de inicio del dispositivo. Incluirá récords por material, RM mediante Epley, gráfico elemental y registros nativos; desde Preview se consultará con pulsación prolongada y previsualización nativa para no interferir con iniciar o priorizar un ejercicio.

### Futuro: onboarding y perfil de entrenamiento

- Próximo bloque de producto: onboarding guiado antes de crear un plan y una pantalla equivalente en `Opciones > Perfil de entrenamiento` para revisar o modificar los mismos datos posteriormente.
- [~] Onboarding guiado antes de crear un plan: recoge objetivo, horizonte temporal, disponibilidad, duración por sesión, experiencia, material, prioridades, preferencias, ejercicios a evitar y limitaciones. Pendientes: cardio y referencias iniciales por patrón.
- [ ] Recoger nivel inicial sin obligar a introducir un 1RM: pesos y repeticiones cómodos aproximados por patrón o ejercicio, además de preferencia por aislados frente a superseries.
- [~] Registrar limitaciones y molestias declaradas durante el onboarding para condicionar las sustituciones y el diseño inicial del plan. La captura existe; faltan las reglas que la apliquen a una propuesta.
- [~] Permitir revisar y editar ese perfil desde `Opciones > Perfil de entrenamiento` sin alterar retroactivamente las sesiones ya registradas. La edición existe; falta conectar cambios a revisiones futuras del plan.

Actualización v0.1.117: el perfil de entrenamiento se persiste en SwiftData como entidad independiente del plan, el borrador activo y las sesiones históricas. Si no existe, la app abre un onboarding de tres pasos para definir objetivo, horizonte en semanas, disponibilidad, duración máxima por sesión, experiencia, material y contexto personal. En una instalación con planificación ya cargada se puede omitir temporalmente con `Mantener mi planificación actual`; esto no crea, reescribe ni descarta sesiones. `Opciones > Perfil de entrenamiento` permite revisar los mismos datos sin alterar registros ya ejecutados. El horizonte temporal se conserva expresamente para que el futuro agente pueda estructurar macrociclos y hacer explícitas las expectativas poco realistas, no solo proponer sesiones aisladas. El perfil captura además el inventario concreto: pesos de mancuernas y discos con su número de unidades, paso de poleas y peso base de barra y Multipower. Las sesiones nuevas guardan una instantánea de este inventario para cálculos, selectores y discos; sesiones activas e históricas conservan la suya.

Actualización v0.1.118: el plan incluido conserva su papel de base inmutable. Las propuestas futuras se persisten como instantáneas completas de una revisión, vinculadas al identificador de su plan base, con número secuencial, motivo, fecha de vigencia y estados pendiente, aceptada o descartada. Solo una revisión aceptada y ya vigente puede resolver el plan que usa Hoy y el catálogo del Watch; una propuesta no cambia la ejecución hasta su aceptación. Una sesión activa permanece visible incluso cuando una revisión vigente ya no la contiene. `Opciones > Planificación` permite revisar y decidir las propuestas. El siguiente bloque define operaciones tipadas y el motor determinista que generará propuestas válidas; el agente de chat no escribirá planes directamente.

Actualización v0.1.119: el núcleo incorpora operaciones tipadas para mover o cancelar una sesión, añadir, quitar o sustituir un ejercicio, y ajustar reps, carga, duración o descanso de una serie. Antes de generar una propuesta se validan la sesión activa o completada, fechas pasadas, disponibilidad semanal, conflictos de calendario, material disponible y ejercicios restringidos; una sesión que exceda la duración preferida produce un aviso visible pero no bloquea la propuesta. La operación genera una instantánea de plan con cancelaciones explícitas, que Hoy, Calendario y Watch excluyen sin borrar ningún historial. Cada revisión guarda las operaciones y avisos que la originan, y los muestra antes de aceptar o descartar. Falta traducir automáticamente las limitaciones expresadas en texto a restricciones de ejercicios y extender el motor a prioridades de bloque y volumen semanal.

Actualización v0.1.120: el perfil compila localmente menciones explícitas de hombro, rodilla, lumbar, codo, muñeca, fondos, peso muerto y rechazo de superseries a restricciones estructuradas por patrón o ejercicio. Estas restricciones se inyectan al construir el contrato de planificación y el motor las aplica al añadir o sustituir ejercicios. Es una regla conservadora de seguridad, no una interpretación médica ni de lenguaje general: cualquier texto ambiguo deberá requerir confirmación cuando exista el agente.

Actualización v0.1.121: el perfil mantiene las molestias declaradas como chips, con alta y eliminación explícitas. En cada feedback de serie se muestran con la misma escala 0–3 que rodilla, muñeca, hombro y lumbar, y esos niveles se conservan internamente en el registro y el borrador. La exportación actual hacia Obsidian y CSV sigue limitándose a las cuatro zonas ya existentes hasta definir el almacén sensible propio. El motor recibe las molestias del perfil mediante el compilador estructurado. `Opciones > Planificación > Simular propuesta` permite crear localmente y sin alterar el plan una revisión pendiente para mover o cancelar una sesión futura, sustituir un ejercicio o ajustar reps y carga de una serie; protege sesiones activas, completadas y pasadas, y ejecuta las mismas validaciones de disponibilidad, material y restricciones que usará el agente.

Actualización v0.1.122: los perfiles existentes sin chips de molestias migran a Hombro, Lumbar, Muñeca y Rodilla, preservando además las entradas heredadas. Las cuatro zonas usan el mismo control en el feedback, sin una sección duplicada. Las propuestas guardan un diff de impacto calculado en el núcleo: sesiones modificadas, cambio estimado de duración, número de superseries y volumen de series por semana y grupo muscular. La revisión enseña este impacto antes de aceptar; el simulador declara además las restricciones de perfil comprobadas durante la validación.

Actualización v0.1.123: se separa la intención conversacional de la planificación. El núcleo define una solicitud de texto, intenciones codificables para mover o cancelar sesión, sustituir ejercicio, ajustar una serie o adaptar duración, y un resolvedor que solo las transforma en operaciones tipadas. La intención de acortar una sesión queda expresamente pendiente de una estrategia de programación, en lugar de eliminar ejercicios de forma implícita. Un futuro intérprete local o remoto solo podrá sugerir estas intenciones; el motor de validación y la aceptación de la revisión siguen siendo las únicas vías para modificar el plan.

Actualización v0.1.124: la estrategia conservadora para acortar una sesión ya genera alternativas revisables: primero reduce descansos a 60 segundos y, si hace falta, retira accesorios independientes desde el final. No elimina ejercicios básicos ni técnicos, ni descompone superseries. Cada alternativa pasa por el mismo motor de validación, calcula su duración resultante y se guarda como una revisión pendiente con su impacto antes de aplicarse. Un perfil nuevo no declara molestias por defecto; los perfiles anteriores sin el campo se migran a las cuatro zonas históricas. Los nombres de molestias se normalizan sin duplicados por mayúsculas o tildes, y desde el feedback una primera molestia puede añadirse al perfil y valorarse inmediatamente sin abandonar la serie.

Actualización v0.1.125: mover una sesión a una fecha elegida expresamente por la persona prevalece sobre la disponibilidad semanal general, aunque mantiene la protección contra fechas pasadas y conflictos de calendario. La disponibilidad seguirá guiando las replanificaciones automáticas del futuro agente. El catálogo de sustituciones agrupa una sola vez cada familia visual de ejercicio, conservando el `exerciseId` concreto para ejecutar la operación y para no romper histórico ni exports. El generador normaliza además los campos base de curls, dominadas, gemelos y peso muerto rumano; los CSV existentes siguen siendo compatibles porque mantienen los identificadores históricos.

Actualización v0.1.126: una revisión que mueve una sesión queda vigente desde el momento en que se acepta, no desde la fecha destino; el calendario y Hoy pueden mostrar el cambio de inmediato mientras la sesión conserva su nueva fecha futura. `Planificación > Hablar con el entrenador` añade la primera interfaz de solicitud: un intérprete local y sustituible reconoce por ahora cancelaciones, una fecha ISO y una duración en minutos, muestra la intención resultante y solo permite crear una revisión pendiente. No hay acceso a red, modelo de IA ni mutación directa del plan en esta capa.

Actualización v0.1.127: las solicitudes al entrenador se guardan localmente con su texto, sesión de contexto, interpretación, estado de aclaración y revisión vinculada, y pueden borrarse desde la propia pantalla. La autorización para un futuro intérprete remoto es explícita y reversible; por ahora no activa ninguna transmisión. El contrato remoto v1 queda limitado a la solicitud, objetivo, experiencia, disponibilidad, material y resumen de la sesión elegida. Excluye por diseño Apple Salud, molestias, limitaciones en texto libre, series ejecutadas, cargas reales e historial de entrenamientos. Cualquier proveedor remoto deberá devolver únicamente intenciones tipadas, que seguirán siendo validadas y aceptadas localmente.

Actualización v0.1.128: el motor de propuestas incorpora avisos auditables para aumentos de carga superiores al 10 %, incrementos semanales de volumen superiores al 30 % y reducciones de grupos musculares declarados prioritarios. No bloquea ni muta automáticamente un plan: obliga a revisar la intención antes de aceptar la revisión. El calendario de Planificación identifica cada semana del macrociclo con un color de baja intensidad y, al seleccionar una sesión, muestra el número de semana y su objetivo sin interferir con los estados de hoy, sesión prevista o completada.

Actualización v0.1.129: el perfil separa molestias de lesiones. Las molestias se conservan como chips para el feedback 0–3 y generan precauciones de ejecución por patrón, con recomendación de carga y RIR conservadores, pero no bloquean ejercicios ni marcan incompatibilidad. Las lesiones o restricciones médicas se declaran por separado y sí se compilan como restricciones para el motor y la compatibilidad futura. Planificación incorpora el detalle de macrociclo: fases agrupadas, objetivo semanal y progreso de sesiones realizadas. El intérprete local reconoce además mañana, pasado mañana y días de la semana en español; los casos ambiguos siguen quedando como solicitudes que requieren aclaración.

Actualización v0.1.130: el detalle semanal del macrociclo usa tarjetas independientes con cabecera integrada, color de fase y progreso de sesiones para conservar la jerarquía visual de la previsualización de entrenamiento. Ante una solicitud de cancelación, el entrenador local busca hasta tres fechas futuras disponibles, posteriores a la sesión afectada y sin conflictos de calendario. La persona puede escoger una alternativa o conservar la cancelación; ambas opciones crean únicamente una revisión pendiente tras confirmación.

Actualización v0.1.131: la disponibilidad del perfil guía las replanificaciones automáticas, pero no impide excepciones explícitas. Si no existen suficientes huecos compatibles, el planificador propone también fechas futuras sin conflicto fuera de la disponibilidad habitual y las etiqueta de forma visible antes de crear una revisión. La elección puntual no modifica los días generales configurados en el perfil.

Actualización v0.1.132: cuando una sesión no tiene hueco directo, el planificador puede proponer una cadena corta de desplazamientos entre sesiones futuras y editables. Las operaciones se validan y aplican de atrás hacia delante para liberar cada fecha antes de ocuparla. La interfaz informa cuántas sesiones posteriores se desplazan; las sesiones activas, completadas, pasadas o una cadena sin hueco final siguen excluidas.

Actualización v0.1.133: el entrenador local reconoce una ausencia de una semana, por ejemplo “estaré de vacaciones la semana que viene”, y genera una única revisión tipada que desplaza siete días todas las sesiones futuras desde el inicio de esa semana. El impacto enumera todas las sesiones aplazadas y la aplicación conserva intactas las sesiones activas, completadas, canceladas o pasadas; si alguna sesión afectada no es editable, la propuesta se rechaza antes de modificar el plan.

Actualización v0.1.134: las ausencias aceptan ahora intervalos explícitos, tanto en ISO (`del 2026-11-02 al 2026-11-16`) como en español (`del 12 al 19 de octubre`). La fecha final representa el regreso y es exclusiva, por lo que el motor calcula el número exacto de días a desplazar. Cada revisión comunica también la nueva fecha de finalización del macrociclo; los impactos guardados antes de este campo se mantienen legibles.

Actualización v0.1.135: los intervalos de ausencia en español pueden cruzar mes, por ejemplo `del 28 de noviembre al 6 de diciembre`, y el motor conserva la fase, el objetivo y el volumen de cada semana mientras traslada sus fechas. El impacto identifica las semanas de macrociclo reprogramadas (`S3`, `S4`, etc.) junto con la nueva fecha final, para distinguir con claridad un cambio temporal de una modificación de la carga planificada.

Actualización v0.1.136: el entrenador local reconoce cierres puntuales del gimnasio, por ejemplo `El 12 de octubre es festivo y el gym no abre` o una fecha ISO equivalente. El cierre genera una intención auditable propia y una revisión que desplaza un día las sesiones futuras desde esa fecha, sin requerir seleccionar una sesión y sin modificar los objetivos ni las semanas del macrociclo.

Actualización v0.1.137: las revisiones aceptadas forman ahora una cadena explícita. Cada propuesta se simula sobre el plan efectivo en su fecha de vigencia, guarda la revisión aceptada de la que parte y la muestra en su tarjeta. Conversación y simulador usan la misma instantánea efectiva para seleccionar sesiones, alternativas y ejercicios. Si una propuesta hermana queda obsoleta al aceptar otra revisión, no se aplica silenciosamente: permanece pendiente y pide regenerarse sobre la planificación actual.

Actualización v0.1.138: una revisión pendiente obsoleta puede actualizarse desde su propia tarjeta. La actualización conserva su motivo y sus operaciones, vuelve a validarlas contra perfil, sesiones protegidas y plan efectivo, renueva su impacto y reasigna la revisión base. Hasta completar este paso, la acción principal no permite aceptar una instantánea antigua.

Actualización v0.1.139: Planificación incorpora `Revisión semanal`, una exportación versionada de contexto para el flujo externo de pruebas. Al cerrar una semana, comparte el plan efectivo, perfil, identificadores de sesiones cerradas, ejecuciones con cargas, RIR, descansos y molestias, y la referencia de la siguiente semana del macrociclo. El archivo no aplica cambios: permite que un agente externo proponga un borrador sin sustituir silenciosamente la planificación local.

Actualización v0.1.140: la revisión semanal puede compartir instrucciones y reimportar una propuesta externa con contrato `gymapp.external-planning-proposal`. El agente debe devolver operaciones tipadas, nunca un plan completo; la app comprueba schema, versión, identificador de plan, restricciones, sesiones protegidas, volumen, progresión y conflictos antes de crear una revisión pendiente con diff e impacto.

Actualización v0.1.141: `Hoy` se ancla a la semana correspondiente a la fecha real, o a la sesión activa si existe; ya no adelanta automáticamente la interfaz a una semana futura al completar la actual. Cuando el plan contiene una semana posterior, ofrece una consulta explícita en modo lectura: permite recorrer sus tarjetas y previsualizaciones, pero no iniciar ni reanudar entrenamientos. La exportación de revisión semanal queda accesible desde `Hoy` y desde el resumen de la última sesión de la semana, incluyendo esta última ejecución aunque SwiftData aún no haya actualizado su consulta.

Actualización v0.1.142: una sesión pendiente cuya fecha ya pasó se puede recuperar sin alterar el histórico: `Hoy` ofrece llevarla directamente al Entrenador y el selector conversacional incluye sesiones pasadas no completadas. La persona puede pedir una fecha concreta, como el próximo miércoles, o pedir replanificación; el motor solo permite mover esa sesión a hoy o al futuro y sigue rechazando sesiones activas, completadas o canceladas. La revisión semanal incorpora una primera lectura determinista de adherencia, RIR, series omitidas, molestias y objetivo de la próxima semana. Informa recomendaciones conservadoras, pero todavía no aplica ajustes automáticos.

Actualización v0.1.143: la revisión local puede crear una propuesta conservadora tipada cuando la semana se completó sin series omitidas ni molestias y el RIR medio fue al menos 3. Solo ajusta series efectivas de ejercicios equivalentes en la siguiente semana futura, limita el aumento a un 2,5 % y lo redondea a 0,5 kg. La propuesta sigue el mismo recorrido auditable de revisión, validación y aceptación manual; no aparece ni modifica el plan cuando faltan condiciones de seguridad.

Actualización v0.1.144: las propuestas locales usan el inventario real del perfil, no redondeos genéricos: solo sugieren el siguiente peso montable para el material del ejercicio y dentro del límite conservador. Con RIR alto, si no existe un salto de carga seguro, pueden proponer una repetición adicional; con RIR muy bajo, sin omisiones ni molestias, pueden ampliar el descanso. La revisión muestra una explicación por ejercicio antes de crear el borrador. La pantalla del Entrenador separa privacidad, sesión y solicitud con relleno interno y espaciado consistente, y `Hoy` ofrece acceso directo por chat.

Actualización v0.1.145: la revisión local condiciona sus propuestas a la fase de destino y limita un cambio por familia de ejercicio en la semana futura. Acumulación prioriza una repetición; intensificación permite el siguiente salto de carga montable; descarga, readaptación y test no generan progresión automática; realización conserva la prescripción. Con RIR muy bajo solo amplía descansos fuera de fases ya conservadoras. La interfaz expone la regla aplicada junto al objetivo semanal.

Actualización v0.1.146: la propuesta semanal define límites por tipo de ejercicio y material: básicos no superan 10 reps y accesorios 15; barra y multipower no aumentan más del 2,5 %, mientras que mancuernas, poleas y máquinas quedan limitadas al 5 % y siempre a una carga disponible. Los descansos se acotan a 240 s en básicos y 150 s en accesorios. Superseries, temporizados y peso corporal se excluyen de automatización hasta disponer de una regla específica de bloque.

Actualización v0.1.147: las superseries pasan a tener regla de bloque: solo se proponen ajustes si todos los integrantes equivalentes se completaron y todos admiten el mismo modo de ajuste; de otro modo el bloque entero se conserva. Los temporizados pueden progresar únicamente en acumulación mediante +5 s, con máximo de 90 s, y ante RIR bajo ajustan el descanso de ronda con máximo de 90 s. El peso corporal continúa requiriendo revisión manual.

Actualización v0.1.148: peso corporal sin asistencia ni lastre puede progresar una repetición en acumulación, dentro del rango de reps correspondiente. La app no infiere ni modifica asistencia o lastre desde texto libre: cualquier ejercicio que los declare, o que no tenga carga objetivo cero, queda fuera de la propuesta automática y requiere revisión manual.

Actualización v0.1.149: el modelo de serie incorpora `bodyweightLoad` opcional, con `assistanceKg` y `addedWeightKg` y un modo derivado (`unassisted`, `assisted`, `weighted`). El campo vive en el plan y viaja por los borradores, histórico y backups ya codificados; su ausencia conserva compatibilidad y significa peso corporal sin asistencia ni lastre. Falta una operación de planificación tipada para modificarlo tras validación.

Actualización v0.1.150: el motor incorpora `adjustBodyweightLoad`, operación tipada y serializable para modificar asistencia o lastre de una serie de peso corporal. Solo se aplica a sesiones editables y ejercicios de peso corporal, y rechaza asistencia y lastre simultáneos. El contrato de revisión externa queda actualizado para que un agente pueda proponerla sin generar JSON ambiguo; las reglas automáticas para decidir cuándo usarla siguen pendientes.

Actualización v0.1.151: el perfil registra el salto de asistencia y los lastres realmente disponibles para peso corporal. La revisión semanal conserva el orden de progresión: añade reps en acumulación, reduce después la asistencia declarada y solo propone el siguiente lastre configurado en intensificación. Entrenador ofrece además un selector explícito de ejercicio y serie de peso corporal para crear esa misma revisión tipada; el texto libre no infiere todavía el ejercicio objetivo, evitando cambios ambiguos.

Actualización v0.1.152: Entrenador convierte las solicitudes locales inequívocas de reducir asistencia o añadir lastre en una aclaración contextual dentro del formulario. Si el mensaje identifica un único ejercicio de peso corporal, lo preselecciona; de lo contrario obliga a elegir ejercicio y serie antes de habilitar la propuesta. La aclaración se registra en el historial local y la revisión sigue siendo explícita, tipada y confirmable.

Actualización v0.1.153: Entrenador reconoce también peticiones locales direccionales de reps, peso y descanso. Las transforma en una tarjeta de aclaración de ejercicio y serie que enseña el antes y el después: una repetición, el siguiente salto de carga realmente disponible o 15 s de descanso, dentro de límites. El cambio se limita por ahora a una serie concreta; aplicar una regla a varias series equivalentes requerirá una opción de alcance explícita.

Actualización v0.1.154: el Core incorpora `CoachSetAdjustmentRequest`, contrato codificable de ajuste parcialmente resuelto con tipo, dirección, objetivo opcional y alcance. Entrenador admite objetivos expresos como “a 8 reps”, “a 62,5 kg” o “a 120 s”, ajusta el peso a la carga disponible más próxima y pide seleccionar el alcance: una serie o todas las series del ejercicio. El segundo caso crea una revisión compuesta de operaciones tipadas; el alcance nunca se presupone.

Actualización v0.1.155: Entrenador incorpora sustituciones conversacionales de ejercicios. Detecta el ejercicio origen cuando el texto es inequívoco y, si no, solicita elegirlo; ofrece alternativas del catálogo canónico filtradas por material, restricciones y afinidad de patrón o musculatura principal. La tarjeta explica si conserva patrón, series y posición de superserie, y la decisión se confirma como una revisión tipada de sustitución validada de nuevo por el motor.

Actualización v0.1.156: Entrenador puede encadenar una sustitución y un ajuste de serie de la misma solicitud. Resuelve una aclaración cada vez, conserva las operaciones ya concretadas y, al terminar, presenta una única propuesta compuesta vinculada a la conversación original. El alcance inicial se limita a estas dos clases de acción para que una frase con más cambios o contradicciones no oculte decisiones al usuario.

Actualización v0.1.157: `CoachRequestCoherence` revisa una propuesta antes de crear su revisión. Bloquea operaciones contradictorias sobre la misma serie y cambios que aumenten la exigencia durante descarga o readaptación, o que alteren realización y test; además avisa cuando una carga en acumulación o más reps en intensificación contradicen la prioridad de fase. Las incidencias se muestran en Entrenador y los bloqueos deshabilitan la creación de la revisión.

Actualización v0.1.158: las solicitudes compuestas de Entrenador se guardan como `CoachConversationDraft` en el registro local de conversación. Conservan la petición original, la aclaración activa, la cola pendiente y las operaciones ya resueltas; al volver a Entrenador, restauran la misma decisión sobre la sesión elegida y continúan hasta generar una única revisión. El borrador se borra al completar la propuesta.

Actualización v0.1.159: las entradas de Historial local recuperan relleno interno consistente dentro de su tarjeta. El compositor de Entrenador admite además reprogramar una sesión a una fecha ISO explícita junto con una sustitución o ajuste; el movimiento se incorpora a la misma cola persistible y a la revisión compuesta final. La adaptación de duración seguirá usando una aclaración de alternativas, no una elección automática.

Actualización v0.1.160: el compositor incorpora adaptación de duración como aclaración de alternativas conservadoras dentro de la misma solicitud persistible. También interpreta fechas ISO, mañana, pasado mañana y los días de la semana en solicitudes compuestas, resolviéndolos a una fecha concreta antes de la validación. Una petición puede ahora mover sesión, escoger una versión acortada, sustituir ejercicio y ajustar series dentro de una única revisión confirmable.

Actualización v0.1.161: la compatibilidad del perfil se acota a las tres próximas sesiones y separa restricciones reales de molestias. Las molestias no invalidan ni bloquean ejercicios: se agrupan como una pauta de ejecución con técnica, rango sin dolor y RIR conservador. La revisión semanal aplica relleno y separación explícitos a cada bloque de acciones, lectura y propuesta local. La ejecución deriva el RIR inicial y el consejo de entrenador de la fase del ejercicio: descarga y readaptación parten de 3 RIR, acumulación de 2 e intensificación de 1; las notas estáticas con RIR o reps no prevalecen sobre la prescripción semanal.

Actualización v0.1.162: el contrato Watch–iPhone incluye fase, foco semanal y molestias declaradas del perfil. El feedback de Watch muestra exactamente esas molestias con escala 0–3 y devuelve los niveles personalizados junto al RIR contextual. Las órdenes del reloj se envían en tiempo real cuando el iPhone es alcanzable y, si no lo es, se encolan con `transferUserInfo`; el iPhone las deduplica por UUID de forma persistente para que una entrega tardía no registre una serie dos veces. Ambos destinos compilan sobre el mismo contrato antes de la validación física.

Actualización v0.1.163: la lista principal del Watch recibe del iPhone la semana activa, su objetivo y la sesión recomendada, usando la misma regla que `Hoy` tras reprogramaciones, sesiones completadas o una sesión activa. Las duraciones de tarjetas y previsualización se derivan con el estimador compartido. Un bloque de diagnóstico al final de la lista muestra alcance del iPhone, última sincronización y acciones pendientes, con actualización manual para validar el flujo real en gimnasio.

Actualización v0.1.164: la ejecución en Watch incorpora continuación explícita desde RIR, `OK` inicial en feedback y la duración de calentamiento configurada aunque la orden llegue antes de que iOS materialice el valor de preferencias. El calentamiento comparte la animación de barra vaciándose de descanso. En descansos entre ejercicios la corona selecciona un ejercicio pendiente sin alterar el temporizador. El progreso global abre un historial de solo lectura con series completadas, omitidas y pendientes.

Actualización v0.1.165: una petición de actualización desde Watch ya no devuelve un catálogo en memoria potencialmente caducado. Al recibir `requestState`, el iPhone obliga al host de SwiftData a reconstruir y publicar el estado efectivo; la respuesta directa incluye dicho snapshot y también actualiza `applicationContext`. El diagnóstico solo marca una sincronización nueva después de decodificar ese estado recibido.

Actualización v0.1.166: cada comando alcanzable del Watch recibe en su propia respuesta el snapshot resultante para avanzar de pantalla sin depender de un segundo envío. La revisión semanal deja de usar un único RIR medio global: analiza adherencia, RIR, molestias, decisión y valores ejecutados por ejercicio y material, contrasta esas señales con la fase de la semana siguiente y crea únicamente un borrador revisable. La pantalla separa cambios propuestos de objetivos que ya conviene conservar.

Actualización v0.1.167: el contexto exportado de revisión semanal sube a schema v2 e incluye las decisiones finales por ejercicio de cada sesión. Las instrucciones compartidas con el agente externo reproducen las mismas reglas de seguridad, fase, material, redondeos y no duplicación de progresión del motor local, para que ambas rutas generen borradores equivalentes y auditables.

### Futuro: planificación y análisis con IA

- Dirección de producto: GymApp prioriza un agente de IA que actúa como entrenador personal conversacional. El objetivo no es construir primero un editor manual amplio, sino permitir expresar intenciones como "no podré entrenar el jueves", "quiero priorizar dominadas" o "me molesta el hombro" y recibir una propuesta explicable de reajuste.
- Principio de arquitectura: el agente interpreta la intención y propone cambios, pero no es la fuente de verdad ni modifica directamente el plan. El motor determinista valida calendario, volumen, material, restricciones, ejercicios compatibles y límites de progresión antes de que el usuario confirme.
- [~] Definir el perfil estructurado que condiciona toda propuesta: objetivo, experiencia, disponibilidad, duración máxima por sesión, material, preferencias, prioridades musculares, ejercicios a evitar y limitaciones existen; faltan cardio y referencias iniciales por patrón.
- [~] Versionar el plan con fecha de vigencia. Las instantáneas, estados, operaciones, diff legible, generación validada y encadenamiento explícito sobre el plan efectivo existen; falta una herramienta guiada para regenerar una propuesta obsoleta sin reescribir la petición.
- [~] Crear operaciones de planificación tipadas y auditables: mover, cancelar, añadir, quitar y sustituir ejercicios, y cambiar reps, carga, duración, descanso, asistencia o lastre existen con validación y cambios resultantes; faltan reglas más ricas para prioridades y superseries.
- [~] Implementar un motor determinista de calendario y programación que funcione sin IA: comprueba conflictos, sesiones duplicadas, duración, material, restricciones y progresión conservadora; faltan límites por bloque, distribución semanal completa y reglas de periodización.
- [~] Añadir una pantalla de propuesta que muestre qué cambia, qué se conserva, por qué y el impacto semanal. El simulador local crea revisiones pendientes para mover o cancelar sesiones, sustituir ejercicios y ajustar series con cambios y avisos auditables; falta el impacto semanal completo.
- [ ] Análisis de entrenamiento con IA sobre historial, adherencia, feedback, cargas y duración real, siempre como propuesta explicada y confirmada antes de modificar un plan.
- [~] Integrar el chat como interfaz de intención sobre las operaciones validadas, con contexto limitado al perfil, plan efectivo, sesiones ejecutadas y restricciones relevantes. El intérprete local entiende ausencias, fechas, cierres, duración, ajustes de series y sustituciones de ejercicios; Entrenador encadena una sustitución y un ajuste de serie en una revisión compuesta. Faltan más de dos acciones, peticiones contradictorias y aclaraciones que dependan de una respuesta anterior.
- [~] Definir una revisión semanal estructurada local: recopila cumplimiento, RIR, series omitidas, decisiones y molestias por ejercicio; contrasta cada señal con la fase siguiente y puede crear un borrador de carga, reps, descanso, duración, asistencia o lastre tipado, limitado y confirmable. Distingue los cambios de aquello que conserva y evita que una incidencia aislada bloquee toda la semana; falta una explicación agrupada por sesión.
- [~] Mantener durante las pruebas un puente de revisión externa: la app exporta contexto semanal, comparte el contrato e importa operaciones tipadas como revisión pendiente validada; falta permitir adjuntar la explicación extensa del agente y registrar proveedor/modelo/consentimiento cuando la integración sea remota.

### Futuro: nuevo macrociclo

- [ ] Al finalizar el macrociclo, ofrecer un asistente de creación de un nuevo plan, separado de las revisiones del anterior y conservando íntegros el histórico y las decisiones ya aceptadas.
- [ ] Permitir reutilizar selectivamente perfil, disponibilidad, inventario de material, preferencias, molestias y referencias de carga, sin asumir que se conserva el objetivo.
- [ ] Recoger objetivo nuevo, horizonte temporal, prioridad muscular, experiencia reciente y posibles cambios de disponibilidad antes de generar el borrador.
- [ ] Generar una propuesta de nuevo macrociclo con versión y fecha de inicio explícitas; el plan actual debe archivarse, no sobrescribirse.
- [ ] Diseñar límites de seguridad: no proponer progresiones o sustituciones que contradigan molestias declaradas, material real o límites del usuario; dejar trazabilidad de la propuesta y de la decisión del usuario.
- [ ] Definir backend, identidad, política de coste, retención, consentimiento y privacidad antes de enviar perfil, molestias o historial a un modelo externo.
- [ ] Mantener la ejecución en gimnasio, el registro y el acceso a planes ya descargados plenamente funcionales sin IA ni conexión.

### Futuro: molestias y almacenamiento independiente

- [~] Ampliar molestias más allá del feedback puntual de cada serie: el perfil permite declararlas como chips y la pantalla de serie las valora de 0 a 3; generan precauciones de ejecución, separadas de las lesiones que restringen ejercicios. Faltan un modelo específico de zona, contexto, evolución y recomendaciones individualizadas.
- [ ] Definir un esquema de datos y exportación propio para molestias, separado del CSV de series y no dependiente de Obsidian, antes de almacenar información sensible.
- [ ] Establecer reglas de retención, edición y borrado de esas entradas, junto con una exportación completa legible por el usuario.

### Hito 27: Companion Apple Watch

Objetivo: ofrecer una extensión de muñeca rápida durante el entrenamiento sin duplicar la lógica ni comprometer el registro que ya funciona en el iPhone.

Prioridad 1:

- [x] crear el target watchOS y un canal de sincronización con el iPhone que publique la sesión, serie actual, objetivos, material, progreso y descanso
- [~] publicar en el reloj los entrenamientos disponibles y el estado activo, incluidos título, fecha, progreso y posibilidad de solicitar el inicio de uno desde la muñeca
- [~] diseñar la selección de entrenamiento equivalente a Hoy: lista compacta, estados en curso/completado y acceso a previsualización; falta validar jerarquía y estados con datos reales
- [~] diseñar la previsualización de Watch: ejercicios con primera serie, navegación nativa, selección de siguiente ejercicio y botón Play superior; falta reflejar la siguiente serie de un borrador reanudado
- [~] diseñar la pantalla de serie: número de serie y material en etiqueta superior, dos cajas verticales para reps y peso, edición por Digital Crown con confirmación, y acciones inferiores de saltar (un tercio) y registrar (dos tercios); falta validar ergonomía física
- [~] diseñar la pantalla de descanso con cuenta atrás, próxima serie y háptica al finalizar
- [~] aplicar en descanso una animación de vaciado del realce como fondo, contador grande, tip de próxima serie y estado verde sutil con háptica al terminar; el vaciado continuo queda pendiente
- [~] diseñar una pantalla compacta de entrenamiento completado, adaptada al resumen nativo del iPhone
- [x] aplicar las acciones del reloj de forma idempotente sobre el estado del iPhone, evitando registros duplicados al reconectar

Prioridad 2:

- [x] mostrar superseries como secuencia de ejercicios vinculados, manteniendo clara la integrante actual
- [ ] sincronizar tokens de apariencia y acento del iPhone con Watch: fondo, superficies, realce, variantes desaturadas, éxito, aviso y contraste accesible en todos los temas
- [ ] incorporar una cola local visible en el reloj para registrar acciones sin conexión temporal con el teléfono, mostrar qué está pendiente y reconciliar automáticamente en orden al recuperar alcance, con deduplicación y resolución explícita de conflictos
- [ ] definir notificaciones y sonidos de finalización coherentes entre iPhone y reloj, sin avisos duplicados

Fuera de la primera versión:

- edición del plan, historial, exportación, análisis y configuración completa desde el reloj
- fuente de verdad independiente en watchOS; el iPhone seguirá guardando el borrador y las sesiones definitivas

### Corrección de series registradas

- [x] Permitir corregir `reps`, `peso` y duración, cuando aplique, de una serie ya registrada tanto en un entrenamiento activo como en uno finalizado.
- [x] Conservar la edición como una modificación explícita del registro: actualizar histórico, RM, CSV, backup JSON y la representación de progreso sin alterar el orden ni el estado (`completed` o `skipped`) de la serie.
- [x] Reconciliar Apple Salud para una sesión ya exportada: eliminar el `HKWorkout` vinculado antes de recrearlo, sin duplicados.

Criterio de aceptación:

- con el iPhone cerca, una serie normal, una superserie y una temporizada se pueden completar desde el reloj y quedan registradas una sola vez en el iPhone
- un descanso termina con háptica y permite ver con claridad la siguiente acción
- al abrir el iPhone, progreso, material, feedback y exportación reflejan exactamente la ejecución registrada desde el reloj

## Riesgos y decisiones pendientes

- Confirmar si los pesos de GymBook en ejercicios con mancuernas representan total o peso por mancuerna.
- Definir si el plan prioriza fuerza, hipertrofia, recomposicion o rendimiento mixto.
- Decidir si la primera version necesita autenticacion. Por ahora, no.
- Decidir si los datos se quedan solo en el dispositivo, si habra sincronizacion iCloud o si se ofrecera backup manual como opcion principal.
- Evitar que el countdown de descanso bloquee ajustes utiles entre series.
- Disenar controles tactiles suficientemente grandes sin convertir la pantalla en una calculadora.
- Definir mas adelante como tratar superseries con distinto numero de series por ejercicio.
- Decidir si el plan tendra correcciones manuales, versiones generadas desde la app o sugerencias asistidas por IA.
- Decidir cuando IndexedDB deja de ser suficiente en PWA y conviene una copia local exportable mas directa.
- Revisar la decision inicial de SwiftData si aparecen requisitos fuertes de portabilidad o control manual de base de datos.
- Definir que datos deben sincronizarse por iCloud y cuales pueden quedarse solo en el dispositivo.
- Definir que estadisticas son imprescindibles en local y cuales pueden esperar a exportaciones externas.
- Definir si la IA se ejecutara mediante backend propio, proveedor externo o solo como flujo manual durante las primeras pruebas.
- Definir politica de privacidad antes de enviar historico, molestias o datos fisicos a cualquier servicio de IA.

## Backlog futuro

- Integracion opcional con Atajos de iOS.
- Paridad nativa del flujo principal: preview, serie, feedback, descanso y finalizacion.
- Live Activity para temporizador de descanso.
- Integracion con HealthKit para registrar entrenamientos.
- App companion de Apple Watch para registrar series y descansos.
- Widget de proximo entrenamiento y progreso semanal.
- Exportacion Markdown por sesion, si aporta valor frente al CSV.
- Estadisticas avanzadas y graficos dentro de la app.
- Exportacion de graficos y resumenes desde la app.
- Vista de volumen semanal por grupo muscular.
- Vista de progresion por ejercicio.
- Vista de duracion real, descansos reales y tiempos entre ejercicios.
- Vista de comparacion planificado vs ejecutado.
- Modo de edicion manual del plan desde la propia app.
- Generador guiado de planes de entrenamiento dentro de la app.
- Perfil de material disponible editable por el usuario.
- Versionado de planes activos y planes historicos.
- Capa opcional de IA para proponer planes, analizar semanas y sugerir ajustes.
- Sustituciones inteligentes de ejercicios por material disponible o molestias.
- Modo `tengo 45 minutos hoy` para adaptar una sesion puntual sin alterar el plan base.
- Gestion de calentamientos o aproximaciones antes de series efectivas.
- Soporte para notas libres con dictado, si no rompe la filosofia tactil.
- Sincronizacion multi-dispositivo, solo si el uso local se queda corto.
- Autenticacion, solo si aparece backend o sincronizacion.

## Próximo hito recomendado

Construir el onboarding y el perfil de entrenamiento editable desde `Opciones`. Será la base estructurada para generar y reajustar planes mediante el futuro agente, sin empezar todavía por un editor manual amplio.

Checklist mínima de la siguiente iteración:

- [ ] Definir y persistir un perfil versionado: objetivo, experiencia, disponibilidad, duración máxima, material, preferencias, prioridades, ejercicios a evitar y limitaciones.
- [ ] Crear un onboarding que recoja el perfil por pasos y pueda retomarse sin perder el progreso.
- [ ] Añadir `Opciones > Perfil de entrenamiento` para revisar y actualizar el perfil sin modificar entrenamientos activos o sesiones históricas.
- [ ] Mostrar con claridad desde qué fecha se aplicarán los futuros ajustes del plan.
- [ ] Mantener el gesto de vuelta como pulido posterior, no como un bloque prioritario.
