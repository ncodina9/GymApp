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
  public let planID: String
  public let sourceDocument: String
  public let startsOn: String
  public let endsOn: String
  public let durationWeeks: Int
  public let sessions: [TrainingSession]

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
  public let sessionID: String
  public let date: String
  public let week: Int
  public let weekday: String
  public let sessionLabel: String
  public let label: String
  public let estimatedMinutes: Int
  public let focus: String
  public let weekFocusLabel: String
  public let weekFocus: String
  public let exercises: [TrainingExercise]

  public var id: String { sessionID }

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
  }
}

public struct TrainingExercise: Codable, Identifiable, Sendable {
  public let exerciseID: String
  public let name: String
  public let baseExerciseID: String
  public let baseExerciseName: String
  public let variantLabel: String?
  public let type: String
  public let block: String
  public let equipment: Equipment
  public let equipmentOptions: [Equipment]?
  public let trainingBlock: String?
  public let movementPattern: String?
  public let primaryMuscles: [String]
  public let secondaryMuscles: [String]
  public let supersetID: String?
  public let supersetOrder: Int?
  public let phase: String
  public let notes: String
  public let target: String
  public let decisionOptions: [String]
  public let sets: [TrainingSet]

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
    case "curl-biceps", "curl-biceps-alterno", "curl-martillo":
      "curl-biceps"
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
    case "curl-biceps", "curl-biceps-alterno", "curl-martillo":
      "Curl de bíceps"
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

public struct TrainingSet: Codable, Identifiable, Sendable {
  public let setIndex: Int
  public let targetReps: Int?
  public let targetWeightKg: Double
  public let targetDurationSeconds: Int?
  public let restSeconds: Int
  public let type: TrainingSetKind

  public var id: Int { setIndex }
}

public enum TrainingPlanLoader {
  public static func decode(data: Data) throws -> TrainingPlan {
    try JSONDecoder().decode(TrainingPlan.self, from: data)
  }
}
