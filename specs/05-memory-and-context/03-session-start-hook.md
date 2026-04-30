---
phase: 5
task_id: 03-session-start-hook
agent: planner (Haiku 可)
estimated_minutes: 10
depends_on: [02-init-agent-memory-files]
---

# Task: SessionStart hook で agent の memory.md を自動 context 注入

## Goal
Claude Code の SessionStart hook を使い、subagent (or main session) 起動時に該当 memory ファイルを `additionalContext` として注入する。各 agent が自分の過去文脈を持って起動できる。

## Steps

1. `.claude/hooks/session_start_inject_memory.sh` を作成 (実行権限付与):

```bash
#!/usr/bin/env bash
# SessionStart hook: inject agent-specific memory.md as additionalContext.
# Triggered for both main session and subagent sessions (Claude Code passes
# the relevant agent identity via env / payload).

set -uo pipefail

# 1) Determine agent name. Priority:
#    a) CLAUDE_AGENT_NAME env var (if Claude Code sets it for subagents)
#    b) Read from stdin JSON's `agent` field
#    c) Fallback: "main" (no specific agent — load planner as default in project root)

input=$(cat)
agent=""

if [ -n "${CLAUDE_AGENT_NAME:-}" ]; then
  agent="$CLAUDE_AGENT_NAME"
elif command -v jq >/dev/null 2>&1; then
  agent=$(printf '%s' "$input" | jq -r '.agent // .subagent // empty' 2>/dev/null)
fi

if [ -z "$agent" ]; then
  agent="planner"
fi

# 2) Locate memory directory (project root assumption: cwd is repo root)
mem_index="memory/MEMORY.md"
mem_file="memory/${agent}.md"

# 3) Build additionalContext (cap at ~6000 chars to avoid context bloat)
ctx=""
if [ -f "$mem_index" ]; then
  ctx+=$'\n\n## Memory Index\n'
  ctx+="$(head -c 1500 "$mem_index")"
fi
if [ -f "$mem_file" ]; then
  ctx+=$'\n\n## Your Memory ('"${agent}"$')\n'
  ctx+="$(head -c 4500 "$mem_file")"
fi

# 4) Output JSON for hook spec (additionalContext)
if [ -n "$ctx" ]; then
  jq -nc \
    --arg ctx "$ctx" \
    '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
else
  echo '{}'
fi
exit 0
```

2. 実行権限付与:
```bash
chmod +x .claude/hooks/session_start_inject_memory.sh
```

3. `.claude/settings.json` に SessionStart hook を追加 (既存 hooks セクションに merge):
```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/session_start_inject_memory.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

4. pipe-test:
```bash
echo '{"agent":"planner"}' | bash .claude/hooks/session_start_inject_memory.sh
# Expected: JSON output containing additionalContext with planner.md head content
```

5. commit:
```bash
git add .claude/hooks/session_start_inject_memory.sh .claude/settings.json
git commit -m "feat(v2): SessionStart hook to auto-inject agent memory as context"
```

## Verification
```bash
# Pipe test
echo '{"agent":"planner"}' | bash .claude/hooks/session_start_inject_memory.sh | jq -e '.hookSpecificOutput.additionalContext' | head -c 200
# Expected: planner.md の先頭が JSON で返る

# settings.json schema 確認
jq -e '.hooks.SessionStart[].hooks[].command' .claude/settings.json
# Expected: command 文字列がある
```

## Notes
- Claude Code が SessionStart hook 入力で subagent name を渡すか実装依存
  - Anthropic 公式: SessionStart hook の `agent` フィールド or env var で渡される実装あり
  - 渡されない場合は fallback として planner を default (main session 用)
- 6000 char 上限: 各 agent の context window を圧迫しないため
- 機密情報を memory に書かないルール (Phase 5 Task 1) と相俟って、漏洩リスク最小化
- 各 pane の Claude Code は restart 必要 (hooks reload は /hooks 開けば反映)
