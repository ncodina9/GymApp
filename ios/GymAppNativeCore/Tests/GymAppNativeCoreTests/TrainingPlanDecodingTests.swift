import Foundation
import Testing
@testable import GymAppNativeCore

struct TrainingPlanDecodingTests {
  @Test("Ajusta el RIR recomendado a la fase de la semana")
  func recommendsRIRByTrainingPhase() {
    #expect(TrainingPhaseCoaching.effort(for: "descarga").defaultRIR == 3)
    #expect(TrainingPhaseCoaching.effort(for: "readaptación").rangeLabel == "3-4")
    #expect(TrainingPhaseCoaching.effort(for: "acumulacion").defaultRIR == 2)
    #expect(TrainingPhaseCoaching.effort(for: "intensificación").defaultRIR == 1)
    #expect(TrainingPhaseCoaching.effort(for: "realización").cue.contains("prescripción"))
  }

  @Test("Acota la compatibilidad a las próximas sesiones relevantes")
  func limitsProfileCompatibilityHorizon() throws {
    let plan = try TrainingPlanLoader.decode(data: Data(contentsOf: sharedPlanURL))
    let constraints = PlanningConstraints(
      availableWeekdays: Set(1 ... 7),
      availableEquipment: Set(Equipment.allCases),
      maxSessionMinutes: 30,
      referenceDate: try #require(isoDate("2026-01-01"))
    )
    let issues = PlanningProfileCompatibility.issues(
      in: plan,
      constraints: constraints,
      maximumUpcomingSessions: 1
    )
    let sessionIDs = Set(issues.map { issue -> String in
      switch issue {
      case let .duration(sessionID, _, _), let .unavailableEquipment(sessionID, _),
           let .restrictedExercise(sessionID, _), let .superset(sessionID),
           let .caution(sessionID, _): sessionID
      }
    })
    #expect(sessionIDs.count == 1)
  }

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
      trainingPhase: "descarga",
      weekFocusLabel: "Descarga técnica",
      equipment: .dumbbell,
      equipmentName: "Mancuernas",
      equipmentOptions: [.barbell, .dumbbell],
      declaredDiscomforts: ["Hombro", "Muñeca"],
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
    #expect(decodedState.trainingPhase == "descarga")
    #expect(decodedState.declaredDiscomforts == ["Hombro", "Muñeca"])

