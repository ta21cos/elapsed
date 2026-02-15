# ta21cos Time Tracker - テスト計画

## 1. テスト戦略

### 1.1 テストレベル

| レベル | 対象 | ツール | 自動化 |
|--------|------|--------|--------|
| Unit Test | 個々のサービス、ロジック | XCTest | 自動 |
| Integration Test | サービス間連携、SwiftData | XCTest | 自動 |
| Manual Test | UI操作、通知、権限フロー | チェックリスト | 手動 |

### 1.2 テスト方針

- **依存性注入**: 各サービスはプロトコル経由で依存を受け取り、テスト時にモック差し替え可能にする
- **時間依存のテスト**: `Date` の生成を注入可能にし、テストで固定日時を使用
- **非同期テスト**: `async/await` を使用するテストは `XCTestExpectation` または Swift Concurrency のテスト機能を活用

### 1.3 テスト用プロトコル

```swift
// 時間の注入用
protocol DateProvider {
    var now: Date { get }
}

struct RealDateProvider: DateProvider {
    var now: Date { Date() }
}

struct MockDateProvider: DateProvider {
    var fixedDate: Date
    var now: Date { fixedDate }
}

// 入力監視のモック用
protocol InputEventMonitoring {
    var lastInputTime: Date { get }
    func start()
    func stop()
}

// 通知サービスのモック用
protocol NotificationSending {
    func sendBreakReminder(streakMinutes: Int)
    func sendReturnNotification()
    func cancelPendingNotifications()
}
```

---

## 2. 機能別テストケース

### 2.1 アクティビティ検知 (FR-001)

**対象クラス**: `InputEventMonitor`, `ActivityMonitorService`

#### Unit Tests

| ID | テスト名 | 内容 | 期待結果 |
|----|---------|------|---------|
| ACT-001 | イベント受信でタイムスタンプ更新 | モックイベントを発火し、`lastInputTime` を確認 | `lastInputTime` が更新される |
| ACT-002 | 非アクティブ判定 (5分超過) | `lastInputTime` を6分前に設定し、ポーリング実行 | `state` が `.inactive` に遷移 |
| ACT-003 | アクティブ維持 (5分未満) | `lastInputTime` を3分前に設定し、ポーリング実行 | `state` が `.active` を維持 |
| ACT-004 | 非アクティブからアクティブ復帰 | inactive 状態で `lastInputTime` を現在時刻に更新後、ポーリング実行 | `state` が `.active` に遷移 |
| ACT-005 | 設定値の反映 | `inactivityThresholdMinutes` を10分に変更し、7分後にポーリング | `state` が `.active` を維持 |
| ACT-006 | 開始/停止 | `start()` → `stop()` の順で呼び出し | リソースが解放され、ポーリングが停止 |

#### Integration Tests

| ID | テスト名 | 内容 | 期待結果 |
|----|---------|------|---------|
| ACT-I01 | ActivityMonitorService と InputEventMonitor の連携 | InputEventMonitor のモックを注入し、状態遷移を確認 | 状態遷移コールバックが正しく呼ばれる |
| ACT-I02 | ActivityMonitorService と AppSettings の連携 | 設定変更後、閾値が即座に反映される | 新しい閾値で判定が行われる |

---

### 2.2 セッション管理 (FR-005)

**対象クラス**: `SessionManager`

#### Unit Tests

