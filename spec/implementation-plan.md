# ta21cos Time Tracker - 実装計画

## 1. テクニカルアーキテクチャ

### 1.1 プロジェクト構成

```
TimeTracker/
├── TimeTrackerApp.swift              # @main, MenuBarExtra 定義
├── Info.plist                         # 権限記述、LSUIElement
├── TimeTracker.entitlements          # App Sandbox, Accessibility
│
├── Models/
│   ├── Session.swift                  # SwiftData モデル
│   └── DailySummary.swift            # SwiftData モデル
│
├── Services/
│   ├── InputEventMonitor.swift       # CGEvent tap による入力監視
│   ├── SystemStateMonitor.swift      # ロック/スリープ検知
│   ├── ActivityMonitorService.swift  # 入力監視 + システム状態の統合
│   ├── SessionManager.swift          # セッション管理、状態遷移
│   ├── BreakReminderService.swift    # 休憩タイミング判定
│   ├── NotificationService.swift     # UserNotifications ラッパー
│   └── PermissionManager.swift       # 権限チェック・リクエスト
│
├── Settings/
│   └── AppSettings.swift             # @AppStorage ラッパー
│
├── Views/
│   ├── MenuBarView.swift             # メニューバーアイコン制御
│   ├── PopoverView.swift             # ポップオーバーメイン画面
│   ├── StatsView.swift               # 本日の統計セクション
│   ├── ProgressRingView.swift        # プログレスリング/バー
│   ├── SettingsView.swift            # 設定画面
│   └── OnboardingView.swift          # 初回セットアップ画面
│
├── Utilities/
│   ├── TimeFormatter.swift           # 時間表示のフォーマット
│   └── Constants.swift               # 定数定義
│
├── Resources/
│   └── Assets.xcassets               # アイコン、色定義
│
└── Tests/
    └── TimeTrackerTests/
        ├── SessionManagerTests.swift
        ├── BreakReminderServiceTests.swift
        ├── ActivityMonitorServiceTests.swift
        └── AppSettingsTests.swift
```

### 1.2 サービス責務

| サービス | 責務 | 依存先 |
|---------|------|--------|
| `InputEventMonitor` | CGEvent tap の管理、最終入力時刻の更新 | なし |
| `SystemStateMonitor` | ロック/スリープ/アンロック/ウェイクの検知 | なし |
| `ActivityMonitorService` | 入力監視とシステム状態を統合し、アクティブ/非アクティブを判定 | `InputEventMonitor`, `SystemStateMonitor`, `AppSettings` |
| `SessionManager` | セッションの開始/終了/一時停止、SwiftData 永続化、日次サマリー更新 | `ActivityMonitorService`, `SwiftData ModelContext` |
| `BreakReminderService` | 連続使用時間の監視、休憩タイミング判定、休憩タイマー管理 | `SessionManager`, `AppSettings` |
| `NotificationService` | UserNotifications の設定、通知の送信/取消、アクション処理 | `UNUserNotificationCenter` |
| `PermissionManager` | アクセシビリティ/通知権限のチェックとリクエスト | `AXIsProcessTrusted`, `UNUserNotificationCenter` |

### 1.3 依存関係図

```
┌──────────────┐    ┌───────────────────┐
│InputEvent    │    │SystemState        │
│Monitor       │    │Monitor            │
└──────┬───────┘    └────────┬──────────┘
       │                     │
       ▼                     ▼
┌──────────────────────────────────────┐
│       ActivityMonitorService         │
│  (アクティブ/非アクティブ判定の統合)    │
└──────────────────┬───────────────────┘
                   │
                   ▼
┌──────────────────────────────────────┐
│          SessionManager              │
│  (セッション管理, SwiftData永続化)     │
└──────────┬───────────────────────────┘
           │
           ▼
┌──────────────────────────────────────┐
│       BreakReminderService           │
│  (休憩タイミング判定, タイマー管理)     │
└──────────┬───────────────────────────┘
           │
           ▼
┌──────────────────────────────────────┐
│       NotificationService            │
│  (通知の送信/取消/アクション処理)      │
└──────────────────────────────────────┘

         ┌─────────────┐
         │ AppSettings  │──────▶ 各サービスが参照
         └─────────────┘

         ┌─────────────────┐
         │PermissionManager │──────▶ OnboardingView が使用
         └─────────────────┘
```

