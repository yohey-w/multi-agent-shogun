#!/usr/bin/env bats
# ═══════════════════════════════════════════════════════════════
# E2E-008: Codex CLI Startup Prompt after /new
# ═══════════════════════════════════════════════════════════════
# Validates that inbox_watcher correctly handles Codex CLI agents:
#   1. Sends /new (not /clear) for context reset
#   2. Sends startup prompt AFTER /new to trigger Session Start
#   3. Agent processes assigned task via startup prompt
#   4. Nudge is suppressed immediately after startup prompt
#
# Background: Codex CLI's /new does NOT auto-reload AGENTS.md and
# trigger Session Start like Claude Code's /clear does with CLAUDE.md.
# inbox_watcher must explicitly send a startup prompt after /new.
# ═══════════════════════════════════════════════════════════════

# bats file_tags=e2e

load "../test_helper/bats-support/load"
load "../test_helper/bats-assert/load"

# Load E2E helpers
E2E_HELPERS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/helpers" && pwd)"
source "$E2E_HELPERS_DIR/setup.bash"
source "$E2E_HELPERS_DIR/assertions.bash"
source "$E2E_HELPERS_DIR/tmux_helpers.bash"

# ─── Lifecycle ───

setup_file() {
    command -v tmux &>/dev/null || skip "tmux not available"
    command -v python3 &>/dev/null || skip "python3 not available"
    python3 -c "import yaml" 2>/dev/null || skip "python3-yaml not available"

    setup_e2e_session 3
}

teardown_file() {
    teardown_e2e_session
}

setup() {
    reset_queues
    sleep 1
}

# Helper: dump watcher log on failure
dump_watcher_log() {
    local log_file="$1"
    echo "=== Watcher log ($log_file) ===" >&2
    cat "$log_file" >&2 2>/dev/null || echo "(log not found)" >&2
    echo "=== End watcher log ===" >&2
}

# ═══════════════════════════════════════════════════════════════
# E2E-008-A: Codex agent receives startup prompt after /new
#            and processes assigned task
# ═══════════════════════════════════════════════════════════════

@test "E2E-008-A: Codex startup prompt triggers task processing via inbox_watcher" {
    local ashigaru1_pane
    ashigaru1_pane=$(pane_target 1)

    # 1. Respawn pane with codex mock (clean restart)
    tmux respawn-pane -k -t "$ashigaru1_pane" \
        "MOCK_CLI_TYPE=codex MOCK_AGENT_ID=ashigaru1 MOCK_PROCESSING_DELAY=1 MOCK_PROJECT_ROOT=$E2E_QUEUE bash $PROJECT_ROOT/tests/e2e/mock_cli.sh"
    sleep 2
    tmux set-option -p -t "$ashigaru1_pane" @agent_cli "codex"

    # 2. Place assigned task YAML
    cp "$PROJECT_ROOT/tests/e2e/fixtures/task_ashigaru1_basic.yaml" \
       "$E2E_QUEUE/queue/tasks/ashigaru1.yaml"

    # 3. Send task_assigned message via inbox_write
    bash "$E2E_QUEUE/scripts/inbox_write.sh" "ashigaru1" \
        "タスクYAMLを読んで作業開始せよ。" "task_assigned" "karo"

    # 4. Start inbox_watcher with codex CLI type
    local watcher_pid log_file
    watcher_pid=$(start_inbox_watcher "ashigaru1" 1 "codex")
    log_file="/tmp/e2e_inbox_watcher_ashigaru1_$$.log"

    # 5. Wait for task to complete
    #    Flow: watcher detects unread → sends /new → polls idle (5s) → sends startup prompt → mock processes
    #    Expected time: ~10-15s
    run wait_for_yaml_value "$E2E_QUEUE/queue/tasks/ashigaru1.yaml" "task.status" "done" 45
    if [ "$status" -ne 0 ]; then
        dump_pane_for_debug "$ashigaru1_pane" "ashigaru1-codex"
        dump_watcher_log "$log_file"
    fi
    assert_success

    # 6. Verify report was written
    run wait_for_file "$E2E_QUEUE/queue/reports/ashigaru1_report.yaml" 10
    assert_success

    # 7. Verify report content
    assert_yaml_field "$E2E_QUEUE/queue/reports/ashigaru1_report.yaml" "status" "done"
    assert_yaml_field "$E2E_QUEUE/queue/reports/ashigaru1_report.yaml" "task_id" "subtask_test_001a"

    # 8. Verify startup prompt appeared in pane output (scrollback search)
    run wait_for_pane_text "$ashigaru1_pane" "Startup prompt received" 10
    if [ "$status" -ne 0 ]; then
        dump_watcher_log "$log_file"
    fi
    assert_success

    # Cleanup
    stop_inbox_watcher "$watcher_pid"
}

