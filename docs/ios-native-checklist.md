# Checklist operativo de la app nativa iOS

Este documento es la lista de trabajo ejecutable de la migración SwiftUI. Complementa el contexto, las decisiones y el historial de `ROADMAP.md`; no los sustituye. Una tarea solo se marca como terminada si tiene criterios de aceptación cubiertos y pasa la validación indicada.

## Convenciones

- Prioridad `P0`: impide probar la app nativa como producto real.
- Prioridad `P1`: necesaria para cerrar la paridad funcional v1.
- Prioridad `P2`: mejora de producto posterior a la paridad v1.
- Coste `XS`: hasta 1 hora; `S`: 1-3 horas; `M`: media jornada; `L`: 1-2 jornadas.
- Cada cambio de comportamiento visible actualiza la versión de la PWA y deja una entrada breve en `ROADMAP.md`.
- La navegación interna usa una transición horizontal estable: avance de derecha a izquierda; vuelta de izquierda a derecha. Las pantallas nuevas reutilizan esta regla salvo que una interacción puntual requiera otra semántica.

## Estado actual

| Área | Estado verificable | Referencia |
| --- | --- | --- |
| Contrato del plan | Completado | `GymAppNativeCore` decodifica el JSON de producción en pruebas. |
| Hoy y previsualización | Completado | Semana completa en tarjetas, con fecha, foco, estimado, bloques y navegación directa a la previsualización. |
| Serie, feedback y descanso | Persistencia activa | Ejecutan, editan objetivos, saltan series, cambian el siguiente bloque al terminar el descanso y recuperan serie, feedback, evaluación y temporizador tras un cierre. |
| Material y cargas | Completado en memoria | Variante por ejercicio, inventario y redondeo cubiertos por tests Swift. |
| Persistencia, historial e import/export | Parcial | El borrador activo y las sesiones terminadas usan SwiftData; CSV por sesión, backup interoperable e importación deduplicada están disponibles. La recuperación del borrador está cubierta en Core para serie normal, superserie y descanso caducado. Falta una vista de detalle histórico nativa. |

## Próximo bloque: sesión persistente

| Estado | Pri. | Coste | Tarea | Criterio de aceptación |
| --- | --- | --- | --- | --- |
| [x] | P0 | M | Definir modelo SwiftData para borrador activo. | Una instantánea versionada conserva localizador de serie, objetivos, material real, feedback, `startedAt` y `endsAt`. Los eventos e historial definitivos permanecen en el bloque P1. |
| [x] | P0 | M | Persistir cada cambio de la sesión activa. | Material, fase, feedback, series registradas y descanso se escriben inmediatamente; un cierre no elimina el borrador. |
| [x] | P0 | S | Restaurar el borrador desde Hoy. | Hoy ofrece reanudar solo cuando existe una instantánea válida; completar la sesión borra el borrador activo. |
| [x] | P0 | S | Añadir pruebas de serialización y restauración del secuenciador. | Cubren una serie normal, una superserie y un descanso recuperado tras caducar. |

## Paridad funcional v1

| Estado | Pri. | Coste | Tarea | Criterio de aceptación |
| --- | --- | --- | --- | --- |
| [~] | P1 | M | Guardar sesiones finalizadas e historial nativo básico. | `Hoy` marca las sesiones terminadas con borde y chip verdes; falta una vista de detalle con series, material y feedback. |
| [x] | P1 | M | Completar exportación CSV por serie y backup JSON desde iOS. | El CSV nativo se comparte desde el cierre y el backup usa `gymapp.full-training-data-export` v1, incluyendo plan, ajustes, borrador resumido y sesiones. |
| [x] | P1 | M | Importar backup JSON completo de la PWA. | Valida schema/version, evita IDs duplicados, preserva la sesión original e informa del resultado. |
| [x] | P1 | S | Temporizadores nativos temporizados y de descanso. | Calculan contra fecha final, se recuperan correctamente al volver a primer plano, mantienen la marcha al ajustar duracion y muestran estado terminado. |
| [x] | P1 | M | Edición táctil de objetivos y evaluación final de ejercicio. | Reps y peso se ajustan en una hoja inferior con los incrementos reales del material, se propagan a series homogéneas y se evalúa cada ejercicio o superserie antes del descanso. |
| [x] | P1 | S | Reordenar el siguiente bloque durante un descanso. | Tras acabar un descanso se puede priorizar un bloque no iniciado; no se crean series saltadas, el bloque originalmente propuesto permanece pendiente y el bloque elegido conserva todas sus series consecutivas. |
| [x] | P1 | S | Pantalla de finalización y duración real. | Muestra duración desde la entrada en la primera serie y compara con el estimado del plan, sin contar movilidad. |
| [x] | P1 | S | Ajustes nativos de apariencia y datos locales. | Tema persistente, pantalla activa, consulta futura, CSV por sesión, backup/importación JSON y borrado confirmado están accesibles. |

## Pulido posterior a v1

| Estado | Pri. | Coste | Tarea | Criterio de aceptación |
| --- | --- | --- | --- | --- |
| [x] | P2 | S | Mostrar discos por lado para barra y multipower. | Respeta inventario y variantes, sin reducir la legibilidad del peso central. |
| [ ] | P2 | S | Sustituir SF Symbols provisionales por Heroicons locales. | Los iconos usados coinciden con los roles de la PWA y respetan accesibilidad. |
| [x] | P2 | M | Sistema de cuatro temas nativos. | Apariencia permite Sistema, Claro u Oscuro; cada familia conserva una variante independiente: White/Light y Dark/Black. Canvas, superficie y realce usan tokens compartidos. |
| [x] | P2 | XS | Integración del canvas con regiones de sistema. | La app requiere iOS 27 y aplica el esquema de contraste oficial a la barra de estado. El canvas base se normaliza a blanco o negro puro por familia para mantener continuidad aunque el sistema conserve sus superficies de borde. |
| [ ] | P2 | M | Notificación local y háptica al acabar descanso. | Funciona con permisos denegados sin bloquear el flujo. |
| [ ] | P2 | M | Aviso de finalización de descanso y serie temporizada. | Programa notificación local al pasar a segundo plano y reproduce sonido corto más háptica al terminar en primer plano. |
| [ ] | P2 | M | Live Activity de descanso. | Se mantiene coherente con el temporizador interno y se limpia al continuar. |
| [ ] | P2 | M | HealthKit, widget y sincronización. | Se evalúan por separado cuando la persistencia local sea estable. |

## Validación obligatoria por iteración

- [ ] `git diff --check` sin errores.
- [ ] `npm run lint` y `npm run build` pasan para conservar la PWA de referencia.
- [ ] `swift test --package-path ios/GymAppNativeCore` pasa.
- [ ] La app compila en el simulador objetivo con `xcodebuild`.
- [ ] Si cambia una pantalla nativa, se revisa en simulador con nombre largo, superserie y tema claro/oscuro cuando aplique.
- [ ] Se actualizan versión, roadmap y este checklist cuando cambia el estado de una tarea.

## Criterio para prueba real en gimnasio

La app nativa solo se marcará como lista para una primera sesión real cuando pase un recorrido completo en dispositivo: elegir sesión, preview, serie normal, superserie, serie temporizada, feedback, descanso, reordenar un bloque, finalizar, exportar CSV y recuperar una sesión activa tras bloquear o cerrar la app. Las notificaciones locales son una mejora P2 y no bloquean esa primera validación, siempre que los temporizadores se recuperen correctamente al volver a primer plano.
