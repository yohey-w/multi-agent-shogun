---
phase: cmd_001
task_id: subtask_001a
agent: engineer1
estimated_minutes: 10
depends_on: []
---

# Task: project-level agent への memory 配布

## Goal
`./memory/` 配下の各 agent memory ファイルを project-level agents (`.claude/agents/<agent>/agent-memory/`) に複製する。

## Inputs
- Source: `/Users/mizunomakoto/Project/makotoProj/ai_accelerate/agent-orchestra-makoto-mizuno/memory/`
  - planner.md, design-reviewer.md, code-reviewer.md, claude-code-expert.md, tester.md
  - MEMORY.md
- Destination base: `/Users/mizunomakoto/Project/makotoProj/ai_accelerate/agent-orchestra-makoto-mizuno/.claude/agents/`

## Steps

1. 対象 agent と dest path の確認:
   ```
   planner       → .claude/agents/planner/agent-memory/planner.md
   design-reviewer → .claude/agents/design-reviewer/agent-memory/design-reviewer.md
   code-reviewer → .claude/agents/code-reviewer/agent-memory/code-reviewer.md
   claude-code-expert → .claude/agents/claude-code-expert/agent-memory/claude-code-expert.md
   tester        → .claude/agents/tester/agent-memory/tester.md  (新規ディレクトリ)
   ```

2. 各 agent-memory/ ディレクトリを作成:
   ```bash
   PROJECT_ROOT="/Users/mizunomakoto/Project/makotoProj/ai_accelerate/agent-orchestra-makoto-mizuno"
   AGENTS_DIR="$PROJECT_ROOT/.claude/agents"
   MEMORY_DIR="$PROJECT_ROOT/memory"
   for agent in planner design-reviewer code-reviewer claude-code-expert tester; do
     mkdir -p "$AGENTS_DIR/$agent/agent-memory"
   done
   ```

3. memory ファイルを実体コピー (symlink ではなく cp — archive/move 時の安全性のため):
   ```bash
   for agent in planner design-reviewer code-reviewer claude-code-expert tester; do
     cp "$MEMORY_DIR/$agent.md" "$AGENTS_DIR/$agent/agent-memory/$agent.md"
     cp "$MEMORY_DIR/MEMORY.md" "$AGENTS_DIR/$agent/agent-memory/MEMORY.md"
   done
   ```

4. コピー結果を確認:
   ```bash
   for agent in planner design-reviewer code-reviewer claude-code-expert tester; do
     echo "=== $agent ==="
     ls -la "$AGENTS_DIR/$agent/agent-memory/"
   done
   ```

## Expected Output
- `.claude/agents/planner/agent-memory/planner.md` (memory/planner.md と同一内容)
- `.claude/agents/planner/agent-memory/MEMORY.md` (memory/MEMORY.md と同一内容)
- 上記 5 agent 分 × 2 ファイル = 計 10 ファイル

## Verification
```bash
PROJECT_ROOT="/Users/mizunomakoto/Project/makotoProj/ai_accelerate/agent-orchestra-makoto-mizuno"
AGENTS_DIR="$PROJECT_ROOT/.claude/agents"
MEMORY_DIR="$PROJECT_ROOT/memory"
for agent in planner design-reviewer code-reviewer claude-code-expert tester; do
  test -f "$AGENTS_DIR/$agent/agent-memory/$agent.md" || echo "MISSING: $agent/$agent.md"
  test -f "$AGENTS_DIR/$agent/agent-memory/MEMORY.md" || echo "MISSING: $agent/MEMORY.md"
  diff "$MEMORY_DIR/$agent.md" "$AGENTS_DIR/$agent/agent-memory/$agent.md" >/dev/null && echo "OK: $agent.md" || echo "DIFF: $agent.md"
done
# Expected: 全て "OK: <agent>.md" が出力される
```

## Notes
- 実体コピー (cp) を選定。symlink は rsync/archive 時に broken link になるリスクがある
- tester は .claude/agents/ に tester.md が存在しないが agent-memory/ を作成して memory file を置く
- 既存の .claude/agents/*.md (agent 定義ファイル) は一切変更しない
