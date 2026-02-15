import Foundation

@Observable
final class BreakReminderService {
    enum BreakState {
        case working
        case reminderSent
        case onBreak
    }

    private let sessionManager: SessionManager
    private let notificationService: NotificationService
    private let settings: AppSettings

    private(set) var breakState: BreakState = .working
    private(set) var breakTimeRemaining: TimeInterval = 0
    private var breakTimer: Timer?
    private var breakStartTime: Date?
    private var snoozeTimer: Timer?

    var timeUntilBreak: TimeInterval {
        let threshold = TimeInterval(settings.workDurationMinutes * 60)
        let elapsed = TimeInterval(sessionManager.currentStreakSeconds)
        return max(0, threshold - elapsed)
    }

    init(
        sessionManager: SessionManager,
        notificationService: NotificationService,
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
        if sessionManager.currentStreakSeconds >= threshold {
            notificationService.sendBreakReminder(
                streakMinutes: settings.workDurationMinutes
            )
            breakState = .reminderSent
        }
    }

    func startBreak() {
        breakState = .onBreak
        breakStartTime = Date()
        breakTimeRemaining = TimeInterval(settings.breakDurationMinutes * 60)

        breakTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.Polling.streakUpdateIntervalSeconds,
            repeats: true
        ) { [weak self] _ in
            guard let self else { return }
            self.breakTimeRemaining -= 1

            if self.breakTimeRemaining <= 0 {
                self.endBreak(countAsBreak: true)
            }
        }
        breakTimer?.tolerance = 0.5
    }

    func endBreak(countAsBreak: Bool? = nil) {
        breakTimer?.invalidate()
        breakTimer = nil

        let shouldCount: Bool
        if let explicit = countAsBreak {
            shouldCount = explicit
        } else if let start = breakStartTime {
            let elapsed = Date().timeIntervalSince(start)
            let threshold = TimeInterval(settings.breakResetThresholdMinutes * 60)
            shouldCount = elapsed >= threshold
        } else {
            shouldCount = false
        }

        breakState = .working
        breakTimeRemaining = 0
        breakStartTime = nil

        if shouldCount {
            notificationService.sendReturnNotification()
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
        breakTimer?.invalidate()
        breakTimer = nil
        snoozeTimer?.invalidate()
        snoozeTimer = nil
        breakState = .working
        breakTimeRemaining = 0
        breakStartTime = nil
    }

    private func setupNotificationCallbacks() {
        notificationService.onTakeBreak = { [weak self] in
            self?.startBreak()
        }
        notificationService.onSnooze = { [weak self] in
            self?.snooze()
        }
    }
}
