import AppKit
import ApplicationServices
import EncajeCore

@MainActor enum WindowBenchmarkLegacy {
  static func move(_ window: AXUIElement, application: AXUIElement, target: CGRect)
    -> Bool
  {
    _ = WindowAccessibility.attribute(application, kAXFocusedWindowAttribute)
    guard movable(window), frame(window) != nil,
      movable(window), frame(window) != nil
    else { return false }
    var size = target.size
    var point = CGPoint(x: target.minX, y: WindowAccessibility.originHeight - target.maxY)
    guard let s = AXValueCreate(.cgSize, &size), let p = AXValueCreate(.cgPoint, &point) else {
      return false
    }
    let resized = write(window, name: kAXSizeAttribute, value: s)
    let moved = write(window, name: kAXPositionAttribute, value: p)
    _ = write(window, name: kAXSizeAttribute, value: s)
    guard let actual = frame(window) else { return false }
    _ = actual
    return resized && moved
  }

  static func movable(_ window: AXUIElement) -> Bool {
    guard WindowAccessibility.string(window, kAXSubroleAttribute) == kAXStandardWindowSubrole else {
      return false
    }
    for name in [kAXPositionAttribute, kAXSizeAttribute] {
      let ok = WindowPerformanceMetrics.measure("settable") {
        var value = DarwinBoolean(false)
        return WindowPerformanceMetrics.status(
          AXUIElementIsAttributeSettable(window, name as CFString, &value)) == .success
          && value.boolValue
      }
      guard ok else { return false }
    }
    return !(WindowAccessibility.attribute(window, "AXFullScreen") as? Bool ?? false)
      && !(WindowAccessibility.attribute(window, kAXMinimizedAttribute) as? Bool ?? false)
  }

  static func frame(_ window: AXUIElement) -> CGRect? {
    guard let p = WindowAccessibility.attribute(window, kAXPositionAttribute),
      let s = WindowAccessibility.attribute(window, kAXSizeAttribute),
      CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID()
    else { return nil }
    var point = CGPoint.zero
    var size = CGSize.zero
    guard AXValueGetValue(p as! AXValue, .cgPoint, &point),
      AXValueGetValue(s as! AXValue, .cgSize, &size)
    else { return nil }
    return CGRect(
      x: point.x, y: WindowAccessibility.originHeight - point.y - size.height, width: size.width,
      height: size.height)
  }

  static func write(_ window: AXUIElement, name: String, value: CFTypeRef) -> Bool {
    WindowPerformanceMetrics.measure(name == kAXSizeAttribute ? "writeSize" : "writePosition") {
      WindowPerformanceMetrics.status(AXUIElementSetAttributeValue(window, name as CFString, value))
        == .success
    }
  }

}
