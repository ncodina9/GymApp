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
          record.healthKitWorkoutUUID == nil,
          isAvailable
    else { return }

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
        "GymAppCompletedSets": execution.records.filter { $0.status == .completed }.count,
        "GymAppSkippedSets": execution.records.filter { $0.status == .skipped }.count
      ])
      try await builder.endCollection(at: record.completedAt)
      guard let workout = try await builder.finishWorkout() else { return }
      record.healthKitWorkoutUUID = workout.uuid.uuidString
      try? context.save()
    } catch {
      // Keep the record unsynced so a later completed workout can retry safely.
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
