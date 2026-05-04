---
phase: cmd_002
task_id: subtask_003
agent: engineer1
estimated_minutes: 15
depends_on: []
bloom_level: L4
---

# Task: .claude/agents/tester.md 新規作成

## Goal
tester の project-level subagent 定義ファイルを `.claude/agents/tester.md` に新規作成する。
**必ず claude-code-expert subagent を Agent tool で dispatch し、公式 frontmatter 仕様を確認してから作成すること。**

## ⚠️ 必須制約: claude-code-expert subagent dispatch

このタスクは本 cmd の検証ポイント (ドッグフード) である。
engineer1 は以下の手順で **Agent tool から claude-code-expert subagent を dispatch** すること:

```
Agent({
  subagent_type: "claude-code-expert",
  description: "Official subagent frontmatter spec check",
  prompt: |
    .claude/agents/ 配下の subagent 定義ファイルの公式仕様を確認してください。
    以下を教えてください:
    1. frontmatter に必須のフィールド (name, description, tools, model, memory 等) と型
    2. memory: project の挙動 (SessionStart hook との関係)
    3. tools フィールドで利用可能な値一覧
    4. tester agent に適したツールセット (read-only + write report のみが必要な場合)
    5. 既存 .claude/agents/planner.md を参考に tester.md の frontmatter を提案してください
})
```

dispatch 結果 (frontmatter 提案) を notes に記録し、それを元に tester.md を作成すること。

## Steps

1. claude-code-expert subagent を Agent tool で dispatch (上記 prompt)
2. dispatch 結果から正しい frontmatter を確定する
3. `.claude/rules/tester.md` を Read して tester の責務・禁止事項・フォーマットを把握する
4. `.claude/agents/tester.md` を Write で新規作成:
   - frontmatter: name, description, tools, model, memory
   - 本文: tester の役割・blindness 規律・report フォーマット・forbidden actions

## Expected Output: .claude/agents/tester.md

```markdown
---
name: tester
description: Execute blind QA against spec Acceptance Criteria only. Does NOT read engineer reports, git diffs, or impl code. Tests deliverable outputs against spec verification items. Reports PASS/FAIL per AC with evidence.
tools: [Read, Bash, Grep, Glob, Write]
model: claude-sonnet-4-5
memory: project
---

# Tester

## 役割
spec の Acceptance Criteria のみを根拠として deliverable を blind QA する。...
（.claude/rules/tester.md の内容を凝縮して記述）
```

## Verification
```bash
# ファイル存在確認
test -f /Users/mizunomakoto/Project/makotoProj/ai_accelerate/agent-orchestra-makoto-mizuno/.claude/agents/tester.md && echo "PASS: tester.md exists"

# frontmatter フィールド確認
grep -E "^name:|^description:|^tools:|^model:|^memory:" \
  /Users/mizunomakoto/Project/makotoProj/ai_accelerate/agent-orchestra-makoto-mizuno/.claude/agents/tester.md
# Expected: 全5フィールドが存在

# blindness rule 記述確認
grep -i "blind\|impl\|git log\|git diff" \
  /Users/mizunomakoto/Project/makotoProj/ai_accelerate/agent-orchestra-makoto-mizuno/.claude/agents/tester.md
# Expected: blindness 関連記述あり
```

## Notes
- 完了 report (engineer1_report.yaml) の notes に claude-code-expert dispatch 結果を記録すること
- skill_candidate.found は false でよい (定型作業)
- 完了後: `bash scripts/inbox_write.sh reviewer "Engineer 1 task complete (subtask_003). tester.md created." report_received engineer1`