    var legacyPayload = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any]
    )
    legacyPayload.removeValue(forKey: "trainingPhase")
    legacyPayload.removeValue(forKey: "weekFocusLabel")
    legacyPayload.removeValue(forKey: "declaredDiscomforts")
    let legacyState = try JSONDecoder().decode(
      WatchWorkoutState.self,
      from: JSONSerialization.data(withJSONObject: legacyPayload)
    )
    #expect(legacyState.trainingPhase == nil)
    #expect(legacyState.declaredDiscomforts == nil)

    let appState = WatchWorkoutAppState(
      sessions: [],
      completedSessionIDs: [],
      activeWorkout: state,
      theme: WatchWorkoutTheme(appearance: "dark", accent: "blue"),
      currentWeek: 4,
      weekFocusLabel: "Descarga técnica",
      recommendedSessionID: "session-1"
    )
    let decodedAppState = try JSONDecoder().decode(
      WatchWorkoutAppState.self,
      from: JSONEncoder().encode(appState)
    )
    #expect(decodedAppState.currentWeek == 4)
    #expect(decodedAppState.weekFocusLabel == "Descarga técnica")
    #expect(decodedAppState.recommendedSessionID == "session-1")
  }

  @Test("Decodifica el plan de producción compartido")
  func decodesProductionPlan() throws {
    let plan = try TrainingPlanLoader.decode(data: Data(contentsOf: sharedPlanURL))

    #expect(plan.planID == "training-plan-2026-q4")
    #expect(plan.durationWeeks == 13)
    #expect(plan.sessions.count == 51)
    #expect(plan.sessions.allSatisfy { !$0.exercises.isEmpty })
    #expect(plan.sessions.allSatisfy { !$0.isCancelled })
    #expect(plan.sessions.flatMap(\.exercises).flatMap(\.sets).allSatisfy { $0.bodyweightLoad == nil })

    let assisted = BodyweightLoad(assistanceKg: 20)
    let weighted = BodyweightLoad(addedWeightKg: 10)
    #expect(assisted.mode == .assisted)
    #expect(weighted.mode == .weighted)
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
      operations: [.moveSession(sessionID: session.sessionID, toDate: "2027-01-06")],
      constraints: constraints
    )
    #expect(moved.plan.sessions.first?.date == "2027-01-06")
    #expect(moved.plan.sessions.first?.weekday == "Miércoles")
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
    #expect(cancelled.impact.changedSessionIDs == [session.sessionID])
    #expect(cancelled.impact.estimatedMinutesAfter == cancelled.impact.estimatedMinutesBefore - session.estimatedMinutes)

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

  @Test("Valida asistencia y lastre como carga estructurada de peso corporal")
  func validatesBodyweightLoadOperation() throws {
    let plan = try TrainingPlanLoader.decode(data: Data(contentsOf: sharedPlanURL))
    let session = try #require(plan.sessions.first { $0.exercises.contains(where: { $0.equipment == .bodyweight }) })
    let exercise = try #require(session.exercises.first { $0.equipment == .bodyweight })
    let set = try #require(exercise.sets.first)
    let constraints = PlanningConstraints(
      availableWeekdays: Set(1 ... 7),
      availableEquipment: Set(Equipment.allCases),
      maxSessionMinutes: 90,
      referenceDate: try #require(isoDate("2026-01-01"))
    )
    let proposal = try PlanningOperationEngine.preview(
      basePlan: plan,
      operations: [.adjustBodyweightLoad(
        sessionID: session.sessionID,
        exerciseID: exercise.exerciseID,
        setIndex: set.setIndex,
        assistanceKg: 15,
        addedWeightKg: 0
      )],
      constraints: constraints
    )
    let adjusted = try #require(proposal.plan.sessions.first(where: { $0.sessionID == session.sessionID })?.exercises.first(where: { $0.exerciseID == exercise.exerciseID })?.sets.first(where: { $0.setIndex == set.setIndex }))
    #expect(adjusted.bodyweightLoad?.mode == .assisted)
    #expect(throws: PlanningOperationError.invalidBodyweightLoad) {
      try PlanningOperationEngine.preview(
        basePlan: plan,
        operations: [.adjustBodyweightLoad(
          sessionID: session.sessionID,
          exerciseID: exercise.exerciseID,
          setIndex: set.setIndex,
          assistanceKg: 10,
          addedWeightKg: 5
        )],
        constraints: constraints
      )
    }
  }

  @Test("Advierte progresiones de carga agresivas antes de aceptar una revisión")
  func warnsAboutAggressiveSetProgression() throws {
    let plan = try TrainingPlanLoader.decode(data: Data(contentsOf: sharedPlanURL))
    let session = try #require(plan.sessions.first)
    let exercise = try #require(session.exercises.first { $0.sets.first?.targetWeightKg ?? 0 > 0 })
    let trainingSet = try #require(exercise.sets.first)
    let constraints = PlanningConstraints(
      availableWeekdays: Set(1 ... 7),
      availableEquipment: Set(Equipment.allCases),
      maxSessionMinutes: 90,
      referenceDate: try #require(isoDate("2026-01-01"))
    )
    let proposedWeight = trainingSet.targetWeightKg * 1.15

    let proposal = try PlanningOperationEngine.preview(
      basePlan: plan,
      operations: [.adjustSet(
        sessionID: session.sessionID,
        exerciseID: exercise.exerciseID,
        setIndex: trainingSet.setIndex,
        reps: nil,
        weightKg: proposedWeight,
        durationSeconds: nil,
        restSeconds: nil
      )],
      constraints: constraints
    )

    #expect(proposal.warnings.contains(.aggressiveSetProgression(
      sessionID: session.sessionID,
      exerciseID: exercise.exerciseID,
      setIndex: trainingSet.setIndex,
      before: trainingSet.targetWeightKg,
      after: proposedWeight
    )))
  }

  @Test("Advierte al reducir un grupo prioritario del perfil")
  func warnsWhenReducingPriorityVolume() throws {
    let plan = try TrainingPlanLoader.decode(data: Data(contentsOf: sharedPlanURL))
    let session = try #require(plan.sessions.first { $0.exercises.count > 1 })
    let exercise = try #require(session.exercises.first { !$0.primaryMuscles.isEmpty })
    let priority = try #require(exercise.primaryMuscles.first)
    let constraints = PlanningConstraints(
      availableWeekdays: Set(1 ... 7),
      availableEquipment: Set(Equipment.allCases),
      maxSessionMinutes: 90,
      priorityMuscleGroups: [priority.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es_ES"))],
      referenceDate: try #require(isoDate("2026-01-01"))
    )

    let proposal = try PlanningOperationEngine.preview(
      basePlan: plan,
      operations: [.removeExercise(sessionID: session.sessionID, exerciseID: exercise.exerciseID)],
      constraints: constraints
    )

    #expect(proposal.warnings.contains { warning in
      if case .priorityVolumeReduced = warning { return true }
      return false
    })
  }

  @Test("Traduce intenciones estructuradas sin modificar el plan")
  func resolvesPlanningIntents() throws {
    let intent = PlanningIntent.adjustSet(
      sessionID: "session-1",
      exerciseID: "press-banca-barra",
      setIndex: 2,
      reps: 6,
      weightKg: 72.5,
      durationSeconds: nil,
      restSeconds: 150
    )

    let restored = try JSONDecoder().decode(PlanningIntent.self, from: JSONEncoder().encode(intent))
    #expect(restored == intent)
    #expect(PlanningIntentResolver.resolve(intent) == .operations([
      .adjustSet(
        sessionID: "session-1",
        exerciseID: "press-banca-barra",
        setIndex: 2,
        reps: 6,
        weightKg: 72.5,
        durationSeconds: nil,
        restSeconds: 150
      ),
    ]))
    #expect(PlanningIntentResolver.resolve(.adaptSessionDuration(sessionID: "session-1", maximumMinutes: 10)) == .requiresPlanningStrategy(sessionID: "session-1", maximumMinutes: 15))

    let bodyweightIntent = PlanningIntent.adjustBodyweightLoad(
      sessionID: "session-1",
      exerciseID: "dominadas",
      setIndex: 1,
      assistanceKg: 10,
      addedWeightKg: 0
    )
    #expect(try JSONDecoder().decode(PlanningIntent.self, from: JSONEncoder().encode(bodyweightIntent)) == bodyweightIntent)
    #expect(PlanningIntentResolver.resolve(bodyweightIntent) == .operations([
      .adjustBodyweightLoad(sessionID: "session-1", exerciseID: "dominadas", setIndex: 1, assistanceKg: 10, addedWeightKg: 0),
    ]))
  }

  @Test("Conserva una solicitud de ajuste parcialmente resuelta")
  func encodesCoachSetAdjustmentRequest() throws {
    let request = CoachSetAdjustmentRequest(
      kind: .weight,
      direction: .decrease,
      targetValue: 62.5,
      scope: .matchingSets
    )
    let restored = try JSONDecoder().decode(
      CoachSetAdjustmentRequest.self,
      from: JSONEncoder().encode(request)
    )
    #expect(restored == request)
  }

  @Test("Bloquea propuestas que sustituyen y ajustan el mismo ejercicio")
  func detectsConflictingCoachOperations() throws {
    let plan = try TrainingPlanLoader.decode(data: Data(contentsOf: sharedPlanURL))
    let session = try #require(plan.sessions.first)
    let exercise = try #require(session.exercises.first)
    let set = try #require(exercise.sets.first)
    let issues = CoachRequestCoherence.issues(in: plan, operations: [
      .replaceExercise(sessionID: session.sessionID, exerciseID: exercise.exerciseID, replacementExerciseID: exercise.exerciseID),
      .adjustSet(sessionID: session.sessionID, exerciseID: exercise.exerciseID, setIndex: set.setIndex, reps: set.targetReps, weightKg: nil, durationSeconds: nil, restSeconds: nil),
    ])
    #expect(issues.contains { $0.severity == .blocking && $0.message.contains("sustituir y ajustar") })
  }

  @Test("Conserva una aclaración compuesta de Entrenador")
  func encodesCoachConversationDraft() throws {
    let draft = CoachConversationDraft(
      request: .init(userText: "Sustituye dominadas y baja el peso", referencedSessionID: "session-1"),
      activeTask: .setAdjustment(.init(kind: .weight, direction: .decrease)),
      queuedTasks: [
        .replacement,
        .moveSession(toDate: "2026-10-03"),
        .adaptDuration(maximumMinutes: 45),
      ],
      stagedOperations: [.adjustSet(sessionID: "session-1", exerciseID: "remo", setIndex: 1, reps: nil, weightKg: 55, durationSeconds: nil, restSeconds: nil)],
      stagedSummaries: ["Bajar peso de remo"]
    )
    let restored = try JSONDecoder().decode(CoachConversationDraft.self, from: JSONEncoder().encode(draft))
    #expect(restored == draft)
  }

  @Test("Interpreta solicitudes conversacionales locales sin tocar el plan")
  func interpretsLocalPlanningRequests() async throws {
    let interpreter = LocalPlanningIntentInterpreter()
    let sessionID = "session-1"

    let moved = try await interpreter.interpret(.init(
      userText: "Mueve esta sesión al 2026-10-03",
      referencedSessionID: sessionID
    ))
    #expect(moved == [.moveSession(sessionID: sessionID, toDate: "2026-10-03")])

    let shortened = try await interpreter.interpret(.init(
      userText: "Hoy solo tengo 45 minutos",
      referencedSessionID: sessionID
    ))
    #expect(shortened == [.adaptSessionDuration(sessionID: sessionID, maximumMinutes: 45)])

    let cancelled = try await interpreter.interpret(.init(
      userText: "No podré entrenar esta sesión",
      referencedSessionID: sessionID
    ))
    #expect(cancelled == [.cancelSession(sessionID: sessionID)])

    let movedToThursday = try await interpreter.interpret(.init(
      userText: "Muévela al jueves",
      referencedSessionID: sessionID,
      createdAt: try #require(isoDate("2026-09-28"))
    ))
    #expect(movedToThursday == [.moveSession(sessionID: sessionID, toDate: "2026-10-01")])

    let rescheduled = try await interpreter.interpret(.init(
      userText: "Replanifica esta sesión a otro día",
      referencedSessionID: sessionID
    ))
    #expect(rescheduled == [.cancelSession(sessionID: sessionID)])

    let vacation = try await interpreter.interpret(.init(
      userText: "Estaré de vacaciones la semana que viene",
      createdAt: try #require(isoDate("2026-09-28"))
    ))
    #expect(vacation == [.postponeFutureSessions(fromDate: "2026-10-05", byDays: 7)])

    let datedVacation = try await interpreter.interpret(.init(
      userText: "Estaré de vacaciones del 12 al 19 de octubre",
      createdAt: try #require(isoDate("2026-09-28"))
    ))
    #expect(datedVacation == [.postponeFutureSessions(fromDate: "2026-10-12", byDays: 7)])

    let isoDatedVacation = try await interpreter.interpret(.init(
      userText: "Vacaciones del 2026-11-02 al 2026-11-16",
      createdAt: try #require(isoDate("2026-09-28"))
    ))
    #expect(isoDatedVacation == [.postponeFutureSessions(fromDate: "2026-11-02", byDays: 14)])

    let crossMonthVacation = try await interpreter.interpret(.init(
      userText: "Estaré de vacaciones del 28 de noviembre al 6 de diciembre",
      createdAt: try #require(isoDate("2026-09-28"))
    ))
    #expect(crossMonthVacation == [.postponeFutureSessions(fromDate: "2026-11-28", byDays: 8)])

    let holiday = try await interpreter.interpret(.init(
      userText: "El 12 de octubre es festivo y el gym no abre",
      createdAt: try #require(isoDate("2026-09-28"))
    ))
    #expect(holiday == [.gymClosure(date: "2026-10-12")])
    #expect(PlanningIntentResolver.resolve(.gymClosure(date: "2026-10-12")) == .operations([
      .shiftFutureSessions(fromDate: "2026-10-12", byDays: 1),
    ]))
  }

  @Test("Retrasa el macrociclo sin alterar sesiones protegidas")
  func postponesFutureSessionsForAbsence() throws {
    let plan = try TrainingPlanLoader.decode(data: Data(contentsOf: sharedPlanURL))
    let constraints = PlanningConstraints(
      availableWeekdays: Set(1 ... 7),
      availableEquipment: Set(Equipment.allCases),
      maxSessionMinutes: 90,
      referenceDate: try #require(isoDate("2026-09-28"))
    )
    let proposal = try PlanningOperationEngine.preview(
      basePlan: plan,
      operations: [.shiftFutureSessions(fromDate: "2026-10-05", byDays: 7)],
      constraints: constraints
    )
    let original = try #require(plan.sessions.first { $0.date == "2026-10-05" })
    let shifted = try #require(proposal.plan.sessions.first { $0.sessionID == original.sessionID })
    #expect(shifted.date == "2026-10-12")
    #expect(proposal.impact.changedSessionIDs.contains(original.sessionID))
    #expect(proposal.impact.scheduleEndBefore != proposal.impact.scheduleEndAfter)
    #expect(!proposal.impact.shiftedMacrocycleWeeks.isEmpty)
  }

  @Test("Permite recuperar una sesión pendiente de una fecha pasada")
  func movesMissedSessionToFutureDate() throws {
    let plan = try TrainingPlanLoader.decode(data: Data(contentsOf: sharedPlanURL))
    let missed = try #require(plan.sessions.first { $0.date == "2026-09-07" })
    let constraints = PlanningConstraints(
      availableWeekdays: Set(1 ... 7),
      availableEquipment: Set(Equipment.allCases),
      maxSessionMinutes: 90,
      referenceDate: try #require(isoDate("2026-09-28"))
    )
    let proposal = try PlanningOperationEngine.preview(
      basePlan: plan,
      operations: [.moveSession(sessionID: missed.sessionID, toDate: "2026-10-03")],
      constraints: constraints
    )
    #expect(proposal.plan.sessions.first(where: { $0.sessionID == missed.sessionID })?.date == "2026-10-03")
  }

  @Test("Compone ausencias sucesivas sobre el plan efectivo")
  func composesSequentialScheduleChanges() throws {
    let plan = try TrainingPlanLoader.decode(data: Data(contentsOf: sharedPlanURL))
    let constraints = PlanningConstraints(
      availableWeekdays: Set(1 ... 7),
      availableEquipment: Set(Equipment.allCases),
      maxSessionMinutes: 90,
      referenceDate: try #require(isoDate("2026-09-28"))
    )
    let vacation = try PlanningOperationEngine.preview(
      basePlan: plan,
      operations: [.shiftFutureSessions(fromDate: "2026-10-05", byDays: 7)],
      constraints: constraints
    )
    let holiday = try PlanningOperationEngine.preview(
      basePlan: vacation.plan,
      operations: [.shiftFutureSessions(fromDate: "2026-10-12", byDays: 1)],
      constraints: constraints
    )
    let original = try #require(plan.sessions.first { $0.date == "2026-10-05" })
    let finalSession = try #require(holiday.plan.sessions.first { $0.sessionID == original.sessionID })
    #expect(finalSession.date == "2026-10-13")
    #expect(holiday.impact.scheduleEndAfter != vacation.impact.scheduleEndAfter)
  }

  @Test("Codifica el contexto remoto mínimo sin histórico ni series")
  func encodesMinimalRemotePlanningContext() throws {
    let input = RemotePlanningInterpretationInput(
      request: .init(userText: "Quiero mover esta sesión", referencedSessionID: "session-1"),
      profile: .init(
        goal: "fuerza",
        experience: "intermedio",
        weeklyTrainingDays: 3,
        maximumSessionMinutes: 60,
        availableEquipment: ["dumbbell", "barbell"]
      ),
      session: .init(
        sessionID: "session-1",
        date: "2026-10-03",
        label: "Torso",
        estimatedMinutes: 60,
        exerciseFamilies: ["Dominadas", "Press banca"]
      )
    )

    let restored = try JSONDecoder().decode(
      RemotePlanningInterpretationInput.self,
      from: JSONEncoder().encode(input)
    )
    #expect(restored == input)
    #expect(restored.session.exerciseFamilies == ["Dominadas", "Press banca"])
    #expect(restored.profile.availableEquipment == ["barbell", "dumbbell"])
  }

  @Test("Propone acortar una sesión sin modificar el plan base")
  func proposesSafeSessionDurationAdaptations() throws {
    let plan = try TrainingPlanLoader.decode(data: Data(contentsOf: sharedPlanURL))
    let session = try #require(plan.sessions.first)
    let originalMinutes = SessionDurationEstimator.estimate(for: session).totalMinutes
    let constraints = PlanningConstraints(
      availableWeekdays: Set(1 ... 7),
      availableEquipment: Set(Equipment.allCases),
      maxSessionMinutes: 45,
      referenceDate: try #require(isoDate("2026-01-01"))
    )

    let options = try SessionDurationAdaptationPlanner.options(
      basePlan: plan,
      sessionID: session.sessionID,
      maximumMinutes: 45,
      constraints: constraints
    )

    #expect(!options.isEmpty)
    #expect(options.allSatisfy { $0.estimatedMinutes < originalMinutes })
    #expect(SessionDurationEstimator.estimate(for: plan.sessions[0]).totalMinutes == originalMinutes)
    let protectedExerciseIDs = Set(session.exercises.compactMap { exercise in
      let type = exercise.type.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
      return type == "basico" || type == "basico tecnico" ? exercise.exerciseID : nil
    })

    for option in options {
      let preview = try PlanningOperationEngine.preview(
        basePlan: plan,
        operations: option.operations,
        constraints: constraints
      )
      let adaptedSession = try #require(preview.plan.sessions.first { $0.sessionID == session.sessionID })
      #expect(SessionDurationEstimator.estimate(for: adaptedSession).totalMinutes == option.estimatedMinutes)
      #expect(option.operations.allSatisfy { operation in
        if case let .removeExercise(_, exerciseID) = operation {
          return !protectedExerciseIDs.contains(exerciseID)
        }
        return true
      })
    }
  }

  @Test("Propone fechas disponibles al reprogramar una sesión")
  func proposesAvailableReschedulingDates() throws {
    let plan = try TrainingPlanLoader.decode(data: Data(contentsOf: sharedPlanURL))
    let session = try #require(plan.sessions.first { $0.date >= "2026-09-28" })
    let constraints = PlanningConstraints(
      availableWeekdays: [1],
      availableEquipment: Set(Equipment.allCases),
      maxSessionMinutes: 90,
      referenceDate: try #require(isoDate("2026-09-28"))
    )

    let options = try SessionReschedulingPlanner.options(
      basePlan: plan,
      sessionID: session.sessionID,
      constraints: constraints
    )

    #expect(!options.isEmpty)
    #expect(options.allSatisfy { $0.date != session.date })
    #expect(options.allSatisfy { option in
      guard let date = isoDate(option.date) else { return false }
      let weekday = Calendar.current.component(.weekday, from: date)
      return [1].contains(weekday)
    })

    let fallbackConstraints = PlanningConstraints(
      availableWeekdays: [],
      availableEquipment: Set(Equipment.allCases),
      maxSessionMinutes: 90,
      referenceDate: try #require(isoDate("2026-09-28"))
    )
    let fallbackOptions = try SessionReschedulingPlanner.options(
      basePlan: plan,
      sessionID: session.sessionID,
      constraints: fallbackConstraints
    )
    #expect(!fallbackOptions.isEmpty)
    #expect(fallbackOptions.allSatisfy { $0.isOutsideAvailability })
    #expect(fallbackOptions.contains { $0.shiftsOtherSessions })
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

    let canonicalExercises = TrainingExerciseCatalog.canonicalExercises(in: plan.sessions)
    #expect(canonicalExercises.filter { $0.displayName == "Curl de bíceps" }.count == 1)
    #expect(canonicalExercises.filter { $0.displayName == "Dominadas" }.count == 1)
    #expect(canonicalExercises.filter { $0.displayName == "Elevación de gemelos" }.count == 1)
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