| ID | テスト名 | 内容 | 期待結果 |
|----|---------|------|---------|
| SES-001 | セッション開始 | `handleActivityChange(.active)` を呼び出し | 新しい `Session` が作成され、`isActive == true` |
| SES-002 | セッション終了 | `endCurrentSession()` を呼び出し | `endTime` が設定され、`isActive == false` |
| SES-003 | 連続使用時間のカウント | active 状態で10秒経過 | `currentStreakSeconds` が約10 |
| SES-004 | 短い非アクティブ後の復帰 | 3分の非アクティブ後にactive復帰 | 連続使用時間が継続（リセットされない） |
| SES-005 | 長い非アクティブ後の復帰 (休憩リセット) | 15分の非アクティブ後にactive復帰 | 連続使用時間がリセット、`breaksTaken` が+1 |
| SES-006 | 最長連続時間の記録 | 30分連続使用後に非アクティブ遷移 | `longestStreakSeconds` が約1800 |
| SES-007 | DailySummary の作成 | 本日のサマリーが存在しない状態で起動 | 新しい `DailySummary` が自動作成される |
| SES-008 | DailySummary の更新 | セッション終了時 | `totalActiveSeconds`, `totalBreaks` 等が正しく加算 |
| SES-009 | 複数セッション | 2つのセッションを開始・終了 | `sessionCount` が2、各値が累積 |
| SES-010 | アプリ再起動後の復元 | セッション作成後、新しい `SessionManager` を生成 | SwiftData から既存セッションが読み取れる |

#### Integration Tests

| ID | テスト名 | 内容 | 期待結果 |
|----|---------|------|---------|
| SES-I01 | ActivityMonitorService → SessionManager | アクティブ/非アクティブの遷移をシミュレーション | セッションが正しく管理される |
| SES-I02 | SwiftData 永続化 | セッション作成後、ModelContext を再生成して取得 | データが永続化されている |

---

### 2.3 スクリーンロック / スリープ検知 (FR-002)

**対象クラス**: `SystemStateMonitor`, `ActivityMonitorService`

#### Unit Tests

| ID | テスト名 | 内容 | 期待結果 |
|----|---------|------|---------|
| SYS-001 | ロック検知 | `com.apple.screenIsLocked` 通知を発火 | `lastEvent == .screenLocked`、コールバック呼び出し |
| SYS-002 | アンロック検知 | `com.apple.screenIsUnlocked` 通知を発火 | `lastEvent == .screenUnlocked`、コールバック呼び出し |
| SYS-003 | スリープ検知 | `willSleepNotification` を発火 | `lastEvent == .systemSleep`、コールバック呼び出し |
| SYS-004 | ウェイク検知 | `didWakeNotification` を発火 | `lastEvent == .systemWake`、コールバック呼び出し |
| SYS-005 | ロック時の非アクティブ遷移 | ロック通知を送信 | `ActivityMonitorService.state == .inactive` |
| SYS-006 | アンロック後の短時間復帰 | ロック→5分後アンロック→入力 | 連続使用時間が継続 |
| SYS-007 | アンロック後の長時間復帰 | ロック→15分後アンロック→入力 | 連続使用時間がリセット、休憩カウント+1 |

#### Integration Tests

| ID | テスト名 | 内容 | 期待結果 |
|----|---------|------|---------|
| SYS-I01 | SystemStateMonitor → ActivityMonitorService → SessionManager | ロック→アンロックのフローを通しで確認 | セッションの非アクティブ/復帰が正しく処理 |

---

### 2.4 休憩リマインダー通知 (FR-003)

**対象クラス**: `BreakReminderService`, `NotificationService`

#### Unit Tests

| ID | テスト名 | 内容 | 期待結果 |
|----|---------|------|---------|
| BRK-001 | 50分到達で通知 | `currentStreakSeconds` を50*60に設定し `checkAndNotify()` | `sendBreakReminder` が呼ばれる |
| BRK-002 | 49分では通知しない | `currentStreakSeconds` を49*60に設定し `checkAndNotify()` | `sendBreakReminder` が呼ばれない |
| BRK-003 | 「休憩する」アクション | `startBreak()` を呼び出し | `breakState == .onBreak`、タイマー開始 |
| BRK-004 | 休憩タイマー完了 | `startBreak()` 後、タイマー満了まで待機 | `endBreak()` が呼ばれ、復帰通知が送信 |
| BRK-005 | スヌーズ | `snooze()` を呼び出し | `breakState == .working`、5分後に再通知 |
| BRK-006 | 設定変更の反映 | `workDurationMinutes` を30に変更 | 30分で通知が送信される |
| BRK-007 | timeUntilBreak の計算 | `currentStreakSeconds = 1800` (30分)、`workDuration = 50` | `timeUntilBreak == 1200` (20分) |
| BRK-008 | 休憩中は再通知しない | `breakState == .onBreak` 中に `checkAndNotify()` | 通知が送信されない |
| BRK-009 | 復帰通知の内容 | `endBreak(countAsBreak: true)` を呼び出し | 復帰通知のタイトル/本文が正しい |
| BRK-010 | PC操作による早期終了 (閾値未満) | 休憩開始3分後に `endBreak()` (閾値10分) | 休憩としてカウントされない、復帰通知なし |
| BRK-011 | PC操作による早期終了 (閾値以上) | 休憩開始12分後に `endBreak()` (閾値10分) | 休憩としてカウントされる、復帰通知あり |
| BRK-012 | スヌーズボタンテキスト | `snoozeDurationMinutes = 10` で通知カテゴリ登録 | ボタンテキストが「10分後に再通知」 |