### 1.4 データフロー

```
CGEvent / DistributedNotification / NSWorkspace
          │
          ▼
  ActivityMonitorService  ──▶  @Published isActive: Bool
          │                    @Published lastInputTime: Date
          ▼
     SessionManager       ──▶  @Published currentSession: Session?
          │                    @Published currentStreak: TimeInterval
          ▼
  BreakReminderService    ──▶  @Published breakState: BreakState
          │                    @Published timeUntilBreak: TimeInterval
          ▼
    NotificationService   ──▶  UNNotification 送信
          │
          ▼
       MenuBarView        ──▶  アイコン状態更新
       PopoverView        ──▶  UI表示更新
```

---

## 2. 使用する macOS API

| API | 用途 | ステップ |
|-----|------|---------|
| `CGEvent.tapCreate` | グローバル入力イベントの監視 | Step 2 |
| `CFMachPortCreateRunLoopSource` | CGEvent tap を RunLoop に追加 | Step 2 |
| `AXIsProcessTrusted()` | アクセシビリティ権限チェック | Step 2, 6 |
| `DistributedNotificationCenter` | スクリーンロック/アンロック検知 | Step 2 |
| `NSWorkspace.willSleepNotification` | システムスリープ検知 | Step 2 |
| `NSWorkspace.didWakeNotification` | システムウェイク検知 | Step 2 |
| `SwiftData` (`@Model`, `ModelContainer`) | データ永続化 | Step 3 |
| `UNUserNotificationCenter` | ローカル通知の送信 | Step 4 |
| `UNNotificationAction` / `UNNotificationCategory` | 通知アクションボタン | Step 4 |
| `MenuBarExtra` (SwiftUI) | メニューバー常駐 | Step 1, 5 |
| `@AppStorage` | ユーザー設定の永続化 | Step 6 |
| `SMAppService` | ログイン時自動起動 | Step 6 |

---

## 3. 実装ステップ

### Step 1: プロジェクトセットアップ

**目標**: Xcode プロジェクトの作成、MenuBarExtra の骨格実装

**主要ファイル**:

#### `TimeTrackerApp.swift`

```swift
import SwiftUI
import SwiftData

@main
struct TimeTrackerApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environment(appState)
        } label: {
            Image(systemName: appState.menuBarIcon)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}
```

#### `AppState.swift` (後に各サービスに分割)

```swift
@Observable
final class AppState {
    var menuBarIcon: String = "timer"
    var isTracking: Bool = true
    var currentStreakSeconds: Int = 0
}
```

**Info.plist 設定**:

```xml
<key>LSUIElement</key>
<true/>  <!-- Dockに表示しない -->
```

**タスク**:
1. Xcode で macOS App プロジェクト作成 (SwiftUI lifecycle)
2. `Info.plist` に `LSUIElement = true` 設定
3. `MenuBarExtra` で骨格UI実装
4. ビルド・実行確認

---

### Step 2: アクティビティ監視

**目標**: CGEvent tap による入力監視、スクリーンロック/スリープ検知の実装

**主要ファイル**:

#### `InputEventMonitor.swift`

```swift
import Foundation
import CoreGraphics

@Observable
final class InputEventMonitor {
    private(set) var lastInputTime: Date = Date()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func start() {
        let eventMask: CGEventMask = (
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue)
        )

        // パッシブリスナー (listenOnly) として作成
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, _, event, refcon in
                let monitor = Unmanaged<InputEventMonitor>
                    .fromOpaque(refcon!)
                    .takeUnretainedValue()
                monitor.lastInputTime = Date()
                return nil  // listenOnly なので nil を返す
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap else { return }

        runLoopSource = CFMachPortCreateRunLoopSource(
            kCFAllocatorDefault, eventTap, 0
        )
        CFRunLoopAddSource(
            CFRunLoopGetCurrent(), runLoopSource, .commonModes
        )
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(
                CFRunLoopGetCurrent(), runLoopSource, .commonModes
            )
        }
        eventTap = nil
        runLoopSource = nil
    }
}
```

#### `SystemStateMonitor.swift`

