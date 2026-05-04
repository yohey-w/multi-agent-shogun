---
phase: cmd_001
task_id: subtask_002
agent: engineer3
estimated_minutes: 8
depends_on: []
---

# Task: planner.md に spec-first 禁止ルール (F006/F007) を追加

## Goal
`.claude/rules/planner.md` の Forbidden Actions テーブルに F006/F007 を追加し、
planner が spec を省略して直接 dispatch することを明文禁止する。

## Inputs
- 編集対象: `/Users/mizunomakoto/Project/makotoProj/ai_accelerate/agent-orchestra-makoto-mizuno/.claude/rules/planner.md`
- 現行 Forbidden Actions:
  - F001: Execute tasks yourself
  - F002: Report directly to human
  - F003: Use Task agents for execution
  - F004: Polling/wait loops
  - F005: Skip context reading

## Steps

1. ファイルを Read して現行 Forbidden Actions テーブルを確認する

2. テーブルの末尾 (F005 の行の後) に以下の 2 行を追加する:

   ```
   | F006 | cmd を受領後に spec ファイル (specs/YYYY-MM-DD-<topic>/) を作成せずに engineer/tester/reviewer へ inbox dispatch する | 必ず spec を先に作成してから dispatch すること |
   | F007 | spec 不在のまま実装作業を継続させた場合 (orchestrator に報告せずに放置する) | orchestrator に即時報告し、当該 cmd を cancel 要請する |
   ```

3. Edit ツールで正確に挿入する (既存行を変更しない)

4. 変更後に Read で確認し、F006/F007 が正しく挿入されていることを検証する

## Expected Output
`.claude/rules/planner.md` の Forbidden Actions テーブルが以下の状態になる:

```
| F001 | Execute tasks yourself | Delegate to engineer |
| F002 | Report directly to human | Update dashboard.md |
| F003 | Use Task agents for execution | Use inbox_write. Exception: Task agents OK for doc reading, decomposition, analysis |
| F004 | Polling/wait loops | Event-driven only |
| F005 | Skip context reading | Always read first |
| F006 | cmd を受領後に spec ファイル (specs/YYYY-MM-DD-<topic>/) を作成せずに engineer/tester/reviewer へ inbox dispatch する | 必ず spec を先に作成してから dispatch すること |
| F007 | spec 不在のまま実装作業を継続させた場合 (orchestrator に報告せずに放置する) | orchestrator に即時報告し、当該 cmd を cancel 要請する |
```

## Verification
```bash
grep -n "F006\|F007" /Users/mizunomakoto/Project/makotoProj/ai_accelerate/agent-orchestra-makoto-mizuno/.claude/rules/planner.md
# Expected: F006 と F007 の行が表示される
```

## Notes
- Edit ツールで old_string に F005 行を含め、new_string に F005+F006+F007 の 3 行を書く
- テーブルの既存フォーマット (| ID | Action | Instead |) を維持する
- 同じ内容が roles/planner_role.md にもあるが、そちらは編集対象外 (main rules を正とする)
