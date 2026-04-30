#!/usr/bin/env bats
# ═══════════════════════════════════════════════════════════════
# E2E-005: Redo Test
# ═══════════════════════════════════════════════════════════════
# Validates the redo protocol:
#   1. Initial task completes (status: done, report written)
#   2. New task YAML written with redo_of field
#   3. /clear sent directly to agent (simulates inbox_watcher clear_command)
#   4. Agent resets, reads new task YAML, processes redo task
#   5. New report written with new task_id
#   6. redo_of field preserved in task YAML
#
# Uses direct /clear via send_to_pane (no inbox_watcher needed).
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
# E2E-005-A: Complete redo flow — initial task → redo → new task processed
# ═══════════════════════════════════════════════════════════════

@test "E2E-005-A: redo via /clear replaces task and produces new report" {
    local ashigaru1_pane
    ashigaru1_pane=$(pane_target 1)

    # ─── Phase 1: Complete initial task ───

    # 1. Place initial task and process via direct nudge
    cp "$PROJECT_ROOT/tests/e2e/fixtures/task_ashigaru1_basic.yaml" \
       "$E2E_QUEUE/queue/tasks/ashigaru1.yaml"

    bash "$E2E_QUEUE/scripts/inbox_write.sh" "ashigaru1" \
        "初回タスク開始。" "task_assigned" "karo"
    send_to_pane "$ashigaru1_pane" "inbox1"

    # 2. Wait for initial task to complete
    run wait_for_yaml_value "$E2E_QUEUE/queue/tasks/ashigaru1.yaml" "task.status" "done" 30
    assert_success

    # 3. Verify initial report
    run wait_for_file "$E2E_QUEUE/queue/reports/ashigaru1_report.yaml" 10
    assert_success
    assert_yaml_field "$E2E_QUEUE/queue/reports/ashigaru1_report.yaml" "task_id" "subtask_test_001a"

    # ─── Phase 2: Redo ───

    # 4. Write redo task YAML (new task_id, redo_of field, status: assigned)
    cat > "$E2E_QUEUE/queue/tasks/ashigaru1.yaml" <<'EOF'
task:
  task_id: subtask_test_001a2
  parent_cmd: cmd_test_001
  type: implementation
  redo_of: subtask_test_001a
  description: |
    Redo task: re-execute with corrections.
  status: assigned
  timestamp: "2026-01-01T01:00:00"
EOF

    # 5. Send /clear directly (simulates inbox_watcher clear_command delivery)
    send_to_pane "$ashigaru1_pane" "/clear"

    # 6. Wait for redo task to complete
    run wait_for_yaml_value "$E2E_QUEUE/queue/tasks/ashigaru1.yaml" "task.status" "done" 30
    assert_success

    # 7. Verify new report has new task_id
    assert_yaml_field "$E2E_QUEUE/queue/reports/ashigaru1_report.yaml" "task_id" "subtask_test_001a2"
    assert_yaml_field "$E2E_QUEUE/queue/reports/ashigaru1_report.yaml" "status" "done"

    # 8. Verify redo_of field is preserved in task YAML
    assert_yaml_field "$E2E_QUEUE/queue/tasks/ashigaru1.yaml" "task.redo_of" "subtask_test_001a"
}

# ═══════════════════════════════════════════════════════════════
# E2E-005-B: Redo does not corrupt inbox — all messages processed
# ═══════════════════════════════════════════════════════════════

@test "E2E-005-B: redo preserves task history — redo_of field intact" {
    local ashigaru1_pane
    ashigaru1_pane=$(pane_target 1)

    # 1. Complete initial task via direct nudge
    cp "$PROJECT_ROOT/tests/e2e/fixtures/task_ashigaru1_basic.yaml" \
       "$E2E_QUEUE/queue/tasks/ashigaru1.yaml"

    bash "$E2E_QUEUE/scripts/inbox_write.sh" "ashigaru1" \
        "初回タスク開始。" "task_assigned" "karo"
    send_to_pane "$ashigaru1_pane" "inbox1"

    run wait_for_yaml_value "$E2E_QUEUE/queue/tasks/ashigaru1.yaml" "task.status" "done" 30
    assert_success

    # 2. Save initial report task_id
    assert_yaml_field "$E2E_QUEUE/queue/reports/ashigaru1_report.yaml" "task_id" "subtask_test_001a"

    # 3. Write redo task YAML
    cat > "$E2E_QUEUE/queue/tasks/ashigaru1.yaml" <<'EOF'
task:
  task_id: subtask_test_001a2
  parent_cmd: cmd_test_001
  type: implementation
  redo_of: subtask_test_001a
  description: |
    Redo task for history test.
  status: assigned
  timestamp: "2026-01-01T01:00:00"
EOF

    # 4. Send /clear directly (simulates inbox_watcher clear_command delivery)
    send_to_pane "$ashigaru1_pane" "/clear"

    # 5. Wait for redo task to complete
    run wait_for_yaml_value "$E2E_QUEUE/queue/tasks/ashigaru1.yaml" "task.status" "done" 30
    assert_success

    # 6. Report now has the NEW task_id (overwritten)
    assert_yaml_field "$E2E_QUEUE/queue/reports/ashigaru1_report.yaml" "task_id" "subtask_test_001a2"

    # 7. redo_of field preserved in task YAML
    assert_yaml_field "$E2E_QUEUE/queue/tasks/ashigaru1.yaml" "task.redo_of" "subtask_test_001a"
}
