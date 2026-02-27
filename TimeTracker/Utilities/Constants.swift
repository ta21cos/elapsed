import Foundation

enum Constants {
    enum Polling {
        static let intervalSeconds: TimeInterval = 10.0
        static let streakUpdateIntervalSeconds: TimeInterval = 1.0
    }

    enum Notification {
        static let breakCategoryId = "breakReminder"
        static let takeBreakActionId = "takeBreak"
        static let snoozeActionId = "snooze"
        static let breakReminderId = "breakReminder"
        static let returnNotificationId = "returnNotification"
    }

    enum Icon {
        static let activeNormal = "timer"
        static let activeWarning = "timer.circle.fill"
        static let inactive = "moon.zzz"
        static let stopped = "stop.circle"
    }

    enum Defaults {
        static let workDurationMinutes = 50
        static let breakDurationMinutes = 10
        static let inactivityThresholdMinutes = 5
        static let snoozeDurationMinutes = 5
        static let warningBufferMinutes = 10
        static let minimumWarningMinutes = 10
    }
}
