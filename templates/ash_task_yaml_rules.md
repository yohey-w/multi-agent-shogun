# ash task YAML rule template

**由来**: cmd_377 Phase 5 LU / Layer D（2026-05-02）
**管理**: 家老（karo）が起票時に本 template を参照し 4 項目を必ず含める。

---

## 必須 4 項目（全 task 共通）

| # | ルール ID | 内容 |
|---|----------|------|
| R-1 | `main-push-ban` | main branch 直接 push 厳禁（feature branch + PR + 家老 merge gate、LU #54 / Q8） |
| R-2 | `regression-gate` | PR merge 前 regression test mandatory（Q14）+ 家老 GO サイン待機 |
| R-3 | `ac-format` | acceptance_criteria に「main 直 push 完了」等の Q8 矛盾表現禁止、`feature branch + PR 完了` 形式で記載 |
| R-4 | `push-preflight` | push 直前 inbox_write で家老に pair / merge gate 状況確認 |

---

## Copy-paste template（最小構成）

```yaml
task:
  task_id: subtask_XXXYYY
  parent_cmd: cmd_XXX
  assigned_to: ashigaruN
  status: assigned
  bloom_level: L4
  project: <project_name>
  timestamp: "YYYY-MM-DDTHH:MM:SS"

  title: "<task title>"

  background: |
    <背景・経緯>

  scope:
    - <実装内容 bullet>

  acceptance_criteria:
    # 正しい書き方（feature branch + PR + 家老 merge gate）
    - "feature branch <branch名> 作成 + commit + push 完了"
    - "PR 作成完了 (PR URL 報告)"
    - "regression test シナリオ A-D 静的 PASS evidence (PR body 記載)"
    - "家老 merge gate 依頼 inbox_write 送信済"
    - "Secret 値出力ゼロ"
    - "Triple-Check 記載"
    # NG 例（Q8 矛盾表現、書いてはならない）
    # - "main 直 push 完了"
    # - "commit SHA 報告"

  rules:
    - "main branch 直接 push 禁止 (feature branch + PR + 家老 merge gate 厳守、LU #54 / Q8)"
    - "PR merge 前 regression test PASS 確認 (Q14 mandatory) + 家老 GO サイン待機"
    - "push 直前 inbox_write で家老に pair / merge gate 状況確認"
    - "Secret 値出力厳禁 (env 変数名のみ)"
```

---

## Bloom Level 別 追加 rule

| Level | 追加必須ルール |
|-------|-------------|
| **L4**（実装のみ） | 上記 R-1〜R-4 のみで十分 |
| **L5**（設計 + 実装） | `"軍師 QC 必須（実装前に設計書を軍師に送付し LGTM 取得）"` |
| **L6**（戦略 + 設計 + 実装） | `"軍師 QC 必須（各 Phase 開始前）"` + `"殿厳命項目は 家老 → 殿 Q&A で全 OK 後に出陣"` |

---

## 起票前 self-check（家老手順）

```bash
# 1. acceptance_criteria に Q8 矛盾表現が混入していないか確認
grep -E "main\s*(直)?\s*push|main.*(commit SHA|push 完了)" queue/tasks/ashigaru*.yaml
# → 出力ゼロ = OK

# 2. rules: section に 4 項目が存在するか確認
grep -c "main branch 直接 push 禁止\|regression test PASS\|push 直前 inbox_write\|Secret 値出力" queue/tasks/ashigaru*.yaml
# → 4 件以上 = OK（1 task あたり）
```

---

## 失敗事例引用（ash5 self-correction 文脈）

**事例**: cmd_377 Phase 3 subtask_377f（ash5担当）

家老が acceptance_criteria に「main 直 push 完了 + commit SHA 報告」と記載した task YAML を起票。
ash5 はその指示通りに行動し、AB repo に main 直 push（commit 4586921）を実施した。

**結果**:
- Q8 殿裁定（両 repo 同期 PR + 家老 merge gate）違反
- Q14（mandatory regression test PR merge gate）skip
- LU #54（家老 orchestration gate）skip
- path 不整合バグ（`/auth?intent=...` ↔ Portal `/login`）を pre-merge regression test で未検出のまま push 完了
- stg E2E 失敗状態、Phase 4 進行 NG
- redo 命令（subtask_377f_followup_path_fix）発令、追加コスト発生

**真因**: ash5 個人責任ではなく **task YAML 起票時の acceptance_criteria 記述が Q8 規範と矛盾**していた構造的問題。

**本 template で防止する**: 起票 self-check + R-1〜R-4 必須化により同型再発を構造的に解消。

---

*最終更新: 2026-05-02 / cmd_377 Phase 5 LU Layer D（ash5 self-correction）*
