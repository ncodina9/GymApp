import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers
import GymAppNativeCore

enum AppAppearance: String, CaseIterable, Identifiable {
  case system
  case light
  case dark

  var id: String { rawValue }
  var label: String {
    switch self {
    case .system: "Sistema"
    case .light: "Claro"
    case .dark: "Oscuro"
    }
  }
  var colorScheme: ColorScheme? {
    switch self {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
  }
}

struct SettingsView: View {
  let plan: TrainingPlan
  @Query private var revisionRecords: [PlanRevisionRecord]
  @AppStorage("appearanceTheme") private var appearanceRaw = AppAppearance.system.rawValue
  @AppStorage("themeAccent") private var accentRaw = ThemeAccent.blue.rawValue
  @AppStorage("premiumColorScheme") private var premiumSchemeRaw = ""
  @Environment(\.dismiss) private var dismiss

  private var themeKey: String {
    "\(appearanceRaw)-\(accentRaw)-\(premiumSchemeRaw)"
  }

  private var pendingRevisionCount: Int {
    revisionRecords.count { $0.basePlanID == plan.planID && $0.status == .proposed }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        SettingsCategory(title: "Entrenamiento") {
          SettingsRow(
            title: "Calentamiento",
            detail: "Tiempo previo antes de la primera serie",
            destination: WarmupSettingsView()
          )
          SettingsDivider()
          SettingsRow(
            title: "Perfil de entrenamiento",
            detail: "Objetivos, disponibilidad y restricciones",
            destination: TrainingProfileSettingsView()
          )
          SettingsDivider()
          SettingsRow(
            title: "Planificación",
            detail: "Calendario, sesiones, revisiones y datos locales",
            destination: PlanningHubView(plan: plan),
            badge: pendingRevisionCount
          )
          SettingsDivider()
          SettingsRow(
            title: "Ejercicios",
            detail: "Historial y récords por ejercicio",
            destination: ExercisesLibraryView(plan: plan)
          )
        }

        SettingsCategory(title: "Personalización") {
          SettingsRow(
            title: "Apariencia",
            detail: "Tema, color y pantalla activa",
            destination: AppearanceSettingsView()
          )
        }

        SettingsCategory(title: "Integraciones") {
          SettingsRow(
            title: "Apple Salud",
            detail: "Registrar sesiones de fuerza finalizadas",
            destination: HealthSettingsView()
          )
        }

        Text("v0.1.118")
          .font(.gymSupport.weight(.medium))
          .foregroundStyle(.tertiary)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.top, 8)
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .id(themeKey)
    .background(GymCanvas())
    .navigationBarBackButtonHidden()
    .toolbar(.hidden, for: .navigationBar)
    .safeAreaInset(edge: .top, spacing: 0) { AccentHeaderCard(title: "Opciones") }
    .overlay(alignment: .bottomLeading) { BottomBackButton(action: { dismiss() }) }
  }
}

private struct PlanRevisionsView: View {
  let plan: TrainingPlan
  @Query private var revisionRecords: [PlanRevisionRecord]
  @Query private var profileRecords: [TrainingProfileRecord]
  @Query private var activeRecords: [ActiveWorkoutRecord]
  @Query private var completedRecords: [CompletedWorkoutRecord]
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @State private var revisionMessage: String?

  private var planningConstraints: PlanningConstraints {
    let profile = TrainingProfileStore.load(from: profileRecords) ?? .initial
    return profile.planningConstraints(
      activeSessionID: ActiveWorkoutStore.load(from: activeRecords)?.execution.session.sessionID,
      completedSessionIDs: Set(completedRecords.map(\.sessionID))
    )
  }

  private var revisions: [PlanRevisionRecord] {
    revisionRecords
      .filter { $0.basePlanID == plan.planID }
      .sorted {
        if $0.status == .proposed, $1.status != .proposed { return true }
        if $0.status != .proposed, $1.status == .proposed { return false }
        return $0.effectiveFrom > $1.effectiveFrom
      }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Plan actual")
            .font(.gymH3.weight(.bold))
          Text(plan.sourceDocument)
            .font(.gymBody)
            .foregroundStyle(Color.gymSecondaryText)
          Text("Vigente desde \(Self.dateFormatter.string(from: planStartDate))")
            .font(.gymSupport)
            .foregroundStyle(Color.gymSecondaryText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 16))

        Text("Revisiones")
          .font(.gymH2.weight(.bold))

        if revisions.isEmpty {
          ContentUnavailableView(
            "Sin propuestas pendientes",
            systemImage: "calendar.badge.checkmark",
            description: Text("Las propuestas del entrenador se revisarán aquí antes de modificar la planificación."))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
        } else {
          ForEach(revisions, id: \.id) { revision in
            PlanRevisionCard(
              revision: revision,
              operations: PlanRevisionStore.operations(for: revision),
              warnings: PlanRevisionStore.warnings(for: revision),
              impact: PlanRevisionStore.impact(for: revision),
              rationales: PlanRevisionStore.rationales(for: revision),
              parentRevisionNumber: revision.parentRevisionID.flatMap { parentID in
                revisionRecords.first(where: { $0.id == parentID })?.revisionNumber
              },
              isStale: !PlanRevisionStore.isCurrent(revision, basedOn: plan, records: revisionRecords),
              onAccept: {
                do {
                  try PlanRevisionStore.accept(revision, basedOn: plan, records: revisionRecords, in: modelContext)
                } catch {
                  revisionMessage = error.localizedDescription
                }
              },
              onRefresh: {
                do {
                  try PlanRevisionStore.refresh(
                    revision,
                    basedOn: plan,
                    records: revisionRecords,
                    constraints: planningConstraints,
                    in: modelContext
                  )
                  revisionMessage = "La propuesta se ha actualizado sobre la planificación vigente."
                } catch {
                  revisionMessage = error.localizedDescription
                }
              },
              onReject: { PlanRevisionStore.reject(revision, in: modelContext) },
              onKeepOperations: { indexes in
                do {
                  try PlanRevisionStore.keepOperations(
                    at: indexes,
                    in: revision,
                    basedOn: plan,
                    records: revisionRecords,
                    constraints: planningConstraints,
                    context: modelContext
                  )
                  revisionMessage = "La propuesta se ha recalculado con los ajustes seleccionados."
                } catch {
                  revisionMessage = error.localizedDescription
                }
              }
            )
            .id("\(revision.id)-\(revision.updatedAt.timeIntervalSinceReferenceDate)")
          }
        }
      }
      .padding(16)
      .padding(.bottom, 76)
    }
    .background(GymCanvas())
    .navigationBarBackButtonHidden()
    .toolbar(.hidden, for: .navigationBar)
    .safeAreaInset(edge: .top, spacing: 0) {
      AccentHeaderCard(title: "Planificación", detail: "Propuestas con vigencia y confirmación")
    }
    .overlay(alignment: .bottomLeading) { BottomBackButton(action: { dismiss() }) }
    .alert(
      "Revisiones del plan",
      isPresented: Binding(get: { revisionMessage != nil }, set: { if !$0 { revisionMessage = nil } })
    ) {
      Button("Aceptar", role: .cancel) { revisionMessage = nil }
    } message: {
      Text(revisionMessage ?? "")
    }
  }

  private var planStartDate: Date {
    Self.isoDateFormatter.date(from: plan.startsOn) ?? .now
  }

  private static let isoDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "es_ES")
    formatter.dateStyle = .medium
    return formatter
  }()
}

private struct PlanRevisionCard: View {
  let revision: PlanRevisionRecord
  let operations: [PlanningOperation]
  let warnings: [PlanningWarning]
  let impact: PlanningImpact?
  let rationales: [PlanRevisionRationale]
  let parentRevisionNumber: Int?
  let isStale: Bool
  let onAccept: () -> Void
  let onRefresh: () -> Void
  let onReject: () -> Void
  let onKeepOperations: (Set<Int>) -> Void
  @State private var selectedOperationIndexes: Set<Int>

  init(
    revision: PlanRevisionRecord,
    operations: [PlanningOperation],
    warnings: [PlanningWarning],
    impact: PlanningImpact?,
    rationales: [PlanRevisionRationale],
    parentRevisionNumber: Int?,
    isStale: Bool,
    onAccept: @escaping () -> Void,
    onRefresh: @escaping () -> Void,
    onReject: @escaping () -> Void,
    onKeepOperations: @escaping (Set<Int>) -> Void
  ) {
    self.revision = revision
    self.operations = operations
    self.warnings = warnings
    self.impact = impact
    self.rationales = rationales
    self.parentRevisionNumber = parentRevisionNumber
    self.isStale = isStale
    self.onAccept = onAccept
    self.onRefresh = onRefresh
    self.onReject = onReject
    self.onKeepOperations = onKeepOperations
    _selectedOperationIndexes = State(initialValue: Set(operations.indices))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        Text("Revisión \(revision.revisionNumber)")
          .font(.gymH3.weight(.bold))
        Spacer()
        Text(revision.status.label)
          .font(.gymSupport.weight(.bold))
          .foregroundStyle(statusColor)
      }

      Text(revision.reason)
        .font(.gymBody)
        .frame(maxWidth: .infinity, alignment: .leading)

      Text("Vigente desde \(Self.dateFormatter.string(from: revision.effectiveFrom))")
        .font(.gymSupport)
        .foregroundStyle(Color.gymSecondaryText)

      if let parentRevisionNumber {
        Label("Basada en la revisión \(parentRevisionNumber)", systemImage: "arrow.triangle.branch")
          .font(.gymSupport)
          .foregroundStyle(Color.gymSecondaryText)
      }

      if !operations.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text(revision.status == .proposed ? "Ajustes a aplicar" : "Cambios")
            .font(.gymSupport.weight(.bold))
            .foregroundStyle(Color.gymSecondaryText)
          ForEach(Array(operations.enumerated()), id: \.offset) { index, operation in
            if revision.status == .proposed {
              Toggle(isOn: operationSelectionBinding(for: index)) {
                Label(operation.summary, systemImage: "arrow.triangle.branch")
                  .font(.gymBody.weight(.medium))
              }
              .tint(Color.gymAccent)
              .padding(10)
              .background(
                selectedOperationIndexes.contains(index) ? Color.gymAccent.opacity(0.10) : Color.gymCanvas,
                in: RoundedRectangle(cornerRadius: 10)
              )
            } else {
              Label(operation.summary, systemImage: "arrow.triangle.branch")
                .font(.gymSupport)
                .foregroundStyle(Color.gymSecondaryText)
            }
          }
          if revision.status == .proposed, selectedOperationIndexes != Set(operations.indices) {
            Button {
              onKeepOperations(selectedOperationIndexes)
            } label: {
              Label("Recalcular con \(selectedOperationIndexes.count) ajuste\(selectedOperationIndexes.count == 1 ? "" : "s")", systemImage: "arrow.triangle.2.circlepath")
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .font(.gymBody.weight(.semibold))
            .foregroundStyle(Color.gymAccent)
            .background(Color.gymCanvas, in: RoundedRectangle(cornerRadius: 12))
            .disabled(selectedOperationIndexes.isEmpty)
            .opacity(selectedOperationIndexes.isEmpty ? 0.45 : 1)
          }
        }
      }

      if !rationales.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("Motivo por ejercicio")
            .font(.gymSupport.weight(.bold))
            .foregroundStyle(Color.gymSecondaryText)
          ForEach(rationales) { rationale in
            VStack(alignment: .leading, spacing: 4) {
              HStack(spacing: 6) {
                Text(rationale.exerciseName)
                  .font(.gymBody.weight(.semibold))
                Spacer(minLength: 8)
                Text(rationale.outcome == .adjusted ? "Ajustado" : "Se conserva")
                  .font(.gymSupport.weight(.bold))
                  .foregroundStyle(rationale.outcome == .adjusted ? Color.gymAccent : Color.gymSecondaryText)
              }
              Text("\(rationale.material) · \(rationale.setIndexes.isEmpty ? "sin cambios de serie" : "series \(rationale.setIndexes.map(String.init).joined(separator: ", "))")")
                .font(.gymSupport)
                .foregroundStyle(Color.gymSecondaryText)
              Text(rationale.detail)
                .font(.gymBody)
                .foregroundStyle(Color.gymSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background(Color.gymCanvas, in: RoundedRectangle(cornerRadius: 10))
          }
        }
      }

      if !warnings.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in
            Label(warning.message, systemImage: "exclamationmark.triangle")
              .font(.gymSupport)
              .foregroundStyle(Color.gymWarning)
          }
        }
      }

      if let impact {
        PlanningImpactSummary(impact: impact)
      }

      if revision.status == .proposed {
        if isStale {
          Label("La planificación cambió desde que se creó esta propuesta.", systemImage: "arrow.triangle.2.circlepath")
            .font(.gymSupport)
            .foregroundStyle(Color.gymWarning)
        }
        HStack(spacing: 10) {
          Button("Descartar", role: .destructive, action: onReject)
            .font(.gymBody.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(.bordered)

          Button(isStale ? "Actualizar propuesta" : "Aceptar", action: isStale ? onRefresh : onAccept)
            .font(.gymBody.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(Color.gymAccentForeground)
            .glassEffect(.regular.tint(Color.gymAccent).interactive(), in: Capsule())
            .buttonStyle(.plain)
        }
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 16))
    .overlay {
      RoundedRectangle(cornerRadius: 16)
        .stroke(revision.status == .proposed ? Color.gymAccent.opacity(0.45) : Color.secondary.opacity(0.2), lineWidth: 1)
    }
  }

  private var statusColor: Color {
    switch revision.status {
    case .proposed: Color.gymAccent
    case .accepted: Color.gymCompleted
    case .rejected: Color.gymSecondaryText
    }
  }

  private func operationSelectionBinding(for index: Int) -> Binding<Bool> {
    Binding(
      get: { selectedOperationIndexes.contains(index) },
      set: { isSelected in
        if isSelected {
          selectedOperationIndexes.insert(index)
        } else {
          selectedOperationIndexes.remove(index)
        }
      }
    )
  }

  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "es_ES")
    formatter.dateStyle = .medium
    return formatter
  }()
}

private struct PlanningImpactSummary: View {
  let impact: PlanningImpact

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Impacto previsto")
        .font(.gymSupport.weight(.bold))
        .foregroundStyle(Color.gymSecondaryText)

      HStack(spacing: 8) {
        impactMetric("Sesiones", value: "\(impact.sessionChanges.count)", color: impact.sessionChanges.isEmpty ? Color.gymSecondaryText : Color.gymAccent)
        impactMetric("Duración", delta: impact.estimatedMinutesAfter - impact.estimatedMinutesBefore, suffix: " min")
        impactMetric("Superseries", delta: impact.supersetsAfter - impact.supersetsBefore, suffix: "")
      }

      if !impact.sessionChanges.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("Sesiones afectadas")
            .font(.gymSupport.weight(.bold))
            .foregroundStyle(Color.gymSecondaryText)
          ForEach(impact.sessionChanges) { change in
            VStack(alignment: .leading, spacing: 5) {
              HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("S\(change.week) · \(change.label)")
                  .font(.gymBody.weight(.semibold))
                  .lineLimit(1)
                Spacer(minLength: 8)
                if change.isCancelled {
                  Text("Cancelada")
                    .font(.gymSupport.weight(.bold))
                    .foregroundStyle(Color.gymWarning)
                } else if change.estimatedMinutesBefore != change.estimatedMinutesAfter {
                  Text("\(change.estimatedMinutesAfter) min")
                    .font(.gymSupport.weight(.bold))
                    .foregroundStyle(Color.gymAccent)
                }
              }
              if !change.focus.isEmpty {
                Text(change.focus)
                  .font(.gymSupport)
                  .foregroundStyle(Color.gymSecondaryText)
                  .lineLimit(1)
              }
              ForEach(change.changes, id: \.self) { detail in
                Label(detail, systemImage: "arrow.right")
                  .font(.gymSupport)
                  .foregroundStyle(Color.gymSecondaryText)
              }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gymCanvas, in: RoundedRectangle(cornerRadius: 10))
          }
        }
      }

      if !impact.diagnostics.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("Coherencia y recuperación")
            .font(.gymSupport.weight(.bold))
            .foregroundStyle(Color.gymSecondaryText)
          ForEach(impact.diagnostics) { diagnostic in
            Label {
              VStack(alignment: .leading, spacing: 2) {
                Text(diagnostic.title)
                  .font(.gymBody.weight(.semibold))
                Text(diagnostic.detail)
                  .font(.gymSupport)
              }
            } icon: {
              Image(systemName: diagnosticSymbol(for: diagnostic.tone))
            }
            .foregroundStyle(diagnosticColor(for: diagnostic.tone))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(diagnosticColor(for: diagnostic.tone).opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
          }
        }
      }

      if let previousEnd = impact.scheduleEndBefore,
         let proposedEnd = impact.scheduleEndAfter,
         previousEnd != proposedEnd {
        Label("Fin del macrociclo: \(Self.dateLabel(proposedEnd))", systemImage: "calendar.badge.clock")
          .font(.gymSupport.weight(.semibold))
          .foregroundStyle(Color.gymAccent)
      }

      if !impact.shiftedMacrocycleWeeks.isEmpty {
        Label("Semanas reprogramadas: \(impact.shiftedMacrocycleWeeks.map { "S\($0)" }.joined(separator: ", "))", systemImage: "arrow.left.and.right")
          .font(.gymSupport)
          .foregroundStyle(Color.gymSecondaryText)
      }

      if impact.weeklySetChanges.isEmpty {
        Text("Sin cambio de volumen semanal por grupo muscular.")
          .font(.gymSupport)
          .foregroundStyle(Color.gymSecondaryText)
      } else {
        ForEach(impact.weeklySetChanges) { change in
          Text("Semana \(change.week) · \(change.muscle.capitalized): \(change.before) → \(change.after) series")
            .font(.gymSupport)
            .foregroundStyle(Color.gymSecondaryText)
        }
      }
    }
  }

  private func impactMetric(_ title: String, delta: Int, suffix: String) -> some View {
    impactMetric(
      title,
      value: "\(delta >= 0 ? "+" : "")\(delta)\(suffix)",
      color: delta == 0 ? Color.gymSecondaryText : (delta > 0 ? Color.gymCompleted : Color.gymWarning)
    )
  }

  private func impactMetric(_ title: String, value: String, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title).font(.gymSupport.weight(.semibold)).foregroundStyle(Color.gymSecondaryText)
      Text(value)
        .font(.gymBody.weight(.bold))
        .foregroundStyle(color)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(8)
    .background(Color.gymCanvas, in: RoundedRectangle(cornerRadius: 10))
  }

  private func diagnosticColor(for tone: PlanningImpact.Diagnostic.Tone) -> Color {
    switch tone {
    case .positive: Color.gymCompleted
    case .caution: Color.gymWarning
    case .critical: Color.gymDanger
    }
  }

  private func diagnosticSymbol(for tone: PlanningImpact.Diagnostic.Tone) -> String {
    switch tone {
    case .positive: "checkmark.circle"
    case .caution: "exclamationmark.triangle"
    case .critical: "xmark.octagon"
    }
  }

  private static func dateLabel(_ value: String) -> String {
    let parser = DateFormatter()
    parser.locale = Locale(identifier: "en_US_POSIX")
    parser.timeZone = .current
    parser.dateFormat = "yyyy-MM-dd"
    guard let date = parser.date(from: value) else { return value }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "es_ES")
    formatter.dateStyle = .medium
    return formatter.string(from: date)
  }
}

private struct ExercisesLibraryView: View {
  let plan: TrainingPlan
  @Query private var completedWorkoutRecords: [CompletedWorkoutRecord]
  @Environment(\.dismiss) private var dismiss

