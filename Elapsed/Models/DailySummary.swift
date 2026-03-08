import Foundation
import SwiftData

@Model
final class DailySummary {
    @Attribute(.unique) var date: String
    var totalActiveSeconds: Int
    var sessionCount: Int
    var firstSessionStart: Date?
    var lastSessionEnd: Date?

    init(date: String) {
        self.date = date
        self.totalActiveSeconds = 0
        self.sessionCount = 0
    }
}
