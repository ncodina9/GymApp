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
  @AppStorage("appearanceTheme") private var appearanceRaw = AppAppearance.system.rawValue
  @AppStorage("themeAccent") private var accentRaw = ThemeAccent.blue.rawValue
  @AppStorage("premiumColorScheme") private var premiumSchemeRaw = ""
  @Environment(\.dismiss) private var dismiss

  private var themeKey: String {
    "\(appearanceRaw)-\(accentRaw)-\(premiumSchemeRaw)"
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        SettingsCategory(title: "Entrenamiento") {
          SettingsRow(
            title: "Próximos entrenamientos",
            detail: "Consulta del plan pendiente",
            destination: UpcomingWorkoutsView(plan: plan)
          )
        }

        SettingsCategory(title: "Personalización") {
          SettingsRow(
            title: "Apariencia",
            detail: "Tema, color y pantalla activa",
            destination: AppearanceSettingsView()
          )
        }

        SettingsCategory(title: "Datos locales") {
          SettingsRow(
            title: "Exportación",
            detail: "Backup, CSV y datos locales",
            destination: ExportSettingsView(plan: plan)
          )
        }

        Text("v0.1.104")
          .font(.caption2.weight(.medium))
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

private struct SettingsCategory<Content: View>: View {
  let title: String
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.subheadline.weight(.semibold))
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

  var body: some View {
    NavigationLink { destination } label: {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(title).font(.headline.weight(.bold))
          Text(detail).font(.subheadline).foregroundStyle(Color.gymSecondaryText)
        }
        Spacer()
        Image(systemName: "chevron.right").foregroundStyle(Color.gymSecondaryText)
      }
      .padding(16)
      .frame(maxWidth: .infinity)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
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

private struct ThemeToggleStyle: ToggleStyle {
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
        .font(.subheadline.weight(.semibold))
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
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Color.gymSecondaryText)

      Text("El fondo y el resalte se invierten entre la apariencia clara y la oscura.")
        .font(.caption)
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
            .font(.headline.weight(.bold))
          Text(isSelected ? "Seleccionado" : "Fondo y resalte adaptativos")
            .font(.caption.weight(.medium))
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
            .font(.headline.weight(.bold))
            .foregroundStyle(.primary)
          Text(isSelected ? "Seleccionado" : "Color de interfaz")
            .font(.caption.weight(.medium))
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
    .toolbar(.hidden, for: .navigationBar)
    .safeAreaInset(edge: .top, spacing: 0) { AccentHeaderCard(title: "Próximos entrenamientos") }
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
          .font(.headline)
          .padding(.top, 8)
        Text("El backup JSON conserva todas las sesiones. El CSV se puede regenerar para sesiones con registro nativo detallado.")
          .font(.subheadline)
          .foregroundStyle(Color.gymSecondaryText)

        ForEach(completedRecords.sorted { $0.completedAt > $1.completedAt }) { record in
          SavedWorkoutCard(
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
  let date: String
  let label: String
  let csvURL: URL?
  let deleteAction: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(date)
          .font(.caption.weight(.semibold))
          .foregroundStyle(Color.gymSecondaryText)
        Text(label)
          .font(.headline.weight(.bold))
          .lineLimit(1)
      }

      HStack(spacing: 10) {
        if let csvURL {
          ShareLink(item: csvURL) {
            Label("Exportar CSV", systemImage: "square.and.arrow.up")
          }
          .buttonStyle(.bordered)
          .tint(Color.gymAccent)
        } else {
          Text("Registro sin detalle. Solo las sesiones finalizadas desde v0.1.71 pueden reexportarse.")
            .font(.caption)
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
