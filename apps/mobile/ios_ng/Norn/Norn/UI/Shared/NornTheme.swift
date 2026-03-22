import SwiftUI
import UIKit

enum NornTheme {
  static let canvasTop = adaptiveColor(
    light: UIColor(red: 0.97, green: 0.96, blue: 0.93, alpha: 1),
    dark: UIColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1)
  )

  static let canvasBottom = adaptiveColor(
    light: UIColor(red: 0.93, green: 0.95, blue: 0.99, alpha: 1),
    dark: UIColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 1)
  )

  static let cardSurface = adaptiveColor(
    light: UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 0.90),
    dark: UIColor(red: 0.14, green: 0.15, blue: 0.18, alpha: 0.94)
  )

  static let cardSurfaceMuted = adaptiveColor(
    light: UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 0.92),
    dark: UIColor(red: 0.11, green: 0.12, blue: 0.15, alpha: 0.92)
  )

  static let pillSurface = adaptiveColor(
    light: UIColor(red: 0.92, green: 0.94, blue: 0.97, alpha: 1),
    dark: UIColor(red: 0.18, green: 0.19, blue: 0.22, alpha: 1)
  )

  static let pillSurfaceStrong = adaptiveColor(
    light: UIColor(red: 0.88, green: 0.91, blue: 0.95, alpha: 1),
    dark: UIColor(red: 0.22, green: 0.23, blue: 0.27, alpha: 1)
  )

  static let border = adaptiveColor(
    light: UIColor.black.withAlphaComponent(0.08),
    dark: UIColor.white.withAlphaComponent(0.10)
  )

  static let borderStrong = adaptiveColor(
    light: UIColor.black.withAlphaComponent(0.12),
    dark: UIColor.white.withAlphaComponent(0.16)
  )

  static let divider = adaptiveColor(
    light: UIColor.black.withAlphaComponent(0.10),
    dark: UIColor.white.withAlphaComponent(0.18)
  )

  static let shadow = adaptiveColor(
    light: UIColor.black.withAlphaComponent(0.10),
    dark: UIColor.black.withAlphaComponent(0.30)
  )

  private static func adaptiveColor(light: UIColor, dark: UIColor) -> Color {
    Color(
      uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? dark : light
      }
    )
  }
}

struct NornScreenBackground: View {
  var body: some View {
    LinearGradient(
      colors: [NornTheme.canvasTop, NornTheme.canvasBottom],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .ignoresSafeArea()
  }
}
