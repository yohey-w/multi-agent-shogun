#!/usr/bin/env bats
# test_send_wakeup.bats — send_wakeup() unit tests
# Sources the REAL inbox_watcher.sh with __INBOX_WATCHER_TESTING__=1
# to test actual production functions with mocked externals (tmux, pgrep, etc).
#
# テスト構成:
#   T-SW-001: send_wakeup — active self-watch → skip nudge
#   T-SW-002: send_wakeup — no self-watch → tmux send-keys
#   T-SW-003: send_wakeup — send-keys content is "inboxN" + Enter (separated)
#   T-SW-004: send_wakeup — send-keys failure → return 1
#   T-SW-005: send_wakeup — no paste-buffer or set-buffer used
#   T-SW-006: agent_has_self_watch — detects inotifywait process
#   T-SW-007: agent_has_self_watch — no inotifywait → returns 1
#   T-SW-008: send_cli_command — /clear uses send-keys
#   T-SW-009: send_cli_command — /model uses send-keys
#   T-SW-010: nudge content format — inboxN (backward compatible)
#   T-SW-011: inbox_watcher.sh uses send-keys, functions exist
#   T-ESC-001: escalation — no unread → FIRST_UNREAD_SEEN stays 0
#   T-ESC-002: escalation — unread < 2min → standard nudge
#   T-ESC-003: escalation — unread 2-4min → Escape+nudge
#   T-ESC-004: escalation — unread > 4min → /clear sent
#   T-ESC-005: escalation — /clear cooldown → falls back to Escape+nudge
#   T-BUSY-001: agent_is_busy — detects "Working" in pane
#   T-BUSY-002: agent_is_busy — idle pane returns 1
#   T-BUSY-003: send_wakeup — skips when agent is busy
#   T-BUSY-004: send_wakeup_with_escape — skips when agent is busy
#   T-CODEX-001: send_cli_command — codex /clear → /new conversion
#   T-CODEX-002: send_cli_command — codex /model → skip
#   T-CODEX-003: C-u sent when unread=0 and agent is idle
#   T-CODEX-004: C-u NOT sent when agent is busy
#   T-CODEX-005: send_cli_command — claude /clear passes through as-is
#   T-CODEX-006: inbox_watcher.sh has agent_is_busy and Codex/Copilot handlers
#   T-CODEX-007: pane @agent_cli=codex overrides stale CLI_TYPE (Phase2 C-c抑止)
#   T-CODEX-008: pane @agent_cli=codex overrides stale CLI_TYPE (/clear→/new)
#   T-CODEX-009: normalize_special_command rejects invalid model_switch payload
#   T-CODEX-010: unresolved CLI type falls back to codex-safe path
#   T-CODEX-011: clear_command処理でauto-recovery task_assignedを自動投入
#   T-CODEX-012: auto-recovery task_assignedは重複投入しない
#   T-SHOGUN-001: session_has_client — returns 0 when client attached
#   T-SHOGUN-002: session_has_client — returns 1 when no client
#   T-SHOGUN-003: send_wakeup — shogun + active + attached → display-message only
#   T-SHOGUN-004: send_wakeup — shogun + active + detached → send-keys fallthrough
#   T-BUSY-005: agent_is_busy — returns busy during /clear cooldown (LAST_CLEAR_TS)
#   T-BUSY-006: agent_is_busy — returns idle after /clear cooldown expires
#   T-BUSY-007: agent_is_busy — /clear cooldown overrides idle pane
#   T-BUSY-008: agent_is_busy — idle prompt at bottom overrides old busy markers (false-busy fix)
#   T-BUSY-009: agent_is_busy — 'background terminal running' detected as busy
#   T-BUSY-010: agent_is_busy — 'Compacting conversation' detected as busy
#   T-BUSY-011: agent_is_busy — 'esc to interrupt' alone detected as busy
#   T-SHOOK-001: Claude Code throttle uses 300s cooldown (stop-hook-primary)
#   T-SHOOK-002: Claude Code throttle ignores count changes (stop-hook-primary)
#   T-SHOOK-003: Non-Claude CLIs still bypass throttle on count change
#   T-CRESET-001: send_context_reset — suppresses /clear for karo
#   T-CRESET-002: send_context_reset — suppresses /clear for gunshi
#   T-CRESET-003: send_context_reset — sends /clear for ashigaru
#   T-COPILOT-001: send_cli_command — copilot /clear → Ctrl-C + restart
#   T-COPILOT-002: send_cli_command — copilot /model → skip

# --- セットアップ ---

setup_file() {
    export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export WATCHER_SCRIPT="$PROJECT_ROOT/scripts/inbox_watcher.sh"
    export VENV_PYTHON="$PROJECT_ROOT/.venv/bin/python3"
    [ -f "$WATCHER_SCRIPT" ] || return 1
    "$VENV_PYTHON" -c "import yaml" 2>/dev/null || return 1
}

