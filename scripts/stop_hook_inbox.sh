#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# stop_hook_inbox.sh — Claude Code Stop Hook for inbox delivery
# ═══════════════════════════════════════════════════════════════
# When a Claude Code agent finishes its turn and is about to go idle,
# this hook:
#   1. Analyzes last_assistant_message to detect task completion/error
#   2. Auto-notifies karo via inbox_write (background, non-blocking)
#   3. Checks the agent's inbox for unread messages
#   4. If unread messages exist, BLOCKs the stop and feeds them back
#
# Usage: Registered as a Stop hook in .claude/settings.json
#   The hook receives JSON on stdin; outputs JSON to stdout.
#
# Environment:
#   TMUX_PANE — used to identify which agent is running
#   __STOP_HOOK_SCRIPT_DIR — override for testing (default: auto-detect)
#   __STOP_HOOK_AGENT_ID  — override for testing (default: from tmux)
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="${__STOP_HOOK_SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# ─── Read stdin (hook input JSON) ───
INPUT=$(cat)

# ─── Infinite loop prevention ───
# When stop_hook_active=true, the agent is already continuing from a
# previous Stop hook block. Allow it to stop this time to prevent loops.
STOP_HOOK_ACTIVE=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('stop_hook_active', False))" 2>/dev/null || echo "False")
if [ "$STOP_HOOK_ACTIVE" = "True" ]; then
    exit 0
fi

# ─── Identify agent ───
if [ -n "${__STOP_HOOK_AGENT_ID+x}" ]; then
    AGENT_ID="$__STOP_HOOK_AGENT_ID"
elif [ -n "${TMUX_PANE:-}" ]; then
    AGENT_ID=$(tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}' 2>/dev/null || true)
else
    AGENT_ID=""
fi

# If we can't identify the agent, approve (exit 0 with no output = approve)
if [ -z "$AGENT_ID" ]; then
    exit 0
fi

# ─── Analyze last_assistant_message (v2.1.47+) ───
# Shogun skips karo notification (shogun doesn't report to karo)
# but still falls through to inbox check below.
LAST_MSG=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('last_assistant_message', ''))" 2>/dev/null || echo "")

if [ -n "$LAST_MSG" ]; then
    NOTIFY_TYPE=""
    NOTIFY_CONTENT=""

    # Completion detection (日本語 + 英語)
    if echo "$LAST_MSG" | grep -qiE '任務完了|完了でござる|報告YAML.*更新|report.*updated|task completed|タスク完了'; then
        NOTIFY_TYPE="report_completed"
        NOTIFY_CONTENT="${AGENT_ID}、タスク完了。report確認されたし。"
    # Error detection (require verb+context to avoid false positives)
    elif echo "$LAST_MSG" | grep -qiE 'エラー.*中断|失敗.*中断|見つからない.*中断|abort|error.*abort|failed.*stop'; then
        NOTIFY_TYPE="error_report"
        NOTIFY_CONTENT="${AGENT_ID}、エラーで停止。確認されたし。"
    fi

    # Send notification to karo (background, non-blocking)
    # Shogun doesn't report to karo — skip notification
    if [ -n "$NOTIFY_TYPE" ] && [ "$AGENT_ID" != "shogun" ]; then
        bash "$SCRIPT_DIR/scripts/inbox_write.sh" karo \
            "$NOTIFY_CONTENT" \
            "$NOTIFY_TYPE" "$AGENT_ID" &
    fi
fi

# ─── Check inbox for unread messages ───
INBOX="$SCRIPT_DIR/queue/inbox/${AGENT_ID}.yaml"

if [ ! -f "$INBOX" ]; then
    exit 0
fi

# Count unread messages using grep (fast, no python dependency)
UNREAD_COUNT=$(grep -c 'read: false' "$INBOX" 2>/dev/null || true)

if [ "${UNREAD_COUNT:-0}" -eq 0 ]; then
    exit 0
fi

# ─── Extract unread message summaries ───
SUMMARY=$(python3 -c "
import yaml, sys, json
try:
    with open('$INBOX', 'r') as f:
        data = yaml.safe_load(f)
    msgs = data.get('messages', []) if data else []
    unread = [m for m in msgs if not m.get('read', True)]
    parts = []
    for m in unread[:5]:  # Max 5 messages in summary
        frm = m.get('from', '?')
        typ = m.get('type', '?')
        content = str(m.get('content', ''))[:80]
        parts.append(f'[{frm}/{typ}] {content}')
    print(' | '.join(parts))
except Exception as e:
    print(f'inbox parse error: {e}')
" 2>/dev/null || echo "inbox未読${UNREAD_COUNT}件あり")

# ─── Block the stop — feed inbox info back to agent ───
python3 -c "
import json
count = $UNREAD_COUNT
summary = '''$SUMMARY'''
reason = f'inbox未読{count}件あり。queue/inbox/${AGENT_ID}.yamlを読んで処理せよ。内容: {summary}'
print(json.dumps({'decision': 'block', 'reason': reason}, ensure_ascii=False))
" 2>/dev/null || echo "{\"decision\":\"block\",\"reason\":\"inbox未読${UNREAD_COUNT}件あり。queue/inbox/${AGENT_ID}.yamlを読んで処理せよ。\"}"