# ═══════════════════════════════════════════════════════════════
# E2E-008-B: Codex watcher log confirms startup prompt sent
#            and nudge suppressed
# ═══════════════════════════════════════════════════════════════

@test "E2E-008-B: Codex watcher log shows startup prompt sent and nudge skipped" {
    local ashigaru1_pane
    ashigaru1_pane=$(pane_target 1)

    # 1. Respawn pane with codex mock
    tmux respawn-pane -k -t "$ashigaru1_pane" \
        "MOCK_CLI_TYPE=codex MOCK_AGENT_ID=ashigaru1 MOCK_PROCESSING_DELAY=1 MOCK_PROJECT_ROOT=$E2E_QUEUE bash $PROJECT_ROOT/tests/e2e/mock_cli.sh"
    sleep 2
    tmux set-option -p -t "$ashigaru1_pane" @agent_cli "codex"

    # 2. Place task and send inbox message
    cp "$PROJECT_ROOT/tests/e2e/fixtures/task_ashigaru1_basic.yaml" \
       "$E2E_QUEUE/queue/tasks/ashigaru1.yaml"

    bash "$E2E_QUEUE/scripts/inbox_write.sh" "ashigaru1" \
        "タスクYAMLを読んで作業開始せよ。" "task_assigned" "karo"

    # 3. Start watcher (codex CLI type)
    local watcher_pid log_file
    watcher_pid=$(start_inbox_watcher "ashigaru1" 1 "codex")
    log_file="/tmp/e2e_inbox_watcher_ashigaru1_$$.log"

    # 4. Wait for processing
    run wait_for_yaml_value "$E2E_QUEUE/queue/tasks/ashigaru1.yaml" "task.status" "done" 45
    if [ "$status" -ne 0 ]; then
        dump_pane_for_debug "$ashigaru1_pane" "ashigaru1-codex-B"
        dump_watcher_log "$log_file"
    fi
    assert_success

    # 5. Check watcher log for startup prompt delivery
    run grep "Sending startup prompt to ashigaru1" "$log_file"
    if [ "$status" -ne 0 ]; then
        dump_watcher_log "$log_file"
    fi
    assert_success

    # 6. Check watcher log for nudge suppression after startup prompt
    run grep "Startup prompt just sent.*skipping nudge" "$log_file"
    assert_success

    # 7. Check that /new was sent (not /clear)
    run grep "CONTEXT-RESET.*Sending /new" "$log_file"
    assert_success

    # Cleanup
    stop_inbox_watcher "$watcher_pid"
}

# ═══════════════════════════════════════════════════════════════
# E2E-008-C: Claude agent does NOT receive startup prompt
#            (only Codex gets it)
# ═══════════════════════════════════════════════════════════════

