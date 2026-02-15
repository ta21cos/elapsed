import Foundation
import SwiftData

@Model
final class Session {
    var id: UUID
    var startTime: Date
    var endTime: Date?
    var activeSeconds: Int
    var inactiveSeconds: Int
    var breaksTaken: Int
    var longestStreakSeconds: Int
    var isActive: Bool

    init() {
        self.id = UUID()
        self.startTime = Date()
        self.endTime = nil
        self.activeSeconds = 0
        self.inactiveSeconds = 0
        self.breaksTaken = 0
        self.longestStreakSeconds = 0
        self.isActive = true
    }
}
