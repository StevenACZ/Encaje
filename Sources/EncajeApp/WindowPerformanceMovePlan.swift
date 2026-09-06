import CoreGraphics
import EncajeCore

struct WindowMovePlan {
  let resize: Bool
  let reposition: Bool

  init(current: CGRect, target: CGRect) {
    resize = abs(target.width - current.width) > 0.5 || abs(target.height - current.height) > 0.5
    reposition = abs(target.minX - current.minX) > 0.5 || abs(target.maxY - current.maxY) > 0.5
  }
  func shouldRetrySize(target: CGRect, observed: CGRect?) -> Bool {
    guard resize, let observed else { return false }
    return abs(observed.width - target.width) > 0.5 || abs(observed.height - target.height) > 0.5
  }
  static func shouldReconcile(target: CGRect, observed: CGRect, current: CGRect) -> Bool {
    !WindowGeometry.approximately(current, target)
      && WindowGeometry.approximately(current, observed)
  }

}
