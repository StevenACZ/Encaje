import Foundation

public struct ShortcutModifiers: OptionSet, Codable, Hashable, Sendable {
  public let rawValue: Int
  public init(rawValue: Int) { self.rawValue = rawValue }
  public static let shift = ShortcutModifiers(rawValue: 1)
  public static let command = ShortcutModifiers(rawValue: 2)
  public static let option = ShortcutModifiers(rawValue: 4)
  public static let control = ShortcutModifiers(rawValue: 8)
}

public struct ShortcutCombination: Hashable, Sendable {
  public let keyCode: Int
  public let modifiers: ShortcutModifiers
  public init(keyCode: Int, modifiers: ShortcutModifiers) {
    self.keyCode = keyCode
    self.modifiers = modifiers
  }
}
