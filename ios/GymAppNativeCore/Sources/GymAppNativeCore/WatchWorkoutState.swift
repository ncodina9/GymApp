import Foundation

/// Compact, transport-safe view of the active session for the Apple Watch.
/// The iPhone owns the mutable workout state; this is intentionally a snapshot.
public struct WatchWorkoutState: Codable, Equatable, Sendable {
  public static let schemaVersion = 10

  public enum Phase: String, Codable, Sendable {
    case workingSet
    case feedback
    case rest
    case exerciseReview
    case warmup
  }

  public let schemaVersion: Int
  public let sessionID: String
  public let workoutName: String
  public let exerciseName: String
  public let equipment: Equipment
  public let equipmentName: String
  public let equipmentOptions: [Equipment]?
  public let supersetExerciseNames: [String]?
  public let completedExerciseIDs: [String]
  public let currentExerciseID: String?
  public let currentExerciseHasRecordedSets: Bool
  public let reviewExercises: [WatchExerciseReviewItem]
  public let isFinalExerciseReview: Bool
  public let feedback: WorkoutSetFeedback
  public let phase: Phase
  public let completedSetCount: Int
  public let totalSetCount: Int
  public let exerciseSetNumber: Int
  public let exerciseSetTotal: Int
  public let reps: Int?
  public let weightKg: Double
  public let durationSeconds: Int?
  public let restTotalSeconds: Int
  public let timerEndsAt: Date?
  public let updatedAt: Date

  public init(
    sessionID: String,
    workoutName: String,
    exerciseName: String,
    equipment: Equipment,
    equipmentName: String,
    equipmentOptions: [Equipment]? = nil,
    supersetExerciseNames: [String]? = nil,
    completedExerciseIDs: [String] = [],
    currentExerciseID: String? = nil,
    currentExerciseHasRecordedSets: Bool = false,
    reviewExercises: [WatchExerciseReviewItem] = [],
    isFinalExerciseReview: Bool = false,
    feedback: WorkoutSetFeedback = .ok,
    phase: Phase,
    completedSetCount: Int,
    totalSetCount: Int,
    exerciseSetNumber: Int,
    exerciseSetTotal: Int,
    reps: Int?,
    weightKg: Double,
    durationSeconds: Int?,
    restTotalSeconds: Int = 0,
    timerEndsAt: Date?,
    updatedAt: Date = .now
  ) {
    schemaVersion = Self.schemaVersion
    self.sessionID = sessionID
    self.workoutName = workoutName
    self.exerciseName = exerciseName
    self.equipment = equipment
    self.equipmentName = equipmentName
    self.equipmentOptions = equipmentOptions
    self.supersetExerciseNames = supersetExerciseNames
    self.completedExerciseIDs = completedExerciseIDs
    self.currentExerciseID = currentExerciseID
    self.currentExerciseHasRecordedSets = currentExerciseHasRecordedSets
    self.reviewExercises = reviewExercises
    self.isFinalExerciseReview = isFinalExerciseReview
    self.feedback = feedback
    self.phase = phase
    self.completedSetCount = completedSetCount
    self.totalSetCount = totalSetCount
    self.exerciseSetNumber = exerciseSetNumber
    self.exerciseSetTotal = exerciseSetTotal
    self.reps = reps
    self.weightKg = weightKg
    self.durationSeconds = durationSeconds
    self.restTotalSeconds = restTotalSeconds
    self.timerEndsAt = timerEndsAt
    self.updatedAt = updatedAt
  }
}

public struct WatchExerciseReviewItem: Codable, Equatable, Sendable, Identifiable {
  public let exerciseID: String
  public let exerciseName: String
  public let equipment: Equipment
  public let isTimed: Bool
  public let decision: String

  public var id: String { exerciseID }

  public init(
    exerciseID: String,
    exerciseName: String,
    equipment: Equipment,
    isTimed: Bool,
    decision: String
  ) {
    self.exerciseID = exerciseID
    self.exerciseName = exerciseName
    self.equipment = equipment
    self.isTimed = isTimed
    self.decision = decision
  }
}

