import AppKit
import ApplicationServices
import EncajeCore

@MainActor final class WindowEngine: ObservableObject {
  @Published var lastMessage: String?
  struct Snapshot {
    let window: AXUIElement
    let frame: CGRect
  }
  var originals: [Snapshot] = []
  var history: [Snapshot] = []
  private var movementGeneration = 0
  private let pendingMoves = WindowMoveRegistry()
  private var lastDirectional:
    (
      window: AXUIElement, placement: DirectionalPlacement, zone: GridZone?, neighborZone: GridZone?
    )?

  func perform(
    _ action: WindowAction, gap: CGFloat, zone: GridZone? = nil, neighborZone: GridZone? = nil
  ) {
    WindowPerformanceMetrics.begin(action.rawValue)
    defer { WindowPerformanceMetrics.finish() }
    guard AXIsProcessTrusted() else {
      lastMessage = localized(
        "Accessibility permission is required.", "Se necesita permiso de Accesibilidad.")
      return
    }
    if action == .undo {
      guard let snapshot = history.popLast() else { return }
      if let target = WindowGeometry.recovered(
        snapshot.frame, displays: WindowAccessibility.displays)
      {
        move(snapshot.window, to: target, remember: false)
      }
      return
    }
    guard let window = WindowAccessibility.focused(),
      let validated = WindowAccessibility.snapshot(window)
    else {
      lastMessage = localized(
        "Select a movable application window.",
        "Selecciona una ventana de aplicación que se pueda mover.")
      return
    }
    let frame = validated.frame
    if action == .restore {
      guard let original = originals.first(where: { CFEqual($0.window, window) }) else { return }
      if let target = WindowGeometry.recovered(
        original.frame, displays: WindowAccessibility.displays)
      {
        move(window, to: target, validated: validated)
      }
    } else {
      let displays = WindowAccessibility.displays
      let previous = lastDirectional.flatMap {
        CFEqual($0.window, window) && $0.zone == zone && $0.neighborZone == neighborZone
          ? $0.placement : nil
      }
      let geometryFrame =
        previous?.geometryFrame(for: action, current: frame, displays: displays, gap: gap) ?? frame
      let target =
        zone.map {
          ZoneGeometry.target(
            for: action, zone: $0, window: geometryFrame, displays: displays, gap: gap,
            neighborZone: neighborZone)
        }
        ?? WindowGeometry.target(for: action, window: geometryFrame, displays: displays, gap: gap)
      if let target {
        move(
          window, to: target, action: action, gap: gap, validated: validated, zone: zone,
          neighborZone: neighborZone)
      }
    }
  }

  @discardableResult
  func move(
    _ window: AXUIElement, to requested: CGRect, remember: Bool = true, action: WindowAction? = nil,
    gap: CGFloat = 0, verifyFeedback: Bool = true, validated: WindowAccessibility.Snapshot? = nil,
    zone: GridZone? = nil, neighborZone: GridZone? = nil
  ) -> Bool {
    let target = WindowGeometry.pointAligned(requested)
    guard let validated = validated ?? WindowAccessibility.snapshot(window) else { return false }
    let current = validated.frame
    movementGeneration += 1
    pendingMoves.replace(window, generation: movementGeneration)
    lastDirectional = nil
    let plan = WindowMovePlan(current: current, target: target)
    if !plan.resize && !plan.reposition {
      pendingMoves.finish(window, generation: movementGeneration)
      lastMessage = nil
      return true
    }
    if remember {
      if !originals.contains(where: { CFEqual($0.window, window) }) {
        originals.append(Snapshot(window: window, frame: current))
      }
      history.append(Snapshot(window: window, frame: current))
      if history.count > 100 { history.removeFirst() }
      if originals.count > 200 { originals.removeFirst() }
    }
    let applied = WindowAccessibility.apply(target, to: window, current: current)
    guard applied.succeeded else {
      pendingMoves.finish(window, generation: movementGeneration)
      lastMessage = localized(
        "This window could not be moved or resized.",
        "No se pudo mover o redimensionar esta ventana.")
      return false
    }
    lastMessage = nil
    if let action, let actual = applied.actual,
      let display = WindowGeometry.display(for: target, in: WindowAccessibility.displays)
    {
      lastDirectional = (
        window,
        DirectionalPlacement(
          action: action, actualFrame: actual,
          intendedFrame: target, display: display, gap: gap), zone, neighborZone
      )
    }
    let generation = movementGeneration
    let displays = WindowAccessibility.displays
    let crossesDisplay =
      WindowGeometry.display(for: current, in: displays)?.id
      != WindowGeometry.display(for: target, in: displays)?.id
    Task { @MainActor [weak self] in
      guard let self else { return }
      defer { self.pendingMoves.finish(window, generation: generation) }
      if crossesDisplay, var observed = applied.actual {
        for delay in [30, 60] {
          if WindowGeometry.approximately(observed, target) { break }
          try? await Task.sleep(for: .milliseconds(delay))
          guard self.pendingMoves.contains(window, generation: generation),
            let settled = WindowAccessibility.frame(window),
            WindowMovePlan.shouldReconcile(target: target, observed: observed, current: settled)
          else { return }
          let corrected = WindowAccessibility.apply(target, to: window, current: settled)
          guard corrected.succeeded, let actual = corrected.actual else { return }
          observed = actual
          if self.movementGeneration == generation, let action,
            let display = WindowGeometry.display(for: target, in: WindowAccessibility.displays)
          {
            self.lastDirectional = (
              window,
              DirectionalPlacement(
                action: action, actualFrame: actual, intendedFrame: target,
                display: display, gap: gap), zone, neighborZone
            )
          }
        }
      }
      try? await Task.sleep(for: .milliseconds(150))
      guard self.movementGeneration == generation,
        let actual = WindowAccessibility.frame(window)
      else { return }
      if verifyFeedback && !WindowGeometry.approximately(actual, target) {
        self.lastMessage = localized(
          "This application limits its window size or position.",
          "Esta aplicación limita el tamaño o la posición de su ventana.")
      }
    }
    return true
  }
}
