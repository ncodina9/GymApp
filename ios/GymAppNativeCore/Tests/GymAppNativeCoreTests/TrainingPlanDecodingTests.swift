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

  @Test("Desglosa los discos de una barra por lado")
  func createsPlateLayoutForBarbell() {
    let layout = EquipmentLoadRules.plateLayout(totalWeightKg: 70, equipment: .barbell)

    #expect(layout?.barWeightKg == 20)
    #expect(layout?.sidePlatesKg == [20, 5])
    #expect(EquipmentLoadRules.plateLayout(totalWeightKg: 70, equipment: .dumbbell) == nil)
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

  @Test("Alterna superseries y descansa solo al completar la ronda")
  func sequencesSupersetsAndRest() throws {
    let plan = try TrainingPlanLoader.decode(data: Data(contentsOf: sharedPlanURL))
    let session = try #require(plan.sessions.first)
    let firstSupersetIndex = try #require(
      session.exercises.firstIndex { $0.supersetID != nil }
    )
    var state = WorkoutExecutionState(session: session)

    while state.current?.exerciseIndex != firstSupersetIndex {
      _ = state.recordCurrent(feedback: .ok)
    }

    let firstAdvance = state.recordCurrent(feedback: .ok)
    #expect(firstAdvance != nil)
    guard let firstAdvance else { return }
    #expect(firstAdvance.restSeconds == nil)
    #expect(firstAdvance.next?.exerciseIndex == firstSupersetIndex + 1)

    let secondAdvance = state.recordCurrent(feedback: .ok)
    #expect(secondAdvance != nil)
    guard let secondAdvance else { return }
    #expect(secondAdvance.restSeconds != nil)
    #expect(secondAdvance.next?.exerciseIndex == firstSupersetIndex)
    #expect(secondAdvance.next?.setIndex == 2)
  }

  @Test("Conserva el feedback detallado de cada serie")
  func keepsDetailedSetFeedback() throws {
    let plan = try TrainingPlanLoader.decode(data: Data(contentsOf: sharedPlanURL))
    let session = try #require(plan.sessions.first)
    var state = WorkoutExecutionState(session: session)
    let feedback = WorkoutSetFeedback(
      rir: 1,
      painKnee: 0,
      painWrist: 2,
      painShoulder: 1,
      painLowerBack: 0,
      note: "Técnica"
    )

    _ = state.recordCurrent(feedback: feedback)

    #expect(state.records.count == 1)
    #expect(state.records.first?.feedback == feedback)
  }

  @Test("Registra una serie saltada y avanza el flujo")
  func skipsCurrentSetAndAdvances() throws {
    let plan = try TrainingPlanLoader.decode(data: Data(contentsOf: sharedPlanURL))
    let session = try #require(plan.sessions.first)
    var state = WorkoutExecutionState(session: session)

    let advance = state.skipCurrent()

    #expect(state.records.count == 1)
    #expect(state.records.first?.status == .skipped)
    #expect(advance?.next?.setIndex == 2)
  }

  @Test("Solicita la evaluación al terminar un ejercicio")
  func requestsExerciseReviewAfterFinalSet() throws {
    let plan = try TrainingPlanLoader.decode(data: Data(contentsOf: sharedPlanURL))
    let session = try #require(plan.sessions.first)
    let firstExercise = try #require(session.exercises.first)
    var state = WorkoutExecutionState(session: session)
    var advance: WorkoutAdvance?

    for _ in firstExercise.sets {
      advance = state.recordCurrent(feedback: .ok)
    }

    #expect(advance?.reviewExerciseIndexes == [0])
  }

  @Test("Codifica el borrador ejecutable para recuperar una sesión activa")
  func encodesActiveWorkoutState() throws {
    let plan = try TrainingPlanLoader.decode(data: Data(contentsOf: sharedPlanURL))
    let session = try #require(plan.sessions.first)
    let press = try #require(session.exercises.first { $0.exerciseID == "press-banca-barra" })
    var state = WorkoutExecutionState(session: session)

    let selectedMultipower = state.selectEquipment(
      .multipower,
      for: WorkoutSetLocator(exerciseIndex: 0, setIndex: 1)
    )
    #expect(selectedMultipower)
    _ = state.recordCurrent(feedback: WorkoutSetFeedback(
      rir: 1,
      painKnee: 0,
      painWrist: 0,
      painShoulder: 1,
      painLowerBack: 0,
      note: "Técnica"
    ))

    let restored = try JSONDecoder().decode(
      WorkoutExecutionState.self,
      from: JSONEncoder().encode(state)
    )

    #expect(restored.session.sessionID == session.sessionID)
    #expect(restored.records.count == 1)
    #expect(restored.current?.setIndex == 2)
    #expect(restored.draft.equipment(for: press.exerciseID) == .multipower)
    #expect(restored.targets(for: WorkoutSetLocator(exerciseIndex: 0, setIndex: 2))?.weightKg == 65.5)
  }

  private var sharedPlanURL: URL {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0 ..< 5 {
      url.deleteLastPathComponent()
    }
    return url.appendingPathComponent("data/trainingPlan.json")
  }
}
