import Combine
import Foundation
import WatchConnectivity
import WatchKit
import GymAppNativeCore

@MainActor
final class WatchWorkoutConnectivity: NSObject, ObservableObject {
  @Published private(set) var appState = WatchWorkoutAppState(
    sessions: [],
    completedSessionIDs: [],
    activeWorkout: nil,
    theme: WatchWorkoutTheme(appearance: "system", accent: "blue")
  )
  @Published private(set) var workout: WatchWorkoutState?
  @Published private(set) var connectionStatus = "Conectando con el iPhone"
  @Published private(set) var pendingCommand: WatchWorkoutCommand?
  @Published private(set) var lastStateReceivedAt: Date?
  @Published private(set) var lastActionSentAt: Date?
  @Published private(set) var isPhoneReachable = false

  private enum Key {
    static let workoutState = "workoutState"
    static let appState = "watchWorkoutAppState"
    static let workoutCommandEnvelope = "workoutCommandEnvelope"
    static let workoutCommandAcknowledgement = "workoutCommandAcknowledgement"
  }

  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()
  private var pendingCommandID: UUID?
  private var queuedCommandID: UUID?
  private var queuedCommandDate: Date?
  private var queuedSessionID: String?

  override init() {
    super.init()
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    session.delegate = self
    isPhoneReachable = session.isReachable
    session.activate()
  }

  var isSendingAction: Bool { pendingCommand != nil || queuedCommandID != nil }
  var hasQueuedAction: Bool { queuedCommandID != nil }

  func send(_ command: WatchWorkoutCommand) {
    let session = WCSession.default
    guard pendingCommand == nil, queuedCommandID == nil else { return }

    let envelope = WatchWorkoutCommandEnvelope(command: command)
    guard let data = try? encoder.encode(envelope) else { return }
    guard command != .requestState else {
      guard session.isReachable else {
        connectionStatus = "Esperando la última sincronización del iPhone"
        return
      }
      sendImmediately(envelope: envelope, data: data, with: session)
      return
    }

    pendingCommand = command
    pendingCommandID = envelope.id
    lastActionSentAt = .now
    if session.isReachable {
      sendImmediately(envelope: envelope, data: data, with: session)
    } else {
      queue(envelope: envelope, data: data, with: session)
    }
  }

  private func sendImmediately(
    envelope: WatchWorkoutCommandEnvelope,
    data: Data,
    with session: WCSession
  ) {
    session.sendMessage(
      [Key.workoutCommandEnvelope: data],
      replyHandler: { [weak self] response in
        guard let data = response[Key.workoutCommandAcknowledgement] as? Data,
              let acknowledgement = try? JSONDecoder().decode(WatchWorkoutCommandAcknowledgement.self, from: data)
        else { return }
        Task { @MainActor in
          self?.apply(response)
          self?.apply(acknowledgement)
        }
      },
      errorHandler: { [weak self] _ in
        Task { @MainActor in
          guard let self else { return }
          self.queue(envelope: envelope, data: data, with: session)
        }
      }
    )
  }

  private func queue(
    envelope: WatchWorkoutCommandEnvelope,
    data: Data,
    with session: WCSession
  ) {
    _ = session.transferUserInfo([Key.workoutCommandEnvelope: data])
    queuedCommandID = envelope.id
    queuedCommandDate = .now
    queuedSessionID = workout?.sessionID
    pendingCommand = nil
    pendingCommandID = nil
    connectionStatus = "Acción guardada; se aplicará al reconectar"
    WKInterfaceDevice.current().play(.click)
  }

  func requestState() {
    send(.requestState)
  }

  private func apply(_ acknowledgement: WatchWorkoutCommandAcknowledgement) {
    guard acknowledgement.commandID == pendingCommandID || pendingCommandID == nil else { return }
    pendingCommand = nil
    pendingCommandID = nil
    if acknowledgement.result != .rejected {
      WKInterfaceDevice.current().play(.click)
    }
    connectionStatus = acknowledgement.result == .rejected
      ? "La acción ya no está disponible"
      : "Acción confirmada"
  }

  private func apply(_ payload: [String: Any]) {
    if let data = payload[Key.appState] as? Data,
       let appState = try? decoder.decode(WatchWorkoutAppState.self, from: data) {
      self.appState = appState
      workout = appState.activeWorkout
      lastStateReceivedAt = .now
      clearQueuedCommandIfReflected(by: appState)
      connectionStatus = workout == nil ? "Conectado, elige un entrenamiento" : "Sesión recibida"
      return
    }
    // A command acknowledgement has no state payload. Treating it as an empty
    // snapshot briefly dismissed the workout and showed a false completion.
    guard let data = payload[Key.workoutState] as? Data else { return }
    workout = try? decoder.decode(WatchWorkoutState.self, from: data)
    if let workout {
      clearQueuedCommandIfReflected(by: WatchWorkoutAppState(
        sessions: appState.sessions,
        completedSessionIDs: appState.completedSessionIDs,
      activeWorkout: workout,
        theme: appState.theme,
        currentWeek: appState.currentWeek,
        weekFocusLabel: appState.weekFocusLabel,
        recommendedSessionID: appState.recommendedSessionID
      ))
    }
    lastStateReceivedAt = .now
    connectionStatus = workout == nil ? "No se pudo leer la sesión" : "Sesión recibida"
  }

  private func clearQueuedCommandIfReflected(by state: WatchWorkoutAppState) {
    guard let queuedCommandDate else { return }
    if let activeWorkout = state.activeWorkout, activeWorkout.updatedAt >= queuedCommandDate {
      clearQueuedCommand()
    } else if let queuedSessionID,
              state.activeWorkout == nil,
              state.completedSessionIDs.contains(queuedSessionID) {
      clearQueuedCommand()
    }
  }

  private func clearQueuedCommand() {
    queuedCommandID = nil
    queuedCommandDate = nil
    queuedSessionID = nil
  }
}

extension WatchWorkoutConnectivity: WCSessionDelegate {
  nonisolated func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    Task { @MainActor in
      self.connectionStatus = activationState == .activated
        ? "Conectado, esperando sesión"
        : "No se pudo activar la conexión"
      self.isPhoneReachable = session.isReachable
      self.apply(session.receivedApplicationContext)
      self.requestState()
    }
  }

  nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    Task { @MainActor in self.apply(message) }
  }

  nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    Task { @MainActor in self.apply(applicationContext) }
  }

  nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
    Task { @MainActor in
      self.isPhoneReachable = session.isReachable
      if !session.isReachable, !self.hasQueuedAction, self.workout == nil {
        self.connectionStatus = "iPhone fuera de alcance; usando el último estado"
      }
    }
  }
}
