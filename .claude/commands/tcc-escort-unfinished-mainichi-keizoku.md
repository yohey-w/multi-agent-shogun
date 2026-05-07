---
name: tcc-escort-unfinished-mainichi-keizoku
description: |
  前日「毎日継続」タグ付き未完了タスクを当日「時間なしセクション」へ自動エスコート（2スキル呼出チェーン）

  引数:
    target_date (省略可・YYYY-MM-DD): エスコート対象日。省略時は実行日-1日（前日）。
    move_to_date (省略可・YYYY-MM-DD): 移動先日付。省略時は実行日（当日）。
argument-hint: "[target_date=YYYY-MM-DD] [move_to_date=YYYY-MM-DD]"
allowed-tools: ToolSearch, mcp__taskchute__get_tags, mcp__taskchute__get_taskchute, mcp__taskchute__search_documents, mcp__taskchute__get_nodes, Read, Write, Bash(bash scripts/generate_dashboard.sh), Bash(bash scripts/inbox_write.sh *)
---

# /tcc-escort-unfinished-mainichi-keizoku - 前日「毎日継続」タグ付き未完了タスクの当日エスコート（2スキル呼出チェーン）

前日の「毎日継続」タグ付き未完了タスクを当日の「時間なしセクション」へ自動移動する。既存2スキルを **改変せず** に逐次呼出するチェーンとして実装。

> **Version**: 1.0.0
> **Author**: gunshi (軍師)
> **Created**: 2026-05-08
> **Parent cmd**: cmd_1434
> **Wraps**: `/tcc-mainichi-keizoku-unfinished-list` + `/tcc-batch-move-date`

---

## 概要

殿の日次「毎日継続」タスク管理を2段階で自動化する:

| Step | 委譲先スキル | 役割 |
|------|------------|------|
| Phase 1 | `/tcc-mainichi-keizoku-unfinished-list` | target_date の「毎日継続」タグ付き未完了タスク一覧取得 |
| Phase 2 | `/tcc-batch-move-date` | Phase 1 取得タスク全件を move_to_date の「時間なしセクション」へ移動 |
| Phase 4 | （本スキル内で集約） | 2Phase の結果を1枚MD表で `dashboard_items/{caller_cmd}.yaml` に統合掲載 |

**設計原則:**
- **WET禁止**: 既存2スキルの内部ロジックを複製しない。必ず呼出（参照）形式
- **無確認・連続実行**: 各Phase間に殿確認プロンプトを挟まない（失敗時の手動復帰可能性は殿御達しで担保）
- **既存2スキル改変禁止**: 影響範囲拡大回避（cmd_1434 制約）
- **担当**: 足軽1専任（F030 — 全Phaseが TCC 操作のため）

---

## 引数

```
/tcc-escort-unfinished-mainichi-keizoku [target_date] [move_to_date]
```

| 引数 | 説明 | 必須 | デフォルト |
|------|------|------|----------|
| target_date | エスコート対象日（YYYY-MM-DD） | No | 実行日の **1日前**（前日） |
| move_to_date | Phase 2 の移動先日付（YYYY-MM-DD） | No | 実行日（当日） |

**例:**

```
/tcc-escort-unfinished-mainichi-keizoku
  → target_date=実行日-1日, move_to_date=実行日

/tcc-escort-unfinished-mainichi-keizoku 2026-05-07
  → target_date=2026-05-07, move_to_date=実行日

/tcc-escort-unfinished-mainichi-keizoku 2026-05-07 2026-05-08
  → target_date=2026-05-07, move_to_date=2026-05-08
```

---

## 前提条件

1. **担当**: 足軽1のみ（F030 — 配下2スキル全てが ash1 専任）
2. **MCP**: `taskchute`（tcc2-mcp）+ `playwright-tcc`（Phase 2 の UI 操作で使用）
3. **既存2スキル**が `.claude/commands/` 配下に存在し変更されていないこと
4. **既存2スキルの責務契約**:
   - `/tcc-mainichi-keizoku-unfinished-list` が `dashboard_items/{parent_cmd}.yaml` に「毎日継続」タグ付き未完了タスクMD表を書込む
   - `/tcc-batch-move-date` がタスク名マッチ方式で時間なしセクション経由移動に対応している

---

## 処理フロー

### Phase 0: 引数パース・cmd_id確定

