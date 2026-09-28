import Foundation
import SwiftData
import GymAppNativeCore

enum HealthWorkoutSyncStatus: String, Codable {
  case pending
  case syncing
  case synced
  case failed
}

@Model
final class ActiveWorkoutRecord {
  @Attribute(.unique) var id: String
  var snapshotData: Data
  var updatedAt: Date

  init(id: String = "active-workout", snapshotData: Data, updatedAt: Date = .now) {
    self.id = id
    self.snapshotData = snapshotData
    self.updatedAt = updatedAt
  }
}

@Model
final class CompletedWorkoutRecord {
  @Attribute(.unique) var sessionID: String
  var completedAt: Date
  var startedAt: Date?
  var executionData: Data?
  var decisionsData: Data?
  var importedSessionData: Data?
  var healthKitWorkoutUUID: String?
  var healthKitSyncStatusRaw: String?
  var healthKitLastAttemptAt: Date?
  var healthKitLastError: String?

  var healthKitSyncStatus: HealthWorkoutSyncStatus {
    get {
      if healthKitWorkoutUUID != nil { return .synced }
      return healthKitSyncStatusRaw.flatMap(HealthWorkoutSyncStatus.init(rawValue:)) ?? .pending
    }
    set { healthKitSyncStatusRaw = newValue.rawValue }
  }

  init(
    sessionID: String,
    startedAt: Date?,
    completedAt: Date = .now,
    executionData: Data? = nil,
    decisionsData: Data? = nil,
    importedSessionData: Data? = nil,
    healthKitWorkoutUUID: String? = nil,
    healthKitSyncStatus: HealthWorkoutSyncStatus = .pending,
    healthKitLastAttemptAt: Date? = nil,
    healthKitLastError: String? = nil
  ) {
    self.sessionID = sessionID
    self.startedAt = startedAt
    self.completedAt = completedAt
    self.executionData = executionData
    self.decisionsData = decisionsData
    self.importedSessionData = importedSessionData
    self.healthKitWorkoutUUID = healthKitWorkoutUUID
    healthKitSyncStatusRaw = healthKitSyncStatus.rawValue
    self.healthKitLastAttemptAt = healthKitLastAttemptAt
    self.healthKitLastError = healthKitLastError
  }
}

@Model
final class TrainingProfileRecord {
  @Attribute(.unique) var id: String
  var profileData: Data
  var updatedAt: Date

  init(id: String = "training-profile", profileData: Data, updatedAt: Date = .now) {
    self.id = id
    self.profileData = profileData
    self.updatedAt = updatedAt
  }
}

enum TrainingGoal: String, Codable, CaseIterable, Identifiable {
  case strength
  case muscle
  case health
  case performance

  var id: String { rawValue }
  var label: String {
    switch self {
    case .strength: "Fuerza"
    case .muscle: "Masa muscular"
    case .health: "Salud y constancia"
    case .performance: "Rendimiento"
    }
  }
}

enum TrainingExperience: String, Codable, CaseIterable, Identifiable {
  case beginner
  case intermediate
  case advanced

  var id: String { rawValue }
  var label: String {
    switch self {
    case .beginner: "Principiante"
    case .intermediate: "Intermedio"
    case .advanced: "Avanzado"
    }
  }
}

struct TrainingProfile: Codable, Equatable {
  var goal: TrainingGoal
  var targetTimeframeWeeks: Int
  var experience: TrainingExperience
  var trainingWeekdays: Set<Int>
  var sessionDurationMinutes: Int
  var availableEquipment: Set<Equipment>
  var dumbbellWeightsKg: [Double]
  var dumbbellUnitsByWeight: [String: Int]
  var plateWeightsKg: [Double]
  var plateUnitsByWeight: [String: Int]
  var cableStepKg: Double
  var barbellWeightKg: Double
  var multipowerBarWeightKg: Double
  var priorityMuscleGroups: [String]
  var exercisePreferences: String
  var exercisesToAvoid: String
  var limitations: String
  var declaredDiscomforts: [String]

