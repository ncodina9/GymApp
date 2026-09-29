import Foundation

public enum PlanningProfileIssue: Equatable, Sendable, Identifiable {
  case duration(sessionID: String, minutes: Int, maximum: Int)
  case unavailableEquipment(sessionID: String, equipment: Equipment)
  case restrictedExercise(sessionID: String, exerciseID: String)
  case superset(sessionID: String)
  case caution(sessionID: String, exerciseID: String)

  public var id: String {
    switch self {
    case let .duration(sessionID, _, _): "duration-\(sessionID)"
    case let .unavailableEquipment(sessionID, equipment): "equipment-\(sessionID)-\(equipment.rawValue)"
    case let .restrictedExercise(sessionID, exerciseID): "restriction-\(sessionID)-\(exerciseID)"
    case let .superset(sessionID): "superset-\(sessionID)"
    case let .caution(sessionID, exerciseID): "caution-\(sessionID)-\(exerciseID)"
    }
  }
}

public enum PlanningProfileCompatibility {
  /// Reports the next relevant plan/profile mismatches without modifying the
  /// plan or producing a revision. A bounded horizon keeps the result useful
  /// for an athlete and avoids rendering an entire macrocycle as warnings.
  public static func issues(
    in plan: TrainingPlan,
    constraints: PlanningConstraints,
    maximumUpcomingSessions: Int? = nil
  ) -> [PlanningProfileIssue] {
    let today = Calendar.current.startOfDay(for: constraints.referenceDate)
    let upcomingSessions = plan.sessions
      .filter { !$0.isCancelled }
      .filter { session in
        guard let date = date(from: session.date) else { return false }
        return Calendar.current.startOfDay(for: date) >= today
      }
      .sorted { $0.date < $1.date }

    let scopedSessions: ArraySlice<TrainingSession>
    if let maximumUpcomingSessions {
      scopedSessions = upcomingSessions.prefix(max(0, maximumUpcomingSessions))
    } else {
      scopedSessions = ArraySlice(upcomingSessions)
    }

    return scopedSessions
      .flatMap { session in
        var result: [PlanningProfileIssue] = []
        if constraints.maxSessionMinutes > 0, session.estimatedMinutes > constraints.maxSessionMinutes {
          result.append(.duration(sessionID: session.sessionID, minutes: session.estimatedMinutes, maximum: constraints.maxSessionMinutes))
        }
        if constraints.avoidsSupersets, session.exercises.contains(where: { $0.supersetID != nil }) {
          result.append(.superset(sessionID: session.sessionID))
        }
        for exercise in session.exercises {
          if !exercise.selectableEquipmentOptions.contains(where: constraints.availableEquipment.contains) {
            result.append(.unavailableEquipment(sessionID: session.sessionID, equipment: exercise.equipment))
          }
          if constraints.restrictedExerciseIDs.contains(exercise.exerciseID)
            || constraints.restrictedExerciseIDs.contains(exercise.baseExerciseID)
            || constraints.restrictedMovementPatterns.contains(exercise.movementPattern ?? "") {
            result.append(.restrictedExercise(sessionID: session.sessionID, exerciseID: exercise.exerciseID))
          }
          if constraints.cautionMovementPatterns.contains(exercise.movementPattern ?? "") {
            result.append(.caution(sessionID: session.sessionID, exerciseID: exercise.exerciseID))
          }
        }
        return result
      }
      .sorted { $0.id < $1.id }
  }

  private static func date(from value: String) -> Date? {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: value)
  }
}
