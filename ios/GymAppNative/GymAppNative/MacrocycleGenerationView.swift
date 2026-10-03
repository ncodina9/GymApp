import SwiftUI
import SwiftData
import GymAppNativeCore

struct MacrocycleGenerationView: View {
  private struct PreviewWeek: Identifiable {
    let week: Int
    let focusLabel: String
    let focus: String
    let sessions: [TrainingSession]

    var id: Int { week }
  }

  let previousPlan: TrainingPlan
  @Query private var profileRecords: [TrainingProfileRecord]
  @Query private var generatedPlanRecords: [GeneratedMacrocycleRecord]
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @State private var durationWeeks = 12
  @State private var goal: TrainingGoal = .strength
  @State private var objective = ""
  @State private var previewPlan: TrainingPlan?
  @State private var showsConfirmation = false
  @State private var message: String?

  private var profile: TrainingProfile {
    TrainingProfileStore.load(from: profileRecords) ?? .initial
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("El ciclo anterior permanece en tu historial. El generador crea cada semana a partir del catálogo, la fase, tu disponibilidad, material y duración de sesión actuales; podrás revisar el resultado antes de activarlo.")
          .font(.gymBody)
          .foregroundStyle(Color.gymSecondaryText)

        SettingsCategory(title: "Nuevo objetivo") {
          VStack(alignment: .leading, spacing: 14) {
            Picker("Objetivo principal", selection: $goal) {
              ForEach(TrainingGoal.allCases) { goal in
                Text(goal.label).tag(goal)
              }
            }
            Stepper("Duración: \(durationWeeks) semanas", value: $durationWeeks, in: 4...24, step: 1)
              .font(.gymBody.weight(.semibold))
            VStack(alignment: .leading, spacing: 6) {
              Text("Objetivo concreto")
                .font(.gymH3.weight(.bold))
              TextField("Ej. mejorar la sentadilla sin irritar la rodilla", text: $objective, axis: .vertical)
                .font(.gymBody)
                .lineLimit(2...4)
                .padding(12)
                .background(Color.gymCanvas, in: RoundedRectangle(cornerRadius: 12))
            }
          }
          .padding(16)
        }

        SettingsCategory(title: "Base reutilizada") {
          VStack(alignment: .leading, spacing: 8) {
            Label("\(profile.trainingWeekdays.count) días disponibles por semana", systemImage: "calendar")
            Label("Sesiones de hasta \(profile.sessionDurationMinutes) min", systemImage: "clock")
            Label("Material y preferencias actuales del perfil", systemImage: "dumbbell")
          }
          .font(.gymBody)
          .foregroundStyle(Color.gymSecondaryText)
          .padding(16)
        }

        Button(action: generatePreview) {
          Label(previewPlan == nil ? "Generar vista previa" : "Actualizar vista previa", systemImage: "calendar.badge.plus")
            .font(.gymBody.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .foregroundStyle(Color.gymAccentForeground)
        .background(Color.gymAccent, in: RoundedRectangle(cornerRadius: 14))
        .buttonStyle(.plain)

        if let previewPlan {
          SettingsCategory(title: "Vista previa del macrociclo") {
            VStack(alignment: .leading, spacing: 14) {
              Text("\(previewPlan.durationWeeks) semanas · \(previewPlan.sessions.count) sesiones · inicio \(previewPlan.startsOn)")
                .font(.gymBody.weight(.semibold))
              Text("La acumulación rota alternativas compatibles del catálogo; la intensificación conserva más continuidad para medir progresión; la descarga reduce volumen.")
                .font(.gymSupport)
                .foregroundStyle(Color.gymSecondaryText)
              ForEach(previewWeeks) { week in
                VStack(alignment: .leading, spacing: 8) {
                  Text("S\(week.week) · \(week.focusLabel)")
                    .font(.gymH3.weight(.bold))
                    .foregroundStyle(Color.gymAccent)
                  Text(week.focus)
                    .font(.gymBody)
                    .foregroundStyle(Color.gymSecondaryText)
                  ForEach(week.sessions) { session in
                    VStack(alignment: .leading, spacing: 4) {
                      Text("\(session.weekday.capitalized) · \(session.sessionLabel)")
                        .font(.gymBody.weight(.semibold))
                      Text(session.exercises.map(\.displayName).joined(separator: " · "))
                        .font(.gymSupport)
                        .foregroundStyle(Color.gymSecondaryText)
                        .lineLimit(2)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gymCanvas, in: RoundedRectangle(cornerRadius: 12))
                  }
                }
                if week.week != previewWeeks.last?.week { SettingsDivider() }
              }
              Button { showsConfirmation = true } label: {
                Label("Activar nuevo macrociclo", systemImage: "checkmark.circle")
                  .font(.gymBody.weight(.semibold))
                  .frame(maxWidth: .infinity, minHeight: 52)
              }
              .foregroundStyle(Color.gymAccentForeground)
              .background(Color.gymAccent, in: RoundedRectangle(cornerRadius: 14))
              .buttonStyle(.plain)
            }
            .padding(16)
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
      AccentHeaderCard(title: "Nuevo macrociclo", detail: "Objetivo, duración y base del plan")
    }
    .overlay(alignment: .bottomLeading) { BottomBackButton(action: { dismiss() }) }
    .onAppear {
      durationWeeks = min(max(profile.targetTimeframeWeeks, 4), 24)
      goal = profile.goal
    }
    .onChange(of: durationWeeks) { _, _ in previewPlan = nil }
    .onChange(of: goal) { _, _ in previewPlan = nil }
    .onChange(of: objective) { _, _ in previewPlan = nil }
    .confirmationDialog("Generar nuevo macrociclo", isPresented: $showsConfirmation, titleVisibility: .visible) {
      Button("Generar y activar") { generate() }
      Button("Cancelar", role: .cancel) {}
    } message: {
      Text("Activarás el macrociclo que acabas de revisar. El plan anterior y sus sesiones completadas permanecerán en el historial.")
    }
    .alert("Nuevo macrociclo", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
      Button("Aceptar", role: .cancel) { message = nil }
    } message: {
      Text(message ?? "")
    }
  }

  private var previewWeeks: [PreviewWeek] {
    guard let previewPlan else { return [] }
    let grouped = Dictionary(grouping: previewPlan.sessions, by: \.week)
    return grouped.keys
      .sorted()
      .compactMap { week in
        guard let sessions = grouped[week],
              let first = sessions.first else { return nil }
        return PreviewWeek(
          week: week,
          focusLabel: first.weekFocusLabel,
          focus: first.weekFocus,
          sessions: sessions.sorted { $0.date < $1.date }
        )
      }
  }

  private func generatePreview() {
    let request = MacrocycleGenerationRequest(
      durationWeeks: durationWeeks,
      goal: goal,
      objective: objective
    )
    guard let plan = MacrocycleGenerator.generate(from: previousPlan, profile: profile, request: request) else {
      message = "No hay una semana final compatible con tu disponibilidad actual para usar como base. Revisa el perfil antes de generar el ciclo."
      return
    }
    previewPlan = plan
  }

  private func generate() {
    guard let previewPlan else { return }
    do {
      try ActiveTrainingPlanStore.activate(
        previewPlan,
        sourcePlanID: previousPlan.planID,
        records: generatedPlanRecords,
        in: modelContext
      )
      dismiss()
    } catch {
      message = error.localizedDescription
    }
  }
}
