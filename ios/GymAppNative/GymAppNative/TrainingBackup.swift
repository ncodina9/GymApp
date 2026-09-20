import Foundation
import SwiftData
import GymAppNativeCore

/// Versioned interchange format shared with the PWA. Imported sessions are kept
/// as their original payload so later native versions can read newly added fields.
enum TrainingBackup {
  static let schemaName = "gymapp.full-training-data-export"
  static let schemaVersion = 1

  struct Export: Codable {
    let schemaName: String
    let schemaVersion: Int
    let exportedAt: String
    let app: AppInfo
    let source: Source
    let plan: JSONValue
    let settings: Settings
    let activeWorkout: ActiveWorkout?
    let sessions: [Session]
  }

  struct AppInfo: Codable { let name: String; let version: String }
  struct Source: Codable { let platform: String; let localStores: [String] }
  struct Settings: Codable { let appearanceTheme: String; let keepScreenAwake: Bool }

  struct ActiveWorkout: Codable {
    let selectedSessionId: String
    let phase: String
    let exerciseIndex: Int
    let setIndex: Int
    let startedAt: String?
  }

  struct Session: Codable {
    let sessionId: String
    let sessionDate: String?
    let sessionLabel: String?
    let planSession: TrainingSession?
    let summary: Summary?
    let metadata: Metadata?
    let decisions: [String: String]?
    let events: [Event]?
  }

  struct Summary: Codable {
    let sessionId: String
    let sessionDate: String?
    let sessionLabel: String?
    let estimatedMinutes: Int?
    let derivedEstimatedMinutes: Int?
    let attemptedSets: Int?
    let completedSets: Int?
    let totalSets: Int?
    let schemaVersion: Int?
    let startedAt: String?
    let finishedAt: String?
    let exportedAt: String?
    let firstPerformedAt: String?
    let lastPerformedAt: String?
  }

  struct Metadata: Codable { let startedAt: String?; let finishedAt: String? }

  struct Event: Codable {
    let id: String
    let performedAt: String
    let planId: String
    let sessionId: String
    let sessionDate: String
    let exerciseId: String
    let exerciseIndex: Int
    let setIndex: Int
    let supersetId: String?
    let supersetOrder: Int?
    let roundNumber: Int?
    let plannedReps: Int?
    let plannedWeightKg: Double?
    let plannedDurationSeconds: Int?
    let plannedEquipment: String?
    let actualReps: Int?
    let actualWeightKg: Double?
    let actualDurationSeconds: Int?
    let actualEquipment: String?
    let restSecondsPlanned: Int?
    let restSecondsActual: Int?
    let status: String
    let rirLast: Int?
    let painKnee: Int
    let painWrist: Int
    let painShoulder: Int?
    let painLowerBack: Int?
    let painOther: JSONValue?
    let note: String?
  }

  struct ImportResult { let imported: Int; let duplicates: Int }

