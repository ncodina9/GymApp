# Roadmap companion app de entrenamiento

## Objetivo

Crear una companion app para iPhone orientada a ejecutar el entrenamiento en el gimnasio con el mínimo rozamiento posible. La app debe decir claramente que toca hacer ahora, permitir ajustar carga y repeticiones con controles tactiles rapidos, registrar la serie y guiar el descanso hasta la siguiente accion.

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

Primera version como PWA offline-first.

Stack inicial recomendado:

- React + TypeScript + Vite
- CSS propio o Tailwind si se decide priorizar velocidad de UI
- IndexedDB para registros locales
- JSON versionado para planificacion
- service worker para funcionamiento offline
- exportacion Markdown/CSV en una fase posterior

La app debe poder alojarse como sitio estatico. No hace falta Northflank para la primera version si no hay backend. Un alojamiento estatico con soporte HTTPS es suficiente para instalarla como PWA en iPhone. Si despues necesitamos sincronizacion multi-dispositivo, cuentas de usuario o backups automaticos, se reevaluara backend.

## Hitos

### Estado actual

Ya esta implementada una primera version funcional de la app:

- proyecto versionado en GitHub y conectado con Vercel
- app React/Vinext con UI tactil orientada a iPhone
- pantalla Hoy con recomendacion de entrenamiento y seleccion semanal
- reanudacion de entrenamiento iniciado
- previsualizacion previa con ejercicios, series, reps/tiempo y pesos
- pantalla de serie sin teclado, con controles grandes de reps/peso
- incremento de peso con paso configurable de `1 kg` o `0.5 kg`
- soporte para ejercicios temporizados con cuenta atras circular
- feedback despues de cada serie, antes del descanso
- descanso con cuenta atras circular y ajuste de `-15s` / `+15s`
- persistencia local con IndexedDB y recuperacion del borrador desde `localStorage`
- ajustes con selector de tema, reset de entrenamiento y borrado local
- temas claro y oscuro minimalistas
- iconos PWA y manifest para instalacion en iPhone
- service worker basico
- exportacion CSV por serie
- plan trimestral real en `data/trainingPlan.json`
- generador del plan en `scripts/generate-training-plan.mjs`
- superseries v1 mediante bloques `E1/E2`, `F1/F2`, etc.
- planchas ajustadas a series de 60 s
- cargas del plan ajustadas al material disponible: mancuernas, discos y polea
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
- redondear barra/multipower a combinaciones simétricas de barra de 20 kg y discos disponibles
- redondear lastre a combinaciones de discos disponibles
- redondear polea a saltos de 5 kg hasta 100 kg cuando haya carga conocida
- regenerar `data/trainingPlan.json` desde `scripts/generate-training-plan.mjs`
- validar que no quedan pesos no montables ni planchas de 45 s

Criterio de aceptacion:

- todas las planchas del JSON muestran `60s`
- todo `targetWeightKg` no nulo corresponde a una carga disponible
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

- mostrar estado simple de guardado local despues de registrar una serie
- proteger contra doble pulsacion accidental en `Registrar serie`
- permitir reexportar un entrenamiento terminado sin perder datos
- listar entrenamientos con datos locales desde Ajustes
- borrar los datos de una sesion concreta sin borrar todo el historico local
- marcar sesiones exportadas con `exportedAt`
- purgar automaticamente sesiones exportadas cuando cumplan el periodo de retencion local
- no purgar sesiones sin exportar para evitar perdida silenciosa de datos
- mostrar progreso de historial como series registradas / series planificadas
- sustituir chips numericos ambiguos por estado: en curso, completo o exportado
- guardar metadata basica de sesion: `schemaVersion`, `startedAt`, `finishedAt`, `exportedAt`
- bloquear el registro mientras se guarda una serie para evitar doble pulsacion
- definir si se guarda también un resumen por ejercicio además del CSV por serie
- documentar el flujo recomendado para guardar el CSV en una ruta de Archivos del iPhone
- revisar compatibilidad del CSV con el fichero maestro de Obsidian
- decidir si el CSV debe incluir version de esquema
- valorar importacion o concatenacion posterior de varios CSV

Criterio de aceptacion:

- cada serie registrada queda persistida una sola vez
- el usuario entiende donde queda el CSV y como moverlo al repositorio personal
- los campos exportados permiten analizar volumen, carga, RIR, molestias y superseries

Estado parcial:

- historial local visible desde Ajustes, con scroll permitido en esa pantalla
- exportacion CSV de sesiones con datos sin depender de estar en la pantalla final
- borrado de una sesion concreta desde Ajustes
- al cerrar un entrenamiento y volver a hoy, se conserva la sesion finalizada para exportarla despues
- sesiones exportadas marcadas en IndexedDB con `exportedAt`
- purga automatica de sesiones exportadas con mas de 30 dias de antiguedad
- las tarjetas de historial muestran `series registradas / series planificadas`
- chip de historial cambiado a estado legible: en curso, completo o exportado
- registro de serie protegido contra doble pulsacion con bloqueo visual y bloqueo interno
- metadata local de sesion ampliada con `schemaVersion`, `startedAt`, `finishedAt` y `exportedAt`

### Hito 14: Duracion real del entrenamiento

Objetivo: medir cuanto dura una sesion y compararlo con la estimacion del plan.

Tareas:

