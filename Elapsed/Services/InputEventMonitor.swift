import Foundation
import CoreGraphics

protocol InputEventMonitoring {
    var idleSeconds: TimeInterval { get }
}

final class InputEventMonitor: InputEventMonitoring {
    private static let monitoredEventTypes: [CGEventType] = [
        .keyDown, .mouseMoved, .leftMouseDown, .rightMouseDown, .scrollWheel,
    ]

    var idleSeconds: TimeInterval {
        Self.monitoredEventTypes
            .map { CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: $0) }
            .min() ?? .greatestFiniteMagnitude
    }
}