setup() {
    export TEST_TMPDIR="$(mktemp -d "$BATS_TMPDIR/send_wakeup_test.XXXXXX")"

    # Log file for tmux mock calls (all tmux invocations recorded here)
    export MOCK_LOG="$TEST_TMPDIR/tmux_calls.log"
    > "$MOCK_LOG"

    # Create mock pgrep (default: no self-watch found)
    export MOCK_PGREP="$TEST_TMPDIR/mock_pgrep"
    cat > "$MOCK_PGREP" << 'MOCK'
#!/bin/bash
exit 1
MOCK
    chmod +x "$MOCK_PGREP"

    # Create test inbox directory
    export TEST_INBOX_DIR="$TEST_TMPDIR/queue/inbox"
    mkdir -p "$TEST_INBOX_DIR"

    # Default mock control variables
    export MOCK_CAPTURE_PANE=""
    export MOCK_SENDKEYS_RC=0
    export MOCK_PANE_CLI=""
    export MOCK_PANE_ACTIVE=""
    export MOCK_LIST_CLIENTS=""

    # Test harness: sets up mocks, then sources the REAL inbox_watcher.sh
    # __INBOX_WATCHER_TESTING__=1 skips arg parsing, inotifywait check, and main loop.
    # Only function definitions are loaded — testing actual production code.
    export TEST_HARNESS="$TEST_TMPDIR/test_harness.sh"
    cat > "$TEST_HARNESS" << HARNESS
#!/bin/bash
# Variables required by inbox_watcher.sh functions
AGENT_ID="test_agent"
PANE_TARGET="test:0.0"
CLI_TYPE="claude"
INBOX="$TEST_INBOX_DIR/test_agent.yaml"
LOCKFILE="\${INBOX}.lock"
SCRIPT_DIR="$PROJECT_ROOT"

# Mock external commands (defined before sourcing so they override real commands)
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
        if echo "\$*" | grep -q "pane_active"; then
            echo "\${MOCK_PANE_ACTIVE:-0}"
        else
            echo "mock_session"
        fi
        return 0
    fi
    return 0
}
timeout() { shift; "\$@"; }
pgrep() { "$MOCK_PGREP" "\$@"; }
sleep() { :; }
export -f tmux timeout pgrep sleep

# Source the REAL inbox_watcher.sh (testing guard skips startup & main loop)
export __INBOX_WATCHER_TESTING__=1
source "$WATCHER_SCRIPT"
HARNESS
    chmod +x "$TEST_HARNESS"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

# --- T-SW-001: self-watch active → skip nudge ---

@test "T-SW-001: send_wakeup skips nudge when agent has active self-watch" {
    cat > "$MOCK_PGREP" << 'MOCK'
#!/bin/bash
echo "12345 inotifywait -q -t 120 -e modify inbox/test_agent.yaml"
exit 0
MOCK
    chmod +x "$MOCK_PGREP"

    run bash -c "source '$TEST_HARNESS' && send_wakeup 3"
    [ "$status" -eq 0 ]

    # No nudge send-keys should have occurred
    ! grep -q "send-keys.*inbox" "$MOCK_LOG"

    echo "$output" | grep -q "SKIP"
}

# --- T-SW-002: no self-watch → tmux send-keys ---

@test "T-SW-002: send_wakeup uses tmux send-keys when no self-watch" {
    run bash -c "source '$TEST_HARNESS' && send_wakeup 5"
    [ "$status" -eq 0 ]

    # Verify send-keys occurred with inbox5
    grep -q "send-keys.*inbox5" "$MOCK_LOG"
    # Verify Enter was sent (as separate call — Codex TUI compatibility)
    grep -q "send-keys.*Enter" "$MOCK_LOG"
}

# --- T-SW-003: send-keys content is "inboxN" + Enter (separated) ---

@test "T-SW-003: send-keys sends inboxN and Enter as separate calls" {
    run bash -c "source '$TEST_HARNESS' && send_wakeup 3"
    [ "$status" -eq 0 ]

    # Text and Enter are sent as separate send-keys calls (Codex TUI compatibility)
    grep -q "send-keys -t test:0.0 inbox3" "$MOCK_LOG"
    grep -q "send-keys -t test:0.0 Enter" "$MOCK_LOG"
}

# --- T-SW-004: send-keys failure → return 0 (daemon-safe) + WARNING log ---
# send_wakeup always returns 0 to avoid killing the watcher under set -euo pipefail.

@test "T-SW-004: send_wakeup returns 0 when send-keys fails (daemon-safe)" {
    run bash -c "MOCK_SENDKEYS_RC=1; source '$TEST_HARNESS' && send_wakeup 2"
    [ "$status" -eq 0 ]

    echo "$output" | grep -qi "WARNING\|failed"
}

# --- T-SW-005: no paste-buffer or set-buffer used ---

@test "T-SW-005: nudge delivery does NOT use paste-buffer or set-buffer" {
    run bash -c "source '$TEST_HARNESS' && send_wakeup 3"
    [ "$status" -eq 0 ]

    # These should never be used
    ! grep -q "paste-buffer" "$MOCK_LOG"
    ! grep -q "set-buffer" "$MOCK_LOG"

    # send-keys IS expected
    grep -q "send-keys" "$MOCK_LOG"
}

# --- T-SW-006: agent_has_self_watch — detects inotifywait ---

@test "T-SW-006: agent_has_self_watch returns 0 when inotifywait running" {
    cat > "$MOCK_PGREP" << 'MOCK'
#!/bin/bash
echo "99999 inotifywait -q -t 120 -e modify inbox/test_agent.yaml"
exit 0
MOCK
    chmod +x "$MOCK_PGREP"

    run bash -c "source '$TEST_HARNESS' && agent_has_self_watch"
    [ "$status" -eq 0 ]
}

