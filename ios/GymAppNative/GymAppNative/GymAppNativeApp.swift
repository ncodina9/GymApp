import SwiftUI
import SwiftData

@main
struct GymAppNativeApp: App {
  @AppStorage("appearanceTheme") private var appearanceRaw = AppAppearance.system.rawValue
  @AppStorage("keepScreenAwake") private var keepScreenAwake = false

  var body: some Scene {
    WindowGroup {
      ContentView()
        .preferredColorScheme(AppAppearance(rawValue: appearanceRaw)?.colorScheme)
        .tint(.gymAccent)
        .background(Color.gymCanvas)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = keepScreenAwake }
        .onChange(of: keepScreenAwake) { _, enabled in
          UIApplication.shared.isIdleTimerDisabled = enabled
        }
    }
    .modelContainer(for: [ActiveWorkoutRecord.self, CompletedWorkoutRecord.self])
  }
}
