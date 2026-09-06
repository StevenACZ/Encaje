import CoreGraphics
import Foundation

public enum WindowGeometry {
  public static func display(for window: CGRect, in displays: [DisplayArea]) -> DisplayArea? {
    displays.max { a, b in
      let aa = area(window.intersection(a.frame))
      let ba = area(window.intersection(b.frame))
      return aa == ba ? distance(window, a.frame) > distance(window, b.frame) : aa < ba
    }
  }

  public static func target(
    for action: WindowAction, window: CGRect, displays: [DisplayArea], gap: CGFloat
  ) -> CGRect? {
    guard let current = display(for: window, in: displays) else { return nil }
    let local = placement(action, window: window, bounds: current.frame, gap: gap)
    guard [.left, .right, .up, .down].contains(action), approximately(window, local),
      let next = neighbor(of: current, direction: action, displays: displays)
    else { return local }
    let opposite: WindowAction =
      switch action {
      case .left: .right
      case .right: .left
      case .up: .down
      default: .up
      }
    return placement(opposite, window: window, bounds: next.frame, gap: gap)
  }

  public static func neighbor(
    of current: DisplayArea, direction: WindowAction, displays: [DisplayArea]
  ) -> DisplayArea? {
    let f = current.frame
    let candidates = displays.filter { display in
      guard display.id != current.id else { return false }
      let b = display.frame
      return switch direction {
      case .left: b.midX < f.midX && overlap(f.minY, f.maxY, b.minY, b.maxY) > 0
      case .right: b.midX > f.midX && overlap(f.minY, f.maxY, b.minY, b.maxY) > 0
      case .up: b.midY > f.midY && overlap(f.minX, f.maxX, b.minX, b.maxX) > 0
      case .down: b.midY < f.midY && overlap(f.minX, f.maxX, b.minX, b.maxX) > 0
      default: false
      }
    }
    return candidates.sorted {
      let a = distance(f, $0.frame)
      let b = distance(f, $1.frame)
      return a == b ? $0.id < $1.id : a < b
    }.first
  }

  public static func placement(_ action: WindowAction, window: CGRect, bounds: CGRect, gap: CGFloat)
    -> CGRect
  {
    let g = max(0, min(gap, min(bounds.width, bounds.height) / 10))
    let b = bounds.insetBy(dx: g, dy: g)
    let halfW = max(1, (b.width - g) / 2)
    let halfH = max(1, (b.height - g) / 2)
    let third = max(1, (b.width - 2 * g) / 3)
    switch action {
    case .left: return CGRect(x: b.minX, y: b.minY, width: halfW, height: b.height)
    case .right: return CGRect(x: b.maxX - halfW, y: b.minY, width: halfW, height: b.height)
    case .up: return CGRect(x: b.minX, y: b.maxY - halfH, width: b.width, height: halfH)
    case .down: return CGRect(x: b.minX, y: b.minY, width: b.width, height: halfH)
    case .topLeft: return CGRect(x: b.minX, y: b.maxY - halfH, width: halfW, height: halfH)
    case .topRight: return CGRect(x: b.maxX - halfW, y: b.maxY - halfH, width: halfW, height: halfH)
    case .bottomLeft: return CGRect(x: b.minX, y: b.minY, width: halfW, height: halfH)
    case .bottomRight: return CGRect(x: b.maxX - halfW, y: b.minY, width: halfW, height: halfH)
    case .leftThird: return CGRect(x: b.minX, y: b.minY, width: third, height: b.height)
    case .centerThird:
      return CGRect(x: b.minX + third + g, y: b.minY, width: third, height: b.height)
    case .rightThird: return CGRect(x: b.maxX - third, y: b.minY, width: third, height: b.height)
    case .center:
      let w = min(window.width, b.width)
      let h = min(window.height, b.height)
      return CGRect(x: b.midX - w / 2, y: b.midY - h / 2, width: w, height: h)
    case .maximize: return b
    case .undo, .restore: return window
    }
  }

  public static func recovered(_ frame: CGRect, displays: [DisplayArea]) -> CGRect? {
    guard let display = display(for: frame, in: displays) else { return nil }
    let b = display.frame
    let w = min(frame.width, display.frame.width)
    let h = min(frame.height, display.frame.height)
    return CGRect(
      x: max(b.minX, min(frame.minX, b.maxX - w)),
      y: max(b.minY, min(frame.minY, b.maxY - h)), width: w, height: h)
  }

  public static func pointAligned(_ frame: CGRect) -> CGRect {
    let x = (frame.minX + 0.000001).rounded(.down)
    let y = (frame.minY + 0.000001).rounded(.down)
    let right = (frame.maxX + 0.000001).rounded(.down)
    let top = (frame.maxY + 0.000001).rounded(.down)
    return CGRect(x: x, y: y, width: max(1, right - x), height: max(1, top - y))
  }

  public static func approximately(_ a: CGRect, _ b: CGRect, tolerance: CGFloat = 2) -> Bool {
    abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance
      && abs(a.width - b.width) <= tolerance && abs(a.height - b.height) <= tolerance
  }

  private static func area(_ rect: CGRect) -> CGFloat { rect.isNull ? 0 : rect.width * rect.height }
  private static func distance(_ a: CGRect, _ b: CGRect) -> CGFloat {
    hypot(a.midX - b.midX, a.midY - b.midY)
  }
  private static func overlap(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> CGFloat {
    min(b, d) - max(a, c)
  }
}
