import CoreGraphics
import Foundation

public enum WindowAnimation {
  public static let duration = 0.22

  public static func progress(elapsed: Double, duration: Double = duration) -> CGFloat {
    let t = min(max(elapsed / duration, 0), 1)
    return CGFloat(1 - (1 - t) * (1 - t))
  }

  public static func frame(from start: CGRect, to end: CGRect, progress: CGFloat) -> CGRect {
    CGRect(
      x: start.minX + (end.minX - start.minX) * progress,
      y: start.minY + (end.minY - start.minY) * progress,
      width: start.width + (end.width - start.width) * progress,
      height: start.height + (end.height - start.height) * progress)
  }

  public static func resizesFirst(from previous: CGRect, to next: CGRect, within bounds: CGRect)
    -> Bool
  {
    guard previous.minX + next.width <= bounds.maxX + 0.5 else { return false }
    let resized = CGRect(
      x: previous.minX, y: previous.maxY - next.height, width: next.width, height: next.height)
    let moved = CGRect(
      x: next.minX, y: next.maxY - previous.height, width: previous.width, height: previous.height)
    return drift(resized, from: previous, to: next, within: bounds)
      <= drift(moved, from: previous, to: next, within: bounds)
  }

  private static func drift(
    _ frame: CGRect, from previous: CGRect, to next: CGRect, within bounds: CGRect
  ) -> CGFloat {
    func outside(_ value: CGFloat, _ a: CGFloat, _ b: CGFloat, _ low: CGFloat, _ high: CGFloat)
      -> CGFloat
    {
      let visible = min(max(value, low), high)
      let lower = min(max(min(a, b), low), high)
      let upper = min(max(max(a, b), low), high)
      return max(0, lower - visible, visible - upper)
    }
    return outside(frame.minX, previous.minX, next.minX, bounds.minX, bounds.maxX)
      + outside(frame.maxX, previous.maxX, next.maxX, bounds.minX, bounds.maxX)
      + outside(frame.minY, previous.minY, next.minY, bounds.minY, bounds.maxY)
      + outside(frame.maxY, previous.maxY, next.maxY, bounds.minY, bounds.maxY)
  }
}
