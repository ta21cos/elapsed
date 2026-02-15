import Foundation
import SwiftData

@Model
final class DailySummary {
    @Attribute(.unique) var date: String
    var totalActiveSeconds: Int
    var totalInactiveSeconds: Int
    var totalBreaks: Int
    var longestStreakSeconds: Int
    var sessionCount: Int
    var firstSessionStart: Date?
    var lastSessionEnd: Date?

    init(date: String) {
        self.date = date
        self.totalActiveSeconds = 0
        self.totalInactiveSeconds = 0
        self.totalBreaks = 0
        self.longestStreakSeconds = 0
        self.sessionCount = 0
    }
}
