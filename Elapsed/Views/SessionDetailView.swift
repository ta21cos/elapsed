import SwiftUI
import SwiftData

struct SessionDetailView: View {
    @Environment(SessionManager.self) private var sessionManager
    @Query private var sessions: [Session]

    init() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        _sessions = Query(
            filter: #Predicate<Session> { $0.startTime >= cutoff },
            sort: \Session.startTime,
            order: .reverse
        )
    }

    private static let dateFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd (E)"
        f.locale = Locale(identifier: "ja_JP")
        return f
    }()

    private static let timeFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private var groupedSessions: [(String, [Session])] {
        let grouped = Dictionary(grouping: sessions) { session in
            Self.dateFormat.string(from: session.startTime)
        }
        return grouped.sorted { lhs, rhs in
            guard let l = lhs.value.first?.startTime, let r = rhs.value.first?.startTime else {
                return false
            }
            return l > r
        }
    }

    private func displaySeconds(for session: Session) -> Int {
        session.isActive
            ? sessionManager.currentSessionSeconds
            : session.activeSeconds
    }

    var body: some View {
        Group {
            if sessions.isEmpty {
                ContentUnavailableView(
                    "セッションなし",
                    systemImage: "clock.badge.questionmark",
                    description: Text("まだセッションが記録されていません")
                )
            } else {
                List {
                    ForEach(groupedSessions, id: \.0) { date, daySessions in
                        Section {
                            ForEach(daySessions) { session in
                                sessionRow(session)
                            }
                        } header: {
                            HStack {
                                Text(date)
                                Spacer()
                                let total = daySessions.reduce(0) { $0 + displaySeconds(for: $1) }
                                Text("合計 \(TimeFormatter.formatDuration(total))")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func sessionRow(_ session: Session) -> some View {
        HStack {
            Image(systemName: session.isActive ? "circle.fill" : "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(session.isActive ? .red : .green)

            Text(Self.timeFormat.string(from: session.startTime))
                .monospacedDigit()

            Text("→")
                .foregroundStyle(.secondary)

            if let end = session.endTime {
                Text(Self.timeFormat.string(from: end))
                    .monospacedDigit()
            } else {
                Text("進行中")
                    .foregroundStyle(.red)
            }

            Spacer()

            Text(TimeFormatter.formatDuration(displaySeconds(for: session)))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
