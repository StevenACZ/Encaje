import ApplicationServices

@MainActor
final class WindowMoveRegistry {
  private var pending: [(window: AXUIElement, generation: Int)] = []

  func replace(_ window: AXUIElement, generation: Int) {
    pending.removeAll { CFEqual($0.window, window) }
    pending.append((window, generation))
  }

  func contains(_ window: AXUIElement, generation: Int) -> Bool {
    pending.contains { $0.generation == generation && CFEqual($0.window, window) }
  }

  func finish(_ window: AXUIElement, generation: Int) {
    pending.removeAll { $0.generation == generation && CFEqual($0.window, window) }
  }
}