# --- T-SW-007: agent_has_self_watch — no inotifywait ---

@test "T-SW-007: agent_has_self_watch returns 1 when no inotifywait" {
    run bash -c "source '$TEST_HARNESS' && agent_has_self_watch"
    [ "$status" -eq 1 ]
}

# --- T-SW-008: /clear uses send-keys ---

@test "T-SW-008: send_cli_command /clear uses tmux send-keys" {
    run bash -c "source '$TEST_HARNESS' && send_cli_command /clear"
    [ "$status" -eq 0 ]

    # Verify send-keys was used with /clear
    grep -q "send-keys.*/clear" "$MOCK_LOG"
    # C-c was sent first (stale input clearing)
    grep -q "send-keys.*C-c" "$MOCK_LOG"
    # Enter was sent after /clear
    grep -q "send-keys.*Enter" "$MOCK_LOG"
}

# --- T-SW-009: /model uses send-keys ---

@test "T-SW-009: send_cli_command /model uses tmux send-keys" {
    run bash -c "source '$TEST_HARNESS' && send_cli_command '/model opus'"
    [ "$status" -eq 0 ]

    grep -q "send-keys.*/model opus" "$MOCK_LOG"
    grep -q "send-keys.*Enter" "$MOCK_LOG"
}

# --- T-SW-010: nudge content format ---

@test "T-SW-010: nudge content format is inboxN (backward compatible)" {
    run bash -c "source '$TEST_HARNESS' && send_wakeup 7"
    [ "$status" -eq 0 ]

    grep -q "send-keys.*inbox7" "$MOCK_LOG"
}

# --- T-SW-011: functions exist in inbox_watcher.sh ---

@test "T-SW-011: inbox_watcher.sh uses send-keys with required functions" {
    grep -q "send_wakeup()" "$WATCHER_SCRIPT"
    grep -q "agent_has_self_watch" "$WATCHER_SCRIPT"
    grep -q "send_wakeup_with_escape()" "$WATCHER_SCRIPT"
    grep -q "send_cli_command()" "$WATCHER_SCRIPT"

    # send-keys IS used in executable code
    local executable_lines
    executable_lines=$(grep -v '^\s*#' "$WATCHER_SCRIPT")
    echo "$executable_lines" | grep -q "send-keys"

    # paste-buffer and set-buffer are NOT used
    ! echo "$executable_lines" | grep -q "paste-buffer"
    ! echo "$executable_lines" | grep -q "set-buffer"
}

# --- T-ESC-001: no unread → FIRST_UNREAD_SEEN stays 0 ---

@test "T-ESC-001: escalation state resets when no unread messages" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        FIRST_UNREAD_SEEN=12345
        # Simulate no unread
        normal_count=0
        if [ "$normal_count" -gt 0 ] 2>/dev/null; then
            echo "SHOULD_NOT_REACH"
        else
            FIRST_UNREAD_SEEN=0
        fi
        echo "FIRST_UNREAD_SEEN=$FIRST_UNREAD_SEEN"
    '
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "FIRST_UNREAD_SEEN=0"
}

# --- T-ESC-002: unread < 2min → standard nudge ---

@test "T-ESC-002: escalation Phase 1 — unread under 2min uses standard nudge" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        now=$(date +%s)
        FIRST_UNREAD_SEEN=$((now - 30))  # 30 seconds ago
        age=$((now - FIRST_UNREAD_SEEN))
        if [ "$age" -lt "$ESCALATE_PHASE1" ]; then
            send_wakeup 2
            echo "PHASE1_NUDGE"
        fi
    '
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "PHASE1_NUDGE"
    grep -q "send-keys.*inbox2" "$MOCK_LOG"
    # No Escape-based nudge
    ! grep -q "send-keys.*Escape" "$MOCK_LOG"
}

# --- T-ESC-003: unread 2-4min → Escape+nudge ---

@test "T-ESC-003: escalation Phase 2 — unread 2-4min uses Escape+nudge (copilot)" {
    # Escape escalation is suppressed for claude/codex (Stop hook / safety).
    # Test with copilot CLI which still uses Escape escalation.
    export MOCK_PANE_CLI="copilot"
    run bash -c '
        source "'"$TEST_HARNESS"'"
        now=$(date +%s)
        FIRST_UNREAD_SEEN=$((now - 180))  # 3 minutes ago
        age=$((now - FIRST_UNREAD_SEEN))
        if [ "$age" -ge "$ESCALATE_PHASE1" ] && [ "$age" -lt "$ESCALATE_PHASE2" ]; then
            send_wakeup_with_escape 3
            echo "PHASE2_ESCAPE_NUDGE"
        fi
    '
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "PHASE2_ESCAPE_NUDGE"
    # Escape was sent
    grep -q "send-keys.*Escape" "$MOCK_LOG"
    # Nudge was also sent
    grep -q "send-keys.*inbox3" "$MOCK_LOG"
}

# --- T-ESC-004: unread > 4min → /clear sent ---