#### Integration Tests

| ID | テスト名 | 内容 | 期待結果 |
|----|---------|------|---------|
| BRK-I01 | SessionManager → BreakReminderService → NotificationService | 50分連続使用のフローを通しで確認 | 通知が送信され、アクション処理が正しい |
| BRK-I02 | 通知アクション → 休憩 → 復帰 | 通知の「休憩する」→タイマー→復帰通知 | 全フローが正しく動作 |

---

### 2.5 メニューバーUI (FR-004)

**対象クラス**: `MenuBarIconProvider`, `PopoverView`, `StatsView`

#### Unit Tests

| ID | テスト名 | 内容 | 期待結果 |
|----|---------|------|---------|
| UI-001 | アイコン: アクティブ通常 | `active`, `working`, streak < `workDuration - 10`min (デフォルト40min) | `"timer"` |
| UI-002 | アイコン: アクティブ警告 | `active`, `working`, streak ≥ `workDuration - 10`min (デフォルト40min) | `"timer.circle.fill"` |
| UI-002a | 警告閾値の動的計算 | `workDurationMinutes = 30` のとき | 閾値が20分 (`warningThresholdSeconds` = 1200) |
| UI-003 | アイコン: 休憩中 | `breakState == .onBreak` | `"cup.and.saucer.fill"` |
| UI-004 | アイコン: 非アクティブ | `inactive` | `"moon.zzz"` |
| UI-005 | アイコン: 停止 | `isTracking == false` | `"stop.circle"` |
| UI-006 | 時間フォーマット | 3661秒 | `"1時間1分"` |
| UI-007 | 時間フォーマット (分のみ) | 300秒 | `"5分"` |
| UI-008 | 時間フォーマット (0分) | 0秒 | `"0分"` |

#### Manual Tests

| ID | テスト名 | 手順 | 期待結果 |
|----|---------|------|---------|
| UI-M01 | ポップオーバー表示 | メニューバーアイコンをクリック | ポップオーバーが表示され、現在の状態が正しい |
| UI-M02 | プログレスバー | 作業中にポップオーバーを確認 | プログレスバーが連続使用時間に応じて進行 |
| UI-M03 | 統計表示 | 数回の作業/休憩後にポップオーバーを確認 | 本日の統計が正しく表示 |
| UI-M04 | 一時停止/再開 | 一時停止ボタンをクリック → 再開 | 監視が停止/再開される |
| UI-M05 | 設定画面遷移 | 設定ボタンをクリック | 設定画面が表示される |
| UI-M06 | アプリ終了 | 終了ボタンをクリック | アプリが正常終了 |
| UI-M07 | 休憩カウントダウン | 休憩中にポップオーバーを確認 | カウントダウンタイマーが動作 |

---

### 2.6 データ永続化 (FR-005)

**対象クラス**: `Session`, `DailySummary`, `SessionManager`

#### Unit Tests

