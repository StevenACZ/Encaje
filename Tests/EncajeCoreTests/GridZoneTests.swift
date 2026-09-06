import XCTest

@testable import EncajeCore

final class GridZoneTests: XCTestCase {
  func testReferenceGridUsesComplementaryWidthsAndHeights() throws {
    let screen = CGRect(x: -1800, y: 100, width: 1800, height: 1000)
    let left = try XCTUnwrap(GridZone.defaultZone(for: .left)).frame(in: screen, gap: 8)
    let right = try XCTUnwrap(GridZone.defaultZone(for: .right)).frame(in: screen, gap: 8)
    XCTAssertEqual(right.minX - left.maxX, 8, accuracy: 0.001)
    XCTAssertEqual(left.minX, screen.minX + 8, accuracy: 0.001)
    XCTAssertEqual(right.maxX, screen.maxX - 8, accuracy: 0.001)
    XCTAssertLessThan(left.width, right.width)
    let q = try XCTUnwrap(GridZone.defaultZone(for: .topLeft)).frame(in: screen, gap: 8)
    let z = try XCTUnwrap(GridZone.defaultZone(for: .bottomLeft)).frame(in: screen, gap: 8)
    XCTAssertEqual(q.minY - z.maxY, 8, accuracy: 0.001)
    XCTAssertGreaterThan(q.height, z.height)
    XCTAssertEqual(q.maxY, screen.maxY - 8, accuracy: 0.001)
  }

  func testCustomWidthsContinueAcrossDisplaysUsingConfiguredOppositeZone() throws {
    let a = DisplayArea(id: "a", frame: CGRect(x: 0, y: 0, width: 1440, height: 900))
    let b = DisplayArea(id: "b", frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080))
    let left = GridZone(x: 0, y: 0, width: 10, height: 24)
    let right = GridZone(x: 10, y: 0, width: 14, height: 24)
    let initial = left.frame(in: a.frame, gap: 8)
    let next = try XCTUnwrap(
      ZoneGeometry.target(
        for: .left, zone: left, window: initial, displays: [a, b], gap: 8, neighborZone: right))
    XCTAssertEqual(next, right.frame(in: b.frame, gap: 8))
    let far = try XCTUnwrap(
      ZoneGeometry.target(
        for: .left, zone: left, window: next, displays: [a, b], gap: 8, neighborZone: right))
    XCTAssertEqual(far, left.frame(in: b.frame, gap: 8))
  }

  func testGridNormalizesInvalidBoundsAndPreservesFrameWithinMonitor() {
    let invalid = GridZone(columns: -1, rows: 999, x: 99, y: -5, width: -4, height: 999).normalized
    XCTAssertEqual(invalid.columns, 1)
    XCTAssertEqual(invalid.rows, 64)
    XCTAssertEqual(invalid.x, 0)
    XCTAssertEqual(invalid.width, 1)
    XCTAssertEqual(invalid.height, 64)
    let monitor = CGRect(x: -640, y: -900, width: 640, height: 900)
    XCTAssertTrue(monitor.contains(invalid.frame(in: monitor, gap: 32)))
  }

  func testNineSpatialDefaultsAndLegacyOverridesSurviveMigration() {
    let expected = [
      "topLeft": 12, "up": 13, "topRight": 14, "left": 0, "maximize": 1, "right": 2,
      "bottomLeft": 6, "down": 7, "bottomRight": 8,
    ]
    XCTAssertEqual(
      Dictionary(uniqueKeysWithValues: WindowRule.defaults.map { ($0.id, $0.keyCode!) }), expected)
    let migrated = WindowRule.migrating([
      "left": 3, "right": 2, "up": 13, "down": 7, "maximize": 1, "topLeft": -1,
    ])
    XCTAssertEqual(migrated.first { $0.id == "left" }?.keyCode, 3)
    XCTAssertNil(migrated.first { $0.id == "topLeft" })
    XCTAssertEqual(migrated.first { $0.id == "bottomRight" }?.keyCode, 8)
    let conflicts = WindowRule.migrating(["center": 12, "left": 0])
    XCTAssertEqual(conflicts.filter { $0.keyCode == 12 }.count, 1)
    XCTAssertEqual(conflicts.first { $0.keyCode == 12 }?.action, .center)
  }

  func testCustomRulePersistenceRoundTrip() throws {
    let rule = WindowRule(
      title: "Reading", keyCode: 15,
      zone: GridZone(columns: 30, rows: 20, x: 0, y: 0, width: 10, height: 20))
    XCTAssertEqual(
      try JSONDecoder().decode(WindowRule.self, from: JSONEncoder().encode(rule)), rule)
  }
  func testEquivalentSelectionsKeepSameGapAcrossGridResolutions() {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let a = GridZone(columns: 24, rows: 24, x: 0, y: 0, width: 24, height: 24)
    let b = GridZone(columns: 64, rows: 64, x: 0, y: 0, width: 64, height: 64)
    XCTAssertEqual(a.frame(in: screen, gap: 32), b.frame(in: screen, gap: 32))
    XCTAssertEqual(a.frame(in: screen, gap: 32).minX, 32)
    let left24 = GridZone(columns: 24, rows: 24, x: 0, y: 0, width: 12, height: 24)
    let left64 = GridZone(columns: 64, rows: 64, x: 0, y: 0, width: 32, height: 64)
    XCTAssertEqual(left24.frame(in: screen, gap: 32), left64.frame(in: screen, gap: 32))
  }

  func testRulesWithoutModifiersDecodeAsLegacyShiftAndCombinationsStayDistinct() throws {
    let data = Data(#"{"id":"left","title":"","action":"left","keyCode":0}"#.utf8)
    let old = try JSONDecoder().decode(WindowRule.self, from: data)
    XCTAssertEqual(old.modifiers, .shift)
    let first = ShortcutCombination(keyCode: 13, modifiers: .shift)
    let second = ShortcutCombination(keyCode: 13, modifiers: .command)
    XCTAssertNotEqual(first, second)
    let custom = WindowRule(title: "Custom", keyCode: 13, modifiers: [.control, .option])
    XCTAssertEqual(
      try JSONDecoder().decode(WindowRule.self, from: JSONEncoder().encode(custom)), custom)
  }

  func testSharedBoundariesKeepExactGuttersAfterWindowPointAlignment() {
    for x: CGFloat in [0, -1920, -500] {
      let bounds = CGRect(x: x, y: 0, width: 2560, height: 1410)
      for gap: CGFloat in [0, 1, 8, 13, 32] {
        for split in 1..<24 {
          let left = WindowGeometry.pointAligned(
            GridZone(x: 0, y: 0, width: split, height: 24).frame(in: bounds, gap: gap))
          let right = WindowGeometry.pointAligned(
            GridZone(x: split, y: 0, width: 24 - split, height: 24).frame(in: bounds, gap: gap))
          XCTAssertEqual(right.minX - left.maxX, gap)
          XCTAssertEqual(left.width, left.width.rounded())
          XCTAssertEqual(right.minX, right.minX.rounded())
        }
      }
    }
  }

}
