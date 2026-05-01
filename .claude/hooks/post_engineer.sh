#!/usr/bin/env bash
# SubagentStop hook: memory curation trigger + dashboard update.
# Called when a subagent (engineer, reviewer, etc.) finishes.
#
# Responsibilities:
#   1. If memory/<agent>.md > 200 lines, emit a reminder to curate it
#   2. Log completion of the subagent to a simple audit log
#   3. Update dashboard.md timestamp (lightweight — no heavy processing)
#
# Exit code: always 0 (non-blocking). This hook must not delay the parent session.
#
# Stdin: JSON (SubagentStop) with fields:
#   session_id, hook_event_name, agent_id?, subagent_id?, cwd, transcript_path

set -uo pipefail

input=$(cat)

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Extract agent name from JSON input
agent_name=""
if command -v jq >/dev/null 2>&1; then
  agent_name=$(printf '%s' "$input" | jq -r '.agent_name // .subagent_name // .agent_id // ""' 2>/dev/null)
fi

# Fallback: CLAUDE_AGENT_NAME env
if [ -z "$agent_name" ] && [ -n "${CLAUDE_AGENT_NAME:-}" ]; then
  agent_name="$CLAUDE_AGENT_NAME"
fi

# --------------------------------------------------------------------------
# 1. Memory curation reminder
# --------------------------------------------------------------------------
if [ -n "$agent_name" ]; then
  mem_file="${project_dir}/memory/${agent_name}.md"
  if [ -f "$mem_file" ]; then
    line_count=$(wc -l < "$mem_file" 2>/dev/null || echo 0)
    if [ "$line_count" -gt 200 ]; then
      # Emit as additionalContext so Claude sees it after subagent completes
      cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SubagentStop",
    "additionalContext": "MEMORY CURATION NEEDED: memory/${agent_name}.md has ${line_count} lines (> 200 limit). Please run /memory-curate or manually trim memory/${agent_name}.md to under 200 lines."
  }
}
EOF
      exit 0
    fi
  fi
fi

# --------------------------------------------------------------------------
# 2. Lightweight completion audit log
# --------------------------------------------------------------------------
log_dir="${project_dir}/.claude/logs"
mkdir -p "$log_dir" 2>/dev/null || true

log_file="${log_dir}/subagent_completions.log"
timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo "unknown-time")
agent_label="${agent_name:-unknown}"

printf '%s\t%s\tcompleted\n' "$timestamp" "$agent_label" >> "$log_file" 2>/dev/null || true

# --------------------------------------------------------------------------
# 3. Touch dashboard.md last-updated line (non-blocking best-effort)
# --------------------------------------------------------------------------
dashboard="${project_dir}/dashboard.md"
if [ -f "$dashboard" ] && command -v sed >/dev/null 2>&1; then
  today=$(date '+%Y-%m-%d' 2>/dev/null || echo "")
  if [ -n "$today" ]; then
    # Update the "Last updated:" line if present (in-place, macOS + Linux compatible)
    sed -i.bak "s/^Last updated: .*/Last updated: ${today} (auto)/" "$dashboard" 2>/dev/null && \
      rm -f "${dashboard}.bak" 2>/dev/null || true
  fi
fi

exit 0