@test "T-ESC-004: escalation Phase 3 — unread over 4min sends /clear" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        now=$(date +%s)
        FIRST_UNREAD_SEEN=$((now - 300))  # 5 minutes ago
        LAST_CLEAR_TS=0  # no recent /clear
        age=$((now - FIRST_UNREAD_SEEN))
        if [ "$age" -ge "$ESCALATE_PHASE2" ] && [ "$LAST_CLEAR_TS" -lt "$((now - ESCALATE_COOLDOWN))" ]; then
            send_cli_command "/clear"
            echo "PHASE3_CLEAR"
        fi
    '
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "PHASE3_CLEAR"
    grep -q "send-keys.*/clear" "$MOCK_LOG"
}

# --- T-ESC-005: /clear cooldown → falls back to Escape+nudge ---

@test "T-ESC-005: escalation /clear cooldown — falls back to Escape+nudge (copilot)" {
    # Escape escalation is suppressed for claude/codex. Test with copilot.
    export MOCK_PANE_CLI="copilot"
    run bash -c '
        source "'"$TEST_HARNESS"'"
        now=$(date +%s)
        FIRST_UNREAD_SEEN=$((now - 300))  # 5 minutes ago
        LAST_CLEAR_TS=$((now - 60))  # /clear sent 1 min ago (within 5min cooldown)
        age=$((now - FIRST_UNREAD_SEEN))
        if [ "$age" -ge "$ESCALATE_PHASE2" ] && [ "$LAST_CLEAR_TS" -ge "$((now - ESCALATE_COOLDOWN))" ]; then
            send_wakeup_with_escape 4
            echo "COOLDOWN_FALLBACK"
        fi
    '
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "COOLDOWN_FALLBACK"
    grep -q "send-keys.*Escape" "$MOCK_LOG"
    grep -q "send-keys.*inbox4" "$MOCK_LOG"
    ! grep -q "send-keys.*/clear" "$MOCK_LOG"
}

# --- T-BUSY-001: agent_is_busy detects "Working" ---

@test "T-BUSY-001: agent_is_busy returns 0 when pane shows Working" {
    run bash -c '
        MOCK_CAPTURE_PANE="◦ Working on task (12s • esc to interrupt)"
        source "'"$TEST_HARNESS"'"
        agent_is_busy
    '
    [ "$status" -eq 0 ]
}

# --- T-BUSY-002: agent_is_busy returns 1 when idle ---

@test "T-BUSY-002: agent_is_busy returns 1 when pane is idle" {
    run bash -c '
        MOCK_CAPTURE_PANE="› Summarize recent commits
  ? for shortcuts                100% context left"
        source "'"$TEST_HARNESS"'"
        agent_is_busy
    '
    [ "$status" -eq 1 ]
}

# --- T-BUSY-003: send_wakeup skips when agent is busy ---

@test "T-BUSY-003: send_wakeup skips nudge when agent is busy" {
    run bash -c '
        MOCK_CAPTURE_PANE="◦ Thinking about approach (5s • esc to interrupt)"
        source "'"$TEST_HARNESS"'"
        send_wakeup 3
    '
    [ "$status" -eq 0 ]
    echo "$output" | grep -qi "SKIP.*busy"

    # No nudge should have been sent
    ! grep -q "send-keys.*inbox" "$MOCK_LOG"
}

# --- T-BUSY-004: send_wakeup_with_escape skips when agent is busy ---

@test "T-BUSY-004: send_wakeup_with_escape skips when agent is busy" {
    run bash -c '
        MOCK_CAPTURE_PANE="◦ Sending request (2s • esc to interrupt)"
        source "'"$TEST_HARNESS"'"
        send_wakeup_with_escape 2
    '
    [ "$status" -eq 0 ]
    echo "$output" | grep -qi "SKIP.*busy"

    # No nudge should have been sent
    ! grep -q "send-keys.*inbox" "$MOCK_LOG"
}

# --- T-CODEX-001: codex /clear → /new conversion ---

@test "T-CODEX-001: send_cli_command converts /clear to /new for codex" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        CLI_TYPE="codex"
        send_cli_command "/clear"
    '
    [ "$status" -eq 0 ]

    # Should send /new, NOT /clear
    grep -q "send-keys.*/new" "$MOCK_LOG"
    ! grep -q "send-keys.*/clear" "$MOCK_LOG"
}

# --- T-CODEX-002: codex /model → skip ---

@test "T-CODEX-002: send_cli_command skips /model for codex" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        CLI_TYPE="codex"
        send_cli_command "/model opus"
    '
    [ "$status" -eq 0 ]

    # No tmux send-keys for /model
    ! grep -q "send-keys.*/model" "$MOCK_LOG"

    # Stderr indicates skip
    echo "$output" | grep -q "not supported on codex"
}

# --- T-CODEX-003: C-u sent when unread=0 and agent is idle ---

@test "T-CODEX-003: C-u cleanup sent when no unread and agent is idle" {
    run bash -c '
        MOCK_CAPTURE_PANE="› Summarize recent commits
  ? for shortcuts                100% context left"
        source "'"$TEST_HARNESS"'"
        # Simulate process_unread no-unread path
        FIRST_UNREAD_SEEN=12345
        normal_count=0
        if [ "$normal_count" -gt 0 ] 2>/dev/null; then
            echo "SHOULD_NOT_REACH"
        else
            FIRST_UNREAD_SEEN=0
            if ! agent_is_busy; then
                timeout 2 tmux send-keys -t "$PANE_TARGET" C-u 2>/dev/null
                echo "C_U_SENT"
            fi
        fi
    '
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "C_U_SENT"
    grep -q "send-keys.*C-u" "$MOCK_LOG"
}

