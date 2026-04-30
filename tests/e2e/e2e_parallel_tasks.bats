#!/usr/bin/env bats
# ═══════════════════════════════════════════════════════════════
# E2E-006: Parallel Tasks Test
# ═══════════════════════════════════════════════════════════════
# Validates that multiple ashigaru can process tasks simultaneously:
#   1. Two tasks assigned to ashigaru1 and ashigaru2
#   2. Both receive inbox nudges
#   3. Both complete independently
#   4. Both reports are written
#
# Uses 3-pane setup (karo + ashigaru1 + ashigaru2).
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
# E2E-006-A: Two ashigaru process tasks in parallel
# ═══════════════════════════════════════════════════════════════

@test "E2E-006-A: ashigaru1 and ashigaru2 complete tasks in parallel" {
    # 1. Place tasks for both ashigaru
    cp "$PROJECT_ROOT/tests/e2e/fixtures/task_ashigaru1_basic.yaml" \
       "$E2E_QUEUE/queue/tasks/ashigaru1.yaml"
    cp "$PROJECT_ROOT/tests/e2e/fixtures/task_ashigaru2_basic.yaml" \
       "$E2E_QUEUE/queue/tasks/ashigaru2.yaml"

    # 2. Send task_assigned to both inboxes
    bash "$E2E_QUEUE/scripts/inbox_write.sh" "ashigaru1" \
        "タスクYAMLを読んで作業開始せよ。" "task_assigned" "karo"
    bash "$E2E_QUEUE/scripts/inbox_write.sh" "ashigaru2" \
        "タスクYAMLを読んで作業開始せよ。" "task_assigned" "karo"

    # 3. Nudge both simultaneously
    local ashigaru1_pane ashigaru2_pane
    ashigaru1_pane=$(pane_target 1)
    ashigaru2_pane=$(pane_target 2)

    send_to_pane "$ashigaru1_pane" "inbox1"
    send_to_pane "$ashigaru2_pane" "inbox1"

    # 4. Both should complete
    run wait_for_yaml_value "$E2E_QUEUE/queue/tasks/ashigaru1.yaml" "task.status" "done" 30
    assert_success
    run wait_for_yaml_value "$E2E_QUEUE/queue/tasks/ashigaru2.yaml" "task.status" "done" 30
    assert_success

    # 5. Both reports should exist
    run wait_for_file "$E2E_QUEUE/queue/reports/ashigaru1_report.yaml" 10
    assert_success
    run wait_for_file "$E2E_QUEUE/queue/reports/ashigaru2_report.yaml" 10
    assert_success

    # 6. Reports should have correct agent IDs
    assert_yaml_field "$E2E_QUEUE/queue/reports/ashigaru1_report.yaml" "worker_id" "ashigaru1"
    assert_yaml_field "$E2E_QUEUE/queue/reports/ashigaru2_report.yaml" "worker_id" "ashigaru2"
}

# ═══════════════════════════════════════════════════════════════
# E2E-006-B: Parallel tasks don't interfere with each other's inbox
# ═══════════════════════════════════════════════════════════════

@test "E2E-006-B: parallel tasks maintain inbox isolation" {
    # 1. Place tasks and send notifications
    cp "$PROJECT_ROOT/tests/e2e/fixtures/task_ashigaru1_basic.yaml" \
       "$E2E_QUEUE/queue/tasks/ashigaru1.yaml"
    cp "$PROJECT_ROOT/tests/e2e/fixtures/task_ashigaru2_basic.yaml" \
       "$E2E_QUEUE/queue/tasks/ashigaru2.yaml"

    bash "$E2E_QUEUE/scripts/inbox_write.sh" "ashigaru1" \
        "タスクYAMLを読んで作業開始せよ。" "task_assigned" "karo"
    bash "$E2E_QUEUE/scripts/inbox_write.sh" "ashigaru2" \
        "タスクYAMLを読んで作業開始せよ。" "task_assigned" "karo"

    local ashigaru1_pane ashigaru2_pane
    ashigaru1_pane=$(pane_target 1)
    ashigaru2_pane=$(pane_target 2)

    send_to_pane "$ashigaru1_pane" "inbox1"
    send_to_pane "$ashigaru2_pane" "inbox1"

    # 2. Wait for both to complete
    run wait_for_yaml_value "$E2E_QUEUE/queue/tasks/ashigaru1.yaml" "task.status" "done" 30
    assert_success
    run wait_for_yaml_value "$E2E_QUEUE/queue/tasks/ashigaru2.yaml" "task.status" "done" 30
    assert_success

    # 3. Each inbox should have its own messages (task_assigned from karo + no cross-contamination)
    # ashigaru1's inbox should NOT have ashigaru2's messages
    run python3 -c "
import yaml
with open('$E2E_QUEUE/queue/inbox/ashigaru1.yaml') as f:
    data = yaml.safe_load(f) or {}
msgs = data.get('messages', [])
# All messages in ashigaru1's inbox should be addressed to ashigaru1 context
# (no ashigaru2 task_assigned should appear here)
for m in msgs:
    if m.get('type') == 'task_assigned' and 'ashigaru2' in str(m.get('content', '')):
        print('CROSS-CONTAMINATION DETECTED')
        exit(1)
"
    assert_success
}
