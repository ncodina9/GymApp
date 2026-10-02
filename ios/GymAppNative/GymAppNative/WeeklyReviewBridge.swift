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
    let exerciseDecisionsBySession: [String: [String: String]]
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
    let preservedDetails: [String]
  }

  enum AdviceTone {
    case neutral
    case caution
    case positive
  }

  private enum ExerciseAdjustmentIntent: Equatable {
    case hold
    case increaseReps
    case increaseLoad
    case decreaseReps
    case decreaseLoad
    case recover
  }

  private struct ExerciseSignal {
    var completedSets = 0
    var skippedSets = 0
    var rirValues: [Int] = []
    var maximumDiscomfort = 0
    var maximumActualReps: Int?
    var maximumActualWeightKgByEquipment: [Equipment: Double] = [:]
    var maximumActualDurationSeconds: Int?
    var decision: String?

    var averageRIR: Double? {
      guard !rirValues.isEmpty else { return nil }
      return Double(rirValues.reduce(0, +)) / Double(rirValues.count)
    }
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
    let exerciseDecisionsBySession = completedRecords.reduce(into: [String: [String: String]]()) { decisionsBySession, record in
      guard let data = record.executionData,
            let execution = try? JSONDecoder().decode(WorkoutExecutionState.self, from: data),
            execution.session.week == closedWeek,
            let decisionsData = record.decisionsData,
            let decisions = try? JSONDecoder().decode([String: String].self, from: decisionsData),
            !decisions.isEmpty else { return }
      decisionsBySession[record.sessionID] = decisions
    }
    let export = Export(
      schemaName: contextSchemaName,
      schemaVersion: 2,
      exportedAt: .now,
      closedWeek: closedWeek,
      nextWeek: nextWeek,
      plan: plan,
      profile: profile,
      completedSessionIDs: executions.map { $0.session.sessionID }.sorted(),
      executions: executions,
      exerciseDecisionsBySession: exerciseDecisionsBySession,
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
    let weekResults = completedRecords.sorted { $0.completedAt < $1.completedAt }.compactMap { record -> (WorkoutExecutionState, [String: String])? in
      guard let data = record.executionData,
            let execution = try? JSONDecoder().decode(WorkoutExecutionState.self, from: data),
            execution.session.week == closedWeek else { return nil }
      let decisions = record.decisionsData.flatMap {
        try? JSONDecoder().decode([String: String].self, from: $0)
      } ?? [:]
      return (execution, decisions)
    }
    guard !weekResults.isEmpty else { return nil }

    var signals: [String: ExerciseSignal] = [:]
    for (execution, decisions) in weekResults {
      for exercise in execution.session.exercises {
        guard let decision = decisions[exercise.exerciseID] else { continue }
        var signal = signals[exercise.displayGroupID] ?? .init()
        signal.decision = decision
        signals[exercise.displayGroupID] = signal
      }
      for record in execution.records {
        guard execution.session.exercises.indices.contains(record.locator.exerciseIndex) else { continue }
        let exercise = execution.session.exercises[record.locator.exerciseIndex]
        let groupID = exercise.displayGroupID
        let targets = execution.targets(for: record)
        var signal = signals[groupID] ?? .init()
        if record.status == .completed {
          signal.completedSets += 1
          if let rir = record.feedback.rir { signal.rirValues.append(rir) }
          if let reps = targets?.reps {
            signal.maximumActualReps = max(signal.maximumActualReps ?? reps, reps)
          }
          if let weight = targets?.weightKg, weight > 0 {
            let equipment = execution.equipment(for: record) ?? exercise.equipment
            signal.maximumActualWeightKgByEquipment[equipment] = max(
              signal.maximumActualWeightKgByEquipment[equipment] ?? weight,
              weight
            )
          }
          if let duration = targets?.durationSeconds {
            signal.maximumActualDurationSeconds = max(signal.maximumActualDurationSeconds ?? duration, duration)
          }
        } else {
          signal.skippedSets += 1
        }
        signal.maximumDiscomfort = max(
          signal.maximumDiscomfort,
          record.feedback.painKnee,
          record.feedback.painWrist,
          record.feedback.painShoulder,
          record.feedback.painLowerBack,
          record.feedback.declaredDiscomfortLevels.values.max() ?? 0
        )
        signals[groupID] = signal
      }
    }

    let today = Calendar.current.startOfDay(for: referenceDate)
    let targetSessions = plan.sessions.filter {
      !$0.isCancelled && $0.week == nextWeek && date(from: $0.date) >= today
    }
    guard !targetSessions.isEmpty else { return nil }

    var operations: [PlanningOperation] = []
    var details: [String] = []
    var preservedDetails: [String] = []
    var explainedAdjustments = Set<String>()
    var explainedPreservations = Set<String>()

    for session in targetSessions {
      let progressiveSupersets = Set(session.exercises.compactMap(\.supersetID)).filter { supersetID in
        session.exercises.filter { $0.supersetID == supersetID }.allSatisfy { member in
          guard let signal = signals[member.displayGroupID] else { return false }
          return isProgression(intent(for: signal, phase: member.phase))
        }
      }

      for exercise in session.exercises {
        guard let signal = signals[exercise.displayGroupID], signal.completedSets > 0 else {
          appendUnique(
            "\(exercise.displayName): se conserva por falta de una ejecución comparable en S\(closedWeek).",
            key: exercise.displayGroupID,
            seen: &explainedPreservations,
            values: &preservedDetails
          )
          continue
        }
        var adjustment = intent(for: signal, phase: exercise.phase)
        if isProgression(adjustment),
           let supersetID = exercise.supersetID,
           !progressiveSupersets.contains(supersetID) {
          adjustment = .hold
        }

        var exerciseOperations: [PlanningOperation] = []
        for set in exercise.sets {
          switch adjustment {
          case .increaseReps:
            switch set.type {
            case .working:
              guard normalizedPhase(exercise.phase) == "acumulacion",
                    let reps = set.targetReps,
                    (signal.maximumActualReps ?? 0) >= reps,
                    reps < maximumReps(for: exercise) else { continue }
              exerciseOperations.append(.adjustSet(
                sessionID: session.sessionID,
                exerciseID: exercise.exerciseID,
                setIndex: set.setIndex,
                reps: reps + 1,
                weightKg: nil,
                durationSeconds: nil,
                restSeconds: nil
              ))
              appendUnique(
                "\(exercise.displayName): +1 repetición en cada serie elegible; \(signalLabel(signal)).",
                key: exercise.displayGroupID,
                seen: &explainedAdjustments,
                values: &details
              )
            case .timed:
              guard normalizedPhase(exercise.phase) == "acumulacion",
                    let duration = set.targetDurationSeconds,
                    (signal.maximumActualDurationSeconds ?? 0) >= duration,
                    duration < maximumTimedDuration else { continue }
              let nextDuration = min(maximumTimedDuration, duration + 5)
              exerciseOperations.append(.adjustSet(
                sessionID: session.sessionID,
                exerciseID: exercise.exerciseID,
                setIndex: set.setIndex,
                reps: nil,
                weightKg: nil,
                durationSeconds: nextDuration,
                restSeconds: nil
              ))
              appendUnique(
                "\(exercise.displayName): \(duration) → \(nextDuration) s por serie; \(signalLabel(signal)).",
                key: exercise.displayGroupID,
                seen: &explainedAdjustments,
                values: &details
              )
            }
          case .increaseLoad:
            guard case .working = set.type,
                  normalizedPhase(exercise.phase) == "intensificacion" else { continue }
            if exercise.equipment == .bodyweight,
               let bodyweight = bodyweightProgression(for: exercise, set: set, profile: profile) {
              if case let .load(assistanceKg, addedWeightKg) = bodyweight {
                exerciseOperations.append(.adjustBodyweightLoad(
                  sessionID: session.sessionID,
                  exerciseID: exercise.exerciseID,
                  setIndex: set.setIndex,
                  assistanceKg: assistanceKg,
                  addedWeightKg: addedWeightKg
                ))
                let currentAssistance = set.bodyweightLoad?.assistanceKg ?? 0
                let currentAddedWeight = set.bodyweightLoad?.addedWeightKg ?? 0
                let description = assistanceKg > 0 || currentAssistance > 0
                  ? "asistencia \(weightLabel(currentAssistance)) → \(weightLabel(assistanceKg)) kg"
                  : "lastre \(weightLabel(currentAddedWeight)) → \(weightLabel(addedWeightKg)) kg"
                appendUnique(
                  "\(exercise.displayName): \(description), usando los pasos configurados en el perfil; \(signalLabel(signal)).",
                  key: exercise.displayGroupID,
                  seen: &explainedAdjustments,
                  values: &details
                )
              }
              continue
            }
            guard set.targetWeightKg > 0 else { continue }
            guard let performedWeight = signal.maximumActualWeightKgByEquipment[exercise.equipment],
                  performedWeight >= set.targetWeightKg else { continue }
            let observedWeight = max(set.targetWeightKg, performedWeight)
            let maximumWeight = set.targetWeightKg * (1 + maximumLoadIncrease(for: exercise.equipment))
            guard let weight = EquipmentLoadRules.availableLoads(for: exercise.equipment, inventory: inventory)
              .first(where: { $0 > observedWeight && $0 <= maximumWeight }) else { continue }
            exerciseOperations.append(.adjustSet(
              sessionID: session.sessionID,
              exerciseID: exercise.exerciseID,
              setIndex: set.setIndex,
              reps: nil,
              weightKg: weight,
              durationSeconds: nil,
              restSeconds: nil
            ))
            appendUnique(
              "\(exercise.displayName): siguiente salto de carga disponible en cada serie elegible; \(signalLabel(signal)).",
              key: exercise.displayGroupID,
              seen: &explainedAdjustments,
              values: &details
            )
          case .decreaseReps:
            guard case .working = set.type,
                  let reps = set.targetReps,
                  reps >= (signal.maximumActualReps ?? reps),
                  reps > 1 else { continue }
            exerciseOperations.append(.adjustSet(
              sessionID: session.sessionID,
              exerciseID: exercise.exerciseID,
              setIndex: set.setIndex,
              reps: reps - 1,
              weightKg: nil,
              durationSeconds: nil,
              restSeconds: nil
            ))
            appendUnique(
              "\(exercise.displayName): -1 repetición en cada serie elegible, siguiendo el feedback de la semana.",
              key: exercise.displayGroupID,
              seen: &explainedAdjustments,
              values: &details
            )
          case .decreaseLoad:
            guard case .working = set.type,
                  exercise.equipment != .bodyweight,
                  set.targetWeightKg > 0 else { continue }
            if let observed = signal.maximumActualWeightKgByEquipment[exercise.equipment],
               set.targetWeightKg < observed {
              continue
            }
            let weight = EquipmentLoadRules.adjustedWeight(
              from: set.targetWeightKg,
              equipment: exercise.equipment,
              direction: -1,
              inventory: inventory
            )
            guard weight < set.targetWeightKg else { continue }
            exerciseOperations.append(.adjustSet(
              sessionID: session.sessionID,
              exerciseID: exercise.exerciseID,
              setIndex: set.setIndex,
              reps: nil,
              weightKg: weight,
              durationSeconds: nil,
              restSeconds: nil
            ))
            appendUnique(
              "\(exercise.displayName): un salto menos de carga en cada serie elegible, respetando el material configurado.",
              key: exercise.displayGroupID,
              seen: &explainedAdjustments,
              values: &details
            )
          case .recover:
            let isTimed: Bool
            if case .timed = set.type { isTimed = true } else { isTimed = false }
            let rest = min(maximumRest(for: exercise, isTimed: isTimed), set.restSeconds + 15)
            var weight: Double?
            var duration: Int?
            if shouldReduceLoad(for: signal),
               !isTimed,
               exercise.equipment != .bodyweight,
               set.targetWeightKg > 0 {
              let observed = signal.maximumActualWeightKgByEquipment[exercise.equipment]
              let planAlreadyRecovers = observed.map { set.targetWeightKg < $0 } ?? false
              if !planAlreadyRecovers {
                let reduced = EquipmentLoadRules.adjustedWeight(
                  from: set.targetWeightKg,
                  equipment: exercise.equipment,
                  direction: -1,
                  inventory: inventory
                )
                if reduced < set.targetWeightKg { weight = reduced }
              }
            }
            if shouldReduceLoad(for: signal), isTimed, let seconds = set.targetDurationSeconds {
              let planAlreadyRecovers = signal.maximumActualDurationSeconds.map { seconds < $0 } ?? false
              if !planAlreadyRecovers { duration = max(15, seconds - 5) }
            }
            guard weight != nil || duration != nil || rest > set.restSeconds else { continue }
            exerciseOperations.append(.adjustSet(
              sessionID: session.sessionID,
              exerciseID: exercise.exerciseID,
              setIndex: set.setIndex,
              reps: nil,
              weightKg: weight,
              durationSeconds: duration,
              restSeconds: rest > set.restSeconds ? rest : nil
            ))
            appendUnique(
              "\(exercise.displayName): recuperación conservadora con más descanso\(weight != nil || duration != nil ? " y menor exigencia" : ""); \(signalLabel(signal)).",
              key: exercise.displayGroupID,
              seen: &explainedAdjustments,
              values: &details
            )
          case .hold:
            break
          }
        }
        operations.append(contentsOf: exerciseOperations)
        if exerciseOperations.isEmpty {
          appendUnique(
            preservationReason(for: exercise, signal: signal, intent: adjustment, closedWeek: closedWeek),
            key: exercise.displayGroupID,
            seen: &explainedPreservations,
            values: &preservedDetails
          )
        }
      }
    }

    let changedGroups = explainedAdjustments.count
    let summary = operations.isEmpty
      ? "La prescripción actual de S\(nextWeek) ya encaja con el feedback de S\(closedWeek); no se proponen cambios automáticos."
      : "Borrador para S\(nextWeek): \(changedGroups) ejercicio\(changedGroups == 1 ? "" : "s") ajustado\(changedGroups == 1 ? "" : "s") según ejecución, feedback y fase del macrociclo."
    return .init(
      operations: operations,
      summary: summary,
      details: details,
      preservedDetails: preservedDetails
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
    switch normalizedPhase(phase ?? "") {
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

  private static func intent(for signal: ExerciseSignal, phase: String) -> ExerciseAdjustmentIntent {
    let decision = normalized(signal.decision ?? "")
    if signal.maximumDiscomfort >= 2 || signal.skippedSets > 0 || (signal.averageRIR ?? 2) < 1 {
      return .recover
    }
    switch decision {
    case "marcar molestia", "molestia": return .recover
    case "bajar reps": return .decreaseReps
    case "bajar peso": return .decreaseLoad
    case "mantener", "mantener tiempo", "mejorar posicion": return .hold
    case "subir reps":
      return normalizedPhase(phase) == "acumulacion" ? .increaseReps : .hold
    case "subir peso":
      return normalizedPhase(phase) == "intensificacion" ? .increaseLoad : .hold
    default:
      break
    }
    guard signal.maximumDiscomfort == 0, let averageRIR = signal.averageRIR else { return .hold }
    switch normalizedPhase(phase) {
    case "acumulacion" where averageRIR >= 3:
      return .increaseReps
    case "intensificacion" where averageRIR >= 2:
      return .increaseLoad
    default:
      return .hold
    }
  }

  private static func isProgression(_ intent: ExerciseAdjustmentIntent) -> Bool {
    intent == .increaseReps || intent == .increaseLoad
  }

  private static func shouldReduceLoad(for signal: ExerciseSignal) -> Bool {
    let decision = normalized(signal.decision ?? "")
    return signal.maximumDiscomfort >= 2
      || signal.skippedSets > 0
      || decision == "marcar molestia"
      || decision == "molestia"
  }

  private static func signalLabel(_ signal: ExerciseSignal) -> String {
    var parts: [String] = []
    if let averageRIR = signal.averageRIR {
      parts.append("RIR medio \(String(format: "%.1f", averageRIR))")
    }
    if signal.skippedSets > 0 {
      parts.append("\(signal.skippedSets) serie\(signal.skippedSets == 1 ? " omitida" : "s omitidas")")
    }
    if signal.maximumDiscomfort > 0 {
      parts.append("molestia \(signal.maximumDiscomfort)/3")
    }
    if let decision = signal.decision, !decision.isEmpty {
      parts.append("feedback «\(decision)»")
    }
    return parts.isEmpty ? "ejecución completada sin señal suficiente" : parts.joined(separator: ", ")
  }

  private static func preservationReason(
    for exercise: TrainingExercise,
    signal: ExerciseSignal,
    intent: ExerciseAdjustmentIntent,
    closedWeek: Int
  ) -> String {
    let phase = normalizedPhase(exercise.phase)
    if ["descarga", "readaptacion", "realizacion", "test"].contains(phase) {
      return "\(exercise.displayName): se conserva porque la fase «\(exercise.phase)» no admite progresión automática."
    }
    if exercise.supersetID != nil, intent == .hold {
      return "\(exercise.displayName): se conserva para no descompensar su superserie; \(signalLabel(signal))."
    }
    if signal.maximumDiscomfort == 1 {
      return "\(exercise.displayName): se conserva con precaución por molestia 1/3."
    }
    if normalized(signal.decision ?? "").hasPrefix("mantener") {
      return "\(exercise.displayName): se conserva según el feedback «\(signal.decision ?? "Mantener")»."
    }
    if signal.averageRIR == nil {
      return "\(exercise.displayName): se conserva porque S\(closedWeek) no aporta RIR suficiente para ajustar con seguridad."
    }
    return "\(exercise.displayName): el objetivo previsto ya encaja con \(signalLabel(signal))."
  }

  private static func appendUnique(
    _ value: String,
    key: String,
    seen: inout Set<String>,
    values: inout [String]
  ) {
    guard seen.insert(key).inserted else { return }
    values.append(value)
  }

  private static func normalized(_ value: String) -> String {
    value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es_ES"))
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func normalizedPhase(_ phase: String) -> String {
    normalized(phase)
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
          !["descarga", "readaptacion", "test", "realizacion"].contains(normalizedPhase(exercise.phase)) else { return nil }
    let load = set.bodyweightLoad ?? .init()
    if normalizedPhase(exercise.phase) == "acumulacion",
       let reps = set.targetReps,
       reps < maximumReps(for: exercise) {
      return .reps(reps + 1)
    }
    if load.assistanceKg > 0 {
      return .load(assistanceKg: max(0, load.assistanceKg - max(0.5, profile.bodyweightAssistanceStepKg)), addedWeightKg: 0)
    }
    guard normalizedPhase(exercise.phase) == "intensificacion",
          let nextLoad = profile.bodyweightWeightedLoadsKg.first(where: { $0 > load.addedWeightKg }) else { return nil }
    return .load(assistanceKg: 0, addedWeightKg: nextLoad)
  }

  static func instructionsURL(planID: String, reviewedWeek: Int, targetWeek: Int?) throws -> URL {
    let target = targetWeek.map(String.init) ?? "null"
    let text = """
    Eres un entrenador que revisa una semana de GymApp. Recibirás un JSON con schemaName \(contextSchemaName).

    Evalúa ejercicio a ejercicio, agrupando variantes por baseExerciseId cuando exista; no uses un único RIR medio global. El contexto v2 incluye exerciseDecisionsBySession: la decisión final de la evaluación de cada ejercicio. No cambies sesiones completadas, activas o pasadas.

    Sigue estas reglas, que son las mismas del motor local:
    - Prioriza seguridad. Una serie omitida, una molestia de nivel 2 o 3, o RIR medio inferior a 1 requieren recuperación solo para ese ejercicio: añade hasta 15 s de descanso. Ante omisión o molestia 2-3, reduce además una carga disponible o la duración solo si la siguiente semana no la ha reducido ya. Molestia de nivel 1 implica mantener y advertir; no bloquea automáticamente el ejercicio.
    - Respeta la decisión explícita: Mantener, Mantener tiempo y Mejorar posición conservan el objetivo; Bajar reps o Bajar peso solo reducen el parámetro indicado; Subir reps solo puede progresar durante acumulación y Subir peso solo durante intensificación.
    - Sin una decisión explícita, propone como máximo +1 repetición durante acumulación si se cumplió el objetivo y el RIR medio es al menos 3; para temporizados, como máximo +5 s hasta 90 s. Durante intensificación, propone solo la siguiente carga disponible si se cumplió el objetivo con el mismo material y el RIR medio es al menos 2.
    - No progreses automáticamente en descarga, readaptación, realización ni test. No dupliques una progresión ya prevista: compara siempre el objetivo de la siguiente semana con el valor realmente ejecutado antes de incrementarlo o reducirlo.
    - Compara cargas reales únicamente dentro del mismo material. Nunca extrapoles entre barra, mancuernas, máquina, polea o multipower. Para barra/multipower, un incremento no puede superar el 2,5 %; para mancuernas, polea, máquinas o carga externa, el 5 %. Usa solo valores disponibles en el perfil.
    - En superseries, no propongas una progresión parcial: si todos los miembros no son elegibles, conserva el bloque. Una recuperación por molestia o serie omitida sí puede afectar solo al ejercicio señalado.
    - Respeta material, lesiones, molestias y límites de progresión indicados en el contexto. La summary debe indicar de forma breve qué ejercicios cambian, cuáles se conservan y el motivo.

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

    Usa solo operaciones soportadas por GymApp: moveSession, shiftFutureSessions, cancelSession, replaceExercise, addExercise, removeExercise, adjustSet y adjustBodyweightLoad. Aplica un cambio coherente a todas las series futuras elegibles del ejercicio, no solo a la primera. Para asistencia o lastre usa adjustBodyweightLoad con assistanceKg o addedWeightKg, nunca ambos a la vez. No devuelvas un plan completo ni inventes IDs.
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
        Text("Revisa la semana cerrada y prepara un borrador conservador para la siguiente. Nada cambia hasta que aceptes la propuesta desde Planificación.")
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
                  VStack(alignment: .leading, spacing: 12) {
                    Text(localProgressionProposal.summary)
                      .font(.gymBody.weight(.semibold))
                    if !localProgressionProposal.details.isEmpty {
                      Text("Cambios propuestos")
                        .font(.gymSupport.weight(.bold))
                        .foregroundStyle(Color.gymAccent)
                      ForEach(localProgressionProposal.details.prefix(4), id: \.self) { detail in
                        Text(detail)
                          .font(.gymBody)
                          .foregroundStyle(Color.gymSecondaryText)
                          .frame(maxWidth: .infinity, alignment: .leading)
                      }
                      if localProgressionProposal.details.count > 4 {
                        Text("Y \(localProgressionProposal.details.count - 4) ajustes más en la revisión.")
                          .font(.gymSupport)
                          .foregroundStyle(Color.gymSecondaryText)
                      }
                    }
                    if !localProgressionProposal.preservedDetails.isEmpty {
                      Text("Se conserva")
                        .font(.gymSupport.weight(.bold))
                        .foregroundStyle(Color.gymSecondaryText)
                        .padding(.top, 2)
                      ForEach(localProgressionProposal.preservedDetails.prefix(3), id: \.self) { detail in
                        Text(detail)
                          .font(.gymBody)
                          .foregroundStyle(Color.gymSecondaryText)
                          .frame(maxWidth: .infinity, alignment: .leading)
                      }
                    }
                    if localProgressionProposal.operations.isEmpty {
                      Label("No hace falta crear una revisión", systemImage: "checkmark.circle")
                        .font(.gymBody.weight(.semibold))
                        .foregroundStyle(Color.gymCompleted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                    } else {
                      Button(action: { createLocalProposal(localProgressionProposal) }) {
                        Label("Crear borrador para la semana siguiente", systemImage: "arrow.up.right")
                          .frame(maxWidth: .infinity, minHeight: 48)
                      }
                      .font(.gymBody.weight(.semibold))
                      .foregroundStyle(Color.gymAccentForeground)
                      .background(Color.gymAccent, in: RoundedRectangle(cornerRadius: 14))
                    }
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
      AccentHeaderCard(title: "Revisión semanal", detail: "Feedback y propuesta para la próxima semana")
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
