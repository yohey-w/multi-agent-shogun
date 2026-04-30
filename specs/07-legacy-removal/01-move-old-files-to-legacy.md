---
phase: 7
task_id: 01-move-old-files-to-legacy
agent: planner (Haiku 可)
estimated_minutes: 5
depends_on: [06-claude-md-rewrite/01-write-claude-md-v2]
---

# Task: 旧戦国系ファイルを legacy/ に移動

## Goal
削除前の最終確認のため、旧戦国系資産を全て `legacy/` に移動。git mv で履歴維持。

## Steps
1. legacy ディレクトリ作成:
```bash
mkdir -p legacy
```

2. 移動対象 (戦国系一式):
```bash
git mv instructions legacy/instructions
git mv scripts legacy/scripts
git mv queue legacy/queue
git mv dashboard.md legacy/dashboard.md
# 既存 CLAUDE.md は新 CLAUDE.md に置き換わるので、旧 CLAUDE.md だけ legacy 化
# (Phase 6 で新規作成済前提、existing CLAUDE.md があれば legacy/CLAUDE-v1.md として保存)
[ -f CLAUDE.md ] && [ "$(head -1 CLAUDE.md)" != "# agent-orchestra-makoto-mizuno — CLAUDE.md" ] && git mv CLAUDE.md legacy/CLAUDE-v1.md
git mv config legacy/config 2>/dev/null || true
git mv requirements.txt legacy/requirements.txt 2>/dev/null || true
```

3. 旧 stop_hook 等の hook ファイルも legacy 化:
```bash
[ -f .claude/hooks/notify.sh ] && git mv .claude/hooks/notify.sh legacy/notify.sh
# session_start_inject_memory.sh と notify_dashboard_update.sh は v2 でも有用 → 残す
```

4. .gitignore で `legacy/` を ignore (Phase 2 で既に実施済の場合スキップ):
```bash
grep -q '^legacy/' .gitignore || echo 'legacy/' >> .gitignore
```

5. commit:
```bash
git add .gitignore
git commit -m "chore(v2): move legacy shogun assets to legacy/ for review before deletion"
```

## Expected Output
- `legacy/instructions/`, `legacy/scripts/`, `legacy/queue/`, `legacy/dashboard.md` などが存在
- main ツリー root に旧戦国系ディレクトリ消える
- git log で `git log --follow legacy/scripts/inbox_write.sh` で履歴追える

## Verification
```bash
ls legacy/
# Expected: instructions/ scripts/ queue/ dashboard.md (など)
ls instructions scripts queue dashboard.md 2>/dev/null
# Expected: 全て "No such file"
```

## Notes
- `git mv` で履歴を維持
- legacy/ は `.gitignore` で除外しているが、git tracking 中のファイルは引き続き履歴あり
- 完全削除は次の task (02-grep-secrets-then-delete) で実施
