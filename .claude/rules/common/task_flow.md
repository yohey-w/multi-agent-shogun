# Task Flow

## Workflow: Orchestrator → Planner → Engineer

```
User: command → Orchestrator: write YAML → inbox_write → Planner: decompose → inbox_write → Engineer: execute → report YAML → inbox_write → Planner: update dashboard → Orchestrator: read dashboard
```

## Status Reference (Single Source)

Status is defined per YAML file type. **Keep it minimal. Simple is best.**

Fixed status set (do not add casually):
- `queue/orchestrator_to_planner.yaml`: `pending`, `in_progress`, `done`, `cancelled`
- `queue/tasks/engineerN.yaml`: `assigned`, `blocked`, `done`, `failed`
- `queue/tasks/pending.yaml`: `pending_blocked`
- `queue/ntfy_inbox.yaml`: `pending`, `processed`

Do NOT invent new status values without updating this section.

### Command Queue: `queue/orchestrator_to_planner.yaml`

Meanings and allowed/forbidden actions (short):

- `pending`: not acknowledged yet
  - Allowed: Planner reads and immediately ACKs (`pending → in_progress`)
  - Forbidden: dispatching subtasks while still `pending`

- `in_progress`: acknowledged and being worked
  - Allowed: decompose/dispatch/collect/consolidate
  - Forbidden: moving goalposts (editing acceptance_criteria), or marking `done` without meeting all criteria

- `done`: complete and validated
  - Allowed: read-only (history)
  - Forbidden: editing old cmd to "reopen" (use a new cmd instead)

- `cancelled`: intentionally stopped
  - Allowed: read-only (history)
  - Forbidden: continuing work under this cmd (use a new cmd instead)

### Archive Rule

The active queue file (`queue/orchestrator_to_planner.yaml`) must only contain
`pending` and `in_progress` entries. All other statuses are archived.

When a cmd reaches a terminal status (`done`, `cancelled`, `paused`),
Planner must move the entire YAML entry to `queue/orchestrator_to_planner_archive.yaml`.

| Status | In active file? | Action |
|--------|----------------|--------|
| pending | YES | Keep |
| in_progress | YES | Keep |
| done | NO | Move to archive |
| cancelled | NO | Move to archive |
| paused | NO | Move to archive (restore to active when resumed) |

**Canonical statuses (exhaustive list — do NOT invent others)**:
- `pending` — not started
- `in_progress` — acknowledged, being worked
- `done` — complete (covers former "completed", "superseded", "active")
- `cancelled` — intentionally stopped, will not resume
- `paused` — stopped by User's decision, may resume later

Any other status value (e.g., `completed`, `active`, `superseded`) is
forbidden. If found during archive, normalize to the canonical set above.

**Planner rule (ack fast)**:
- The moment Planner starts processing a cmd (after reading it), update that cmd status:
  - `pending` → `in_progress`
  - This prevents "nobody is working" confusion and stabilizes escalation logic.

### Engineer Task File: `queue/tasks/engineerN.yaml`

Meanings and allowed/forbidden actions (short):

- `assigned`: start now
  - Allowed: assignee engineer executes and updates to `done/failed` + report + inbox_write
  - Forbidden: other agents editing that engineer YAML

- `blocked`: do NOT start yet (prereqs missing)
  - Allowed: Planner unblocks by changing to `assigned` when ready, then inbox_write
  - Forbidden: nudging or starting work while `blocked`

- `done`: completed
  - Allowed: read-only; used for consolidation
  - Forbidden: reusing task_id for redo (use redo protocol)

- `failed`: failed with reason
  - Allowed: report must include reason + unblock suggestion
  - Forbidden: silent failure

Note:
- Normally, "idle" is a UI state (no active task), not a YAML status value.
- Exception (placeholder only): `status: idle` is allowed **only** when `task_id: null` (clean start template written by `start_session.sh --clean`).
  - In that state, the file is a placeholder and should be treated as "no task assigned yet".

