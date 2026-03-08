import Foundation
@testable import Elapsed

final class MockInputEventMonitor: InputEventMonitoring {
    var idleSeconds: TimeInterval = 0
}
