---
phase: cmd_001
task_id: subtask_001b
agent: engineer2
estimated_minutes: 10
depends_on: []
---

# Task: user-level agent への memory 配布

## Goal
`./memory/` 配下の各 agent memory ファイルを user-level agents (`~/.claude/agents/<agent>/agent-memory/`) に複製する。

## Inputs
- Source: `/Users/mizunomakoto/Project/makotoProj/ai_accelerate/agent-orchestra-makoto-mizuno/memory/`
  - frontend-engineer.md, backend-engineer.md, infrastructure-engineer.md, db-engineer.md
  - chrome-extension-engineer.md, native-app-engineer.md, game-engineer.md, ml-engineer.md, qa-engineer.md
  - MEMORY.md
- Destination base: `~/.claude/agents/`

## Steps

1. 対象 agent 一覧:
   ```
   frontend-engineer, backend-engineer, infrastructure-engineer, db-engineer,
   chrome-extension-engineer, native-app-engineer, game-engineer, ml-engineer, qa-engineer
   ```

2. 各 agent-memory/ ディレクトリを作成:
   ```bash
   USER_AGENTS="$HOME/.claude/agents"
   MEMORY_DIR="/Users/mizunomakoto/Project/makotoProj/ai_accelerate/agent-orchestra-makoto-mizuno/memory"
   for agent in frontend-engineer backend-engineer infrastructure-engineer db-engineer \
                chrome-extension-engineer native-app-engineer game-engineer ml-engineer qa-engineer; do
     mkdir -p "$USER_AGENTS/$agent/agent-memory"
   done
   ```

3. memory ファイルを実体コピー:
   ```bash
   for agent in frontend-engineer backend-engineer infrastructure-engineer db-engineer \
                chrome-extension-engineer native-app-engineer game-engineer ml-engineer qa-engineer; do
     cp "$MEMORY_DIR/$agent.md" "$USER_AGENTS/$agent/agent-memory/$agent.md"
     cp "$MEMORY_DIR/MEMORY.md" "$USER_AGENTS/$agent/agent-memory/MEMORY.md"
   done
   ```

4. コピー結果確認:
   ```bash
   for agent in frontend-engineer backend-engineer infrastructure-engineer db-engineer \
                chrome-extension-engineer native-app-engineer game-engineer ml-engineer qa-engineer; do
     echo "=== $agent ==="
     ls -la "$USER_AGENTS/$agent/agent-memory/"
   done
   ```

## Expected Output
- `~/.claude/agents/frontend-engineer/agent-memory/frontend-engineer.md`
- `~/.claude/agents/frontend-engineer/agent-memory/MEMORY.md`
- 上記 9 agent 分 × 2 ファイル = 計 18 ファイル

## Verification
```bash
USER_AGENTS="$HOME/.claude/agents"
MEMORY_DIR="/Users/mizunomakoto/Project/makotoProj/ai_accelerate/agent-orchestra-makoto-mizuno/memory"
for agent in frontend-engineer backend-engineer infrastructure-engineer db-engineer \
             chrome-extension-engineer native-app-engineer game-engineer ml-engineer qa-engineer; do
  test -f "$USER_AGENTS/$agent/agent-memory/$agent.md" || echo "MISSING: $agent/$agent.md"
  test -f "$USER_AGENTS/$agent/agent-memory/MEMORY.md" || echo "MISSING: $agent/MEMORY.md"
  diff "$MEMORY_DIR/$agent.md" "$USER_AGENTS/$agent/agent-memory/$agent.md" >/dev/null && echo "OK: $agent.md" || echo "DIFF: $agent.md"
done
# Expected: 全て "OK: <agent>.md" が出力される
```

## Notes
- 実体コピー (cp) を採用 — symlink は relative path 問題や archive 時の broken link リスクがある
- 既存の `~/.claude/agents/<agent>.md` (agent 定義ファイル) は一切変更しない
- `<agent>/` ディレクトリと `<agent>.md` ファイルは同名だが別エンティティとして共存可能
