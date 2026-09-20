import SwiftUI
import UIKit

enum LightPalette: String, CaseIterable {
  case white
  case light

  var label: String { self == .white ? "White" : "Light" }
}

enum DarkPalette: String, CaseIterable {
  case dark
  case black

  var label: String { self == .dark ? "Dark" : "Black" }
}

private enum ThemeColor {
  case canvas
  case surface
  case accent
}

enum GymTheme {
  nonisolated(unsafe) private static var appearance: AppAppearance = .system
  nonisolated(unsafe) private static var lightPalette: LightPalette = .white
  nonisolated(unsafe) private static var darkPalette: DarkPalette = .dark

  static func apply(
    appearance: AppAppearance,
    lightPalette: LightPalette,
    darkPalette: DarkPalette
  ) {
    Self.appearance = appearance
    Self.lightPalette = lightPalette
    Self.darkPalette = darkPalette
  }

  fileprivate static func color(_ role: ThemeColor, traits: UITraitCollection) -> UIColor {
    let usesDarkCanvas: Bool = switch appearance {
    case .light: false
    case .dark: true
    case .system: traits.userInterfaceStyle == .dark
    }

    if usesDarkCanvas {
      switch (darkPalette, role) {
      case (.dark, .canvas): return UIColor.black
      case (.dark, .surface): return UIColor(red: 0.102, green: 0.125, blue: 0.157, alpha: 1)
      case (.dark, .accent): return UIColor(red: 0.00, green: 0.36, blue: 0.64, alpha: 1)
      case (.black, .canvas): return UIColor.black
      case (.black, .surface): return UIColor(red: 0.070, green: 0.070, blue: 0.070, alpha: 1)
      case (.black, .accent): return UIColor(red: 0.00, green: 0.31, blue: 0.56, alpha: 1)
      }
    }

    switch (lightPalette, role) {
    case (.white, .canvas): return UIColor.white
    case (.white, .surface): return UIColor(red: 0.955, green: 0.961, blue: 0.969, alpha: 1)
    case (.white, .accent): return UIColor(red: 0.20, green: 0.23, blue: 0.27, alpha: 1)
    case (.light, .canvas): return UIColor.white
    case (.light, .surface): return UIColor.white
    case (.light, .accent): return UIColor(red: 0.24, green: 0.28, blue: 0.33, alpha: 1)
    }
  }
}

extension Color {
  static let gymCanvas = Color(uiColor: UIColor { GymTheme.color(.canvas, traits: $0) })
  static let gymSurface = Color(uiColor: UIColor { GymTheme.color(.surface, traits: $0) })
  static let gymAccent = Color(uiColor: UIColor { GymTheme.color(.accent, traits: $0) })
  static let gymSuccess = Color(red: 0.09, green: 0.45, blue: 0.29)
  static let gymWarning = Color(red: 0.64, green: 0.43, blue: 0.00)
  static let gymDanger = Color(red: 0.70, green: 0.23, blue: 0.22)
}

struct GymCanvas: View {
  @AppStorage("appearanceTheme") private var appearanceRaw = AppAppearance.system.rawValue
  @AppStorage("lightPalette") private var lightPaletteRaw = LightPalette.white.rawValue
  @AppStorage("darkPalette") private var darkPaletteRaw = DarkPalette.dark.rawValue
  @Environment(\.colorScheme) private var systemColorScheme

  private var isDark: Bool {
    switch AppAppearance(rawValue: appearanceRaw) ?? .system {
    case .light: false
    case .dark: true
    case .system: systemColorScheme == .dark
    }
  }

  var body: some View {
    if isDark {
      Color.black
    } else {
      Color.white
    }
  }
}
