# ta21cos Time Tracker - 仕様書

## 1. プロダクト概要

### 1.1 コンセプト

デスクワーク中心のユーザーが、PCの連続使用時間を自動で監視し、定期的にスタンディング・ストレッチなどの休憩を促す macOS メニューバー常駐アプリ。

### 1.2 バリュープロポジション

- **完全自動追跡**: 手動のタイマー操作が不要。PC操作を自動検知してセッションを管理
- **非侵入型**: メニューバーに常駐し、通知で休憩を促す。作業フローを妨げない
- **健康管理**: 長時間の連続PC使用を防ぎ、定期的な休憩を習慣化

### 1.3 対象ユーザー

- デスクワーク中心の macOS ユーザー
- 長時間PC作業による健康リスクを意識しているが、自発的な休憩が難しいユーザー

### 1.4 技術スタック

| 項目 | 選定技術 |
|------|---------|
| 言語 | Swift 5.9+ |
| UI フレームワーク | SwiftUI |
| データ永続化 | SwiftData |
| 設定管理 | UserDefaults |
| 通知 | UserNotifications |
| 対応OS | macOS 14 Sonoma 以上 |

---

## 2. 機能要件

### 2.1 Phase 1 (MVP)

#### FR-001: アクティビティ自動監視

| 項目 | 内容 |
|------|------|
| 概要 | キーボード・マウス入力イベントを監視し、ユーザーのPC使用状況を自動追跡する |
| 検知方式 | `CGEvent` tap (パッシブリスナー) |
| ポーリング間隔 | 10秒ごとに最終入力イベントのタイムスタンプを評価 |
| 非アクティブ判定 | 最終入力から **5分** 経過で非アクティブ状態に遷移 |
| 監視対象イベント | キーボード入力 (`keyDown`)、マウス移動 (`mouseMoved`)、マウスクリック (`leftMouseDown`, `rightMouseDown`)、スクロール (`scrollWheel`) |
| 実装クラス | `InputEventMonitor` |

**詳細動作**:
1. アプリ起動時に `CGEvent` tap を作成し、`RunLoop` に追加
2. イベント発生時に `lastInputTimestamp` を更新（イベント内容は記録しない）
3. 10秒間隔の `Timer` で `lastInputTimestamp` を評価
4. 現在時刻 - `lastInputTimestamp` > 5分 → 非アクティブ通知を発行
5. 非アクティブ状態中にイベント検知 → アクティブ復帰通知を発行

**必要な権限**: アクセシビリティ権限 (Accessibility)

#### FR-002: スクリーンロック / スリープ検知

| 項目 | 内容 |
|------|------|
| 概要 | スクリーンロック・システムスリープを検知し、自動的に非アクティブ状態に遷移する |
| ロック検知 | `DistributedNotificationCenter` で `com.apple.screenIsLocked` / `com.apple.screenIsUnlocked` を監視 |
| スリープ検知 | `NSWorkspace.shared.notificationCenter` で `willSleepNotification` / `didWakeNotification` を監視 |
| 実装クラス | `SystemStateMonitor` |

**詳細動作**:
1. ロック/スリープ検知 → 即座に非アクティブ状態に遷移、ロック開始時刻を記録
2. アンロック/ウェイク検知 → 離席時間を算出
3. 離席時間 ≥ 設定閾値（デフォルト10分）→ 休憩としてカウントし、連続使用時間をリセット
4. 離席時間 < 設定閾値 → 一時的な中断として、連続使用時間を継続

#### FR-003: 休憩リマインダー通知

| 項目 | 内容 |
|------|------|
| 概要 | 連続使用時間が閾値に達したら通知で休憩を促す |
| トリガー | 連続アクティブ時間が **50分** に達した時点 |
| 通知方式 | `UserNotifications` フレームワーク |
| アクションボタン | 「休憩する」「5分後に再通知」 |
| 実装クラス | `BreakReminderService`, `NotificationService` |

**詳細動作**:
1. `SessionManager` から連続使用時間の更新を受信
2. 連続使用時間 ≥ 50分 → 通知をスケジュール
3. 「休憩する」タップ → 休憩タイマー開始（デフォルト10分）、メニューバーアイコン変更
4. 「{スヌーズ時間}分後に再通知」タップ → スヌーズ時間後に再度通知をスケジュール（ボタンテキストは `snoozeDurationMinutes` の値を動的に反映）
5. 休憩タイマー完了 → 復帰通知を表示
6. 休憩中にPC操作検知 → 休憩終了としてカウント（休憩時間が設定閾値以上の場合のみ）

