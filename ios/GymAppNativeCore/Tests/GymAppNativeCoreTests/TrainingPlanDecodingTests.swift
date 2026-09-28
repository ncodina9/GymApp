import Foundation
import Testing
@testable import GymAppNativeCore

struct TrainingPlanDecodingTests {
  @Test("Codifica órdenes del Watch con acuse y deduplicación")
  func encodesWatchCommandEnvelope() throws {
    let id = UUID()
    let envelope = WatchWorkoutCommandEnvelope(id: id, command: .registerSet)
    let decodedEnvelope = try JSONDecoder().decode(
      WatchWorkoutCommandEnvelope.self,
      from: JSONEncoder().encode(envelope)
    )
    let acknowledgement = WatchWorkoutCommandAcknowledgement(commandID: id, result: .applied)
    let decodedAcknowledgement = try JSONDecoder().decode(
      WatchWorkoutCommandAcknowledgement.self,
      from: JSONEncoder().encode(acknowledgement)
    )

    #expect(decodedEnvelope.id == id)
    #expect(decodedEnvelope.command == .registerSet)
    #expect(decodedAcknowledgement.commandID == id)
    #expect(decodedAcknowledgement.result == .applied)

    let start = WatchWorkoutCommand.startWarmup(sessionID: "session-1")
    let replacement = WatchWorkoutCommand.replaceActiveWorkout(
      sessionID: "session-2",
      startsWithWarmup: true,
      exerciseIndex: nil
    )
    let edited = WatchWorkoutCommand.updateWorkingSet(reps: 8, weightKg: 42.5)
    let equipment = WatchWorkoutCommand.selectEquipment(.multipower)
    let feedback = WatchWorkoutCommand.submitSetFeedback(WorkoutSetFeedback(
      rir: 1,
      painKnee: 0,
      painWrist: 2,
      painShoulder: 0,
      painLowerBack: 0,
      note: "Molestia"
    ))
    let review = WatchWorkoutCommand.submitExerciseReview(decisions: [
      "press-banca-inclinado": "Subir reps",
      "remo-inclinado-barra": "Mantener"
    ])
    let decodedStart = try JSONDecoder().decode(WatchWorkoutCommand.self, from: JSONEncoder().encode(start))
    let decodedReplacement = try JSONDecoder().decode(WatchWorkoutCommand.self, from: JSONEncoder().encode(replacement))
    let decodedEdit = try JSONDecoder().decode(WatchWorkoutCommand.self, from: JSONEncoder().encode(edited))
    let decodedEquipment = try JSONDecoder().decode(WatchWorkoutCommand.self, from: JSONEncoder().encode(equipment))
    let decodedFeedback = try JSONDecoder().decode(WatchWorkoutCommand.self, from: JSONEncoder().encode(feedback))
    let decodedReview = try JSONDecoder().decode(WatchWorkoutCommand.self, from: JSONEncoder().encode(review))
    #expect(decodedStart == start)
    #expect(decodedReplacement == replacement)
    #expect(decodedEdit == edited)
    #expect(decodedEquipment == equipment)
    #expect(decodedFeedback == feedback)
    #expect(decodedReview == review)

    let state = WatchWorkoutState(
      sessionID: "session-1",
      workoutName: "Torso fuerza",
      exerciseName: "Press banca inclinado",
      equipment: .dumbbell,
      equipmentName: "Mancuernas",
      equipmentOptions: [.barbell, .dumbbell],
      phase: .workingSet,
      completedSetCount: 3,
      totalSetCount: 20,
      exerciseSetNumber: 2,
      exerciseSetTotal: 4,
      reps: 8,
      weightKg: 24,
      durationSeconds: nil,
      restTotalSeconds: 90,
      timerEndsAt: nil
    )
    let decodedState = try JSONDecoder().decode(
      WatchWorkoutState.self,
      from: JSONEncoder().encode(state)
    )
    #expect(decodedState.equipment == .dumbbell)
    #expect(decodedState.equipmentOptions == [.barbell, .dumbbell])
  }

  @Test("Decodifica el plan de producción compartido")
  func decodesProductionPlan() throws {
    let plan = try TrainingPlanLoader.decode(data: Data(contentsOf: sharedPlanURL))

    #expect(plan.planID == "training-plan-2026-q4")
    #expect(plan.durationWeeks == 13)
    #expect(plan.sessions.count == 51)
    #expect(plan.sessions.allSatisfy { !$0.exercises.isEmpty })
    #expect(plan.sessions.allSatisfy { !$0.isCancelled })
  }

