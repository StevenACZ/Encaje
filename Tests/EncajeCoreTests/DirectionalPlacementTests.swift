import CoreGraphics
import XCTest

@testable import EncajeCore

final class DirectionalPlacementTests: XCTestCase {
  let main = DisplayArea(id: "main", frame: CGRect(x: 0, y: 0, width: 1000, height: 800))
  func testEveryDirectionTraversesThreeStepsAndStops() throws {
    let cases: [(WindowAction, WindowAction, CGRect)] = [
      (.left, .right, CGRect(x: -1600, y: -50, width: 1500, height: 1000)),
      (.right, .left, CGRect(x: 1100, y: -50, width: 1500, height: 1000)),
      (.up, .down, CGRect(x: -50, y: 900, width: 1500, height: 1000)),
      (.down, .up, CGRect(x: -50, y: -1100, width: 1500, height: 1000)),
    ]
    for (action, opposite, bounds) in cases {
      for gap: CGFloat in [0, 8, 13.5] {
        let neighbor = DisplayArea(id: "neighbor", frame: bounds)
        let screens = [main, neighbor]
        let initial = WindowGeometry.placement(
          opposite, window: .zero, bounds: main.frame, gap: gap)
        let local = try XCTUnwrap(
          WindowGeometry.target(for: action, window: initial, displays: screens, gap: gap))
        XCTAssertEqual(
          local, WindowGeometry.placement(action, window: initial, bounds: main.frame, gap: gap))
        let entered = try XCTUnwrap(
          WindowGeometry.target(for: action, window: local, displays: screens, gap: gap))
        XCTAssertEqual(
          entered, WindowGeometry.placement(opposite, window: local, bounds: bounds, gap: gap))
        let far = try XCTUnwrap(
          WindowGeometry.target(for: action, window: entered, displays: screens, gap: gap))
        XCTAssertEqual(
          far, WindowGeometry.placement(action, window: entered, bounds: bounds, gap: gap))
        XCTAssertEqual(
          WindowGeometry.target(for: action, window: far, displays: screens, gap: gap), far)
      }
    }
  }

  func testConstrainedWindowCanContinueAcrossMonitor() throws {
    let left = DisplayArea(id: "left", frame: CGRect(x: -1000, y: 0, width: 1000, height: 800))
    let intended = WindowGeometry.placement(.left, window: .zero, bounds: main.frame, gap: 8)
    let actual = CGRect(x: intended.minX, y: intended.minY, width: 700, height: intended.height)
    let state = DirectionalPlacement(
      action: .left, actualFrame: actual, intendedFrame: intended, display: main, gap: 8)
    let effective = state.geometryFrame(
      for: .left, current: actual, displays: [main, left], gap: 8)
    XCTAssertEqual(effective, intended)
    XCTAssertEqual(
      WindowGeometry.target(for: .left, window: effective, displays: [main, left], gap: 8),
      WindowGeometry.placement(.right, window: actual, bounds: left.frame, gap: 8))
  }

  func testUserMovementDirectionGapOrDisplayChangesInvalidateContinuation() {
    let intended = WindowGeometry.placement(.left, window: .zero, bounds: main.frame, gap: 8)
    let actual = CGRect(x: 8, y: 8, width: 700, height: 784)
    let state = DirectionalPlacement(
      action: .left, actualFrame: actual, intendedFrame: intended, display: main, gap: 8)
    let moved = actual.offsetBy(dx: 20, dy: 0)
    XCTAssertEqual(state.geometryFrame(for: .left, current: moved, displays: [main], gap: 8), moved)
    XCTAssertEqual(
      state.geometryFrame(for: .right, current: actual, displays: [main], gap: 8), actual)
    XCTAssertEqual(
      state.geometryFrame(for: .left, current: actual, displays: [main], gap: 10), actual)
    XCTAssertEqual(state.geometryFrame(for: .left, current: actual, displays: [], gap: 8), actual)
    let changed = DisplayArea(id: main.id, frame: CGRect(x: 0, y: 0, width: 800, height: 600))
    XCTAssertEqual(
      state.geometryFrame(for: .left, current: actual, displays: [changed], gap: 8), actual)
  }

  func testEveryPlacementRemainsWithinVisibleBoundsAndGapClamps() {
    for action in WindowAction.allCases where ![.undo, .restore].contains(action) {
      for gap: CGFloat in [-10, 0, 8, 10000] {
        let frame = WindowGeometry.placement(
          action, window: CGRect(x: -500, y: 100, width: 1200, height: 900), bounds: main.frame,
          gap: gap)
        XCTAssertTrue(main.frame.contains(frame), "\(action) gap \(gap): \(frame)")
        XCTAssertGreaterThan(frame.width, 0)
        XCTAssertGreaterThan(frame.height, 0)
      }
    }
  }

  func testDisconnectedDisplayRecoveryAndOversizedWindow() {
    XCTAssertEqual(
      WindowGeometry.recovered(
        CGRect(x: -1800, y: -100, width: 800, height: 700), displays: [main]),
      CGRect(x: 0, y: 0, width: 800, height: 700))
    XCTAssertEqual(
      WindowGeometry.recovered(CGRect(x: 500, y: 600, width: 2000, height: 1500), displays: [main]),
      main.frame)
    let normal = CGRect(x: 100, y: 100, width: 600, height: 500)
    XCTAssertEqual(WindowGeometry.recovered(normal, displays: [main]), normal)
    XCTAssertNil(WindowGeometry.recovered(normal, displays: []))
  }

  func testSavedLayoutRoundTripPreservesMapping() throws {
    let entry = SavedWindow(
      bundleID: "test.app", title: "test document", ordinal: 2, displayID: "display-uuid",
      normalizedFrame: CGRect(x: 0.5, y: 0, width: 0.5, height: 1))
    let original = SavedLayout(name: "Test", windows: [entry])
    let decoded = try JSONDecoder().decode(SavedLayout.self, from: JSONEncoder().encode(original))
    XCTAssertEqual(decoded.id, original.id)
    XCTAssertEqual(decoded.windows[0].bundleID, entry.bundleID)
    XCTAssertEqual(decoded.windows[0].ordinal, 2)
    XCTAssertEqual(decoded.windows[0].displayID, "display-uuid")
    XCTAssertEqual(decoded.windows[0].normalizedFrame, entry.normalizedFrame)
  }
}
