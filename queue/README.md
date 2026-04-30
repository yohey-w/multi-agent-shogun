# queue/ — Inter-role Message Queue

This directory holds the message queues used by the agent-orchestra v2
inbox/outbox protocol. Roles (orchestrator, planner, reviewer, engineer1-7)
exchange messages by appending to YAML files here, watched by
`scripts/inbox_watcher.sh`.

## Structure

```
queue/
├── inbox/        <role>.yaml — incoming messages addressed to <role>
├── outbox/       <role>.yaml — outgoing messages sent by <role>
├── tasks/        per-role task state files (created at runtime)
├── reports/      per-role completion reports (created at runtime)
└── metrics/      per-role rate / cost metrics (created at runtime)
```

## Roles

| Role          | Responsibility                                      |
|---------------|-----------------------------------------------------|
| orchestrator  | Top-level dispatcher; relays user requests          |
| planner       | Spec author; breaks work into Haiku-grade tasks     |
| reviewer      | Design + code review (pre-implementation + pre-merge) |
| engineer1..7  | Implementation workers (parallelizable)             |

## Message Format

Each `inbox/<role>.yaml` and `outbox/<role>.yaml` is a YAML document of the
form:

```yaml
messages:
  - id: msg_<timestamp>_<n>
    from: <sender role>
    to: <receiver role>
    timestamp: 2026-04-30T12:34:56+09:00
    type: task | report | question | nudge
    subject: short string
    body: |
      free-form markdown body
    refs:                 # optional
      - specs/2026-04-30-foo/01-task.md
    status: pending | seen | done
```

Writers append entries with `scripts/inbox_write.sh`; readers consume them via
`scripts/inbox_watcher.sh`, which signals the target tmux pane.

## Protocol Outline

1. **Dispatch**: orchestrator (or planner) writes a `type: task` entry to the
   target role's inbox referencing one or more spec files in `specs/`.
2. **Acknowledge**: receiver appends `type: report` with `status: done` to its
   outbox once the task is complete.
3. **Review handoff**: planner forwards completed engineer reports to
   reviewer's inbox for design / code review.
4. **Escalate**: any role may write `type: question` to orchestrator's inbox
   for user-level decisions.

The watcher process (`scripts/inbox_watcher.sh`) polls each `inbox/<role>.yaml`
and nudges the corresponding tmux pane when a new pending message appears.

## Resetting

`start_session.sh -c` (clean mode) truncates all inbox / outbox files back to
`messages: []` and resets `tasks/`, `reports/`, `metrics/`. Without `-c` the
queue state is preserved across sessions.
