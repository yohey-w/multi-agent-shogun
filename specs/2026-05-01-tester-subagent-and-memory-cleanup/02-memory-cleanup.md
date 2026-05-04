---
phase: cmd_002
task_id: subtask_004
agent: engineer2
estimated_minutes: 15
depends_on: []
bloom_level: L3
---

# Task: memory/ ディレクトリ削除 + パス参照更新

## Goal
cmd_001 で agent-memory/ への配布が完了した memory/ を git rm で削除し、
hooks・rules・CLAUDE.md の `memory/` パス参照を `agent-memory/` ベースに更新する。

## Pre-check (必ず実行)

```bash
PROJECT_ROOT="/Users/mizunomakoto/Project/makotoProj/ai_accelerate/agent-orchestra-makoto-mizuno"
cd "$PROJECT_ROOT"

# memory/ 参照箇所を全列挙 (agent-memory は除外)
grep -rn "memory/" .claude/hooks/ scripts/ .claude/rules/ .claude/agents/ CLAUDE.md 2>/dev/null \
  | grep -v "agent-memory" | grep -v ".git/"
```

## Steps

### Step 1: session_start_inject_memory.sh の更新

現在: `memory/MEMORY.md` / `memory/${agent}.md`
変更後: agent の種類によって以下を参照

```bash
# .claude/hooks/session_start_inject_memory.sh を Edit で以下に置換:
```

変更内容 (lines 27-28 付近):
```bash
# 旧:
# mem_index="memory/MEMORY.md"
# mem_file="memory/${agent}.md"

# 新:
# Project-level agents (in .claude/agents/<agent>/agent-memory/)
project_agents="planner design-reviewer code-reviewer claude-code-expert tester"
project_dir=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

if echo "$project_agents" | grep -qw "$agent"; then
  mem_base="${project_dir}/.claude/agents/${agent}/agent-memory"
else
  mem_base="${HOME}/.claude/agents/${agent}/agent-memory"
fi

mem_index="${mem_base}/MEMORY.md"
mem_file="${mem_base}/${agent}.md"
```

### Step 2: post_engineer.sh の更新

対象: `.claude/hooks/post_engineer.sh` lines 36 / 45

```bash
# 旧:
# mem_file="${project_dir}/memory/${agent_name}.md"

# 新 (project-level agentsは .claude/agents/, それ以外は ~/.claude/agents/):
project_agents="planner design-reviewer code-reviewer claude-code-expert tester"
if echo "$project_agents" | grep -qw "$agent_name"; then
  mem_file="${project_dir}/.claude/agents/${agent_name}/agent-memory/${agent_name}.md"
else
  mem_file="${HOME}/.claude/agents/${agent_name}/agent-memory/${agent_name}.md"
fi
```

### Step 3: CLAUDE.md の参照更新

CLAUDE.md に複数の `memory/<agent>.md` / `memory/MEMORY.md` 言及がある。
以下のように更新 (ドキュメント内の記述なので、新パスを示す形で更新):

対象行の例:
- `memory/MEMORY.md` → `.claude/agents/<agent>/agent-memory/MEMORY.md`
- `memory/<agent>.md` → `agent-memory/<agent>.md` (または `.claude/agents/<agent>/agent-memory/<agent>.md`)
- `memory/claude-code-expert.md` → `.claude/agents/claude-code-expert/agent-memory/claude-code-expert.md`

※ CLAUDE.md は長大なため、grep で特定した行のみ Edit で更新すること。
※ `memory:` フィールド名 (frontmatter の `memory: project`) は変更不要 (パスではなくキーワード)。

### Step 4: git rm で memory/ を削除

```bash
cd /Users/mizunomakoto/Project/makotoProj/ai_accelerate/agent-orchestra-makoto-mizuno
git rm -r memory/
```

D001-D008 遵守: `rm -rf` 禁止。必ず `git rm` を使う。

### Step 5: Verification

```bash
cd /Users/mizunomakoto/Project/makotoProj/ai_accelerate/agent-orchestra-makoto-mizuno

# memory/ が削除されていること
test ! -d memory/ && echo "PASS: memory/ deleted" || echo "FAIL: memory/ still exists"

# 壊れた参照がないこと (agent-memory 除外)
broken=$(grep -rn "memory/" .claude/hooks/ scripts/ .claude/rules/ .claude/agents/ CLAUDE.md 2>/dev/null \
  | grep -v "agent-memory" | grep -v ".git/" | grep -v "memory: project" | grep -v "^--$")
if [ -z "$broken" ]; then
  echo "PASS: no broken memory/ references"
else
  echo "FAIL: remaining references:"
  echo "$broken"
fi
```

## Expected Output
- `memory/` ディレクトリが存在しない
- `.claude/hooks/session_start_inject_memory.sh` が agent-memory/ パスを参照
- `.claude/hooks/post_engineer.sh` が agent-memory/ パスを参照
- `CLAUDE.md` の参照が新パスに更新 (または意図的なコメントのみ残存)
- grep チェック PASS

## Notes
- `memory: project` フィールド名はフロントマターのキーワードなので変更不要
- CLAUDE.md の変更は最小限に (docs の雰囲気を壊さない範囲で)
- 完了後: `bash scripts/inbox_write.sh reviewer "Engineer 2 task complete (subtask_004). memory/ deleted." report_received engineer2`
