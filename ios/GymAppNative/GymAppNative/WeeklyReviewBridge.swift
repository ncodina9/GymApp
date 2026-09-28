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

    Usa solo operaciones soportadas por GymApp: moveSession, shiftFutureSessions, cancelSession, replaceExercise, addExercise, removeExercise y adjustSet. Para ajustes de series usa adjustSet. No devuelvas un plan completo ni inventes IDs.
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

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("Genera un contexto versionado para revisar la semana cerrada con un agente externo. El archivo no modifica tu planificación.")
          .font(.gymBody)
          .foregroundStyle(Color.gymSecondaryText)

        if let closedWeek, let exportURL {
          SettingsCategory(title: "Semana cerrada") {
            Text("Semana \(closedWeek)")
              .font(.gymH2.weight(.bold))
            Text(nextWeek.map { "La propuesta debe respetar el objetivo de la semana \($0)." } ?? "No hay una semana posterior en el plan actual.")
              .font(.gymBody)
              .foregroundStyle(Color.gymSecondaryText)
            SettingsDivider()
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
}
