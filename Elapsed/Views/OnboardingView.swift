import SwiftUI

struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    @State private var accessibilityGranted = false
    @State private var notificationGranted = false

    let permissionManager: PermissionManager
    let notificationService: NotificationService
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            stepIndicator

            Spacer()

            switch currentStep {
            case 0:
                welcomeStep
            case 1:
                accessibilityStep
            case 2:
                notificationStep
            case 3:
                completionStep
            default:
                EmptyView()
            }

            Spacer()
        }
        .frame(width: 450, height: 350)
        .padding()
        .task {
            while !accessibilityGranted && !Task.isCancelled {
                accessibilityGranted = permissionManager.checkAccessibilityPermission()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<4) { step in
                Circle()
                    .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityLabel("ステップ \(currentStep + 1) / 4")
    }

    // MARK: - Welcome Step

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "timer")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("Elapsed へようこそ")
                .font(.title)
                .fontWeight(.bold)

            Text("PCの連続使用時間を自動で監視し、\n定期的な休憩を促します。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("始める") { currentStep = 1 }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }

    // MARK: - Accessibility Step

    private var accessibilityStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("アクセシビリティ権限")
                .font(.title2)
                .fontWeight(.bold)

            Text("キーボード・マウスの使用を検知するために、\nアクセシビリティ権限が必要です。\n入力の内容は一切記録しません。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if accessibilityGranted {
                Label("権限が付与されました", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.headline)

                Button("次へ") { currentStep = 2 }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            } else {
                Button("システム環境設定を開く") {
                    permissionManager.requestAccessibilityPermission()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("権限を確認する") {
                    accessibilityGranted = permissionManager.checkAccessibilityPermission()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button("スキップして次へ") {
                    currentStep = 2
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)
            }
        }
    }

    // MARK: - Notification Step

    private var notificationStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("通知の許可")
                .font(.title2)
                .fontWeight(.bold)

            Text("休憩時間になったら通知でお知らせします。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if notificationGranted {
                Label("通知が許可されました", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.headline)
            }

            Button("通知を許可する") {
                Task {
                    notificationGranted = await notificationService.requestAuthorization()
                    currentStep = 3
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("通知なしで続行") {
                currentStep = 3
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Completion Step

    private var completionStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("セットアップ完了！")
                .font(.title)
                .fontWeight(.bold)

            Text("メニューバーからいつでも状態を確認できます。\n健康的な作業習慣を始めましょう！")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("始める") {
                settings.hasCompletedOnboarding = true
                onComplete()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}
