import SwiftUI
import SwiftData

@main
struct TimeTrackerApp: App {
    @State private var appCoordinator: AppCoordinator

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
                    appCoordinator.onAppear()
                }
        } label: {
            Image(systemName: appCoordinator.currentMenuBarIcon)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(appCoordinator.settings)
                .environment(appCoordinator.sessionManager)
                .environment(appCoordinator.breakReminder)
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
