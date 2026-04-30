---
phase: 7
task_id: 03-delete-legacy
agent: planner (Haiku 可、ただし削除前に殿確認)
estimated_minutes: 3
depends_on: [02-grep-secrets-in-legacy]
---

# Task: legacy/ ディレクトリを削除

## Goal
secret スキャン PASS 後、legacy/ を物理削除。git 履歴は残るので将来必要なら `git checkout <commit> -- legacy/` で復元可能。

## Steps

1. 削除前確認 (殿に提示):
```bash
echo "=== legacy contents (will be deleted) ==="
find legacy -maxdepth 2 -type f | head -30
echo "..."
echo "Total files: $(find legacy -type f | wc -l)"
echo ""
echo "Total size: $(du -sh legacy | cut -f1)"
```

2. **殿確認後** に削除:
```bash
git rm -r legacy
git commit -m "chore(v2): remove legacy shogun assets (secret scan passed, history preserved in git)"
```

## Expected Output
- legacy/ ディレクトリ消失
- 該当 commit が main に存在
- `git log --all -- legacy/scripts/inbox_write.sh` で過去履歴は引ける

## Verification
```bash
test ! -d legacy
git log --oneline | head -3
# Expected: 直近 commit が "chore(v2): remove legacy shogun assets"

# 履歴復元確認 (試しに復元 → 即削除)
git checkout HEAD~1 -- legacy/dashboard.md 2>/dev/null && {
  ls legacy/
  rm -rf legacy/
  echo "history retrievable: OK"
}
```

## Notes
- これで戦国系資産が main ツリーから完全消失
- git log/blame で過去は追えるので「移行前の状態を見たい」時は復元可能
- push する前に殿に最終確認、push 後に殿が「やっぱり戻したい」となれば revert で対応
