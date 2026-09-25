import AppKit
import SwiftUI
import XCTest

@testable import EncajeApp

final class PermissionIconTests: XCTestCase {
  @MainActor func testLargeArtworkDoesNotDictateDragControlSize() {
    let view = PermissionFlowDragImageView()
    view.image = NSImage(size: NSSize(width: 256, height: 256))
    XCTAssertEqual(view.intrinsicContentSize, NSSize(width: 52, height: 52))
  }

  @MainActor func testHostedDragIconStaysInsideItsProposedFrame() {
    _ = NSApplication.shared
    let hosting = NSHostingView(
      rootView: PermissionFlowDragIcon(icon: AppArtwork.icon, label: "Encaje")
        .frame(width: 52, height: 52))
    hosting.frame = NSRect(x: 0, y: 0, width: 52, height: 52)
    hosting.layoutSubtreeIfNeeded()
    func descendants(_ view: NSView) -> [NSView] {
      view.subviews.flatMap { [$0] + descendants($0) }
    }
    let icons = descendants(hosting).compactMap { $0 as? PermissionFlowDragImageView }
    XCTAssertEqual(icons.count, 1)
    XCTAssertEqual(icons.first?.frame.size, NSSize(width: 52, height: 52))
  }
}
