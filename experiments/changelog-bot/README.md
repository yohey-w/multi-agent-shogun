# ChangelogBot

AI-powered CHANGELOG generation from raw git history — **no Conventional Commits required**.

Feed it any git log, PR body, or Issue body. An LLM rewrites it into user-facing
[Keep a Changelog](https://keepachangelog.com/) sections and suggests a SemVer bump.

> Status: **MVP** (experiments/changelog-bot). Ships as a CLI and a GitHub Action.
> BYOK — you supply your Anthropic or OpenAI key.

## Why

- `release-please` / `conventional-changelog` require strict commit conventions.
- `git-cliff` is template-only — no semantic rewrite.
- Most real repos don't enforce commit conventions. ChangelogBot summarises what
  actually happened from free-form commit messages + PR/Issue bodies.

## Install

```bash
# One-shot
npx changelog-bot --from v1.2.0 --to HEAD

# Or install globally
npm install -g changelog-bot
changelog-bot --help
```

Requires Node.js ≥ 20 and `git` on `PATH`.

## CLI usage

```
changelog-bot [options]

  --from <ref>       Starting tag/commit (default: latest tag).
  --to <ref>         Ending ref (default: HEAD).
  --output <file>    Write to file instead of stdout.
  --provider <p>     anthropic | openai (default: auto-detect from env).
  --model <name>     Model name (default: claude-haiku-4-5 / gpt-4o-mini).
  --bump             Print only the SemVer bump (major/minor/patch).
  --dry-run          Skip LLM; print raw git log collected.
  --repo <owner/r>   GitHub repo for PR/Issue fetch (default: origin remote).
  --github-token     Token for PR/Issue body fetch (default: $GITHUB_TOKEN).
  -h, --help         Show help.
```

### Example

```bash
export ANTHROPIC_API_KEY=sk-ant-...
changelog-bot --from v0.2.0 --to HEAD
```

Output is Keep-a-Changelog markdown plus a suggested bump line — see the CLI
itself for the canonical format (this README does not hard-code sample output
to avoid drift).

## BYOK (API keys)

Set **one** of these before invoking the CLI or pass them as Action inputs:

| Env var             | Purpose                                   |
| ------------------- | ----------------------------------------- |
| `ANTHROPIC_API_KEY` | Use Claude (default: `claude-haiku-4-5`). |
| `OPENAI_API_KEY`    | Use GPT (default: `gpt-4o-mini`).         |
| `GITHUB_TOKEN`      | Optional; unlocks PR/Issue body fetch.    |

No keys are transmitted anywhere except to the chosen provider. There is no
hosted backend.

## GitHub Action

```yaml
# .github/workflows/changelog.yml
name: Changelog
on:
  pull_request:
    types: [opened, synchronize, reopened]

permissions:
  contents: read
  pull-requests: write

jobs:
  changelog:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # needed so the Action can see tags
      - uses: makotonos/changelog-bot@v0
        with:
          anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
          mode: pr-comment
```

### Modes

| `mode`          | Behaviour                                                       |
| --------------- | --------------------------------------------------------------- |
| `pr-comment`    | Diff PR base ↔ HEAD → post CHANGELOG as a PR comment.           |
| `release-notes` | On tag push → inject generated notes into the GitHub Release.   |
| `file-commit`   | Update `CHANGELOG.md` on the branch and commit as `github-actions[bot]`. |

### Action inputs

| Input               | Required | Default              | Description                                   |
| ------------------- | -------- | -------------------- | --------------------------------------------- |
| `anthropic-api-key` | one of   | —                    | Anthropic key (BYOK).                         |
| `openai-api-key`    | one of   | —                    | OpenAI key (BYOK).                            |
| `from`              | no       | latest tag           | Starting ref.                                 |
| `to`                | no       | `HEAD`               | Ending ref.                                   |
| `mode`              | no       | `pr-comment`         | `pr-comment` / `release-notes` / `file-commit`. |
| `provider`          | no       | auto                 | `anthropic` or `openai`.                      |
| `model`             | no       | provider-default     | Override model name.                          |
| `output-file`       | no       | `CHANGELOG.md`       | Target file for `file-commit` mode.           |
| `github-token`      | no       | `${{ github.token }}`| For PR/Issue fetch and PR comments.           |

At least one of `anthropic-api-key` / `openai-api-key` must be supplied.

### Outputs

| Output      | Description                                  |
| ----------- | -------------------------------------------- |
| `changelog` | Generated CHANGELOG markdown section.        |
| `bump`      | Suggested SemVer bump (`major`/`minor`/`patch`). |

## How it works

1. Collect commits between `from` and `to` via `simple-git`.
2. If `GITHUB_TOKEN` is available, enrich commits with PR + Issue bodies via
   `@octokit/graphql`.
3. Send the bundle to the LLM with a prompt that forbids fabrication and pins
   output to a zod-validated schema.
4. Render to Keep-a-Changelog markdown; emit SemVer bump heuristic.

## Privacy & cost

- Commit messages, PR bodies, and issue bodies are sent to the chosen LLM
  provider. Redact secrets before running on private repos — see
  `--exclude-labels` (roadmap).
- Default models (`claude-haiku-4-5` / `gpt-4o-mini`) are chosen for low cost.
  A typical monthly release on a 200-commit repo costs well under $0.10.

## Roadmap

- `--exclude-labels` to drop PRs by label (e.g. `internal`, `security`).
- Provider extension point for local models (Ollama).
- `--style` templates (terse / marketing / technical).
- Publish to GitHub Marketplace after Phase 2 QC.

## License

MIT — see `LICENSE`.
