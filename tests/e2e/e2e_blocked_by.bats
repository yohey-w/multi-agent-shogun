#!/usr/bin/env bats
# ═══════════════════════════════════════════════════════════════
# E2E-007: blocked_by Dependency Test
# ═══════════════════════════════════════════════════════════════
# Validates task dependency ordering:
#   1. Task A (ashigaru1) has no dependencies → executes immediately
#   2. Task B (ashigaru2) has blocked_by: [task_A] → waits
#   3. After task A completes, karo unblocks task B
#   4. Task B executes and completes
#
# Simulates karo's dependency resolution logic.
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
# E2E-007-A: Blocked task waits until dependency completes
# ═══════════════════════════════════════════════════════════════

@test "E2E-007-A: task B waits for task A to complete before starting" {
    local ashigaru1_pane ashigaru2_pane
    ashigaru1_pane=$(pane_target 1)
    ashigaru2_pane=$(pane_target 2)

    # 1. Place task A for ashigaru1 (no blocked_by)
    cp "$PROJECT_ROOT/tests/e2e/fixtures/task_ashigaru1_basic.yaml" \
       "$E2E_QUEUE/queue/tasks/ashigaru1.yaml"

    # 2. Place task B for ashigaru2 (blocked_by: subtask_test_001a)
    cp "$PROJECT_ROOT/tests/e2e/fixtures/task_ashigaru2_blocked.yaml" \
       "$E2E_QUEUE/queue/tasks/ashigaru2.yaml"

    # 3. Only send task_assigned to ashigaru1 (ashigaru2 is blocked)
    bash "$E2E_QUEUE/scripts/inbox_write.sh" "ashigaru1" \
        "タスクYAMLを読んで作業開始せよ。" "task_assigned" "karo"
    send_to_pane "$ashigaru1_pane" "inbox1"

    # 4. Verify task B is still blocked (not started)
    sleep 2
    assert_yaml_field "$E2E_QUEUE/queue/tasks/ashigaru2.yaml" "task.status" "blocked"

    # 5. Wait for task A to complete
    run wait_for_yaml_value "$E2E_QUEUE/queue/tasks/ashigaru1.yaml" "task.status" "done" 30
    assert_success

    # 6. Simulate karo unblocking task B: change status from blocked → assigned
    python3 -c "
import yaml, os, tempfile
with open('$E2E_QUEUE/queue/tasks/ashigaru2.yaml') as f:
    data = yaml.safe_load(f)
data['task']['status'] = 'assigned'
tmp_fd, tmp_path = tempfile.mkstemp(dir='$E2E_QUEUE/queue/tasks', suffix='.tmp')
with os.fdopen(tmp_fd, 'w') as f:
    yaml.dump(data, f, default_flow_style=False, allow_unicode=True, indent=2)
os.replace(tmp_path, '$E2E_QUEUE/queue/tasks/ashigaru2.yaml')
"

    # 7. Send task_assigned to ashigaru2
    bash "$E2E_QUEUE/scripts/inbox_write.sh" "ashigaru2" \
        "タスクYAMLを読んで作業開始せよ。ブロック解除。" "task_assigned" "karo"
    send_to_pane "$ashigaru2_pane" "inbox1"

    # 8. Wait for task B to complete
    run wait_for_yaml_value "$E2E_QUEUE/queue/tasks/ashigaru2.yaml" "task.status" "done" 30
    assert_success

    # 9. Both reports should exist
    run wait_for_file "$E2E_QUEUE/queue/reports/ashigaru1_report.yaml" 10
    assert_success
    run wait_for_file "$E2E_QUEUE/queue/reports/ashigaru2_report.yaml" 10
    assert_success
}

# ═══════════════════════════════════════════════════════════════
# E2E-007-B: Blocked task is not processed even if nudged
# ═══════════════════════════════════════════════════════════════

@test "E2E-007-B: blocked task ignores inbox nudge until unblocked" {
    local ashigaru2_pane
    ashigaru2_pane=$(pane_target 2)

    # 1. Place blocked task for ashigaru2
    cp "$PROJECT_ROOT/tests/e2e/fixtures/task_ashigaru2_blocked.yaml" \
       "$E2E_QUEUE/queue/tasks/ashigaru2.yaml"

    # 2. Send task_assigned and nudge (even though task is blocked)
    bash "$E2E_QUEUE/scripts/inbox_write.sh" "ashigaru2" \
        "タスクYAMLを読んで作業開始せよ。" "task_assigned" "karo"
    send_to_pane "$ashigaru2_pane" "inbox1"

    # 3. Wait a reasonable time
    sleep 5

    # 4. Task should still be blocked (mock_cli skips non-assigned tasks)
    assert_yaml_field "$E2E_QUEUE/queue/tasks/ashigaru2.yaml" "task.status" "blocked"

    # 5. No report should be created
    [ ! -f "$E2E_QUEUE/queue/reports/ashigaru2_report.yaml" ]
}
