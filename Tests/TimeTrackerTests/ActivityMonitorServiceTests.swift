import XCTest
@testable import TimeTracker

final class ActivityMonitorServiceTests: XCTestCase {
    private var clock: TestClock!
    private var inputMonitor: MockInputEventMonitor!
    private var systemMonitor: MockSystemStateMonitor!
    private var settings: AppSettings!
    private var sut: ActivityMonitorService!

    override func setUp() {
        super.setUp()
        clock = TestClock()
        inputMonitor = MockInputEventMonitor()
        systemMonitor = MockSystemStateMonitor()
        settings = TestHelpers.makeSettings(inactivityThreshold: 5)
        inputMonitor.idleSeconds = 0
        sut = ActivityMonitorService(
            settings: settings,
            inputMonitor: inputMonitor,
            systemMonitor: systemMonitor,
            clock: clock
        )
    }

    override func tearDown() {
        sut = nil
        settings = nil
        systemMonitor = nil
        inputMonitor = nil
        clock = nil
        super.tearDown()
    }

    func testRecentInputMakesActive() {
        inputMonitor.idleSeconds = 0
        sut.evaluateActivity()
        XCTAssertEqual(sut.state, .active)
    }

    func testStaleInputMakesInactive() {
        inputMonitor.idleSeconds = 6 * 60
        sut.evaluateActivity()
        sut.evaluateActivity()
        XCTAssertEqual(sut.state, .inactive)
    }

    func testStateChangeCallbackFires() {
        var receivedStates: [ActivityMonitorService.ActivityState] = []
        sut.onStateChange = { receivedStates.append($0) }

        inputMonitor.idleSeconds = 0
        sut.evaluateActivity()

        XCTAssertEqual(receivedStates, [.active])
    }

    func testNoCallbackOnSameState() {
        inputMonitor.idleSeconds = 0
        sut.evaluateActivity()

        var callbackCount = 0
        sut.onStateChange = { _ in callbackCount += 1 }

        inputMonitor.idleSeconds = 1
        sut.evaluateActivity()

        XCTAssertEqual(callbackCount, 0)
    }

    func testScreenLockForcesInactive() {
        inputMonitor.idleSeconds = 0
        sut.evaluateActivity()
        XCTAssertEqual(sut.state, .active)

        systemMonitor.simulateEvent(.screenLocked)
        XCTAssertEqual(sut.state, .inactive)
    }

    func testCustomThresholdRespected() {
        settings.inactivityThresholdMinutes = 1
        inputMonitor.idleSeconds = 61
        sut.evaluateActivity()
        sut.evaluateActivity()
        XCTAssertEqual(sut.state, .inactive)
    }

    func testStartAndStopLifecycle() {
        sut.start()
        XCTAssertTrue(systemMonitor.isRunning)

        sut.stop()
        XCTAssertFalse(systemMonitor.isRunning)
        XCTAssertEqual(sut.state, .inactive)
    }

    func testScreenUnlockDoesNotForceActive() {
        XCTAssertEqual(sut.state, .inactive)
        systemMonitor.simulateEvent(.screenUnlocked)
        XCTAssertEqual(sut.state, .inactive)
    }

    // MARK: - Debounce

    func testDebouncing_requiresConsecutiveInactivePolls() {
        inputMonitor.idleSeconds = 0
        sut.evaluateActivity()
        XCTAssertEqual(sut.state, .active)

        inputMonitor.idleSeconds = 6 * 60

        sut.evaluateActivity()
        XCTAssertEqual(sut.state, .active, "Single inactive poll should not transition to inactive")

        sut.evaluateActivity()
        XCTAssertEqual(sut.state, .inactive, "Second consecutive inactive poll should transition to inactive")
    }

    func testDebouncing_resetByActivity() {
        inputMonitor.idleSeconds = 0
        sut.evaluateActivity()
        XCTAssertEqual(sut.state, .active)

        inputMonitor.idleSeconds = 6 * 60
        sut.evaluateActivity()
        XCTAssertEqual(sut.state, .active, "First inactive poll — still active due to debounce")

        inputMonitor.idleSeconds = 0
        sut.evaluateActivity()
        XCTAssertEqual(sut.state, .active, "Activity resets the counter")

        inputMonitor.idleSeconds = 6 * 60
        sut.evaluateActivity()
        XCTAssertEqual(sut.state, .active, "First inactive poll after reset — still active")

        sut.evaluateActivity()
        XCTAssertEqual(sut.state, .inactive, "Second consecutive inactive poll — now inactive")
    }

    func testSystemSleep_bypassesDebouncing() {
        inputMonitor.idleSeconds = 0
        sut.evaluateActivity()
        XCTAssertEqual(sut.state, .active)

        systemMonitor.simulateEvent(.systemSleep)
        XCTAssertEqual(sut.state, .inactive, "System sleep bypasses debounce and immediately goes inactive")
    }
}