/// The visual settings that are meaningful on a small Watch canvas. The raw
/// values deliberately mirror the persisted iPhone choices instead of making
/// watchOS depend on UIKit's theme implementation.
public struct WatchWorkoutTheme: Codable, Equatable, Sendable {
  public let appearance: String
  public let accent: String
  public let premiumScheme: String?

  public init(appearance: String, accent: String, premiumScheme: String? = nil) {
    self.appearance = appearance
    self.accent = accent
    self.premiumScheme = premiumScheme
  }
}

/// The Watch receives the scheduled sessions too, not only a running session.
/// TrainingSession stays the source data so the preflight screen can show the
/// actual first set without inventing a second planning model.
public struct WatchWorkoutAppState: Codable, Sendable {
  public static let schemaVersion = 1

  public let schemaVersion: Int
  public let sessions: [TrainingSession]
  public let completedSessionIDs: [String]
  public let activeWorkout: WatchWorkoutState?
  public let theme: WatchWorkoutTheme
  public let updatedAt: Date

  public init(
    sessions: [TrainingSession],
    completedSessionIDs: [String],
    activeWorkout: WatchWorkoutState?,
    theme: WatchWorkoutTheme,
    updatedAt: Date = .now
  ) {
    schemaVersion = Self.schemaVersion
    self.sessions = sessions
    self.completedSessionIDs = completedSessionIDs
    self.activeWorkout = activeWorkout
    self.theme = theme
    self.updatedAt = updatedAt
  }
}

public enum WatchWorkoutCommand: Codable, Sendable, Equatable {
  case requestState
  case startWorkout(sessionID: String)
  case startWarmup(sessionID: String)
  case prioritizeExercise(sessionID: String, exerciseIndex: Int)
  case replaceActiveWorkout(sessionID: String, startsWithWarmup: Bool, exerciseIndex: Int?)
  case addRest15
  case subtractRest15
  case continueAfterTimer
  case registerSet
  case skipSet
  case startTimedSet
  case pauseTimedSet
  case resetTimedSet
  case updateWorkingSet(reps: Int?, weightKg: Double)
  case selectEquipment(Equipment)
  case submitSetFeedback(WorkoutSetFeedback)
  case submitExerciseReview(decisions: [String: String])

  private enum CodingKeys: String, CodingKey {
    case kind, sessionID, exerciseIndex, startsWithWarmup, reps, weightKg, equipment, feedback, decisions
  }

