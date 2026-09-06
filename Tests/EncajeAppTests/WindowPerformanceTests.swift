import ApplicationServices
import CoreGraphics
import XCTest

@testable import EncajeApp

final class WindowPerformanceTests: XCTestCase {
  func testMovePlanSkipsUnchangedOperations() {
    let current = CGRect(x: 100, y: 100, width: 800, height: 600)
    let unchanged = WindowMovePlan(current: current, target: current)
    XCTAssertFalse(unchanged.resize)
    XCTAssertFalse(unchanged.reposition)
    let moved = WindowMovePlan(current: current, target: current.offsetBy(dx: 100, dy: 0))
    XCTAssertFalse(moved.resize)
    XCTAssertTrue(moved.reposition)
  }

  func testMovePlanUsesAccessibilityTopEdgeForResize() {
    let current = CGRect(x: 100, y: 100, width: 800, height: 600)
    let anchoredTop = WindowMovePlan(
      current: current, target: CGRect(x: 100, y: 300, width: 800, height: 400))
    XCTAssertTrue(anchoredTop.resize)
    XCTAssertFalse(anchoredTop.reposition)
    let anchoredBottom = WindowMovePlan(
      current: current, target: CGRect(x: 100, y: 100, width: 800, height: 400))
    XCTAssertTrue(anchoredBottom.resize)
    XCTAssertTrue(anchoredBottom.reposition)
  }

  func testResizeClippedByOldPositionRetriesOnSameDisplay() {
    let target = CGRect(x: 8, y: 8, width: 1268, height: 1394)
    let plan = WindowMovePlan(
      current: CGRect(x: 180, y: 180, width: 800, height: 600), target: target)
    let clipped = CGRect(x: 8, y: 993, width: 1268, height: 409)
    XCTAssertTrue(plan.shouldRetrySize(target: target, observed: clipped))
    XCTAssertFalse(plan.shouldRetrySize(target: target, observed: target))
    XCTAssertFalse(plan.shouldRetrySize(target: target, observed: nil))
    let translation = WindowMovePlan(current: target.offsetBy(dx: 20, dy: 0), target: target)
    XCTAssertFalse(translation.shouldRetrySize(target: target, observed: clipped))
  }

  func testCrossDisplayReconciliationOnlyRepairsTheUnchangedClippedFrame() {
    let target = CGRect(x: 0, y: 0, width: 1173, height: 1410)
    let clipped = CGRect(x: 0, y: 212, width: 1173, height: 1198)
    XCTAssertTrue(
      WindowMovePlan.shouldReconcile(target: target, observed: clipped, current: clipped))
    XCTAssertFalse(
      WindowMovePlan.shouldReconcile(target: target, observed: clipped, current: target))
    XCTAssertFalse(
      WindowMovePlan.shouldReconcile(
        target: target, observed: clipped,
        current: clipped.offsetBy(dx: 40, dy: 20)))
    XCTAssertFalse(
      WindowMovePlan.shouldReconcile(
        target: target, observed: clipped,
        current: CGRect(x: 0, y: 0, width: 800, height: 900)))
  }

  @MainActor func testRepairsForDifferentWindowsDoNotCancelEachOther() {
    let first = AXUIElementCreateApplication(101)
    let second = AXUIElementCreateApplication(102)
    let registry = WindowMoveRegistry()
    registry.replace(first, generation: 1)
    registry.replace(second, generation: 2)
    XCTAssertTrue(registry.contains(first, generation: 1))
    XCTAssertTrue(registry.contains(second, generation: 2))
    registry.replace(first, generation: 3)
    XCTAssertFalse(registry.contains(first, generation: 1))
    registry.finish(first, generation: 1)
    XCTAssertTrue(registry.contains(first, generation: 3))
    XCTAssertTrue(registry.contains(second, generation: 2))
    registry.finish(first, generation: 3)
    XCTAssertFalse(registry.contains(first, generation: 3))
    XCTAssertTrue(registry.contains(second, generation: 2))
  }

  @MainActor func testDistributionUsesNearestRankP95AndMedian() {
    XCTAssertEqual(
      WindowBenchmark.distribution([1, 10, 2, 3]), ["median": 2.5, "p95": 10, "max": 10])
    XCTAssertEqual(WindowBenchmark.distribution([]), [:])
    XCTAssertEqual(WindowBenchmark.distribution([4]), ["median": 4, "p95": 4, "max": 4])
  }

  @MainActor func testMetricsCaptureCountsOperationsWithoutWindowContent() throws {
    let (value, record) = WindowPerformanceMetrics.capture("left") {
      WindowPerformanceMetrics.measure("readBatch") { 42 }
    }
    XCTAssertEqual(value, 42)
    XCTAssertEqual(record.calls, ["readBatch": 1])
    XCTAssertGreaterThanOrEqual(record.durationMS, 0)
    let encoded = try JSONEncoder().encode(record)
    let dictionary = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    XCTAssertEqual(
      Set(dictionary.keys), Set(["action", "durationMS", "phasesMS", "calls", "axStatuses"]))
  }
}
