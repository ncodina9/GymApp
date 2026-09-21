import SwiftUI
import UIKit

enum ThemeAccent: String, CaseIterable, Identifiable {
  case blue
  case red
  case amber

  var id: String { rawValue }

  var label: String {
    switch self {
    case .blue: "Azul"
    case .red: "Rojo oscuro"
    case .amber: "Ámbar"
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
  nonisolated(unsafe) private static var appearance: AppAppearance = .system
  nonisolated(unsafe) private static var accent: ThemeAccent = .blue

  static func apply(appearance: AppAppearance, accent: ThemeAccent) {
    Self.appearance = appearance
    Self.accent = accent
  }

  fileprivate static func color(_ role: ThemeColor, traits: UITraitCollection) -> UIColor {
    let usesDarkCanvas: Bool = switch appearance {
    case .light: false
    case .dark: true
    case .system: traits.userInterfaceStyle == .dark
    }

    switch role {
    case .canvas:
      return usesDarkCanvas
        ? UIColor(red: 0.055, green: 0.067, blue: 0.086, alpha: 1)
        : UIColor(red: 0.949, green: 0.961, blue: 0.973, alpha: 1)
    case .surface:
      return usesDarkCanvas
        ? UIColor(red: 0.102, green: 0.125, blue: 0.157, alpha: 1)
        : UIColor.white
    case .accent:
      switch accent {
      case .blue: return UIColor(red: 0.00, green: 0.33, blue: 0.62, alpha: 1)
      case .red: return UIColor(red: 0.56, green: 0.14, blue: 0.18, alpha: 1)
      case .amber: return UIColor(red: 0.52, green: 0.31, blue: 0.00, alpha: 1)
      }
    case .accentSecondary:
      switch accent {
      case .blue: return UIColor(red: 0.16, green: 0.31, blue: 0.42, alpha: 1)
      case .red: return UIColor(red: 0.37, green: 0.20, blue: 0.23, alpha: 1)
      case .amber: return UIColor(red: 0.39, green: 0.30, blue: 0.10, alpha: 1)
      }
    }
  }
}

extension Color {
  static let gymCanvas = Color(uiColor: UIColor { GymTheme.color(.canvas, traits: $0) })
  static let gymSurface = Color(uiColor: UIColor { GymTheme.color(.surface, traits: $0) })
  static let gymAccent = Color(uiColor: UIColor { GymTheme.color(.accent, traits: $0) })
  static let gymAccentSecondary = Color(uiColor: UIColor { GymTheme.color(.accentSecondary, traits: $0) })
  static let gymSuccess = Color(red: 0.09, green: 0.45, blue: 0.29)
  static let gymWarning = Color(red: 0.64, green: 0.43, blue: 0.00)
  static let gymDanger = Color(red: 0.70, green: 0.23, blue: 0.22)
}

struct GymCanvas: View {
  var body: some View {
    Color.gymCanvas
  }
}
