# Agent Self-Watch テスト仕様書

| 項目 | 内容 |
|---|---|
| 文書ID | ASW-SPEC-001 |
| parent_cmd | cmd_107 |
| task_id | subtask_107b |
| 作成日 | 2026-02-09 |
| 参照要件 | reports/requirements_agent_selfwatch.md |
| 対象 | Agent self-watch Phase 1-3（TDD Step 2） |

---

## 1. 目的

本仕様書は、`reports/requirements_agent_selfwatch.md` で定義された FR/NFR を、
実装前に検証可能なテストケースへ分解する。

ゴール:
- FR/NFRごとにテストケースID・期待値を定義する
- ユニットテスト範囲（inbox処理・監視・競合制御・エスカレーション）を明確化する
- E2E範囲を「殿担当」として分離する

---

## 2. テストレベルと担当

| レベル | 名称 | 主担当 | 実行環境 | 用途 |
|---|---|---|---|---|
| L1 | Unit | 足軽（本件） | bats + bash + python3 | 関数/ロジック単体検証 |
| L2 | Integration | 家老 | L1 + tmux + inotify-tools | watcher/CLI境界の統合検証 |
| L3 | E2E | **殿担当** | 実運用tmux全体 | 指揮系統を含む完走確認 |

注記:
- `SKIP=0` は必須。SKIPが1以上なら「未完了」扱い。
- 本仕様書は Step 2 対象。実装・実行は後続 Step 3以降。

---

## 3. FRテストケース一覧

### 3.1 Phase 1

| TC ID | 要件 | レベル | 観点 | 期待値 |
|---|---|---|---|---|
| TC-FR-001 | FR-001 起動時未読回収 | L1 | 起動直後処理 | 未読ありで `process_unread_once` が1回動作し取りこぼし0 |
| TC-FR-002 | FR-002 self-watch監視 | L1/L2 | inotify+timeout | inotify欠落時でもtimeout経由で未読検知できる |
| TC-FR-003 | FR-003 type別処理 | L1 | message type分岐 | `task_assigned`/`clear_command`/`model_switch` が正しい処理レーンへ分岐 |
| TC-FR-004 | FR-004 排他整合 | L1/L2 | flock+atomic | 競合時でもYAML破損せず read更新が巻き戻らない |
| TC-FR-005 | FR-005 post-task inbox check | L1/L3 | 完了直後動作 | 完了直後に未読確認し、未読あり時はidle移行しない |
| TC-FR-006 | FR-006 可観測性メトリクス | L1 | metrics記録 | `unread_latency_sec`/`read_count`/`estimated_tokens` が算出可能 |
| TC-FR-007 | FR-007 Feature Flag移行 | L1/L2 | フラグ切替 | phase切替が有効、OFF時は現行互換モードへ戻る |

### 3.2 Phase 2

| TC ID | 要件 | レベル | 観点 | 期待値 |
|---|---|---|---|---|
| TC-FR-008 | FR-008 通常nudge停止 | L2 | send-keys削減 | 通常メッセージで `send-keys inboxN` が実行されない |
| TC-FR-009 | FR-009 特殊コマンド互換 | L1/L2 | 互換性 | `clear_command`/`model_switch` の既存挙動を維持 |
| TC-FR-010 | FR-010 summary-first | L1 | fast-path | unread_count=0時にfull read回避、必要時のみfull read |

### 3.3 Phase 3

| TC ID | 要件 | レベル | 観点 | 期待値 |
|---|---|---|---|---|
| TC-FR-011 | FR-011 send-keys最終手段化 | L2/L3 | 復旧限定 | 平常時send-keys利用0、異常時のみ発火 |
| TC-FR-012 | FR-012 閾値再定義 | L1/L2 | エスカレーション | 閾値/cooldownに従い過剰復旧ループが発生しない |
| TC-FR-013 | FR-013 代替IPC評価フック | L1 | 拡張性 | YAML正本を崩さずPoC導入/撤回が可能 |

### 3.4 共通

| TC ID | 要件 | レベル | 観点 | 期待値 |
|---|---|---|---|---|
| TC-FR-014 | FR-014 後方互換IF | L1/L2 | インターフェース | inbox YAML schema / inbox_write IF / message type互換を維持 |
| TC-FR-015 | FR-015 実装/CI連携 | L1/L2 | 連携 | spec→bats→CI が同一IDでトレース可能 |

