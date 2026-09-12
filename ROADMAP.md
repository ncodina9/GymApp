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
| 17   | Parcial   | Media    | Media       | Instalacion/offline mas solida y estado de service worker.                       |
| 18   | Pendiente | Baja     | Media       | Layout movil horizontal; de momento la app bloquea vertical.                     |
| 19   | Parcial   | Media    | Media       | Historial dentro de la app con exportacion y borrado.                            |
| 20   | Parcial   | Alta     | Alta        | Preparacion PWA -> app nativa iOS y contrato JSON completo.                      |
| 21   | Parcial   | Alta     | Alta        | Estadisticas y graficos dentro de la app.                                        |
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
- descanso con cuenta atras circular y ajuste de `-15s` / `+15s`
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
- decision cerrada: el CSV por serie conserva cabecera estable sin columnas de schema para seguir siendo apendable al maestro de Obsidian; el contrato queda documentado como `gymapp.workout-set-export` version 1
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
- [ ] documentar como forzar actualizacion de la PWA en iPhone
- [x] validar que `trainingPlan.json`, iconos y assets quedan cacheados
- [x] decidir si hace falta aviso cuando hay una version nueva disponible
- [x] subir `package.json` y `package-lock.json` en cada iteracion desplegable para que Ajustes identifique la version servida

Criterio de aceptacion:

- la app abre y funciona sin conexion despues de haber cargado una vez
- el usuario puede comprobar que version esta usando
- actualizar la app no borra datos locales

Estado: v1 implementada. El service worker cachea la ruta principal, manifest e iconos base, limpia caches antiguas y responde con version/cache para que Ajustes pueda mostrar el estado de uso sin conexion. La pantalla de Ajustes incluye comprobacion manual de caché, version del worker, recursos base y boton de actualizacion cuando hay una version esperando. En `localhost` se permite registrar el worker para pruebas; en una URL `http://IP-del-Mac:3000` iOS no lo tratara como contexto seguro, por lo que la prueba real de gimnasio debe hacerse desde la URL HTTPS de Vercel instalada en pantalla de inicio.

Pendiente futuro: documentar el flujo de forzar refresco de PWA en iPhone si Safari mantiene una version antigua.

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
- [ ] separar calculo de progreso de sesion
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
- el secuenciador de ejercicios, series y superseries vive en `lib/workoutSequence.ts`
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
- Decidir cuando iniciar el prototipo SwiftUI: despues de validar el flujo principal en gimnasio o antes para probar ventajas nativas concretas.
- Revisar la decision inicial de SwiftData si aparecen requisitos fuertes de portabilidad o control manual de base de datos.
- Definir que datos deben sincronizarse por iCloud y cuales pueden quedarse solo en el dispositivo.
- Definir que estadisticas son imprescindibles en local y cuales pueden esperar a exportaciones externas.
- Definir si la IA se ejecutara mediante backend propio, proveedor externo o solo como flujo manual durante las primeras pruebas.
- Definir politica de privacidad antes de enviar historico, molestias o datos fisicos a cualquier servicio de IA.

## Backlog futuro

- Integracion opcional con Atajos de iOS.
- Prototipo SwiftUI que cargue `trainingPlan.json` y permita completar una sesion minima.
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

## Proximo hito recomendado

Simplificar la vista `Revisión del plan` del Hito 21/16 para que funcione como lectura descriptiva mientras no exista todavía revision semanal inteligente ni ajuste automatico del planning.

Checklist minima de la siguiente iteracion:

- [x] Revisar textos y jerarquia visual de `Revisión del plan`.
- [x] Separar claramente senal calculada, decision manual y datos reales.
- [ ] Decidir que tarjetas deben mostrarse cerradas y que informacion solo al desplegar.
- [ ] Reducir ruido de recomendaciones conservadoras hasta que exista revision semanal guiada.
- [ ] Mantener exportacion estadistica trazable para Obsidian y futura app nativa.
