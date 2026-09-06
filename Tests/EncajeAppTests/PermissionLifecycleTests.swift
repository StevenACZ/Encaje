import XCTest

@testable import EncajeApp

final class PermissionLifecycleTests: XCTestCase {
  @MainActor func testDismissPreservesPendingSetupAcrossCoordinatorInstances() {
    let name = "Encaje.Tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    defaults.set(true, forKey: "permissionSetupPending")
    defaults.set(true, forKey: "welcomeComplete")
    let coordinator = PermissionCoordinator(defaults: defaults)
    coordinator.dismiss()
    XCTAssertTrue(defaults.bool(forKey: "permissionSetupPending"))
    XCTAssertTrue(defaults.bool(forKey: "welcomeComplete"))
    let resumed = PermissionCoordinator(defaults: defaults)
    resumed.dismiss()
    XCTAssertTrue(defaults.bool(forKey: "permissionSetupPending"))
    resumed.completeSetup()
    XCTAssertFalse(defaults.bool(forKey: "permissionSetupPending"))
  }
}
