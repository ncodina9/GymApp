import SwiftUI
import SwiftData
import GymAppNativeCore

struct ContentView: View {
  @State private var plan: TrainingPlan?
  @State private var loadingError: String?
  @Query private var trainingProfiles: [TrainingProfileRecord]
  @Query private var planRevisionRecords: [PlanRevisionRecord]
  @Query private var generatedPlanRecords: [GeneratedMacrocycleRecord]
  @AppStorage("trainingProfileOnboardingDeferred") private var onboardingDeferred = false

  var body: some View {
    Group {
      if TrainingProfileStore.load(from: trainingProfiles) == nil, !onboardingDeferred {
        TrainingProfileOnboardingView(onDefer: { onboardingDeferred = true })
      } else if let plan = activePlan {
        TodayView(plan: PlanRevisionStore.resolvedPlan(basePlan: plan, records: planRevisionRecords))
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

  private var activePlan: TrainingPlan? {
    ActiveTrainingPlanStore.load(from: generatedPlanRecords) ?? plan
  }
}
