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

private enum GymTheme {
  static func color(_ role: ThemeColor, traits: UITraitCollection) -> UIColor {
    let defaults = UserDefaults.standard
    let appearance = AppAppearance(rawValue: defaults.string(forKey: "appearanceTheme") ?? "system") ?? .system
    let usesDarkCanvas: Bool = switch appearance {
    case .light: false
    case .dark: true
    case .system: traits.userInterfaceStyle == .dark
    }

    if usesDarkCanvas {
      let palette = DarkPalette(rawValue: defaults.string(forKey: "darkPalette") ?? "dark") ?? .dark
      switch (palette, role) {
      case (.dark, .canvas): return UIColor(red: 0.055, green: 0.071, blue: 0.094, alpha: 1)
      case (.dark, .surface): return UIColor(red: 0.102, green: 0.125, blue: 0.157, alpha: 1)
      case (.dark, .accent): return UIColor(red: 0.00, green: 0.36, blue: 0.64, alpha: 1)
      case (.black, .canvas): return UIColor.black
      case (.black, .surface): return UIColor(red: 0.070, green: 0.070, blue: 0.070, alpha: 1)
      case (.black, .accent): return UIColor(red: 0.00, green: 0.31, blue: 0.56, alpha: 1)
      }
    }

    let palette = LightPalette(rawValue: defaults.string(forKey: "lightPalette") ?? "white") ?? .white
    switch (palette, role) {
    case (.white, .canvas): return UIColor.white
    case (.white, .surface): return UIColor(red: 0.955, green: 0.961, blue: 0.969, alpha: 1)
    case (.white, .accent): return UIColor(red: 0.20, green: 0.23, blue: 0.27, alpha: 1)
    case (.light, .canvas): return UIColor(red: 0.925, green: 0.937, blue: 0.949, alpha: 1)
    case (.light, .surface): return UIColor.white
    case (.light, .accent): return UIColor(red: 0.24, green: 0.28, blue: 0.33, alpha: 1)
    }
  }
}

extension Color {
  static let gymCanvas = Color(uiColor: UIColor { GymTheme.color(.canvas, traits: $0) })
  static let gymSurface = Color(uiColor: UIColor { GymTheme.color(.surface, traits: $0) })
  static let gymAccent = Color(uiColor: UIColor { GymTheme.color(.accent, traits: $0) })
}
