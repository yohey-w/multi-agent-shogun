#!/usr/bin/env bash
# PreToolUse hook: block dangerous rm -rf patterns (CLAUDE.md §7 D001-D002).
# Triggered for Bash tool invocations.
#
# Exit codes:
#   0 = allow
#   2 = block (stderr message shown to Claude/user)
#
# Stdin: JSON with at minimum {"tool_input": {"command": "..."}}

set -uo pipefail

input=$(cat)

# Extract the command being run
if command -v jq >/dev/null 2>&1; then
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // .input.command // ""' 2>/dev/null)
else
  # Fallback: naive grep (less precise but avoids hard dependency)
  cmd=$(printf '%s' "$input" | grep -o '"command":"[^"]*"' | head -1 | sed 's/"command":"//;s/"//')
fi

if [ -z "$cmd" ]; then
  # Not a Bash-style tool input we can inspect; allow through
  exit 0
fi

# Helper: does the command contain "rm" with recursive+force flags (in any order)?
# Matches: rm -rf, rm -fr, rm -Rf, rm -Rrf, rm -rRf --force, etc.
# Returns 0 (true) if rm with both r/R and f flags is present.
_has_rm_rf() {
  # Check for rm flag cluster containing both r (or R) and f
  printf '%s' "$1" | grep -qE 'rm[[:space:]]+-[a-zA-Z]*[rR][a-zA-Z]*f|rm[[:space:]]+-[a-zA-Z]*f[a-zA-Z]*[rR]'
}

# D001: block rm targeting known dangerous absolute destinations.
# Patterns match specific destinations only, not all absolute paths.
if _has_rm_rf "$cmd"; then
  # Check for filesystem root "/"
  if printf '%s' "$cmd" | grep -qE '[[:space:]]("|'"'"')?/([[:space:]"|'"'"']|$)'; then
    echo "BLOCKED (guard_rm): Destructive rm targeting filesystem root. Command: ${cmd:0:200}" >&2
    exit 2
  fi
  # Check for /mnt (D001)
  if printf '%s' "$cmd" | grep -qE '[[:space:]]("|'"'"')?/mnt([/[:space:]"|'"'"']|$)'; then
    echo "BLOCKED (guard_rm): Destructive rm targeting /mnt. Command: ${cmd:0:200}" >&2
    exit 2
  fi
  # Check for /home (D001)
  if printf '%s' "$cmd" | grep -qE '[[:space:]]("|'"'"')?/home([/[:space:]"|'"'"']|$)'; then
    echo "BLOCKED (guard_rm): Destructive rm targeting /home. Command: ${cmd:0:200}" >&2
    exit 2
  fi
  # Check for ~ or $HOME (D001)
  if printf '%s' "$cmd" | grep -qE '[[:space:]]("|'"'"')?~([/[:space:]"|'"'"']|$)'; then
    echo "BLOCKED (guard_rm): Destructive rm targeting home directory (~). Command: ${cmd:0:200}" >&2
    exit 2
  fi
  if printf '%s' "$cmd" | grep -qE '[[:space:]]("|'"'"')?\$HOME([/[:space:]"|'"'"']|$)'; then
    echo "BLOCKED (guard_rm): Destructive rm targeting \$HOME. Command: ${cmd:0:200}" >&2
    exit 2
  fi
fi

# D002: working-tree-external absolute path deletion
# Determine project root (env var takes priority, fallback to cwd)
project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Look for rm -rf patterns with an absolute path that is outside project_dir
# We only block if we detect rm -rf with an absolute path not under $project_dir
if printf '%s' "$cmd" | grep -qE 'rm[[:space:]]+-[a-zA-Z]*r[a-zA-Z]*f|rm[[:space:]]+-[a-zA-Z]*f[a-zA-Z]*r'; then
  # Extract all absolute paths from the command (simple heuristic: tokens starting with /)
  while IFS= read -r token; do
    # Skip flags (-rf, -fr, etc.) and empty
    [[ "$token" =~ ^- ]] && continue
    [[ -z "$token" ]] && continue
    # If it's an absolute path not inside project_dir, block
    if [[ "$token" == /* ]] && [[ "$token" != "${project_dir}"* ]]; then
      # Allow common safe temp paths
      case "$token" in
        /tmp/*|/var/tmp/*|/private/tmp/*)
          continue
          ;;
        *)
          echo "BLOCKED (guard_rm): rm targeting path outside project tree: ${token}. Project root: ${project_dir}" >&2
          exit 2
          ;;
      esac
    fi
  done < <(printf '%s' "$cmd" | tr ' ' '\n')
fi

exit 0