# --- T-CODEX-004: C-u NOT sent when agent is busy ---

@test "T-CODEX-004: C-u cleanup NOT sent when agent is busy" {
    run bash -c '
        MOCK_CAPTURE_PANE="◦ Working on request (10s • esc to interrupt)"
        source "'"$TEST_HARNESS"'"
        FIRST_UNREAD_SEEN=12345
        normal_count=0
        if [ "$normal_count" -gt 0 ] 2>/dev/null; then
            echo "SHOULD_NOT_REACH"
        else
            FIRST_UNREAD_SEEN=0
            if ! agent_is_busy; then
                timeout 2 tmux send-keys -t "$PANE_TARGET" C-u 2>/dev/null
                echo "C_U_SENT"
            else
                echo "C_U_SKIPPED"
            fi
        fi
    '
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "C_U_SKIPPED"
    ! grep -q "C-u" "$MOCK_LOG"
}

# --- T-CODEX-005: claude /clear passes through as-is ---

@test "T-CODEX-005: send_cli_command sends /clear as-is for claude" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        CLI_TYPE="claude"
        send_cli_command "/clear"
    '
    [ "$status" -eq 0 ]

    # Should send /clear directly (not /new)
    grep -q "send-keys.*/clear" "$MOCK_LOG"
    ! grep -q "/new" "$MOCK_LOG"
}

# --- T-CODEX-006: inbox_watcher.sh has agent_is_busy and Codex/Copilot handlers ---

@test "T-CODEX-006: inbox_watcher.sh contains agent_is_busy and Codex/Copilot handlers" {
    grep -q "agent_is_busy()" "$WATCHER_SCRIPT"
    # Busy detection patterns live in lib/agent_status.sh (shared library)
    grep -q 'Working|Thinking|Planning|Sending' "$PROJECT_ROOT/lib/agent_status.sh"

    # Codex /clear → /new conversion exists
    grep -q '/new' "$WATCHER_SCRIPT"

    # Codex /model skip exists
    grep -q 'not supported on codex' "$WATCHER_SCRIPT"

    # C-u cleanup exists
    grep -q 'C-u' "$WATCHER_SCRIPT"

    # Copilot handler exists
    grep -q 'copilot --yolo' "$WATCHER_SCRIPT"
    grep -q 'not supported on copilot' "$WATCHER_SCRIPT"
}

# --- T-CODEX-007: pane cli overrides stale CLI_TYPE in Phase2 ---

@test "T-CODEX-007: pane @agent_cli=codex overrides stale CLI_TYPE for Phase2 (no C-c)" {
    run bash -c '
        MOCK_PANE_CLI="codex"
        source "'"$TEST_HARNESS"'"
        CLI_TYPE="claude"
        send_wakeup_with_escape 2
    '
    [ "$status" -eq 0 ]

    grep -q "send-keys.*inbox2" "$MOCK_LOG"
    # Codex: Escape escalation is suppressed (avoid interrupting work / human typing)
    ! grep -q "send-keys.*Escape" "$MOCK_LOG"
    ! grep -q "send-keys.*C-c" "$MOCK_LOG"
}

# --- T-CODEX-008: pane cli overrides stale CLI_TYPE in /clear path ---

@test "T-CODEX-008: pane @agent_cli=codex overrides stale CLI_TYPE for /clear (uses /new)" {
    run bash -c '
        MOCK_PANE_CLI="codex"
        source "'"$TEST_HARNESS"'"
        CLI_TYPE="claude"
        send_cli_command "/clear"
    '
    [ "$status" -eq 0 ]

    grep -q "send-keys.*/new" "$MOCK_LOG"
    ! grep -q "send-keys.*/clear" "$MOCK_LOG"
    ! grep -q "send-keys.*C-c" "$MOCK_LOG"
}

# --- T-CODEX-009: invalid model_switch payload is rejected ---

@test "T-CODEX-009: normalize_special_command rejects invalid model_switch payload" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        cmd=$(normalize_special_command "model_switch" "please change model" 2>/dev/null)
        [ -z "$cmd" ]
    '
    [ "$status" -eq 0 ]
}

# --- T-CODEX-010: unresolved cli falls back to codex-safe ---

@test "T-CODEX-010: unresolved CLI type falls back to codex-safe (/clear->/new, no C-c)" {
    run bash -c '
        MOCK_PANE_CLI=""
        source "'"$TEST_HARNESS"'"
        CLI_TYPE="unknown_cli"
        send_cli_command "/clear"
    '
    [ "$status" -eq 0 ]

    grep -q "send-keys.*/new" "$MOCK_LOG"
    ! grep -q "send-keys.*/clear" "$MOCK_LOG"
    ! grep -q "send-keys.*C-c" "$MOCK_LOG"
}

# --- T-CODEX-011: clear_command auto-recovery injection ---

@test "T-CODEX-011: process_unread injects auto-recovery task and sends inbox nudge after clear_command" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        CLI_TYPE="codex"
        cat > "$INBOX" << "YAML"
messages:
  - id: msg_clear
    from: karo
    timestamp: "2026-02-10T14:00:00+09:00"
    type: clear_command
    content: redo
    read: false
