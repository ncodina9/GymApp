import Foundation

/// A structured request that an eventual conversational layer may produce.
/// It contains no model-generated plan and never mutates a `TrainingPlan` directly.
public enum PlanningIntent: Codable, Equatable, Sendable {
  case moveSession(sessionID: String, toDate: String)
  case cancelSession(sessionID: String)
  case replaceExercise(sessionID: String, exerciseID: String, replacementExerciseID: String)
  case adjustSet(
    sessionID: String,
    exerciseID: String,
    setIndex: Int,
    reps: Int?,
    weightKg: Double?,
    durationSeconds: Int?,
    restSeconds: Int?
  )
  case adaptSessionDuration(sessionID: String, maximumMinutes: Int)

  private enum CodingKeys: String, CodingKey {
    case type, sessionID, toDate, exerciseID, replacementExerciseID
    case setIndex, reps, weightKg, durationSeconds, restSeconds, maximumMinutes
  }

  private enum Kind: String, Codable {
    case moveSession, cancelSession, replaceExercise, adjustSet, adaptSessionDuration
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    switch try container.decode(Kind.self, forKey: .type) {
    case .moveSession:
      self = .moveSession(sessionID: try container.decode(String.self, forKey: .sessionID), toDate: try container.decode(String.self, forKey: .toDate))
    case .cancelSession:
      self = .cancelSession(sessionID: try container.decode(String.self, forKey: .sessionID))
    case .replaceExercise:
      self = .replaceExercise(sessionID: try container.decode(String.self, forKey: .sessionID), exerciseID: try container.decode(String.self, forKey: .exerciseID), replacementExerciseID: try container.decode(String.self, forKey: .replacementExerciseID))
    case .adjustSet:
      self = .adjustSet(sessionID: try container.decode(String.self, forKey: .sessionID), exerciseID: try container.decode(String.self, forKey: .exerciseID), setIndex: try container.decode(Int.self, forKey: .setIndex), reps: try container.decodeIfPresent(Int.self, forKey: .reps), weightKg: try container.decodeIfPresent(Double.self, forKey: .weightKg), durationSeconds: try container.decodeIfPresent(Int.self, forKey: .durationSeconds), restSeconds: try container.decodeIfPresent(Int.self, forKey: .restSeconds))
    case .adaptSessionDuration:
      self = .adaptSessionDuration(sessionID: try container.decode(String.self, forKey: .sessionID), maximumMinutes: try container.decode(Int.self, forKey: .maximumMinutes))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case let .moveSession(sessionID, toDate):
      try container.encode(Kind.moveSession, forKey: .type); try container.encode(sessionID, forKey: .sessionID); try container.encode(toDate, forKey: .toDate)
    case let .cancelSession(sessionID):
      try container.encode(Kind.cancelSession, forKey: .type); try container.encode(sessionID, forKey: .sessionID)
    case let .replaceExercise(sessionID, exerciseID, replacementExerciseID):
      try container.encode(Kind.replaceExercise, forKey: .type); try container.encode(sessionID, forKey: .sessionID); try container.encode(exerciseID, forKey: .exerciseID); try container.encode(replacementExerciseID, forKey: .replacementExerciseID)
    case let .adjustSet(sessionID, exerciseID, setIndex, reps, weightKg, durationSeconds, restSeconds):
      try container.encode(Kind.adjustSet, forKey: .type); try container.encode(sessionID, forKey: .sessionID); try container.encode(exerciseID, forKey: .exerciseID); try container.encode(setIndex, forKey: .setIndex); try container.encodeIfPresent(reps, forKey: .reps); try container.encodeIfPresent(weightKg, forKey: .weightKg); try container.encodeIfPresent(durationSeconds, forKey: .durationSeconds); try container.encodeIfPresent(restSeconds, forKey: .restSeconds)
    case let .adaptSessionDuration(sessionID, maximumMinutes):
      try container.encode(Kind.adaptSessionDuration, forKey: .type); try container.encode(sessionID, forKey: .sessionID); try container.encode(maximumMinutes, forKey: .maximumMinutes)
    }
  }
}

public struct PlanningIntentRequest: Codable, Equatable, Sendable {
  public let userText: String
  public let referencedSessionID: String?
  public let createdAt: Date

  public init(userText: String, referencedSessionID: String? = nil, createdAt: Date = .now) {
    self.userText = userText
    self.referencedSessionID = referencedSessionID
    self.createdAt = createdAt
  }
}

public enum PlanningIntentResolution: Equatable, Sendable {
  case operations([PlanningOperation])
  case requiresPlanningStrategy(sessionID: String, maximumMinutes: Int)
}

public enum PlanningIntentResolver {
  /// Converts an already-resolved intent to the deterministic operation contract.
  /// Validation and preview remain the responsibility of `PlanningOperationEngine`.
  public static func resolve(_ intent: PlanningIntent) -> PlanningIntentResolution {
    switch intent {
    case let .moveSession(sessionID, toDate):
      .operations([.moveSession(sessionID: sessionID, toDate: toDate)])
    case let .cancelSession(sessionID):
      .operations([.cancelSession(sessionID: sessionID)])
    case let .replaceExercise(sessionID, exerciseID, replacementExerciseID):
      .operations([.replaceExercise(sessionID: sessionID, exerciseID: exerciseID, replacementExerciseID: replacementExerciseID)])
    case let .adjustSet(sessionID, exerciseID, setIndex, reps, weightKg, durationSeconds, restSeconds):
      .operations([.adjustSet(sessionID: sessionID, exerciseID: exerciseID, setIndex: setIndex, reps: reps, weightKg: weightKg, durationSeconds: durationSeconds, restSeconds: restSeconds)])
    case let .adaptSessionDuration(sessionID, maximumMinutes):
      .requiresPlanningStrategy(sessionID: sessionID, maximumMinutes: max(15, maximumMinutes))
    }
  }
}

