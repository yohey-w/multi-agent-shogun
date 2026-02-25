#!/usr/bin/env bash
# inbox_write.sh — メールボックスへのメッセージ書き込み（排他ロック付き）
# Usage: bash scripts/inbox_write.sh <target_agent> <content> [type] [from]
# Example: bash scripts/inbox_write.sh karo "足軽5号、任務完了" report_received ashigaru5

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$1"
CONTENT="$2"
TYPE="${3:-wake_up}"
FROM="${4:-unknown}"

INBOX="$SCRIPT_DIR/queue/inbox/${TARGET}.yaml"
LOCKFILE="${INBOX}.lock"

# Validate arguments
if [ -z "$TARGET" ] || [ -z "$CONTENT" ]; then
    echo "Usage: inbox_write.sh <target_agent> <content> [type] [from]" >&2
    exit 1
fi

# Initialize inbox if not exists
if [ ! -f "$INBOX" ]; then
    mkdir -p "$(dirname "$INBOX")"
    echo "messages: []" > "$INBOX"
fi

# Generate unique message ID (timestamp-based)
MSG_ID="msg_$(date +%Y%m%d_%H%M%S)_$(head -c 4 /dev/urandom | xxd -p)"
TIMESTAMP=$(date "+%Y-%m-%dT%H:%M:%S")

# Cross-platform lock: flock (Linux) or mkdir (macOS fallback)
LOCK_DIR="${LOCKFILE}.d"

_acquire_lock() {
    if command -v flock &>/dev/null; then
        exec 200>"$LOCKFILE"
        flock -w 5 200 || return 1
    else
        local i=0
        while ! mkdir "$LOCK_DIR" 2>/dev/null; do
            sleep 0.1
            i=$((i + 1))
            [ $i -ge 50 ] && return 1  # 5s timeout
        done
    fi
    return 0
}

_release_lock() {
    if command -v flock &>/dev/null; then
        exec 200>&-
    else
        rmdir "$LOCK_DIR" 2>/dev/null
    fi
}

# Atomic write with lock (3 retries)
attempt=0
max_attempts=3

while [ $attempt -lt $max_attempts ]; do
    if _acquire_lock; then
        "$SCRIPT_DIR/.venv/bin/python3" -c "
import yaml, sys

try:
    # Load existing inbox
    with open('$INBOX') as f:
        data = yaml.safe_load(f)

    # Initialize if needed
    if not data:
        data = {}
    if not data.get('messages'):
        data['messages'] = []

    # Add new message
    new_msg = {
        'id': '$MSG_ID',
        'from': '$FROM',
        'timestamp': '$TIMESTAMP',
        'type': '$TYPE',
        'content': '''$CONTENT''',
        'read': False
    }
    data['messages'].append(new_msg)

    # Overflow protection: keep max 50 messages
    if len(data['messages']) > 50:
        msgs = data['messages']
        unread = [m for m in msgs if not m.get('read', False)]
        read = [m for m in msgs if m.get('read', False)]
        # Keep all unread + newest 30 read messages
        data['messages'] = unread + read[-30:]

    # Atomic write: tmp file + rename (prevents partial reads)
    import tempfile, os
    tmp_fd, tmp_path = tempfile.mkstemp(dir=os.path.dirname('$INBOX'), suffix='.tmp')
    try:
        with os.fdopen(tmp_fd, 'w') as f:
            yaml.dump(data, f, default_flow_style=False, allow_unicode=True, indent=2)
        os.replace(tmp_path, '$INBOX')
    except:
        os.unlink(tmp_path)
        raise

except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
"
        STATUS=$?
        _release_lock
        [ $STATUS -eq 0 ] && exit 0
        attempt=$((attempt + 1))
        [ $attempt -lt $max_attempts ] && sleep 1
    else
        # Lock timeout
        attempt=$((attempt + 1))
        if [ $attempt -lt $max_attempts ]; then
            echo "[inbox_write] Lock timeout for $INBOX (attempt $attempt/$max_attempts), retrying..." >&2
            sleep 1
        else
            echo "[inbox_write] Failed to acquire lock after $max_attempts attempts for $INBOX" >&2
            exit 1
        fi
    fi
done
