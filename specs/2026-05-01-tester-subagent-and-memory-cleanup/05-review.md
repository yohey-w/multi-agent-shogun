---
phase: cmd_002
task_id: reviewer_task_002
agent: reviewer
estimated_minutes: 12
depends_on: [subtask_003, subtask_004, subtask_005]
---

# Task: impl + diff レビュー — cmd_002

## Goal
engineer 3 名の deliverable を reviewer が確認し、指摘事項の有無を report する。

## Review Scope

### 1. tester subagent 定義 (.claude/agents/tester.md) の検証

- frontmatter が公式仕様を満たしているか (name/description/tools/model/memory フィールド)
- `memory: project` が設定されているか
- `.claude/rules/tester.md` の内容 (impl blind / SKIP=FAIL / AC のみ Read) が tester.md に反映されているか
- report format セクションが存在するか

### 2. memory/ 削除と参照更新の検証

- `memory/` ディレクトリが git rm 済みか (`git status` / 実ファイル確認)
- `.claude/hooks/session_start_inject_memory.sh` が agent-memory/ パスを正しく参照しているか
- `.claude/hooks/post_engineer.sh` が更新されているか
- agent-memory/ ベース以外の壊れた `memory/` 参照がないか

### 3. engineer dispatch ルールの検証

- `.claude/rules/engineer.md` に Specialist Subagent Dispatch Rule セクションが追記されているか
- ルール内容が cmd_002 command セクションの要件 (bloom_level L1-L2 は不要 / L3以上は dispatch) と整合しているか
- 既存セクションへの破壊的変更がないか

## Review Commands

```bash
PROJECT_ROOT="/Users/mizunomakoto/Project/makotoProj/ai_accelerate/agent-orchestra-makoto-mizuno"

# 1. tester.md frontmatter
echo "=== tester.md frontmatter ==="
head -10 "$PROJECT_ROOT/.claude/agents/tester.md"

# 2. memory/ 削除確認
echo "=== memory/ existence ==="
test ! -d "$PROJECT_ROOT/memory/" && echo "DELETED OK" || echo "STILL EXISTS"

# 3. hook 更新確認
echo "=== session_start_inject_memory.sh agent-memory refs ==="
grep -n "agent-memory\|mem_base\|mem_index\|mem_file" \
  "$PROJECT_ROOT/.claude/hooks/session_start_inject_memory.sh"

# 4. broken refs check
echo "=== broken memory/ refs ==="
grep -rn "memory/" "$PROJECT_ROOT/.claude/hooks/" "$PROJECT_ROOT/scripts/" \
  "$PROJECT_ROOT/.claude/rules/" 2>/dev/null \
  | grep -v "agent-memory" | grep -v ".git/" | grep -v "memory: project"

# 5. engineer dispatch rule
echo "=== engineer dispatch rule ==="
grep -A5 "Specialist Subagent Dispatch Rule" "$PROJECT_ROOT/.claude/rules/engineer.md" | head -15
```

## Expected Output
- qa_decision: pass / issues_found: [] (問題なし)
- または qa_decision: fail + 具体的な指摘

## Notes
- north_star: end-to-end 連携検証 + spec-first ルール遵守体制確立
- 完了後: `bash scripts/inbox_write.sh planner "Reviewer: review complete on reviewer_task_002." report_received reviewer`