| ID | テスト名 | 内容 | 期待結果 |
|----|---------|------|---------|
| DAT-001 | Session 保存 | Session を作成し ModelContext に保存 | エラーなく保存される |
| DAT-002 | Session 読出 | 保存した Session を FetchDescriptor で取得 | 全フィールドが一致 |
| DAT-003 | DailySummary の一意制約 | 同じ日付の DailySummary を2つ作成 | 2つ目がエラーまたは既存を更新 |
| DAT-004 | アプリ再起動シミュレーション | ModelContainer を再生成し、データ取得 | 前回のデータが残っている |
| DAT-005 | 日次サマリー集計 | 複数セッションの後に DailySummary を確認 | 各フィールドが正しく集計 |
| DAT-006 | dateString フォーマット | 2024-03-15 12:30:00 を変換 | `"2024-03-15"` |

#### Integration Tests

| ID | テスト名 | 内容 | 期待結果 |
|----|---------|------|---------|
| DAT-I01 | セッション完全ライフサイクル | 開始→作業→非アクティブ→復帰→終了 | Session と DailySummary が正しく更新 |
| DAT-I02 | SwiftData ModelContainer 共有 | App と Settings で同じ Container を参照 | データの一貫性が保たれる |

---

### 2.7 設定 (FR-006)

**対象クラス**: `AppSettings`, `SettingsView`

#### Unit Tests

| ID | テスト名 | 内容 | 期待結果 |
|----|---------|------|---------|
| SET-001 | デフォルト値 | 初期状態で各設定値を確認 | 仕様通りのデフォルト値 |
| SET-002 | workDurationMinutes 範囲 | 19, 20, 120, 121 を設定 | 20-120 の範囲内のみ有効 |
| SET-003 | 変更の永続化 | 設定変更後、AppSettings を再生成 | 変更が UserDefaults に保存されている |
| SET-004 | 設定変更の即時反映 | `workDurationMinutes` を変更 | `BreakReminderService` が新しい値で判定 |

#### Manual Tests

| ID | テスト名 | 手順 | 期待結果 |
|----|---------|------|---------|
| SET-M01 | 設定画面の表示 | ポップオーバーから設定を開く | 全設定項目が表示される |
| SET-M02 | Stepper 操作 | 作業時間の Stepper を操作 | 値が5分刻みで増減 |
| SET-M03 | 自動起動設定 | 「ログイン時自動起動」を ON | ログイン項目に追加される |

---

### 2.8 初回セットアップ (FR-007)

**対象クラス**: `OnboardingView`, `PermissionManager`

#### Unit Tests

| ID | テスト名 | 内容 | 期待結果 |
|----|---------|------|---------|
| ONB-001 | 権限チェック (未付与) | アクセシビリティ権限なしで確認 | `false` を返す |
| ONB-002 | 権限チェック (付与済み) | アクセシビリティ権限ありで確認 | `true` を返す |
| ONB-003 | onboarding 完了フラグ | セットアップ完了後 | `hasCompletedOnboarding == true` |
| ONB-004 | 2回目以降の起動 | `hasCompletedOnboarding == true` で起動 | オンボーディングが表示されない |

#### Manual Tests

| ID | テスト名 | 手順 | 期待結果 |
|----|---------|------|---------|
| ONB-M01 | 初回起動フロー | アプリを初回起動 | ウェルカム画面が表示される |
| ONB-M02 | アクセシビリティ権限リクエスト | 「システム環境設定を開く」ボタンをクリック | システム環境設定が開く |
| ONB-M03 | 権限付与の検知 | システム環境設定で権限を付与 | 自動的に次のステップに進む |
| ONB-M04 | 通知権限許可 | 通知権限ダイアログで「許可」 | セットアップ完了画面に進む |
| ONB-M05 | 通知権限拒否 | 通知権限ダイアログで「拒否」 | 「通知なしで続行」説明後、完了画面に進む |

---

## 3. エッジケース

### 3.1 時間関連

| ID | シナリオ | テスト内容 | 期待結果 |
|----|---------|----------|---------|
| EDGE-001 | 深夜跨ぎ | 23:50にセッション開始、0:10に確認 | 前日のセッション終了、新日のサマリー作成 |
| EDGE-002 | 長時間スリープ後 | 8時間スリープ後にウェイク | 前セッション終了、休憩リセット、新セッション開始準備 |
| EDGE-003 | 非常に短い操作 | 1秒だけ入力後に離席 | セッションは作成されるが、最小限のデータ |
| EDGE-004 | 日付変更直後の操作 | 0:00:01に入力 | 新日のサマリーが作成される |
| EDGE-005 | 連続24時間使用 | 24時間休憩なしで使用 | セッションが日付をまたいで正しく管理 |

