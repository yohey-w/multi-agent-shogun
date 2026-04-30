#!/usr/bin/env bats
# ═══════════════════════════════════════════════════════════════
# E2E-003: /clear Recovery Test
# ═══════════════════════════════════════════════════════════════
# Validates that after /clear, the mock CLI:
#   1. Resets state
#   2. Re-reads task YAML
#   3. Detects assigned task and processes it
#   4. Completes successfully with report
#
# Uses mock_cli.sh handle_clear() function.
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
# E2E-003-A: /clear with assigned task triggers processing
# ═══════════════════════════════════════════════════════════════

@test "E2E-003-A: /clear with assigned task triggers auto-recovery" {
    # 1. Place task YAML for ashigaru1 (status: assigned)
    cp "$PROJECT_ROOT/tests/e2e/fixtures/task_ashigaru1_basic.yaml" \
       "$E2E_QUEUE/queue/tasks/ashigaru1.yaml"

    # 2. Send /clear to ashigaru1 (not inbox nudge — direct /clear)
    local ashigaru1_pane
    ashigaru1_pane=$(pane_target 1)
    send_to_pane "$ashigaru1_pane" "/clear"

    # 3. Wait for task to complete (handle_clear detects assigned task)
    run wait_for_yaml_value "$E2E_QUEUE/queue/tasks/ashigaru1.yaml" "task.status" "done" 30
    assert_success

    # 4. Verify report was written
    run wait_for_file "$E2E_QUEUE/queue/reports/ashigaru1_report.yaml" 10
    assert_success

    # 5. Verify report content
    assert_yaml_field "$E2E_QUEUE/queue/reports/ashigaru1_report.yaml" "status" "done"
    assert_yaml_field "$E2E_QUEUE/queue/reports/ashigaru1_report.yaml" "task_id" "subtask_test_001a"
}

# ═══════════════════════════════════════════════════════════════
# E2E-003-B: /clear without task does not crash
# ═══════════════════════════════════════════════════════════════

@test "E2E-003-B: /clear without assigned task does not crash" {
    # 1. No task YAML placed — ashigaru1 has nothing to do

    # 2. Send /clear
    local ashigaru1_pane
    ashigaru1_pane=$(pane_target 1)
    send_to_pane "$ashigaru1_pane" "/clear"

    # 3. Wait for mock to process /clear
    sleep 3

    # 4. No report should be created (no task was processed)
    [ ! -f "$E2E_QUEUE/queue/reports/ashigaru1_report.yaml" ]

    # 5. Verify mock is still alive — send test input, check it's processed
    send_to_pane "$ashigaru1_pane" "health_check"
    run wait_for_pane_text "$ashigaru1_pane" "Processed input: health_check" 10
    assert_success
}

# ═══════════════════════════════════════════════════════════════
# E2E-003-C: /clear during idle, then task assigned, then inbox
# ═══════════════════════════════════════════════════════════════
# Simulates: agent gets /clear → recovers → then new task arrives normally

@test "E2E-003-C: /clear recovery then normal task processing works" {
    local ashigaru1_pane
    ashigaru1_pane=$(pane_target 1)

    # 1. Send /clear first (no task)
    send_to_pane "$ashigaru1_pane" "/clear"
    sleep 3

    # 2. Now place task and send normal inbox nudge
    cp "$PROJECT_ROOT/tests/e2e/fixtures/task_ashigaru1_basic.yaml" \
       "$E2E_QUEUE/queue/tasks/ashigaru1.yaml"

    bash "$E2E_QUEUE/scripts/inbox_write.sh" "ashigaru1" \
        "タスクYAMLを読んで作業開始せよ。" "task_assigned" "karo"

    send_to_pane "$ashigaru1_pane" "inbox1"

    # 3. Task should complete normally
    run wait_for_yaml_value "$E2E_QUEUE/queue/tasks/ashigaru1.yaml" "task.status" "done" 30
    assert_success

    # 4. Report should exist
    run wait_for_file "$E2E_QUEUE/queue/reports/ashigaru1_report.yaml" 10
    assert_success
}
