#!/usr/bin/env bash
#
# slim_yaml.sh - YAML slimming wrapper with file locking
#
# Usage: bash slim_yaml.sh <agent_id>
#
# This script acquires an exclusive lock before calling the Python slimmer,
# ensuring no concurrent modifications to YAML files (same pattern as inbox_write.sh).
#

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOCK_FILE="${SCRIPT_DIR}/../queue/.slim_yaml.lock"
LOCK_TIMEOUT=10

# Acquire exclusive lock (cross-platform: flock on Linux, mkdir on macOS)
if command -v flock &>/dev/null; then
    exec 200>"$LOCK_FILE"
    if ! flock -w "$LOCK_TIMEOUT" 200; then
        echo "Error: Failed to acquire lock within $LOCK_TIMEOUT seconds" >&2
        exit 1
    fi
else
    _ld="${LOCK_FILE}.d"; _i=0
    while ! mkdir "$_ld" 2>/dev/null; do
        sleep 0.1; _i=$((_i+1))
        [ $_i -ge $((LOCK_TIMEOUT * 10)) ] && { echo "Error: Failed to acquire lock within $LOCK_TIMEOUT seconds" >&2; exit 1; }
    done
    trap "rmdir '$_ld' 2>/dev/null" EXIT
fi

# Call the Python implementation
python3 "$(dirname "$0")/slim_yaml.py" "$@"
exit_code=$?

# Lock is automatically released when file descriptor is closed
exit "$exit_code"
