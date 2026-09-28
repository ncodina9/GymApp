import Foundation

public struct SessionDurationAdaptationOption: Equatable, Sendable, Identifiable {
  public let id: String
  public let title: String
  public let detail: String
  public let operations: [PlanningOperation]
  public let estimatedMinutes: Int

  public init(id: String, title: String, detail: String, operations: [PlanningOperation], estimatedMinutes: Int) {
    self.id = id
    self.title = title
    self.detail = detail
    self.operations = operations
    self.estimatedMinutes = estimatedMinutes
  }
}

/// Produces conservative, reviewable ways to shorten a future session.
/// It never removes basic or technical exercises and delegates final validation
/// to the regular planning operation engine.
public enum SessionDurationAdaptationPlanner {
  public static func options(
    basePlan: TrainingPlan,
    sessionID: String,
    maximumMinutes: Int,
    constraints: PlanningConstraints
  ) throws -> [SessionDurationAdaptationOption] {
    guard let session = basePlan.sessions.first(where: { $0.sessionID == sessionID }) else {
      throw PlanningOperationError.sessionNotFound(sessionID)
    }
    let target = max(15, maximumMinutes)
    let originalMinutes = SessionDurationEstimator.estimate(for: session).totalMinutes
    guard originalMinutes > target else { return [] }

    var candidates: [SessionDurationAdaptationOption] = []
    let restOperations = shorterRestOperations(for: session)
    if !restOperations.isEmpty,
       let option = makeOption(
        id: "rest",
        title: "Acortar descansos",
        detail: "Mantiene todos los ejercicios y reduce descansos a un mínimo de 60 s.",
        operations: restOperations,
        basePlan: basePlan,
        sessionID: sessionID,
        constraints: constraints
       ) {
      candidates.append(option)
    }

    // Removing only standalone accessories avoids breaking a programmed superset
    // by leaving one of its exercises behind.
    let accessories = session.exercises.reversed().filter {
      $0.supersetID == nil
        && $0.type.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) == "accesorio"
    }
    var removalOperations: [PlanningOperation] = []
    for accessory in accessories {
      removalOperations.append(.removeExercise(sessionID: sessionID, exerciseID: accessory.exerciseID))
      if let option = makeOption(
        id: "accessory-\(removalOperations.count)",
        title: "Reducir accesorios",
        detail: "Quita \(removalOperations.count) accesorio\(removalOperations.count == 1 ? "" : "s") independiente\(removalOperations.count == 1 ? "" : "s") desde el final.",
        operations: removalOperations,
        basePlan: basePlan,
        sessionID: sessionID,
        constraints: constraints
      ) {
        candidates.append(option)
      }
    }

    var combinedOperations = restOperations
    for accessory in accessories {
      combinedOperations.append(.removeExercise(sessionID: sessionID, exerciseID: accessory.exerciseID))
      if let option = makeOption(
        id: "combined-\(combinedOperations.count)",
        title: "Descansos y accesorios",
        detail: "Acorta descansos y retira accesorios al final; conserva básicos y técnica.",
        operations: combinedOperations,
        basePlan: basePlan,
        sessionID: sessionID,
        constraints: constraints
      ) {
        candidates.append(option)
      }
    }

    return candidates
      .filter { $0.estimatedMinutes < originalMinutes }
      .sorted {
        let lhsMeetsTarget = $0.estimatedMinutes <= target
        let rhsMeetsTarget = $1.estimatedMinutes <= target
        if lhsMeetsTarget != rhsMeetsTarget { return lhsMeetsTarget }
        if $0.estimatedMinutes != $1.estimatedMinutes { return $0.estimatedMinutes > $1.estimatedMinutes }
        return $0.operations.count < $1.operations.count
      }
  }

  private static func shorterRestOperations(for session: TrainingSession) -> [PlanningOperation] {
    session.exercises.flatMap { exercise in
      exercise.sets.compactMap { trainingSet in
        guard trainingSet.restSeconds > 60 else { return nil }
        return .adjustSet(
          sessionID: session.sessionID,
          exerciseID: exercise.exerciseID,
          setIndex: trainingSet.setIndex,
          reps: nil,
          weightKg: nil,
          durationSeconds: nil,
          restSeconds: 60
        )
      }
    }
  }

  private static func makeOption(
    id: String,
    title: String,
    detail: String,
    operations: [PlanningOperation],
    basePlan: TrainingPlan,
    sessionID: String,
    constraints: PlanningConstraints
  ) -> SessionDurationAdaptationOption? {
    guard let proposed = try? PlanningOperationEngine.preview(
      basePlan: basePlan,
      operations: operations,
      constraints: constraints
    ), let session = proposed.plan.sessions.first(where: { $0.sessionID == sessionID }) else {
      return nil
    }
    return SessionDurationAdaptationOption(
      id: id,
      title: title,
      detail: detail,
      operations: operations,
      estimatedMinutes: SessionDurationEstimator.estimate(for: session).totalMinutes
    )
  }
}
