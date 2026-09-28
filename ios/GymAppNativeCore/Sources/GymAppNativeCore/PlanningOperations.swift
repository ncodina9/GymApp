import Foundation

public enum PlanningOperation: Codable, Equatable, Sendable {
  case moveSession(sessionID: String, toDate: String)
  case cancelSession(sessionID: String)
  case replaceExercise(sessionID: String, exerciseID: String, replacementExerciseID: String)
  case addExercise(sessionID: String, sourceExerciseID: String)
  case removeExercise(sessionID: String, exerciseID: String)
  case adjustSet(sessionID: String, exerciseID: String, setIndex: Int, reps: Int?, weightKg: Double?, durationSeconds: Int?, restSeconds: Int?)

  private enum CodingKeys: String, CodingKey {
    case type
    case sessionID
    case toDate
    case exerciseID
    case replacementExerciseID
    case sourceExerciseID, setIndex, reps, weightKg, durationSeconds, restSeconds
  }

  private enum Kind: String, Codable {
    case moveSession
    case cancelSession
    case replaceExercise
    case addExercise, removeExercise, adjustSet
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    switch try container.decode(Kind.self, forKey: .type) {
    case .moveSession:
      self = .moveSession(
        sessionID: try container.decode(String.self, forKey: .sessionID),
        toDate: try container.decode(String.self, forKey: .toDate)
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
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case let .moveSession(sessionID, toDate):
      try container.encode(Kind.moveSession, forKey: .type)
      try container.encode(sessionID, forKey: .sessionID)
      try container.encode(toDate, forKey: .toDate)
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
    }
  }

  public var summary: String {
    switch self {
    case let .moveSession(_, toDate): "Mover la sesión al \(toDate)"
    case .cancelSession: "Cancelar la sesión"
    case let .replaceExercise(_, _, replacementExerciseID): "Sustituir ejercicio por \(replacementExerciseID)"
    case let .addExercise(_, sourceExerciseID): "Añadir ejercicio \(sourceExerciseID)"
    case let .removeExercise(_, exerciseID): "Quitar ejercicio \(exerciseID)"
    case .adjustSet: "Ajustar objetivo de serie"
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
  public let changedSessionIDs: [String]
  public let estimatedMinutesBefore: Int
  public let estimatedMinutesAfter: Int
  public let supersetsBefore: Int
  public let supersetsAfter: Int
  public let weeklySetChanges: [WeeklySetChange]

  public init(
    changedSessionIDs: [String],
    estimatedMinutesBefore: Int,
    estimatedMinutesAfter: Int,
    supersetsBefore: Int,
    supersetsAfter: Int,
    weeklySetChanges: [WeeklySetChange]
  ) {
    self.changedSessionIDs = changedSessionIDs
    self.estimatedMinutesBefore = estimatedMinutesBefore
    self.estimatedMinutesAfter = estimatedMinutesAfter
    self.supersetsBefore = supersetsBefore
    self.supersetsAfter = supersetsAfter
    self.weeklySetChanges = weeklySetChanges
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
  case exerciseNotFound(String)
  case replacementNotFound(String)
  case replacementUsesUnavailableEquipment(String)
  case replacementIsRestricted(String)
  case cannotRemoveLastExercise
  case setNotFound(Int)

  public var errorDescription: String? {
    switch self {
    case let .sessionNotFound(id): "No existe la sesión \(id)."
    case let .sessionNotEditable(id): "La sesión \(id) no se puede modificar."
    case let .sessionCompleted(id): "La sesión \(id) ya está completada."
    case let .sessionActive(id): "La sesión \(id) está en curso."
    case let .invalidDate(value): "La fecha \(value) no es válida."
    case let .dateOutsideAvailability(value): "La fecha \(value) queda fuera de la disponibilidad indicada."
    case let .conflictingSession(value): "Ya existe una sesión programada para \(value)."
    case let .exerciseNotFound(id): "No existe el ejercicio \(id) en la sesión."
    case let .replacementNotFound(id): "No existe el ejercicio alternativo \(id)."
    case let .replacementUsesUnavailableEquipment(id): "El ejercicio \(id) requiere material no disponible."
    case let .replacementIsRestricted(id): "El ejercicio \(id) está restringido por el perfil."
    case .cannotRemoveLastExercise: "Una sesión debe conservar al menos un ejercicio."
    case let .setNotFound(index): "No existe la serie \(index)."
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
        let index = try editableSessionIndex(sessionID, in: plan, constraints: constraints)
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
      }
    }

    appendWeeklyVolumeWarnings(from: basePlan, to: plan, constraints: constraints, warnings: &warnings)

    return PlanningProposal(
      plan: plan,
      operations: operations,
      warnings: warnings,
      impact: impact(from: basePlan, to: plan, operations: operations)
    )
  }

  private static func impact(
    from basePlan: TrainingPlan,
    to proposedPlan: TrainingPlan,
    operations: [PlanningOperation]
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

    return PlanningImpact(
      changedSessionIDs: Array(Set(operations.compactMap(sessionID(for:)))).sorted(),
      estimatedMinutesBefore: basePlan.sessions.filter { !$0.isCancelled }.reduce(0) { $0 + $1.estimatedMinutes },
      estimatedMinutesAfter: proposedPlan.sessions.filter { !$0.isCancelled }.reduce(0) { $0 + $1.estimatedMinutes },
      supersetsBefore: supersetCount(for: basePlan),
      supersetsAfter: supersetCount(for: proposedPlan),
      weeklySetChanges: changedVolume
    )
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
         let .removeExercise(sessionID, _), let .adjustSet(sessionID, _, _, _, _, _, _):
      sessionID
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
}
