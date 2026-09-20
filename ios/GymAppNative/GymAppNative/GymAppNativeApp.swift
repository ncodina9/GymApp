import SwiftUI
import SwiftData

@main
struct GymAppNativeApp: App {
  @AppStorage("appearanceTheme") private var appearanceRaw = AppAppearance.system.rawValue
  @AppStorage("lightPalette") private var lightPaletteRaw = LightPalette.white.rawValue
  @AppStorage("darkPalette") private var darkPaletteRaw = DarkPalette.dark.rawValue
  @AppStorage("keepScreenAwake") private var keepScreenAwake = false

  private var appearance: AppAppearance {
    AppAppearance(rawValue: appearanceRaw) ?? .system
  }

  private var lightPalette: LightPalette {
    LightPalette(rawValue: lightPaletteRaw) ?? .white
  }

  private var darkPalette: DarkPalette {
    DarkPalette(rawValue: darkPaletteRaw) ?? .dark
  }

  private var windowCanvas: Color {
    Color(uiColor: windowCanvasColor)
  }

  private var windowCanvasColor: UIColor {
    let usesDarkCanvas: Bool = switch appearance {
    case .light: false
    case .dark: true
    case .system: UITraitCollection.current.userInterfaceStyle == .dark
    }
    if usesDarkCanvas {
      return darkPalette == .black
        ? .black
        : UIColor(red: 0.055, green: 0.071, blue: 0.094, alpha: 1)
    }
    return lightPalette == .white
      ? .white
      : UIColor(red: 0.925, green: 0.937, blue: 0.949, alpha: 1)
  }

  var body: some Scene {
    WindowGroup {
      ZStack {
        SafeAreaCanvas(color: windowCanvas)
        ContentView()
      }
        .preferredColorScheme(appearance.colorScheme)
        .background(windowCanvas, ignoresSafeAreaEdges: .all)
        .tint(.gymAccent)
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
