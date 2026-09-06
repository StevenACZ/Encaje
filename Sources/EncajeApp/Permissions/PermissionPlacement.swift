import CoreGraphics

struct PermissionPlacement {
  static func frame(settings: CGRect, visible: CGRect) -> CGRect? {
    let sidebar = min(240, max(180, settings.width * 0.31))
    let left = max(settings.minX + sidebar + 20, visible.minX)
    let right = min(settings.maxX - 20, visible.maxX)
    let bottom = max(settings.minY + 20, visible.minY)
    let top = min(settings.maxY - 20, visible.maxY)
    guard right - left >= 200, top - bottom >= 128 else { return nil }
    return CGRect(
      x: left.rounded(.up), y: bottom.rounded(.up),
      width: right.rounded(.down) - left.rounded(.up), height: 128)
  }
}
