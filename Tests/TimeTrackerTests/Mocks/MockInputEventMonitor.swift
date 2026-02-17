import Foundation
@testable import TimeTracker

final class MockInputEventMonitor: InputEventMonitoring {
    var lastInputTime: Date = Date()
    private(set) var isRunning = false

    func start() {
        isRunning = true
    }

    func stop() {
        isRunning = false
    }
}
