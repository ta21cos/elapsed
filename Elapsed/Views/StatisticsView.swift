import SwiftUI
import SwiftData

struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedPeriod: Period = .day
    @State private var sessionsInRange: [Session] = []

    enum Period: String, CaseIterable {
        case day = "日"
        case week = "週"
        case month = "月"
    }

    private func cutoffDate(for period: Period) -> Date {
        let calendar = Calendar.current
        switch period {
        case .day:
            return calendar.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        case .week:
            return calendar.date(byAdding: .day, value: -84, to: Date()) ?? Date()
        case .month:
            return calendar.date(byAdding: .month, value: -12, to: Date()) ?? Date()
        }
    }

    private func fetchSessions() {
        let cutoff = cutoffDate(for: selectedPeriod)
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.startTime >= cutoff && !$0.isActive },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        sessionsInRange = (try? modelContext.fetch(descriptor)) ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            periodPicker
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)

            if buckets.isEmpty {
                ContentUnavailableView(
                    "データなし",
                    systemImage: "chart.bar",
                    description: Text("まだセッションが記録されていません")
                )
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        summaryCards
                        chartSection
                        detailList
                    }
                    .padding()
                }
            }
        }
        .task(id: selectedPeriod) {
            fetchSessions()
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("期間", selection: $selectedPeriod) {
            ForEach(Period.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 200)
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        let stats = currentPeriodStats
        return HStack(spacing: 12) {
            SummaryCard(
                icon: "clock.fill",
                title: "合計作業時間",
                value: TimeFormatter.formatDuration(stats.totalSeconds),
                color: .blue
            )
            SummaryCard(
                icon: "number",
                title: "セッション数",
                value: "\(stats.sessionCount)回",
                color: .green
            )
            SummaryCard(
                icon: "chart.line.uptrend.xyaxis",
                title: "平均/日",
                value: TimeFormatter.formatDuration(stats.averagePerDay),
                color: .orange
            )
        }
    }

    // MARK: - Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("作業時間の推移")
                .font(.headline)

            BarChartView(data: chartData, barColor: .blue)
                .frame(height: 140)
        }
        .padding()
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Detail List

    private var detailList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("詳細")
                .font(.headline)

            ForEach(buckets.prefix(20), id: \.label) { bucket in
                HStack {
                    Text(bucket.label)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 120, alignment: .leading)

                    ProgressView(value: bucket.ratio)
                        .tint(barTint(for: bucket.ratio))

                    Spacer()

                    Text(TimeFormatter.formatDuration(bucket.totalSeconds))
                        .font(.system(.callout, design: .rounded))
                        .fontWeight(.medium)
                        .monospacedDigit()
                        .frame(width: 90, alignment: .trailing)

                    Text("\(bucket.sessionCount)回")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
                .padding(.vertical, 4)

                if bucket.label != buckets.prefix(20).last?.label {
                    Divider()
                }
            }
        }
        .padding()
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Data

    private struct Bucket: Equatable {
        let label: String
        let totalSeconds: Int
        let sessionCount: Int
        let ratio: Double
    }

    private struct PeriodStats {
        let totalSeconds: Int
        let sessionCount: Int
        let averagePerDay: Int
    }

    private var buckets: [Bucket] {
        let calendar = Calendar.current
        let now = Date()

        let grouped: [(String, [Session])]
        let limit: Int

        switch selectedPeriod {
        case .day:
            limit = 14
            grouped = groupSessions(by: { session in
                let df = Self.dayFormatter
                return df.string(from: session.startTime)
            })
        case .week:
            limit = 12
            grouped = groupSessions(by: { session in
                let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: session.startTime)
                let weekStart = calendar.date(from: comps) ?? session.startTime
                return Self.weekFormatter.string(from: weekStart)
            })
        case .month:
            limit = 12
            grouped = groupSessions(by: { session in
                Self.monthFormatter.string(from: session.startTime)
            })
        }

        let limited = Array(grouped.prefix(limit))
        let maxSeconds = limited.map { $0.1.reduce(0) { $0 + $1.activeSeconds } }.max() ?? 1

        return limited.map { label, sessions in
            let total = sessions.reduce(0) { $0 + $1.activeSeconds }
            return Bucket(
                label: label,
                totalSeconds: total,
                sessionCount: sessions.count,
                ratio: Double(total) / Double(max(maxSeconds, 1))
            )
        }
    }

    private var currentPeriodStats: PeriodStats {
        let total = buckets.reduce(0) { $0 + $1.totalSeconds }
        let count = buckets.reduce(0) { $0 + $1.sessionCount }
        let days = max(buckets.count, 1)
        return PeriodStats(
            totalSeconds: total,
            sessionCount: count,
            averagePerDay: total / days
        )
    }

    private var chartData: [BarChartView.DataPoint] {
        Array(buckets.reversed().suffix(14).map {
            BarChartView.DataPoint(label: shortLabel($0.label), value: Double($0.totalSeconds), ratio: $0.ratio)
        })
    }

    private func groupSessions(by key: (Session) -> String) -> [(String, [Session])] {
        let grouped = Dictionary(grouping: sessionsInRange, by: key)
        return grouped.sorted { lhs, rhs in
            lhs.key > rhs.key
        }
    }

    private func shortLabel(_ label: String) -> String {
        switch selectedPeriod {
        case .day:
            let parts = label.split(separator: "/")
            return parts.count >= 2 ? String(parts[1]) : label
        case .week:
            return String(label.suffix(5))
        case .month:
            let parts = label.split(separator: "/")
            return parts.count >= 2 ? "\(parts[1])月" : label
        }
    }

    private func barTint(for ratio: Double) -> Color {
        if ratio >= 0.8 { return .blue }
        if ratio >= 0.5 { return .cyan }
        return .blue.opacity(0.7)
    }

    // MARK: - Formatters

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd (E)"
        f.locale = Locale(identifier: "ja_JP")
        return f
    }()

    private static let weekFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd"
        f.locale = Locale(identifier: "ja_JP")
        return f
    }()

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM"
        return f
    }()
}

// MARK: - Summary Card

private struct SummaryCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Bar Chart

struct BarChartView: View {
    struct DataPoint: Identifiable {
        var id: String { label }
        let label: String
        let value: Double
        let ratio: Double
    }

    let data: [DataPoint]
    var barColor: Color = .blue

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: max(2, geo.size.width / CGFloat(data.count) * 0.15)) {
                ForEach(data) { point in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(barColor.gradient)
                            .frame(height: max(2, geo.size.height * 0.85 * point.ratio))

                        Text(point.label)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
