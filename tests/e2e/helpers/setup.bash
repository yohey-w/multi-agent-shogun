#!/usr/bin/env bash
# setup.bash — E2E test setup/teardown helpers for bats
# Provides tmux session lifecycle and queue directory management.

# ─── Constants ───
E2E_SESSION_PREFIX="e2e_test"
DEFAULT_PROCESSING_DELAY="${MOCK_PROCESSING_DELAY:-1}"
DEFAULT_AGENTS=("karo" "ashigaru1" "ashigaru2")

# ─── setup_e2e_session ───
# Creates a tmux session with mock CLIs running in panes.
# Call from setup_file() in .bats files.
setup_e2e_session() {
    local num_panes="${1:-3}"

    # Unique session name per test file
    export E2E_SESSION="${E2E_SESSION_PREFIX}_$$"
    export PROJECT_ROOT
    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

    # Create isolated project root with queue/ subdirectory
    # inbox_write.sh resolves SCRIPT_DIR to parent of scripts/, then uses queue/inbox/
    export E2E_QUEUE
    E2E_QUEUE="$(mktemp -d "/tmp/e2e_queue_XXXXXX")"
    mkdir -p "$E2E_QUEUE"/queue/{inbox,tasks,reports,metrics}

    # Copy scripts (SCRIPT_DIR auto-resolves to $E2E_QUEUE from script location)
    mkdir -p "$E2E_QUEUE/scripts"
    cp "$PROJECT_ROOT/scripts/inbox_write.sh" "$E2E_QUEUE/scripts/"
    cp "$PROJECT_ROOT/scripts/inbox_watcher.sh" "$E2E_QUEUE/scripts/"
    chmod +x "$E2E_QUEUE/scripts/inbox_write.sh"
    chmod +x "$E2E_QUEUE/scripts/inbox_watcher.sh"

    # Copy lib/ for cli_adapter.sh and agent_status.sh (needed by inbox_watcher)
    if [ -d "$PROJECT_ROOT/lib" ]; then
        mkdir -p "$E2E_QUEUE/lib"
        cp "$PROJECT_ROOT/lib/cli_adapter.sh" "$E2E_QUEUE/lib/" 2>/dev/null || true
        cp "$PROJECT_ROOT/lib/agent_status.sh" "$E2E_QUEUE/lib/" 2>/dev/null || true
    fi

    # Copy config/ for cli_adapter settings resolution
    if [ -d "$PROJECT_ROOT/config" ]; then
        mkdir -p "$E2E_QUEUE/config"
        cp "$PROJECT_ROOT/config/settings.yaml" "$E2E_QUEUE/config/" 2>/dev/null || true
    fi

    # Link .venv for inbox_watcher.sh (uses $SCRIPT_DIR/.venv/bin/python3)
    if [ -d "$PROJECT_ROOT/.venv" ]; then
        ln -sf "$PROJECT_ROOT/.venv" "$E2E_QUEUE/.venv"
    fi
    # Fallback: if the symlink target is broken or .venv didn't exist at
    # PROJECT_ROOT, create a minimal .venv/bin/python3 pointing to the
    # system python3 so inbox_watcher can still find a working interpreter.
    if [ ! -x "$E2E_QUEUE/.venv/bin/python3" ] && command -v python3 &>/dev/null; then
        rm -f "$E2E_QUEUE/.venv"  # remove broken symlink if any
        mkdir -p "$E2E_QUEUE/.venv/bin"
        ln -sf "$(command -v python3)" "$E2E_QUEUE/.venv/bin/python3"
    fi

    # Initialize empty inboxes
    for agent in "${DEFAULT_AGENTS[@]}"; do
        echo "messages:" > "$E2E_QUEUE/queue/inbox/${agent}.yaml"
    done

    # Create tmux session
    tmux new-session -d -s "$E2E_SESSION" -n agents -x 200 -y 50

    # Split into panes (session starts with 1 pane, need num_panes-1 splits)
    local i
    for ((i = 1; i < num_panes; i++)); do
        tmux split-window -h -t "${E2E_SESSION}:agents"
    done
    # Even out the layout
    tmux select-layout -t "${E2E_SESSION}:agents" even-horizontal

    # Set @agent_id on each pane
    for ((i = 0; i < num_panes && i < ${#DEFAULT_AGENTS[@]}; i++)); do
        tmux set-option -p -t "${E2E_SESSION}:agents.${i}" @agent_id "${DEFAULT_AGENTS[$i]}"
        tmux set-option -p -t "${E2E_SESSION}:agents.${i}" @agent_cli "claude"
    done

    # Start mock CLIs in each pane
    for ((i = 0; i < num_panes && i < ${#DEFAULT_AGENTS[@]}; i++)); do
        local agent_id="${DEFAULT_AGENTS[$i]}"
        tmux send-keys -t "${E2E_SESSION}:agents.${i}" \
            "MOCK_CLI_TYPE=claude MOCK_AGENT_ID=$agent_id MOCK_PROCESSING_DELAY=$DEFAULT_PROCESSING_DELAY MOCK_PROJECT_ROOT=$E2E_QUEUE bash $PROJECT_ROOT/tests/e2e/mock_cli.sh" Enter
    done

    # Wait for mock CLIs to start up
    sleep 2
}

# ─── teardown_e2e_session ───
# Cleans up tmux session and temp directories.
# Call from teardown_file() in .bats files.
teardown_e2e_session() {
    tmux kill-session -t "$E2E_SESSION" 2>/dev/null || true
    if [ -n "${E2E_QUEUE:-}" ] && [ -d "$E2E_QUEUE" ]; then
        rm -rf "$E2E_QUEUE"
    fi
}

# ─── reset_queues ───
# Resets inbox/tasks/reports to clean state between tests.
# Call from setup() in .bats files.
reset_queues() {
    # Reset inboxes
    for agent in "${DEFAULT_AGENTS[@]}"; do
        echo "messages:" > "$E2E_QUEUE/queue/inbox/${agent}.yaml"
    done

    # Clear task files
    rm -f "$E2E_QUEUE"/queue/tasks/*.yaml

    # Clear report files
    rm -f "$E2E_QUEUE"/queue/reports/*.yaml
}

# ─── start_inbox_watcher ───
# Starts inbox_watcher for a specific agent in background.
# Returns PID via stdout.
# Usage: start_inbox_watcher <agent_id> <pane_idx> [cli_type]
start_inbox_watcher() {
    local agent_id="$1"
    local pane_idx="$2"
    local cli_type="${3:-claude}"
    local pane_target="${E2E_SESSION}:agents.${pane_idx}"
    local log_file="/tmp/e2e_inbox_watcher_${agent_id}_$$.log"

    # Override escalation timers for fast testing
    # Run the copied inbox_watcher.sh from E2E_QUEUE/scripts/
    # so SCRIPT_DIR auto-resolves to E2E_QUEUE (from dirname of script)
    ESCALATE_PHASE1="${E2E_ESCALATE_PHASE1:-10}" \
    ESCALATE_PHASE2="${E2E_ESCALATE_PHASE2:-20}" \
    ESCALATE_COOLDOWN="${E2E_ESCALATE_COOLDOWN:-25}" \
    INOTIFY_TIMEOUT="${E2E_INOTIFY_TIMEOUT:-5}" \
    bash "$E2E_QUEUE/scripts/inbox_watcher.sh" "$agent_id" "$pane_target" "$cli_type" \
        > "$log_file" 2>&1 &

    local pid=$!
    echo "$pid"
}

# ─── stop_inbox_watcher ───
# Stops an inbox_watcher by PID.
stop_inbox_watcher() {
    local pid="$1"
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
}
