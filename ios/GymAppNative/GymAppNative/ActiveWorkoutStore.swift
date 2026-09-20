import Foundation
import SwiftData
import GymAppNativeCore

enum ActiveWorkoutPhase: String, Codable {
  case workingSet
  case feedback
  case rest
  case exerciseReview
}

struct ActiveWorkoutFeedbackDraft: Codable {
  var rir: Int
  var painKnee: Int
  var painWrist: Int
  var painShoulder: Int
  var painLowerBack: Int
  var note: String
}

struct ActiveWorkoutSnapshot: Codable {
  static let currentSchemaVersion = 4

  let schemaVersion: Int
  var execution: WorkoutExecutionState
  var phase: ActiveWorkoutPhase
  var feedback: ActiveWorkoutFeedbackDraft
  var restEndsAt: Date?
  var restTotalSeconds: Int
  var setTimerEndsAt: Date?
  var setTimerRemaining: Int
  var reviewExerciseIndexes: [Int]
  var reviewRestSeconds: Int
  var exerciseDecisions: [String: String]
  let startedAt: Date

  init(
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
    case startedAt
  }

  init(from decoder: Decoder) throws {
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
    startedAt = try container.decode(Date.self, forKey: .startedAt)
  }
}

@Model
final class ActiveWorkoutRecord {
  @Attribute(.unique) var id: String
  var snapshotData: Data
  var updatedAt: Date

  init(id: String = "active-workout", snapshotData: Data, updatedAt: Date = .now) {
    self.id = id
    self.snapshotData = snapshotData
    self.updatedAt = updatedAt
  }
}

@Model
final class CompletedWorkoutRecord {
  @Attribute(.unique) var sessionID: String
  var completedAt: Date

  init(sessionID: String, completedAt: Date = .now) {
    self.sessionID = sessionID
    self.completedAt = completedAt
  }
}

@MainActor
enum ActiveWorkoutStore {
  static let recordID = "active-workout"

  static func load(from records: [ActiveWorkoutRecord]) -> ActiveWorkoutSnapshot? {
    guard let record = records.first(where: { $0.id == recordID }),
          let snapshot = try? JSONDecoder().decode(ActiveWorkoutSnapshot.self, from: record.snapshotData),
          (3 ... ActiveWorkoutSnapshot.currentSchemaVersion).contains(snapshot.schemaVersion)
    else {
      return nil
    }
    return snapshot
  }

  static func save(_ snapshot: ActiveWorkoutSnapshot, in context: ModelContext) {
    guard let data = try? JSONEncoder().encode(snapshot) else { return }

    let descriptor = FetchDescriptor<ActiveWorkoutRecord>(
      predicate: #Predicate { $0.id == recordID }
    )
    if let record = try? context.fetch(descriptor).first {
      record.snapshotData = data
      record.updatedAt = .now
    } else {
      context.insert(ActiveWorkoutRecord(snapshotData: data))
    }

    try? context.save()
  }

  static func clear(in context: ModelContext) {
    let descriptor = FetchDescriptor<ActiveWorkoutRecord>(
      predicate: #Predicate { $0.id == recordID }
    )
    guard let records = try? context.fetch(descriptor) else { return }
    records.forEach(context.delete)
    try? context.save()
  }

  static func markCompleted(sessionID: String, in context: ModelContext) {
    let descriptor = FetchDescriptor<CompletedWorkoutRecord>(
      predicate: #Predicate { $0.sessionID == sessionID }
    )
    guard (try? context.fetch(descriptor).first) == nil else { return }
    context.insert(CompletedWorkoutRecord(sessionID: sessionID))
    try? context.save()
  }
}
