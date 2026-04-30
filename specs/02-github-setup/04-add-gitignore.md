---
phase: 2
task_id: 04-add-gitignore
agent: planner (Haiku 可)
estimated_minutes: 3
depends_on: [02-rename-local-dir]
---

# Task: .gitignore を整備して機密漏洩を防ぐ

## Goal
リポ root の `.gitignore` を v2 用に書き換え (or 既存に追記)、secret / 個人情報 / 環境固有データを git push から除外。

## Steps
1. 既存 .gitignore があれば Read。
2. 以下を含む .gitignore を最終形として書く:

```gitignore
# Python
__pycache__/
*.pyc
.venv/
venv/

# Node
node_modules/
dist/
.next/
.cache/

# OS
.DS_Store
Thumbs.db

# IDE
.idea/
.vscode/
*.swp
*~

# Secrets / env
.env
.env.*
!.env.example
*.pem
*.key
*.crt
secrets/

# Claude Code session-local
.claude/settings.local.json

# Project secrets (legacy も含む)
projects/                    # Lord-defined: contains secrets, gitignored
.cdp-chrome-profile/         # CDP Chrome user data (殿のローカル)
~/.cdp-chrome-profile        # 念の為

# v2 移行中の作業ディレクトリ
legacy/                      # Phase 7 で削除予定、push しない

# auto-memory (User-level、project に持ち込まない)
.claude/projects/

# misc
*.log
*.tmp
.tmp/
/tmp/claude/                 # claude code 用 tmp
```

3. commit:
```bash
git add .gitignore
git commit -m "chore: gitignore for OSS publication (secrets/env/legacy excluded)"
```

## Verification
```bash
git check-ignore .env projects/anything legacy/anything 2>/dev/null
# Expected: それぞれパスが echo される (= ignored 確認)
```

## Notes
- `legacy/` は Phase 7 で物理削除するので git push 対象外
- `projects/` は CLAUDE.md にも「git-ignored、外部プロジェクト固有」と記載あり、絶対に push 禁止
- 既存の `.gitignore` が他に固有エントリ持ってたらマージで残す
