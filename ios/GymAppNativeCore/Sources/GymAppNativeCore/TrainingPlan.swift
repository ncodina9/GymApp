import Foundation

public enum Equipment: String, Codable, CaseIterable, Sendable, Hashable {
  case barbell
  case multipower
  case dumbbell
  case cable
  case plateLoadedMachine = "plate_loaded_machine"
  case external
  case bodyweight
}

public enum TrainingSetKind: String, Codable, Sendable {
  case working
  case timed
}

public struct TrainingPlan: Codable, Sendable {
  public var planID: String
  public var sourceDocument: String
  public var startsOn: String
  public var endsOn: String
  public var durationWeeks: Int
  public var sessions: [TrainingSession]

  enum CodingKeys: String, CodingKey {
    case planID = "planId"
    case sourceDocument
    case startsOn
    case endsOn
    case durationWeeks
    case sessions
  }
}

public struct TrainingSession: Codable, Identifiable, Sendable {
  public var sessionID: String
  public var date: String
  public var week: Int
  public var weekday: String
  public var sessionLabel: String
  public var label: String
  public var estimatedMinutes: Int
  public var focus: String
  public var weekFocusLabel: String
  public var weekFocus: String
  public var exercises: [TrainingExercise]
  public var cancelled: Bool?

  public var id: String { sessionID }
  public var isCancelled: Bool { cancelled ?? false }

  enum CodingKeys: String, CodingKey {
    case sessionID = "sessionId"
    case date
    case week
    case weekday
    case sessionLabel
    case label
    case estimatedMinutes
    case focus
    case weekFocusLabel
    case weekFocus
    case exercises
    case cancelled
  }
}

public struct TrainingExercise: Codable, Identifiable, Sendable {
  public var exerciseID: String
  public var name: String
  public var baseExerciseID: String
  public var baseExerciseName: String
  public var variantLabel: String?
  public var type: String
  public var block: String
  public var equipment: Equipment
  public var equipmentOptions: [Equipment]?
  public var trainingBlock: String?
  public var movementPattern: String?
  public var primaryMuscles: [String]
  public var secondaryMuscles: [String]
  public var supersetID: String?
  public var supersetOrder: Int?
  public var phase: String
  public var notes: String
  public var target: String
  public var decisionOptions: [String]
  public var sets: [TrainingSet]

  public var id: String { exerciseID }

  enum CodingKeys: String, CodingKey {
    case exerciseID = "exerciseId"
    case name
    case baseExerciseID = "baseExerciseId"
    case baseExerciseName
    case variantLabel
    case type
    case block
    case equipment
    case equipmentOptions
    case trainingBlock
    case movementPattern
    case primaryMuscles
    case secondaryMuscles
    case supersetID = "supersetId"
    case supersetOrder
    case phase
    case notes
    case target
    case decisionOptions
    case sets
  }
}

public extension TrainingExercise {
  var displayGroupID: String {
    switch baseExerciseID {
    case "press-banca-agarre-cerrado":
      "press-banca"
    case "curl-biceps", "curl-biceps-alterno", "curl-martillo":
      "curl-biceps"
    case "dominadas-supinas":
      "dominadas"
    case "elevacion-gemelos", "elevacion-gemelos-sentado":
      "elevacion-gemelos"
    case "peso-muerto-rumano", "rdl-tecnico":
      "peso-muerto-rumano"
    case "elevacion-lateral-mecanica":
      "elevaciones-laterales"
    default:
      baseExerciseID
    }
  }

  /// Groups plan variants under a stable name for execution and history views.
  var displayName: String {
    switch baseExerciseID {
    case "press-banca-agarre-cerrado":
      "Press banca"
    case "curl-biceps", "curl-biceps-alterno", "curl-martillo":
      "Curl de bíceps"
    case "dominadas-supinas":
      "Dominadas"
    case "elevacion-gemelos", "elevacion-gemelos-sentado":
      "Elevación de gemelos"
    case "peso-muerto-rumano", "rdl-tecnico":
      "Peso muerto rumano"
    case "elevacion-lateral-mecanica":
      "Elevaciones laterales"
    default:
      baseExerciseName
    }
  }

  /// Variación técnica mostrada en las recomendaciones, sin repetir el material.
  var coachingVariationName: String? {
    switch exerciseID {
    case "press-cerrado-multipower":
      "Agarre cerrado"
    default:
      nil
    }
  }

  /// Materiales que la app puede convertir con las reglas del gimnasio.
  var selectableEquipmentOptions: [Equipment] {
    if let equipmentOptions, !equipmentOptions.isEmpty {
      return equipmentOptions
    }

    let alternatives: [Equipment] = switch exerciseID {
    case "press-banca-barra", "press-banca-inclinado", "press-militar-sentado", "press-militar-sentado-velocidad":
      [.barbell, .multipower, .dumbbell]
    case "press-cerrado-multipower":
      [.multipower, .dumbbell]
    case "remo-inclinado-barra", "remo-barra-multipower", "hip-thrust-barra", "hip-thrust-volumen", "peso-muerto-rumano-barra", "rdl-tecnico":
      [.barbell, .multipower]
    default:
      [equipment]
    }

    return alternatives.contains(equipment) ? alternatives : [equipment] + alternatives
  }
}

/// A deterministic catalogue for selection UIs. It preserves the concrete
/// exercise identifier required by plan operations while exposing one entry
/// for every user-facing exercise family.
public enum TrainingExerciseCatalog {
  public static func canonicalExercises(
    in sessions: [TrainingSession],
    excludingDisplayGroupID excludedGroupID: String? = nil
  ) -> [TrainingExercise] {
    var seen = Set<String>()
    return sessions
      .flatMap(\.exercises)
      .filter { exercise in
        guard exercise.displayGroupID != excludedGroupID else { return false }
        return seen.insert(exercise.displayGroupID).inserted
      }
      .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
  }
}

public struct TrainingSet: Codable, Identifiable, Sendable {
  public var setIndex: Int
  public var targetReps: Int?
  public var targetWeightKg: Double
  public var bodyweightLoad: BodyweightLoad?
  public var targetDurationSeconds: Int?
  public var restSeconds: Int
  public var type: TrainingSetKind

  public var id: Int { setIndex }
}

/// Explicit support or external load for a bodyweight set. Existing plans omit
/// this value and therefore retain their unassisted, unweighted meaning.
public struct BodyweightLoad: Codable, Equatable, Sendable {
  public enum Mode: String, Codable, Sendable {
    case unassisted
    case assisted
    case weighted
  }

  public var assistanceKg: Double
  public var addedWeightKg: Double

  public init(assistanceKg: Double = 0, addedWeightKg: Double = 0) {
    self.assistanceKg = max(0, assistanceKg)
    self.addedWeightKg = max(0, addedWeightKg)
  }

  public var mode: Mode {
    assistanceKg > 0 ? .assisted : (addedWeightKg > 0 ? .weighted : .unassisted)
  }
}

public enum TrainingPlanLoader {
  public static func decode(data: Data) throws -> TrainingPlan {
    try JSONDecoder().decode(TrainingPlan.self, from: data)
  }
}
