---
phase: cmd_002
task_id: subtask_005
agent: engineer3
estimated_minutes: 8
depends_on: []
bloom_level: L2
---

# Task: engineer.md に specialist subagent dispatch ルール追記

## Goal
`.claude/rules/engineer.md` の Persona セクション (または適切なセクション) に、
specialist subagent dispatch ルールを追加する。

## Inputs
- 編集対象: `/Users/mizunomakoto/Project/makotoProj/ai_accelerate/agent-orchestra-makoto-mizuno/.claude/rules/engineer.md`

## Steps

1. `.claude/rules/engineer.md` を Read して現行構造を確認
2. `## Persona` セクションの直前または `## Autonomous Judgment Rules` の直前に以下のセクションを挿入:

```markdown
## Specialist Subagent Dispatch Rule

spec の作業領域が以下のいずれかに該当し、かつ bloom_level が L3 以上の場合、
engineer pane は Agent tool でその specialist subagent を dispatch して実行させること:

| 作業領域 | subagent | 場所 |
|----------|----------|------|
| フロントエンド (React/Vue/Next等) | frontend-engineer | ~/.claude/agents/ |
| バックエンド API / サービス | backend-engineer | ~/.claude/agents/ |
| インフラ / CI/CD / Docker | infrastructure-engineer | ~/.claude/agents/ |
| DB スキーマ / クエリ | db-engineer | ~/.claude/agents/ |
| Chrome 拡張 | chrome-extension-engineer | ~/.claude/agents/ |
| ネイティブ (iOS/Android/Electron) | native-app-engineer | ~/.claude/agents/ |
| ゲーム開発 | game-engineer | ~/.claude/agents/ |
| ML / AI / LLM | ml-engineer | ~/.claude/agents/ |
| テスト設計 / 実行 | qa-engineer | ~/.claude/agents/ |
| Claude Code 公式仕様確認 | claude-code-expert | .claude/agents/ |

**dispatch 不要ケース (Bloom L1-L2)**:
単純な copy / edit / rename / ファイル操作のみで判断不要な場合は dispatch しなくてよい。
spec の bloom_level field を判定基準とすること。

**dispatch 手順 (例)**:
```
Agent({
  subagent_type: "backend-engineer",
  description: "Implement REST API endpoint for task queue",
  prompt: "Read specs/2026-05-01-example/02-api.md and implement the described endpoint."
})
```
```

3. Edit ツールで正確に挿入する (既存行を変更しない)
4. Read で確認し、追加内容が正しく挿入されていることを検証する

## Verification
```bash
grep -n "Specialist Subagent Dispatch Rule" \
  /Users/mizunomakoto/Project/makotoProj/ai_accelerate/agent-orchestra-makoto-mizuno/.claude/rules/engineer.md
# Expected: セクション見出し行が表示される

grep -n "bloom_level" \
  /Users/mizunomakoto/Project/makotoProj/ai_accelerate/agent-orchestra-makoto-mizuno/.claude/rules/engineer.md
# Expected: dispatch ルール説明内に bloom_level 参照あり
```

## Notes
- 挿入箇所は `## Persona` セクションの直前が推奨 (file の上部に近いため読まれやすい)
- 完了後: `bash scripts/inbox_write.sh reviewer "Engineer 3 task complete (subtask_005). engineer dispatch rule added." report_received engineer3`
