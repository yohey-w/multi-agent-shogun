#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# inbox_watcher.sh — メールボックス監視＆起動シグナル配信
# Usage: bash scripts/inbox_watcher.sh <agent_id> <pane_target> [cli_type]
# Example: bash scripts/inbox_watcher.sh karo multiagent:0.0 claude
#
# 設計思想:
#   メッセージ本体はファイル（inbox YAML）に書く = 確実
#   起動シグナルは tmux send-keys（テキストとEnterを分離送信）
#   エージェントが自分でinboxをReadして処理する
#   冪等: 2回届いてもunreadがなければ何もしない
#
# inotifywait でファイル変更を検知（イベント駆動、ポーリングではない）
# Fallback 1: 30秒タイムアウト（WSL2 inotify不発時の安全網）
# Fallback 2: rc=1処理（Claude Code atomic write = tmp+rename でinode変更時）
#
# エスカレーション（未読メッセージが放置されている場合）:
#   0〜2分: 通常nudge（send-keys）。ただしWorking中はスキップ
#   2〜4分: Escape×2 + nudge（カーソル位置バグ対策）
#   4分〜 : /clear送信（5分に1回まで。強制リセット+YAML再読）
# ═══════════════════════════════════════════════════════════════

# ─── Testing guard ───
# When __INBOX_WATCHER_TESTING__=1, only function definitions are loaded.
# Argument parsing, inotifywait check, and main loop are skipped.
# Test code sets variables (AGENT_ID, PANE_TARGET, CLI_TYPE, INBOX) externally.
if [ "${__INBOX_WATCHER_TESTING__:-}" != "1" ]; then
    set -euo pipefail

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    AGENT_ID="$1"
    PANE_TARGET="$2"
    CLI_TYPE="${3:-claude}"  # CLI種別（claude/codex/copilot）。未指定→claude（後方互換）

    INBOX="$SCRIPT_DIR/queue/inbox/${AGENT_ID}.yaml"
    LOCKFILE="${INBOX}.lock"

    if [ -z "$AGENT_ID" ] || [ -z "$PANE_TARGET" ]; then
        echo "Usage: inbox_watcher.sh <agent_id> <pane_target> [cli_type]" >&2
        exit 1
    fi

    # Initialize inbox if not exists
    if [ ! -f "$INBOX" ]; then
        mkdir -p "$(dirname "$INBOX")"
        echo "messages: []" > "$INBOX"
    fi

    echo "[$(date)] inbox_watcher started — agent: $AGENT_ID, pane: $PANE_TARGET, cli: $CLI_TYPE" >&2

    # Source cli_adapter for get_startup_prompt() (Codex needs startup prompt after /new)
    _cli_adapter="${SCRIPT_DIR}/lib/cli_adapter.sh"
    if [ -f "$_cli_adapter" ]; then
        source "$_cli_adapter"
        echo "[$(date)] cli_adapter.sh loaded (get_startup_prompt available)" >&2
    fi

    # Source shared agent status library (busy/idle detection)
    _agent_status_lib="${SCRIPT_DIR}/lib/agent_status.sh"
    if [ -f "$_agent_status_lib" ]; then
        source "$_agent_status_lib"
    fi

    # Detect OS and select file-watching backend
    INBOX_WATCHER_OS="$(uname -s)"
    if [ "$INBOX_WATCHER_OS" = "Darwin" ]; then
        # macOS: use fswatch instead of inotifywait
        if ! command -v fswatch &>/dev/null; then
            echo "[inbox_watcher] ERROR: fswatch not found. Install: brew install fswatch" >&2
            exit 1
        fi
        WATCH_BACKEND="fswatch"
    else
        # Linux: use inotifywait
        if ! command -v inotifywait &>/dev/null; then
            echo "[inbox_watcher] ERROR: inotifywait not found. Install: sudo apt install inotify-tools" >&2
            exit 1
        fi
        WATCH_BACKEND="inotifywait"
    fi
    echo "[$(date)] File watch backend: $WATCH_BACKEND" >&2
fi

# ─── timeout command compatibility wrapper (macOS support) ───
if ! command -v timeout &>/dev/null; then
  if command -v gtimeout &>/dev/null; then
    timeout() { gtimeout "$@"; }
  else
    # Pure bash fallback: timeout DURATION COMMAND [ARGS...]
    timeout() {
      local duration="$1"; shift
      "$@" &
      local pid=$!
      ( sleep "$duration" && kill "$pid" 2>/dev/null ) &
      local watcher=$!
      wait "$pid" 2>/dev/null
      local rc=$?
      kill "$watcher" 2>/dev/null
      wait "$watcher" 2>/dev/null
      return $rc
    }
  fi
fi

# ─── Escalation state ───
# Time-based escalation: track how long unread messages have been waiting
FIRST_UNREAD_SEEN=${FIRST_UNREAD_SEEN:-0}
LAST_CLEAR_TS=${LAST_CLEAR_TS:-0}
ESCALATE_PHASE1=${ESCALATE_PHASE1:-120}
ESCALATE_PHASE2=${ESCALATE_PHASE2:-240}
ESCALATE_COOLDOWN=${ESCALATE_COOLDOWN:-300}

# ─── Nudge throttle ───
# Avoid spamming the same "inboxN" into the pane every timeout tick.
LAST_NUDGE_TS=${LAST_NUDGE_TS:-0}
LAST_NUDGE_COUNT=${LAST_NUDGE_COUNT:-""}
NUDGE_COOLDOWN_SEC=${NUDGE_COOLDOWN_SEC:-60}
# Codex は「思考中に入力が入ると即拾う」挙動があり、思考がループすることがあるため長めにする。
NUDGE_COOLDOWN_SEC_CODEX=${NUDGE_COOLDOWN_SEC_CODEX:-300}

# ─── Context reset tracking ───
# Tracks whether we've sent /new or /clear for the current task_assigned batch.
# Resets to 0 when all messages are read (FIRST_UNREAD_SEEN → 0).
NEW_CONTEXT_SENT=${NEW_CONTEXT_SENT:-0}
# Tracks whether we sent a startup prompt (Codex) that includes full recovery.
# When set, skip follow-up nudge for this cycle (agent already knows what to do).
STARTUP_PROMPT_SENT=${STARTUP_PROMPT_SENT:-0}

