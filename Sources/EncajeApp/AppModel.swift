import AppKit
import Combine
import EncajeCore
import ServiceManagement
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
  let permissions: PermissionCoordinator
  let engine = WindowEngine()
  @Published var paused = false {
    didSet {
      hotkeys.paused = paused
      onMenuChange?()
    }
  }
  @Published var language: AppLanguage {
    didSet {
      guard language != oldValue else { return }
      defaults.set(language.rawValue, forKey: "language")
      message = nil
      onLanguageChange?()
    }
  }
  var onLanguageChange: (() -> Void)?
  @Published var gap: Double { didSet { defaults.set(gap, forKey: "gap") } }
  @Published var exclusions: String {
    didSet {
      defaults.set(exclusions, forKey: "exclusions")
      applyHotkeys()
    }
  }
  @Published var rules: [WindowRule] {
    didSet {
      save(rules, key: "rulesV2")
      applyHotkeys()
    }
  }
  @Published var layouts: [SavedLayout] { didSet { save(layouts, key: "layouts") } }
  @Published var isEditingZone = false
  @Published private(set) var zoneHistory = ZoneEditHistory()
  @Published private(set) var zoneHistorySelection: String?
  @Published private(set) var zoneHistoryRevision = 0
  @Published var message: String?
  @Published private(set) var loginEnabled = false
  @Published private(set) var loginApprovalNeeded = false
  @Published private(set) var shortcutReady = false
  var onMenuChange: (() -> Void)?
  private let defaults: UserDefaults
  private var observers: Set<AnyCancellable> = []
  private lazy var hotkeys = HotkeyController { [weak self] id in self?.performRule(id: id) }

  init() {
    let suite = ProcessInfo.processInfo.environment["ENCAJE_DEFAULTS_SUITE"]
    defaults = suite.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    language = AppLanguage(rawValue: defaults.string(forKey: "language") ?? "") ?? .system
    permissions = PermissionCoordinator(defaults: defaults)
    gap = defaults.object(forKey: "gap") as? Double ?? 8
    exclusions = defaults.string(forKey: "exclusions") ?? ""
    rules =
      Self.decode([WindowRule].self, defaults: defaults, key: "rulesV2")
      ?? WindowRule.migrating(Self.decode([String: Int].self, defaults: defaults, key: "bindings"))
    layouts = Self.decode([SavedLayout].self, defaults: defaults, key: "layouts") ?? []
    permissions.$granted.removeDuplicates().sink { [weak self] granted in
      Task { @MainActor in self?.permissionChanged(granted) }
    }.store(in: &observers)
    engine.$lastMessage.sink { [weak self] value in
      Task { @MainActor in self?.message = value }
    }.store(in: &observers)
    refreshLoginState()
    applyHotkeys()
  }

  var welcomeComplete: Bool {
    get { defaults.bool(forKey: "welcomeComplete") }
    set {
      defaults.set(newValue, forKey: "welcomeComplete")
      if newValue { defaults.removeObject(forKey: "permissionSetupPending") }
    }
  }

  var setupPending: Bool { defaults.bool(forKey: "permissionSetupPending") }
  var ready: Bool { permissions.granted && shortcutReady }

  func refresh() {
    permissions.refresh()
    if permissions.granted && !shortcutReady { permissionChanged(true) }
  }

  func perform(_ action: WindowAction) {
    guard permissions.granted else {
      message = localized(
        "Allow Accessibility to arrange windows.", "Activa Accesibilidad para ordenar ventanas.")
      return
    }
    if let rule = rules.first(where: { $0.id == action.rawValue }) {
      performRule(id: rule.id)
    } else {
      engine.perform(action, gap: gap)
    }
  }

  func performRule(id: String) {
    guard permissions.granted, let rule = rules.first(where: { $0.id == id }) else { return }
    let opposite: WindowAction? =
      switch rule.action {
      case .left: .right
      case .right: .left
      case .up: .down
      case .down: .up
      default: nil
      }
    let neighbor =
      rule.id == rule.action.rawValue
      ? opposite.flatMap { action in rules.first(where: { $0.id == action.rawValue })?.zone } : nil
    engine.perform(rule.action, gap: gap, zone: rule.zone, neighborZone: neighbor)
  }

  @discardableResult
  func updateRule(_ rule: WindowRule, recordHistory: Bool = true) -> Bool {
    guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return false }
    if let code = rule.keyCode,
      rules.contains(where: {
        $0.id != rule.id && $0.keyCode == code && $0.modifiers == rule.modifiers
      })
    {
      message = localized("That shortcut is already assigned.", "Ese atajo ya está asignado.")
      return false
    }
    var value = rule
    value.zone = value.zone?.normalized
    guard rules[index] != value else { return true }
    if rules[index].action != value.action { zoneHistory.remove(ruleID: rule.id) }
    if recordHistory && rules[index].action == value.action {
      zoneHistory.record(ruleID: rule.id, before: rules[index].zone, after: value.zone)
    }
    rules[index] = value
    return true
  }

  func addRule() -> String {
    let rule = WindowRule(title: localized("Custom zone", "Zona personalizada"))
    rules.append(rule)
    return rule.id
  }

  func recordZoneEdit(id: String, before: GridZone?) {
    guard let rule = rules.first(where: { $0.id == id }) else { return }
    zoneHistory.record(ruleID: id, before: before, after: rule.zone)
  }

  func undoZoneEdit() {
    guard !isEditingZone else { return }
    guard let entry = zoneHistory.undo(),
      let index = rules.firstIndex(where: { $0.id == entry.ruleID })
    else { return }
    rules[index].zone = entry.before
    zoneHistorySelection = entry.ruleID
    zoneHistoryRevision += 1
  }

  func redoZoneEdit() {
    guard !isEditingZone else { return }
    guard let entry = zoneHistory.redo(),
      let index = rules.firstIndex(where: { $0.id == entry.ruleID })
    else { return }
    rules[index].zone = entry.after
    zoneHistorySelection = entry.ruleID
    zoneHistoryRevision += 1
  }

  func removeRule(id: String) {
    zoneHistory.remove(ruleID: id)
    rules.removeAll { $0.id == id }
  }
  func resetRules() {
    zoneHistory.clear()
    rules = WindowRule.defaults
  }

  func addExcludedApp() {
    let panel = NSOpenPanel()
    panel.directoryURL = URL(fileURLWithPath: "/Applications")
    panel.canChooseDirectories = false
    panel.allowedContentTypes = [.applicationBundle]
    panel.allowsMultipleSelection = true
    guard panel.runModal() == .OK else { return }
    var ids = Set(
      exclusions.split(whereSeparator: { $0.isWhitespace || $0 == "," }).map(String.init))
    for url in panel.urls { if let id = Bundle(url: url)?.bundleIdentifier { ids.insert(id) } }
    exclusions = ids.sorted().joined(separator: "\n")
  }

  func removeExcludedApp(_ bundleID: String) {
    exclusions = exclusions.split(whereSeparator: { $0.isWhitespace || $0 == "," })
      .map(String.init).filter { $0 != bundleID }.joined(separator: "\n")
  }

  func saveLayout(name: String) {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    if let layout = engine.captureLayout(name: trimmed) { layouts.append(layout) }
  }

  func restoreLayout(_ layout: SavedLayout) { engine.restoreLayout(layout, gap: gap) }

  func setLogin(_ enabled: Bool) {
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
    } catch { message = error.localizedDescription }
    refreshLoginState()
  }

  func stop() {
    hotkeys.stop()
    permissions.dismiss()
  }

  func refreshLoginState() {
    let status = SMAppService.mainApp.status
    let enabled = status == .enabled
    let needsApproval = status == .requiresApproval
    if loginEnabled != enabled { loginEnabled = enabled }
    if loginApprovalNeeded != needsApproval { loginApprovalNeeded = needsApproval }
  }

  private func permissionChanged(_ granted: Bool) {
    if granted {
      shortcutReady = hotkeys.start()
      if !shortcutReady { permissions.markRestartNeeded() }
    } else {
      hotkeys.stop()
      shortcutReady = false
    }
    onMenuChange?()
  }

  private func applyHotkeys() {
    var mapped: [ShortcutCombination: String] = [:]
    for rule in rules {
      guard let code = rule.keyCode, code >= 0, code <= Int(UInt16.max) else { continue }
      let combination = ShortcutCombination(keyCode: code, modifiers: rule.modifiers)
      if mapped[combination] == nil { mapped[combination] = rule.id }
    }
    hotkeys.bindings = mapped
    hotkeys.excludedBundleIDs = Set(
      exclusions.split(whereSeparator: { $0.isWhitespace || $0 == "," }).map(String.init))
  }

  private func save<T: Encodable>(_ value: T, key: String) {
    if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
  }

  private static func decode<T: Decodable>(_ type: T.Type, defaults: UserDefaults, key: String)
    -> T?
  {
    guard let data = defaults.data(forKey: key) else { return nil }
    return try? JSONDecoder().decode(type, from: data)
  }
}
