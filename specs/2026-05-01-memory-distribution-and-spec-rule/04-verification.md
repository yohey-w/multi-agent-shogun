---
phase: cmd_001
task_id: tester_task_001
agent: tester
estimated_minutes: 12
depends_on: [subtask_001a, subtask_001b, subtask_002]
---

# Task: Blind QA — cmd_001 全 AC 検証

## Goal
spec の Acceptance Criteria のみを根拠として、実装物が全 AC を満たすかを blind に検証する。
engineer report / git diff は読まない。

## ⚠️ Blindness Rule
- 読んでよいもの: この spec ファイル + 各 deliverable ファイルの実体
- 読んではいけないもの: engineer report YAML, git diff/log, engineer inbox

## Test Cases

### AC-1: project-level agent memory 配布確認

```bash
PROJECT_ROOT="/Users/mizunomakoto/Project/makotoProj/ai_accelerate/agent-orchestra-makoto-mizuno"
AGENTS_DIR="$PROJECT_ROOT/.claude/agents"
MEMORY_DIR="$PROJECT_ROOT/memory"
for agent in planner design-reviewer code-reviewer claude-code-expert tester; do
  test -f "$AGENTS_DIR/$agent/agent-memory/$agent.md" || echo "MISSING: $agent/$agent.md"
  test -f "$AGENTS_DIR/$agent/agent-memory/MEMORY.md" || echo "MISSING: $agent/MEMORY.md"
  diff "$MEMORY_DIR/$agent.md" "$AGENTS_DIR/$agent/agent-memory/$agent.md" > /dev/null \
    && echo "PASS: $agent.md content matches" \
    || echo "FAIL: $agent.md content mismatch"
  diff "$MEMORY_DIR/MEMORY.md" "$AGENTS_DIR/$agent/agent-memory/MEMORY.md" > /dev/null \
    && echo "PASS: $agent MEMORY.md matches" \
    || echo "FAIL: $agent MEMORY.md mismatch"
done
```

**期待**: 全ファイル存在 + 内容一致

### AC-2: user-level agent memory 配布確認

```bash
USER_AGENTS="$HOME/.claude/agents"
MEMORY_DIR="$PROJECT_ROOT/memory"
for agent in frontend-engineer backend-engineer infrastructure-engineer db-engineer \
             chrome-extension-engineer native-app-engineer game-engineer ml-engineer qa-engineer; do
  test -f "$USER_AGENTS/$agent/agent-memory/$agent.md" || echo "MISSING: $agent/$agent.md"
  test -f "$USER_AGENTS/$agent/agent-memory/MEMORY.md" || echo "MISSING: $agent/MEMORY.md"
  diff "$MEMORY_DIR/$agent.md" "$USER_AGENTS/$agent/agent-memory/$agent.md" > /dev/null \
    && echo "PASS: $agent.md content matches" \
    || echo "FAIL: $agent.md content mismatch"
done
```

**期待**: 全 9 engineer × 2 ファイル = 18 ファイル存在 + 内容一致

### AC-3: planner.md F006/F007 存在確認

```bash
grep -n "F006\|F007" /Users/mizunomakoto/Project/makotoProj/ai_accelerate/agent-orchestra-makoto-mizuno/.claude/rules/planner.md
```

**期待**: F006 と F007 の行が表示される (それぞれ 1 行以上)

### AC-4: spec ファイル存在確認

```bash
ls /Users/mizunomakoto/Project/makotoProj/ai_accelerate/agent-orchestra-makoto-mizuno/specs/2026-05-01-memory-distribution-and-spec-rule/
```

**期待**: 00-overview.md, 01-memory-dist-project.md, 02-memory-dist-user.md, 03-planner-rule-addition.md, 04-verification.md の 5 ファイル以上存在

## Expected Output

全 AC が PASS → overall: pass でレポート

## Verification (tester 自身の確認)
上記 Test Cases の bash コマンドを実行し、全て期待通りの出力が得られること。
"MISSING" / "FAIL" が 1 件でもあれば overall: fail。

## Notes
- SKIP = FAIL ルール厳守
- 全コマンドを実際に実行し、出力を evidence として記録すること
