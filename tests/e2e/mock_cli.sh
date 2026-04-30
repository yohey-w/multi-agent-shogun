#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# mock_cli.sh — Mock CLI for E2E testing
# ═══════════════════════════════════════════════════════════════
# Simulates CLI behavior (state transitions, YAML operations)
# without requiring real AI APIs.
#
# Environment variables:
#   MOCK_CLI_TYPE          — claude | codex (default: claude)
#   MOCK_PROCESSING_DELAY  — seconds to simulate processing (default: 2)
#   MOCK_AGENT_ID          — agent identifier (e.g., karo, ashigaru1)
#   MOCK_PROJECT_ROOT      — project root with queue/ directory
#
# State machine:
#   IDLE → (input received) → BUSY → (processing done) → IDLE
#
# Usage:
#   MOCK_AGENT_ID=ashigaru1 MOCK_CLI_TYPE=claude MOCK_PROJECT_ROOT=/tmp/e2e mock_cli.sh
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

# Ignore SIGINT — real CLIs handle C-c gracefully; mock must survive
# inbox_watcher sends C-c before /clear to clear stale input.
trap '' INT

MOCK_CLI_TYPE="${MOCK_CLI_TYPE:-claude}"
MOCK_PROCESSING_DELAY="${MOCK_PROCESSING_DELAY:-2}"
MOCK_AGENT_ID="${MOCK_AGENT_ID:-unknown}"
MOCK_PROJECT_ROOT="${MOCK_PROJECT_ROOT:-.}"

# Resolve script directory for behavior imports
MOCK_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$MOCK_SCRIPT_DIR/mock_behaviors/common.sh"
case "$MOCK_CLI_TYPE" in
    claude) source "$MOCK_SCRIPT_DIR/mock_behaviors/claude_behavior.sh" ;;
    codex)  source "$MOCK_SCRIPT_DIR/mock_behaviors/codex_behavior.sh" ;;
esac

# ─── State ───
STATE="idle"
# Paths mirror the real project structure: $PROJECT_ROOT/queue/{inbox,tasks,reports}
INBOX_FILE="$MOCK_PROJECT_ROOT/queue/inbox/${MOCK_AGENT_ID}.yaml"
TASK_FILE="$MOCK_PROJECT_ROOT/queue/tasks/${MOCK_AGENT_ID}.yaml"
REPORT_DIR="$MOCK_PROJECT_ROOT/queue/reports"

# ─── Startup ───
echo "[mock_cli] Starting as $MOCK_AGENT_ID (type=$MOCK_CLI_TYPE, delay=${MOCK_PROCESSING_DELAY}s)"

case "$MOCK_CLI_TYPE" in
    claude) claude_startup_banner ;;
    codex)  codex_startup_banner ;;
    *)      echo "Mock CLI ($MOCK_CLI_TYPE)" ;;
esac

# ─── Process a task from YAML ───
process_task() {
    local task_file="$1"

    if [ ! -f "$task_file" ]; then
        echo "[mock] No task file found: $task_file"
        return 1
    fi

    local task_id parent_cmd status
    task_id=$(yaml_read "$task_file" "task.task_id")
    parent_cmd=$(yaml_read "$task_file" "task.parent_cmd")
    status=$(yaml_read "$task_file" "task.status")

    if [ "$status" != "assigned" ] && [ "$status" != "in_progress" ]; then
        echo "[mock] Task $task_id status=$status — skipping"
        return 1
    fi

    STATE="busy"
    show_busy "$MOCK_CLI_TYPE" 0

    # 1. Update status to in_progress
    yaml_update "$task_file" "task.status" "in_progress"
    echo "[mock] Task $task_id → in_progress"

    # 2. Simulate processing delay
    local elapsed=0
    while [ "$elapsed" -lt "$MOCK_PROCESSING_DELAY" ]; do
        sleep 1
        elapsed=$((elapsed + 1))
        show_busy "$MOCK_CLI_TYPE" "$elapsed"
    done

    # 3. Write completion report
    write_mock_report "$MOCK_AGENT_ID" "$task_id" "$parent_cmd" "$MOCK_PROJECT_ROOT"
    echo "[mock] Report written for $task_id"

    # 4. Update status to done
    yaml_update "$task_file" "task.status" "done"
    echo "[mock] Task $task_id → done"

    # 5. Notify via inbox_write (prefer test copy, fallback to project's real script)
    local inbox_write_script="$MOCK_PROJECT_ROOT/scripts/inbox_write.sh"
    if [ ! -f "$inbox_write_script" ]; then
        inbox_write_script="$MOCK_SCRIPT_DIR/../../scripts/inbox_write.sh"
    fi
    if [ -f "$inbox_write_script" ]; then
        # Determine report target based on role
        local report_target="karo"
        if [ "$MOCK_AGENT_ID" = "karo" ]; then
            report_target="shogun"
        fi
        SCRIPT_DIR="$MOCK_PROJECT_ROOT" bash "$inbox_write_script" "$report_target" \
            "${MOCK_AGENT_ID}号、任務完了。報告YAML確認されたし。" \
            "report_received" "$MOCK_AGENT_ID" 2>/dev/null || true
    fi

    STATE="idle"
    return 0
}

