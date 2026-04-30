#!/usr/bin/env bats
# test_idle_flag.bats — idle flag file system unit tests
#
# Tests for cmd_222: フラグファイル方式 idle/busy検知
#
# テスト構成:
#   T-001: unread=0時にフラグファイルが作成される (stop_hook exit 0後)
#   T-002: unread>0時にフラグファイルが削除される (stop_hook block後)
#   T-003: agent_is_busy() フラグなし時にtrue (return 0) — claude CLI
#   T-004: agent_is_busy() フラグあり時にfalse (return 1) — claude CLI
#   T-005: agent_is_busy() 非Claude CLI時にpane解析フォールバック
#   T-006: stop_hook_active=True時にもフラグが作成される (C-001修正)
#   T-007: /clear cooldown (LAST_CLEAR_TS) がフラグより優先される (return 0)
#   T-008: nudge送信後にフラグが削除される
#   T-009: shutsujin時 (rm -f /tmp/shogun_idle_*) で全フラグがクリアされる

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
HOOK_SCRIPT="$SCRIPT_DIR/scripts/stop_hook_inbox.sh"
WATCHER_SCRIPT="$SCRIPT_DIR/scripts/inbox_watcher.sh"

setup_file() {
    export PROJECT_ROOT="$SCRIPT_DIR"
    export VENV_PYTHON="$PROJECT_ROOT/.venv/bin/python3"
    [ -f "$HOOK_SCRIPT" ] || return 1
    [ -f "$WATCHER_SCRIPT" ] || return 1
    "$VENV_PYTHON" -c "import yaml" 2>/dev/null || return 1
}

setup() {
    export IDLE_FLAG_DIR="$(mktemp -d "$BATS_TMPDIR/idle_flag_test.XXXXXX")"
    export TEST_HOOK_TMP="$(mktemp -d "$BATS_TMPDIR/hook_tmp.XXXXXX")"

    # Mock inbox_write.sh
    mkdir -p "$TEST_HOOK_TMP/scripts"
    cat > "$TEST_HOOK_TMP/scripts/inbox_write.sh" << 'MOCK'
#!/bin/bash
echo "$@" >> "$(dirname "$0")/../inbox_write_calls.log"
MOCK
    chmod +x "$TEST_HOOK_TMP/scripts/inbox_write.sh"

    mkdir -p "$TEST_HOOK_TMP/queue/inbox"

    # Build test harness for inbox_watcher.sh functions
    export WATCHER_HARNESS="$IDLE_FLAG_DIR/watcher_harness.sh"
    export MOCK_LOG="$IDLE_FLAG_DIR/tmux_calls.log"
    > "$MOCK_LOG"

    export MOCK_PGREP="$IDLE_FLAG_DIR/mock_pgrep"
    cat > "$MOCK_PGREP" << 'MOCK'
#!/bin/bash
exit 1
MOCK
    chmod +x "$MOCK_PGREP"

    export MOCK_CAPTURE_PANE=""
    export MOCK_PANE_CLI=""

    cat > "$WATCHER_HARNESS" << HARNESS
#!/bin/bash
AGENT_ID="test_idle_agent"
PANE_TARGET="test:0.0"
CLI_TYPE="claude"
INBOX="$TEST_HOOK_TMP/queue/inbox/test_idle_agent.yaml"
LOCKFILE="\${INBOX}.lock"
SCRIPT_DIR="$PROJECT_ROOT"
export IDLE_FLAG_DIR="$IDLE_FLAG_DIR"

tmux() {
    echo "tmux \$*" >> "$MOCK_LOG"
    if echo "\$*" | grep -q "capture-pane"; then
        echo "\${MOCK_CAPTURE_PANE:-}"
        return 0
    fi
    if echo "\$*" | grep -q "send-keys"; then
        return \${MOCK_SENDKEYS_RC:-0}
    fi
    if echo "\$*" | grep -q "show-options"; then
        echo "\${MOCK_PANE_CLI:-}"
        return 0
    fi
    if echo "\$*" | grep -q "list-clients"; then
        [ -n "\${MOCK_LIST_CLIENTS:-}" ] && echo "\$MOCK_LIST_CLIENTS"
        return 0
    fi
    if echo "\$*" | grep -q "display-message"; then
        echo "mock_session"
        return 0
    fi
    return 0
}
timeout() { shift; "\$@"; }
pgrep() { "$MOCK_PGREP" "\$@"; }
sleep() { :; }
export -f tmux timeout pgrep sleep

export __INBOX_WATCHER_TESTING__=1
source "$WATCHER_SCRIPT"
HARNESS
    chmod +x "$WATCHER_HARNESS"
}