**通知の内容例**:
- タイトル: 「休憩しましょう」
- 本文: 「50分間連続で作業しています。立ち上がってストレッチしましょう！」
- カテゴリ: `breakReminder`

#### FR-004: メニューバーUI

| 項目 | 内容 |
|------|------|
| 概要 | メニューバーに常駐し、現在の状態を表示する |
| 実装方式 | SwiftUI `MenuBarExtra` (window style) |
| 実装クラス | `TimeTrackerApp`, `MenuBarView`, `PopoverView` |

**アイコン状態遷移**:

| 状態 | アイコン | 説明 |
|------|---------|------|
| アクティブ (通常) | `timer` (SF Symbol) | 通常の作業中 |
| アクティブ (警告) | `timer.circle.fill` (オレンジ) | 連続使用が `workDurationMinutes - 10` 分以上（デフォルト40分） |
| 休憩中 | `cup.and.saucer.fill` (グリーン) | 休憩タイマー動作中 |
| 非アクティブ | `moon.zzz` (グレー) | 5分以上入力なし |
| 停止 | `stop.circle` (グレー) | 監視停止中 |

**ポップオーバー表示内容**:
- 現在の連続使用時間（プログレスバー付き）
- 次の休憩までの残り時間
- 本日の統計（総作業時間、休憩回数、最長連続使用時間）
- 「一時停止/再開」ボタン
- 「設定」ボタン
- 「終了」ボタン

#### FR-005: セッションデータ永続化

| 項目 | 内容 |
|------|------|
| 概要 | 作業セッションと日次サマリーを永続化する |
| 永続化方式 | SwiftData |
| 実装クラス | `Session`, `DailySummary`, `SessionManager` |

**データモデル**: → セクション3で詳述

#### FR-006: 基本設定画面

| 項目 | 内容 |
|------|------|
| 概要 | ユーザーがアプリの動作パラメータをカスタマイズできる |
| 実装方式 | SwiftUI Settings シーン (`@AppStorage`) |
| 実装クラス | `SettingsView`, `AppSettings` |

**設定項目**:

| パラメータ | デフォルト値 | 範囲 | 説明 |
|-----------|------------|------|------|
| `workDurationMinutes` | 50 | 20-120 | 休憩通知までの連続作業時間 (分) |
| `breakDurationMinutes` | 10 | 5-30 | 推奨休憩時間 (分) |
| `inactivityThresholdMinutes` | 5 | 1-15 | 非アクティブ判定閾値 (分) |
| `breakResetThresholdMinutes` | 10 | 5-30 | 休憩リセット判定閾値 (分) |
| `snoozeDurationMinutes` | 5 | 1-15 | スヌーズ時間 (分) |
| `launchAtLogin` | false | - | ログイン時に自動起動 |
| `soundEnabled` | true | - | 通知音の有効/無効 |

> Note: `hasCompletedOnboarding` (Bool, デフォルト: false) は内部管理用フラグとして `@AppStorage` に保存する。初回セットアップ完了時に `true` に設定し、2回目以降の起動でオンボーディングをスキップする。ユーザー向け設定画面には表示しない。

#### FR-007: 初回セットアップ

| 項目 | 内容 |
|------|------|
| 概要 | 初回起動時に必要な権限をリクエストし、基本設定をガイドする |
| 実装クラス | `OnboardingView`, `PermissionManager` |

**フロー**:
1. ウェルカム画面（アプリの説明）
2. アクセシビリティ権限リクエスト
   - 権限の必要性を説明
   - 「システム環境設定を開く」ボタン
   - 権限付与の確認（ポーリングで検知）
3. 通知権限リクエスト (`UNUserNotificationCenter.requestAuthorization`)
4. セットアップ完了画面

### 2.2 Phase 2 (将来)

- **FR-008**: 日次/週次レポート画面（グラフ表示）
- **FR-009**: ポモドーロタイマーモード
- **FR-010**: カスタム休憩アクティビティ提案（ストレッチ動画リンクなど）
- **FR-011**: データエクスポート (CSV/JSON)

