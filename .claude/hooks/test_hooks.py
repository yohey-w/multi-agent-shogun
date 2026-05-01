#!/usr/bin/env python3
"""
Functional tests for guard_rm.sh and guard_outside_project.sh.
Run: python3 .claude/hooks/test_hooks.py
"""
import subprocess
import json
import os
import sys

PROJECT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HOME = os.path.expanduser("~")
env = {"CLAUDE_PROJECT_DIR": PROJECT, "PATH": "/usr/bin:/bin:/usr/local/bin", "HOME": HOME}

GUARD_RM = os.path.join(PROJECT, ".claude/hooks/guard_rm.sh")
GUARD_OUT = os.path.join(PROJECT, ".claude/hooks/guard_outside_project.sh")

def run(hook, payload, extra_env=None):
    e = dict(env)
    if extra_env:
        e.update(extra_env)
    r = subprocess.run(
        ["bash", hook],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        env=e,
    )
    return r.returncode, r.stderr.strip()

failures = []

def check(label, hook, payload, expected_exit, extra_env=None):
    code, stderr = run(hook, payload, extra_env)
    ok = code == expected_exit
    sym = "PASS" if ok else "FAIL"
    print(f"[{sym}] {label} -> exit={code} (expected {expected_exit}) {('| ' + stderr[:70]) if stderr else ''}")
    if not ok:
        failures.append(label)

# guard_rm.sh tests
check("rm -rf / -> block",          GUARD_RM, {"tool_input":{"command":"rm -rf /"}},           2)
check("rm -fr / -> block",          GUARD_RM, {"tool_input":{"command":"rm -fr /"}},           2)
check("rm -rf /home/user -> block", GUARD_RM, {"tool_input":{"command":"rm -rf /home/user"}},  2)
check("rm -rf /mnt/data -> block",  GUARD_RM, {"tool_input":{"command":"rm -rf /mnt/data"}},   2)
check("rm -fr ~ -> block",          GUARD_RM, {"tool_input":{"command":"rm -fr ~"}},            2)
check("rm -rf /tmp/x -> allow",     GUARD_RM, {"tool_input":{"command":"rm -rf /tmp/x"}},      0)
check("rm -rf ./build -> allow",    GUARD_RM, {"tool_input":{"command":"rm -rf ./build"}},     0)
check("rm -f file.txt -> allow",    GUARD_RM, {"tool_input":{"command":"rm -f file.txt"}},     0)
check("no command field -> allow",  GUARD_RM, {"tool_input":{}},                               0)

# guard_outside_project.sh tests
check("edit /etc/hosts -> block",        GUARD_OUT, {"tool_input":{"file_path":"/etc/hosts"}},               2)
check("edit /usr/local/bin/x -> block",  GUARD_OUT, {"tool_input":{"file_path":"/usr/local/bin/x"}},         2)
check("edit inside project -> allow",    GUARD_OUT, {"tool_input":{"file_path":f"{PROJECT}/dashboard.md"}},  0)
check("edit ~/.claude/agents/ -> allow", GUARD_OUT, {"tool_input":{"file_path":f"{HOME}/.claude/agents/x.md"}}, 0)
check("no file_path -> allow",           GUARD_OUT, {"tool_input":{}},                                       0)

print()
if failures:
    print(f"FAILED: {len(failures)} test(s): {', '.join(failures)}")
    sys.exit(1)
else:
    print(f"All tests passed.")
