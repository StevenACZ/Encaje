import CoreGraphics
import XCTest

@testable import EncajeCore

final class WindowAnimationTests: XCTestCase {
  func testProgressEasesOutAndClamps() {
    XCTAssertEqual(WindowAnimation.progress(elapsed: -1), 0)
    XCTAssertEqual(WindowAnimation.progress(elapsed: 0), 0)
    XCTAssertEqual(WindowAnimation.progress(elapsed: WindowAnimation.duration), 1)
    XCTAssertEqual(WindowAnimation.progress(elapsed: 5), 1)
    let half = WindowAnimation.progress(elapsed: WindowAnimation.duration / 2)
    XCTAssertEqual(half, 0.75, accuracy: 0.0001)
    var previous: CGFloat = 0
    for step in 1...20 {
      let value = WindowAnimation.progress(elapsed: WindowAnimation.duration * Double(step) / 20)
      XCTAssertGreaterThan(value, previous)
      previous = value
    }
  }

  func testMotionIsSpreadAcrossFrames() {
    let frames = 13
    let deltas = (1...frames).map { index in
      WindowAnimation.progress(elapsed: WindowAnimation.duration * Double(index) / Double(frames))
        - WindowAnimation.progress(
          elapsed: WindowAnimation.duration * Double(index - 1) / Double(frames))
    }
    XCTAssertLessThan(deltas.max() ?? 1, 0.16)
    XCTAssertGreaterThan(deltas.filter { $0 > 0.05 }.count, 8)
  }

  func testWriteOrderKeepsVisibleEdgesFromStepping() {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 870)
    XCTAssertFalse(
      WindowAnimation.resizesFirst(
        from: CGRect(x: 0, y: 0, width: 1440, height: 870),
        to: CGRect(x: 100, y: 0, width: 1340, height: 870), within: screen))
    XCTAssertFalse(
      WindowAnimation.resizesFirst(
        from: CGRect(x: 720, y: 0, width: 720, height: 870),
        to: CGRect(x: 620, y: 0, width: 820, height: 870), within: screen))
    XCTAssertTrue(
      WindowAnimation.resizesFirst(
        from: CGRect(x: 0, y: 0, width: 660, height: 870),
        to: CGRect(x: 100, y: 0, width: 700, height: 870), within: screen))
    XCTAssertTrue(
      WindowAnimation.resizesFirst(
        from: CGRect(x: 0, y: 0, width: 660, height: 253),
        to: CGRect(x: 0, y: 0, width: 760, height: 320), within: screen))
    XCTAssertFalse(
      WindowAnimation.resizesFirst(
        from: CGRect(x: 0, y: 0, width: 1440, height: 870),
        to: CGRect(x: 90, y: 0, width: 1350, height: 800), within: screen))
  }

  func testFrameInterpolatesEveryEdge() {
    let start = CGRect(x: 0, y: 100, width: 400, height: 300)
    let end = CGRect(x: 800, y: 0, width: 1000, height: 900)
    XCTAssertEqual(WindowAnimation.frame(from: start, to: end, progress: 0), start)
    XCTAssertEqual(WindowAnimation.frame(from: start, to: end, progress: 1), end)
    XCTAssertEqual(
      WindowAnimation.frame(from: start, to: end, progress: 0.5),
      CGRect(x: 400, y: 50, width: 700, height: 600))
  }

  func testIntermediateFramesStayInsideTheSpanOfBothFrames() {
    let bounds = CGRect(x: 0, y: 0, width: 1440, height: 875)
    let start = CGRect(x: 0, y: 0, width: 720, height: 875)
    let end = CGRect(x: 960, y: 437.5, width: 480, height: 437.5)
    for step in 0...20 {
      let frame = WindowAnimation.frame(
        from: start, to: end, progress: WindowAnimation.progress(elapsed: 0.01 * Double(step)))
      XCTAssertTrue(bounds.contains(frame))
    }
  }
}
