#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_FILE="${PROJECT_ROOT}/logs/mcp_health.log"
TIMESTAMP="$(date '+%Y-%m-%dT%H:%M:%S')"

mkdir -p "${PROJECT_ROOT}/logs"

errors=0
checked=0

echo "[${TIMESTAMP}] MCP Health Check Start" | tee -a "$LOG_FILE"

# multiagent:agents セッションの全ペインを走査
if ! tmux has-session -t multiagent 2>/dev/null; then
    echo "[${TIMESTAMP}] SKIP: multiagent session not found" | tee -a "$LOG_FILE"
    exit 0
fi

while IFS= read -r pane_id; do
    agent_cli=$(tmux display-message -t "multiagent:agents.${pane_id}" -p '#{@agent_cli}' 2>/dev/null || echo "")
    agent_id=$(tmux display-message -t "multiagent:agents.${pane_id}" -p '#{@agent_id}' 2>/dev/null || echo "pane${pane_id}")

    if [ "$agent_cli" != "codex" ]; then
        continue
    fi

    checked=$((checked + 1))
    capture=$(tmux capture-pane -t "multiagent:agents.${pane_id}" -p -S -100 2>/dev/null || echo "")

    if echo "$capture" | grep -qiE 'MCP startup interrupted|servers were not initialized|MCP server .+ failed|MCP connection .+ timed out'; then
        echo "[${TIMESTAMP}] ${agent_id} (codex): NG - MCP initialization error detected" | tee -a "$LOG_FILE"
        errors=$((errors + 1))
    else
        echo "[${TIMESTAMP}] ${agent_id} (codex): OK" | tee -a "$LOG_FILE"
    fi
done < <(tmux list-panes -t "multiagent:agents" -F '#{pane_index}' 2>/dev/null || true)

echo "[${TIMESTAMP}] Result: ${errors} errors found (checked ${checked} codex panes)" | tee -a "$LOG_FILE"

if [ "$errors" -gt 0 ]; then
    echo "⚠️ MCP Health Check: ${errors} error(s) detected. Run 'bash scripts/switch_cli.sh <agent>' to restart affected agents."
    exit 1
else
    echo "✅ MCP Health Check: All codex agents OK (${checked} checked)"
    exit 0
fi
