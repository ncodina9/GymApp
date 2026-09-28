import Foundation

/// A structured request that an eventual conversational layer may produce.
/// It contains no model-generated plan and never mutates a `TrainingPlan` directly.
public enum PlanningIntent: Codable, Equatable, Sendable {
  case moveSession(sessionID: String, toDate: String)
  case postponeFutureSessions(fromDate: String, byDays: Int)
  case gymClosure(date: String)
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
  case adjustBodyweightLoad(sessionID: String, exerciseID: String, setIndex: Int, assistanceKg: Double, addedWeightKg: Double)
  case adaptSessionDuration(sessionID: String, maximumMinutes: Int)

  private enum CodingKeys: String, CodingKey {
    case type, sessionID, toDate, fromDate, byDays, exerciseID, replacementExerciseID
    case setIndex, reps, weightKg, durationSeconds, restSeconds, assistanceKg, addedWeightKg, maximumMinutes
  }

  private enum Kind: String, Codable {
    case moveSession, postponeFutureSessions, gymClosure, cancelSession, replaceExercise, adjustSet, adjustBodyweightLoad, adaptSessionDuration
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    switch try container.decode(Kind.self, forKey: .type) {
    case .moveSession:
      self = .moveSession(sessionID: try container.decode(String.self, forKey: .sessionID), toDate: try container.decode(String.self, forKey: .toDate))
    case .postponeFutureSessions:
      self = .postponeFutureSessions(fromDate: try container.decode(String.self, forKey: .fromDate), byDays: try container.decode(Int.self, forKey: .byDays))
    case .gymClosure:
      self = .gymClosure(date: try container.decode(String.self, forKey: .fromDate))
    case .cancelSession:
      self = .cancelSession(sessionID: try container.decode(String.self, forKey: .sessionID))
    case .replaceExercise:
      self = .replaceExercise(sessionID: try container.decode(String.self, forKey: .sessionID), exerciseID: try container.decode(String.self, forKey: .exerciseID), replacementExerciseID: try container.decode(String.self, forKey: .replacementExerciseID))
    case .adjustSet:
      self = .adjustSet(sessionID: try container.decode(String.self, forKey: .sessionID), exerciseID: try container.decode(String.self, forKey: .exerciseID), setIndex: try container.decode(Int.self, forKey: .setIndex), reps: try container.decodeIfPresent(Int.self, forKey: .reps), weightKg: try container.decodeIfPresent(Double.self, forKey: .weightKg), durationSeconds: try container.decodeIfPresent(Int.self, forKey: .durationSeconds), restSeconds: try container.decodeIfPresent(Int.self, forKey: .restSeconds))
    case .adjustBodyweightLoad:
      self = .adjustBodyweightLoad(sessionID: try container.decode(String.self, forKey: .sessionID), exerciseID: try container.decode(String.self, forKey: .exerciseID), setIndex: try container.decode(Int.self, forKey: .setIndex), assistanceKg: try container.decode(Double.self, forKey: .assistanceKg), addedWeightKg: try container.decode(Double.self, forKey: .addedWeightKg))
    case .adaptSessionDuration:
      self = .adaptSessionDuration(sessionID: try container.decode(String.self, forKey: .sessionID), maximumMinutes: try container.decode(Int.self, forKey: .maximumMinutes))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case let .moveSession(sessionID, toDate):
      try container.encode(Kind.moveSession, forKey: .type); try container.encode(sessionID, forKey: .sessionID); try container.encode(toDate, forKey: .toDate)
    case let .postponeFutureSessions(fromDate, byDays):
      try container.encode(Kind.postponeFutureSessions, forKey: .type); try container.encode(fromDate, forKey: .fromDate); try container.encode(byDays, forKey: .byDays)
    case let .gymClosure(date):
      try container.encode(Kind.gymClosure, forKey: .type); try container.encode(date, forKey: .fromDate)
    case let .cancelSession(sessionID):
      try container.encode(Kind.cancelSession, forKey: .type); try container.encode(sessionID, forKey: .sessionID)
    case let .replaceExercise(sessionID, exerciseID, replacementExerciseID):
      try container.encode(Kind.replaceExercise, forKey: .type); try container.encode(sessionID, forKey: .sessionID); try container.encode(exerciseID, forKey: .exerciseID); try container.encode(replacementExerciseID, forKey: .replacementExerciseID)
    case let .adjustSet(sessionID, exerciseID, setIndex, reps, weightKg, durationSeconds, restSeconds):
      try container.encode(Kind.adjustSet, forKey: .type); try container.encode(sessionID, forKey: .sessionID); try container.encode(exerciseID, forKey: .exerciseID); try container.encode(setIndex, forKey: .setIndex); try container.encodeIfPresent(reps, forKey: .reps); try container.encodeIfPresent(weightKg, forKey: .weightKg); try container.encodeIfPresent(durationSeconds, forKey: .durationSeconds); try container.encodeIfPresent(restSeconds, forKey: .restSeconds)
    case let .adjustBodyweightLoad(sessionID, exerciseID, setIndex, assistanceKg, addedWeightKg):
      try container.encode(Kind.adjustBodyweightLoad, forKey: .type); try container.encode(sessionID, forKey: .sessionID); try container.encode(exerciseID, forKey: .exerciseID); try container.encode(setIndex, forKey: .setIndex); try container.encode(assistanceKg, forKey: .assistanceKg); try container.encode(addedWeightKg, forKey: .addedWeightKg)
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
    case let .postponeFutureSessions(fromDate, byDays):
      .operations([.shiftFutureSessions(fromDate: fromDate, byDays: byDays)])
    case let .gymClosure(date):
      .operations([.shiftFutureSessions(fromDate: date, byDays: 1)])
    case let .cancelSession(sessionID):
      .operations([.cancelSession(sessionID: sessionID)])
    case let .replaceExercise(sessionID, exerciseID, replacementExerciseID):
      .operations([.replaceExercise(sessionID: sessionID, exerciseID: exerciseID, replacementExerciseID: replacementExerciseID)])
    case let .adjustSet(sessionID, exerciseID, setIndex, reps, weightKg, durationSeconds, restSeconds):
      .operations([.adjustSet(sessionID: sessionID, exerciseID: exerciseID, setIndex: setIndex, reps: reps, weightKg: weightKg, durationSeconds: durationSeconds, restSeconds: restSeconds)])
    case let .adjustBodyweightLoad(sessionID, exerciseID, setIndex, assistanceKg, addedWeightKg):
      .operations([.adjustBodyweightLoad(sessionID: sessionID, exerciseID: exerciseID, setIndex: setIndex, assistanceKg: assistanceKg, addedWeightKg: addedWeightKg)])
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
      "Necesito saber si quieres cancelar, mover la sesión, indicar una ausencia o ajustar su duración. Puedes usar fechas como mañana, el jueves o 2026-10-03."
    }
  }
}

