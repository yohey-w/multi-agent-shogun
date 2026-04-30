---
name: shogun-model-switch
description: |
  エージェントのCLI/モデルをライブ切替するスキル。settings.yaml更新→/exit→新CLI起動→
  pane metadata更新を一発で実行。Thinking有無も制御。
  「モデル切替」「Sonnetにして」「Opusに変えて」「足軽全員切替」「Thinking切って」で起動。
argument-hint: "[agent-name target-model e.g. ashigaru1 sonnet]"
allowed-tools: Bash(bash scripts/switch_cli.sh *), Read, Edit
---

# /model-switch - Agent CLI Live Switcher

## Overview

稼働中のエージェントのCLI種別・モデル・Thinking設定をライブで切り替える。
`settings.yaml` → `build_cli_command()` → `/exit` → 新CLI起動 → pane metadata更新 を一貫実行。

## When to Use

- 「ashigaru3をOpusにして」「足軽全員Sonnetに切替」
- 「モデル切替」「モデル変えて」「CLI変えて」
- 「Thinking切って」「Thinking有効にして」
- 「CodexからClaudeに戻して」「Sparkにして」
- タスクの性質に応じてモデルを切り替えたいとき

## Architecture

```
settings.yaml (source of truth)
    │
    ├─ cli.agents.{id}.type      → claude | codex | copilot | kimi
    ├─ cli.agents.{id}.model     → claude-sonnet-4-6 | claude-opus-4-6 | ...
    └─ cli.agents.{id}.thinking  → true | false
         │
         ├── build_cli_command()
         │   └─ thinking: false → "MAX_THINKING_TOKENS=0 claude --model ..."
         │   └─ thinking: true  → "claude --model ..."
         │
         └── get_model_display_name()
             └─ thinking: true  → "Sonnet+T" / "Opus+T"
             └─ thinking: false → "Sonnet" / "Opus"
```

## Display Name Mapping

| model (settings.yaml) | 表示名 | +Thinking |
|---|---|---|
| claude-sonnet-4-6 | Sonnet | Sonnet+T |
| claude-opus-4-6 | Opus | Opus+T |
| claude-haiku-4-5-20251001 | Haiku | Haiku+T |
| gpt-5.3-codex | Codex | — |
| gpt-5.3-codex-spark | Spark | — |

## Instructions

### 単体切替

```bash
# settings.yaml の現在値で再起動（CLIリセットしたいだけのとき）
bash scripts/switch_cli.sh ashigaru3

# モデル変更（settings.yaml も自動更新）
bash scripts/switch_cli.sh ashigaru3 --model claude-opus-4-6

# CLI種別ごと変更（Codex → Claude）
bash scripts/switch_cli.sh ashigaru3 --type claude --model claude-sonnet-4-6

# Claude → Codex Spark
bash scripts/switch_cli.sh ashigaru5 --type codex --model gpt-5.3-codex-spark
```

### 一括切替

```bash
# 全足軽をSonnetに
for i in $(seq 1 7); do
    bash scripts/switch_cli.sh ashigaru$i --type claude --model claude-sonnet-4-6
done

# 全足軽をSparkに
for i in $(seq 1 7); do
    bash scripts/switch_cli.sh ashigaru$i --type codex --model gpt-5.3-codex-spark
done

# 全エージェント（家老・軍師含む）を再起動
for agent in karo ashigaru1 ashigaru2 ashigaru3 ashigaru4 ashigaru5 ashigaru6 ashigaru7 gunshi; do
    bash scripts/switch_cli.sh "$agent"
done
```

### Thinking 制御

settings.yaml の `thinking` フィールドを編集してから switch_cli.sh を実行:

```yaml
# config/settings.yaml
cli:
  agents:
    ashigaru3:
      type: claude
      model: claude-opus-4-6
      thinking: false  # ← MAX_THINKING_TOKENS=0 で起動
```

```bash
# settings.yaml 編集後に再起動
bash scripts/switch_cli.sh ashigaru3
```

Thinking ON/OFF の切替手順:
1. `config/settings.yaml` の対象エージェントの `thinking:` を `true` / `false` に変更
2. `bash scripts/switch_cli.sh <agent_id>` で再起動
3. pane border に `+T` の有無が反映される

### inbox 経由（家老からの切替）

```bash
# 家老が足軽のCLIを切り替える場合
bash scripts/inbox_write.sh ashigaru3 "--type claude --model claude-opus-4-6" cli_restart karo
```

inbox_watcher が `cli_restart` type を検知し、switch_cli.sh を自動実行する。

## What switch_cli.sh Does (internal)

1. **settings.yaml 更新**（`--type`/`--model` 指定時のみ）
2. **現在のCLI種別を検出**（tmux pane metadata `@agent_cli`）
3. **CLI別の exit コマンドを送信**
   - Claude: `/exit` + Enter
   - Codex: Escape → Ctrl-C → `/exit` + Enter
   - Copilot/Kimi: Ctrl-C → `/exit` + Enter
4. **シェルプロンプト復帰を待機**（最大15秒、1秒ごとにキャプチャ）
5. **`build_cli_command()` で新コマンド構築**
   - thinking: false → `MAX_THINKING_TOKENS=0` prefix 付与
6. **tmux send-keys で新CLI起動**（テキストとEnterを分離送信）
7. **pane metadata 更新**: `@agent_cli`, `@model_name`

## Files

| ファイル | 役割 |
|---|---|
| `scripts/switch_cli.sh` | メインスクリプト |
| `lib/cli_adapter.sh` | `build_cli_command()`, `get_model_display_name()` |
| `config/settings.yaml` | エージェント設定（type, model, thinking） |
| `scripts/inbox_watcher.sh` | `cli_restart` type ハンドリング |
| `logs/switch_cli.log` | 実行ログ |

## Constraints

- **将軍(shogun)ペインには送信しない**: switch_cli.sh は multiagent セッションのペインのみ対象
- **実行中のエージェントに注意**: タスク実行中に切り替えるとデータ消失の可能性あり。idle確認してから実行
- **Codex → Claude 切替時**: Codex の /exit が不安定な場合がある。Escape + Ctrl-C で確実に終了させる
- **inbox_watcher との連携**: cli_restart 後、inbox_watcher の CLI_TYPE 変数も自動更新される
