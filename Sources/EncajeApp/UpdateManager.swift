import AppKit
import Combine
import Foundation
import Sparkle
import os

@MainActor
final class UpdateManager: ObservableObject {

  static let shared = UpdateManager()

  enum Phase: Equatable {
    case idle
    case available(version: String)
    case downloading(fraction: Double?)
    case readyToInstall(version: String)
    case installing
    case failed(version: String)
  }

  enum ManualCheckStatus: Equatable {
    case idle
    case checking
    case upToDate
    case failed
  }

  static let autoCheckDefaultsKey = "autoUpdateCheckEnabled"
  static let installNowCheckRetryLimit = 300
  static let installNowCheckRetryDelay: TimeInterval = 0.25
  static let backgroundCheckInterval: TimeInterval = 30 * 60
  static let backgroundCheckThrottle: TimeInterval = 5 * 60

  @Published private(set) var phase: Phase = .idle
  @Published private(set) var releasePageURL: URL?
  @Published private(set) var manualCheckStatus: ManualCheckStatus = .idle
  @Published private(set) var pendingVersion: String?
  @Published private(set) var autoCheckEnabled: Bool

  let isDevelopmentBuild =
    Bundle.main.object(forInfoDictionaryKey: "EncajeDevelopmentBuild") as? Bool ?? true
  var available: Bool {
    !isDevelopmentBuild || ProcessInfo.processInfo.environment["ENCAJE_QA_UPDATES"] == "1"
  }
  private let defaults: UserDefaults
  private let log = Logger(subsystem: "com.stevenacz.Encaje", category: "updates")

  private var updater: SPUUpdater?
  private var driver: Driver?
  private var updaterDelegate: UpdaterDelegate?

