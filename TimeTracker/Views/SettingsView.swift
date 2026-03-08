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

            StatisticsView()
                .tabItem {
                    Label("統計", systemImage: "chart.bar.fill")
                }
        }
        .frame(width: 560, height: 480)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                for window in NSApp.windows where window.title.contains("設定") || window.identifier?.rawValue == "com_apple_SwiftUI_Settings_window" {
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @Bindable var settings: AppSettings
    @State private var notificationStatus: UNAuthorizationStatus?

    var body: some View {
        Form {
            Section {
                SettingsRow(icon: "power", iconColor: .blue) {
                    Toggle("ログイン時に自動起動", isOn: $settings.launchAtLogin)
                        .onChange(of: settings.launchAtLogin) { _, newValue in
                            updateLaunchAtLogin(newValue)
                        }
                }

                SettingsRow(icon: "speaker.wave.2.fill", iconColor: .purple) {
                    Toggle("通知音を有効にする", isOn: $settings.soundEnabled)
                }

                SettingsRow(icon: "ant.fill", iconColor: .gray) {
                    Toggle("デバッグモード", isOn: $settings.debugMode)
                }
            } header: {
                Text("一般")
            }

            Section {
                SettingsRow(icon: "bell.badge.fill", iconColor: .red) {
                    HStack {
                        Text("通知の許可")
                        Spacer()
                        notificationStatusLabel
                    }
                }

                if notificationStatus != .authorized {
                    Button {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings")!
                        )
                    } label: {
                        HStack {
                            Spacer()
                            Label("システム設定で通知を許可する", systemImage: "arrow.up.forward.square")
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.blue)
                }
            } header: {
                Text("通知")
            }
        }
        .formStyle(.grouped)
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
                .font(.callout)
        case .denied:
            Label("拒否", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.callout)
        case .provisional:
            Label("仮許可", systemImage: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
                .font(.callout)
        default:
            Label("未設定", systemImage: "questionmark.circle")
                .foregroundStyle(.secondary)
                .font(.callout)
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

// MARK: - Timing Settings

struct TimingSettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                SettingsRow(icon: "deskclock.fill", iconColor: .blue) {
                    StepperField(
                        label: "休憩通知までの作業時間",
                        value: $settings.workDurationMinutes,
                        range: 1...120
                    )
                }
                SettingsRow(icon: "cup.and.saucer.fill", iconColor: .green) {
                    StepperField(
                        label: "推奨休憩時間",
                        value: $settings.breakDurationMinutes,
                        range: 1...30
                    )
                }
            } header: {
                Text("作業サイクル")
            }

            Section {
                SettingsRow(icon: "person.fill.checkmark", iconColor: .cyan) {
                    StepperField(
                        label: "セッション開始の確認時間",
                        value: $settings.sessionConfirmationSeconds,
                        range: 10...300,
                        unit: "秒"
                    )
                }
                SettingsRow(icon: "moon.fill", iconColor: .indigo) {
                    StepperField(
                        label: "非アクティブ判定",
                        value: $settings.inactivityThresholdMinutes,
                        range: 1...15
                    )
                }
                SettingsRow(icon: "alarm.fill", iconColor: .orange) {
                    StepperField(
                        label: "スヌーズ時間",
                        value: $settings.snoozeDurationMinutes,
                        range: 1...15
                    )
                }
            } header: {
                Text("検知設定")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Reusable Components

private struct SettingsRow<Content: View>: View {
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(iconColor.gradient, in: RoundedRectangle(cornerRadius: 6))

            content
        }
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
                .foregroundStyle(.secondary)
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
