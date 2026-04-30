---
phase: 1
task_id: 03-mark-cancelled-statuses
agent: planner (or Haiku 直接実行可)
estimated_minutes: 5
depends_on: [01-stop-tmux-panes]
---

# Task: 進行中タスクの status を全て cancelled に書き換える

## Goal
queue/shogun_to_karo.yaml と各 queue/tasks/{agent}.yaml に残る pending/in_progress/assigned を全て cancelled にして、後で grep した時に「v2 移行で凍結」と分かる状態にする。

## Inputs
- `queue/shogun_to_karo.yaml`
- `queue/tasks/karo.yaml`, `queue/tasks/gunshi.yaml`, `queue/tasks/ashigaru[1-7].yaml`

## Steps
1. shogun_to_karo.yaml で以下を grep + sed で一括置換:
   - status: `pending` / `in_progress` / `partial` → `cancelled (v2 migration freeze 2026-04-30)`
   - 対象 cmd_id: 095, 096, 097, 098, 099, 100, 101, 102 (これら以外は既に done か legacy 化対象)
2. 各 tasks/*.yaml で同様に status: `assigned` / `in_progress` を `cancelled (v2 migration freeze 2026-04-30)` に
3. 変更を git add + commit:
```bash
git add queue/shogun_to_karo.yaml queue/tasks/
git commit -m "chore(v2-migration): mark all in-progress tasks as cancelled (freeze for v2)"
```

## Expected Output
- すべての progress 状態の status が `cancelled` に統一
- 1 commit

## Verification
```bash
grep -E "status:\s*(pending|in_progress|assigned|partial)" queue/shogun_to_karo.yaml queue/tasks/*.yaml
# Expected: 何も出力されない
```

## Notes
- inbox は触らない (既に処理済 = read: true / 未読 = v2 移行で意味失効)
- 編集は Bash + sed で一括 OK だが、YAML の indent を壊さないように単純な status: 行のみ対象
