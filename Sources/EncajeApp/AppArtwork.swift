import AppKit

@MainActor
enum AppArtwork {
  static let icon: NSImage = {
    guard let url = Bundle.main.url(forResource: "EncajeIcon", withExtension: "icns"),
      let source = NSImage(contentsOf: url)
    else {
      return NSWorkspace.shared.icon(forFile: Bundle.main.bundleURL.path)
    }
    let image = NSImage(size: NSSize(width: 256, height: 256))
    image.lockFocus()
    let rect = NSRect(x: 0, y: 0, width: 256, height: 256)
    NSBezierPath(roundedRect: rect, xRadius: 56, yRadius: 56).addClip()
    source.draw(in: rect)
    image.unlockFocus()
    return image
  }()
}
