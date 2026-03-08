import Foundation
import SwiftData
@testable import Elapsed

enum TestHelpers {
    static func makeModelContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Session.self, DailySummary.self, configurations: config)
    }

    static func makeSettings(
        workDuration: Int = Constants.Defaults.workDurationMinutes,
        breakDuration: Int = Constants.Defaults.breakDurationMinutes,
        inactivityThreshold: Int = Constants.Defaults.inactivityThresholdMinutes,
        snoozeDuration: Int = Constants.Defaults.snoozeDurationMinutes,
        sessionConfirmationSeconds: Int = Constants.Defaults.sessionConfirmationSeconds
    ) -> AppSettings {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let settings = AppSettings(defaults: defaults)
        settings.workDurationMinutes = workDuration
        settings.breakDurationMinutes = breakDuration
        settings.inactivityThresholdMinutes = inactivityThreshold
        settings.snoozeDurationMinutes = snoozeDuration
        settings.sessionConfirmationSeconds = sessionConfirmationSeconds
        return settings
    }
}
