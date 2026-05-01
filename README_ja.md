# agent-orchestra-makoto-mizuno

Claude Code 上で **tmux 複数 pane** に専門 role を並列稼働させる、マルチエージェント開発オーケストレーション基盤。spec / memory / queue ベースの役割分担で動く。

## コンセプト

tmux session 1 つに role 別 pane を立ち上げる:

- **orchestrator** — 殿の要件を受け取り planner に dispatch、最終結果を返す
- **planner** — 要件を Haiku 粒度の仕様書 (`specs/`) に分解し、各 task を担当 engineer に割当
- **engineer1..7** — 実装 pane。subagent dispatch で frontend / backend / db / ... の専門に化ける
- **reviewer** — merge 前の design + code レビュー

各 pane は独立した Claude Code session で、それぞれ別のコンテキストウィンドウを持つ。連携は `queue/inbox/<role>.yaml` + `queue/outbox/<role>.yaml` (file ベース message bus、`scripts/inbox_watcher.sh` が監視)。役割別 memory は `memory/<role>.md` に置き、SessionStart hook で起動時に自動 inject される。

## 役割

| レイヤ | 役割 | 場所 |
|--------|------|------|
| プロジェクト subagent | planner | `.claude/agents/planner.md` |
| プロジェクト subagent | design-reviewer | `.claude/agents/design-reviewer.md` |
| プロジェクト subagent | code-reviewer | `.claude/agents/code-reviewer.md` |
| プロジェクト subagent | claude-code-expert | `.claude/agents/claude-code-expert.md` |
| ユーザ subagent | frontend-engineer / backend-engineer / db-engineer / chrome-extension-engineer / native-app-engineer / game-engineer / ml-engineer / qa-engineer / infrastructure-engineer | `~/.claude/agents/*.md` |

## 前提条件

- macOS または Linux
- [tmux](https://github.com/tmux/tmux) 3.2 以上
- [Claude Code CLI](https://docs.claude.com/en/docs/claude-code) (最新)
- (任意) `fswatch` (macOS) または `inotifywait` (Linux) — inbox watcher 用
- (任意) `gitleaks` + `pre-commit` — secret スキャン用

## 立ち上げ方

### 1. clone + 設定確認

```bash
git clone <このリポジトリ> agent-orchestra
cd agent-orchestra
```

`CLAUDE.md` (Claude が自動 load する project 指示書) と `.claude/settings.json` (hooks / permissions) に目を通す。`config/settings.yaml` があれば内容調整。

### 2. multi-pane session を起動

```bash
./start_session.sh           # default — orchestrator + planner + engineer1..7 + reviewer
./start_session.sh -k        # 全 pane Opus (決戦モード)
./start_session.sh -c codex  # 一部 pane を Codex CLI に
./start_session.sh -h        # 完全な help
```

`orchestrator` (1 pane) と `multiagent` (9 pane: planner + engineer1..7 + reviewer) の 2 つの tmux session が起動する。

### 3. orchestrator に attach

```bash
tmux attach -t orchestrator        # css alias がインストール済なら css でも可
```

これで orchestrator pane に入る。殿 (ユーザ) はここに高レベル要件を投げる。orchestrator は:

1. planner に dispatch (`queue/inbox/planner.yaml` 経由)
2. planner が `specs/<date>-<topic>/` 配下に spec 群を作成
3. planner が dispatch 指示書を返す
4. orchestrator (= main session で動いている殿/Claude) が `Agent` tool で engineer を起動
5. engineer 実装 → reviewer レビュー → orchestrator が殿に最終報告

### 4. 便利な skills (slash command)

起動後、どの pane でも以下が使える:

| コマンド | 用途 |
|---------|------|
| `/spec-haiku <topic>` | 要件から Haiku 粒度 spec 群を生成 |
| `/dispatch-engineer <task-id>` | 担当 engineer に spec task を dispatch |
| `/review-pr` | design + code reviewer chain を現在 branch に対して実行 |
| `/dashboard` | `dashboard.md` を最新状況で再生成 |
| `/archive-spec <topic>` | 完了 spec を `specs/archive/YYYY-MM/` に移動 |
| `/init-project <name>` | `projects/` 配下に新規プロジェクト雛形 |
| `/memory-curate <agent>` | 指定 agent の memory を 200 行以下に整理 |

### 5. hooks (自動実行)

| event | hook | 動作 |
|-------|------|------|
| SessionStart | `session_start_inject_memory.sh` | 起動時に `memory/<role>.md` を context 注入 |
| PreToolUse · Bash | `guard_rm.sh` | 危険な `rm -rf` パターン (`CLAUDE.md` の D001–D002) を block |
| PreToolUse · Edit/Write | `guard_outside_project.sh` | プロジェクト外への書込を block |
| SubagentStop | `post_engineer.sh` | memory が 200 行超なら curate を促す |
| UserPromptSubmit | `inject_dashboard.sh` | dashboard と queue 状況をプロンプトに注入 |

### 6. session 停止

```bash
tmux kill-session -t orchestrator
tmux kill-session -t multiagent
```

(`./start_session.sh --shutdown` があればそれを使ってもよい — `-h` で確認)

## ディレクトリ構成

```
.claude/
├── agents/   # planner / reviewers / claude-code-expert (project subagent)
├── hooks/    # SessionStart / PreToolUse / SubagentStop / UserPromptSubmit
├── rules/    # role 別手順書 (Claude Code rule として auto-load)
├── skills/   # slash command (SKILL.md 形式)
└── settings.json
.github/workflows/secret-scan.yml
config/                   # ntfy auth サンプル、runtime config
memory/                   # role 別 persistent context (SessionStart で注入)
queue/                    # inbox/outbox YAML message bus
scripts/                  # inbox watcher, agent status, switch CLI 等
specs/                    # Haiku 粒度の task 仕様書
projects/                 # 実プロジェクト (gitignored)
start_session.sh          # tmux 起動 entry point
CLAUDE.md                 # project 指示書 (auto-load)
```

詳細は `CLAUDE.md` (アーキテクチャ全体)、`memory/claude-code-expert.md` (Anthropic Claude Code 公式仕様の知識ベース) を参照。

## ライセンス

MIT — [LICENSE](LICENSE) 参照。

## ステータス

開発中 (v2 移行中、`specs/` 参照)。

---

[English](README.md)
