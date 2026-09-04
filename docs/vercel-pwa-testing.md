# Probar GymApp desde iPhone sin el Mac

## Despliegue

1. En Vercel, usa el repositorio `ncodina9/GymApp`.
2. El repositorio incluye `vercel.json`, que usa `npm run build:vercel`. Nitro genera `.vercel/output`, que Vercel despliega directamente.
3. Instala la app desde una URL `https://...vercel.app`; iOS solo permite service worker/PWA en HTTPS o localhost.

## Instalacion en iPhone

1. Abre la URL de Vercel en Safari.
2. Espera a que cargue la pantalla principal una vez.
3. Pulsa compartir.
4. Pulsa `Anadir a pantalla de inicio`.
5. Abre GymApp desde el icono instalado.

## Prueba previa al gimnasio

Antes del lunes, haz una prueba corta con conexion:

1. Abre la PWA instalada.
2. Elige el entrenamiento del lunes.
3. Registra una serie.
4. Cierra la app y vuelve a abrirla para comprobar `Reanudar`.
5. Termina el entrenamiento de prueba.
6. Pulsa `Guardar CSV` y usa la hoja de compartir de iOS para guardarlo en Archivos.

La app guarda el borrador en `localStorage` y las series en IndexedDB dentro del iPhone. El service worker cachea la app despues de la primera carga para que la pantalla y el plan sigan disponibles aunque la cobertura del gimnasio sea mala.
