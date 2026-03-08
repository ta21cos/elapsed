import XCTest
@testable import Elapsed

final class AppSettingsTests: XCTestCase {
    func testDefaultValues() {
        let suiteName = "test-defaults-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.workDurationMinutes, Constants.Defaults.workDurationMinutes)
        XCTAssertEqual(settings.breakDurationMinutes, Constants.Defaults.breakDurationMinutes)
        XCTAssertEqual(settings.inactivityThresholdMinutes, Constants.Defaults.inactivityThresholdMinutes)
        XCTAssertEqual(settings.snoozeDurationMinutes, Constants.Defaults.snoozeDurationMinutes)
        XCTAssertTrue(settings.soundEnabled)
        XCTAssertFalse(settings.hasCompletedOnboarding)
    }

    func testPersistsChanges() {
        let suiteName = "test-persist-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let settings = AppSettings(defaults: defaults)

        settings.workDurationMinutes = 25

        XCTAssertEqual(defaults.integer(forKey: "workDurationMinutes"), 25)
    }

    func testIsolatedUserDefaults() {
        let settings1 = TestHelpers.makeSettings(workDuration: 30)
        let settings2 = TestHelpers.makeSettings(workDuration: 60)

        XCTAssertEqual(settings1.workDurationMinutes, 30)
        XCTAssertEqual(settings2.workDurationMinutes, 60)
    }

    func testCustomValues() {
        let settings = TestHelpers.makeSettings(
            workDuration: 25,
            breakDuration: 5,
            inactivityThreshold: 3,
            snoozeDuration: 10
        )

        XCTAssertEqual(settings.workDurationMinutes, 25)
        XCTAssertEqual(settings.breakDurationMinutes, 5)
        XCTAssertEqual(settings.inactivityThresholdMinutes, 3)
        XCTAssertEqual(settings.snoozeDurationMinutes, 10)
    }
}
