import Foundation

public enum PlanningOperation: Codable, Equatable, Sendable {
  case moveSession(sessionID: String, toDate: String)
  case shiftFutureSessions(fromDate: String, byDays: Int)
  case cancelSession(sessionID: String)
  case replaceExercise(sessionID: String, exerciseID: String, replacementExerciseID: String)
  case addExercise(sessionID: String, sourceExerciseID: String)
  case removeExercise(sessionID: String, exerciseID: String)
  case adjustSet(sessionID: String, exerciseID: String, setIndex: Int, reps: Int?, weightKg: Double?, durationSeconds: Int?, restSeconds: Int?)
  case adjustBodyweightLoad(sessionID: String, exerciseID: String, setIndex: Int, assistanceKg: Double, addedWeightKg: Double)

  private enum CodingKeys: String, CodingKey {
    case type
    case sessionID
    case toDate
    case fromDate, byDays
    case exerciseID
    case replacementExerciseID
    case sourceExerciseID, setIndex, reps, weightKg, durationSeconds, restSeconds, assistanceKg, addedWeightKg
  }

  private enum Kind: String, Codable {
    case moveSession, shiftFutureSessions
    case cancelSession
    case replaceExercise
    case addExercise, removeExercise, adjustSet, adjustBodyweightLoad
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    switch try container.decode(Kind.self, forKey: .type) {
    case .moveSession:
      self = .moveSession(
        sessionID: try container.decode(String.self, forKey: .sessionID),
        toDate: try container.decode(String.self, forKey: .toDate)
      )
    case .shiftFutureSessions:
      self = .shiftFutureSessions(
        fromDate: try container.decode(String.self, forKey: .fromDate),
        byDays: try container.decode(Int.self, forKey: .byDays)
      )
    case .cancelSession:
      self = .cancelSession(sessionID: try container.decode(String.self, forKey: .sessionID))
    case .replaceExercise:
      self = .replaceExercise(
        sessionID: try container.decode(String.self, forKey: .sessionID),
        exerciseID: try container.decode(String.self, forKey: .exerciseID),
        replacementExerciseID: try container.decode(String.self, forKey: .replacementExerciseID)
      )
    case .addExercise:
      self = .addExercise(sessionID: try container.decode(String.self, forKey: .sessionID), sourceExerciseID: try container.decode(String.self, forKey: .sourceExerciseID))
    case .removeExercise:
      self = .removeExercise(sessionID: try container.decode(String.self, forKey: .sessionID), exerciseID: try container.decode(String.self, forKey: .exerciseID))
    case .adjustSet:
      self = .adjustSet(sessionID: try container.decode(String.self, forKey: .sessionID), exerciseID: try container.decode(String.self, forKey: .exerciseID), setIndex: try container.decode(Int.self, forKey: .setIndex), reps: try container.decodeIfPresent(Int.self, forKey: .reps), weightKg: try container.decodeIfPresent(Double.self, forKey: .weightKg), durationSeconds: try container.decodeIfPresent(Int.self, forKey: .durationSeconds), restSeconds: try container.decodeIfPresent(Int.self, forKey: .restSeconds))
    case .adjustBodyweightLoad:
      self = .adjustBodyweightLoad(sessionID: try container.decode(String.self, forKey: .sessionID), exerciseID: try container.decode(String.self, forKey: .exerciseID), setIndex: try container.decode(Int.self, forKey: .setIndex), assistanceKg: try container.decode(Double.self, forKey: .assistanceKg), addedWeightKg: try container.decode(Double.self, forKey: .addedWeightKg))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case let .moveSession(sessionID, toDate):
      try container.encode(Kind.moveSession, forKey: .type)
      try container.encode(sessionID, forKey: .sessionID)
      try container.encode(toDate, forKey: .toDate)
    case let .shiftFutureSessions(fromDate, byDays):
      try container.encode(Kind.shiftFutureSessions, forKey: .type)
      try container.encode(fromDate, forKey: .fromDate)
      try container.encode(byDays, forKey: .byDays)
    case let .cancelSession(sessionID):
      try container.encode(Kind.cancelSession, forKey: .type)
      try container.encode(sessionID, forKey: .sessionID)
    case let .replaceExercise(sessionID, exerciseID, replacementExerciseID):
      try container.encode(Kind.replaceExercise, forKey: .type)
      try container.encode(sessionID, forKey: .sessionID)
      try container.encode(exerciseID, forKey: .exerciseID)
      try container.encode(replacementExerciseID, forKey: .replacementExerciseID)
    case let .addExercise(sessionID, sourceExerciseID):
      try container.encode(Kind.addExercise, forKey: .type); try container.encode(sessionID, forKey: .sessionID); try container.encode(sourceExerciseID, forKey: .sourceExerciseID)
    case let .removeExercise(sessionID, exerciseID):
      try container.encode(Kind.removeExercise, forKey: .type); try container.encode(sessionID, forKey: .sessionID); try container.encode(exerciseID, forKey: .exerciseID)
    case let .adjustSet(sessionID, exerciseID, setIndex, reps, weightKg, durationSeconds, restSeconds):
      try container.encode(Kind.adjustSet, forKey: .type); try container.encode(sessionID, forKey: .sessionID); try container.encode(exerciseID, forKey: .exerciseID); try container.encode(setIndex, forKey: .setIndex); try container.encodeIfPresent(reps, forKey: .reps); try container.encodeIfPresent(weightKg, forKey: .weightKg); try container.encodeIfPresent(durationSeconds, forKey: .durationSeconds); try container.encodeIfPresent(restSeconds, forKey: .restSeconds)
    case let .adjustBodyweightLoad(sessionID, exerciseID, setIndex, assistanceKg, addedWeightKg):
      try container.encode(Kind.adjustBodyweightLoad, forKey: .type); try container.encode(sessionID, forKey: .sessionID); try container.encode(exerciseID, forKey: .exerciseID); try container.encode(setIndex, forKey: .setIndex); try container.encode(assistanceKg, forKey: .assistanceKg); try container.encode(addedWeightKg, forKey: .addedWeightKg)
    }
  }

