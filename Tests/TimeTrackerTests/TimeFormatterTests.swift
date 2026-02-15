import XCTest
@testable import TimeTracker

final class TimeFormatterTests: XCTestCase {
    func testFormatDurationMinutesOnly() {
        XCTAssertEqual(TimeFormatter.formatDuration(300), "5分")
    }

    func testFormatDurationHoursAndMinutes() {
        XCTAssertEqual(TimeFormatter.formatDuration(3661), "1時間1分")
    }

    func testFormatDurationZero() {
        XCTAssertEqual(TimeFormatter.formatDuration(0), "0分")
    }

    func testFormatCountdown() {
        XCTAssertEqual(TimeFormatter.formatCountdown(125), "2:05")
    }

    func testDateString() {
        let components = DateComponents(year: 2024, month: 3, day: 15, hour: 12, minute: 30)
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: components)!
        XCTAssertEqual(TimeFormatter.dateString(from: date), "2024-03-15")
    }
}