  private enum Kind: String, Codable {
    case requestState, startWorkout, startWarmup, prioritizeExercise, replaceActiveWorkout
    case addRest15, subtractRest15, continueAfterTimer, registerSet, skipSet
    case startTimedSet, pauseTimedSet, resetTimedSet, updateWorkingSet, selectEquipment, submitSetFeedback, submitExerciseReview
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    switch try container.decode(Kind.self, forKey: .kind) {
    case .requestState: self = .requestState
    case .startWorkout: self = .startWorkout(sessionID: try container.decode(String.self, forKey: .sessionID))
    case .startWarmup: self = .startWarmup(sessionID: try container.decode(String.self, forKey: .sessionID))
    case .prioritizeExercise:
      self = .prioritizeExercise(
        sessionID: try container.decode(String.self, forKey: .sessionID),
        exerciseIndex: try container.decode(Int.self, forKey: .exerciseIndex)
      )
    case .replaceActiveWorkout:
      self = .replaceActiveWorkout(
        sessionID: try container.decode(String.self, forKey: .sessionID),
        startsWithWarmup: try container.decode(Bool.self, forKey: .startsWithWarmup),
        exerciseIndex: try container.decodeIfPresent(Int.self, forKey: .exerciseIndex)
      )
    case .addRest15: self = .addRest15
    case .subtractRest15: self = .subtractRest15
    case .continueAfterTimer: self = .continueAfterTimer
    case .registerSet: self = .registerSet
    case .skipSet: self = .skipSet
    case .startTimedSet: self = .startTimedSet
    case .pauseTimedSet: self = .pauseTimedSet
    case .resetTimedSet: self = .resetTimedSet
    case .updateWorkingSet:
      self = .updateWorkingSet(
        reps: try container.decodeIfPresent(Int.self, forKey: .reps),
        weightKg: try container.decode(Double.self, forKey: .weightKg)
      )
    case .selectEquipment:
      self = .selectEquipment(try container.decode(Equipment.self, forKey: .equipment))
    case .submitSetFeedback:
      self = .submitSetFeedback(try container.decode(WorkoutSetFeedback.self, forKey: .feedback))
    case .submitExerciseReview:
      self = .submitExerciseReview(decisions: try container.decode([String: String].self, forKey: .decisions))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .requestState:
      try container.encode(Kind.requestState, forKey: .kind)
    case let .startWorkout(sessionID):
      try container.encode(Kind.startWorkout, forKey: .kind)
      try container.encode(sessionID, forKey: .sessionID)
    case let .startWarmup(sessionID):
      try container.encode(Kind.startWarmup, forKey: .kind)
      try container.encode(sessionID, forKey: .sessionID)
    case let .prioritizeExercise(sessionID, exerciseIndex):
      try container.encode(Kind.prioritizeExercise, forKey: .kind)
      try container.encode(sessionID, forKey: .sessionID)
      try container.encode(exerciseIndex, forKey: .exerciseIndex)
    case let .replaceActiveWorkout(sessionID, startsWithWarmup, exerciseIndex):
      try container.encode(Kind.replaceActiveWorkout, forKey: .kind)
      try container.encode(sessionID, forKey: .sessionID)
      try container.encode(startsWithWarmup, forKey: .startsWithWarmup)
      try container.encodeIfPresent(exerciseIndex, forKey: .exerciseIndex)
    case .addRest15: try container.encode(Kind.addRest15, forKey: .kind)
    case .subtractRest15: try container.encode(Kind.subtractRest15, forKey: .kind)
    case .continueAfterTimer: try container.encode(Kind.continueAfterTimer, forKey: .kind)
    case .registerSet: try container.encode(Kind.registerSet, forKey: .kind)
    case .skipSet: try container.encode(Kind.skipSet, forKey: .kind)
    case .startTimedSet: try container.encode(Kind.startTimedSet, forKey: .kind)
    case .pauseTimedSet: try container.encode(Kind.pauseTimedSet, forKey: .kind)
    case .resetTimedSet: try container.encode(Kind.resetTimedSet, forKey: .kind)
    case let .updateWorkingSet(reps, weightKg):
      try container.encode(Kind.updateWorkingSet, forKey: .kind)
      try container.encodeIfPresent(reps, forKey: .reps)
      try container.encode(weightKg, forKey: .weightKg)
    case let .selectEquipment(equipment):
      try container.encode(Kind.selectEquipment, forKey: .kind)
      try container.encode(equipment, forKey: .equipment)
    case let .submitSetFeedback(feedback):
      try container.encode(Kind.submitSetFeedback, forKey: .kind)
      try container.encode(feedback, forKey: .feedback)
    case let .submitExerciseReview(decisions):
      try container.encode(Kind.submitExerciseReview, forKey: .kind)
      try container.encode(decisions, forKey: .decisions)
    }
  }
}

/// A command is intentionally separate from the latest workout snapshot. The
/// identifier lets the iPhone acknowledge it once and discard retries safely.
public struct WatchWorkoutCommandEnvelope: Codable, Equatable, Sendable {
  public let id: UUID
  public let command: WatchWorkoutCommand
  public let sentAt: Date

  public init(id: UUID = UUID(), command: WatchWorkoutCommand, sentAt: Date = .now) {
    self.id = id
    self.command = command
    self.sentAt = sentAt
  }
}

public enum WatchWorkoutCommandResult: String, Codable, Sendable {
  case applied
  case duplicate
  case rejected
}

public struct WatchWorkoutCommandAcknowledgement: Codable, Equatable, Sendable {
  public let commandID: UUID
  public let result: WatchWorkoutCommandResult

  public init(commandID: UUID, result: WatchWorkoutCommandResult) {
    self.commandID = commandID
    self.result = result
  }
}
