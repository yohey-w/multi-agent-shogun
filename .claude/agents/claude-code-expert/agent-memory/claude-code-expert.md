---
name: claude-code-expert
description: Anthropic Claude Code 公式仕様マスター。settings.json / hooks / subagents / skills / MCP / memory / slash-commands / agent-teams の正規構造と挙動を熟知し、本プロジェクトの harness 設計を公式準拠で判断する。
type: project
---

# Claude Code 公式準拠 ナレッジベース

最終更新: 2026-04-30
情報源:
- <https://code.claude.com/docs/en/overview>
- <https://code.claude.com/docs/en/sub-agents>
- <https://code.claude.com/docs/en/agent-teams>
- <https://code.claude.com/docs/en/hooks>
- <https://code.claude.com/docs/en/skills>
- <https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview>
- <https://code.claude.com/docs/en/settings>
- <https://code.claude.com/docs/en/slash-commands>
- <https://code.claude.com/docs/en/memory>
- <https://code.claude.com/docs/en/mcp>

注: `docs.claude.com/en/docs/claude-code/*` は **301 redirect** で `code.claude.com/docs/en/*` に移行済 (2026-04 確認)。

---

## 0. 重要な変更点 (v2.1 系の最新仕様)

| 変更 | 影響 | 確定情報 |
|---|---|---|
| `Task` tool → **`Agent` tool** に rename (v2.1.63) | 既存 `Task(...)` は alias で動作 | sub-agents docs |
| Custom commands と Skills が **統合** | `.claude/commands/<name>.md` と `.claude/skills/<name>/SKILL.md` は等価。Skills は frontmatter で invocation 制御可 | skills docs |
| **Agent Teams** (実験的, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) v2.1.32+ | tmux multi-pane / 並列 session の **公式版**。lead と teammate が独立 session、mailbox/task list 経由通信 | agent-teams docs |
| **Auto memory** v2.1.59+ | `~/.claude/projects/<project>/memory/MEMORY.md` を Claude が自動更新 (本プロジェクトの `memory/` とは別系統) | memory docs |
| `.claude/rules/` (path-scoped rules) | CLAUDE.md の細分割。`paths:` glob で発火条件指定 | memory docs |
| MCP Tool Search が default ON | 多数の MCP tool 追加でも context 圧迫しない | mcp docs |

---

## 1. Settings (`settings.json`)

### 1.1 階層 (precedence — 高い順)

1. **Managed settings** (組織配布, MDM/policy 配置, 上書き不可)
2. **Command-line arguments** (一時的 session override)
3. **Local project settings** — `.claude/settings.local.json` (**自動 gitignore**)
4. **Shared project settings** — `.claude/settings.json` (commit 対象)
5. **User settings** — `~/.claude/settings.json`

> "When the same setting is configured in multiple scopes, more specific scopes take precedence."
> 配列値 (`permissions.allow` 等) は **concatenate + dedupe** で merge される。

### 1.2 主要 key (確定)

```json
{
  "permissions": {
    "allow": ["Bash(npm run *)", "Read(~/.zshrc)"],
    "deny": ["Bash(curl *)", "Read(./.env)"],
    "ask": ["Bash(git push *)"],
    "defaultMode": "default | acceptEdits | plan | auto | dontAsk | bypassPermissions",
    "additionalDirectories": ["../docs/"]
  },
  "env": { "CLAUDE_CODE_ENABLE_TELEMETRY": "1" },
  "model": "claude-sonnet-4-6",
  "hooks": { /* see §2 */ },
  "statusLine": { "type": "command", "command": "~/.claude/statusline.sh" },
  "attribution": { "commit": "🤖 Generated...", "pr": "" },
  "agent": "code-reviewer",                 // session-default subagent
  "autoMemoryEnabled": true,
  "autoMemoryDirectory": "~/my-mem",
  "claudeMdExcludes": ["**/monorepo/CLAUDE.md"],
  "teammateMode": "auto | in-process | tmux",
  "disableAllHooks": false,
  "disableSkillShellExecution": false
}
```