  indirect enum JSONValue: Codable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      if container.decodeNil() { self = .null }
      else if let value = try? container.decode(Bool.self) { self = .bool(value) }
      else if let value = try? container.decode(Double.self) { self = .number(value) }
      else if let value = try? container.decode(String.self) { self = .string(value) }
      else if let value = try? container.decode([String: JSONValue].self) { self = .object(value) }
      else { self = .array(try container.decode([JSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.singleValueContainer()
      switch self {
      case let .object(value): try container.encode(value)
      case let .array(value): try container.encode(value)
      case let .string(value): try container.encode(value)
      case let .number(value): try container.encode(value)
      case let .bool(value): try container.encode(value)
      case .null: try container.encodeNil()
      }
    }

    func removingNativeOnlyPlanFields() -> JSONValue {
      switch self {
      case let .object(value):
        return .object(value.reduce(into: [:]) { result, item in
          guard item.key != "sourceDocument", item.key != "equipmentOptions" else { return }
          result[item.key] = item.value.removingNativeOnlyPlanFields()
        })
      case let .array(value): return .array(value.map { $0.removingNativeOnlyPlanFields() })
      default: return self
      }
    }
  }

  @MainActor
  static func write(
    plan: TrainingPlan,
    appearanceTheme: String,
    keepScreenAwake: Bool,
    activeWorkout: ActiveWorkoutSnapshot?,
    completedRecords: [CompletedWorkoutRecord],
    appVersion: String
  ) throws -> URL {
    let activeState: ActiveWorkout? = if let activeWorkout { activeBackup(activeWorkout) } else { nil }
    let backup = Export(
      schemaName: schemaName,
      schemaVersion: schemaVersion,
      exportedAt: timestamp(.now),
      app: AppInfo(name: "GymAppNative", version: appVersion),
      source: Source(platform: "ios", localStores: ["SwiftData:activeWorkout", "SwiftData:completedWorkouts"]),
      plan: try JSONDecoder()
        .decode(JSONValue.self, from: JSONEncoder().encode(plan))
        .removingNativeOnlyPlanFields(),
      settings: Settings(appearanceTheme: appearanceTheme, keepScreenAwake: keepScreenAwake),
      activeWorkout: activeState,
      sessions: completedRecords.compactMap { session(from: $0, plan: plan) }
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("gymapp-full-training-backup.json")
    try encoder.encode(backup).write(to: url, options: .atomic)
    return url
  }

  static func validate(_ data: Data) throws -> Export {
    let backup = try JSONDecoder().decode(Export.self, from: data)
    guard backup.schemaName == schemaName else { throw BackupError.unsupportedSchema }
    guard backup.schemaVersion == schemaVersion else { throw BackupError.unsupportedVersion }
    return backup
  }

  @MainActor
  static func importBackup(_ data: Data, into context: ModelContext) throws -> ImportResult {
    let backup = try validate(data)
    var existing = Set((try context.fetch(FetchDescriptor<CompletedWorkoutRecord>())).map(\.sessionID))
    var imported = 0
    var duplicates = 0
    for session in backup.sessions {
      guard !existing.contains(session.sessionId) else { duplicates += 1; continue }
      context.insert(CompletedWorkoutRecord(
        sessionID: session.sessionId,
        startedAt: date(session.metadata?.startedAt ?? session.summary?.startedAt),
        completedAt: date(session.metadata?.finishedAt ?? session.summary?.finishedAt) ?? .now,
        decisionsData: try? JSONEncoder().encode(session.decisions ?? [:]),
        importedSessionData: try JSONEncoder().encode(session)
      ))
      existing.insert(session.sessionId)
      imported += 1
    }
    try context.save()
    return ImportResult(imported: imported, duplicates: duplicates)
  }

  private static func session(from record: CompletedWorkoutRecord, plan: TrainingPlan) -> Session? {
    if record.executionData == nil,
       let data = record.importedSessionData,
       let imported = try? JSONDecoder().decode(Session.self, from: data) { return imported }
    guard let data = record.executionData,
          let execution = try? JSONDecoder().decode(WorkoutExecutionState.self, from: data) else { return nil }
    let records = execution.records.sorted { $0.performedAt < $1.performedAt }
    let events = records.compactMap { event(from: $0, execution: execution, plan: plan) }
    let startedAt: String? = if let startedAt = record.startedAt { timestamp(startedAt) } else { nil }
    let finishedAt = timestamp(record.completedAt)
    return Session(
      sessionId: execution.session.sessionID,
      sessionDate: execution.session.date,
      sessionLabel: execution.session.sessionLabel,
      planSession: execution.session,
      summary: Summary(
        sessionId: execution.session.sessionID,
        sessionDate: execution.session.date,
        sessionLabel: execution.session.sessionLabel,
        estimatedMinutes: execution.session.estimatedMinutes,
        derivedEstimatedMinutes: execution.session.estimatedMinutes,
        attemptedSets: records.count,
        completedSets: records.filter { $0.status == .completed }.count,
        totalSets: execution.totalSetCount,
        schemaVersion: 1,
        startedAt: startedAt,
        finishedAt: finishedAt,
        exportedAt: timestamp(.now),
        firstPerformedAt: records.first.map { timestamp($0.performedAt) },
        lastPerformedAt: records.last.map { timestamp($0.performedAt) }
      ),
      metadata: Metadata(startedAt: startedAt, finishedAt: finishedAt),
      decisions: decodedDecisions(record),
      events: events
    )
  }

  private static func activeBackup(_ snapshot: ActiveWorkoutSnapshot) -> ActiveWorkout {
    let locator = snapshot.execution.current ?? WorkoutSetLocator(exerciseIndex: 0, setIndex: 0)
    return ActiveWorkout(selectedSessionId: snapshot.execution.session.sessionID, phase: snapshot.phase.rawValue, exerciseIndex: locator.exerciseIndex, setIndex: locator.setIndex, startedAt: timestamp(snapshot.startedAt))
  }

  private static func event(from record: WorkoutSetRecord, execution: WorkoutExecutionState, plan: TrainingPlan) -> Event? {
    guard let exercise = execution.exercise(for: record.locator),
          let targets = execution.targets(for: record.locator),
          let plannedSet = execution.trainingSet(for: record.locator) else { return nil }
    let equipment = execution.equipment(for: record.locator) ?? exercise.equipment
    let isTimed = targets.durationSeconds != nil
    let isSkipped = record.status == .skipped
    return Event(
      id: "\(execution.session.sessionID)-\(exercise.exerciseID)-\(record.locator.setIndex)-\(Int(record.performedAt.timeIntervalSince1970 * 1000))",
      performedAt: timestamp(record.performedAt), planId: plan.planID, sessionId: execution.session.sessionID, sessionDate: execution.session.date,
      exerciseId: exercise.exerciseID, exerciseIndex: record.locator.exerciseIndex, setIndex: record.locator.setIndex,
      supersetId: exercise.supersetID, supersetOrder: exercise.supersetOrder, roundNumber: plannedSet.setIndex,
      plannedReps: plannedSet.targetReps, plannedWeightKg: plannedSet.targetWeightKg, plannedDurationSeconds: plannedSet.targetDurationSeconds,
      plannedEquipment: exercise.equipment.rawValue, actualReps: isSkipped || isTimed ? nil : targets.reps,
      actualWeightKg: isSkipped || equipment == .bodyweight ? nil : targets.weightKg,
      actualDurationSeconds: isSkipped ? nil : targets.durationSeconds, actualEquipment: equipment.rawValue,
      restSecondsPlanned: plannedSet.restSeconds, restSecondsActual: plannedSet.restSeconds,
      status: isSkipped ? "skipped" : "completed", rirLast: isSkipped || isTimed ? nil : record.feedback.rir,
      painKnee: record.feedback.painKnee, painWrist: record.feedback.painWrist, painShoulder: record.feedback.painShoulder,
      painLowerBack: record.feedback.painLowerBack, painOther: nil, note: record.feedback.note
    )
  }

  private static func decodedDecisions(_ record: CompletedWorkoutRecord) -> [String: String] {
    guard let data = record.decisionsData else { return [:] }
    return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
  }

  private static func timestamp(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }

  private static func date(_ value: String?) -> Date? {
    guard let value else { return nil }
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
  }

  enum BackupError: LocalizedError {
    case unsupportedSchema
    case unsupportedVersion
    case noFilePermission
    var errorDescription: String? {
      switch self {
      case .unsupportedSchema: "El archivo no es un backup de GymApp compatible."
      case .unsupportedVersion: "La versión del backup no es compatible con esta app."
      case .noFilePermission: "No se puede leer el archivo seleccionado."
      }
    }
  }
}
