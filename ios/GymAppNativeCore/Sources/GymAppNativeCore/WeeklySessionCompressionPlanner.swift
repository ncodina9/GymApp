import Foundation

public struct WeeklySessionCompressionOption: Equatable, Sendable, Identifiable {
  public let id: String
  public let retainedSessionIDs: [String]
  public let cancelledSessionIDs: [String]
  public let transferredExerciseNames: [String]
  public let operations: [PlanningOperation]

  public init(
    retainedSessionIDs: [String],
    cancelledSessionIDs: [String],
    transferredExerciseNames: [String],
    operations: [PlanningOperation]
  ) {
    self.id = "compress-\(retainedSessionIDs.joined(separator: ","))-\(cancelledSessionIDs.joined(separator: ","))"
    self.retainedSessionIDs = retainedSessionIDs
    self.cancelledSessionIDs = cancelledSessionIDs
    self.transferredExerciseNames = transferredExerciseNames
    self.operations = operations
  }
}

/// Compresses a future training week when the profile no longer has enough
/// available days. It keeps the highest-priority sessions, transfers only
/// standalone anchor work that still fits the recipient session, and leaves
/// every change as ordinary planning operations for review.
public enum WeeklySessionCompressionPlanner {
  public static func option(
    basePlan: TrainingPlan,
    sessionIDs: [String],
    constraints: PlanningConstraints
  ) -> WeeklySessionCompressionOption? {
    let sessions = basePlan.sessions.filter {
      sessionIDs.contains($0.sessionID) && !$0.isCancelled
    }
    let capacity = constraints.availableWeekdays.count
    guard capacity > 0, sessions.count > capacity else { return nil }

    let retained = sessions
      .sorted { lhs, rhs in
        let lhsScore = sessionPriority(lhs, constraints: constraints)
        let rhsScore = sessionPriority(rhs, constraints: constraints)
        if lhsScore != rhsScore { return lhsScore > rhsScore }
        return lhs.date < rhs.date
      }
      .prefix(capacity)
      .map(\.sessionID)
    let cancelled = sessions
      .filter { !retained.contains($0.sessionID) }
      .sorted { lhs, rhs in
        let lhsScore = sessionPriority(lhs, constraints: constraints)
        let rhsScore = sessionPriority(rhs, constraints: constraints)
        if lhsScore != rhsScore { return lhsScore < rhsScore }
        return lhs.date < rhs.date
      }

    var operations: [PlanningOperation] = []
    var workingPlan = basePlan
    var transferredExerciseNames: [String] = []

    for source in cancelled {
      let anchors = source.exercises
        .filter { $0.supersetID == nil && anchorPriority($0, constraints: constraints) > 0 }
        .sorted { lhs, rhs in
          let lhsScore = anchorPriority(lhs, constraints: constraints)
          let rhsScore = anchorPriority(rhs, constraints: constraints)
          if lhsScore != rhsScore { return lhsScore > rhsScore }
          return lhs.exerciseID < rhs.exerciseID
        }

      for exercise in anchors {
        guard let recipientID = bestRecipient(
          for: exercise,
          sessionIDs: retained,
          in: workingPlan
        ) else {
          continue
        }
        var transfer = exercise
        transfer.exerciseID = "\(exercise.exerciseID)-compressed-\(recipientID)"
        transfer.supersetID = nil
        transfer.supersetOrder = nil
        transfer.block = "Adaptación semanal"
        let operation = PlanningOperation.addExerciseWithTemplate(sessionID: recipientID, exercise: transfer)
        guard let preview = try? PlanningOperationEngine.preview(
          basePlan: workingPlan,
          operations: [operation],
          constraints: constraints
        ), let adaptedRecipient = preview.plan.sessions.first(where: { $0.sessionID == recipientID }),
          SessionDurationEstimator.estimate(for: adaptedRecipient).totalMinutes <= constraints.maxSessionMinutes else {
          continue
        }
        operations.append(operation)
        workingPlan = preview.plan
        transferredExerciseNames.append(exercise.displayName)
      }

      let cancellation = PlanningOperation.cancelSession(sessionID: source.sessionID)
      guard let preview = try? PlanningOperationEngine.preview(
        basePlan: workingPlan,
        operations: [cancellation],
        constraints: constraints
      ) else { continue }
      operations.append(cancellation)
      workingPlan = preview.plan
    }

    guard !operations.isEmpty else { return nil }
    return WeeklySessionCompressionOption(
      retainedSessionIDs: retained,
      cancelledSessionIDs: cancelled.map(\.sessionID),
      transferredExerciseNames: uniqueNames(transferredExerciseNames),
      operations: operations
    )
  }

  private static func bestRecipient(
    for exercise: TrainingExercise,
    sessionIDs: [String],
    in plan: TrainingPlan
  ) -> String? {
    plan.sessions
      .filter { sessionIDs.contains($0.sessionID) && !$0.isCancelled }
      .filter { !$0.exercises.contains(where: { $0.displayGroupID == exercise.displayGroupID }) }
      .sorted { lhs, rhs in
        let lhsMinutes = SessionDurationEstimator.estimate(for: lhs).totalMinutes
        let rhsMinutes = SessionDurationEstimator.estimate(for: rhs).totalMinutes
        if lhsMinutes != rhsMinutes { return lhsMinutes < rhsMinutes }
        return lhs.date < rhs.date
      }
      .first?
      .sessionID
  }

  private static func sessionPriority(_ session: TrainingSession, constraints: PlanningConstraints) -> Int {
    session.exercises.reduce(0) { $0 + anchorPriority($1, constraints: constraints) }
  }

  private static func anchorPriority(_ exercise: TrainingExercise, constraints: PlanningConstraints) -> Int {
    let type = normalized(exercise.type)
    var score: Int
    switch type {
    case "basico": score = 5
    case "basicotecnico": score = 4
    case "tecnico": score = 3
    case "accesorio": score = 0
    default: score = 1
    }
    score += Set(exercise.primaryMuscles).intersection(constraints.priorityMuscleGroups).count * 5
    return score
  }

  private static func normalized(_ value: String) -> String {
    value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
      .replacingOccurrences(of: " ", with: "")
  }

  private static func uniqueNames(_ names: [String]) -> [String] {
    var seen = Set<String>()
    return names.filter { seen.insert($0).inserted }
  }
}
