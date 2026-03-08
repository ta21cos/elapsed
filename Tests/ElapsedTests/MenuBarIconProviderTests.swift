import XCTest
@testable import Elapsed

final class MenuBarIconProviderTests: XCTestCase {
    func testActiveNormal() {
        let icon = MenuBarIconProvider.icon(
            breakState: .working,
            activityState: .active,
            isTracking: true,
            sessionSeconds: 1800,
            workDurationMinutes: 50
        )
        XCTAssertEqual(icon, Constants.Icon.activeNormal)
    }

    func testActiveWarning() {
        let icon = MenuBarIconProvider.icon(
            breakState: .working,
            activityState: .active,
            isTracking: true,
            sessionSeconds: 2400,
            workDurationMinutes: 50
        )
        XCTAssertEqual(icon, Constants.Icon.activeWarning)
    }

    func testWarningThresholdDynamic() {
        let threshold = MenuBarIconProvider.warningThresholdSeconds(workDurationMinutes: 30)
        XCTAssertEqual(threshold, 1200)
    }

    func testWarningThresholdSmallDuration() {
        let threshold = MenuBarIconProvider.warningThresholdSeconds(workDurationMinutes: 3)
        XCTAssertEqual(threshold, 60)
    }

    func testWarningThresholdMinimumOneMinute() {
        let threshold = MenuBarIconProvider.warningThresholdSeconds(workDurationMinutes: 1)
        XCTAssertEqual(threshold, 60)
    }

    func testReminderSent() {
        let icon = MenuBarIconProvider.icon(
            breakState: .reminderSent,
            activityState: .active,
            isTracking: true,
            sessionSeconds: 0,
            workDurationMinutes: 50
        )
        XCTAssertEqual(icon, Constants.Icon.activeWarning)
    }

    func testInactive() {
        let icon = MenuBarIconProvider.icon(
            breakState: .working,
            activityState: .inactive,
            isTracking: true,
            sessionSeconds: 0,
            workDurationMinutes: 50
        )
        XCTAssertEqual(icon, Constants.Icon.inactive)
    }

    func testStopped() {
        let icon = MenuBarIconProvider.icon(
            breakState: .working,
            activityState: .active,
            isTracking: false,
            sessionSeconds: 0,
            workDurationMinutes: 50
        )
        XCTAssertEqual(icon, Constants.Icon.stopped)
    }
}
