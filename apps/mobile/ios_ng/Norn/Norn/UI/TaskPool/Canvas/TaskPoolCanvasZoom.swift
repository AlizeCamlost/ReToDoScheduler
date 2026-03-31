import CoreGraphics
import Foundation

enum TaskPoolCanvasZoom {
  static let defaultScale: CGFloat = 1
  static let minScale: CGFloat = 0.7
  static let maxScale: CGFloat = 1.8
  static let step: CGFloat = 0.15

  static func clamped(_ scale: CGFloat) -> CGFloat {
    min(max(scale, minScale), maxScale)
  }

  static func stepped(from scale: CGFloat, delta: CGFloat) -> CGFloat {
    clamped(scale + delta)
  }

  static func normalizedTranslation(_ translation: CGSize, scale: CGFloat) -> CGSize {
    let resolvedScale = clamped(scale)
    return CGSize(
      width: translation.width / resolvedScale,
      height: translation.height / resolvedScale
    )
  }

  static func scaledCanvasSize(for size: CGSize, scale: CGFloat) -> CGSize {
    let resolvedScale = clamped(scale)
    return CGSize(
      width: size.width * resolvedScale,
      height: size.height * resolvedScale
    )
  }

  static func percentLabel(for scale: CGFloat) -> String {
    "\(Int((clamped(scale) * 100).rounded()))%"
  }
}
