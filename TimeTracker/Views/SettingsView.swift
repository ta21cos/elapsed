import SwiftUI
import ServiceManagement
import UserNotifications

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        TabView {
            GeneralSettingsView(settings: settings)
                .tabItem {
                    Label("一般", systemImage: "gear")
                }

            TimingSettingsView(settings: settings)
                .tabItem {
                    Label("タイミング", systemImage: "clock")
                }
        }
        .frame(width: 500, height: 400)
    }
}

struct GeneralSettingsView: View {
    @Bindable var settings: AppSettings
    @State private var notificationStatus: UNAuthorizationStatus?

    var body: some View {
        Form {
            Section("一般") {
                Toggle("ログイン時に自動起動", isOn: $settings.launchAtLogin)
                    .onChange(of: settings.launchAtLogin) { _, newValue in
                        updateLaunchAtLogin(newValue)
                    }
                    .accessibilityLabel("ログイン時に自動起動")

                Toggle("通知音を有効にする", isOn: $settings.soundEnabled)
                    .accessibilityLabel("通知音を有効にする")

                Toggle("デバッグモード", isOn: $settings.debugMode)
                    .accessibilityLabel("デバッグモード")
            }

            Section("通知") {
                HStack {
                    Text("通知の許可")
                    Spacer()
                    notificationStatusLabel
                }

                if notificationStatus != .authorized {
                    Button("システム設定で通知を許可する") {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings")!
                        )
                    }
                }
            }
        }
        .padding()
        .task { await refreshNotificationStatus() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await refreshNotificationStatus() }
        }
    }

    @ViewBuilder
    private var notificationStatusLabel: some View {
        switch notificationStatus {
        case .authorized:
            Label("許可済み", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .denied:
            Label("拒否", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .provisional:
            Label("仮許可", systemImage: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
        default:
            Label("未設定", systemImage: "questionmark.circle")
                .foregroundStyle(.secondary)
        }
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            settings.launchAtLogin = !enabled
        }
    }
}

struct TimingSettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section("作業サイクル") {
                StepperField(
                    label: "休憩通知までの作業時間",
                    value: $settings.workDurationMinutes,
                    range: 1...120
                )
                StepperField(
                    label: "推奨休憩時間",
                    value: $settings.breakDurationMinutes,
                    range: 1...30
                )
            }

            Section("検知設定") {
                StepperField(
                    label: "セッション開始の確認時間",
                    value: $settings.sessionConfirmationSeconds,
                    range: 10...300,
                    unit: "秒"
                )
                StepperField(
                    label: "非アクティブ判定（セッション終了）",
                    value: $settings.inactivityThresholdMinutes,
                    range: 1...15
                )
                StepperField(
                    label: "スヌーズ時間",
                    value: $settings.snoozeDurationMinutes,
                    range: 1...15
                )
            }
        }
        .padding()
    }
}

private struct StepperField: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var unit: String = "分"

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("", value: $value, format: .number)
                .frame(width: 48)
                .multilineTextAlignment(.trailing)
                .onSubmit { value = value.clamped(to: range) }
            Stepper("", value: $value, in: range)
                .labelsHidden()
            Text(unit)
        }
        .accessibilityLabel(label)
        .accessibilityValue("\(value)\(unit)")
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
