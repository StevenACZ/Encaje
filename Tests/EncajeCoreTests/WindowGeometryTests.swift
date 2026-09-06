import CoreGraphics
import XCTest

@testable import EncajeCore

final class WindowGeometryTests: XCTestCase {
  let main = DisplayArea(id: "main", frame: CGRect(x: 0, y: 0, width: 1200, height: 800))
  func testRepeatedLeftCrossesIntoOppositeHalf() throws {
    let left = DisplayArea(id: "left", frame: CGRect(x: -1920, y: -100, width: 1920, height: 1080))
    let screens = [main, left]
    var frame = CGRect(x: 600, y: 0, width: 600, height: 800)
    frame = try XCTUnwrap(
      WindowGeometry.target(for: .left, window: frame, displays: screens, gap: 0))
    XCTAssertEqual(frame, CGRect(x: 0, y: 0, width: 600, height: 800))
    frame = try XCTUnwrap(
      WindowGeometry.target(for: .left, window: frame, displays: screens, gap: 0))
    XCTAssertEqual(frame, CGRect(x: -960, y: -100, width: 960, height: 1080))
    frame = try XCTUnwrap(
      WindowGeometry.target(for: .left, window: frame, displays: screens, gap: 0))
    XCTAssertEqual(frame, CGRect(x: -1920, y: -100, width: 960, height: 1080))
    XCTAssertEqual(
      WindowGeometry.target(for: .left, window: frame, displays: screens, gap: 0), frame)
  }
  func testVerticalDirectionsUseAppKitCoordinates() throws {
    let top = DisplayArea(id: "top", frame: CGRect(x: 100, y: 900, width: 800, height: 600))
    let bottom = DisplayArea(id: "bottom", frame: CGRect(x: 0, y: -900, width: 1200, height: 800))
    let screens = [main, top, bottom]
    let up = WindowGeometry.placement(.up, window: .zero, bounds: main.frame, gap: 0)
    XCTAssertEqual(
      WindowGeometry.target(for: .up, window: up, displays: screens, gap: 0),
      CGRect(x: 100, y: 900, width: 800, height: 300))
    let down = WindowGeometry.placement(.down, window: .zero, bounds: main.frame, gap: 0)
    XCTAssertEqual(
      WindowGeometry.target(for: .down, window: down, displays: screens, gap: 0),
      CGRect(x: 0, y: -500, width: 1200, height: 400))
  }
  func testGapsAreEqualAcrossHalves() {
    let left = WindowGeometry.placement(.left, window: .zero, bounds: main.frame, gap: 8)
    let right = WindowGeometry.placement(.right, window: .zero, bounds: main.frame, gap: 8)
    XCTAssertEqual(left.minX, 8)
    XCTAssertEqual(right.maxX, 1192)
    XCTAssertEqual(right.minX - left.maxX, 8)
    XCTAssertEqual(left.width, right.width)
  }
  func testNoDiagonalNeighborAndDeterministicTie() {
    let diagonal = DisplayArea(
      id: "diagonal", frame: CGRect(x: 1300, y: 900, width: 400, height: 400))
    XCTAssertNil(WindowGeometry.neighbor(of: main, direction: .right, displays: [main, diagonal]))
    let a = DisplayArea(id: "a", frame: CGRect(x: 1400, y: 0, width: 800, height: 800))
    let b = DisplayArea(id: "b", frame: a.frame)
    XCTAssertEqual(
      WindowGeometry.neighbor(of: main, direction: .right, displays: [main, b, a])?.id, "a")
  }
  func testMaximizeStaysOnDestinationAndCenterClampsSize() {
    let other = DisplayArea(id: "other", frame: CGRect(x: 1200, y: 0, width: 800, height: 600))
    let window = CGRect(x: 1600, y: 0, width: 400, height: 600)
    XCTAssertEqual(
      WindowGeometry.target(for: .maximize, window: window, displays: [main, other], gap: 8),
      other.frame.insetBy(dx: 8, dy: 8))
    XCTAssertEqual(
      WindowGeometry.placement(
        .center, window: CGRect(x: 0, y: 0, width: 3000, height: 3000), bounds: main.frame, gap: 0),
      main.frame)
  }
}
