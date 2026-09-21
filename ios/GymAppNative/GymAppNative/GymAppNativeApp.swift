import SwiftUI
import SwiftData

@main
struct GymAppNativeApp: App {
  @AppStorage("appearanceTheme") private var appearanceRaw = AppAppearance.system.rawValue
  @AppStorage("themeAccent") private var accentRaw = ThemeAccent.blue.rawValue
  @AppStorage("keepScreenAwake") private var keepScreenAwake = false

  private var appearance: AppAppearance {
    AppAppearance(rawValue: appearanceRaw) ?? .system
  }

  private var accent: ThemeAccent {
    ThemeAccent(rawValue: accentRaw) ?? .blue
  }

  var body: some Scene {
    WindowGroup {
      ZStack {
        SafeAreaCanvas(color: .gymCanvas)
        ContentView()
      }
        .preferredColorScheme(appearance.colorScheme)
        .background(Color.gymCanvas, ignoresSafeAreaEdges: .all)
        .toolbarBackground(.hidden, for: .statusBar)
        .toolbarColorScheme(.dark, for: .statusBar)
        .tint(.gymAccent)
        .onAppear(perform: applyTheme)
        .onChange(of: appearanceRaw) { _, _ in applyTheme() }
        .onChange(of: accentRaw) { _, _ in applyTheme() }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = keepScreenAwake }
        .onChange(of: keepScreenAwake) { _, enabled in
          UIApplication.shared.isIdleTimerDisabled = enabled
        }
    }
    .modelContainer(for: [ActiveWorkoutRecord.self, CompletedWorkoutRecord.self])
  }

  private func applyTheme() {
    GymTheme.apply(appearance: appearance, accent: accent)
  }
}

private struct SafeAreaCanvas: View {
  let color: Color

  var body: some View {
    GeometryReader { proxy in
      color
        .frame(
          width: proxy.size.width,
          height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
        )
        .offset(y: -proxy.safeAreaInsets.top)
    }
    .ignoresSafeArea()
  }
}
