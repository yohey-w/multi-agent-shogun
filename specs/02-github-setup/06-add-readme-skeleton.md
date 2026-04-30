---
phase: 2
task_id: 06-add-readme-skeleton
agent: planner (Haiku 可、内容は本仕様 + overview 参照)
estimated_minutes: 10
depends_on: [03-add-license-mit]
---

# Task: README.md (英語) と README_ja.md (日本語) 骨格作成

## Goal
OSS 公開用の README を 2 言語で書く。詳細は後続の docs/ で書き込むので、トップ README は要約 + Quick Start。

## Inputs
- `specs/00-overview.md` (v2 アーキテクチャの全体絵)

## Steps
1. リポ root に `README.md` を作成 (英語):

```markdown
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
```

2. `README_ja.md` を作成 (日本語):

```markdown
# agent-orchestra-makoto-mizuno

Claude Code 上で動く、subagent 派遣 + 役割別 memory に基づいたマルチエージェント開発オーケストレーション。

## コンセプト

planner agent が作業を仕様書に分解し、専門 engineer subagent (frontend / backend / db / chrome-extension / native-app / game / ml / qa / infrastructure) に派遣する。reviewer (design + code) が commit 前に検証する。各 agent はプロジェクトごとに `memory/<agent>.md` を読んで蓄積された知識を活用する。

## 役割

| レイヤ | 役割 | 場所 |
|--------|------|------|
| プロジェクト | planner | `.claude/agents/planner.md` |
| プロジェクト | design-reviewer | `.claude/agents/design-reviewer.md` |
| プロジェクト | code-reviewer | `.claude/agents/code-reviewer.md` |
| ユーザ | frontend-engineer / backend-engineer / db-engineer / chrome-extension-engineer / native-app-engineer / game-engineer / ml-engineer / qa-engineer / infrastructure-engineer | `~/.claude/agents/*.md` |

## Quick Start

(後日記載 — Phase 8 完了後 `docs/getting-started.md` 参照)

## ライセンス

MIT — [LICENSE](LICENSE) 参照。

## ステータス

開発中 (v2 移行中、`specs/` 参照)。

---

[English](README.md)
```

3. commit:
```bash
git add README.md README_ja.md
git commit -m "docs: add bilingual README skeleton (en/ja) for OSS publication"
```

## Verification
- README に英語 / 日本語両方リンクされている
- `head -1 README.md` で `# agent-orchestra-makoto-mizuno`

## Notes
- Quick Start 詳細は v2 完成後 docs/ に書く
- shogun-readme-sync スキルが「英語/日本語同期」を担保するので将来の更新も漏れない
