---
phase: harness-engineering
task_id: 01-research-claude-code-official
agent: claude-code-guide (Anthropic Claude Code 公式仕様マスター)
estimated_minutes: 30
depends_on: []
---

# Task: Claude Code 公式推奨のディレクトリ構成 / harness 構成を網羅的に調査

## Goal
Anthropic 公式の Claude Code (CLI / Agent SDK / Subagent / Skills / Hooks / MCP / Settings)
の **最新かつ正式な** 推奨構成を、公式情報源 (docs.claude.com, github.com/anthropics/claude-code,
Anthropic engineering blog, リリースノート等) に基づいて整理し、本プロジェクト v2 の
harness engineering 設計の土台にする。

その知見を `memory/claude-code-expert.md` に**永続化**して、以後 claude-code-expert agent が
召喚されるたびに公式準拠の判断ができるようにする。

## Inputs
- 既存 v2 構造: `.claude/agents/`, `.claude/hooks/`, `.claude/skills/`,
  `.claude/settings.json`, `instructions/`, `specs/`, `memory/`,
  `queue/`, `scripts/`, `start_session.sh`, `CLAUDE.md`
- 殿の方針: tmux multi-pane で複数 role を独立 Claude session 化 + queue/inbox 経由連携 +
  各 pane が Agent tool で subagent を一時 dispatch

## Steps

### 1. 公式情報源を網羅
以下のドキュメント / repo を WebFetch / WebSearch で読み込み、最新版の公式推奨を確認:

- **Claude Code 本体**: <https://docs.claude.com/en/docs/claude-code/overview>
  - Settings (`settings.json` schema、project / user / local の階層)
  - Hooks (PreToolUse / PostToolUse / SessionStart / Stop / UserPromptSubmit 等)
  - Permissions (allow / deny / ask)
  - Slash Commands (`.claude/commands/`)
  - IDE integrations
- **Subagents**: <https://docs.claude.com/en/docs/claude-code/sub-agents>
  - `.claude/agents/<name>.md` フォーマット (frontmatter: name, description, tools, model)
  - Project-level vs User-level の優先順
  - description ベースの自動選択
  - Agent tool dispatch の制限 (nested dispatch の可否)
- **Skills**: <https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview>
  - SKILL.md フォーマット
  - skill discovery (どこに置けば検出されるか)
  - Skill creator の使い方
- **Hooks**: <https://docs.claude.com/en/docs/claude-code/hooks>
  - 各 hook event の発火タイミング
  - hook script の入出力 (env var / stdin / exit code)
  - blocking / non-blocking
- **MCP**: <https://docs.claude.com/en/docs/claude-code/mcp>
  - `.mcp.json` の location 推奨 (project root / user / project-local)
  - MCP server config の書き方
- **Memory / CLAUDE.md**: 公式の memory システム (auto-load CLAUDE.md, project / user)
  vs プロジェクト固有 memory ディレクトリの区別
- **Agent SDK**: <https://docs.claude.com/en/docs/agent-sdk> の subagent 推奨構成
- **GitHub repo**: <https://github.com/anthropics/claude-code> の README、examples、issues
- **Best practices**: Anthropic engineering blog の Claude Code 関連記事

### 2. 各構成要素の "公式推奨 vs v2 現状" を表で比較
以下の項目について、公式が**何を**どこに置くべきと言っているかを確認し、
v2 現状とのズレを `memory/claude-code-expert.md` に記録:

| 項目 | 公式推奨配置 | 公式 file 名規約 | v2 現状 | 一致 / ズレ | 修正案 |
|---|---|---|---|---|---|
| Project agent 定義 | `.claude/agents/<name>.md` | YAML frontmatter | `.claude/agents/{planner,design-reviewer,code-reviewer}.md` | ? | ? |
| Project hooks | `.claude/hooks/` | shell script (実行可) | `.claude/hooks/session_start_inject_memory.sh` | ? | ? |
| Project skills | `.claude/skills/<name>/SKILL.md` | SKILL.md + 補助 file | (空) | ? | ? |
| Project settings | `.claude/settings.json` | JSON schema 準拠 | あり (hooks / permissions のみ) | ? | ? |
| Slash commands | `.claude/commands/<name>.md` | Markdown | (削除済) | ? | ? |
| Project-level CLAUDE.md | repo root / 子ディレクトリ | Markdown (auto-load) | repo root にあり | ? | ? |
| MCP config | `.mcp.json` (repo root) | JSON | repo root に `.mcp.json` (playwright-cdp) | ? | ? |
| Custom memory | プロジェクト独自 | (公式規約は無い? CLAUDE.md だけが auto-load?) | `memory/` に role 別 file + SessionStart hook で inject | ? | ? |

