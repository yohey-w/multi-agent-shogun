---
phase: 8
task_id: 02-end-to-end-validation
agent: planner (Haiku 可で各検査項目)
estimated_minutes: 10
depends_on: [01-test-planner-flow]
---

# Task: v2 完了基準 (overview §9) を全項目確認

## Goal
overview.md に書いた全 12 項目の完了基準を確認、v2 移行完了を宣言。

## Steps

各項目を検査:

```bash
echo "=== AC-1: GitHub repo ==="
gh repo view <殿>/agent-orchestra-makoto-mizuno --json name,visibility,licenseInfo
# Expected: PUBLIC + MIT

echo "=== AC-2: main branch protection ==="
gh api repos/<殿>/agent-orchestra-makoto-mizuno/branches/main/protection | jq '.required_pull_request_reviews'
# Expected: not null

echo "=== AC-3: pre-commit secret scan ==="
test -f .pre-commit-config.yaml && grep -q gitleaks .pre-commit-config.yaml && echo OK

echo "=== AC-4: User-level subagents (9 種) ==="
ls ~/.claude/agents/{frontend,backend,infrastructure,db,chrome-extension,native-app,game,ml,qa}-engineer.md 2>&1 | grep -c '^/Users'
# Expected: 9

echo "=== AC-5: Project-level subagents (3 種) ==="
ls .claude/agents/{planner,design-reviewer,code-reviewer}.md 2>&1 | grep -c '^\.claude'
# Expected: 3

echo "=== AC-6: memory/MEMORY.md + 12 agent.md ==="
ls memory/*.md | wc -l
# Expected: 14 (12 agents + MEMORY + agent-template)

echo "=== AC-7: SessionStart hook 作動 ==="
echo '{"agent":"planner"}' | bash .claude/hooks/session_start_inject_memory.sh | jq -e '.hookSpecificOutput.additionalContext' >/dev/null && echo OK

echo "=== AC-8: CLAUDE.md 戦国要素ゼロ ==="
grep -cE "戦国|家老|足軽|軍師|将軍" CLAUDE.md
# Expected: 0

echo "=== AC-9: legacy/ 削除済 ==="
test ! -d legacy && echo OK

echo "=== AC-10: hello-world テスト PASS ==="
cd projects/_v2_validation && npm test 2>&1 | tail -3
```

## Expected Output
- 全項目 OK
- 1 件でも NG なら該当 spec を再開、修正

## Verification
- スクリプト実行で全項目 OK 出力

## Notes
- これが通れば v2 移行完遂、殿に「v2 ready」を報告
- planner は memory/planner.md に「v2 移行で得た学び」を追記
- skills_pending.md を見て、移行作業中に提案された skill 候補を planner が review