YAML
        process_unread event
        "$VENV_PYTHON" - << "PY" "$INBOX"
import sys
import yaml

inbox_path = sys.argv[1]
with open(inbox_path, "r", encoding="utf-8") as f:
    data = yaml.safe_load(f) or {}

messages = data.get("messages", []) or []
msg_clear = [m for m in messages if m.get("id") == "msg_clear"]
assert len(msg_clear) == 1 and msg_clear[0].get("read") is True

auto = [
    m for m in messages
    if m.get("from") == "inbox_watcher"
    and m.get("type") == "task_assigned"
    and "[auto-recovery]" in (m.get("content") or "")
]
assert len(auto) == 1
assert auto[0].get("read") is False
print("OK")
PY
    '
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "OK"

    # codex clear path uses /new
    grep -q "send-keys.*/new" "$MOCK_LOG"
    # After /new, startup prompt is sent (replaces inbox1 nudge for wake-up)
    grep -q "send-keys.*Session Start" "$MOCK_LOG"
}

# --- T-CODEX-012: auto-recovery dedupe ---

@test "T-CODEX-012: enqueue_recovery_task_assigned deduplicates unread auto-recovery message" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        cat > "$INBOX" << "YAML"
messages:
  - id: msg_auto_existing
    from: inbox_watcher
    timestamp: "2026-02-10T14:00:00+09:00"
    type: task_assigned
    content: "[auto-recovery] existing hint"
    read: false
YAML
        r1=$(enqueue_recovery_task_assigned)
        r2=$(enqueue_recovery_task_assigned)
        "$VENV_PYTHON" - << "PY" "$INBOX" "$r1" "$r2"
import sys
import yaml

inbox_path, r1, r2 = sys.argv[1], sys.argv[2], sys.argv[3]
with open(inbox_path, "r", encoding="utf-8") as f:
    data = yaml.safe_load(f) or {}
messages = data.get("messages", []) or []
auto = [
    m for m in messages
    if m.get("from") == "inbox_watcher"
    and m.get("type") == "task_assigned"
    and "[auto-recovery]" in (m.get("content") or "")
    and m.get("read") is False
]
assert len(auto) == 1
assert r1 == "SKIP_DUPLICATE"
assert r2 == "SKIP_DUPLICATE"
print("OK")
PY
    '
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "OK"
}

# --- T-CODEX-013: auto-recovery skipped when task is cancelled ---

@test "T-CODEX-013: enqueue_recovery_task_assigned skips if task YAML status is cancelled" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        # Initialize inbox (required by enqueue_recovery_task_assigned)
        echo "messages: []" > "$INBOX"
        # Place task YAML with status: cancelled
        mkdir -p "$(dirname "$INBOX")/../tasks"
        cat > "$(dirname "$INBOX")/../tasks/test_agent.yaml" << "YAML"
worker_id: test_agent
task_id: subtask_test_cancelled
status: cancelled
YAML
        r=$(enqueue_recovery_task_assigned)
        # Should return SKIP_CANCELLED:cancelled
        if [ "$r" = "SKIP_CANCELLED:cancelled" ]; then echo "OK"; else echo "FAIL:$r"; fi
    '
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "OK"
}

# --- T-CODEX-014: auto-recovery skipped when task is idle ---

@test "T-CODEX-014: enqueue_recovery_task_assigned skips if task YAML status is idle" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        echo "messages: []" > "$INBOX"
        mkdir -p "$(dirname "$INBOX")/../tasks"
        cat > "$(dirname "$INBOX")/../tasks/test_agent.yaml" << "YAML"
worker_id: test_agent
task_id: subtask_test_idle
status: idle
YAML
        r=$(enqueue_recovery_task_assigned)
        if [ "$r" = "SKIP_CANCELLED:idle" ]; then echo "OK"; else echo "FAIL:$r"; fi
    '
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "OK"
}

# --- T-CODEX-015: auto-recovery proceeds when task is assigned ---

@test "T-CODEX-015: enqueue_recovery_task_assigned proceeds when task YAML status is assigned" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        echo "messages: []" > "$INBOX"
        mkdir -p "$(dirname "$INBOX")/../tasks"
        cat > "$(dirname "$INBOX")/../tasks/test_agent.yaml" << "YAML"
worker_id: test_agent
task_id: subtask_test_assigned
status: assigned
YAML
        r=$(enqueue_recovery_task_assigned)
        # Should return a message ID (not SKIP_*)
        if [[ "$r" != SKIP_* ]] && [[ "$r" != "ERROR" ]] && [[ -n "$r" ]]; then echo "OK"; else echo "FAIL:$r"; fi
    '
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "OK"
}

# --- T-COPILOT-001: copilot /clear → Ctrl-C + restart ---

@test "T-COPILOT-001: send_cli_command sends Ctrl-C + copilot restart for copilot /clear" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        CLI_TYPE="copilot"
        send_cli_command "/clear"
    '
    [ "$status" -eq 0 ]

    # Should trigger copilot restart
    grep -q "send-keys.*C-c" "$MOCK_LOG"
    grep -q "send-keys.*copilot --yolo" "$MOCK_LOG"
    # NOT /clear or /new
    ! grep -q "send-keys.*/clear" "$MOCK_LOG"
    ! grep -q "send-keys.*/new" "$MOCK_LOG"
}