# ─── Phase feature flags (cmd_107 Phase 1/2/3) ───
# ASW_PHASE:
#   1 = self-watch base (compatible)
#   2 = disable normal nudge by default
#   3 = FINAL_ESCALATION_ONLY (send-keys is fallback only)
ASW_PHASE=${ASW_PHASE:-1}
ASW_DISABLE_NORMAL_NUDGE=${ASW_DISABLE_NORMAL_NUDGE:-$([ "${ASW_PHASE}" -ge 2 ] && echo 1 || echo 0)}
ASW_FINAL_ESCALATION_ONLY=${ASW_FINAL_ESCALATION_ONLY:-$([ "${ASW_PHASE}" -ge 3 ] && echo 1 || echo 0)}
FINAL_ESCALATION_ONLY=${FINAL_ESCALATION_ONLY:-$ASW_FINAL_ESCALATION_ONLY}
ASW_NO_IDLE_FULL_READ=${ASW_NO_IDLE_FULL_READ:-1}
# Optional safety toggles:
# - ASW_DISABLE_ESCALATION=1: disable phase2/phase3 escalation actions
# - ASW_PROCESS_TIMEOUT=0: do not process unread on timeout ticks (event-only)
ASW_DISABLE_ESCALATION=${ASW_DISABLE_ESCALATION:-0}
ASW_PROCESS_TIMEOUT=${ASW_PROCESS_TIMEOUT:-1}

# ─── Metrics hooks (FR-006 / NFR-003) ───
# unread_latency_sec / read_count / estimated_tokens are intentionally explicit
READ_COUNT=${READ_COUNT:-0}
READ_BYTES_TOTAL=${READ_BYTES_TOTAL:-0}
ESTIMATED_TOKENS_TOTAL=${ESTIMATED_TOKENS_TOTAL:-0}
METRICS_FILE=${METRICS_FILE:-${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/queue/metrics/${AGENT_ID:-unknown}_selfwatch.yaml}

update_metrics() {
    local bytes_read="${1:-0}"
    local now
    now=$(date +%s)

    READ_COUNT=$((READ_COUNT + 1))
    READ_BYTES_TOTAL=$((READ_BYTES_TOTAL + bytes_read))
    ESTIMATED_TOKENS_TOTAL=$((ESTIMATED_TOKENS_TOTAL + ((bytes_read + 3) / 4)))

    local unread_latency_sec=0
    if [ "$FIRST_UNREAD_SEEN" -gt 0 ] 2>/dev/null; then
        unread_latency_sec=$((now - FIRST_UNREAD_SEEN))
    fi

    mkdir -p "$(dirname "$METRICS_FILE")" 2>/dev/null || true
    cat > "$METRICS_FILE" <<EOF
agent_id: "${AGENT_ID:-unknown}"
timestamp: "$(date '+%Y-%m-%dT%H:%M:%S%z')"
unread_latency_sec: $unread_latency_sec
read_count: $READ_COUNT
bytes_read: $READ_BYTES_TOTAL
estimated_tokens: $ESTIMATED_TOKENS_TOTAL
EOF
}

disable_normal_nudge() {
    [ "${ASW_DISABLE_NORMAL_NUDGE:-0}" = "1" ]
}

should_throttle_nudge() {
    local unread_count="${1:-0}"
    local now
    now=$(date +%s)

    local effective_cli
    effective_cli=$(get_effective_cli_type)

    local cooldown_sec="${NUDGE_COOLDOWN_SEC:-60}"
    if [[ "$effective_cli" == "codex" ]]; then
        cooldown_sec="${NUDGE_COOLDOWN_SEC_CODEX:-300}"
    elif [[ "$effective_cli" == "claude" ]]; then
        # Claude Code: Stop hook is the primary inbox delivery mechanism.
        # Normal nudges are only a safety net — throttle aggressively (5 min).
        cooldown_sec="${NUDGE_COOLDOWN_SEC_CLAUDE:-300}"
    fi

    # Claude Code: throttle regardless of count change.
    # Stop hook catches new messages at turn end, so count-change bypass is unnecessary.
    if [[ "$effective_cli" == "claude" ]] && [ "${LAST_NUDGE_TS:-0}" -gt 0 ]; then
        local age=$((now - LAST_NUDGE_TS))
        if [ "$age" -lt "${cooldown_sec}" ]; then
            echo "[$(date)] [SKIP] Throttling nudge for $AGENT_ID: inbox${unread_count} (${age}s < ${cooldown_sec}s, cli=$effective_cli, stop-hook-primary)" >&2
            return 0
        fi
    elif [ "${LAST_NUDGE_COUNT:-}" = "$unread_count" ] && [ "${LAST_NUDGE_TS:-0}" -gt 0 ]; then
        local age=$((now - LAST_NUDGE_TS))
        if [ "$age" -lt "${cooldown_sec}" ]; then
            echo "[$(date)] [SKIP] Throttling nudge for $AGENT_ID: inbox${unread_count} (${age}s < ${cooldown_sec}s, cli=$effective_cli)" >&2
            return 0
        fi
    fi

    LAST_NUDGE_COUNT="$unread_count"
    LAST_NUDGE_TS="$now"
    return 1
}

is_valid_cli_type() {
    case "${1:-}" in
        claude|codex|copilot|kimi) return 0 ;;
        *) return 1 ;;
    esac
}

get_effective_cli_type() {
    local pane_cli_raw=""
    local pane_cli=""

    pane_cli_raw=$(timeout 2 tmux show-options -p -t "$PANE_TARGET" -v @agent_cli 2>/dev/null || true)
    pane_cli=$(echo "$pane_cli_raw" | tr -d '\r' | head -n1 | tr -d '[:space:]')

    if is_valid_cli_type "$pane_cli"; then
        if is_valid_cli_type "${CLI_TYPE:-}" && [ "$pane_cli" != "${CLI_TYPE}" ]; then
            echo "[$(date)] [WARN] CLI drift detected for $AGENT_ID: arg=${CLI_TYPE}, pane=${pane_cli}. Using pane value." >&2
        fi
        echo "$pane_cli"
        return 0
    fi

    if is_valid_cli_type "${CLI_TYPE:-}"; then
        if [ -n "$pane_cli" ]; then
            echo "[$(date)] [WARN] Invalid pane @agent_cli for $AGENT_ID: '${pane_cli}'. Falling back to arg=${CLI_TYPE}." >&2
        fi
        echo "${CLI_TYPE}"
        return 0
    fi

    # Fail-closed: when CLI is unknown, take codex-safe path (no C-c, /clear->/new)
    echo "[$(date)] [WARN] CLI unresolved for $AGENT_ID (pane='${pane_cli:-<empty>}', arg='${CLI_TYPE:-<empty>}'). Fallback=codex-safe." >&2
    echo "codex"
}

normalize_special_command() {
    local msg_type="${1:-}"
    local raw_content="${2:-}"

    case "$msg_type" in
        clear_command)
            echo "/clear"
            ;;
        model_switch)
            if [[ "$raw_content" =~ ^/model[[:space:]]+[^[:space:]].* ]]; then
                echo "$raw_content"
            else
                echo "[$(date)] [SKIP] Invalid model_switch payload for $AGENT_ID: ${raw_content:-<empty>}" >&2
            fi
            ;;
        cli_restart)
            # cli_restart is handled externally by switch_cli.sh, not via send_cli_command.
            # Emit a marker so the main loop can call switch_cli.sh.
            echo "__CLI_RESTART__:${raw_content}"
            ;;
    esac
}

