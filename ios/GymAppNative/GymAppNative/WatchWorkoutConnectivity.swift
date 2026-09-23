import Foundation
import WatchConnectivity
import GymAppNativeCore

extension Notification.Name {
  static let watchWorkoutCommandReceived = Notification.Name("watchWorkoutCommandReceived")
}

@MainActor
final class WatchWorkoutConnectivity: NSObject {
  static let shared = WatchWorkoutConnectivity()

  private enum Key {
    static let workoutState = "workoutState"
    static let workoutCommand = "workoutCommand"
    static let persistedWorkoutState = "watchPersistedWorkoutState"
  }

  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()
  private var didActivate = false
  private var latestState: WatchWorkoutState?

  private override init() {
    super.init()
    if let data = UserDefaults.standard.data(forKey: Key.persistedWorkoutState) {
      latestState = try? decoder.decode(WatchWorkoutState.self, from: data)
    }
  }

  func activate() {
    guard !didActivate, WCSession.isSupported() else { return }
    didActivate = true
    let session = WCSession.default
    session.delegate = self
    session.activate()
  }

  func publish(_ state: WatchWorkoutState) {
    latestState = state
    if let data = try? encoder.encode(state) {
      UserDefaults.standard.set(data, forKey: Key.persistedWorkoutState)
    }
    activate()
    publishLatestStateIfPossible()
  }

  func publish(_ snapshot: ActiveWorkoutSnapshot) {
    let execution = snapshot.execution
    guard let locator = execution.current,
          let exercise = execution.exercise(for: locator),
          let targets = execution.targets(for: locator)
    else {
      clear()
      return
    }

    let phase: WatchWorkoutState.Phase = switch snapshot.phase {
    case .workingSet: .workingSet
    case .feedback: .feedback
    case .rest: .rest
    case .exerciseReview: .exerciseReview
    }
    let timerEndsAt = snapshot.phase == .rest
      ? snapshot.restEndsAt
      : snapshot.setTimerEndsAt

    publish(
      WatchWorkoutState(
        sessionID: execution.session.sessionID,
        workoutName: execution.session.label,
        exerciseName: exercise.name,
        equipmentName: (execution.equipment(for: locator) ?? exercise.equipment).executionLabel,
        phase: phase,
        completedSetCount: execution.completedSetCount,
        totalSetCount: execution.totalSetCount,
        exerciseSetNumber: locator.setIndex,
        exerciseSetTotal: exercise.sets.count,
        reps: targets.reps,
        weightKg: targets.weightKg,
        durationSeconds: targets.durationSeconds,
        timerEndsAt: timerEndsAt
      )
    )
  }

  func clear() {
    latestState = nil
    UserDefaults.standard.removeObject(forKey: Key.persistedWorkoutState)
    activate()
    publishLatestStateIfPossible()
  }

  private func publishLatestStateIfPossible() {
    let session = WCSession.default
    guard session.activationState == .activated else { return }

    let context: [String: Any]
    if let latestState,
       let data = try? encoder.encode(latestState) {
      context = [Key.workoutState: data]
    } else {
      context = [:]
    }

    try? session.updateApplicationContext(context)
    if session.isReachable, !context.isEmpty {
      session.sendMessage(context, replyHandler: nil, errorHandler: nil)
    }
  }
}

extension WatchWorkoutConnectivity: WCSessionDelegate {
  nonisolated func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    Task { @MainActor in
      self.publishLatestStateIfPossible()
    }
  }

  nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

  nonisolated func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }

  nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    receive(commandFrom: message)
  }

  nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    receive(commandFrom: applicationContext)
  }

  private nonisolated func receive(commandFrom payload: [String: Any]) {
    guard let data = payload["workoutCommand"] as? Data else { return }

    Task { @MainActor in
      guard let command = try? self.decoder.decode(WatchWorkoutCommand.self, from: data) else { return }
      if command == .requestState {
        self.publishLatestStateIfPossible()
      } else {
        NotificationCenter.default.post(name: .watchWorkoutCommandReceived, object: command)
      }
    }
  }
}