# --- T-COPILOT-002: copilot /model → skip ---

@test "T-COPILOT-002: send_cli_command skips /model for copilot" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        CLI_TYPE="copilot"
        send_cli_command "/model opus"
    '
    [ "$status" -eq 0 ]

    ! grep -q "send-keys.*/model" "$MOCK_LOG"
    echo "$output" | grep -q "not supported on copilot"
}

# --- T-SHOGUN-001: session_has_client — client attached ---

@test "T-SHOGUN-001: session_has_client returns 0 when client attached" {
    run bash -c '
        MOCK_LIST_CLIENTS="/dev/pts/1: mock_session [200x50 xterm-256color]"
        source "'"$TEST_HARNESS"'"
        session_has_client
    '
    [ "$status" -eq 0 ]
}

# --- T-SHOGUN-002: session_has_client — no client ---

@test "T-SHOGUN-002: session_has_client returns 1 when no client" {
    run bash -c '
        MOCK_LIST_CLIENTS=""
        source "'"$TEST_HARNESS"'"
        session_has_client
    '
    [ "$status" -ne 0 ]
}

# --- T-SHOGUN-003: shogun + active pane + client attached → display-message only ---

@test "T-SHOGUN-003: send_wakeup shogun + active + attached uses display-message only" {
    run bash -c '
        MOCK_PANE_ACTIVE="1"
        MOCK_LIST_CLIENTS="/dev/pts/1: mock_session [200x50 xterm-256color]"
        source "'"$TEST_HARNESS"'"
        AGENT_ID="shogun"
        send_wakeup 2
    '
    [ "$status" -eq 0 ]

    # display-message was used for nudge
    echo "$output" | grep -q "DISPLAY"

    # send-keys with inbox should NOT have occurred
    ! grep -q "send-keys.*inbox" "$MOCK_LOG"
}

# --- T-SHOGUN-004: shogun + active pane + no client → send-keys fallthrough ---

@test "T-SHOGUN-004: send_wakeup shogun + active + detached falls through to send-keys" {
    run bash -c '
        MOCK_PANE_ACTIVE="1"
        MOCK_LIST_CLIENTS=""
        source "'"$TEST_HARNESS"'"
        AGENT_ID="shogun"
        send_wakeup 2
    '
    [ "$status" -eq 0 ]

    # Should NOT show display-message path
    ! echo "$output" | grep -q "DISPLAY"

    # Should have used send-keys
    grep -q "send-keys.*inbox2" "$MOCK_LOG"
}

# --- T-BUSY-005: agent_is_busy during /clear cooldown ---

@test "T-BUSY-005: agent_is_busy returns 0 (busy) during /clear cooldown period" {
    run bash -c '
        MOCK_CAPTURE_PANE="› prompt
  ? for shortcuts                100% context left"
        source "'"$TEST_HARNESS"'"
        now=$(date +%s)
        LAST_CLEAR_TS=$((now - 10))  # /clear sent 10 seconds ago (within 30s cooldown)
        agent_is_busy
    '
    [ "$status" -eq 0 ]
}

# --- T-BUSY-006: agent_is_busy idle after /clear cooldown expires ---

@test "T-BUSY-006: agent_is_busy returns 1 (idle) after /clear cooldown expires" {
    run bash -c '
        MOCK_CAPTURE_PANE="› prompt
  ? for shortcuts                100% context left"
        source "'"$TEST_HARNESS"'"
        now=$(date +%s)
        LAST_CLEAR_TS=$((now - 40))  # /clear sent 40 seconds ago (past 30s cooldown)
        agent_is_busy
    '
    [ "$status" -eq 1 ]
}

# --- T-BUSY-007: /clear cooldown overrides idle pane ---

@test "T-BUSY-007: agent_is_busy /clear cooldown overrides idle pane state" {
    run bash -c '
        MOCK_CAPTURE_PANE="› Summarize recent commits
  ? for shortcuts                100% context left"
        source "'"$TEST_HARNESS"'"
        now=$(date +%s)
        LAST_CLEAR_TS=$((now - 5))  # /clear sent 5 seconds ago
        # Pane looks idle, but cooldown should make it busy
        if agent_is_busy; then
            echo "BUSY_DURING_COOLDOWN"
        else
            echo "WRONGLY_IDLE"
        fi
    '
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "BUSY_DURING_COOLDOWN"
}

# --- T-BUSY-008: idle prompt at bottom overrides old busy markers (false-busy fix) ---
# Bug: 59ec12f / 69c1ecb — old "Working" or "esc to interrupt" lingered in scroll-back
# above the idle prompt, causing false-busy. Fix: only check bottom 5 lines, idle first.

@test "T-BUSY-008: agent_is_busy returns idle when idle prompt is below old busy markers" {
    run bash -c '
        MOCK_CAPTURE_PANE="$(printf "◦ Working on task (12s • esc to interrupt)\nsome output line\nmore output\n\n❯ ")"
        source "'"$TEST_HARNESS"'"
        LAST_CLEAR_TS=0
        if agent_is_busy; then
            echo "WRONGLY_BUSY"
        else
            echo "CORRECTLY_IDLE"
        fi
    '
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "CORRECTLY_IDLE"
}