  private var exercises: [TrainingExercise] {
    var seen = Set<String>()
    return plan.sessions
      .flatMap(\.exercises)
      .filter { seen.insert($0.displayGroupID).inserted }
      .sorted {
        $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
      }
  }

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 10) {
        NavigationLink {
          ExerciseCatalogSettingsView(plan: plan)
        } label: {
          HStack(spacing: 12) {
            Image(systemName: "slider.horizontal.3")
              .font(.gymH2.weight(.semibold))
              .foregroundStyle(Color.gymAccent)
              .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 4) {
              Text("Catálogo y preferencias")
                .font(.gymH2.weight(.bold))
                .foregroundStyle(.primary)
              Text("Ejercicios, variantes y material para propuestas futuras")
                .font(.gymBody)
                .foregroundStyle(Color.gymSecondaryText)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
              .font(.gymBody.weight(.bold))
              .foregroundStyle(Color.gymSecondaryText)
          }
          .padding(14)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 18))
          .overlay { RoundedRectangle(cornerRadius: 18).stroke(Color.gymAccent.opacity(0.35), lineWidth: 1) }
        }
        .buttonStyle(.plain)

        ForEach(exercises) { exercise in
          NavigationLink {
            ExerciseHistoryView(exercise: exercise, records: completedWorkoutRecords)
          } label: {
            HStack(spacing: 12) {
              Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.gymH2.weight(.semibold))
                .foregroundStyle(Color.gymAccent)
                .frame(width: 30, height: 30)

              VStack(alignment: .leading, spacing: 4) {
                Text(exercise.displayName)
                  .font(.gymH2.weight(.bold))
                  .foregroundStyle(.primary)
                Text(equipmentLabel(exercise.equipment))
                  .font(.gymBody)
                  .foregroundStyle(Color.gymSecondaryText)
              }

              Spacer(minLength: 8)
              Image(systemName: "chevron.right")
                .font(.gymBody.weight(.bold))
                .foregroundStyle(Color.gymSecondaryText)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
              RoundedRectangle(cornerRadius: 18)
                .stroke(.separator.opacity(0.7), lineWidth: 1)
            }
          }
          .buttonStyle(.plain)
        }
      }
      .padding(16)
      .padding(.bottom, 88)
    }
    .background(GymCanvas())
    .navigationBarBackButtonHidden()
    .toolbar(.hidden, for: .navigationBar)
    .safeAreaInset(edge: .top, spacing: 0) { AccentHeaderCard(title: "Ejercicios") }
    .overlay(alignment: .bottomLeading) { BottomBackButton(action: { dismiss() }) }
  }

  private func equipmentLabel(_ equipment: Equipment) -> String {
    switch equipment {
    case .barbell: "Barra"
    case .shortBar: "Barra corta"
    case .ezBar: "Barra Z"
    case .multipower: "Multipower"
    case .dumbbell: "Mancuernas"
    case .kettlebell: "Kettlebell"
    case .cable: "Polea"
    case .weightPlate: "Discos"
    case .plateLoadedMachine: "Máquina de discos"
    case .landmine: "Landmine"
    case .abWheel: "Rodillo abdominal"
    case .assaultBike: "Bici Assault"
    case .stationaryBike: "Bici estática"
    case .skiErg: "Ski"
    case .rowErg: "Row"
    case .battleRopes: "Battle ropes"
    case .external: "Lastre"
    case .bodyweight: "Peso corporal"
    }
  }
}

private struct HealthSettingsView: View {
  @AppStorage(HealthWorkoutStore.syncEnabledKey) private var syncEnabled = false
  @State private var message: String?
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Toggle("Registrar entrenamientos en Salud", isOn: Binding(
        get: { syncEnabled },
        set: updateSync
      ))
      .toggleStyle(ThemeToggleStyle())

      Text("Cada entrenamiento finalizado se guarda como fuerza tradicional con su duración real. Si no se pudo enviar en ese momento, se reintenta al abrir la app. No se estiman calorías ni se leen datos de Salud.")
        .font(.gymBody)
        .foregroundStyle(Color.gymSecondaryText)

      if let message {
        Text(message)
          .font(.gymSupport.weight(.medium))
          .foregroundStyle(Color.gymSecondaryText)
          .padding(12)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 14))
      }

      Spacer()
    }
    .padding(16)
    .background(GymCanvas())
    .navigationBarBackButtonHidden()
    .toolbar(.hidden, for: .navigationBar)
    .safeAreaInset(edge: .top, spacing: 0) { AccentHeaderCard(title: "Apple Salud") }
    .overlay(alignment: .bottomLeading) { BottomBackButton(action: { dismiss() }) }
  }

  private func updateSync(_ enabled: Bool) {
    guard enabled else {
      syncEnabled = false
      message = nil
      return
    }

    guard HealthWorkoutStore.isAvailable else {
      syncEnabled = false
      message = "Salud no está disponible en este dispositivo."
      return
    }

    syncEnabled = true
    Task {
      do {
        try await HealthWorkoutStore.requestAuthorization()
        message = "Los entrenamientos finalizados se guardarán en Salud; los pendientes se reintentarán al abrir la app."
      } catch {
        syncEnabled = false
        message = "No se ha podido solicitar el permiso de Salud."
      }
    }
  }
}

struct SettingsCategory<Content: View>: View {
  let title: String
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.gymBody.weight(.semibold))
        .foregroundStyle(Color.gymSecondaryText)
        .padding(.horizontal, 4)

      VStack(spacing: 0) {
        content
      }
      .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 18))
      .overlay {
        RoundedRectangle(cornerRadius: 18)
          .stroke(.separator.opacity(0.7), lineWidth: 1)
      }
    }
  }
}

private struct SettingsRow<Destination: View>: View {
  let title: String
  let detail: String
  let destination: Destination
  let badge: Int?

  init(title: String, detail: String, destination: Destination, badge: Int? = nil) {
    self.title = title
    self.detail = detail
    self.destination = destination
    self.badge = badge
  }

  var body: some View {
    NavigationLink { destination } label: {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(title).font(.gymH2.weight(.bold))
          Text(detail).font(.gymBody).foregroundStyle(Color.gymSecondaryText)
        }
        Spacer()
        if let badge, badge > 0 {
          Text("\(badge)")
            .font(.gymSupport.weight(.bold))
            .foregroundStyle(Color.gymAccentForeground)
            .frame(minWidth: 24, minHeight: 24)
            .background(Color.gymAccent, in: Capsule())
            .accessibilityLabel("\(badge) revisiones pendientes")
        }
        Image(systemName: "chevron.right").foregroundStyle(Color.gymSecondaryText)
      }
      .padding(16)
      .frame(maxWidth: .infinity)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

struct SettingsDivider: View {
  var body: some View {
    Divider().padding(.leading, 16)
  }
}

private struct WarmupSettingsView: View {
  @AppStorage("warmupEnabled") private var warmupEnabled = true
  @AppStorage("warmupMinutes") private var warmupMinutes = 9
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Toggle("Incluir calentamiento", isOn: $warmupEnabled)
        .toggleStyle(ThemeToggleStyle())

      Text("El calentamiento inicia el tiempo real de la sesión, pero no genera series ni feedback.")
        .font(.gymBody)
        .foregroundStyle(Color.gymSecondaryText)

      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Duración estándar")
            .font(.gymH2.weight(.bold))
          Text("Se puede omitir al empezar directamente.")
            .font(.gymSupport)
            .foregroundStyle(Color.gymSecondaryText)
        }
        Spacer()
        HStack(spacing: 10) {
          durationButton(symbol: "minus") { warmupMinutes = max(3, warmupMinutes - 1) }
          Text("\(warmupMinutes) min")
            .font(.gymH2.weight(.bold))
            .monospacedDigit()
            .frame(minWidth: 54)
          durationButton(symbol: "plus") { warmupMinutes = min(20, warmupMinutes + 1) }
        }
      }
      .padding(16)
      .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 18))

      Spacer()
    }
    .padding(16)
    .background(GymCanvas())
    .navigationBarBackButtonHidden()
    .toolbar(.hidden, for: .navigationBar)
    .safeAreaInset(edge: .top, spacing: 0) { AccentHeaderCard(title: "Calentamiento") }
    .overlay(alignment: .bottomLeading) { BottomBackButton(action: { dismiss() }) }
  }

  private func durationButton(symbol: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.gymBody.weight(.bold))
        .frame(width: 40, height: 40)
        .foregroundStyle(Color.gymAccentForeground)
        .glassEffect(.regular.tint(Color.gymAccent).interactive(), in: Circle())
    }
    .buttonStyle(.plain)
    .disabled(!warmupEnabled)
    .opacity(warmupEnabled ? 1 : 0.45)
  }
}

private struct AppearanceSettingsView: View {
  @AppStorage("appearanceTheme") private var appearanceRaw = AppAppearance.system.rawValue
  @AppStorage("themeAccent") private var accentRaw = ThemeAccent.blue.rawValue
  @AppStorage("premiumColorScheme") private var premiumSchemeRaw = ""
  @AppStorage("keepScreenAwake") private var keepScreenAwake = false
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        AppearanceSegmentedSelector(selection: $appearanceRaw)

        AccentThemePreviewList(selection: $accentRaw, premiumSelection: $premiumSchemeRaw)

        PremiumColorSchemePreviewList(selection: $premiumSchemeRaw)

        Toggle("Mantener la pantalla activa", isOn: $keepScreenAwake)
          .toggleStyle(ThemeToggleStyle())
      }
      .padding(16)
      .padding(.bottom, 88)
    }
    .background(GymCanvas())
    .navigationBarBackButtonHidden()
    .toolbar(.hidden, for: .navigationBar)
    .safeAreaInset(edge: .top, spacing: 0) { AccentHeaderCard(title: "Apariencia") }
    .overlay(alignment: .bottomLeading) { BottomBackButton(action: { dismiss() }) }
    .id("appearance-\(appearanceRaw)-\(accentRaw)-\(premiumSchemeRaw)")
  }
}

struct ThemeToggleStyle: ToggleStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: 12) {
      configuration.label
      Spacer(minLength: 12)
      Button {
        configuration.isOn.toggle()
      } label: {
        Capsule()
          .fill(configuration.isOn ? Color.gymControlSelectionFill : Color.secondary.opacity(0.16))
          .frame(width: 52, height: 32)
          .overlay {
            Capsule()
              .stroke(configuration.isOn ? Color.gymAccent : Color.secondary.opacity(0.42), lineWidth: 1)
          }
          .overlay(alignment: configuration.isOn ? .trailing : .leading) {
            Circle()
              .fill(configuration.isOn ? Color.gymControlSelectionForeground : Color.primary)
              .padding(4)
          }
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Mantener la pantalla activa")
      .accessibilityValue(configuration.isOn ? "Activado" : "Desactivado")
    }
  }
}

private struct AccentThemePreviewList: View {
  @Binding var selection: String
  @Binding var premiumSelection: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Color de resalte")
        .font(.gymBody.weight(.semibold))
        .foregroundStyle(Color.gymSecondaryText)

      ForEach(ThemeAccent.allCases) { theme in
        AccentThemePreviewCard(
          theme: theme,
          isSelected: premiumSelection.isEmpty && selection == theme.rawValue
        ) {
          withAnimation(.easeInOut(duration: 0.2)) {
            selection = theme.rawValue
            premiumSelection = ""
          }
        }
      }
    }
  }
}

private struct PremiumColorSchemePreviewList: View {
  @Binding var selection: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Esquemas premium")
        .font(.gymBody.weight(.semibold))
        .foregroundStyle(Color.gymSecondaryText)

      Text("El fondo y el resalte se invierten entre la apariencia clara y la oscura.")
        .font(.gymSupport)
        .foregroundStyle(Color.gymSecondaryText)

      ForEach(PremiumColorScheme.allCases) { scheme in
        PremiumColorSchemePreviewCard(
          scheme: scheme,
          isSelected: selection == scheme.rawValue
        ) {
          withAnimation(.easeInOut(duration: 0.2)) {
            selection = scheme.rawValue
          }
        }
      }
    }
  }
}

private struct PremiumColorSchemePreviewCard: View {
  let scheme: PremiumColorScheme
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 14) {
        VStack(alignment: .leading, spacing: 4) {
          Text(scheme.label)
            .font(.gymH2.weight(.bold))
          Text(isSelected ? "Seleccionado" : "Fondo y resalte adaptativos")
            .font(.gymSupport.weight(.medium))
            .foregroundStyle(Color.gymSecondaryText)
        }

        Spacer(minLength: 12)

        HStack(spacing: 6) {
          schemeSwatch(background: scheme.lightColor, accent: scheme.darkColor)
          schemeSwatch(background: scheme.darkColor, accent: scheme.lightColor)
        }
      }
      .padding(14)
      .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 18))
      .overlay {
        RoundedRectangle(cornerRadius: 18)
          .stroke(isSelected ? Color.gymAccent : Color.secondary.opacity(0.28), lineWidth: isSelected ? 2 : 1)
      }
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private func schemeSwatch(background: UIColor, accent: UIColor) -> some View {
    RoundedRectangle(cornerRadius: 10)
      .fill(Color(uiColor: background))
      .frame(width: 46, height: 42)
      .overlay {
        Capsule()
          .fill(Color(uiColor: accent))
          .frame(width: 28, height: 8)
      }
      .overlay {
        RoundedRectangle(cornerRadius: 10)
          .stroke(Color.primary.opacity(0.18), lineWidth: 1)
      }
  }
}

private struct AccentThemePreviewCard: View {
  let theme: ThemeAccent
  let isSelected: Bool
  let action: () -> Void
  @Environment(\.colorScheme) private var colorScheme

  private var surface: Color {
    Color(uiColor: colorScheme == .dark ? theme.darkSurfaceColor : theme.lightSurfaceColor)
  }

  private var accent: Color {
    Color(uiColor: theme.primaryColor)
  }

  var body: some View {
    Button(action: action) {
      HStack(spacing: 14) {
        VStack(alignment: .leading, spacing: 4) {
          Text(theme.label)
            .font(.gymH2.weight(.bold))
            .foregroundStyle(.primary)
          Text(isSelected ? "Seleccionado" : "Color de interfaz")
            .font(.gymSupport.weight(.medium))
            .foregroundStyle(Color.gymSecondaryText)
        }

        Spacer(minLength: 12)

        VStack(spacing: 4) {
          Capsule()
            .fill(accent)
            .frame(width: 92, height: 14)
          HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 5)
              .fill(surface)
            RoundedRectangle(cornerRadius: 5)
              .fill(surface)
            RoundedRectangle(cornerRadius: 5)
              .fill(accent.opacity(0.72))
          }
          .frame(width: 92, height: 21)
        }
        .padding(7)
        .background(surface, in: RoundedRectangle(cornerRadius: 12))
      }
      .padding(14)
      .background(surface, in: RoundedRectangle(cornerRadius: 18))
      .overlay {
        RoundedRectangle(cornerRadius: 18)
          .stroke(isSelected ? accent : Color.secondary.opacity(0.28), lineWidth: isSelected ? 2 : 1)
      }
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

private struct AppearanceSegmentedSelector: View {
  @Binding var selection: String

  var body: some View {
    GlassSegmentedSelector(
      selection: $selection,
      options: AppAppearance.allCases.map(\.rawValue),
      unavailableOptions: [],
      label: { AppAppearance(rawValue: $0)?.label ?? $0 }
    )
  }
}

private struct PlanningHubView: View {
  let plan: TrainingPlan
  @Query private var completedRecords: [CompletedWorkoutRecord]
  @Query private var profileRecords: [TrainingProfileRecord]
  @Environment(\.dismiss) private var dismiss
  @State private var displayMode: ScheduleDisplayMode = .calendar
  @State private var displayedMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: .now)) ?? .now
  @State private var selectedDay: Date?

  private var upcomingSessions: [TrainingSession] {
    let completed = Set(completedRecords.map(\.sessionID))
    let today = Self.todayISODate
    return plan.sessions.filter { !$0.isCancelled && $0.date >= today && !completed.contains($0.sessionID) }
  }

  private var profile: TrainingProfile {
    TrainingProfileStore.load(from: profileRecords) ?? .initial
  }

  private var sessionsByDay: [Date: [TrainingSession]] {
    Dictionary(grouping: plan.sessions.filter { !$0.isCancelled }, by: { Self.day(for: $0.date) })
  }

  private var selectedSessions: [TrainingSession] {
    guard let selectedDay else { return [] }
    return sessionsByDay[Calendar.current.startOfDay(for: selectedDay)] ?? []
  }

  private var macrocycleWeeksByDay: [Date: MacrocycleWeekInfo] {
    sessionsByDay.reduce(into: [:]) { result, entry in
      guard let session = entry.value.first else { return }
      result[entry.key] = MacrocycleWeekInfo(
        week: session.week,
        focusLabel: session.weekFocusLabel,
        focus: session.weekFocus
      )
    }
  }

  private var selectedMacrocycleWeek: MacrocycleWeekInfo? {
    guard let selectedDay else { return nil }
    return macrocycleWeeksByDay[Calendar.current.startOfDay(for: selectedDay)]
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Picker("Vista", selection: $displayMode) {
          ForEach(ScheduleDisplayMode.allCases) { mode in
            Label(mode.label, systemImage: mode.symbol).tag(mode)
          }
        }
        .pickerStyle(.segmented)

        if displayMode == .calendar {
          TrainingCalendarGrid(
            displayedMonth: $displayedMonth,
            selectedDay: $selectedDay,
            sessionsByDay: sessionsByDay,
            macrocycleWeeksByDay: macrocycleWeeksByDay,
            completedSessionIDs: Set(completedRecords.map(\.sessionID))
          )

          if let selectedMacrocycleWeek {
            MacrocycleWeekSummary(week: selectedMacrocycleWeek)
          }

          if selectedSessions.isEmpty {
            ContentUnavailableView(
              "Sin entrenamiento este día",
              systemImage: "calendar",
              description: Text("Elige un día marcado para consultar su sesión."))
              .frame(maxWidth: .infinity)
              .padding(.vertical, 22)
          } else {
            ForEach(selectedSessions) { session in
              PlanningSessionCard(session: session, record: completedRecord(for: session))
            }
          }
        } else {
          LazyVStack(spacing: 12) {
            ForEach(upcomingSessions) { session in
              NavigationLink {
                SessionPreviewView(session: session, onReturnHome: {}, readOnly: true)
              } label: {
                WeekSessionCard(session: session, isRecommended: false, isInProgress: false, isCompleted: false)
              }
              .buttonStyle(.plain)
            }
          }
        }

        SettingsCategory(title: "Plan y datos") {
          SettingsRow(
            title: "Macrociclo",
            detail: "Fases, objetivos y progreso del plan",
            destination: MacrocycleDetailView(plan: plan)
          )
          SettingsDivider()
          SettingsRow(
            title: "Compatibilidad del perfil",
            detail: "Revisa duración, material y restricciones futuras",
            destination: ProfilePlanCompatibilityView(plan: plan, profile: profile)
          )
          SettingsDivider()
          SettingsRow(
            title: "Revisiones del plan",
            detail: "Propuestas pendientes y cambios aceptados",
            destination: PlanRevisionsView(plan: plan)
          )
          SettingsDivider()
          SettingsRow(
            title: "Hablar con el entrenador",
            detail: "Convierte una solicitud en una propuesta revisable",
            destination: CoachConversationView(plan: plan)
          )
          SettingsDivider()
          SettingsRow(
            title: "Revisión semanal",
            detail: "Exporta contexto para recalcular la siguiente semana",
            destination: WeeklyReviewExportView(plan: plan)
          )
          SettingsDivider()
          SettingsRow(
            title: "Simular propuesta",
            detail: "Genera una revisión sin modificar el plan",
            destination: ProposalSimulatorView(plan: plan)
          )
          SettingsDivider()
          SettingsRow(
            title: "Gestión de datos locales",
            detail: "Backup, importación y sesiones guardadas",
            destination: ExportSettingsView(plan: plan)
          )
        }
      }
      .padding(16)
      .padding(.bottom, 88)
    }
    .background(GymCanvas())
    .navigationBarBackButtonHidden()
    .toolbar(.hidden, for: .navigationBar)
    .safeAreaInset(edge: .top, spacing: 0) { AccentHeaderCard(title: "Planificación", detail: "Calendario, sesiones y revisiones") }
    .overlay(alignment: .bottomLeading) { BottomBackButton(action: { dismiss() }) }
    .onAppear {
      guard selectedDay == nil else { return }
      let firstRelevant = plan.sessions
        .filter { !$0.isCancelled }
        .map { Self.day(for: $0.date) }
        .first(where: { $0 >= Calendar.current.startOfDay(for: .now) })
        ?? sessionsByDay.keys.sorted().last
      guard let firstRelevant else { return }
      selectedDay = firstRelevant
      displayedMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: firstRelevant)) ?? firstRelevant
    }
  }

  private func completedRecord(for session: TrainingSession) -> CompletedWorkoutRecord? {
    completedRecords.first(where: { $0.sessionID == session.sessionID })
  }

  private static func day(for value: String) -> Date {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd"
    return Calendar.current.startOfDay(for: formatter.date(from: value) ?? .distantPast)
  }

  private static var todayISODate: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: .now)
  }
}