enqueue_recovery_task_assigned() {
    (
        flock -x 200
        INBOX_PATH="$INBOX" AGENT_ID="$AGENT_ID" "$SCRIPT_DIR/.venv/bin/python3" - << 'PY'
import datetime
import os
import uuid
import yaml

inbox = os.environ.get("INBOX_PATH", "")
agent_id = os.environ.get("AGENT_ID", "agent")

try:
    with open(inbox, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}

    messages = data.get("messages", []) or []

    # Dedup guard: keep only one pending auto-recovery hint at a time.
    for m in reversed(messages):
        if (
            m.get("from") == "inbox_watcher"
            and m.get("type") == "task_assigned"
            and m.get("read", False) is False
            and "[auto-recovery]" in (m.get("content") or "")
        ):
            print("SKIP_DUPLICATE")
            raise SystemExit(0)

    # Task YAML status guard: skip auto-recovery if task is cancelled or idle.
    # This prevents restarting a task that Karo intentionally cancelled via clear_command.
    task_yaml_path = os.path.join(
        os.path.dirname(os.path.dirname(inbox)), "tasks", f"{agent_id}.yaml"
    )
    if os.path.exists(task_yaml_path):
        try:
            with open(task_yaml_path, "r", encoding="utf-8") as tf:
                task_data = yaml.safe_load(tf) or {}
            task_status = str(task_data.get("status") or "").strip().strip("'\"")
            if task_status in ("cancelled", "idle"):
                print(f"SKIP_CANCELLED:{task_status}")
                raise SystemExit(0)
        except SystemExit:
            raise
        except Exception:
            pass  # If task YAML is unreadable, proceed with auto-recovery as safety net

    now = datetime.datetime.now(datetime.timezone.utc).astimezone()
    msg = {
        "content": (
            f"[auto-recovery] /clear 後の再着手通知。"
            f"queue/tasks/{agent_id}.yaml を再読し、assigned タスクを即時再開せよ。"
        ),
        "from": "inbox_watcher",
        "id": f"msg_auto_recovery_{now.strftime('%Y%m%d_%H%M%S')}_{uuid.uuid4().hex[:8]}",
        "read": False,
        "timestamp": now.replace(microsecond=0).isoformat(),
        "type": "task_assigned",
    }
    messages.append(msg)
    data["messages"] = messages

    tmp_path = f"{inbox}.tmp.{os.getpid()}"
    with open(tmp_path, "w", encoding="utf-8") as f:
        yaml.safe_dump(
            data,
            f,
            default_flow_style=False,
            allow_unicode=True,
            sort_keys=False,
        )
    os.replace(tmp_path, inbox)
    print(msg["id"])
except Exception:
    # Best-effort safety net only. Primary /clear delivery must not fail here.
    print("ERROR")
PY
    ) 200>"$LOCKFILE" 2>/dev/null
}

no_idle_full_read() {
    local trigger="${1:-timeout}"
    [ "${ASW_NO_IDLE_FULL_READ:-1}" = "1" ] || return 1
    [ "$trigger" = "timeout" ] || return 1
    [ "${FIRST_UNREAD_SEEN:-0}" -eq 0 ] || return 1
    return 0
}

# summary-first: unread_count fast-path before full read
get_unread_count_fast() {
    INBOX_PATH="$INBOX" "$SCRIPT_DIR/.venv/bin/python3" - << 'PY'
import json
import os
import yaml

inbox = os.environ.get("INBOX_PATH", "")
try:
    with open(inbox, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}
    messages = data.get("messages", []) or []
    unread_count = sum(1 for m in messages if not m.get("read", False))
    print(json.dumps({"count": unread_count}))
except Exception:
    print(json.dumps({"count": 0}))
PY
}

# ─── Extract unread message info (lock-free read) ───
# Returns JSON lines: {"count": N, "has_special": true/false, "specials": [...]}
# Test anchor for bats awk pattern: get_unread_info\\(\\)
get_unread_info() {
    (
        flock -x 200
        INBOX_PATH="$INBOX" "$SCRIPT_DIR/.venv/bin/python3" - << 'PY'
import json
import os
import yaml

inbox = os.environ.get("INBOX_PATH", "")
try:
    with open(inbox, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}

    messages = data.get("messages", []) or []
    unread = [m for m in messages if not m.get("read", False)]
    special_types = ("clear_command", "model_switch", "cli_restart")
    specials = [m for m in unread if m.get("type") in special_types]

    if specials:
        for m in messages:
            if not m.get("read", False) and m.get("type") in special_types:
                m["read"] = True

        tmp_path = f"{inbox}.tmp.{os.getpid()}"
        with open(tmp_path, "w", encoding="utf-8") as f:
            yaml.safe_dump(
                data,
                f,
                default_flow_style=False,
                allow_unicode=True,
                sort_keys=False,
            )
        os.replace(tmp_path, inbox)

    normal_count = len(unread) - len(specials)
    normal_msgs = [m for m in unread if m.get("type") not in special_types]
    has_task_assigned = any(m.get("type") == "task_assigned" for m in normal_msgs)
    payload = {
        "count": normal_count,
        "has_task_assigned": has_task_assigned,
        "specials": [{"type": m.get("type", ""), "content": m.get("content", "")} for m in specials],
    }
    print(json.dumps(payload))
except Exception:
    print(json.dumps({"count": 0, "specials": []}))
PY
    ) 200>"$LOCKFILE" 2>/dev/null
}

