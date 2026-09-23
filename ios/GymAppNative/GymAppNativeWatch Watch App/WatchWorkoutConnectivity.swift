import Combine
import Foundation
import WatchConnectivity
import WatchKit
import GymAppNativeCore

@MainActor
final class WatchWorkoutConnectivity: NSObject, ObservableObject {
  @Published private(set) var workout: WatchWorkoutState?
  @Published private(set) var connectionStatus = "Conectando con el iPhone"
  @Published private(set) var pendingCommand: WatchWorkoutCommand?

  private enum Key {
    static let workoutState = "workoutState"
    static let workoutCommandEnvelope = "workoutCommandEnvelope"
    static let workoutCommandAcknowledgement = "workoutCommandAcknowledgement"
  }

  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()
  private var pendingCommandID: UUID?

  override init() {
    super.init()
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    session.delegate = self
    session.activate()
  }

  var isSendingAction: Bool { pendingCommand != nil }

  func send(_ command: WatchWorkoutCommand) {
    let session = WCSession.default
    guard session.isReachable else {
      connectionStatus = "Abre GymApp en el iPhone para continuar"
      return
    }
    guard pendingCommand == nil else { return }

    let envelope = WatchWorkoutCommandEnvelope(command: command)
    guard let data = try? encoder.encode(envelope) else { return }
    if command != .requestState {
      pendingCommand = command
      pendingCommandID = envelope.id
    }

    session.sendMessage(
      [Key.workoutCommandEnvelope: data],
      replyHandler: { [weak self] response in
        guard let data = response[Key.workoutCommandAcknowledgement] as? Data,
              let acknowledgement = try? JSONDecoder().decode(WatchWorkoutCommandAcknowledgement.self, from: data)
        else { return }
        Task { @MainActor in self?.apply(acknowledgement) }
      },
      errorHandler: { [weak self] _ in
        Task { @MainActor in
          self?.pendingCommand = nil
          self?.pendingCommandID = nil
          self?.connectionStatus = "No se pudo enviar la acción"
        }
      }
    )
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
    guard let data = payload[Key.workoutState] as? Data else {
      workout = nil
      connectionStatus = "Conectado, sin sesión activa"
      return
    }
    workout = try? decoder.decode(WatchWorkoutState.self, from: data)
    connectionStatus = workout == nil ? "No se pudo leer la sesión" : "Sesión recibida"
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
}