```swift
import Foundation
import Combine

@Observable
final class SystemStateMonitor {
    enum SystemEvent {
        case screenLocked
        case screenUnlocked
        case systemSleep
        case systemWake
    }

    private(set) var lastEvent: SystemEvent?
    private(set) var lastEventTime: Date?
    var onSystemEvent: ((SystemEvent) -> Void)?

    func start() {
        // スクリーンロック/アンロック
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleScreenLock),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleScreenUnlock),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )

        // スリープ/ウェイク
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    func stop() {
        DistributedNotificationCenter.default().removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func handleScreenLock() {
        emit(.screenLocked)
    }

    @objc private func handleScreenUnlock() {
        emit(.screenUnlocked)
    }

    @objc private func handleSleep() {
        emit(.systemSleep)
    }

    @objc private func handleWake() {
        emit(.systemWake)
    }

    private func emit(_ event: SystemEvent) {
        lastEvent = event
        lastEventTime = Date()
        onSystemEvent?(event)
    }
}
```

#### `ActivityMonitorService.swift`

```swift
import Foundation

@Observable
final class ActivityMonitorService {
    enum ActivityState {
        case active
        case inactive
    }

    private let inputMonitor = InputEventMonitor()
    private let systemMonitor = SystemStateMonitor()
    private let settings: AppSettings
    private var pollingTimer: Timer?

    private(set) var state: ActivityState = .inactive
    private(set) var lastInputTime: Date = Date()
    var onStateChange: ((ActivityState) -> Void)?

    init(settings: AppSettings) {
        self.settings = settings
        setupSystemMonitorCallbacks()
    }

    func start() {
        inputMonitor.start()
        systemMonitor.start()
        startPolling()
    }

    func stop() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        inputMonitor.stop()
        systemMonitor.stop()
    }

    private func startPolling() {
        pollingTimer = Timer.scheduledTimer(
            withTimeInterval: 10.0,  // 10秒ポーリング
            repeats: true
        ) { [weak self] _ in
            self?.evaluateActivity()
        }
    }

    private func evaluateActivity() {
        lastInputTime = inputMonitor.lastInputTime
        let elapsed = Date().timeIntervalSince(lastInputTime)
        let threshold = TimeInterval(settings.inactivityThresholdMinutes * 60)

        let newState: ActivityState = elapsed > threshold ? .inactive : .active

        if newState != state {
            state = newState
            onStateChange?(newState)
        }
    }

    private func setupSystemMonitorCallbacks() {
        systemMonitor.onSystemEvent = { [weak self] event in
            switch event {
            case .screenLocked, .systemSleep:
                self?.state = .inactive
                self?.onStateChange?(.inactive)
            case .screenUnlocked, .systemWake:
                // 入力再開を待つ（pollingで自然にactiveになる）
                break
            }
        }
    }
}
```

**タスク**:
1. `InputEventMonitor` 実装
2. `SystemStateMonitor` 実装
3. `ActivityMonitorService` 実装（統合）
4. アクセシビリティ権限チェック追加
5. 動作確認: コンソールにアクティブ/非アクティブ遷移をログ出力

**注意点**:
- `CGEvent.tapCreate` は App Sandbox 内では動作しない場合がある。Hardened Runtime + アクセシビリティ権限が必要
- `listenOnly` オプションを使用し、イベントの改変・ブロックは行わない
- `Unmanaged` でのメモリ管理に注意 (`passUnretained` を使用し、`InputEventMonitor` の寿命を保証する)

---

### Step 3: セッション管理

**目標**: SwiftData によるセッションの永続化、非アクティブ/リセット判定ロジック

**主要ファイル**:

#### `Session.swift`

```swift
import Foundation
import SwiftData

@Model
final class Session {
    var id: UUID
    var startTime: Date
    var endTime: Date?
    var activeSeconds: Int
    var inactiveSeconds: Int
    var breaksTaken: Int
    var longestStreakSeconds: Int
    var isActive: Bool

    init() {
        self.id = UUID()
        self.startTime = Date()
        self.endTime = nil
        self.activeSeconds = 0
        self.inactiveSeconds = 0
        self.breaksTaken = 0
        self.longestStreakSeconds = 0
        self.isActive = true
    }
}
```

#### `DailySummary.swift`