---

## 4. NFRテストケース一覧

| TC ID | 要件 | レベル | 観点 | 期待値 |
|---|---|---|---|---|
| TC-NFR-001 | NFR-001 信頼性 | L2/L3 | 未読喪失防止 | 未読メッセージ喪失0、再処理は冪等 |
| TC-NFR-002 | NFR-002 後方互換性 | L1/L2 | 回帰 | 既存inbox_write/既存YAMLで回帰なし |
| TC-NFR-003 | NFR-003 トークン効率 | L1/L2 | No Idle Read | idle時full readゼロ、推定tokens/dayが閾値内 |
| TC-NFR-004 | NFR-004 運用性 | L2 | 障害復旧 | 手順書のみで復旧可能、再現率100% |
| TC-NFR-005 | NFR-005 可搬性 | L2/L3 | 環境差分 | WSL2/Linux/Docker/SSH方針に矛盾がない |
| TC-NFR-006 | NFR-006 観測可能性 | L1 | ログ/指標 | 主要メトリクスが継続収集できる |
| TC-NFR-007 | NFR-007 保守性 | L1 | 責務分離 | watcher責務が肥大せず、標準経路/復旧経路が分離 |
| TC-NFR-008 | NFR-008 テスト容易性 | L1 | トレース | FR/NFR→TC→batsの対応表が欠落なし |

---

## 5. ユニットテスト範囲（Step 3対象）

## 5.1 inbox処理

- UT-INBOX-001: unread_count算出（空/既読のみ/混在）
- UT-INBOX-002: type別分岐（task_assigned/clear/model/unknown）
- UT-INBOX-003: read更新の冪等性（同一メッセージ再処理でも破壊なし）
- UT-INBOX-004: 起動時 `process_unread_once` の必須実行

期待値:
- unread算出誤差0
- unknown typeでも異常終了しない
- read更新後のYAML構造が有効

## 5.2 監視（self-watch）

- UT-WATCH-001: inotifyイベントで処理起動
- UT-WATCH-002: timeout fallbackで補足
- UT-WATCH-003: No Idle Readルール（idle時full read禁止）

期待値:
- event欠落があってもtimeoutで未読回収
- idle時に無駄なfull readを実行しない

## 5.3 競合制御

- UT-LOCK-001: flock競合時の安全リトライ
- UT-LOCK-002: atomic replace後もYAML破損なし
- UT-LOCK-003: 同時更新時の整合性（巻き戻りなし）

期待値:
- lock競合でも整合性を維持
- 破損YAMLを生成しない

## 5.4 エスカレーション

- UT-ESC-001: unread ageに応じたPhase1/2/3遷移
- UT-ESC-002: cooldownで `/clear` 連打を抑制
- UT-ESC-003: busy時はnudge defer
- UT-ESC-004: self-watch有効時はnudge送信スキップ

期待値:
- 時間条件に応じた期待アクションのみ発火
- busy/self-watch条件で誤送信なし

---

## 6. 統合テスト範囲（家老担当）

- IT-001: watcher + agent + inbox_write の連携
- IT-002: CLI別分岐（claude/codex/copilot）
- IT-003: 通常経路でsend-keys不要化（Phase2）
- IT-004: 障害注入時の最終復旧（Phase3）

期待値:
- ユニットでは見えない境界不整合が解消される
- エージェント間運用で再現性がある

---

## 7. E2E範囲（殿担当）

本仕様におけるE2Eは **殿担当** とし、家老/足軽は実施しない。

対象:
- E2E-001: Shogun→Karo→Ashigaruの全系統完走
- E2E-002: redo/clearを含む長時間運用
- E2E-003: 9エージェント並列時の安定性と未読滞留

期待値:
- 組織階層運用での実運用成立
- /clear依存が過剰に増えない
- 主要メトリクスが許容範囲に収まる

---

## 8. 前提条件（Preflight）

- `bash`, `python3`, `bats` が利用可能
- L2以上は `tmux`, `inotifywait` が利用可能
- テスト対象のqueue/testsパスへ読み書き可能

