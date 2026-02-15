import Foundation
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.ta21cos.TimeTracker", category: "SessionManager")

@Observable
final class SessionManager {
    private let modelContext: ModelContext
    private let settings: AppSettings

    private(set) var currentSession: Session?
    private(set) var currentStreakSeconds: Int = 0
    private(set) var todaySummary: DailySummary?
    private(set) var isTracking: Bool = true

    private var streakStartTime: Date?
    private var inactiveStartTime: Date?
    private var updateTimer: Timer?

    init(modelContext: ModelContext, settings: AppSettings) {
        self.modelContext = modelContext
        self.settings = settings
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

        if currentStreakSeconds > session.longestStreakSeconds {
            session.longestStreakSeconds = currentStreakSeconds
        }

        session.endTime = Date()
        session.isActive = false
        updateDailySummary(with: session)
        save()

        currentSession = nil
        currentStreakSeconds = 0
        streakStartTime = nil
        inactiveStartTime = nil
    }

    // MARK: - Private

    private func handleBecameActive() {
        checkDateChange()

        if currentSession == nil {
            startNewSession()
        }

        if let inactiveStart = inactiveStartTime {
            let inactiveDuration = Date().timeIntervalSince(inactiveStart)
            let resetThreshold = TimeInterval(settings.breakResetThresholdMinutes * 60)

            if let session = currentSession {
                session.inactiveSeconds += Int(inactiveDuration)
            }

            if inactiveDuration >= resetThreshold {
                currentSession?.breaksTaken += 1
                if currentStreakSeconds > (currentSession?.longestStreakSeconds ?? 0) {
                    currentSession?.longestStreakSeconds = currentStreakSeconds
                }
                currentStreakSeconds = 0
                streakStartTime = Date()
            }
            inactiveStartTime = nil
        }

        if streakStartTime == nil {
            streakStartTime = Date()
        }
        startStreakTimer()
    }

    private func handleBecameInactive() {
        inactiveStartTime = Date()
        updateTimer?.invalidate()
        updateTimer = nil

        if let session = currentSession,
           currentStreakSeconds > session.longestStreakSeconds {
            session.longestStreakSeconds = currentStreakSeconds
        }
    }

    private func startNewSession() {
        let session = Session()
        modelContext.insert(session)
        currentSession = session
        streakStartTime = Date()
        currentStreakSeconds = 0

        todaySummary?.sessionCount += 1
        if todaySummary?.firstSessionStart == nil {
            todaySummary?.firstSessionStart = session.startTime
        }

        save()
    }

    private func startStreakTimer() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.Polling.streakUpdateIntervalSeconds,
            repeats: true
        ) { [weak self] _ in
            guard let self, let start = self.streakStartTime else { return }
            self.currentStreakSeconds = Int(Date().timeIntervalSince(start))
            self.currentSession?.activeSeconds += 1
        }
        updateTimer?.tolerance = 0.5
    }

    private func fetchOrCreateTodaySummary() -> DailySummary {
        let today = TimeFormatter.dateString(from: Date())
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
        summary.totalInactiveSeconds += session.inactiveSeconds
        summary.totalBreaks += session.breaksTaken
        if session.longestStreakSeconds > summary.longestStreakSeconds {
            summary.longestStreakSeconds = session.longestStreakSeconds
        }
        summary.lastSessionEnd = session.endTime
    }

    private func checkDateChange() {
        let today = TimeFormatter.dateString(from: Date())
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
            session.endTime = session.endTime ?? Date()
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
