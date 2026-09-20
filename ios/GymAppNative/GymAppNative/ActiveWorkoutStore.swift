import Foundation
import SwiftData
import GymAppNativeCore

enum ActiveWorkoutPhase: String, Codable {
  case workingSet
  case feedback
  case rest
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
  static let currentSchemaVersion = 1

  let schemaVersion: Int
  var execution: WorkoutExecutionState
  var phase: ActiveWorkoutPhase
  var feedback: ActiveWorkoutFeedbackDraft
  var restEndsAt: Date?
  let startedAt: Date

  init(
    execution: WorkoutExecutionState,
    phase: ActiveWorkoutPhase,
    feedback: ActiveWorkoutFeedbackDraft,
    restEndsAt: Date?,
    startedAt: Date
  ) {
    schemaVersion = Self.currentSchemaVersion
    self.execution = execution
    self.phase = phase
    self.feedback = feedback
    self.restEndsAt = restEndsAt
    self.startedAt = startedAt
  }
}

@Model
final class ActiveWorkoutRecord {
  @Attribute(.unique) var id: String
  var snapshotData: Data
  var updatedAt: Date

  init(id: String = ActiveWorkoutStore.recordID, snapshotData: Data, updatedAt: Date = .now) {
    self.id = id
    self.snapshotData = snapshotData
    self.updatedAt = updatedAt
  }
}

@MainActor
enum ActiveWorkoutStore {
  static let recordID = "active-workout"

  static func load(from records: [ActiveWorkoutRecord]) -> ActiveWorkoutSnapshot? {
    guard let record = records.first(where: { $0.id == recordID }),
          let snapshot = try? JSONDecoder().decode(ActiveWorkoutSnapshot.self, from: record.snapshotData),
          snapshot.schemaVersion == ActiveWorkoutSnapshot.currentSchemaVersion
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
}