private struct ProfilePlanCompatibilityView: View {
  let plan: TrainingPlan
  let profile: TrainingProfile
  @Environment(\.dismiss) private var dismiss
  private let reviewHorizon = 3

  private var issues: [PlanningProfileIssue] {
    PlanningProfileCompatibility.issues(
      in: plan,
      constraints: profile.planningConstraints(activeSessionID: nil, completedSessionIDs: []),
      maximumUpcomingSessions: reviewHorizon
    )
  }

  private var cautionExerciseSummaries: [String] {
    var result: [String] = []
    for issue in cautionIssues {
      guard let session = plan.sessions.first(where: { $0.sessionID == issue.sessionID }),
            let exerciseID = issue.exerciseID,
            let exercise = session.exercises.first(where: { $0.exerciseID == exerciseID })
      else { continue }
      let summary = "\(session.weekday) · \(exercise.displayName)"
      if !result.contains(summary) { result.append(summary) }
    }
    return result
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("Revisa las próximas \(reviewHorizon) sesiones. Las molestias orientan la ejecución; solo las lesiones y restricciones reales bloquean cambios del plan.")
          .font(.gymBody)
          .foregroundStyle(Color.gymSecondaryText)

        if blockingIssues.isEmpty {
          ContentUnavailableView(
            "Perfil compatible",
            systemImage: "checkmark.seal.fill",
            description: Text("Las próximas sesiones respetan el material, la duración y las restricciones actuales."))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        } else {
          SettingsCategory(title: "Requiere revisión") {
            ForEach(blockingIssues) { issue in
              ProfilePlanIssueRow(issue: issue, session: plan.sessions.first(where: { $0.sessionID == issue.sessionID }))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
              if issue.id != blockingIssues.last?.id { SettingsDivider() }
            }
          }
        }

        if !cautionIssues.isEmpty {
          SettingsCategory(title: "Precauciones de ejecución") {
            VStack(alignment: .leading, spacing: 12) {
              Label("No bloquean estos ejercicios", systemImage: "figure.strengthtraining.functional")
                .font(.gymH3.weight(.bold))
                .foregroundStyle(Color.gymAccent)
              Text("Con molestias declaradas, mantén el rango sin dolor, una técnica estable y el RIR recomendado por la fase. Registra la intensidad real al terminar la serie.")
                .font(.gymBody)
                .foregroundStyle(Color.gymSecondaryText)
              ForEach(cautionExerciseSummaries.prefix(3), id: \.self) { summary in
                Text(summary)
                  .font(.gymSupport.weight(.semibold))
                  .foregroundStyle(Color.gymSecondaryText)
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
              if cautionExerciseSummaries.count > 3 {
                Text("Y \(cautionExerciseSummaries.count - 3) ejercicios próximos con la misma precaución.")
                  .font(.gymSupport)
                  .foregroundStyle(Color.gymSecondaryText)
              }
            }
            .padding(16)
          }
        }

        if !issues.isEmpty {
          Text("Usa el Entrenador para preparar una revisión futura. Las sesiones en curso y ya realizadas nunca se modifican.")
            .font(.gymSupport)
            .foregroundStyle(Color.gymSecondaryText)
        }
      }
      .padding(16)
      .padding(.bottom, 88)
    }
    .background(GymCanvas())
    .navigationBarBackButtonHidden()
    .toolbar(.hidden, for: .navigationBar)
    .safeAreaInset(edge: .top, spacing: 0) {
      AccentHeaderCard(title: "Compatibilidad", detail: "Perfil y planificación futura")
    }
    .overlay(alignment: .bottomLeading) { BottomBackButton(action: { dismiss() }) }
  }

  private var blockingIssues: [PlanningProfileIssue] {
    issues.filter { !$0.isCaution }
  }

  private var cautionIssues: [PlanningProfileIssue] {
    issues.filter(\.isCaution)
  }
}

private struct MacrocycleDetailView: View {
  let plan: TrainingPlan
  @Query private var completedRecords: [CompletedWorkoutRecord]
  @Environment(\.dismiss) private var dismiss

  private var weeks: [MacrocycleWeekInfo] {
    Dictionary(grouping: plan.sessions.filter { !$0.isCancelled }, by: \.week)
      .compactMap { week, sessions in
        guard let session = sessions.first else { return nil }
        return MacrocycleWeekInfo(week: week, focusLabel: session.weekFocusLabel, focus: session.weekFocus)
      }
      .sorted { $0.week < $1.week }
  }

  private var phases: [MacrocyclePhase] {
    weeks.reduce(into: []) { phases, week in
      if var last = phases.last, last.label == week.focusLabel {
        last.endWeek = week.week
        last.weeks.append(week)
        phases[phases.count - 1] = last
      } else {
        phases.append(MacrocyclePhase(label: week.focusLabel, startWeek: week.week, endWeek: week.week, weeks: [week]))
      }
    }
  }

  private var completedIDs: Set<String> { Set(completedRecords.map(\.sessionID)) }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        Text("El macrociclo organiza la progresión del plan. Las revisiones futuras conservan estas fases salvo que aceptes una propuesta que las cambie explícitamente.")
          .font(.gymBody)
          .foregroundStyle(Color.gymSecondaryText)

        MacrocyclePhaseBar(phases: phases, totalWeeks: max(1, weeks.count))

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 138), spacing: 8)], alignment: .leading, spacing: 8) {
          ForEach(phases) { phase in
            HStack(spacing: 7) {
              Circle().fill(phase.tint).frame(width: 9, height: 9)
              Text(phase.label)
                .font(.gymSupport.weight(.semibold))
                .foregroundStyle(Color.gymSecondaryText)
            }
          }
        }

        LazyVStack(spacing: 12) {
          ForEach(weeks) { week in
            MacrocycleWeekRow(
              week: week,
              sessions: plan.sessions.filter { !$0.isCancelled && $0.week == week.week },
              completedIDs: completedIDs
            )
          }
        }
      }
      .padding(16)
      .padding(.bottom, 88)
    }
    .background(GymCanvas())
    .navigationBarBackButtonHidden()
    .toolbar(.hidden, for: .navigationBar)
    .safeAreaInset(edge: .top, spacing: 0) {
      AccentHeaderCard(title: "Macrociclo", detail: "Progreso y objetivos semanales")
    }
    .overlay(alignment: .bottomLeading) { BottomBackButton(action: { dismiss() }) }
  }
}

private struct MacrocyclePhase: Identifiable {
  let label: String
  let startWeek: Int
  var endWeek: Int
  var weeks: [MacrocycleWeekInfo]

  var id: String { "\(startWeek)-\(endWeek)-\(label)" }
  var tint: Color { weeks.first?.tint ?? .gymAccent }
  var weekCount: Int { endWeek - startWeek + 1 }
  var rangeLabel: String { startWeek == endWeek ? "S\(startWeek)" : "S\(startWeek)-\(endWeek)" }
}

private struct MacrocyclePhaseBar: View {
  let phases: [MacrocyclePhase]
  let totalWeeks: Int

  var body: some View {
    GeometryReader { proxy in
      HStack(spacing: 1) {
        ForEach(phases) { phase in
          Text(phase.rangeLabel)
            .font(.gymSupport.weight(.bold))
            .foregroundStyle(Color.gymAccentForeground)
            .frame(width: proxy.size.width * CGFloat(phase.weekCount) / CGFloat(totalWeeks), height: 50)
            .background(phase.tint)
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    .frame(height: 50)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Fases del macrociclo")
  }
}

private struct MacrocycleWeekRow: View {
  let week: MacrocycleWeekInfo
  let sessions: [TrainingSession]
  let completedIDs: Set<String>

  private var completedCount: Int { sessions.filter { completedIDs.contains($0.sessionID) }.count }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      VStack(alignment: .leading, spacing: 4) {
        Text(week.focus)
          .font(.gymBody)
          .foregroundStyle(Color.gymSecondaryText)
        Text("\(completedCount)/\(sessions.count) sesiones completadas")
          .font(.gymSupport.weight(.semibold))
          .foregroundStyle(completedCount == sessions.count && !sessions.isEmpty ? Color.gymCompleted : Color.gymSecondaryText)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 14)
    .padding(.top, 58)
    .padding(.bottom, 14)
    .background(Color.gymCanvas, in: RoundedRectangle(cornerRadius: 18))
    .overlay(alignment: .topLeading) {
      HStack(spacing: 10) {
        Text("S\(week.week)")
          .font(.gymH3.weight(.bold))
          .frame(width: 30, height: 30)
          .background(Color.gymAccentForeground.opacity(0.18), in: Circle())
        Text(week.focusLabel)
          .font(.gymH2.weight(.semibold))
          .lineLimit(1)
      }
      .foregroundStyle(Color.gymAccentForeground)
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .background(week.tint, in: UnevenRoundedRectangle(
        topLeadingRadius: 18,
        bottomLeadingRadius: 0,
        bottomTrailingRadius: 18,
        topTrailingRadius: 0,
        style: .continuous
      ))
    }
    .overlay { RoundedRectangle(cornerRadius: 18).stroke(week.tint.opacity(0.42), lineWidth: 1) }
  }
}

private struct ProfilePlanIssueRow: View {
  let issue: PlanningProfileIssue
  let session: TrainingSession?

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: symbol)
        .font(.gymH3.weight(.bold))
        .foregroundStyle(Color.gymWarning)
        .frame(width: 24)
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.gymH3.weight(.bold))
        Text(session?.label ?? "Sesión futura")
          .font(.gymSupport)
          .foregroundStyle(Color.gymSecondaryText)
      }
      Spacer(minLength: 0)
    }
    .padding(.vertical, 4)
  }

  private var symbol: String {
    switch issue {
    case .duration: "clock.badge.exclamationmark"
    case .unavailableEquipment: "dumbbell.fill"
    case .restrictedExercise: "figure.strengthtraining.traditional"
    case .superset: "rectangle.3.group.fill"
    case .caution: "exclamationmark.triangle.fill"
    }
  }

  private var title: String {
    switch issue {
    case let .duration(_, minutes, maximum): "Duración estimada: \(minutes) min · preferencia: \(maximum) min"
    case let .unavailableEquipment(_, equipment): "Sin material compatible para \(equipmentLabel(equipment).lowercased())"
    case .restrictedExercise: "Incluye un ejercicio restringido por el perfil"
    case .superset: "Incluye una superserie que el perfil prefiere evitar"
    case .caution: "Molestia declarada: usa carga y RIR conservadores"
    }
  }

  private func equipmentLabel(_ equipment: Equipment) -> String {
    switch equipment {
    case .barbell: "Barra"
    case .shortBar: "Barra corta"
    case .ezBar: "Barra Z"
    case .dumbbell: "Mancuernas"
    case .kettlebell: "Kettlebell"
    case .cable: "Polea"
    case .multipower: "Multipower"
    case .weightPlate: "Discos"
    case .plateLoadedMachine: "Máquina de discos"
    case .landmine: "Landmine"
    case .abWheel: "Rodillo abdominal"
    case .assaultBike: "Bici Assault"
    case .stationaryBike: "Bici estática"
    case .skiErg: "Ski"
    case .rowErg: "Row"
    case .battleRopes: "Battle ropes"
    case .external: "Carga externa"
    case .bodyweight: "Peso corporal"
    }
  }
}

private extension PlanningProfileIssue {
  var sessionID: String {
    switch self {
    case let .duration(sessionID, _, _), let .unavailableEquipment(sessionID, _),
         let .restrictedExercise(sessionID, _), let .superset(sessionID),
         let .caution(sessionID, _): sessionID
    }
  }

  var isCaution: Bool {
    if case .caution = self { return true }
    return false
  }

  var exerciseID: String? {
    switch self {
    case let .restrictedExercise(_, exerciseID), let .caution(_, exerciseID): exerciseID
    default: nil
    }
  }
}

struct CoachConversationView: View {
  private enum BodyweightClarificationAction: Equatable {
    case reduceAssistance
    case addWeight

    var prompt: String {
      switch self {
      case .reduceAssistance: "Quieres reducir la asistencia."
      case .addWeight: "Quieres añadir lastre."
      }
    }

    var confirmationLabel: String {
      switch self {
      case .reduceAssistance: "Preparar reducción de asistencia"
      case .addWeight: "Preparar propuesta de lastre"
      }
    }
  }

  private typealias CoachFollowup = CoachConversationPendingTask

  let plan: TrainingPlan
  let initialSessionID: String?
  @Query private var profileRecords: [TrainingProfileRecord]
  @Query private var revisionRecords: [PlanRevisionRecord]
  @Query private var activeRecords: [ActiveWorkoutRecord]
  @Query private var completedRecords: [CompletedWorkoutRecord]
  @Query private var conversationRecords: [PlanningConversationRecord]
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @AppStorage("remotePlanningConsent") private var remotePlanningConsent = false
  @State private var selectedSessionID = ""
  @State private var selectedBodyweightExerciseID = ""
  @State private var selectedBodyweightSetIndex = 1
  @State private var pendingBodyweightAction: BodyweightClarificationAction?
  @State private var bodyweightExerciseSelectionRequired = false
  @State private var pendingSetAdjustmentAction: CoachSetAdjustmentRequest?
  @State private var selectedSetAdjustmentExerciseID = ""
  @State private var selectedSetAdjustmentSetIndex = 1
  @State private var setAdjustmentExerciseSelectionRequired = false
  @State private var setAdjustmentScope: CoachSetAdjustmentRequest.Scope = .singleSet
  @State private var preparedCoachOperations: [PlanningOperation]?
  @State private var preparedCoachSummary: String?
  @State private var replacementClarificationPending = false
  @State private var selectedReplacementSourceExerciseID = ""
  @State private var selectedReplacementExerciseID = ""
  @State private var replacementSourceSelectionRequired = false
  @State private var catalogAdditionClarificationPending = false
  @State private var selectedCatalogAdditionID = ""
  @State private var temporaryAvailabilityClarificationPending = false
  @State private var temporaryAvailableWeekdays = Set<Int>()
  @State private var compositeTaskQueue: [CoachFollowup] = []
  @State private var stagedCoachOperations: [PlanningOperation] = []
  @State private var stagedCoachSummaries: [String] = []
  @State private var isBuildingCompositeRequest = false
  @State private var activeCompositeTask: CoachFollowup?
  @State private var compositeRequest: PlanningIntentRequest?
  @State private var pendingCompositeMaximumMinutes: Int?
  @State private var selectedCompositeDurationOptionID = ""
  @State private var requestText = ""
  @State private var suggestedIntent: PlanningIntent?
  @State private var selectedDurationOptionID = ""
  @State private var selectedReschedulingOptionID = ""
  @State private var responseText: String?
  @State private var currentConversationID: String?
  @State private var showsPrivacyDetails = false

  init(plan: TrainingPlan, initialSessionID: String? = nil) {
    self.plan = plan
    self.initialSessionID = initialSessionID
  }

  private var profile: TrainingProfile {
    TrainingProfileStore.load(from: profileRecords) ?? .initial
  }

  private var activeSessionID: String? {
    ActiveWorkoutStore.load(from: activeRecords)?.execution.session.sessionID
  }

  private var effectivePlan: TrainingPlan {
    PlanRevisionStore.resolvedPlan(basePlan: plan, records: revisionRecords)
  }

  private var completedSessionIDs: Set<String> {
    Set(completedRecords.map(\.sessionID))
  }

  private var selectableSessions: [TrainingSession] {
    return effectivePlan.sessions
      .filter { session in
        return !session.isCancelled
          && session.sessionID != activeSessionID
          && !completedSessionIDs.contains(session.sessionID)
      }
      .sorted { $0.date < $1.date }
  }

  private var selectedSession: TrainingSession? {
    selectableSessions.first(where: { $0.sessionID == selectedSessionID })
  }

  private var bodyweightExercises: [TrainingExercise] {
    selectedSession?.exercises.filter { $0.equipment == .bodyweight } ?? []
  }

  private var selectedBodyweightExercise: TrainingExercise? {
    bodyweightExercises.first(where: { $0.exerciseID == selectedBodyweightExerciseID })
  }

  private var selectedBodyweightSet: TrainingSet? {
    selectedBodyweightExercise?.sets.first(where: { $0.setIndex == selectedBodyweightSetIndex })
  }

  private var currentBodyweightLoad: BodyweightLoad {
    selectedBodyweightSet?.bodyweightLoad ?? .init()
  }

  private var nextAssistanceKg: Double? {
    guard currentBodyweightLoad.addedWeightKg == 0 else { return nil }
    let step = max(0.5, profile.bodyweightAssistanceStepKg)
    guard currentBodyweightLoad.assistanceKg > 0 else { return nil }
    return max(0, currentBodyweightLoad.assistanceKg - step)
  }

  private var nextAddedWeightKg: Double? {
    guard currentBodyweightLoad.assistanceKg == 0 else { return nil }
    return profile.bodyweightWeightedLoadsKg.first(where: { $0 > currentBodyweightLoad.addedWeightKg })
  }

  private var adjustableExercises: [TrainingExercise] {
    selectedSession?.exercises.filter { !$0.sets.isEmpty } ?? []
  }

  private var selectedSetAdjustmentExercise: TrainingExercise? {
    adjustableExercises.first(where: { $0.exerciseID == selectedSetAdjustmentExerciseID })
  }

  private var selectedSetAdjustmentSet: TrainingSet? {
    selectedSetAdjustmentExercise?.sets.first(where: { $0.setIndex == selectedSetAdjustmentSetIndex })
  }

  private var selectedReplacementSourceExercise: TrainingExercise? {
    selectedSession?.exercises.first(where: { $0.exerciseID == selectedReplacementSourceExerciseID })
  }

  private var replacementCandidates: [TrainingExercise] {
    guard let source = selectedReplacementSourceExercise else { return [] }
    let restrictions = ProfilePlanningRestrictions.compile(from: profile)
    let planCandidates = TrainingExerciseCatalog.canonicalExercises(
      in: effectivePlan.sessions,
      excludingDisplayGroupID: source.displayGroupID
    )
    let existingGroups = Set(planCandidates.map(\.displayGroupID))
    let catalogCandidates = ExerciseCatalogStore.entries(for: effectivePlan)
      .filter { $0.baseExerciseID != source.displayGroupID && !existingGroups.contains($0.baseExerciseID) }
      .map { $0.replacementTemplate(for: source) }

    return (planCandidates + catalogCandidates)
      .filter { candidate in
      guard candidate.exerciseID != source.exerciseID,
            profile.catalogPreferences.allows(candidate),
            candidate.selectableEquipmentOptions.contains(where: {
              profile.availableEquipment.contains($0)
                && profile.catalogPreferences.allows($0, for: candidate.baseExerciseID)
            }),
            !restrictions.exerciseIDs.contains(candidate.exerciseID),
            !restrictions.exerciseIDs.contains(candidate.baseExerciseID),
            !restrictions.movementPatterns.contains(candidate.movementPattern ?? "") else { return false }
      let sharesPrimaryMuscle = !Set(candidate.primaryMuscles).isDisjoint(with: Set(source.primaryMuscles))
      return candidate.movementPattern == source.movementPattern || sharesPrimaryMuscle
    }
    .sorted { lhs, rhs in
      let lhsSamePattern = lhs.movementPattern == source.movementPattern
      let rhsSamePattern = rhs.movementPattern == source.movementPattern
      if lhsSamePattern != rhsSamePattern { return lhsSamePattern }
      return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
    }
  }

