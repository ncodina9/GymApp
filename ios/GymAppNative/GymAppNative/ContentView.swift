import SwiftUI
import GymAppNativeCore

struct ContentView: View {
  @State private var plan: TrainingPlan?
  @State private var loadingError: String?

  var body: some View {
    Group {
      if let plan {
        TodayView(plan: plan)
      } else if let loadingError {
        ContentUnavailableView(
          "No se pudo cargar el plan",
          systemImage: "exclamationmark.triangle",
          description: Text(loadingError)
        )
      } else {
        ProgressView("Cargando entrenamiento")
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(GymCanvas().ignoresSafeArea())
    .task { loadPlan() }
  }

  private func loadPlan() {
    guard let planURL = Bundle.main.url(
      forResource: "trainingPlan",
      withExtension: "json"
    ) else {
      loadingError = "El plan de entrenamiento no está incluido en la app."
      return
    }

    do {
      plan = try TrainingPlanLoader.decode(data: Data(contentsOf: planURL))
    } catch {
      loadingError = error.localizedDescription
    }
  }
}
