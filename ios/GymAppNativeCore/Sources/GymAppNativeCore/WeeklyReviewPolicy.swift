import Foundation

/// Pure safeguards shared by weekly-review implementations and tests.
public enum WeeklyReviewPolicy {
  /// Timed work has no meaningful repetitions in reserve, including legacy
  /// records that may still contain a persisted RIR value.
  public static func includesRIR(durationSeconds: Int?) -> Bool {
    durationSeconds == nil
  }

  /// Weight observations are only comparable when they were performed with
  /// the same equipment as the future prescription.
  public static func performedWeight(
    in observedWeights: [Equipment: Double],
    matching equipment: Equipment
  ) -> Double? {
    observedWeights[equipment]
  }

  /// The future plan must not receive a second load increase when it already
  /// asks for more weight than the completed session achieved.
  public static func allowsAutomaticLoadIncrease(
    phase: String,
    averageRIR: Double?,
    performedWeightKg: Double?,
    plannedWeightKg: Double
  ) -> Bool {
    normalized(phase) == "intensificacion"
      && (averageRIR ?? 0) >= 2
      && plannedWeightKg > 0
      && (performedWeightKg ?? 0) >= plannedWeightKg
  }

  /// A superset can only progress when every member has independently met
  /// its progression condition.
  public static func allowsSupersetProgression(memberEligibility: [Bool]) -> Bool {
    !memberEligibility.isEmpty && memberEligibility.allSatisfy { $0 }
  }

  private static func normalized(_ value: String) -> String {
    value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es_ES"))
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