/// Small deterministic adapter used while the conversational model is not
/// connected. It deliberately produces only typed intents and never sees or
/// changes the training plan itself.
public struct LocalPlanningIntentInterpreter: PlanningIntentInterpreting {
  public init() {}

  public func interpret(_ request: PlanningIntentRequest) async throws -> [PlanningIntent] {
    let normalized = request.userText.folding(
      options: [.caseInsensitive, .diacriticInsensitive],
      locale: .current
    )
    if normalized.contains("vacaciones"), let absence = Self.vacationPeriod(in: normalized, from: request.createdAt) {
      return [.postponeFutureSessions(fromDate: absence.startDate, byDays: absence.days)]
    }
    if Self.describesGymClosure(normalized), let date = Self.singleDate(in: normalized, from: request.createdAt) {
      return [.gymClosure(date: date)]
    }
    guard let sessionID = request.referencedSessionID, !sessionID.isEmpty else {
      throw LocalPlanningIntentInterpreterError.missingSessionContext
    }
    if normalized.contains("cancel") || normalized.contains("no puedo") || normalized.contains("no podre")
      || normalized.contains("replanifica") || normalized.contains("reprograma") || normalized.contains("otro dia") {
      return [.cancelSession(sessionID: sessionID)]
    }
    if let minutes = Self.minutes(in: normalized) {
      return [.adaptSessionDuration(sessionID: sessionID, maximumMinutes: minutes)]
    }
    if let date = Self.isoDate(in: normalized) ?? Self.relativeDate(in: normalized, from: request.createdAt) {
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

  private static func relativeDate(in text: String, from referenceDate: Date) -> String? {
    let calendar = Calendar.current
    let reference = calendar.startOfDay(for: referenceDate)
    let offset: Int?
    if text.contains("pasado manana") {
      offset = 2
    } else if text.contains("manana") {
      offset = 1
    } else {
      let weekdays = [
        "domingo": 1,
        "lunes": 2,
        "martes": 3,
        "miercoles": 4,
        "jueves": 5,
        "viernes": 6,
        "sabado": 7,
      ]
      guard let target = weekdays.first(where: { text.contains($0.key) })?.value else { return nil }
      let current = calendar.component(.weekday, from: reference)
      let daysUntil = (target - current + 7) % 7
      offset = daysUntil == 0 ? 7 : daysUntil
    }
    guard let offset,
          let date = calendar.date(byAdding: .day, value: offset, to: reference) else { return nil }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }

  private static func vacationPeriod(in text: String, from referenceDate: Date) -> (startDate: String, days: Int)? {
    if let period = isoDateRange(in: text) { return period }
    if let period = spanishCrossMonthDateRange(in: text, from: referenceDate) { return period }
    if let period = spanishDateRange(in: text, from: referenceDate) { return period }
    guard text.contains("semana que viene") || text.contains("proxima semana") else { return nil }
    let calendar = Calendar.current
    guard let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: referenceDate),
          let interval = calendar.dateInterval(of: .weekOfYear, for: nextWeek) else { return nil }
    return (isoDateString(interval.start), 7)
  }

  private static func describesGymClosure(_ text: String) -> Bool {
    text.contains("festivo") || text.contains("gym no abre") || text.contains("gimnasio no abre") || text.contains("gym cerrado") || text.contains("gimnasio cerrado")
  }

  private static func singleDate(in text: String, from referenceDate: Date) -> String? {
    if let date = isoDate(in: text) { return date }
    guard let captures = captures(in: text, pattern: "\\b(?:el\\s+dia\\s+|el\\s+)?(\\d{1,2})\\s+de\\s+([a-z]+)(?:\\s+de\\s+(\\d{4}))?\\b"),
          captures.count == 3,
          let day = Int(captures[0]),
          let month = spanishMonth[captures[1]] else { return nil }
    let calendar = Calendar.current
    var year = Int(captures[2]) ?? calendar.component(.year, from: referenceDate)
    guard var date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
    if captures[2].isEmpty, date < calendar.startOfDay(for: referenceDate) {
      year += 1
      guard let nextYearDate = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
      date = nextYearDate
    }
    return isoDateString(date)
  }

  /// The end date in a natural-language range is the return date, therefore it
  /// is exclusive: "del 12 al 19" represents seven unavailable days.
  private static func isoDateRange(in text: String) -> (startDate: String, days: Int)? {
    guard let captures = captures(in: text, pattern: "\\b(?:del\\s+)?(\\d{4}-\\d{2}-\\d{2})\\s+(?:al|a)\\s+(\\d{4}-\\d{2}-\\d{2})\\b"),
          captures.count == 2,
          let start = date(from: captures[0]),
          let end = date(from: captures[1]) else { return nil }
    let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
    guard days > 0 else { return nil }
    return (captures[0], days)
  }

  private static func spanishDateRange(in text: String, from referenceDate: Date) -> (startDate: String, days: Int)? {
    guard let captures = captures(in: text, pattern: "\\b(?:del\\s+)?(\\d{1,2})\\s+(?:al|a)\\s+(\\d{1,2})\\s+de\\s+([a-z]+)(?:\\s+de\\s+(\\d{4}))?\\b"),
          captures.count == 4,
          let startDay = Int(captures[0]),
          let endDay = Int(captures[1]),
          let month = spanishMonth[captures[2]] else { return nil }
    let calendar = Calendar.current
    let referenceYear = calendar.component(.year, from: referenceDate)
    var year = Int(captures[3]) ?? referenceYear
    guard var start = calendar.date(from: DateComponents(year: year, month: month, day: startDay)),
          var end = calendar.date(from: DateComponents(year: year, month: month, day: endDay)) else { return nil }
    if captures[3].isEmpty, end < start {
      year += 1
      guard let nextYearEnd = calendar.date(from: DateComponents(year: year, month: month, day: endDay)) else { return nil }
      end = nextYearEnd
    }
    if captures[3].isEmpty, start < calendar.startOfDay(for: referenceDate),
       let nextYearStart = calendar.date(byAdding: .year, value: 1, to: start),
       let nextYearEnd = calendar.date(byAdding: .year, value: 1, to: end) {
      start = nextYearStart
      end = nextYearEnd
    }
    let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
    guard days > 0 else { return nil }
    return (isoDateString(start), days)
  }

  private static func spanishCrossMonthDateRange(in text: String, from referenceDate: Date) -> (startDate: String, days: Int)? {
    guard let captures = captures(in: text, pattern: "\\b(?:del\\s+)?(\\d{1,2})\\s+de\\s+([a-z]+)\\s+(?:al|a)\\s+(\\d{1,2})\\s+de\\s+([a-z]+)(?:\\s+de\\s+(\\d{4}))?\\b"),
          captures.count == 5,
          let startDay = Int(captures[0]),
          let startMonth = spanishMonth[captures[1]],
          let endDay = Int(captures[2]),
          let endMonth = spanishMonth[captures[3]] else { return nil }
    let calendar = Calendar.current
    let explicitYear = Int(captures[4])
    var startYear = explicitYear ?? calendar.component(.year, from: referenceDate)
    var endYear = startYear
    if explicitYear == nil, endMonth < startMonth { endYear += 1 }
    guard var start = calendar.date(from: DateComponents(year: startYear, month: startMonth, day: startDay)),
          var end = calendar.date(from: DateComponents(year: endYear, month: endMonth, day: endDay)) else { return nil }
    if explicitYear == nil, start < calendar.startOfDay(for: referenceDate) {
      startYear += 1
      endYear += 1
      guard let nextYearStart = calendar.date(from: DateComponents(year: startYear, month: startMonth, day: startDay)),
            let nextYearEnd = calendar.date(from: DateComponents(year: endYear, month: endMonth, day: endDay)) else { return nil }
      start = nextYearStart
      end = nextYearEnd
    }
    let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
    guard days > 0 else { return nil }
    return (isoDateString(start), days)
  }

  private static let spanishMonth: [String: Int] = [
    "enero": 1, "febrero": 2, "marzo": 3, "abril": 4, "mayo": 5, "junio": 6,
    "julio": 7, "agosto": 8, "septiembre": 9, "octubre": 10, "noviembre": 11, "diciembre": 12,
  ]

  private static func date(from value: String) -> Date? {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: value)
  }

  private static func isoDateString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }

  private static func captures(in text: String, pattern: String) -> [String]? {
    guard let expression = try? NSRegularExpression(pattern: pattern),
          let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
    return (1 ..< match.numberOfRanges).map { index in
      guard let range = Range(match.range(at: index), in: text) else { return "" }
      return String(text[range])
    }
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
