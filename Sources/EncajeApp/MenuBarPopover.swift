import AppKit
import SwiftUI

@MainActor
final class MenuBarPopover: NSObject, NSPopoverDelegate {
  private let popover = NSPopover()
  private weak var button: NSStatusBarButton?
  private var localMonitor: Any?
  private var globalMonitor: Any?
  private var previousApplication: NSRunningApplication?
  private var isClosing = false
  var isPresented: Bool { popover.isShown || isClosing }

  func toggle(
    from button: NSStatusBarButton, model: AppModel,
    settings: @escaping () -> Void, about: @escaping () -> Void, quit: @escaping () -> Void
  ) {
    guard !isClosing else { return }
    if popover.isShown {
      close()
      return
    }
    previousApplication = NSWorkspace.shared.frontmostApplication
    self.button = button
    let content = MenuBarPopoverView(
      model: model,
      settings: { [weak self] in
        self?.previousApplication = nil
        self?.close()
        settings()
      },
      about: { [weak self] in
        self?.previousApplication = nil
        self?.close()
        about()
      },
      quit: { [weak self] in
        self?.previousApplication = nil
        self?.close()
        quit()
      })
    let hosting = NSHostingController(rootView: content)
    hosting.sizingOptions = [.preferredContentSize]
    hosting.preferredContentSize = hosting.sizeThatFits(in: NSSize(width: 300, height: 1000))
    popover.contentViewController = hosting
    popover.contentSize = hosting.preferredContentSize
    popover.behavior = .applicationDefined
    popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    popover.delegate = self
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    NSApplication.shared.activate(ignoringOtherApps: true)
    popover.contentViewController?.view.window?.makeKey()
    button.highlight(true)
    localMonitor = NSEvent.addLocalMonitorForEvents(matching: [
      .leftMouseDown, .rightMouseDown, .keyDown,
    ]) { [weak self] event in
      let consumed = MainActor.assumeIsolated { () -> Bool in
        guard let self else { return false }
        if event.type == .keyDown && event.keyCode == 53 {
          self.close()
          return true
        }
        if event.type != .keyDown { self.closeIfOutside() }
        return false
      }
      return consumed ? nil : event
    }
    globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
      [weak self] _ in
      MainActor.assumeIsolated { self?.closeIfOutside() }
    }
    NSWorkspace.shared.notificationCenter.addObserver(
      self, selector: #selector(applicationChanged),
      name: NSWorkspace.didActivateApplicationNotification, object: nil)
  }

  func close(restoreFocus: Bool = true) {
    if !restoreFocus { previousApplication = nil }
    guard !isClosing else { return }
    if popover.isShown {
      isClosing = true
      popover.performClose(nil)
    } else {
      releaseContent()
    }
  }

  func popoverDidClose(_ notification: Notification) { releaseContent() }

  @objc private func applicationChanged(_ notification: Notification) {
    guard
      let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
      app.bundleIdentifier != Bundle.main.bundleIdentifier
    else { return }
    close(restoreFocus: false)
  }

  private func closeIfOutside() {
    let point = NSEvent.mouseLocation
    if let frame = popover.contentViewController?.view.window?.frame, frame.contains(point) {
      return
    }
    if let button, let window = button.window {
      let rect = window.convertToScreen(button.convert(button.bounds, to: nil))
      if rect.contains(point) { return }
    }
    close(restoreFocus: false)
  }

  private func releaseContent() {
    isClosing = false
    if let localMonitor { NSEvent.removeMonitor(localMonitor) }
    if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
    localMonitor = nil
    globalMonitor = nil
    NSWorkspace.shared.notificationCenter.removeObserver(self)
    popover.contentViewController = nil
    button?.highlight(false)
    if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Bundle.main.bundleIdentifier,
      let previousApplication, previousApplication.bundleIdentifier != Bundle.main.bundleIdentifier
    {
      previousApplication.activate()
    }
    previousApplication = nil
  }
}

private struct MenuBarPopoverView: View {
  @ObservedObject var model: AppModel
  @ObservedObject private var updates = UpdateManager.shared
  let settings: () -> Void
  let about: () -> Void
  let quit: () -> Void

  var body: some View {
    VStack(spacing: 14) {
      HStack(spacing: 12) {
        Image(nsImage: AppArtwork.icon).resizable().frame(width: 44, height: 44)
        VStack(alignment: .leading, spacing: 3) {
          Text("Encaje").font(.system(size: 19, weight: .bold, design: .rounded))
          Text(
            model.paused
              ? localized("Shortcuts paused", "Atajos en pausa")
              : (model.ready
                ? localized("Everything in its place", "Todo en su sitio")
                : localized("Finish setup to begin", "Completa la bienvenida"))
          )
          .font(.caption).foregroundStyle(.secondary)
        }
        Spacer(minLength: 0)
      }
      Button {
        model.paused.toggle()
      } label: {
        Label(
          model.paused
            ? localized("Resume shortcuts", "Reanudar atajos")
            : localized("Pause shortcuts", "Pausar atajos"),
          systemImage: model.paused ? "play.fill" : "pause.fill"
        )
        .font(.system(size: 14, weight: .semibold)).frame(maxWidth: .infinity).padding(
          .vertical, 11)
      }.buttonStyle(.plain).background(.teal.gradient, in: RoundedRectangle(cornerRadius: 10))
        .foregroundStyle(.white)
      if updates.available, updates.phase != .idle {
        UpdateActionView()
      }
      VStack(spacing: 0) {
        row(
          localized("Configuration", "Configuración"), symbol: "slider.horizontal.3",
          action: settings)
        Divider()
        row(localized("About Encaje", "Acerca de Encaje"), symbol: "info.circle", action: about)
        Divider()
        Button(action: quit) {
          Label(localized("Quit Encaje", "Salir de Encaje"), systemImage: "power")
            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10).contentShape(
              Rectangle())
        }.buttonStyle(.plain).foregroundStyle(.red)
      }.font(.system(size: 13, weight: .medium))
    }.padding(18).frame(width: 300).fixedSize(horizontal: false, vertical: true).tint(.teal)
  }

  private func row(_ text: String, symbol: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack {
        Label(text, systemImage: symbol)
        Spacer()
        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
      }
      .padding(.vertical, 10).contentShape(Rectangle())
    }.buttonStyle(.plain)
  }
}
