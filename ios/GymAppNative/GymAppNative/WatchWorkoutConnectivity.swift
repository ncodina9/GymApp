import Foundation
import WatchConnectivity
import GymAppNativeCore

extension Notification.Name {
  static let watchWorkoutCommandReceived = Notification.Name("watchWorkoutCommandReceived")
  static let watchHealthWorkoutFinished = Notification.Name("watchHealthWorkoutFinished")
}

@MainActor
enum WatchHealthWorkoutRegistry {
  private static let key = "watchLiveHealthWorkoutSessionIDs"

  static func markStarted(_ sessionID: String) {
    var ids = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    ids.insert(sessionID)
    UserDefaults.standard.set(Array(ids), forKey: key)
  }

  static func markFinished(_ sessionID: String) {
    var ids = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    ids.remove(sessionID)
    UserDefaults.standard.set(Array(ids), forKey: key)
  }

  static func isManaging(_ sessionID: String) -> Bool {
    Set(UserDefaults.standard.stringArray(forKey: key) ?? []).contains(sessionID)
  }
}

/// A visible execution view owns its in-memory animation state. When it is not
/// visible, the app-level sync host applies the same Watch command to SwiftData.
@MainActor
final class WatchWorkoutCommandRouter {
  static let shared = WatchWorkoutCommandRouter()
  var handler: ((WatchWorkoutCommand) -> Void)?
}

@MainActor
final class WatchWorkoutConnectivity: NSObject {
  static let shared = WatchWorkoutConnectivity()
  /// The SwiftUI host owns SwiftData queries. A Watch refresh must ask that
  /// host for a new catalog instead of returning a stale in-memory snapshot.
  var stateRefreshHandler: (() -> Void)?

  private enum Key {
    static let workoutState = "workoutState"
    static let appState = "watchWorkoutAppState"
    static let workoutCommandEnvelope = "workoutCommandEnvelope"
    static let workoutCommandAcknowledgement = "workoutCommandAcknowledgement"
    static let persistedAppState = "watchPersistedAppState"
    static let processedCommandDates = "watchProcessedCommandDates"
  }

  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()
  private var didActivate = false
  private var latestState: WatchWorkoutState?
  private var sessions: [TrainingSession] = []
  private var completedSessionIDs: [String] = []
  private var theme = WatchWorkoutTheme(appearance: "system", accent: "blue")
  private var declaredDiscomforts: [String] = []
  private var currentWeek: Int?
  private var weekFocusLabel: String?
  private var recommendedSessionID: String?
  private var processedCommandDates: [UUID: Date] = [:]

