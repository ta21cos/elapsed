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
        inputMonitor.lastInputTime = clock.now
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
        inputMonitor.lastInputTime = clock.now
        sut.evaluateActivity()
        XCTAssertEqual(sut.state, .active)
    }

    func testStaleInputMakesInactive() {
        inputMonitor.lastInputTime = clock.now
        clock.advance(by: 6 * 60)
        sut.evaluateActivity()
        XCTAssertEqual(sut.state, .inactive)
    }

    func testStateChangeCallbackFires() {
        var receivedStates: [ActivityMonitorService.ActivityState] = []
        sut.onStateChange = { receivedStates.append($0) }

        inputMonitor.lastInputTime = clock.now
        sut.evaluateActivity()

        XCTAssertEqual(receivedStates, [.active])
    }

    func testNoCallbackOnSameState() {
        inputMonitor.lastInputTime = clock.now
        sut.evaluateActivity()

        var callbackCount = 0
        sut.onStateChange = { _ in callbackCount += 1 }

        inputMonitor.lastInputTime = clock.now
        clock.advance(by: 1)
        sut.evaluateActivity()

        XCTAssertEqual(callbackCount, 0)
    }

    func testScreenLockForcesInactive() {
        inputMonitor.lastInputTime = clock.now
        sut.evaluateActivity()
        XCTAssertEqual(sut.state, .active)

        systemMonitor.simulateEvent(.screenLocked)
        XCTAssertEqual(sut.state, .inactive)
    }

    func testCustomThresholdRespected() {
        settings.inactivityThresholdMinutes = 1
        inputMonitor.lastInputTime = clock.now
        clock.advance(by: 61)
        sut.evaluateActivity()
        XCTAssertEqual(sut.state, .inactive)
    }

    func testStartAndStopLifecycle() {
        sut.start()
        XCTAssertTrue(inputMonitor.isRunning)
        XCTAssertTrue(systemMonitor.isRunning)

        sut.stop()
        XCTAssertFalse(inputMonitor.isRunning)
        XCTAssertFalse(systemMonitor.isRunning)
        XCTAssertEqual(sut.state, .inactive)
    }

    func testScreenUnlockDoesNotForceActive() {
        XCTAssertEqual(sut.state, .inactive)
        systemMonitor.simulateEvent(.screenUnlocked)
        XCTAssertEqual(sut.state, .inactive)
    }
}