@test "E2E-008-C: Claude agent does not receive startup prompt after /clear" {
    local ashigaru1_pane
    ashigaru1_pane=$(pane_target 1)

    # 1. Respawn pane with claude mock
    tmux respawn-pane -k -t "$ashigaru1_pane" \
        "MOCK_CLI_TYPE=claude MOCK_AGENT_ID=ashigaru1 MOCK_PROCESSING_DELAY=1 MOCK_PROJECT_ROOT=$E2E_QUEUE bash $PROJECT_ROOT/tests/e2e/mock_cli.sh"
    sleep 2
    tmux set-option -p -t "$ashigaru1_pane" @agent_cli "claude"

    # 2. Place task and send inbox message
    cp "$PROJECT_ROOT/tests/e2e/fixtures/task_ashigaru1_basic.yaml" \
       "$E2E_QUEUE/queue/tasks/ashigaru1.yaml"

    bash "$E2E_QUEUE/scripts/inbox_write.sh" "ashigaru1" \
        "タスクYAMLを読んで作業開始せよ。" "task_assigned" "karo"

    # 3. Start watcher (claude CLI type)
    local watcher_pid log_file
    watcher_pid=$(start_inbox_watcher "ashigaru1" 1 "claude")
    log_file="/tmp/e2e_inbox_watcher_ashigaru1_$$.log"

    # 4. Wait for task to complete (claude uses /clear → auto-recovery via mock handle_clear)
    run wait_for_yaml_value "$E2E_QUEUE/queue/tasks/ashigaru1.yaml" "task.status" "done" 45
    if [ "$status" -ne 0 ]; then
        dump_pane_for_debug "$ashigaru1_pane" "ashigaru1-claude-C"
        dump_watcher_log "$log_file"
    fi
    assert_success

    # 5. Check that startup prompt was NOT sent (claude doesn't need it)
    run grep "Sending startup prompt" "$log_file"
    assert_failure

    # 6. Check that /clear was sent (not /new)
    run grep "CONTEXT-RESET.*Sending /clear" "$log_file"
    assert_success

    # Cleanup
    stop_inbox_watcher "$watcher_pid"
}

# ═══════════════════════════════════════════════════════════════
# E2E-008-D: Codex clear_command sends /new exactly once
#            (dedup guard prevents multiple /new sends)
# ═══════════════════════════════════════════════════════════════
# Regression test for the /new multi-send bug where clear_command
# followed by auto-recovery task_assigned caused 2+ /new sends,
# wiping the startup prompt each time.

@test "E2E-008-D: Codex clear_command sends /new exactly once, not multiple times" {
    local ashigaru1_pane
    ashigaru1_pane=$(pane_target 1)

    # 1. Respawn pane with codex mock
    tmux respawn-pane -k -t "$ashigaru1_pane" \
        "MOCK_CLI_TYPE=codex MOCK_AGENT_ID=ashigaru1 MOCK_PROCESSING_DELAY=1 MOCK_PROJECT_ROOT=$E2E_QUEUE bash $PROJECT_ROOT/tests/e2e/mock_cli.sh"
    sleep 2
    tmux set-option -p -t "$ashigaru1_pane" @agent_cli "codex"

    # 2. Place assigned task YAML
    cp "$PROJECT_ROOT/tests/e2e/fixtures/task_ashigaru1_basic.yaml" \
       "$E2E_QUEUE/queue/tasks/ashigaru1.yaml"

    # 3. Send clear_command via inbox_write (simulates karo sending /clear)
    bash "$E2E_QUEUE/scripts/inbox_write.sh" "ashigaru1" \
        "/clear" "clear_command" "karo"

    # 4. Start inbox_watcher with codex CLI type
    local watcher_pid log_file
    watcher_pid=$(start_inbox_watcher "ashigaru1" 1 "codex")
    log_file="/tmp/e2e_inbox_watcher_ashigaru1_$$.log"

    # 5. Wait for task to complete
    run wait_for_yaml_value "$E2E_QUEUE/queue/tasks/ashigaru1.yaml" "task.status" "done" 60
    if [ "$status" -ne 0 ]; then
        dump_pane_for_debug "$ashigaru1_pane" "ashigaru1-codex-D"
        dump_watcher_log "$log_file"
    fi
    assert_success

    # 6. Count /new sends in watcher log — must be exactly 1
    local new_count
    new_count=$(grep -c "Codex /clear→/new" "$log_file" 2>/dev/null || true)
    if [ "$new_count" -ne 1 ]; then
        echo "Expected 1 /new send, got $new_count" >&2
        dump_watcher_log "$log_file"
    fi
    [ "$new_count" -eq 1 ]

    # 7. Verify startup prompt was sent exactly once
    local startup_count
    startup_count=$(grep -c "Sending startup prompt to ashigaru1" "$log_file" 2>/dev/null || true)
    if [ "$startup_count" -ne 1 ]; then
        echo "Expected 1 startup prompt, got $startup_count" >&2
        dump_watcher_log "$log_file"
    fi
    [ "$startup_count" -eq 1 ]

    # 8. Verify no duplicate context-reset /new was sent
    local context_reset_new_count
    context_reset_new_count=$(grep -c "CONTEXT-RESET.*Sending /new" "$log_file" 2>/dev/null || true)
    if [ "$context_reset_new_count" -ne 0 ]; then
        echo "Expected 0 context-reset /new sends (clear_command path should skip), got $context_reset_new_count" >&2
        dump_watcher_log "$log_file"
    fi
    [ "$context_reset_new_count" -eq 0 ]

    # Cleanup
    stop_inbox_watcher "$watcher_pid"
}