  public var summary: String {
    switch self {
    case let .moveSession(_, toDate): "Mover la sesión al \(toDate)"
    case let .shiftFutureSessions(fromDate, byDays): "Desplazar sesiones desde \(fromDate) \(byDays) días"
    case .cancelSession: "Cancelar la sesión"
    case let .replaceExercise(_, _, replacementExerciseID): "Sustituir ejercicio por \(replacementExerciseID)"
    case let .addExercise(_, sourceExerciseID): "Añadir ejercicio \(sourceExerciseID)"
    case let .removeExercise(_, exerciseID): "Quitar ejercicio \(exerciseID)"
    case .adjustSet: "Ajustar objetivo de serie"
    case .adjustBodyweightLoad: "Ajustar asistencia o lastre"
    }
  }

  public var targetSessionID: String? {
    switch self {
    case let .moveSession(sessionID, _), let .cancelSession(sessionID),
         let .replaceExercise(sessionID, _, _), let .addExercise(sessionID, _),
         let .removeExercise(sessionID, _), let .adjustSet(sessionID, _, _, _, _, _, _),
         let .adjustBodyweightLoad(sessionID, _, _, _, _):
      sessionID
    case .shiftFutureSessions:
      nil
    }
  }

  public var targetExerciseID: String? {
    switch self {
    case let .replaceExercise(_, exerciseID, _), let .removeExercise(_, exerciseID),
         let .adjustSet(_, exerciseID, _, _, _, _, _),
         let .adjustBodyweightLoad(_, exerciseID, _, _, _):
      exerciseID
    case .moveSession, .shiftFutureSessions, .cancelSession, .addExercise:
      nil
    }
  }
}

public struct PlanningConstraints: Sendable {
  public var availableWeekdays: Set<Int>
  public var availableEquipment: Set<Equipment>
  public var restrictedExerciseIDs: Set<String>
  public var restrictedMovementPatterns: Set<String>
  public var cautionMovementPatterns: Set<String>
  public var avoidsSupersets: Bool
  public var maxSessionMinutes: Int
  public var priorityMuscleGroups: Set<String>
  public var activeSessionID: String?
  public var completedSessionIDs: Set<String>
  public var referenceDate: Date

  public init(
    availableWeekdays: Set<Int>,
    availableEquipment: Set<Equipment>,
    restrictedExerciseIDs: Set<String> = [],
    restrictedMovementPatterns: Set<String> = [],
    cautionMovementPatterns: Set<String> = [],
    avoidsSupersets: Bool = false,
    maxSessionMinutes: Int,
    priorityMuscleGroups: Set<String> = [],
    activeSessionID: String? = nil,
    completedSessionIDs: Set<String> = [],
    referenceDate: Date = .now
  ) {
    self.availableWeekdays = availableWeekdays
    self.availableEquipment = availableEquipment
    self.restrictedExerciseIDs = restrictedExerciseIDs
    self.restrictedMovementPatterns = restrictedMovementPatterns
    self.cautionMovementPatterns = cautionMovementPatterns
    self.avoidsSupersets = avoidsSupersets
    self.maxSessionMinutes = maxSessionMinutes
    self.priorityMuscleGroups = priorityMuscleGroups
    self.activeSessionID = activeSessionID
    self.completedSessionIDs = completedSessionIDs
    self.referenceDate = referenceDate
  }
}

public struct PlanningProposal: Sendable {
  public let plan: TrainingPlan
  public let operations: [PlanningOperation]
  public let warnings: [PlanningWarning]
  public let impact: PlanningImpact

  public init(plan: TrainingPlan, operations: [PlanningOperation], warnings: [PlanningWarning], impact: PlanningImpact) {
    self.plan = plan
    self.operations = operations
    self.warnings = warnings
    self.impact = impact
  }
}

public struct PlanningImpact: Codable, Equatable, Sendable {
  public struct Diagnostic: Codable, Equatable, Identifiable, Sendable {
    public enum Tone: String, Codable, Sendable { case positive, caution, critical }

    public let id: String
    public let tone: Tone
    public let title: String
    public let detail: String

    public init(id: String, tone: Tone, title: String, detail: String) {
      self.id = id
      self.tone = tone
      self.title = title
      self.detail = detail
    }
  }

  public struct SessionChange: Codable, Equatable, Identifiable, Sendable {
    public let sessionID: String
    public let label: String
    public let week: Int
    public let focus: String
    public let dateBefore: String
    public let dateAfter: String
    public let estimatedMinutesBefore: Int
    public let estimatedMinutesAfter: Int
    public let wasCancelled: Bool
    public let isCancelled: Bool
    public let changes: [String]

