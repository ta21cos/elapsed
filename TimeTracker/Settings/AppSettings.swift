import Foundation
import SwiftUI

@Observable
final class AppSettings {
    @ObservationIgnored
    @AppStorage("workDurationMinutes") var workDurationMinutes: Int = Constants.Defaults.workDurationMinutes

    @ObservationIgnored
    @AppStorage("breakDurationMinutes") var breakDurationMinutes: Int = Constants.Defaults.breakDurationMinutes

    @ObservationIgnored
    @AppStorage("inactivityThresholdMinutes") var inactivityThresholdMinutes: Int = Constants.Defaults.inactivityThresholdMinutes

    @ObservationIgnored
    @AppStorage("breakResetThresholdMinutes") var breakResetThresholdMinutes: Int = Constants.Defaults.breakResetThresholdMinutes

    @ObservationIgnored
    @AppStorage("snoozeDurationMinutes") var snoozeDurationMinutes: Int = Constants.Defaults.snoozeDurationMinutes

    @ObservationIgnored
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false

    @ObservationIgnored
    @AppStorage("soundEnabled") var soundEnabled: Bool = true

    @ObservationIgnored
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
}
