import UserNotifications

protocol NotificationSending {
    func sendBreakReminder(streakMinutes: Int)
    func sendReturnNotification()
    func cancelPendingNotifications()
}

final class NotificationService: NSObject, UNUserNotificationCenterDelegate, NotificationSending {
    private let settings: AppSettings
    var onTakeBreak: (() -> Void)?
    var onSnooze: (() -> Void)?

    init(settings: AppSettings) {
        self.settings = settings
    }

    func setup() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        registerCategories()
    }

    func registerCategories() {
        let center = UNUserNotificationCenter.current()

        let takeBreakAction = UNNotificationAction(
            identifier: Constants.Notification.takeBreakActionId,
            title: "休憩する",
            options: [.foreground]
        )
        let snoozeAction = UNNotificationAction(
            identifier: Constants.Notification.snoozeActionId,
            title: "\(settings.snoozeDurationMinutes)分後に再通知",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: Constants.Notification.breakCategoryId,
            actions: [takeBreakAction, snoozeAction],
            intentIdentifiers: []
        )
        center.setNotificationCategories([category])
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func sendBreakReminder(streakMinutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "休憩しましょう"
        content.body = "\(streakMinutes)分間連続で作業しています。立ち上がってストレッチしましょう！"
        content.categoryIdentifier = Constants.Notification.breakCategoryId

        if settings.soundEnabled {
            content.sound = .default
        }

        let request = UNNotificationRequest(
            identifier: "\(Constants.Notification.breakReminderId)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func sendReturnNotification() {
        let content = UNMutableNotificationContent()
        content.title = "休憩終了"
        content.body = "リフレッシュできましたか？作業に戻りましょう！"

        if settings.soundEnabled {
            content.sound = .default
        }

        let request = UNNotificationRequest(
            identifier: Constants.Notification.returnNotificationId,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func cancelPendingNotifications() {
        UNUserNotificationCenter.current()
            .removeAllPendingNotificationRequests()
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        switch response.actionIdentifier {
        case Constants.Notification.takeBreakActionId:
            await MainActor.run { onTakeBreak?() }
        case Constants.Notification.snoozeActionId:
            await MainActor.run { onSnooze?() }
        default:
            break
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
