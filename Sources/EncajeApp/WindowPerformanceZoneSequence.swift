import AppKit
import ApplicationServices
import EncajeCore

@MainActor enum WindowBenchmarkZoneSequence {
  static func run(window: AXUIElement, original: CGRect, display: DisplayArea) -> [String: Any] {
    var pid: pid_t = 0
    guard ProcessInfo.processInfo.environment["ENCAJE_QA"] == "1",
      AXUIElementGetPid(window, &pid) == .success,
      NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
        == "com.stevenacz.Encaje.PerformanceFixture",
      WindowAccessibility.string(window, kAXTitleAttribute) == "Encaje Performance Fixture"
    else { return ["error": "Fixture allowlist check failed"] }
    guard let initial = WindowAccessibility.snapshot(window),
      WindowAccessibility.apply(original, to: window, current: initial.frame).succeeded,
      settled(window, target: original).matches
    else { return ["error": "Fixture reset failed"] }
    var observations: [[String: Any]] = []
    var failures = 0
    let sequence: [WindowAction] = [.bottomLeft, .topLeft, .topRight, .bottomLeft, .topLeft]
    for action in sequence {
      guard let zone = GridZone.defaultZone(for: action) else { continue }
      let target = zone.frame(in: display.frame, gap: 8)
      var observation: [String: Any] = ["action": action.rawValue, "expected": geometry(target)]
      let (success, metrics) = WindowPerformanceMetrics.capture(action.rawValue) {
        guard let snapshot = WindowAccessibility.snapshot(window) else { return false }
        let result = WindowAccessibility.apply(target, to: window, current: snapshot.frame)
        observation["immediate"] = result.actual.map(geometry) ?? [:]
        observation["accepted"] = result.succeeded
        return WindowPerformanceMetrics.measure("independentVerification") {
          let verified = settled(window, target: target)
          observation["settled"] = verified.frame.map(geometry) ?? [:]
          observation["polls"] = verified.polls
          return result.succeeded && verified.matches
        }
      }
      let withinCorrectionBudget =
        metrics.calls["writeSize", default: 0] <= 2
        && metrics.calls["writePosition", default: 0] <= 1
      observation["success"] = success && withinCorrectionBudget
      observation["oneCommand"] = true
      observation["withinCorrectionBudget"] = withinCorrectionBudget
      observation["durationMS"] = metrics.durationMS
      observation["calls"] = metrics.calls
      observation["axStatuses"] = metrics.axStatuses
      observations.append(observation)
      if !success || !withinCorrectionBudget { failures += 1 }
    }
    let reset = WindowAccessibility.snapshot(window).map {
      WindowAccessibility.apply(original, to: window, current: $0.frame)
    }
    let restored = settled(window, target: original)
    return [
      "samples": observations.count, "failures": failures, "observations": observations,
      "restoreSucceeded": reset?.succeeded == true && restored.matches,
      "scope": "single-command Z Q E Z Q default zones; fixture only; independent AX verification",
    ]
  }

  private static func settled(_ window: AXUIElement, target: CGRect) -> (
    frame: CGRect?, matches: Bool, polls: Int
  ) {
    var actual = WindowBenchmarkLegacy.frame(window)
    let deadline = DispatchTime.now().uptimeNanoseconds + 250_000_000
    var polls = 0
    while actual.map({ WindowGeometry.approximately($0, target) }) != true,
      DispatchTime.now().uptimeNanoseconds < deadline
    {
      Thread.sleep(forTimeInterval: 0.005)
      actual = WindowBenchmarkLegacy.frame(window)
      polls += 1
    }
    return (actual, actual.map { WindowGeometry.approximately($0, target) } == true, polls)
  }

  private static func geometry(_ frame: CGRect) -> [String: Double] {
    ["x": frame.minX, "y": frame.minY, "width": frame.width, "height": frame.height]
  }
}
