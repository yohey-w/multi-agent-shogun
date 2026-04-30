---
phase: 2
task_id: 07-set-main-branch-protection
agent: manual (殿)
estimated_minutes: 3
depends_on: [01-create-fork]
---

# Task: GitHub の main ブランチ保護を設定

## Goal
直 push / force push を禁じ、PR ベースで main にマージする運用に切替。OSS 公開で外部コントリビュータが直接 main を壊せないようにする。

## Steps (殿が GitHub UI で実施)

1. `https://github.com/<殿>/agent-orchestra-makoto-mizuno/settings/branches` を開く
2. "Branch protection rules" → "Add branch ruleset" or 旧 UI なら "Add rule"
3. 設定:
   - **Branch name pattern**: `main`
   - ✅ Require a pull request before merging
     - ✅ Require approvals (1 名以上)
     - ✅ Dismiss stale pull request approvals when new commits are pushed
   - ✅ Require status checks to pass before merging (gitleaks 等の workflow が後で追加されたら有効化)
   - ✅ Require conversation resolution before merging
   - ✅ Block force pushes (絶対)
   - ✅ Block deletions (絶対)
   - ✅ Restrict pushes that create matching branches (force pushes 含む)
4. Save changes

## Expected Output
- main へ直 push 試行が拒否される
- force push も拒否
- PR 経由 + 1 approve 必須

## Verification
ローカルで試しに直 push:
```bash
git checkout main
echo "test" >> /tmp/dummy
git add /tmp/dummy 2>/dev/null
git commit --allow-empty -m "direct push test"
git push origin main
# Expected: ERROR (direct push not allowed)
git reset HEAD~1 --hard
```

## Notes
- 殿 1 人開発時の不便: 殿自身も直 push できなくなり、毎回 PR 作成 → self-approve が必要
- 緩和案: 「Allow specified actors to bypass required pull requests」で殿自身を bypass 許可リストに
- ただし OSS 公開時は厳格運用が望ましい (殿 bypass を OFF)
