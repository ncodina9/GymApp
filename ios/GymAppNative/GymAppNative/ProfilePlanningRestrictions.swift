import Foundation
import GymAppNativeCore

struct ProfilePlanningRestrictions: Equatable {
  var exerciseIDs: Set<String>
  var movementPatterns: Set<String>
  var cautionMovementPatterns: Set<String>
  var avoidsSupersets: Bool

  static func compile(from profile: TrainingProfile) -> Self {
    let text = normalized("\(profile.exercisesToAvoid) \(profile.limitations) \(profile.declaredInjuries.joined(separator: " "))")
    let discomfortText = normalized(profile.declaredDiscomforts.joined(separator: " "))
    var patterns = Set<String>()
    var cautionPatterns = Set<String>()
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

    if discomfortText.contains("hombro") {
      cautionPatterns.formUnion(["empuje-vertical", "abduccion-hombro", "extension-hombro"])
    }
    if discomfortText.contains("rodilla") {
      cautionPatterns.formUnion(["dominante-rodilla", "extension-rodilla", "flexion-rodilla"])
    }
    if discomfortText.contains("lumbar") || discomfortText.contains("espalda baja") {
      cautionPatterns.formUnion(["bisagra-cadera", "extension-cadera", "anti-extension"])
    }
    if discomfortText.contains("codo") || discomfortText.contains("muneca") {
      cautionPatterns.formUnion(["flexion-codo", "extension-codo"])
    }

    return Self(
      exerciseIDs: exercises,
      movementPatterns: patterns,
      cautionMovementPatterns: cautionPatterns,
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
      disabledEquipmentByBaseExercise: catalogPreferences.disabledEquipmentByBaseExercise,
      restrictedExerciseIDs: restrictions.exerciseIDs
        .union(catalogPreferences.disabledBaseExerciseIDs)
        .union(catalogPreferences.disabledVariantExerciseIDs),
      restrictedMovementPatterns: restrictions.movementPatterns,
      cautionMovementPatterns: restrictions.cautionMovementPatterns,
      avoidsSupersets: restrictions.avoidsSupersets,
      maxSessionMinutes: sessionDurationMinutes,
      priorityMuscleGroups: Set(priorityMuscleGroups.map {
        $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es_ES"))
      }),
      activeSessionID: activeSessionID,
      completedSessionIDs: completedSessionIDs,
      referenceDate: referenceDate
    )
  }
}
