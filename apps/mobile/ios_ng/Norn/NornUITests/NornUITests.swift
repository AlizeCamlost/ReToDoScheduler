import XCTest

final class NornUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testSmokeLaunchAndNavigateTaskPool() throws {
    let app = XCUIApplication()
    app.launch()

    XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 1))
    app.swipeLeft()
    app.swipeLeft()

    XCTAssertTrue(app.staticTexts["任务池"].waitForExistence(timeout: 1))
  }
}
