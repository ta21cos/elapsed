import SwiftUI
import ServiceManagement

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
        .frame(width: 400, height: 300)
    }
}

struct GeneralSettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Toggle("ログイン時に自動起動", isOn: $settings.launchAtLogin)
                .onChange(of: settings.launchAtLogin) { _, newValue in
                    updateLaunchAtLogin(newValue)
                }
                .accessibilityLabel("ログイン時に自動起動")

            Toggle("通知音を有効にする", isOn: $settings.soundEnabled)
                .accessibilityLabel("通知音を有効にする")
        }
        .padding()
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
                Stepper(
                    "休憩通知までの作業時間: \(settings.workDurationMinutes)分",
                    value: $settings.workDurationMinutes,
                    in: 20...120,
                    step: 5
                )
                .accessibilityLabel("休憩通知までの作業時間")
                .accessibilityValue("\(settings.workDurationMinutes)分")

                Stepper(
                    "推奨休憩時間: \(settings.breakDurationMinutes)分",
                    value: $settings.breakDurationMinutes,
                    in: 5...30,
                    step: 5
                )
                .accessibilityLabel("推奨休憩時間")
                .accessibilityValue("\(settings.breakDurationMinutes)分")
            }

            Section("検知設定") {
                Stepper(
                    "非アクティブ判定: \(settings.inactivityThresholdMinutes)分",
                    value: $settings.inactivityThresholdMinutes,
                    in: 1...15
                )
                .accessibilityLabel("非アクティブ判定閾値")
                .accessibilityValue("\(settings.inactivityThresholdMinutes)分")

                Stepper(
                    "休憩リセット判定: \(settings.breakResetThresholdMinutes)分",
                    value: $settings.breakResetThresholdMinutes,
                    in: 5...30,
                    step: 5
                )
                .accessibilityLabel("休憩リセット判定閾値")
                .accessibilityValue("\(settings.breakResetThresholdMinutes)分")

                Stepper(
                    "スヌーズ時間: \(settings.snoozeDurationMinutes)分",
                    value: $settings.snoozeDurationMinutes,
                    in: 1...15
                )
                .accessibilityLabel("スヌーズ時間")
                .accessibilityValue("\(settings.snoozeDurationMinutes)分")
            }
        }
        .padding()
    }
}