    public var id: String { sessionID }

    public init(
      sessionID: String,
      label: String,
      week: Int,
      focus: String,
      dateBefore: String,
      dateAfter: String,
      estimatedMinutesBefore: Int,
      estimatedMinutesAfter: Int,
      wasCancelled: Bool,
      isCancelled: Bool,
      changes: [String]
    ) {
      self.sessionID = sessionID
      self.label = label
      self.week = week
      self.focus = focus
      self.dateBefore = dateBefore
      self.dateAfter = dateAfter
      self.estimatedMinutesBefore = estimatedMinutesBefore
      self.estimatedMinutesAfter = estimatedMinutesAfter
      self.wasCancelled = wasCancelled
      self.isCancelled = isCancelled
      self.changes = changes
    }
  }

  public let changedSessionIDs: [String]
  public let sessionChanges: [SessionChange]
  public let diagnostics: [Diagnostic]
  public let estimatedMinutesBefore: Int
  public let estimatedMinutesAfter: Int
  public let supersetsBefore: Int
  public let supersetsAfter: Int
  public let weeklySetChanges: [WeeklySetChange]
  public let shiftedMacrocycleWeeks: [Int]
  public let scheduleEndBefore: String?
  public let scheduleEndAfter: String?

  private enum CodingKeys: String, CodingKey {
    case changedSessionIDs, sessionChanges, diagnostics, estimatedMinutesBefore, estimatedMinutesAfter
    case supersetsBefore, supersetsAfter, weeklySetChanges, shiftedMacrocycleWeeks
    case scheduleEndBefore, scheduleEndAfter
  }

  public init(
    changedSessionIDs: [String],
    sessionChanges: [SessionChange] = [],
    diagnostics: [Diagnostic] = [],
    estimatedMinutesBefore: Int,
    estimatedMinutesAfter: Int,
    supersetsBefore: Int,
    supersetsAfter: Int,
    weeklySetChanges: [WeeklySetChange],
    shiftedMacrocycleWeeks: [Int] = [],
    scheduleEndBefore: String? = nil,
    scheduleEndAfter: String? = nil
  ) {
    self.changedSessionIDs = changedSessionIDs
    self.sessionChanges = sessionChanges
    self.diagnostics = diagnostics
    self.estimatedMinutesBefore = estimatedMinutesBefore
    self.estimatedMinutesAfter = estimatedMinutesAfter
    self.supersetsBefore = supersetsBefore
    self.supersetsAfter = supersetsAfter
    self.weeklySetChanges = weeklySetChanges
    self.shiftedMacrocycleWeeks = shiftedMacrocycleWeeks
    self.scheduleEndBefore = scheduleEndBefore
    self.scheduleEndAfter = scheduleEndAfter
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    changedSessionIDs = try container.decode([String].self, forKey: .changedSessionIDs)
    sessionChanges = try container.decodeIfPresent([SessionChange].self, forKey: .sessionChanges) ?? []
    diagnostics = try container.decodeIfPresent([Diagnostic].self, forKey: .diagnostics) ?? []
    estimatedMinutesBefore = try container.decode(Int.self, forKey: .estimatedMinutesBefore)
    estimatedMinutesAfter = try container.decode(Int.self, forKey: .estimatedMinutesAfter)
    supersetsBefore = try container.decode(Int.self, forKey: .supersetsBefore)
    supersetsAfter = try container.decode(Int.self, forKey: .supersetsAfter)
    weeklySetChanges = try container.decode([WeeklySetChange].self, forKey: .weeklySetChanges)
    shiftedMacrocycleWeeks = try container.decodeIfPresent([Int].self, forKey: .shiftedMacrocycleWeeks) ?? []
    scheduleEndBefore = try container.decodeIfPresent(String.self, forKey: .scheduleEndBefore)
    scheduleEndAfter = try container.decodeIfPresent(String.self, forKey: .scheduleEndAfter)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(changedSessionIDs, forKey: .changedSessionIDs)
    try container.encode(sessionChanges, forKey: .sessionChanges)
    try container.encode(diagnostics, forKey: .diagnostics)
    try container.encode(estimatedMinutesBefore, forKey: .estimatedMinutesBefore)
    try container.encode(estimatedMinutesAfter, forKey: .estimatedMinutesAfter)
    try container.encode(supersetsBefore, forKey: .supersetsBefore)
    try container.encode(supersetsAfter, forKey: .supersetsAfter)
    try container.encode(weeklySetChanges, forKey: .weeklySetChanges)
    try container.encode(shiftedMacrocycleWeeks, forKey: .shiftedMacrocycleWeeks)
    try container.encodeIfPresent(scheduleEndBefore, forKey: .scheduleEndBefore)
    try container.encodeIfPresent(scheduleEndAfter, forKey: .scheduleEndAfter)
  }
}

public struct WeeklySetChange: Codable, Equatable, Sendable, Identifiable {
  public let week: Int
  public let muscle: String
  public let before: Int
  public let after: Int

  public var id: String { "\(week)-\(muscle)" }
  public var delta: Int { after - before }

  public init(week: Int, muscle: String, before: Int, after: Int) {
    self.week = week
    self.muscle = muscle
    self.before = before
    self.after = after
  }
}

