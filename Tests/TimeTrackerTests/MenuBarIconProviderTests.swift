import XCTest
@testable import TimeTracker

final class MenuBarIconProviderTests: XCTestCase {
    func testActiveNormal() {
        let icon = MenuBarIconProvider.icon(
            breakState: .working,
            activityState: .active,
            isTracking: true,
            streakSeconds: 1800,
            workDurationMinutes: 50
        )
        XCTAssertEqual(icon, Constants.Icon.activeNormal)
    }

    func testActiveWarning() {
        let icon = MenuBarIconProvider.icon(
            breakState: .working,
            activityState: .active,
            isTracking: true,
            streakSeconds: 2400,
            workDurationMinutes: 50
        )
        XCTAssertEqual(icon, Constants.Icon.activeWarning)
    }

    func testWarningThresholdDynamic() {
        let threshold = MenuBarIconProvider.warningThresholdSeconds(workDurationMinutes: 30)
        XCTAssertEqual(threshold, 1200) // (30-10) * 60
    }

    func testWarningThresholdMinimum() {
        let threshold = MenuBarIconProvider.warningThresholdSeconds(workDurationMinutes: 15)
        XCTAssertEqual(threshold, 600) // max(10, 15-10) * 60 = 10 * 60
    }

    func testOnBreak() {
        let icon = MenuBarIconProvider.icon(
            breakState: .onBreak,
            activityState: .active,
            isTracking: true,
            streakSeconds: 0,
            workDurationMinutes: 50
        )
        XCTAssertEqual(icon, Constants.Icon.onBreak)
    }

    func testInactive() {
        let icon = MenuBarIconProvider.icon(
            breakState: .working,
            activityState: .inactive,
            isTracking: true,
            streakSeconds: 0,
            workDurationMinutes: 50
        )
        XCTAssertEqual(icon, Constants.Icon.inactive)
    }

    func testStopped() {
        let icon = MenuBarIconProvider.icon(
            breakState: .working,
            activityState: .active,
            isTracking: false,
            streakSeconds: 0,
            workDurationMinutes: 50
        )
        XCTAssertEqual(icon, Constants.Icon.stopped)
    }
}
