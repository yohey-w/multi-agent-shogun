---
phase: 1
task_id: 03-build-skills
agent: infrastructure-engineer
estimated_minutes: 25
depends_on: []
---

# Task: 8 skills を `.claude/skills/<name>/SKILL.md` で構築

## Goal
殿の頻用 op を Claude Code 公式 skill 機構で slash command 化。`memory/claude-code-expert.md §4 §5` 参照。

## Inputs
- `memory/claude-code-expert.md` を **Read** (公式 frontmatter schema 確認)
- `.claude/agents/*.md` (既存 subagent 定義、skill から呼出する場合に必要)
- `instructions/`, `specs/`, `queue/`, `memory/` の現構成 (skill 内で path 参照)

## Steps

### Skill 一覧 (`.claude/skills/<name>/SKILL.md` 各々作成)

| skill | frontmatter | 主な動作 |
|-------|-------------|----------|
| `dispatch-engineer` | `user-invocable: true`, `argument-hint: "<task-id>"` | spec の task_id を引数に取り、`agent:` フィールドで指定された engineer を Agent tool で dispatch |
| `spec-haiku` | `user-invocable: true`, `argument-hint: "<topic>"` | 殿要件 → `specs/<date>-<topic>/` 配下に Haiku 粒度 spec 群を生成 |
| `review-pr` | `user-invocable: true`, `context: fork`, `agent: code-reviewer` | code-reviewer + design-reviewer を chain 実行 |
| `archive-spec` | `user-invocable: true`, `argument-hint: "<topic-or-date>"` | 完了 spec を `specs/archive/YYYY-MM/` へ移動 |
| `init-project` | `user-invocable: true`, `argument-hint: "<name>"` | `projects/<name>/` 配下に最小プロジェクト雛形 (.git init, README.md, CLAUDE.md, .gitignore) |
| `update-memory` | `disable-model-invocation: true` | SubagentStop hook から呼出、対象 agent の memory file を 200 行以内に curate |
| `dashboard` | `user-invocable: true` | `dashboard.md` を queue/inbox 状況 + アクティブ specs から再生成 |
| `memory-curate` | `user-invocable: true`, `argument-hint: "<agent-name>"` | 指定 agent の memory を整理 (古い学びを `memory/archive/` 移動 + 200 行以内化) |

### 各 SKILL.md 構造 (公式準拠 frontmatter)

```yaml
---
name: dispatch-engineer
description: Dispatch a spec task to its assigned engineer subagent. Use when the user types `/dispatch <task-id>` or asks to "dispatch task X to engineer", "send task to backend engineer", etc. Reads the spec's `agent:` frontmatter field and invokes the appropriate engineer via Agent tool.
argument-hint: <task-id>
allowed-tools: [Read, Bash, Agent, Edit]
user-invocable: true
---

# /dispatch-engineer

## Purpose
...

## Usage
`/dispatch-engineer <task-id>`

## Behavior
1. ...
2. ...
```

### 実装方針

- 各 skill の SKILL.md は **150-300 行程度** で、frontmatter + Markdown body
- skill body は `${ARGUMENTS}` `$1` 等で殿入力を受け、bash exec で具体動作を起こす
- 実行系 skill (dispatch-engineer / archive-spec / init-project) は inline `` !`bash command` `` で動的 context 注入を活用してよい
- `update-memory` は `disable-model-invocation: true` (Claude が勝手に呼ばないようにし、hook 専用に)
- `review-pr` は `context: fork` で git worktree を分けて review (公式 §6 推奨)

### 実装作業

8 skill それぞれにディレクトリ + SKILL.md を作成:
```
.claude/skills/
├── dispatch-engineer/SKILL.md
├── spec-haiku/SKILL.md
├── review-pr/SKILL.md
├── archive-spec/SKILL.md
├── init-project/SKILL.md
├── update-memory/SKILL.md
├── dashboard/SKILL.md
└── memory-curate/SKILL.md
```

## Expected Output
- 上記 8 skill 配下に valid な SKILL.md
- frontmatter は `memory/claude-code-expert.md §4 §5` の field 順守
- 各 SKILL.md は **trigger description が具体的** (殿が普通に話して invoke される単語を含む)

## Verification
1. `find .claude/skills -name SKILL.md | wc -l` → 8
2. 各 SKILL.md を Read して frontmatter validate (name / description / `---` で囲む / valid YAML)
3. `description` field が triggering keyword 5 個以上 ("dispatch", "engineer", "send", "review", etc.)
4. `bash -n` の対象になる shell snippet があれば構文チェック

## Notes
- skill の body は具体的に書く (Anthropic 公式 skill ガイドライン参照、`memory/claude-code-expert.md §4` の "rigid" vs "flexible" 区別あり)
- `disable-model-invocation: true` の skill (update-memory) は user prompt からは呼ばれず、hook 経由のみ
- `review-pr` の `context: fork` 指定で worktree 隔離 (public 公式機構)
- skill 全 8 個の作成は 1 agent で sequential 実行で OK (~25 分目安)
- commit はしない (planner = 親 session が一括 commit)
