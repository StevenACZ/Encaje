import AppKit
import ApplicationServices
import EncajeCore

@MainActor enum WindowAccessibility {
  static var displays: [DisplayArea] {
    NSScreen.screens.compactMap { screen in
      guard
        let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
          as? NSNumber,
        let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue()
      else { return nil }
      return DisplayArea(id: CFUUIDCreateString(nil, uuid) as String, frame: screen.visibleFrame)
    }
  }
  static var originHeight: CGFloat { NSScreen.screens.first?.frame.maxY ?? 0 }
  struct Snapshot {
    let frame: CGRect
  }
  struct Applied {
    let succeeded: Bool
    let actual: CGRect?
  }
  static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    WindowPerformanceMetrics.measure("read") {
      var value: CFTypeRef?
      guard
        WindowPerformanceMetrics.status(
          AXUIElementCopyAttributeValue(element, name as CFString, &value)) == .success
      else { return nil }
      return value
    }
  }
  static func attributes(_ element: AXUIElement, _ names: [String]) -> [Any]? {
    WindowPerformanceMetrics.measure("readBatch") {
      var values: CFArray?
      guard
        WindowPerformanceMetrics.status(
          AXUIElementCopyMultipleAttributeValues(element, names as CFArray, [], &values))
          == .success
      else { return nil }
      return values as? [Any]
    }
  }
  static func string(_ element: AXUIElement, _ name: String) -> String {
    attribute(element, name) as? String ?? ""
  }
  static func frame(_ element: AXUIElement) -> CGRect? {
    guard let values = attributes(element, [kAXPositionAttribute, kAXSizeAttribute]) else {
      return nil
    }
    return frame(values)
  }
  private static func frame(_ values: [Any]) -> CGRect? {
    guard values.count >= 2 else { return nil }
    let p = values[0] as CFTypeRef
    let s = values[1] as CFTypeRef
    guard CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else {
      return nil
    }
    var point = CGPoint.zero
    var size = CGSize.zero
    guard AXValueGetValue(p as! AXValue, .cgPoint, &point),
      AXValueGetValue(s as! AXValue, .cgSize, &size)
    else { return nil }
    return CGRect(
      x: point.x, y: originHeight - point.y - size.height, width: size.width, height: size.height)
  }
  static func snapshot(_ window: AXUIElement) -> Snapshot? {
    guard
      let values = attributes(
        window,
        [
          kAXPositionAttribute, kAXSizeAttribute, kAXSubroleAttribute, "AXFullScreen",
          kAXMinimizedAttribute,
        ]),
      values.count == 5, values[2] as? String == kAXStandardWindowSubrole,
      !(values[3] as? Bool ?? false), !(values[4] as? Bool ?? false), let frame = frame(values)
    else { return nil }
    for name in [kAXPositionAttribute, kAXSizeAttribute] {
      let settable = WindowPerformanceMetrics.measure("settable") {
        var value = DarwinBoolean(false)
        return WindowPerformanceMetrics.status(
          AXUIElementIsAttributeSettable(window, name as CFString, &value)) == .success
          && value.boolValue
      }
      guard settable else { return nil }
    }
    return Snapshot(frame: frame)
  }
  static func apply(_ target: CGRect, to window: AXUIElement, current: CGRect) -> Applied {
    var size = target.size
    var point = CGPoint(x: target.minX, y: originHeight - target.maxY)
    guard let s = AXValueCreate(.cgSize, &size), let p = AXValueCreate(.cgPoint, &point) else {
      return Applied(succeeded: false, actual: nil)
    }
    let plan = WindowMovePlan(current: current, target: target)
    guard plan.resize || plan.reposition else { return Applied(succeeded: true, actual: current) }
    var success = true
    if plan.resize { success = write(window, name: kAXSizeAttribute, value: s) }
    if plan.reposition { success = write(window, name: kAXPositionAttribute, value: p) && success }
    var actual = frame(window)
    if plan.shouldRetrySize(target: target, observed: actual) {
      success = write(window, name: kAXSizeAttribute, value: s) && success
      actual = frame(window)
    }
    return Applied(succeeded: success, actual: actual)
  }
  private static func write(_ window: AXUIElement, name: String, value: CFTypeRef) -> Bool {
    WindowPerformanceMetrics.measure(name == kAXSizeAttribute ? "writeSize" : "writePosition") {
      WindowPerformanceMetrics.status(AXUIElementSetAttributeValue(window, name as CFString, value))
        == .success
    }
  }
  static func focused() -> AXUIElement? {
    guard let app = NSWorkspace.shared.frontmostApplication,
      app.bundleIdentifier != Bundle.main.bundleIdentifier
    else { return nil }
    let element = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(element, 0.3)
    guard let value = attribute(element, kAXFocusedWindowAttribute),
      CFGetTypeID(value) == AXUIElementGetTypeID()
    else { return nil }
    return (value as! AXUIElement)
  }
  static func windows(_ app: NSRunningApplication) -> [AXUIElement] {
    let element = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(element, 0.3)
    return (attribute(element, kAXWindowsAttribute) as? [AXUIElement] ?? []).filter { movable($0) }
  }
  static func movable(_ window: AXUIElement) -> Bool { snapshot(window) != nil }
}
