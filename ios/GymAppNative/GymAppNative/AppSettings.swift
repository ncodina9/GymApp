import SwiftUI
import SwiftData
import UIKit
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
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        SettingsLink(title: "Apariencia", detail: "Tema y pantalla activa", destination: AppearanceSettingsView())
        SettingsLink(title: "Próximos entrenamientos", detail: "Consulta del plan pendiente", destination: UpcomingWorkoutsView(plan: plan))
        SettingsLink(title: "Exportación", detail: "Backup, CSV y datos locales", destination: ExportSettingsView(plan: plan))
      }
      .padding(16)
    }
    .navigationBarBackButtonHidden()
    .toolbar { NavigationHeader(title: "Opciones") }
    .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    .toolbarBackground(.visible, for: .navigationBar)
    .overlay(alignment: .bottomLeading) { BottomBackButton(action: { dismiss() }) }
  }
}

private struct SettingsLink<Destination: View>: View {
  let title: String
  let detail: String
  let destination: Destination

  var body: some View {
    NavigationLink { destination } label: {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(title).font(.headline.weight(.bold))
          Text(detail).font(.subheadline).foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: "chevron.right").foregroundStyle(.secondary)
      }
      .padding(16)
      .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 20))
    }
    .buttonStyle(.plain)
  }
}

private struct AppearanceSettingsView: View {
  @AppStorage("appearanceTheme") private var appearanceRaw = AppAppearance.system.rawValue
  @AppStorage("keepScreenAwake") private var keepScreenAwake = false

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Picker("Tema", selection: $appearanceRaw) {
        ForEach(AppAppearance.allCases) { appearance in
          Text(appearance.label).tag(appearance.rawValue)
        }
      }
      .pickerStyle(.segmented)

      Toggle("Mantener la pantalla activa", isOn: $keepScreenAwake)
        .tint(.accentColor)
      Spacer()
    }
    .padding(16)
    .navigationTitle("Apariencia")
  }
}

private struct UpcomingWorkoutsView: View {
  let plan: TrainingPlan
  @Query private var completedRecords: [CompletedWorkoutRecord]
  @Environment(\.dismiss) private var dismiss

  private var upcomingSessions: [TrainingSession] {
    let completed = Set(completedRecords.map(\.sessionID))
    let today = Self.todayISODate
    return plan.sessions.filter { $0.date >= today && !completed.contains($0.sessionID) }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("Próximos entrenamientos")
          .font(.system(size: 27, weight: .bold))
          .frame(maxWidth: .infinity, alignment: .leading)

        LazyVStack(spacing: 12) {
          ForEach(upcomingSessions) { session in
            NavigationLink {
              SessionPreviewView(session: session, activeWorkout: nil, onReturnHome: {}, readOnly: true)
            } label: {
              WeekSessionCard(session: session, isRecommended: false, isInProgress: false, isCompleted: false)
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding(16)
      .padding(.bottom, 88)
    }
    .navigationBarBackButtonHidden()
    .toolbar { NavigationHeader(title: "Próximos entrenamientos") }
    .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    .toolbarBackground(.visible, for: .navigationBar)
    .overlay(alignment: .bottomLeading) { BottomBackButton(action: { dismiss() }) }
  }

  private static var todayISODate: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: .now)
  }
}

private struct ExportSettingsView: View {
  let plan: TrainingPlan
  @Query private var completedRecords: [CompletedWorkoutRecord]
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @State private var showsDeleteConfirmation = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Text("Sesiones guardadas: \(completedRecords.count)")
          .font(.headline)
        Text("Los exports incluyen solo sesiones nativas que conservan su registro detallado.")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        ForEach(completedRecords.sorted { $0.completedAt > $1.completedAt }) { record in
          if let url = csvURL(for: record) {
            ShareLink(item: url) {
              Label(csvLabel(for: record), systemImage: "square.and.arrow.up")
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(.white)
            .glassEffect(.regular.tint(.accentColor).interactive(), in: Capsule())
          } else {
            VStack(alignment: .leading, spacing: 4) {
              Text(csvLabel(for: record))
                .font(.headline.weight(.bold))
              Text("Registro sin detalle. Solo las sesiones finalizadas desde v0.1.71 pueden reexportarse.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 18))
          }
        }

        ShareLink(item: backupURL()) {
          Label("Exportar backup JSON", systemImage: "archivebox")
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .foregroundStyle(.white)
        .glassEffect(.regular.tint(.accentColor).interactive(), in: Capsule())

        Button("Borrar todos los datos locales", role: .destructive) {
          showsDeleteConfirmation = true
        }
        .frame(maxWidth: .infinity, minHeight: 56)
      }
      .padding(16)
    }
    .navigationBarBackButtonHidden()
    .toolbar { NavigationHeader(title: "Exportación") }
    .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    .toolbarBackground(.visible, for: .navigationBar)
    .overlay(alignment: .bottomLeading) { BottomBackButton(action: { dismiss() }) }
    .alert("Borrar datos locales", isPresented: $showsDeleteConfirmation) {
      Button("Cancelar", role: .cancel) {}
      Button("Borrar", role: .destructive, action: clearLocalData)
    } message: {
      Text("Se eliminarán los entrenamientos en curso y las sesiones nativas guardadas.")
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

  private func csvLabel(for record: CompletedWorkoutRecord) -> String {
    guard let data = record.executionData,
          let execution = try? JSONDecoder().decode(WorkoutExecutionState.self, from: data)
    else { return "CSV · \(record.sessionID)" }
    return "Exportar CSV · \(execution.session.sessionLabel)"
  }

  private func backupURL() -> URL {
    let payload: [String: Any] = [
      "schemaName": "gymapp.full-training-data-export",
      "schemaVersion": 1,
      "exportedAt": ISO8601DateFormatter().string(from: .now),
      "app": ["name": "GymAppNative", "version": "0.1.70"],
      "source": ["platform": "ios", "localStores": ["SwiftData:completedWorkouts"]],
      "plan": (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(plan))) ?? [:],
      "sessions": completedRecords.compactMap { record -> [String: Any]? in
        guard let data = record.executionData else { return nil }
        return [
          "sessionId": record.sessionID,
          "startedAt": record.startedAt.map { ISO8601DateFormatter().string(from: $0) } ?? NSNull(),
          "finishedAt": ISO8601DateFormatter().string(from: record.completedAt),
          "execution": (try? JSONSerialization.jsonObject(with: data)) ?? [:],
          "decisions": decodedDecisions(record)
        ] as [String: Any]
      }
    ]
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("gymapp-native-backup.json")
    let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    try? data?.write(to: url, options: .atomic)
    return url
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
}

private struct NavigationHeader: ToolbarContent {
  let title: String

  var body: some ToolbarContent {
    ToolbarItem(placement: .principal) {
      Text(title)
        .font(.system(size: 20, weight: .bold))
        .lineLimit(1)
    }
  }
}

private struct BottomBackButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "chevron.left")
        .font(.headline.weight(.bold))
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
