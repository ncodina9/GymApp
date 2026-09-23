import Foundation
import Combine
import WatchConnectivity

// Keep this transport contract independent from the view layer. It mirrors the
// iPhone's versioned payload so the Watch can evolve without owning workout data.
struct WatchWorkoutState: Codable, Equatable {
  enum Phase: String, Codable {
    case workingSet
    case feedback
    case rest
    case exerciseReview
    case warmup
  }

  let schemaVersion: Int
  let sessionID: String
  let workoutName: String
  let exerciseName: String
  let equipmentName: String
  let phase: Phase
  let completedSetCount: Int
  let totalSetCount: Int
  let exerciseSetNumber: Int
  let exerciseSetTotal: Int
  let reps: Int?
  let weightKg: Double
  let durationSeconds: Int?
  let timerEndsAt: Date?
  let updatedAt: Date
}

enum WatchWorkoutCommand: String, Codable {
  case requestState
  case addRest15
  case subtractRest15
}

@MainActor
final class WatchWorkoutConnectivity: NSObject, ObservableObject {
  @Published private(set) var workout: WatchWorkoutState?
  @Published private(set) var connectionStatus = "Conectando con el iPhone"

  private enum Key {
    static let workoutState = "workoutState"
    static let workoutCommand = "workoutCommand"
  }

  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  override init() {
    super.init()
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    session.delegate = self
    session.activate()
  }

  func send(_ command: WatchWorkoutCommand) {
    guard WCSession.default.isReachable,
          let data = try? encoder.encode(command)
    else { return }
    let payload = [Key.workoutCommand: data]
    WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
  }

  func requestState() {
    send(.requestState)
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
