import AppKit

@MainActor
enum MenuBarGlyph {
  static let image: NSImage = {
    let image = NSImage(size: NSSize(width: 18, height: 18))
    image.lockFocus()
    NSColor.black.setFill()
    for rect in [
      NSRect(x: 1, y: 1, width: 7, height: 7),
      NSRect(x: 1, y: 10, width: 7, height: 7),
      NSRect(x: 10, y: 1, width: 7, height: 16),
    ] {
      NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2).fill()
    }
    image.unlockFocus()
    image.isTemplate = true
    image.accessibilityDescription = "Encaje"
    return image
  }()
}
