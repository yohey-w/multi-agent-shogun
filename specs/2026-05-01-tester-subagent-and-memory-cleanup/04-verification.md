---
phase: cmd_002
task_id: tester_task_002
agent: tester
estimated_minutes: 15
depends_on: [subtask_003, subtask_004, subtask_005]
---

# Task: Blind QA — cmd_002 全 AC 検証

## Goal
spec の AC のみを根拠として blind QA を実行する。
engineer report / git diff / git log は読まない。

## ⚠️ Blindness Rule
- 読んでよいもの: この spec ファイル + 各 deliverable の実体ファイル
- 読んではいけないもの: engineer report, git diff/log, engineer inbox

## Test Cases

### AC-1: .claude/agents/tester.md 存在と frontmatter 確認

```bash
PROJECT_ROOT="/Users/mizunomakoto/Project/makotoProj/ai_accelerate/agent-orchestra-makoto-mizuno"
TESTER_MD="$PROJECT_ROOT/.claude/agents/tester.md"

test -f "$TESTER_MD" && echo "PASS: tester.md exists" || echo "FAIL: tester.md missing"

# frontmatter 5フィールド確認
for field in "^name:" "^description:" "^tools:" "^model:" "^memory:"; do
  grep -qE "$field" "$TESTER_MD" && echo "PASS: $field present" || echo "FAIL: $field missing"
done
```

**期待**: 全 PASS (ファイル存在 + 5フィールド全て)

### AC-2: tester.md に blindness 規律が記述されているか

```bash
grep -i "blind\|impl.*diff\|git log\|git diff\|engineer.*report" \
  /Users/mizunomakoto/Project/makotoProj/ai_accelerate/agent-orchestra-makoto-mizuno/.claude/agents/tester.md
```

**期待**: blindness 関連キーワードが 1 行以上ヒット

### AC-3: memory/ ディレクトリが削除されているか

```bash
PROJECT_ROOT="/Users/mizunomakoto/Project/makotoProj/ai_accelerate/agent-orchestra-makoto-mizuno"
test ! -d "$PROJECT_ROOT/memory/" && echo "PASS: memory/ deleted" || echo "FAIL: memory/ still exists"
```

**期待**: PASS

### AC-4: hooks の memory/ 参照が更新されているか

```bash
PROJECT_ROOT="/Users/mizunomakoto/Project/makotoProj/ai_accelerate/agent-orchestra-makoto-mizuno"
broken=$(grep -n "memory/" "$PROJECT_ROOT/.claude/hooks/session_start_inject_memory.sh" \
  | grep -v "agent-memory" | grep -v "#")
if [ -z "$broken" ]; then
  echo "PASS: session_start_inject_memory.sh no broken refs"
else
  echo "FAIL: remaining refs:"
  echo "$broken"
fi
```

**期待**: PASS (agent-memory を参照、または空)

### AC-5: engineer.md に subagent dispatch ルールが追記されているか

```bash
grep -n "Specialist Subagent Dispatch Rule" \
  /Users/mizunomakoto/Project/makotoProj/ai_accelerate/agent-orchestra-makoto-mizuno/.claude/rules/engineer.md
```

**期待**: セクション見出しが 1 行以上ヒット

## Report Format
4/5 以上 PASS かつ AC-3 (memory/ 削除) 必須 PASS で overall: pass。
1 件でも FAIL は overall: fail。SKIP = FAIL。

## Notes
- 全コマンドを実際に実行し、出力を evidence として記録すること
- 完了後: `bash scripts/inbox_write.sh planner "Tester: QA complete on tester_task_002." report_received tester`
