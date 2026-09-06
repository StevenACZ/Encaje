import AppKit

@MainActor final class FixtureDelegate: NSObject, NSApplicationDelegate {
  var window: NSWindow?
  func applicationDidFinishLaunching(_ notification: Notification) {
    let window = NSWindow(contentRect: NSRect(x: 160, y: 160, width: 720, height: 460),
                          styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
    window.title = "Encaje Performance Fixture"
    window.identifier = NSUserInterfaceItemIdentifier("encaje.performance.fixture")
    let label = NSTextField(labelWithString: "Encaje • Window movement test")
    label.font = .systemFont(ofSize: 24, weight: .semibold)
    label.alignment = .center
    label.frame = NSRect(x: 20, y: 190, width: 680, height: 40)
    label.autoresizingMask = [.width, .minYMargin, .maxYMargin]
    window.contentView?.addSubview(label)
    window.isReleasedWhenClosed = false
    window.makeKeyAndOrderFront(nil)
    self.window = window
    NSApplication.shared.activate(ignoringOtherApps: true)
  }
}
let app = NSApplication.shared
let delegate = FixtureDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
