# GymAppNativeCore

Base de dominio Swift para la futura app nativa. No incluye SwiftUI, SwiftData
ni APIs exclusivas de iOS para que pueda verificarse también con `swift test`.

## Alcance actual

- modelos `Codable` para el plan: plan, sesiones, ejercicios, series y material
- enums de material y tipo de serie
- reglas puras de material para convertir cargas entre barra, multipower y mancuernas con el inventario real
- borrador de sesion en memoria que conserva el material por ejercicio y propaga ajustes por series planificadas homogeneas
- secuenciador de series que alterna superseries, registra feedback temporal y aplica descanso solo al cerrar cada ronda
- decodificador del `trainingPlan.json` de producción
- pruebas que consumen el JSON compartido de la raíz del repositorio

## Ejecutar pruebas

```sh
cd ios/GymAppNativeCore
swift test
```

## Incorporación en Xcode

Al crear `ios/GymAppNative`, añadir este paquete local como dependencia. El
target de iOS debe incluir `../../data/trainingPlan.json` como recurso copiado
en el bundle, sin crear una segunda fuente del plan. La app cargará ese recurso
con `Bundle.main.url(forResource: "trainingPlan", withExtension: "json")` y
lo decodificará mediante `TrainingPlanLoader`.

La siguiente ampliación persistirá el borrador y sus registros con SwiftData para
permitir reanudar una sesión tras cerrar la app.
