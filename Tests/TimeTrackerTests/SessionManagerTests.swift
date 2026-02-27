import XCTest
import SwiftData
@testable import TimeTracker

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

    func testActiveCreatesSession() {
        sut.handleActivityChange(.active)
        XCTAssertNotNil(sut.currentSession)
        XCTAssertEqual(sut.currentSession?.isActive, true)
    }

    func testSessionSecondsAdvancesWithClock() {
        sut.handleActivityChange(.active)
        clock.advance(by: 120)
        sut.updateSession()
        XCTAssertEqual(sut.currentSessionSeconds, 120)
    }

    func testInactiveEndsSession() {
        sut.handleActivityChange(.active)
        let session = sut.currentSession
        clock.advance(by: 300)
        sut.updateSession()

        sut.handleActivityChange(.inactive)

        XCTAssertNil(sut.currentSession)
        XCTAssertEqual(sut.currentSessionSeconds, 0)
        XCTAssertNotNil(session?.endTime)
        XCTAssertEqual(session?.isActive, false)
        XCTAssertEqual(session?.activeSeconds, 300)
    }

    func testReactivationCreatesNewSession() {
        sut.handleActivityChange(.active)
        let firstSession = sut.currentSession

        sut.handleActivityChange(.inactive)
        sut.handleActivityChange(.active)
        let secondSession = sut.currentSession

        XCTAssertNotNil(secondSession)
        XCTAssertNotEqual(firstSession?.id, secondSession?.id)
    }

    func testEndSessionSetsEndTime() {
        sut.handleActivityChange(.active)
        let session = sut.currentSession

        clock.advance(by: 60)
        sut.endCurrentSession()

        XCTAssertNotNil(session?.endTime)
        XCTAssertEqual(session?.isActive, false)
        XCTAssertEqual(session?.activeSeconds, 60)
        XCTAssertNil(sut.currentSession)
    }

    func testDailySummaryCreatedAutomatically() {
        XCTAssertNotNil(sut.todaySummary)
        let today = TimeFormatter.dateString(from: clock.now)
        XCTAssertEqual(sut.todaySummary?.date, today)
    }

    func testDailySummaryAccumulatesAcrossSessions() {
        sut.handleActivityChange(.active)
        clock.advance(by: 10)
        sut.updateSession()
        sut.endCurrentSession()

        sut.handleActivityChange(.active)
        clock.advance(by: 20)
        sut.updateSession()
        sut.endCurrentSession()

        let summary = sut.todaySummary
        XCTAssertNotNil(summary)
        XCTAssertGreaterThan(summary?.totalActiveSeconds ?? 0, 0)
    }

    func testToggleTrackingStopsSession() {
        sut.handleActivityChange(.active)
        XCTAssertNotNil(sut.currentSession)

        sut.toggleTracking()
        XCTAssertFalse(sut.isTracking)
        XCTAssertNil(sut.currentSession)
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
        XCTAssertEqual(sut.todaySummary?.sessionCount, 1)

        sut.endCurrentSession()
        sut.handleActivityChange(.active)
        XCTAssertEqual(sut.todaySummary?.sessionCount, 2)
    }

    func testFirstSessionStartRecorded() {
        sut.handleActivityChange(.active)
        XCTAssertNotNil(sut.todaySummary?.firstSessionStart)
    }

    func testTrackingDisabledIgnoresActivityChange() {
        sut.toggleTracking()
        sut.handleActivityChange(.active)
        XCTAssertNil(sut.currentSession)
    }
}
