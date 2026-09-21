import SwiftUI
import UIKit

enum ThemeAccent: String, CaseIterable, Identifiable {
  case blue
  case red
  case amber
  case graphite

  var id: String { rawValue }

  var label: String {
    switch self {
    case .blue: "Azul"
    case .red: "Rojo oscuro"
    case .amber: "Ámbar"
    case .graphite: "Grafito"
    }
  }

  var primaryColor: UIColor {
    switch self {
    case .blue: UIColor(red: 0.00, green: 0.33, blue: 0.62, alpha: 1)
    case .red: UIColor(red: 0.56, green: 0.14, blue: 0.18, alpha: 1)
    case .amber: UIColor(red: 0.52, green: 0.31, blue: 0.00, alpha: 1)
    case .graphite: UIColor(red: 0.19, green: 0.23, blue: 0.28, alpha: 1)
    }
  }

  var secondaryColor: UIColor {
    switch self {
    case .blue: UIColor(red: 0.16, green: 0.31, blue: 0.42, alpha: 1)
    case .red: UIColor(red: 0.37, green: 0.20, blue: 0.23, alpha: 1)
    case .amber: UIColor(red: 0.39, green: 0.30, blue: 0.10, alpha: 1)
    case .graphite: UIColor(red: 0.13, green: 0.16, blue: 0.20, alpha: 1)
    }
  }

  var lightSurfaceColor: UIColor {
    switch self {
    case .blue: UIColor(red: 0.929, green: 0.957, blue: 0.976, alpha: 1)
    case .red: UIColor(red: 0.984, green: 0.941, blue: 0.945, alpha: 1)
    case .amber: UIColor(red: 0.984, green: 0.961, blue: 0.910, alpha: 1)
    case .graphite: UIColor(red: 0.941, green: 0.953, blue: 0.965, alpha: 1)
    }
  }

  var darkSurfaceColor: UIColor {
    switch self {
    case .blue: UIColor(red: 0.067, green: 0.110, blue: 0.145, alpha: 1)
    case .red: UIColor(red: 0.133, green: 0.078, blue: 0.094, alpha: 1)
    case .amber: UIColor(red: 0.129, green: 0.102, blue: 0.055, alpha: 1)
    case .graphite: UIColor(red: 0.102, green: 0.125, blue: 0.157, alpha: 1)
    }
  }
}

private enum ThemeColor {
  case canvas
  case surface
  case accent
  case accentSecondary
}

enum GymTheme {
  private static var appearance: AppAppearance {
    AppAppearance(rawValue: UserDefaults.standard.string(forKey: "appearanceTheme") ?? "system") ?? .system
  }

  private static var accent: ThemeAccent {
    ThemeAccent(rawValue: UserDefaults.standard.string(forKey: "themeAccent") ?? "blue") ?? .blue
  }

  fileprivate static func color(_ role: ThemeColor, traits: UITraitCollection) -> UIColor {
    let usesDarkCanvas: Bool = switch appearance {
    case .light: false
    case .dark: true
    case .system: traits.userInterfaceStyle == .dark
    }

    switch role {
    case .canvas:
      return usesDarkCanvas ? .black : .white
    case .surface:
      return usesDarkCanvas ? accent.darkSurfaceColor : accent.lightSurfaceColor
    case .accent: return accent.primaryColor
    case .accentSecondary: return accent.secondaryColor
    }
  }
}

extension Color {
  static var gymCanvas: Color { Color(uiColor: UIColor { GymTheme.color(.canvas, traits: $0) }) }
  static var gymSurface: Color { Color(uiColor: UIColor { GymTheme.color(.surface, traits: $0) }) }
  static var gymAccent: Color { Color(uiColor: UIColor { GymTheme.color(.accent, traits: $0) }) }
  static var gymAccentSecondary: Color { Color(uiColor: UIColor { GymTheme.color(.accentSecondary, traits: $0) }) }
  static let gymSuccess = Color(red: 0.09, green: 0.45, blue: 0.29)
  static let gymWarning = Color(red: 0.64, green: 0.43, blue: 0.00)
  static let gymDanger = Color(red: 0.70, green: 0.23, blue: 0.22)
}

struct GymCanvas: View {
  var body: some View {
    Color.gymCanvas
  }
}
