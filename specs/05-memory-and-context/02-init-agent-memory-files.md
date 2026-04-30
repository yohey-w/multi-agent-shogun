---
phase: 5
task_id: 02-init-agent-memory-files
agent: planner (Haiku 可)
estimated_minutes: 5
depends_on: [01-memory-md-structure]
---

# Task: 各 agent の memory ファイルを初期化

## Goal
12 agent (planner, design-reviewer, code-reviewer + 9 engineer) 全員分の memory ファイルを `memory/agent-template.md` をベースに作成。

## Steps
```bash
TEMPLATE=memory/agent-template.md
AGENTS=(planner design-reviewer code-reviewer frontend-engineer backend-engineer infrastructure-engineer db-engineer chrome-extension-engineer native-app-engineer game-engineer ml-engineer qa-engineer)

for agent in "${AGENTS[@]}"; do
  out="memory/${agent}.md"
  if [ -f "$out" ]; then
    echo "skip: $out (exists)"
    continue
  fi
  sed "s/<agent-name>/${agent}/g" "$TEMPLATE" > "$out"
  echo "created: $out"
done
```

2. 確認:
```bash
ls memory/*.md | head -20
```

3. commit:
```bash
git add memory/*.md
git commit -m "feat(v2): initialize memory files for all 12 agents"
```

## Expected Output
- 12 個の `memory/<agent>.md` が存在
- 内容は template ベース (各 agent の役割パートはまだ空、作業ごとに育つ)

## Verification
```bash
ls memory/ | grep -c '\.md$'
# Expected: 14 (12 agents + MEMORY.md + agent-template.md)
```

## Notes
- 空のテンプレで初期化、作業ごとに更新される
- 各 subagent が初回起動時に「このプロジェクトでの役割」段落を埋めるよう、agent 定義に instruction が含まれている (specs/03/04 で定義済)
