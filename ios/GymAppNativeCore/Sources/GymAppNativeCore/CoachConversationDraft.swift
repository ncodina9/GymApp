import Foundation

public enum CoachConversationPendingTask: Codable, Equatable, Sendable {
  case replacement
  case setAdjustment(CoachSetAdjustmentRequest)
  case moveSession(toDate: String)
  case adaptDuration(maximumMinutes: Int)

  private enum CodingKeys: String, CodingKey { case type, adjustment, toDate, maximumMinutes }
  private enum Kind: String, Codable { case replacement, setAdjustment, moveSession, adaptDuration }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    switch try container.decode(Kind.self, forKey: .type) {
    case .replacement: self = .replacement
    case .setAdjustment: self = .setAdjustment(try container.decode(CoachSetAdjustmentRequest.self, forKey: .adjustment))
    case .moveSession: self = .moveSession(toDate: try container.decode(String.self, forKey: .toDate))
    case .adaptDuration: self = .adaptDuration(maximumMinutes: try container.decode(Int.self, forKey: .maximumMinutes))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .replacement: try container.encode(Kind.replacement, forKey: .type)
    case let .setAdjustment(request):
      try container.encode(Kind.setAdjustment, forKey: .type)
      try container.encode(request, forKey: .adjustment)
    case let .moveSession(toDate):
      try container.encode(Kind.moveSession, forKey: .type)
      try container.encode(toDate, forKey: .toDate)
    case let .adaptDuration(maximumMinutes):
      try container.encode(Kind.adaptDuration, forKey: .type)
      try container.encode(maximumMinutes, forKey: .maximumMinutes)
    }
  }
}

public struct CoachConversationDraft: Codable, Equatable, Sendable {
  public var request: PlanningIntentRequest
  public var activeTask: CoachConversationPendingTask
  public var queuedTasks: [CoachConversationPendingTask]
  public var stagedOperations: [PlanningOperation]
  public var stagedSummaries: [String]

  public init(request: PlanningIntentRequest, activeTask: CoachConversationPendingTask, queuedTasks: [CoachConversationPendingTask], stagedOperations: [PlanningOperation], stagedSummaries: [String]) {
    self.request = request
    self.activeTask = activeTask
    self.queuedTasks = queuedTasks
    self.stagedOperations = stagedOperations
    self.stagedSummaries = stagedSummaries
  }
}
