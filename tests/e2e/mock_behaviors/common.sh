#!/usr/bin/env bash
# common.sh — Mock CLI common functions (shared across all CLI types)
# Provides YAML read/write, state transitions, and report generation.

set -euo pipefail

# ─── YAML helpers (python3-yaml based) ───

# Read a YAML field value
# Usage: yaml_read <file> <dotted.key.path>
yaml_read() {
    local file="$1" key_path="$2"
    local result
    result=$(python3 -c "
import yaml, sys
try:
    with open('$file') as f:
        data = yaml.safe_load(f) or {}
    keys = '$key_path'.split('.')
    val = data
    for k in keys:
        if isinstance(val, dict):
            val = val.get(k)
        elif isinstance(val, list) and k.isdigit():
            idx = int(k)
            val = val[idx] if idx < len(val) else None
        else:
            val = None
            break
    if val is not None:
        print(val)
        sys.exit(0)
    else:
        sys.exit(1)
except Exception:
    sys.exit(1)
" 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$result" ]; then
        echo "$result"
        return 0
    fi
    return 1
}

# Update a YAML field value (atomic write with flock)
# Usage: yaml_update <file> <dotted.key.path> <value>
yaml_update() {
    local file="$1" key_path="$2" value="$3"
    local lockfile="${file}.lock"

    (
        flock -w 5 200 || { echo "[mock] flock timeout on $file" >&2; return 1; }
        python3 -c "
import yaml, os, tempfile
try:
    with open('$file') as f:
        data = yaml.safe_load(f) or {}
    keys = '$key_path'.split('.')
    obj = data
    for k in keys[:-1]:
        if k not in obj or not isinstance(obj[k], dict):
            obj[k] = {}
        obj = obj[k]
    # Type coercion for common values
    val = '$value'
    if val == 'true': val = True
    elif val == 'false': val = False
    elif val.isdigit(): val = int(val)
    obj[keys[-1]] = val
    tmp_fd, tmp_path = tempfile.mkstemp(dir=os.path.dirname('$file'), suffix='.tmp')
    with os.fdopen(tmp_fd, 'w') as f:
        yaml.dump(data, f, default_flow_style=False, allow_unicode=True, indent=2)
    os.replace(tmp_path, '$file')
except Exception as e:
    print(f'yaml_update error: {e}', file=__import__('sys').stderr)
" 2>/dev/null
    ) 200>"$lockfile"
}

# Mark all inbox messages as read
# Usage: inbox_mark_all_read <inbox_file>
inbox_mark_all_read() {
    local inbox_file="$1"
    local lockfile="${inbox_file}.lock"

    (
        flock -w 5 200 || return 1
        python3 -c "
import yaml, os, tempfile
try:
    with open('$inbox_file') as f:
        data = yaml.safe_load(f) or {}
    for m in data.get('messages', []):
        m['read'] = True
    tmp_fd, tmp_path = tempfile.mkstemp(dir=os.path.dirname('$inbox_file'), suffix='.tmp')
    with os.fdopen(tmp_fd, 'w') as f:
        yaml.dump(data, f, default_flow_style=False, allow_unicode=True, indent=2)
    os.replace(tmp_path, '$inbox_file')
except Exception as e:
    print(f'inbox_mark_all_read error: {e}', file=__import__('sys').stderr)
" 2>/dev/null
    ) 200>"$lockfile"
}

# Get count of unread inbox messages
# Usage: inbox_unread_count <inbox_file>
inbox_unread_count() {
    local inbox_file="$1"
    grep -c 'read: false' "$inbox_file" 2>/dev/null || echo 0
}

# Write a mock completion report
# Usage: write_mock_report <agent_id> <task_id> <parent_cmd> <project_root>
write_mock_report() {
    local agent_id="$1"
    local task_id="$2"
    local parent_cmd="$3"
    local project_root="$4"
    local report_file="$project_root/queue/reports/${agent_id}_report.yaml"
    local timestamp
    timestamp=$(date "+%Y-%m-%dT%H:%M:%S")

    cat > "$report_file" <<EOF
worker_id: "$agent_id"
task_id: "$task_id"
parent_cmd: "$parent_cmd"
timestamp: "$timestamp"
status: done
result:
  type: mock_completion
  summary: "Mock task completed successfully"
  files_modified: []
  notes: "Completed by mock_cli.sh"
skill_candidate:
  found: false
EOF
}

# Show mock CLI prompt (idle state indicator)
# Usage: show_prompt <cli_type>
#
# For Claude CLI: creates the idle flag file to simulate Claude Code's Stop hook.
# inbox_watcher uses flag-file-based busy detection for Claude; without this,
# the watcher always sees the mock as "busy" and never sends nudges.
show_prompt() {
    local cli_type="${1:-claude}"
    # Simulate Stop hook: create idle flag when Claude mock becomes idle
    if [[ "${MOCK_CLI_TYPE:-claude}" == "claude" ]] && [[ -n "${MOCK_AGENT_ID:-}" ]]; then
        local _flag_dir="${IDLE_FLAG_DIR:-/tmp}"
        touch "${_flag_dir}/shogun_idle_${MOCK_AGENT_ID}" 2>/dev/null || true
    fi
    case "$cli_type" in
        claude) echo -e "\n\$ " ;;
        codex)  echo -e "\n? for shortcuts                100% context left\n\$ " ;;
        *)      echo -e "\n\$ " ;;
    esac
}

# Show mock CLI busy indicator
# Usage: show_busy <cli_type> <seconds>
#
# For Claude CLI: removes the idle flag file to simulate the agent being busy.
show_busy() {
    local cli_type="${1:-claude}"
    local seconds="${2:-0}"
    # Simulate Stop hook: remove idle flag when Claude mock starts processing
    if [[ "${MOCK_CLI_TYPE:-claude}" == "claude" ]] && [[ -n "${MOCK_AGENT_ID:-}" ]]; then
        local _flag_dir="${IDLE_FLAG_DIR:-/tmp}"
        rm -f "${_flag_dir}/shogun_idle_${MOCK_AGENT_ID}" 2>/dev/null || true
    fi
    case "$cli_type" in
        claude) echo "Working on task (${seconds}s • esc to interrupt)" ;;
        codex)  echo "Thinking about approach (${seconds}s • esc to interrupt)" ;;
        *)      echo "Processing... (${seconds}s)" ;;
    esac
}