# ═══════════════════════════════════════════════════════════════
# E2E-008-E: Multiple clear_commands to Codex agent still
#            result in only one /new send
# ═══════════════════════════════════════════════════════════════

@test "E2E-008-E: Multiple rapid clear_commands to Codex result in single /new" {
    local ashigaru1_pane
    ashigaru1_pane=$(pane_target 1)

    # 1. Respawn pane with codex mock
    tmux respawn-pane -k -t "$ashigaru1_pane" \
        "MOCK_CLI_TYPE=codex MOCK_AGENT_ID=ashigaru1 MOCK_PROCESSING_DELAY=1 MOCK_PROJECT_ROOT=$E2E_QUEUE bash $PROJECT_ROOT/tests/e2e/mock_cli.sh"
    sleep 2
    tmux set-option -p -t "$ashigaru1_pane" @agent_cli "codex"

    # 2. Place assigned task YAML
    cp "$PROJECT_ROOT/tests/e2e/fixtures/task_ashigaru1_basic.yaml" \
       "$E2E_QUEUE/queue/tasks/ashigaru1.yaml"

    # 3. Send THREE clear_commands in rapid succession (simulates karo bug)
    bash "$E2E_QUEUE/scripts/inbox_write.sh" "ashigaru1" \
        "/clear" "clear_command" "karo"
    bash "$E2E_QUEUE/scripts/inbox_write.sh" "ashigaru1" \
        "/clear" "clear_command" "karo"
    bash "$E2E_QUEUE/scripts/inbox_write.sh" "ashigaru1" \
        "/clear" "clear_command" "karo"

    # 4. Start inbox_watcher with codex CLI type
    local watcher_pid log_file
    watcher_pid=$(start_inbox_watcher "ashigaru1" 1 "codex")
    log_file="/tmp/e2e_inbox_watcher_ashigaru1_$$.log"

    # 5. Wait for task to complete
    run wait_for_yaml_value "$E2E_QUEUE/queue/tasks/ashigaru1.yaml" "task.status" "done" 60
    if [ "$status" -ne 0 ]; then
        dump_pane_for_debug "$ashigaru1_pane" "ashigaru1-codex-E"
        dump_watcher_log "$log_file"
    fi
    assert_success

    # 6. Count /new sends — must be exactly 1 despite 3 clear_commands
    local new_count
    new_count=$(grep -c "Codex /clear→/new" "$log_file" 2>/dev/null || true)
    if [ "$new_count" -ne 1 ]; then
        echo "Expected 1 /new send despite 3 clear_commands, got $new_count" >&2
        dump_watcher_log "$log_file"
    fi
    [ "$new_count" -eq 1 ]

    # 7. Verify extra clear_commands were suppressed (dedup or busy deferral)
    local skip_count
    skip_count=$(grep -c -E "SKIP.*(Codex /new already sent|is busy.*deferred)" "$log_file" 2>/dev/null || true)
    if [ "$skip_count" -lt 1 ]; then
        echo "Expected at least 1 dedup/deferral skip log, got $skip_count" >&2
        dump_watcher_log "$log_file"
    fi
    [ "$skip_count" -ge 1 ]

    # Cleanup
    stop_inbox_watcher "$watcher_pid"
}

