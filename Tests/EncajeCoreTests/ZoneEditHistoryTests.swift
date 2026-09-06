import XCTest

@testable import EncajeCore

final class ZoneEditHistoryTests: XCTestCase {
  private let first = GridZone(x: 0, y: 0, width: 8, height: 24)
  private let second = GridZone(x: 0, y: 0, width: 12, height: 24)

  func testMultipleEditsUndoAndRedoInOrderIncludingNilGeometry() throws {
    var history = ZoneEditHistory()
    XCTAssertFalse(history.canUndo)
    XCTAssertFalse(history.canRedo)
    XCTAssertNil(history.undo())
    XCTAssertNil(history.redo())

    history.record(ruleID: "left", before: nil, after: first)
    history.record(ruleID: "left", before: first, after: second)
    history.record(ruleID: "right", before: second, after: nil)

    let removal = try XCTUnwrap(history.undo())
    XCTAssertEqual(removal.ruleID, "right")
    XCTAssertEqual(removal.before, second)
    XCTAssertNil(removal.after)
    let resize = try XCTUnwrap(history.undo())
    XCTAssertEqual(resize.before, first)
    XCTAssertEqual(resize.after, second)
    let creation = try XCTUnwrap(history.undo())
    XCTAssertNil(creation.before)
    XCTAssertEqual(creation.after, first)
    XCTAssertFalse(history.canUndo)
    XCTAssertTrue(history.canRedo)
    XCTAssertNil(history.undo())

    XCTAssertEqual(history.redo(), creation)
    XCTAssertEqual(history.redo(), resize)
    XCTAssertEqual(history.redo(), removal)
    XCTAssertTrue(history.canUndo)
    XCTAssertFalse(history.canRedo)
    XCTAssertNil(history.redo())
  }

  func testNormalizedNoOpPreservesRedoAndEntriesStoreNormalizedGeometry() throws {
    var history = ZoneEditHistory()
    let invalid = GridZone(columns: -1, rows: 999, x: 99, y: -5, width: -4, height: 999)
    history.record(ruleID: "left", before: invalid, after: first)
    let entry = try XCTUnwrap(history.undo())
    XCTAssertEqual(entry.before, invalid.normalized)
    history.record(ruleID: "left", before: invalid, after: invalid.normalized)
    history.record(ruleID: "right", before: nil, after: nil)
    XCTAssertFalse(history.canUndo)
    XCTAssertEqual(history.redo(), entry)

    history.record(ruleID: "left", before: first, after: invalid)
    XCTAssertEqual(history.undo()?.after, invalid.normalized)
  }

  func testNewEditAfterUndoDiscardsRedo() {
    var history = ZoneEditHistory()
    history.record(ruleID: "left", before: nil, after: first)
    history.record(ruleID: "left", before: first, after: second)
    _ = history.undo()
    history.record(ruleID: "right", before: nil, after: second)
    XCTAssertFalse(history.canRedo)
    XCTAssertNil(history.redo())
    XCTAssertEqual(history.undo()?.ruleID, "right")
    XCTAssertEqual(history.undo()?.after, first)
    XCTAssertNil(history.undo())
  }

  func testHistoryRetainsNewestHundredEditsAcrossUndoAndRedo() {
    var history = ZoneEditHistory()
    for index in 0..<105 {
      history.record(ruleID: String(index), before: nil, after: first)
    }
    for index in (5..<105).reversed() {
      XCTAssertEqual(history.undo()?.ruleID, String(index))
    }
    XCTAssertNil(history.undo())
    for index in 5..<105 {
      XCTAssertEqual(history.redo()?.ruleID, String(index))
    }
    XCTAssertNil(history.redo())
    history.record(ruleID: "new", before: nil, after: second)
    XCTAssertEqual(history.undo()?.ruleID, "new")
    for index in (6..<105).reversed() {
      XCTAssertEqual(history.undo()?.ruleID, String(index))
    }
    XCTAssertNil(history.undo())
  }

  func testRemoveDropsMatchingRuleFromBothStacksAndPreservesOtherOrder() {
    var history = ZoneEditHistory()
    for ruleID in ["keepFirst", "remove", "keepSecond", "remove", "keepThird"] {
      history.record(ruleID: ruleID, before: nil, after: first)
    }
    for _ in 0..<3 { _ = history.undo() }
    history.remove(ruleID: "missing")
    history.remove(ruleID: "remove")
    XCTAssertEqual(history.redo()?.ruleID, "keepSecond")
    XCTAssertEqual(history.redo()?.ruleID, "keepThird")
    XCTAssertNil(history.redo())
    XCTAssertEqual(history.undo()?.ruleID, "keepThird")
    XCTAssertEqual(history.undo()?.ruleID, "keepSecond")
    XCTAssertEqual(history.undo()?.ruleID, "keepFirst")
    XCTAssertNil(history.undo())
  }

  func testClearResetsBothStacksWithoutChangingCopiedHistory() {
    var history = ZoneEditHistory()
    history.record(ruleID: "left", before: nil, after: first)
    history.record(ruleID: "right", before: nil, after: second)
    _ = history.undo()
    var copy = history
    history.clear()
    XCTAssertFalse(history.canUndo)
    XCTAssertFalse(history.canRedo)
    XCTAssertNil(history.undo())
    XCTAssertNil(history.redo())
    XCTAssertEqual(copy.undo()?.ruleID, "left")
    XCTAssertEqual(copy.redo()?.ruleID, "left")
    XCTAssertEqual(copy.redo()?.ruleID, "right")
  }
}