  private override init() {
    super.init()
    if let data = UserDefaults.standard.data(forKey: Key.persistedAppState),
       let persisted = try? decoder.decode(WatchWorkoutAppState.self, from: data) {
      latestState = persisted.activeWorkout
      sessions = persisted.sessions
      completedSessionIDs = persisted.completedSessionIDs
      theme = persisted.theme
      currentWeek = persisted.currentWeek
      weekFocusLabel = persisted.weekFocusLabel
      recommendedSessionID = persisted.recommendedSessionID
    }
    if let persistedDates = UserDefaults.standard.dictionary(forKey: Key.processedCommandDates) as? [String: Date] {
      processedCommandDates = persistedDates.reduce(into: [:]) { result, entry in
        guard let id = UUID(uuidString: entry.key) else { return }
        result[id] = entry.value
      }
      pruneProcessedCommands()
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
    activate()
    publishLatestStateIfPossible()
  }

  func publishCatalog(
    sessions: [TrainingSession],
    completedSessionIDs: Set<String>,
    theme: WatchWorkoutTheme,
    declaredDiscomforts: [String],
    currentWeek: Int?,
    weekFocusLabel: String?,
    recommendedSessionID: String?
  ) {
    self.sessions = sessions
    self.completedSessionIDs = Array(completedSessionIDs).sorted()
    self.theme = theme
    self.declaredDiscomforts = declaredDiscomforts
    self.currentWeek = currentWeek
    self.weekFocusLabel = weekFocusLabel
    self.recommendedSessionID = recommendedSessionID
    activate()
    publishLatestStateIfPossible()
  }

  func publish(_ snapshot: ActiveWorkoutSnapshot) {
    let execution = snapshot.execution
    let reviewExercises = snapshot.phase == .exerciseReview
      ? snapshot.reviewExerciseIndexes.compactMap { index -> WatchExerciseReviewItem? in
          guard execution.session.exercises.indices.contains(index) else { return nil }
          let exercise = execution.session.exercises[index]
          let equipment = exercise.sets.first.flatMap { set in
            execution.equipment(for: WorkoutSetLocator(exerciseIndex: index, setIndex: set.setIndex))
          } ?? exercise.equipment
          let isTimed = exercise.sets.first?.type == .timed
          return WatchExerciseReviewItem(
            exerciseID: exercise.exerciseID,
            exerciseName: exercise.displayName,
            equipment: equipment,
            isTimed: isTimed,
            decision: snapshot.exerciseDecisions[exercise.exerciseID]
              ?? (isTimed ? "Mantener tiempo" : "Mantener")
          )
        }
      : []
    let reviewLocator = snapshot.phase == .exerciseReview
      ? snapshot.reviewExerciseIndexes.first.flatMap { index -> WorkoutSetLocator? in
          guard execution.session.exercises.indices.contains(index),
                let set = execution.session.exercises[index].sets.last
          else { return nil }
          return WorkoutSetLocator(exerciseIndex: index, setIndex: set.setIndex)
        }
      : nil
    guard let locator = execution.current ?? reviewLocator,
          let exercise = execution.exercise(for: locator),
          let targets = execution.targets(for: locator)
    else {
      clear()
      return
    }

    let phase: WatchWorkoutState.Phase
    let timerEndsAt: Date?
    if snapshot.warmupStatus == .running {
      phase = .warmup
      timerEndsAt = snapshot.warmupEndsAt
    } else {
      phase = switch snapshot.phase {
      case .workingSet: .workingSet
      case .feedback: .feedback
      case .rest: .rest
      case .exerciseReview: .exerciseReview
      }
      timerEndsAt = snapshot.phase == .rest ? snapshot.restEndsAt : snapshot.setTimerEndsAt
    }
    let supersetExerciseNames = exercise.supersetID.map { supersetID in
      execution.session.exercises
        .filter { $0.supersetID == supersetID }
        .map(\.displayName)
    }
    let selectableEquipment = equipmentOptions(for: exercise).filter {
      execution.canSelectEquipment($0, for: locator)
    }
    let completedExerciseIDs = execution.session.exercises.enumerated().compactMap { index, candidate in
      let isComplete = candidate.sets.allSatisfy { set in
        execution.records.contains {
          $0.locator.exerciseIndex == index && $0.locator.setIndex == set.setIndex
        }
      }
      return isComplete ? candidate.exerciseID : nil
    }
    let currentExerciseHasRecordedSets = execution.records.contains {
      $0.locator.exerciseIndex == locator.exerciseIndex
    }
    let upcomingExercises = execution.session.exercises.enumerated().compactMap { index, candidate -> WatchUpcomingExercise? in
      let hasPendingSet = candidate.sets.contains { set in
        !execution.records.contains {
          $0.locator.exerciseIndex == index && $0.locator.setIndex == set.setIndex
        }
      }
      guard hasPendingSet,
            let nextSet = candidate.sets.first(where: { set in
              !execution.records.contains {
                $0.locator.exerciseIndex == index && $0.locator.setIndex == set.setIndex
              }
            }),
            let nextTargets = execution.targets(for: WorkoutSetLocator(exerciseIndex: index, setIndex: nextSet.setIndex))
      else { return nil }
      let detail: String
      if let seconds = nextTargets.durationSeconds {
        detail = "\(seconds)s"
      } else {
        let weight = nextTargets.weightKg.formatted(
          .number.precision(.fractionLength(0 ... 2)).locale(Locale(identifier: "es_ES"))
        )
        detail = "\(nextTargets.reps ?? 0) reps · \(weight) kg"
      }
      return WatchUpcomingExercise(
        exerciseIndex: index,
        exerciseID: candidate.exerciseID,
        name: candidate.displayName,
        detail: detail
      )
    }
    let historyExercises = execution.session.exercises.enumerated().map { index, candidate in
      WatchWorkoutHistoryExercise(
        exerciseID: candidate.exerciseID,
        name: candidate.displayName,
        sets: candidate.sets.map { set in
          let locator = WorkoutSetLocator(exerciseIndex: index, setIndex: set.setIndex)
          let record = execution.records.first { $0.locator == locator }
          let targets = record.flatMap(execution.targets(for:)) ?? execution.targets(for: locator)
          return WatchWorkoutHistorySet(
            setIndex: set.setIndex,
            reps: targets?.reps,
            weightKg: targets?.weightKg ?? 0,
            durationSeconds: targets?.durationSeconds,
            status: record?.status
          )
        }
      )
    }

    publish(
      WatchWorkoutState(
        sessionID: execution.session.sessionID,
        workoutName: execution.session.label,
        exerciseName: exercise.displayName,
        trainingPhase: exercise.phase,
        weekFocusLabel: execution.session.weekFocusLabel,
        equipment: execution.equipment(for: locator) ?? exercise.equipment,
        equipmentName: (execution.equipment(for: locator) ?? exercise.equipment).executionLabel,
        equipmentOptions: selectableEquipment,
        supersetExerciseNames: supersetExerciseNames,
        completedExerciseIDs: completedExerciseIDs,
        currentExerciseID: execution.current.flatMap { execution.exercise(for: $0)?.exerciseID },
        currentExerciseHasRecordedSets: currentExerciseHasRecordedSets,
        reviewExercises: reviewExercises,
        isFinalExerciseReview: snapshot.phase == .exerciseReview && execution.current == nil,
        feedback: WorkoutSetFeedback(
          rir: snapshot.feedback.rir,
          painKnee: snapshot.feedback.painKnee,
          painWrist: snapshot.feedback.painWrist,
          painShoulder: snapshot.feedback.painShoulder,
          painLowerBack: snapshot.feedback.painLowerBack,
          declaredDiscomfortLevels: snapshot.feedback.declaredDiscomfortLevels,
          note: snapshot.feedback.note
        ),
        declaredDiscomforts: declaredDiscomforts,
        phase: phase,
        completedSetCount: execution.completedSetCount,
        totalSetCount: execution.totalSetCount,
        exerciseSetNumber: locator.setIndex,
        exerciseSetTotal: exercise.sets.count,
        reps: targets.reps,
        weightKg: targets.weightKg,
        durationSeconds: targets.durationSeconds,
        restTotalSeconds: snapshot.restTotalSeconds,
        countdownTotalSeconds: snapshot.warmupStatus == .running
          ? snapshot.warmupRemaining
          : snapshot.phase == .rest ? snapshot.restTotalSeconds : targets.durationSeconds,
        upcomingExercises: upcomingExercises,
        historyExercises: historyExercises,
        timerEndsAt: timerEndsAt
      )
    )
  }

  func clear() {
    latestState = nil
    activate()
    publishLatestStateIfPossible()
  }

  private func equipmentOptions(for exercise: TrainingExercise) -> [Equipment] {
    exercise.selectableEquipmentOptions
  }

  private func publishLatestStateIfPossible() {
    let session = WCSession.default
    guard session.activationState == .activated else { return }

    guard let data = encodedAppState() else { return }
    UserDefaults.standard.set(data, forKey: Key.persistedAppState)
    let context: [String: Any] = [Key.appState: data]

    try? session.updateApplicationContext(context)
    if session.isReachable {
      session.sendMessage(context, replyHandler: nil, errorHandler: nil)
    }
  }

  private func encodedAppState() -> Data? {
    let state = WatchWorkoutAppState(
      sessions: sessions,
      completedSessionIDs: completedSessionIDs,
      activeWorkout: latestState,
      theme: theme,
      currentWeek: currentWeek,
      weekFocusLabel: weekFocusLabel,
      recommendedSessionID: recommendedSessionID
    )
    return try? encoder.encode(state)
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
    receive(commandFrom: message, replyHandler: nil)
  }

  nonisolated func session(
    _ session: WCSession,
    didReceiveMessage message: [String: Any],
    replyHandler: @escaping ([String: Any]) -> Void
  ) {
    receive(commandFrom: message, replyHandler: replyHandler)
  }

  nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    receive(commandFrom: applicationContext, replyHandler: nil)
  }

  nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
    receive(commandFrom: userInfo, replyHandler: nil)
  }

  private nonisolated func receive(
    commandFrom payload: [String: Any],
    replyHandler: (([String: Any]) -> Void)?
  ) {
    guard let data = payload["workoutCommandEnvelope"] as? Data else { return }
    Task { @MainActor in
      guard let envelope = try? self.decoder.decode(WatchWorkoutCommandEnvelope.self, from: data) else {
        return
      }
      let acknowledgement = self.apply(envelope)
      guard let encodedAcknowledgement = try? self.encoder.encode(acknowledgement) else { return }
      var response: [String: Any] = [Key.workoutCommandAcknowledgement: encodedAcknowledgement]
      // NotificationCenter delivers the command synchronously on the main
      // actor. Include the resulting snapshot in every direct reply so the
      // Watch can advance immediately instead of waiting for a second push.
      if let state = self.encodedAppState() {
        response[Key.appState] = state
      }
      replyHandler?(response)
    }
  }

  private func apply(_ envelope: WatchWorkoutCommandEnvelope) -> WatchWorkoutCommandAcknowledgement {
    pruneProcessedCommands()
    if processedCommandDates[envelope.id] != nil {
      return WatchWorkoutCommandAcknowledgement(commandID: envelope.id, result: .duplicate)
    }

    processedCommandDates[envelope.id] = .now
    persistProcessedCommands()
    switch envelope.command {
    case .requestState:
      stateRefreshHandler?()
      publishLatestStateIfPossible()
    case let .watchHealthSessionStarted(sessionID):
      WatchHealthWorkoutRegistry.markStarted(sessionID)
    case let .watchHealthSessionFinished(sessionID, _):
      WatchHealthWorkoutRegistry.markFinished(sessionID)
      NotificationCenter.default.post(name: .watchHealthWorkoutFinished, object: envelope.command)
    default:
      NotificationCenter.default.post(name: .watchWorkoutCommandReceived, object: envelope)
    }
    return WatchWorkoutCommandAcknowledgement(commandID: envelope.id, result: .applied)
  }

  private func pruneProcessedCommands() {
    let cutoff = Date.now.addingTimeInterval(-86_400)
    processedCommandDates = processedCommandDates.filter { $0.value >= cutoff }
    persistProcessedCommands()
  }

  private func persistProcessedCommands() {
    UserDefaults.standard.set(
      Dictionary(uniqueKeysWithValues: processedCommandDates.map { ($0.key.uuidString, $0.value) }),
      forKey: Key.processedCommandDates
    )
  }
}
