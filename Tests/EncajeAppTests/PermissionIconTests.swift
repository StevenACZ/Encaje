import AppKit
import SwiftUI
import XCTest

@testable import EncajeApp

final class PermissionIconTests: XCTestCase {
  @MainActor func testLargeArtworkDoesNotDictateDragControlSize() {
    let view = PermissionDragImageView()
    view.image = NSImage(size: NSSize(width: 256, height: 256))
    XCTAssertEqual(view.intrinsicContentSize, NSSize(width: 58, height: 58))
  }

  @MainActor func testHostedDragIconStaysInsideItsProposedFrame() {
    _ = NSApplication.shared
    let hosting = NSHostingView(rootView: PermissionAppIcon().frame(width: 58, height: 58))
    hosting.frame = NSRect(x: 0, y: 0, width: 58, height: 58)
    hosting.layoutSubtreeIfNeeded()
    func descendants(_ view: NSView) -> [NSView] {
      view.subviews.flatMap { [$0] + descendants($0) }
    }
    let icons = descendants(hosting).compactMap { $0 as? PermissionDragImageView }
    XCTAssertEqual(icons.count, 1)
    XCTAssertEqual(icons.first?.frame.size, NSSize(width: 58, height: 58))
  }
}
