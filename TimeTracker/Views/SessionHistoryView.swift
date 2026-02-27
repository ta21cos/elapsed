import SwiftUI
import SwiftData

struct SessionHistoryView: View {
    @Environment(SessionManager.self) private var sessionManager
    @Environment(ActivityMonitorService.self) private var activityMonitor
    @Environment(BreakReminderService.self) private var breakReminder
    @Query(sort: \Session.startTime, order: .reverse) private var sessions: [Session]

    private static let timeFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private static let dateTimeFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm:ss"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            liveStatusSection
            Divider()
            sessionListSection
        }
    }

    // MARK: - Live Status

    private var liveStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ライブ状態")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    Text("追跡中:").foregroundStyle(.secondary)
                    Text(sessionManager.isTracking ? "はい" : "いいえ")
                        .foregroundStyle(sessionManager.isTracking ? .green : .red)
                        .fontWeight(.medium)
                }
                GridRow {
                    Text("アクティビティ:").foregroundStyle(.secondary)
                    Text(activityMonitor.state == .active ? "アクティブ" : "非アクティブ")
                        .foregroundStyle(activityMonitor.state == .active ? .green : .orange)
                        .fontWeight(.medium)
                }
                GridRow {
                    Text("セッション:").foregroundStyle(.secondary)
                    Text(sessionManager.currentSession != nil ? "進行中" : "なし")
                        .foregroundStyle(sessionManager.currentSession != nil ? .green : .secondary)
                        .fontWeight(.medium)
                }
                GridRow {
                    Text("作業時間:").foregroundStyle(.secondary)
                    Text(TimeFormatter.formatDuration(sessionManager.currentSessionSeconds))
                        .fontWeight(.medium)
                        .monospacedDigit()
                }
                GridRow {
                    Text("アイドル:").foregroundStyle(.secondary)
                    Text("\(Int(activityMonitor.idleSeconds))秒前")
                        .monospacedDigit()
                }
            }
            .font(.caption)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary)
    }

    // MARK: - Session List

    private var sessionListSection: some View {
        Group {
            if sessions.isEmpty {
                ContentUnavailableView(
                    "セッションなし",
                    systemImage: "clock.badge.questionmark",
                    description: Text("まだセッションが記録されていません")
                )
            } else {
                List {
                    ForEach(sessions) { session in
                        sessionRow(session)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private func sessionRow(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: session.isActive ? "record.circle" : "checkmark.circle")
                    .foregroundStyle(session.isActive ? .red : .green)
                    .font(.caption)

                Text(Self.dateTimeFormat.string(from: session.startTime))
                    .font(.caption)
                    .fontWeight(.medium)
                    .monospacedDigit()

                if let end = session.endTime {
                    Text("→ \(Self.timeFormat.string(from: end))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } else {
                    Text("→ 進行中")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            HStack(spacing: 12) {
                Label("作業 \(TimeFormatter.formatDuration(session.activeSeconds))", systemImage: "desktopcomputer")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
