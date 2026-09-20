import SwiftUI
import SwiftData

@main
struct GymAppNativeApp: App {
  @AppStorage("appearanceTheme") private var appearanceRaw = AppAppearance.system.rawValue
  @AppStorage("lightPalette") private var lightPaletteRaw = LightPalette.white.rawValue
  @AppStorage("darkPalette") private var darkPaletteRaw = DarkPalette.dark.rawValue
  @AppStorage("keepScreenAwake") private var keepScreenAwake = false
  @State private var themeRevision = 0

  private var appearance: AppAppearance {
    AppAppearance(rawValue: appearanceRaw) ?? .system
  }

  private var lightPalette: LightPalette {
    LightPalette(rawValue: lightPaletteRaw) ?? .white
  }

  private var darkPalette: DarkPalette {
    DarkPalette(rawValue: darkPaletteRaw) ?? .dark
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .id(themeRevision)
        .preferredColorScheme(appearance.colorScheme)
        .tint(.gymAccent)
        .background(GymCanvas())
        .onAppear(perform: applyTheme)
        .onChange(of: appearanceRaw) { _, _ in applyTheme() }
        .onChange(of: lightPaletteRaw) { _, _ in applyTheme() }
        .onChange(of: darkPaletteRaw) { _, _ in applyTheme() }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = keepScreenAwake }
        .onChange(of: keepScreenAwake) { _, enabled in
          UIApplication.shared.isIdleTimerDisabled = enabled
        }
    }
    .modelContainer(for: [ActiveWorkoutRecord.self, CompletedWorkoutRecord.self])
  }

  private func applyTheme() {
    GymTheme.apply(appearance: appearance, lightPalette: lightPalette, darkPalette: darkPalette)
    themeRevision += 1
  }
}
