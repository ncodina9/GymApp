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
| Hoy y previsualización | Completado | Diseño y navegación base trasladados desde la PWA. |
| Serie, feedback y descanso | En memoria | Ejecutan una sesión y respetan superseries; no sobreviven a un cierre. |
| Material y cargas | Completado en memoria | Variante por ejercicio, inventario y redondeo cubiertos por tests Swift. |
| Persistencia, historial e import/export | Pendiente | Requisito de paridad funcional v1. |

## Próximo bloque: sesión persistente

| Estado | Pri. | Coste | Tarea | Criterio de aceptación |
| --- | --- | --- | --- | --- |
| [ ] | P0 | M | Definir modelos SwiftData para borrador activo, eventos de serie y metadatos de sesión. | El esquema conserva localizador de serie, objetivo ejecutado, material real, feedback, `startedAt` y `endsAt`. |
| [ ] | P0 | M | Persistir cada cambio de la sesión activa. | Al forzar el cierre y relanzar, se recuperan serie actual, material, objetivos, feedback pendiente y descanso con su tiempo restante. |
| [ ] | P0 | S | Restaurar o descartar de forma explícita el borrador desde Hoy. | Hoy ofrece reanudar solo cuando existe un borrador válido y no duplica registros. |
| [ ] | P0 | S | Añadir pruebas de serialización y restauración del secuenciador. | Cubren una serie normal, una superserie y un descanso recuperado tras caducar. |

## Paridad funcional v1

| Estado | Pri. | Coste | Tarea | Criterio de aceptación |
| --- | --- | --- | --- | --- |
| [ ] | P1 | M | Guardar sesiones finalizadas e historial nativo básico. | Se puede abrir una sesión terminada y consultar series, material y feedback. |
| [ ] | P1 | M | Exportar CSV por serie y backup JSON desde iOS. | Los archivos cumplen `docs/data-schemas.md` y se pueden guardar en Archivos. |
| [ ] | P1 | M | Importar backup JSON completo de la PWA. | Valida schema/version, evita IDs duplicados e informa del resultado. |
| [ ] | P1 | S | Temporizadores nativos temporizados y de descanso. | Calculan contra fecha final, se recuperan correctamente al volver a primer plano y muestran estado terminado. |
| [ ] | P1 | S | Pantalla de finalización y duración real. | Muestra duración desde la primera serie y compara con el estimado operativo, sin contar movilidad. |
| [ ] | P1 | S | Ajustes nativos de apariencia y datos locales. | Tema persistente, reinicio controlado e importación/exportación accesibles. |

## Pulido posterior a v1

| Estado | Pri. | Coste | Tarea | Criterio de aceptación |
| --- | --- | --- | --- | --- |
| [ ] | P2 | S | Mostrar discos por lado para barra y multipower. | Respeta inventario y variantes, sin reducir la legibilidad del peso central. |
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
