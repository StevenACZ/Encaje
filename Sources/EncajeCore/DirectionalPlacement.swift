import CoreGraphics

public struct DirectionalPlacement: Sendable {
  public let action: WindowAction
  public let actualFrame: CGRect
  public let intendedFrame: CGRect
  public let display: DisplayArea
  public let gap: CGFloat

  public init(
    action: WindowAction, actualFrame: CGRect, intendedFrame: CGRect, display: DisplayArea,
    gap: CGFloat
  ) {
    self.action = action
    self.actualFrame = actualFrame
    self.intendedFrame = intendedFrame
    self.display = display
    self.gap = gap
  }

  public func geometryFrame(
    for nextAction: WindowAction, current: CGRect, displays: [DisplayArea], gap: CGFloat
  ) -> CGRect {
    guard action == nextAction, self.gap == gap, [.left, .right, .up, .down].contains(action),
      displays.contains(display), WindowGeometry.approximately(current, actualFrame)
    else { return current }
    return intendedFrame
  }
}