public enum PlanningWarning: Codable, Equatable, Sendable {
  case durationExceedsPreference(sessionID: String, minutes: Int, maximum: Int)
  case aggressiveSetProgression(sessionID: String, exerciseID: String, setIndex: Int, before: Double, after: Double)
  case weeklyVolumeIncrease(week: Int, muscle: String, before: Int, after: Int)
  case priorityVolumeReduced(week: Int, muscle: String, before: Int, after: Int)

  public var message: String {
    switch self {
    case let .durationExceedsPreference(_, minutes, maximum):
      "La sesión estima \(minutes) min, por encima de la preferencia de \(maximum) min."
    case let .aggressiveSetProgression(_, _, _, before, after):
      "La carga objetivo sube de \(Self.weight(before)) a \(Self.weight(after)) kg en una sola revisión."
    case let .weeklyVolumeIncrease(week, muscle, before, after):
      "La semana \(week) sube \(muscle) de \(before) a \(after) series; revisa que el aumento sea intencional."
    case let .priorityVolumeReduced(week, muscle, before, after):
      "La semana \(week) reduce el grupo prioritario \(muscle) de \(before) a \(after) series."
    }
  }

  private static func weight(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(value.rounded() == value ? 0 : 1)))
  }
}

public enum PlanningOperationError: Error, Equatable, Sendable, LocalizedError {
  case sessionNotFound(String)
  case sessionNotEditable(String)
  case sessionCompleted(String)
  case sessionActive(String)
  case invalidDate(String)
  case dateOutsideAvailability(String)
  case conflictingSession(String)
  case invalidShift(Int)
  case exerciseNotFound(String)
  case replacementNotFound(String)
  case replacementUsesUnavailableEquipment(String)
  case replacementIsRestricted(String)
  case cannotRemoveLastExercise
  case setNotFound(Int)
  case invalidBodyweightLoad

  public var errorDescription: String? {
    switch self {
    case let .sessionNotFound(id): "No existe la sesión \(id)."
    case let .sessionNotEditable(id): "La sesión \(id) no se puede modificar."
    case let .sessionCompleted(id): "La sesión \(id) ya está completada."
    case let .sessionActive(id): "La sesión \(id) está en curso."
    case let .invalidDate(value): "La fecha \(value) no es válida."
    case let .dateOutsideAvailability(value): "La fecha \(value) queda fuera de la disponibilidad indicada."
    case let .conflictingSession(value): "Ya existe una sesión programada para \(value)."
    case let .invalidShift(days): "No se pueden desplazar sesiones \(days) días."
    case let .exerciseNotFound(id): "No existe el ejercicio \(id) en la sesión."
    case let .replacementNotFound(id): "No existe el ejercicio alternativo \(id)."
    case let .replacementUsesUnavailableEquipment(id): "El ejercicio \(id) requiere material no disponible."
    case let .replacementIsRestricted(id): "El ejercicio \(id) está restringido por el perfil."
    case .cannotRemoveLastExercise: "Una sesión debe conservar al menos un ejercicio."
    case let .setNotFound(index): "No existe la serie \(index)."
    case .invalidBodyweightLoad: "La asistencia y el lastre no pueden aplicarse a la vez."
    }
  }
}

