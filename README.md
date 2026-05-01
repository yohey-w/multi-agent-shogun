# agent-orchestra-makoto-mizuno

Multi-agent development orchestration for Claude Code, running multiple specialized roles in parallel **tmux panes** with shared spec/memory/queue protocol.

## Concept

The runtime is a tmux session with one pane per role:

- **orchestrator** — receives requirements from the user (lord), dispatches to planner, returns final result
- **planner** — decomposes work into Haiku-grade specs (`specs/`), assigns each task to the right engineer
- **engineer1..7** — implementation panes; each can be a different specialist (frontend/backend/db/...) via subagent dispatch
- **reviewer** — design + code review before merge

Each pane is an independent Claude Code session with its own context window. Coordination happens through `queue/inbox/<role>.yaml` + `queue/outbox/<role>.yaml` (file-based message bus, watched by `scripts/inbox_watcher.sh`). Per-role memory in `memory/<role>.md` is auto-injected at session start via SessionStart hook.

## Roles

| Layer | Role | Location |
|-------|------|----------|
| Project subagent | planner | `.claude/agents/planner.md` |
| Project subagent | design-reviewer | `.claude/agents/design-reviewer.md` |
| Project subagent | code-reviewer | `.claude/agents/code-reviewer.md` |
| Project subagent | claude-code-expert | `.claude/agents/claude-code-expert.md` |
| User subagent | frontend-engineer / backend-engineer / db-engineer / chrome-extension-engineer / native-app-engineer / game-engineer / ml-engineer / qa-engineer / infrastructure-engineer | `~/.claude/agents/*.md` |

## Prerequisites

- macOS or Linux
- [tmux](https://github.com/tmux/tmux) ≥ 3.2
- [Claude Code CLI](https://docs.claude.com/en/docs/claude-code) (latest)
- (optional) `fswatch` (macOS) or `inotifywait` (Linux) for inbox watcher
- (optional) `gitleaks` + `pre-commit` for secret scanning

## Getting Started

### 1. Clone and review settings

```bash
git clone <this-repo> agent-orchestra
cd agent-orchestra
```

Skim `CLAUDE.md` (project instructions, auto-loaded by Claude) and `.claude/settings.json` (hooks + permissions). Adjust `config/settings.yaml` if it exists.

### 2. Launch the multi-pane session

```bash
./start_session.sh           # default — orchestrator + planner + engineer1..7 + reviewer
./start_session.sh -k        # all panes Opus (decisive mode)
./start_session.sh -c codex  # use Codex CLI instead of Claude where applicable
./start_session.sh -h        # full help
```

This boots a tmux session named `shogun` (orchestrator pane) plus a `multiagent` session for the rest.

### 3. Attach to the orchestrator

```bash
tmux attach -t shogun        # or use the css alias if installed
```

You are now talking to the orchestrator. Give it a high-level requirement; it will:

1. Forward to planner via `queue/inbox/planner.yaml`
2. Planner writes specs under `specs/<date>-<topic>/`
3. Planner returns a dispatch instruction sheet
4. The orchestrator (= you in main session) invokes the engineer subagent via `Agent` tool
5. Engineer implements, reviewer reviews, orchestrator reports back

### 4. Useful skills (slash commands)

Once running, these are available in any pane:

| Command | Purpose |
|---------|---------|
| `/spec-haiku <topic>` | Generate Haiku-grade specs from a feature request |
| `/dispatch-engineer <task-id>` | Dispatch a spec task to its assigned engineer |
| `/review-pr` | Run design + code reviewer chain on the current branch |
| `/dashboard` | Regenerate `dashboard.md` with current status |
| `/archive-spec <topic>` | Move completed specs to `specs/archive/YYYY-MM/` |
| `/init-project <name>` | Scaffold a new project under `projects/` |
| `/memory-curate <agent>` | Trim an agent's memory file to ≤ 200 lines |

### 5. Hooks (run automatically)

| Event | Hook | What it does |
|-------|------|--------------|
| SessionStart | `session_start_inject_memory.sh` | Injects per-role `memory/*.md` into the new session |
| PreToolUse · Bash | `guard_rm.sh` | Blocks dangerous `rm -rf` patterns (D001–D002 of `CLAUDE.md`) |
| PreToolUse · Edit/Write | `guard_outside_project.sh` | Blocks edits outside the project working tree |
| SubagentStop | `post_engineer.sh` | Suggests memory curation when a memory file exceeds 200 lines |
| UserPromptSubmit | `inject_dashboard.sh` | Injects current dashboard + queue status into the prompt context |

### 6. Stop the session

```bash
tmux kill-session -t shogun
tmux kill-session -t multiagent
```

(or run `./start_session.sh --shutdown` if available — see `start_session.sh -h`)

## Project Layout

```
.claude/
├── agents/   # planner / reviewers / claude-code-expert (project subagents)
├── hooks/    # SessionStart / PreToolUse / SubagentStop / UserPromptSubmit
├── rules/    # per-role manuals (auto-loaded as Claude Code rules)
├── skills/   # slash commands (SKILL.md format)
└── settings.json
.github/workflows/secret-scan.yml
config/                   # ntfy auth sample, runtime configs
memory/                   # per-role persistent context (SessionStart-injected)
queue/                    # inbox/outbox YAML message bus
scripts/                  # inbox watcher, agent status, switch CLI, etc.
specs/                    # Haiku-grade task specifications
projects/                 # actual projects (gitignored)
start_session.sh          # tmux launcher
CLAUDE.md                 # project instructions (auto-loaded)
```

See `CLAUDE.md` for the full architecture and `memory/claude-code-expert.md` for the official Claude Code spec reference distilled for this project.

## Secret Scan (pre-commit / CI)

This repo uses [gitleaks](https://github.com/gitleaks/gitleaks) to prevent accidental secret commits.

### One-time setup (macOS)

```bash
# Install tools (choose one)
brew install gitleaks pre-commit
# or: pip3 install --user pre-commit

# Install hooks into .git/hooks/
pre-commit install --hook-type pre-commit
pre-commit install --hook-type pre-push
```

### Verify

```bash
# Full repo scan (no git history required)
gitleaks detect --source . --config .gitleaks.toml --verbose --no-git
# Expected: "no leaks found"
```

### False positives

Allowed paths are declared in `.gitleaks.toml` (specs/docs markdown, test fixtures, manifest.json).
To suppress a new false positive, add an `[[allowlist]]` entry in `.gitleaks.toml` — never commit a real secret.

### CI

`.github/workflows/secret-scan.yml` runs gitleaks on every push and pull request.

## License

MIT — see [LICENSE](LICENSE).

## Status

Active development (v2 migration in progress, see `specs/`).

---

[日本語](README_ja.md)
