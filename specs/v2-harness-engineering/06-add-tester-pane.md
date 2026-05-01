---
phase: 2
task_id: 06-add-tester-pane
agent: infrastructure-engineer
estimated_minutes: 25
depends_on: [02, 03, 04, 05]
---

# Task: tester pane を追加 (impl context blind の独立 QA pane)

## Goal
v2 開発フローを engineer → (tester ∥ reviewer) → planner の 4 stage に確立する。
tester は **実装コンテキストを持たない**独立 pane で、spec の Acceptance Criteria のみを見て
テストを実行し、PASS/FAIL を planner に返す。

## Inputs
- 既存: `start_session.sh`, `.claude/rules/{orchestrator,planner,reviewer,engineer}.md`
- 既存: `memory/MEMORY.md`, `queue/inbox/`, `queue/outbox/`
- 既存: `~/.claude/agents/qa-engineer.md` (user-level subagent、tester pane が dispatch する)
- `memory/claude-code-expert.md` (公式仕様確認用)

## Steps

### A. pane layout 変更 (start_session.sh)

旧: 3x3 grid、9 pane (planner + engineer1..7 + reviewer)
新: **5x2 grid**、10 pane (planner + engineer1..7 + tester + reviewer)

```
   col0       col1        col2        col3       col4
   planner    engineer2   engineer4   engineer6  tester
   engineer1  engineer3   engineer5   engineer7  reviewer
```

tmux split 順序例:
```bash
# 5 column 作成 (4 horizontal split)
tmux split-window -h -t "multiagent:agents"
tmux split-window -h -t "multiagent:agents"
tmux split-window -h -t "multiagent:agents"
tmux split-window -h -t "multiagent:agents"

# 各 col を縦 2 分割 (5 vertical split)
for col in 0 1 2 3 4; do
  tmux select-pane -t "multiagent:agents.$col"
  tmux split-window -v -t "multiagent:agents"
done
tmux select-layout -t "multiagent:agents" tiled  # or custom layout
```

`AGENT_IDS` 配列を以下に拡張:
```bash
AGENT_IDS=("planner" "engineer1" "engineer2" "engineer3" "engineer4" "engineer5" "engineer6" "engineer7" "tester" "reviewer")
```

10 pane 全部に `@agent_id` `@model_name` `@current_task` を set。

### B. tester role files 新規作成

#### B1. `.claude/rules/tester.md`
frontmatter:
```yaml
---
description: Tester pane の手順書。実装コンテキストを持たず、spec の Verification セクションのみを見てテストを実行、結果を planner に返す。
---
```

body 主要項目:
- 役割: 「spec を真実情報源として、blind test execution を実行する独立 QA」
- 入力: `specs/<topic>/<task>.md` の `## Verification` 句および `## Expected Output`
- **禁止**: engineer report (`queue/outbox/engineer*.yaml`)、実装 diff、git log を **Read しない**
- 実行: qa-engineer subagent を Agent tool で dispatch、test fixture / runner があれば走らせる
- 出力: `queue/outbox/tester.yaml` に PASS/FAIL + 失敗時は失敗 case の出力 + 該当 spec の AC 番号
- planner にのみ報告 (orchestrator / engineer / reviewer 直接通信は禁止)

#### B2. `.claude/rules/roles/tester_role.md`
- 詳細な役割説明 + critical thinking + SKIP=FAIL ルール ([CLAUDE.md §10] と整合)
- impl blindness の徹底 (なぜ blind か、見ると何が問題か)

### C. tester memory file 新規作成
`memory/tester.md` を `memory/agent-template.md` 元に作成:
```markdown
---
name: tester
description: 独立 QA pane の memory。impl context を排し AC ベースで test 実行する規律を蓄積。
type: project
---

# Tester Memory

## 役割
spec の Verification / Acceptance Criteria に従い blind test を実行。

## 過去の学び
(初期は空、運用中に追記)

## 暗黙のルール
- engineer report は Read しない (impl 知識汚染回避)
- ...
```

