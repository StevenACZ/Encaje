import ApplicationServices
import Foundation

@MainActor enum WindowPerformanceMetrics {
  struct Record: Codable, Sendable {
    var action: String
    var durationMS: Double = 0
    var phasesMS: [String: Double] = [:]
    var calls: [String: Int] = [:]
    var axStatuses: [String: Int] = [:]
  }
  private static var record: Record?
  private static var started: UInt64 = 0
  private static let destination = ProcessInfo.processInfo.environment[
    "ENCAJE_MOVEMENT_METRICS_FILE"]
  private static let writer = DispatchQueue(label: "app.encaje.movement-metrics", qos: .utility)

  static func begin(_ action: String) {
    guard destination != nil else { return }
    started = DispatchTime.now().uptimeNanoseconds
    record = Record(action: action)
  }

  @discardableResult
  static func status(_ value: AXError) -> AXError {
    record?.axStatuses[String(value.rawValue), default: 0] += 1
    return value
  }

  static func measure<T>(_ phase: String, _ operation: () -> T) -> T {
    guard record != nil else { return operation() }
    let start = DispatchTime.now().uptimeNanoseconds
    defer {
      record?.phasesMS[phase, default: 0] +=
        Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
      record?.calls[phase, default: 0] += 1
    }
    return operation()
  }

  static func capture<T>(_ action: String, operation: () -> T) -> (T, Record) {
    let start = DispatchTime.now().uptimeNanoseconds
    record = Record(action: action)
    let result = operation()
    var completed = record ?? Record(action: action)
    completed.durationMS = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
    record = nil
    return (result, completed)
  }

  static func finish() {
    guard var completed = record, let destination else { return }
    record = nil
    completed.durationMS = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000
    guard var data = try? JSONEncoder().encode(completed) else { return }
    data.append(0x0A)
    let output = data
    writer.async {
      if !FileManager.default.fileExists(atPath: destination) {
        _ = FileManager.default.createFile(
          atPath: destination, contents: nil, attributes: [.posixPermissions: 0o600])
      }
      guard let file = FileHandle(forWritingAtPath: destination) else { return }
      defer { try? file.close() }
      do {
        try file.seekToEnd()
        try file.write(contentsOf: output)
      } catch {}
    }
  }
}