- guardar `startedAt` al pulsar `Empezar entrenamiento`
- guardar `finishedAt` al cerrar la sesion
- mostrar duracion real al finalizar
- comparar duracion real contra `estimatedMinutes`
- incluir duracion real en el CSV o en un futuro resumen de sesion
- decidir si las pausas manuales o interrupciones cuentan dentro del tiempo total

Criterio de aceptacion:

- al terminar se ve el tiempo real invertido
- la app indica si la sesion fue mas corta, similar o mas larga que lo previsto
- la informacion queda disponible para revision posterior

Estado parcial:

- `startedAt` se guarda al empezar entrenamiento
- `finishedAt` se guarda al cerrar entrenamiento
- al finalizar se muestra la duracion real, el tiempo estimado y la diferencia
- el historial muestra la duracion de las sesiones cerradas cuando existe metadata suficiente

Estado: cerrado para la app. Queda como decision futura si la duracion total debe anadirse tambien al CSV por serie o a un resumen independiente de sesion.

### Hito 15: Superseries v2

Objetivo: mejorar la primera version de superseries para cubrir casos menos regulares.

Tareas:

- decidir politica para superseries con distinto numero de series
- mostrar mejor en la pantalla de serie que se esta dentro de una superserie
- mostrar progreso de ronda: por ejemplo `Ronda 2/4`
- revisar si conviene una transicion breve entre ejercicios vinculados o avance directo
- permitir descanso propio de superserie si difiere del descanso de cada ejercicio
- validar que decisiones de ejercicios vinculados no ocupan demasiado en movil
- incluir tests unitarios del secuenciador con casos normales, superseries y casos limite

Criterio de aceptacion:

- la app representa claramente ejercicio, orden y ronda dentro de la superserie
- los casos irregulares estan definidos y no generan comportamiento ambiguo
- el secuenciador queda protegido con tests

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

### Hito 17: Instalacion/offline mas solida

Objetivo: reducir riesgos de uso en gimnasio sin red.

Tareas:

- revisar estrategia de cache del service worker
- mostrar version/build visible en ajustes
- anadir boton de comprobacion offline o estado de app instalada
- documentar como forzar actualizacion de la PWA en iPhone
- validar que `trainingPlan.json`, iconos y assets quedan cacheados
- decidir si hace falta aviso cuando hay una version nueva disponible

Criterio de aceptacion:

- la app abre y funciona sin conexion despues de haber cargado una vez
- el usuario puede comprobar que version esta usando
- actualizar la app no borra datos locales

### Hito 18: Layout movil horizontal

Objetivo: adaptar la app a iPhone en horizontal sin degradar el flujo vertical.

Tareas:

- definir distribucion horizontal para pantalla de serie
- colocar ejercicio/progreso y controles en columnas sin scroll
- adaptar pantalla de descanso para que el circulo y botones respiren
- revisar feedback en horizontal
- probar iPhone normal y Pro Max

Criterio de aceptacion:

- girar el movil no rompe el layout
- los controles siguen siendo tactiles y legibles
- no se introduce scroll durante serie, feedback o descanso

### Hito 19: Historial dentro de la app

Objetivo: consultar sesiones anteriores sin depender del CSV exportado.

Tareas:

- listar sesiones guardadas en el dispositivo
- permitir ver resumen simple de una sesion terminada
- permitir exportar de nuevo una sesion anterior
- permitir borrar una sesion concreta
- distinguir sesion en curso, completada y abandonada

Criterio de aceptacion:

- se puede recuperar un entrenamiento anterior desde ajustes o una pantalla dedicada
- exportar no depende de estar justo en la pantalla final
- borrar datos es deliberado y claro

## Riesgos y decisiones pendientes

- Confirmar si los pesos de GymBook en ejercicios con mancuernas representan total o peso por mancuerna.
- Definir si el plan prioriza fuerza, hipertrofia, recomposicion o rendimiento mixto.
- Decidir si la primera version necesita autenticacion. Por ahora, no.
- Decidir si los datos se quedan solo en el dispositivo o si habra sincronizacion.
- Evitar que el countdown de descanso bloquee ajustes utiles entre series.
- Disenar controles tactiles suficientemente grandes sin convertir la pantalla en una calculadora.
- Definir mas adelante como tratar superseries con distinto numero de series por ejercicio.
- Decidir si el plan tendra correcciones manuales despues de cada semana o versiones generadas.
- Decidir si el historico local debe quedarse solo en IndexedDB o si conviene una copia exportable mas directa.

## Backlog futuro

- Integracion opcional con Atajos de iOS.
- Exportacion Markdown por sesion, si aporta valor frente al CSV.
- Vista de volumen semanal por grupo muscular.
- Vista de progresion por ejercicio.
- Modo de edicion manual del plan desde la propia app.
- Gestion de calentamientos o aproximaciones antes de series efectivas.
- Soporte para notas libres con dictado, si no rompe la filosofia tactil.
- Sincronizacion multi-dispositivo, solo si el uso local se queda corto.
- Autenticacion, solo si aparece backend o sincronizacion.

## Proximo hito recomendado

Continuar con el Hito 12: Pulido táctil y visual de controles.

Checklist minima de la siguiente iteracion:

1. Revisar tema claro y oscuro en iPhone real.
2. Cerrar el color principal definitivo de cada tema.
3. Homogeneizar botones de navegación y acciones secundarias.
4. Revisar contraste de textos e iconos en botones primarios.
5. Anotar fricciones de tamano, scroll, textos cortados o pulsaciones incomodas.

Despues de esa prueba, priorizar Hito 13 si el problema principal es fiabilidad de datos/exportacion.
