#!/usr/bin/env bash
# PreToolUse hook: block Edit/Write to paths outside the project directory.
# Matcher: "Edit|Write" (configured in settings.json)
#
# Exit codes:
#   0 = allow
#   2 = block (stderr message shown to Claude/user)
#
# Stdin: JSON with at minimum {"tool_input": {"file_path": "..."}}

set -uo pipefail

input=$(cat)

# Extract file_path from tool input
if command -v jq >/dev/null 2>&1; then
  file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .input.file_path // ""' 2>/dev/null)
else
  file_path=$(printf '%s' "$input" | grep -o '"file_path":"[^"]*"' | head -1 | sed 's/"file_path":"//;s/"//')
fi

if [ -z "$file_path" ]; then
  # No file_path field; allow (e.g. MultiEdit uses a different structure)
  exit 0
fi

# Resolve project root
project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
# Normalize project_dir (remove trailing slash)
project_dir="${project_dir%/}"

# Expand ~ in file_path
if [[ "$file_path" == "~/"* ]]; then
  file_path="${HOME}/${file_path:2}"
fi

# Resolve absolute path without requiring the file to exist
# Use python3 for reliable path normalization
if command -v python3 >/dev/null 2>&1; then
  abs_path=$(python3 -c "import os, sys; print(os.path.normpath(os.path.join('${project_dir}', sys.argv[1])))" "$file_path" 2>/dev/null)
else
  # Fallback: if already absolute, use as-is; else prepend project_dir
  if [[ "$file_path" == /* ]]; then
    abs_path="$file_path"
  else
    abs_path="${project_dir}/${file_path}"
  fi
fi

# Explicit allow-list for paths outside the project that are legitimate
ALLOWED_PREFIXES=(
  "${HOME}/.claude/agents/"
  "${HOME}/.claude/CLAUDE.md"
  "${HOME}/.claude/settings.json"
  "/tmp/claude/"
  "/var/tmp/claude/"
  "/private/tmp/claude/"
)

for allowed in "${ALLOWED_PREFIXES[@]}"; do
  if [[ "$abs_path" == "${allowed}"* || "$abs_path" == "$allowed" ]]; then
    exit 0
  fi
done

# Check if the path is inside the project directory
if [[ "$abs_path" != "${project_dir}"* ]]; then
  echo "BLOCKED (guard_outside_project): Attempted Edit/Write to path outside project directory." >&2
  echo "  Target:  ${abs_path}" >&2
  echo "  Project: ${project_dir}" >&2
  echo "If this is intentional, please confirm with the user before proceeding." >&2
  exit 2
fi

exit 0
