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

    func testStreakAdvancesWithClock() {
        sut.handleActivityChange(.active)
        clock.advance(by: 120)
        sut.updateStreak()
        XCTAssertEqual(sut.currentStreakSeconds, 120)
    }

    func testShortInactivityPreservesStreak() {
        sut.handleActivityChange(.active)
        clock.advance(by: 100)
        sut.updateStreak()
        let streakBefore = sut.currentStreakSeconds

        sut.handleActivityChange(.inactive)
        clock.advance(by: 60)
        sut.handleActivityChange(.active)

        XCTAssertGreaterThanOrEqual(sut.currentStreakSeconds, streakBefore)
    }

    func testLongInactivityResetsStreakAndCountsBreak() {
        sut.handleActivityChange(.active)
        clock.advance(by: 300)
        sut.updateStreak()

        sut.handleActivityChange(.inactive)
        clock.advance(by: TimeInterval(settings.breakResetThresholdMinutes * 60))
        sut.handleActivityChange(.active)

        XCTAssertEqual(sut.currentStreakSeconds, 0)
        XCTAssertEqual(sut.currentSession?.breaksTaken, 1)
    }

    func testLongestStreakRecorded() {
        sut.handleActivityChange(.active)
        clock.advance(by: 500)
        sut.updateStreak()

        sut.handleActivityChange(.inactive)

        XCTAssertEqual(sut.currentSession?.longestStreakSeconds, 500)
    }

    func testEndSessionSetsEndTime() {
        sut.handleActivityChange(.active)
        let session = sut.currentSession
        XCTAssertNotNil(session)

        clock.advance(by: 60)
        sut.endCurrentSession()

        XCTAssertNotNil(session?.endTime)
        XCTAssertEqual(session?.isActive, false)
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
        sut.updateStreak()
        sut.endCurrentSession()

        sut.handleActivityChange(.active)
        clock.advance(by: 20)
        sut.updateStreak()
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

    func testInactiveSecondsTracked() {
        sut.handleActivityChange(.active)

        sut.handleActivityChange(.inactive)
        clock.advance(by: 120)
        sut.handleActivityChange(.active)

        XCTAssertEqual(sut.currentSession?.inactiveSeconds, 120)
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
