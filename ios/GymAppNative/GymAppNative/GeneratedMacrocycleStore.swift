import Foundation
import SwiftData
import GymAppNativeCore

@Model
final class GeneratedMacrocycleRecord {
  @Attribute(.unique) var id: String
  @Attribute(.unique) var planID: String
  var planData: Data
  var sourcePlanID: String
  var createdAt: Date
  var activatedAt: Date
  var isActive: Bool

  init(
    id: String = UUID().uuidString,
    planID: String,
    planData: Data,
    sourcePlanID: String,
    createdAt: Date = .now,
    activatedAt: Date = .now,
    isActive: Bool = true
  ) {
    self.id = id
    self.planID = planID
    self.planData = planData
    self.sourcePlanID = sourcePlanID
    self.createdAt = createdAt
    self.activatedAt = activatedAt
    self.isActive = isActive
  }
}

@MainActor
enum ActiveTrainingPlanStore {
  static func load(from records: [GeneratedMacrocycleRecord]) -> TrainingPlan? {
    records
      .filter(\.isActive)
      .sorted { $0.activatedAt > $1.activatedAt }
      .compactMap { try? TrainingPlanLoader.decode(data: $0.planData) }
      .first
  }

  static func activate(
    _ plan: TrainingPlan,
    sourcePlanID: String,
    records: [GeneratedMacrocycleRecord],
    in context: ModelContext
  ) throws {
    let data = try JSONEncoder().encode(plan)
    for record in records where record.isActive {
      record.isActive = false
    }
    context.insert(GeneratedMacrocycleRecord(
      planID: plan.planID,
      planData: data,
      sourcePlanID: sourcePlanID
    ))
    try context.save()
  }
}

struct MacrocycleGenerationRequest {
  let durationWeeks: Int
  let goal: TrainingGoal
  let objective: String
}

enum MacrocycleGenerator {
  private enum Phase: Equatable {
    case accumulation
    case intensification
    case deload

    var label: String {
      switch self {
      case .accumulation: "Acumulación"
      case .intensification: "Intensificación"
      case .deload: "Descarga"
      }
    }
  }

  static func generate(
    from previousPlan: TrainingPlan,
    profile: TrainingProfile,
    request: MacrocycleGenerationRequest,
    referenceDate: Date = .now
  ) -> TrainingPlan? {
    let availableSessions = previousPlan.sessions
      .filter { !$0.isCancelled }
      .filter { profile.trainingWeekdays.contains(profileWeekday(for: $0.date)) }
    let candidateWeeks = Set(availableSessions.map(\.week)).sorted(by: >)
    let sourceWeek = candidateWeeks.first { week in
      availableSessions
        .filter { $0.week == week }
        .flatMap(\.exercises)
        .contains { !isRecoveryPhase($0.phase) }
    } ?? candidateWeeks.first
    let sourceSessions = availableSessions
      .filter { $0.week == sourceWeek }
      .sorted { $0.date < $1.date }
    guard !sourceSessions.isEmpty else { return nil }

    let duration = min(max(request.durationWeeks, 4), 24)
    let start = nextMonday(after: referenceDate)
    let catalog = ExerciseCatalogStore.entries(for: previousPlan)
    var generatedSessions: [TrainingSession] = []

    for weekOffset in 0..<duration {
      let phase = phase(for: weekOffset, duration: duration)
      for (sessionOffset, source) in sourceSessions.enumerated() {
        var session = source
        let date = scheduledDate(
          for: source,
          starting: start,
          weekOffset: weekOffset
        )
        session.sessionID = "macro-\(dateString(start))-w\(weekOffset + 1)-s\(sessionOffset + 1)"
        session.date = dateString(date)
        session.week = weekOffset + 1
        session.estimatedMinutes = min(source.estimatedMinutes, profile.sessionDurationMinutes)
        session.weekFocusLabel = phase.label
        session.weekFocus = focus(for: phase, goal: request.goal, objective: request.objective)
        session.focus = session.weekFocus
        var usedExerciseGroups = Set<String>()
        session.exercises = source.exercises.enumerated().compactMap { exerciseOffset, sourceExercise in
          let exercise = prescribedExercise(
            from: sourceExercise,
            catalog: catalog,
            profile: profile,
            phase: phase,
            weekOffset: weekOffset,
            sessionOffset: sessionOffset,
            exerciseOffset: exerciseOffset,
            objective: request.objective,
            goal: request.goal,
            usedExerciseGroups: &usedExerciseGroups
          )
          return exercise
        }
        if !session.exercises.isEmpty {
          generatedSessions.append(session)
        }
      }
    }

    guard let lastDate = generatedSessions.map(\.date).max() else { return nil }
    let identifier = "macrocycle-\(dateString(start))-\(UUID().uuidString.prefix(8).lowercased())"
    return TrainingPlan(
      planID: identifier,
      sourceDocument: "Macrociclo generado en la app",
      startsOn: dateString(start),
      endsOn: lastDate,
      durationWeeks: duration,
      sessions: generatedSessions.sorted { $0.date < $1.date }
    )
  }

