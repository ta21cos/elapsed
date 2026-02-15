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
        // workDuration=30: buffer=min(10, 29)=10, threshold=(30-10)*60=1200
        let threshold = MenuBarIconProvider.warningThresholdSeconds(workDurationMinutes: 30)
        XCTAssertEqual(threshold, 1200)
    }

    func testWarningThresholdSmallDuration() {
        // workDuration=3: buffer=min(10, 2)=2, threshold=(3-2)*60=60
        let threshold = MenuBarIconProvider.warningThresholdSeconds(workDurationMinutes: 3)
        XCTAssertEqual(threshold, 60)
    }

    func testWarningThresholdMinimumOneMiute() {
        // workDuration=1: buffer=min(10, 0)=0, threshold=(1-0)*60=60
        let threshold = MenuBarIconProvider.warningThresholdSeconds(workDurationMinutes: 1)
        XCTAssertEqual(threshold, 60)
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
