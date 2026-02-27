import SwiftUI
import SwiftData

@main
struct TimeTrackerApp: App {
    @State private var appCoordinator: AppCoordinator
    @Environment(\.openWindow) private var openWindow

    init() {
        let coordinator = AppCoordinator()
        _appCoordinator = State(initialValue: coordinator)
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environment(appCoordinator.sessionManager)
                .environment(appCoordinator.breakReminder)
                .environment(appCoordinator.settings)
                .modelContainer(appCoordinator.modelContainer)
                .onAppear {
                    if !appCoordinator.settings.hasCompletedOnboarding {
                        openWindow(id: "onboarding")
                    }
                }
        } label: {
            Label {
                if !appCoordinator.currentMenuBarTitle.isEmpty {
                    Text(appCoordinator.currentMenuBarTitle)
                }
            } icon: {
                Image(systemName: appCoordinator.currentMenuBarIcon)
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(appCoordinator.settings)
                .environment(appCoordinator.sessionManager)
                .environment(appCoordinator.breakReminder)
                .environment(appCoordinator.activityMonitor)
                .modelContainer(appCoordinator.modelContainer)
        }

        Window("セットアップ", id: "onboarding") {
            OnboardingView(
                permissionManager: appCoordinator.permissionManager,
                notificationService: appCoordinator.notificationService,
                onComplete: {
                    appCoordinator.startMonitoring()
                }
            )
            .environment(appCoordinator.settings)
            .environment(appCoordinator.sessionManager)
            .environment(appCoordinator.breakReminder)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