  private var selectedReplacementExercise: TrainingExercise? {
    replacementCandidates.first(where: { $0.exerciseID == selectedReplacementExerciseID })
  }

  private var catalogAdditionCandidates: [ExerciseCatalogEntry] {
    guard let session = selectedSession else { return [] }
    let restrictions = ProfilePlanningRestrictions.compile(from: profile)
    let presentGroups = Set(session.exercises.map(\.displayGroupID))
    return ExerciseCatalogStore.entries(for: effectivePlan).filter { entry in
      !presentGroups.contains(entry.baseExerciseID)
        && !profile.catalogPreferences.disabledBaseExerciseIDs.contains(entry.baseExerciseID)
        && !restrictions.exerciseIDs.contains(entry.baseExerciseID)
        && !restrictions.movementPatterns.contains(entry.movementPattern ?? "")
        && entry.equipment.contains { equipment in
          profile.availableEquipment.contains(equipment)
            && profile.catalogPreferences.allows(equipment, for: entry.baseExerciseID)
        }
    }
  }

  private var selectedCatalogAddition: ExerciseCatalogEntry? {
    catalogAdditionCandidates.first(where: { $0.baseExerciseID == selectedCatalogAdditionID })
  }

  private var catalogAdditionTemplate: TrainingExercise? {
    guard let session = selectedSession,
          let entry = selectedCatalogAddition,
          let equipment = entry.equipment.first(where: {
            profile.availableEquipment.contains($0)
              && profile.catalogPreferences.allows($0, for: entry.baseExerciseID)
          }) else { return nil }
    return entry.additionTemplate(for: session, equipment: equipment, inventory: profile.loadInventory)
  }

  private var setAdjustmentOperations: [PlanningOperation]? {
    guard let action = pendingSetAdjustmentAction,
          let session = selectedSession,
          let exercise = selectedSetAdjustmentExercise,
          let set = selectedSetAdjustmentSet else { return nil }
    let sets = setAdjustmentScope == .singleSet ? [set] : exercise.sets
    let operations = sets.compactMap { setAdjustmentOperation(action, session: session, exercise: exercise, set: $0) }
    return operations.count == sets.count && !operations.isEmpty ? operations : nil
  }

  private func setAdjustmentOperation(
    _ action: CoachSetAdjustmentRequest,
    session: TrainingSession,
    exercise: TrainingExercise,
    set: TrainingSet
  ) -> PlanningOperation? {
    switch action.kind {
    case .reps:
      guard let reps = set.targetReps else { return nil }
      let adjustedReps = action.targetValue.map { Int($0.rounded()) }
        ?? min(40, max(1, reps + (action.direction == .increase ? 1 : -1)))
      guard adjustedReps != reps else { return nil }
      return .adjustSet(sessionID: session.sessionID, exerciseID: exercise.exerciseID, setIndex: set.setIndex, reps: adjustedReps, weightKg: nil, durationSeconds: nil, restSeconds: nil)
    case .weight:
      guard exercise.equipment != .bodyweight else { return nil }
      let adjustedWeight = action.targetValue.flatMap { requestedWeight in
        EquipmentLoadRules.availableLoads(for: exercise.equipment, inventory: profile.loadInventory)
          .min { abs($0 - requestedWeight) < abs($1 - requestedWeight) }
      } ?? EquipmentLoadRules.adjustedWeight(from: set.targetWeightKg, equipment: exercise.equipment, direction: action.direction == .increase ? 1 : -1, inventory: profile.loadInventory)
      guard abs(adjustedWeight - set.targetWeightKg) > 0.001 else { return nil }
      return .adjustSet(sessionID: session.sessionID, exerciseID: exercise.exerciseID, setIndex: set.setIndex, reps: nil, weightKg: adjustedWeight, durationSeconds: nil, restSeconds: nil)
    case .rest:
      let rest = action.targetValue.map { Int($0.rounded()) }
        ?? min(300, max(30, set.restSeconds + (action.direction == .increase ? 15 : -15)))
      let boundedRest = min(300, max(30, rest))
      guard boundedRest != set.restSeconds else { return nil }
      return .adjustSet(sessionID: session.sessionID, exerciseID: exercise.exerciseID, setIndex: set.setIndex, reps: nil, weightKg: nil, durationSeconds: nil, restSeconds: boundedRest)
    }
  }

  private var currentConversation: PlanningConversationRecord? {
    guard let currentConversationID else { return nil }
    return conversationRecords.first(where: { $0.id == currentConversationID })
  }

  private var recentConversations: [PlanningConversationRecord] {
    conversationRecords.sorted { $0.updatedAt > $1.updatedAt }.prefix(5).map { $0 }
  }

  private var constraints: PlanningConstraints {
    profile.planningConstraints(
      activeSessionID: activeSessionID,
      completedSessionIDs: completedSessionIDs
    )
  }

  private var durationOptions: [SessionDurationAdaptationOption] {
    guard case let .adaptSessionDuration(sessionID, maximumMinutes) = suggestedIntent else { return [] }
    return (try? SessionDurationAdaptationPlanner.options(
      basePlan: effectivePlan,
      sessionID: sessionID,
      maximumMinutes: maximumMinutes,
      constraints: constraints
    )) ?? []
  }

  private var selectedDurationOption: SessionDurationAdaptationOption? {
    durationOptions.first(where: { $0.id == selectedDurationOptionID })
  }

  private var compositeDurationOptions: [SessionDurationAdaptationOption] {
    guard let maximumMinutes = pendingCompositeMaximumMinutes,
          let session = selectedSession else { return [] }
    return (try? SessionDurationAdaptationPlanner.options(
      basePlan: effectivePlan,
      sessionID: session.sessionID,
      maximumMinutes: maximumMinutes,
      constraints: constraints
    )) ?? []
  }

  private var selectedCompositeDurationOption: SessionDurationAdaptationOption? {
    compositeDurationOptions.first(where: { $0.id == selectedCompositeDurationOptionID })
  }

  private var reschedulingOptions: [SessionReschedulingOption] {
    guard case let .cancelSession(sessionID) = suggestedIntent else { return [] }
    return (try? SessionReschedulingPlanner.options(
      basePlan: effectivePlan,
      sessionID: sessionID,
      constraints: constraints
    )) ?? []
  }

  private var selectedReschedulingOption: SessionReschedulingOption? {
    reschedulingOptions.first(where: { $0.id == selectedReschedulingOptionID })
  }

  private var proposalOperations: [PlanningOperation]? {
    if let preparedCoachOperations { return preparedCoachOperations }
    guard let suggestedIntent else { return nil }
    if case .cancelSession = suggestedIntent, let selectedReschedulingOption {
      return selectedReschedulingOption.operations
    }
    return switch PlanningIntentResolver.resolve(suggestedIntent) {
    case let .operations(operations): operations
    case .requiresPlanningStrategy: selectedDurationOption?.operations
    }
  }

  private var proposalSummary: String? {
    preparedCoachSummary ?? suggestedIntent.map(summary(for:))
  }

  private var coachCoherenceIssues: [CoachRequestCoherenceIssue] {
    guard let proposalOperations else { return [] }
    return CoachRequestCoherence.issues(
      in: effectivePlan,
      operations: proposalOperations,
      context: .init(
        globalGoal: profile.goal.label,
        priorityMuscles: Set(profile.priorityMuscleGroups)
      )
    )
  }

