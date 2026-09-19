import Foundation
import Testing
@testable import GymAppNativeCore

struct TrainingPlanDecodingTests {
  @Test("Decodifica el plan de producción compartido")
  func decodesProductionPlan() throws {
    let plan = try TrainingPlanLoader.decode(data: Data(contentsOf: sharedPlanURL))

    #expect(plan.planID == "training-plan-2026-q4")
    #expect(plan.durationWeeks == 13)
    #expect(plan.sessions.count == 51)
    #expect(plan.sessions.allSatisfy { !$0.exercises.isEmpty })
  }

  @Test("Conserva superseries, temporizados y material")
  func preservesTrainingFlowData() throws {
    let plan = try TrainingPlanLoader.decode(data: Data(contentsOf: sharedPlanURL))
    let firstSession = try #require(plan.sessions.first)
    let lateralRaises = try #require(
      firstSession.exercises.first { $0.exerciseID == "elevaciones-laterales" },
    )
    let timedExercise = try #require(
      plan.sessions
        .flatMap(\.exercises)
        .first { exercise in exercise.sets.contains { $0.type == .timed } },
    )

    #expect(lateralRaises.equipment == .dumbbell)
    #expect(lateralRaises.supersetID != nil)
    #expect(timedExercise.sets.allSatisfy { $0.targetDurationSeconds == 60 })
  }

  @Test("Convierte cargas entre variantes con el material disponible")
  func convertsLoadsForEquipment() {
    #expect(
      EquipmentLoadRules.weightForReferenceWeight(70, equipment: .multipower) == 70.5,
    )
    #expect(
      EquipmentLoadRules.weightForReferenceWeight(60, equipment: .dumbbell) == 30,
    )
    #expect(
      EquipmentLoadRules.referenceWeightKg(20, equipment: .dumbbell) == 40,
    )
    #expect(EquipmentLoadRules.canUse(equipment: .dumbbell, referenceWeightKg: 60))
    #expect(!EquipmentLoadRules.canUse(equipment: .dumbbell, referenceWeightKg: 65))
  }

  @Test("Conserva material y propaga objetivos homogéneos en una sesión")
  func keepsSessionMaterialAndTargets() throws {
    let plan = try TrainingPlanLoader.decode(data: Data(contentsOf: sharedPlanURL))
    let session = try #require(plan.sessions.first)
    let exercise = try #require(
      session.exercises.first { $0.exerciseID == "press-banca-barra" }
    )
    var draft = WorkoutSessionDraft(session: session)

    let selectedMultipower = draft.selectEquipment(.multipower, for: exercise.exerciseID)
    #expect(selectedMultipower)
    #expect(draft.equipment(for: exercise.exerciseID) == .multipower)
    #expect(draft.targets(for: exercise.exerciseID, setIndex: 1)?.weightKg == 65.5)
    let selectedDumbbells = draft.selectEquipment(.dumbbell, for: exercise.exerciseID)
    #expect(!selectedDumbbells)

    draft.updateWorkingTargets(
      for: exercise.exerciseID,
      setIndex: 1,
      reps: 6,
      weightKg: 67.5
    )

    #expect(draft.targets(for: exercise.exerciseID, setIndex: 1)?.reps == 6)
    #expect(draft.targets(for: exercise.exerciseID, setIndex: 2)?.reps == 6)
    #expect(draft.targets(for: exercise.exerciseID, setIndex: 2)?.weightKg == 68)
  }

  private var sharedPlanURL: URL {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0 ..< 5 {
      url.deleteLastPathComponent()
    }
    return url.appendingPathComponent("data/trainingPlan.json")
  }
}
