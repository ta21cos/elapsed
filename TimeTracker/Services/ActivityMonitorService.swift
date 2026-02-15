import Foundation

@Observable
final class ActivityMonitorService {
    enum ActivityState {
        case active
        case inactive
    }

    private let inputMonitor: InputEventMonitoring
    private let systemMonitor: SystemStateMonitor
    private let settings: AppSettings
    private var pollingTimer: Timer?

    private(set) var state: ActivityState = .inactive
    private(set) var lastInputTime: Date = Date()
    var onStateChange: ((ActivityState) -> Void)?

    init(
        settings: AppSettings,
        inputMonitor: InputEventMonitoring? = nil,
        systemMonitor: SystemStateMonitor? = nil
    ) {
        self.settings = settings
        self.inputMonitor = inputMonitor ?? InputEventMonitor()
        self.systemMonitor = systemMonitor ?? SystemStateMonitor()
        setupSystemMonitorCallbacks()
    }

    func start() {
        inputMonitor.start()
        systemMonitor.start()
        startPolling()
    }

    func stop() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        inputMonitor.stop()
        systemMonitor.stop()
        state = .inactive
    }

    private func startPolling() {
        pollingTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.Polling.intervalSeconds,
            repeats: true
        ) { [weak self] _ in
            self?.evaluateActivity()
        }
        pollingTimer?.tolerance = 2.0
    }

    private func evaluateActivity() {
        lastInputTime = inputMonitor.lastInputTime
        let elapsed = Date().timeIntervalSince(lastInputTime)
        let threshold = TimeInterval(settings.inactivityThresholdMinutes * 60)

        let newState: ActivityState = elapsed > threshold ? .inactive : .active

        if newState != state {
            state = newState
            onStateChange?(newState)
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
