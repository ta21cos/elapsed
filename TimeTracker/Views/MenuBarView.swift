import SwiftUI

enum MenuBarIconProvider {
    static func warningThresholdSeconds(workDurationMinutes: Int) -> Int {
        max(Constants.Defaults.minimumWarningMinutes,
            workDurationMinutes - Constants.Defaults.warningBufferMinutes) * 60
    }

    static func icon(
        breakState: BreakReminderService.BreakState,
        activityState: ActivityMonitorService.ActivityState,
        isTracking: Bool,
        streakSeconds: Int,
        workDurationMinutes: Int
    ) -> String {
        guard isTracking else { return Constants.Icon.stopped }

        switch breakState {
        case .onBreak:
            return Constants.Icon.onBreak
        case .reminderSent, .working:
            switch activityState {
            case .inactive:
                return Constants.Icon.inactive
            case .active:
                let threshold = warningThresholdSeconds(
                    workDurationMinutes: workDurationMinutes
                )
                if streakSeconds >= threshold {
                    return Constants.Icon.activeWarning
                }
                return Constants.Icon.activeNormal
            }
        }
    }
}
