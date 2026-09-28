import Foundation
import GymAppNativeCore

struct ProfilePlanningRestrictions: Equatable {
  var exerciseIDs: Set<String>
  var movementPatterns: Set<String>
  var avoidsSupersets: Bool

  static func compile(from profile: TrainingProfile) -> Self {
    let text = normalized("\(profile.exercisesToAvoid) \(profile.limitations) \(profile.declaredDiscomforts.joined(separator: " "))")
    var patterns = Set<String>()
    var exercises = Set<String>()

    if text.contains("hombro") {
      patterns.formUnion(["empuje-vertical", "abduccion-hombro", "extension-hombro"])
    }
    if text.contains("rodilla") {
      patterns.formUnion(["dominante-rodilla", "extension-rodilla", "flexion-rodilla"])
    }
    if text.contains("lumbar") || text.contains("espalda baja") {
      patterns.formUnion(["bisagra-cadera", "extension-cadera", "anti-extension"])
    }
    if text.contains("codo") || text.contains("muneca") {
      patterns.formUnion(["flexion-codo", "extension-codo"])
    }
    if text.contains("fondos") { exercises.insert("fondos") }
    if text.contains("peso muerto") { patterns.insert("bisagra-cadera") }

    return Self(
      exerciseIDs: exercises,
      movementPatterns: patterns,
      avoidsSupersets: text.contains("sin superseries") || text.contains("evitar superseries")
    )
  }

  private static func normalized(_ value: String) -> String {
    value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_ES"))
  }
}

extension TrainingProfile {
  func planningConstraints(
    activeSessionID: String?,
    completedSessionIDs: Set<String>,
    referenceDate: Date = .now
  ) -> PlanningConstraints {
    let restrictions = ProfilePlanningRestrictions.compile(from: self)
    return PlanningConstraints(
      availableWeekdays: trainingWeekdays,
      availableEquipment: availableEquipment,
      restrictedExerciseIDs: restrictions.exerciseIDs,
      restrictedMovementPatterns: restrictions.movementPatterns,
      avoidsSupersets: restrictions.avoidsSupersets,
      maxSessionMinutes: sessionDurationMinutes,
      activeSessionID: activeSessionID,
      completedSessionIDs: completedSessionIDs,
      referenceDate: referenceDate
    )
  }
}
