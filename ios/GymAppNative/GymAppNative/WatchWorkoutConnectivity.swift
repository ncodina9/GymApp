import Foundation
import WatchConnectivity
import GymAppNativeCore

extension Notification.Name {
  static let watchWorkoutCommandReceived = Notification.Name("watchWorkoutCommandReceived")
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

  private enum Key {
    static let workoutState = "workoutState"
    static let appState = "watchWorkoutAppState"
    static let workoutCommandEnvelope = "workoutCommandEnvelope"
    static let workoutCommandAcknowledgement = "workoutCommandAcknowledgement"
    static let persistedAppState = "watchPersistedAppState"
  }

  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()
  private var didActivate = false
  private var latestState: WatchWorkoutState?
  private var sessions: [TrainingSession] = []
  private var completedSessionIDs: [String] = []
  private var theme = WatchWorkoutTheme(appearance: "system", accent: "blue")
  private var processedCommandDates: [UUID: Date] = [:]

  private override init() {
    super.init()
    if let data = UserDefaults.standard.data(forKey: Key.persistedAppState),
       let persisted = try? decoder.decode(WatchWorkoutAppState.self, from: data) {
      latestState = persisted.activeWorkout
      sessions = persisted.sessions
      completedSessionIDs = persisted.completedSessionIDs
      theme = persisted.theme
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
    theme: WatchWorkoutTheme
  ) {
    self.sessions = sessions
    self.completedSessionIDs = Array(completedSessionIDs).sorted()
    self.theme = theme
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
            exerciseName: exercise.baseExerciseName,
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
        .map(\.baseExerciseName)
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

    publish(
      WatchWorkoutState(
        sessionID: execution.session.sessionID,
        workoutName: execution.session.label,
        exerciseName: exercise.baseExerciseName,
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
          note: snapshot.feedback.note
        ),
        phase: phase,
        completedSetCount: execution.completedSetCount,
        totalSetCount: execution.totalSetCount,
        exerciseSetNumber: locator.setIndex,
        exerciseSetTotal: exercise.sets.count,
        reps: targets.reps,
        weightKg: targets.weightKg,
        durationSeconds: targets.durationSeconds,
        restTotalSeconds: snapshot.restTotalSeconds,
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
    if let equipmentOptions = exercise.equipmentOptions {
      return equipmentOptions
    }

    let variants: [Equipment] = switch exercise.exerciseID {
    case "press-banca-barra", "press-banca-inclinado", "press-militar-sentado", "press-militar-sentado-velocidad":
      [.barbell, .multipower, .dumbbell]
    case "remo-inclinado-barra", "remo-barra-multipower", "press-cerrado-multipower", "hip-thrust-barra", "hip-thrust-volumen", "peso-muerto-rumano-barra":
      [.barbell, .multipower]
    default:
      [exercise.equipment]
    }

    return variants.contains(exercise.equipment)
      ? variants
      : [exercise.equipment] + variants
  }

  private func publishLatestStateIfPossible() {
    let session = WCSession.default
    guard session.activationState == .activated else { return }

    let state = WatchWorkoutAppState(
      sessions: sessions,
      completedSessionIDs: completedSessionIDs,
      activeWorkout: latestState,
      theme: theme
    )
    guard let data = try? encoder.encode(state) else { return }
    UserDefaults.standard.set(data, forKey: Key.persistedAppState)
    let context: [String: Any] = [Key.appState: data]

    try? session.updateApplicationContext(context)
    if session.isReachable {
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
      replyHandler?([Key.workoutCommandAcknowledgement: encodedAcknowledgement])
    }
  }

  private func apply(_ envelope: WatchWorkoutCommandEnvelope) -> WatchWorkoutCommandAcknowledgement {
    pruneProcessedCommands()
    if processedCommandDates[envelope.id] != nil {
      return WatchWorkoutCommandAcknowledgement(commandID: envelope.id, result: .duplicate)
    }

    processedCommandDates[envelope.id] = .now
    if envelope.command == .requestState {
      publishLatestStateIfPossible()
    } else {
      NotificationCenter.default.post(name: .watchWorkoutCommandReceived, object: envelope)
    }
    return WatchWorkoutCommandAcknowledgement(commandID: envelope.id, result: .applied)
  }

  private func pruneProcessedCommands() {
    let cutoff = Date.now.addingTimeInterval(-300)
    processedCommandDates = processedCommandDates.filter { $0.value >= cutoff }
  }
}
