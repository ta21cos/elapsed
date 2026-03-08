import Foundation
@testable import Elapsed

final class MockNotificationService: NotificationSending {
    var onTakeBreak: (() -> Void)?
    var onSnooze: (() -> Void)?

    private(set) var breakReminderCount = 0
    private(set) var lastBreakReminderMinutes: Int?
    private(set) var returnNotificationCount = 0
    private(set) var cancelCount = 0

    func sendBreakReminder(streakMinutes: Int) {
        breakReminderCount += 1
        lastBreakReminderMinutes = streakMinutes
    }

    func sendReturnNotification() {
        returnNotificationCount += 1
    }

    func cancelPendingNotifications() {
        cancelCount += 1
    }
}
