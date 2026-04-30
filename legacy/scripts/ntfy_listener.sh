#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# ntfy Input Listener
# Streams messages from ntfy topic, writes to inbox YAML, wakes shogun.
# NOT polling — uses ntfy's streaming endpoint (long-lived HTTP connection).
# FR-066: ntfy認証対応 (Bearer token / Basic auth)
# ═══════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS="$SCRIPT_DIR/config/settings.yaml"
TOPIC=$(grep 'ntfy_topic:' "$SETTINGS" | awk '{print $2}' | tr -d '"')
INBOX="$SCRIPT_DIR/queue/ntfy_inbox.yaml"
LOCKFILE="${INBOX}.lock"
CORRUPT_DIR="$SCRIPT_DIR/logs/ntfy_inbox_corrupt"

# ntfy_auth.sh読み込み
# shellcheck source=../lib/ntfy_auth.sh
source "$SCRIPT_DIR/lib/ntfy_auth.sh"

if [ -z "$TOPIC" ]; then
    echo "[ntfy_listener] ntfy_topic not configured in settings.yaml" >&2
    exit 1
fi

# トピック名セキュリティ検証
ntfy_validate_topic "$TOPIC" || true

# Initialize inbox if not exists
if [ ! -f "$INBOX" ]; then
    echo "inbox:" > "$INBOX"
fi

# 認証引数を取得（設定がなければ空 = 後方互換）
AUTH_ARGS=()
while IFS= read -r line; do
    [ -n "$line" ] && AUTH_ARGS+=("$line")
done < <(ntfy_get_auth_args "$SCRIPT_DIR/config/ntfy_auth.env")

# JSON field extractor (python3 — jq not available)
parse_json() {
    "$SCRIPT_DIR/.venv/bin/python3" -c "import sys,json; print(json.load(sys.stdin).get('$1',''))" 2>/dev/null
}

parse_tags() {
    "$SCRIPT_DIR/.venv/bin/python3" -c "import sys,json; print(','.join(json.load(sys.stdin).get('tags',[])))" 2>/dev/null
}

append_ntfy_inbox() {
    local msg_id="$1"
    local ts="$2"
    local msg="$3"

    (
        if command -v flock &>/dev/null; then
            flock -w 5 200 || exit 1
        else
            _ld="${LOCKFILE}.d"; _i=0
            while ! mkdir "$_ld" 2>/dev/null; do sleep 0.1; _i=$((_i+1)); [ $_i -ge 50 ] && exit 1; done
            trap "rmdir '$_ld' 2>/dev/null" EXIT
        fi
        NTFY_INBOX_PATH="$INBOX" \
        NTFY_CORRUPT_DIR="$CORRUPT_DIR" \
        MSG_ID="$msg_id" \
        MSG_TS="$ts" \
        MSG_TEXT="$msg" \
        "$SCRIPT_DIR/.venv/bin/python3" - << 'PY'
import datetime
import os
import shutil
import sys
import tempfile
import yaml

path = os.environ["NTFY_INBOX_PATH"]
corrupt_dir = os.environ.get("NTFY_CORRUPT_DIR", "")
entry = {
    "id": os.environ.get("MSG_ID", ""),
    "timestamp": os.environ.get("MSG_TS", ""),
    "message": os.environ.get("MSG_TEXT", ""),
    "status": "pending",
}

data = {}
parse_error = False

if os.path.exists(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            loaded = yaml.safe_load(f)
        if isinstance(loaded, dict):
            data = loaded
        elif loaded is None:
            data = {}
        else:
            parse_error = True
    except Exception:
        parse_error = True

if parse_error and os.path.exists(path):
    try:
        if corrupt_dir:
            os.makedirs(corrupt_dir, exist_ok=True)
            backup = os.path.join(
                corrupt_dir,
                f"ntfy_inbox_corrupt_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.yaml",
            )
            shutil.copy2(path, backup)
    except Exception:
        pass
    data = {}

items = data.get("inbox")
if not isinstance(items, list):
    items = []
items.append(entry)
data["inbox"] = items

tmp_fd, tmp_path = tempfile.mkstemp(dir=os.path.dirname(path), suffix=".tmp")
try:
    with os.fdopen(tmp_fd, "w", encoding="utf-8") as f:
        yaml.safe_dump(
            data,
            f,
            default_flow_style=False,
            allow_unicode=True,
            sort_keys=False,
        )
    os.replace(tmp_path, path)
except Exception as e:
    try:
        os.unlink(tmp_path)
    except Exception:
        pass
    print(f"[ntfy_listener] failed to write inbox: {e}", file=sys.stderr)
    sys.exit(1)
PY
    ) 200>"$LOCKFILE"
}

echo "[$(date)] ntfy listener started — topic: $TOPIC (auth: ${NTFY_TOKEN:+token}${NTFY_USER:+basic}${NTFY_TOKEN:-${NTFY_USER:-none}})" >&2

while true; do
    # Stream new messages (long-lived connection, blocks until message arrives)
    curl -s --no-buffer "${AUTH_ARGS[@]}" "https://ntfy.sh/$TOPIC/json" 2>/dev/null | while IFS= read -r line; do
        # Skip keepalive pings and non-message events
        EVENT=$(echo "$line" | parse_json event)
        [ "$EVENT" != "message" ] && continue

        # Skip outbound messages (sent by our own scripts/ntfy.sh)
        TAGS=$(echo "$line" | parse_tags)
        echo "$TAGS" | grep -q "outbound" && continue

        # Extract message content
        MSG=$(echo "$line" | parse_json message)
        [ -z "$MSG" ] && continue

        MSG_ID=$(echo "$line" | parse_json id)
        TIMESTAMP=$(date "+%Y-%m-%dT%H:%M:%S%:z")

        echo "[$(date)] Received: $MSG" >&2

        # Append to inbox YAML (flock + atomic write; multiline-safe)
        if ! append_ntfy_inbox "$MSG_ID" "$TIMESTAMP" "$MSG"; then
            echo "[$(date)] [ntfy_listener] WARNING: failed to append ntfy_inbox entry" >&2
            continue
        fi

        # Auto-reply removed — shogun replies directly after processing.

        # Wake shogun via inbox (ntfy処理は将軍が直接受信)
        bash "$SCRIPT_DIR/scripts/inbox_write.sh" shogun \
            "ntfyから新しいメッセージ受信。queue/ntfy_inbox.yaml を確認し処理せよ。" \
            ntfy_received ntfy_listener
    done

    # Connection dropped — reconnect after brief pause
    echo "[$(date)] Connection lost, reconnecting in 5s..." >&2
    sleep 5
done