### 3.2 権限関連

| ID | シナリオ | テスト内容 | 期待結果 |
|----|---------|----------|---------|
| EDGE-006 | アクセシビリティ権限なしで起動 | 権限なしでアプリ起動 | オンボーディングが表示され、権限リクエスト |
| EDGE-007 | 権限を後から取り消し | 使用中にシステム環境設定で権限を無効化 | CGEvent tap が無効化、ユーザーに通知 |
| EDGE-008 | 通知権限なしで使用 | 通知権限を拒否して使用 | 通知以外の機能は正常動作、アイコン変化で状態表示 |

### 3.3 システム関連

| ID | シナリオ | テスト内容 | 期待結果 |
|----|---------|----------|---------|
| EDGE-009 | アプリ強制終了後の復帰 | kill -9 後に再起動 | 前セッションが `isActive == true` のまま残る → 起動時にクリーンアップ |
| EDGE-010 | メモリ不足時 | 低メモリ状態での動作 | Timer が正常動作し、データ損失なし |
| EDGE-011 | 複数ディスプレイ | 外部ディスプレイ接続/切断 | メニューバーアイコンが正しく表示 |
| EDGE-012 | クラムシェルモード | MacBook を閉じて外部ディスプレイ使用 | スリープせず正常監視 |

### 3.4 データ関連

| ID | シナリオ | テスト内容 | 期待結果 |
|----|---------|----------|---------|
| EDGE-013 | SwiftData マイグレーション | モデル変更後の起動 | マイグレーションが成功し、データが保持 |
| EDGE-014 | データベース破損 | ストアファイルを破損させて起動 | エラーハンドリング、新しいストア作成 |
| EDGE-015 | 大量データ | 365日分のセッションデータ | パフォーマンスが劣化しない |

---

## 4. パフォーマンステスト

### 4.1 CPU使用率

| ID | シナリオ | 測定方法 | 目標値 |
|----|---------|---------|--------|
| PERF-001 | アイドル時 | Activity Monitor で1時間計測 | < 0.5% |
| PERF-002 | アクティブ監視時 | 通常操作中に Activity Monitor で1時間計測 | < 1.0% |
| PERF-003 | ポップオーバー表示中 | ポップオーバーを開いた状態で計測 | < 2.0% |

### 4.2 メモリ使用量

| ID | シナリオ | 測定方法 | 目標値 |
|----|---------|---------|--------|
| PERF-004 | 起動直後 | Activity Monitor で確認 | < 20MB |
| PERF-005 | 8時間使用後 | 1日の使用後に確認 | < 30MB (メモリリークなし) |
| PERF-006 | 大量データ保持 | 1年分のデータを事前投入 | < 50MB |

### 4.3 バッテリー影響

| ID | シナリオ | 測定方法 | 目標値 |
|----|---------|---------|--------|
| PERF-007 | 通常使用 | Activity Monitor の Energy Impact | Low |
| PERF-008 | バックグラウンド | 12/h Average Energy Impact | < 5 |

### 4.4 起動時間

| ID | シナリオ | 測定方法 | 目標値 |
|----|---------|---------|--------|
| PERF-009 | コールドスタート | アプリ起動〜メニューバーアイコン表示 | < 2秒 |
| PERF-010 | データあり起動 | 1年分データで起動 | < 3秒 |

---

## 5. 手動テストチェックリスト

### 5.1 初回セットアップ

- [ ] アプリ初回起動でウェルカム画面が表示される
- [ ] アクセシビリティ権限の説明が分かりやすい
- [ ] 「システム環境設定を開く」ボタンが正しく動作する
- [ ] 権限付与後、自動的に次のステップに進む
- [ ] 通知権限ダイアログが表示される
- [ ] 全ステップ完了後、メニューバーに常駐開始
- [ ] 2回目の起動ではオンボーディングが表示されない

