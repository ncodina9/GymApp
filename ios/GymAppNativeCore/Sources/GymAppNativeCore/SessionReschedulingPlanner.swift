import Foundation

public struct SessionReschedulingOption: Equatable, Sendable, Identifiable {
  public let id: String
  public let date: String
  public let isOutsideAvailability: Bool
  public let operations: [PlanningOperation]

  public init(date: String, isOutsideAvailability: Bool, operations: [PlanningOperation]) {
    id = date
    self.date = date
    self.isOutsideAvailability = isOutsideAvailability
    self.operations = operations
  }
}

/// Finds explicit, conservative dates for a future session. It never edits a
/// plan directly and leaves the final preview to the normal operation engine.
public enum SessionReschedulingPlanner {
  public static func options(
    basePlan: TrainingPlan,
    sessionID: String,
    constraints: PlanningConstraints,
    maximumResults: Int = 3
  ) throws -> [SessionReschedulingOption] {
    guard let session = basePlan.sessions.first(where: { $0.sessionID == sessionID }) else {
      throw PlanningOperationError.sessionNotFound(sessionID)
    }
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: constraints.referenceDate)
    let sessionDate = try date(from: session.date)
    let dayAfterSession = calendar.date(byAdding: .day, value: 1, to: sessionDate) ?? sessionDate
    let start = max(today, calendar.startOfDay(for: dayAfterSession))
    let formatter = isoFormatter()
    var results: [SessionReschedulingOption] = []

    for respectsAvailability in [true, false] {
      guard results.count < maximumResults else { break }
      for offset in 0 ..< 28 {
        guard results.count < maximumResults,
              let candidate = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
        let weekday = calendar.component(.weekday, from: candidate)
        let isAvailable = constraints.availableWeekdays.contains(weekday)
        guard isAvailable == respectsAvailability else { continue }
        let date = formatter.string(from: candidate)
        guard !basePlan.sessions.contains(where: { $0.sessionID != sessionID && !$0.isCancelled && $0.date == date }) else { continue }
        let operation = PlanningOperation.moveSession(sessionID: sessionID, toDate: date)
        guard (try? PlanningOperationEngine.preview(basePlan: basePlan, operations: [operation], constraints: constraints)) != nil else { continue }
        results.append(SessionReschedulingOption(
          date: date,
          isOutsideAvailability: !isAvailable,
          operations: [operation]
        ))
      }
    }
    return results
  }

  private static func date(from value: String) throws -> Date {
    guard let date = isoFormatter().date(from: value) else { throw PlanningOperationError.invalidDate(value) }
    return date
  }

  private static func isoFormatter() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }
}
