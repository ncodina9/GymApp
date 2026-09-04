# GymApp

Companion app para ejecutar el entrenamiento en el gimnasio desde iPhone.

## Estado

Hito actual: prototipo navegable local-first con plan trimestral cargado.

Incluye:

- pantalla del entrenamiento recomendado para hoy
- seleccion tactil de entrenamientos de la semana
- ejecucion serie a serie
- controles grandes para reps y peso sin teclado
- progreso por circulos dentro del ejercicio
- barra de progreso de sesion
- cuenta atras de descanso
- transicion entre ejercicios con decisiones pulsables
- deteccion de entrenamiento empezado y opcion de reanudar
- exportacion CSV compatible con guardar en Archivos desde iPhone

El plan cargado por la app esta materializado en `data/trainingPlan.json` y se genera desde el plan trimestral de Obsidian mediante `scripts/generate-training-plan.mjs`.

## Persistencia local

La app esta pensada para correr en local en el iPhone como PWA estatica. De momento guarda el borrador de entrenamiento en `localStorage` despues de cada cambio relevante y permite reanudar desde la pantalla inicial. El siguiente paso sera mover el registro a IndexedDB para guardar eventos por serie con mas robustez.

Al terminar, `Guardar CSV` genera un archivo descargable/compartible desde iOS para poder guardarlo manualmente en Archivos, idealmente en la carpeta de exports del sistema de entrenamiento.

## Desarrollo

```sh
npm install
npm run dev
```

## Regenerar plan

```sh
npm run generate:plan
```

## Build

```sh
npm run build
```

## Roadmap

Ver [ROADMAP.md](./ROADMAP.md).
