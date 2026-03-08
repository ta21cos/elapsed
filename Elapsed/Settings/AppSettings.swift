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
    var snoozeDurationMinutes: Int {
        didSet { defaults.set(snoozeDurationMinutes, forKey: "snoozeDurationMinutes") }
    }
    var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: "launchAtLogin") }
    }
    var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: "soundEnabled") }
    }
    var sessionConfirmationSeconds: Int {
        didSet { defaults.set(sessionConfirmationSeconds, forKey: "sessionConfirmationSeconds") }
    }
    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }
    var debugMode: Bool {
        didSet { defaults.set(debugMode, forKey: "debugMode") }
    }
    var showSeconds: Bool {
        didSet { defaults.set(showSeconds, forKey: "showSeconds") }
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
        self.snoozeDurationMinutes = has("snoozeDurationMinutes")
            ? d.integer(forKey: "snoozeDurationMinutes")
            : Constants.Defaults.snoozeDurationMinutes
        self.launchAtLogin = has("launchAtLogin")
            ? d.bool(forKey: "launchAtLogin")
            : false
        self.soundEnabled = has("soundEnabled")
            ? d.bool(forKey: "soundEnabled")
            : true
        self.sessionConfirmationSeconds = has("sessionConfirmationSeconds")
            ? d.integer(forKey: "sessionConfirmationSeconds")
            : Constants.Defaults.sessionConfirmationSeconds
        self.hasCompletedOnboarding = has("hasCompletedOnboarding")
            ? d.bool(forKey: "hasCompletedOnboarding")
            : false
        self.debugMode = has("debugMode")
            ? d.bool(forKey: "debugMode")
            : false
        self.showSeconds = has("showSeconds")
            ? d.bool(forKey: "showSeconds")
            : false
    }
}