teardown() {
    rm -rf "$IDLE_FLAG_DIR" "$TEST_HOOK_TMP"
}

# Helper: run stop_hook with given JSON and agent_id
run_hook() {
    local json="$1"
    local agent_id="${2:-test_idle_agent}"
    IDLE_FLAG_DIR="$IDLE_FLAG_DIR" \
    __STOP_HOOK_SCRIPT_DIR="$TEST_HOOK_TMP" \
    __STOP_HOOK_AGENT_ID="$agent_id" \
    run bash "$HOOK_SCRIPT" <<< "$json"
}

# ─── T-001: unread=0時にフラグ作成 ───

@test "T-001: stop_hook creates idle flag when unread=0" {
    # Empty inbox (no unread)
    cat > "$TEST_HOOK_TMP/queue/inbox/test_idle_agent.yaml" << 'YAML'
messages:
- content: old message
  from: karo
  id: msg_001
  read: true
  timestamp: '2026-01-01T00:00:00'
  type: task_assigned
YAML

    run_hook '{"stop_hook_active": false, "last_assistant_message": ""}'
    [ "$status" -eq 0 ]

    # Flag file should be created
    [ -f "$IDLE_FLAG_DIR/shogun_idle_test_idle_agent" ]
}

# ─── T-002: unread>0時にフラグ保持（v4.0.1 rm -f廃止） ───

@test "T-002: stop_hook preserves idle flag when unread>0" {
    # Pre-create the flag (agent was idle)
    touch "$IDLE_FLAG_DIR/shogun_idle_test_idle_agent"

    # Inbox with unread message
    cat > "$TEST_HOOK_TMP/queue/inbox/test_idle_agent.yaml" << 'YAML'
messages:
- content: new task
  from: karo
  id: msg_002
  read: false
  timestamp: '2026-01-01T00:00:00'
  type: task_assigned
YAML

    run_hook '{"stop_hook_active": false, "last_assistant_message": ""}'
    # Status is non-zero (blocked) — that's expected for unread
    # v4.0.1: Flag must NOT be removed (rm -f廃止). Flag persists so
    # watcher can detect idle and send nudge without deadlock.
    [ -f "$IDLE_FLAG_DIR/shogun_idle_test_idle_agent" ]
}

# ─── T-003: agent_is_busy() フラグなし時にtrue (busy) ───

@test "T-003: agent_is_busy returns 0 (busy) when no flag file — claude CLI" {
    # Ensure no flag file
    rm -f "$IDLE_FLAG_DIR/shogun_idle_test_idle_agent"

    run bash -c "
        source '$WATCHER_HARNESS'
        LAST_CLEAR_TS=0
        CLI_TYPE='claude'
        agent_is_busy
    "
    [ "$status" -eq 0 ]  # 0 = busy
}

# ─── T-004: agent_is_busy() フラグあり時にfalse (idle) ───

@test "T-004: agent_is_busy returns 1 (idle) when flag file exists — claude CLI" {
    # Create idle flag
    touch "$IDLE_FLAG_DIR/shogun_idle_test_idle_agent"

    run bash -c "
        source '$WATCHER_HARNESS'
        LAST_CLEAR_TS=0
        CLI_TYPE='claude'
        agent_is_busy
    "
    [ "$status" -eq 1 ]  # 1 = idle
}

# ─── T-005: 非Claude CLI時にpane解析フォールバック ───