JSON Schema 公開: <https://json.schemastore.org/claude-code-settings.json>

### 1.3 v2 採用判定
- v2 `.claude/settings.json` 現状: `hooks` (Stop, PostToolUse, SessionStart) + `permissions.deny` のみ → **公式 schema 準拠 OK**
- 採用検討:
  - `permissions.ask` で `git push` 等を **明示的に確認**プロンプト化
  - `additionalDirectories` で `projects/` 配下のサブプロジェクト読み込み
  - `claudeMdExcludes` で巨大 monorepo 取込時のノイズ除去
  - `attribution.commit` を MIT/Makoto 名義 footer に統一

---

## 2. Hooks (`.claude/hooks/`)

### 2.1 公式 event 一覧 (29 種、抜粋)

| Event | 発火 | Exit 2 効果 | v2 用途候補 |
|---|---|---|---|
| **SessionStart** | session 開始/resume | non-blocking error | ✅ 既に memory inject に使用 |
| Setup | `--init-only` | shown to user | CI 依存導入 |
| InstructionsLoaded | CLAUDE.md / rules 読込時 | non-blocking | audit |
| **UserPromptSubmit** | user prompt 送信前 | block & erase | 命令検閲 / context 注入 |
| UserPromptExpansion | slash command 展開時 | block expansion | skill 制御 |
| **PreToolUse** | tool 呼出前 | **block call** | **D001-D008 Bash deny の補強**, file 削除前確認 |
| PermissionRequest | permission ダイアログ前 | deny | auto-approve 政策 |
| PermissionDenied | classifier deny 時 | retry 制御 | retry 通知 |
| **PostToolUse** | tool 成功時 | non-blocking | ✅ 既に dashboard 更新に使用 (Edit/Write/MultiEdit) |
| PostToolUseFailure | tool 失敗時 | non-blocking | error log |
| PostToolBatch | parallel batch 完了 | block next | batch validate |
| Notification | 通知送信時 | non-blocking | desktop/slack 連携 |
| **SubagentStart** | subagent spawn | non-blocking | ✅ engineer dispatch ログ |
| **SubagentStop** | subagent 完了 | block stop | ✅ 結果 validation, memory 自動更新 |
| TaskCreated | TaskCreate 時 | rollback | task lifecycle audit |
| TaskCompleted | task 完了 | prevent | 完了 gate |
| **Stop** | turn 終了 | continue | ✅ 既に inbox 通知に使用 |
| StopFailure | API error 終了 | (ignored) | recovery |
| TeammateIdle | teammate idle 直前 | block idle | 仕事継続強制 |
| **PreCompact** | compact 直前 | block | important context 保護 |
| PostCompact | compact 後 | non-blocking | log |
| ConfigChange | 設定変更時 | block | audit |
| CwdChanged | `cd` 時 | non-blocking | direnv |
| FileChanged | watched file 変更 | non-blocking | rebuild |
| WorktreeCreate / WorktreeRemove | worktree 操作 | fail | custom worktree |
| Elicitation / ElicitationResult | MCP 入力要求 | deny / block | mock |
| SessionEnd | session 終了 | non-blocking | cleanup |

### 2.2 hook 設定構造

```json
{
  "hooks": {
    "EventName": [
      {
        "matcher": "ToolName|OtherTool",     // tool 名 regex / SessionStart は "startup|resume|clear|compact"
        "hooks": [
          {
            "type": "command|http|mcp_tool|prompt|agent",
            "if": "Bash(git *)",              // permission rule syntax
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/script.sh",
            "timeout": 600,
            "statusMessage": "Custom spinner"
          }
        ]
      }
    ]
  }
}
```

### 2.3 hook 入出力規約

