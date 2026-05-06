# 長時間稼働時のリソース消費リスク修正 設計書

作成日：2026-05-06
対象：`Elapsed.app`（macOS メニューバーアプリ）

## ゴール

- 長時間稼働時の CPU スパイク・メモリ増加を抑制する
- ユーザーから見える挙動（更新頻度・表示内容）は原則維持する
- 既存テストを壊さず、各修正を独立検証可能にする

## Non-goals

- メニューバー更新頻度の延長（Q2-C：秒精度を維持）
- 古いデータの自動削除（Q4-A：ストア成長は許容、predicate で必要範囲のみロード）
- SwiftData スキーマ変更（マイグレーション回避）

## 対象リスク（高 + 中リスク = 7 件）

| # | リスク | 対処方針 |
|---|---|---|
| 1 | NSImage を毎秒再生成 | キャッシュ層を追加（icon + title をキー） |
| 2 | SwiftData を毎秒ミューテート | 終了時のみ `session.activeSeconds` を確定書き込み |
| 3 | `@Query` の全件ロード | `predicate` で範囲制限 |
| 4 | `StatisticsView.buckets` の毎秒再計算 | #2 解消で連鎖発火が消える + 結果メモ化 |
| 5 | Timer tolerance 0.05 | 0.1 に微調整 |
| 6 | `checkAndNotify` 二重呼び出し | アイコン更新側を削除し、セッションティック経由に集約 |
| 7 | `BarChartView.DataPoint` の毎回 UUID 発行 | `label` ベースの安定 ID に変更 |

## アーキテクチャ変更詳細

### 1. NSImage キャッシュ層

`MenuBarView.swift` に `MenuBarImageCache` クラスを追加し、`MenuBarLabel` で `static let cache` として保持する。キャッシュキーは `(icon, title)`、上限 16 エントリで超過時は全クリア。`@MainActor` 上で動作するため lock 不要。

### 2. SwiftData 書き込み戦略変更

`SessionManager.updateSession()` から `session.activeSeconds = currentSessionSeconds` を削除する。`endCurrentSession()` の既存ロジックが `endTime - startTime` から `activeSeconds` を確定するため、UI 表示と保存値の整合性は維持される。

副作用対応：`PopoverView.sessionRow` で `session.isActive == true` の場合は `sessionManager.currentSessionSeconds` を表示するよう分岐を追加する。

### 3. `@Query` の範囲制限

- `PopoverView`：当日 0 時以降の `Session` のみ取得（`init` で `startOfDay` を計算して `predicate` 構築）
- `SessionDetailView`：直近 30 日のみ取得
- `StatisticsView`：`@Query` を廃止し `ModelContext.fetch` ベースに変更。期間切替時に `FetchDescriptor` で必要範囲のみ取得し、`@State private var buckets: [Bucket]` にキャッシュ

### 4. Timer tolerance 微調整

- `AppCoordinator.iconUpdateTimer.tolerance`：`0.05` → `0.1`
- `SessionManager.updateTimer.tolerance`：`0.5` → `0.5`（変更なし）

### 5. `checkAndNotify` 重複削除

`AppCoordinator.updateMenuBarIcon` 内の `checkAndNotify` 呼び出しを削除する。`SessionManager` に `var onSessionTick: ((Int) -> Void)?` を追加し、`updateSession()` 内で発火する。`AppCoordinator` で接続して `BreakReminderService.checkAndNotify()` をトリガーする。

### 6. `BarChartView.DataPoint` の安定 ID 化

`UUID()` を廃止し、`var id: String { label }` に変更する。同一チャート内で `label` がユニークであることは `groupSessions` の現状実装で担保されている。

## テスト方針

### 既存テストへの影響

- `SessionManagerTests.testEndSessionUsesLastUpdateTimeExcludingSleep`：影響なし（`endCurrentSession` で `endTime - startTime` から計算するため）
- `SessionManagerTests.testSessionSecondsAdvancesWithClock`：影響なし（`currentSessionSeconds` のみ検証）
- `MenuBarIconProviderTests`：影響なし（純粋関数）

### 追加テスト

- `SessionManagerTests`：`updateSession` 後に `session.activeSeconds == 0` が保たれることを確認（毎秒書き込まないことの検証）
- `SessionManagerTests`：`onSessionTick` コールバックの発火確認
- `MenuBarImageCacheTests`：同一キーで同一インスタンス、上限超過時の挙動

## 実装順序

1. SessionManager の書き込み戦略変更 + `onSessionTick` 追加
2. AppCoordinator の `checkAndNotify` 経路差し替え + Timer tolerance 調整
3. NSImage キャッシュ層追加
4. `@Query` の predicate 化（PopoverView, SessionDetailView）
5. StatisticsView の `ModelContext.fetch` ベース化
6. PopoverView の進行中セッション表示分岐
7. BarChartView.DataPoint の安定 ID 化
8. テスト追加 + 全テスト実行

## ロールバック方針

各変更は独立しているため、問題発生時は該当コミットのみ revert で対応可能。

## 確認済み事項

- Q1：スコープ B（高 + 中リスク 7 件）
- Q2：C（メニューバー更新頻度は 1 秒間隔維持、tolerance のみ微調整）
- Q3：A（セッション終了時のみ書き込み）
- Q4：A（`predicate` のみで範囲制限、データ自動削除は実装しない）
