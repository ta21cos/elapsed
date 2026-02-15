import SwiftUI

struct PopoverView: View {
    @Environment(SessionManager.self) private var sessionManager
    @Environment(BreakReminderService.self) private var breakService
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            statusHeader

            Divider()

            progressSection

            Divider()

            if let summary = sessionManager.todaySummary {
                StatsView(summary: summary)
                Divider()
            }

            controlButtons
        }
        .padding()
        .frame(width: 300)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var statusHeader: some View {
        HStack {
            Image(systemName: statusIcon)
                .font(.title2)
                .foregroundStyle(statusColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.headline)
                Text(statusSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(statusTitle)、\(statusSubtitle)")
    }

    @ViewBuilder
    private var progressSection: some View {
        if breakService.breakState == .onBreak {
            BreakCountdownView(
                remaining: breakService.breakTimeRemaining,
                total: TimeInterval(settings.breakDurationMinutes * 60)
            )
        } else {
            WorkProgressView(
                elapsed: TimeInterval(sessionManager.currentStreakSeconds),
                total: TimeInterval(settings.workDurationMinutes * 60)
            )
        }
    }

    private var controlButtons: some View {
        HStack {
            Button(sessionManager.isTracking ? "一時停止" : "再開") {
                sessionManager.toggleTracking()
            }
            .accessibilityLabel(sessionManager.isTracking ? "監視を一時停止" : "監視を再開")

            Spacer()

            SettingsLink {
                Text("設定")
            }
            .accessibilityLabel("設定画面を開く")

            Button("終了") {
                NSApp.terminate(nil)
            }
            .accessibilityLabel("アプリを終了")
        }
    }

    // MARK: - Computed Properties

    private var statusIcon: String {
        switch breakService.breakState {
        case .onBreak:
            return Constants.Icon.onBreak
        case .reminderSent:
            return Constants.Icon.activeWarning
        case .working:
            if !sessionManager.isTracking {
                return Constants.Icon.stopped
            }
            return Constants.Icon.activeNormal
        }
    }

    private var statusColor: Color {
        switch breakService.breakState {
        case .onBreak: return .green
        case .reminderSent: return .orange
        case .working:
            if !sessionManager.isTracking { return .gray }
            return .blue
        }
    }

    private var statusTitle: String {
        if !sessionManager.isTracking { return "停止中" }
        switch breakService.breakState {
        case .onBreak: return "休憩中"
        case .reminderSent: return "休憩してください"
        case .working: return "作業中"
        }
    }

    private var statusSubtitle: String {
        if !sessionManager.isTracking { return "監視は停止しています" }
        switch breakService.breakState {
        case .onBreak:
            return "残り \(TimeFormatter.formatCountdown(Int(breakService.breakTimeRemaining)))"
        case .reminderSent:
            return "長時間作業しています"
        case .working:
            let remaining = breakService.timeUntilBreak
            if remaining > 0 {
                return "休憩まで \(TimeFormatter.formatDuration(Int(remaining)))"
            }
            return "休憩時間です"
        }
    }

}
