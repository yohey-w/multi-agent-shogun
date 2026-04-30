---
name: shogun-agent-status
description: 全エージェント（家老・足軽1-7・軍師）の稼働状態を一覧表示するスキル。tmux pane状態（稼働中/待機中/不在）とタスクYAML状態（task_id, status）と未読inbox数を統合表示。「稼働確認」「エージェント状態」「布陣確認」「agent status」で起動。
---

# /agent-status - エージェント稼働確認

## Overview

全エージェントの稼働状態を2つのデータソースから統合判定して一覧表示する。

1. **Pane状態**: tmux capture-paneの末尾5行からCLI固有のidle/busyパターンを検出
2. **タスクYAML**: `queue/tasks/{agent}.yaml` のtask_idとstatus
3. **未読inbox**: `queue/inbox/{agent}.yaml` の未処理メッセージ数

Claude Code / Codex CLI 両方に対応。

## When to Use

- 「稼働確認」「エージェント状態」「布陣確認」と言われた時
- 足軽が暇そうか確認したい時
- タスク配分前に空いているエージェントを探す時
- 誰かが止まっているか調べたい時

## Instructions

以下のコマンドを実行する:

```bash
bash scripts/agent_status.sh
```

## 出力の読み方

| Column | 意味 |
|--------|------|
| Agent | エージェント名 |
| CLI | CLI種別（claude/codex） |
| Pane | tmux pane状態: 稼働中/待機中/不在 |
| Task ID | タスクYAMLのtask_id（---=未割当） |
| Status | タスクYAMLのstatus: assigned/done/idle等 |
| Inbox | 未読inboxメッセージ数 |

## 状態の解釈

- **Pane=待機中 + Status=done**: 完了済み、次タスク待ち。新タスク配分可能。
- **Pane=稼働中 + Status=assigned**: 正常にタスク実行中。放置してよい。
- **Pane=待機中 + Status=assigned**: タスク割当済みだがCLIが止まっている。要調査。
- **Pane=稼働中 + Status=done**: タスク完了後に別作業中（inbox処理等）。
- **Inbox > 0**: 未読メッセージあり。エージェントが処理していない可能性。
- **Pane=不在**: tmux paneが存在しない（shutsujin未実行 or pane killed）。