# ─── Send CLI command via pty direct write ───
# For /clear and /model only. These are CLI commands, not conversation messages.
# CLI_TYPE別分岐: claude→そのまま, codex→/clear対応・/modelスキップ,
#                  copilot→Ctrl-C+再起動・/modelスキップ
# 実行時にtmux paneの @agent_cli を再確認し、ドリフト時はpane値を優先する。
send_cli_command() {
    local cmd="$1"
    local effective_cli
    effective_cli=$(get_effective_cli_type)

    # cli_restart: delegate to switch_cli.sh (full /exit → relaunch cycle)
    if [[ "$cmd" == __CLI_RESTART__:* ]]; then
        local restart_args="${cmd#__CLI_RESTART__:}"
        echo "[$(date)] [CLI-RESTART] Delegating to switch_cli.sh for $AGENT_ID: ${restart_args}" >&2
        bash "${SCRIPT_DIR}/scripts/switch_cli.sh" "$AGENT_ID" $restart_args 2>&1 | while IFS= read -r line; do  # SCRIPT_DIR=project_root
            echo "[$(date)] [switch_cli] $line" >&2
        done
        # Update effective CLI type after restart
        CLI_TYPE=$(tmux show-options -p -t "$PANE_TARGET" -v @agent_cli 2>/dev/null || echo "$CLI_TYPE")
        return 0
    fi

    # Safety: never inject CLI commands into the shogun pane.
    # Shogun is controlled by the Lord; keystroke injection can clobber human input.
    if [ "$AGENT_ID" = "shogun" ]; then
        echo "[$(date)] [SKIP] shogun: suppressing CLI command injection ($cmd)" >&2
        return 0
    fi

    # CLI別コマンド変換
    local actual_cmd="$cmd"
    case "$effective_cli" in
        codex)
            # Codex: /clear不存在→/newで新規会話開始, /model非対応→スキップ
            # /clearはCodexでは未定義コマンドでCLI終了してしまうため、/newに変換
            if [[ "$cmd" == "/clear" ]]; then
                # Guard: skip duplicate /new if already sent for this batch
                if [ "${NEW_CONTEXT_SENT:-0}" -eq 1 ]; then
                    echo "[$(date)] [SKIP] Codex /new already sent for $AGENT_ID — skipping duplicate clear_command" >&2
                    return 0
                fi
                echo "[$(date)] [SEND-KEYS] Codex /clear→/new: starting new conversation for $AGENT_ID" >&2
                # Dismiss suggestion UI first (typing "x" clears autocomplete prompt)
                timeout 5 tmux send-keys -t "$PANE_TARGET" "x" 2>/dev/null || true
                sleep 0.3
                timeout 5 tmux send-keys -t "$PANE_TARGET" C-u 2>/dev/null || true
                sleep 0.3
                timeout 5 tmux send-keys -t "$PANE_TARGET" "/new" 2>/dev/null || true
                sleep 0.3
                timeout 5 tmux send-keys -t "$PANE_TARGET" Enter 2>/dev/null || true
                sleep 3
                # Send startup prompt immediately (don't defer to context-reset cycle)
                send_codex_startup_prompt
                NEW_CONTEXT_SENT=1
                return 0
            fi
            if [[ "$cmd" == /model* ]]; then
                echo "[$(date)] Skipping $cmd (not supported on codex)" >&2
                return 0
            fi
            ;;
        copilot)
            # Copilot: /clearはCtrl-C+再起動, /model非対応→スキップ
            if [[ "$cmd" == "/clear" ]]; then
                echo "[$(date)] [SEND-KEYS] Copilot /clear: sending Ctrl-C + restart for $AGENT_ID" >&2
                timeout 5 tmux send-keys -t "$PANE_TARGET" C-c 2>/dev/null || true
                sleep 2
                timeout 5 tmux send-keys -t "$PANE_TARGET" "copilot --yolo" 2>/dev/null || true
                sleep 0.3
                timeout 5 tmux send-keys -t "$PANE_TARGET" Enter 2>/dev/null || true
                sleep 3
                return 0
            fi
            if [[ "$cmd" == /model* ]]; then
                echo "[$(date)] Skipping $cmd (not supported on copilot)" >&2
                return 0
            fi
            ;;
        # claude: commands pass through as-is
    esac

    echo "[$(date)] [SEND-KEYS] Sending CLI command to $AGENT_ID ($effective_cli): $actual_cmd" >&2
    # Clear stale input first, then send command (text and Enter separated for Codex TUI)
    # Codex CLI: C-c when idle causes CLI to exit — skip it
    if [[ "$effective_cli" != "codex" ]]; then
        timeout 5 tmux send-keys -t "$PANE_TARGET" C-c 2>/dev/null || true
        sleep 0.5
    fi
    timeout 5 tmux send-keys -t "$PANE_TARGET" "$actual_cmd" 2>/dev/null || true
    sleep 0.3
    timeout 5 tmux send-keys -t "$PANE_TARGET" Enter 2>/dev/null || true

    # /clear needs extra wait time before follow-up
    if [[ "$actual_cmd" == "/clear" ]]; then
        LAST_CLEAR_TS=$(date +%s)
        sleep 3
    else
        sleep 1
    fi
}

# ─── Send Codex startup prompt after /new ───
# Waits for agent to become idle, then sends a startup prompt that includes
# full recovery steps (identify, read task YAML, read inbox, start work).
# Called from both send_cli_command (clear_command) and send_context_reset.
send_codex_startup_prompt() {
    # Poll until agent becomes idle (prompt ready) instead of fixed sleep.
    # Max 15s (3 attempts × 5s). If still busy after 15s, proceed anyway.
    local attempt
    for attempt in 1 2 3; do
        sleep 5
        if ! agent_is_busy; then
            echo "[$(date)] [STARTUP] $AGENT_ID idle after ${attempt}×5s — sending startup prompt" >&2
            break
        fi
        echo "[$(date)] [STARTUP] $AGENT_ID still busy after ${attempt}×5s — retrying" >&2
    done
    if agent_is_busy; then
        echo "[$(date)] [STARTUP] $AGENT_ID still busy after 15s — proceeding with startup prompt anyway" >&2
    fi

    local startup_prompt=""
    if type get_startup_prompt &>/dev/null; then
        startup_prompt=$(get_startup_prompt "$AGENT_ID" 2>/dev/null || true)
    fi
    if [[ -z "$startup_prompt" ]]; then
        startup_prompt="Session Start — do ALL of this in one turn, do NOT stop early: 1) tmux display-message to identify yourself. 2) Read queue/tasks/${AGENT_ID}.yaml. 3) Read queue/inbox/${AGENT_ID}.yaml, mark read:true. 4) Read context_files. 5) Execute the assigned task to completion — edit files, run commands, write reports. Keep working until done."
    fi
    echo "[$(date)] [STARTUP] Sending startup prompt to $AGENT_ID (codex): ${startup_prompt:0:80}..." >&2
    # Dismiss suggestion UI, then send startup prompt
    timeout 5 tmux send-keys -t "$PANE_TARGET" "x" 2>/dev/null || true
    sleep 0.3
    timeout 5 tmux send-keys -t "$PANE_TARGET" C-u 2>/dev/null || true
    sleep 0.3
    timeout 5 tmux send-keys -t "$PANE_TARGET" "$startup_prompt" 2>/dev/null || true
    sleep 0.3
    timeout 5 tmux send-keys -t "$PANE_TARGET" Enter 2>/dev/null || true
    STARTUP_PROMPT_SENT=1
}

