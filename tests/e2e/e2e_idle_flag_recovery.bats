#!/usr/bin/env bats
# ═══════════════════════════════════════════════════════════════
# E2E-010: /clear + idle flag recovery
# ═══════════════════════════════════════════════════════════════
# Validates:
#   A) /clear processing restores idle flag (IDLE_FLAG_DIR)
#   B) stale busy recovery can force idle flag creation
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
}

teardown_file() {
    teardown_e2e_session
}

setup() {
    reset_queues
    sleep 1
}

wait_for_file_within() {
    local target="$1" timeout="${2:-20}"
    local elapsed=0
    while [ "$elapsed" -lt "$timeout" ]; do
        [ -f "$target" ] && return 0
        sleep 1
        elapsed=$((elapsed + 1))
    done
    echo "TIMEOUT: file not found: $target" >&2
    return 1
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

# ═══ E2E-010-A: /clear後にidle flagが作成される ═══

@test "E2E-010-A: /clear recovery creates idle flag" {
    local ashigaru1_pane
    ashigaru1_pane=$(pane_target 1)
    local flag_dir log_file watcher_pid

    flag_dir="$(mktemp -d "/tmp/e2e_idle_flags_XXXXXX")"
    local ashigaru_idle_flag="$flag_dir/shogun_idle_ashigaru1"

    cp "$PROJECT_ROOT/tests/e2e/fixtures/task_ashigaru1_basic.yaml" \
        "$E2E_QUEUE/queue/tasks/ashigaru1.yaml"

    log_file="/tmp/e2e_inbox_watcher_ashigaru1_clear_${BASHPID}.log"
    watcher_pid=$(
        IDLE_FLAG_DIR="$flag_dir" \
        bash "$E2E_QUEUE/scripts/inbox_watcher.sh" "ashigaru1" "$ashigaru1_pane" "claude" \
            > "$log_file" 2>&1 &
        echo $!
    )
    sleep 1

    bash "$E2E_QUEUE/scripts/inbox_write.sh" "ashigaru1" \
        "/clear" "clear_command" "karo"

    run wait_for_yaml_value "$E2E_QUEUE/queue/tasks/ashigaru1.yaml" "task.status" "done" 45
    assert_success

    run wait_for_file_within "$ashigaru_idle_flag" 10
    assert_success

    stop_inbox_watcher "$watcher_pid"
    rm -rf "$flag_dir"
}

# ═══ E2E-010-B: stale busy recovery forces idle flag ═══

@test "E2E-010-B: stale busy recovery forces idle flag creation" {
    local ashigaru1_pane
    ashigaru1_pane=$(pane_target 1)
    local flag_dir log_file watcher_pid first_unread_seen

    flag_dir="$(mktemp -d "/tmp/e2e_idle_flags_stale_XXXXXX")"
    local ashigaru_idle_flag="$flag_dir/shogun_idle_ashigaru1"
    first_unread_seen=$(( $(date +%s) - 420 ))

    # Start mock in busy state before unread messages arrive.
    send_to_pane "$ashigaru1_pane" "busy_hold 12"
    sleep 1

    cp "$PROJECT_ROOT/tests/e2e/fixtures/task_ashigaru1_basic.yaml" \
        "$E2E_QUEUE/queue/tasks/ashigaru1.yaml"

    bash "$E2E_QUEUE/scripts/inbox_write.sh" "ashigaru1" \
        "タスクYAMLを読んで作業開始せよ。" "task_assigned" "karo"

    log_file="/tmp/e2e_inbox_watcher_ashigaru1_stale_busy_${BASHPID}.log"
    watcher_pid=$(
        IDLE_FLAG_DIR="$flag_dir" \
        FIRST_UNREAD_SEEN="$first_unread_seen" \
        bash "$E2E_QUEUE/scripts/inbox_watcher.sh" "ashigaru1" "$ashigaru1_pane" "copilot" \
            > "$log_file" 2>&1 &
        echo $!
    )

    run wait_for_log "$log_file" "forcing idle flag"
    assert_success

    run wait_for_file_within "$ashigaru_idle_flag" 10
    assert_success

    run wait_for_yaml_value "$E2E_QUEUE/queue/tasks/ashigaru1.yaml" "task.status" "done" 45
    assert_success

    stop_inbox_watcher "$watcher_pid"
    rm -rf "$flag_dir"
}
