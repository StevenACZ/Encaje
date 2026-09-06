import AppKit
import QuartzCore

@MainActor
final class SettingsPermissionAssistant: NSObject {
  private let panel: PermissionGuidePanel
  private let locator = SettingsWindowLocator()
  private let metrics = PermissionTrackingMetrics()
  private let sourceFrame: CGRect?
  private var discoveryTimer: Timer?
  private var displayLink: CADisplayLink?
  private var presented = false
  private var entering = false
  private var completed = false

  init(sourceFrame: CGRect?, close: @escaping () -> Void) {
    self.sourceFrame = sourceFrame
    panel = PermissionGuidePanel(close: close)
    super.init()
  }

  func start() {
    discoveryTimer = Timer.scheduledTimer(
      timeInterval: 0.5, target: self,
      selector: #selector(discover), userInfo: nil, repeats: true)
    NSWorkspace.shared.notificationCenter.addObserver(
      self, selector: #selector(discover),
      name: NSWorkspace.didActivateApplicationNotification, object: nil)
    discover()
  }

  func stop() {
    discoveryTimer?.invalidate()
    discoveryTimer = nil
    stopTracking()
    NSWorkspace.shared.notificationCenter.removeObserver(self)
    panel.orderOut(nil)
    metrics.flush()
  }

  func showSuccess() {
    completed = true
    panel.guideState.success = true
  }

  @objc private func discover() {
    guard !completed else { return }
    guard let frame = locator.locate() else {
      panel.orderOut(nil)
      stopTracking()
      return
    }
    position(frame)
    guard panel.isVisible else {
      stopTracking()
      return
    }
    guard displayLink == nil else { return }
    let link = panel.displayLink(target: self, selector: #selector(track))
    link.add(to: .main, forMode: .common)
    displayLink = link
    updateRefreshRate()
  }

  @objc private func track() {
    let start = ProcessInfo.processInfo.systemUptime
    guard let frame = locator.locate() else {
      panel.orderOut(nil)
      stopTracking()
      return
    }
    let moved = position(frame)
    guard panel.isVisible else {
      stopTracking()
      return
    }
    updateRefreshRate()
    metrics.record(start: start, moved: moved)
  }

  private func stopTracking() {
    displayLink?.invalidate()
    displayLink = nil
    metrics.pause()
  }

  private func updateRefreshRate() {
    guard let displayLink else { return }
    let rate = Float(min(120, max(30, panel.screen?.maximumFramesPerSecond ?? 60)))
    if displayLink.preferredFrameRateRange.maximum != rate {
      displayLink.preferredFrameRateRange = CAFrameRateRange(
        minimum: min(60, rate), maximum: rate, preferred: rate)
    }
  }

  @discardableResult
  private func position(_ settingsFrame: CGRect) -> Bool {
    guard !entering else { return false }
    let screen =
      NSScreen.screens.max {
        $0.frame.intersection(settingsFrame).area < $1.frame.intersection(settingsFrame).area
      } ?? NSScreen.main
    guard let screen else { return false }
    let visible = screen.visibleFrame.insetBy(dx: 10, dy: 10)
    guard let target = PermissionPlacement.frame(settings: settingsFrame, visible: visible) else {
      panel.orderOut(nil)
      return false
    }
    let size = target.size
    if !presented {
      presented = true
      if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
        entering = true
        panel.alphaValue = 0
        let origin =
          sourceFrame.map {
            CGRect(
              x: $0.midX - size.width / 2,
              y: $0.midY - size.height / 2, width: size.width, height: size.height)
          }
          ?? target.offsetBy(dx: 0, dy: 12)
        panel.setFrame(origin, display: false)
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
          context.duration = 0.28
          panel.animator().setFrame(target, display: true)
          panel.animator().alphaValue = 1
        } completionHandler: { [weak self] in
          MainActor.assumeIsolated { self?.entering = false }
        }
        return true
      }
    }
    let changed = panel.frame != target
    if changed { panel.setFrame(target, display: true) }
    if !panel.isVisible { panel.orderFrontRegardless() }
    return changed
  }
}

extension CGRect {
  fileprivate var area: CGFloat { isNull ? 0 : width * height }
}