```swift
import Foundation
import SwiftData

@Model
final class DailySummary {
    @Attribute(.unique) var date: String
    var totalActiveSeconds: Int
    var totalInactiveSeconds: Int
    var totalBreaks: Int
    var longestStreakSeconds: Int
    var sessionCount: Int
    var firstSessionStart: Date?
    var lastSessionEnd: Date?

    init(date: String) {
        self.date = date
        self.totalActiveSeconds = 0
        self.totalInactiveSeconds = 0
        self.totalBreaks = 0
        self.longestStreakSeconds = 0
        self.sessionCount = 0
    }
}
```

#### `SessionManager.swift`

```swift
import Foundation
import SwiftData

@Observable
final class SessionManager {
    private let modelContext: ModelContext
    private let settings: AppSettings

    private(set) var currentSession: Session?
    private(set) var currentStreakSeconds: Int = 0
    private(set) var todaySummary: DailySummary?
    private var streakStartTime: Date?
    private var inactiveStartTime: Date?
    private var updateTimer: Timer?

    init(modelContext: ModelContext, settings: AppSettings) {
        self.modelContext = modelContext
        self.settings = settings
        self.todaySummary = fetchOrCreateTodaySummary()
    }

    // アクティビティ状態変化のハンドリング
    func handleActivityChange(_ state: ActivityMonitorService.ActivityState) {
        switch state {
        case .active:
            handleBecameActive()
        case .inactive:
            handleBecameInactive()
        }
    }

    private func handleBecameActive() {
        if currentSession == nil {
            startNewSession()
        }

        // 非アクティブだった場合の復帰判定
        if let inactiveStart = inactiveStartTime {
            let inactiveDuration = Date().timeIntervalSince(inactiveStart)
            let resetThreshold = TimeInterval(
                settings.breakResetThresholdMinutes * 60
            )

            if inactiveDuration >= resetThreshold {
                // 休憩としてリセット
                currentSession?.breaksTaken += 1
                currentStreakSeconds = 0
                streakStartTime = Date()
            }
            // 短い中断: 連続時間を継続
            inactiveStartTime = nil
        }

        if streakStartTime == nil {
            streakStartTime = Date()
        }
        startStreakTimer()
    }

    private func handleBecameInactive() {
        inactiveStartTime = Date()
        updateTimer?.invalidate()
        updateTimer = nil

        // 現在のストリークを記録
        if let session = currentSession,
           currentStreakSeconds > session.longestStreakSeconds {
            session.longestStreakSeconds = currentStreakSeconds
        }
    }

    private func startNewSession() {
        let session = Session()
        modelContext.insert(session)
        currentSession = session
        streakStartTime = Date()
        currentStreakSeconds = 0

        todaySummary?.sessionCount += 1
        if todaySummary?.firstSessionStart == nil {
            todaySummary?.firstSessionStart = session.startTime
        }

        try? modelContext.save()
    }

    func endCurrentSession() {
        guard let session = currentSession else { return }
        session.endTime = Date()
        session.isActive = false
        updateDailySummary(with: session)
        try? modelContext.save()

        currentSession = nil
        currentStreakSeconds = 0
        streakStartTime = nil
    }

    private func startStreakTimer() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in
            guard let self, let start = self.streakStartTime else { return }
            self.currentStreakSeconds = Int(Date().timeIntervalSince(start))
            self.currentSession?.activeSeconds += 1
        }
    }

    private func fetchOrCreateTodaySummary() -> DailySummary {
        let today = Self.dateString(from: Date())
        let descriptor = FetchDescriptor<DailySummary>(
            predicate: #Predicate { $0.date == today }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        let summary = DailySummary(date: today)
        modelContext.insert(summary)
        try? modelContext.save()
        return summary
    }

    private func updateDailySummary(with session: Session) {
        guard let summary = todaySummary else { return }
        summary.totalActiveSeconds += session.activeSeconds
        summary.totalInactiveSeconds += session.inactiveSeconds
        summary.totalBreaks += session.breaksTaken
        if session.longestStreakSeconds > summary.longestStreakSeconds {
            summary.longestStreakSeconds = session.longestStreakSeconds
        }
        summary.lastSessionEnd = session.endTime
    }

    static func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
```

