import Foundation

@Observable
final class ActivityMonitorService {
    enum ActivityState {
        case active
        case inactive
    }

    private static let requiredInactivePolls = 2

    private let inputMonitor: InputEventMonitoring
    private let systemMonitor: any SystemStateMonitoring
    private let settings: AppSettings
    private let clock: Clock
    private var pollingTimer: Timer?
    private var consecutiveInactivePolls = 0

    private(set) var state: ActivityState = .inactive
    private(set) var idleSeconds: TimeInterval = 0
    var onStateChange: ((ActivityState) -> Void)?

    init(
        settings: AppSettings,
        inputMonitor: InputEventMonitoring? = nil,
        systemMonitor: (any SystemStateMonitoring)? = nil,
        clock: Clock = SystemClock()
    ) {
        self.settings = settings
        self.inputMonitor = inputMonitor ?? InputEventMonitor()
        self.systemMonitor = systemMonitor ?? SystemStateMonitor()
        self.clock = clock
        setupSystemMonitorCallbacks()
    }

    func start() {
        systemMonitor.start()
        startPolling()
    }

    func stop() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        systemMonitor.stop()
        consecutiveInactivePolls = 0
        state = .inactive
    }

    private func startPolling() {
        evaluateActivity()
        pollingTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.Polling.intervalSeconds,
            repeats: true
        ) { [weak self] _ in
            self?.evaluateActivity()
        }
        pollingTimer?.tolerance = 2.0
    }

    func evaluateActivity() {
        idleSeconds = inputMonitor.idleSeconds
        let threshold = TimeInterval(settings.inactivityThresholdMinutes * 60)

        if idleSeconds > threshold {
            consecutiveInactivePolls += 1
            if consecutiveInactivePolls >= Self.requiredInactivePolls && state != .inactive {
                state = .inactive
                onStateChange?(.inactive)
            }
        } else {
            consecutiveInactivePolls = 0
            if state != .active {
                state = .active
                onStateChange?(.active)
            }
        }
    }

    private func setupSystemMonitorCallbacks() {
        systemMonitor.onSystemEvent = { [weak self] event in
            switch event {
            case .screenLocked, .systemSleep:
                guard let self, self.state != .inactive else { return }
                self.state = .inactive
                self.onStateChange?(.inactive)
            case .screenUnlocked, .systemWake:
                break
            }
        }
    }
}
