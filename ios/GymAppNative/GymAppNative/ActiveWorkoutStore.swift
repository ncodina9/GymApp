import Foundation
import SwiftData
import GymAppNativeCore

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
  var startedAt: Date?
  var executionData: Data?
  var decisionsData: Data?
  var importedSessionData: Data?
  var healthKitWorkoutUUID: String?

  init(
    sessionID: String,
    startedAt: Date?,
    completedAt: Date = .now,
    executionData: Data? = nil,
    decisionsData: Data? = nil,
    importedSessionData: Data? = nil,
    healthKitWorkoutUUID: String? = nil
  ) {
    self.sessionID = sessionID
    self.startedAt = startedAt
    self.completedAt = completedAt
    self.executionData = executionData
    self.decisionsData = decisionsData
    self.importedSessionData = importedSessionData
    self.healthKitWorkoutUUID = healthKitWorkoutUUID
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

  static func markCompleted(
    sessionID: String,
    startedAt: Date,
    completedAt: Date,
    execution: WorkoutExecutionState,
    decisions: [String: String],
    in context: ModelContext
  ) -> CompletedWorkoutRecord? {
    let descriptor = FetchDescriptor<CompletedWorkoutRecord>(
      predicate: #Predicate { $0.sessionID == sessionID }
    )
    if let existing = try? context.fetch(descriptor).first { return existing }
    let record = CompletedWorkoutRecord(
        sessionID: sessionID,
        startedAt: startedAt,
        completedAt: completedAt,
        executionData: try? JSONEncoder().encode(execution),
        decisionsData: try? JSONEncoder().encode(decisions)
      )
    context.insert(record)
    try? context.save()
    return record
  }
}
