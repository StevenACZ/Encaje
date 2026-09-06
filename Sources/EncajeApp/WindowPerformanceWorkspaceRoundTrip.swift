import AppKit
import ApplicationServices
import EncajeCore

@MainActor enum WindowBenchmarkWorkspaceRoundTrip {
  static func run(window: AXUIElement, original: CGRect, display: DisplayArea) -> [String: Any] {
    let bundleID = "com.stevenacz.Encaje.PerformanceFixture"
    let title = "Encaje Performance Fixture"
    var pid: pid_t = 0
    let applications = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    guard ProcessInfo.processInfo.environment["ENCAJE_QA"] == "1", AXIsProcessTrusted(),
      AXUIElementGetPid(window, &pid) == .success,
      applications.count == 1, let app = applications.first, app.processIdentifier == pid,
      WindowAccessibility.string(window, kAXTitleAttribute) == title
    else { return ["error": "Fixture allowlist check failed"] }
    let windows = WindowAccessibility.windows(app)
    let matching = windows.filter { WindowAccessibility.string($0, kAXTitleAttribute) == title }
    guard matching.count == 1, let matched = matching.first, CFEqual(matched, window),
      let ordinal = windows.firstIndex(where: { CFEqual($0, window) }),
      display.frame.width > 0, display.frame.height > 0
    else {
      return ["error": "Fixture window match is not unique", "matchingWindows": matching.count]
    }
    defer {
      if let current = WindowBenchmarkLegacy.frame(window) {
        _ = WindowAccessibility.apply(original, to: window, current: current)
      }
    }
    let bounds = display.frame
    let normalized = CGRect(
      x: (original.minX - bounds.minX) / bounds.width,
      y: (original.minY - bounds.minY) / bounds.height,
      width: original.width / bounds.width, height: original.height / bounds.height)
    let layout = SavedLayout(
      name: "Fixture roundtrip",
      windows: [
        SavedWindow(
          bundleID: bundleID, title: title, ordinal: ordinal,
          displayID: display.id, normalizedFrame: normalized)
      ])
    var destination = WindowGeometry.placement(
      .bottomRight, window: original, bounds: bounds, gap: 8)
    if WindowGeometry.approximately(destination, original) {
      destination = WindowGeometry.placement(.topLeft, window: original, bounds: bounds, gap: 8)
    }
    guard let snapshot = WindowAccessibility.snapshot(window) else {
      return ["moved": false, "restored": false, "matchingWindows": 1]
    }
    let applied = WindowAccessibility.apply(destination, to: window, current: snapshot.frame)
    let moved =
      applied.succeeded && settled(window, target: destination)
      && !WindowGeometry.approximately(destination, original)
    guard moved else { return ["moved": false, "restored": false, "matchingWindows": 1] }
    let engine = WindowEngine()
    engine.restoreLayout(layout, gap: 0)
    return ["moved": true, "restored": settled(window, target: original), "matchingWindows": 1]
  }

  private static func settled(_ window: AXUIElement, target: CGRect) -> Bool {
    let deadline = DispatchTime.now().uptimeNanoseconds + 250_000_000
    repeat {
      if let actual = WindowBenchmarkLegacy.frame(window),
        WindowGeometry.approximately(actual, target)
      {
        return true
      }
      Thread.sleep(forTimeInterval: 0.005)
    } while DispatchTime.now().uptimeNanoseconds < deadline
    return false
  }
}