  private(set) var installRequested = false
  private(set) var installNowRequested = false
  private(set) var resumeCheckPending = false
  var hasLiveUpdater: @MainActor (UpdateManager) -> Bool = { $0.updater != nil }
  var resumeCheckStarter: @MainActor (UpdateManager) -> Void = {
    $0.startInstallNowCheck(attempt: 0)
  }
  var manualCheckStarter: @MainActor (UpdateManager) -> Void = { $0.startManualCheck(attempt: 0) }
  var backgroundCheckStarter: @MainActor (UpdateManager) -> Void = {
    $0.updater?.checkForUpdatesInBackground()
  }
  var userCheckStarter: @MainActor (UpdateManager) -> Void = { $0.updater?.checkForUpdates() }
  var backgroundCheckIntervalProvider: @MainActor () -> TimeInterval = {
    UpdateManager.backgroundCheckInterval
  }
  var isSessionInProgress: @MainActor (UpdateManager) -> Bool = {
    $0.updater?.sessionInProgress == true
  }
  var monotonicClock: @MainActor () -> TimeInterval = {
    TimeInterval(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)) / 1_000_000_000
  }
  private var pendingInstallReply: ((SPUUserUpdateChoice) -> Void)?
  private var pendingIsInformationOnly = false
  private var expectedDownloadBytes: UInt64 = 0
  private var receivedDownloadBytes: UInt64 = 0
  private var manualCheckPending = false
  private var manualCheckWaiting = false
  private var manualCheckResetTask: Task<Void, Never>?
  private var backgroundCheckTimer: Timer?
  private var wakeObserver: NSObjectProtocol?
  private var lastBackgroundCheck: TimeInterval?

  init(defaults: UserDefaults = AppLanguage.defaults) {
    self.defaults = defaults
    if defaults.object(forKey: Self.autoCheckDefaultsKey) == nil {
      autoCheckEnabled = true
    } else {
      autoCheckEnabled = defaults.bool(forKey: Self.autoCheckDefaultsKey)
    }
  }

  func start() {
    guard updater == nil, available else { return }

    let driver = Driver(manager: self)
    let updaterDelegate = UpdaterDelegate()
    let updater = SPUUpdater(
      hostBundle: .main,
      applicationBundle: .main,
      userDriver: driver,
      delegate: updaterDelegate
    )
    updater.sendsSystemProfile = false
    updater.updateCheckInterval = 86400
    updater.automaticallyDownloadsUpdates = false
    updater.automaticallyChecksForUpdates = autoCheckEnabled

    do {
      try updater.start()
    } catch {
      log.error("Updater failed to start: \(error.localizedDescription, privacy: .public)")
      return
    }

    self.driver = driver
    self.updaterDelegate = updaterDelegate
    self.updater = updater
    if autoCheckEnabled { startBackgroundDiscovery() }
  }

  func setAutoCheckEnabled(_ enabled: Bool) {
    autoCheckEnabled = enabled
    defaults.set(enabled, forKey: Self.autoCheckDefaultsKey)
    updater?.automaticallyChecksForUpdates = enabled
    if enabled {
      startBackgroundDiscovery()
    } else {
      stopBackgroundDiscovery()
    }
  }

  var backgroundDiscoveryArmed: Bool { backgroundCheckTimer != nil }

  var phaseAllowsQuietCheck: Bool {
    guard !installRequested, !installNowRequested, !resumeCheckPending,
      !manualCheckPending, pendingInstallReply == nil
    else { return false }
    switch phase {
    case .idle, .available, .failed:
      return true
    case .downloading, .readyToInstall, .installing:
      return false
    }
  }

  private var sessionIsUserDriven: Bool {
    installRequested || installNowRequested || resumeCheckPending
      || (manualCheckPending && !manualCheckWaiting)
  }

  func startBackgroundDiscovery() {
    guard backgroundCheckTimer == nil else { return }
    let interval = backgroundCheckIntervalProvider()
    let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
      Task { @MainActor in self?.requestBackgroundCheck() }
    }
    timer.tolerance = interval / 10
    RunLoop.main.add(timer, forMode: .common)
    backgroundCheckTimer = timer
    wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.requestBackgroundCheck() }
    }
  }

  func stopBackgroundDiscovery() {
    backgroundCheckTimer?.invalidate()
    backgroundCheckTimer = nil
    if let wakeObserver {
      NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
      self.wakeObserver = nil
    }
  }

  func requestBackgroundCheck() {
    guard autoCheckEnabled, phaseAllowsQuietCheck, hasLiveUpdater(self),
      !isSessionInProgress(self)
    else { return }
    let now = monotonicClock()
    if let lastBackgroundCheck, now - lastBackgroundCheck < Self.backgroundCheckThrottle { return }
    lastBackgroundCheck = now
    backgroundCheckStarter(self)
  }

  func surfaceDidOpen() {
    requestBackgroundCheck()
  }

  func installPendingUpdate() {
    guard hasLiveUpdater(self) else { return }
    if pendingIsInformationOnly {
      openReleasePage()
      return
    }
    if resumeCheckPending {
      installRequested = true
      installNowRequested = false
      phase = .downloading(fraction: nil)
      return
    }
    if isSessionInProgress(self) {
      switch phase {
      case .downloading, .installing:
        return
      case .idle, .available, .readyToInstall, .failed:
        break
      }
    }
    handleRetryRequested()
  }

  func installNow() {
    guard phase != .installing else { return }
    if let reply = pendingInstallReply {
      pendingInstallReply = nil
      installRequested = true
      phase = .installing
      reply(.install)
      return
    }
    guard hasLiveUpdater(self) else { return }
    handleInstallNowRequested()
  }

  func retryPendingUpdate() {
    guard phase != .installing else { return }
    if pendingInstallReply != nil {
      phase = .readyToInstall(version: pendingVersion ?? "")
      return
    }
    guard hasLiveUpdater(self) else { return }
    handleRetryRequested()
  }

  func installLater() {
    guard let reply = pendingInstallReply else { return }
    pendingInstallReply = nil
    installRequested = false
    reply(.dismiss)
  }

  func checkForUpdatesManually() {
    guard hasLiveUpdater(self) else { return }
    manualCheckResetTask?.cancel()
    manualCheckPending = true
    manualCheckStatus = .checking
    guard isSessionInProgress(self) else {
      manualCheckWaiting = false
      userCheckStarter(self)
      return
    }
    guard !manualCheckWaiting else { return }
    manualCheckWaiting = true
    manualCheckStarter(self)
  }

  func startManualCheck(attempt: Int) {
    guard manualCheckWaiting else { return }
    guard attempt < Self.installNowCheckRetryLimit else {
      manualCheckWaiting = false
      finishManualCheck(status: .idle)
      return
    }
    guard isSessionInProgress(self) else {
      manualCheckWaiting = false
      userCheckStarter(self)
      return
    }
    Task { [weak self] in
      try? await Task.sleep(nanoseconds: 250_000_000)
      guard let self, !Task.isCancelled else { return }
      self.startManualCheck(attempt: attempt + 1)
    }
  }

  func openReleasePage() {
    guard let releasePageURL else { return }
    NSWorkspace.shared.open(releasePageURL)
  }

  func handleInstallRequested() {
    installRequested = true
    phase = .downloading(fraction: nil)
  }

  func handleInstallNowRequested() {
    installRequested = true
    installNowRequested = true
    resumeCheckPending = true
    phase = .installing
    resumeCheckStarter(self)
  }

  func handleRetryRequested() {
    installRequested = true
    installNowRequested = false
    resumeCheckPending = true
    phase = .downloading(fraction: nil)
    resumeCheckStarter(self)
  }

  func startInstallNowCheck(attempt: Int) {
    guard resumeCheckPending else { return }
    if hasLiveUpdater(self), !isSessionInProgress(self) {
      resumeCheckPending = false
      userCheckStarter(self)
      return
    }
    guard attempt < Self.installNowCheckRetryLimit else {
      installRequested = false
      installNowRequested = false
      resumeCheckPending = false
      phase = .failed(version: pendingVersion ?? "")
      return
    }
    Task { [weak self] in
      try? await Task.sleep(
        nanoseconds: UInt64(Self.installNowCheckRetryDelay * 1_000_000_000))
      guard let self, !Task.isCancelled else { return }
      self.startInstallNowCheck(attempt: attempt + 1)
    }
  }

  func handleUpdateFound(
    version: String,
    releasePage: URL?,
    informationOnly: Bool,
    stage: SPUUserUpdateStage
  ) -> SPUUserUpdateChoice {
    if !sessionIsUserDriven, phase != .idle, let pendingVersion,
      !Self.isNewerVersion(version, than: pendingVersion)
    {
      return .dismiss
    }
    resumeCheckPending = false
    pendingVersion = version
    pendingIsInformationOnly = informationOnly
    releasePageURL = releasePage
    finishManualCheck(status: .idle)

    let prepared = stage != .notDownloaded
    if !informationOnly, prepared ? installNowRequested : installRequested {
      phase = prepared ? .installing : .downloading(fraction: nil)
      return .install
    }
    installRequested = false
    installNowRequested = false
    phase = prepared ? .readyToInstall(version: version) : .available(version: version)
    return .dismiss
  }

  func handleDownloadInitiated() {
    expectedDownloadBytes = 0
    receivedDownloadBytes = 0
    phase = .downloading(fraction: nil)
  }

  func handleDownloadExpectedLength(_ length: UInt64) {
    expectedDownloadBytes = length
  }

  func handleDownloadReceived(bytes: UInt64) {
    receivedDownloadBytes += bytes
    guard expectedDownloadBytes > 0 else { return }
    let fraction = min(1.0, Double(receivedDownloadBytes) / Double(expectedDownloadBytes))
    phase = .downloading(fraction: fraction)
  }

  func handleExtractionStarted() {
    phase = .installing
  }

  func handleReadyToInstall(reply: @escaping (SPUUserUpdateChoice) -> Void) {
    resumeCheckPending = false
    if installNowRequested {
      installNowRequested = false
      phase = .installing
      reply(.install)
      return
    }
    pendingInstallReply = reply
    phase = .readyToInstall(version: pendingVersion ?? "")
  }

  func handleInstalling() {
    phase = .installing
  }

  func handleNotFound() {
    if resumeCheckPending {
      pendingInstallReply = nil
      return
    }
    installRequested = false
    installNowRequested = false
    pendingInstallReply = nil
    pendingVersion = nil
    pendingIsInformationOnly = false
    releasePageURL = nil
    phase = .idle
    finishManualCheck(status: .upToDate)
  }

  func handleError(_ message: String) {
    if resumeCheckPending {
      pendingInstallReply = nil
      return
    }
    finishManualCheck(status: .failed)
    if installRequested, let pendingVersion {
      log.error("Update install failed: \(message, privacy: .public)")
      phase = .failed(version: pendingVersion)
    } else {
      log.debug("Update check failed silently")
      switch phase {
      case .readyToInstall, .installing:
        phase = .readyToInstall(version: pendingVersion ?? "")
      case .idle, .available, .downloading, .failed:
        phase = pendingVersion.map { .available(version: $0) } ?? .idle
      }
    }
    installRequested = false
    installNowRequested = false
    pendingInstallReply = nil
  }

  func handleDismissInstallation() {
    if resumeCheckPending {
      pendingInstallReply = nil
      return
    }
    installRequested = false
    installNowRequested = false
    pendingInstallReply = nil
    switch phase {
    case .installing, .readyToInstall:
      phase = .readyToInstall(version: pendingVersion ?? "")
    case .downloading:
      phase = pendingVersion.map { .available(version: $0) } ?? .idle
    case .idle, .available, .failed:
      break
    }
  }

  private static func isNewerVersion(_ version: String, than current: String) -> Bool {
    SUStandardVersionComparator.default.compareVersion(version, toVersion: current)
      == .orderedDescending
  }

  private func finishManualCheck(status: ManualCheckStatus) {
    guard manualCheckPending, !manualCheckWaiting else { return }
    manualCheckPending = false
    manualCheckStatus = status
    guard status != .idle else { return }
    manualCheckResetTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: 3_000_000_000)
      guard !Task.isCancelled else { return }
      self?.manualCheckStatus = .idle
    }
  }
}