**タスク**:
1. SwiftData モデル (`Session`, `DailySummary`) 実装
2. `ModelContainer` を `TimeTrackerApp` に設定
3. `SessionManager` 実装
4. `ActivityMonitorService` と `SessionManager` の接続
5. 動作確認: セッション開始/終了、データ永続化の検証

**注意点**:
- SwiftData の `ModelContext` はメインスレッドで操作すること
- 日付跨ぎの処理: 深夜0時に `todaySummary` を切り替えるロジックが必要（Step 3 では簡易実装、後に改善）
- `Timer` のリーク防止: `invalidate()` を確実に呼ぶ

---

### Step 4: 休憩リマインダー

**目標**: 連続使用時間の監視、通知送信、休憩タイマー管理

**主要ファイル**:

#### `NotificationService.swift`

```swift
import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let breakCategoryId = "breakReminder"
    static let takeBreakActionId = "takeBreak"
    static let snoozeActionId = "snooze"

    private let settings: AppSettings
    var onTakeBreak: (() -> Void)?
    var onSnooze: (() -> Void)?

    init(settings: AppSettings) {
        self.settings = settings
    }

    func setup() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        registerCategories()
    }

    /// スヌーズ時間の設定変更時にも呼び出してカテゴリを再登録する
    func registerCategories() {
        let center = UNUserNotificationCenter.current()

        // アクションボタン定義
        let takeBreakAction = UNNotificationAction(
            identifier: Self.takeBreakActionId,
            title: "休憩する",
            options: [.foreground]
        )
        let snoozeAction = UNNotificationAction(
            identifier: Self.snoozeActionId,
            title: "\(settings.snoozeDurationMinutes)分後に再通知",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: Self.breakCategoryId,
            actions: [takeBreakAction, snoozeAction],
            intentIdentifiers: []
        )
        center.setNotificationCategories([category])
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func sendBreakReminder(streakMinutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "休憩しましょう"
        content.body = "\(streakMinutes)分間連続で作業しています。立ち上がってストレッチしましょう！"
        content.sound = .default
        content.categoryIdentifier = Self.breakCategoryId

        let request = UNNotificationRequest(
            identifier: "breakReminder-\(UUID().uuidString)",
            content: content,
            trigger: nil  // 即座に送信
        )

        UNUserNotificationCenter.current().add(request)
    }

    func sendReturnNotification() {
        let content = UNMutableNotificationContent()
        content.title = "休憩終了"
        content.body = "リフレッシュできましたか？作業に戻りましょう！"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "returnNotification",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func cancelPendingNotifications() {
        UNUserNotificationCenter.current()
            .removeAllPendingNotificationRequests()
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        switch response.actionIdentifier {
        case Self.takeBreakActionId:
            onTakeBreak?()
        case Self.snoozeActionId:
            onSnooze?()
        default:
            break
        }
    }

    // フォアグラウンドでも通知を表示
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
```

#### `BreakReminderService.swift`

