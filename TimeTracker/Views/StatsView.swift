import SwiftUI

struct StatsView: View {
    let summary: DailySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("本日の統計")
                .font(.headline)

            HStack {
                StatItem(
                    icon: "clock",
                    label: "作業時間",
                    value: TimeFormatter.formatDuration(summary.totalActiveSeconds)
                )
                Spacer()
                StatItem(
                    icon: "list.number",
                    label: "セッション数",
                    value: "\(summary.sessionCount)回"
                )
            }
        }
    }
}

struct StatItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.body, design: .rounded))
                .fontWeight(.semibold)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }
}
