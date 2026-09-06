import Foundation

@MainActor
final class PermissionTrackingMetrics {
  private let destination = ProcessInfo.processInfo.environment["ENCAJE_PERMISSION_METRICS_FILE"]
  private var samples = 0
  private var updates = 0
  private var totalCost = 0.0
  private var maximumCost = 0.0
  private var previousSample: Double?
  private var maximumInterval = 0.0

  func record(start: Double, moved: Bool) {
    guard destination != nil else { return }
    let end = ProcessInfo.processInfo.systemUptime
    samples += 1
    if moved { updates += 1 }
    let cost = end - start
    totalCost += cost
    maximumCost = max(maximumCost, cost)
    if let previousSample { maximumInterval = max(maximumInterval, start - previousSample) }
    previousSample = start
  }

  func pause() {
    previousSample = nil
  }

  func flush() {
    guard let destination, samples > 0 else { return }
    let report: [String: Double] = [
      "trackingSamples": Double(samples), "positionUpdates": Double(updates),
      "meanQueryAndUpdateMilliseconds": totalCost / Double(samples) * 1_000,
      "maxQueryAndUpdateMilliseconds": maximumCost * 1_000,
      "maxSampleIntervalMilliseconds": maximumInterval * 1_000,
    ]
    guard let data = try? JSONSerialization.data(withJSONObject: report, options: .sortedKeys)
    else { return }
    try? data.write(to: URL(fileURLWithPath: destination), options: .atomic)
  }
}
