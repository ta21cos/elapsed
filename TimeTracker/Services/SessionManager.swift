import Foundation
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.ta21cos.TimeTracker", category: "SessionManager")

@Observable
final class SessionManager {
    private let modelContext: ModelContext
    private let settings: AppSettings
    let clock: Clock

    private(set) var currentSession: Session?
    private(set) var currentSessionSeconds: Int = 0
    private(set) var todaySummary: DailySummary?
    private(set) var isTracking: Bool = true

    private var updateTimer: Timer?

    init(modelContext: ModelContext, settings: AppSettings, clock: Clock = SystemClock()) {
        self.modelContext = modelContext
        self.settings = settings
        self.clock = clock
        self.todaySummary = fetchOrCreateTodaySummary()
        cleanupStaleSessions()
    }

    func handleActivityChange(_ state: ActivityMonitorService.ActivityState) {
        guard isTracking else { return }

        switch state {
        case .active:
            handleBecameActive()
        case .inactive:
            handleBecameInactive()
        }
    }

    func toggleTracking() {
        isTracking.toggle()
        if !isTracking {
            endCurrentSession()
        }
    }

    func endCurrentSession() {
        updateTimer?.invalidate()
        updateTimer = nil

        guard let session = currentSession else { return }

        session.endTime = clock.now
        session.activeSeconds = Int(clock.now.timeIntervalSince(session.startTime))
        session.isActive = false
        updateDailySummary(with: session)
        save()

        currentSession = nil
        currentSessionSeconds = 0
    }

    // MARK: - Internal (testable)

    func updateSession() {
        guard let session = currentSession else { return }
        currentSessionSeconds = Int(clock.now.timeIntervalSince(session.startTime))
        session.activeSeconds = currentSessionSeconds
    }

    // MARK: - Private

    private func handleBecameActive() {
        checkDateChange()

        if currentSession == nil {
            startNewSession()
        }
        startSessionTimer()
    }

    private func handleBecameInactive() {
        endCurrentSession()
    }

    private func startNewSession() {
        let session = Session()
        session.startTime = clock.now
        modelContext.insert(session)
        currentSession = session
        currentSessionSeconds = 0

        todaySummary?.sessionCount += 1
        if todaySummary?.firstSessionStart == nil {
            todaySummary?.firstSessionStart = session.startTime
        }

        save()
    }

    private func startSessionTimer() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.Polling.streakUpdateIntervalSeconds,
            repeats: true
        ) { [weak self] _ in
            self?.updateSession()
        }
        updateTimer?.tolerance = 0.5
    }

    private func fetchOrCreateTodaySummary() -> DailySummary {
        let today = TimeFormatter.dateString(from: clock.now)
        let descriptor = FetchDescriptor<DailySummary>(
            predicate: #Predicate { $0.date == today }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        let summary = DailySummary(date: today)
        modelContext.insert(summary)
        save()
        return summary
    }

    private func updateDailySummary(with session: Session) {
        guard let summary = todaySummary else { return }
        summary.totalActiveSeconds += session.activeSeconds
        summary.lastSessionEnd = session.endTime
    }

    private func checkDateChange() {
        let today = TimeFormatter.dateString(from: clock.now)
        if todaySummary?.date != today {
            endCurrentSession()
            todaySummary = fetchOrCreateTodaySummary()
        }
    }

    private func cleanupStaleSessions() {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.isActive == true }
        )
        guard let staleSessions = try? modelContext.fetch(descriptor) else { return }
        for session in staleSessions {
            session.isActive = false
            let endTime = session.endTime ?? clock.now
            session.endTime = endTime
            session.activeSeconds = Int(endTime.timeIntervalSince(session.startTime))
        }
        save()
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save model context: \(error.localizedDescription)")
        }
    }
}
