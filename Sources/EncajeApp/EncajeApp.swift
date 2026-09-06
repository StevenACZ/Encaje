import AppKit
import ApplicationServices
import EncajeCore
import ServiceManagement
import SwiftUI

@main
struct EncajeMain {
  @MainActor static func main() {
    let app = NSApplication.shared
    if let index = CommandLine.arguments.firstIndex(of: "--benchmark-pid"),
      CommandLine.arguments.indices.contains(index + 1),
      let pid = Int32(CommandLine.arguments[index + 1]),
      ProcessInfo.processInfo.environment["ENCAJE_QA"] == "1"
    {
      let report = WindowBenchmark.run(pid: pid)
      if let data = try? JSONSerialization.data(
        withJSONObject: report, options: [.prettyPrinted, .sortedKeys]),
        let text = String(data: data, encoding: .utf8)
      {
        print(text)
      }
      return
    }
    if CommandLine.arguments.contains("--diagnostics") {
      let report: [String: Any] = [
        "accessibility": AXIsProcessTrusted(),
        "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
          ?? "",
        "screens": NSScreen.screens.count,
        "loginEnabled": SMAppService.mainApp.status == .enabled,
      ]
      if let data = try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]),
        let text = String(data: data, encoding: .utf8)
      {
        print(text)
      }
      return
    }
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) { app.run() }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation {
  private var model: AppModel!
  private var statusItem: NSStatusItem!
  private var settingsWindow: NSWindow?
  private var welcomeWindow: NSWindow?
  private var refreshTimer: Timer?
  private let menuPopover = MenuBarPopover()

  func applicationDidFinishLaunching(_ notification: Notification) {
    model = AppModel()
    UpdateManager.shared.start()
    configureApplicationMenu()
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem.button?.image = MenuBarGlyph.image
    statusItem.button?.toolTip = "Encaje"
    statusItem.button?.target = self
    statusItem.button?.action = #selector(toggleMenuPopover)
    statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    model.onLanguageChange = { [weak self] in
      guard let self else { return }
      self.configureApplicationMenu()
      self.rebuildMenu()
      self.settingsWindow?.title = localized("Encaje Settings", "Ajustes de Encaje")
      self.welcomeWindow?.title = localized("Welcome to Encaje", "Bienvenido a Encaje")
    }
    model.onMenuChange = { [weak self] in self?.rebuildMenu() }
    rebuildMenu()
    NSWorkspace.shared.notificationCenter.addObserver(
      self, selector: #selector(workspaceActivated),
      name: NSWorkspace.didActivateApplicationNotification, object: nil)
    if !model.welcomeComplete || !model.permissions.granted || model.setupPending {
      showWelcome()
    }
    if ProcessInfo.processInfo.environment["ENCAJE_SHOW_SETTINGS"] == "1" { showSettings() }
    if ProcessInfo.processInfo.environment["ENCAJE_SHOW_POPOVER"] == "1" { toggleMenuPopover() }
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    if model.permissions.granted { showSettings() } else { showWelcome() }
    return true
  }

  func applicationDidBecomeActive(_ notification: Notification) {
    if settingsWindow?.isVisible == true { model?.refreshLoginState() }
  }

  func applicationWillTerminate(_ notification: Notification) {
    refreshTimer?.invalidate()
    model.stop()
    menuPopover.close()
    NSWorkspace.shared.notificationCenter.removeObserver(self)
  }

  @objc private func workspaceActivated() { model.refresh() }

  private func configureApplicationMenu() {
    let main = NSMenu()
    let application = NSMenuItem()
    let applicationMenu = NSMenu()
    let settings = item(localized("Settings…", "Ajustes…"), #selector(showSettings))
    settings.keyEquivalent = ","
    applicationMenu.addItem(settings)
    applicationMenu.addItem(.separator())
    let exit = item(localized("Quit Encaje", "Salir de Encaje"), #selector(quit))
    exit.keyEquivalent = "q"
    applicationMenu.addItem(exit)
    application.submenu = applicationMenu
    main.addItem(application)
    let edit = NSMenuItem(title: localized("Edit", "Editar"), action: nil, keyEquivalent: "")
    let editMenu = NSMenu(title: edit.title)
    let undo = item(localized("Undo", "Deshacer"), #selector(undoEditing))
    undo.keyEquivalent = "z"
    editMenu.addItem(undo)
    let redo = item(localized("Redo", "Rehacer"), #selector(redoEditing))
    redo.keyEquivalent = "z"
    redo.keyEquivalentModifierMask = [.command, .shift]
    editMenu.addItem(redo)
    for (title, selector, key) in [
      (localized("Cut", "Cortar"), #selector(NSText.cut(_:)), "x"),
      (localized("Copy", "Copiar"), #selector(NSText.copy(_:)), "c"),
      (localized("Paste", "Pegar"), #selector(NSText.paste(_:)), "v"),
      (localized("Select All", "Seleccionar todo"), #selector(NSText.selectAll(_:)), "a"),
    ] { editMenu.addItem(NSMenuItem(title: title, action: selector, keyEquivalent: key)) }
    edit.submenu = editMenu
    main.addItem(edit)
    let windows = NSMenuItem(title: localized("Window", "Ventana"), action: nil, keyEquivalent: "")
    let windowsMenu = NSMenu(title: windows.title)
    let close = item(localized("Close Window", "Cerrar ventana"), #selector(closeActiveWindow))
    close.keyEquivalent = "w"
    windowsMenu.addItem(close)
    windows.submenu = windowsMenu
    main.addItem(windows)
    NSApplication.shared.windowsMenu = windowsMenu
    NSApplication.shared.mainMenu = main
  }

  private func rebuildMenu() {
    guard model != nil else { return }
    statusItem.button?.appearsDisabled = model.paused
    statusItem.button?.toolTip =
      model.paused ? localized("Encaje — paused", "Encaje — en pausa") : "Encaje"
  }

  @objc private func toggleMenuPopover() {
    if (NSApplication.shared.currentEvent?.clickCount ?? 0) > 1 {
      menuPopover.close()
      return
    }
    guard let button = statusItem.button else { return }
    menuPopover.toggle(
      from: button, model: model, settings: { [weak self] in self?.showSettings() },
      about: { [weak self] in self?.showAbout() }, quit: { NSApplication.shared.terminate(nil) })
  }

  private func showAbout() {
    menuPopover.close(restoreFocus: false)
    NSApplication.shared.activate(ignoringOtherApps: true)
    NSApplication.shared.orderFrontStandardAboutPanel(options: [
      .applicationName: "Encaje", .applicationIcon: AppArtwork.icon,
      .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
        as? String ?? "",
      .credits: NSAttributedString(
        string: localized("Your space, your way.", "Tu espacio, a tu manera.")),
    ])
  }

  private func item(_ title: String, _ selector: Selector) -> NSMenuItem {
    let entry = NSMenuItem(title: title, action: selector, keyEquivalent: "")
    entry.target = self
    return entry
  }

  @objc private func undoEditing() {
    if let text = NSApplication.shared.keyWindow?.firstResponder as? NSTextView {
      text.undoManager?.undo()
    } else if NSApplication.shared.keyWindow === settingsWindow {
      model.undoZoneEdit()
    }
  }

  @objc private func redoEditing() {
    if let text = NSApplication.shared.keyWindow?.firstResponder as? NSTextView {
      text.undoManager?.redo()
    } else if NSApplication.shared.keyWindow === settingsWindow {
      model.redoZoneEdit()
    }
  }

  func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
    if menuItem.action == #selector(undoEditing) || menuItem.action == #selector(redoEditing) {
      let undo = menuItem.action == #selector(undoEditing)
      if let text = NSApplication.shared.keyWindow?.firstResponder as? NSTextView {
        return undo ? text.undoManager?.canUndo == true : text.undoManager?.canRedo == true
      }
      return NSApplication.shared.keyWindow === settingsWindow && !model.isEditingZone
        && (undo ? model.zoneHistory.canUndo : model.zoneHistory.canRedo)
    }
    return true
  }

  @objc private func closeActiveWindow() {
    if menuPopover.isPresented {
      menuPopover.close()
    } else {
      NSApplication.shared.keyWindow?.performClose(nil)
    }
  }

  @objc private func togglePause() { model.paused.toggle() }
  @objc private func quit() { NSApplication.shared.terminate(nil) }

  @objc private func showSettings() {
    menuPopover.close(restoreFocus: false)
    model.refreshLoginState()
    if settingsWindow == nil {
      let view = SettingsView(
        model: model, permissions: model.permissions,
        showWelcome: { [weak self] in self?.showWelcome() })
      settingsWindow = makeWindow(
        title: localized("Encaje Settings", "Ajustes de Encaje"),
        size: NSSize(width: 880, height: 660),
        view: view)
      settingsWindow?.identifier = NSUserInterfaceItemIdentifier("encaje.settings")
    }
    present(settingsWindow)
  }

  @objc private func showWelcome() {
    menuPopover.close(restoreFocus: false)
    model.refresh()
    if welcomeWindow == nil {
      let view = WelcomeView(
        model: model, permissions: model.permissions,
        sourceFrame: { [weak self] in self?.welcomeWindow?.frame },
        finish: { [weak self] in
          self?.model.permissions.dismiss()
          self?.welcomeWindow?.close()
        })
      welcomeWindow = makeWindow(
        title: localized("Welcome to Encaje", "Bienvenido a Encaje"),
        size: NSSize(width: 510, height: 590),
        view: view)
      welcomeWindow?.identifier = NSUserInterfaceItemIdentifier("encaje.welcome")
    }
    present(welcomeWindow)
  }

  private func makeWindow<V: View>(title: String, size: NSSize, view: V) -> NSWindow {
    let window = NSWindow(
      contentRect: NSRect(origin: .zero, size: size),
      styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
    window.title = title
    window.isReleasedWhenClosed = false
    let hosting = NSHostingView(rootView: view)
    hosting.sizingOptions = []
    window.contentView = hosting
    window.contentMinSize = size
    window.contentMaxSize = size
    window.delegate = self
    window.center()
    return window
  }

  private func present(_ window: NSWindow?) {
    NSApplication.shared.activate(ignoringOtherApps: true)
    window?.makeKeyAndOrderFront(nil)
    if refreshTimer == nil {
      refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
        MainActor.assumeIsolated { self?.model.refresh() }
      }
    }
  }

  func windowWillClose(_ notification: Notification) {
    guard let closed = notification.object as? NSWindow else { return }
    if closed === welcomeWindow {
      model.permissions.dismiss()
      welcomeWindow = nil
    }
    if closed === settingsWindow { settingsWindow = nil }
    if welcomeWindow == nil && settingsWindow == nil {
      refreshTimer?.invalidate()
      refreshTimer = nil
    }
  }
}