```swift
import Foundation

@Observable
final class BreakReminderService {
    enum BreakState {
        case working           // 作業中
        case reminderSent      // 通知送信済み（まだ休憩していない）
        case onBreak           // 休憩中
    }

    private let sessionManager: SessionManager
    private let notificationService: NotificationService
    private let settings: AppSettings

    private(set) var breakState: BreakState = .working
    private(set) var breakTimeRemaining: TimeInterval = 0
    private var breakTimer: Timer?
    private var breakStartTime: Date?

    var timeUntilBreak: TimeInterval {
        let threshold = TimeInterval(settings.workDurationMinutes * 60)
        let elapsed = TimeInterval(sessionManager.currentStreakSeconds)
        return max(0, threshold - elapsed)
    }

    init(
        sessionManager: SessionManager,
        notificationService: NotificationService,
        settings: AppSettings
    ) {
        self.sessionManager = sessionManager
        self.notificationService = notificationService
        self.settings = settings
        setupNotificationCallbacks()
    }

    func checkAndNotify() {
        guard breakState == .working else { return }

        let threshold = settings.workDurationMinutes * 60
        if sessionManager.currentStreakSeconds >= threshold {
            notificationService.sendBreakReminder(
                streakMinutes: settings.workDurationMinutes
            )
            breakState = .reminderSent
        }
    }

    func startBreak() {
        breakState = .onBreak
        breakStartTime = Date()
        breakTimeRemaining = TimeInterval(settings.breakDurationMinutes * 60)

        breakTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in
            guard let self else { return }
            self.breakTimeRemaining -= 1

            if self.breakTimeRemaining <= 0 {
                self.endBreak(countAsBreak: true)
            }
        }
    }

    /// 休憩を終了する
    /// - Parameter countAsBreak: 有効な休憩としてカウントするかどうか
    ///   PC操作による早期終了の場合、経過時間が `breakResetThresholdMinutes` 以上の場合のみカウント
    func endBreak(countAsBreak: Bool? = nil) {
        breakTimer?.invalidate()
        breakTimer = nil

        let shouldCount: Bool
        if let explicit = countAsBreak {
            shouldCount = explicit
        } else if let start = breakStartTime {
            // PC操作で中断された場合: 休憩時間が閾値以上ならカウント
            let elapsed = Date().timeIntervalSince(start)
            let threshold = TimeInterval(settings.breakResetThresholdMinutes * 60)
            shouldCount = elapsed >= threshold
        } else {
            shouldCount = false
        }

        breakState = .working
        breakTimeRemaining = 0
        breakStartTime = nil

        if shouldCount {
            notificationService.sendReturnNotification()
        }
    }

    func snooze() {
        breakState = .working
        // スヌーズ後、snooze分数分だけ加算して再チェック
        // (currentStreakSecondsが閾値を超え続けているため、
        //  snooze時間後に再度チェックされて通知が送られる)
        DispatchQueue.main.asyncAfter(
            deadline: .now() + TimeInterval(settings.snoozeDurationMinutes * 60)
        ) { [weak self] in
            self?.breakState = .working
            self?.checkAndNotify()
        }
    }

    private func setupNotificationCallbacks() {
        notificationService.onTakeBreak = { [weak self] in
            self?.startBreak()
        }
        notificationService.onSnooze = { [weak self] in
            self?.snooze()
        }
    }
}
```

**タスク**:
1. `NotificationService` 実装（通知カテゴリ、アクション定義）
2. `BreakReminderService` 実装（休憩判定、タイマー管理）
3. `SessionManager` との連携
4. メニューバーアイコンの状態変化（警告色、休憩中アイコン）
5. 動作確認: 50分（テスト用に短縮）後の通知、アクション処理

**注意点**:
- `UNUserNotificationCenterDelegate` を設定しないとフォアグラウンド通知が表示されない
- `DispatchQueue.main.asyncAfter` でのスヌーズは簡易実装。正確なタイマーが必要な場合は `Timer` に置換

---

### Step 5: メニューバーUI

**目標**: ポップオーバーUI、プログレスバー、統計表示、休憩カウントダウン

**主要ファイル**:

#### `PopoverView.swift`

```swift
import SwiftUI

struct PopoverView: View {
    @Environment(SessionManager.self) private var sessionManager
    @Environment(BreakReminderService.self) private var breakService
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ヘッダー: 現在の状態
            StatusHeaderView(
                breakState: breakService.breakState,
                currentStreak: sessionManager.currentStreakSeconds
            )

            Divider()

            // プログレスリング: 休憩までの残り時間
            if breakService.breakState == .onBreak {
                BreakCountdownView(
                    remaining: breakService.breakTimeRemaining,
                    total: TimeInterval(settings.breakDurationMinutes * 60)
                )
            } else {
                WorkProgressView(
                    elapsed: TimeInterval(sessionManager.currentStreakSeconds),
                    total: TimeInterval(settings.workDurationMinutes * 60)
                )
            }

            Divider()

            // 本日の統計
            if let summary = sessionManager.todaySummary {
                StatsView(summary: summary)
            }

            Divider()

            // コントロールボタン
            HStack {
                Button(sessionManager.currentSession != nil ? "一時停止" : "再開") {
                    // TODO: 一時停止/再開の実装
                }
                Spacer()
                Button("設定") {
                    NSApp.sendAction(
                        Selector(("showSettingsWindow:")),
                        to: nil, from: nil
                    )
                }
                Button("終了") {
                    NSApp.terminate(nil)
                }
            }
        }
        .padding()
        .frame(width: 300)
    }
}
```

