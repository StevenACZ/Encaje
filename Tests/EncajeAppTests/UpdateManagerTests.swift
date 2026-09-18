import AppKit
import Sparkle
import XCTest

@testable import EncajeApp

@MainActor
final class UpdateManagerTests: XCTestCase {

  private func makeManager() -> UpdateManager {
    UpdateManager(defaults: UserDefaults(suiteName: "Encaje.UpdaterTests." + UUID().uuidString)!)
  }

  func testScheduledFoundUpdateIsDismissedAndSurfaced() {
    let manager = makeManager()
    let choice = manager.handleUpdateFound(
      version: "9.9.9",
      releasePage: URL(string: "https://example.com/release"),
      informationOnly: false,
      stage: .notDownloaded
    )

    XCTAssertEqual(choice, .dismiss)
    XCTAssertEqual(manager.phase, .available(version: "9.9.9"))
    XCTAssertEqual(manager.releasePageURL?.absoluteString, "https://example.com/release")
  }

  func testInformationOnlyUpdateNeverInstalls() {
    let manager = makeManager()
    manager.installPendingUpdate()

    let choice = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: true, stage: .notDownloaded)

    XCTAssertEqual(choice, .dismiss)
    XCTAssertEqual(manager.phase, .available(version: "9.9.9"))
  }

  func testDownloadProgressIsFractionOfExpectedLength() {
    let manager = makeManager()
    manager.handleDownloadInitiated()
    XCTAssertEqual(manager.phase, .downloading(fraction: nil))

    manager.handleDownloadExpectedLength(1_000)
    manager.handleDownloadReceived(bytes: 250)
    XCTAssertEqual(manager.phase, .downloading(fraction: 0.25))

    manager.handleDownloadReceived(bytes: 750)
    XCTAssertEqual(manager.phase, .downloading(fraction: 1.0))
  }

  func testUnknownContentLengthStaysIndeterminate() {
    let manager = makeManager()
    manager.handleDownloadInitiated()
    manager.handleDownloadReceived(bytes: 4_096)

    XCTAssertEqual(manager.phase, .downloading(fraction: nil))
  }

  func testDownloadFractionIsCappedAtOne() {
    let manager = makeManager()
    manager.handleDownloadInitiated()
    manager.handleDownloadExpectedLength(100)
    manager.handleDownloadReceived(bytes: 250)

    XCTAssertEqual(manager.phase, .downloading(fraction: 1.0))
  }

  func testExtractionShowsInstalling() {
    let manager = makeManager()
    manager.handleExtractionStarted()

    XCTAssertEqual(manager.phase, .installing)
  }

  func testReadyToInstallHoldsTheReplyAndSurfacesTheChoice() {
    let manager = makeManager()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .notDownloaded)
    var choices: [SPUUserUpdateChoice] = []

    manager.handleReadyToInstall { choices.append($0) }

    XCTAssertTrue(choices.isEmpty)
    XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
  }

  func testInstallNowRepliesInstall() {
    let manager = makeManager()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .notDownloaded)
    var choices: [SPUUserUpdateChoice] = []
    manager.handleReadyToInstall { choices.append($0) }

    manager.installNow()

    XCTAssertEqual(choices, [.install])
    XCTAssertEqual(manager.phase, .installing)
  }

  func testInstallLaterThenScheduledPreparedCheckKeepsReadyToInstall() {
    let manager = makeManager()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .notDownloaded)
    var choices: [SPUUserUpdateChoice] = []
    manager.handleReadyToInstall { choices.append($0) }

    manager.installLater()
    manager.handleDismissInstallation()
    let choice = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .installing)

    XCTAssertEqual(choices, [.dismiss])
    XCTAssertEqual(choice, .dismiss)
    XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
  }

  func testScheduledPreparedUpdateSurfacesReadyToInstall() {
    let manager = makeManager()
    let choice = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .installing)

    XCTAssertEqual(choice, .dismiss)
    XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
  }

  func testPreparedUpdateInstallsWhenInstallNowWasRequested() {
    let manager = makeManager()
    manager.handleInstallNowRequested()

    let choice = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .installing)

    XCTAssertEqual(choice, .install)
    XCTAssertEqual(manager.phase, .installing)
  }

  func testInstallNowRepliesExactlyOnce() {
    let manager = makeManager()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .notDownloaded)
    var choices: [SPUUserUpdateChoice] = []
    manager.handleReadyToInstall { choices.append($0) }

    manager.installNow()
    manager.installNow()

    XCTAssertEqual(choices, [.install])
  }

  func testInstallFailureAfterInstallNowIsVisible() {
    let manager = makeManager()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .notDownloaded)
    manager.handleReadyToInstall { _ in }
    manager.installNow()

    manager.handleError("installer failed")

    XCTAssertEqual(manager.phase, .failed(version: "9.9.9"))
  }

  func testScheduledCheckErrorStaysSilent() {
    let manager = makeManager()
    let choice = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .notDownloaded)
    XCTAssertEqual(choice, .dismiss)

    manager.handleError("network down")

    XCTAssertEqual(manager.phase, .available(version: "9.9.9"))
  }

  func testScheduledCheckErrorWithNothingPendingIsIdle() {
    let manager = makeManager()
    manager.handleError("network down")

    XCTAssertEqual(manager.phase, .idle)
  }

  func testDismissDuringDownloadRollsBackToAvailable() {
    let manager = makeManager()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .notDownloaded)
    manager.handleDownloadInitiated()

    manager.handleDismissInstallation()

    XCTAssertEqual(manager.phase, .available(version: "9.9.9"))
  }

  func testDismissKeepsPendingRowAlive() {
    let manager = makeManager()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .notDownloaded)

    manager.handleDismissInstallation()

    XCTAssertEqual(manager.phase, .available(version: "9.9.9"))
  }

  func testNotFoundClearsPendingState() {
    let manager = makeManager()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .notDownloaded)

    manager.handleNotFound()

    XCTAssertEqual(manager.phase, .idle)
    XCTAssertNil(manager.releasePageURL)
  }
  func testCancelledInstallationCannotAuthorizeTheNextCheck() {
    let manager = makeManager()
    _ = manager.handleUpdateFound(
      version: "1.0.1", releasePage: nil, informationOnly: false, stage: .notDownloaded)
    manager.handleInstallRequested()
    XCTAssertEqual(
      manager.handleUpdateFound(
        version: "1.0.1", releasePage: nil, informationOnly: false, stage: .notDownloaded),
      .install)
    manager.handleDismissInstallation()
    XCTAssertEqual(
      manager.handleUpdateFound(
        version: "1.0.1", releasePage: nil, informationOnly: false, stage: .notDownloaded),
      .dismiss)
    manager.handleInstallRequested()
    XCTAssertEqual(
      manager.handleUpdateFound(
        version: "1.0.1", releasePage: nil, informationOnly: false, stage: .notDownloaded),
      .install)
  }

  func testInstallNowWithoutHeldReplyStartsOneCheckAndSetsBothFlags() {
    let manager = makeManager()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .installing)

    manager.handleInstallNowRequested()

    XCTAssertEqual(manager.phase, .installing)
    XCTAssertTrue(manager.installRequested)
    XCTAssertTrue(manager.installNowRequested)
    XCTAssertTrue(manager.resumeCheckPending)
  }

  func testResumedDownloadedUpdateKeepsInstallNowRequested() {
    let manager = makeManager()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .installing)
    manager.handleInstallNowRequested()

    let choice = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .downloaded)

    XCTAssertEqual(choice, .install)
    XCTAssertTrue(manager.installNowRequested)
  }

  func testReadyAfterResumedInstallNowRepliesInstallAndClearsTheFlag() {
    let manager = makeManager()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .installing)
    manager.handleInstallNowRequested()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .downloaded)
    var choices: [SPUUserUpdateChoice] = []

    manager.handleReadyToInstall { choices.append($0) }

    XCTAssertEqual(choices, [.install])
    XCTAssertFalse(manager.installNowRequested)
    XCTAssertEqual(manager.phase, .installing)
  }

  func testInstallLaterRepliesExactlyOnce() {
    let manager = makeManager()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .notDownloaded)
    var choices: [SPUUserUpdateChoice] = []
    manager.handleReadyToInstall { choices.append($0) }

    manager.installLater()
    manager.installLater()

    XCTAssertEqual(choices, [.dismiss])
    XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
  }

  func testDismissWhileInstallingKeepsReadyToInstall() {
    let manager = makeManager()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .notDownloaded)
    manager.handleReadyToInstall { _ in }
    manager.installNow()

    manager.handleDismissInstallation()

    XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
  }

  func testInstallNowWhileInstallingIsANoOp() {
    let manager = makeManager()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .notDownloaded)
    var choices: [SPUUserUpdateChoice] = []
    manager.handleReadyToInstall { choices.append($0) }
    manager.installNow()
    manager.handleReadyToInstall { choices.append($0) }
    manager.handleInstalling()

    manager.installNow()

    XCTAssertEqual(choices, [.install])
    XCTAssertFalse(manager.resumeCheckPending)
  }

  func testReadyAfterInstallNowInstallsEvenWithoutAVersion() {
    let manager = makeManager()
    manager.handleInstallNowRequested()
    var choices: [SPUUserUpdateChoice] = []

    manager.handleReadyToInstall { choices.append($0) }

    XCTAssertEqual(choices, [.install])
    XCTAssertEqual(manager.phase, .installing)
    XCTAssertFalse(manager.installNowRequested)
    XCTAssertFalse(manager.resumeCheckPending)
  }

  func testDismissedFoundUpdateDropsTheInstallNowIntent() {
    let manager = makeManager()
    manager.handleInstallNowRequested()

    XCTAssertEqual(
      manager.handleUpdateFound(
        version: "9.9.9", releasePage: nil, informationOnly: true, stage: .notDownloaded),
      .dismiss)
    XCTAssertFalse(manager.installNowRequested)

    var choices: [SPUUserUpdateChoice] = []
    XCTAssertEqual(
      manager.handleUpdateFound(
        version: "9.9.9", releasePage: nil, informationOnly: false, stage: .downloaded),
      .dismiss)
    manager.handleReadyToInstall { choices.append($0) }

    XCTAssertTrue(choices.isEmpty)
    XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
  }

  func testNotFoundDropsTheInstallNowIntent() {
    let manager = makeManager()
    manager.handleInstallNowRequested()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .downloaded)

    manager.handleNotFound()

    XCTAssertFalse(manager.installNowRequested)
  }

  func testErrorDropsTheInstallNowIntent() {
    let manager = makeManager()
    manager.handleInstallNowRequested()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .downloaded)

    manager.handleError("installer failed")

    XCTAssertEqual(manager.phase, .failed(version: "9.9.9"))
    XCTAssertFalse(manager.installNowRequested)
  }

  func testDismissInstallationDropsTheInstallNowIntent() {
    let manager = makeManager()
    manager.handleInstallNowRequested()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .downloaded)

    manager.handleDismissInstallation()

    XCTAssertFalse(manager.installNowRequested)
    XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
  }

  func testErrorWhileReadyToInstallKeepsTheCard() {
    let manager = makeManager()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .installing)

    manager.handleError("network down")

    XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
  }

  func testOldSessionDismissDuringResumeCheckKeepsTheInstallIntent() {
    let manager = makeManager()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .installing)
    manager.handleInstallNowRequested()

    manager.handleDismissInstallation()

    XCTAssertTrue(manager.installRequested)
    XCTAssertTrue(manager.installNowRequested)
    XCTAssertEqual(manager.phase, .installing)

    let choice = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .installing)

    XCTAssertEqual(choice, .install)
  }

  func testResumeCheckExhaustionFailsAndClearsTheInstallIntent() {
    let manager = makeManager()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .installing)
    manager.handleInstallNowRequested()

    manager.startInstallNowCheck(attempt: UpdateManager.installNowCheckRetryLimit)

    XCTAssertEqual(manager.phase, .failed(version: "9.9.9"))
    XCTAssertFalse(manager.installRequested)
    XCTAssertFalse(manager.installNowRequested)
    XCTAssertFalse(manager.resumeCheckPending)
  }

  func testReachingTheNewSessionStopsTheResumeLoop() {
    let manager = makeManager()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .installing)
    manager.handleInstallNowRequested()

    XCTAssertEqual(
      manager.handleUpdateFound(
        version: "9.9.9", releasePage: nil, informationOnly: false, stage: .downloaded),
      .install)
    XCTAssertFalse(manager.resumeCheckPending)

    manager.startInstallNowCheck(attempt: 0)

    XCTAssertEqual(manager.phase, .installing)
    XCTAssertTrue(manager.installRequested)
    XCTAssertTrue(manager.installNowRequested)
  }

  func testExhaustionAfterTheNewSessionStartedCannotFailTheInstall() {
    let manager = makeManager()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .installing)
    manager.handleInstallNowRequested()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .downloaded)

    manager.startInstallNowCheck(attempt: UpdateManager.installNowCheckRetryLimit)

    XCTAssertEqual(manager.phase, .installing)
    XCTAssertTrue(manager.installRequested)
    XCTAssertTrue(manager.installNowRequested)
  }

  func testInstallNowWithoutUpdaterKeepsThePhase() {
    let manager = makeManager()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .installing)

    manager.installNow()

    XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
    XCTAssertFalse(manager.installRequested)
    XCTAssertFalse(manager.installNowRequested)
  }

  func testRetryOnANotDownloadedStageStopsAtTheReadyCard() {
    let manager = makeManager()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .notDownloaded)
    manager.handleRetryRequested()

    let choice = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .notDownloaded)
    var choices: [SPUUserUpdateChoice] = []
    manager.handleReadyToInstall { choices.append($0) }

    XCTAssertEqual(choice, .install)
    XCTAssertTrue(choices.isEmpty)
    XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
    XCTAssertFalse(manager.installNowRequested)
  }

  func testRetryOnADownloadedStageStopsAtTheReadyCard() {
    let manager = makeManager()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .downloaded)
    manager.handleRetryRequested()

    let choice = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .downloaded)
    var choices: [SPUUserUpdateChoice] = []
    manager.handleReadyToInstall { choices.append($0) }

    XCTAssertEqual(choice, .dismiss)
    XCTAssertTrue(choices.isEmpty)
    XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
    XCTAssertFalse(manager.installNowRequested)
  }

  func testRetryOnAnInstallingStageStopsAtTheReadyCard() {
    let manager = makeManager()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .installing)
    manager.handleRetryRequested()

    let choice = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .installing)
    var choices: [SPUUserUpdateChoice] = []
    manager.handleReadyToInstall { choices.append($0) }

    XCTAssertEqual(choice, .dismiss)
    XCTAssertTrue(choices.isEmpty)
    XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
    XCTAssertFalse(manager.installNowRequested)
  }

  func testRetryButtonArmsACheckWithoutTheInstallNowIntent() {
    let manager = makeManager()
    var checks = 0
    manager.hasLiveUpdater = { _ in true }
    manager.resumeCheckStarter = { _ in checks += 1 }
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .notDownloaded)

    manager.retryPendingUpdate()

    XCTAssertEqual(checks, 1)
    XCTAssertTrue(manager.installRequested)
    XCTAssertFalse(manager.installNowRequested)
    XCTAssertTrue(manager.resumeCheckPending)
    XCTAssertEqual(manager.phase, .downloading(fraction: nil))
  }

  func testRetryButtonWithAHeldReplyKeepsTheCardAndTheReply() {
    let manager = makeManager()
    var checks = 0
    manager.hasLiveUpdater = { _ in true }
    manager.resumeCheckStarter = { _ in checks += 1 }
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .notDownloaded)
    var choices: [SPUUserUpdateChoice] = []
    manager.handleReadyToInstall { choices.append($0) }

    manager.retryPendingUpdate()

    XCTAssertEqual(checks, 0)
    XCTAssertTrue(choices.isEmpty)
    XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))

    manager.installNow()

    XCTAssertEqual(choices, [.install])
    XCTAssertEqual(manager.phase, .installing)
  }

  func testRetryThenInstallNowStillInstalls() {
    let manager = makeManager()
    var checks = 0
    manager.hasLiveUpdater = { _ in true }
    manager.resumeCheckStarter = { _ in checks += 1 }
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .notDownloaded)

    manager.retryPendingUpdate()
    XCTAssertEqual(
      manager.handleUpdateFound(
        version: "9.9.9", releasePage: nil, informationOnly: false, stage: .downloaded),
      .dismiss)
    XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
    manager.installLater()
    XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))

    manager.installNow()
    let choice = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .downloaded)

    XCTAssertEqual(checks, 2)
    XCTAssertEqual(choice, .install)
    XCTAssertEqual(manager.phase, .installing)
  }

  func testReadyDuringAResumeCheckKeepsTheCardAndInstallsOnce() {
    let manager = makeManager()
    manager.resumeCheckStarter = { _ in }
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .notDownloaded)
    manager.handleRetryRequested()
    var choices: [SPUUserUpdateChoice] = []
    manager.handleReadyToInstall { choices.append($0) }

    manager.startInstallNowCheck(attempt: UpdateManager.installNowCheckRetryLimit)

    XCTAssertFalse(manager.resumeCheckPending)
    XCTAssertTrue(choices.isEmpty)
    XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))

    manager.installNow()
    manager.installNow()

    XCTAssertEqual(choices, [.install])
    XCTAssertEqual(manager.phase, .installing)
  }

  private var discoveryNow: TimeInterval = 0
  private var backgroundChecks = 0

  private func makeDiscoveryManager() -> UpdateManager {
    let manager = makeManager()
    discoveryNow = 0
    backgroundChecks = 0
    manager.setAutoCheckEnabled(true)
    manager.stopBackgroundDiscovery()
    manager.monotonicClock = { [unowned self] in self.discoveryNow }
    manager.backgroundCheckStarter = { [unowned self] _ in self.backgroundChecks += 1 }
    manager.isSessionInProgress = { _ in false }
    manager.hasLiveUpdater = { _ in true }
    return manager
  }

  func testOpeningASurfaceAsksForASilentCheck() {
    let manager = makeDiscoveryManager()

    manager.surfaceDidOpen()

    XCTAssertEqual(backgroundChecks, 1)
    XCTAssertEqual(manager.phase, .idle)
    XCTAssertEqual(manager.manualCheckStatus, .idle)
  }

  func testEverySurfaceCallsTheDiscoveryHook() throws {
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()

    for surface in [
      "Sources/EncajeApp/MenuBarPopover.swift",
      "Sources/EncajeApp/UI/AboutWindowController.swift",
      "Sources/EncajeApp/EncajeApp.swift",
    ] {
      let source = try String(
        contentsOf: root.appendingPathComponent(surface), encoding: .utf8)
      XCTAssertTrue(source.contains("UpdateManager.shared.surfaceDidOpen()"), surface)
    }
  }

  func testTheDiscoveryTimerRunsOnTheRunLoopAndAsksForACheck() {
    let manager = makeDiscoveryManager()
    let fired = expectation(description: "the discovery timer asked for a silent check")
    fired.assertForOverFulfill = false
    manager.backgroundCheckStarter = { [unowned self] _ in
      self.backgroundChecks += 1
      fired.fulfill()
    }
    manager.backgroundCheckIntervalProvider = { 0.05 }

    manager.startBackgroundDiscovery()

    XCTAssertTrue(manager.backgroundDiscoveryArmed)
    waitForExpectations(timeout: 5)
    manager.stopBackgroundDiscovery()
    XCTAssertEqual(backgroundChecks, 1)
  }

  func testWakeNotificationAsksForASilentCheck() {
    let manager = makeDiscoveryManager()
    manager.startBackgroundDiscovery()
    defer { manager.stopBackgroundDiscovery() }

    NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)

    XCTAssertTrue(manager.backgroundDiscoveryArmed)
    XCTAssertEqual(backgroundChecks, 1)
  }

  func testAllTriggersShareTheFiveMinuteThrottle() {
    let manager = makeDiscoveryManager()

    manager.surfaceDidOpen()
    discoveryNow = UpdateManager.backgroundCheckThrottle - 1
    manager.requestBackgroundCheck()

    XCTAssertEqual(backgroundChecks, 1)

    discoveryNow = UpdateManager.backgroundCheckThrottle
    manager.requestBackgroundCheck()

    XCTAssertEqual(backgroundChecks, 2)
  }

  func testBackgroundCheckIsSkippedWhileASessionIsInProgress() {
    let manager = makeDiscoveryManager()
    manager.isSessionInProgress = { _ in true }

    manager.requestBackgroundCheck()

    XCTAssertEqual(backgroundChecks, 0)
  }

  func testBackgroundCheckIsSkippedWhileACardIsShowing() {
    let manager = makeDiscoveryManager()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .notDownloaded)

    manager.requestBackgroundCheck()

    XCTAssertEqual(backgroundChecks, 0)
    XCTAssertEqual(manager.phase, .available(version: "9.9.9"))
  }

  func testDisabledAutoChecksFireNoTrigger() {
    let manager = makeDiscoveryManager()
    manager.startBackgroundDiscovery()
    XCTAssertTrue(manager.backgroundDiscoveryArmed)

    manager.setAutoCheckEnabled(false)
    manager.surfaceDidOpen()

    XCTAssertEqual(backgroundChecks, 0)
    XCTAssertFalse(manager.backgroundDiscoveryArmed)

    manager.setAutoCheckEnabled(true)
    defer { manager.stopBackgroundDiscovery() }

    XCTAssertTrue(manager.backgroundDiscoveryArmed)
  }

  func testSilentCheckThatFindsNothingChangesNoVisibleState() {
    let manager = makeDiscoveryManager()
    manager.requestBackgroundCheck()

    manager.handleNotFound()

    XCTAssertEqual(manager.phase, .idle)
    XCTAssertEqual(manager.manualCheckStatus, .idle)
    XCTAssertNil(manager.pendingVersion)
  }

  func testSilentCheckThatFailsChangesNoVisibleState() {
    let manager = makeDiscoveryManager()
    manager.requestBackgroundCheck()

    manager.handleError("offline")

    XCTAssertEqual(manager.phase, .idle)
    XCTAssertEqual(manager.manualCheckStatus, .idle)
  }

  func testSilentCheckOnAPreparedUpdateStillWaitsForInstallNow() {
    let manager = makeDiscoveryManager()
    manager.requestBackgroundCheck()

    let choice = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .downloaded)

    XCTAssertEqual(choice, .dismiss)
    XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
  }

  func testManualCheckIsNeverThrottled() {
    let manager = makeDiscoveryManager()
    var userChecks = 0
    manager.userCheckStarter = { _ in userChecks += 1 }
    manager.requestBackgroundCheck()

    manager.checkForUpdatesManually()
    manager.checkForUpdatesManually()

    XCTAssertEqual(userChecks, 2)
    XCTAssertEqual(manager.manualCheckStatus, .checking)
  }

  func testManualCheckDuringASilentSessionRunsWhenTheSessionEnds() {
    let manager = makeDiscoveryManager()
    var sessionInProgress = true
    var userChecks = 0
    manager.isSessionInProgress = { _ in sessionInProgress }
    manager.userCheckStarter = { _ in userChecks += 1 }
    manager.manualCheckStarter = { _ in }

    manager.checkForUpdatesManually()

    XCTAssertEqual(manager.manualCheckStatus, .checking)
    XCTAssertEqual(userChecks, 0)

    sessionInProgress = false
    manager.startManualCheck(attempt: 1)

    XCTAssertEqual(userChecks, 1)
    XCTAssertEqual(manager.manualCheckStatus, .checking)

    manager.handleNotFound()

    XCTAssertEqual(manager.manualCheckStatus, .upToDate)
  }

  func testManualCheckGivesUpQuietlyWhenTheSessionNeverEnds() {
    let manager = makeDiscoveryManager()
    var userChecks = 0
    manager.isSessionInProgress = { _ in true }
    manager.userCheckStarter = { _ in userChecks += 1 }
    manager.manualCheckStarter = { _ in }

    manager.checkForUpdatesManually()
    XCTAssertEqual(manager.manualCheckStatus, .checking)

    manager.startManualCheck(attempt: UpdateManager.installNowCheckRetryLimit)

    XCTAssertEqual(userChecks, 0)
    XCTAssertEqual(manager.manualCheckStatus, .idle)
    XCTAssertEqual(manager.phase, .idle)
  }

  func testUpdateClickDuringTheSilentSessionTeardownStillDownloads() {
    let manager = makeDiscoveryManager()
    var sessionInProgress = true
    var userChecks = 0
    manager.isSessionInProgress = { _ in sessionInProgress }
    manager.userCheckStarter = { _ in userChecks += 1 }
    manager.resumeCheckStarter = { _ in }
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .notDownloaded)

    manager.installPendingUpdate()

    XCTAssertEqual(manager.phase, .downloading(fraction: nil))
    XCTAssertEqual(userChecks, 0)

    sessionInProgress = false
    manager.startInstallNowCheck(attempt: 1)

    XCTAssertEqual(userChecks, 1)
    XCTAssertFalse(manager.resumeCheckPending)
    XCTAssertFalse(manager.installNowRequested)

    let choice = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .downloaded)
    var choices: [SPUUserUpdateChoice] = []
    manager.handleReadyToInstall { choices.append($0) }

    XCTAssertEqual(choice, .dismiss)
    XCTAssertTrue(choices.isEmpty)
    XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
  }

  func testUpdateClickDuringARunningDownloadIsIgnored() {
    let manager = makeDiscoveryManager()
    var userChecks = 0
    var resumeStarts = 0
    manager.isSessionInProgress = { _ in true }
    manager.userCheckStarter = { _ in userChecks += 1 }
    manager.resumeCheckStarter = { _ in resumeStarts += 1 }
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .notDownloaded)
    manager.installPendingUpdate()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .notDownloaded)
    manager.handleDownloadInitiated()
    manager.handleDownloadExpectedLength(1_000)
    manager.handleDownloadReceived(bytes: 400)
    XCTAssertEqual(manager.phase, .downloading(fraction: 0.4))
    XCTAssertEqual(resumeStarts, 1)

    manager.installPendingUpdate()

    XCTAssertEqual(manager.phase, .downloading(fraction: 0.4))
    XCTAssertFalse(manager.resumeCheckPending)
    XCTAssertEqual(resumeStarts, 1)
    XCTAssertEqual(userChecks, 0)
  }

  func testUpdateClickWhileInstallingIsIgnored() {
    let manager = makeDiscoveryManager()
    var resumeStarts = 0
    manager.isSessionInProgress = { _ in true }
    manager.resumeCheckStarter = { _ in resumeStarts += 1 }
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .notDownloaded)
    manager.installPendingUpdate()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .notDownloaded)
    manager.handleExtractionStarted()

    manager.installPendingUpdate()

    XCTAssertEqual(manager.phase, .installing)
    XCTAssertFalse(manager.resumeCheckPending)
    XCTAssertEqual(resumeStarts, 1)
  }

  func testRetryAfterAFailedDownloadStillStartsTheResumePath() {
    let manager = makeDiscoveryManager()
    var resumeStarts = 0
    manager.isSessionInProgress = { _ in true }
    manager.resumeCheckStarter = { _ in resumeStarts += 1 }
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .notDownloaded)
    manager.installPendingUpdate()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .notDownloaded)
    manager.handleError("download died")
    XCTAssertEqual(manager.phase, .failed(version: "9.9.9"))

    manager.retryPendingUpdate()

    XCTAssertEqual(manager.phase, .downloading(fraction: nil))
    XCTAssertTrue(manager.resumeCheckPending)
    XCTAssertEqual(resumeStarts, 2)
  }

}