### 2.3 Phase 3 (将来)

- **FR-012**: ショートカットアプリ連携
- **FR-013**: ヘルスケア連携（Apple Health 経由でスタンド時間を記録）
- **FR-014**: ウィジェット対応

### 2.4 スコープ外

- iOS / iPadOS / watchOS 対応
- クラウド同期
- 複数デバイス間の連携
- アクティビティの内容（使用アプリ名など）の記録
- スクリーンタイムとの連携

---

## 3. データモデル

### 3.1 Session

```swift
@Model
final class Session {
    var id: UUID
    var startTime: Date
    var endTime: Date?
    var activeSeconds: Int        // 実際のアクティブ時間（秒）
    var inactiveSeconds: Int      // 非アクティブ時間（秒）
    var breaksTaken: Int          // 休憩回数
    var longestStreakSeconds: Int  // 最長連続アクティブ時間（秒）
    var isActive: Bool            // 現在進行中かどうか

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

### 3.2 DailySummary

```swift
@Model
final class DailySummary {
    @Attribute(.unique) var date: String  // "yyyy-MM-dd" 形式
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

### 3.3 ER図

```
┌─────────────┐       ┌──────────────────┐
│   Session    │       │  DailySummary    │
├─────────────┤       ├──────────────────┤
│ id (PK)     │       │ date (PK, UK)    │
│ startTime   │  N:1  │ totalActive...   │
│ endTime     │──────▶│ totalInactive... │
│ active...   │       │ totalBreaks      │
│ inactive... │       │ longestStreak... │
│ breaksTaken │       │ sessionCount     │
│ longestS... │       │ firstSession...  │
│ isActive    │       │ lastSession...   │
└─────────────┘       └──────────────────┘
```

> Note: Session と DailySummary は明示的なリレーションを持たず、`startTime` の日付で論理的に紐づく。日次サマリーはセッション終了時に集計・更新される。

---

## 4. 状態遷移図

```
                    ┌─────────┐
                    │  停止   │
                    │ Stopped │
                    └────┬────┘
                         │ ユーザーが開始
                         ▼
┌──────────────────────────────────────────────────────────┐
│                                                          │
│    ┌──────────┐    5分入力なし    ┌─────────────┐         │
│    │ アクティブ │───────────────▶│ 非アクティブ  │         │
│    │  Active   │◀───────────────│  Inactive    │         │
│    └─────┬────┘  入力検知(10分未満)└──────┬──────┘         │
│          │                               │               │
│          │ 50分連続                       │ 入力検知       │
│          │ 使用到達                       │ (離席≥10分)    │
│          │ →通知送信                      │               │
│          ▼                               ▼               │
│    ┌──────────────┐              ┌──────────┐            │
│    │ 通知送信済み    │              │ アクティブ │            │
│    │ ReminderSent  │              │  Active   │           │
│    └───┬─────┬────┘              │(ストリーク │            │
│        │     │                   │ リセット)  │            │
│ 「休憩」│     │「スヌーズ」        └──────────┘            │
│        ▼     ▼                                           │
│  ┌────────┐  ┌──────────┐                                │
│  │ 休憩中  │  │ アクティブ │                                │
│  │ Break   │  │ (スヌーズ後│                                │
│  └───┬────┘  │  再カウント)│                                │
│      │       └──────────┘                                │
│      │ 休憩タイマー完了 or                                  │
│      │ PC操作再開(閾値以上の休憩時間経過時のみカウント)       │
│      ▼                                                   │
│  ┌──────────┐                                            │
│  │ アクティブ │  (連続使用時間リセット)                       │
│  │  Active   │                                           │
│  └──────────┘                                            │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

> Note: 状態管理は実装上2つのサービスに分散される:
> - `ActivityMonitorService.ActivityState`: `.active` / `.inactive` (PC操作レベルの状態)
> - `BreakReminderService.BreakState`: `.working` / `.reminderSent` / `.onBreak` (休憩管理レベルの状態)
> - `Stopped` 状態は `isTracking: Bool` フラグで管理
>
> 「暗黙の休憩」パス: 10分以上の非アクティブ後に入力再開 → Break 状態を経由せず、直接 Active に遷移しストリークをリセット。`breaksTaken` をインクリメントして休憩としてカウントする。

**状態定義**:

| 状態 | 説明 | 遷移条件 (入) | 遷移条件 (出) |
|------|------|-------------|-------------|
| Stopped | 監視停止中 | ユーザーが一時停止 | ユーザーが再開 |
| Active | PC使用中 | 入力イベント検知 | 5分入力なし / ロック・スリープ |
| Inactive | 離席中 | 5分入力なし / ロック・スリープ | 入力再開 (10分未満→継続, 10分以上→暗黙リセット) |
| ReminderSent | 通知送信済み | 連続使用が `workDurationMinutes` に到達 | 「休憩する」→ Break / 「スヌーズ」→ Active (再カウント) |
| Break | 明示的休憩中 | 通知で「休憩する」選択 | 休憩タイマー完了 / PC操作再開 |

---

## 5. 非機能要件

### 5.1 パフォーマンス

| 指標 | 目標値 |
|------|--------|
| CPU使用率 (アイドル時) | < 0.5% |
| CPU使用率 (アクティブ監視時) | < 1.0% |
| メモリ使用量 | < 30MB |
| バッテリー影響 | Energy Impact: Low (Activity Monitor基準) |
| 起動時間 | < 2秒 |
| ポーリング間隔 | 10秒 (設定可能にしない) |

### 5.2 プライバシー

- **入力内容は一切記録しない**: キー入力の内容、マウス座標は保存しない
- **タイムスタンプのみ記録**: 最終入力時刻のみを一時保持
- **ローカルデータのみ**: ネットワーク通信は行わない
- **データはアプリ内に閉じる**: サンドボックス内のSwiftDataストアのみ使用

### 5.3 必要な権限

| 権限 | 用途 | 必須 |
|------|------|------|
| アクセシビリティ | CGEvent tap によるグローバル入力検知 | はい |
| 通知 | 休憩リマインダーの表示 | はい（なくても動作するが通知不可） |

### 5.4 アクセシビリティ

- VoiceOver 対応: 全UI要素にアクセシビリティラベルを設定
- Dynamic Type: テキストサイズの変更に対応
- 高コントラストモード対応
- キーボードナビゲーション対応（ポップオーバー内）

---

## 6. ユーザーフロー

### 6.1 初回起動フロー

```
アプリ起動
  │
  ▼
ウェルカム画面表示
  │
  ▼
アクセシビリティ権限説明
  │
  ├─▶ 「システム環境設定を開く」ボタン押下
  │     │
  │     ▼
  │   システム環境設定で権限付与
  │     │
  │     ▼ (ポーリングで検知)
  │   権限付与確認
  │
  ▼
通知権限リクエスト
  │
  ├─▶ 許可 → セットアップ完了画面
  │
  └─▶ 拒否 → 「通知なしで続行」説明 → セットアップ完了画面
       │
       ▼
    メニューバーに常駐開始
    自動監視開始
```

### 6.2 日常使用フロー

```
PC起動/ログイン
  │
  ▼ (自動起動設定時)
アプリ起動 → メニューバーに常駐
  │
  ▼
キーボード/マウス入力を検知
  │
  ▼
セッション開始 (自動)
  │
  ├─▶ 50分連続使用
  │     │
  │     ▼
  │   休憩通知表示
  │     │
  │     ├─▶ 「休憩する」→ 休憩タイマー開始
  │     │     │
  │     │     ▼
  │     │   10分後: 復帰通知
  │     │
  │     └─▶ 「5分後に再通知」→ スヌーズ
  │
  ├─▶ 5分間入力なし → 非アクティブ遷移
  │     │
  │     ├─▶ 入力再開 (10分未満) → アクティブ復帰 (継続)
  │     └─▶ 10分以上経過 → 休憩としてリセット
  │
  └─▶ ロック/スリープ → 非アクティブ遷移 (同上)
```

### 6.3 メニューバー操作フロー

```
メニューバーアイコンクリック
  │
  ▼
ポップオーバー表示
  │
  ├─▶ 現在の状態確認 (連続使用時間、休憩残り時間)
  │
  ├─▶ 本日の統計確認
  │
  ├─▶ 「一時停止」→ 監視停止
  │
  ├─▶ 「設定」→ 設定画面表示
  │
  └─▶ 「終了」→ アプリ終了
```