### Pending Tasks (Planner-managed): `queue/tasks/pending.yaml`

- `pending_blocked`: holding area; **must not** be assigned yet
  - Allowed: Planner moves it to an `engineerN.yaml` as `assigned` after prerequisites complete
  - Forbidden: pre-assigning to engineer before ready

### NTFY Inbox (User phone): `queue/ntfy_inbox.yaml`

- `pending`: needs processing
  - Allowed: Orchestrator processes and sets `processed`
  - Forbidden: leaving it pending without reason

- `processed`: processed; keep record
  - Allowed: read-only
  - Forbidden: flipping back to pending without creating a new entry

## Immediate Delegation Principle (Orchestrator)

**Delegate to Planner immediately and end your turn** so the User can input next command.

```
User: command → Orchestrator: write YAML → inbox_write → END TURN
                                        ↓
                                  User: can input next
                                        ↓
                              Planner/Engineer: work in background
                                        ↓
                              dashboard.md updated as report
```

## Event-Driven Wait Pattern (Planner)

**After dispatching all subtasks: STOP.** Do not launch background monitors or sleep loops.

```
Step 7: Dispatch cmd_N subtasks → inbox_write to engineer
Step 8: check_pending → if pending cmd_N+1, process it → then STOP
  → Planner becomes idle (prompt waiting)
Step 9: Engineer completes → inbox_write planner → watcher nudges planner
  → Planner wakes, scans reports, acts
```

**Why no background monitor**: inbox_watcher.sh detects engineer's inbox_write to planner and sends a nudge. This is true event-driven. No sleep, no polling, no CPU waste.

**Planner wakes via**: inbox nudge from engineer report, orchestrator new cmd, or system event. Nothing else.

## "Wake = Full Scan" Pattern

Claude Code cannot "wait". Prompt-wait = stopped.

1. Dispatch engineer
2. Say "stopping here" and end processing
3. Engineer wakes you via inbox
4. Scan ALL report files (not just the reporting one)
5. Assess situation, then act

## Report Scanning (Communication Loss Safety)

On every wakeup (regardless of reason), scan ALL `queue/reports/engineer*_report.yaml`.
Cross-reference with dashboard.md — process any reports not yet reflected.

**Why**: Engineer inbox messages may be delayed. Report files are already written and scannable as a safety net.

## Foreground Block Prevention (24-min Freeze Lesson)

**Planner blocking = entire army halts.** On 2026-02-06, foreground `sleep` during delivery checks froze planner for 24 minutes.

**Rule: NEVER use `sleep` in foreground.** After dispatching tasks → stop and wait for inbox wakeup.

| Command Type | Execution Method | Reason |
|-------------|-----------------|--------|
| Read / Write / Edit | Foreground | Completes instantly |
| inbox_write.sh | Foreground | Completes instantly |
| `sleep N` | **FORBIDDEN** | Use inbox event-driven instead |
| tmux capture-pane | **FORBIDDEN** | Read report YAML instead |

### Dispatch-then-Stop Pattern

```
✅ Correct (event-driven):
  cmd_008 dispatch → inbox_write engineer → stop (await inbox wakeup)
  → engineer completes → inbox_write planner → planner wakes → process report

❌ Wrong (polling):
  cmd_008 dispatch → sleep 30 → capture-pane → check status → sleep 30 ...
```

## Timestamps

**Always use `date` command.** Never guess.
```bash
date "+%Y-%m-%d %H:%M"       # For dashboard.md
date "+%Y-%m-%dT%H:%M:%S"    # For YAML (ISO 8601)
```

## Pre-Commit Gate (CI-Aligned)

Rule:
- Run the same checks as GitHub Actions *before* committing.
- Only commit when checks are OK.
- Ask the User before any `git push`.

Minimum local checks:
```bash
# Unit tests (same as CI)
bats tests/*.bats tests/unit/*.bats

# Instruction generation must be in sync (same as CI "Build Instructions Check")
bash scripts/build_instructions.sh
git diff --exit-code .claude/rules/generated/
```