/// Boundary for a future local or remote conversational implementation.
/// The interpreter can suggest intents but has no direct access to plan mutation.
public protocol PlanningIntentInterpreting: Sendable {
  func interpret(_ request: PlanningIntentRequest) async throws -> [PlanningIntent]
}

/// Deliberately minimal context allowed to cross a future remote interpreter
/// boundary. It excludes completed workouts, set-level execution, HealthKit and
/// free-form profile limitations unless a later consent tier explicitly adds them.
public struct RemotePlanningInterpretationInput: Codable, Equatable, Sendable {
  public let schemaVersion: Int
  public let request: PlanningIntentRequest
  public let profile: ProfileContext
  public let session: SessionContext

  public init(
    schemaVersion: Int = 1,
    request: PlanningIntentRequest,
    profile: ProfileContext,
    session: SessionContext
  ) {
    self.schemaVersion = schemaVersion
    self.request = request
    self.profile = profile
    self.session = session
  }

  public struct ProfileContext: Codable, Equatable, Sendable {
    public let goal: String
    public let experience: String
    public let weeklyTrainingDays: Int
    public let maximumSessionMinutes: Int
    public let availableEquipment: [String]

    public init(goal: String, experience: String, weeklyTrainingDays: Int, maximumSessionMinutes: Int, availableEquipment: [String]) {
      self.goal = goal
      self.experience = experience
      self.weeklyTrainingDays = weeklyTrainingDays
      self.maximumSessionMinutes = maximumSessionMinutes
      self.availableEquipment = availableEquipment.sorted()
    }
  }

  public struct SessionContext: Codable, Equatable, Sendable {
    public let sessionID: String
    public let date: String
    public let label: String
    public let estimatedMinutes: Int
    public let exerciseFamilies: [String]

    public init(sessionID: String, date: String, label: String, estimatedMinutes: Int, exerciseFamilies: [String]) {
      self.sessionID = sessionID
      self.date = date
      self.label = label
      self.estimatedMinutes = estimatedMinutes
      self.exerciseFamilies = exerciseFamilies.sorted()
    }
  }
}

/// Network implementations must use the minimum context above and return
/// intents only. Validation, review and plan mutation remain local.
public protocol RemotePlanningIntentInterpreting: Sendable {
  func interpret(_ input: RemotePlanningInterpretationInput) async throws -> [PlanningIntent]
}

public enum LocalPlanningIntentInterpreterError: LocalizedError, Equatable, Sendable {
  case missingSessionContext
  case unsupportedRequest

  public var errorDescription: String? {
    switch self {
    case .missingSessionContext:
      "Elige primero la sesión sobre la que quieres hacer la solicitud."
    case .unsupportedRequest:
      "Por ahora puedo entender cancelaciones, cambios a una fecha YYYY-MM-DD y objetivos de duración en minutos."
    }
  }
}

/// Small deterministic adapter used while the conversational model is not
/// connected. It deliberately produces only typed intents and never sees or
/// changes the training plan itself.
public struct LocalPlanningIntentInterpreter: PlanningIntentInterpreting {
  public init() {}

  public func interpret(_ request: PlanningIntentRequest) async throws -> [PlanningIntent] {
    guard let sessionID = request.referencedSessionID, !sessionID.isEmpty else {
      throw LocalPlanningIntentInterpreterError.missingSessionContext
    }

    let normalized = request.userText.folding(
      options: [.caseInsensitive, .diacriticInsensitive],
      locale: .current
    )
    if normalized.contains("cancel") || normalized.contains("no puedo") || normalized.contains("no podre") {
      return [.cancelSession(sessionID: sessionID)]
    }
    if let minutes = Self.minutes(in: normalized) {
      return [.adaptSessionDuration(sessionID: sessionID, maximumMinutes: minutes)]
    }
    if let date = Self.isoDate(in: normalized) {
      return [.moveSession(sessionID: sessionID, toDate: date)]
    }
    throw LocalPlanningIntentInterpreterError.unsupportedRequest
  }

  private static func minutes(in text: String) -> Int? {
    firstCapture(in: text, pattern: "\\b(\\d{1,3})\\s*(?:min|mins|minutos)\\b").flatMap(Int.init)
  }

  private static func isoDate(in text: String) -> String? {
    firstCapture(in: text, pattern: "\\b(\\d{4}-\\d{2}-\\d{2})\\b")
  }

  private static func firstCapture(in text: String, pattern: String) -> String? {
    guard let expression = try? NSRegularExpression(pattern: pattern),
          let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
          let range = Range(match.range(at: 1), in: text) else {
      return nil
    }
    return String(text[range])
  }
}
