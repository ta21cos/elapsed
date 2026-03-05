import SwiftUI
import SwiftData

struct PopoverView: View {
    @Environment(SessionManager.self) private var sessionManager
    @Environment(BreakReminderService.self) private var breakService
    @Environment(AppSettings.self) private var settings
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \Session.startTime, order: .reverse) private var allSessions: [Session]

    private var todaySessions: [Session] {
        let today = Calendar.current.startOfDay(for: Date())
        return allSessions.filter { $0.startTime >= today }
    }

    private static let timeFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            statusHeader

            Divider()

            WorkProgressView(
                elapsed: TimeInterval(sessionManager.currentSessionSeconds),
                total: TimeInterval(settings.workDurationMinutes * 60)
            )

            Divider()

            if let summary = sessionManager.todaySummary {
                StatsView(summary: summary)
                Divider()
            }

            todaySessionList

            Divider()

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
            .simultaneousGesture(TapGesture().onEnded {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NSApp.activate()
                }
            })
            .accessibilityLabel("設定画面を開く")

            Button("終了") {
                NSApp.terminate(nil)
            }
            .accessibilityLabel("アプリを終了")
        }
    }

    // MARK: - Today Sessions

    @ViewBuilder
    private var todaySessionList: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("今日のセッション")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("履歴") {
                    openWindow(id: "session-detail")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NSApp.activate()
                    }
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            }

            if todaySessions.isEmpty {
                Text("セッションなし")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(todaySessions) { session in
                    sessionRow(session)
                }
            }
        }
    }

    private func sessionRow(_ session: Session) -> some View {
        HStack(spacing: 4) {
            Image(systemName: session.isActive ? "circle.fill" : "circle.fill")
                .font(.system(size: 6))
                .foregroundStyle(session.isActive ? .red : .green)

            Text(Self.timeFormat.string(from: session.startTime))
                .monospacedDigit()

            Text("→")

            if let end = session.endTime {
                Text(Self.timeFormat.string(from: end))
                    .monospacedDigit()
            } else {
                Text("進行中")
                    .foregroundStyle(.red)
            }

            Text("(\(session.activeSeconds / 60)分)")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }

    // MARK: - Computed Properties

    private var statusIcon: String {
        if !sessionManager.isTracking { return Constants.Icon.stopped }
        if breakService.breakState == .reminderSent { return Constants.Icon.activeWarning }
        if sessionManager.currentSession != nil { return Constants.Icon.activeNormal }
        return Constants.Icon.inactive
    }

    private var statusColor: Color {
        if !sessionManager.isTracking { return .gray }
        if breakService.breakState == .reminderSent { return .orange }
        if sessionManager.currentSession != nil { return .blue }
        return .secondary
    }

    private var statusTitle: String {
        if !sessionManager.isTracking { return "停止中" }
        if breakService.breakState == .reminderSent { return "休憩してください" }
        if sessionManager.currentSession != nil { return "作業中" }
        return "待機中"
    }

    private var statusSubtitle: String {
        if !sessionManager.isTracking { return "監視は停止しています" }
        if breakService.breakState == .reminderSent { return "長時間作業しています" }
        if sessionManager.currentSession != nil {
            let remaining = breakService.timeUntilBreak
            if remaining > 0 {
                return "休憩まで \(TimeFormatter.formatDuration(Int(remaining)))"
            }
            return "休憩時間です"
        }
        return "入力を待っています"
    }
}
