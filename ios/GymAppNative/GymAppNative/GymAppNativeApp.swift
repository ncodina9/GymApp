import SwiftUI
import SwiftData

@main
struct GymAppNativeApp: App {
  @AppStorage("appearanceTheme") private var appearanceRaw = AppAppearance.system.rawValue
  @AppStorage("premiumColorScheme") private var premiumSchemeRaw = ""
  @AppStorage("keepScreenAwake") private var keepScreenAwake = false

  private var appearance: AppAppearance {
    AppAppearance(rawValue: appearanceRaw) ?? .system
  }

  var body: some Scene {
    WindowGroup {
      ZStack {
        SafeAreaCanvas(color: .gymCanvas)
          .id(premiumSchemeRaw)
        ContentView()
        WatchWorkoutSyncHost()
      }
        .preferredColorScheme(appearance.colorScheme)
        .background(Color.gymCanvas, ignoresSafeAreaEdges: .all)
        .toolbarBackground(.hidden, for: .statusBar)
        .toolbarColorScheme(appearance.colorScheme, for: .statusBar)
        // Native alerts and file pickers inherit this tint. It intentionally
        // differs from the selected visual accent to preserve contrast on all
        // of iOS's system surfaces.
        .tint(.gymSystemAction)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = keepScreenAwake }
        .onChange(of: keepScreenAwake) { _, enabled in
          UIApplication.shared.isIdleTimerDisabled = enabled
        }
    }
    .modelContainer(for: [ActiveWorkoutRecord.self, CompletedWorkoutRecord.self])
    .onChange(of: appearanceRaw) { _, _ in WatchWorkoutConnectivity.shared.activate() }
    .onChange(of: premiumSchemeRaw) { _, _ in WatchWorkoutConnectivity.shared.activate() }
  }

}

private struct WatchWorkoutSyncHost: View {
  @Query private var activeWorkoutRecords: [ActiveWorkoutRecord]

  private var updateToken: [Date] {
    activeWorkoutRecords.map(\.updatedAt)
  }

  var body: some View {
    Color.clear
      .allowsHitTesting(false)
      .accessibilityHidden(true)
      .onAppear(perform: synchronize)
      .onChange(of: updateToken) { _, _ in synchronize() }
  }

  private func synchronize() {
    if let snapshot = ActiveWorkoutStore.load(from: activeWorkoutRecords) {
      WatchWorkoutConnectivity.shared.publish(snapshot)
    } else {
      WatchWorkoutConnectivity.shared.clear()
    }
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
