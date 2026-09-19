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

  private var sharedPlanURL: URL {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0 ..< 5 {
      url.deleteLastPathComponent()
    }
    return url.appendingPathComponent("data/trainingPlan.json")
  }
}