  private static func phase(for weekOffset: Int, duration: Int) -> Phase {
    if duration >= 4, weekOffset == duration - 1 { return .deload }
    let accumulationWeeks = max(1, Int((Double(duration) * 0.6).rounded(.down)))
    return weekOffset < accumulationWeeks ? .accumulation : .intensification
  }

  private static func isRecoveryPhase(_ value: String) -> Bool {
    let normalized = value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es_ES"))
    return normalized == "descarga" || normalized == "readaptacion" || normalized == "test"
  }

  private static func prescribedExercise(
    from source: TrainingExercise,
    catalog: [ExerciseCatalogEntry],
    profile: TrainingProfile,
    phase: Phase,
    weekOffset: Int,
    sessionOffset: Int,
    exerciseOffset: Int,
    objective: String,
    goal: TrainingGoal,
    usedExerciseGroups: inout Set<String>
  ) -> TrainingExercise? {
    let restrictions = ProfilePlanningRestrictions.compile(from: profile)
    let candidates = catalog.filter { entry in
      let compatiblePattern = entry.movementPattern == source.movementPattern
      let sharedMuscle = !Set(entry.primaryMuscles).isDisjoint(with: Set(source.primaryMuscles))
      return (compatiblePattern || sharedMuscle)
        && !usedExerciseGroups.contains(entry.baseExerciseID)
        && !profile.catalogPreferences.disabledBaseExerciseIDs.contains(entry.baseExerciseID)
        && !restrictions.exerciseIDs.contains(entry.baseExerciseID)
        && !restrictions.movementPatterns.contains(entry.movementPattern ?? "")
        && entry.equipment.contains { equipment in
          profile.availableEquipment.contains(equipment)
            && profile.catalogPreferences.allows(equipment, for: entry.baseExerciseID)
        }
    }
    let ordered = candidates.sorted { lhs, rhs in
      let lhsMatchesSource = lhs.baseExerciseID == source.displayGroupID
      let rhsMatchesSource = rhs.baseExerciseID == source.displayGroupID
      if phase == .intensification, lhsMatchesSource != rhsMatchesSource { return lhsMatchesSource }
      return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
    guard !ordered.isEmpty else { return nil }

    let rotation = weekOffset + (sessionOffset * 2) + exerciseOffset
    let entry: ExerciseCatalogEntry
    if phase == .intensification,
       let sourceFamily = ordered.first(where: { $0.baseExerciseID == source.displayGroupID }) {
      entry = sourceFamily
    } else {
      entry = ordered[rotation % ordered.count]
    }
    let equipmentOptions = entry.equipment.filter {
      profile.availableEquipment.contains($0)
        && profile.catalogPreferences.allows($0, for: entry.baseExerciseID)
    }
    let sortedEquipment = equipmentOptions.sorted { $0.executionLabel < $1.executionLabel }
    guard !sortedEquipment.isEmpty else { return nil }
    let equipment = sortedEquipment[rotation % sortedEquipment.count]

    var exercise = entry.replacementTemplate(for: source)
    exercise.exerciseID = "macro-\(entry.baseExerciseID)-w\(weekOffset + 1)-s\(sessionOffset + 1)-e\(exerciseOffset + 1)"
    exercise.equipment = equipment
    exercise.equipmentOptions = equipmentOptions
    exercise.supersetID = nil
    exercise.supersetOrder = nil
    exercise.phase = phase.label
    exercise.target = target(for: phase, goal: goal, objective: objective)
    exercise.notes = "Selección del catálogo para \(phase.label.lowercased()): prioriza técnica, rango cómodo y el objetivo semanal."
    exercise.sets = prescribedSets(from: source.sets, equipment: equipment, profile: profile, phase: phase)
    guard !exercise.sets.isEmpty else { return nil }
    usedExerciseGroups.insert(entry.baseExerciseID)
    return exercise
  }

  private static func prescribedSets(
    from sourceSets: [TrainingSet],
    equipment: Equipment,
    profile: TrainingProfile,
    phase: Phase
  ) -> [TrainingSet] {
    let setLimit = phase == .deload ? max(1, sourceSets.count - 1) : sourceSets.count
    let selectedSets = Array(sourceSets.prefix(setLimit))
    let availableLoads = EquipmentLoadRules.availableLoads(for: equipment, inventory: profile.loadInventory)
    return selectedSets.enumerated().map { index, sourceSet in
      var set = sourceSet
      set.setIndex = index + 1
      if set.type == .working, let reps = set.targetReps {
        switch phase {
        case .accumulation: set.targetReps = min(15, max(6, reps))
        case .intensification: set.targetReps = min(8, max(4, reps))
        case .deload: set.targetReps = max(5, reps - 2)
        }
      }
      if equipment == .bodyweight {
        set.targetWeightKg = 0
        set.bodyweightLoad = nil
      } else if !availableLoads.contains(set.targetWeightKg) {
        set.targetWeightKg = availableLoads.first ?? 0
      }
      switch phase {
      case .accumulation: set.restSeconds = min(120, max(60, set.restSeconds))
      case .intensification: set.restSeconds = min(240, max(90, set.restSeconds))
      case .deload: set.restSeconds = min(120, max(60, set.restSeconds))
      }
      return set
    }
  }

  private static func focus(for phase: Phase, goal: TrainingGoal, objective: String) -> String {
    let objective = objective.trimmingCharacters(in: .whitespacesAndNewlines)
    let base = objective.isEmpty ? goal.label.lowercased() : objective
    return switch phase {
    case .accumulation: "Construir volumen técnico para \(base)."
    case .intensification: "Consolidar intensidad para \(base) sin comprometer la técnica."
    case .deload: "Reducir fatiga y consolidar el trabajo de \(base)."
    }
  }

  private static func target(for phase: Phase, goal: TrainingGoal, objective: String) -> String {
    let objective = objective.trimmingCharacters(in: .whitespacesAndNewlines)
    let target = objective.isEmpty ? goal.label.lowercased() : objective
    return switch phase {
    case .accumulation: "Acumular trabajo de calidad para \(target)."
    case .intensification: "Priorizar carga y técnica para \(target)."
    case .deload: "Mantener técnica y margen de recuperación para \(target)."
    }
  }

  private static func nextMonday(after date: Date) -> Date {
    let calendar = Calendar.current
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
    return calendar.nextDate(after: tomorrow, matching: DateComponents(weekday: 2), matchingPolicy: .nextTime)
      ?? tomorrow
  }

  private static func scheduledDate(for session: TrainingSession, starting start: Date, weekOffset: Int) -> Date {
    let sourceDate = date(from: session.date)
    let weekday = Calendar.current.component(.weekday, from: sourceDate)
    let daysFromMonday = (weekday - 2 + 7) % 7
    return Calendar.current.date(byAdding: .day, value: (weekOffset * 7) + daysFromMonday, to: start) ?? start
  }

  private static func profileWeekday(for value: String) -> Int {
    let weekday = Calendar.current.component(.weekday, from: date(from: value))
    return weekday == 1 ? 7 : weekday - 1
  }

  private static func date(from value: String) -> Date {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: value) ?? .distantPast
  }

  private static func dateString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }
}
