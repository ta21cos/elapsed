import SwiftUI

struct MenuBarLabel: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(alignment: .center, spacing: title.isEmpty ? 0 : 8) {
            Image(systemName: icon)
                .imageScale(.medium)
                .offset(y: -0.5)
            Text(title)
        }
    }
}

enum MenuBarIconProvider {
    static func warningThresholdSeconds(workDurationMinutes: Int) -> Int {
        let buffer = min(Constants.Defaults.warningBufferMinutes, workDurationMinutes - 1)
        return max(0, workDurationMinutes - max(buffer, 0)) * 60
    }

    static func icon(
        breakState: BreakReminderService.BreakState,
        activityState: ActivityMonitorService.ActivityState,
        isTracking: Bool,
        sessionSeconds: Int,
        workDurationMinutes: Int
    ) -> String {
        guard isTracking else { return Constants.Icon.stopped }

        switch breakState {
        case .reminderSent:
            return Constants.Icon.activeWarning
        case .working:
            switch activityState {
            case .inactive:
                return Constants.Icon.inactive
            case .active:
                let threshold = warningThresholdSeconds(
                    workDurationMinutes: workDurationMinutes
                )
                if sessionSeconds >= threshold {
                    return Constants.Icon.activeWarning
                }
                return Constants.Icon.activeNormal
            }
        }
    }
}
