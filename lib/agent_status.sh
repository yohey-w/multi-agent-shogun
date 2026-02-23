#!/usr/bin/env bash
# lib/agent_status.sh — エージェント稼働状態検出の共有ライブラリ
#
# 提供関数:
#   agent_is_busy_check <pane_target>   → 0=busy, 1=idle, 2=pane不在
#   get_pane_state_label <pane_target>  → "稼働中" / "待機中" / "不在"
#
# 使用例:
#   source lib/agent_status.sh
#   agent_is_busy_check "multiagent:agents.0"
#   state=$(get_pane_state_label "multiagent:agents.3")

# agent_is_busy_check <pane_target>
# tmux paneの末尾5行からCLI固有のidle/busyパターンを検出する。
# Returns: 0=busy, 1=idle, 2=pane不在
#
# Detection strategy:
#   1. Status bar check (last non-empty line): 'esc to' only appears in
#      Claude Code's status bar during active processing. This is the most
#      reliable busy signal — immune to old spinner text in scroll-back.
#   2. Idle checks: CLI-specific idle prompts (❯, Codex ? prompt)
#   3. Text-based busy markers: spinner keywords in bottom 5 lines
#
# Why this order matters:
#   - Claude Code shows ❯ prompt even during thinking/working, so idle
#     checks alone cause false-idle (the bug that broke is_busy).
#   - Old spinner text (e.g. "Working on task • esc to interrupt") lingers
#     in scroll-back, so checking all 5 lines for 'esc to' causes false-busy
#     (the bug T-BUSY-008 fixed). Solution: check ONLY the last line for
#     'esc to' — the status bar is always at the bottom.
agent_is_busy_check() {
    local pane_target="$1"
    local pane_tail
    # Only check the bottom 5 lines. Old busy markers linger in scroll-back
    # and cause false-busy if we scan too many lines.
    pane_tail=$(timeout 2 tmux capture-pane -t "$pane_target" -p 2>/dev/null | tail -5)

    # Pane doesn't exist or empty capture
    if [[ -z "$pane_tail" ]]; then
        return 2
    fi

    # ── Status bar check (last non-empty line = most reliable) ──
    # Claude Code status bar appends 'esc to interrupt' (or truncated 'esc to…')
    # ONLY during active processing. When idle, this suffix disappears.
    # Checking only the last line avoids false-busy from old spinner text
    # that might still be visible in the bottom 5 lines (T-BUSY-008 scenario).
    local last_line
    last_line=$(echo "$pane_tail" | grep -v '^[[:space:]]*$' | tail -1)
    if echo "$last_line" | grep -qiF 'esc to'; then
        return 0  # busy — status bar confirms active processing
    fi

    # ── Idle checks ──
    # Codex idle prompt
    if echo "$pane_tail" | grep -qE '(\? for shortcuts|context left)'; then
        return 1
    fi
    # Claude Code bare prompt
    if echo "$pane_tail" | grep -qE '^(❯|›)\s*$'; then
        return 1
    fi

    # ── Text-based busy markers (bottom 5 lines) ──
    # These catch non-Claude-Code CLIs and edge cases where status bar
    # isn't present but spinner text indicates active work.
    if echo "$pane_tail" | grep -qiF 'background terminal running'; then
        return 0
    fi
    if echo "$pane_tail" | grep -qiE '(Working|Thinking|Planning|Sending|task is in progress|Compacting conversation|thought for|思考中|考え中|計画中|送信中|処理中|実行中)'; then
        return 0
    fi

    return 1  # idle (default)
}

# get_pane_state_label <pane_target>
# 人間が読めるラベルを返す。
get_pane_state_label() {
    local pane_target="$1"
    agent_is_busy_check "$pane_target"
    local rc=$?
    case $rc in
        0) echo "稼働中" ;;
        1) echo "待機中" ;;
        2) echo "不在" ;;
    esac
}
