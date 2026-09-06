import AppKit

@MainActor
final class SettingsWindowLocator {
  private var windowID: CGWindowID?
  private var ownerPID: pid_t?

  func locate() -> CGRect? {
    guard let app = NSWorkspace.shared.frontmostApplication,
      app.bundleIdentifier == "com.apple.systempreferences"
    else { return nil }
    if app.processIdentifier != ownerPID {
      ownerPID = app.processIdentifier
      windowID = nil
    }
    if let windowID,
      let windows = CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID)
        as? [[String: Any]],
      let window = windows.first, let frame = frame(of: window, pid: app.processIdentifier)
    {
      return frame
    }
    windowID = nil
    guard
      let windows = CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
    else { return nil }
    for window in windows {
      if let frame = frame(of: window, pid: app.processIdentifier) {
        windowID = (window[kCGWindowNumber as String] as? NSNumber)?.uint32Value
        return frame
      }
    }
    return nil
  }

  private func frame(of window: [String: Any], pid: pid_t) -> CGRect? {
    guard (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
      (window[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
      (window[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue == true,
      let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
      let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary),
      frame.width > 300, frame.height > 250
    else { return nil }
    let top = NSScreen.screens.first?.frame.maxY ?? 0
    return CGRect(x: frame.minX, y: top - frame.maxY, width: frame.width, height: frame.height)
  }
}
