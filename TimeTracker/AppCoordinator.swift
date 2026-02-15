import Foundation
import SwiftData

@Observable
@MainActor
final class AppCoordinator {
    let settings: AppSettings
    let permissionManager: PermissionManager
    let notificationService: NotificationService
    let modelContainer: ModelContainer
    let sessionManager: SessionManager
    let activityMonitor: ActivityMonitorService
    let breakReminder: BreakReminderService

    private(set) var currentMenuBarIcon: String = Constants.Icon.activeNormal
    private var iconUpdateTimer: Timer?
    private var hasStarted = false

    init() {
        let settings = AppSettings()
        self.settings = settings
        self.permissionManager = PermissionManager()
        self.notificationService = NotificationService(settings: settings)

        do {
            self.modelContainer = try ModelContainer(for: Session.self, DailySummary.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        let context = modelContainer.mainContext
        let sm = SessionManager(modelContext: context, settings: settings)
        self.sessionManager = sm

        let am = ActivityMonitorService(settings: settings)
        self.activityMonitor = am

        let br = BreakReminderService(
            sessionManager: sm,
            notificationService: notificationService,
            settings: settings
        )
        self.breakReminder = br

        notificationService.setup()
        setupActivityCallbacks()
        startIconUpdate()
    }

    func onAppear() {
        guard !hasStarted else { return }
        hasStarted = true

        if settings.hasCompletedOnboarding {
            startMonitoring()
        }
    }

    func startMonitoring() {
        activityMonitor.start()
    }

    // MARK: - Private

    private func setupActivityCallbacks() {
        activityMonitor.onStateChange = { [weak self] state in
            guard let self else { return }
            self.sessionManager.handleActivityChange(state)

            if state == .active {
                self.breakReminder.checkAndNotify()
            }
        }
    }

    private func startIconUpdate() {
        iconUpdateTimer = Timer.scheduledTimer(
            withTimeInterval: 2.0,
            repeats: true
        ) { [weak self] _ in
            self?.updateMenuBarIcon()
        }
        iconUpdateTimer?.tolerance = 1.0
    }

    private func updateMenuBarIcon() {
        currentMenuBarIcon = MenuBarIconProvider.icon(
            breakState: breakReminder.breakState,
            activityState: activityMonitor.state,
            isTracking: sessionManager.isTracking,
            streakSeconds: sessionManager.currentStreakSeconds,
            workDurationMinutes: settings.workDurationMinutes
        )
    }
}
