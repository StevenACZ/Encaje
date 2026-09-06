public struct ZoneEditHistory: Sendable {
  public struct Entry: Equatable, Sendable {
    public let ruleID: String
    public let before: GridZone?
    public let after: GridZone?
  }

  private var undoEntries: [Entry] = []
  private var redoEntries: [Entry] = []

  public init() {}

  public var canUndo: Bool { !undoEntries.isEmpty }
  public var canRedo: Bool { !redoEntries.isEmpty }

  public mutating func record(ruleID: String, before: GridZone?, after: GridZone?) {
    let before = before?.normalized
    let after = after?.normalized
    guard before != after else { return }
    undoEntries.append(Entry(ruleID: ruleID, before: before, after: after))
    if undoEntries.count > 100 {
      undoEntries.removeFirst(undoEntries.count - 100)
    }
    redoEntries.removeAll()
  }

  public mutating func undo() -> Entry? {
    guard let entry = undoEntries.popLast() else { return nil }
    redoEntries.append(entry)
    return entry
  }

  public mutating func redo() -> Entry? {
    guard let entry = redoEntries.popLast() else { return nil }
    undoEntries.append(entry)
    return entry
  }

  public mutating func remove(ruleID: String) {
    undoEntries.removeAll { $0.ruleID == ruleID }
    redoEntries.removeAll { $0.ruleID == ruleID }
  }

  public mutating func clear() {
    undoEntries.removeAll()
    redoEntries.removeAll()
  }
}
