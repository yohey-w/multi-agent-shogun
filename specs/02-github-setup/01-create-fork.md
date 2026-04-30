---
phase: 2
task_id: 01-create-fork
agent: manual (殿)
estimated_minutes: 3
depends_on: []
---

# Task: GitHub に新リポ作成 (or 現リポを rename)

## Goal
新しい公開リポジトリ `agent-orchestra-makoto-mizuno` を作る。現 multi-agent-shogun の git 履歴は維持する。

## Inputs
- 殿の GitHub アカウント
- 現リポ: `multi-agent-shogun` (assumed Public か Private)

## Steps (どちらか1案を選ぶ)

### 案A: 現リポを rename
1. GitHub UI で現 `multi-agent-shogun` の Settings → Rename to `agent-orchestra-makoto-mizuno`
2. local の `git remote -v` 確認 → URL 自動転送設定されているが、`set-url` で明示更新:
```bash
cd /Users/mizunomakoto/Project/makotoProj/ai_accelerate/multi-agent-shogun
git remote set-url origin git@github.com:<殿>/agent-orchestra-makoto-mizuno.git
```

### 案B: 新リポ作成 + 履歴 push
1. GitHub UI で `agent-orchestra-makoto-mizuno` を Public + MIT で新規作成
2. local で remote 切替 + push:
```bash
git remote add new-origin git@github.com:<殿>/agent-orchestra-makoto-mizuno.git
git push new-origin main
```
3. 旧 multi-agent-shogun は archive or 残置 (殿判断)

## Expected Output
- GitHub に `agent-orchestra-makoto-mizuno` リポが Public で存在
- main ブランチに既存履歴が push 済

## Verification
```bash
gh repo view <殿>/agent-orchestra-makoto-mizuno --json name,visibility,licenseInfo
# Expected: name: "agent-orchestra-makoto-mizuno", visibility: "PUBLIC", licenseInfo: 後段でMIT追加するのでまだ null
```

## Notes
- 推薦は案A (rename): 履歴・star・watch 等を維持できる
- 殿のリポにはプライベート設定がある可能性 → Public 化要確認
- ローカルディレクトリ名 `multi-agent-shogun` は後で task `02-rename-local-dir.md` で変更
