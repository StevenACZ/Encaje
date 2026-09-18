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
    XCTAssertFalse(manager.retryRequested)
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
    XCTAssertFalse(manager.retryRequested)
    XCTAssertFalse(manager.installNowRequested)
  }

  func testRetryThenInstallNowStillInstalls() {
    let manager = makeManager()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .notDownloaded)
    manager.handleRetryRequested()
    XCTAssertEqual(
      manager.handleUpdateFound(
        version: "9.9.9", releasePage: nil, informationOnly: false, stage: .downloaded),
      .dismiss)
    XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))

    manager.handleInstallNowRequested()
    let choice = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false, stage: .downloaded)

    XCTAssertEqual(choice, .install)
    XCTAssertEqual(manager.phase, .installing)
    XCTAssertFalse(manager.retryRequested)
  }

}
