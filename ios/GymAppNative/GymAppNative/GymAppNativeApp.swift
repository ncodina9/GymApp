import SwiftUI
import SwiftData

@main
struct GymAppNativeApp: App {
  @AppStorage("appearanceTheme") private var appearanceRaw = AppAppearance.system.rawValue
  @AppStorage("keepScreenAwake") private var keepScreenAwake = false

  private var appearance: AppAppearance {
    AppAppearance(rawValue: appearanceRaw) ?? .system
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
        .onAppear { UIApplication.shared.isIdleTimerDisabled = keepScreenAwake }
        .onChange(of: keepScreenAwake) { _, enabled in
          UIApplication.shared.isIdleTimerDisabled = enabled
        }
    }
    .modelContainer(for: [ActiveWorkoutRecord.self, CompletedWorkoutRecord.self])
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
