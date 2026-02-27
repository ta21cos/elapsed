import Foundation

@Observable
final class BreakReminderService {
    enum BreakState {
        case working
        case reminderSent
    }

    private let sessionManager: SessionManager
    private var notificationService: any NotificationSending
    private let settings: AppSettings

    private(set) var breakState: BreakState = .working
    private var snoozeTimer: Timer?

    var timeUntilBreak: TimeInterval {
        let threshold = TimeInterval(settings.workDurationMinutes * 60)
        let elapsed = TimeInterval(sessionManager.currentSessionSeconds)
        return max(0, threshold - elapsed)
    }

    init(
        sessionManager: SessionManager,
        notificationService: any NotificationSending,
        settings: AppSettings
    ) {
        self.sessionManager = sessionManager
        self.notificationService = notificationService
        self.settings = settings
        setupNotificationCallbacks()
    }

    func checkAndNotify() {
        guard breakState == .working else { return }

        let threshold = settings.workDurationMinutes * 60
        if sessionManager.currentSessionSeconds >= threshold {
            notificationService.sendBreakReminder(
                streakMinutes: settings.workDurationMinutes
            )
            breakState = .reminderSent
        }
    }

    func snooze() {
        breakState = .working
        snoozeTimer?.invalidate()
        snoozeTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(settings.snoozeDurationMinutes * 60),
            repeats: false
        ) { [weak self] _ in
            self?.checkAndNotify()
        }
        snoozeTimer?.tolerance = 5.0
    }

    func reset() {
        snoozeTimer?.invalidate()
        snoozeTimer = nil
        breakState = .working
    }

    private func setupNotificationCallbacks() {
        notificationService.onTakeBreak = { [weak self] in
            self?.reset()
        }
        notificationService.onSnooze = { [weak self] in
            self?.snooze()
        }
    }
}
