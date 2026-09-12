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

## Forzar actualización de la PWA en iPhone

Usa este flujo cuando Vercel ya haya desplegado una versión nueva, pero la app instalada siga mostrando una versión anterior en `Ajustes`.

1. Abre la PWA instalada desde la pantalla de inicio.
2. Entra en `Ajustes > App sin conexión`.
3. Pulsa `Comprobar caché`.
4. Si aparece una versión pendiente, pulsa `Actualizar ahora`.
5. Cierra la app desde el selector de apps de iOS y vuelve a abrirla.
6. Comprueba en `Ajustes` que el chip de versión coincide con la versión esperada.

Si no aparece la versión nueva:

1. Abre la URL de Vercel en Safari.
2. Recarga la página.
3. Vuelve a abrir la PWA instalada.
4. Entra otra vez en `Ajustes > App sin conexión` y repite `Comprobar caché`.

Último recurso, solo si la app sigue bloqueada en una versión antigua:

1. Exporta primero el backup JSON desde `Ajustes > Datos locales`.
2. Exporta cualquier CSV pendiente desde `Ajustes > Historial`.
3. Elimina la PWA de la pantalla de inicio.
4. En Safari, abre la URL de Vercel y vuelve a usar `Añadir a pantalla de inicio`.

No borres los datos de Safari ni del sitio salvo que tengas backup JSON y CSV exportados. iOS puede eliminar `localStorage` e IndexedDB al borrar datos del sitio.

## Guardar CSV en Archivos

Flujo recomendado al terminar una sesion real:

1. En la pantalla final, pulsa `Guardar CSV`. Si ya saliste de la pantalla final, abre `Ajustes > Historial` y usa `Exportar CSV` en la sesion correspondiente.
2. En la hoja de compartir de iOS, elige `Guardar en Archivos`.
3. Guarda el archivo en la carpeta de iCloud Drive usada para Obsidian:

```text
LifeOS/10. Gym/sesiones/exports
```

4. Conserva el nombre generado por la app: `YYYY-MM-DD-nombre-sesion.csv`.
5. Cuando vuelvas al Mac, ejecuta el importador si quieres consolidar los exports en el CSV maestro:

```sh
npm run import:obsidian-workouts
```

El CSV por serie esta pensado para ser apendable al maestro de Obsidian. Por compatibilidad, no incluye columnas `schema_name` ni `schema_version`; su contrato actual queda documentado como `gymapp.workout-set-export` version `2` en `docs/data-schemas.md`. El backup JSON completo sigue siendo el formato preferente para migracion futura a Swift.