# ─── Send context reset before new task ───
# Called when task_assigned is detected in unread messages.
# Sends the appropriate "new conversation" command per CLI type to clear
# stale context from the previous task.
# CLI mapping: claude→/clear, codex→/new, copilot→/clear, kimi→/clear
send_context_reset() {
    local effective_cli
    effective_cli=$(get_effective_cli_type)

    # Safety: never auto-reset context for command-layer agents.
    # Only ashigaru should receive automatic context resets (clear stale task context).
    # Shogun (human-controlled), Karo (coordinator state), Gunshi (strategic state)
    # all maintain complex running context that should not be wiped automatically.
    if [ "$AGENT_ID" = "shogun" ] || [ "$AGENT_ID" = "karo" ] || [ "$AGENT_ID" = "gunshi" ]; then
        echo "[$(date)] [SKIP] $AGENT_ID: suppressing context reset (command-layer agent)" >&2
        return 0
    fi

    local reset_cmd
    case "$effective_cli" in
        codex)    reset_cmd="/new" ;;
        claude)   reset_cmd="/clear" ;;
        copilot)  reset_cmd="/clear" ;;
        kimi)     reset_cmd="/clear" ;;
        *)        reset_cmd="/new" ;;  # safe default (codex-safe)
    esac

    echo "[$(date)] [CONTEXT-RESET] Sending $reset_cmd before task_assigned for $AGENT_ID ($effective_cli)" >&2

    # Codex: send /new + startup prompt as a single atomic operation.
    # When called from clear_command path, NEW_CONTEXT_SENT=1 prevents reaching here.
    # When called for standalone task_assigned, this is the only /new send.
    if [[ "$effective_cli" == "codex" ]]; then
        # Dismiss suggestion UI + send /new
        timeout 5 tmux send-keys -t "$PANE_TARGET" "x" 2>/dev/null || true
        sleep 0.3
        timeout 5 tmux send-keys -t "$PANE_TARGET" C-u 2>/dev/null || true
        sleep 0.3
        timeout 5 tmux send-keys -t "$PANE_TARGET" "/new" 2>/dev/null || true
        sleep 0.3
        timeout 5 tmux send-keys -t "$PANE_TARGET" Enter 2>/dev/null || true
        sleep 3
        # Wait for idle + send startup prompt via shared helper
        send_codex_startup_prompt
        return 0
    fi

    # Non-Codex CLIs: send /clear and wait for idle
    # Send the command (text and Enter separated for TUI compatibility)
    timeout 5 tmux send-keys -t "$PANE_TARGET" "$reset_cmd" 2>/dev/null || true
    sleep 0.3
    timeout 5 tmux send-keys -t "$PANE_TARGET" Enter 2>/dev/null || true
    # Mark /clear timestamp so agent_is_busy() treats it as busy during processing
    if [[ "$reset_cmd" == "/clear" ]]; then
        LAST_CLEAR_TS=$(date +%s)
    fi

    # Poll until agent becomes idle (prompt ready) instead of fixed sleep.
    # Max 15s (3 attempts × 5s). If still busy after 15s, proceed anyway.
    local attempt
    for attempt in 1 2 3; do
        sleep 5
        if ! agent_is_busy; then
            echo "[$(date)] [CONTEXT-RESET] $AGENT_ID idle after ${attempt}×5s — ready for nudge" >&2
            break
        fi
        echo "[$(date)] [CONTEXT-RESET] $AGENT_ID still busy after ${attempt}×5s — retrying" >&2
    done
    if agent_is_busy; then
        echo "[$(date)] [CONTEXT-RESET] $AGENT_ID still busy after 15s — proceeding anyway" >&2
    fi
}

# ─── Agent self-watch detection ───
# Check if the agent has an active inotifywait on its inbox.
# If yes, the agent will self-wake — no nudge needed.
agent_has_self_watch() {
    # Codex/Copilot/Kimi CLIs cannot run self-watch. Only Claude Code agents can.
    local effective_cli
    effective_cli=$(get_effective_cli_type)
    if [[ "$effective_cli" != "claude" ]]; then
        return 1  # non-Claude CLIs never have self-watch
    fi
    # For Claude Code agents: check if an inotifywait exists that is NOT
    # a child of this inbox_watcher process (exclude our own watcher).
    local my_pgid
    my_pgid=$(ps -o pgid= -p $$ 2>/dev/null | tr -d ' ')
    local found=1  # default: not found
    while IFS= read -r pid; do
        local pid_pgid
        pid_pgid=$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')
        if [[ "$pid_pgid" != "$my_pgid" ]]; then
            found=0  # found an inotifywait NOT from our process group
            break
        fi
    done < <(pgrep -f "inotifywait.*inbox/${AGENT_ID}.yaml" 2>/dev/null)
    return $found
}

# ─── Agent busy detection ───
# Check if the agent's CLI is currently processing (Working/thinking/etc).
# Sending nudge during Working causes text to queue but Enter to be lost.
# Returns 0 (true) if agent is busy, 1 if idle.
# Implementation: delegates to lib/agent_status.sh (shared library).
agent_is_busy() {
    # /clear cooldown: treat agent as busy for 30s after /clear was sent.
    # Claude Code's /clear takes 10-30s (CLAUDE.md reload + context init).
    # Without this, nudges sent during /clear processing queue up at the prompt
    # and cause race conditions (inbox1 arrives before /clear completes).
    local now_busy
    now_busy=$(date +%s)
    if [ "${LAST_CLEAR_TS:-0}" -gt 0 ] && [ "$((now_busy - LAST_CLEAR_TS))" -lt 30 ]; then
        return 0  # busy — /clear still processing
    fi

    if type agent_is_busy_check &>/dev/null; then
        agent_is_busy_check "$PANE_TARGET"
    else
        # Fallback: if shared library not loaded, assume idle
        return 1
    fi
}

# ─── Pane focus detection (human safety) ───
# If the target pane is currently active, avoid injecting keystrokes.
pane_is_active() {
    local active=""
    active=$(timeout 2 tmux display-message -p -t "$PANE_TARGET" '#{pane_active}' 2>/dev/null || true)
    [ "$active" = "1" ]
}

# ─── Session attach detection ───
# Function: session_has_client
# Description: Checks if the tmux session containing PANE_TARGET has at least
#   one client attached. Used to avoid suppressing send-keys when no human is
#   watching (e.g. single-pane shogun session where pane_is_active is always true).
# Arguments: none (uses global PANE_TARGET)
# Returns: 0 if at least one client is attached, 1 otherwise
session_has_client() {
    local session_name
    session_name=$(timeout 2 tmux display-message -p -t "$PANE_TARGET" '#{session_name}' 2>/dev/null || true)
    [ -n "$session_name" ] && [ "$(tmux list-clients -t "$session_name" 2>/dev/null | wc -l)" -gt 0 ]
}

