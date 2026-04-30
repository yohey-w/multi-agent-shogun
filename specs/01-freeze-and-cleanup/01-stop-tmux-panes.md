---
phase: 1
task_id: 01-stop-tmux-panes
agent: manual (殿)
estimated_minutes: 1
depends_on: []
---

# Task: tmux multiagent セッションを終了

## Goal
旧戦国システムの tmux 9 pane を全て停止し、リソースを解放する。

## Inputs
- tmux session: `multiagent`

## Steps
1. 殿のターミナルで以下を実行:
```bash
tmux kill-session -t multiagent
```

## Expected Output
- `multiagent` session が消滅
- 9 pane (karo, ashigaru1-7, gunshi) の Claude Code CLI プロセスが終了

## Verification
```bash
tmux ls
# Expected: multiagent が一覧に出ない (or "no server running" なら全 OK)
```

## Notes
- 殿の現セッション (将軍/main) は別 tmux session or 直接ターミナルなので影響なし
- 終了前に「進行中の commit / 未保存の作業」が無いか念のため確認 (今回は v2 移行で全部捨てる前提なので気にしない)
