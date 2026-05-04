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

# 2) Locate memory directory based on agent type
# Project-level agents live in .claude/agents/<agent>/agent-memory/
# User-level agents live in ~/.claude/agents/<agent>/agent-memory/
project_agents="planner design-reviewer code-reviewer claude-code-expert tester"
project_dir=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

if echo "$project_agents" | grep -qw "$agent"; then
  mem_base="${project_dir}/.claude/agents/${agent}/agent-memory"
else
  mem_base="${HOME}/.claude/agents/${agent}/agent-memory"
fi

mem_index="${mem_base}/MEMORY.md"
mem_file="${mem_base}/${agent}.md"

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
