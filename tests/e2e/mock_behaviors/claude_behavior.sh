#!/usr/bin/env bash
# claude_behavior.sh — Claude Code CLI specific mock behaviors
# Handles /clear, Stop Hook simulation, and Claude-specific prompts.

# Claude Code startup banner
claude_startup_banner() {
    echo "╭────────────────────────────────────────╮"
    echo "│        Claude Code (mock)              │"
    echo "│        bypass permissions               │"
    echo "╰────────────────────────────────────────╯"
}

# Handle /clear command (Claude Code behavior)
# Resets state and re-reads task YAML
claude_handle_clear() {
    local agent_id="$1"
    local project_root="$2"

    echo "[mock] /clear received — resetting session for $agent_id"
    # In real Claude Code, /clear reloads CLAUDE.md and restarts.
    # Mock: just re-check task YAML for assigned tasks.
    local task_file="$project_root/queue/tasks/${agent_id}.yaml"
    if [ -f "$task_file" ]; then
        local status
        status=$(yaml_read "$task_file" "task.status")
        if [ "$status" = "assigned" ]; then
            echo "[mock] Found assigned task after /clear — resuming"
            return 0  # signal: task available
        fi
    fi
    return 1  # signal: no task
}

# Claude idle prompt pattern (matches agent_is_busy() detection)
claude_idle_prompt() {
    echo -ne "\033[0m"
    echo ""
    echo "$ "
}