  @Test("Valida operaciones de planificación antes de proponer una revisión")
  func validatesPlanningOperations() throws {
    let plan = try TrainingPlanLoader.decode(data: Data(contentsOf: sharedPlanURL))
    let session = try #require(plan.sessions.first)
    let originalExercise = try #require(session.exercises.first)
    let replacement = try #require(
      plan.sessions
        .flatMap(\.exercises)
        .first { $0.exerciseID != originalExercise.exerciseID }
    )
    let referenceDate = try #require(isoDate("2026-01-01"))
    let constraints = PlanningConstraints(
      availableWeekdays: [2],
      availableEquipment: Set(Equipment.allCases),
      maxSessionMinutes: 45,
      referenceDate: referenceDate
    )

    let moved = try PlanningOperationEngine.preview(
      basePlan: plan,
      operations: [.moveSession(sessionID: session.sessionID, toDate: "2027-01-05")],
      constraints: constraints
    )
    #expect(moved.plan.sessions.first?.date == "2027-01-05")
    #expect(moved.warnings.contains(.durationExceedsPreference(
      sessionID: session.sessionID,
      minutes: session.estimatedMinutes,
      maximum: 45
    )))

    let cancelled = try PlanningOperationEngine.preview(
      basePlan: plan,
      operations: [.cancelSession(sessionID: session.sessionID)],
      constraints: constraints
    )
    #expect(cancelled.plan.sessions.first?.isCancelled == true)

    let replaced = try PlanningOperationEngine.preview(
      basePlan: plan,
      operations: [
        .replaceExercise(
          sessionID: session.sessionID,
          exerciseID: originalExercise.exerciseID,
          replacementExerciseID: replacement.exerciseID
        ),
      ],
      constraints: constraints
    )
    #expect(replaced.plan.sessions.first?.exercises.first?.exerciseID == replacement.exerciseID)
    #expect(replaced.plan.sessions.first?.exercises.first?.sets.count == originalExercise.sets.count)

    var completedConstraints = constraints
    completedConstraints.completedSessionIDs = [session.sessionID]
    #expect(throws: PlanningOperationError.self) {
      try PlanningOperationEngine.preview(
        basePlan: plan,
        operations: [.cancelSession(sessionID: session.sessionID)],
        constraints: completedConstraints
      )
    }

    if let pattern = replacement.movementPattern {
      var restrictedConstraints = constraints
      restrictedConstraints.restrictedMovementPatterns = [pattern]
      #expect(throws: PlanningOperationError.self) {
        try PlanningOperationEngine.preview(
          basePlan: plan,
          operations: [.replaceExercise(sessionID: session.sessionID, exerciseID: originalExercise.exerciseID, replacementExerciseID: replacement.exerciseID)],
          constraints: restrictedConstraints
        )
      }
    }
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

  @Test("Unifica variantes y expone materiales alternativos del gimnasio")
  func normalizesExerciseNamesAndEquipmentOptions() throws {
    let plan = try TrainingPlanLoader.decode(data: Data(contentsOf: sharedPlanURL))
    let exercises = plan.sessions.flatMap(\.exercises)
    let hammerCurl = try #require(exercises.first { $0.exerciseID == "curl-martillo" })
    let seatedCalves = try #require(exercises.first { $0.exerciseID == "gemelos-sentado-multipower" })
    let technicalRDL = try #require(exercises.first { $0.exerciseID == "rdl-tecnico" })
    let closeGripPress = try #require(exercises.first { $0.exerciseID == "press-cerrado-multipower" })

    #expect(hammerCurl.displayName == "Curl de bíceps")
    #expect(hammerCurl.displayGroupID == "curl-biceps")
    #expect(seatedCalves.displayName == "Elevación de gemelos")
    #expect(technicalRDL.displayName == "Peso muerto rumano")
    #expect(closeGripPress.displayName == "Press banca")
    #expect(closeGripPress.displayGroupID == "press-banca")
    #expect(closeGripPress.coachingVariationName == "Agarre cerrado")
    #expect(closeGripPress.selectableEquipmentOptions == [.multipower, .dumbbell])
    #expect(technicalRDL.selectableEquipmentOptions == [.barbell, .multipower])
  }

  @Test("Estima las sesiones con la misma regla que la PWA")
  func estimatesSessionDurationUsingSharedRules() throws {
    let plan = try TrainingPlanLoader.decode(data: Data(contentsOf: sharedPlanURL))
    let firstSession = try #require(plan.sessions.first)
    let secondSession = try #require(plan.sessions.dropFirst().first)

    #expect(SessionDurationEstimator.estimate(for: firstSession).totalMinutes == 70)
    #expect(SessionDurationEstimator.estimate(for: secondSession).totalMinutes == 65)
    #expect(SessionDurationEstimator.estimate(for: firstSession).mobilityMinutes == 9)
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

  @Test("Usa el inventario personalizado para cargas y barras")
  func usesCustomLoadInventory() {
    let inventory = EquipmentLoadInventory(
      dumbbellLoadsKg: [8, 14, 18],
      plates: [.init(weightKg: 2.5, count: 4), .init(weightKg: 10, count: 4)],
      cableStepKg: 2.5,
      cableMaximumKg: 50,
      barbellWeightKg: 15,
      multipowerBarWeightKg: 12
    )

    #expect(EquipmentLoadRules.weightForReferenceWeight(30, equipment: .dumbbell, inventory: inventory) == 14)
    #expect(EquipmentLoadRules.availableLoads(for: .cable, inventory: inventory).prefix(3) == [2.5, 5, 7.5])
    #expect(EquipmentLoadRules.plateLayout(totalWeightKg: 35, equipment: .barbell, inventory: inventory)?.barWeightKg == 15)
  }

  @Test("Desglosa los discos de una barra por lado")
  func createsPlateLayoutForBarbell() {
    let layout = EquipmentLoadRules.plateLayout(totalWeightKg: 70, equipment: .barbell)

    #expect(layout?.barWeightKg == 20)
    #expect(layout?.sidePlatesKg == [20, 5])
    #expect(EquipmentLoadRules.plateLayout(totalWeightKg: 70, equipment: .dumbbell) == nil)
  }

  @Test("Proyecta el histórico por ejercicio y material con RM de Epley")
  func projectsExerciseHistoryByMaterial() throws {
    let plan = try TrainingPlanLoader.decode(data: Data(contentsOf: sharedPlanURL))
    let session = try #require(plan.sessions.first)
    let exercise = try #require(session.exercises.first { $0.exerciseID == "press-banca-barra" })
    var execution = WorkoutExecutionState(session: session)

    let locator = try #require(execution.current)
    execution.updateWorkingTargets(for: locator, reps: 5, weightKg: 70)
    _ = execution.recordCurrent(feedback: .ok)

    let entries = ExerciseHistory.entries(
      for: exercise,
      from: [HistoricalWorkoutExecution(completedAt: .now, execution: execution)]
    )

    let entry = try #require(entries.first)
    #expect(entry.equipment == .barbell)
    #expect(entry.weightKg == 70)
    #expect(entry.reps == 5)
    #expect(entry.estimatedOneRepMax == 81.66666666666667)
  }

  @Test("Corrige el resultado de una serie sin alterar las siguientes")
  func correctsRecordedSetWithoutChangingOtherTargets() throws {
    let plan = try TrainingPlanLoader.decode(data: Data(contentsOf: sharedPlanURL))
    let session = try #require(plan.sessions.first)
    let exercise = try #require(session.exercises.first { $0.sets.count > 1 && $0.sets.first?.type != .timed })
    var execution = WorkoutExecutionState(session: session)
    let locator = WorkoutSetLocator(exerciseIndex: 0, setIndex: 1)

    while execution.current != locator { _ = execution.recordCurrent(feedback: .ok) }
    _ = execution.recordCurrent(feedback: .ok)
    let corrected = execution.correctRecordedSet(
      at: locator,
      reps: 9,
      weightKg: 72.5,
      durationSeconds: nil
    )
    #expect(corrected)

    let record = try #require(execution.records.first { $0.locator == locator })
    #expect(execution.targets(for: record)?.reps == 9)
    #expect(execution.targets(for: record)?.weightKg == 72.5)
    #expect(execution.targets(for: WorkoutSetLocator(exerciseIndex: 0, setIndex: 2))?.weightKg == exercise.sets[1].targetWeightKg)
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
      declaredDiscomfortLevels: ["Cadera derecha": 3],
      note: "Técnica"
    )

    _ = state.recordCurrent(feedback: feedback)

    #expect(state.records.count == 1)
    #expect(state.records.first?.feedback == feedback)
    #expect(state.records.first?.feedback.declaredDiscomfortLevels["Cadera derecha"] == 3)
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

  @Test("Permite priorizar un bloque pendiente sin saltar series")
  func prioritizesPendingBlock() throws {
    let plan = try TrainingPlanLoader.decode(data: Data(contentsOf: sharedPlanURL))
    let session = try #require(plan.sessions.first)
    var state = WorkoutExecutionState(session: session)

    let selected = state.selectNextBlock(exerciseIndex: 2)

    #expect(selected)
    #expect(state.current == WorkoutSetLocator(exerciseIndex: 2, setIndex: 1))
    #expect(state.records.isEmpty)

    _ = state.recordCurrent(feedback: .ok)
    #expect(state.current == WorkoutSetLocator(exerciseIndex: 2, setIndex: 2))
  }

  @Test("Mantiene local el ajuste temporal de una serie")
  func keepsTimedDurationAdjustmentLocalToCurrentSet() throws {
    let plan = try TrainingPlanLoader.decode(data: Data(contentsOf: sharedPlanURL))
    let session = try #require(plan.sessions.first(where: {
      $0.exercises.contains(where: { $0.sets.first?.type == .timed && $0.sets.count > 1 })
    }))
    let exerciseIndex = try #require(session.exercises.firstIndex(where: {
      $0.sets.first?.type == .timed && $0.sets.count > 1
    }))
    let exercise = session.exercises[exerciseIndex]
    var state = WorkoutExecutionState(session: session)
    let locator = WorkoutSetLocator(exerciseIndex: exerciseIndex, setIndex: 1)

    while state.current != locator {
      _ = state.recordCurrent(feedback: .ok)
    }
    state.updateTimedDuration(for: locator, durationSeconds: 75)

    #expect(state.targets(for: locator)?.durationSeconds == 75)
    #expect(state.targets(for: WorkoutSetLocator(exerciseIndex: exerciseIndex, setIndex: 2))?.durationSeconds == exercise.sets[1].targetDurationSeconds)
    #expect(exercise.sets.count == 2)
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

  @Test("Restaura una serie normal con su feedback y objetivo editado")
  func restoresNormalSetSnapshot() throws {
    let plan = try TrainingPlanLoader.decode(data: Data(contentsOf: sharedPlanURL))
    let session = try #require(plan.sessions.first)
    var execution = WorkoutExecutionState(session: session)
    let locator = try #require(execution.current)
    execution.updateWorkingTargets(for: locator, reps: 6, weightKg: 67.5)
    let snapshot = ActiveWorkoutSnapshot(
      execution: execution,
      phase: .feedback,
      feedback: ActiveWorkoutFeedbackDraft(rir: 1, painKnee: 0, painWrist: 0, painShoulder: 1, painLowerBack: 0, note: "Técnica"),
      restEndsAt: nil,
      restTotalSeconds: 0,
      setTimerEndsAt: nil,
      setTimerRemaining: 0,
      reviewExerciseIndexes: [],
      reviewRestSeconds: 0,
      exerciseDecisions: [:],
      startedAt: Date(timeIntervalSince1970: 1_789_000_000)
    )

    let restored = try JSONDecoder().decode(ActiveWorkoutSnapshot.self, from: JSONEncoder().encode(snapshot))
    #expect(restored.phase == .feedback)
    #expect(restored.execution.current == locator)
    #expect(restored.execution.targets(for: locator)?.reps == 6)
    #expect(restored.execution.targets(for: locator)?.weightKg == 67.5)
    #expect(restored.feedback.note == "Técnica")
  }

  @Test("Restaura una superserie en el segundo ejercicio de la ronda")
  func restoresSupersetSnapshot() throws {
    let plan = try TrainingPlanLoader.decode(data: Data(contentsOf: sharedPlanURL))
    let session = try #require(plan.sessions.first)
    let firstSuperset = try #require(session.exercises.firstIndex { $0.supersetID != nil })
    var execution = WorkoutExecutionState(session: session)
    while execution.current?.exerciseIndex != firstSuperset { _ = execution.recordCurrent(feedback: .ok) }
    _ = execution.recordCurrent(feedback: .ok)
    let expectedCurrent = WorkoutSetLocator(exerciseIndex: firstSuperset + 1, setIndex: 1)
    let snapshot = ActiveWorkoutSnapshot(
      execution: execution,
      phase: .workingSet,
      feedback: .init(rir: 2, painKnee: 0, painWrist: 0, painShoulder: 0, painLowerBack: 0, note: "OK"),
      restEndsAt: nil,
      restTotalSeconds: 0,
      setTimerEndsAt: nil,
      setTimerRemaining: 0,
      reviewExerciseIndexes: [],
      reviewRestSeconds: 0,
      exerciseDecisions: [:],
      startedAt: .now
    )

    let restored = try JSONDecoder().decode(ActiveWorkoutSnapshot.self, from: JSONEncoder().encode(snapshot))
    #expect(restored.execution.current == expectedCurrent)
    #expect(restored.execution.records.count == execution.records.count)
  }

  @Test("Restaura un descanso caducado sin alterar la siguiente serie")
  func restoresExpiredRestSnapshot() throws {
    let plan = try TrainingPlanLoader.decode(data: Data(contentsOf: sharedPlanURL))
    let session = try #require(plan.sessions.first)
    var execution = WorkoutExecutionState(session: session)
    _ = execution.recordCurrent(feedback: .ok)
    let expectedCurrent = try #require(execution.current)
    let endedAt = Date.now.addingTimeInterval(-15)
    let snapshot = ActiveWorkoutSnapshot(
      execution: execution,
      phase: .rest,
      feedback: .init(rir: 2, painKnee: 0, painWrist: 0, painShoulder: 0, painLowerBack: 0, note: "OK"),
      restEndsAt: endedAt,
      restTotalSeconds: 90,
      setTimerEndsAt: nil,
      setTimerRemaining: 0,
      reviewExerciseIndexes: [],
      reviewRestSeconds: 0,
      exerciseDecisions: [:],
      startedAt: .now
    )

    let restored = try JSONDecoder().decode(ActiveWorkoutSnapshot.self, from: JSONEncoder().encode(snapshot))
    #expect(restored.phase == .rest)
    #expect(restored.restEndsAt?.timeIntervalSinceNow ?? 0 < 0)
    #expect(restored.restTotalSeconds == 90)
    #expect(restored.execution.current == expectedCurrent)
  }

  @Test("Conserva el calentamiento en un borrador recuperable")
  func preservesWarmupStateInActiveWorkout() throws {
    let plan = try TrainingPlanLoader.decode(data: Data(contentsOf: sharedPlanURL))
    let session = try #require(plan.sessions.first)
    let endsAt = Date(timeIntervalSince1970: 1_789_000_000)
    let snapshot = ActiveWorkoutSnapshot(
      execution: WorkoutExecutionState(session: session),
      phase: .workingSet,
      feedback: .init(rir: 2, painKnee: 0, painWrist: 0, painShoulder: 0, painLowerBack: 0, note: "OK"),
      restEndsAt: nil,
      restTotalSeconds: 0,
      setTimerEndsAt: nil,
      setTimerRemaining: 0,
      reviewExerciseIndexes: [],
      reviewRestSeconds: 0,
      exerciseDecisions: [:],
      warmupStatus: .running,
      warmupEndsAt: endsAt,
      warmupRemaining: 420,
      startedAt: Date(timeIntervalSince1970: 1_788_999_500)
    )

    let restored = try JSONDecoder().decode(ActiveWorkoutSnapshot.self, from: JSONEncoder().encode(snapshot))
    #expect(restored.schemaVersion == ActiveWorkoutSnapshot.currentSchemaVersion)
    #expect(restored.warmupStatus == .running)
    #expect(restored.warmupEndsAt == endsAt)
    #expect(restored.warmupRemaining == 420)
  }

  @Test("Finaliza una sesión marcando como omitidas todas las series pendientes")
  func skipsEveryRemainingSetWhenFinishingEarly() throws {
    let plan = try TrainingPlanLoader.decode(data: Data(contentsOf: sharedPlanURL))
    let session = try #require(plan.sessions.first)
    var execution = WorkoutExecutionState(session: session)

    _ = execution.recordCurrent(feedback: .ok)
    let skipped = execution.skipRemaining(performedAt: Date(timeIntervalSince1970: 1_789_000_000))

    #expect(skipped == session.exercises.reduce(0) { $0 + $1.sets.count } - 1)
    #expect(execution.current == nil)
    #expect(execution.records.count == execution.totalSetCount)
    #expect(execution.records.filter { $0.status == .completed }.count == 1)
    #expect(execution.records.dropFirst().allSatisfy { $0.status == .skipped })
  }

  private var sharedPlanURL: URL {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0 ..< 5 {
      url.deleteLastPathComponent()
    }
    return url.appendingPathComponent("data/trainingPlan.json")
  }

  private func isoDate(_ value: String) -> Date? {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: value)
  }
}