  init(
    goal: TrainingGoal,
    targetTimeframeWeeks: Int,
    experience: TrainingExperience,
    trainingWeekdays: Set<Int>,
    sessionDurationMinutes: Int,
    availableEquipment: Set<Equipment>,
    dumbbellWeightsKg: [Double],
    dumbbellUnitsByWeight: [String: Int],
    plateWeightsKg: [Double],
    plateUnitsByWeight: [String: Int],
    cableStepKg: Double,
    barbellWeightKg: Double,
    multipowerBarWeightKg: Double,
    priorityMuscleGroups: [String],
    exercisePreferences: String,
    exercisesToAvoid: String,
    limitations: String,
    declaredDiscomforts: [String] = []
  ) {
    self.goal = goal
    self.targetTimeframeWeeks = targetTimeframeWeeks
    self.experience = experience
    self.trainingWeekdays = trainingWeekdays
    self.sessionDurationMinutes = sessionDurationMinutes
    self.availableEquipment = availableEquipment
    self.dumbbellWeightsKg = dumbbellWeightsKg
    self.dumbbellUnitsByWeight = dumbbellUnitsByWeight
    self.plateWeightsKg = plateWeightsKg
    self.plateUnitsByWeight = plateUnitsByWeight
    self.cableStepKg = cableStepKg
    self.barbellWeightKg = barbellWeightKg
    self.multipowerBarWeightKg = multipowerBarWeightKg
    self.priorityMuscleGroups = priorityMuscleGroups
    self.exercisePreferences = exercisePreferences
    self.exercisesToAvoid = exercisesToAvoid
    self.limitations = limitations
    self.declaredDiscomforts = declaredDiscomforts
  }

  private enum CodingKeys: String, CodingKey {
    case goal, targetTimeframeWeeks, experience, trainingWeekdays, sessionDurationMinutes
    case availableEquipment, dumbbellWeightsKg, dumbbellUnitsByWeight, plateWeightsKg, plateUnitsByWeight, cableStepKg
    case barbellWeightKg, multipowerBarWeightKg, priorityMuscleGroups
    case exercisePreferences, exercisesToAvoid, limitations, declaredDiscomforts
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let defaults = TrainingProfile.initial
    goal = try container.decodeIfPresent(TrainingGoal.self, forKey: .goal) ?? defaults.goal
    targetTimeframeWeeks = try container.decodeIfPresent(Int.self, forKey: .targetTimeframeWeeks) ?? defaults.targetTimeframeWeeks
    experience = try container.decodeIfPresent(TrainingExperience.self, forKey: .experience) ?? defaults.experience
    trainingWeekdays = try container.decodeIfPresent(Set<Int>.self, forKey: .trainingWeekdays) ?? defaults.trainingWeekdays
    sessionDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .sessionDurationMinutes) ?? defaults.sessionDurationMinutes
    availableEquipment = try container.decodeIfPresent(Set<Equipment>.self, forKey: .availableEquipment) ?? defaults.availableEquipment
    dumbbellWeightsKg = try container.decodeIfPresent([Double].self, forKey: .dumbbellWeightsKg) ?? defaults.dumbbellWeightsKg
    dumbbellUnitsByWeight = try container.decodeIfPresent([String: Int].self, forKey: .dumbbellUnitsByWeight) ?? defaults.dumbbellUnitsByWeight
    plateWeightsKg = try container.decodeIfPresent([Double].self, forKey: .plateWeightsKg) ?? defaults.plateWeightsKg
    plateUnitsByWeight = try container.decodeIfPresent([String: Int].self, forKey: .plateUnitsByWeight) ?? defaults.plateUnitsByWeight
    cableStepKg = try container.decodeIfPresent(Double.self, forKey: .cableStepKg) ?? defaults.cableStepKg
    barbellWeightKg = try container.decodeIfPresent(Double.self, forKey: .barbellWeightKg) ?? defaults.barbellWeightKg
    multipowerBarWeightKg = try container.decodeIfPresent(Double.self, forKey: .multipowerBarWeightKg) ?? defaults.multipowerBarWeightKg
    priorityMuscleGroups = try container.decodeIfPresent([String].self, forKey: .priorityMuscleGroups) ?? defaults.priorityMuscleGroups
    exercisePreferences = try container.decodeIfPresent(String.self, forKey: .exercisePreferences) ?? defaults.exercisePreferences
    exercisesToAvoid = try container.decodeIfPresent(String.self, forKey: .exercisesToAvoid) ?? defaults.exercisesToAvoid
    limitations = try container.decodeIfPresent(String.self, forKey: .limitations) ?? defaults.limitations
    declaredDiscomforts = try container.decodeIfPresent([String].self, forKey: .declaredDiscomforts)
      ?? Self.discomforts(from: limitations)
  }

  static let initial = TrainingProfile(
    goal: .strength,
    targetTimeframeWeeks: 16,
    experience: .intermediate,
    trainingWeekdays: [1, 2, 4, 5],
    sessionDurationMinutes: 60,
    availableEquipment: Set(Equipment.allCases),
    dumbbellWeightsKg: [5, 6, 7.5, 8, 9, 10, 12.5, 15, 17.5, 20, 22.5, 25, 27.5, 30],
    dumbbellUnitsByWeight: [:],
    plateWeightsKg: [1.25, 2.5, 5, 10, 15, 20],
    plateUnitsByWeight: ["1.25": 4, "2.50": 4, "5.00": 12, "10.00": 12, "15.00": 2, "20.00": 4],
    cableStepKg: 5,
    barbellWeightKg: 20,
    multipowerBarWeightKg: 18,
    priorityMuscleGroups: [],
    exercisePreferences: "",
    exercisesToAvoid: "",
    limitations: "",
    declaredDiscomforts: []
  )

  var loadInventory: EquipmentLoadInventory {
    return EquipmentLoadInventory(
      dumbbellLoadsKg: dumbbellWeightsKg,
      plates: plateWeightsKg.map { PlateLoad(weightKg: $0, count: plateUnits(for: $0)) },
      cableStepKg: max(0.5, cableStepKg),
      barbellWeightKg: max(0, barbellWeightKg),
      multipowerBarWeightKg: max(0, multipowerBarWeightKg)
    )
  }

  func dumbbellUnits(for weight: Double) -> Int { max(1, dumbbellUnitsByWeight[loadKey(weight)] ?? 2) }
  func plateUnits(for weight: Double) -> Int { max(1, plateUnitsByWeight[loadKey(weight)] ?? 2) }
  func loadKey(_ weight: Double) -> String { String(format: "%.2f", weight) }

  private static func discomforts(from value: String) -> [String] {
    value
      .split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "\n" })
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }
}

