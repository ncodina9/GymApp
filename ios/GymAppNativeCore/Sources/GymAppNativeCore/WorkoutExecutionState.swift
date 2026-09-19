import Foundation

public struct WorkoutSetLocator: Equatable, Hashable, Sendable {
  public let exerciseIndex: Int
  public let setIndex: Int

  public init(exerciseIndex: Int, setIndex: Int) {
    self.exerciseIndex = exerciseIndex
    self.setIndex = setIndex
  }
}

public struct WorkoutSetFeedback: Equatable, Sendable {
  public let rir: Int?
  public let painKnee: Int
  public let painWrist: Int
  public let painShoulder: Int
  public let painLowerBack: Int
  public let note: String

  public init(
    rir: Int?,
    painKnee: Int,
    painWrist: Int,
    painShoulder: Int,
    painLowerBack: Int,
    note: String
  ) {
    self.rir = rir
    self.painKnee = painKnee
    self.painWrist = painWrist
    self.painShoulder = painShoulder
    self.painLowerBack = painLowerBack
    self.note = note
  }

  public static let ok = WorkoutSetFeedback(
    rir: 2,
    painKnee: 0,
    painWrist: 0,
    painShoulder: 0,
    painLowerBack: 0,
    note: "OK"
  )
}

public struct WorkoutSetRecord: Equatable, Sendable {
  public let locator: WorkoutSetLocator
  public let feedback: WorkoutSetFeedback
  public let performedAt: Date
}

public struct WorkoutAdvance: Sendable {
  public let next: WorkoutSetLocator?
  public let restSeconds: Int?
}

public struct WorkoutExecutionState: Sendable {
  public let session: TrainingSession
  public private(set) var draft: WorkoutSessionDraft
  public private(set) var records: [WorkoutSetRecord]

  private let order: [WorkoutSetLocator]
  private var currentPosition: Int

  public init(session: TrainingSession) {
    self.session = session
    draft = WorkoutSessionDraft(session: session)
    records = []
    order = Self.makeOrder(for: session)
    currentPosition = 0
  }

  public var current: WorkoutSetLocator? {
    order.indices.contains(currentPosition) ? order[currentPosition] : nil
  }

  public var completedSetCount: Int { records.count }
  public var totalSetCount: Int { order.count }

  public func exercise(for locator: WorkoutSetLocator) -> TrainingExercise? {
    guard session.exercises.indices.contains(locator.exerciseIndex) else { return nil }
    return session.exercises[locator.exerciseIndex]
  }

  public func trainingSet(for locator: WorkoutSetLocator) -> TrainingSet? {
    exercise(for: locator)?.sets.first { $0.setIndex == locator.setIndex }
  }

  public func targets(for locator: WorkoutSetLocator) -> WorkoutSetTargets? {
    guard let exercise = exercise(for: locator) else { return nil }
    return draft.targets(for: exercise.exerciseID, setIndex: locator.setIndex)
  }

  public func equipment(for locator: WorkoutSetLocator) -> Equipment? {
    guard let exercise = exercise(for: locator) else { return nil }
    return draft.equipment(for: exercise.exerciseID)
  }

  public mutating func selectEquipment(_ equipment: Equipment, for locator: WorkoutSetLocator) -> Bool {
    guard let exercise = exercise(for: locator) else { return false }
    return draft.selectEquipment(equipment, for: exercise.exerciseID)
  }

  public func canSelectEquipment(_ equipment: Equipment, for locator: WorkoutSetLocator) -> Bool {
    guard let exercise = exercise(for: locator) else { return false }
    return draft.canSelectEquipment(equipment, for: exercise.exerciseID)
  }

  public mutating func updateWorkingTargets(
    for locator: WorkoutSetLocator,
    reps: Int?,
    weightKg: Double
  ) {
    guard let exercise = exercise(for: locator) else { return }
    draft.updateWorkingTargets(
      for: exercise.exerciseID,
      setIndex: locator.setIndex,
      reps: reps,
      weightKg: weightKg
    )
  }

  @discardableResult
  public mutating func recordCurrent(
    feedback: WorkoutSetFeedback,
    performedAt: Date = Date()
  ) -> WorkoutAdvance? {
    guard let current,
          let trainingSet = trainingSet(for: current)
    else {
      return nil
    }

    records.append(
      WorkoutSetRecord(locator: current, feedback: feedback, performedAt: performedAt)
    )
    currentPosition += 1
    let next = self.current

    return WorkoutAdvance(
      next: next,
      restSeconds: restAfterCurrent(current, next: next, proposedRest: trainingSet.restSeconds)
    )
  }

  private func restAfterCurrent(
    _ current: WorkoutSetLocator,
    next: WorkoutSetLocator?,
    proposedRest: Int
  ) -> Int? {
    guard let next else { return nil }
    guard let currentExercise = exercise(for: current),
          let nextExercise = exercise(for: next)
    else {
      return proposedRest
    }

    let continuesSupersetRound = currentExercise.supersetID != nil &&
      currentExercise.supersetID == nextExercise.supersetID &&
      current.setIndex == next.setIndex

    return continuesSupersetRound ? nil : proposedRest
  }

  private static func makeOrder(for session: TrainingSession) -> [WorkoutSetLocator] {
    var result: [WorkoutSetLocator] = []
    var exerciseIndex = 0

    while exerciseIndex < session.exercises.count {
      let exercise = session.exercises[exerciseIndex]
      guard let supersetID = exercise.supersetID else {
        result.append(contentsOf: exercise.sets.map {
          WorkoutSetLocator(exerciseIndex: exerciseIndex, setIndex: $0.setIndex)
        })
        exerciseIndex += 1
        continue
      }

      let groupStart = exerciseIndex
      while exerciseIndex < session.exercises.count,
            session.exercises[exerciseIndex].supersetID == supersetID {
        exerciseIndex += 1
      }

      let groupIndexes = Array(groupStart ..< exerciseIndex)
      let maxSetCount = groupIndexes.map { session.exercises[$0].sets.count }.max() ?? 0
      for setOffset in 0 ..< maxSetCount {
        for index in groupIndexes where session.exercises[index].sets.indices.contains(setOffset) {
          let trainingSet = session.exercises[index].sets[setOffset]
          result.append(WorkoutSetLocator(exerciseIndex: index, setIndex: trainingSet.setIndex))
        }
      }
    }

    return result
  }
}
