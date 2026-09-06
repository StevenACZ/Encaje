import AppKit
import SwiftUI

struct PermissionAppIcon: NSViewRepresentable {
  func makeNSView(context: Context) -> PermissionDragImageView {
    let view = PermissionDragImageView()
    view.image = AppArtwork.icon
    view.imageScaling = .scaleProportionallyUpOrDown
    view.setAccessibilityLabel(
      localized(
        "Drag Encaje to the Accessibility list", "Arrastra Encaje a la lista de Accesibilidad"))
    return view
  }

  func updateNSView(_ view: PermissionDragImageView, context: Context) {}

  func sizeThatFits(_ proposal: ProposedViewSize, nsView: PermissionDragImageView, context: Context)
    -> CGSize?
  {
    CGSize(width: proposal.width ?? 58, height: proposal.height ?? 58)
  }
}

@MainActor
final class PermissionDragImageView: NSImageView, NSDraggingSource {
  private var dragging = false

  override var intrinsicContentSize: NSSize { NSSize(width: 58, height: 58) }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

  override func mouseDown(with event: NSEvent) {}

  override func mouseDragged(with event: NSEvent) {
    guard !dragging, let image else { return }
    let pasteboardItem = NSPasteboardItem()
    pasteboardItem.setString(Bundle.main.bundleURL.absoluteString, forType: .fileURL)
    let item = NSDraggingItem(pasteboardWriter: pasteboardItem)
    item.setDraggingFrame(bounds, contents: image)
    dragging = true
    let session = beginDraggingSession(with: [item], event: event, source: self)
    session.animatesToStartingPositionsOnCancelOrFail = true
  }

  func draggingSession(
    _ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext
  ) -> NSDragOperation {
    .copy
  }

  func draggingSession(
    _ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation
  ) {
    dragging = false
  }
}
