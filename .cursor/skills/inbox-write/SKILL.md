---
name: inbox-write
description: 別エージェントのinboxにメッセージを送信する。agent-to-agent通信の唯一の手段。
---

他のエージェントにメッセージを送るには、必ずこのスキルを使うこと。
tmux send-keys で直接メッセージを送ることは禁止。

## 使い方

```bash
bash scripts/inbox_write.sh <target_agent> "<message>" <type> <from>
```

### type 一覧

| type | 用途 |
|------|------|
| `cmd_new` | 新規コマンド（shogun→karo） |
| `task_assigned` | タスク割り当て（karo→ashigaru） |
| `report_received` | 作業完了報告（ashigaru→karo/gunshi） |
| `clear_command` | セッションリセット指示 |
| `model_switch` | モデル切り替え指示 |

### 例

```bash
bash scripts/inbox_write.sh karo "cmd_048を書いた。実行せよ。" cmd_new shogun
bash scripts/inbox_write.sh ashigaru3 "タスクYAMLを読んで作業開始せよ。" task_assigned karo
bash scripts/inbox_write.sh gunshi "足軽5号、任務完了。品質チェックを仰ぎたし。" report_received ashigaru5
```