1. `$ARGUMENTS` を空白区切りで分割し、`target_date` / `move_to_date` を取得
2. デフォルト計算（JST基準）:
   - `target_date` 未指定 → 実行日 - 1日（前日）
   - `move_to_date` 未指定 → 実行日（当日）
3. タスクYAMLの `parent_cmd` から `caller_cmd` を取得（例: `cmd_1500`）
   - skill_direct 実行（cmd起票なし）の場合は家老が事前にcmd_idを採番してSTKに登録すること（`/tcc-mainichi-keizoku-unfinished-list` 同条件）
4. ログ出力: 「target_date=YYYY-MM-DD / move_to_date=YYYY-MM-DD / caller_cmd={caller_cmd}」

### Phase 1: /tcc-mainichi-keizoku-unfinished-list 委譲

**委譲先**: `.claude/commands/tcc-mainichi-keizoku-unfinished-list.md` Phase 0〜Phase 1 を **そのスキル定義に従って** 実行する。

> ⚠️ **WET禁止（cmd_1434 制約）**
>
> 「毎日継続」タグ付き未完了タスク抽出ロジック（get_taskchute × search_documents クロスチェック・未完了フィルタ・MD表生成）を本スキル内で複製してはならない。必ず委譲先汎用スキルの仕様に従って実行する参照形式のみ使用すること。

呼出引数:
```
target_date={Phase0.target_date}
parent_cmd={caller_cmd}
```

**期待される副作用**:
- `tmp/tcc_task_by_tag_毎日継続_{target_date}.md` に証跡作成
- `dashboard_items/{caller_cmd}.yaml` に「毎日継続」タグ付き未完了タスクの単一MD表掲載

**結果取得**:
- 未完了件数 `N1` を取得（MD表の合計件数）
- タスク名一覧を Phase 2 引数として保持

**Phase 1 結果0件の場合**: Phase 2 をスキップして Phase 4 へ進む（移動対象なし）

### Phase 2: /tcc-batch-move-date 委譲

**委譲先**: `.claude/commands/tcc-batch-move-date.md` Phase 0.4〜Phase 3 を **そのスキル定義に従って** 実行する。

**呼出引数（フィルタ結果MD表のためタスク名マッチ方式必須）**:
```
{caller_cmd}:1-{N1}→{move_to_date_short}
```
- `{move_to_date_short}` 形式: `MM/DD`（既存スキル仕様準拠）
- 例: `cmd_1500:1-5→05/08`

**実行モード**:
- **Phase 0.5 判定**: フィルタ結果MD表のため **タスク名マッチ方式** を使用
- **無確認・連続実行**: 殿確認プロンプトなし（cmd_1434 制約・失敗時手動復帰前提）

**期待される副作用**:
- 対象タスク全件が `move_to_date` の時間なしセクションへ移動完了
- `dashboard_items/{caller_cmd}.yaml` MD表のステータス列が ✅成功 / ❌失敗 で更新される

**結果取得**:
- 移動成功件数 `N2_ok` / 失敗件数 `N2_ng` を Phase 4 集約用に保持

**Phase 2 失敗時の取り扱い**:
- 部分失敗（一部のみ移動完了）はそのまま継続して Phase 4 へ進む
- 完全失敗（0件移動）でも Phase 4 を継続実行
- 失敗内容は Phase 4 集約MD表に明記（殿が手動復帰判断するための情報源）

### Phase 4: 統合結果の dashboard_items 集約掲載

`queue/dashboard_items/{caller_cmd}.yaml` の `display_content` を以下の集約MD表で **上書き** する:

