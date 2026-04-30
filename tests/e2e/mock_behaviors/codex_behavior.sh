#!/usr/bin/env bash
# codex_behavior.sh — Codex CLI specific mock behaviors
# Handles /new (Codex equivalent of /clear), suggestion UI, and Codex-specific prompts.

# Codex CLI startup banner
codex_startup_banner() {
    echo "╭────────────────────────────────────────╮"
    echo "│        Codex CLI (mock)                │"
    echo "│        ? for shortcuts                 │"
    echo "╰────────────────────────────────────────╯"
    echo "                                    100% context left"
}

# Handle /new command (Codex equivalent of /clear)
# Resets state and re-reads task YAML
codex_handle_clear() {
    local agent_id="$1"
    local project_root="$2"

    echo "[mock] /new received — starting new conversation for $agent_id"
    local task_file="$project_root/queue/tasks/${agent_id}.yaml"
    if [ -f "$task_file" ]; then
        local status
        status=$(yaml_read "$task_file" "task.status")
        if [ "$status" = "assigned" ]; then
            echo "[mock] Found assigned task after /new — resuming"
            return 0  # signal: task available
        fi
    fi
    return 1  # signal: no task
}

# Codex idle prompt pattern (matches agent_is_busy() detection)
codex_idle_prompt() {
    echo ""
    echo "? for shortcuts                100% context left"
    echo "$ "
}