  private var hasBlockingCoachCoherenceIssue: Bool {
    coachCoherenceIssues.contains { $0.severity == .blocking }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("La interpretación local prepara una revisión; el plan solo cambia cuando la aceptas.")
          .font(.gymBody)
          .foregroundStyle(Color.gymSecondaryText)

        SettingsCategory(title: "Privacidad") {
          VStack(alignment: .leading, spacing: 10) {
            Toggle("Autorizar contexto remoto", isOn: $remotePlanningConsent)
              .font(.gymBody.weight(.semibold))
            Text(remotePlanningConsent
              ? "La autorización queda registrada. Esta versión no transmite datos."
              : "El intérprete actual funciona solo en el dispositivo.")
              .font(.gymSupport)
              .foregroundStyle(Color.gymSecondaryText)
            DisclosureGroup("Ver datos incluidos", isExpanded: $showsPrivacyDetails) {
              Text("Incluirá objetivo, experiencia, disponibilidad, material y la sesión elegida. Excluirá Salud, series ejecutadas, pesos reales, historial y molestias.")
                .font(.gymSupport)
                .foregroundStyle(Color.gymSecondaryText)
                .padding(.top, 4)
            }
            .font(.gymSupport.weight(.semibold))
          }
          .padding(16)
        }

        if selectableSessions.isEmpty {
          ContentUnavailableView(
            "No hay sesiones disponibles",
            systemImage: "calendar.badge.exclamationmark",
            description: Text("Las sesiones activas y completadas se protegen de cambios."))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
        } else {
          SettingsCategory(title: "Sesión") {
            VStack(alignment: .leading, spacing: 0) {
              Picker("Sesión", selection: $selectedSessionID) {
                ForEach(selectableSessions) { session in
                  Text("\(Self.dateLabel(session.date)) · \(session.sessionLabel)")
                    .tag(session.sessionID)
                }
              }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
          }

          if !bodyweightExercises.isEmpty {
            SettingsCategory(title: "Peso corporal") {
              VStack(alignment: .leading, spacing: 10) {
                if let pendingBodyweightAction {
                  Label("Necesito concretar el ejercicio y la serie.", systemImage: "questionmark.circle")
                    .font(.gymBody.weight(.semibold))
                    .foregroundStyle(Color.gymAccent)
                  Text(pendingBodyweightAction.prompt)
                    .font(.gymSupport)
                    .foregroundStyle(Color.gymSecondaryText)
                }
                Picker("Ejercicio", selection: $selectedBodyweightExerciseID) {
                  if bodyweightExerciseSelectionRequired {
                    Text("Elige el ejercicio").tag("")
                  }
                  ForEach(bodyweightExercises) { exercise in
                    Text(exercise.displayName).tag(exercise.exerciseID)
                  }
                }
                if let exercise = selectedBodyweightExercise {
                  Picker("Serie", selection: $selectedBodyweightSetIndex) {
                    ForEach(exercise.sets, id: \.setIndex) { set in
                      Text("Serie \(set.setIndex)").tag(set.setIndex)
                    }
                  }
                }
                Text(bodyweightLoadDetail)
                  .font(.gymSupport)
                  .foregroundStyle(Color.gymSecondaryText)
                if let pendingBodyweightAction {
                  Button(action: { completeBodyweightClarification(pendingBodyweightAction) }) {
                    Label(pendingBodyweightAction.confirmationLabel, systemImage: "text.badge.checkmark")
                      .frame(maxWidth: .infinity, minHeight: 44)
                  }
                  .font(.gymBody.weight(.semibold))
                  .foregroundStyle(Color.gymAccentForeground)
                  .background(Color.gymAccent, in: RoundedRectangle(cornerRadius: 12))
                  .buttonStyle(.plain)
                  .disabled(selectedBodyweightExercise == nil || selectedBodyweightSet == nil || (pendingBodyweightAction == .reduceAssistance ? nextAssistanceKg == nil : nextAddedWeightKg == nil))
                  .opacity(selectedBodyweightExercise == nil || selectedBodyweightSet == nil || (pendingBodyweightAction == .reduceAssistance ? nextAssistanceKg == nil : nextAddedWeightKg == nil) ? 0.45 : 1)
                } else {
                  HStack(spacing: 10) {
                    Button(action: proposeLessAssistance) {
                      Label("Reducir asistencia", systemImage: "arrow.down")
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .font(.gymBody.weight(.semibold))
                    .foregroundStyle(Color.gymControlSelectionForeground)
                    .background(Color.gymControlSelectionFill, in: RoundedRectangle(cornerRadius: 12))
                    .buttonStyle(.plain)
                    .disabled(nextAssistanceKg == nil)
                    .opacity(nextAssistanceKg == nil ? 0.45 : 1)

                    Button(action: proposeAddedWeight) {
                      Label("Añadir lastre", systemImage: "plus")
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .font(.gymBody.weight(.semibold))
                    .foregroundStyle(Color.gymAccentForeground)
                    .background(Color.gymAccent, in: RoundedRectangle(cornerRadius: 12))
                    .buttonStyle(.plain)
                    .disabled(nextAddedWeightKg == nil)
                    .opacity(nextAddedWeightKg == nil ? 0.45 : 1)
                  }
                }
                if profile.bodyweightWeightedLoadsKg.isEmpty {
                  Text("Añade lastres disponibles desde tu perfil para poder proponerlos.")
                    .font(.gymSupport)
                    .foregroundStyle(Color.gymSecondaryText)
                }
              }
              .padding(16)
            }
          }

          if let pendingSetAdjustmentAction {
            SettingsCategory(title: "Aclaración necesaria") {
              VStack(alignment: .leading, spacing: 10) {
                Label("Necesito concretar el ejercicio y la serie.", systemImage: "questionmark.circle")
                  .font(.gymBody.weight(.semibold))
                  .foregroundStyle(Color.gymAccent)
                Text(setAdjustmentPrompt(pendingSetAdjustmentAction))
                  .font(.gymSupport)
                  .foregroundStyle(Color.gymSecondaryText)
                Picker("Ejercicio", selection: $selectedSetAdjustmentExerciseID) {
                  if setAdjustmentExerciseSelectionRequired {
                    Text("Elige el ejercicio").tag("")
                  }
                  ForEach(adjustableExercises) { exercise in
                    Text(exercise.displayName).tag(exercise.exerciseID)
                  }
                }
                if let exercise = selectedSetAdjustmentExercise {
                  Picker("Serie", selection: $selectedSetAdjustmentSetIndex) {
                    ForEach(exercise.sets, id: \.setIndex) { set in
                      Text("Serie \(set.setIndex)").tag(set.setIndex)
                    }
                  }
                }
                Picker("Aplicar", selection: $setAdjustmentScope) {
                  Text("Solo esta serie").tag(CoachSetAdjustmentRequest.Scope.singleSet)
                  Text("Todas las series del ejercicio").tag(CoachSetAdjustmentRequest.Scope.matchingSets)
                }
                Text(setAdjustmentDetail)
                  .font(.gymSupport)
                  .foregroundStyle(Color.gymSecondaryText)
                Button(action: completeSetAdjustmentClarification) {
                  Label(setAdjustmentConfirmationLabel(pendingSetAdjustmentAction), systemImage: "text.badge.checkmark")
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .font(.gymBody.weight(.semibold))
                .foregroundStyle(Color.gymAccentForeground)
                .background(Color.gymAccent, in: RoundedRectangle(cornerRadius: 12))
                .buttonStyle(.plain)
                .disabled(setAdjustmentOperations == nil)
                .opacity(setAdjustmentOperations == nil ? 0.45 : 1)
              }
              .padding(16)
            }
          }

          if replacementClarificationPending {
            SettingsCategory(title: "Sustituir ejercicio") {
              VStack(alignment: .leading, spacing: 10) {
                Label("Necesito concretar la sustitución.", systemImage: "arrow.triangle.swap")
                  .font(.gymBody.weight(.semibold))
                  .foregroundStyle(Color.gymAccent)
                Text("Elige una alternativa: se muestran las opciones equivalentes del catálogo que respetan tu perfil.")
                  .font(.gymSupport)
                  .foregroundStyle(Color.gymSecondaryText)
                Picker("Ejercicio actual", selection: $selectedReplacementSourceExerciseID) {
                  if replacementSourceSelectionRequired {
                    Text("Elige el ejercicio").tag("")
                  }
                  ForEach(selectedSession?.exercises ?? []) { exercise in
                    Text(exercise.displayName).tag(exercise.exerciseID)
                  }
                }
                if replacementCandidates.isEmpty, selectedReplacementSourceExercise != nil {
                  Text("No hay una alternativa compatible con el material y las restricciones actuales.")
                    .font(.gymSupport)
                    .foregroundStyle(Color.gymWarning)
                } else {
                  Picker("Sustituir por", selection: $selectedReplacementExerciseID) {
                    Text("Elige una alternativa").tag("")
                    ForEach(replacementCandidates) { exercise in
                      Text(exercise.displayName).tag(exercise.exerciseID)
                    }
                  }
                }
                Text(replacementDetail)
                  .font(.gymSupport)
                  .foregroundStyle(Color.gymSecondaryText)
                Button(action: prepareReplacementReview) {
                  Label("Preparar sustitución", systemImage: "text.badge.checkmark")
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .font(.gymBody.weight(.semibold))
                .foregroundStyle(Color.gymAccentForeground)
                .background(Color.gymAccent, in: RoundedRectangle(cornerRadius: 12))
                .buttonStyle(.plain)
                .disabled(selectedReplacementSourceExercise == nil || selectedReplacementExercise == nil)
                .opacity(selectedReplacementSourceExercise == nil || selectedReplacementExercise == nil ? 0.45 : 1)
              }
              .padding(16)
            }
          }

          if catalogAdditionClarificationPending {
            SettingsCategory(title: "Añadir ejercicio") {
              VStack(alignment: .leading, spacing: 10) {
                Label("Elige un ejercicio para incorporar.", systemImage: "plus.rectangle.on.rectangle")
                  .font(.gymBody.weight(.semibold))
                  .foregroundStyle(Color.gymAccent)
                Text("Solo se muestran alternativas del catálogo que no duplican la sesión y respetan tu material, preferencias y restricciones.")
                  .font(.gymSupport)
                  .foregroundStyle(Color.gymSecondaryText)
                if catalogAdditionCandidates.isEmpty {
                  Text("No hay ejercicios compatibles disponibles para añadir a esta sesión.")
                    .font(.gymSupport)
                    .foregroundStyle(Color.gymWarning)
                } else {
                  Picker("Ejercicio", selection: $selectedCatalogAdditionID) {
                    Text("Elige un ejercicio").tag("")
                    ForEach(catalogAdditionCandidates) { entry in
                      Text(entry.name).tag(entry.baseExerciseID)
                    }
                  }
                  if let template = catalogAdditionTemplate,
                     let firstSet = template.sets.first {
                    let volume = firstSet.targetReps.map { "\($0) reps" }
                      ?? firstSet.targetDurationSeconds.map { "\($0) s" }
                      ?? "series técnicas"
                    Text("Introducción: \(template.sets.count) series · \(volume) · \(firstSet.restSeconds) s de descanso.")
                      .font(.gymSupport)
                      .foregroundStyle(Color.gymSecondaryText)
                    Text("Se añade como accesorio técnico y no se integra en una superserie.")
                      .font(.gymSupport)
                      .foregroundStyle(Color.gymSecondaryText)
                  }
                }
                Button(action: prepareCatalogAdditionReview) {
                  Label("Preparar incorporación", systemImage: "text.badge.checkmark")
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .font(.gymBody.weight(.semibold))
                .foregroundStyle(Color.gymAccentForeground)
                .background(Color.gymAccent, in: RoundedRectangle(cornerRadius: 12))
                .buttonStyle(.plain)
                .disabled(catalogAdditionTemplate == nil)
                .opacity(catalogAdditionTemplate == nil ? 0.45 : 1)
              }
              .padding(16)
            }
          }

          if temporaryAvailabilityClarificationPending {
            SettingsCategory(title: "Disponibilidad temporal") {
              VStack(alignment: .leading, spacing: 12) {
                Label("Elige los días disponibles para esa semana.", systemImage: "calendar.badge.clock")
                  .font(.gymBody.weight(.semibold))
                  .foregroundStyle(Color.gymAccent)
                Text("No se modificará tu disponibilidad habitual. El entrenador conservará el trabajo esencial y preparará una revisión para que la aceptes.")
                  .font(.gymSupport)
                  .foregroundStyle(Color.gymSecondaryText)
                HStack(spacing: 8) {
                  ForEach(Array(zip(["L", "M", "X", "J", "V", "S", "D"], 1...7)), id: \.1) { label, day in
                    Button(label) {
                      if temporaryAvailableWeekdays.contains(day) {
                        temporaryAvailableWeekdays.remove(day)
                      } else {
                        temporaryAvailableWeekdays.insert(day)
                      }
                    }
                    .font(.gymSupport.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .foregroundStyle(temporaryAvailableWeekdays.contains(day) ? Color.gymControlSelectionForeground : Color.gymSecondaryText)
                    .background(temporaryAvailableWeekdays.contains(day) ? Color.gymControlSelectionFill : Color.gymSurface, in: RoundedRectangle(cornerRadius: 10))
                    .buttonStyle(.plain)
                  }
                }
                Button(action: prepareTemporaryAvailabilityReview) {
                  Label("Preparar adaptación semanal", systemImage: "calendar.badge.checkmark")
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .font(.gymBody.weight(.semibold))
                .foregroundStyle(Color.gymAccentForeground)
                .background(Color.gymAccent, in: RoundedRectangle(cornerRadius: 12))
                .buttonStyle(.plain)
                .disabled(temporaryAvailableWeekdays.isEmpty)
                .opacity(temporaryAvailableWeekdays.isEmpty ? 0.45 : 1)
              }
              .padding(16)
            }
          }

          if let maximumMinutes = pendingCompositeMaximumMinutes {
            SettingsCategory(title: "Adaptar duración") {
              VStack(alignment: .leading, spacing: 10) {
                Label("Elige una alternativa para \(maximumMinutes) min.", systemImage: "clock.arrow.2.circlepath")
                  .font(.gymBody.weight(.semibold))
                  .foregroundStyle(Color.gymAccent)
                if compositeDurationOptions.isEmpty {
                  Text("No hay una alternativa conservadora para acortar esta sesión.")
                    .font(.gymSupport)
                    .foregroundStyle(Color.gymWarning)
                } else {
                  ForEach(compositeDurationOptions) { option in
                    Button { selectedCompositeDurationOptionID = option.id } label: {
                      VStack(alignment: .leading, spacing: 3) {
                        HStack {
                          Text(option.title).font(.gymBody.weight(.bold))
                          Spacer()
                          Image(systemName: selectedCompositeDurationOptionID == option.id ? "checkmark.circle.fill" : "circle")
                        }
                        Text("\(option.detail) \(option.estimatedMinutes) min.")
                          .font(.gymSupport)
                          .multilineTextAlignment(.leading)
                      }
                      .frame(maxWidth: .infinity, alignment: .leading)
                      .padding(10)
                      .foregroundStyle(selectedCompositeDurationOptionID == option.id ? Color.gymControlSelectionForeground : .primary)
                      .background(selectedCompositeDurationOptionID == option.id ? Color.gymControlSelectionFill : Color.gymSurface, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                  }
                }
                Button(action: completeCompositeDuration) {
                  Label("Añadir adaptación", systemImage: "text.badge.checkmark")
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .font(.gymBody.weight(.semibold))
                .foregroundStyle(Color.gymAccentForeground)
                .background(Color.gymAccent, in: RoundedRectangle(cornerRadius: 12))
                .buttonStyle(.plain)
                .disabled(selectedCompositeDurationOption == nil)
                .opacity(selectedCompositeDurationOption == nil ? 0.45 : 1)
              }
              .padding(16)
            }
          }

          SettingsCategory(title: "Solicitud") {
            VStack(spacing: 10) {
              TextEditor(text: $requestText)
                .font(.gymBody)
                .frame(minHeight: 72)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(Color.gymCanvas, in: RoundedRectangle(cornerRadius: 12))
                .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.25), lineWidth: 1) }

              HStack(spacing: 10) {
                coachPrompt("No podré entrenar")
                coachPrompt("Solo tengo 45 minutos")
              }
              HStack(spacing: 10) {
                coachPrompt("Muévela al jueves")
                coachPrompt("Vacaciones próximas")
              }
            }
            .padding(16)
          }

          Button(action: interpretRequest) {
            Label("Interpretar solicitud", systemImage: "text.bubble")
              .font(.gymH3.weight(.bold))
              .frame(maxWidth: .infinity, minHeight: 52)
          }
          .foregroundStyle(Color.gymAccentForeground)
          .background(Color.gymAccent, in: RoundedRectangle(cornerRadius: 16))
          .disabled(requestText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          .opacity(requestText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)

          if let proposalSummary {
            SettingsCategory(title: "Interpretación") {
              Text(proposalSummary)
                .font(.gymH3.weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)

              if !coachCoherenceIssues.isEmpty {
                SettingsDivider()
                ForEach(coachCoherenceIssues) { issue in
                  Label(issue.message, systemImage: issue.severity == .blocking ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .font(.gymSupport.weight(.semibold))
                    .foregroundStyle(issue.severity == .blocking ? Color.gymDanger : Color.gymWarning)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
              }

              if case let .adaptSessionDuration(_, maximumMinutes) = suggestedIntent {
                SettingsDivider()
                if durationOptions.isEmpty {
                  Text("No hay una alternativa conservadora para llegar a \(maximumMinutes) min.")
                    .font(.gymBody)
                    .foregroundStyle(Color.gymSecondaryText)
                } else {
                  ForEach(durationOptions) { option in
                    Button { selectedDurationOptionID = option.id } label: {
                      HStack(alignment: .top, spacing: 10) {
                        Image(systemName: selectedDurationOptionID == option.id ? "checkmark.circle.fill" : "circle")
                          .foregroundStyle(selectedDurationOptionID == option.id ? Color.gymAccent : Color.gymSecondaryText)
                        VStack(alignment: .leading, spacing: 3) {
                          Text(option.title).font(.gymBody.weight(.bold))
                          Text("\(option.detail) \(option.estimatedMinutes) min.")
                            .font(.gymSupport)
                            .multilineTextAlignment(.leading)
                        }
                      }
                      .frame(maxWidth: .infinity, alignment: .leading)
                      .padding(10)
                      .background(selectedDurationOptionID == option.id ? Color.gymControlSelectionFill : Color.gymSurface, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                  }
                }
              }

              if case .cancelSession = suggestedIntent, !reschedulingOptions.isEmpty {
                SettingsDivider()
                Text("Alternativas disponibles")
                  .font(.gymH3.weight(.bold))
                ForEach(reschedulingOptions) { option in
                  Button { selectedReschedulingOptionID = option.id } label: {
                    HStack(spacing: 10) {
                      Image(systemName: selectedReschedulingOptionID == option.id ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedReschedulingOptionID == option.id ? Color.gymAccent : Color.gymSecondaryText)
                      VStack(alignment: .leading, spacing: 2) {
                        Text("Reprogramar al \(Self.dateLabel(option.date))")
                          .font(.gymBody.weight(.semibold))
                        if option.isOutsideAvailability {
                          Text("Fuera de tu disponibilidad habitual")
                            .font(.gymSupport)
                            .foregroundStyle(Color.gymWarning)
                        }
                        if option.shiftsOtherSessions {
                          Text("Desplaza \(option.shiftedSessionIDs.count) sesión\(option.shiftedSessionIDs.count == 1 ? "" : "es") posterior\(option.shiftedSessionIDs.count == 1 ? "" : "es")")
                            .font(.gymSupport)
                            .foregroundStyle(Color.gymSecondaryText)
                        }
                      }
                      Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(selectedReschedulingOptionID == option.id ? Color.gymControlSelectionFill : Color.gymSurface, in: RoundedRectangle(cornerRadius: 12))
                  }
                  .buttonStyle(.plain)
                }
                Button("Cancelar la sesión", action: { selectedReschedulingOptionID = "" })
                  .font(.gymSupport.weight(.semibold))
                  .foregroundStyle(Color.gymDanger)
                  .buttonStyle(.plain)
              }
            }

            Button(action: createReview) {
              Label("Crear revisión", systemImage: "doc.badge.plus")
                .font(.gymH3.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .foregroundStyle(Color.gymAccentForeground)
            .background(Color.gymAccent, in: RoundedRectangle(cornerRadius: 16))
            .disabled(proposalOperations == nil)
            .disabled(hasBlockingCoachCoherenceIssue)
            .opacity(proposalOperations == nil || hasBlockingCoachCoherenceIssue ? 0.45 : 1)
          }
        }

        if !recentConversations.isEmpty {
          SettingsCategory(title: "Historial local") {
            ForEach(recentConversations, id: \.id) { conversation in
              VStack(alignment: .leading, spacing: 4) {
                HStack {
                  Text(conversation.status.label)
                    .font(.gymSupport.weight(.bold))
                    .foregroundStyle(statusColor(for: conversation.status))
                  Spacer()
                  Text(Self.timeLabel(conversation.updatedAt))
                    .font(.gymSupport)
                    .foregroundStyle(Color.gymSecondaryText)
                }
                Text(conversation.requestText)
                  .font(.gymBody)
                  .lineLimit(2)
                if !conversation.responseText.isEmpty {
                  Text(conversation.responseText)
                    .font(.gymSupport)
                    .foregroundStyle(Color.gymSecondaryText)
                    .lineLimit(2)
                }
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal, 12)
              .padding(.vertical, 10)

              if conversation.id != recentConversations.last?.id {
                SettingsDivider()
              }
            }

            Button("Eliminar historial local", role: .destructive, action: deleteConversationHistory)
              .font(.gymBody.weight(.semibold))
              .frame(maxWidth: .infinity, minHeight: 42)
              .buttonStyle(.bordered)
          }
        }
      }
      .padding(16)
      .padding(.bottom, 88)
    }
    .background(GymCanvas())
    .navigationBarBackButtonHidden()
    .toolbar(.hidden, for: .navigationBar)
    .safeAreaInset(edge: .top, spacing: 0) {
      AccentHeaderCard(title: "Entrenador", detail: "Solicitud y propuesta")
    }
    .overlay(alignment: .bottomLeading) { BottomBackButton(action: { dismiss() }) }
    .onAppear {
      selectedSessionID = selectableSessions.first(where: { $0.sessionID == initialSessionID })?.sessionID
        ?? selectableSessions.first?.sessionID
        ?? ""
      selectInitialBodyweightExercise()
      selectInitialSetAdjustmentExercise()
      restoreCompositeDraft()
    }
    .onChange(of: selectedSessionID) { _, _ in
      suggestedIntent = nil
      selectedDurationOptionID = ""
      pendingBodyweightAction = nil
      bodyweightExerciseSelectionRequired = false
      pendingSetAdjustmentAction = nil
      setAdjustmentExerciseSelectionRequired = false
      preparedCoachOperations = nil
      preparedCoachSummary = nil
      replacementClarificationPending = false
      replacementSourceSelectionRequired = false
      catalogAdditionClarificationPending = false
      selectedCatalogAdditionID = ""
      temporaryAvailabilityClarificationPending = false
      temporaryAvailableWeekdays = []
      selectInitialBodyweightExercise()
      selectInitialSetAdjustmentExercise()
    }
    .onChange(of: selectedBodyweightExerciseID) { _, _ in
      selectedBodyweightSetIndex = selectedBodyweightExercise?.sets.first?.setIndex ?? 1
      if !selectedBodyweightExerciseID.isEmpty {
        bodyweightExerciseSelectionRequired = false
      }
    }
    .onChange(of: selectedSetAdjustmentExerciseID) { _, _ in
      selectedSetAdjustmentSetIndex = selectedSetAdjustmentExercise?.sets.first?.setIndex ?? 1
      if !selectedSetAdjustmentExerciseID.isEmpty {
        setAdjustmentExerciseSelectionRequired = false
      }
      persistCompositeDraft()
    }
    .onChange(of: selectedReplacementSourceExerciseID) { _, _ in
      if !selectedReplacementSourceExerciseID.isEmpty {
        replacementSourceSelectionRequired = false
      }
      selectedReplacementExerciseID = replacementCandidates.first?.exerciseID ?? ""
      persistCompositeDraft()
    }
    .alert(
      "Entrenador",
      isPresented: Binding(
        get: { responseText != nil },
        set: { if !$0 { responseText = nil } }
      )
    ) {
      Button("Aceptar", role: .cancel) { responseText = nil }
    } message: {
      Text(responseText ?? "")
    }
  }

  @ViewBuilder
  private func coachPrompt(_ text: String) -> some View {
    Button(text) {
      requestText = text == "No podré entrenar"
        ? "No podré entrenar esta sesión"
        : text == "Muévela al jueves"
          ? "Mueve esta sesión al jueves"
        : text == "Vacaciones próximas"
            ? "Estaré de vacaciones la semana que viene"
            : "Quiero hacer esta sesión en 45 minutos"
    }
    .font(.gymSupport.weight(.semibold))
    .lineLimit(1)
    .minimumScaleFactor(0.85)
    .frame(maxWidth: .infinity, minHeight: 34)
    .foregroundStyle(Color.gymControlSelectionForeground)
    .background(Color.gymControlSelectionFill, in: RoundedRectangle(cornerRadius: 10))
    .buttonStyle(.plain)
  }

  private func interpretRequest() {
    let request = PlanningIntentRequest(userText: requestText, referencedSessionID: selectedSessionID)
    let record = PlanningConversationStore.start(request, in: modelContext)
    currentConversationID = record.id
    preparedCoachOperations = nil
    preparedCoachSummary = nil
    let followups = coachFollowups(in: requestText)
    if followups.count > 1 {
      isBuildingCompositeRequest = true
      compositeTaskQueue = Array(followups.dropFirst())
      stagedCoachOperations = []
      stagedCoachSummaries = []
      compositeRequest = request
      activate(followups[0], request: request, record: record)
      return
    }
    if let action = bodyweightAction(in: requestText) {
      beginBodyweightClarification(action, request: request, record: record)
      return
    }
    if replacementRequest(in: requestText) {
      beginReplacementClarification(request: request, record: record)
      return
    }
    if catalogAdditionRequest(in: requestText) {
      beginCatalogAdditionClarification(request: request, record: record)
      return
    }
    if temporaryAvailabilityRequest(in: requestText) {
      beginTemporaryAvailabilityClarification(request: request, record: record)
      return
    }
    if let action = setAdjustmentAction(in: requestText) {
      beginSetAdjustmentClarification(action, request: request, record: record)
      return
    }
    Task { @MainActor in
      do {
        let intents = try await LocalPlanningIntentInterpreter().interpret(request)
        guard let intent = intents.first else { return }
        suggestedIntent = intent
        selectedDurationOptionID = durationOptions.first?.id ?? ""
        selectedReschedulingOptionID = reschedulingOptions.first?.id ?? ""
        PlanningConversationStore.interpret(intent, summary: summary(for: intent), for: record, in: modelContext)
      } catch {
        suggestedIntent = nil
        selectedDurationOptionID = ""
        selectedReschedulingOptionID = ""
        responseText = error.localizedDescription
        PlanningConversationStore.needsClarification(error.localizedDescription, for: record, in: modelContext)
      }
    }
  }

  private func coachFollowups(in text: String) -> [CoachFollowup] {
    var result: [CoachFollowup] = []
    if let date = requestedDate(in: text) { result.append(.moveSession(toDate: date)) }
    if let minutes = requestedMinutes(in: text) { result.append(.adaptDuration(maximumMinutes: minutes)) }
    if replacementRequest(in: text) { result.append(.replacement) }
    if catalogAdditionRequest(in: text) { result.append(.catalogAddition) }
    if let action = setAdjustmentAction(in: text) { result.append(.setAdjustment(action)) }
    return result
  }

  private func activate(_ followup: CoachFollowup, request: PlanningIntentRequest, record: PlanningConversationRecord) {
    activeCompositeTask = followup
    switch followup {
    case .replacement:
      beginReplacementClarification(request: request, record: record)
    case .catalogAddition:
      beginCatalogAdditionClarification(request: request, record: record)
    case let .setAdjustment(action):
      beginSetAdjustmentClarification(action, request: request, record: record)
    case let .moveSession(toDate):
      _ = stageCompositeOperation(
        .moveSession(sessionID: request.referencedSessionID ?? "", toDate: toDate),
        summary: "Mover la sesión al \(Self.dateLabel(toDate))"
      )
    case let .adaptDuration(maximumMinutes):
      pendingCompositeMaximumMinutes = maximumMinutes
      selectedCompositeDurationOptionID = compositeDurationOptions.first?.id ?? ""
    }
    persistCompositeDraft(for: record)
  }

  private func completeCompositeDuration() {
    guard let option = selectedCompositeDurationOption else { return }
    pendingCompositeMaximumMinutes = nil
    _ = stageCompositeOperations(option.operations, summary: "Adaptar la sesión a \(option.estimatedMinutes) min")
  }

  private func requestedDate(in text: String) -> String? {
    let pattern = "\\b(\\d{4}-\\d{2}-\\d{2})\\b"
    guard let expression = try? NSRegularExpression(pattern: pattern),
          let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
          let range = Range(match.range(at: 1), in: text) else {
      let normalizedText = normalized(text)
      let calendar = Calendar.current
      let today = calendar.startOfDay(for: .now)
      if normalizedText.contains("pasado manana") {
        return Self.isoDate(calendar.date(byAdding: .day, value: 2, to: today) ?? today)
      }
      if normalizedText.contains("manana") {
        return Self.isoDate(calendar.date(byAdding: .day, value: 1, to: today) ?? today)
      }
      let weekdays = ["domingo", "lunes", "martes", "miercoles", "jueves", "viernes", "sabado"]
      for (index, weekday) in weekdays.enumerated() where normalizedText.contains(weekday) {
        let current = calendar.component(.weekday, from: today) - 1
        let delta = (index - current + 7) % 7
        return Self.isoDate(calendar.date(byAdding: .day, value: delta == 0 ? 7 : delta, to: today) ?? today)
      }
      return nil
    }
    return String(text[range])
  }

  private func requestedMinutes(in text: String) -> Int? {
    let pattern = "\\b(\\d{1,3})\\s*(?:min|mins|minutos)\\b"
    guard let expression = try? NSRegularExpression(pattern: pattern),
          let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
          let range = Range(match.range(at: 1), in: text),
          let minutes = Int(text[range]) else { return nil }
    return min(120, max(15, minutes))
  }

  private func beginReplacementClarification(
    request: PlanningIntentRequest,
    record: PlanningConversationRecord
  ) {
    guard let session = selectedSession, !session.exercises.isEmpty else {
      let message = "La sesión elegida no contiene ejercicios que se puedan sustituir."
      responseText = message
      PlanningConversationStore.needsClarification(message, for: record, in: modelContext)
      return
    }
    let matches = session.exercises.filter { exercise in
      let name = normalized(exercise.displayName)
      return name.count > 2 && normalized(request.userText).contains(name)
    }
    replacementClarificationPending = true
    pendingBodyweightAction = nil
    pendingSetAdjustmentAction = nil
    suggestedIntent = nil
    preparedCoachOperations = nil
    preparedCoachSummary = nil
    if matches.count == 1, let exercise = matches.first {
      selectedReplacementSourceExerciseID = exercise.exerciseID
      replacementSourceSelectionRequired = false
      selectedReplacementExerciseID = ""
    } else {
      selectedReplacementSourceExerciseID = ""
      selectedReplacementExerciseID = ""
      replacementSourceSelectionRequired = true
    }
    PlanningConversationStore.needsClarification(
      matches.count == 1
        ? "Falta confirmar la alternativa para sustituir el ejercicio."
        : "Falta seleccionar el ejercicio y su alternativa compatible.",
      for: record,
      in: modelContext
    )
  }

  private func replacementRequest(in text: String) -> Bool {
    let text = normalized(text)
    let asksToReplace = text.contains("sustitu") || text.contains("cambia") || text.contains("reemplaza")
    guard asksToReplace || text.contains("no puedo") else { return false }
    return selectedSession?.exercises.contains { exercise in
      let name = normalized(exercise.displayName)
      return name.count > 2 && text.contains(name)
    } ?? false
  }

  private func catalogAdditionRequest(in text: String) -> Bool {
    let text = normalized(text)
    let asksToAdd = text.contains("anade") || text.contains("agrega") || text.contains("incluye") || text.contains("incorpora")
    guard asksToAdd else { return false }
    return text.contains("ejercicio") || catalogAdditionCandidates.contains { entry in
      let name = normalized(entry.name)
      return name.count > 2 && text.contains(name)
    }
  }

  private func temporaryAvailabilityRequest(in text: String) -> Bool {
    let value = normalized(text)
    return (value.contains("solo puedo entrenar") || value.contains("solo tendre") || value.contains("solo tengo"))
      && (value.contains("dia") || value.contains("semana"))
  }

  private func beginTemporaryAvailabilityClarification(
    request: PlanningIntentRequest,
    record: PlanningConversationRecord
  ) {
    guard let session = selectedSession else {
      let message = "Selecciona una sesión de la semana que quieres adaptar."
      responseText = message
      PlanningConversationStore.needsClarification(message, for: record, in: modelContext)
      return
    }
    temporaryAvailabilityClarificationPending = true
    temporaryAvailableWeekdays = Set(profile.trainingWeekdays)
    preparedCoachOperations = nil
    preparedCoachSummary = nil
    suggestedIntent = nil
    PlanningConversationStore.needsClarification(
      "Indica los días concretos disponibles para la semana de \(session.sessionLabel). No cambiaré la disponibilidad habitual de tu perfil.",
      for: record,
      in: modelContext
    )
  }

  private func prepareTemporaryAvailabilityReview() {
    guard let session = selectedSession else { return }
    var temporaryConstraints = constraints
    temporaryConstraints.availableWeekdays = Set(temporaryAvailableWeekdays.map { $0 == 7 ? 1 : $0 + 1 })
    let sessions = effectivePlan.sessions.filter {
      !$0.isCancelled && $0.week == session.week && $0.date >= Self.isoDate(.now)
    }
    guard let option = WeeklySessionCompressionPlanner.option(
      basePlan: effectivePlan,
      sessionIDs: sessions.map(\.sessionID),
      constraints: temporaryConstraints
    ) else {
      responseText = "Con esos días no hace falta reducir sesiones; puedes reprogramarlas manteniendo la estructura actual."
      return
    }
    preparedCoachOperations = option.operations
    let omitted = effectivePlan.sessions
      .filter { option.cancelledSessionIDs.contains($0.sessionID) }
      .map(\.sessionLabel)
      .joined(separator: ", ")
    preparedCoachSummary = "Adaptar S\(session.week) a \(temporaryAvailableWeekdays.count) días. Se conserva el trabajo principal y queda sin programar: \(omitted)."
    temporaryAvailabilityClarificationPending = false
  }

  private func preferredReplacement(for source: TrainingExercise, text: String) -> TrainingExercise? {
    let text = normalized(text)
    if text.contains("mancuerna") {
      return replacementCandidates.first(where: { $0.selectableEquipmentOptions.contains(.dumbbell) })
    }
    if text.contains("barra") {
      return replacementCandidates.first(where: { $0.selectableEquipmentOptions.contains(.barbell) })
    }
    if text.contains("polea") {
      return replacementCandidates.first(where: { $0.selectableEquipmentOptions.contains(.cable) })
    }
    return replacementCandidates.first { candidate in
      let name = normalized(candidate.displayName)
      return name.count > 2 && text.contains(name)
    }
  }

  private var replacementDetail: String {
    guard let source = selectedReplacementSourceExercise else {
      return "Selecciona el ejercicio que quieres sustituir."
    }
    guard let replacement = selectedReplacementExercise else {
      return "Elige una alternativa compatible para \(source.displayName)."
    }
    let pattern = replacement.movementPattern == source.movementPattern
      ? "Conserva el patrón de movimiento"
      : "Conserva el grupo muscular principal"
    let superset = source.supersetID == nil ? "" : " Mantendrá su posición en la superserie."
    return "\(pattern) y las \(source.sets.count) series previstas.\(superset)"
  }

  private func prepareReplacementReview() {
    guard let session = selectedSession,
          let source = selectedReplacementSourceExercise,
          let replacement = selectedReplacementExercise else { return }
    let operation: PlanningOperation = replacement.exerciseID.hasPrefix("catalog.")
      ? .replaceExerciseWithTemplate(sessionID: session.sessionID, exerciseID: source.exerciseID, replacement: replacement)
      : .replaceExercise(sessionID: session.sessionID, exerciseID: source.exerciseID, replacementExerciseID: replacement.exerciseID)
    if stageCompositeOperation(operation, summary: "Sustituir \(source.displayName) por \(replacement.displayName)") {
      replacementClarificationPending = false
      replacementSourceSelectionRequired = false
      return
    }
    let request = PlanningIntentRequest(userText: "Sustituir \(source.displayName) por \(replacement.displayName)", referencedSessionID: session.sessionID)
    let record = PlanningConversationStore.start(request, in: modelContext)
    currentConversationID = record.id
    requestText = request.userText
    suggestedIntent = nil
    preparedCoachOperations = [operation]
    preparedCoachSummary = "Sustituir \(source.displayName) por \(replacement.displayName)"
    replacementClarificationPending = false
    replacementSourceSelectionRequired = false
    PlanningConversationStore.interpret([operation], summary: preparedCoachSummary ?? "Sustituir ejercicio", for: record, in: modelContext)
  }

  private func beginCatalogAdditionClarification(
    request: PlanningIntentRequest,
    record: PlanningConversationRecord
  ) {
    guard selectedSession != nil else {
      let message = "Selecciona una sesión antes de incorporar un ejercicio."
      responseText = message
      PlanningConversationStore.needsClarification(message, for: record, in: modelContext)
      return
    }
    guard !catalogAdditionCandidates.isEmpty else {
      let message = "No hay ejercicios del catálogo compatibles con el material y las restricciones actuales."
      responseText = message
      PlanningConversationStore.needsClarification(message, for: record, in: modelContext)
      return
    }
    catalogAdditionClarificationPending = true
    replacementClarificationPending = false
    replacementSourceSelectionRequired = false
    pendingBodyweightAction = nil
    pendingSetAdjustmentAction = nil
    suggestedIntent = nil
    preparedCoachOperations = nil
    preparedCoachSummary = nil
    selectedCatalogAdditionID = ""
    PlanningConversationStore.needsClarification(
      "Elige qué ejercicio compatible quieres incorporar. Prepararé una introducción conservadora para que la revises.",
      for: record,
      in: modelContext
    )
  }

  private func prepareCatalogAdditionReview() {
    guard let session = selectedSession,
          let template = catalogAdditionTemplate else { return }
    let operation = PlanningOperation.addExerciseWithTemplate(sessionID: session.sessionID, exercise: template)
    let summary = "Incorporar \(template.displayName) como accesorio en \(session.sessionLabel)"
    if stageCompositeOperation(operation, summary: summary) {
      catalogAdditionClarificationPending = false
      selectedCatalogAdditionID = ""
      return
    }
    let request = PlanningIntentRequest(userText: summary, referencedSessionID: session.sessionID)
    let record = PlanningConversationStore.start(request, in: modelContext)
    currentConversationID = record.id
    requestText = summary
    suggestedIntent = nil
    preparedCoachOperations = [operation]
    preparedCoachSummary = summary
    catalogAdditionClarificationPending = false
    selectedCatalogAdditionID = ""
    PlanningConversationStore.interpret([operation], summary: summary, for: record, in: modelContext)
  }

  private func beginSetAdjustmentClarification(
    _ action: CoachSetAdjustmentRequest,
    request: PlanningIntentRequest,
    record: PlanningConversationRecord
  ) {
    guard !adjustableExercises.isEmpty else {
      let message = "La sesión elegida no contiene series que se puedan ajustar."
      responseText = message
      PlanningConversationStore.needsClarification(message, for: record, in: modelContext)
      return
    }
    let candidates = adjustableExercises.filter { exercise in
      let name = normalized(exercise.displayName)
      return name.count > 2 && normalized(request.userText).contains(name)
    }
    pendingSetAdjustmentAction = action
    pendingBodyweightAction = nil
    suggestedIntent = nil
    preparedCoachOperations = nil
    preparedCoachSummary = nil
    if candidates.count == 1, let exercise = candidates.first {
      selectedSetAdjustmentExerciseID = exercise.exerciseID
      selectedSetAdjustmentSetIndex = exercise.sets.first?.setIndex ?? 1
      setAdjustmentExerciseSelectionRequired = false
    } else {
      selectedSetAdjustmentExerciseID = ""
      selectedSetAdjustmentSetIndex = 1
      setAdjustmentExerciseSelectionRequired = true
    }
    PlanningConversationStore.needsClarification(
      candidates.count == 1
        ? "Falta confirmar la serie que se va a ajustar."
        : "Falta seleccionar el ejercicio y la serie que se van a ajustar.",
      for: record,
      in: modelContext
    )
  }

  private func completeSetAdjustmentClarification() {
    guard let operations = setAdjustmentOperations,
          let exercise = selectedSetAdjustmentExercise else { return }
    prepareSetAdjustmentReview(operations, text: "Ajustar serie de \(exercise.displayName)")
  }

  private func setAdjustmentAction(in text: String) -> CoachSetAdjustmentRequest? {
    let text = normalized(text)
    let raises = text.contains("sube") || text.contains("aumenta") || text.contains("mas")
    let lowers = text.contains("baja") || text.contains("reduce") || text.contains("menos")
    if text.contains("rep") || text.contains("repeticion") {
      if raises { return .init(kind: .reps, direction: .increase, targetValue: requestedValue(in: text, unit: "rep")) }
      if lowers { return .init(kind: .reps, direction: .decrease, targetValue: requestedValue(in: text, unit: "rep")) }
    }
    if text.contains("peso") || text.contains("carga") || text.contains("kilo") || text.contains("kg") {
      if raises { return .init(kind: .weight, direction: .increase, targetValue: requestedValue(in: text, unit: "kg")) }
      if lowers { return .init(kind: .weight, direction: .decrease, targetValue: requestedValue(in: text, unit: "kg")) }
    }
    if text.contains("descanso") {
      if raises { return .init(kind: .rest, direction: .increase, targetValue: requestedValue(in: text, unit: "s")) }
      if lowers { return .init(kind: .rest, direction: .decrease, targetValue: requestedValue(in: text, unit: "s")) }
    }
    return nil
  }

  private func requestedValue(in text: String, unit: String) -> Double? {
    let pattern = "(?:a|hasta|en)\\s*(\\d+(?:[.,]\\d+)?)\\s*" + NSRegularExpression.escapedPattern(for: unit)
    guard let expression = try? NSRegularExpression(pattern: pattern),
          let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
          let range = Range(match.range(at: 1), in: text) else { return nil }
    return Double(text[range].replacingOccurrences(of: ",", with: "."))
  }

  private func beginBodyweightClarification(
    _ action: BodyweightClarificationAction,
    request: PlanningIntentRequest,
    record: PlanningConversationRecord
  ) {
    guard !bodyweightExercises.isEmpty else {
      let message = "La sesión elegida no contiene ejercicios de peso corporal para ajustar."
      responseText = message
      PlanningConversationStore.needsClarification(message, for: record, in: modelContext)
      return
    }
    let matches = bodyweightExercises.filter { exercise in
      let name = normalized(exercise.displayName)
      return name.count > 2 && normalized(request.userText).contains(name)
    }
    pendingBodyweightAction = action
    suggestedIntent = nil
    if matches.count == 1, let exercise = matches.first {
      selectedBodyweightExerciseID = exercise.exerciseID
      selectedBodyweightSetIndex = exercise.sets.first?.setIndex ?? 1
      bodyweightExerciseSelectionRequired = false
    } else {
      selectedBodyweightExerciseID = ""
      selectedBodyweightSetIndex = 1
      bodyweightExerciseSelectionRequired = true
    }
    PlanningConversationStore.needsClarification(
      matches.count == 1
        ? "Falta confirmar la serie de peso corporal."
        : "Falta seleccionar el ejercicio y la serie de peso corporal.",
      for: record,
      in: modelContext
    )
  }

  private func completeBodyweightClarification(_ action: BodyweightClarificationAction) {
    switch action {
    case .reduceAssistance: proposeLessAssistance()
    case .addWeight: proposeAddedWeight()
    }
  }

  private func bodyweightAction(in text: String) -> BodyweightClarificationAction? {
    let text = normalized(text)
    if (text.contains("asistencia") || text.contains("asistida"))
      && (text.contains("reduce") || text.contains("baja") || text.contains("menos")) {
      return .reduceAssistance
    }
    if text.contains("lastre")
      && (text.contains("anade") || text.contains("añade") || text.contains("sube") || text.contains("aumenta")) {
      return .addWeight
    }
    return nil
  }

  private func normalized(_ text: String) -> String {
    text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
  }

  private func createReview() {
    guard let operations = proposalOperations else { return }
    guard !hasBlockingCoachCoherenceIssue else {
      responseText = "La propuesta contradice la fase u objetivo de la semana. Ajusta la solicitud antes de crear la revisión."
      return
    }
    do {
      let revision = try PlanRevisionStore.propose(
        operations: operations,
        basedOn: plan,
        effectiveFrom: .now,
        reason: "Solicitud al entrenador: \(requestText)",
        constraints: constraints,
        in: modelContext,
        existingRecords: revisionRecords
      )
      if let currentConversation {
        PlanningConversationStore.link(revision, to: currentConversation, in: modelContext)
      }
      responseText = "Revisión \(revision.revisionNumber) creada como pendiente. Revísala y acéptala desde Planificación."
      suggestedIntent = nil
      preparedCoachOperations = nil
      preparedCoachSummary = nil
    } catch {
      responseText = error.localizedDescription
    }
  }

  private var bodyweightLoadDetail: String {
    guard let exercise = selectedBodyweightExercise, let set = selectedBodyweightSet else {
      return "Selecciona un ejercicio y una serie."
    }
    switch currentBodyweightLoad.mode {
    case .unassisted:
      return "\(exercise.displayName), serie \(set.setIndex): sin asistencia ni lastre."
    case .assisted:
      return "\(exercise.displayName), serie \(set.setIndex): asistencia de \(Self.weightLabel(currentBodyweightLoad.assistanceKg)) kg."
    case .weighted:
      return "\(exercise.displayName), serie \(set.setIndex): lastre de \(Self.weightLabel(currentBodyweightLoad.addedWeightKg)) kg."
    }
  }

  private var setAdjustmentDetail: String {
    guard let action = pendingSetAdjustmentAction,
          let exercise = selectedSetAdjustmentExercise,
          let set = selectedSetAdjustmentSet else {
      return "Selecciona un ejercicio y una serie."
    }
    switch action.kind {
    case .reps:
      guard let reps = set.targetReps else { return "Esta serie no usa repeticiones." }
      let adjustedReps = action.targetValue.map { Int($0.rounded()) }
        ?? min(40, max(1, reps + (action.direction == .increase ? 1 : -1)))
      return "\(exercise.displayName), serie \(set.setIndex): \(reps) → \(min(40, max(1, adjustedReps))) reps."
    case .weight:
      guard exercise.equipment != .bodyweight else { return "El peso corporal se ajusta mediante asistencia o lastre." }
      let weight = action.targetValue.flatMap { requestedWeight in
        EquipmentLoadRules.availableLoads(for: exercise.equipment, inventory: profile.loadInventory)
          .min { abs($0 - requestedWeight) < abs($1 - requestedWeight) }
      } ?? EquipmentLoadRules.adjustedWeight(from: set.targetWeightKg, equipment: exercise.equipment, direction: action.direction == .increase ? 1 : -1, inventory: profile.loadInventory)
      return weight == set.targetWeightKg
        ? "No hay otro peso disponible para este material."
        : "\(exercise.displayName), serie \(set.setIndex): \(Self.weightLabel(set.targetWeightKg)) → \(Self.weightLabel(weight)) kg."
    case .rest:
      let requestedRest = action.targetValue.map { Int($0.rounded()) }
        ?? set.restSeconds + (action.direction == .increase ? 15 : -15)
      let rest = min(300, max(30, requestedRest))
      return rest == set.restSeconds
        ? "El descanso ya está en el límite permitido."
        : "\(exercise.displayName), serie \(set.setIndex): \(set.restSeconds) → \(rest) s de descanso."
    }
  }

  private func setAdjustmentPrompt(_ request: CoachSetAdjustmentRequest) -> String {
    switch (request.kind, request.direction, request.targetValue) {
    case (.reps, .increase, .some(let target)): return "Quieres dejar la serie en \(Int(target.rounded())) reps."
    case (.reps, .decrease, .some(let target)): return "Quieres dejar la serie en \(Int(target.rounded())) reps."
    case (.reps, .increase, nil): return "Quieres añadir una repetición."
    case (.reps, .decrease, nil): return "Quieres reducir una repetición."
    case (.weight, _, .some(let target)): return "Quieres aproximar el peso a \(Self.weightLabel(target)) kg con el material disponible."
    case (.weight, .increase, nil): return "Quieres subir al siguiente peso disponible."
    case (.weight, .decrease, nil): return "Quieres bajar al peso disponible anterior."
    case (.rest, _, .some(let target)): return "Quieres dejar el descanso en \(Int(target.rounded())) s."
    case (.rest, .increase, nil): return "Quieres añadir 15 segundos de descanso."
    case (.rest, .decrease, nil): return "Quieres reducir 15 segundos de descanso."
    }
  }

  private func setAdjustmentConfirmationLabel(_ request: CoachSetAdjustmentRequest) -> String {
    switch request.kind {
    case .reps: "Preparar ajuste de reps"
    case .weight: "Preparar ajuste de peso"
    case .rest: "Preparar ajuste de descanso"
    }
  }

  private func proposeLessAssistance() {
    guard let session = selectedSession,
          let exercise = selectedBodyweightExercise,
          let assistanceKg = nextAssistanceKg else { return }
    prepareBodyweightReview(
      .adjustBodyweightLoad(
        sessionID: session.sessionID,
        exerciseID: exercise.exerciseID,
        setIndex: selectedBodyweightSetIndex,
        assistanceKg: assistanceKg,
        addedWeightKg: 0
      ),
      text: "Reducir asistencia en \(exercise.displayName)"
    )
  }

  private func proposeAddedWeight() {
    guard let session = selectedSession,
          let exercise = selectedBodyweightExercise,
          let addedWeightKg = nextAddedWeightKg else { return }
    prepareBodyweightReview(
      .adjustBodyweightLoad(
        sessionID: session.sessionID,
        exerciseID: exercise.exerciseID,
        setIndex: selectedBodyweightSetIndex,
        assistanceKg: 0,
        addedWeightKg: addedWeightKg
      ),
      text: "Añadir lastre en \(exercise.displayName)"
    )
  }

  private func prepareBodyweightReview(_ intent: PlanningIntent, text: String) {
    let request = PlanningIntentRequest(userText: text, referencedSessionID: selectedSessionID)
    let record = PlanningConversationStore.start(request, in: modelContext)
    currentConversationID = record.id
    requestText = text
    suggestedIntent = intent
    pendingBodyweightAction = nil
    bodyweightExerciseSelectionRequired = false
    PlanningConversationStore.interpret(intent, summary: summary(for: intent), for: record, in: modelContext)
  }

  private func prepareSetAdjustmentReview(_ operations: [PlanningOperation], text: String) {
    if stageCompositeOperations(operations, summary: text) { return }
    let request = PlanningIntentRequest(userText: text, referencedSessionID: selectedSessionID)
    let record = PlanningConversationStore.start(request, in: modelContext)
    currentConversationID = record.id
    requestText = text
    suggestedIntent = nil
    preparedCoachOperations = operations
    preparedCoachSummary = operations.count == 1
      ? "Ajustar una serie de \(selectedSetAdjustmentExercise?.displayName ?? "ejercicio")"
      : "Ajustar \(operations.count) series de \(selectedSetAdjustmentExercise?.displayName ?? "ejercicio")"
    pendingSetAdjustmentAction = nil
    setAdjustmentExerciseSelectionRequired = false
    PlanningConversationStore.interpret(operations, summary: preparedCoachSummary ?? "Ajustar series", for: record, in: modelContext)
  }

  private func stageCompositeOperation(_ operation: PlanningOperation, summary: String) -> Bool {
    stageCompositeOperations([operation], summary: summary)
  }

  private func stageCompositeOperations(_ operations: [PlanningOperation], summary: String) -> Bool {
    guard isBuildingCompositeRequest else { return false }
    stagedCoachOperations.append(contentsOf: operations)
    stagedCoachSummaries.append(summary)
    pendingSetAdjustmentAction = nil
    replacementClarificationPending = false
    replacementSourceSelectionRequired = false
    catalogAdditionClarificationPending = false
    selectedCatalogAdditionID = ""
    if !compositeTaskQueue.isEmpty {
      let next = compositeTaskQueue.removeFirst()
      guard let record = currentConversation else { return true }
      let request = compositeRequest ?? PlanningIntentRequest(userText: requestText, referencedSessionID: selectedSessionID)
      activate(next, request: request, record: record)
      return true
    }
    isBuildingCompositeRequest = false
    preparedCoachOperations = stagedCoachOperations
    preparedCoachSummary = "Propuesta compuesta: " + stagedCoachSummaries.joined(separator: " · ")
    if let record = currentConversation {
      PlanningConversationStore.interpret(stagedCoachOperations, summary: preparedCoachSummary ?? "Propuesta compuesta", for: record, in: modelContext)
      PlanningConversationStore.clearDraft(for: record, in: modelContext)
    }
    stagedCoachOperations = []
    stagedCoachSummaries = []
    activeCompositeTask = nil
    compositeRequest = nil
    return true
  }

  private func persistCompositeDraft(for record: PlanningConversationRecord? = nil) {
    guard isBuildingCompositeRequest,
          let activeCompositeTask,
          let request = compositeRequest ?? Optional(PlanningIntentRequest(userText: requestText, referencedSessionID: selectedSessionID)),
          let target = record ?? currentConversation else { return }
    let draft = CoachConversationDraft(
      request: request,
      activeTask: activeCompositeTask,
      queuedTasks: compositeTaskQueue,
      stagedOperations: stagedCoachOperations,
      stagedSummaries: stagedCoachSummaries
    )
    PlanningConversationStore.saveDraft(draft, message: "Aclaración pendiente: continúa la solicitud para crear una propuesta compuesta.", for: target, in: modelContext)
  }

  private func restoreCompositeDraft() {
    guard !isBuildingCompositeRequest,
          let record = conversationRecords
            .filter({ $0.draftData != nil })
            .sorted(by: { $0.updatedAt > $1.updatedAt })
            .first,
          let data = record.draftData,
          let draft = try? JSONDecoder().decode(CoachConversationDraft.self, from: data),
          selectableSessions.contains(where: { $0.sessionID == draft.request.referencedSessionID }) else { return }
    currentConversationID = record.id
    requestText = draft.request.userText
    selectedSessionID = draft.request.referencedSessionID ?? ""
    isBuildingCompositeRequest = true
    compositeRequest = draft.request
    compositeTaskQueue = draft.queuedTasks
    stagedCoachOperations = draft.stagedOperations
    stagedCoachSummaries = draft.stagedSummaries
    activate(draft.activeTask, request: draft.request, record: record)
  }

  private func selectInitialBodyweightExercise() {
    selectedBodyweightExerciseID = bodyweightExercises.first?.exerciseID ?? ""
    selectedBodyweightSetIndex = bodyweightExercises.first?.sets.first?.setIndex ?? 1
  }

  private func selectInitialSetAdjustmentExercise() {
    selectedSetAdjustmentExerciseID = adjustableExercises.first?.exerciseID ?? ""
    selectedSetAdjustmentSetIndex = adjustableExercises.first?.sets.first?.setIndex ?? 1
  }

  private func summary(for intent: PlanningIntent) -> String {
    switch intent {
    case let .moveSession(_, date): "Mover la sesión al \(Self.dateLabel(date))"
    case let .postponeFutureSessions(fromDate, byDays): "Retrasar el macrociclo desde \(Self.dateLabel(fromDate)) \(byDays) días"
    case let .gymClosure(date): "El gimnasio no abre el \(Self.dateLabel(date)); retrasar el macrociclo un día"
    case .cancelSession: "Cancelar la sesión seleccionada"
    case .replaceExercise: "Sustituir un ejercicio"
    case .adjustSet: "Ajustar una serie"
    case let .adjustBodyweightLoad(_, _, _, assistanceKg, addedWeightKg):
      assistanceKg > 0
        ? "Ajustar asistencia a \(Self.weightLabel(assistanceKg)) kg"
        : "Ajustar lastre a \(Self.weightLabel(addedWeightKg)) kg"
    case let .adaptSessionDuration(_, minutes): "Adaptar esta sesión a \(minutes) min"
    }
  }

  private func statusColor(for status: PlanningConversationStatus) -> Color {
    switch status {
    case .interpreted: Color.gymAccent
    case .needsClarification: Color.gymWarning
    case .proposed: Color.gymCompleted
    }
  }

  private func deleteConversationHistory() {
    for record in conversationRecords {
      modelContext.delete(record)
    }
    currentConversationID = nil
    try? modelContext.save()
  }

  private static func weightLabel(_ value: Double) -> String {
    value.rounded() == value ? String(Int(value)) : String(format: "%.2f", value)
  }

  private static func date(from value: String) -> Date? {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: value)
  }

  private static func isoDate(_ value: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: value)
  }

  private static func dateLabel(_ value: String) -> String {
    guard let date = date(from: value) else { return value }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "es_ES")
    formatter.dateStyle = .medium
    return formatter.string(from: date)
  }

  private static func timeLabel(_ value: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "es_ES")
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter.string(from: value)
  }
}

private struct ProposalSimulatorView: View {
  let plan: TrainingPlan
  @Query private var profileRecords: [TrainingProfileRecord]
  @Query private var revisionRecords: [PlanRevisionRecord]
  @Query private var activeRecords: [ActiveWorkoutRecord]
  @Query private var completedRecords: [CompletedWorkoutRecord]
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @State private var selectedSessionID = ""
  @State private var intent: ProposalSimulationIntent = .move
  @State private var targetDate = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
  @State private var selectedExerciseID = ""
  @State private var replacementExerciseID = ""
  @State private var selectedCatalogExerciseID = ""
  @State private var selectedSetIndex = 1
  @State private var adjustedReps = 8
  @State private var adjustedWeightKg = 0.0
  @State private var requestedDuration = 45
  @State private var selectedAdaptationID = ""
  @State private var resultMessage: String?

  private var activeSessionID: String? {
    ActiveWorkoutStore.load(from: activeRecords)?.execution.session.sessionID
  }

  private var completedSessionIDs: Set<String> {
    Set(completedRecords.map(\.sessionID))
  }

  private var effectivePlan: TrainingPlan {
    PlanRevisionStore.resolvedPlan(basePlan: plan, records: revisionRecords)
  }

  private var editableSessions: [TrainingSession] {
    effectivePlan.sessions
      .filter {
        !$0.isCancelled
          && !completedSessionIDs.contains($0.sessionID)
          && $0.sessionID != activeSessionID
          && Self.date(from: $0.date) >= Calendar.current.startOfDay(for: .now)
      }
      .sorted { $0.date < $1.date }
  }

  private var selectedSession: TrainingSession? {
    editableSessions.first(where: { $0.sessionID == selectedSessionID })
  }

  private var selectedExercise: TrainingExercise? {
    selectedSession?.exercises.first(where: { $0.exerciseID == selectedExerciseID })
  }

  private var selectedSet: TrainingSet? {
    selectedExercise?.sets.first(where: { $0.setIndex == selectedSetIndex })
  }

  private var planningConstraints: PlanningConstraints {
    profile.planningConstraints(
      activeSessionID: activeSessionID,
      completedSessionIDs: completedSessionIDs
    )
  }

  private var durationOptions: [SessionDurationAdaptationOption] {
    guard let selectedSession else { return [] }
    return (try? SessionDurationAdaptationPlanner.options(
      basePlan: effectivePlan,
      sessionID: selectedSession.sessionID,
      maximumMinutes: requestedDuration,
      constraints: planningConstraints
    )) ?? []
  }

  private var selectedDurationOption: SessionDurationAdaptationOption? {
    durationOptions.first(where: { $0.id == selectedAdaptationID })
  }

  private var replacementExercises: [TrainingExercise] {
    TrainingExerciseCatalog.canonicalExercises(
      in: effectivePlan.sessions,
      excludingDisplayGroupID: selectedExercise?.displayGroupID
    )
  }

  private var catalogAdditionCandidates: [ExerciseCatalogEntry] {
    guard let selectedSession else { return [] }
    let restrictions = ProfilePlanningRestrictions.compile(from: profile)
    let presentGroups = Set(selectedSession.exercises.map(\.displayGroupID))
    return ExerciseCatalogStore.entries(for: effectivePlan)
      .filter { entry in
        !presentGroups.contains(entry.baseExerciseID)
          && !profile.catalogPreferences.disabledBaseExerciseIDs.contains(entry.baseExerciseID)
          && !restrictions.exerciseIDs.contains(entry.baseExerciseID)
          && !restrictions.movementPatterns.contains(entry.movementPattern ?? "")
          && entry.equipment.contains { equipment in
            profile.availableEquipment.contains(equipment)
              && profile.catalogPreferences.allows(equipment, for: entry.baseExerciseID)
          }
      }
  }

  private var selectedCatalogExercise: ExerciseCatalogEntry? {
    catalogAdditionCandidates.first(where: { $0.baseExerciseID == selectedCatalogExerciseID })
  }

  private var catalogAdditionTemplate: TrainingExercise? {
    guard let selectedSession,
          let entry = selectedCatalogExercise,
          let equipment = entry.equipment.first(where: {
            profile.availableEquipment.contains($0)
              && profile.catalogPreferences.allows($0, for: entry.baseExerciseID)
          }) else { return nil }
    return entry.additionTemplate(for: selectedSession, equipment: equipment, inventory: profile.loadInventory)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("Prueba una modificación antes de pedirla al agente. La propuesta se guarda como pendiente y no sustituye el plan hasta que se acepte.")
          .font(.gymBody)
          .foregroundStyle(Color.gymSecondaryText)

        if editableSessions.isEmpty {
          ContentUnavailableView(
            "No hay sesiones editables",
            systemImage: "calendar.badge.exclamationmark",
            description: Text("Las sesiones completadas, pasadas o en curso se protegen de las propuestas."))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
        } else {
          SettingsCategory(title: "Propuesta") {
            Picker("Sesión", selection: $selectedSessionID) {
              ForEach(editableSessions) { session in
                Text("\(Self.dateLabel(session.date)) · \(session.sessionLabel)")
                  .tag(session.sessionID)
              }
            }

            SettingsDivider()

            Picker("Acción", selection: $intent) {
              ForEach(ProposalSimulationIntent.allCases) { action in
                Text(action.label).tag(action)
              }
            }
            .pickerStyle(.menu)

            switch intent {
            case .move:
              SettingsDivider()
              DatePicker(
                "Nueva fecha",
                selection: $targetDate,
                in: Calendar.current.startOfDay(for: .now)...,
                displayedComponents: .date
              )
            case .replaceExercise:
              exercisePicker
              SettingsDivider()
              replacementPicker
            case .addExercise:
              catalogAdditionPicker
            case .adjustSet:
              exercisePicker
              SettingsDivider()
              setAdjustmentControls
            case .adaptDuration:
              SettingsDivider()
              Stepper("Duración máxima: \(requestedDuration) min", value: $requestedDuration, in: 15 ... 120, step: 5)
              if durationOptions.isEmpty {
                Text("No hay una alternativa conservadora que reduzca esta sesión.")
                  .font(.gymSupport)
                  .foregroundStyle(Color.gymSecondaryText)
              } else {
                ForEach(durationOptions) { option in
                  Button { selectedAdaptationID = option.id } label: {
                    VStack(alignment: .leading, spacing: 3) {
                      HStack {
                        Text(option.title).font(.gymBody.weight(.bold))
                        Spacer()
                        Text("\(option.estimatedMinutes) min").font(.gymSupport.weight(.bold))
                      }
                      Text(option.detail).font(.gymSupport).multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .foregroundStyle(selectedAdaptationID == option.id ? Color.gymControlSelectionForeground : .primary)
                    .background(selectedAdaptationID == option.id ? Color.gymControlSelectionFill : Color.gymSurface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay { RoundedRectangle(cornerRadius: 12).stroke(selectedAdaptationID == option.id ? Color.gymAccent : Color.secondary.opacity(0.3), lineWidth: 1) }
                  }
                  .buttonStyle(.plain)
                }
              }
            case .cancel:
              EmptyView()
            }
          }

          if let selectedSession {
            SettingsCategory(title: "Validación") {
              ValidationDetailRow(title: "Sesión", value: selectedSession.sessionLabel)
              SettingsDivider()
              ValidationDetailRow(title: "Material", value: equipmentSummary(for: selectedSession))
              if !profile.declaredDiscomforts.isEmpty {
                SettingsDivider()
                ValidationDetailRow(title: "Molestias", value: profile.declaredDiscomforts.joined(separator: ", "))
              }
              SettingsDivider()
              ValidationDetailRow(title: "Restricciones aplicadas", value: restrictionsSummary)
            }
          }

          Button(action: createProposal) {
            Label(intent.buttonLabel, systemImage: intent.symbol)
              .font(.gymH3.weight(.bold))
              .frame(maxWidth: .infinity, minHeight: 54)
          }
          .foregroundStyle(Color.gymAccentForeground)
          .background(Color.gymAccent, in: RoundedRectangle(cornerRadius: 16))
        }
      }
      .padding(16)
      .padding(.bottom, 88)
    }
    .background(GymCanvas())
    .navigationBarBackButtonHidden()
    .toolbar(.hidden, for: .navigationBar)
    .safeAreaInset(edge: .top, spacing: 0) {
      AccentHeaderCard(title: "Simulador de propuestas", detail: "Validación local del plan")
    }
    .overlay(alignment: .bottomLeading) { BottomBackButton(action: { dismiss() }) }
    .onAppear {
      if selectedSessionID.isEmpty {
        selectedSessionID = editableSessions.first?.sessionID ?? ""
      }
      resetExerciseSelection()
      selectedAdaptationID = durationOptions.first?.id ?? ""
    }
    .onChange(of: editableSessions.map(\.sessionID)) { _, sessionIDs in
      if !sessionIDs.contains(selectedSessionID) {
        selectedSessionID = sessionIDs.first ?? ""
      }
      resetExerciseSelection()
    }
    .onChange(of: selectedSessionID) { _, _ in
      resetExerciseSelection()
      selectedCatalogExerciseID = catalogAdditionCandidates.first?.baseExerciseID ?? ""
      selectedAdaptationID = durationOptions.first?.id ?? ""
    }
    .onChange(of: selectedExerciseID) { _, _ in
      guard let exercise = selectedExercise else { return }
      replacementExerciseID = replacementExercises.first?.exerciseID ?? ""
      selectedSetIndex = exercise.sets.first?.setIndex ?? 1
      syncAdjustmentValues()
    }
    .onChange(of: selectedSetIndex) { _, _ in
      syncAdjustmentValues()
    }
    .onChange(of: requestedDuration) { _, _ in
      selectedAdaptationID = durationOptions.first?.id ?? ""
    }
    .onChange(of: intent) { _, newIntent in
      if newIntent == .adaptDuration {
        selectedAdaptationID = durationOptions.first?.id ?? ""
      }
      if newIntent == .addExercise {
        selectedCatalogExerciseID = catalogAdditionCandidates.first?.baseExerciseID ?? ""
      }
    }
    .alert(
      "Simulador de propuestas",
      isPresented: Binding(
        get: { resultMessage != nil },
        set: { if !$0 { resultMessage = nil } }
      )
    ) {
      Button("Aceptar", role: .cancel) { resultMessage = nil }
    } message: {
      Text(resultMessage ?? "")
    }
  }

  private var profile: TrainingProfile {
    TrainingProfileStore.load(from: profileRecords) ?? .initial
  }

  private func createProposal() {
    guard let session = selectedSession else { return }
    let operation: PlanningOperation
    switch intent {
    case .move:
      operation = .moveSession(sessionID: session.sessionID, toDate: Self.isoDate(targetDate))
    case .cancel:
      operation = .cancelSession(sessionID: session.sessionID)
    case .replaceExercise:
      guard !selectedExerciseID.isEmpty, !replacementExerciseID.isEmpty else {
        resultMessage = "Elige el ejercicio actual y su sustitución."
        return
      }
      operation = .replaceExercise(
        sessionID: session.sessionID,
        exerciseID: selectedExerciseID,
        replacementExerciseID: replacementExerciseID
      )
    case .addExercise:
      guard let template = catalogAdditionTemplate else {
        resultMessage = "Elige un ejercicio compatible del catálogo."
        return
      }
      operation = .addExerciseWithTemplate(sessionID: session.sessionID, exercise: template)
    case .adjustSet:
      guard !selectedExerciseID.isEmpty else {
        resultMessage = "Elige el ejercicio y la serie que quieres ajustar."
        return
      }
      operation = .adjustSet(
        sessionID: session.sessionID,
        exerciseID: selectedExerciseID,
        setIndex: selectedSetIndex,
        reps: selectedSet?.targetReps == nil ? nil : adjustedReps,
        weightKg: adjustedWeightKg,
        durationSeconds: nil,
        restSeconds: nil
      )
    case .adaptDuration:
      guard let option = selectedDurationOption else {
        resultMessage = "Elige una alternativa para acortar la sesión."
        return
      }
      createProposal(operations: option.operations, effectiveFrom: .now, reason: "Simulación interna: adaptar sesión a \(requestedDuration) min")
      return
    }

    createProposal(operations: [operation], effectiveFrom: .now, reason: "Simulación interna: \(intent.reason)")
  }

  private func createProposal(operations: [PlanningOperation], effectiveFrom: Date, reason: String) {
    do {
      let revision = try PlanRevisionStore.propose(
        operations: operations,
        basedOn: plan,
        effectiveFrom: effectiveFrom,
        reason: reason,
        constraints: planningConstraints,
        in: modelContext,
        existingRecords: revisionRecords
      )
      resultMessage = "Propuesta \(revision.revisionNumber) creada como pendiente. Puedes revisarla y aceptarla desde Planificación."
    } catch {
      resultMessage = error.localizedDescription
    }
  }

  private func equipmentSummary(for session: TrainingSession) -> String {
    let required = Set(session.exercises.map(\.equipment))
    let unavailable = required.subtracting(profile.availableEquipment)
    if unavailable.isEmpty { return "Compatible con el perfil" }
    return "Falta: \(unavailable.map(\.executionLabel).sorted().joined(separator: ", "))"
  }

  private var restrictionsSummary: String {
    let restrictions = ProfilePlanningRestrictions.compile(from: profile)
    var values: [String] = []
    if !restrictions.exerciseIDs.isEmpty { values.append("Ejercicios vetados") }
    if !restrictions.movementPatterns.isEmpty { values.append("Patrones restringidos") }
    if restrictions.avoidsSupersets { values.append("Sin superseries") }
    return values.isEmpty ? "Disponibilidad, duración y material" : values.joined(separator: " · ")
  }

  @ViewBuilder
  private var exercisePicker: some View {
    SettingsDivider()
    Picker("Ejercicio", selection: $selectedExerciseID) {
      ForEach(selectedSession?.exercises ?? []) { exercise in
        Text(exercise.displayName).tag(exercise.exerciseID)
      }
    }
  }

  @ViewBuilder
  private var replacementPicker: some View {
    Picker("Sustituir por", selection: $replacementExerciseID) {
      ForEach(replacementExercises) { exercise in
        Text(exercise.displayName).tag(exercise.exerciseID)
      }
    }
  }

  @ViewBuilder
  private var catalogAdditionPicker: some View {
    if catalogAdditionCandidates.isEmpty {
      Text("No hay ejercicios nuevos del catálogo compatibles con el perfil para esta sesión.")
        .font(.gymSupport)
        .foregroundStyle(Color.gymSecondaryText)
    } else {
      Picker("Ejercicio del catálogo", selection: $selectedCatalogExerciseID) {
        ForEach(catalogAdditionCandidates) { entry in
          Text(entry.name).tag(entry.baseExerciseID)
        }
      }
      if let template = catalogAdditionTemplate {
        Text("Introducción: \(template.sets.count) series · \(template.sets.first?.targetReps ?? 0) reps · \(template.sets.first?.restSeconds ?? 0) s · \(template.equipment.executionLabel)")
          .font(.gymSupport)
          .foregroundStyle(Color.gymSecondaryText)
      }
    }
  }

  @ViewBuilder
  private var setAdjustmentControls: some View {
    Picker("Serie", selection: $selectedSetIndex) {
      ForEach(selectedExercise?.sets ?? []) { trainingSet in
        Text("Serie \(trainingSet.setIndex)").tag(trainingSet.setIndex)
      }
    }
    SettingsDivider()
    if selectedSet?.targetReps != nil {
      Stepper("Reps: \(adjustedReps)", value: $adjustedReps, in: 1 ... 40)
      SettingsDivider()
    }
    HStack {
      Text("Peso")
      Spacer()
      TextField("kg", value: $adjustedWeightKg, format: .number.precision(.fractionLength(0 ... 2)))
        .keyboardType(.decimalPad)
        .multilineTextAlignment(.trailing)
        .frame(width: 96)
      Text("kg").foregroundStyle(Color.gymSecondaryText)
    }
  }

  private func resetExerciseSelection() {
    guard let firstExercise = selectedSession?.exercises.first else {
      selectedExerciseID = ""
      replacementExerciseID = ""
      return
    }
    selectedExerciseID = firstExercise.exerciseID
    replacementExerciseID = replacementExercises.first?.exerciseID ?? ""
    selectedCatalogExerciseID = catalogAdditionCandidates.first?.baseExerciseID ?? ""
    selectedSetIndex = firstExercise.sets.first?.setIndex ?? 1
    syncAdjustmentValues()
  }

  private func syncAdjustmentValues() {
    guard let trainingSet = selectedSet else { return }
    adjustedReps = trainingSet.targetReps ?? adjustedReps
    adjustedWeightKg = trainingSet.targetWeightKg
  }

  private static func date(from value: String) -> Date {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd"
    return Calendar.current.startOfDay(for: formatter.date(from: value) ?? .distantPast)
  }

  private static func isoDate(_ value: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: value)
  }

  private static func dateLabel(_ value: String) -> String {
    date(from: value).formatted(.dateTime.day().month(.abbreviated))
  }
}

private enum ProposalSimulationIntent: String, CaseIterable, Identifiable {
  case move
  case cancel
  case replaceExercise
  case addExercise
  case adjustSet
  case adaptDuration

  var id: String { rawValue }
  var label: String {
    switch self {
    case .move: "Mover sesión"
    case .cancel: "Cancelar sesión"
    case .replaceExercise: "Sustituir ejercicio"
    case .addExercise: "Añadir ejercicio del catálogo"
    case .adjustSet: "Ajustar serie"
    case .adaptDuration: "Adaptar duración"
    }
  }

  var buttonLabel: String { "Crear propuesta: \(label.lowercased())" }

  var symbol: String {
    switch self {
    case .move: "calendar.badge.clock"
    case .cancel: "calendar.badge.minus"
    case .replaceExercise: "arrow.triangle.swap"
    case .addExercise: "plus.rectangle.on.rectangle"
    case .adjustSet: "slider.horizontal.3"
    case .adaptDuration: "clock.arrow.2.circlepath"
    }
  }

  var reason: String { label.lowercased() }
}

private struct ValidationDetailRow: View {
  let title: String
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.gymSupport.weight(.semibold))
        .foregroundStyle(Color.gymSecondaryText)
      Text(value)
        .font(.gymBody.weight(.medium))
        .foregroundStyle(.primary)
    }
  }
}

private enum ScheduleDisplayMode: String, CaseIterable, Identifiable {
  case calendar
  case list

  var id: String { rawValue }
  var label: String { self == .calendar ? "Calendario" : "Lista" }
  var symbol: String { self == .calendar ? "calendar" : "list.bullet" }
}

private struct MacrocycleWeekInfo: Equatable, Identifiable {
  let week: Int
  let focusLabel: String
  let focus: String

  var id: Int { week }

  var tint: Color {
    switch (week - 1) % 6 {
    case 0: .gymAccent
    case 1: .gymTertiary
    case 2: .gymAccentSecondary
    case 3: .gymWarning
    case 4: .gymCompleted
    default: .gymSystemAction
    }
  }
}

private struct MacrocycleWeekSummary: View {
  let week: MacrocycleWeekInfo

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Circle().fill(week.tint).frame(width: 10, height: 10)
      VStack(alignment: .leading, spacing: 2) {
        Text("Semana \(week.week) · \(week.focusLabel)")
          .font(.gymH3.weight(.bold))
        Text(week.focus)
          .font(.gymSupport)
          .foregroundStyle(Color.gymSecondaryText)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background(week.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    .overlay { RoundedRectangle(cornerRadius: 14).stroke(week.tint.opacity(0.28), lineWidth: 1) }
  }
}

private struct TrainingCalendarGrid: View {
  @Binding var displayedMonth: Date
  @Binding var selectedDay: Date?
  let sessionsByDay: [Date: [TrainingSession]]
  let macrocycleWeeksByDay: [Date: MacrocycleWeekInfo]
  let completedSessionIDs: Set<String>
  @Environment(\.colorScheme) private var colorScheme

  private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
  private let calendar = Calendar.current

  var body: some View {
    VStack(spacing: 12) {
      HStack {
        Button { moveMonth(by: -1) } label: {
          Image(systemName: "chevron.left").frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        Spacer()
        Text(Self.monthFormatter.string(from: displayedMonth).capitalized)
          .font(.gymH2.weight(.bold))
        Spacer()
        Button { moveMonth(by: 1) } label: {
          Image(systemName: "chevron.right").frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
      }

      LazyVGrid(columns: columns, spacing: 8) {
        ForEach(["L", "M", "X", "J", "V", "S", "D"], id: \.self) { label in
          Text(label)
            .font(.gymSupport.weight(.bold))
            .foregroundStyle(Color.gymSecondaryText)
            .frame(maxWidth: .infinity)
        }

        ForEach(Array(daysInGrid.enumerated()), id: \.offset) { _, day in
          if let day {
            dayButton(day)
          } else {
            Color.clear.frame(height: 40)
          }
        }
      }
    }
    .padding(14)
    .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 16))
  }

  private var daysInGrid: [Date?] {
    guard let interval = calendar.dateInterval(of: .month, for: displayedMonth),
          let dayCount = calendar.range(of: .day, in: .month, for: displayedMonth)?.count else { return [] }
    let weekday = calendar.component(.weekday, from: interval.start)
    let leadingDays = (weekday + 5) % 7
    return Array(repeating: nil, count: leadingDays) + (0 ..< dayCount).compactMap {
      calendar.date(byAdding: .day, value: $0, to: interval.start)
    }
  }

  private func dayButton(_ day: Date) -> some View {
    let normalized = calendar.startOfDay(for: day)
    let sessions = sessionsByDay[normalized] ?? []
    let isSelected = selectedDay.map { calendar.isDate($0, inSameDayAs: normalized) } ?? false
    let isCompleted = !sessions.isEmpty && sessions.allSatisfy { completedSessionIDs.contains($0.sessionID) }
    let isToday = calendar.isDateInToday(normalized)
    let macrocycleWeek = macrocycleWeeksByDay[normalized]
    return Button { selectedDay = normalized } label: {
      Text("\(calendar.component(.day, from: day))")
        .font(.gymSupport.weight(isSelected || isToday ? .bold : .medium))
      .frame(maxWidth: .infinity, minHeight: 40)
      .foregroundStyle(isSelected ? Color.gymAccentForeground : .primary)
      .background(dayFill(hasSession: !sessions.isEmpty, isCompleted: isCompleted, isToday: isToday, isSelected: isSelected), in: RoundedRectangle(cornerRadius: 12))
      .overlay {
        RoundedRectangle(cornerRadius: 12)
          .stroke(isToday && !isSelected ? Color.gymAccent : .clear, lineWidth: 1.5)
      }
      .overlay(alignment: .bottom) {
        if let macrocycleWeek, !isSelected {
          Capsule()
            .fill(macrocycleWeek.tint)
            .frame(height: 3)
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
        }
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Self.dayFormatter.string(from: day))
  }

  private func dayFill(hasSession: Bool, isCompleted: Bool, isToday: Bool, isSelected: Bool) -> Color {
    if isSelected { return Color.gymAccent }
    if isToday { return Color.gymTertiary.opacity(0.24) }
    if isCompleted {
      return colorScheme == .dark
        ? Color(red: 0.16, green: 0.72, blue: 0.39).opacity(0.62)
        : Color.gymCompleted.opacity(0.28)
    }
    if hasSession { return Color.gymAccent.opacity(0.18) }
    return .clear
  }

  private func moveMonth(by offset: Int) {
    displayedMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonth) ?? displayedMonth
  }

  private static let monthFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "es_ES")
    formatter.dateFormat = "LLLL yyyy"
    return formatter
  }()

  private static let dayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "es_ES")
    formatter.dateStyle = .long
    return formatter
  }()
}

private struct PlanningSessionCard: View {
  let session: TrainingSession
  let record: CompletedWorkoutRecord?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      WeekSessionCard(
        session: session,
        isRecommended: false,
        isInProgress: false,
        isCompleted: record != nil
      )

      if let record {
        HStack(spacing: 10) {
          NavigationLink {
            CompletedWorkoutDetailView(record: record)
          } label: {
            Label("Corregir series", systemImage: "pencil")
              .frame(maxWidth: .infinity, minHeight: 44)
          }
          .buttonStyle(.bordered)

          if let csvURL = Self.csvURL(for: record) {
            ShareLink(item: csvURL) {
              Label("Exportar", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
          }
        }
      } else {
        NavigationLink {
          SessionPreviewView(session: session, onReturnHome: {}, readOnly: true)
        } label: {
          Label("Ver previsualización", systemImage: "play.circle")
            .font(.gymBody.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private static func csvURL(for record: CompletedWorkoutRecord) -> URL? {
    guard let data = record.executionData,
          let execution = try? JSONDecoder().decode(WorkoutExecutionState.self, from: data) else { return nil }
    let decisions = record.decisionsData.flatMap { try? JSONDecoder().decode([String: String].self, from: $0) } ?? [:]
    return try? WorkoutCSVExporter.write(session: execution.session, execution: execution, exerciseDecisions: decisions)
  }
}

private struct ExportSettingsView: View {
  let plan: TrainingPlan
  @Query private var completedRecords: [CompletedWorkoutRecord]
  @Query private var activeRecords: [ActiveWorkoutRecord]
  @AppStorage("appearanceTheme") private var appearanceTheme = AppAppearance.system.rawValue
  @AppStorage("themeAccent") private var accentTheme = ThemeAccent.blue.rawValue
  @AppStorage("keepScreenAwake") private var keepScreenAwake = false
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @State private var showsDeleteConfirmation = false
  @State private var showsDiscardActiveConfirmation = false
  @State private var recordPendingDeletion: CompletedWorkoutRecord?
  @State private var showsImporter = false
  @State private var importMessage: String?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        ShareLink(item: backupURL()) {
          Label("Exportar backup JSON", systemImage: "archivebox")
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .foregroundStyle(Color.gymAccent)
        .background(Color.gymSurface, in: Capsule())
        .overlay {
          Capsule().stroke(Color.gymAccent, lineWidth: 1.5)
        }

        Button {
          showsImporter = true
        } label: {
          Label("Importar backup JSON", systemImage: "square.and.arrow.down")
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .foregroundStyle(Color.gymAccent)
        .background(Color.gymSurface, in: Capsule())
        .overlay {
          Capsule().stroke(Color.gymAccent, lineWidth: 1.5)
        }

        if !activeRecords.isEmpty {
          Button("Descartar entrenamiento en curso", role: .destructive) {
            showsDiscardActiveConfirmation = true
          }
          .frame(maxWidth: .infinity, minHeight: 56)
          .buttonStyle(.bordered)
          .tint(Color.gymDanger)
        }

        Button("Borrar todos los datos locales", role: .destructive) {
          showsDeleteConfirmation = true
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .buttonStyle(.bordered)
        .tint(Color.gymDanger)

        Text("Sesiones guardadas: \(completedRecords.count)")
          .font(.gymH2)
          .padding(.top, 8)
        Text("El backup JSON conserva todas las sesiones. El CSV se puede regenerar para sesiones con registro nativo detallado.")
          .font(.gymBody)
          .foregroundStyle(Color.gymSecondaryText)

        ForEach(completedRecords.sorted { $0.completedAt > $1.completedAt }) { record in
          SavedWorkoutCard(
            record: record,
            date: sessionDetails(for: record).date,
            label: sessionDetails(for: record).label,
            csvURL: csvURL(for: record),
            deleteAction: { recordPendingDeletion = record }
          )
        }

      }
      .padding(16)
    }
    .background(GymCanvas())
    .navigationBarBackButtonHidden()
    .toolbar(.hidden, for: .navigationBar)
    .safeAreaInset(edge: .top, spacing: 0) { AccentHeaderCard(title: "Exportación") }
    .overlay(alignment: .bottomLeading) { BottomBackButton(action: { dismiss() }) }
    .alert("Borrar datos locales", isPresented: $showsDeleteConfirmation) {
      Button("Cancelar", role: .cancel) {}
      Button("Borrar", role: .destructive, action: clearLocalData)
    } message: {
      Text("Se eliminarán los entrenamientos en curso y las sesiones nativas guardadas.")
    }
    .alert("Descartar entrenamiento en curso", isPresented: $showsDiscardActiveConfirmation) {
      Button("Cancelar", role: .cancel) {}
      Button("Descartar", role: .destructive, action: discardActiveWorkout)
    } message: {
      Text("Se borrará únicamente el entrenamiento en curso. Las sesiones terminadas e importadas se conservarán.")
    }
    .alert(
      "Borrar entrenamiento guardado",
      isPresented: Binding(
        get: { recordPendingDeletion != nil },
        set: { if !$0 { recordPendingDeletion = nil } }
      ),
      presenting: recordPendingDeletion
    ) { record in
      Button("Cancelar", role: .cancel) {
        recordPendingDeletion = nil
      }
      Button("Borrar", role: .destructive) {
        delete(record)
      }
    } message: { record in
      Text("Se eliminará \(sessionDetails(for: record).label) de los datos locales.")
    }
    .alert("Importación", isPresented: Binding(
      get: { importMessage != nil },
      set: { if !$0 { importMessage = nil } }
    )) {
      Button("Aceptar", role: .cancel) { importMessage = nil }
    } message: {
      Text(importMessage ?? "")
    }
    .fileImporter(isPresented: $showsImporter, allowedContentTypes: [.json]) { result in
      importBackup(result)
    }
  }

  private func csvURL(for record: CompletedWorkoutRecord) -> URL? {
    guard let data = record.executionData,
          let execution = try? JSONDecoder().decode(WorkoutExecutionState.self, from: data),
          let url = try? WorkoutCSVExporter.write(
            session: execution.session,
            execution: execution,
            exerciseDecisions: decodedDecisions(record)
          )
    else { return nil }
    return url
  }

  private func sessionDetails(for record: CompletedWorkoutRecord) -> (date: String, label: String) {
    if let data = record.executionData,
       let execution = try? JSONDecoder().decode(WorkoutExecutionState.self, from: data) {
      return (trainingDateLabel(execution.session.date), execution.session.sessionLabel)
    }

    if let data = record.importedSessionData,
       let session = try? JSONDecoder().decode(TrainingBackup.Session.self, from: data) {
      return (
        trainingDateLabel(session.sessionDate ?? session.summary?.sessionDate ?? ""),
        session.sessionLabel ?? session.summary?.sessionLabel ?? record.sessionID
      )
    }

    return (record.completedAt.formatted(.dateTime.day().month(.abbreviated).year()), record.sessionID)
  }

  private func trainingDateLabel(_ value: String) -> String {
    let input = DateFormatter()
    input.locale = Locale(identifier: "en_US_POSIX")
    input.dateFormat = "yyyy-MM-dd"

    guard let date = input.date(from: value) else { return value }
    return date.formatted(.dateTime.day().month(.abbreviated).year())
  }

  private func backupURL() -> URL {
    (try? TrainingBackup.write(
      plan: plan,
      appearanceTheme: appearanceTheme,
      accentTheme: accentTheme,
      keepScreenAwake: keepScreenAwake,
      activeWorkout: ActiveWorkoutStore.load(from: activeRecords),
      completedRecords: completedRecords,
      appVersion: "0.1.103"
    )) ?? FileManager.default.temporaryDirectory.appendingPathComponent("gymapp-full-training-backup.json")
  }

  private func decodedDecisions(_ record: CompletedWorkoutRecord) -> [String: String] {
    guard let data = record.decisionsData else { return [:] }
    return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
  }

  private func clearLocalData() {
    ActiveWorkoutStore.clear(in: modelContext)
    completedRecords.forEach(modelContext.delete)
    try? modelContext.save()
  }

  private func delete(_ record: CompletedWorkoutRecord) {
    modelContext.delete(record)
    try? modelContext.save()
    recordPendingDeletion = nil
  }

  private func discardActiveWorkout() {
    ActiveWorkoutStore.clear(in: modelContext)
  }

  private func importBackup(_ result: Result<URL, Error>) {
    do {
      let url = try result.get()
      guard url.startAccessingSecurityScopedResource() else {
        throw TrainingBackup.BackupError.noFilePermission
      }
      defer { url.stopAccessingSecurityScopedResource() }
      let data = try Data(contentsOf: url)
      let result = try TrainingBackup.importBackup(data, into: modelContext)
      importMessage = "Importadas: \(result.imported). Ya existentes: \(result.duplicates)."
    } catch {
      importMessage = error.localizedDescription
    }
  }
}

private struct SavedWorkoutCard: View {
  let record: CompletedWorkoutRecord
  let date: String
  let label: String
  let csvURL: URL?
  let deleteAction: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(date)
          .font(.gymSupport.weight(.semibold))
          .foregroundStyle(Color.gymSecondaryText)
        Text(label)
          .font(.gymH2.weight(.bold))
          .lineLimit(1)
      }

      HStack(spacing: 10) {
        if record.executionData != nil {
          NavigationLink {
            CompletedWorkoutDetailView(record: record)
          } label: {
            Label("Corregir series", systemImage: "pencil")
          }
          .buttonStyle(.bordered)
          .tint(Color.gymAccent)
        }

        if let csvURL {
          ShareLink(item: csvURL) {
            Label("Exportar CSV", systemImage: "square.and.arrow.up")
          }
          .buttonStyle(.bordered)
          .tint(Color.gymAccent)
        } else {
          Text("Registro sin detalle. Solo las sesiones finalizadas desde v0.1.71 pueden reexportarse.")
            .font(.gymSupport)
            .foregroundStyle(Color.gymSecondaryText)
        }

        Spacer(minLength: 0)

        Button("Borrar", role: .destructive, action: deleteAction)
          .buttonStyle(.bordered)
          .tint(Color.gymDanger)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 18))
    .overlay {
      RoundedRectangle(cornerRadius: 18)
        .stroke(Color.gymAccent, lineWidth: 1.5)
    }
  }
}

struct BottomBackButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "chevron.left")
        .font(.gymH2.weight(.bold))
        .frame(width: 56, height: 56)
        .foregroundStyle(.primary)
        .glassEffect(.regular.interactive(), in: Circle())
    }
    .accessibilityLabel("Atrás")
    .buttonStyle(.plain)
    .padding(.leading, 20)
    .padding(.bottom, 8)
  }
}