# ─── Send wake-up nudge ───
# Layered approach:
#   1. If agent has active inotifywait self-watch → skip (agent wakes itself)
#   2. If agent is busy (Working) → skip (nudge during Working loses Enter)
#   3. tmux send-keys (短いnudgeのみ、timeout 5s)
send_wakeup() {
    local unread_count="$1"
    local nudge="inbox${unread_count}"

    if [ "${FINAL_ESCALATION_ONLY:-0}" = "1" ]; then
        echo "[$(date)] [SKIP] FINAL_ESCALATION_ONLY=1, suppressing normal nudge for $AGENT_ID" >&2
        return 0
    fi

    # 優先度1: Agent self-watch — nudge不要（エージェントが自分で気づく）
    if agent_has_self_watch; then
        echo "[$(date)] [SKIP] Agent $AGENT_ID has active self-watch, no nudge needed" >&2
        return 0
    fi

    # 優先度2: Agent busy — nudge送信するとEnterが消失するためスキップ
    # Claude Code agents: Stop hook handles delivery, no nudge needed at all.
    if agent_is_busy; then
        local busy_cli_wakeup
        busy_cli_wakeup=$(get_effective_cli_type)
        if [[ "$busy_cli_wakeup" == "claude" ]]; then
            echo "[$(date)] [SKIP] Agent $AGENT_ID is busy (claude) — Stop hook will deliver, no nudge" >&2
        else
            echo "[$(date)] [SKIP] Agent $AGENT_ID is busy ($busy_cli_wakeup), deferring nudge" >&2
        fi
        return 0
    fi

    if should_throttle_nudge "$unread_count"; then
        return 0
    fi

    # Shogun: if the pane is focused AND a human is attached, never inject keys
    # (it can clobber the Lord's input). Show a tmux message instead.
    # If session is detached, no human is watching — safe to send-keys normally.
    if [ "$AGENT_ID" = "shogun" ] && pane_is_active && session_has_client; then
        echo "[$(date)] [DISPLAY] shogun pane is active + attached — showing nudge: inbox${unread_count}" >&2
        timeout 2 tmux display-message -t "$PANE_TARGET" -d 5000 "inbox${unread_count}" 2>/dev/null || true
        return 0
    fi

    # 優先度3: tmux send-keys（テキストとEnterを分離 — Codex TUI対策）
    echo "[$(date)] [SEND-KEYS] Sending nudge to $PANE_TARGET for $AGENT_ID" >&2

    # Codex suggestion UI dismissal: typing any character dismisses the autocomplete
    # suggestion prompt (› Implement {feature} etc.) that traps idle agents.
    # Sequence: "x" (dismiss suggestion) → C-u (clear input) → nudge → Enter
    local effective_cli_for_nudge
    effective_cli_for_nudge=$(get_effective_cli_type)
    if [[ "$effective_cli_for_nudge" == "codex" ]]; then
        timeout 5 tmux send-keys -t "$PANE_TARGET" "x" 2>/dev/null || true
        sleep 0.3
        timeout 5 tmux send-keys -t "$PANE_TARGET" C-u 2>/dev/null || true
        sleep 0.3
    fi

    if timeout 5 tmux send-keys -t "$PANE_TARGET" "$nudge" 2>/dev/null; then
        sleep 0.3
        timeout 5 tmux send-keys -t "$PANE_TARGET" Enter 2>/dev/null || true
        echo "[$(date)] Wake-up sent to $AGENT_ID (${unread_count} unread)" >&2
        return 0
    fi

    echo "[$(date)] WARNING: send-keys failed or timed out for $AGENT_ID" >&2
    return 0  # Never return 1 — set -euo pipefail would kill the watcher daemon
}

# ─── Send wake-up nudge with Escape prefix ───
# Phase 2 escalation: send Escape×2 + C-c to clear stuck input, then nudge.
# Addresses the "echo last tool call" cursor position bug and stale input.
send_wakeup_with_escape() {
    local unread_count="$1"
    local nudge="inbox${unread_count}"
    local effective_cli
    effective_cli=$(get_effective_cli_type)
    local c_ctrl_state="skipped"

    # Safety: never send Escape escalation to shogun. It can wipe the Lord's input.
    if [ "$AGENT_ID" = "shogun" ]; then
        echo "[$(date)] [SKIP] shogun: suppressing Escape escalation; sending plain nudge" >&2
        send_wakeup "$unread_count"
        return 0
    fi

    # Codex CLI: ESC は「中断」になりやすく、人間操作中の事故も多い。
    # Phase 2 の Escape エスカレーションは無効化し、通常 nudge のみに落とす。
    if [[ "$effective_cli" == "codex" ]]; then
        echo "[$(date)] [SKIP] codex: suppressing Escape escalation for $AGENT_ID; sending plain nudge" >&2
        send_wakeup "$unread_count"
        return 0
    fi

    # Claude Code: Stop hookがturn終了時にinbox未読を検出→自動処理する。
    # Escape送信は処理中のturnを中断させるため有害。Phase 2は通常nudgeに落とす。
    if [[ "$effective_cli" == "claude" ]]; then
        echo "[$(date)] [SKIP] claude: suppressing Escape escalation for $AGENT_ID (Stop hook handles delivery); sending plain nudge" >&2
        send_wakeup "$unread_count"
        return 0
    fi

    if [ "${FINAL_ESCALATION_ONLY:-0}" = "1" ]; then
        echo "[$(date)] [SKIP] FINAL_ESCALATION_ONLY=1, suppressing phase2 nudge for $AGENT_ID" >&2
        return 0
    fi

    if agent_has_self_watch; then
        return 0
    fi

    # Phase 2 still skips if agent is busy — Escape during Working would interrupt
    if agent_is_busy; then
        echo "[$(date)] [SKIP] Agent $AGENT_ID is busy (Working), deferring Phase 2 nudge" >&2
        return 0
    fi

    echo "[$(date)] [SEND-KEYS] ESCALATION Phase 2: Escape×2 + nudge for $AGENT_ID (cli=$effective_cli)" >&2
    # Escape×2 to exit any mode
    timeout 5 tmux send-keys -t "$PANE_TARGET" Escape Escape 2>/dev/null || true
    sleep 0.5
    # C-c to clear stale input (but Codex CLI terminates on C-c when idle, so skip it)
    if [[ "$effective_cli" != "codex" ]]; then
        timeout 5 tmux send-keys -t "$PANE_TARGET" C-c 2>/dev/null || true
        sleep 0.5
        c_ctrl_state="sent"
    fi
    if timeout 5 tmux send-keys -t "$PANE_TARGET" "$nudge" 2>/dev/null; then
        sleep 0.3
        timeout 5 tmux send-keys -t "$PANE_TARGET" Enter 2>/dev/null || true
        echo "[$(date)] Escape+nudge sent to $AGENT_ID (${unread_count} unread, cli=$effective_cli, C-c=$c_ctrl_state)" >&2
        return 0
    fi

    echo "[$(date)] WARNING: send-keys failed for Escape+nudge ($AGENT_ID)" >&2
    return 0  # Never return 1 — set -euo pipefail would kill the watcher daemon
}

