import AppKit

protocol SystemStateMonitoring: AnyObject {
    var onSystemEvent: ((SystemStateMonitor.SystemEvent) -> Void)? { get set }
    func start()
    func stop()
}

@Observable
final class SystemStateMonitor: SystemStateMonitoring {
    enum SystemEvent {
        case screenLocked
        case screenUnlocked
        case systemSleep
        case systemWake
    }

    private(set) var lastEvent: SystemEvent?
    private(set) var lastEventTime: Date?
    var onSystemEvent: ((SystemEvent) -> Void)?

    func start() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleScreenLock),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleScreenUnlock),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    func stop() {
        DistributedNotificationCenter.default().removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func handleScreenLock() {
        emit(.screenLocked)
    }

    @objc private func handleScreenUnlock() {
        emit(.screenUnlocked)
    }

    @objc private func handleSleep() {
        emit(.systemSleep)
    }

    @objc private func handleWake() {
        emit(.systemWake)
    }

    private func emit(_ event: SystemEvent) {
        lastEvent = event
        lastEventTime = Date()
        onSystemEvent?(event)
    }
}
