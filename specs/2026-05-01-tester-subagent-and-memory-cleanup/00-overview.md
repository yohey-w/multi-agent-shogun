---
phase: cmd_002
task_id: 00-overview
agent: planner
estimated_minutes: 3
depends_on: []
---

# cmd_002 Overview: tester subagent 化 + memory/ 削除 + engineer subagent dispatch ルール

## North Star
agent definition の欠損を埋め、single-source-of-truth を agent-memory/ に集約する。
engineer pane が specialist subagent を Agent tool 経由で呼び出す動作を検証する。

## Task Map

| task_id | agent | 内容 | bloom | 依存 |
|---------|-------|------|-------|------|
| subtask_003 | engineer1 | .claude/agents/tester.md 作成 (claude-code-expert dispatch 必須) | L4 | なし |
| subtask_004 | engineer2 | memory/ 削除 + hook/doc パス更新 | L3 | なし |
| subtask_005 | engineer3 | engineer.md に subagent dispatch ルール追記 | L2 | なし |
| tester_task_002 | tester | blind QA (AC 全項目) | — | 003, 004, 005 |
| reviewer_task_002 | reviewer | impl+diff レビュー | — | 003, 004, 005 |

## Acceptance Criteria (cmd_002)

1. `.claude/agents/tester.md` 新規作成 (公式 frontmatter + tester.md rules 整合)
2. `.claude/agents/tester.md` が claude-code-expert subagent レビュー済みであること
3. `memory/` ディレクトリが完全削除 (git rm)
4. hooks / rules / CLAUDE.md の `memory/` パス参照が agent-memory/ ベースに更新
5. `.claude/rules/engineer.md` に specialist subagent dispatch ルール追記
6. tester blind QA 全 AC PASS
7. reviewer 指摘 0 件
