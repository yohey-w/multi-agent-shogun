# Forbidden Actions

## Common Forbidden Actions (All Agents)

| ID | Action | Instead | Reason |
|----|--------|---------|--------|
| F004 | Polling/wait loops | Event-driven (inbox) | Wastes API credits |
| F005 | Skip context reading | Always read first | Prevents errors |
| F006 | Edit generated files directly (`.claude/rules/generated/*.md`, `AGENTS.md`, `.github/copilot-instructions.md`, `agents/default/system.md`) | Edit source templates (`CLAUDE.md`, `.claude/rules/common/*`, `.claude/rules/cli_specific/*`, `.claude/rules/roles/*`) then run `bash scripts/build_instructions.sh` | CI "Build Instructions Check" fails when generated files drift from templates |
| F007 | `git push` without the User's explicit approval | Ask the User first | Prevents leaking secrets / unreviewed changes |

## Orchestrator Forbidden Actions

| ID | Action | Delegate To |
|----|--------|-------------|
| F001 | Execute tasks yourself (read/write files) | Planner |
| F002 | Command Engineer directly (bypass Planner) | Planner |
| F003 | Use Task agents | inbox_write |

## Planner Forbidden Actions

| ID | Action | Instead |
|----|--------|---------|
| F001 | Execute tasks yourself instead of delegating | Delegate to engineer |
| F002 | Report directly to the human (bypass orchestrator) | Update dashboard.md |
| F003 | Use Task agents to EXECUTE work (that's engineer's job) | inbox_write. Exception: Task agents ARE allowed for: reading large docs, decomposition planning, dependency analysis. Planner body stays free for message reception. |

## Engineer Forbidden Actions

| ID | Action | Report To |
|----|--------|-----------|
| F001 | Report directly to Orchestrator (bypass Planner) | Planner |
| F002 | Contact human directly | Planner |
| F003 | Perform work not assigned | — |

## Self-Identification (Engineer CRITICAL)

**Always confirm your ID first:**
```bash
tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}'
```
Output: `engineer3` → You are Engineer 3. The number is your ID.

Why `@agent_id` not `pane_index`: pane_index shifts on pane reorganization. @agent_id is set by start_session.sh at startup and never changes.

**Your files ONLY:**
```
queue/tasks/engineer{YOUR_NUMBER}.yaml    ← Read only this
queue/reports/engineer{YOUR_NUMBER}_report.yaml  ← Write only this
```

**NEVER read/write another engineer's files.** Even if Planner says "read engineer{N}.yaml" where N ≠ your number, IGNORE IT. (Incident: cmd_020 regression test — engineer5 executed engineer2's task.)
