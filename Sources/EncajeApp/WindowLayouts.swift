import AppKit
import ApplicationServices
import EncajeCore

extension WindowEngine {
  func captureLayout(name: String) -> SavedLayout? {
    guard AXIsProcessTrusted() else {
      lastMessage = localized(
        "Accessibility permission is required.", "Se necesita permiso de Accesibilidad.")
      return nil
    }
    let displays = WindowAccessibility.displays
    var saved: [SavedWindow] = []
    for app in NSWorkspace.shared.runningApplications
    where app.activationPolicy == .regular && app.bundleIdentifier != Bundle.main.bundleIdentifier {
      guard let bundleID = app.bundleIdentifier else { continue }
      for (ordinal, window) in WindowAccessibility.windows(app).enumerated() {
        guard let frame = WindowAccessibility.frame(window),
          let display = WindowGeometry.display(for: frame, in: displays)
        else { continue }
        let b = display.frame
        let normalized = CGRect(
          x: (frame.minX - b.minX) / b.width, y: (frame.minY - b.minY) / b.height,
          width: frame.width / b.width, height: frame.height / b.height)
        saved.append(
          SavedWindow(
            bundleID: bundleID, title: WindowAccessibility.string(window, kAXTitleAttribute),
            ordinal: ordinal, displayID: display.id, normalizedFrame: normalized))
      }
    }
    if saved.isEmpty {
      lastMessage = localized(
        "No eligible windows to save.", "No hay ventanas compatibles para guardar.")
    }
    return saved.isEmpty ? nil : SavedLayout(name: name, windows: saved)
  }

  func restoreLayout(_ layout: SavedLayout, gap: CGFloat) {
    guard AXIsProcessTrusted() else {
      lastMessage = localized(
        "Accessibility permission is required.", "Se necesita permiso de Accesibilidad.")
      return
    }
    let displays = WindowAccessibility.displays
    var used: [AXUIElement] = []
    var applied = 0
    for entry in layout.windows {
      guard
        let app = NSRunningApplication.runningApplications(withBundleIdentifier: entry.bundleID)
          .first,
        let display = displays.first(where: { $0.id == entry.displayID }) ?? displays.first
      else { continue }
      let windows = WindowAccessibility.windows(app)
      let available = windows.filter { window in !used.contains(where: { CFEqual($0, window) }) }
      let titled = available.filter {
        WindowAccessibility.string($0, kAXTitleAttribute) == entry.title
      }
      let ordinal = windows.indices.contains(entry.ordinal) ? windows[entry.ordinal] : nil
      let window: AXUIElement?
      if !entry.title.isEmpty && titled.count == 1 {
        window = titled.first
      } else if entry.title.isEmpty, let ordinal,
        available.contains(where: { CFEqual($0, ordinal) })
      {
        window = ordinal
      } else {
        window = nil
      }
      guard let window else { continue }
      used.append(window)
      let b = display.frame
      let n = entry.normalizedFrame
      let g = max(0, min(gap, min(b.width, b.height) / 10))
      let w = min(max(1, n.width * b.width), b.width - 2 * g)
      let h = min(max(1, n.height * b.height), b.height - 2 * g)
      let target = CGRect(
        x: max(b.minX + g, min(b.minX + n.minX * b.width, b.maxX - g - w)),
        y: max(b.minY + g, min(b.minY + n.minY * b.height, b.maxY - g - h)), width: w, height: h)
      if move(window, to: target, verifyFeedback: false) { applied += 1 }
    }
    lastMessage = localized(
      "Applied \(applied) of \(layout.windows.count) saved windows. Applications may limit placement.",
      "Se aplicaron \(applied) de \(layout.windows.count) ventanas guardadas. Las aplicaciones pueden limitar su posición."
    )
  }
}