@MainActor
private final class Driver: NSObject, SPUUserDriver {

  private unowned let manager: UpdateManager

  init(manager: UpdateManager) {
    self.manager = manager
  }

  func show(
    _ request: SPUUpdatePermissionRequest,
    reply: @escaping (SUUpdatePermissionResponse) -> Void
  ) {
    reply(SUUpdatePermissionResponse(automaticUpdateChecks: true, sendSystemProfile: false))
  }

  func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {}

  func showUpdateFound(
    with appcastItem: SUAppcastItem,
    state: SPUUserUpdateState,
    reply: @escaping (SPUUserUpdateChoice) -> Void
  ) {
    let choice = manager.handleUpdateFound(
      version: appcastItem.displayVersionString,
      releasePage: appcastItem.infoURL,
      informationOnly: appcastItem.isInformationOnlyUpdate,
      stage: state.stage
    )
    reply(choice)
  }

  func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}

  func showUpdateReleaseNotesFailedToDownloadWithError(_ error: any Error) {}

  func showUpdateNotFoundWithError(_ error: any Error, acknowledgement: @escaping () -> Void) {
    manager.handleNotFound()
    acknowledgement()
  }

  func showUpdaterError(_ error: any Error, acknowledgement: @escaping () -> Void) {
    manager.handleError(error.localizedDescription)
    acknowledgement()
  }

  func showDownloadInitiated(cancellation: @escaping () -> Void) {
    manager.handleDownloadInitiated()
  }

  func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
    manager.handleDownloadExpectedLength(expectedContentLength)
  }

  func showDownloadDidReceiveData(ofLength length: UInt64) {
    manager.handleDownloadReceived(bytes: length)
  }

  func showDownloadDidStartExtractingUpdate() {
    manager.handleExtractionStarted()
  }

  func showExtractionReceivedProgress(_ progress: Double) {}

  func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
    manager.handleReadyToInstall(reply: reply)
  }

  func showInstallingUpdate(
    withApplicationTerminated applicationTerminated: Bool,
    retryTerminatingApplication: @escaping () -> Void
  ) {
    manager.handleInstalling()
  }

  func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
    acknowledgement()
  }

  func dismissUpdateInstallation() {
    manager.handleDismissInstallation()
  }
}

private final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {

  nonisolated func feedURLString(for updater: SPUUpdater) -> String? {
    guard ProcessInfo.processInfo.environment["ENCAJE_QA_UPDATES"] == "1",
      let raw = ProcessInfo.processInfo.environment["ENCAJE_UPDATE_FEED_URL"],
      let url = URL(string: raw), url.scheme == "http",
      ["localhost", "127.0.0.1", "::1"].contains(url.host ?? "")
    else { return nil }
    return raw
  }
}
