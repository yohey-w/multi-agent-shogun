---
phase: cmd_001
task_id: 00-overview
agent: planner
estimated_minutes: 3
depends_on: []
---

# cmd_001 Overview: Memory 配布 + Planner spec-first ルール強化

## North Star
Multi-pane orchestrator の end-to-end 連携を実タスクで検証し、spec-first ルールの遵守体制を確立する。

## Task Map

| task_id | agent | 内容 | 依存 |
|---------|-------|------|------|
| 01-memory-dist-project | engineer1 | project-level agent に memory 配布 | なし |
| 02-memory-dist-user | engineer2 | user-level agent に memory 配布 | なし |
| 03-planner-rule | engineer3 | planner.md に F006/F007 追加 | なし |
| 04-verification | tester | blind QA — AC 全項目 verify | 01, 02, 03 |
| 05-review | reviewer | impl+diff レビュー | 01, 02, 03 |

## Acceptance Criteria (cmd_001)

1. project-level agents (.claude/agents/): planner/design-reviewer/code-reviewer/claude-code-expert/tester の各 agent-memory/ に memory.md + MEMORY.md が存在
2. user-level agents (~/.claude/agents/): 9 engineer の各 agent-memory/ に memory.md + MEMORY.md が存在
3. .claude/rules/planner.md の Forbidden Actions に F006/F007 が追加されている
4. specs/2026-05-01-memory-distribution-and-spec-rule/ に全 spec が揃っている
5. tester が全 AC PASS を report
6. reviewer が指摘 0 件を report
7. dashboard.md に 4-stage flow 完了が記録されている