# ─── Process inbox messages ───
process_inbox() {
    if [ ! -f "$INBOX_FILE" ]; then
        return 0
    fi

    local unread_count
    unread_count=$(inbox_unread_count "$INBOX_FILE")

    if [ "$unread_count" -eq 0 ] 2>/dev/null; then
        return 0
    fi

    STATE="busy"
    echo "[mock] Processing $unread_count unread inbox message(s)..."

    # Check for message types
    local msg_types
    msg_types=$(python3 -c "
import yaml
try:
    with open('$INBOX_FILE') as f:
        data = yaml.safe_load(f) or {}
    msgs = data.get('messages', [])
    unread = [m for m in msgs if not m.get('read', False)]
    types = set(m.get('type', '') for m in unread)
    print(' '.join(types))
except:
    pass
" 2>/dev/null)

    # Mark all inbox messages as read
    inbox_mark_all_read "$INBOX_FILE"
    echo "[mock] Inbox messages marked as read"

    # Handle message types
    if echo "$msg_types" | grep -q "task_assigned"; then
        echo "[mock] task_assigned detected — processing task"
        sleep 0.5
        process_task "$TASK_FILE" || true
    fi

    if echo "$msg_types" | grep -q "cmd_new"; then
        echo "[mock] cmd_new detected"
        if [ "$MOCK_AGENT_ID" = "karo" ]; then
            karo_decompose_cmd
        fi
    fi

    STATE="idle"
}

# ─── Handle /clear ───
handle_clear() {
    echo "[mock] /clear received"
    STATE="idle"

    # Re-check for assigned tasks
    if [ -f "$TASK_FILE" ]; then
        local status
        status=$(yaml_read "$TASK_FILE" "task.status")
        if [ "$status" = "assigned" ]; then
            echo "[mock] Found assigned task after /clear — processing"
            process_task "$TASK_FILE" || true
        fi
    fi

    show_prompt "$MOCK_CLI_TYPE"
}

# ─── Karo-specific: decompose cmd into subtasks ───
# When karo receives a cmd_new, it reads shogun_to_karo.yaml,
# creates task YAMLs for ashigaru, and sends inbox notifications.
karo_decompose_cmd() {
    local cmd_file="$MOCK_PROJECT_ROOT/queue/shogun_to_karo.yaml"
    if [ ! -f "$cmd_file" ]; then
        echo "[mock/karo] No cmd file found"
        return 1
    fi

    STATE="busy"
    show_busy "$MOCK_CLI_TYPE" 0

    local cmd_id cmd_description
    cmd_id=$(yaml_read "$cmd_file" "id") || cmd_id=$(yaml_read "$cmd_file" "commands.0.id") || cmd_id="cmd_unknown"
    cmd_description=$(yaml_read "$cmd_file" "description") || cmd_description=$(yaml_read "$cmd_file" "commands.0.description") || cmd_description="Unknown task"

    echo "[mock/karo] Decomposing cmd: $cmd_id"
    sleep "$MOCK_PROCESSING_DELAY"

    # Create subtask for ashigaru1
    local subtask_file="$MOCK_PROJECT_ROOT/queue/tasks/ashigaru1.yaml"
    local subtask_id="subtask_${cmd_id}_a"
    cat > "$subtask_file" <<EOF
task:
  task_id: "$subtask_id"
  parent_cmd: "$cmd_id"
  type: implementation
  description: |
    Subtask decomposed from $cmd_id by karo mock.
    Original: $cmd_description
  status: assigned
  timestamp: "$(date '+%Y-%m-%dT%H:%M:%S')"
EOF

    echo "[mock/karo] Created subtask: $subtask_id for ashigaru1"

    # Send task_assigned to ashigaru1 via inbox_write
    local inbox_write_script="$MOCK_PROJECT_ROOT/scripts/inbox_write.sh"
    if [ ! -f "$inbox_write_script" ]; then
        inbox_write_script="$MOCK_SCRIPT_DIR/../../scripts/inbox_write.sh"
    fi
    if [ -f "$inbox_write_script" ]; then
        bash "$inbox_write_script" "ashigaru1" \
            "タスクYAMLを読んで作業開始せよ。" "task_assigned" "karo" 2>/dev/null || true
        echo "[mock/karo] Sent task_assigned to ashigaru1"
    fi

    STATE="idle"
}

# ─── Main input loop ───
show_prompt "$MOCK_CLI_TYPE"

# Check for pre-existing assigned tasks on startup
if [ -f "$TASK_FILE" ]; then
    startup_status=$(yaml_read "$TASK_FILE" "task.status")
    if [ "$startup_status" = "assigned" ]; then
        echo "[mock] Pre-existing assigned task found on startup"
        process_task "$TASK_FILE" || true
        show_prompt "$MOCK_CLI_TYPE"
    fi
fi

while IFS= read -r input || true; do
    # Trim whitespace
    input=$(echo "$input" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Skip empty input
    [ -z "$input" ] && continue

    case "$input" in
        /new)
            # Codex /new: reset state but do NOT auto-process tasks.
            # Real Codex CLI loads AGENTS.md but does NOT trigger Session Start.
            # Task processing requires an explicit startup prompt from inbox_watcher.
            echo "[mock] /new received — conversation reset (no auto-task)"
            STATE="idle"
            show_prompt "$MOCK_CLI_TYPE"
            ;;
        /clear)
            # Claude /clear: auto-reload CLAUDE.md → triggers Session Start → processes tasks.
            handle_clear
            ;;
        "Session Start"*)
            # Codex startup prompt: triggers full recovery + task execution
            echo "[mock] Startup prompt received: ${input:0:60}..."
            # Check for assigned tasks (simulates Session Start procedure)
            # Note: no 'local' here — we're in main loop, not a function
            if [ -f "$TASK_FILE" ]; then
                sp_status=$(yaml_read "$TASK_FILE" "task.status")
                if [ "$sp_status" = "assigned" ]; then
                    echo "[mock] Session Start: found assigned task — processing"
                    process_inbox
                    process_task "$TASK_FILE" || true
                fi
            fi
            show_prompt "$MOCK_CLI_TYPE"
            ;;
        inbox*)
            # inbox nudge received (e.g., "inbox3")
            echo "[mock] Received nudge: $input"
            process_inbox
            show_prompt "$MOCK_CLI_TYPE"
            ;;
        cmd_new*)
            # Karo-specific: decompose cmd
            if [ "$MOCK_AGENT_ID" = "karo" ]; then
                karo_decompose_cmd
            fi
            show_prompt "$MOCK_CLI_TYPE"
            ;;
        busy_hold*)
            # E2E-004 testing: hold busy state for N seconds
            hold_time="${input#busy_hold }"
            hold_time="${hold_time:-10}"
            STATE="busy"
            held=0
            while [ "$held" -lt "$hold_time" ]; do
                show_busy "$MOCK_CLI_TYPE" "$held"
                sleep 1
                held=$((held + 1))
            done
            STATE="idle"
            show_prompt "$MOCK_CLI_TYPE"
            ;;
        *)
            # Generic input handling
            STATE="busy"
            show_busy "$MOCK_CLI_TYPE" 0
            sleep "$MOCK_PROCESSING_DELAY"
            echo "[mock] Processed input: $input"
            STATE="idle"
            show_prompt "$MOCK_CLI_TYPE"
            ;;
    esac
done
