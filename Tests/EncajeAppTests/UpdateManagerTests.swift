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
      informationOnly: false
    )

    XCTAssertEqual(choice, .dismiss)
    XCTAssertEqual(manager.phase, .available(version: "9.9.9"))
    XCTAssertEqual(manager.releasePageURL?.absoluteString, "https://example.com/release")
  }

  func testInformationOnlyUpdateNeverInstalls() {
    let manager = makeManager()
    manager.installPendingUpdate()

    let choice = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: true)

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

  func testExtractionAndReadyToInstallShowInstalling() {
    let manager = makeManager()
    manager.handleExtractionStarted()
    XCTAssertEqual(manager.phase, .installing)

    XCTAssertEqual(manager.handleReadyToInstall(), .install)
    XCTAssertEqual(manager.phase, .installing)
  }

  func testScheduledCheckErrorStaysSilent() {
    let manager = makeManager()
    let choice = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false)
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
      version: "9.9.9", releasePage: nil, informationOnly: false)
    manager.handleDownloadInitiated()

    manager.handleDismissInstallation()

    XCTAssertEqual(manager.phase, .available(version: "9.9.9"))
  }

  func testDismissKeepsPendingRowAlive() {
    let manager = makeManager()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false)

    manager.handleDismissInstallation()

    XCTAssertEqual(manager.phase, .available(version: "9.9.9"))
  }

  func testNotFoundClearsPendingState() {
    let manager = makeManager()
    _ = manager.handleUpdateFound(
      version: "9.9.9", releasePage: nil, informationOnly: false)

    manager.handleNotFound()

    XCTAssertEqual(manager.phase, .idle)
    XCTAssertNil(manager.releasePageURL)
  }
  func testCancelledInstallationCannotAuthorizeTheNextCheck() {
    let manager = makeManager()
    _ = manager.handleUpdateFound(version: "1.0.1", releasePage: nil, informationOnly: false)
    manager.handleInstallRequested()
    XCTAssertEqual(
      manager.handleUpdateFound(version: "1.0.1", releasePage: nil, informationOnly: false),
      .install)
    manager.handleDismissInstallation()
    XCTAssertEqual(
      manager.handleUpdateFound(version: "1.0.1", releasePage: nil, informationOnly: false),
      .dismiss)
    manager.handleInstallRequested()
    XCTAssertEqual(
      manager.handleUpdateFound(version: "1.0.1", releasePage: nil, informationOnly: false),
      .install)
  }

}
