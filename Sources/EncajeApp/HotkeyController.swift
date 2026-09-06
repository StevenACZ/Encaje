import AppKit
import Carbon
import EncajeCore

@MainActor final class HotkeyController {
  var paused = false
  var excludedBundleIDs: Set<String> = []
  var bindings: [ShortcutCombination: String] = [:]
  private var tap: CFMachPort?
  private var source: CFRunLoopSource?
  private var consumed: Set<UInt16> = []
  private let onAction: (String) -> Void
  init(onAction: @escaping (String) -> Void) { self.onAction = onAction }

  func start() -> Bool {
    if let tap { return CGEvent.tapIsEnabled(tap: tap) }
    let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
    let callback: CGEventTapCallBack = { _, type, event, context in
      guard let context else { return Unmanaged.passUnretained(event) }
      let shouldPass = MainActor.assumeIsolated {
        Unmanaged<HotkeyController>.fromOpaque(context).takeUnretainedValue().handle(type, event)
          != nil
      }
      return shouldPass ? Unmanaged.passUnretained(event) : nil
    }
    guard
      let port = CGEvent.tapCreate(
        tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
        eventsOfInterest: CGEventMask(mask), callback: callback,
        userInfo: Unmanaged.passUnretained(self).toOpaque())
    else { return false }
    tap = port
    source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: port, enable: true)
    return CGEvent.tapIsEnabled(tap: port)
  }

  func stop() {
    if let tap {
      CGEvent.tapEnable(tap: tap, enable: false)
      CFMachPortInvalidate(tap)
    }
    if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
    source = nil
    tap = nil
    consumed.removeAll()
  }

  private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      consumed.removeAll()
      if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
      return Unmanaged.passUnretained(event)
    }
    let key = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
    if type == .keyUp {
      return consumed.remove(key) != nil ? nil : Unmanaged.passUnretained(event)
    }
    guard type == .keyDown else { return Unmanaged.passUnretained(event) }
    if consumed.contains(key) { return nil }
    let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
    var modifiers: ShortcutModifiers = []
    if event.flags.contains(.maskShift) { modifiers.insert(.shift) }
    if event.flags.contains(.maskCommand) { modifiers.insert(.command) }
    if event.flags.contains(.maskAlternate) { modifiers.insert(.option) }
    if event.flags.contains(.maskControl) { modifiers.insert(.control) }
    let combination = ShortcutCombination(keyCode: Int(key), modifiers: modifiers)
    guard !paused, !IsSecureEventInputEnabled(),
      bundleID != Bundle.main.bundleIdentifier, !excludedBundleIDs.contains(bundleID),
      event.getIntegerValueField(.keyboardEventAutorepeat) == 0,
      let action = bindings[combination]
    else { return Unmanaged.passUnretained(event) }
    consumed.insert(key)
    DispatchQueue.main.async { [weak self] in self?.onAction(action) }
    return nil
  }
}
