import Foundation

public struct SessionReschedulingOption: Equatable, Sendable, Identifiable {
  public let id: String
  public let date: String
  public let isOutsideAvailability: Bool
  public let shiftedSessionIDs: [String]
  public let operations: [PlanningOperation]

  public init(date: String, isOutsideAvailability: Bool, shiftedSessionIDs: [String] = [], operations: [PlanningOperation]) {
    id = "\(date)-\(shiftedSessionIDs.joined(separator: ","))"
    self.date = date
    self.isOutsideAvailability = isOutsideAvailability
    self.shiftedSessionIDs = shiftedSessionIDs
    self.operations = operations
  }

  public var shiftsOtherSessions: Bool { !shiftedSessionIDs.isEmpty }
}

/// Creates direct moves first, then short, reviewable chains of future sessions.
public enum SessionReschedulingPlanner {
  public static func options(basePlan: TrainingPlan, sessionID: String, constraints: PlanningConstraints, maximumResults: Int = 3) throws -> [SessionReschedulingOption] {
    guard let session = basePlan.sessions.first(where: { $0.sessionID == sessionID }) else { throw PlanningOperationError.sessionNotFound(sessionID) }
    let start = try firstDayAfter(session.date, referenceDate: constraints.referenceDate)
    var results = directOptions(basePlan: basePlan, sessionID: sessionID, start: start, constraints: constraints, respectsAvailability: true, maximumResults: maximumResults)
    if results.count < maximumResults {
      results += chainedOptions(basePlan: basePlan, sessionID: sessionID, start: start, constraints: constraints, maximumResults: maximumResults - results.count)
    }
    if results.count < maximumResults {
      results += directOptions(basePlan: basePlan, sessionID: sessionID, start: start, constraints: constraints, respectsAvailability: false, maximumResults: maximumResults - results.count)
    }
    return Array(results.prefix(maximumResults))
  }

  private static func directOptions(basePlan: TrainingPlan, sessionID: String, start: Date, constraints: PlanningConstraints, respectsAvailability: Bool, maximumResults: Int) -> [SessionReschedulingOption] {
    let calendar = Calendar.current
    var result: [SessionReschedulingOption] = []
    for offset in 0 ..< 28 where result.count < maximumResults {
      guard let candidate = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
      let isAvailable = constraints.availableWeekdays.contains(calendar.component(.weekday, from: candidate))
      guard isAvailable == respectsAvailability else { continue }
      let value = format(candidate)
      guard session(at: value, in: basePlan, excluding: [sessionID]) == nil else { continue }
      let operations = [PlanningOperation.moveSession(sessionID: sessionID, toDate: value)]
      guard validates(operations, basePlan: basePlan, constraints: constraints) else { continue }
      result.append(.init(date: value, isOutsideAvailability: !isAvailable, operations: operations))
    }
    return result
  }

  private static func chainedOptions(basePlan: TrainingPlan, sessionID: String, start: Date, constraints: PlanningConstraints, maximumResults: Int) -> [SessionReschedulingOption] {
    let calendar = Calendar.current
    var result: [SessionReschedulingOption] = []
    for offset in 0 ..< 14 where result.count < maximumResults {
      guard let target = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
      let targetDate = format(target)
      guard let occupied = session(at: targetDate, in: basePlan, excluding: [sessionID]),
            let option = chain(basePlan: basePlan, source: sessionID, occupied: occupied.sessionID, target: targetDate, constraints: constraints) else { continue }
      result.append(option)
    }
    return result
  }

  private static func chain(basePlan: TrainingPlan, source: String, occupied: String, target: String, constraints: PlanningConstraints) -> SessionReschedulingOption? {
    var assignments = [(source, target)]
    var displaced = occupied
    var cursor = (try? date(target)) ?? constraints.referenceDate
    var shifted = [String]()
    for _ in 0 ..< 3 {
      guard let next = nextDestination(after: cursor, basePlan: basePlan, excluding: Set(assignments.map(\.0)), constraints: constraints) else { return nil }
      assignments.append((displaced, next))
      shifted.append(displaced)
      if let occupied = session(at: next, in: basePlan, excluding: Set(assignments.map(\.0))) {
        displaced = occupied.sessionID
        cursor = (try? date(next)) ?? cursor
      } else {
        let operations = assignments.reversed().map { PlanningOperation.moveSession(sessionID: $0.0, toDate: $0.1) }
        guard validates(operations, basePlan: basePlan, constraints: constraints), let targetDay = try? date(target) else { return nil }
        let outside = !constraints.availableWeekdays.contains(Calendar.current.component(.weekday, from: targetDay))
        return .init(date: target, isOutsideAvailability: outside, shiftedSessionIDs: shifted, operations: operations)
      }
    }
    return nil
  }

  private static func nextDestination(after date: Date, basePlan: TrainingPlan, excluding ids: Set<String>, constraints: PlanningConstraints) -> String? {
    let calendar = Calendar.current
    for respectsAvailability in [true, false] {
      for offset in 1 ... 14 {
        guard let candidate = calendar.date(byAdding: .day, value: offset, to: date) else { continue }
        let isAvailable = constraints.availableWeekdays.contains(calendar.component(.weekday, from: candidate))
        guard isAvailable == respectsAvailability else { continue }
        let value = format(candidate)
        if let existing = session(at: value, in: basePlan), ids.contains(existing.sessionID) { continue }
        return value
      }
    }
    return nil
  }

  private static func session(at date: String, in plan: TrainingPlan, excluding ids: Set<String> = []) -> TrainingSession? {
    plan.sessions.first { !$0.isCancelled && !ids.contains($0.sessionID) && $0.date == date }
  }

  private static func validates(_ operations: [PlanningOperation], basePlan: TrainingPlan, constraints: PlanningConstraints) -> Bool {
    (try? PlanningOperationEngine.preview(basePlan: basePlan, operations: operations, constraints: constraints)) != nil
  }

  private static func firstDayAfter(_ sessionDate: String, referenceDate: Date) throws -> Date {
    let calendar = Calendar.current
    let next = calendar.date(byAdding: .day, value: 1, to: try date(sessionDate)) ?? referenceDate
    return max(calendar.startOfDay(for: referenceDate), calendar.startOfDay(for: next))
  }

  private static func date(_ value: String) throws -> Date {
    guard let date = formatter.date(from: value) else { throw PlanningOperationError.invalidDate(value) }
    return date
  }

  private static func format(_ date: Date) -> String { formatter.string(from: date) }

  private static var formatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }
}
