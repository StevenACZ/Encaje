import AppKit
import ApplicationServices
import Combine

@MainActor
final class PermissionCoordinator: NSObject, ObservableObject {
  @Published private(set) var granted = AXIsProcessTrusted()
  @Published private(set) var restartSuggested = false

  override init() {
    super.init()
    NSWorkspace.shared.notificationCenter.addObserver(
      self, selector: #selector(refresh),
      name: NSWorkspace.didActivateApplicationNotification, object: nil
    )
  }

  @objc func refresh() {
    let trusted = AXIsProcessTrusted()
    if granted != trusted { granted = trusted }
    if !trusted && restartSuggested { restartSuggested = false }
  }

  func markRestartNeeded() {
    refresh()
    restartSuggested = granted
  }
}
