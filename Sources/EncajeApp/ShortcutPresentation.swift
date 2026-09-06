import EncajeCore

@MainActor
enum ShortcutPresentation {
  static func keyName(code: Int) -> String {
    if let letter = shortcutKeys.first(where: { $0.code == code })?.name { return letter }
    let special = [
      18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 25: "9", 26: "7", 28: "8", 29: "0",
      24: "=", 27: "-", 30: "]", 33: "[", 39: "'", 41: ";", 42: "\\", 43: ",", 44: "/", 47: ".",
      50: "`",
      36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋", 76: "⌤", 117: "⌦", 115: "↖", 119: "↘",
      116: "⇞", 121: "⇟",
      122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9",
      109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17",
      79: "F18", 80: "F19", 90: "F20",
    ]
    return special[code] ?? "Key \(code)"
  }

  static func label(keyCode: Int?, modifiers: ShortcutModifiers) -> String {
    guard let keyCode else { return localized("Record shortcut", "Grabar atajo") }
    var text = ""
    if modifiers.contains(.control) { text += "⌃ " }
    if modifiers.contains(.option) { text += "⌥ " }
    if modifiers.contains(.shift) { text += "⇧ " }
    if modifiers.contains(.command) { text += "⌘ " }
    return text + keyName(code: keyCode)
  }
}