public enum PlanningOperationEngine {
  public static func preview(
    basePlan: TrainingPlan,
    operations: [PlanningOperation],
    constraints: PlanningConstraints
  ) throws -> PlanningProposal {
    var plan = basePlan
    var warnings: [PlanningWarning] = []

    for operation in operations {
      switch operation {
      case let .moveSession(sessionID, toDate):
        let index = try movableSessionIndex(sessionID, in: plan, constraints: constraints)
        let targetDate = try date(from: toDate)
        let targetDay = Calendar.current.startOfDay(for: targetDate)
        let today = Calendar.current.startOfDay(for: constraints.referenceDate)
        guard targetDay >= today else { throw PlanningOperationError.invalidDate(toDate) }
        guard !plan.sessions.contains(where: {
          $0.sessionID != sessionID && !$0.isCancelled && $0.date == toDate
        }) else {
          throw PlanningOperationError.conflictingSession(toDate)
        }
        plan.sessions[index].date = toDate
        plan.sessions[index].weekday = weekdayLabel(for: targetDay)
        appendDurationWarning(for: plan.sessions[index], constraints: constraints, warnings: &warnings)

      case let .shiftFutureSessions(fromDate, byDays):
        guard byDays > 0 else { throw PlanningOperationError.invalidShift(byDays) }
        let startDate = try date(from: fromDate)
        let startDay = Calendar.current.startOfDay(for: startDate)
        let affected = plan.sessions.indices.filter { index in
          guard !plan.sessions[index].isCancelled, let date = try? date(from: plan.sessions[index].date) else { return false }
          return Calendar.current.startOfDay(for: date) >= startDay
        }
        guard !affected.isEmpty else { throw PlanningOperationError.invalidShift(byDays) }
        for index in affected {
          _ = try editableSessionIndex(plan.sessions[index].sessionID, in: plan, constraints: constraints)
        }
        for index in affected {
          let currentDate = try date(from: plan.sessions[index].date)
          guard let shiftedDate = Calendar.current.date(byAdding: .day, value: byDays, to: currentDate) else {
            throw PlanningOperationError.invalidShift(byDays)
          }
          plan.sessions[index].date = isoDateString(shiftedDate)
          plan.sessions[index].weekday = weekdayLabel(for: shiftedDate)
        }
        let dates = plan.sessions.filter { !$0.isCancelled }.map(\.date)
        guard Set(dates).count == dates.count else { throw PlanningOperationError.conflictingSession(fromDate) }

      case let .cancelSession(sessionID):
        let index = try editableSessionIndex(sessionID, in: plan, constraints: constraints)
        plan.sessions[index].cancelled = true

      case let .replaceExercise(sessionID, exerciseID, replacementExerciseID):
        let sessionIndex = try editableSessionIndex(sessionID, in: plan, constraints: constraints)
        guard let exerciseIndex = plan.sessions[sessionIndex].exercises.firstIndex(where: { $0.exerciseID == exerciseID }) else {
          throw PlanningOperationError.exerciseNotFound(exerciseID)
        }
        guard var replacement = plan.sessions
          .flatMap(\.exercises)
          .first(where: { $0.exerciseID == replacementExerciseID }) else {
          throw PlanningOperationError.replacementNotFound(replacementExerciseID)
        }
        guard !constraints.restrictedExerciseIDs.contains(replacement.exerciseID),
              !constraints.restrictedExerciseIDs.contains(replacement.baseExerciseID),
              !constraints.restrictedMovementPatterns.contains(replacement.movementPattern ?? ""),
              !(constraints.avoidsSupersets && replacement.supersetID != nil) else {
          throw PlanningOperationError.replacementIsRestricted(replacementExerciseID)
        }
        guard let equipment = replacement.selectableEquipmentOptions.first(where: constraints.availableEquipment.contains) else {
          throw PlanningOperationError.replacementUsesUnavailableEquipment(replacementExerciseID)
        }

        let original = plan.sessions[sessionIndex].exercises[exerciseIndex]
        replacement.equipment = equipment
        replacement.sets = original.sets
        replacement.block = original.block
        replacement.supersetID = original.supersetID
        replacement.supersetOrder = original.supersetOrder
        plan.sessions[sessionIndex].exercises[exerciseIndex] = replacement
        appendDurationWarning(for: plan.sessions[sessionIndex], constraints: constraints, warnings: &warnings)
      case let .addExercise(sessionID, sourceExerciseID):
        let sessionIndex = try editableSessionIndex(sessionID, in: plan, constraints: constraints)
        guard let exercise = plan.sessions.flatMap(\.exercises).first(where: { $0.exerciseID == sourceExerciseID }) else { throw PlanningOperationError.replacementNotFound(sourceExerciseID) }
        guard exercise.selectableEquipmentOptions.contains(where: constraints.availableEquipment.contains) else { throw PlanningOperationError.replacementUsesUnavailableEquipment(sourceExerciseID) }
        guard !constraints.restrictedExerciseIDs.contains(exercise.exerciseID),
              !constraints.restrictedExerciseIDs.contains(exercise.baseExerciseID),
              !constraints.restrictedMovementPatterns.contains(exercise.movementPattern ?? ""),
              !(constraints.avoidsSupersets && exercise.supersetID != nil) else { throw PlanningOperationError.replacementIsRestricted(sourceExerciseID) }
        plan.sessions[sessionIndex].exercises.append(exercise)
        appendDurationWarning(for: plan.sessions[sessionIndex], constraints: constraints, warnings: &warnings)
      case let .removeExercise(sessionID, exerciseID):
        let sessionIndex = try editableSessionIndex(sessionID, in: plan, constraints: constraints)
        guard plan.sessions[sessionIndex].exercises.count > 1 else { throw PlanningOperationError.cannotRemoveLastExercise }
        guard let index = plan.sessions[sessionIndex].exercises.firstIndex(where: { $0.exerciseID == exerciseID }) else { throw PlanningOperationError.exerciseNotFound(exerciseID) }
        plan.sessions[sessionIndex].exercises.remove(at: index)
      case let .adjustSet(sessionID, exerciseID, setIndex, reps, weightKg, durationSeconds, restSeconds):
        let sessionIndex = try editableSessionIndex(sessionID, in: plan, constraints: constraints)
        guard let exerciseIndex = plan.sessions[sessionIndex].exercises.firstIndex(where: { $0.exerciseID == exerciseID }) else { throw PlanningOperationError.exerciseNotFound(exerciseID) }
        guard let targetIndex = plan.sessions[sessionIndex].exercises[exerciseIndex].sets.firstIndex(where: { $0.setIndex == setIndex }) else { throw PlanningOperationError.setNotFound(setIndex) }
        if let reps { plan.sessions[sessionIndex].exercises[exerciseIndex].sets[targetIndex].targetReps = max(1, reps) }
        if let weightKg {
          let previousWeight = plan.sessions[sessionIndex].exercises[exerciseIndex].sets[targetIndex].targetWeightKg
          let adjustedWeight = max(0, weightKg)
          plan.sessions[sessionIndex].exercises[exerciseIndex].sets[targetIndex].targetWeightKg = adjustedWeight
          if previousWeight > 0, adjustedWeight > previousWeight * 1.10 {
            warnings.append(.aggressiveSetProgression(
              sessionID: sessionID,
              exerciseID: exerciseID,
              setIndex: setIndex,
              before: previousWeight,
              after: adjustedWeight
            ))
          }
        }
        if let durationSeconds { plan.sessions[sessionIndex].exercises[exerciseIndex].sets[targetIndex].targetDurationSeconds = max(15, durationSeconds) }
        if let restSeconds { plan.sessions[sessionIndex].exercises[exerciseIndex].sets[targetIndex].restSeconds = max(0, restSeconds) }
        appendDurationWarning(for: plan.sessions[sessionIndex], constraints: constraints, warnings: &warnings)
      case let .adjustBodyweightLoad(sessionID, exerciseID, setIndex, assistanceKg, addedWeightKg):
        let sessionIndex = try editableSessionIndex(sessionID, in: plan, constraints: constraints)
        guard let exerciseIndex = plan.sessions[sessionIndex].exercises.firstIndex(where: { $0.exerciseID == exerciseID }),
              plan.sessions[sessionIndex].exercises[exerciseIndex].equipment == .bodyweight else {
          throw PlanningOperationError.exerciseNotFound(exerciseID)
        }
        guard let targetIndex = plan.sessions[sessionIndex].exercises[exerciseIndex].sets.firstIndex(where: { $0.setIndex == setIndex }) else {
          throw PlanningOperationError.setNotFound(setIndex)
        }
        guard assistanceKg >= 0, addedWeightKg >= 0, assistanceKg == 0 || addedWeightKg == 0 else {
          throw PlanningOperationError.invalidBodyweightLoad
        }
        plan.sessions[sessionIndex].exercises[exerciseIndex].sets[targetIndex].bodyweightLoad = BodyweightLoad(
          assistanceKg: assistanceKg,
          addedWeightKg: addedWeightKg
        )
      }
    }

    appendWeeklyVolumeWarnings(from: basePlan, to: plan, constraints: constraints, warnings: &warnings)

    return PlanningProposal(
      plan: plan,
      operations: operations,
      warnings: warnings,
      impact: impact(from: basePlan, to: plan, operations: operations, constraints: constraints)
    )
  }

