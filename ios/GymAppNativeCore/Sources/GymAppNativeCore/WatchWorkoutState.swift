import Foundation

/// Compact, transport-safe view of the active session for the Apple Watch.
/// The iPhone owns the mutable workout state; this is intentionally a snapshot.
public struct WatchWorkoutState: Codable, Equatable, Sendable {
  public static let schemaVersion = 2

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
  public let equipmentName: String
  public let supersetExerciseNames: [String]?
  public let phase: Phase
  public let completedSetCount: Int
  public let totalSetCount: Int
  public let exerciseSetNumber: Int
  public let exerciseSetTotal: Int
  public let reps: Int?
  public let weightKg: Double
  public let durationSeconds: Int?
  public let timerEndsAt: Date?
  public let updatedAt: Date

  public init(
    sessionID: String,
    workoutName: String,
    exerciseName: String,
    equipmentName: String,
    supersetExerciseNames: [String]? = nil,
    phase: Phase,
    completedSetCount: Int,
    totalSetCount: Int,
    exerciseSetNumber: Int,
    exerciseSetTotal: Int,
    reps: Int?,
    weightKg: Double,
    durationSeconds: Int?,
    timerEndsAt: Date?,
    updatedAt: Date = .now
  ) {
    schemaVersion = Self.schemaVersion
    self.sessionID = sessionID
    self.workoutName = workoutName
    self.exerciseName = exerciseName
    self.equipmentName = equipmentName
    self.supersetExerciseNames = supersetExerciseNames
    self.phase = phase
    self.completedSetCount = completedSetCount
    self.totalSetCount = totalSetCount
    self.exerciseSetNumber = exerciseSetNumber
    self.exerciseSetTotal = exerciseSetTotal
    self.reps = reps
    self.weightKg = weightKg
    self.durationSeconds = durationSeconds
    self.timerEndsAt = timerEndsAt
    self.updatedAt = updatedAt
  }
}

public enum WatchWorkoutCommand: String, Codable, Sendable {
  case requestState
  case addRest15
  case subtractRest15
  case registerSet
  case skipSet
  case startTimedSet
  case pauseTimedSet
  case resetTimedSet
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