### 3. nested subagent dispatch の最新仕様確認
- subagent (Agent tool で dispatch) 自身が**さらに** Agent tool を呼べるか?
- 公式は何と言っているか? (Phase 8 で動かないと判明したが、これは正しい仕様の理解か?)
- 動かない場合、公式が推奨する代替パターンは?

### 4. v2 ディレクトリ構成の最適化提案
公式仕様と v2 現状の比較から、以下を**具体的な diff 案**として提案:
- 既存の何を**移動**すべきか (例: `instructions/` を `.claude/agents/<role>.md` 化すべき?)
- **新設**すべき項目は何か (例: `.claude/commands/<slash-cmd>.md` で planner 起動コマンドを作るべき?)
- **削除 / 統合**すべき重複は何か
- 公式推奨の **hooks** で v2 が活用していない event は? (例: `Stop`, `UserPromptSubmit`,
  `PreToolUse` の使い道)
- **skills** (`.claude/skills/`) で v2 に必要なものは何か (例: `dispatch-engineer`,
  `archive-spec`, `update-memory` 等の自動化)

### 5. memory/claude-code-expert.md に永続化
以下のフォーマットで `memory/claude-code-expert.md` に書き込み:

```markdown
---
name: claude-code-expert
description: Anthropic Claude Code 公式仕様マスター。settings.json / hooks / subagents /
  skills / MCP / memory の正規構造と挙動を熟知し、本プロジェクトの harness 設計を公式準拠で判断する。
type: project
---

# Claude Code 公式準拠 ナレッジベース

最終更新: <YYYY-MM-DD> / source: <URL list>

## 1. Settings (`settings.json`)
- 階層: ...
- 主要 key: ...
- v2 採用 / 採用検討: ...

## 2. Hooks (`.claude/hooks/`)
- 公式 event 一覧と発火タイミング: ...
- v2 で使うべき event と用途: ...

## 3. Subagents (`.claude/agents/<name>.md`)
- frontmatter schema: ...
- nested dispatch 仕様 (Phase 8 検証結果含む): ...
- v2 現状の妥当性判定: ...

## 4. Skills (`.claude/skills/<name>/SKILL.md`)
- discovery / 起動条件: ...
- v2 で必要な skill 候補: ...

## 5. Slash Commands (`.claude/commands/<name>.md`)
- v2 で作るべき command: ...

## 6. MCP (`.mcp.json`)
- project root vs user-level: ...

## 7. CLAUDE.md auto-load
- どこに置けば auto-load されるか: ...
- 子ディレクトリ CLAUDE.md の階層 merge: ...

## 8. 公式推奨ディレクトリ構成 (canonical)
```
.
├── .claude/
│   ├── agents/
│   ├── commands/
│   ├── hooks/
│   ├── settings.json
│   ├── settings.local.json (gitignored)
│   └── skills/
├── .mcp.json
└── CLAUDE.md
```

## 9. v2 と公式の diff (修正案)
- ...

## 10. 参考 URL
- ...
```

## Expected Output
1. `memory/claude-code-expert.md` が created (上記フォーマット、URL ベースの一次情報で裏付けあり)
2. v2 ディレクトリ構成の **修正案 diff** が報告される (具体的にどの file をどこに移すか)
3. 公式が推奨する **追加すべき hook / skill / slash command** リストが報告される
4. nested subagent dispatch の正式回答 (公式 doc 参照付き)

## Verification
- `cat memory/claude-code-expert.md` で内容確認可能
- 修正案 diff が具体的 (file path / 内容まで言及) であること
- 引用 URL がすべて公式ソース (docs.claude.com, github.com/anthropics, anthropic.com)

## Notes
- WebFetch は積極的に使う、検索は WebSearch で公式 URL を見つけてから fetch
- 殿の方針 (tmux multi-pane + 各 pane が独立 Claude session) を否定する方向の公式推奨が
  あればそれも明確に報告 (殿に再判断を仰ぐ材料になる)
- 公式 doc が見つからない / バージョンが古い項目は「未確認」と明記、推測で書かない