### D. `memory/MEMORY.md` index 更新
project-level agents セクションに `tester` を追加。

### E. queue/ に tester slot 追加
- `queue/inbox/tester.yaml` (skeleton: `messages: []`)
- `queue/outbox/tester.yaml` (skeleton: `messages: []`)

### F. planner / reviewer ワークフロー更新

#### F1. `.claude/rules/planner.md`
- engineer 完了後の dispatch を「reviewer のみ」→「tester + reviewer 並列」に変更
- 両者 PASS で spec 完了マーク
- 失敗時の handle: tester FAIL → engineer に test failure 詳細付きで redispatch / reviewer FAIL → engineer に code quality 指摘付きで redispatch

#### F2. `.claude/rules/reviewer.md`
- 自分の責務は **コード品質のみ** (test 実行は tester 側)
- design-review + code-review 両方走らせる (worktree fork で分離可)

#### F3. `.claude/rules/engineer.md`
- 完了 report の宛先は変わらず planner inbox
- 失敗 redispatch 時は tester / reviewer どちらの指摘か明示される

### G. CLAUDE.md 更新

§1 Roles 表に tester 追加:
```markdown
| tester      | `multiagent:agents.8` | spec の AC を blind test 実行 (impl context 排除) | Sonnet |
| reviewer    | `multiagent:agents.9` | 設計 + コード品質レビュー                           | Opus   |
```

§2 標準 workflow を 4 stage 化:
```
殿 → orchestrator → planner: spec 化
planner → engineer: 実装 dispatch
engineer 完了 → planner: tester + reviewer に並列 dispatch
  tester: spec の AC のみ見て blind test → PASS/FAIL
  reviewer: 実装 diff のコード品質 review → 指摘 0 or N
両 ✅ → planner: spec 完了マーク + memory 更新
```

§3 ディレクトリに `.claude/rules/tester.md` および `memory/tester.md` を反映。

### H. README.md / README_ja.md 更新
- Roles 表 / Concept セクションに tester pane 追加 (workflow 図、4 stage を簡潔に説明)
- pane layout 図 (5x2 grid)

### I. scripts 更新

#### I1. `scripts/agent_status.sh`
- `AGENTS` 配列に tester を追加
- pane index mapping: planner=0, engineer1..7=1..7, tester=8, reviewer=9

#### I2. `scripts/ratelimit_check.sh`
- `ALL_AGENTS` 配列に tester 追加
- `get_engineer_ids` 系の helper 関数は engineer のみだが、tester / reviewer 用の独立 helper があれば update

### J. start_session.sh の help / pane layout 表
```
   [orchestrator]  orchestrator
   [multiagent]    5x2 grid:
                      planner    engineer2   engineer4   engineer6  tester
                      engineer1  engineer3   engineer5   engineer7  reviewer
```

## Expected Output
- 10 pane multiagent session が `./start_session.sh` で起動
- tester pane が独自 memory + rules + queue slot を持つ
- planner workflow が tester / reviewer 並列 dispatch に対応
- README / CLAUDE.md / 関連 script 全て tester を反映

## Verification
1. `bash -n start_session.sh` 構文 OK
2. `grep "tester" .claude/rules/ memory/ queue/ scripts/agent_status.sh CLAUDE.md README.md README_ja.md | wc -l` 十分件数
3. `find queue/inbox queue/outbox -name "tester.yaml"` 2 件
4. `find .claude/rules -name "tester*.md"` 2 件 (top + roles/)
5. `find memory -name "tester.md"` 1 件
6. CLAUDE.md §1 Roles 表に tester 行あり、§2 workflow が 4 stage

## Notes
- pane index 番号変更で旧 reviewer pane (旧 0.8 → 新 0.9) を参照する全 script / doc を更新
- tester は qa-engineer subagent を実 test 実行に使う (subagent definition は既存 `~/.claude/agents/qa-engineer.md`)
- tester の **blind discipline** は文化的なルールなので `.claude/rules/tester.md` で強調記述
- commit はしない (main session が一括 commit)
