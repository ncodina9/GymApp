import Foundation

public enum ActiveWorkoutPhase: String, Codable, Equatable, Sendable {
  case workingSet
  case feedback
  case rest
  case exerciseReview
}

public enum WorkoutWarmupStatus: String, Codable, Equatable, Sendable {
  case notStarted
  case running
  case completed
}

public struct ActiveWorkoutFeedbackDraft: Codable, Sendable {
  public var rir: Int
  public var painKnee: Int
  public var painWrist: Int
  public var painShoulder: Int
  public var painLowerBack: Int
  public var note: String

  public init(
    rir: Int,
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
}

public struct ActiveWorkoutSnapshot: Codable, Sendable {
  public static let currentSchemaVersion = 5

  public let schemaVersion: Int
  public var execution: WorkoutExecutionState
  public var phase: ActiveWorkoutPhase
  public var feedback: ActiveWorkoutFeedbackDraft
  public var restEndsAt: Date?
  public var restTotalSeconds: Int
  public var setTimerEndsAt: Date?
  public var setTimerRemaining: Int
  public var reviewExerciseIndexes: [Int]
  public var reviewRestSeconds: Int
  public var exerciseDecisions: [String: String]
  public var warmupStatus: WorkoutWarmupStatus
  public var warmupEndsAt: Date?
  public var warmupRemaining: Int
  public let startedAt: Date

  public init(
    execution: WorkoutExecutionState,
    phase: ActiveWorkoutPhase,
    feedback: ActiveWorkoutFeedbackDraft,
    restEndsAt: Date?,
    restTotalSeconds: Int,
    setTimerEndsAt: Date?,
    setTimerRemaining: Int,
    reviewExerciseIndexes: [Int],
    reviewRestSeconds: Int,
    exerciseDecisions: [String: String],
    warmupStatus: WorkoutWarmupStatus = .notStarted,
    warmupEndsAt: Date? = nil,
    warmupRemaining: Int = 0,
    startedAt: Date
  ) {
    schemaVersion = Self.currentSchemaVersion
    self.execution = execution
    self.phase = phase
    self.feedback = feedback
    self.restEndsAt = restEndsAt
    self.restTotalSeconds = restTotalSeconds
    self.setTimerEndsAt = setTimerEndsAt
    self.setTimerRemaining = setTimerRemaining
    self.reviewExerciseIndexes = reviewExerciseIndexes
    self.reviewRestSeconds = reviewRestSeconds
    self.exerciseDecisions = exerciseDecisions
    self.warmupStatus = warmupStatus
    self.warmupEndsAt = warmupEndsAt
    self.warmupRemaining = warmupRemaining
    self.startedAt = startedAt
  }

  private enum CodingKeys: String, CodingKey {
    case schemaVersion
    case execution
    case phase
    case feedback
    case restEndsAt
    case restTotalSeconds
    case setTimerEndsAt
    case setTimerRemaining
    case reviewExerciseIndexes
    case reviewRestSeconds
    case exerciseDecisions
    case warmupStatus
    case warmupEndsAt
    case warmupRemaining
    case startedAt
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 3
    execution = try container.decode(WorkoutExecutionState.self, forKey: .execution)
    phase = try container.decode(ActiveWorkoutPhase.self, forKey: .phase)
    feedback = try container.decode(ActiveWorkoutFeedbackDraft.self, forKey: .feedback)
    restEndsAt = try container.decodeIfPresent(Date.self, forKey: .restEndsAt)
    restTotalSeconds = try container.decodeIfPresent(Int.self, forKey: .restTotalSeconds) ?? 0
    setTimerEndsAt = try container.decodeIfPresent(Date.self, forKey: .setTimerEndsAt)
    setTimerRemaining = try container.decodeIfPresent(Int.self, forKey: .setTimerRemaining) ?? 0
    reviewExerciseIndexes = try container.decodeIfPresent([Int].self, forKey: .reviewExerciseIndexes) ?? []
    reviewRestSeconds = try container.decodeIfPresent(Int.self, forKey: .reviewRestSeconds) ?? 0
    exerciseDecisions = try container.decodeIfPresent([String: String].self, forKey: .exerciseDecisions) ?? [:]
    warmupStatus = try container.decodeIfPresent(WorkoutWarmupStatus.self, forKey: .warmupStatus) ?? .notStarted
    warmupEndsAt = try container.decodeIfPresent(Date.self, forKey: .warmupEndsAt)
    warmupRemaining = try container.decodeIfPresent(Int.self, forKey: .warmupRemaining) ?? 0
    startedAt = try container.decode(Date.self, forKey: .startedAt)
  }
}