前提未充足時:
- 該当テストは実行せず、未充足理由を記録する
- SKIP報告は禁止（未完了として扱う）

---

## 9. FR/NFRトレース運用ルール

- batsテスト名にTC IDを埋め込む（例: `TC-FR-001`）
- テスト結果レポートは TC ID 単位で PASS/FAIL 記録
- 1要件1件以上のTCを維持（欠落禁止）

---

## 10. E2E実施ランブック（殿向け・時系列）

本節は `cmd_117` 要件「殿がE2Eテストを実施できる準備」を満たすための実行手順である。
実施順は固定し、途中で失敗した場合は当該行の診断に従って復旧してから再開する。

| 前提条件 | 手順 | 期待結果 | 失敗時診断 | 証跡 |
|---|---|---|---|---|
| Step 1: tmux基盤が起動済み | `tmux ls` を実行し、`shogun` と `multiagent` セッションを確認する。 | 2セッションが存在し、終了していない。 | セッション欠落時は `bash scripts/shohou/start_or_resume.sh` を実行し再確認。 | `tests/results/e2e_cmd117_step01_tmux_sessions.txt` |
| Step 2: 家老/足軽の監視プロセスが稼働中 | `pgrep -af \"inbox_watcher.sh|inotifywait\"` を実行する。 | 監視プロセスが確認できる。 | 監視が見えない場合は watcher 再起動後、`logs/` の直近エラーを確認。 | `tests/results/e2e_cmd117_step02_watchers.txt` |
| Step 3: E2E開始前に未読滞留が暴発していない | `for f in queue/inbox/*.yaml; do c=$(awk '/read: false/{n++} END{print n+0}' \"$f\"); echo \"$(basename \"$f\"):$c\"; done` を実行する。 | 実施対象エージェントの未読が許容範囲（原則0）である。 | 未読>0が残る場合は先に通常処理を完了させ、再度Step 3を実行。 | `tests/results/e2e_cmd117_step03_unread_baseline.txt` |
| Step 4: E2E-001（Shogun→Karo→Ashigaru全系統）を起動 | `bash scripts/inbox_write.sh karo \"cmd117_e2e_probe: chain test\" cmd_new shogun` を送信し、家老の処理と足軽タスク配備を確認する。 | 家老inboxが処理され、少なくとも1足軽へタスクが流れる。 | 2分以上変化がない場合は `queue/inbox/karo.yaml` と `logs/inbox_watcher/` を確認し、Phase 2/3 エスカレーション条件を点検。 | `tests/results/e2e_cmd117_step04_chain.md` |
| Step 5: E2E-002（redo/clear系）を検証 | 対象足軽へ `clear_command` を送る（例: `bash scripts/inbox_write.sh ashigaru6 \"cmd117_e2e_probe redo\" clear_command karo`）し、回復フローを確認する。 | `/clear` 後に対象足軽が task YAML を再読込し、停止せず復帰する。 | 復帰しない場合は `queue/inbox/ashigaru6.yaml` の `read` 更新と task status を確認し、race有無を点検。 | `tests/results/e2e_cmd117_step05_redo_clear.md` |
| Step 6: E2E-003（9エージェント並列安定性）を確認 | `tmux list-panes -t multiagent -F '#{pane_index}:#{pane_current_command}'` と Step 3 を再実行し、並列稼働中の滞留を確認する。 | 多重稼働でも未読滞留が連続増加しない。 | 滞留が増える場合は busy-skip/cooldown 条件の誤設定を確認し、該当agentログを採取。 | `tests/results/e2e_cmd117_step06_parallel_health.txt` |
| Step 7: E2E完了判定を記録 | `tests/results/e2e_cmd117_readiness.md` に E2E-001/002/003 の PASS/FAIL、阻害要因、再試行計画を記載する。 | 殿が次アクションを即決できる判定記録が完成する。 | 判定根拠が不足する場合は不足証跡を再取得してから記録を確定する。 | `tests/results/e2e_cmd117_readiness.md` |

---

以上をもって、`cmd_107` AC-2（テスト仕様書完成）および `cmd_117` の「E2E実施可能な手順整備」を満たす。
