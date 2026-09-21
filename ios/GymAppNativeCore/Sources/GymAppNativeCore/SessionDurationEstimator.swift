import Foundation

public struct SessionDurationEstimate: Equatable, Sendable {
  public let totalMinutes: Int
  public let mobilityMinutes: Int
  public let executionMinutes: Int
  public let restMinutes: Int
  public let changeoverMinutes: Int
  public let feedbackMinutes: Int
  public let targetMinutes: Int
}

public enum SessionDurationEstimator {
  public static func estimate(for session: TrainingSession) -> SessionDurationEstimate {
    let steps = executionSteps(for: session)
    var executionSeconds = 0
    var restSeconds = 0
    var changeoverSeconds = 0

    for (index, step) in steps.enumerated() {
      let currentSet = session.exercises[step.exerciseIndex].sets[step.setIndex]
      let nextStep = steps[safe: index + 1]
      executionSeconds += executionDurationSeconds(for: currentSet)

      guard let nextStep else { continue }
      let skipsRest = step.supersetID != nil &&
        step.supersetID == nextStep.supersetID &&
        step.roundNumber == nextStep.roundNumber

      if !skipsRest {
        restSeconds += currentSet.restSeconds
      }

      if step.exerciseIndex != nextStep.exerciseIndex {
        changeoverSeconds += skipsRest ? 15 : 45
      }
    }

    let mobilitySeconds = 9 * 60
    let feedbackSeconds = steps.count * 8
    let totalSeconds = mobilitySeconds + executionSeconds + restSeconds + changeoverSeconds + feedbackSeconds

    return SessionDurationEstimate(
      totalMinutes: Int((Double(totalSeconds) / 60).rounded()),
      mobilityMinutes: 9,
      executionMinutes: Int((Double(executionSeconds) / 60).rounded()),
      restMinutes: Int((Double(restSeconds) / 60).rounded()),
      changeoverMinutes: Int((Double(changeoverSeconds) / 60).rounded()),
      feedbackMinutes: Int((Double(feedbackSeconds) / 60).rounded()),
      targetMinutes: session.estimatedMinutes
    )
  }

  private static func executionDurationSeconds(for trainingSet: TrainingSet) -> Int {
    if trainingSet.type == .timed {
      return trainingSet.targetDurationSeconds ?? 60
    }

    return max(20, (trainingSet.targetReps ?? 8) * 4)
  }

  private static func executionSteps(for session: TrainingSession) -> [ExecutionStep] {
    var visitedSupersets = Set<String>()
    var steps: [ExecutionStep] = []

    for (exerciseIndex, exercise) in session.exercises.enumerated() {
      guard let supersetID = exercise.supersetID else {
        for (setIndex, _) in exercise.sets.enumerated() {
          steps.append(
            ExecutionStep(
              exerciseIndex: exerciseIndex,
              setIndex: setIndex,
              roundNumber: setIndex + 1,
              supersetID: nil
            )
          )
        }
        continue
      }

      guard visitedSupersets.insert(supersetID).inserted else { continue }
      let members = session.exercises.enumerated()
        .filter { $0.element.supersetID == supersetID }
        .sorted { lhs, rhs in
          (lhs.element.supersetOrder ?? lhs.offset) < (rhs.element.supersetOrder ?? rhs.offset)
        }
      let roundCount = members.map { $0.element.sets.count }.max() ?? 0

      for setIndex in 0 ..< roundCount {
        for member in members where member.element.sets.indices.contains(setIndex) {
          steps.append(
            ExecutionStep(
              exerciseIndex: member.offset,
              setIndex: setIndex,
              roundNumber: setIndex + 1,
              supersetID: supersetID
            )
          )
        }
      }
    }

    return steps
  }

  private struct ExecutionStep {
    let exerciseIndex: Int
    let setIndex: Int
    let roundNumber: Int
    let supersetID: String?
  }
}

private extension Collection {
  subscript(safe index: Index) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
