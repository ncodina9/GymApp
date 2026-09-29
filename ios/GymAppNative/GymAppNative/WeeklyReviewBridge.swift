import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import GymAppNativeCore

enum WeeklyReviewBridge {
  static let contextSchemaName = "gymapp.weekly-review-context"
  static let proposalSchemaName = "gymapp.external-planning-proposal"

  struct Export: Codable {
    let schemaName: String
    let schemaVersion: Int
    let exportedAt: Date
    let closedWeek: Int
    let nextWeek: Int?
    let plan: TrainingPlan
    let profile: TrainingProfile
    let completedSessionIDs: [String]
    let executions: [WorkoutExecutionState]
    let localSummary: LocalSummary
  }

  struct LocalSummary: Codable {
    let plannedSessions: Int
    let completedSessions: Int
    let completedSets: Int
    let skippedSets: Int
    let averageRIR: Double?
    let maximumDiscomfort: Int
  }

  struct LocalAdvice: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let tone: AdviceTone
  }

  struct LocalProgressionProposal {
    let operations: [PlanningOperation]
    let summary: String
    let details: [String]
  }

  enum AdviceTone {
    case neutral
    case caution
    case positive
  }

  private enum AutomaticAdjustmentMode {
    case progress
    case recover
  }

  struct ExternalProposal: Codable {
    let schemaName: String
    let schemaVersion: Int
    let planID: String
    let reviewedWeek: Int
    let targetWeek: Int?
    let summary: String
    let operations: [PlanningOperation]
  }

  enum BridgeError: LocalizedError {
    case unsupportedProposal
    case planMismatch
    case emptyProposal
    case filePermission

    var errorDescription: String? {
      switch self {
      case .unsupportedProposal: "El archivo no usa el formato de propuesta externa de GymApp."
      case .planMismatch: "La propuesta pertenece a otro plan y no se puede aplicar."
      case .emptyProposal: "La propuesta externa no contiene cambios para validar."
      case .filePermission: "No se pudo acceder al archivo seleccionado."
      }
    }
  }

  static func write(
    plan: TrainingPlan,
    profile: TrainingProfile,
    closedWeek: Int,
    nextWeek: Int?,
    completedRecords: [CompletedWorkoutRecord],
    including currentExecution: WorkoutExecutionState? = nil
  ) throws -> URL {
    var executions = completedRecords.compactMap { record -> WorkoutExecutionState? in
      guard let data = record.executionData,
            let execution = try? JSONDecoder().decode(WorkoutExecutionState.self, from: data),
            execution.session.week == closedWeek else { return nil }
      return execution
    }
    if let currentExecution,
       currentExecution.session.week == closedWeek,
       !executions.contains(where: { $0.session.sessionID == currentExecution.session.sessionID }) {
      executions.append(currentExecution)
    }
    let records = executions.flatMap(\.records)
    let completed = records.filter { $0.status == .completed }
    let rirValues = completed.compactMap { $0.feedback.rir }
    let maxDiscomfort = records.map {
      max($0.feedback.painKnee, $0.feedback.painWrist, $0.feedback.painShoulder, $0.feedback.painLowerBack, $0.feedback.declaredDiscomfortLevels.values.max() ?? 0)
    }.max() ?? 0
    let plannedSessions = plan.sessions.filter { !$0.isCancelled && $0.week == closedWeek }.count
    let export = Export(
      schemaName: contextSchemaName,
      schemaVersion: 1,
      exportedAt: .now,
      closedWeek: closedWeek,
      nextWeek: nextWeek,
      plan: plan,
      profile: profile,
      completedSessionIDs: executions.map { $0.session.sessionID }.sorted(),
      executions: executions,
      localSummary: LocalSummary(
        plannedSessions: plannedSessions,
        completedSessions: executions.count,
        completedSets: completed.count,
        skippedSets: records.filter { $0.status == .skipped }.count,
        averageRIR: rirValues.isEmpty ? nil : Double(rirValues.reduce(0, +)) / Double(rirValues.count),
        maximumDiscomfort: maxDiscomfort
      )
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("gymapp-weekly-review-week-\(closedWeek).json")
    try encoder.encode(export).write(to: url, options: .atomic)
    return url
  }

  static func decodeProposal(_ data: Data, matching planID: String) throws -> ExternalProposal {
    let proposal = try JSONDecoder().decode(ExternalProposal.self, from: data)
    guard proposal.schemaName == proposalSchemaName, proposal.schemaVersion == 1 else {
      throw BridgeError.unsupportedProposal
    }
    guard proposal.planID == planID else { throw BridgeError.planMismatch }
    guard !proposal.operations.isEmpty else { throw BridgeError.emptyProposal }
    return proposal
  }

  static func localAdvice(
    plan: TrainingPlan,
    closedWeek: Int,
    nextWeek: Int?,
    completedRecords: [CompletedWorkoutRecord]
  ) -> [LocalAdvice] {
    let executions = completedRecords.compactMap { record -> WorkoutExecutionState? in
      guard let data = record.executionData,
            let execution = try? JSONDecoder().decode(WorkoutExecutionState.self, from: data),
            execution.session.week == closedWeek else { return nil }
      return execution
    }
    let records = executions.flatMap(\.records)
    let completed = records.filter { $0.status == .completed }
    let skipped = records.filter { $0.status == .skipped }.count
    let rir = completed.compactMap(\.feedback.rir)
    let averageRIR = rir.isEmpty ? nil : Double(rir.reduce(0, +)) / Double(rir.count)
    let maximumDiscomfort = records.map {
      max($0.feedback.painKnee, $0.feedback.painWrist, $0.feedback.painShoulder, $0.feedback.painLowerBack, $0.feedback.declaredDiscomfortLevels.values.max() ?? 0)
    }.max() ?? 0
    var advice: [LocalAdvice] = []

    if skipped > 0 {
      advice.append(.init(
        id: "adherence",
        title: "Consolida el volumen",
        detail: "Se omitieron \(skipped) serie\(skipped == 1 ? "" : "s"). Mantén las cargas previstas antes de progresar.",
        symbol: "checklist",
        tone: .caution
      ))
    }
    if maximumDiscomfort >= 2 {
      advice.append(.init(
        id: "discomfort",
        title: "Prioriza la tolerancia",
        detail: "Hubo una molestia de nivel \(maximumDiscomfort)/3. Mantén técnica, RIR conservador y evita aumentar carga hasta que remita.",
        symbol: "exclamationmark.triangle",
        tone: .caution
      ))
    }
    if let averageRIR {
      let isDemanding = averageRIR < 1
      advice.append(.init(
        id: "rir",
        title: isDemanding ? "Esfuerzo alto" : "Esfuerzo registrado",
        detail: isDemanding
          ? "RIR medio \(String(format: "%.1f", averageRIR)). Evita progresar la carga esta semana."
          : "RIR medio \(String(format: "%.1f", averageRIR)). Úsalo junto con adherencia y molestias para decidir la siguiente progresión.",
        symbol: isDemanding ? "gauge.with.dots.needle.67percent" : "gauge.with.dots.needle.50percent",
        tone: isDemanding ? .caution : .neutral
      ))
    }
    if skipped == 0, maximumDiscomfort == 0, let averageRIR, averageRIR >= 3 {
      advice.append(.init(
        id: "readiness",
        title: "Margen de progreso",
        detail: "La semana se completó sin molestias relevantes y con RIR medio alto. Una propuesta externa puede valorar una progresión pequeña y validada.",
        symbol: "arrow.up.right",
        tone: .positive
      ))
    }
    if let nextWeek,
       let nextSession = plan.sessions.first(where: { !$0.isCancelled && $0.week == nextWeek }) {
      advice.append(.init(
        id: "next-week",
        title: "Siguiente semana",
        detail: "S\(nextWeek): \(nextSession.weekFocusLabel). Las decisiones deben respetar este objetivo del macrociclo.",
        symbol: "calendar",
        tone: .neutral
      ))
      advice.append(.init(
        id: "phase-rule",
        title: "Regla de fase",
        detail: phaseRule(for: nextSession.exercises.first?.phase),
        symbol: "slider.horizontal.3",
        tone: .neutral
      ))
      advice.append(.init(
        id: "automation-boundary",
        title: "Límite automático",
        detail: "Superseries completas y temporizados usan reglas de bloque. Peso corporal progresa primero reps, después asistencia y solo al final lastre configurado.",
        symbol: "hand.raised",
        tone: .neutral
      ))
    }
    return advice
  }

  static func localProgressionProposal(
    plan: TrainingPlan,
    closedWeek: Int,
    nextWeek: Int?,
    completedRecords: [CompletedWorkoutRecord],
    inventory: EquipmentLoadInventory,
    profile: TrainingProfile,
    referenceDate: Date = .now
  ) -> LocalProgressionProposal? {
    guard let nextWeek else { return nil }
    let executions = completedRecords.compactMap { record -> WorkoutExecutionState? in
      guard let data = record.executionData,
            let execution = try? JSONDecoder().decode(WorkoutExecutionState.self, from: data),
            execution.session.week == closedWeek else { return nil }
      return execution
    }
    let records = executions.flatMap(\.records)
    let completed = records.filter { $0.status == .completed }
    let skipped = records.contains { $0.status == .skipped }
    let maxDiscomfort = records.map {
      max($0.feedback.painKnee, $0.feedback.painWrist, $0.feedback.painShoulder, $0.feedback.painLowerBack, $0.feedback.declaredDiscomfortLevels.values.max() ?? 0)
    }.max() ?? 0
    let rir = completed.compactMap(\.feedback.rir)
    guard !skipped, maxDiscomfort == 0, !rir.isEmpty else { return nil }
    let averageRIR = Double(rir.reduce(0, +)) / Double(rir.count)
    let mode: AutomaticAdjustmentMode
    if averageRIR >= 3 {
      mode = .progress
    } else if averageRIR < 1 {
      mode = .recover
    } else {
      return nil
    }

    let completedGroups = Set(executions.flatMap { execution in
      execution.records.compactMap { record -> String? in
        guard record.status == .completed,
              execution.session.exercises.indices.contains(record.locator.exerciseIndex) else { return nil }
        return execution.session.exercises[record.locator.exerciseIndex].displayGroupID
      }
    })
    let today = Calendar.current.startOfDay(for: referenceDate)
    var operations: [PlanningOperation] = []
    var details: [String] = []
    var adjustedGroups = Set<String>()
    for session in plan.sessions where !session.isCancelled && session.week == nextWeek && date(from: session.date) >= today {
      let eligibleSupersets = Set(session.exercises.compactMap(\.supersetID)).filter { supersetID in
        let members = session.exercises.filter { $0.supersetID == supersetID }
        return members.allSatisfy {
          completedGroups.contains($0.displayGroupID)
            && canAdjustAutomatically($0, mode: mode, inventory: inventory, profile: profile)
        }
      }
      for exercise in session.exercises where completedGroups.contains(exercise.displayGroupID) {
        guard !adjustedGroups.contains(exercise.displayGroupID) else { continue }
        guard exercise.equipment != .bodyweight
          || exercise.sets.contains(where: { canAdjustAutomatically(exercise, set: $0, mode: mode, inventory: inventory, profile: profile) }) else { continue }
        if let supersetID = exercise.supersetID, !eligibleSupersets.contains(supersetID) { continue }
        for set in exercise.sets {
          if exercise.equipment == .bodyweight,
             mode == .progress,
             let adjustment = bodyweightProgression(for: exercise, set: set, profile: profile) {
            switch adjustment {
            case let .reps(reps):
              operations.append(.adjustSet(sessionID: session.sessionID, exerciseID: exercise.exerciseID, setIndex: set.setIndex, reps: reps, weightKg: nil, durationSeconds: nil, restSeconds: nil))
              details.append("\(exercise.displayName): \(set.targetReps ?? 0) → \(reps) reps antes de cambiar la carga corporal.")
            case let .load(assistanceKg, addedWeightKg):
              operations.append(.adjustBodyweightLoad(sessionID: session.sessionID, exerciseID: exercise.exerciseID, setIndex: set.setIndex, assistanceKg: assistanceKg, addedWeightKg: addedWeightKg))
              if assistanceKg > 0 || (set.bodyweightLoad?.assistanceKg ?? 0) > 0 {
                details.append("\(exercise.displayName): asistencia \(weightLabel(set.bodyweightLoad?.assistanceKg ?? 0)) kg → \(weightLabel(assistanceKg)) kg.")
              } else {
                details.append("\(exercise.displayName): lastre \(weightLabel(set.bodyweightLoad?.addedWeightKg ?? 0)) kg → \(weightLabel(addedWeightKg)) kg configurado en tu perfil.")
              }
            }
            adjustedGroups.insert(exercise.displayGroupID)
            break
          }
          switch (mode, set.type) {
          case (.progress, .working):
            if exercise.phase == "acumulacion",
               let reps = set.targetReps,
               reps < maximumReps(for: exercise),
               exercise.equipment != .bodyweight {
              operations.append(.adjustSet(
                sessionID: session.sessionID,
                exerciseID: exercise.exerciseID,
                setIndex: set.setIndex,
                reps: reps + 1,
                weightKg: nil,
                durationSeconds: nil,
                restSeconds: nil
              ))
              details.append("\(exercise.displayName): \(reps) → \(reps + 1) reps, prioridad de acumulación.")
              adjustedGroups.insert(exercise.displayGroupID)
            } else if exercise.phase == "intensificacion" {
              let maximumWeight = set.targetWeightKg * (1 + maximumLoadIncrease(for: exercise.equipment))
              guard set.targetWeightKg > 0,
                    let weight = EquipmentLoadRules.availableLoads(for: exercise.equipment, inventory: inventory)
                      .first(where: { $0 > set.targetWeightKg && $0 <= maximumWeight }) else { continue }
              operations.append(.adjustSet(
                sessionID: session.sessionID,
                exerciseID: exercise.exerciseID,
                setIndex: set.setIndex,
                reps: nil,
                weightKg: weight,
                durationSeconds: nil,
                restSeconds: nil
              ))
              details.append("\(exercise.displayName): \(weightLabel(set.targetWeightKg)) kg → \(weightLabel(weight)) kg, intensidad y material disponible.")
              adjustedGroups.insert(exercise.displayGroupID)
            }
          case (.progress, .timed):
            guard exercise.phase == "acumulacion",
                  let duration = set.targetDurationSeconds,
                  duration < maximumTimedDuration else { continue }
            let nextDuration = min(maximumTimedDuration, duration + 5)
            operations.append(.adjustSet(
              sessionID: session.sessionID,
              exerciseID: exercise.exerciseID,
              setIndex: set.setIndex,
              reps: nil,
              weightKg: nil,
              durationSeconds: nextDuration,
              restSeconds: nil
            ))
            details.append("\(exercise.displayName): \(duration) s → \(nextDuration) s, progresión temporizada de acumulación.")
            adjustedGroups.insert(exercise.displayGroupID)
          case (.recover, .working), (.recover, .timed):
            guard exercise.equipment != .bodyweight,
                  exercise.phase != "descarga", exercise.phase != "readaptacion", exercise.phase != "test" else { continue }
            let isTimed: Bool
            if case .timed = set.type { isTimed = true } else { isTimed = false }
            let rest = min(maximumRest(for: exercise, isTimed: isTimed), set.restSeconds + 15)
            guard rest > set.restSeconds else { continue }
            operations.append(.adjustSet(
              sessionID: session.sessionID,
              exerciseID: exercise.exerciseID,
              setIndex: set.setIndex,
              reps: nil,
              weightKg: nil,
              durationSeconds: nil,
              restSeconds: rest
            ))
            details.append("\(exercise.displayName): descanso \(set.restSeconds) s → \(rest) s por RIR bajo.")
            adjustedGroups.insert(exercise.displayGroupID)
          }
          if adjustedGroups.contains(exercise.displayGroupID) { break }
        }
      }
    }
    guard !operations.isEmpty else { return nil }
    let summary = mode == .progress
      ? "Progresión conservadora en S\(nextWeek), condicionada por la fase y el material disponible."
      : "Recuperación conservadora en S\(nextWeek): más descanso tras un RIR medio bajo."
    return .init(
      operations: operations,
      summary: summary,
      details: Array(Set(details)).sorted()
    )
  }

  private static func date(from value: String) -> Date {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: value) ?? .distantPast
  }

  private static func weightLabel(_ value: Double) -> String {
    value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
  }

  private static func phaseRule(for phase: String?) -> String {
    switch phase {
    case "acumulacion": "Acumulación: prioriza una repetición adicional antes que aumentar carga."
    case "intensificacion": "Intensificación: permite carga solo si el siguiente salto está disponible y es conservador."
    case "descarga": "Descarga: no se generan progresiones automáticas."
    case "readaptacion": "Readaptación: no se generan progresiones automáticas."
    case "realizacion": "Realización: se mantiene la prescripción; no se progresa de forma automática."
    case "test": "Test: se mantiene la prescripción; no se progresa de forma automática."
    default: "La propuesta se mantiene conservadora hasta disponer de una regla específica para esta fase."
    }
  }

  private static func maximumReps(for exercise: TrainingExercise) -> Int {
    exercise.type == "Básico" ? 10 : 15
  }

  private static func maximumLoadIncrease(for equipment: Equipment) -> Double {
    switch equipment {
    case .barbell, .multipower:
      0.025
    case .dumbbell, .cable, .plateLoadedMachine, .external:
      0.05
    case .bodyweight:
      0
    }
  }

  private static func maximumRest(for exercise: TrainingExercise, isTimed: Bool = false) -> Int {
    isTimed ? 90 : (exercise.type == "Básico" ? 240 : 150)
  }

  private static var maximumTimedDuration: Int { 90 }

  private static func canAdjustAutomatically(
    _ exercise: TrainingExercise,
    mode: AutomaticAdjustmentMode,
    inventory: EquipmentLoadInventory,
    profile: TrainingProfile
  ) -> Bool {
    exercise.sets.contains { set in
      canAdjustAutomatically(exercise, set: set, mode: mode, inventory: inventory, profile: profile)
    }
  }

  private static func canAdjustAutomatically(
    _ exercise: TrainingExercise,
    set: TrainingSet,
    mode: AutomaticAdjustmentMode,
    inventory: EquipmentLoadInventory,
    profile: TrainingProfile
  ) -> Bool {
    if exercise.equipment == .bodyweight,
       mode == .progress,
       case .working = set.type {
      return bodyweightProgression(for: exercise, set: set, profile: profile) != nil
    }
    switch (mode, set.type) {
      case (.progress, .working):
        if exercise.phase == "acumulacion", let reps = set.targetReps {
          return reps < maximumReps(for: exercise)
        }
        if exercise.phase == "intensificacion", set.targetWeightKg > 0 {
          let maximumWeight = set.targetWeightKg * (1 + maximumLoadIncrease(for: exercise.equipment))
          return EquipmentLoadRules.availableLoads(for: exercise.equipment, inventory: inventory)
            .contains { $0 > set.targetWeightKg && $0 <= maximumWeight }
        }
        return false
      case (.progress, .timed):
        return exercise.phase == "acumulacion" && (set.targetDurationSeconds ?? maximumTimedDuration) < maximumTimedDuration
      case (.recover, .working):
        return exercise.equipment != .bodyweight
          && exercise.phase != "descarga"
          && exercise.phase != "readaptacion"
          && exercise.phase != "test"
          && set.restSeconds < maximumRest(for: exercise)
      case (.recover, .timed):
        return exercise.phase != "descarga"
          && exercise.phase != "readaptacion"
          && exercise.phase != "test"
          && set.restSeconds < maximumRest(for: exercise, isTimed: true)
    }
  }

  private enum BodyweightProgression {
    case reps(Int)
    case load(assistanceKg: Double, addedWeightKg: Double)
  }

  private static func bodyweightProgression(
    for exercise: TrainingExercise,
    set: TrainingSet,
    profile: TrainingProfile
  ) -> BodyweightProgression? {
    guard exercise.equipment == .bodyweight,
          case .working = set.type,
          exercise.phase != "descarga",
          exercise.phase != "readaptacion",
          exercise.phase != "test",
          exercise.phase != "realizacion" else { return nil }
    let load = set.bodyweightLoad ?? .init()
    if exercise.phase == "acumulacion",
       let reps = set.targetReps,
       reps < maximumReps(for: exercise) {
      return .reps(reps + 1)
    }
    if load.assistanceKg > 0 {
      return .load(assistanceKg: max(0, load.assistanceKg - max(0.5, profile.bodyweightAssistanceStepKg)), addedWeightKg: 0)
    }
    guard exercise.phase == "intensificacion",
          let nextLoad = profile.bodyweightWeightedLoadsKg.first(where: { $0 > load.addedWeightKg }) else { return nil }
    return .load(assistanceKg: 0, addedWeightKg: nextLoad)
  }

  static func instructionsURL(planID: String, reviewedWeek: Int, targetWeek: Int?) throws -> URL {
    let target = targetWeek.map(String.init) ?? "null"
    let text = """
    Eres un entrenador que revisa una semana de GymApp. Recibirás un JSON con schemaName \(contextSchemaName).

    Evalúa adherencia, series omitidas, cargas reales, reps, RIR, descansos, molestias y el objetivo de la siguiente semana. No cambies sesiones completadas, activas o pasadas. Respeta el material, lesiones, molestias y límites de progresión indicados en el contexto.

    Devuelve solo JSON, sin Markdown, con este contrato:
    {
      "schemaName": "\(proposalSchemaName)",
      "schemaVersion": 1,
      "planID": "\(planID)",
      "reviewedWeek": \(reviewedWeek),
      "targetWeek": \(target),
      "summary": "explicación breve y auditable",
      "operations": [
        {
          "type": "adjustSet",
          "sessionID": "id de sesión futura",
          "exerciseID": "id de ejercicio",
          "setIndex": 1,
          "reps": 8,
          "weightKg": 62.5,
          "durationSeconds": null,
          "restSeconds": 120
        }
      ]
    }

    Usa solo operaciones soportadas por GymApp: moveSession, shiftFutureSessions, cancelSession, replaceExercise, addExercise, removeExercise, adjustSet y adjustBodyweightLoad. Para asistencia o lastre usa adjustBodyweightLoad con assistanceKg o addedWeightKg, nunca ambos a la vez. No devuelvas un plan completo ni inventes IDs.
    """
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("gymapp-external-agent-instructions.txt")
    try text.write(to: url, atomically: true, encoding: .utf8)
    return url
  }
}

