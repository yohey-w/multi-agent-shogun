---
phase: 2
task_id: 02-rename-local-dir
agent: manual (殿)
estimated_minutes: 1
depends_on: [01-create-fork]
---

# Task: ローカルディレクトリを rename

## Goal
ローカルの `/Users/mizunomakoto/Project/makotoProj/ai_accelerate/multi-agent-shogun` を `agent-orchestra-makoto-mizuno` に rename。

## Steps
```bash
cd /Users/mizunomakoto/Project/makotoProj/ai_accelerate/
mv multi-agent-shogun agent-orchestra-makoto-mizuno
cd agent-orchestra-makoto-mizuno
```

## Expected Output
- ディレクトリ rename 完了
- 中身は変わらない (git 履歴・全ファイル維持)

## Verification
```bash
ls -d /Users/mizunomakoto/Project/makotoProj/ai_accelerate/agent-orchestra-makoto-mizuno
# Expected: ディレクトリ存在
ls -d /Users/mizunomakoto/Project/makotoProj/ai_accelerate/multi-agent-shogun 2>/dev/null
# Expected: ディレクトリ無し
git -C /Users/mizunomakoto/Project/makotoProj/ai_accelerate/agent-orchestra-makoto-mizuno log --oneline -3
# Expected: 既存 commit が見える
```

## Notes
- 殿が tmux session を別で開いている場合、cwd が古いパスのままだと `cd` 失敗する。新シェルで開き直す
- Claude Code の auto-memory directory も `~/.claude/projects/-Users-...-multi-agent-shogun/memory/` だが、Claude Code 起動時に新パス基準で再生成される (古い memory.md は手動コピー要)