#### `StatsView.swift`

```swift
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
                    value: formatDuration(summary.totalActiveSeconds)
                )
                Spacer()
                StatItem(
                    icon: "cup.and.saucer",
                    label: "休憩回数",
                    value: "\(summary.totalBreaks)回"
                )
            }
            HStack {
                StatItem(
                    icon: "flame",
                    label: "最長連続",
                    value: formatDuration(summary.longestStreakSeconds)
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

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)時間\(minutes)分"
        }
        return "\(minutes)分"
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
    }
}
```

#### `MenuBarView.swift` (アイコン状態管理)

```swift
import SwiftUI

struct MenuBarIconProvider {
    /// 警告アイコン表示の閾値を算出する
    /// workDurationMinutes の10分前（最低10分）
    static func warningThresholdSeconds(workDurationMinutes: Int) -> Int {
        max(10, workDurationMinutes - 10) * 60
    }

    static func icon(
        breakState: BreakReminderService.BreakState,
        activityState: ActivityMonitorService.ActivityState,
        isTracking: Bool,
        streakSeconds: Int,
        workDurationMinutes: Int  // 設定値から取得
    ) -> String {
        guard isTracking else { return "stop.circle" }

        switch breakState {
        case .onBreak:
            return "cup.and.saucer.fill"
        case .reminderSent, .working:
            switch activityState {
            case .inactive:
                return "moon.zzz"
            case .active:
                let threshold = warningThresholdSeconds(
                    workDurationMinutes: workDurationMinutes
                )
                if streakSeconds >= threshold {
                    return "timer.circle.fill"
                }
                return "timer"
            }
        }
    }
}
```

**タスク**:
1. `PopoverView` 実装（レイアウト、データバインディング）
2. `StatsView` 実装（統計表示）
3. `ProgressRingView` 実装（プログレスバー/リング）
4. `MenuBarIconProvider` 実装（アイコン状態遷移）
5. 休憩カウントダウンビュー実装
6. UIテスト、Xcodeプレビューでの確認

---

### Step 6: 設定画面 & オンボーディング

**目標**: ユーザー設定のカスタマイズ画面、初回セットアップフロー

**主要ファイル**:

#### `AppSettings.swift`

```swift
import Foundation
import SwiftUI

@Observable
final class AppSettings {
    @ObservationIgnored
    @AppStorage("workDurationMinutes") var workDurationMinutes: Int = 50

    @ObservationIgnored
    @AppStorage("breakDurationMinutes") var breakDurationMinutes: Int = 10

    @ObservationIgnored
    @AppStorage("inactivityThresholdMinutes") var inactivityThresholdMinutes: Int = 5

    @ObservationIgnored
    @AppStorage("breakResetThresholdMinutes") var breakResetThresholdMinutes: Int = 10

    @ObservationIgnored
    @AppStorage("snoozeDurationMinutes") var snoozeDurationMinutes: Int = 5

    @ObservationIgnored
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false

    @ObservationIgnored
    @AppStorage("soundEnabled") var soundEnabled: Bool = true

    @ObservationIgnored
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
}
```

#### `SettingsView.swift`

```swift
import SwiftUI

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
            Toggle("通知音を有効にする", isOn: $settings.soundEnabled)
        }
        .padding()
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
                Stepper(
                    "推奨休憩時間: \(settings.breakDurationMinutes)分",
                    value: $settings.breakDurationMinutes,
                    in: 5...30,
                    step: 5
                )
            }

            Section("検知設定") {
                Stepper(
                    "非アクティブ判定: \(settings.inactivityThresholdMinutes)分",
                    value: $settings.inactivityThresholdMinutes,
                    in: 1...15
                )
                Stepper(
                    "休憩リセット判定: \(settings.breakResetThresholdMinutes)分",
                    value: $settings.breakResetThresholdMinutes,
                    in: 5...30,
                    step: 5
                )
                Stepper(
                    "スヌーズ時間: \(settings.snoozeDurationMinutes)分",
                    value: $settings.snoozeDurationMinutes,
                    in: 1...15
                )
            }
        }
        .padding()
    }
}
```

#### `OnboardingView.swift`

