# v2 Harness Engineering — 全体仕様

- **Author**: planner (将軍)
- **Date**: 2026-04-30
- **Source 知見**: `memory/claude-code-expert.md` (Anthropic 公式仕様マスター調査結果)
- **Status**: Active

## 北極星

Claude Code 公式仕様 に準拠した v2 harness を整備する。具体的には:

1. **公式 hooks 強化** (PreToolUse / SubagentStop / UserPromptSubmit) で安全性 + 自動化
2. **公式 skills** (`.claude/skills/<name>/SKILL.md`) で殿の頻用 op を slash command 化
3. **subagent definitions の公式準拠** (frontmatter `memory: project`、Agent tool 抑制)
4. **instructions/ → `.claude/rules/`** 移行 (path-scoped、公式機構)
5. **claude-code-expert agent** を project-level に永続化 (公式仕様の一次情報源として再呼出可能)

## 主要発見 (`memory/claude-code-expert.md` より)

- **subagent → subagent dispatch は公式 NG** (3 箇所明記)
- v2 既存 `instructions/<role>.md` は公式機構なし、`.claude/rules/` か `@import` 推奨
- v2 既存 `memory/MEMORY.md` は auto-memory (`~/.claude/projects/.../memory/MEMORY.md`) と名前空間衝突
- 旧 `Task` tool は v2.1.63 で **`Agent` tool に rename**
- **Agent Teams** (experimental) が殿の tmux multi-pane の公式版

## 短期 vs 中期方針

- **短期 (本日)**: planner nested dispatch を即時修正 + skills/hooks 整備 + 構造 cleanup
- **中期 (将来)**: Agent Teams 移行検討 (殿の方針次第、experimental flag 必要)

## Tasks (Haiku 粒度)

| Phase | Task | spec | Agent | 並列 |
|-------|------|------|-------|------|
| 1 | claude-code-expert subagent 定義作成 + planner subagent から Agent tool 抑制 | 02-claude-code-expert-and-planner-fix.md | infrastructure-engineer | A |
| 1 | 8 skills 構築 (dispatch-engineer / spec-haiku / review-pr / archive-spec / init-project / update-memory / dashboard / memory-curate) | 03-build-skills.md | infrastructure-engineer | B |
| 1 | 4 hooks 構築 (guard_rm / guard_outside_project / post_engineer / inject_dashboard) + settings.json hooks block 更新 | 04-build-hooks.md | infrastructure-engineer | C |
| 1 | instructions/ → `.claude/rules/` 移行 (path-scoped、frontmatter 付き) | 05-migrate-instructions-to-rules.md | infrastructure-engineer | D |
| 2 | subagent frontmatter `memory: project` 追加 + `memory/` → 名前空間 conflict 回避策 | 06-memory-frontmatter-and-rename.md | infrastructure-engineer | (W2) |
| 2 | CLAUDE.md 最終 update (公式準拠の最終状態) | 07-update-claude-md.md | infrastructure-engineer | (W2) |

## 完了基準

1. `.claude/agents/claude-code-expert.md` が再呼出可能 (description が Anthropic Claude Code spec を triggering keyword 含む)
2. `.claude/agents/planner.md` の `tools` から `Agent` を削除済み (公式仕様準拠)
3. `.claude/skills/` 配下に 8 skills が存在し、それぞれ valid な SKILL.md を持つ
4. `.claude/hooks/` 配下に 4 hooks (実行可能 shell script) が存在し、`.claude/settings.json` で配線済
5. `.claude/rules/` 配下に role 別 path-scoped rule が存在 (旧 instructions/ から migrate)
6. `memory/` の名前衝突回避が完了 (rename or `claudeMdExcludes`)
7. CLAUDE.md が上記すべてを反映、tmux multi-pane の運用方針も明記

## Notes

- 各 spec は `memory/claude-code-expert.md` を**必ず Read**してから着手 (公式準拠の根拠を確認)
- Phase 1 (W1) の 4 task (A-D) は **完全並列実行可** (依存なし)
- Phase 2 (W2) の 2 task は W1 完了後 (CLAUDE.md update は最後)