```yaml
cmd_id: {caller_cmd}
section: completion_pending
display_title: 'cmd_{caller_cmd}: 毎日継続エスコート（target_date=YYYY-MM-DD→move_to=YYYY-MM-DD）'
display_content: |
  ## /tcc-escort-unfinished-mainichi-keizoku 実行結果サマリ

  | Phase | 委譲先スキル | 件数 | 結果 |
  |-------|------------|------|------|
  | Phase 1 | /tcc-mainichi-keizoku-unfinished-list | {N1}件 | ✅ 一覧取得完了 |
  | Phase 2 | /tcc-batch-move-date | {N2_ok}/{N1}件 | {Phase2 ステータス} |

  ### Phase 1 詳細（毎日継続タグ付き未完了）
  - 証跡: `tmp/tcc_task_by_tag_毎日継続_{target_date}.md`
  - 未完了件数: {N1}件

  ### Phase 2 詳細（時間なしセクション+日付変更）
  - 移動先: {move_to_date}（時間なしセクション）
  - 成功: {N2_ok}件 / 失敗: {N2_ng}件
  - 失敗時の手動復帰: 殿が `dashboard_items/{caller_cmd}.yaml` ステータス列の ❌ 行を確認し、`/tcc-batch-move-date` を個別再実行

timestamp: '{ISO 8601 JST}'
updated_at: '{ISO 8601 JST}'
latest_note: 'Phase1={N1}件 / Phase2={N2_ok}/{N1}件。target_date=YYYY-MM-DD / move_to_date=YYYY-MM-DD。'
```

実行コマンド:
```bash
bash scripts/generate_dashboard.sh
```

### Phase 5: 家老へ完了通知

```bash
bash scripts/inbox_write.sh karo \
  "/tcc-escort-unfinished-mainichi-keizoku 完了。target_date=YYYY-MM-DD / move_to=YYYY-MM-DD。Phase1={N1}件 / Phase2={N2_ok}/{N1}件。" \
  report_received ashigaru1
```

---

## 完了条件

1. Phase 1〜2 の全委譲スキルが実行完了している（0件正常終了含む）
2. `dashboard_items/{caller_cmd}.yaml` に Phase 1〜2 集約MD表が `section: completion_pending` で掲載
3. `dashboard.md` に generate_dashboard.sh の反映済
4. 家老 inbox に完了通知済

---

## エラーハンドリング

| エラー発生Phase | 対応 |
|---------------|------|
| Phase 1 で tcc2-mcp接続失敗 | F028発動 → 本スキル中断（後続Phase実行せず） |
| Phase 1 結果0件 | Phase 2 スキップ → Phase 4 で「対象0件・正常終了」記録 |
| Phase 2 部分失敗 | 失敗件数を Phase 4 集約に明記 → 完了通知 |
| Phase 2 完全失敗（0件移動） | 失敗事実を Phase 4 集約に明記 → 完了通知 |
| 各Phaseでversion競合 | 委譲先スキルのリトライ手順に従う |

**手動復帰の前提**（cmd_1434 殿御達し）:
- 殿は `dashboard_items/{caller_cmd}.yaml` の Phase 4 集約MD表から失敗箇所を確認し、`/tcc-batch-move-date` を直接再実行して復旧可能

---

## 制約・F-rule準拠

- **F030**: TCC操作は足軽1専任（本スキル+配下2スキル全て）
- **F055**: 一時ファイル `tmp/` 配下のみ
- **F028**: 行き詰まり時は停止して家老に報告
- **F004**: ポーリング禁止
- **F035**: multi-agent-shogunリポへのコミット禁止（未コミット運用）
- **F017**: 報告YAML上書 → inbox_write 順序厳守
- **F012**: TCCヘッダーのn/m行番号参照禁止（タスク名マッチ方式必須）

---

## 注意事項

1. **既存2スキルの改変禁止**（cmd_1434 制約）— 改変が必要と判断したら本スキルではなく既存スキル側のcmdを別途起票せよ
2. **WET禁止**（cmd_1434 制約）— 既存スキルの内部ロジックを本スキル定義内に複製してはならない。必ず「委譲先スキル定義に従って実行する」参照形式のみ
3. **無確認・連続実行**（cmd_1434 制約）— Phase間に殿確認プロンプトを挟まない。失敗時手動復帰は dashboard_items の Phase 4 集約MD表で殿が判断
4. **caller_cmd の事前STK登録必須**（skill_direct実行時）— 家老がcmd_idを事前採番すること

---

## 関連スキル

| スキル | 役割 |
|-------|------|
| `/tcc-mainichi-keizoku-unfinished-list` | Phase 1 委譲先（「毎日継続」タグ付き未完了一覧） |
| `/tcc-batch-move-date` | Phase 2 委譲先（複数編集モード+日付変更） |
| `/tcc-clean-up-previous-day` | 同方式の3スキル連鎖チェーン（cmd_1317） |
| `/tcc-task-by-tag-unfinished-list` | Phase 1 委譲先の内部委譲先（汎用タグ未完了一覧） |