# --- T-BUSY-009: 'background terminal running' detected as busy ---
# Bug: 91ebf61 — Codex shows this when a tool is running in background.

@test "T-BUSY-009: agent_is_busy detects 'background terminal running' as busy" {
    run bash -c '
        MOCK_CAPTURE_PANE="$(printf "Some output\nbackground terminal running\n")"
        source "'"$TEST_HARNESS"'"
        LAST_CLEAR_TS=0
        agent_is_busy
    '
    [ "$status" -eq 0 ]
}

# --- T-BUSY-010: 'Compacting conversation' detected as busy ---

@test "T-BUSY-010: agent_is_busy detects 'Compacting conversation' as busy" {
    run bash -c '
        MOCK_CAPTURE_PANE="$(printf "Compacting conversation...\n")"
        source "'"$TEST_HARNESS"'"
        LAST_CLEAR_TS=0
        agent_is_busy
    '
    [ "$status" -eq 0 ]
}

# --- T-BUSY-011: 'esc to interrupt' detected as busy ---

@test "T-BUSY-011: agent_is_busy detects 'esc to interrupt' as busy" {
    run bash -c '
        MOCK_CAPTURE_PANE="$(printf "◦ Thinking (5s • esc to interrupt)\n")"
        source "'"$TEST_HARNESS"'"
        LAST_CLEAR_TS=0
        agent_is_busy
    '
    [ "$status" -eq 0 ]
}

# --- T-SHOOK-001: Claude Code throttle uses 300s cooldown ---

@test "T-SHOOK-001: Claude Code throttle uses 300s cooldown (stop-hook-primary)" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        CLI_TYPE="claude"
        LAST_NUDGE_TS=0
        LAST_NUDGE_COUNT=""

        # First call: should pass through (no throttle)
        should_throttle_nudge 1
        rc1=$?

        # Simulate 60s elapsed (would pass for default 60s cooldown)
        LAST_NUDGE_TS=$(($(date +%s) - 60))
        LAST_NUDGE_COUNT=1

        # Second call with same count after 60s: should STILL throttle for claude (300s cooldown)
        should_throttle_nudge 1
        rc2=$?

        echo "rc1=$rc1 rc2=$rc2"
    '
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "rc1=1 rc2=0"  # 1=not-throttled, 0=throttled
    echo "$output" | grep -q "stop-hook-primary"
}

# --- T-SHOOK-002: Claude Code throttle ignores count changes ---

@test "T-SHOOK-002: Claude Code throttle ignores count changes (stop-hook-primary)" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        CLI_TYPE="claude"
        LAST_NUDGE_TS=0
        LAST_NUDGE_COUNT=""

        # First call: should pass through
        should_throttle_nudge 1
        rc1=$?

        # Simulate 30s elapsed, count changed from 1 to 2
        LAST_NUDGE_TS=$(($(date +%s) - 30))

        # For non-claude, count change (1→2) would bypass throttle.
        # For claude, count change should NOT bypass — Stop hook handles it.
        should_throttle_nudge 2
        rc2=$?

        echo "rc1=$rc1 rc2=$rc2"
    '
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "rc1=1 rc2=0"  # Both: 1=pass, 0=throttled (count change ignored)
    echo "$output" | grep -q "stop-hook-primary"
}

# --- T-SHOOK-003: Non-Claude CLIs bypass throttle on count change ---

@test "T-SHOOK-003: Non-Claude CLIs still bypass throttle on count change" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        CLI_TYPE="copilot"
        LAST_NUDGE_TS=0
        LAST_NUDGE_COUNT=""

        # First call
        should_throttle_nudge 1
        rc1=$?

        # Simulate 30s elapsed, count changed from 1 to 2
        LAST_NUDGE_TS=$(($(date +%s) - 30))

        # For copilot, count change (1→2) SHOULD bypass throttle
        should_throttle_nudge 2
        rc2=$?

        echo "rc1=$rc1 rc2=$rc2"
    '
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "rc1=1 rc2=1"  # Both pass through (count changed)
}

# --- T-CRESET-001: send_context_reset suppresses /clear for karo ---

@test "T-CRESET-001: send_context_reset suppresses /clear for karo" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        AGENT_ID="karo"
        send_context_reset
    '
    [ "$status" -eq 0 ]

    # No send-keys should have occurred
    ! grep -q "send-keys" "$MOCK_LOG"

    # SKIP message in stderr
    echo "$output" | grep -q "SKIP.*karo"
}

# --- T-CRESET-002: send_context_reset suppresses /clear for gunshi ---

@test "T-CRESET-002: send_context_reset suppresses /clear for gunshi" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        AGENT_ID="gunshi"
        send_context_reset
    '
    [ "$status" -eq 0 ]

    # No send-keys should have occurred
    ! grep -q "send-keys" "$MOCK_LOG"

    # SKIP message in stderr
    echo "$output" | grep -q "SKIP.*gunshi"
}

# --- T-CRESET-003: send_context_reset sends /clear for ashigaru ---

@test "T-CRESET-003: send_context_reset sends /clear for ashigaru" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        AGENT_ID="ashigaru3"
        CLI_TYPE="claude"
        send_context_reset
    '
    [ "$status" -eq 0 ]

    # /clear should have been sent via send-keys
    grep -q "send-keys.*/clear" "$MOCK_LOG"
}
