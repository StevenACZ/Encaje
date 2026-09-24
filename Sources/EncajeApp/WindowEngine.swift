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
  var animates = true
  private var movementGeneration = 0
  private let pendingMoves = WindowMoveRegistry()
  private let animator = WindowAnimator()
  private var lastDirectional:
    (
      window: AXUIElement, placement: DirectionalPlacement, zone: GridZone?, neighborZone: GridZone?
    )?

  func perform(
    _ action: WindowAction, gap: CGFloat, zone: GridZone? = nil, neighborZone: GridZone? = nil
  ) {
    WindowPerformanceMetrics.begin(action.rawValue)
    defer { WindowPerformanceMetrics.finish() }
    animator.complete()
    guard AXIsProcessTrusted() else {
      notify(
        localized(
          "Accessibility permission is required.", "Se necesita permiso de Accesibilidad."))
      return
    }
    if action == .undo {
      guard let snapshot = history.popLast() else { return }
      if let target = WindowGeometry.recovered(
        snapshot.frame, displays: WindowAccessibility.displays)
      {
        move(snapshot.window, to: target, remember: false, animated: animates)
      }
      return
    }
    guard let window = WindowAccessibility.focused(),
      let validated = WindowAccessibility.snapshot(window)
    else {
      notify(
        localized(
          "Select a movable application window.",
          "Selecciona una ventana de aplicación que se pueda mover."))
      return
    }
    let frame = validated.frame
    if action == .restore {
      guard let original = originals.first(where: { CFEqual($0.window, window) }) else { return }
      if let target = WindowGeometry.recovered(
        original.frame, displays: WindowAccessibility.displays)
      {
        move(window, to: target, validated: validated, animated: animates)
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
          neighborZone: neighborZone, animated: animates)
      }
    }
  }

  @discardableResult
  func move(
    _ window: AXUIElement, to requested: CGRect, remember: Bool = true, action: WindowAction? = nil,
    gap: CGFloat = 0, verifyFeedback: Bool = true, validated: WindowAccessibility.Snapshot? = nil,
    zone: GridZone? = nil, neighborZone: GridZone? = nil, animated: Bool = false
  ) -> Bool {
    animator.complete()
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
    let displays = WindowAccessibility.displays
    let targetDisplay = WindowGeometry.display(for: target, in: displays)
    let crossesDisplay = WindowGeometry.display(for: current, in: displays)?.id != targetDisplay?.id
    let landing = Landing(
      window: window, current: current, target: target, crossesDisplay: crossesDisplay,
      generation: movementGeneration, action: action, gap: gap, verifyFeedback: verifyFeedback,
      zone: zone, neighborZone: neighborZone)
    if animated && !crossesDisplay && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
      let bounds = targetDisplay?.frame,
      animator.animate(
        window, from: current, to: target, within: bounds,
        land: { [weak self] in self?.land(landing) })
    {
      return true
    }
    return land(landing)
  }

  private struct Landing {
    let window: AXUIElement
    let current: CGRect
    let target: CGRect
    let crossesDisplay: Bool
    let generation: Int
    let action: WindowAction?
    let gap: CGFloat
    let verifyFeedback: Bool
    let zone: GridZone?
    let neighborZone: GridZone?
  }

  @discardableResult
  private func land(_ landing: Landing) -> Bool {
    let window = landing.window
    let target = landing.target
    let generation = landing.generation
    let applied = WindowAccessibility.apply(target, to: window, current: landing.current)
    guard applied.succeeded else {
      pendingMoves.finish(window, generation: generation)
      notify(
        localized(
          "This window could not be moved or resized.",
          "No se pudo mover o redimensionar esta ventana."))
      return false
    }
    lastMessage = nil
    if let actual = applied.actual {
      remember(landing, actual: actual)
      if !landing.crossesDisplay { keepOnScreen(landing, actual: actual) }
    }
    Task { @MainActor [weak self] in
      guard let self else { return }
      defer { self.pendingMoves.finish(window, generation: generation) }
      if landing.crossesDisplay, var observed = applied.actual {
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
          if self.movementGeneration == generation { self.remember(landing, actual: actual) }
        }
      }
      try? await Task.sleep(for: .milliseconds(150))
      guard self.movementGeneration == generation,
        let actual = WindowAccessibility.frame(window)
      else { return }
      if landing.verifyFeedback && !WindowGeometry.approximately(actual, target) {
        self.notify(
          localized(
            "This application limits its window size or position.",
            "Esta aplicación limita el tamaño o la posición de su ventana."))
      }
    }
    return true
  }

  private func keepOnScreen(_ landing: Landing, actual: CGRect) {
    guard
      let display = WindowGeometry.display(for: landing.target, in: WindowAccessibility.displays),
      let fitted = WindowGeometry.recovered(actual, displays: [display]),
      !WindowGeometry.approximately(fitted, actual, tolerance: 0.5)
    else { return }
    let placed = WindowAccessibility.apply(fitted, to: landing.window, current: actual)
    if placed.succeeded, let realized = placed.actual { remember(landing, actual: realized) }
  }

  private func notify(_ message: String) {
    lastMessage = message
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(6))
      if self?.lastMessage == message { self?.lastMessage = nil }
    }
  }

  private func remember(_ landing: Landing, actual: CGRect) {
    guard let action = landing.action,
      let display = WindowGeometry.display(for: landing.target, in: WindowAccessibility.displays)
    else { return }
    lastDirectional = (
      landing.window,
      DirectionalPlacement(
        action: action, actualFrame: actual, intendedFrame: landing.target, display: display,
        gap: landing.gap), landing.zone, landing.neighborZone
    )
  }
}
