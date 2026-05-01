#!/usr/bin/env bash
# UserPromptSubmit hook: inject dashboard summary + inbox counts as context.
# Runs before every user prompt. Must be fast (< 1 second ideal).
#
# Output: plain text (non-JSON stdout) → Claude receives it as additionalContext.
# Exit code: 0 always (non-blocking).
#
# Stdin: JSON (UserPromptSubmit) with fields: session_id, prompt, hook_event_name

set -uo pipefail

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"

dashboard="${project_dir}/dashboard.md"
inbox_dir="${project_dir}/queue/inbox"

# --------------------------------------------------------------------------
# Early exit: nothing useful to inject if neither source exists
# --------------------------------------------------------------------------
if [ ! -f "$dashboard" ] && [ ! -d "$inbox_dir" ]; then
  exit 0
fi

output=""

# --------------------------------------------------------------------------
# Dashboard: extract "In Progress" section (up to 20 lines)
# --------------------------------------------------------------------------
if [ -f "$dashboard" ]; then
  # Extract lines from "## In Progress" until the next "## " heading
  in_progress=$(awk '/^## In Progress/{found=1; next} found && /^## /{exit} found{print}' "$dashboard" 2>/dev/null | head -20)
  if [ -n "$in_progress" ]; then
    output+="### Dashboard: In Progress
${in_progress}
"
  fi
fi

# --------------------------------------------------------------------------
# Inbox: count unread YAML files per role
# --------------------------------------------------------------------------
if [ -d "$inbox_dir" ]; then
  inbox_summary=""
  for yaml_file in "${inbox_dir}"/*.yaml "${inbox_dir}"/*.yml; do
    [ -f "$yaml_file" ] || continue
    role=$(basename "$yaml_file" | sed 's/\.\(yaml\|yml\)$//')
    # Count items: lines starting with "- " (YAML list items) as a proxy
    count=$(grep -c '^- ' "$yaml_file" 2>/dev/null || echo 0)
    if [ "$count" -gt 0 ]; then
      inbox_summary+="  - ${role}: ${count} item(s)
"
    fi
  done

  if [ -n "$inbox_summary" ]; then
    output+="### Inbox (unread)
${inbox_summary}"
  fi
fi

# --------------------------------------------------------------------------
# Only print if there is something meaningful
# --------------------------------------------------------------------------
if [ -n "$output" ]; then
  printf '%s\n' "--- Context injected by inject_dashboard.sh ---"
  printf '%s' "$output"
  printf '%s\n' "--- End of injected context ---"
fi

exit 0
