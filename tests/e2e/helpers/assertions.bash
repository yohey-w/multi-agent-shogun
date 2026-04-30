#!/usr/bin/env bash
# assertions.bash — Custom E2E test assertions for bats

# ─── assert_yaml_field ───
# Check that a YAML field has the expected value.
# Usage: assert_yaml_field <file> <dotted.key.path> <expected_value>
assert_yaml_field() {
    local file="$1" field="$2" expected="$3"
    local actual
    actual=$(python3 -c "
import yaml
try:
    with open('$file') as f:
        data = yaml.safe_load(f) or {}
    keys = '$field'.split('.')
    val = data
    for k in keys:
        if isinstance(val, dict):
            val = val.get(k)
        else:
            val = None
            break
    print(val if val is not None else '')
except Exception:
    print('')
" 2>/dev/null)
    if [ "$actual" != "$expected" ]; then
        echo "ASSERT FAIL: $file → $field = '$actual' (expected '$expected')" >&2
        return 1
    fi
    return 0
}

# ─── wait_for_pane_text ───
# Wait until a regex pattern appears in a tmux pane's output.
# Usage: wait_for_pane_text <pane_target> <pattern> [timeout_sec]
wait_for_pane_text() {
    local pane="$1" pattern="$2" timeout="${3:-30}"
    local elapsed=0
    while [ "$elapsed" -lt "$timeout" ]; do
        # -S - captures full scrollback (not just visible area)
        # -J joins wrapped lines so long messages don't split across capture rows
        if tmux capture-pane -t "$pane" -p -J -S - 2>/dev/null | grep -qE "$pattern"; then
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    echo "TIMEOUT: pattern '$pattern' not found in $pane after ${timeout}s" >&2
    echo "--- Pane content (scrollback) ---" >&2
    tmux capture-pane -t "$pane" -p -J -S - 2>/dev/null | tail -40 >&2 || true
    echo "--- End pane content ---" >&2
    return 1
}

# ─── assert_inbox_unread_count ───
# Check the number of unread messages in an inbox file.
# Usage: assert_inbox_unread_count <inbox_file> <expected_count>
assert_inbox_unread_count() {
    local inbox_file="$1" expected="$2"
    local actual
    actual=$(grep -c 'read: false' "$inbox_file" 2>/dev/null || echo 0)
    if [ "$actual" -ne "$expected" ]; then
        echo "ASSERT FAIL: unread count = $actual (expected $expected) in $inbox_file" >&2
        return 1
    fi
    return 0
}

# ─── wait_for_file ───
# Wait until a file exists.
# Usage: wait_for_file <file_path> [timeout_sec]
wait_for_file() {
    local file="$1" timeout="${2:-10}"
    local elapsed=0
    while [ "$elapsed" -lt "$timeout" ]; do
        [ -f "$file" ] && return 0
        sleep 1
        elapsed=$((elapsed + 1))
    done
    echo "TIMEOUT: file '$file' not created after ${timeout}s" >&2
    return 1
}

# ─── wait_for_yaml_value ───
# Wait until a YAML field reaches the expected value.
# Usage: wait_for_yaml_value <file> <dotted.key.path> <expected_value> [timeout_sec]
wait_for_yaml_value() {
    local file="$1" field="$2" expected="$3" timeout="${4:-30}"
    local elapsed=0
    while [ "$elapsed" -lt "$timeout" ]; do
        if [ -f "$file" ]; then
            local actual
            actual=$(python3 -c "
import yaml
try:
    with open('$file') as f:
        data = yaml.safe_load(f) or {}
    keys = '$field'.split('.')
    val = data
    for k in keys:
        if isinstance(val, dict):
            val = val.get(k)
        else:
            val = None
            break
    print(val if val is not None else '')
except:
    print('')
" 2>/dev/null)
            if [ "$actual" = "$expected" ]; then
                return 0
            fi
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    echo "TIMEOUT: $file → $field did not reach '$expected' after ${timeout}s" >&2
    return 1
}

# ─── assert_file_contains ───
# Check that a file contains a specific string.
# Usage: assert_file_contains <file> <string>
assert_file_contains() {
    local file="$1" string="$2"
    if ! grep -qF "$string" "$file" 2>/dev/null; then
        echo "ASSERT FAIL: '$string' not found in $file" >&2
        return 1
    fi
    return 0
}

# ─── assert_inbox_message_exists ───
# Check that an inbox has a message with the given type from the given sender.
# Usage: assert_inbox_message_exists <inbox_file> <from> <type>
assert_inbox_message_exists() {
    local inbox_file="$1" from="$2" type="$3"
    python3 -c "
import yaml, sys
try:
    with open('$inbox_file') as f:
        data = yaml.safe_load(f) or {}
    msgs = data.get('messages', [])
    found = any(m.get('from') == '$from' and m.get('type') == '$type' for m in msgs)
    if not found:
        print(f'ASSERT FAIL: no message from=$from type=$type in $inbox_file', file=sys.stderr)
        sys.exit(1)
except Exception as e:
    print(f'ASSERT FAIL: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null
}
