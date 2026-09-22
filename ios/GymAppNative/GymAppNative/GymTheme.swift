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

enum PremiumColorScheme: String, CaseIterable, Identifiable {
  case monochrome
  case amberViolet
  case greenBlue
  case whiteNavy
  case grayBurgundy

  var id: String { rawValue }

  var label: String {
    switch self {
    case .monochrome: "Blanco y negro"
    case .amberViolet: "Ámbar y violeta"
    case .greenBlue: "Verde y azul"
    case .whiteNavy: "Blanco y azul marino"
    case .grayBurgundy: "Gris y burdeos"
    }
  }

  var lightColor: UIColor {
    switch self {
    case .monochrome: .white
    case .amberViolet: UIColor(red: 0.70, green: 0.44, blue: 0.13, alpha: 1)
    case .greenBlue: UIColor(red: 0.40, green: 0.62, blue: 0.49, alpha: 1)
    case .whiteNavy: .white
    case .grayBurgundy: UIColor(red: 0.89, green: 0.90, blue: 0.92, alpha: 1)
    }
  }

  var darkColor: UIColor {
    switch self {
    case .monochrome: .black
    case .amberViolet: UIColor(red: 0.20, green: 0.09, blue: 0.34, alpha: 1)
    case .greenBlue: UIColor(red: 0.12, green: 0.22, blue: 0.32, alpha: 1)
    case .whiteNavy: UIColor(red: 0.02, green: 0.12, blue: 0.24, alpha: 1)
    case .grayBurgundy: UIColor(red: 0.40, green: 0.06, blue: 0.12, alpha: 1)
    }
  }
}

private enum ThemeColor {
  case canvas
  case surface
  case accent
  case accentSecondary
  case accentForeground
  case secondaryText
  case controlSelectionFill
  case controlSelectionForeground
  case progressFill
}

enum GymTheme {
  private static var appearance: AppAppearance {
    AppAppearance(rawValue: UserDefaults.standard.string(forKey: "appearanceTheme") ?? "system") ?? .system
  }

  private static var accent: ThemeAccent {
    ThemeAccent(rawValue: UserDefaults.standard.string(forKey: "themeAccent") ?? "blue") ?? .blue
  }

  private static var premiumScheme: PremiumColorScheme? {
    guard let rawValue = UserDefaults.standard.string(forKey: "premiumColorScheme") else { return nil }
    return PremiumColorScheme(rawValue: rawValue)
  }

  fileprivate static func color(_ role: ThemeColor, traits: UITraitCollection) -> UIColor {
    let usesDarkCanvas: Bool = switch appearance {
    case .light: false
    case .dark: true
    case .system: traits.userInterfaceStyle == .dark
    }

    if let premiumScheme {
      let canvas = usesDarkCanvas ? premiumScheme.darkColor : premiumScheme.lightColor
      let accent = usesDarkCanvas ? premiumScheme.lightColor : premiumScheme.darkColor

      switch role {
      case .canvas: return canvas
      case .surface: return accent.withAlphaComponent(usesDarkCanvas ? 0.12 : 0.07)
      case .accent: return accent
      case .accentSecondary: return accent.withAlphaComponent(usesDarkCanvas ? 0.58 : 0.72)
      case .accentForeground: return usesDarkCanvas ? .black : .white
      case .secondaryText: return (usesDarkCanvas ? UIColor.white : UIColor.black).withAlphaComponent(0.82)
      case .controlSelectionFill:
        return usesDarkCanvas ? accent.withAlphaComponent(0.22) : accent
      case .controlSelectionForeground:
        return usesDarkCanvas ? .white : .white
      case .progressFill: return accent.withAlphaComponent(0.22)
      }
    }

    switch role {
    case .canvas:
      return usesDarkCanvas ? .black : .white
    case .surface:
      return usesDarkCanvas ? accent.darkSurfaceColor : accent.lightSurfaceColor
    case .accent: return accent.primaryColor
    case .accentSecondary: return accent.secondaryColor
    case .accentForeground: return .white
    case .secondaryText: return .secondaryLabel
    case .controlSelectionFill: return accent.primaryColor
    case .controlSelectionForeground: return .white
    case .progressFill: return accent.primaryColor.withAlphaComponent(0.22)
    }
  }
}

extension Color {
  static var gymCanvas: Color { Color(uiColor: UIColor { GymTheme.color(.canvas, traits: $0) }) }
  static var gymSurface: Color { Color(uiColor: UIColor { GymTheme.color(.surface, traits: $0) }) }
  static var gymAccent: Color { Color(uiColor: UIColor { GymTheme.color(.accent, traits: $0) }) }
  static var gymAccentSecondary: Color { Color(uiColor: UIColor { GymTheme.color(.accentSecondary, traits: $0) }) }
  static var gymAccentForeground: Color { Color(uiColor: UIColor { GymTheme.color(.accentForeground, traits: $0) }) }
  static var gymSecondaryText: Color { Color(uiColor: UIColor { GymTheme.color(.secondaryText, traits: $0) }) }
  static var gymControlSelectionFill: Color { Color(uiColor: UIColor { GymTheme.color(.controlSelectionFill, traits: $0) }) }
  static var gymControlSelectionForeground: Color { Color(uiColor: UIColor { GymTheme.color(.controlSelectionForeground, traits: $0) }) }
  static var gymProgressFill: Color { Color(uiColor: UIColor { GymTheme.color(.progressFill, traits: $0) }) }
  static let gymSuccess = Color(red: 0.09, green: 0.45, blue: 0.29)
  static let gymWarning = Color(red: 0.64, green: 0.43, blue: 0.00)
  static let gymDanger = Color(red: 0.70, green: 0.23, blue: 0.22)
}

struct GymCanvas: View {
  var body: some View {
    Color.gymCanvas.ignoresSafeArea()
  }
}