struct WeeklyReviewExportView: View {
  let plan: TrainingPlan
  @Query private var profileRecords: [TrainingProfileRecord]
  @Query private var completedRecords: [CompletedWorkoutRecord]
  @Query private var revisionRecords: [PlanRevisionRecord]
  @Query private var activeRecords: [ActiveWorkoutRecord]
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @State private var showsProposalImporter = false
  @State private var message: String?

  private var effectivePlan: TrainingPlan {
    PlanRevisionStore.resolvedPlan(basePlan: plan, records: revisionRecords)
  }

  private var profile: TrainingProfile {
    TrainingProfileStore.load(from: profileRecords) ?? .initial
  }

  private var completedIDs: Set<String> {
    Set(completedRecords.map(\.sessionID))
  }

  private var closedWeek: Int? {
    Dictionary(grouping: effectivePlan.sessions.filter { !$0.isCancelled }, by: \.week)
      .filter { _, sessions in sessions.allSatisfy { completedIDs.contains($0.sessionID) } }
      .map(\.key)
      .max()
  }

  private var nextWeek: Int? {
    guard let closedWeek else { return nil }
    return effectivePlan.sessions
      .filter { !$0.isCancelled && $0.week > closedWeek }
      .map(\.week)
      .min()
  }

  private var exportURL: URL? {
    guard let closedWeek else { return nil }
    return try? WeeklyReviewBridge.write(
      plan: effectivePlan,
      profile: profile,
      closedWeek: closedWeek,
      nextWeek: nextWeek,
      completedRecords: completedRecords
    )
  }

