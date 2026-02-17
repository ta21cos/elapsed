import Foundation
@testable import TimeTracker

final class MockSystemStateMonitor: SystemStateMonitoring {
    var onSystemEvent: ((SystemStateMonitor.SystemEvent) -> Void)?
    private(set) var isRunning = false

    func start() {
        isRunning = true
    }

    func stop() {
        isRunning = false
    }

    func simulateEvent(_ event: SystemStateMonitor.SystemEvent) {
        onSystemEvent?(event)
    }
}