  private static func impact(
    from basePlan: TrainingPlan,
    to proposedPlan: TrainingPlan,
    operations: [PlanningOperation],
    constraints: PlanningConstraints
  ) -> PlanningImpact {
    let beforeVolume = weeklyVolume(for: basePlan)
    let afterVolume = weeklyVolume(for: proposedPlan)
    let changedVolume = Set(beforeVolume.keys).union(afterVolume.keys).compactMap { key -> WeeklySetChange? in
      let before = beforeVolume[key] ?? 0
      let after = afterVolume[key] ?? 0
      guard before != after else { return nil }
      let components = key.split(separator: "|", maxSplits: 1).map(String.init)
      guard components.count == 2, let week = Int(components[0]) else { return nil }
      return WeeklySetChange(week: week, muscle: components[1], before: before, after: after)
    }
    .sorted { lhs, rhs in
      lhs.week == rhs.week ? lhs.muscle < rhs.muscle : lhs.week < rhs.week
    }

    let explicitlyChangedSessionIDs = Set(operations.compactMap(sessionID(for:)))
    let shiftedWeeks = proposedPlan.sessions.compactMap { proposed -> Int? in
      guard let original = basePlan.sessions.first(where: { $0.sessionID == proposed.sessionID }),
            original.date != proposed.date else { return nil }
      return proposed.week
    }
    let changedSessionIDs = proposedPlan.sessions.compactMap { proposed -> String? in
      guard let original = basePlan.sessions.first(where: { $0.sessionID == proposed.sessionID }) else { return proposed.sessionID }
      return original.date != proposed.date || original.isCancelled != proposed.isCancelled || explicitlyChangedSessionIDs.contains(proposed.sessionID)
        ? proposed.sessionID
        : nil
    }
    .sorted()
    let sessionChanges = changedSessionIDs.compactMap { sessionID -> PlanningImpact.SessionChange? in
      guard let before = basePlan.sessions.first(where: { $0.sessionID == sessionID }),
            let after = proposedPlan.sessions.first(where: { $0.sessionID == sessionID }) else { return nil }
      var changes: [String] = []
      if before.date != after.date { changes.append("Fecha: \(before.date) → \(after.date)") }
      if before.isCancelled != after.isCancelled {
        changes.append(after.isCancelled ? "Sesión cancelada" : "Sesión recuperada")
      }
      if before.estimatedMinutes != after.estimatedMinutes {
        changes.append("Duración estimada: \(before.estimatedMinutes) → \(after.estimatedMinutes) min")
      }
      changes.append(contentsOf: operations.compactMap { operation in
        Self.sessionID(for: operation) == sessionID ? operation.summary : nil
      })
      return PlanningImpact.SessionChange(
        sessionID: sessionID,
        label: after.label,
        week: after.week,
        focus: after.focus,
        dateBefore: before.date,
        dateAfter: after.date,
        estimatedMinutesBefore: before.estimatedMinutes,
        estimatedMinutesAfter: after.estimatedMinutes,
        wasCancelled: before.isCancelled,
        isCancelled: after.isCancelled,
        changes: Array(NSOrderedSet(array: changes)).compactMap { $0 as? String }
      )
    }
    return PlanningImpact(
      changedSessionIDs: changedSessionIDs,
      sessionChanges: sessionChanges,
      diagnostics: diagnostics(
        proposedPlan: proposedPlan,
        sessionChanges: sessionChanges,
        weeklySetChanges: changedVolume,
        constraints: constraints
      ),
      estimatedMinutesBefore: basePlan.sessions.filter { !$0.isCancelled }.reduce(0) { $0 + $1.estimatedMinutes },
      estimatedMinutesAfter: proposedPlan.sessions.filter { !$0.isCancelled }.reduce(0) { $0 + $1.estimatedMinutes },
      supersetsBefore: supersetCount(for: basePlan),
      supersetsAfter: supersetCount(for: proposedPlan),
      weeklySetChanges: changedVolume,
      shiftedMacrocycleWeeks: Array(Set(shiftedWeeks)).sorted(),
      scheduleEndBefore: scheduleEndDate(for: basePlan),
      scheduleEndAfter: scheduleEndDate(for: proposedPlan)
    )
  }

