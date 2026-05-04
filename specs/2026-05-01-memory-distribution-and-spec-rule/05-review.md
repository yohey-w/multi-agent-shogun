---
phase: cmd_001
task_id: reviewer_task_001
agent: reviewer
estimated_minutes: 10
depends_on: [subtask_001a, subtask_001b, subtask_002]
---

# Task: impl + diff レビュー — cmd_001

## Goal
engineer 3 名が実装した deliverable (memory 配布 + rule 追加) を reviewer が diff + 実体を確認し、
指摘事項の有無を planner に報告する。

## Review Scope

### 1. memory 配布の検証 (completeness check)

確認項目:
- project-level agents (5 つ) に agent-memory/ ディレクトリと 2 ファイルが存在するか
- user-level agents (9 つ) に同様の構造が存在するか
- コピー元 (memory/*.md) と配布先の内容が一致するか
- 既存の .claude/agents/*.md (定義ファイル) が変更されていないか
- 既存の ~/.claude/agents/*.md (定義ファイル) が変更されていないか

### 2. planner.md rule 追記の検証 (quality check)

確認項目:
- F006/F007 が Forbidden Actions テーブルに正しく追加されているか
- 既存 F001-F005 の行が変更されていないか
- F006/F007 の文言が cmd_001 command section の要件と一致するか
- テーブルの Markdown フォーマット (| ID | Action | Instead |) が維持されているか

### 3. git diff 確認

```bash
cd /Users/mizunomakoto/Project/makotoProj/ai_accelerate/agent-orchestra-makoto-mizuno
git status
git diff HEAD
```

engineer が commit した場合はそれを確認。未 commit なら working tree を確認。

## Review Commands

```bash
PROJECT_ROOT="/Users/mizunomakoto/Project/makotoProj/ai_accelerate/agent-orchestra-makoto-mizuno"

# 1. project-level agent-memory 確認
for agent in planner design-reviewer code-reviewer claude-code-expert tester; do
  echo "=== .claude/agents/$agent/agent-memory/ ==="
  ls -la "$PROJECT_ROOT/.claude/agents/$agent/agent-memory/" 2>/dev/null || echo "DIR MISSING"
done

# 2. user-level agent-memory 確認
for agent in frontend-engineer backend-engineer infrastructure-engineer db-engineer \
             chrome-extension-engineer native-app-engineer game-engineer ml-engineer qa-engineer; do
  echo "=== ~/.claude/agents/$agent/agent-memory/ ==="
  ls -la "$HOME/.claude/agents/$agent/agent-memory/" 2>/dev/null || echo "DIR MISSING"
done

# 3. planner.md rule 確認
grep -A5 "F005" "$PROJECT_ROOT/.claude/rules/planner.md" | head -15
```

## Expected Output

レポート形式:
- 指摘 0 件: `qa_decision: pass`
- 指摘あり: `qa_decision: fail` + 各指摘を issues_found に列挙

## Notes
- north_star: end-to-end 連携検証 + spec-first ルール遵守体制確立
- 細かい文言の好みは指摘しない (spec の acceptance_criteria を満たしていれば OK)
- copy 漏れ / テーブル破損 / 既存ファイル変更 のみ指摘対象
