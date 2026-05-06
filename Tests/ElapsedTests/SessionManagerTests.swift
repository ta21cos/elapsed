import XCTest
import SwiftData
@testable import Elapsed

final class SessionManagerTests: XCTestCase {
    private var clock: TestClock!
    private var settings: AppSettings!
    private var container: ModelContainer!
    private var context: ModelContext!
    private var sut: SessionManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        clock = TestClock()
        settings = TestHelpers.makeSettings()
        container = try TestHelpers.makeModelContainer()
        context = ModelContext(container)
        sut = SessionManager(modelContext: context, settings: settings, clock: clock)
    }

    override func tearDown() {
        sut = nil
        context = nil
        container = nil
        settings = nil
        clock = nil
        super.tearDown()
    }

    func testActiveCreatesSessionAfterConfirmation() {
        sut.handleActivityChange(.active)
        XCTAssertNil(sut.currentSession, "Session should not start immediately")

        clock.advance(by: 60)
        sut.confirmSession()

        XCTAssertNotNil(sut.currentSession)
        XCTAssertEqual(sut.currentSession?.isActive, true)
    }

    func testSessionStartTimeBackdatedToActivityStart() {
        let activityStartTime = clock.now
        sut.handleActivityChange(.active)

        clock.advance(by: 60)
        sut.confirmSession()

        XCTAssertEqual(sut.currentSession?.startTime, activityStartTime)
        XCTAssertEqual(sut.currentSessionSeconds, 60)
    }

    func testSessionSecondsAdvancesWithClock() {
        sut.handleActivityChange(.active)
        clock.advance(by: 60)
        sut.confirmSession()

        clock.advance(by: 120)
        sut.updateSession()
        XCTAssertEqual(sut.currentSessionSeconds, 180)
    }

    func testInactiveBeforeConfirmationCancelsPending() {
        sut.handleActivityChange(.active)
        clock.advance(by: 30)
        sut.handleActivityChange(.inactive)

        XCTAssertNil(sut.currentSession)
    }

    func testInactiveEndsConfirmedSession() {
        sut.handleActivityChange(.active)
        clock.advance(by: 60)
        sut.confirmSession()
        let session = sut.currentSession

        clock.advance(by: 300)
        sut.updateSession()
        sut.handleActivityChange(.inactive)

        XCTAssertNil(sut.currentSession)
        XCTAssertEqual(sut.currentSessionSeconds, 0)
        XCTAssertNotNil(session?.endTime)
        XCTAssertEqual(session?.isActive, false)
        XCTAssertEqual(session?.activeSeconds, 360)
    }

    func testReactivationCreatesNewSession() {
        sut.handleActivityChange(.active)
        clock.advance(by: 60)
        sut.confirmSession()
        let firstSession = sut.currentSession

        sut.handleActivityChange(.inactive)

        sut.handleActivityChange(.active)
        clock.advance(by: 60)
        sut.confirmSession()
        let secondSession = sut.currentSession

        XCTAssertNotNil(secondSession)
        XCTAssertNotEqual(firstSession?.id, secondSession?.id)
    }

    func testEndSessionSetsEndTime() {
        sut.handleActivityChange(.active)
        clock.advance(by: 60)
        sut.confirmSession()
        let session = sut.currentSession

        clock.advance(by: 60)
        sut.endCurrentSession()

        XCTAssertNotNil(session?.endTime)
        XCTAssertEqual(session?.isActive, false)
        XCTAssertEqual(session?.activeSeconds, 120)
        XCTAssertNil(sut.currentSession)
    }

    func testDailySummaryCreatedAutomatically() {
        XCTAssertNotNil(sut.todaySummary)
        let today = TimeFormatter.dateString(from: clock.now)
        XCTAssertEqual(sut.todaySummary?.date, today)
    }

    func testDailySummaryAccumulatesAcrossSessions() {
        sut.handleActivityChange(.active)
        clock.advance(by: 60)
        sut.confirmSession()
        clock.advance(by: 10)
        sut.updateSession()
        sut.endCurrentSession()

        sut.handleActivityChange(.active)
        clock.advance(by: 60)
        sut.confirmSession()
        clock.advance(by: 20)
        sut.updateSession()
        sut.endCurrentSession()

        let summary = sut.todaySummary
        XCTAssertNotNil(summary)
        XCTAssertGreaterThan(summary?.totalActiveSeconds ?? 0, 0)
    }

    func testToggleTrackingStopsSession() {
        sut.handleActivityChange(.active)
        clock.advance(by: 60)
        sut.confirmSession()
        XCTAssertNotNil(sut.currentSession)

        sut.toggleTracking()
        XCTAssertFalse(sut.isTracking)
        XCTAssertNil(sut.currentSession)
    }

    func testToggleTrackingCancelsPendingSession() {
        sut.handleActivityChange(.active)
        sut.toggleTracking()

        XCTAssertNil(sut.currentSession)
        XCTAssertFalse(sut.isTracking)
    }

    func testStaleSessionCleanedOnInit() throws {
        let staleSession = Session()
        staleSession.isActive = true
        context.insert(staleSession)
        try context.save()

        let _ = SessionManager(modelContext: context, settings: settings, clock: clock)

        XCTAssertFalse(staleSession.isActive)
        XCTAssertNotNil(staleSession.endTime)
    }

    func testSessionCountIncrements() {
        sut.handleActivityChange(.active)
        clock.advance(by: 60)
        sut.confirmSession()
        XCTAssertEqual(sut.todaySummary?.sessionCount, 1)

        sut.endCurrentSession()
        sut.handleActivityChange(.active)
        clock.advance(by: 60)
        sut.confirmSession()
        XCTAssertEqual(sut.todaySummary?.sessionCount, 2)
    }

    func testFirstSessionStartRecorded() {
        sut.handleActivityChange(.active)
        clock.advance(by: 60)
        sut.confirmSession()
        XCTAssertNotNil(sut.todaySummary?.firstSessionStart)
    }

    func testTrackingDisabledIgnoresActivityChange() {
        sut.toggleTracking()
        sut.handleActivityChange(.active)
        XCTAssertNil(sut.currentSession)
    }

    func testEndSessionUsesLastUpdateTimeExcludingSleep() {
        sut.handleActivityChange(.active)
        clock.advance(by: 60)
        sut.confirmSession()
        let session = sut.currentSession

        clock.advance(by: 300)
        sut.updateSession()
        let lastActiveTime = clock.now

        clock.advance(by: 3600)
        sut.endCurrentSession()

        XCTAssertEqual(session?.endTime, lastActiveTime)
        XCTAssertEqual(session?.activeSeconds, 360)
    }

    func testUpdateSessionDoesNotMutatePersistedActiveSeconds() {
        sut.handleActivityChange(.active)
        clock.advance(by: 60)
        sut.confirmSession()
        let session = sut.currentSession

        clock.advance(by: 120)
        sut.updateSession()

        XCTAssertEqual(sut.currentSessionSeconds, 180)
        XCTAssertEqual(session?.activeSeconds, 0, "updateSession should not write to SwiftData; activeSeconds is finalized only at endCurrentSession")
    }

    func testOnSessionTickFiresWithCurrentSeconds() {
        var ticked: [Int] = []
        sut.onSessionTick = { seconds in
            ticked.append(seconds)
        }

        sut.handleActivityChange(.active)
        clock.advance(by: 60)
        sut.confirmSession()

        clock.advance(by: 30)
        sut.updateSession()
        clock.advance(by: 30)
        sut.updateSession()

        XCTAssertEqual(ticked, [90, 120])
    }

    func testOnSessionTickNotFiredWithoutCurrentSession() {
        var tickCount = 0
        sut.onSessionTick = { _ in tickCount += 1 }

        sut.updateSession()

        XCTAssertEqual(tickCount, 0)
    }
}
