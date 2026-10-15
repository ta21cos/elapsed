import AppKit
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

    private(set) var currentMenuBarIcon: String = Constants.Icon.activeNormal {
        didSet { PerfMetrics.shared.count(.assignMenuBarIcon) }
    }
    private(set) var currentMenuBarTitle: String = "" {
        didSet { PerfMetrics.shared.count(.assignMenuBarTitle) }
    }
    private var iconUpdateTimer: Timer?
    private var activityToken: NSObjectProtocol?
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
        setupSessionTickCallback()
        startIconUpdate()
        startPerfMetrics()

        startIfNeeded()
    }

    func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true

        if settings.hasCompletedOnboarding {
            startMonitoring()
        }
    }

    func startMonitoring() {
        PerfMetrics.shared.count(.startMonitoring)
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Monitoring user activity for time tracking"
        )
        activityMonitor.start()
    }

    // MARK: - Private

    private func setupActivityCallbacks() {
        activityMonitor.onStateChange = { [weak self] state in
            guard let self else { return }
            self.sessionManager.handleActivityChange(state)

            switch state {
            case .active:
                self.breakReminder.checkAndNotify()
            case .inactive:
                self.breakReminder.reset()
            }

            self.updateMenuBarIcon()
        }
    }

    private func setupSessionTickCallback() {
        sessionManager.onSessionTick = { [weak self] _ in
            guard let self else { return }
            if self.sessionManager.isTracking && self.activityMonitor.state == .active {
                self.breakReminder.checkAndNotify()
            }
        }
    }

    private func startIconUpdate() {
        iconUpdateTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in
            PerfMetrics.shared.count(.timerIcon)
            self?.updateMenuBarIcon()
        }
        iconUpdateTimer?.tolerance = 0.1
    }

    private func startPerfMetrics() {
        let context = modelContainer.mainContext
        PerfMetrics.shared.registerGauge("sessions.total") {
            Double((try? context.fetchCount(FetchDescriptor<Session>())) ?? -1)
        }
        // debugMode はメニューバーのタイトルにアイドル秒数を毎秒表示し、計測対象の再描画回数を変えてしまうため、別の設定で有効にする
        PerfMetrics.shared.start(
            interval: Constants.Polling.perfReportIntervalSeconds,
            writer: PerfCSVWriter()
        ) { [weak self] in
            self?.settings.perfLoggingEnabled == true
        }
    }

    private func updateMenuBarIcon() {
        currentMenuBarIcon = MenuBarIconProvider.icon(
            breakState: breakReminder.breakState,
            activityState: activityMonitor.state,
            isTracking: sessionManager.isTracking,
            sessionSeconds: sessionManager.currentSessionSeconds,
            workDurationMinutes: settings.workDurationMinutes
        )

        if sessionManager.isTracking, sessionManager.currentSession != nil {
            var title = TimeFormatter.compactDuration(sessionManager.currentSessionSeconds, showSeconds: settings.showSeconds)
            if settings.debugMode {
                let idle = activityMonitor.idleSeconds
                let debugSuffix = idle < Constants.Polling.intervalSeconds ? "●" : "○\(Int(idle))s"
                title += " \(debugSuffix)"
            }
            currentMenuBarTitle = title
        } else if settings.debugMode {
            let idle = activityMonitor.idleSeconds
            currentMenuBarTitle = idle < Constants.Polling.intervalSeconds ? "●" : "○\(Int(idle))s"
        } else {
            currentMenuBarTitle = ""
        }
    }
}
