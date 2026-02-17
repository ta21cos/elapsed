import Foundation

@Observable
final class AppSettings {
    private let defaults: UserDefaults

    var workDurationMinutes: Int {
        didSet { defaults.set(workDurationMinutes, forKey: "workDurationMinutes") }
    }
    var breakDurationMinutes: Int {
        didSet { defaults.set(breakDurationMinutes, forKey: "breakDurationMinutes") }
    }
    var inactivityThresholdMinutes: Int {
        didSet { defaults.set(inactivityThresholdMinutes, forKey: "inactivityThresholdMinutes") }
    }
    var breakResetThresholdMinutes: Int {
        didSet { defaults.set(breakResetThresholdMinutes, forKey: "breakResetThresholdMinutes") }
    }
    var snoozeDurationMinutes: Int {
        didSet { defaults.set(snoozeDurationMinutes, forKey: "snoozeDurationMinutes") }
    }
    var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: "launchAtLogin") }
    }
    var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: "soundEnabled") }
    }
    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let d = defaults
        let has = { (key: String) -> Bool in d.object(forKey: key) != nil }

        self.workDurationMinutes = has("workDurationMinutes")
            ? d.integer(forKey: "workDurationMinutes")
            : Constants.Defaults.workDurationMinutes
        self.breakDurationMinutes = has("breakDurationMinutes")
            ? d.integer(forKey: "breakDurationMinutes")
            : Constants.Defaults.breakDurationMinutes
        self.inactivityThresholdMinutes = has("inactivityThresholdMinutes")
            ? d.integer(forKey: "inactivityThresholdMinutes")
            : Constants.Defaults.inactivityThresholdMinutes
        self.breakResetThresholdMinutes = has("breakResetThresholdMinutes")
            ? d.integer(forKey: "breakResetThresholdMinutes")
            : Constants.Defaults.breakResetThresholdMinutes
        self.snoozeDurationMinutes = has("snoozeDurationMinutes")
            ? d.integer(forKey: "snoozeDurationMinutes")
            : Constants.Defaults.snoozeDurationMinutes
        self.launchAtLogin = has("launchAtLogin")
            ? d.bool(forKey: "launchAtLogin")
            : false
        self.soundEnabled = has("soundEnabled")
            ? d.bool(forKey: "soundEnabled")
            : true
        self.hasCompletedOnboarding = has("hasCompletedOnboarding")
            ? d.bool(forKey: "hasCompletedOnboarding")
            : false
    }
}
