#!/usr/bin/env bats
# ═══════════════════════════════════════════════════════════════
# E2E-004: Escalation / Busy State Test
# ═══════════════════════════════════════════════════════════════
# Validates busy state behavior:
#   1. Agent in busy_hold state cannot process inbox immediately
#   2. After busy_hold ends, queued input is processed
#   3. Task eventually completes
#
# Uses mock_cli.sh busy_hold command (no inbox_watcher needed).
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

# ═══════════════════════════════════════════════════════════════
# E2E-004-A: Busy agent defers processing, completes after idle
# ═══════════════════════════════════════════════════════════════

@test "E2E-004-A: busy agent defers inbox processing until idle" {
    local ashigaru1_pane
    ashigaru1_pane=$(pane_target 1)

    # 1. Place task YAML
    cp "$PROJECT_ROOT/tests/e2e/fixtures/task_ashigaru1_basic.yaml" \
       "$E2E_QUEUE/queue/tasks/ashigaru1.yaml"

    # 2. Write task_assigned to inbox
    bash "$E2E_QUEUE/scripts/inbox_write.sh" "ashigaru1" \
        "タスクYAMLを読んで作業開始せよ。" "task_assigned" "karo"

    # 3. Put agent into busy state for 6 seconds BEFORE sending nudge
    send_to_pane "$ashigaru1_pane" "busy_hold 6"
    sleep 2  # Ensure busy state is active

    # 4. Verify agent is busy (pane shows Working)
    run wait_for_pane_text "$ashigaru1_pane" "esc to interrupt" 5
    assert_success

    # 5. Send nudge — will queue in terminal input buffer
    send_to_pane "$ashigaru1_pane" "inbox1"

    # 6. Task should NOT be done yet (agent is busy)
    sleep 1
    local status
    status=$(python3 -c "
import yaml
try:
    with open('$E2E_QUEUE/queue/tasks/ashigaru1.yaml') as f:
        data = yaml.safe_load(f)
    print(data.get('task',{}).get('status',''))
except: print('')
" 2>/dev/null)
    [ "$status" = "assigned" ]

    # 7. Wait for busy_hold to end + inbox processing
    run wait_for_yaml_value "$E2E_QUEUE/queue/tasks/ashigaru1.yaml" "task.status" "done" 30
    assert_success

    # 8. Report should exist
    run wait_for_file "$E2E_QUEUE/queue/reports/ashigaru1_report.yaml" 10
    assert_success
}

# ═══════════════════════════════════════════════════════════════
# E2E-004-B: busy_hold correctly transitions idle → busy → idle
# ═══════════════════════════════════════════════════════════════

@test "E2E-004-B: busy_hold shows correct state transitions" {
    local ashigaru1_pane
    ashigaru1_pane=$(pane_target 1)

    # 1. Send busy_hold for 4 seconds
    send_to_pane "$ashigaru1_pane" "busy_hold 4"

    # 2. Verify busy state appears
    run wait_for_pane_text "$ashigaru1_pane" "esc to interrupt" 5
    assert_success

    # 3. Wait for busy_hold to finish
    sleep 5

    # 4. Send a health check to verify agent is responsive again
    send_to_pane "$ashigaru1_pane" "health_check"
    run wait_for_pane_text "$ashigaru1_pane" "Processed input: health_check" 10
    assert_success
}
