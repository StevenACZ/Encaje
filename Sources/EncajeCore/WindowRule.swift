import Foundation

public struct WindowRule: Codable, Identifiable, Equatable, Sendable {
  public var id: String
  public var title: String
  public var action: WindowAction
  public var keyCode: Int?
  public var modifiers: ShortcutModifiers
  public var zone: GridZone?

  public init(
    id: String = UUID().uuidString, title: String = "", action: WindowAction = .center,
    keyCode: Int? = nil, modifiers: ShortcutModifiers = .shift,
    zone: GridZone? = GridZone(x: 6, y: 6, width: 12, height: 12)
  ) {
    self.id = id
    self.title = title
    self.action = action
    self.keyCode = keyCode
    self.modifiers = modifiers
    self.zone = zone?.normalized
  }

  private enum CodingKeys: String, CodingKey { case id, title, action, keyCode, modifiers, zone }

  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(String.self, forKey: .id)
    title = try values.decodeIfPresent(String.self, forKey: .title) ?? ""
    action = try values.decode(WindowAction.self, forKey: .action)
    keyCode = try values.decodeIfPresent(Int.self, forKey: .keyCode)
    modifiers = try values.decodeIfPresent(ShortcutModifiers.self, forKey: .modifiers) ?? .shift
    zone = try values.decodeIfPresent(GridZone.self, forKey: .zone)?.normalized
  }

  public static var defaults: [WindowRule] {
    let keys: [(WindowAction, Int)] = [
      (.topLeft, 12), (.up, 13), (.topRight, 14), (.left, 0), (.maximize, 1), (.right, 2),
      (.bottomLeft, 6), (.down, 7), (.bottomRight, 8),
    ]
    return keys.map {
      WindowRule(
        id: $0.0.rawValue, action: $0.0, keyCode: $0.1, zone: GridZone.defaultZone(for: $0.0))
    }
  }

  public static func migrating(_ legacy: [String: Int]?) -> [WindowRule] {
    guard let legacy else { return defaults }
    var result: [WindowRule] = []
    var assigned: Set<Int> = []
    for action in WindowAction.allCases {
      guard let code = legacy[action.rawValue], (0...Int(UInt16.max)).contains(code),
        assigned.insert(code).inserted
      else { continue }
      result.append(
        WindowRule(
          id: action.rawValue, action: action, keyCode: code,
          zone: GridZone.defaultZone(for: action)))
    }
    for rule in defaults where legacy[rule.action.rawValue] == nil {
      if let code = rule.keyCode, assigned.insert(code).inserted { result.append(rule) }
    }
    return result
  }
}
