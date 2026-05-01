---
phase: 1
task_id: 05-migrate-instructions-to-rules
agent: infrastructure-engineer
estimated_minutes: 15
depends_on: []
---

# Task: `instructions/<role>.md` → `.claude/rules/<role>.md` (公式 path-scoped rules)

## Goal
v2 で `instructions/` ディレクトリに置いた role 別手順書は公式機構ではない。
`.claude/rules/<role>.md` に移行し frontmatter `paths:` で role-scoped にする (`memory/claude-code-expert.md §7.4 §10.2`)。

## Inputs
- `memory/claude-code-expert.md` (公式 `.claude/rules/` 仕様)
- 既存: `instructions/orchestrator.md`, `instructions/planner.md`, `instructions/reviewer.md`, `instructions/engineer.md`,
  `instructions/roles/*.md`, `instructions/common/*.md`, `instructions/cli_specific/*.md`

## Steps

### A. 主要 role file 4 つを `.claude/rules/` に移動 + frontmatter 付与

| 元 path | 新 path | paths frontmatter |
|---|---|---|
| `instructions/orchestrator.md` | `.claude/rules/orchestrator.md` | (paths 無し = 常時 load) |
| `instructions/planner.md` | `.claude/rules/planner.md` | (paths 無し) |
| `instructions/reviewer.md` | `.claude/rules/reviewer.md` | (paths 無し) |
| `instructions/engineer.md` | `.claude/rules/engineer.md` | (paths 無し) |

frontmatter 例:
```yaml
---
description: Engineer pane の手順書 (engineer1..7 共通)。spec を実装する際に参照。
---
```

注: `paths:` を付けると該当 file を Claude が触ったときだけ load される。各 role pane では常時 load したいので **paths 無しが適切**。代わりに pane 起動時に `--add-dir` で `.claude/rules/<role>.md` を session prompt に明示注入するか、`instructions/<role>.md` を CLAUDE.md から `@import` する。

### B. `instructions/common/`, `instructions/cli_specific/`, `instructions/roles/` の扱い

**選択 1**: そのまま `.claude/rules/` 配下に sub-directory として移動:
```
.claude/rules/
├── orchestrator.md
├── planner.md
├── reviewer.md
├── engineer.md
├── common/
│   ├── forbidden_actions.md
│   ├── protocol.md
│   └── task_flow.md
├── roles/
│   ├── orchestrator_role.md
│   ├── planner_role.md
│   ├── reviewer_role.md
│   └── engineer_role.md
└── cli_specific/
    ├── claude_tools.md
    ├── codex_tools.md
    ├── copilot_tools.md
    └── kimi_tools.md
```

**選択 2** (推奨): common と roles は role 内 `@import` に集約、cli_specific はそのまま rules 配下:
- 各 role file の冒頭に `@./common/forbidden_actions.md @./common/protocol.md @./common/task_flow.md` を入れる
- role-specific 詳細は `roles/<role>_role.md` を `@./roles/<role>_role.md` で import

### C. CLAUDE.md の §11 "個別 role 詳細" を path 更新

旧 `instructions/<role>.md` 参照を `.claude/rules/<role>.md` に書き換える。

### D. start_session.sh の path 参照更新

`start_session.sh` 内の `instructions/orchestrator.md` 等の参照を `.claude/rules/orchestrator.md` に書き換え (各 pane 起動時に該当 rule file を参照する設計)。

### E. instructions/ ディレクトリは削除 (空になったら)

`git rm -r instructions/` (中身が `.claude/rules/` に全部移った場合)。

### F. scripts/build_instructions.sh の output path 更新

`build_instructions.sh` は CLI-specific generated files を作る script。output path を `instructions/generated/` → `.claude/rules/generated/` (or 削除) に書き換え、または不要なら `build_instructions.sh` 自体削除。

## Expected Output
- `.claude/rules/` 配下に role 別 + common + cli_specific が移行済
- 各 file の frontmatter に valid な YAML (description のみ、paths 無し or 慎重に)
- CLAUDE.md / start_session.sh / 関連 script 内の path 参照が新 path に統一
- `instructions/` ディレクトリ削除済

## Verification
1. `find .claude/rules -type f -name "*.md" | wc -l` → 旧 instructions/ と同数 (~15)
2. `grep -rE "instructions/(orchestrator|planner|reviewer|engineer)" .claude/ scripts/ start_session.sh CLAUDE.md` ゼロ件
3. 各 .claude/rules/*.md の frontmatter parsable (YAML valid)
4. `bash -n start_session.sh` 構文 OK

## Notes
- 公式準拠 root: `memory/claude-code-expert.md §7.4 §10.2`
- `paths:` 付けの可否は慎重に (常時 load 必要なら無し、特定 file 触った時だけなら付ける)
- generated/ は build_instructions.sh の output で再生成可能なので一旦削除でも OK
- commit はしない (planner = 親 session が一括 commit)