- **stdin**: JSON (共通: `session_id`, `transcript_path`, `cwd`, `permission_mode`, `hook_event_name`, `agent_id?`, `agent_type?`) + event 固有 field
- **環境変数**: `$CLAUDE_PROJECT_DIR`, `$CLAUDE_PLUGIN_ROOT`, `$CLAUDE_ENV_FILE` (SessionStart で env persist), `$CLAUDE_CODE_REMOTE`
- **exit 0**: success。SessionStart/UserPromptSubmit では非 JSON stdout が context として注入される
- **exit 2**: blocking error。stderr が Claude or user に渡る
- **JSON output (exit 0 + JSON)**: `decision`, `reason`, `hookSpecificOutput.permissionDecision`, `additionalContext`, `updatedInput` で細かく制御可

### 2.4 v2 で **追加すべき** hook

| 用途 | event | 実装 |
|---|---|---|
| 大量 file 削除の事前 stop | PreToolUse + matcher `Bash` + `if: "Bash(rm *)"` | 10 file 超で exit 2 |
| 副 agent 結果の validation | SubagentStop | spec の Verification を自動実行 |
| userへの完了通知 | Stop | 現状 inbox watcher を pull 型 → push 型に |
| project 外修正の禁止 | PreToolUse + Edit/Write | path が project root 外なら exit 2 |
| auto memory 更新 trigger | SubagentStop | engineer 完了時に `memory/<agent>.md` の更新を促す prompt agent hook |

---

## 3. Subagents (`.claude/agents/<name>.md`)

### 3.1 frontmatter schema (公式確定)

```yaml
---
name: <lowercase-hyphens>          # 必須
description: <when to delegate>    # 必須
tools: Read, Grep, Glob, Bash       # 省略時は親 conversation の全 tool 継承
disallowedTools: Write, Edit
model: sonnet|opus|haiku|claude-opus-4-7|inherit  # default: inherit
permissionMode: default|acceptEdits|auto|dontAsk|bypassPermissions|plan
maxTurns: 50
skills: [api-conventions, error-handling]   # 起動時に full content 注入
mcpServers:
  - playwright:
      type: stdio
      command: npx
      args: ["-y", "@playwright/mcp@latest"]
  - github                          # 親 session の server を参照
hooks:
  PreToolUse:
    - matcher: Bash
      hooks: [{type: command, command: ./scripts/validate.sh}]
memory: user|project|local           # ✨ 公式の persistent memory 機構
background: false
effort: low|medium|high|xhigh|max
isolation: worktree                  # 別 git worktree で動く
color: red|blue|green|yellow|purple|orange|pink|cyan
initialPrompt: <auto-submit prompt>  # --agent で main session 化したとき
---

<system prompt body in markdown>
```

### 3.2 Scope precedence (高い順)

1. Managed settings (org-wide)
2. `--agents` CLI flag (session-only JSON)
3. **`.claude/agents/`** (project)
4. **`~/.claude/agents/`** (user)
5. Plugin's `agents/`

### 3.3 ⚠️ Nested Subagent Dispatch — 公式回答

> "**Subagents cannot spawn other subagents.** If your workflow requires nested delegation, use Skills or chain subagents from the main conversation."
> — sub-agents docs (`### Choose between subagents and main conversation` 末尾の Note)

> "This prevents infinite nesting (subagents cannot spawn other subagents) while still gathering necessary context."
> — Built-in Plan subagent の説明

> "If `Agent` is omitted from the `tools` list entirely, the agent cannot spawn any subagents. **This restriction only applies to agents running as the main thread with `claude --agent`. Subagents cannot spawn other subagents, so `Agent(agent_type)` has no effect in subagent definitions.**"
> — Restrict which subagents can be spawned

**結論**: Phase 8 で「動かない」と判明したのは **公式仕様通り**。planner subagent が engineer subagent を Agent tool で dispatch することは **禁止**されている。

### 3.4 Nested 代替パターン (公式推奨)

| パターン | 仕組み | 適合度 |
|---|---|---|
| **Main conversation = orchestrator** | user (CLI) が直接 planner / engineer を Agent tool で dispatch | ◎ シンプル、現行 v2 の改修最小 |
| **Chain subagents** | main が code-reviewer → optimizer と sequential dispatch | ○ 順序ある時 |
| **Skills with `context: fork`** | skill が forked subagent で実行、agent type 指定可 | ○ orchestration を skill 化 |
| **Agent Teams** | lead session が teammate session を spawn、mailbox/task list 経由通信 | ◎ tmux multi-pane を **公式機構**で再現 |
| **Forked subagent** (`CLAUDE_CODE_FORK_SUBAGENT=1`) | 親 conversation 全体を inherit した subagent | △ 並列試行用 |

