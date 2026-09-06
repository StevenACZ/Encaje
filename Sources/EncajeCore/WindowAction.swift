import CoreGraphics
import Foundation

public enum WindowAction: String, CaseIterable, Codable, Sendable {
  case left, right, up, down, maximize, center, topLeft, topRight, bottomLeft, bottomRight
  case leftThird, centerThird, rightThird, undo, restore
}

public struct DisplayArea: Sendable, Equatable {
  public let id: String
  public let frame: CGRect
  public init(id: String, frame: CGRect) {
    self.id = id
    self.frame = frame
  }
}

public struct SavedLayout: Codable, Identifiable, Sendable {
  public let id: UUID
  public var name: String
  public var windows: [SavedWindow]
  public init(id: UUID = UUID(), name: String, windows: [SavedWindow]) {
    self.id = id
    self.name = name
    self.windows = windows
  }
}

public struct SavedWindow: Codable, Sendable {
  public let bundleID: String
  public let title: String
  public let ordinal: Int
  public let displayID: String
  public let normalizedFrame: CGRect
  public init(
    bundleID: String, title: String, ordinal: Int, displayID: String, normalizedFrame: CGRect
  ) {
    self.bundleID = bundleID
    self.title = title
    self.ordinal = ordinal
    self.displayID = displayID
    self.normalizedFrame = normalizedFrame
  }
}
