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
- reps, tiempos, pesos y descansos previstos
- notas breves relevantes para preparar material
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
- `plannedReps`
- `plannedWeightKg`
- `plannedDurationSeconds` si aplica
- `actualReps`
- `actualWeightKg`
- `actualDurationSeconds` si aplica
- `restSecondsPlanned`
- `restSecondsActual`
- `status`: `completed`, `skipped` o `edited`
- `note`

Mas adelante se podran anadir RIR, dolor/molestia, calidad tecnica, tempo o velocidad percibida.

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

## Riesgos y decisiones pendientes

- Confirmar si los pesos de GymBook en ejercicios con mancuernas representan total o peso por mancuerna.
- Definir si el plan prioriza fuerza, hipertrofia, recomposicion o rendimiento mixto.
- Decidir si la primera version necesita autenticacion. Por ahora, no.
- Decidir si los datos se quedan solo en el dispositivo o si habra sincronizacion.
- Evitar que el countdown de descanso bloquee ajustes utiles entre series.
- Disenar controles tactiles suficientemente grandes sin convertir la pantalla en una calculadora.

## Backlog futuro

- Layout para movil en horizontal.
- Colores ligeros para botones secundarios y de control: +, -, volver, saltar, reset, etc. Deben funcionar en ambos temas.
- Medir duracion real del entrenamiento desde que se pulsa empezar hasta finalizar, mostrar el tiempo tardado y compararlo con el tiempo estimado.
- Gestion de superseries (prioritario): en una superserie, un ejercicio lleva al siguiente vinculado y el descanso empieza cuando se han completado ambos.

## Proximo hito recomendado

Empezar por el Hito 0 y una parte acotada del Hito 1:

1. Inicializar el proyecto React/Vite.
2. Crear una sesion mock con 2 ejercicios y 3 series.
3. Construir el flujo tactil completo sin persistencia real.
4. Probarlo en viewport de iPhone.

Este hito es pequeno, valida la decision mas importante de producto y deja para despues el trabajo mas delicado: generar el JSON trimestral completo con cargas ajustadas.