### 5.2 日常使用

- [ ] メニューバーにアイコンが表示される
- [ ] Dock にアプリが表示されない（LSUIElement）
- [ ] キーボード入力でセッションが自動開始
- [ ] マウス操作でセッションが自動開始
- [ ] 5分間操作なしでアイコンが非アクティブ表示に変わる
- [ ] 操作再開でアイコンがアクティブ表示に戻る
- [ ] スクリーンロックでアイコンが非アクティブ表示に変わる
- [ ] アンロック後、操作でアクティブに復帰
- [ ] 50分連続使用で通知が表示される
- [ ] 通知の「休憩する」ボタンが動作する
- [ ] 通知の「5分後に再通知」ボタンが動作する
- [ ] 休憩中はアイコンが休憩表示に変わる
- [ ] 休憩タイマー完了で復帰通知が表示される
- [ ] 10分以上の離席後、連続使用時間がリセットされる

### 5.3 ポップオーバー

- [ ] メニューバーアイコンクリックでポップオーバーが表示
- [ ] 現在の連続使用時間が正しく表示される
- [ ] プログレスバーが進捗を正しく反映
- [ ] 次の休憩までの残り時間が表示される
- [ ] 本日の統計が正しい（作業時間、休憩回数、最長連続、セッション数）
- [ ] 「一時停止」ボタンで監視が停止する
- [ ] 「再開」ボタンで監視が再開する
- [ ] 「設定」ボタンで設定画面が開く
- [ ] 「終了」ボタンでアプリが終了する
- [ ] 他の場所をクリックするとポップオーバーが閉じる

### 5.4 設定画面

- [ ] 設定画面が正しく表示される
- [ ] 「一般」タブと「タイミング」タブが切り替わる
- [ ] 作業時間の Stepper が20-120分の範囲で動作
- [ ] 休憩時間の Stepper が5-30分の範囲で動作
- [ ] 非アクティブ判定の Stepper が1-15分の範囲で動作
- [ ] ログイン時自動起動の Toggle が動作
- [ ] 通知音の Toggle が動作
- [ ] 設定変更が即座に反映される
- [ ] アプリ再起動後も設定が保持される

### 5.5 外観・UX

- [ ] ダークモードで正しく表示される
- [ ] ライトモードで正しく表示される
- [ ] VoiceOver でメニューバーアイコンが読み上げられる
- [ ] VoiceOver でポップオーバー内が操作できる
- [ ] テキストサイズ変更に対応（Dynamic Type）
- [ ] 高コントラストモードで正しく表示される

---

## 6. テスト実装の優先順位

### Phase 1 (MVP と同時)

1. `SessionManager` の Unit Tests (SES-001 〜 SES-010)
2. `BreakReminderService` の Unit Tests (BRK-001 〜 BRK-009)
3. `ActivityMonitorService` の Unit Tests (ACT-001 〜 ACT-006)
4. `MenuBarIconProvider` の Unit Tests (UI-001 〜 UI-008)
5. `AppSettings` の Unit Tests (SET-001 〜 SET-004)
6. 手動テストチェックリスト全項目

### Phase 2 (安定化)

1. Integration Tests 全項目
2. エッジケーステスト (EDGE-001 〜 EDGE-015)
3. パフォーマンステスト (PERF-001 〜 PERF-010)

---

## 7. テスト環境

### 7.1 必要環境

| 項目 | 要件 |
|------|------|
| macOS | 14 Sonoma 以上 |
| Xcode | 15.0 以上 |
| テストランナー | XCTest (Xcode 統合) |

### 7.2 テストデータ

- **日常テスト用**: 空のデータストアから開始
- **パフォーマンステスト用**: 365日分のセッションデータ（スクリプトで生成）
- **マイグレーションテスト用**: 旧スキーマのデータストアファイル

### 7.3 CI/CD (将来)

- GitHub Actions で Unit Test / Integration Test を自動実行
- macOS runner を使用
- テストカバレッジレポートの生成