### 3.5 Built-in subagents (常に利用可)

- **Explore** (Haiku, read-only): codebase 探索
- **Plan** (inherit, read-only): plan mode 内で context 収集 (← まさに nested-prevent 用)
- **general-purpose** (inherit, full tools): 汎用
- statusline-setup, Claude Code Guide

### 3.6 v2 現状の妥当性判定

| 観点 | 判定 |
|---|---|
| `.claude/agents/{planner,design-reviewer,code-reviewer}.md` の場所 | ✅ 公式準拠 |
| frontmatter (name/description/tools/model) | ✅ 公式準拠 |
| planner が tools に `Agent` を含む → 内部で engineer 呼出を期待 | ❌ **公式違反、動かない** |
| `~/.claude/agents/<engineer>.md` (user-level engineer) | ✅ 公式準拠 |
| `memory: project` フィールド未活用 | △ 公式の persistent memory 機構を使えば SessionStart hook 不要にできる |

---

## 4. Skills (`.claude/skills/<name>/SKILL.md`)

### 4.1 frontmatter schema

```yaml
---
name: my-skill                              # default: directory 名
description: <what & when to use>           # 推奨 (Claude が delegation 判断に使用)
when_to_use: <trigger phrases>              # description と合算 1536 文字 cap
argument-hint: "[issue-number]"
arguments: [issue, branch]                  # $issue / $branch で参照
disable-model-invocation: false              # true: user manual のみ
user-invocable: true                         # false: Claude のみ呼出可
allowed-tools: Read Grep, Bash(git *)
model: sonnet|opus|haiku|inherit
effort: low|medium|high|xhigh|max
context: fork                                # subagent 化
agent: Explore|Plan|general-purpose|<custom>  # context: fork の実行 agent
hooks: { PreToolUse: [...] }
paths: ["src/**/*.ts"]                       # この path で作業時のみ active
shell: bash|powershell
---
```

### 4.2 階層

| Location | Path | Scope |
|---|---|---|
| Enterprise | managed settings dir | org |
| Personal | `~/.claude/skills/<name>/SKILL.md` | 全プロジェクト |
| Project | `.claude/skills/<name>/SKILL.md` | このプロジェクト |
| Plugin | `<plugin>/skills/<name>/SKILL.md` | plugin namespace |

precedence: enterprise > personal > project (同名時)。Plugin は `plugin-name:skill-name` namespace なので衝突しない。

### 4.3 Progressive disclosure (3 段階)

1. **Metadata** (常時): `name` + `description` のみ system prompt 注入 (~100 tokens)
2. **Instructions** (invoke 時): SKILL.md 本体 (<5K tokens)
3. **Resources** (必要時): 同梱 file/script を bash 経由で on-demand 取得

### 4.4 Skills と Slash Commands は **統合済**

- `.claude/commands/<deploy>.md` と `.claude/skills/deploy/SKILL.md` は等価で **`/deploy`** を生成
- 既存 `.claude/commands/` は動き続けるが、Skills 推奨 (supporting files / invocation control)

### 4.5 Bundled skills (built-in)

`/simplify` `/batch` `/debug` `/loop` `/claude-api` `/init` `/review` `/security-review` は Claude Code 同梱。`/`-prefix で呼出可。

### 4.6 v2 で **追加すべき** skill 候補