@test "T-005: agent_is_busy uses pane fallback for non-claude CLI" {
    # Create idle flag (would return idle for claude, but codex ignores it)
    touch "$IDLE_FLAG_DIR/shogun_idle_test_idle_agent"

    # Codex CLI with "Working" pane → pane-based detection → busy
    run bash -c "
        MOCK_CAPTURE_PANE='◦ Working on task (5s • esc to interrupt)'
        source '$WATCHER_HARNESS'
        LAST_CLEAR_TS=0
        CLI_TYPE='codex'
        agent_is_busy
    "
    [ "$status" -eq 0 ]  # 0 = busy (from pane detection)
}

# ─── T-006: stop_hook_active=True時にもフラグ作成 (C-001修正) ───

@test "T-006: stop_hook creates idle flag even when stop_hook_active=True" {
    # Empty inbox
    cat > "$TEST_HOOK_TMP/queue/inbox/test_idle_agent.yaml" << 'YAML'
messages: []
YAML

    run_hook '{"stop_hook_active": true, "last_assistant_message": ""}'
    [ "$status" -eq 0 ]

    # Flag should be created even in stop_hook_active=True path
    [ -f "$IDLE_FLAG_DIR/shogun_idle_test_idle_agent" ]
}

# ─── T-007: /clear cooldown (LAST_CLEAR_TS) がフラグより優先 ───

@test "T-007: /clear cooldown overrides idle flag (returns busy)" {
    # Create idle flag
    touch "$IDLE_FLAG_DIR/shogun_idle_test_idle_agent"

    run bash -c "
        source '$WATCHER_HARNESS'
        CLI_TYPE='claude'
        now=\$(date +%s)
        LAST_CLEAR_TS=\$((now - 10))  # /clear sent 10s ago (within 30s cooldown)
        agent_is_busy
    "
    [ "$status" -eq 0 ]  # 0 = busy (cooldown overrides idle flag)
}

# ─── T-008: nudge送信後もフラグ保持 (v4.0.1 cc234ed設計) ───

@test "T-008: send_wakeup preserves idle flag after sending nudge (v4.0.1)" {
    # Create idle flag (agent was idle)
    touch "$IDLE_FLAG_DIR/shogun_idle_test_idle_agent"

    run bash -c "
        source '$WATCHER_HARNESS'
        LAST_CLEAR_TS=0
        send_wakeup 1
    "
    [ "$status" -eq 0 ]

    # Nudge was sent (send-keys)
    grep -q "send-keys.*inbox1" "$MOCK_LOG"

    # Flag should be PRESERVED after nudge (v4.0.1 design: cc234ed)
    # Removing flag here causes: agent_is_busy()=true → no further nudges → deadlock.
    # Flag is removed by stop_hook when agent actually goes idle (natural lifecycle).
    [ -f "$IDLE_FLAG_DIR/shogun_idle_test_idle_agent" ]
}

# ─── T-009: shutsujin時に全フラグクリア ───

@test "T-009: rm -f flag_dir/shogun_idle_* clears all idle flags" {
    # Create multiple idle flags (simulate multiple agents)
    touch "$IDLE_FLAG_DIR/shogun_idle_karo"
    touch "$IDLE_FLAG_DIR/shogun_idle_ashigaru1"
    touch "$IDLE_FLAG_DIR/shogun_idle_ashigaru2"
    touch "$IDLE_FLAG_DIR/shogun_idle_gunshi"

    # Verify they exist
    [ -f "$IDLE_FLAG_DIR/shogun_idle_karo" ]
    [ -f "$IDLE_FLAG_DIR/shogun_idle_ashigaru1" ]

    # Simulate shutsujin flag clear (pattern: rm -f /tmp/shogun_idle_*)
    rm -f "$IDLE_FLAG_DIR"/shogun_idle_*

    # All flags cleared
    [ ! -f "$IDLE_FLAG_DIR/shogun_idle_karo" ]
    [ ! -f "$IDLE_FLAG_DIR/shogun_idle_ashigaru1" ]
    [ ! -f "$IDLE_FLAG_DIR/shogun_idle_ashigaru2" ]
    [ ! -f "$IDLE_FLAG_DIR/shogun_idle_gunshi" ]
}
