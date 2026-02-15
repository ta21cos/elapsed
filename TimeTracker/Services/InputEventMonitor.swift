import Foundation
import CoreGraphics

protocol InputEventMonitoring {
    var lastInputTime: Date { get }
    func start()
    func stop()
}

@Observable
final class InputEventMonitor: InputEventMonitoring {
    private(set) var lastInputTime: Date = Date()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let lock = NSLock()

    func start() {
        let eventMask: CGEventMask = (
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue)
        )

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, _, _, refcon in
                guard let refcon else { return nil }
                let monitor = Unmanaged<InputEventMonitor>
                    .fromOpaque(refcon)
                    .takeUnretainedValue()
                let now = Date()
                monitor.lock.lock()
                monitor.lastInputTime = now
                monitor.lock.unlock()
                return nil
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap else { return }

        runLoopSource = CFMachPortCreateRunLoopSource(
            kCFAllocatorDefault, eventTap, 0
        )
        CFRunLoopAddSource(
            CFRunLoopGetCurrent(), runLoopSource, .commonModes
        )
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(
                CFRunLoopGetCurrent(), runLoopSource, .commonModes
            )
        }
        eventTap = nil
        runLoopSource = nil
    }
}
