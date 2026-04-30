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
