import Foundation
@testable import TimeTracker

final class MockInputEventMonitor: InputEventMonitoring {
    var idleSeconds: TimeInterval = 0
}
