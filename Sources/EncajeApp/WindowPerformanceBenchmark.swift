import AppKit
import ApplicationServices
import EncajeCore

@MainActor enum WindowBenchmark {
  static func run(pid: pid_t) -> [String: Any] {
    guard ProcessInfo.processInfo.environment["ENCAJE_QA"] == "1",
      AXIsProcessTrusted(), let app = NSRunningApplication(processIdentifier: pid),
      app.bundleIdentifier == "com.stevenacz.Encaje.PerformanceFixture"
    else { return ["error": "Fixture allowlist or authorization check failed"] }
    let application = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(application, 0.3)
    guard
      let windows = WindowAccessibility.attribute(application, kAXWindowsAttribute)
        as? [AXUIElement],
      let window = windows.first(where: {
        WindowAccessibility.string($0, kAXTitleAttribute) == "Encaje Performance Fixture"
      }),
      let original = WindowAccessibility.snapshot(window),
      let display = WindowGeometry.display(for: original.frame, in: WindowAccessibility.displays)
    else { return ["error": "Fixture window is unavailable"] }
    defer {
      if let current = WindowAccessibility.frame(window) {
        _ = WindowAccessibility.apply(original.frame, to: window, current: current)
      }
    }
    var legacy: [WindowPerformanceMetrics.Record] = []
    var optimized: [WindowPerformanceMetrics.Record] = []
    var legacyFailures = 0
    var optimizedFailures = 0
    var resetFailures = 0
    var observations: [[String: Any]] = []
    for index in 0..<10 {
      let target = WindowGeometry.placement(
        index.isMultiple(of: 2) ? .left : .right,
        window: original.frame, bounds: display.frame, gap: 8)
      for old in index.isMultiple(of: 2) ? [true, false] : [false, true] {
        guard let before = WindowAccessibility.frame(window),
          WindowAccessibility.apply(original.frame, to: window, current: before).succeeded
        else {
          resetFailures += 1
          continue
        }
        var observation: [String: Any] = [
          "mode": old ? "legacy" : "optimized", "expected": geometry(target),
        ]
        let (success, sample) = WindowPerformanceMetrics.capture(old ? "legacy" : "optimized") {
          let accepted: Bool
          let immediate: CGRect?
          if old {
            accepted = WindowBenchmarkLegacy.move(window, application: application, target: target)
            immediate = WindowBenchmarkLegacy.frame(window)
          } else {
            _ = WindowAccessibility.attribute(application, kAXFocusedWindowAttribute)
            guard let snapshot = WindowAccessibility.snapshot(window) else { return false }
            let result = WindowAccessibility.apply(target, to: window, current: snapshot.frame)
            accepted = result.succeeded
            immediate = result.actual
          }
          observation["immediate"] = immediate.map(geometry) ?? [:]
          observation["accepted"] = accepted
          return WindowPerformanceMetrics.measure("independentVerification") {
            let first = WindowBenchmarkLegacy.frame(window)
            observation["independentInitial"] = first.map(geometry) ?? [:]
            var settled = first
            let deadline = DispatchTime.now().uptimeNanoseconds + 250_000_000
            var polls = 0
            while settled.map({ WindowGeometry.approximately($0, target) }) != true,
              DispatchTime.now().uptimeNanoseconds < deadline
            {
              Thread.sleep(forTimeInterval: 0.005)
              settled = WindowBenchmarkLegacy.frame(window)
              polls += 1
            }
            observation["settled"] = settled.map(geometry) ?? [:]
            observation["polls"] = polls
            return accepted && settled.map { WindowGeometry.approximately($0, target) } == true
          }
        }
        observations.append(observation)
        if old {
          legacy.append(sample)
          if !success { legacyFailures += 1 }
        } else {
          optimized.append(sample)
          if !success { optimizedFailures += 1 }
        }
      }
    }
    let zoneSequence = WindowBenchmarkZoneSequence.run(
      window: window, original: original.frame, display: display)
    let workspaceRoundTrip = WindowBenchmarkWorkspaceRoundTrip.run(
      window: window, original: original.frame, display: display)
    let restored = WindowAccessibility.frame(window).map {
      WindowAccessibility.apply(original.frame, to: window, current: $0)
    }
    let restoreSucceeded =
      restored?.succeeded == true
      && restored?.actual.map { WindowGeometry.approximately($0, original.frame) } == true
    return [
      "legacy": summary(legacy, failures: legacyFailures),
      "optimized": summary(optimized, failures: optimizedFailures),
      "observations": observations, "resetFailures": resetFailures, "zoneSequence": zoneSequence,
      "restoreSucceeded": restoreSucceeded, "workspaceRoundTrip": workspaceRoundTrip,
      "units": "milliseconds",
      "scope":
        "fixture AX command and independent bounded frame settling; excludes physical key delivery and compositor presentation",
    ]
  }

  private static func geometry(_ frame: CGRect) -> [String: Double] {
    ["x": frame.minX, "y": frame.minY, "width": frame.width, "height": frame.height]
  }

  private static func summary(_ records: [WindowPerformanceMetrics.Record], failures: Int)
    -> [String: Any]
  {
    let phases = Set(records.flatMap { $0.phasesMS.keys })
    return [
      "samples": records.count, "failures": failures,
      "total": distribution(records.map(\.durationMS)),
      "phases": Dictionary(
        uniqueKeysWithValues: phases.sorted().map { phase in
          (phase, distribution(records.map { $0.phasesMS[phase, default: 0] }))
        }),
      "callsPerSample": records.map { $0.calls },
      "axStatusesPerSample": records.map { $0.axStatuses },
    ]
  }

  static func distribution(_ values: [Double]) -> [String: Double] {
    let sorted = values.sorted()
    guard !sorted.isEmpty else { return [:] }
    let middle = sorted.count / 2
    let median =
      sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    return [
      "median": median, "p95": sorted[max(0, Int(ceil(Double(sorted.count) * 0.95)) - 1)],
      "max": sorted.last!,
    ]
  }
}
