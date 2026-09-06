import AppKit
import ApplicationServices
import Combine

@MainActor
final class PermissionCoordinator: NSObject, ObservableObject {
  @Published private(set) var granted = AXIsProcessTrusted()
  @Published private(set) var restartSuggested = false
  @Published private(set) var guiding = false
  private let defaults: UserDefaults
  private var assistant: SettingsPermissionAssistant?
  private var permissionTimer: Timer?

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    super.init()
    NSWorkspace.shared.notificationCenter.addObserver(
      self, selector: #selector(refresh),
      name: NSWorkspace.didActivateApplicationNotification, object: nil
    )
  }

  @objc func refresh() {
    let trusted = AXIsProcessTrusted()
    let newlyGranted = trusted && !granted
    if granted != trusted { granted = trusted }
    if newlyGranted && guiding {
      assistant?.showSuccess()
      permissionTimer?.invalidate()
      permissionTimer = Timer.scheduledTimer(
        timeInterval: 1.1, target: self, selector: #selector(dismiss),
        userInfo: nil, repeats: false
      )
    }
    if !trusted && restartSuggested { restartSuggested = false }
  }

  func request(from sourceFrame: CGRect? = nil) {
    dismiss()
    refresh()
    guard !granted else { return }
    defaults.set(true, forKey: "permissionSetupPending")
    guiding = true
    assistant = SettingsPermissionAssistant(sourceFrame: sourceFrame) { [weak self] in
      self?.dismiss()
    }
    assistant?.start()
    if let url = URL(
      string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    {
      NSWorkspace.shared.open(url)
    }
    permissionTimer = Timer.scheduledTimer(
      timeInterval: 0.5, target: self, selector: #selector(refresh),
      userInfo: nil, repeats: true
    )
  }

  @objc func dismiss() {
    permissionTimer?.invalidate()
    permissionTimer = nil
    assistant?.stop()
    assistant = nil
    guiding = false
  }

  func completeSetup() {
    defaults.removeObject(forKey: "permissionSetupPending")
  }

  func markRestartNeeded() {
    refresh()
    restartSuggested = granted
  }

  func restartApplication() {
    guard restartSuggested, Bundle.main.bundleURL.pathExtension == "app" else { return }
    defaults.set(true, forKey: "permissionSetupPending")
    defaults.synchronize()
    let helper = Process()
    helper.executableURL = URL(fileURLWithPath: "/bin/sh")
    helper.arguments = [
      "-c", "while kill -0 \"$1\" 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$2\"",
      "encaje-relaunch", String(ProcessInfo.processInfo.processIdentifier),
      Bundle.main.bundleURL.path,
    ]
    helper.standardInput = FileHandle.nullDevice
    helper.standardOutput = FileHandle.nullDevice
    helper.standardError = FileHandle.nullDevice
    do {
      try helper.run()
      NSApp.terminate(nil)
    } catch {
      restartSuggested = true
    }
  }
}
