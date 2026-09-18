import AppKit
import Combine
import SwiftUI

@MainActor
final class AboutWindowController {
  private var window: NSWindow?
  private var layoutObserver: AnyCancellable?

  func show() {
    let target = window ?? makeWindow()
    window = target
    resize(target)
    if layoutObserver == nil {
      layoutObserver = Publishers.CombineLatest(
        UpdateManager.shared.$phase.map { Self.layoutKey($0) },
        UpdateManager.shared.$manualCheckStatus
      )
      .map { "\($0)|\($1)" }
      .removeDuplicates()
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in
        guard let self, let window = self.window, window.isVisible else { return }
        self.resize(window)
      }
    }
    NSApplication.shared.activate(ignoringOtherApps: true)
    target.makeKeyAndOrderFront(nil)
  }

  private func makeWindow() -> NSWindow {
    let window = NSWindow(
      contentRect: NSRect(origin: .zero, size: measuredSize()),
      styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
    window.title = localized("About Encaje", "Acerca de Encaje")
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.titlebarSeparatorStyle = .none
    window.isReleasedWhenClosed = false
    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
    window.standardWindowButton(.zoomButton)?.isHidden = true
    let hosting = NSHostingView(rootView: AboutView())
    hosting.sizingOptions = []
    window.contentView = hosting
    window.center()
    return window
  }

  private func resize(_ window: NSWindow) {
    let size = measuredSize()
    let topLeft = NSPoint(x: window.frame.minX, y: window.frame.maxY)
    window.contentMinSize = size
    window.contentMaxSize = size
    window.setContentSize(size)
    window.setFrameTopLeftPoint(topLeft)
  }

  private func measuredSize() -> NSSize {
    NSHostingView(rootView: AboutView()).intrinsicContentSize
  }

  private nonisolated static func layoutKey(_ phase: UpdateManager.Phase) -> String {
    switch phase {
    case .idle: return "idle"
    case .available: return "available"
    case .downloading: return "downloading"
    case .readyToInstall: return "readyToInstall"
    case .installing: return "installing"
    case .failed: return "failed"
    }
  }
}
