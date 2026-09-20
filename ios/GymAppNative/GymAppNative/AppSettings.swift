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
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        SettingsLink(title: "Apariencia", detail: "Tema y pantalla activa", destination: AppearanceSettingsView())
        SettingsLink(title: "Próximos entrenamientos", detail: "Consulta del plan pendiente", destination: UpcomingWorkoutsView(plan: plan))
        SettingsLink(title: "Exportación", detail: "Backup, CSV y datos locales", destination: ExportSettingsView(plan: plan))
        Text("v0.1.81")
          .font(.caption2.weight(.medium))
          .foregroundStyle(.tertiary)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.top, 8)
      }
      .padding(16)
    }
    .background(GymCanvas())
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
      .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 20))
    }
    .buttonStyle(.plain)
  }
}

private struct AppearanceSettingsView: View {
  @AppStorage("appearanceTheme") private var appearanceRaw = AppAppearance.system.rawValue
  @AppStorage("lightPalette") private var lightPaletteRaw = LightPalette.white.rawValue
  @AppStorage("darkPalette") private var darkPaletteRaw = DarkPalette.dark.rawValue
  @AppStorage("keepScreenAwake") private var keepScreenAwake = false
  @Environment(\.dismiss) private var dismiss

  private var appearance: AppAppearance {
    AppAppearance(rawValue: appearanceRaw) ?? .system
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        AppearanceSegmentedSelector(selection: $appearanceRaw)

        if appearance == .system || appearance == .light {
          ThemeVariantSection(
            title: appearance == .system ? "Claro" : "Variante clara",
            selection: $lightPaletteRaw,
            options: LightPalette.allCases.map(\.rawValue),
            label: { LightPalette(rawValue: $0)?.label ?? $0 }
          )
        }

        if appearance == .system || appearance == .dark {
          ThemeVariantSection(
            title: appearance == .system ? "Oscuro" : "Variante oscura",
            selection: $darkPaletteRaw,
            options: DarkPalette.allCases.map(\.rawValue),
            label: { DarkPalette(rawValue: $0)?.label ?? $0 }
          )
        }

        Toggle("Mantener la pantalla activa", isOn: $keepScreenAwake)
          .tint(Color.gymAccent)
      }
      .padding(16)
      .padding(.bottom, 88)
    }
    .background(GymCanvas())
    .navigationBarBackButtonHidden()
    .toolbar { NavigationHeader(title: "Apariencia") }
    .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    .toolbarBackground(.visible, for: .navigationBar)
    .overlay(alignment: .bottomLeading) { BottomBackButton(action: { dismiss() }) }
  }
}

private struct ThemeVariantSection: View {
  let title: String
  @Binding var selection: String
  let options: [String]
  let label: (String) -> String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
      GlassSegmentedSelector(
        selection: $selection,
        options: options,
        unavailableOptions: [],
        label: label
      )
    }
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
    .background(GymCanvas())
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
  @Query private var activeRecords: [ActiveWorkoutRecord]
  @AppStorage("appearanceTheme") private var appearanceTheme = AppAppearance.system.rawValue
  @AppStorage("keepScreenAwake") private var keepScreenAwake = false
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @State private var showsDeleteConfirmation = false
  @State private var showsImporter = false
  @State private var importMessage: String?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Text("Sesiones guardadas: \(completedRecords.count)")
          .font(.headline)
        Text("El backup JSON conserva todas las sesiones. El CSV se puede regenerar para sesiones con registro nativo detallado.")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        ForEach(completedRecords.sorted { $0.completedAt > $1.completedAt }) { record in
          if let url = csvURL(for: record) {
            ShareLink(item: url) {
              Label(csvLabel(for: record), systemImage: "square.and.arrow.up")
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(.white)
            .glassEffect(.regular.tint(Color.gymAccent).interactive(), in: Capsule())
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
            .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 18))
          }
        }

        ShareLink(item: backupURL()) {
          Label("Exportar backup JSON", systemImage: "archivebox")
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .foregroundStyle(.white)
        .glassEffect(.regular.tint(Color.gymAccent).interactive(), in: Capsule())

        Button {
          showsImporter = true
        } label: {
          Label("Importar backup JSON", systemImage: "square.and.arrow.down")
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .foregroundStyle(.white)
        .glassEffect(.regular.tint(Color.gymAccent).interactive(), in: Capsule())

        Button("Borrar todos los datos locales", role: .destructive) {
          showsDeleteConfirmation = true
        }
        .frame(maxWidth: .infinity, minHeight: 56)
      }
      .padding(16)
    }
    .background(GymCanvas())
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

  private func csvLabel(for record: CompletedWorkoutRecord) -> String {
    guard let data = record.executionData,
          let execution = try? JSONDecoder().decode(WorkoutExecutionState.self, from: data)
    else { return "CSV · \(record.sessionID)" }
    return "Exportar CSV · \(execution.session.sessionLabel)"
  }

  private func backupURL() -> URL {
    (try? TrainingBackup.write(
      plan: plan,
      appearanceTheme: appearanceTheme,
      keepScreenAwake: keepScreenAwake,
      activeWorkout: ActiveWorkoutStore.load(from: activeRecords),
      completedRecords: completedRecords,
      appVersion: "0.1.81"
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
