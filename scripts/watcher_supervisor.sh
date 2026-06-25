#!/usr/bin/env bash
set -euo pipefail

# Keep inbox watchers alive in a persistent tmux-hosted shell.
# This script is designed to run forever.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

source "$SCRIPT_DIR/lib/agent_registry.sh"

mkdir -p logs queue/inbox

get_multiagent_pane_base() {
    if [ -n "${SHOGUN_PANE_BASE:-}" ]; then
        echo "$SHOGUN_PANE_BASE"
        return 0
    fi
    tmux show-options -gv pane-base-index 2>/dev/null || echo 0
}

ensure_inbox_file() {
    local agent="$1"
    if [ ! -f "queue/inbox/${agent}.yaml" ]; then
        printf 'messages: []\n' > "queue/inbox/${agent}.yaml"
    fi
}

pane_exists() {
    local pane="$1"
    tmux list-panes -a -F "#{session_name}:#{window_name}.#{pane_index}" 2>/dev/null | grep -qx "$pane"
}

start_watcher_if_missing() {
    local agent="$1"
    local pane="$2"
    local log_file="$3"
    local cli
    local lockfile="/tmp/shogun_watcher_start_${agent}.lock"

    ensure_inbox_file "$agent"
    if ! pane_exists "$pane"; then
        return 0
    fi

    (
        if command -v flock &>/dev/null; then flock -n 9 || return 0; else _ld="${lockfile}.d"; mkdir "$_ld" 2>/dev/null || return 0; trap "rmdir '$_ld' 2>/dev/null" EXIT; fi
        if pgrep -Ef "scripts/inbox_watcher.sh ${agent} ${pane}( |$)" >/dev/null 2>&1; then
            return 0
        fi

        if pgrep -f "scripts/inbox_watcher.sh ${agent} " >/dev/null 2>&1; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] stale watcher detected for ${agent}; starting watcher for expected pane ${pane}" >&2
        fi

        cli=$(tmux show-options -p -t "$pane" -v @agent_cli 2>/dev/null || echo "codex")
        nohup bash scripts/inbox_watcher.sh "$agent" "$pane" "$cli" >> "$log_file" 2>&1 &
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [START] inbox_watcher started for ${agent} pane=${pane} PID=$!" >&2
    ) 9>"$lockfile"
}

watcher_specs() {
    local pane_base
    local agent
    pane_base=$(get_multiagent_pane_base)

    while IFS= read -r agent; do
        [ -z "$agent" ] && continue
        local pane
        if ! pane=$(agent_registry_pane_for_agent "$agent" "$pane_base"); then
            continue
        fi
        printf '%s\t%s\tlogs/inbox_watcher_%s.log\n' "$agent" "$pane" "$agent"
    done < <(agent_registry_agents)
}

start_all_watchers() {
    local agent pane log_file
    while IFS=$'\t' read -r agent pane log_file; do
        start_watcher_if_missing "$agent" "$pane" "$log_file"
    done < <(watcher_specs)
}

if [ "${1:-}" = "--print-watchers" ]; then
    watcher_specs
    exit 0
fi

while true; do
    start_all_watchers
    sleep 5
done