# ─── Process cycle ───
process_unread() {
    local trigger="${1:-event}"

    # summary-first: unread_count fast-path (Phase 2/3 optimization)
    # unread_count fast-path lets us skip expensive full reads when idle.
    local fast_info
    fast_info=$(get_unread_count_fast)
    local fast_count
    fast_count=$(echo "$fast_info" | "$SCRIPT_DIR/.venv/bin/python3" -c "import sys,json; print(json.load(sys.stdin).get('count',0))" 2>/dev/null)

    if no_idle_full_read "$trigger" && [ "$fast_count" -eq 0 ] 2>/dev/null; then
        # no_idle_full_read guard: unread=0 and timeout path → no full inbox read
        if [ "$FIRST_UNREAD_SEEN" -ne 0 ]; then
            echo "[$(date)] All messages read for $AGENT_ID — escalation reset (fast-path)" >&2
        fi
        FIRST_UNREAD_SEEN=0
        NEW_CONTEXT_SENT=0
        if ! agent_is_busy; then
            # Shogun: only clear input when pane is not active (Lord is away)
            if [ "$AGENT_ID" = "shogun" ] && pane_is_active; then
                : # Lord may be typing — skip C-u
            else
                timeout 2 tmux send-keys -t "$PANE_TARGET" C-u 2>/dev/null || true
            fi
        fi
        return 0
    fi

    local info
    info=$(get_unread_info)

    local read_bytes=0
    if [ -f "$INBOX" ]; then
        read_bytes=$(wc -c < "$INBOX" 2>/dev/null || echo 0)
    fi
    update_metrics "${read_bytes:-0}"

    # Handle special CLI commands first (/clear, /model)
    local specials
    specials=$(echo "$info" | "$SCRIPT_DIR/.venv/bin/python3" -c "
import sys, json
data = json.load(sys.stdin)
for s in data.get('specials', []):
    t = s.get('type', '')
    c = (s.get('content', '') or '').replace('\t', ' ').replace('\n', ' ').strip()
    print(f'{t}\t{c}')
" 2>/dev/null)

    local clear_seen=0
    if [ -n "$specials" ]; then
        local msg_type msg_content cmd
        while IFS=$'\t' read -r msg_type msg_content; do
            [ -n "$msg_type" ] || continue
            if [ "$msg_type" = "clear_command" ]; then
                clear_seen=1
            fi
            cmd=$(normalize_special_command "$msg_type" "$msg_content")
            [ -n "$cmd" ] && send_cli_command "$cmd"
        done <<< "$specials"
    fi

    # /clear は Codex で /new へ変換される。再起動直後の取りこぼし防止として
    # 追加 task_assigned を自動投入し、次サイクルで確実に wake-up 可能にする。
    # 案B+待機: Karo がタスク YAML を cancelled に更新するまでの猶予を確保してから
    # status チェックを行い、cancelled/idle の場合はスキップする。
    if [ "$clear_seen" -eq 1 ]; then
        # Wait for Karo to update task YAML status (cancellation race condition mitigation).
        # send_cli_command already slept 3s for /clear; add 5s more = ~8s total before check.
        sleep 5
        local recovery_id
        recovery_id=$(enqueue_recovery_task_assigned)
        if [[ "$recovery_id" == SKIP_CANCELLED:* ]]; then
            echo "[$(date)] [AUTO-RECOVERY] skipped for $AGENT_ID — task is ${recovery_id#SKIP_CANCELLED:} (not restarting)" >&2
        elif [ -n "$recovery_id" ] && [ "$recovery_id" != "SKIP_DUPLICATE" ] && [ "$recovery_id" != "ERROR" ]; then
            echo "[$(date)] [AUTO-RECOVERY] queued task_assigned for $AGENT_ID ($recovery_id)" >&2
        fi
        info=$(get_unread_info)
    fi

    # Send wake-up nudge for normal messages (with escalation)
    local normal_count
    normal_count=$(echo "$info" | "$SCRIPT_DIR/.venv/bin/python3" -c "import sys,json; print(json.load(sys.stdin).get('count',0))" 2>/dev/null)

    # Check if unread messages include task_assigned (for context reset)
    local has_task_assigned
    has_task_assigned=$(echo "$info" | "$SCRIPT_DIR/.venv/bin/python3" -c "import sys,json; print(1 if json.load(sys.stdin).get('has_task_assigned') else 0)" 2>/dev/null)

    if [ "$normal_count" -gt 0 ] 2>/dev/null; then
        local now
        now=$(date +%s)

        # When the agent is busy/thinking, do NOT escalate. Interrupting with Escape or /clear
        # can terminate the current thought. Also pause the escalation timer while busy so we
        # don't immediately jump to Phase 2/3 once it becomes idle.
        if agent_is_busy; then
            local busy_cli
            busy_cli=$(get_effective_cli_type)
            if [[ "$busy_cli" == "claude" ]]; then
                # Claude Code: Stop hook will catch unread messages when the agent's
                # turn ends. No nudge needed at all — just log and skip completely.
                # Don't reset FIRST_UNREAD_SEEN so idle-nudge works if hook misses.
                echo "[$(date)] $normal_count unread for $AGENT_ID but agent is busy (claude) — Stop hook will deliver" >&2
            else
                # Codex/Copilot/Kimi: No Stop hook. Pause escalation timer while busy.
                FIRST_UNREAD_SEEN=$now
                echo "[$(date)] $normal_count unread for $AGENT_ID but agent is busy ($busy_cli) — pausing escalation timer" >&2
            fi
            return 0
        fi

        # ─── Context reset before new task ───
        # Send /new or /clear once when task_assigned is first detected,
        # to clear stale context from the previous task.
        # Skip if: (1) already sent this batch, (2) clear_command already handled above,
        #          (3) agent is shogun (human-controlled).
        if [ "$has_task_assigned" = "1" ] && [ "$NEW_CONTEXT_SENT" -eq 0 ] && [ "$clear_seen" -eq 0 ]; then
            send_context_reset
            NEW_CONTEXT_SENT=1
        fi

        # If startup prompt was just sent (Codex), skip follow-up nudge this cycle.
        # The prompt itself contains full recovery instructions (identify + read YAML + work).
        if [ "$STARTUP_PROMPT_SENT" -eq 1 ]; then
            STARTUP_PROMPT_SENT=0
            echo "[$(date)] [SKIP] Startup prompt just sent to $AGENT_ID — skipping nudge this cycle" >&2
            FIRST_UNREAD_SEEN=$now
            return 0
        fi

        # Track when we first saw unread messages
        if [ "$FIRST_UNREAD_SEEN" -eq 0 ]; then
            FIRST_UNREAD_SEEN=$now
        fi

        if [ "${ASW_DISABLE_ESCALATION:-0}" = "1" ]; then
            echo "[$(date)] $normal_count unread for $AGENT_ID (escalation disabled)" >&2
            if disable_normal_nudge; then
                echo "[$(date)] [SKIP] disable_normal_nudge=1, no normal nudge for $AGENT_ID" >&2
            else
                send_wakeup "$normal_count"
            fi
            return 0
        fi

        local age=$((now - FIRST_UNREAD_SEEN))

        if [ "$age" -lt "$ESCALATE_PHASE1" ]; then
            # Phase 1 (0-2 min): Standard nudge
            echo "[$(date)] $normal_count unread for $AGENT_ID (${age}s)" >&2
            if disable_normal_nudge; then
                echo "[$(date)] [SKIP] disable_normal_nudge=1, deferring to escalation-only path" >&2
            else
                send_wakeup "$normal_count"
            fi
        elif [ "$age" -lt "$ESCALATE_PHASE2" ]; then
            # Phase 2 (2-4 min): Escape + nudge
            echo "[$(date)] $normal_count unread for $AGENT_ID (${age}s — escalating: Escape+nudge)" >&2
            send_wakeup_with_escape "$normal_count"
        else
            # Phase 3 (4+ min): /clear (throttled to once per 5 min)
            if [ "$LAST_CLEAR_TS" -lt "$((now - ESCALATE_COOLDOWN))" ]; then
                local effective_cli
                effective_cli=$(get_effective_cli_type)
                if [[ "$effective_cli" == "codex" ]]; then
                    # Codex /clear -> /new は会話を切ってしまうため、安全側に倒す。
                    echo "[$(date)] ESCALATION Phase 3: $AGENT_ID unresponsive for ${age}s, but cli=codex — skipping /clear." >&2
                    FIRST_UNREAD_SEEN=$now  # Reset timer (no destructive action)
                    send_wakeup "$normal_count"
                elif [ "$AGENT_ID" = "shogun" ] || [ "$AGENT_ID" = "karo" ] || [ "$AGENT_ID" = "gunshi" ]; then
                    # Command-layer agents (karo/gunshi/shogun): suppress /clear even in Phase 3
                    echo "[$(date)] [SKIP] ESCALATION Phase 3: $AGENT_ID suppressed (command-layer agent, ${age}s). Using Escape+nudge." >&2
                    FIRST_UNREAD_SEEN=$now  # Reset timer
                    send_wakeup_with_escape "$normal_count"
                else
                    echo "[$(date)] ESCALATION Phase 3: Agent $AGENT_ID unresponsive for ${age}s. Sending /clear." >&2
                    send_cli_command "/clear"
                    LAST_CLEAR_TS=$now
                    FIRST_UNREAD_SEEN=0  # Reset — will re-detect on next cycle
                    NEW_CONTEXT_SENT=0
                fi
            else
                # Cooldown active — fall back to Escape+nudge
                echo "[$(date)] $normal_count unread for $AGENT_ID (${age}s — /clear cooldown, using Escape+nudge)" >&2
                send_wakeup_with_escape "$normal_count"
            fi
        fi
    else
        # No unread messages — reset escalation tracker
        if [ "$FIRST_UNREAD_SEEN" -ne 0 ]; then
            echo "[$(date)] All messages read for $AGENT_ID — escalation reset" >&2
        fi
        FIRST_UNREAD_SEEN=0
        NEW_CONTEXT_SENT=0
        # Clear stale nudge text from input field (Codex CLI prefills last input on idle).
        # Only send C-u when agent is idle — during Working it would be disruptive.
        if ! agent_is_busy; then
            # Shogun: only clear input when pane is not active (Lord is away)
            if [ "$AGENT_ID" = "shogun" ] && pane_is_active; then
                : # Lord may be typing — skip C-u
            else
                timeout 2 tmux send-keys -t "$PANE_TARGET" C-u 2>/dev/null || true
            fi
        fi
    fi
}

process_unread_once() {
    process_unread "startup"
}

# ─── Startup & Main loop (skipped in testing mode) ───
if [ "${__INBOX_WATCHER_TESTING__:-}" != "1" ]; then

# ─── Startup: process any existing unread messages ───
process_unread_once

# ─── Main loop: event-driven via inotifywait ───
# Timeout 30s: WSL2 /mnt/c/ can miss inotify events.
# Shorter timeout = faster escalation retry for stuck agents.
INOTIFY_TIMEOUT="${INOTIFY_TIMEOUT:-30}"

while true; do
    # Block until file is modified OR timeout
    # Backend-specific file watching: inotifywait (Linux) or fswatch (macOS)
    set +e
    if [ "${WATCH_BACKEND:-inotifywait}" = "fswatch" ]; then
        # macOS: fswatch -1 exits after one event. Use timeout for safety net.
        # gtimeout (from coreutils) or perl fallback for macOS timeout
        if command -v gtimeout &>/dev/null; then
            gtimeout "$INOTIFY_TIMEOUT" fswatch -1 --event Updated --event Renamed "$INBOX" 2>/dev/null
            rc=$?
            # gtimeout returns 124 on timeout
            if [ "$rc" -eq 124 ]; then rc=2; else rc=0; fi
        else
            # Fallback: use background fswatch + sleep timeout
            fswatch -1 --event Updated --event Renamed "$INBOX" &>/dev/null &
            FSWATCH_PID=$!
            WAITED=0
            while [ "$WAITED" -lt "$INOTIFY_TIMEOUT" ] && kill -0 "$FSWATCH_PID" 2>/dev/null; do
                sleep 1
                WAITED=$((WAITED + 1))
            done
            if kill -0 "$FSWATCH_PID" 2>/dev/null; then
                kill "$FSWATCH_PID" 2>/dev/null
                wait "$FSWATCH_PID" 2>/dev/null
                rc=2  # timeout
            else
                wait "$FSWATCH_PID" 2>/dev/null
                rc=0  # event
            fi
        fi
    else
        # Linux: inotifywait (original behavior)
        inotifywait -q -t "$INOTIFY_TIMEOUT" -e modify -e close_write "$INBOX" 2>/dev/null
        rc=$?
    fi
    set -e

    # rc=0: event fired (instant delivery)
    # rc=1: watch invalidated — Claude Code uses atomic write (tmp+rename),
    #        which replaces the inode. inotifywait sees DELETE_SELF → rc=1.
    #        File still exists with new inode. Treat as event, re-watch next loop.
    # rc=2: timeout (30s safety net for WSL2 inotify gaps / macOS fswatch timeout)
    # All cases: check for unread, then loop back (re-watches new inode)
    sleep 0.3

    if [ "$rc" -eq 2 ]; then
        if [ "${ASW_PROCESS_TIMEOUT:-1}" = "1" ]; then
            process_unread "timeout"
        fi
    else
        process_unread "event"
    fi
done

fi  # end testing guard

# Source shared agent status library outside the testing guard so that
# agent_is_busy_check() is available in test mode too.
# In normal mode it was already sourced above; double-sourcing is harmless.
_agent_status_lib="${SCRIPT_DIR}/lib/agent_status.sh"
if [ -f "$_agent_status_lib" ] && ! type agent_is_busy_check &>/dev/null; then
    source "$_agent_status_lib"
fi
