import CoreGraphics
import XCTest
@testable import Norn

final class TaskPoolCanvasZoomTests: XCTestCase {
  func testClampedScaleStaysWithinSupportedRange() {
    XCTAssertEqual(TaskPoolCanvasZoom.clamped(0.1), TaskPoolCanvasZoom.minScale, accuracy: 0.001)
    XCTAssertEqual(TaskPoolCanvasZoom.clamped(4), TaskPoolCanvasZoom.maxScale, accuracy: 0.001)
  }

  func testSteppedZoomMovesByFixedIncrementAndClamps() {
    XCTAssertEqual(
      TaskPoolCanvasZoom.stepped(from: 1, delta: TaskPoolCanvasZoom.step),
      1.15,
      accuracy: 0.001
    )
    XCTAssertEqual(
      TaskPoolCanvasZoom.stepped(from: TaskPoolCanvasZoom.minScale, delta: -TaskPoolCanvasZoom.step),
      TaskPoolCanvasZoom.minScale,
      accuracy: 0.001
    )
  }

  func testNormalizedTranslationCompensatesForZoomScale() {
    let translation = TaskPoolCanvasZoom.normalizedTranslation(
      CGSize(width: 180, height: 90),
      scale: 1.5
    )

    XCTAssertEqual(translation.width, 120, accuracy: 0.001)
    XCTAssertEqual(translation.height, 60, accuracy: 0.001)
  }

  func testScaledCanvasSizeUsesClampedScale() {
    let scaled = TaskPoolCanvasZoom.scaledCanvasSize(
      for: CGSize(width: 1_600, height: 1_200),
      scale: 2.4
    )

    XCTAssertEqual(scaled.width, 1_600 * TaskPoolCanvasZoom.maxScale, accuracy: 0.001)
    XCTAssertEqual(scaled.height, 1_200 * TaskPoolCanvasZoom.maxScale, accuracy: 0.001)
  }
}