@MainActor
enum TrainingProfileStore {
  static let recordID = "training-profile"

  static func load(from records: [TrainingProfileRecord]) -> TrainingProfile? {
    guard let record = records.first(where: { $0.id == recordID }) else { return nil }
    return try? JSONDecoder().decode(TrainingProfile.self, from: record.profileData)
  }

  static func save(_ profile: TrainingProfile, in context: ModelContext) {
    guard let data = try? JSONEncoder().encode(profile) else { return }
    let descriptor = FetchDescriptor<TrainingProfileRecord>(
      predicate: #Predicate { $0.id == recordID }
    )
    if let record = try? context.fetch(descriptor).first {
      record.profileData = data
      record.updatedAt = .now
    } else {
      context.insert(TrainingProfileRecord(profileData: data))
    }
    try? context.save()
  }
}

@MainActor
enum ActiveWorkoutStore {
  static let recordID = "active-workout"

  static func load(from records: [ActiveWorkoutRecord]) -> ActiveWorkoutSnapshot? {
    guard let record = records.first(where: { $0.id == recordID }),
          let snapshot = try? JSONDecoder().decode(ActiveWorkoutSnapshot.self, from: record.snapshotData),
          (3 ... ActiveWorkoutSnapshot.currentSchemaVersion).contains(snapshot.schemaVersion)
    else {
      return nil
    }
    return snapshot
  }

  static func save(_ snapshot: ActiveWorkoutSnapshot, in context: ModelContext) {
    guard let data = try? JSONEncoder().encode(snapshot) else { return }

    let descriptor = FetchDescriptor<ActiveWorkoutRecord>(
      predicate: #Predicate { $0.id == recordID }
    )
    if let record = try? context.fetch(descriptor).first {
      record.snapshotData = data
      record.updatedAt = .now
    } else {
      context.insert(ActiveWorkoutRecord(snapshotData: data))
    }

    try? context.save()
  }

  static func clear(in context: ModelContext) {
    let descriptor = FetchDescriptor<ActiveWorkoutRecord>(
      predicate: #Predicate { $0.id == recordID }
    )
    guard let records = try? context.fetch(descriptor) else { return }
    records.forEach(context.delete)
    try? context.save()
  }

  static func markCompleted(
    sessionID: String,
    startedAt: Date,
    completedAt: Date,
    execution: WorkoutExecutionState,
    decisions: [String: String],
    in context: ModelContext
  ) -> CompletedWorkoutRecord? {
    let descriptor = FetchDescriptor<CompletedWorkoutRecord>(
      predicate: #Predicate { $0.sessionID == sessionID }
    )
    if let existing = try? context.fetch(descriptor).first { return existing }
    let record = CompletedWorkoutRecord(
        sessionID: sessionID,
        startedAt: startedAt,
        completedAt: completedAt,
        executionData: try? JSONEncoder().encode(execution),
        decisionsData: try? JSONEncoder().encode(decisions)
      )
    context.insert(record)
    try? context.save()
    return record
  }
}
