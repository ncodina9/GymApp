import Foundation
import HealthKit
import SwiftData
import GymAppNativeCore

@MainActor
enum HealthWorkoutStore {
  static let syncEnabledKey = "healthKitWorkoutSyncEnabled"
  private static let store = HKHealthStore()

  static var isAvailable: Bool {
    HKHealthStore.isHealthDataAvailable()
  }

  static func requestAuthorization() async throws {
    guard isAvailable else { throw HealthWorkoutError.unavailable }
    try await store.requestAuthorization(toShare: [HKObjectType.workoutType()], read: [])
  }

  static func syncIfEnabled(
    record: CompletedWorkoutRecord,
    execution: WorkoutExecutionState,
    in context: ModelContext
  ) async {
    guard UserDefaults.standard.bool(forKey: syncEnabledKey),
          record.healthKitSyncStatus != .synced,
          isAvailable
    else { return }

    record.healthKitSyncStatus = .syncing
    record.healthKitLastAttemptAt = .now
    record.healthKitLastError = nil
    try? context.save()

    do {
      let configuration = HKWorkoutConfiguration()
      configuration.activityType = .traditionalStrengthTraining
      configuration.locationType = .indoor
      let builder = HKWorkoutBuilder(
        healthStore: store,
        configuration: configuration,
        device: .local()
      )
      let start = record.startedAt ?? record.completedAt
      try await builder.beginCollection(at: start)
      try await builder.addMetadata([
        HKMetadataKeyExternalUUID: record.sessionID,
        HKMetadataKeyWorkoutBrandName: "GymApp",
        "GymAppSessionLabel": execution.session.sessionLabel,
        "GymAppRecordVersion": 1,
        "GymAppCompletedSets": execution.records.filter { $0.status == .completed }.count,
        "GymAppSkippedSets": execution.records.filter { $0.status == .skipped }.count
      ])
      try await builder.endCollection(at: record.completedAt)
      guard let workout = try await builder.finishWorkout() else {
        record.healthKitSyncStatus = .failed
        record.healthKitLastError = "Salud no devolvió el entrenamiento guardado."
        try? context.save()
        return
      }
      record.healthKitWorkoutUUID = workout.uuid.uuidString
      record.healthKitSyncStatus = .synced
      record.healthKitLastError = nil
      try? context.save()
    } catch {
      // The completed record remains the editable source of truth; a later app
      // launch retries this same session identifier instead of discarding it.
      record.healthKitSyncStatus = .failed
      record.healthKitLastError = error.localizedDescription
      try? context.save()
    }
  }

  static func syncPendingIfEnabled(
    records: [CompletedWorkoutRecord],
    in context: ModelContext
  ) async {
    guard UserDefaults.standard.bool(forKey: syncEnabledKey), isAvailable else { return }

    for record in records where record.healthKitSyncStatus != .synced {
      guard let data = record.executionData,
            let execution = try? JSONDecoder().decode(WorkoutExecutionState.self, from: data)
      else { continue }
      await syncIfEnabled(record: record, execution: execution, in: context)
    }
  }
}

enum HealthWorkoutError: LocalizedError {
  case unavailable

  var errorDescription: String? {
    switch self {
    case .unavailable: "Salud no está disponible en este dispositivo."
    }
  }
}