  private var instructionsURL: URL? {
    guard let closedWeek else { return nil }
    return try? WeeklyReviewBridge.instructionsURL(
      planID: effectivePlan.planID,
      reviewedWeek: closedWeek,
      targetWeek: nextWeek
    )
  }

  private var constraints: PlanningConstraints {
    profile.planningConstraints(
      activeSessionID: ActiveWorkoutStore.load(from: activeRecords)?.execution.session.sessionID,
      completedSessionIDs: completedIDs
    )
  }

  private var localAdvice: [WeeklyReviewBridge.LocalAdvice] {
    guard let closedWeek else { return [] }
    return WeeklyReviewBridge.localAdvice(
      plan: effectivePlan,
      closedWeek: closedWeek,
      nextWeek: nextWeek,
      completedRecords: completedRecords
    )
  }

  private var localProgressionProposal: WeeklyReviewBridge.LocalProgressionProposal? {
    guard let closedWeek else { return nil }
    return WeeklyReviewBridge.localProgressionProposal(
      plan: effectivePlan,
      closedWeek: closedWeek,
      nextWeek: nextWeek,
      completedRecords: completedRecords,
      inventory: profile.loadInventory,
      profile: profile
    )
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("Genera un contexto versionado para revisar la semana cerrada con un agente externo. El archivo no modifica tu planificación.")
          .font(.gymBody)
          .foregroundStyle(Color.gymSecondaryText)

        if let closedWeek, let exportURL {
          SettingsCategory(title: "Semana cerrada") {
            VStack(alignment: .leading, spacing: 14) {
              VStack(alignment: .leading, spacing: 6) {
                Text("Semana \(closedWeek)")
                  .font(.gymH2.weight(.bold))
                Text(nextWeek.map { "La propuesta debe respetar el objetivo de la semana \($0)." } ?? "No hay una semana posterior en el plan actual.")
                  .font(.gymBody)
                  .foregroundStyle(Color.gymSecondaryText)
              }

              ShareLink(item: exportURL) {
                Label("Exportar contexto de revisión", systemImage: "square.and.arrow.up")
                  .frame(maxWidth: .infinity, minHeight: 48)
              }
              .font(.gymBody.weight(.semibold))
              .foregroundStyle(Color.gymAccentForeground)
              .background(Color.gymAccent, in: RoundedRectangle(cornerRadius: 14))
              if let instructionsURL {
                ShareLink(item: instructionsURL) {
                  Label("Compartir instrucciones para el agente", systemImage: "doc.text")
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .font(.gymBody.weight(.semibold))
                .foregroundStyle(Color.gymAccent)
              }
              Button {
                showsProposalImporter = true
              } label: {
                Label("Importar propuesta externa", systemImage: "square.and.arrow.down")
                  .frame(maxWidth: .infinity, minHeight: 44)
              }
              .font(.gymBody.weight(.semibold))
              .foregroundStyle(Color.gymAccent)
            }
            .padding(16)
          }
          if !localAdvice.isEmpty {
            SettingsCategory(title: "Lectura local") {
              VStack(spacing: 0) {
                ForEach(Array(localAdvice.enumerated()), id: \.element.id) { index, advice in
                  WeeklyReviewAdviceRow(advice: advice, color: adviceColor(for: advice.tone))
                  if index < localAdvice.count - 1 { SettingsDivider() }
                }
                if let localProgressionProposal {
                  SettingsDivider()
                  VStack(alignment: .leading, spacing: 10) {
                    Text(localProgressionProposal.summary)
                      .font(.gymBody.weight(.semibold))
                    ForEach(localProgressionProposal.details.prefix(4), id: \.self) { detail in
                      Text(detail)
                        .font(.gymSupport)
                        .foregroundStyle(Color.gymSecondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if localProgressionProposal.details.count > 4 {
                      Text("Y \(localProgressionProposal.details.count - 4) ajustes más en la revisión.")
                        .font(.gymSupport)
                        .foregroundStyle(Color.gymSecondaryText)
                    }
                    Button(action: { createLocalProposal(localProgressionProposal) }) {
                      Label("Crear propuesta conservadora", systemImage: "arrow.up.right")
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .font(.gymBody.weight(.semibold))
                    .foregroundStyle(Color.gymAccentForeground)
                    .background(Color.gymAccent, in: RoundedRectangle(cornerRadius: 14))
                  }
                  .padding(16)
                }
              }
            }
          }
        } else {
          ContentUnavailableView(
            "Aún no hay una semana cerrada",
            systemImage: "calendar.badge.exclamationmark",
            description: Text("La exportación estará disponible al completar todas las sesiones de una semana del plan."))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
        }
      }
      .padding(16)
      .padding(.bottom, 88)
    }
    .background(GymCanvas())
    .navigationBarBackButtonHidden()
    .toolbar(.hidden, for: .navigationBar)
    .safeAreaInset(edge: .top, spacing: 0) {
      AccentHeaderCard(title: "Revisión semanal", detail: "Contexto para una propuesta externa")
    }
    .overlay(alignment: .bottomLeading) { BottomBackButton(action: { dismiss() }) }
    .fileImporter(isPresented: $showsProposalImporter, allowedContentTypes: [.json]) { result in
      importProposal(result)
    }
    .alert(
      "Revisión semanal",
      isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })
    ) {
      Button("Aceptar", role: .cancel) { message = nil }
    } message: {
      Text(message ?? "")
    }
  }

