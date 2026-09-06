import EncajeCore

extension WindowAction {
  var label: String {
    switch self {
    case .left: localized("Left", "Izquierda")
    case .right: localized("Right", "Derecha")
    case .up: localized("Top", "Arriba")
    case .down: localized("Bottom", "Abajo")
    case .maximize: localized("Maximize", "Maximizar")
    case .center: localized("Center", "Centrar")
    case .topLeft: localized("Top left", "Arriba a la izquierda")
    case .topRight: localized("Top right", "Arriba a la derecha")
    case .bottomLeft: localized("Bottom left", "Abajo a la izquierda")
    case .bottomRight: localized("Bottom right", "Abajo a la derecha")
    case .leftThird: localized("Left third", "Tercio izquierdo")
    case .centerThird: localized("Center third", "Tercio central")
    case .rightThird: localized("Right third", "Tercio derecho")
    case .undo: localized("Undo movement", "Deshacer movimiento")
    case .restore: localized("Restore original size", "Restaurar tamaño original")
    }
  }

  var symbol: String {
    switch self {
    case .left: "rectangle.lefthalf.filled"
    case .right: "rectangle.righthalf.filled"
    case .up: "rectangle.tophalf.filled"
    case .down: "rectangle.bottomhalf.filled"
    case .maximize: "arrow.up.left.and.arrow.down.right"
    case .center: "rectangle.center.inset.filled"
    case .topLeft, .topRight, .bottomLeft, .bottomRight: "rectangle.split.2x2"
    case .leftThird, .centerThird, .rightThird: "rectangle.split.3x1"
    case .undo: "arrow.uturn.backward"
    case .restore: "arrow.counterclockwise"
    }
  }
}

let shortcutKeys: [(name: String, code: Int)] = [
  ("A", 0), ("S", 1), ("D", 2), ("F", 3), ("H", 4), ("G", 5),
  ("Z", 6), ("X", 7), ("C", 8), ("V", 9), ("B", 11), ("Q", 12),
  ("W", 13), ("E", 14), ("R", 15), ("Y", 16), ("T", 17),
  ("O", 31), ("U", 32), ("I", 34), ("P", 35), ("L", 37),
  ("J", 38), ("K", 40), ("N", 45), ("M", 46),
  ("←", 123), ("→", 124), ("↓", 125), ("↑", 126),
]
