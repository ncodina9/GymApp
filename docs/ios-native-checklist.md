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
| Persistencia, historial e import/export | Parcial | El borrador activo y las marcas de sesión completada usan SwiftData; el detalle histórico e import/export siguen pendientes. |

## Próximo bloque: sesión persistente

| Estado | Pri. | Coste | Tarea | Criterio de aceptación |
| --- | --- | --- | --- | --- |
| [x] | P0 | M | Definir modelo SwiftData para borrador activo. | Una instantánea versionada conserva localizador de serie, objetivos, material real, feedback, `startedAt` y `endsAt`. Los eventos e historial definitivos permanecen en el bloque P1. |
| [x] | P0 | M | Persistir cada cambio de la sesión activa. | Material, fase, feedback, series registradas y descanso se escriben inmediatamente; un cierre no elimina el borrador. |
| [x] | P0 | S | Restaurar el borrador desde Hoy. | Hoy ofrece reanudar solo cuando existe una instantánea válida; completar la sesión borra el borrador activo. |
| [ ] | P0 | S | Añadir pruebas de serialización y restauración del secuenciador. | Cubren una serie normal, una superserie y un descanso recuperado tras caducar. |

## Paridad funcional v1

| Estado | Pri. | Coste | Tarea | Criterio de aceptación |
| --- | --- | --- | --- | --- |
| [~] | P1 | M | Guardar sesiones finalizadas e historial nativo básico. | `Hoy` marca las sesiones terminadas con borde y chip verdes; falta una vista de detalle con series, material y feedback. |
| [~] | P1 | M | Completar exportación CSV por serie y backup JSON desde iOS. | El CSV nativo se comparte desde el cierre y respeta `gymapp.workout-set-export` v2; falta el backup JSON completo. |
| [ ] | P1 | M | Importar backup JSON completo de la PWA. | Valida schema/version, evita IDs duplicados e informa del resultado. |
| [x] | P1 | S | Temporizadores nativos temporizados y de descanso. | Calculan contra fecha final, se recuperan correctamente al volver a primer plano, mantienen la marcha al ajustar duracion y muestran estado terminado. |
| [x] | P1 | M | Edición táctil de objetivos y evaluación final de ejercicio. | Reps y peso se ajustan en una hoja inferior con los incrementos reales del material, se propagan a series homogéneas y se evalúa cada ejercicio o superserie antes del descanso. |
| [x] | P1 | S | Reordenar el siguiente bloque durante un descanso. | Tras acabar un descanso se puede priorizar un bloque no iniciado; no se crean series saltadas, el bloque originalmente propuesto permanece pendiente y el bloque elegido conserva todas sus series consecutivas. |
| [x] | P1 | S | Pantalla de finalización y duración real. | Muestra duración desde la entrada en la primera serie y compara con el estimado del plan, sin contar movilidad. |
| [ ] | P1 | S | Ajustes nativos de apariencia y datos locales. | Tema persistente, reinicio controlado e importación/exportación accesibles. |

## Pulido posterior a v1

| Estado | Pri. | Coste | Tarea | Criterio de aceptación |
| --- | --- | --- | --- | --- |
| [x] | P2 | S | Mostrar discos por lado para barra y multipower. | Respeta inventario y variantes, sin reducir la legibilidad del peso central. |
| [ ] | P2 | S | Sustituir SF Symbols provisionales por Heroicons locales. | Los iconos usados coinciden con los roles de la PWA y respetan accesibilidad. |
| [ ] | P2 | M | Notificación local y háptica al acabar descanso. | Funciona con permisos denegados sin bloquear el flujo. |
| [ ] | P2 | M | Live Activity de descanso. | Se mantiene coherente con el temporizador interno y se limpia al continuar. |
| [ ] | P2 | M | HealthKit, widget y sincronización. | Se evalúan por separado cuando la persistencia local sea estable. |

## Validación obligatoria por iteración

- [ ] `git diff --check` sin errores.
- [ ] `npm run lint` y `npm run build` pasan para conservar la PWA de referencia.
- [ ] `swift test --package-path ios/GymAppNativeCore` pasa.
- [ ] La app compila en el simulador objetivo con `xcodebuild`.
- [ ] Si cambia una pantalla nativa, se revisa en simulador con nombre largo, superserie y tema claro/oscuro cuando aplique.
- [ ] Se actualizan versión, roadmap y este checklist cuando cambia el estado de una tarea.
