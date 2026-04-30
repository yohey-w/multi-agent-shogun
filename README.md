# agent-orchestra-makoto-mizuno

Multi-agent development orchestration for Claude Code, built on subagent dispatch + per-role memory.

## Concept

A planner agent decomposes work into specifications and dispatches specialized engineer subagents (frontend / backend / db / chrome-extension / native-app / game / ml / qa / infrastructure). Reviewers (design + code) validate before commit. Each agent reads its own `memory/<agent>.md` for accumulated knowledge per project.

## Roles

| Layer | Role | Location |
|-------|------|----------|
| Project | planner | `.claude/agents/planner.md` |
| Project | design-reviewer | `.claude/agents/design-reviewer.md` |
| Project | code-reviewer | `.claude/agents/code-reviewer.md` |
| User | frontend-engineer / backend-engineer / db-engineer / chrome-extension-engineer / native-app-engineer / game-engineer / ml-engineer / qa-engineer / infrastructure-engineer | `~/.claude/agents/*.md` |

## Quick Start

(coming soon — see `docs/getting-started.md` after Phase 8)

## License

MIT — see [LICENSE](LICENSE).

## Status

Active development (v2 migration in progress, see `specs/`).

---

[日本語](README_ja.md)