# ═══════════════════════════════════════════════════════════════
# E2E-008-F: Claude agent at welcome screen (no idle flag)
#            receives nudge via inbox_watcher initial flag creation
# ═══════════════════════════════════════════════════════════════
# Regression test for false-busy deadlock: when Claude CLI is at its
# welcome screen, no stop_hook has ever fired, so no idle flag exists.
# inbox_watcher must create the initial idle flag at startup so that
# nudge delivery isn't blocked by false-busy detection.

@test "E2E-008-F: Claude at welcome screen with no idle flag — nudge delivered via initial flag" {
    local ashigaru1_pane
    ashigaru1_pane=$(pane_target 1)

    # Use isolated IDLE_FLAG_DIR to avoid cross-test contamination
    local flag_dir
    flag_dir=$(mktemp -d "/tmp/e2e_idle_flags_XXXXXX")
    export IDLE_FLAG_DIR="$flag_dir"

    # 1. Respawn pane with claude mock
    tmux respawn-pane -k -t "$ashigaru1_pane" \
        "IDLE_FLAG_DIR=$flag_dir MOCK_CLI_TYPE=claude MOCK_AGENT_ID=ashigaru1 MOCK_PROCESSING_DELAY=1 MOCK_PROJECT_ROOT=$E2E_QUEUE bash $PROJECT_ROOT/tests/e2e/mock_cli.sh"
    sleep 2
    tmux set-option -p -t "$ashigaru1_pane" @agent_cli "claude"

    # 2. Remove any idle flag that mock_cli created on startup
    #    (simulates real CLI at welcome screen where stop_hook hasn't fired)
    rm -f "$flag_dir/shogun_idle_ashigaru1"

    # Verify flag is truly gone — this is the precondition for the test
    [ ! -f "$flag_dir/shogun_idle_ashigaru1" ]

    # 3. Place assigned task YAML
    cp "$PROJECT_ROOT/tests/e2e/fixtures/task_ashigaru1_basic.yaml" \
       "$E2E_QUEUE/queue/tasks/ashigaru1.yaml"

    # 4. Send task_assigned message (unread message waiting)
    bash "$E2E_QUEUE/scripts/inbox_write.sh" "ashigaru1" \
        "タスクYAMLを読んで作業開始せよ。" "task_assigned" "karo"

    # 5. Start inbox_watcher — this is where the fix kicks in:
    #    inbox_watcher should create the initial idle flag for Claude CLI
    local watcher_pid log_file
    log_file="/tmp/e2e_inbox_watcher_ashigaru1_$$.log"
    IDLE_FLAG_DIR="$flag_dir" \
    ESCALATE_PHASE1="${E2E_ESCALATE_PHASE1:-10}" \
    ESCALATE_PHASE2="${E2E_ESCALATE_PHASE2:-20}" \
    ESCALATE_COOLDOWN="${E2E_ESCALATE_COOLDOWN:-25}" \
    INOTIFY_TIMEOUT="${E2E_INOTIFY_TIMEOUT:-5}" \
    bash "$E2E_QUEUE/scripts/inbox_watcher.sh" "ashigaru1" "$ashigaru1_pane" "claude" \
        > "$log_file" 2>&1 &
    watcher_pid=$!

    # 6. Wait for task to complete (proves initial flag + nudge chain worked)
    #    The initial idle flag is created, then consumed by context-reset→nudge,
    #    so we verify via log + task completion rather than flag file existence.
    run wait_for_yaml_value "$E2E_QUEUE/queue/tasks/ashigaru1.yaml" "task.status" "done" 45
    if [ "$status" -ne 0 ]; then
        dump_pane_for_debug "$ashigaru1_pane" "ashigaru1-claude-F"
        dump_watcher_log "$log_file"
    fi
    assert_success

    # 7. Verify initial flag creation was logged (proves the fix is active)
    run grep "Created initial idle flag for ashigaru1" "$log_file"
    if [ "$status" -ne 0 ]; then
        dump_watcher_log "$log_file"
    fi
    assert_success

    # 8. Verify NO "agent is busy" log for this agent
    #    (without the fix, this would show repeated "busy" messages)
    run grep "unread for ashigaru1 but agent is busy (claude)" "$log_file"
    assert_failure

    # Cleanup
    stop_inbox_watcher "$watcher_pid"
    rm -rf "$flag_dir"
}