  private static func diagnostics(
    proposedPlan: TrainingPlan,
    sessionChanges: [PlanningImpact.SessionChange],
    weeklySetChanges: [WeeklySetChange],
    constraints: PlanningConstraints
  ) -> [PlanningImpact.Diagnostic] {
    let affectedWeeks = Set(sessionChanges.map(\.week))
    var result: [PlanningImpact.Diagnostic] = []

    for week in affectedWeeks.sorted() {
      let sessions = proposedPlan.sessions
        .filter { !$0.isCancelled && $0.week == week }
        .sorted { $0.date < $1.date }
      guard let referenceSession = sessions.first else { continue }
      let phases = Set(sessions.flatMap(\.exercises).map { normalizedPhase($0.phase) })
      let phaseSummary = phases.sorted().joined(separator: ", ")
      result.append(.init(
        id: "week-focus-\(week)",
        tone: .positive,
        title: "S\(week) · \(referenceSession.weekFocusLabel)",
        detail: "La propuesta conserva el foco semanal y se revisa frente a la fase \(phaseSummary.isEmpty ? "planificada" : phaseSummary)."
      ))

      let weekVolumeChanges = weeklySetChanges.filter { $0.week == week && $0.before != $0.after }
      if phases.contains("descarga") || phases.contains("readaptacion") {
        for change in weekVolumeChanges where change.after > change.before {
          result.append(.init(
            id: "phase-volume-increase-\(week)-\(change.muscle)",
            tone: .caution,
            title: "Volumen contrario a la fase",
            detail: "\(change.muscle.capitalized) pasa de \(change.before) a \(change.after) series en una semana de \(phases.contains("descarga") ? "descarga" : "readaptación"). Revisa que sea intencional."
          ))
        }
      } else if phases.contains("acumulacion") {
        for change in weekVolumeChanges where change.before > 0 && Double(change.after) < Double(change.before) * 0.85 {
          result.append(.init(
            id: "phase-volume-reduction-\(week)-\(change.muscle)",
            tone: .caution,
            title: "Volumen reducido en acumulación",
            detail: "\(change.muscle.capitalized) baja de \(change.before) a \(change.after) series. Confirma que la reducción responde a recuperación, disponibilidad o una prioridad mayor."
          ))
        }
      } else if phases.contains("intensificacion") {
        for change in weekVolumeChanges where change.before > 0 && Double(change.after) > Double(change.before) * 1.15 {
          result.append(.init(
            id: "phase-volume-increase-\(week)-\(change.muscle)",
            tone: .caution,
            title: "Volumen alto en intensificación",
            detail: "\(change.muscle.capitalized) sube de \(change.before) a \(change.after) series. En intensificación conviene concentrar la carga sin elevar demasiado la fatiga acumulada."
          ))
        }
      }

      for session in sessions where session.estimatedMinutes > constraints.maxSessionMinutes {
        result.append(.init(
          id: "duration-\(session.sessionID)",
          tone: .caution,
          title: "Duración por encima del límite",
          detail: "\(session.label) queda en \(session.estimatedMinutes) min, por encima de tu límite de \(constraints.maxSessionMinutes) min."
        ))
      }

      for pair in zip(sessions, sessions.dropFirst()) {
        guard let firstDate = try? date(from: pair.0.date),
              let secondDate = try? date(from: pair.1.date) else { continue }
        let fullDays = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: firstDate), to: Calendar.current.startOfDay(for: secondDate)).day ?? 0
        let sharedMuscles = Set(pair.0.exercises.flatMap(\.primaryMuscles)).intersection(pair.1.exercises.flatMap(\.primaryMuscles))
        guard fullDays < 1, !sharedMuscles.isEmpty else { continue }
        result.append(.init(
          id: "recovery-\(week)-\(pair.0.sessionID)-\(pair.1.sessionID)",
          tone: .critical,
          title: "Recuperación insuficiente",
          detail: "\(pair.0.label) y \(pair.1.label) quedan el mismo día y repiten \(sharedMuscles.sorted().joined(separator: ", ")). Revisa el calendario antes de aceptar."
        ))
      }
    }

    for change in weeklySetChanges where change.before > 0 && change.after > change.before {
      let increase = Double(change.after - change.before) / Double(change.before)
      guard increase > 0.15 else { continue }
      result.append(.init(
        id: "volume-\(change.week)-\(change.muscle)",
        tone: increase > 0.30 ? .caution : .positive,
        title: "Volumen de \(change.muscle.capitalized)",
        detail: "S\(change.week): \(change.before) → \(change.after) series (\(Int((increase * 100).rounded())) %)."
      ))
    }
    return result
  }

  private static func scheduleEndDate(for plan: TrainingPlan) -> String? {
    plan.sessions
      .filter { !$0.isCancelled }
      .map(\.date)
      .max()
  }

  private static func normalizedPhase(_ value: String) -> String {
    value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es_ES"))
  }

  private static func weeklyVolume(for plan: TrainingPlan) -> [String: Int] {
    var volume: [String: Int] = [:]
    for session in plan.sessions where !session.isCancelled {
      for exercise in session.exercises {
        for muscle in exercise.primaryMuscles {
          let key = "\(session.week)|\(muscle)"
          volume[key, default: 0] += exercise.sets.count
        }
      }
    }
    return volume
  }

  private static func appendWeeklyVolumeWarnings(
    from basePlan: TrainingPlan,
    to proposedPlan: TrainingPlan,
    constraints: PlanningConstraints,
    warnings: inout [PlanningWarning]
  ) {
    let before = weeklyVolume(for: basePlan)
    let after = weeklyVolume(for: proposedPlan)
    for key in Set(before.keys).union(after.keys) {
      guard let separator = key.firstIndex(of: "|"),
            let week = Int(key[..<separator]) else { continue }
      let muscle = String(key[key.index(after: separator)...])
      let previous = before[key] ?? 0
      let proposed = after[key] ?? 0
      guard previous != proposed else { continue }

      if previous > 0, proposed >= previous + 3, Double(proposed) > Double(previous) * 1.30 {
        let warning = PlanningWarning.weeklyVolumeIncrease(week: week, muscle: muscle, before: previous, after: proposed)
        if !warnings.contains(warning) { warnings.append(warning) }
      }

      if constraints.priorityMuscleGroups.contains(normalized(muscle)), proposed < previous {
        let warning = PlanningWarning.priorityVolumeReduced(week: week, muscle: muscle, before: previous, after: proposed)
        if !warnings.contains(warning) { warnings.append(warning) }
      }
    }
  }

  private static func normalized(_ value: String) -> String {
    value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es_ES"))
  }

  private static func supersetCount(for plan: TrainingPlan) -> Int {
    Set(plan.sessions.filter { !$0.isCancelled }.flatMap { session in
      session.exercises.compactMap { exercise in
        exercise.supersetID.map { "\(session.sessionID)|\($0)" }
      }
    }).count
  }

  private static func sessionID(for operation: PlanningOperation) -> String? {
    switch operation {
    case let .moveSession(sessionID, _), let .cancelSession(sessionID),
         let .replaceExercise(sessionID, _, _), let .addExercise(sessionID, _),
         let .removeExercise(sessionID, _), let .adjustSet(sessionID, _, _, _, _, _, _),
         let .adjustBodyweightLoad(sessionID, _, _, _, _):
      sessionID
    case .shiftFutureSessions:
      nil
    }
  }

  private static func editableSessionIndex(
    _ sessionID: String,
    in plan: TrainingPlan,
    constraints: PlanningConstraints
  ) throws -> Int {
    guard let index = plan.sessions.firstIndex(where: { $0.sessionID == sessionID }) else {
      throw PlanningOperationError.sessionNotFound(sessionID)
    }
    let session = plan.sessions[index]
    guard !session.isCancelled else { throw PlanningOperationError.sessionNotEditable(sessionID) }
    guard !constraints.completedSessionIDs.contains(sessionID) else { throw PlanningOperationError.sessionCompleted(sessionID) }
    guard constraints.activeSessionID != sessionID else { throw PlanningOperationError.sessionActive(sessionID) }
    guard let sessionDate = try? date(from: session.date),
          Calendar.current.startOfDay(for: sessionDate) >= Calendar.current.startOfDay(for: constraints.referenceDate) else {
      throw PlanningOperationError.sessionNotEditable(sessionID)
    }
    return index
  }

  /// A missed session remains movable, but never editable in place. This lets a
  /// person recover an unfinished workout without reopening completed history.
  private static func movableSessionIndex(
    _ sessionID: String,
    in plan: TrainingPlan,
    constraints: PlanningConstraints
  ) throws -> Int {
    guard let index = plan.sessions.firstIndex(where: { $0.sessionID == sessionID }) else {
      throw PlanningOperationError.sessionNotFound(sessionID)
    }
    let session = plan.sessions[index]
    guard !session.isCancelled else { throw PlanningOperationError.sessionNotEditable(sessionID) }
    guard !constraints.completedSessionIDs.contains(sessionID) else { throw PlanningOperationError.sessionCompleted(sessionID) }
    guard constraints.activeSessionID != sessionID else { throw PlanningOperationError.sessionActive(sessionID) }
    return index
  }

  private static func appendDurationWarning(
    for session: TrainingSession,
    constraints: PlanningConstraints,
    warnings: inout [PlanningWarning]
  ) {
    guard constraints.maxSessionMinutes > 0,
          session.estimatedMinutes > constraints.maxSessionMinutes else { return }
    let warning = PlanningWarning.durationExceedsPreference(
      sessionID: session.sessionID,
      minutes: session.estimatedMinutes,
      maximum: constraints.maxSessionMinutes
    )
    if !warnings.contains(warning) { warnings.append(warning) }
  }

  private static func date(from value: String) throws -> Date {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd"
    guard let date = formatter.date(from: value) else { throw PlanningOperationError.invalidDate(value) }
    return date
  }

  private static func weekdayLabel(for date: Date) -> String {
    let names = ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"]
    return names[Calendar.current.component(.weekday, from: date) - 1]
  }

  private static func isoDateString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }
}
