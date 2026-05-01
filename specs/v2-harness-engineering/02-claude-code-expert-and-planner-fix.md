---
phase: 1
task_id: 02-claude-code-expert-and-planner-fix
agent: infrastructure-engineer
estimated_minutes: 10
depends_on: []
---

# Task: claude-code-expert subagent 定義作成 + planner subagent fix

## Goal
- `.claude/agents/claude-code-expert.md` を新規作成 (公式仕様マスターを再呼出可能にする、SessionStart hook で `memory/claude-code-expert.md` が auto-inject される動線を確保)
- `.claude/agents/planner.md` から `Agent` tool を削除 (subagent → subagent dispatch は公式 NG、`memory/claude-code-expert.md §2 §10.1` 参照)

## Inputs
- `memory/claude-code-expert.md` を **Read** してから着手 (公式準拠根拠の確認)
- 既存: `.claude/agents/planner.md`, `.claude/agents/design-reviewer.md`, `.claude/agents/code-reviewer.md`

## Steps

### A. `.claude/agents/claude-code-expert.md` 作成
frontmatter:
```yaml
---
name: claude-code-expert
description: Use when needing authoritative answers about Anthropic Claude Code official specs (settings.json, hooks, subagents, skills, MCP, slash commands, memory, agent teams). Triggers on questions like "what does Claude Code do for X", "official way to configure Y", "claude-code best practice", "subagent dispatch rules", "hooks event timing". The agent's knowledge is grounded in `memory/claude-code-expert.md` (loaded via SessionStart hook) — always cite official URLs.
tools: [Read, WebFetch, WebSearch, Bash, Edit, Write]
model: opus
memory: project
---
```

body には:
- 役割: Anthropic Claude Code 公式仕様の一次情報源として、本プロジェクト v2 harness 設計を判定する
- 主な情報源 (URL list、`memory/claude-code-expert.md §12` をコピー)
- 動作原則: 推測で答えない、公式 doc を必ず引用する、未確認は明記する
- triggering keyword: settings.json / hooks / subagents / skills / SKILL.md / .mcp.json / SessionStart / PreToolUse / Agent tool / memory frontmatter / Agent Teams / slash commands / `.claude/` / `claude --help` 等

### B. `.claude/agents/planner.md` から Agent tool 削除
- 現状を Read → frontmatter `tools:` 行に `Agent` または `Task` が含まれていれば削除
- body に「dispatch は subagent からは行わない、main session (殿の CLI) で実行する」旨を明記
- `memory/claude-code-expert.md §10.1` を参照する旨を body に追記

### C. design-reviewer.md / code-reviewer.md にも同様に確認
- これらの subagent も `Agent` tool を持っていれば削除 (それぞれ単独の review が責務、他 subagent dispatch は不要)

## Expected Output
- `.claude/agents/claude-code-expert.md` 新規作成 (~80-120 行)
- `.claude/agents/planner.md` 修正 (Agent tool 削除 + dispatch 注意書き追記)
- `.claude/agents/design-reviewer.md` 確認 + 必要なら修正
- `.claude/agents/code-reviewer.md` 確認 + 必要なら修正

## Verification
1. `grep -E "tools:.*\b(Agent|Task)\b" .claude/agents/*.md` でゼロ件
2. `cat .claude/agents/claude-code-expert.md | head -10` で frontmatter 表示
3. `claude-code-expert.md` の description が Triggering keyword (settings.json / hooks / subagents / skills / MCP / Agent Teams) を 5 個以上含む
4. `memory/MEMORY.md` の index に `claude-code-expert` が既に追記されている (前 dispatch で済)

## Notes
- 公式準拠 root: `memory/claude-code-expert.md`
- description の質が subagent 自動選択精度を決めるので具体的に書く
- commit はしない (planner = 親 session が一括 commit)
