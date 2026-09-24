import AppKit
import ApplicationServices
import EncajeCore
import QuartzCore

@MainActor final class WindowAnimator: NSObject {
  private struct Run {
    let window: AXUIElement
    let from: CGRect
    let to: CGRect
    let started: CFTimeInterval
    var last: CGRect
    let bounds: CGRect
    let enhancedApp: AXUIElement?
    let land: () -> Void
    var steps = 0
    var busy: CFTimeInterval = 0
    var slowest: CFTimeInterval = 0
  }
  static let slowStep = 0.04
  private var run: Run?
  private var link: CADisplayLink?
  private var generation = 0

  func animate(
    _ window: AXUIElement, from: CGRect, to: CGRect, within bounds: CGRect,
    land: @escaping () -> Void
  ) -> Bool {
    complete()
    let center = CGPoint(x: to.midX, y: to.midY)
    guard let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) ?? NSScreen.main
    else { return false }
    let link = screen.displayLink(target: self, selector: #selector(step))
    let rate = Float(min(120, max(60, screen.maximumFramesPerSecond)))
    link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: rate, preferred: rate)
    run = Run(
      window: window, from: from, to: to, started: CACurrentMediaTime(), last: from,
      bounds: bounds,
      enhancedApp: WindowAccessibility.suspendEnhancedUserInterface(of: window), land: land)
    link.add(to: .main, forMode: .common)
    self.link = link
    generation += 1
    let current = generation
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(WindowAnimation.duration + 0.25))
      guard let self, self.generation == current else { return }
      self.complete()
    }
    return true
  }

  func complete(finished: Bool = false) {
    link?.invalidate()
    link = nil
    guard let run else { return }
    self.run = nil
    run.land()
    if let app = run.enhancedApp { WindowAccessibility.resumeEnhancedUserInterface(of: app) }
    guard WindowPerformanceMetrics.enabled else { return }
    var record = WindowPerformanceMetrics.Record(action: "animate")
    record.durationMS = (CACurrentMediaTime() - run.started) * 1000
    record.calls = ["step": run.steps, "finished": finished ? 1 : 0]
    record.phasesMS = ["step": run.busy * 1000, "slowestStep": run.slowest * 1000]
    WindowPerformanceMetrics.write(record)
  }

  @objc private func step(_ link: CADisplayLink) {
    guard var run else { return }
    let progress = WindowAnimation.progress(elapsed: link.targetTimestamp - run.started)
    guard progress < 1 else { return complete(finished: true) }
    let frame = WindowGeometry.pointAligned(
      WindowAnimation.frame(from: run.from, to: run.to, progress: progress))
    let started = CACurrentMediaTime()
    let placed = WindowAccessibility.place(
      frame, on: run.window, from: run.last,
      resizeFirst: WindowAnimation.resizesFirst(from: run.last, to: frame, within: run.bounds))
    let elapsed = CACurrentMediaTime() - started
    run.last = frame
    run.steps += 1
    run.busy += elapsed
    run.slowest = max(run.slowest, elapsed)
    self.run = run
    if !placed || elapsed > Self.slowStep { complete() }
  }
}
