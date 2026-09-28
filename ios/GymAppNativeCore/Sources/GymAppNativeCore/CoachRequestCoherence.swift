import Foundation

public struct CoachRequestCoherenceIssue: Identifiable, Equatable, Sendable {
  public enum Severity: Equatable, Sendable { case warning, blocking }

  public let id: String
  public let severity: Severity
  public let message: String

  public init(id: String, severity: Severity, message: String) {
    self.id = id
    self.severity = severity
    self.message = message
  }
}

/// Checks a coach proposal against the current prescription before it reaches
/// the operation engine. It explains phase conflicts that are otherwise valid
/// low-level mutations.
public enum CoachRequestCoherence {
  public struct Context: Sendable {
    public let globalGoal: String
    public let priorityMuscles: Set<String>

    public init(globalGoal: String = "", priorityMuscles: Set<String> = []) {
      self.globalGoal = globalGoal
      self.priorityMuscles = Set(priorityMuscles.map(Self.normalized))
    }

    static func normalized(_ value: String) -> String {
      value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
  }

  public static func issues(in plan: TrainingPlan, operations: [PlanningOperation], context: Context = .init()) -> [CoachRequestCoherenceIssue] {
    var result: [CoachRequestCoherenceIssue] = []
    let replacements = Set(operations.compactMap { operation -> String? in
      if case let .replaceExercise(_, exerciseID, _) = operation { return exerciseID }
      return nil
    })
    var adjustedDimensions = Set<String>()

    for operation in operations {
      if case let .replaceExercise(sessionID, exerciseID, replacementExerciseID) = operation,
         let session = plan.sessions.first(where: { $0.sessionID == sessionID }),
         let source = session.exercises.first(where: { $0.exerciseID == exerciseID }),
         let replacement = plan.sessions.flatMap(\.exercises).first(where: { $0.exerciseID == replacementExerciseID }) {
        let sourcePriorities = Set(source.primaryMuscles.map(Context.normalized)).intersection(context.priorityMuscles)
        let replacementPriorities = Set(replacement.primaryMuscles.map(Context.normalized)).intersection(context.priorityMuscles)
        if !sourcePriorities.isEmpty && replacementPriorities.isEmpty {
          result.append(.init(id: "priority-replacement-\(sessionID)-\(exerciseID)", severity: .warning, message: "La sustitución deja de estimular tu prioridad: \(sourcePriorities.sorted().joined(separator: ", "))."))
        }
        let goal = context.globalGoal.isEmpty ? "" : " para tu objetivo de \(context.globalGoal)"
        result.append(.init(id: "week-focus-\(sessionID)-\(exerciseID)", severity: .warning, message: "S\(session.week) · \(session.weekFocusLabel): confirma que la sustitución conserva el foco semanal\(goal)."))
      }
      guard case let .adjustSet(sessionID, exerciseID, setIndex, reps, weightKg, _, restSeconds) = operation else { continue }
      let keyPrefix = "\(sessionID)-\(exerciseID)-\(setIndex)"
      if replacements.contains(exerciseID) {
        result.append(.init(id: "replaced-\(keyPrefix)", severity: .blocking, message: "No puedes sustituir y ajustar la misma serie en una sola petición; elige primero la alternativa."))
      }
      let dimensions = [("reps", reps != nil), ("weight", weightKg != nil), ("rest", restSeconds != nil)]
      for (dimension, exists) in dimensions where exists {
        let key = "\(keyPrefix)-\(dimension)"
        if !adjustedDimensions.insert(key).inserted {
          result.append(.init(id: "duplicate-\(key)", severity: .blocking, message: "La petición modifica dos veces \(dimension) en la misma serie."))
        }
      }
      guard let exercise = plan.sessions.first(where: { $0.sessionID == sessionID })?.exercises.first(where: { $0.exerciseID == exerciseID }),
            let set = exercise.sets.first(where: { $0.setIndex == setIndex }) else { continue }
      let increasesEffort = (reps ?? set.targetReps ?? 0) > (set.targetReps ?? 0)
        || (weightKg ?? set.targetWeightKg) > set.targetWeightKg
        || (restSeconds ?? set.restSeconds) < set.restSeconds
      switch exercise.phase {
      case "descarga", "readaptacion":
        if increasesEffort {
          result.append(.init(id: "phase-\(keyPrefix)", severity: .blocking, message: "La semana de \(exercise.phase) no admite aumentar la exigencia de \(exercise.displayName)."))
        }
      case "realizacion", "test":
        if reps != nil || weightKg != nil || restSeconds != nil {
          result.append(.init(id: "phase-\(keyPrefix)", severity: .blocking, message: "La semana de \(exercise.phase) conserva la prescripción; revisa este cambio con el entrenador."))
        }
      case "acumulacion":
        if weightKg != nil && (weightKg ?? 0) > set.targetWeightKg {
          result.append(.init(id: "focus-\(keyPrefix)", severity: .warning, message: "Acumulación prioriza reps antes que carga; confirma que el aumento de peso es intencional."))
        }
      case "intensificacion":
        if reps != nil && (reps ?? 0) > (set.targetReps ?? 0) {
          result.append(.init(id: "focus-\(keyPrefix)", severity: .warning, message: "Intensificación prioriza carga; confirma que el aumento de reps es intencional."))
        }
      default: break
      }
    }
    return result
  }
}
