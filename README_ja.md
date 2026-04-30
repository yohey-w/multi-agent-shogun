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
