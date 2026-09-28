import Foundation

/// A partially resolved set adjustment from the local or future remote coach.
/// It names the change requested but deliberately leaves exercise and set
/// selection to the local clarification UI when the message is ambiguous.
public struct CoachSetAdjustmentRequest: Codable, Equatable, Sendable {
  public enum Kind: String, Codable, Sendable {
    case reps
    case weight
    case rest
  }

  public enum Direction: String, Codable, Sendable {
    case increase
    case decrease
  }

  public enum Scope: String, Codable, CaseIterable, Sendable {
    case singleSet
    case matchingSets
  }

  public var kind: Kind
  public var direction: Direction
  /// When present, this is the requested final value, not a delta.
  public var targetValue: Double?
  public var scope: Scope

  public init(kind: Kind, direction: Direction, targetValue: Double? = nil, scope: Scope = .singleSet) {
    self.kind = kind
    self.direction = direction
    self.targetValue = targetValue
    self.scope = scope
  }
}