| skill | 用途 | invocation |
|---|---|---|
| `/dispatch-engineer` | user → planner → engineer の自動 dispatch wrapper | user-invocable |
| `/archive-spec` | 完了 spec を `specs/archive/YYYY-MM/` に移動 | user-invocable + auto |
| `/update-memory` | engineer 完了時に `memory/<agent>.md` を curate | `disable-model-invocation: true` で SubagentStop hook から呼出 |
| `/init-project` | `projects/<name>/` 雛形を作成 | user-invocable |
| `/review-pr` | code-reviewer + design-reviewer 両方走らせる skill | `context: fork`, `agent: code-reviewer` |
| `/spec-haiku` | 要件 → Haiku grade spec 自動生成 | `disable-model-invocation: true` |

既存 `archive-queue` skill は既に `.claude/skills/archive-queue/` に置かれているので **公式準拠 OK**。

---

## 5. Slash Commands (`.claude/commands/<name>.md`)

### 5.1 統合後の現状

- **Skills と統合**。新規は `.claude/skills/<name>/SKILL.md` 推奨
- 既存 `.claude/commands/<name>.md` も同じ frontmatter で動き続ける
- 同名衝突時は **skill が優先**

### 5.2 frontmatter (Skills と共通)

`name` `description` `argument-hint` `arguments` `allowed-tools` `model` `disable-model-invocation` `user-invocable` `context` `agent` `paths` `shell` `hooks`

### 5.3 文字列置換

- `$ARGUMENTS` — 全引数文字列
- `$0` `$1` ... — shell-style 位置引数 (`$ARGUMENTS[N]` の短縮)
- `$<name>` — frontmatter `arguments:` で declare した名前
- `${CLAUDE_SESSION_ID}` `${CLAUDE_EFFORT}` `${CLAUDE_SKILL_DIR}`

### 5.4 動的 context 注入

- 行内: `` !`<bash command>` `` → 実行結果を Claude に渡す前に置換
- 多行: ` ```! ` fenced code block
- 設定で停止: `disableSkillShellExecution: true`
- ` @path/to/file ` で file 参照

### 5.5 v2 で **作るべき** slash command

user視点の頻用 op を skill 化:

```
/spec       — 要件から spec を生成 (specs/<topic>/)
/dispatch   — task spec を engineer に dispatch
/review     — design + code reviewer を chain
/archive    — done queue / done specs を archive
/dashboard  — dashboard.md を再生成
/memory-curate — memory/<agent>.md を 200 行以下に整理
```

---

## 6. MCP (`.mcp.json`)

### 6.1 3 つの scope

| Scope | Storage | 共有 |
|---|---|---|
| **Local** | `~/.claude.json` の `projects.<path>.mcpServers` | 個人, 1 project |
| **Project** | `.mcp.json` (project root) | team (commit) |
| **User** | `~/.claude.json` の `mcpServers` | 個人, 全 project |

precedence: local > project > user > plugin > claude.ai connector

### 6.2 `.mcp.json` schema

```json
{
  "mcpServers": {
    "playwright": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@playwright/mcp@latest"],
      "env": {"FOO": "bar"},
      "alwaysLoad": false
    },
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/",
      "headers": {"Authorization": "Bearer ${GITHUB_PAT}"},
      "oauth": {"clientId": "...", "callbackPort": 8080, "scopes": "..."}
    },
    "internal": {
      "type": "sse",
      "url": "...",
      "headersHelper": "/opt/bin/get-auth.sh"
    }
  }
}
```

`type: stdio | http | sse | ws`。env var expansion: `${VAR}` `${VAR:-default}`。

### 6.3 subagent への露出

- subagent の `mcpServers` frontmatter で:
  - **inline 定義**: subagent 起動時に connect, 終了時 disconnect (親 session には露出しない → context 節約)
  - **string 参照** (`- github`): 親 session の既存 connection を共有
- agent teams の teammate に subagent definition を流用するときは `mcpServers` フィールドは **無視**される (teammate は project/user settings から load)

### 6.4 v2 現状

- `.mcp.json` (project root, playwright-cdp) → **公式準拠 OK**
- `MAX_MCP_OUTPUT_TOKENS` env (default 25K) を `.claude/settings.json` の `env` で調整可

---

## 7. Memory / CLAUDE.md auto-load

### 7.1 CLAUDE.md の階層 (precedence — 高い順)

1. **Managed policy** (`/Library/Application Support/ClaudeCode/CLAUDE.md` 等)
2. **Project**: `./CLAUDE.md` または `./.claude/CLAUDE.md`
3. **User**: `~/.claude/CLAUDE.md`
4. **Local**: `./CLAUDE.local.md` (gitignore 推奨)

cwd から **親方向** に walk-up して全部 concat される (override ではない)。subdirectory の CLAUDE.md は **on-demand** (Claude がそのディレクトリの file を読んだ時に load)。

### 7.2 CLAUDE.local.md は **公式機構**

> "For private per-project preferences that shouldn't be checked into version control, create a `CLAUDE.local.md` at the project root."

`/init` で生成可、`.gitignore` に追加されている。

### 7.3 Imports

- `@path/to/file` syntax (相対 path は import 元 file 基準)
- 絶対 path 可、`@~/.claude/foo.md` も可
- 5 hop まで recursive
- 初回は approval dialog

### 7.4 `.claude/rules/` (path-scoped rules)

```yaml
---
paths:
  - "src/api/**/*.ts"
  - "lib/**/*.{ts,js}"
