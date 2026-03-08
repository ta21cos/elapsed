import XCTest
@testable import Elapsed

final class TimeFormatterTests: XCTestCase {
    func testFormatDurationMinutesAndSeconds() {
        XCTAssertEqual(TimeFormatter.formatDuration(300), "5分0秒")
    }

    func testFormatDurationMinutesWithSeconds() {
        XCTAssertEqual(TimeFormatter.formatDuration(125), "2分5秒")
    }

    func testFormatDurationHoursAndMinutes() {
        XCTAssertEqual(TimeFormatter.formatDuration(3661), "1時間1分")
    }

    func testFormatDurationZero() {
        XCTAssertEqual(TimeFormatter.formatDuration(0), "0秒")
    }

    func testFormatDurationSecondsOnly() {
        XCTAssertEqual(TimeFormatter.formatDuration(45), "45秒")
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
