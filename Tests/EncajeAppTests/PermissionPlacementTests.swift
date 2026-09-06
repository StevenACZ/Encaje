import XCTest

@testable import EncajeApp

final class PermissionPlacementTests: XCTestCase {
  func testGuideFillsRightColumnInsideSettings() throws {
    let settings = CGRect(x: 100, y: 100, width: 724, height: 1000)
    let frame = try XCTUnwrap(
      PermissionPlacement.frame(
        settings: settings, visible: CGRect(x: 0, y: 0, width: 1440, height: 1200)))
    XCTAssertTrue(settings.contains(frame))
    XCTAssertEqual(frame.minY, 120)
    XCTAssertEqual(frame.maxX, 804)
    XCTAssertGreaterThan(frame.width, 450)
    XCTAssertGreaterThan(frame.minX, settings.minX + 220)
    XCTAssertEqual(frame, frame.integral)
  }

  func testGuideHidesWhenInsufficientVisibleContentAndRecovers() {
    let screen = CGRect(x: 0, y: 0, width: 1000, height: 900)
    XCTAssertNil(
      PermissionPlacement.frame(
        settings: CGRect(x: 700, y: 100, width: 724, height: 800), visible: screen))
    XCTAssertNotNil(
      PermissionPlacement.frame(
        settings: CGRect(x: 100, y: 100, width: 724, height: 800), visible: screen))
    XCTAssertNil(
      PermissionPlacement.frame(
        settings: CGRect(x: 100, y: 800, width: 724, height: 800), visible: screen))
  }
}
