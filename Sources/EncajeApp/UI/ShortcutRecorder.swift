import AppKit
import EncajeCore
import SwiftUI

struct ShortcutRecorder: NSViewRepresentable {
  let keyCode: Int?
  let modifiers: ShortcutModifiers
  var update: (Int?, ShortcutModifiers) -> Void

  func makeNSView(context: Context) -> ShortcutRecorderButton {
    let button = ShortcutRecorderButton()
    button.bezelStyle = .rounded
    button.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
    button.setAccessibilityLabel(localized("Record shortcut", "Grabar atajo"))
    button.toolTip = localized(
      "Click and press a shortcut. Escape cancels; Delete clears.",
      "Haz clic y pulsa un atajo. Escape cancela; Borrar lo elimina.")
    return button
  }

  func updateNSView(_ button: ShortcutRecorderButton, context: Context) {
    button.savedTitle =
      keyCode == nil
      ? localized("Record shortcut", "Grabar atajo")
      : ShortcutPresentation.label(keyCode: keyCode, modifiers: modifiers)
    button.update = update
    button.refreshTitle()
  }

  static func dismantleNSView(_ button: ShortcutRecorderButton, coordinator: ()) {
    button.stopRecording()
    NotificationCenter.default.removeObserver(button)
  }
}

final class ShortcutRecorderButton: NSButton {
  var savedTitle = ""
  var update: ((Int?, ShortcutModifiers) -> Void)?
  private var monitor: Any?
  private var isRecording = false

  override var acceptsFirstResponder: Bool { true }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    target = self
    action = #selector(toggleRecording)
  }

  required init?(coder: NSCoder) { nil }

  override func viewWillMove(toWindow newWindow: NSWindow?) {
    stopRecording()
    NotificationCenter.default.removeObserver(self)
    if let newWindow {
      NotificationCenter.default.addObserver(
        self, selector: #selector(windowLostFocus),
        name: NSWindow.didResignKeyNotification, object: newWindow)
    }
    super.viewWillMove(toWindow: newWindow)
  }

  override func resignFirstResponder() -> Bool {
    stopRecording()
    return super.resignFirstResponder()
  }

  func refreshTitle() {
    title = isRecording ? localized("Press shortcut…", "Pulsa un atajo…") : savedTitle
    setAccessibilityValue(title)
  }

  @objc private func windowLostFocus() { stopRecording() }

  @objc private func toggleRecording() {
    if isRecording {
      stopRecording()
      return
    }
    guard window?.makeFirstResponder(self) == true else { return }
    isRecording = true
    refreshTitle()
    monitor = NSEvent.addLocalMonitorForEvents(matching: [
      .keyDown, .leftMouseDown, .rightMouseDown,
    ]) {
      [weak self] event in
      let consumed = MainActor.assumeIsolated { self?.consume(event) ?? false }
      return consumed ? nil : event
    }
  }

  private func consume(_ event: NSEvent) -> Bool {
    guard isRecording, event.window === window else {
      stopRecording()
      return false
    }
    if event.type != .keyDown {
      if !bounds.contains(convert(event.locationInWindow, from: nil)) { stopRecording() }
      return false
    }
    guard !event.isARepeat else { return true }
    let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
    if event.keyCode == 53 && flags.isEmpty {
      stopRecording()
      return true
    }
    if flags.isEmpty && [51, 117].contains(event.keyCode) {
      stopRecording()
      update?(nil, .shift)
      return true
    }
    var modifiers: ShortcutModifiers = []
    if flags.contains(.command) { modifiers.insert(.command) }
    if flags.contains(.option) { modifiers.insert(.option) }
    if flags.contains(.control) { modifiers.insert(.control) }
    if flags.contains(.shift) { modifiers.insert(.shift) }
    stopRecording()
    update?(Int(event.keyCode), modifiers)
    return true
  }

  func stopRecording() {
    if let monitor { NSEvent.removeMonitor(monitor) }
    monitor = nil
    isRecording = false
    refreshTitle()
  }
}
