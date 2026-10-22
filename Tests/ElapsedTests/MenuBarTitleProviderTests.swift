import XCTest
@testable import Elapsed

final class MenuBarTitleProviderTests: XCTestCase {
    func testActiveSessionShowsHoursAndMinutes() {
        let title = MenuBarTitleProvider.title(
            hasActiveSession: true, sessionSeconds: 3_725, showSeconds: false, debugMode: false, idleSeconds: 0
        )
        XCTAssertEqual(title, "01:02")
    }

    func testActiveSessionShowsSecondsWhenEnabled() {
        let title = MenuBarTitleProvider.title(
            hasActiveSession: true, sessionSeconds: 3_725, showSeconds: true, debugMode: false, idleSeconds: 0
        )
        XCTAssertEqual(title, "01:02:05")
    }

    func testTitleStaysTheSameWithinAMinuteWhenSecondsAreHidden() {
        let titles = (60..<120).map {
            MenuBarTitleProvider.title(
                hasActiveSession: true, sessionSeconds: $0, showSeconds: false, debugMode: false, idleSeconds: 0
            )
        }
        XCTAssertEqual(Set(titles), ["00:01"])
    }

    func testNoActiveSessionShowsNothing() {
        let title = MenuBarTitleProvider.title(
            hasActiveSession: false, sessionSeconds: 3_725, showSeconds: false, debugMode: false, idleSeconds: 0
        )
        XCTAssertEqual(title, "")
    }

    func testDebugModeAppendsActiveMarkerWhileInputIsRecent() {
        let title = MenuBarTitleProvider.title(
            hasActiveSession: true, sessionSeconds: 3_725, showSeconds: false, debugMode: true, idleSeconds: 3
        )
        XCTAssertEqual(title, "01:02 ●")
    }

    func testDebugModeShowsIdleSecondsWithoutASession() {
        let title = MenuBarTitleProvider.title(
            hasActiveSession: false, sessionSeconds: 0, showSeconds: false, debugMode: true, idleSeconds: 42.7
        )
        XCTAssertEqual(title, "○42s")
    }
}
