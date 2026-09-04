# GymApp

Companion app para ejecutar el entrenamiento en el gimnasio desde iPhone.

## Estado

Hito actual: prototipo navegable local-first con plan trimestral cargado.

Incluye:

- pantalla del entrenamiento recomendado para hoy
- seleccion tactil de entrenamientos de la semana
- ejecucion serie a serie
- controles grandes para reps y peso sin teclado
- series temporizadas con cuenta atras circular
- progreso por circulos dentro del ejercicio
- barra de progreso de sesion
- cuenta atras circular de descanso
- transicion entre ejercicios con decisiones pulsables
- deteccion de entrenamiento empezado y opcion de reanudar
- exportacion CSV compatible con guardar en Archivos desde iPhone

El plan cargado por la app esta materializado en `data/trainingPlan.json` y se genera desde el plan trimestral de Obsidian mediante `scripts/generate-training-plan.mjs`.

## Persistencia local

La app esta pensada para correr en local en el iPhone como PWA instalada desde HTTPS. Guarda el borrador de pantalla en `localStorage` y cada serie registrada como evento en IndexedDB. La pantalla inicial permite reanudar una sesion empezada.

Al terminar, `Guardar CSV` genera un archivo descargable/compartible desde iOS para poder guardarlo manualmente en Archivos, idealmente en la carpeta de exports del sistema de entrenamiento. El CSV sale de los eventos por serie e incluye RIR, molestias y nota rapida.

## PWA y prueba real

La app incluye `manifest.webmanifest`, icono instalable y service worker basico. Para probarla en el gimnasio sin el Mac, despliega `main` en Vercel, abre la URL HTTPS desde Safari y usa `Anadir a pantalla de inicio`.

Ver [docs/vercel-pwa-testing.md](./docs/vercel-pwa-testing.md).

## Desarrollo

```sh
npm install
npm run dev
```

Para probar desde un iPhone en la misma Wi-Fi:

```sh
npm run dev:host
```

Despues abre `http://IP_DEL_MAC:3000/` desde Safari. Ver [docs/mobile-testing.md](./docs/mobile-testing.md).

## Regenerar plan

```sh
npm run generate:plan
```

## Build

```sh
npm run build
```

Para Vercel, el repositorio incluye `vercel.json` y usa:

```sh
npm run build:vercel
```

Ese build genera `.vercel/output` mediante Nitro.

## Roadmap

Ver [ROADMAP.md](./ROADMAP.md).
