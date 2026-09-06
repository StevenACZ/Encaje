import CoreGraphics
import Foundation

public struct GridZone: Codable, Equatable, Sendable {
  public var columns: Int
  public var rows: Int
  public var x: Int
  public var y: Int
  public var width: Int
  public var height: Int

  public init(columns: Int = 24, rows: Int = 24, x: Int, y: Int, width: Int, height: Int) {
    self.columns = columns
    self.rows = rows
    self.x = x
    self.y = y
    self.width = width
    self.height = height
  }

  public var normalized: GridZone {
    let columns = min(64, max(1, columns))
    let rows = min(64, max(1, rows))
    let x = min(columns - 1, max(0, x))
    let y = min(rows - 1, max(0, y))
    return GridZone(
      columns: columns, rows: rows, x: x, y: y,
      width: min(columns - x, max(1, width)), height: min(rows - y, max(1, height)))
  }

  public func frame(in bounds: CGRect, gap: CGFloat) -> CGRect {
    let zone = normalized
    let fractionW = CGFloat(zone.width) / CGFloat(zone.columns)
    let fractionH = CGFloat(zone.height) / CGFloat(zone.rows)
    let maximumGap = max(
      0,
      min(
        (bounds.width * fractionW - 1) / (fractionW + 1),
        (bounds.height * fractionH - 1) / (fractionH + 1)))
    let g = min(max(0, gap), maximumGap)
    let grid = bounds.insetBy(dx: g / 2, dy: g / 2)
    let cellW = grid.width / CGFloat(zone.columns)
    let cellH = grid.height / CGFloat(zone.rows)
    return CGRect(
      x: grid.minX + CGFloat(zone.x) * cellW + g / 2,
      y: grid.maxY - CGFloat(zone.y + zone.height) * cellH + g / 2,
      width: CGFloat(zone.width) * cellW - g,
      height: CGFloat(zone.height) * cellH - g)
  }

  public func mirrored(for action: WindowAction) -> GridZone {
    var zone = normalized
    switch action {
    case .left, .right: zone.x = zone.columns - zone.x - zone.width
    case .up, .down: zone.y = zone.rows - zone.y - zone.height
    default: break
    }
    return zone
  }

  public static func defaultZone(for action: WindowAction) -> GridZone? {
    switch action {
    case .left: GridZone(x: 0, y: 0, width: 11, height: 24)
    case .right: GridZone(x: 11, y: 0, width: 13, height: 24)
    case .up: GridZone(x: 0, y: 0, width: 24, height: 17)
    case .down: GridZone(x: 0, y: 17, width: 24, height: 7)
    case .maximize: GridZone(x: 0, y: 0, width: 24, height: 24)
    case .topLeft: GridZone(x: 0, y: 0, width: 11, height: 17)
    case .topRight: GridZone(x: 11, y: 0, width: 13, height: 17)
    case .bottomLeft: GridZone(x: 0, y: 17, width: 11, height: 7)
    case .bottomRight: GridZone(x: 11, y: 17, width: 13, height: 7)
    case .leftThird: GridZone(x: 0, y: 0, width: 8, height: 24)
    case .centerThird: GridZone(x: 8, y: 0, width: 8, height: 24)
    case .rightThird: GridZone(x: 16, y: 0, width: 8, height: 24)
    case .center, .undo, .restore: nil
    }
  }
}

public enum ZoneGeometry {
  public static func target(
    for action: WindowAction, zone: GridZone, window: CGRect,
    displays: [DisplayArea], gap: CGFloat, neighborZone: GridZone? = nil
  ) -> CGRect? {
    guard let current = WindowGeometry.display(for: window, in: displays) else { return nil }
    let local = zone.frame(in: current.frame, gap: gap)
    guard [.left, .right, .up, .down].contains(action), WindowGeometry.approximately(window, local),
      let next = WindowGeometry.neighbor(of: current, direction: action, displays: displays)
    else { return local }
    return (neighborZone ?? zone.mirrored(for: action)).frame(in: next.frame, gap: gap)
  }
}
