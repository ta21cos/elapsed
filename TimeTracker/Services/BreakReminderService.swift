import Foundation

@Observable
final class BreakReminderService {
    enum BreakState {
        case working
        case reminderSent
        case onBreak
    }

    private let sessionManager: SessionManager
    private var notificationService: any NotificationSending
    private let settings: AppSettings
    private let clock: Clock

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
        notificationService: any NotificationSending,
        settings: AppSettings,
        clock: Clock = SystemClock()
    ) {
        self.sessionManager = sessionManager
        self.notificationService = notificationService
        self.settings = settings
        self.clock = clock
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
        breakStartTime = clock.now
        breakTimeRemaining = TimeInterval(settings.breakDurationMinutes * 60)

        breakTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.Polling.streakUpdateIntervalSeconds,
            repeats: true
        ) { [weak self] _ in
            self?.tickBreak()
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
            let elapsed = clock.now.timeIntervalSince(start)
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

    func tickBreak() {
        breakTimeRemaining -= 1

        if breakTimeRemaining <= 0 {
            endBreak(countAsBreak: true)
        }
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
