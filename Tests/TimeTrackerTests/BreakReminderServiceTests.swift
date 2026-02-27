import XCTest
import SwiftData
@testable import TimeTracker

final class BreakReminderServiceTests: XCTestCase {
    private var clock: TestClock!
    private var settings: AppSettings!
    private var container: ModelContainer!
    private var sessionManager: SessionManager!
    private var notificationService: MockNotificationService!
    private var sut: BreakReminderService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        clock = TestClock()
        settings = TestHelpers.makeSettings(workDuration: 50, breakDuration: 10)
        container = try TestHelpers.makeModelContainer()
        let context = ModelContext(container)
        sessionManager = SessionManager(modelContext: context, settings: settings, clock: clock)
        notificationService = MockNotificationService()
        sut = BreakReminderService(
            sessionManager: sessionManager,
            notificationService: notificationService,
            settings: settings
        )
    }

    override func tearDown() {
        sut = nil
        notificationService = nil
        sessionManager = nil
        container = nil
        settings = nil
        clock = nil
        super.tearDown()
    }

    func testNotifiesAt50Minutes() {
        sessionManager.handleActivityChange(.active)
        clock.advance(by: 50 * 60)
        sessionManager.updateSession()

        sut.checkAndNotify()

        XCTAssertEqual(notificationService.breakReminderCount, 1)
        XCTAssertEqual(notificationService.lastBreakReminderMinutes, 50)
    }

    func testDoesNotNotifyAt49Minutes() {
        sessionManager.handleActivityChange(.active)
        clock.advance(by: 49 * 60)
        sessionManager.updateSession()

        sut.checkAndNotify()

        XCTAssertEqual(notificationService.breakReminderCount, 0)
    }

    func testStateTransitionWorkingToReminderSent() {
        XCTAssertEqual(sut.breakState, .working)

        sessionManager.handleActivityChange(.active)
        clock.advance(by: 50 * 60)
        sessionManager.updateSession()
        sut.checkAndNotify()

        XCTAssertEqual(sut.breakState, .reminderSent)
    }

    func testSnoozeResetsToWorking() {
        sessionManager.handleActivityChange(.active)
        clock.advance(by: 50 * 60)
        sessionManager.updateSession()
        sut.checkAndNotify()
        XCTAssertEqual(sut.breakState, .reminderSent)

        sut.snooze()
        XCTAssertEqual(sut.breakState, .working)
    }

    func testNoNotificationWhenAlreadySent() {
        sessionManager.handleActivityChange(.active)
        clock.advance(by: 50 * 60)
        sessionManager.updateSession()

        sut.checkAndNotify()
        sut.checkAndNotify()

        XCTAssertEqual(notificationService.breakReminderCount, 1)
    }

    func testTimeUntilBreakCalculation() {
        sessionManager.handleActivityChange(.active)
        clock.advance(by: 30 * 60)
        sessionManager.updateSession()

        let remaining = sut.timeUntilBreak
        XCTAssertEqual(remaining, 20 * 60)
    }

    func testResetClearsState() {
        sessionManager.handleActivityChange(.active)
        clock.advance(by: 50 * 60)
        sessionManager.updateSession()
        sut.checkAndNotify()
        XCTAssertEqual(sut.breakState, .reminderSent)

        sut.reset()
        XCTAssertEqual(sut.breakState, .working)
    }

    func testNotificationCallbackWiring() {
        notificationService.onTakeBreak?()
        XCTAssertEqual(sut.breakState, .working)

        notificationService.onSnooze?()
        XCTAssertEqual(sut.breakState, .working)
    }
}