  private func importProposal(_ result: Result<URL, Error>) {
    do {
      let url = try result.get()
      guard url.startAccessingSecurityScopedResource() else {
        throw WeeklyReviewBridge.BridgeError.filePermission
      }
      defer { url.stopAccessingSecurityScopedResource() }
      let proposal = try WeeklyReviewBridge.decodeProposal(Data(contentsOf: url), matching: effectivePlan.planID)
      let revision = try PlanRevisionStore.propose(
        operations: proposal.operations,
        basedOn: plan,
        effectiveFrom: .now,
        reason: "Revisión externa S\(proposal.reviewedWeek) → S\(proposal.targetWeek.map(String.init) ?? "final"): \(proposal.summary)",
        constraints: constraints,
        in: modelContext,
        existingRecords: revisionRecords
      )
      message = "Propuesta externa importada como revisión \(revision.revisionNumber). Revísala antes de aceptarla."
    } catch {
      message = error.localizedDescription
    }
  }

  private func createLocalProposal(_ proposal: WeeklyReviewBridge.LocalProgressionProposal) {
    do {
      let revision = try PlanRevisionStore.propose(
        operations: proposal.operations,
        basedOn: plan,
        effectiveFrom: .now,
        reason: proposal.summary,
        constraints: constraints,
        in: modelContext,
        existingRecords: revisionRecords
      )
      message = "Propuesta local creada como revisión \(revision.revisionNumber). Revísala antes de aceptarla."
    } catch {
      message = error.localizedDescription
    }
  }

  private func adviceColor(for tone: WeeklyReviewBridge.AdviceTone) -> Color {
    switch tone {
    case .neutral: Color.gymAccent
    case .caution: Color.gymWarning
    case .positive: Color.gymCompleted
    }
  }
}

private struct WeeklyReviewAdviceRow: View {
  let advice: WeeklyReviewBridge.LocalAdvice
  let color: Color

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: advice.symbol)
        .font(.gymH3.weight(.bold))
        .foregroundStyle(color)
        .frame(width: 22, height: 22)
      VStack(alignment: .leading, spacing: 6) {
        Text(advice.title)
          .font(.gymH3.weight(.bold))
        Text(advice.detail)
          .font(.gymBody)
          .foregroundStyle(Color.gymSecondaryText)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
  }
}
