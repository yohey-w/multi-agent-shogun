#!/usr/bin/env bats
# ═══════════════════════════════════════════════════════════════
# E2E-009: busy中/clear抑制テスト
# ═══════════════════════════════════════════════════════════════
# Verifies inbox_watcher behavior when clear_command arrives while
# an agent is working:
#   - busy state: clear_command is deferred (no /clear sent)
#   - idle state: clear_command is sent to the agent
# ═══════════════════════════════════════════════════════════════

# bats file_tags=e2e

load "../test_helper/bats-support/load"
load "../test_helper/bats-assert/load"

E2E_HELPERS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/helpers" && pwd)"
source "$E2E_HELPERS_DIR/setup.bash"
source "$E2E_HELPERS_DIR/assertions.bash"
source "$E2E_HELPERS_DIR/tmux_helpers.bash"

setup_file() {
    command -v tmux &>/dev/null || skip "tmux not available"
    command -v python3 &>/dev/null || skip "python3 not available"
    python3 -c "import yaml" 2>/dev/null || skip "python3-yaml not available"

    setup_e2e_session 2
    mkdir -p "$E2E_QUEUE/.venv/bin"
    ln -sf "$(command -v python3)" "$E2E_QUEUE/.venv/bin/python3"
}

teardown_file() {
    teardown_e2e_session
}

setup() {
    reset_queues
    mkdir -p "$E2E_QUEUE/.venv/bin"
    ln -sf "$(command -v python3)" "$E2E_QUEUE/.venv/bin/python3"
    sleep 2
}

wait_for_log() {
    local log_file="$1" pattern="$2" timeout="${3:-20}"
    local elapsed=0
    while [ "$elapsed" -lt "$timeout" ]; do
        if grep -qF "$pattern" "$log_file" 2>/dev/null; then
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    echo "TIMEOUT: '$pattern' not found in $log_file after ${timeout}s" >&2
    return 1
}

# ═══ E2E-009-A: clear_command is deferred while busy ═══

@test "E2E-009-A: clear_command is deferred when agent is busy (no /clear sent)" {
    local ashigaru1_pane
    ashigaru1_pane=$(pane_target 1)
    local log_file watcher_pid

    cp "$PROJECT_ROOT/tests/e2e/fixtures/task_ashigaru1_basic.yaml" \
        "$E2E_QUEUE/queue/tasks/ashigaru1.yaml"

    # Keep mock in busy state before clear_command arrives.
    send_to_pane "$ashigaru1_pane" "busy_hold 2"
    sleep 2

    tmux set-option -p -t "$ashigaru1_pane" @agent_cli "copilot"
    log_file="/tmp/e2e_inbox_watcher_ashigaru1_busy_${BASHPID}.log"
    watcher_pid=$(
        bash "$E2E_QUEUE/scripts/inbox_watcher.sh" "ashigaru1" "$ashigaru1_pane" "copilot" \
            > "$log_file" 2>&1 &
        echo $!
    )
    sleep 2

    bash "$E2E_QUEUE/scripts/inbox_write.sh" "ashigaru1" \
        "/clear" "clear_command" "karo"

    run wait_for_log "$log_file" "[SKIP] Agent ashigaru1 is busy — /clear (clear_command) deferred to next cycle"
    assert_success

    # Busy suppression keeps task unprocessed by /clear path.
    run wait_for_yaml_value "$E2E_QUEUE/queue/tasks/ashigaru1.yaml" "task.status" "assigned" 30
    assert_success

    run grep -qF "[SEND-KEYS] Copilot /clear: sending Ctrl-C + restart for ashigaru1" "$log_file"
    [ "$status" -ne 0 ]

    stop_inbox_watcher "$watcher_pid"
}

# ═══ E2E-009-B: clear_command is sent when idle ═══

@test "E2E-009-B: clear_command is sent when agent is idle" {
    local ashigaru1_pane
    ashigaru1_pane=$(pane_target 1)
    local log_file watcher_pid
    local idle_flag="/tmp/shogun_idle_ashigaru1"

    touch "$idle_flag"

    cp "$PROJECT_ROOT/tests/e2e/fixtures/task_ashigaru1_basic.yaml" \
        "$E2E_QUEUE/queue/tasks/ashigaru1.yaml"

    tmux set-option -p -t "$ashigaru1_pane" @agent_cli "claude"
    log_file="/tmp/e2e_inbox_watcher_ashigaru1_idle_${BASHPID}.log"
    watcher_pid=$(
        bash "$E2E_QUEUE/scripts/inbox_watcher.sh" "ashigaru1" "$ashigaru1_pane" "claude" \
            > "$log_file" 2>&1 &
        echo $!
    )
    sleep 2

    bash "$E2E_QUEUE/scripts/inbox_write.sh" "ashigaru1" \
        "/clear" "clear_command" "karo"

    run wait_for_log "$log_file" "[SEND-KEYS] Sending CLI command to ashigaru1 (claude): /clear"
    assert_success

    run wait_for_yaml_value "$E2E_QUEUE/queue/tasks/ashigaru1.yaml" "task.status" "done" 45
    assert_success

    stop_inbox_watcher "$watcher_pid"
}
