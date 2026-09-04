# Prueba en iPhone real

Objetivo: ejecutar GymApp desde el iPhone en la misma red local que el Mac y revisar el flujo tactil antes de convertirla en PWA instalable.

## Arrancar desde el Mac

1. Conecta el Mac y el iPhone a la misma Wi-Fi.
2. En el Mac, desde el proyecto:

```sh
npm run dev:host
```

3. En otra terminal, consulta la IP local del Mac:

```sh
ipconfig getifaddr en0
```

Si no devuelve nada, prueba:

```sh
ipconfig getifaddr en1
```

4. En Safari del iPhone abre:

```text
http://IP_DEL_MAC:3000/
```

Ejemplo:

```text
http://192.168.1.42:3000/
```

## Si no carga

- Comprueba que Mac y iPhone estan en la misma red Wi-Fi.
- Confirma con `lsof -nP -iTCP:3000 -sTCP:LISTEN` que Node escucha en `*:3000` o en `0.0.0.0:3000`.
- Prueba a abrir `http://IP_DEL_MAC:3000/` desde otro navegador del Mac.
- Si macOS pregunta por conexiones entrantes para Node, aceptalas.
- Si el puerto 3000 esta ocupado, arranca otro puerto:

```sh
npm run dev:host -- --port 3001
```

Y abre:

```text
http://IP_DEL_MAC:3001/
```

## Checklist de prueba

- Inicio: se muestra el entrenamiento del dia y permite elegir los entrenamientos de la semana.
- Reanudar: al empezar una sesion, volver al inicio muestra `Reanudar`.
- Serie normal: reps y peso son legibles de un vistazo y los botones tactiles no provocan errores.
- Incremento de peso: el toggle central alterna entre `1` y `0.5`.
- Feedback: aparece como pantalla propia despues de `Continuar` y no necesita scroll.
- Descanso: aparece el contador circular y los botones `-15s`, `+15s`, `Seguir`.
- Serie temporizada: `Plancha o dead bug` muestra cuenta atras circular, `Iniciar`, `Pausar` y reinicio.
- Saltar serie: el boton existe, es secundario y no domina la pantalla.
- Persistencia: cerrar Safari y volver a abrir mantiene la sesion en curso.
- Exportacion CSV: al finalizar, `Guardar CSV` permite compartir/guardar el archivo desde iOS.

## Limitaciones esperadas en esta fase

- La app se abre como web local, no como PWA instalada.
- La URL `http://IP_DEL_MAC:3000/` solo funciona mientras el Mac mantiene el servidor arrancado.
- Algunas capacidades de PWA o guardado avanzado pueden requerir HTTPS; se validaran en el hito de PWA.

## Resultado de la prueba

Registrar durante la prueba:

- Modelo de iPhone y version de iOS.
- Si hay scroll en alguna pantalla.
- Si algun boton queda demasiado cerca del borde o cuesta pulsarlo.
- Si Safari oculta o tapa elementos con sus barras.
- Si el CSV puede guardarse en Archivos.
- Cualquier pantalla donde el flujo obligue a pensar demasiado.