```swift
import SwiftUI

struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings
    @State private var currentStep = 0
    @State private var accessibilityGranted = false
    @State private var notificationGranted = false

    let permissionManager: PermissionManager
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            switch currentStep {
            case 0:
                WelcomeStep(onNext: { currentStep = 1 })
            case 1:
                AccessibilityStep(
                    isGranted: accessibilityGranted,
                    permissionManager: permissionManager,
                    onNext: { currentStep = 2 }
                )
            case 2:
                NotificationStep(
                    isGranted: notificationGranted,
                    onNext: { currentStep = 3 },
                    onSkip: { currentStep = 3 }
                )
            case 3:
                CompletionStep(onComplete: {
                    settings.hasCompletedOnboarding = true
                    onComplete()
                })
            default:
                EmptyView()
            }
        }
        .frame(width: 450, height: 350)
        .padding()
        .task {
            // アクセシビリティ権限のポーリング
            while !accessibilityGranted {
                accessibilityGranted = permissionManager
                    .checkAccessibilityPermission()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

struct WelcomeStep: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "timer")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("Time Tracker へようこそ")
                .font(.title)
                .fontWeight(.bold)

            Text("PCの連続使用時間を自動で監視し、\n定期的な休憩を促します。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Spacer()

            Button("始める") { onNext() }
                .buttonStyle(.borderedProminent)
        }
    }
}
```

#### `PermissionManager.swift`

```swift
import Foundation
import ApplicationServices

final class PermissionManager {
    func checkAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true
        ] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
```

**タスク**:
1. `AppSettings` 実装
2. `SettingsView` 実装（タブ構成、Stepper、Toggle）
3. `PermissionManager` 実装
4. `OnboardingView` 実装（ステップUI、権限チェック）
5. `SMAppService` でログイン時自動起動を設定
6. 動作確認: 設定変更の即時反映、初回セットアップフロー

---

## 4. 既知の注意点・ワークアラウンド

### 4.1 App Sandbox と CGEvent tap

- **問題**: App Sandbox 有効時、`CGEvent.tapCreate` が `nil` を返す場合がある
- **ワークアラウンド**: Hardened Runtime を使用し、`com.apple.security.accessibility` entitlement を設定。App Sandbox は無効化する（Mac App Store 配布しない前提）
- **代替案**: Sandbox 内で動作させたい場合、`NSEvent.addGlobalMonitorForEvents` を使用（ただしキーイベントの検知精度が下がる）

### 4.2 DistributedNotificationCenter の制限

- **問題**: macOS のバージョンによって通知名が変わる可能性がある
- **ワークアラウンド**: `com.apple.screenIsLocked` は macOS 10.6 以降で安定。将来の変更に備え、`SystemStateMonitor` を差し替え可能な設計にする

### 4.3 SwiftData の制約

- **問題**: SwiftData はメインスレッドでの操作が前提。バックグラウンドでの大量データ操作には不向き
- **ワークアラウンド**: MVP フェーズではデータ量が少ないため問題なし。Phase 2 以降でデータが増加した場合、`ModelActor` を使用してバックグラウンドコンテキストを導入

### 4.4 深夜跨ぎの処理

- **問題**: 深夜0時をまたぐセッションで `DailySummary` が不正確になる
- **ワークアラウンド**: Step 3 の `SessionManager` に日付変更検知ロジックを追加。0時をまたぐ場合、現在のセッションを終了し、新しい日付で `DailySummary` を再作成

### 4.5 メモリ管理 (CGEvent callback)

- **問題**: `CGEvent.tapCreate` のコールバック内で `Unmanaged` を使用するため、メモリリークのリスク
- **ワークアラウンド**: `passUnretained` を使用し、`InputEventMonitor` インスタンスの寿命をアプリケーションのライフサイクルに合わせる。`stop()` で確実にリソースを解放

### 4.6 Energy Impact の最小化

- **問題**: Timer のポーリングがバッテリーに影響する
- **ワークアラウンド**:
  - ポーリング間隔を10秒に設定（1秒ごとのストリーク更新タイマーは別）
  - `Timer.tolerance` を設定して OS のタイマー結合を許可
  - 非アクティブ状態時はストリーク更新タイマーを停止
