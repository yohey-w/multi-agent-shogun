---
phase: 8
task_id: 01-test-planner-flow
agent: planner (Haiku 可)
estimated_minutes: 15
depends_on: [07-legacy-removal/03-delete-legacy]
---

# Task: planner の dispatch フロー動作確認 (Hello World)

## Goal
v2 体制が「殿 → planner → engineer → reviewer → commit」のフルサイクルで動くことを最小プロジェクトで確認。

## Steps
1. テストプロジェクトディレクトリ作成:
```bash
mkdir -p projects/_v2_validation
cd projects/_v2_validation
git init
echo "# v2 validation" > README.md
git add README.md && git commit -m "init"
cd ../..
```

2. planner が以下のミニ要件を受け取る想定で spec を起こす:
   要件: "TypeScript で hello-world.ts を作って 'Hello, world!' を出力する。テスト付き。"

3. planner が `projects/_v2_validation/specs/2026-04-30-hello-world/` を作成し、以下の task を配置:
   - 01-init-package.md (agent: backend-engineer)
   - 02-write-hello-world.md (agent: backend-engineer)
   - 03-write-test.md (agent: qa-engineer)
   - 04-run-tests.md (agent: qa-engineer)

4. planner が Agent tool で backend-engineer dispatch:
```
Agent({
  subagent_type: "backend-engineer",
  description: "Init TS package",
  prompt: "Read projects/_v2_validation/specs/2026-04-30-hello-world/01-init-package.md and execute the steps. Report back with results."
})
```

5. backend-engineer が package.json + tsconfig.json + hello-world.ts を作成

6. planner が qa-engineer dispatch でテスト書き + 実行

7. planner が code-reviewer dispatch で commit 前レビュー

8. レビュー OK → commit

## Expected Output
- `projects/_v2_validation/` に hello-world 実装が完成
- テスト PASS
- planner が殿に「v2 フロー成功」を報告

## Verification
```bash
cd projects/_v2_validation
test -f hello-world.ts
test -f tests/hello-world.test.ts
npm test
# Expected: 全 PASS
git log --oneline | head -5
# Expected: backend-engineer / qa-engineer の commit が見える
```

## Notes
- このテストが完遂したら v2 移行の動作担保 OK
- 失敗 (各 agent が memory 読まない / spec 読まない / dispatch 動かない) → spec/設定を再修正
- 殿の手元で 1 回流すのが理想 (殿の承認的な意味でも)
