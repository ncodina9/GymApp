import Foundation
import HealthKit
import Combine

@MainActor
final class WatchLiveHealthWorkoutManager: NSObject, ObservableObject {
  @Published private(set) var isRunning = false
  @Published private(set) var activeEnergyKilocalories: Double = 0
  @Published private(set) var heartRate: Double?

  private let healthStore = HKHealthStore()
  private var workoutSession: HKWorkoutSession?
  private var builder: HKLiveWorkoutBuilder?
  private var sessionID: String?
  private var isFinishing = false

  func begin(sessionID: String, onStarted: @escaping () -> Void) {
    guard self.sessionID != sessionID else { return }
    guard workoutSession == nil else { return }
    Task { await start(sessionID: sessionID, onStarted: onStarted) }
  }

  func finishIfNeeded(sessionID: String?, onFinished: @escaping (String, String) -> Void) {
    guard let activeID = self.sessionID,
          workoutSession != nil,
          !isFinishing,
          sessionID == nil || sessionID != activeID
    else { return }
    isFinishing = true
    Task { await finish(activeSessionID: activeID, onFinished: onFinished) }
  }

  private func start(sessionID: String, onStarted: @escaping () -> Void) async {
    guard HKHealthStore.isHealthDataAvailable() else { return }
    let configuration = HKWorkoutConfiguration()
    configuration.activityType = .traditionalStrengthTraining
    configuration.locationType = .indoor

    do {
      let energy = HKQuantityType(.activeEnergyBurned)
      let heartRateQuantity = HKQuantityType(.heartRate)
      try await healthStore.requestAuthorization(
        toShare: [HKObjectType.workoutType(), energy],
        read: [heartRateQuantity]
      )

      let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
      let builder = session.associatedWorkoutBuilder()
      builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
      session.delegate = self
      builder.delegate = self
      self.sessionID = sessionID
      workoutSession = session
      self.builder = builder
      activeEnergyKilocalories = 0
      heartRate = nil
      let startedAt = Date.now
      session.startActivity(with: startedAt)
      try await builder.beginCollection(at: startedAt)
      isRunning = true
      onStarted()
    } catch {
      reset()
    }
  }

  private func finish(activeSessionID: String, onFinished: @escaping (String, String) -> Void) async {
    guard let session = workoutSession, let builder else {
      reset()
      return
    }
    session.end()
    do {
      try await builder.endCollection(at: .now)
      try await builder.addMetadata([
        HKMetadataKeyExternalUUID: activeSessionID,
        HKMetadataKeyWorkoutBrandName: "GymApp",
        "GymAppRecordVersion": 1
      ])
      if let workout = try await builder.finishWorkout() {
        let uuid = workout.uuid.uuidString
        reset()
        onFinished(activeSessionID, uuid)
      } else {
        reset()
      }
    } catch {
      reset()
    }
  }

  private func reset() {
    workoutSession = nil
    builder = nil
    sessionID = nil
    isFinishing = false
    isRunning = false
    heartRate = nil
    activeEnergyKilocalories = 0
  }
}

extension WatchLiveHealthWorkoutManager: HKWorkoutSessionDelegate {
  nonisolated func workoutSession(
    _ workoutSession: HKWorkoutSession,
    didChangeTo toState: HKWorkoutSessionState,
    from fromState: HKWorkoutSessionState,
    date: Date
  ) {}

  nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
    Task { @MainActor in self.reset() }
  }
}

extension WatchLiveHealthWorkoutManager: HKLiveWorkoutBuilderDelegate {
  nonisolated func workoutBuilder(
    _ workoutBuilder: HKLiveWorkoutBuilder,
    didCollectDataOf collectedTypes: Set<HKSampleType>
  ) {
    Task { @MainActor in
      if collectedTypes.contains(HKQuantityType(.activeEnergyBurned)),
         let energy = workoutBuilder.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity() {
        self.activeEnergyKilocalories = energy.doubleValue(for: .kilocalorie())
      }
      if collectedTypes.contains(HKQuantityType(.heartRate)),
         let heartRate = workoutBuilder.statistics(for: HKQuantityType(.heartRate))?.mostRecentQuantity() {
        self.heartRate = heartRate.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
      }
    }
  }

  nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