---
# API rules ...
```

- `paths` 無し → 常時 load (CLAUDE.md と同 priority)
- `paths` あり → 該当 file を Claude が触ったときだけ load
- symlink 対応 (shared rules を multiple project で link)

### 7.5 Subagent と memory

- subagent は **`memory:` frontmatter** で persistent memory を持てる:
  - `user`: `~/.claude/agent-memory/<name>/`
  - `project`: `.claude/agent-memory/<name>/`
  - `local`: `.claude/agent-memory-local/<name>/`
- 起動時に `MEMORY.md` の先頭 200 行/25KB が system prompt に自動注入
- Read/Write/Edit tool が自動有効化

### 7.6 ⚠️ v2 と公式の重大な diff

| v2 現状 | 公式機構 | 推奨対応 |
|---|---|---|
| `memory/<agent>.md` を `.claude/hooks/session_start_inject_memory.sh` で手動注入 | subagent frontmatter `memory: project` で **自動注入** | hook を残しつつ、`.claude/agents/*.md` に `memory: project` を追加すれば二重保険。最終的に hook を deprecate して公式機構に寄せる |
| `memory/MEMORY.md` (手動 index) | Claude が auto memory として勝手に作る (`~/.claude/projects/<project>/memory/MEMORY.md`) | **名前空間が衝突する**。v2 の `memory/` ディレクトリを `team-memory/` 等に rename or `claudeMdExcludes` で除外を検討 |
| CLAUDE.md (project root) | 同左 | ✅ OK |
| `instructions/<role>.md` | 公式機構なし。`@instructions/<role>.md` import か `.claude/rules/<role>.md` 相当に変換 | `.claude/rules/<role>.md` 化 + `paths:` で role-scoped 化 |

---

## 8. Agent Teams (実験的 — tmux multi-pane の公式版)

### 8.1 概要

> "Agent teams let you coordinate multiple Claude Code instances working together. **One session acts as the team lead**, coordinating work, assigning tasks, and synthesizing results. Teammates work independently, **each in its own context window, and communicate directly with each other**."

- **`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`** で有効化
- v2.1.32+ 必須
- subagents との違い: teammate は **完全独立 session**、相互 messaging 可

### 8.2 Architecture

| Component | Role |
|---|---|
| **Team lead** | チーム作成 + teammate spawn + 調整 |
| **Teammates** | 各々独立 Claude Code instance、shared task list から claim |
| **Task list** | 共有 work item、3 状態 (pending/in-progress/completed) + dependency 管理 |
| **Mailbox** | teammate 間の direct messaging (file lock で race 防止) |

ストレージ:
- Team config: `~/.claude/teams/{team-name}/config.json`
- Task list: `~/.claude/tasks/{team-name}/`

### 8.3 Display modes

- **in-process** (default if not in tmux): 同一 terminal、Shift+Down で teammate cycle、direct message
- **split panes** (`teammateMode: "tmux"`): 各 teammate が独立 pane (tmux or iTerm2 必須)

### 8.4 設定 (`~/.claude/settings.json` のみ受付、project では不可)

```json
{
  "env": {"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"},
  "teammateMode": "auto"
}
```

### 8.5 Subagent definition の流用

teammate spawn 時に既存 subagent name を指定可。ただし:
- `tools` と `model` のみ honored
- frontmatter body は teammate の system prompt に **append** (replace ではない)
- **`skills` と `mcpServers` は無視される** (teammate は project/user settings から自前で load)
- `SendMessage` と task tool は常に有効

### 8.6 制限事項 (引用)

- "**No nested teams**: teammates cannot spawn their own teams or teammates."
- "Lead is fixed: the session that creates the team is the lead for its lifetime."
- "Permissions set at spawn: all teammates start with the lead's permission mode."
- session resumption (`/resume`, `/rewind`) で in-process teammate は復元されない
- "One team per session"

### 8.7 v2 userの方針との比較

| userの v2 方針 | Agent Teams |
|---|---|
| tmux multi-pane で複数 role を独立 Claude session 化 | ✅ split panes mode で同等 |
| queue/inbox 経由連携 | ✅ mailbox + shared task list で同等 (file lock も標準装備) |
| 各 pane が Agent tool で subagent を一時 dispatch | ✅ 各 teammate session 内で Agent tool 利用可 (ただし teammate は subagent を nested できない、これは公式仕様) |
| pane 間 messaging | ✅ teammate name 指定で direct send |
| lead session が orchestrator | ✅ team lead = userの planner pane に対応 |

**重大な発見**: userが手動で構築している「tmux + queue/inbox + multi-Claude」アーキテクチャは、**Agent Teams (実験的) の手動再実装**である。公式が experimental である点は注意だが、**長期的には Agent Teams へ移行する判断肢が成立する**。

---

## 9. 公式推奨ディレクトリ構成 (canonical)

```
project-root/
├── .claude/
│   ├── agents/              # subagent 定義 (project scope)
│   │   ├── planner.md
│   │   └── code-reviewer.md
│   ├── commands/            # 旧式 slash commands (skills 推奨)
│   ├── hooks/               # hook scripts (任意の場所だが慣例)
│   ├── rules/               # path-scoped rules
│   │   ├── api.md           # paths: src/api/**
│   │   └── frontend.md
│   ├── skills/              # skill 定義
│   │   └── deploy/
│   │       ├── SKILL.md
│   │       └── scripts/
│   ├── settings.json        # 共有設定 (commit)
│   ├── settings.local.json  # 個人設定 (gitignore 自動)
│   ├── CLAUDE.md            # ← project CLAUDE.md (alt location)
│   ├── agent-memory/        # subagent persistent memory (project scope)
│   └── agent-memory-local/  # subagent persistent memory (gitignore)
├── .mcp.json                # MCP servers (project scope)
├── CLAUDE.md                # project instructions (auto-load)
├── CLAUDE.local.md          # personal preferences (gitignore)
└── AGENTS.md                # 他 AI tool 用 (optional, CLAUDE.md から @import 推奨)
```

---

## 10. v2 と公式の diff (具体的修正案)

### 10.1 即時直すべき (公式違反 / 動作不良)

1. **planner subagent からの engineer dispatch 廃止**
   - 現状: `.claude/agents/planner.md` の `tools: [..., Agent]` で planner が engineer を呼ぶ前提
   - 公式仕様: subagent は他 subagent を呼べない → **動かない**
   - 修正: planner 自身の dispatch 機構を **main conversation (userの CLI session)** に移す
     - 案 A: userが CLI で `/spec` → planner が specs/ 作成 → userが `/dispatch <task-id>` で engineer 起動
     - 案 B: userのセッションを `claude --agent planner` で planner system prompt 化 → user = planner = main thread → Agent tool で engineer 呼出可
     - 案 C: Agent Teams を有効化、planner = team lead、engineer = teammates

### 10.2 構造 cleanup (移動 / 統合)

| 操作 | 対象 | 公式準拠 |
|---|---|---|
| Move | `instructions/orchestrator.md` `instructions/planner.md` `instructions/reviewer.md` `instructions/engineer.md` → `.claude/rules/<role>.md` (frontmatter `paths` で scope 限定) または `@instructions/...` を CLAUDE.md から import | path-scoped rules |
| Add | `.claude/CLAUDE.md` を作るか、現 `CLAUDE.md` の `@instructions/...` import を整理 | imports |
| Add | `.claude/agents/*.md` の各 frontmatter に `memory: project` を追加 | persistent memory |
| Rename or exclude | `memory/` → `team-memory/` または `claudeMdExcludes` で auto-memory との衝突回避 | naming clarity |
| Move | `scripts/stop_hook_inbox.sh` `scripts/notify_dashboard_update.sh` → `.claude/hooks/` 配下に集約 | 慣例 |
| Add | `.claude/skills/dispatch-engineer/SKILL.md` (planner 内蔵 dispatch を skill 化) | skill 化 |
| Add | `.claude/skills/spec-haiku/SKILL.md` (要件 → Haiku spec 生成) | skill 化 |
| Add | `.claude/skills/review-pr/SKILL.md` (`context: fork`, design + code reviewer chain) | skill 化 |
| Add | `.claude/commands/` を **削除**して `.claude/skills/` に統一 (現状空なら問題なし) | 統合 |

### 10.3 hooks 強化案

```jsonc
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {"type": "command", "if": "Bash(rm *)",
           "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/guard_rm.sh"}
        ]
      },
      {
        "matcher": "Edit|Write",
        "hooks": [
          {"type": "command",
           "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/guard_outside_project.sh"}
        ]
      }
    ],
    "SubagentStop": [
      {
        "hooks": [
          {"type": "command",
           "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/post_engineer.sh"}
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {"type": "command",
           "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/inject_dashboard.sh"}
        ]
      }
    ]
  }
}
```

### 10.4 Agent Teams 採用 (中期, optional)

userが experimental flag を許容できるなら:

```json
// ~/.claude/settings.json
{
  "env": {"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"},
  "teammateMode": "tmux"
}
```

→ tmux pane / queue/inbox / start_session.sh の **大半が不要**になる (userの自前実装が公式機構に置換)。

ただし known limitations:
- session resume で in-process teammate 復元できない
- task lag、shutdown 遅延
- 1 team per session

→ v3 候補。短期は現状の手動 multi-pane でも問題なし、ただし **planner の nested dispatch だけは即時直す**こと。

---

## 11. 残存 / 未確認

- **Agent SDK** (`/en/agent-sdk/overview`): 本調査では未読。CLI / Subagent 仕様で十分カバーできているはず
- **Plugins** (`/en/plugins`): 配布機構の詳細未読、必要なら別途
- **Permission Modes 詳細** (`/en/permission-modes`): auto mode classifier の挙動、本調査スキップ
- 公式 GitHub repo (`anthropics/claude-code`) の README / examples: 未読 (docs.claude.com で十分)

---

## 12. 参考 URL (公式一次情報)

- Overview: <https://code.claude.com/docs/en/overview>
- Sub-agents: <https://code.claude.com/docs/en/sub-agents>
- Agent Teams: <https://code.claude.com/docs/en/agent-teams>
- Skills (Claude Code): <https://code.claude.com/docs/en/skills>
- Agent Skills (cross-platform): <https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview>
- Hooks: <https://code.claude.com/docs/en/hooks>
- Settings: <https://code.claude.com/docs/en/settings>
- Memory: <https://code.claude.com/docs/en/memory>
- MCP: <https://code.claude.com/docs/en/mcp>
- Slash Commands: <https://code.claude.com/docs/en/slash-commands> (現在は Skills へ統合)
- LLMs index: <https://code.claude.com/docs/llms.txt>
- Settings JSON Schema: <https://json.schemastore.org/claude-code-settings.json>
</content>
</invoke>