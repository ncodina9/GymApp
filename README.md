# GymApp

Companion app para ejecutar el entrenamiento en el gimnasio desde iPhone.

## Estado

Hito actual: prototipo navegable con datos mock.

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
