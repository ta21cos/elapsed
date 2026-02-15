import SwiftUI

struct ProgressRingView: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat

    init(progress: Double, color: Color = .blue, lineWidth: CGFloat = 8) {
        self.progress = min(max(progress, 0), 1)
        self.color = color
        self.lineWidth = lineWidth
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .round
                ))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
        }
    }
}

struct WorkProgressView: View {
    let elapsed: TimeInterval
    let total: TimeInterval

    private var progress: Double {
        guard total > 0 else { return 0 }
        return min(elapsed / total, 1.0)
    }

    private var progressColor: Color {
        if progress >= 1.0 { return .red }
        if progress >= 0.8 { return .orange }
        return .blue
    }

    var body: some View {
        HStack(spacing: 16) {
            ProgressRingView(
                progress: progress,
                color: progressColor,
                lineWidth: 6
            )
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text("連続作業時間")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(TimeFormatter.formatDuration(Int(elapsed)))
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                Text("休憩まで \(TimeFormatter.formatDuration(Int(max(0, total - elapsed))))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("連続作業時間 \(TimeFormatter.formatDuration(Int(elapsed)))、休憩まで \(TimeFormatter.formatDuration(Int(max(0, total - elapsed))))")
    }
}

struct BreakCountdownView: View {
    let remaining: TimeInterval
    let total: TimeInterval

    private var progress: Double {
        guard total > 0 else { return 0 }
        return 1.0 - min(remaining / total, 1.0)
    }

    var body: some View {
        HStack(spacing: 16) {
            ProgressRingView(
                progress: progress,
                color: .green,
                lineWidth: 6
            )
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text("休憩中")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(TimeFormatter.formatCountdown(Int(max(0, remaining))))
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
                Text("リフレッシュしましょう！")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("休憩中、残り \(TimeFormatter.formatCountdown(Int(max(0, remaining))))")
    }
}
