---
name: init-project
description: >
  Initialize a new project scaffold under the projects/ directory. Use when the
  user says "新しいプロジェクトを作って", "project を初期化して", "init project",
  "プロジェクト雛形を作成", "projects/ に新しいプロジェクト", "scaffold new
  project", "project setup", "プロジェクト骨格を作って", "start new project",
  "create project boilerplate". Creates a git-initialized directory with README,
  CLAUDE.md, .gitignore, and a basic directory structure.
argument-hint: "<name>  (e.g. my-api-service)"
allowed-tools:
  - Read
  - Write
  - Bash
  - Edit
user-invocable: true
---

# /init-project

## Purpose

`projects/<name>/` 配下に最小限のプロジェクト雛形を作成し、
git init + 基本設定ファイルを配置する。

`projects/` は gitignore されているため、機密プロジェクトを安全に格納できる。

## Usage

```
/init-project my-api-service
/init-project "payment-gateway"
/init-project frontend-dashboard
```

## Behavior

### Step 1 — 入力検証とパス決定

```bash
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
NAME="${ARGUMENTS}"

if [ -z "${NAME}" ]; then
  echo "ERROR: project name is required"
  echo "Usage: /init-project <name>"
  exit 1
fi

# 安全なディレクトリ名に正規化 (スペース → ハイフン、特殊文字除去)
SAFE_NAME=$(echo "${NAME}" | tr '[:upper:] ' '[:lower:]-' | sed 's/[^a-z0-9-_]//g')

TARGET="${PROJECT_ROOT}/projects/${SAFE_NAME}"

if [ -d "${TARGET}" ]; then
  echo "ERROR: projects/${SAFE_NAME}/ already exists"
  ls -la "${TARGET}/"
  exit 1
fi

# projects/ ディレクトリが存在しない場合は作成
mkdir -p "${PROJECT_ROOT}/projects"

mkdir -p "${TARGET}"
echo "Creating project: ${TARGET}"
```

### Step 2 — git 初期化

```bash
cd "${TARGET}"
git init
git config user.email "makotodevmail@gmail.com"
git config user.name "Makoto Mizuno"
echo "git initialized"
```

### Step 3 — ディレクトリ構造の作成

```bash
# 標準ディレクトリ
mkdir -p "${TARGET}/src"
mkdir -p "${TARGET}/tests"
mkdir -p "${TARGET}/docs"
mkdir -p "${TARGET}/.claude"

# .gitkeep で空ディレクトリをトラック
touch "${TARGET}/src/.gitkeep"
touch "${TARGET}/tests/.gitkeep"
touch "${TARGET}/docs/.gitkeep"
```

### Step 4 — `.gitignore` の生成

```
# .gitignore
# Dependencies
node_modules/
__pycache__/
*.pyc
.venv/
venv/
dist/
build/
*.egg-info/

# Environment & secrets
.env
.env.*
!.env.example
*.secret
*.key
*.pem

# IDE
.vscode/settings.json
.idea/
*.swp
*.swo
.DS_Store

# Logs
*.log
logs/

# Test coverage
.coverage
htmlcov/
.pytest_cache/
coverage/

# Temporary
*.tmp
*.bak
tmp/
```

### Step 5 — `README.md` の生成

```markdown
# <NAME>

> プロジェクト説明をここに記入

## セットアップ

```bash
# 依存パッケージのインストール (言語・フレームワークに応じて変更)
# npm install / pip install -r requirements.txt / etc.
```

## 開発

```bash
# 開発サーバ起動
# npm run dev / python -m uvicorn src.main:app --reload / etc.
```

## テスト

```bash
# テスト実行
# npm test / pytest / etc.
```

## デプロイ

TBD

## ライセンス

MIT License — Copyright (c) 2026 Makoto Mizuno
```

### Step 6 — `CLAUDE.md` の生成

```markdown
# <NAME> — CLAUDE.md

## プロジェクト概要

<プロジェクトの目的と技術スタックをここに記入>

## ディレクトリ構造

```
<NAME>/
├── src/          # ソースコード
├── tests/        # テストコード
├── docs/         # ドキュメント
├── .claude/      # Claude Code 設定
├── .gitignore
├── README.md
└── CLAUDE.md     # this file
```

## 開発ルール

1. `src/` 内の変更は必ず `tests/` にテストを追加する
2. 秘密情報 (.env) を commit しない
3. PR 前に `/review-pr` でレビューを通す

## 関連リソース

- 親プロジェクト: agent-orchestra-makoto-mizuno
- Specs: ../../specs/
```

### Step 7 — `.claude/settings.json` の生成

```json
{
  "permissions": {
    "deny": [
      "Bash(rm -rf *)",
      "Bash(curl * | bash)",
      "Bash(sudo *)"
    ]
  }
}
```

### Step 8 — 初回 commit

```bash
cd "${TARGET}"
git add .
git commit -m "feat: initialize project scaffold

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
echo "Initial commit created"
```

### Step 9 — 完了報告

```
Project initialized:

  Path:    projects/<SAFE_NAME>/
  Git:     initialized (1 commit)

  Structure:
    src/
    tests/
    docs/
    .claude/settings.json
    .gitignore
    README.md
    CLAUDE.md

次のステップ:
  1. README.md にプロジェクト概要を記入
  2. CLAUDE.md の「プロジェクト概要」を更新
  3. 技術スタックに応じて依存管理ファイルを追加
     (package.json / pyproject.toml / Cargo.toml 等)
  4. spec を切る場合: /spec-haiku <name>
```

## Safety Rules

- `projects/` 外には一切ファイルを作成しない
- 既存ディレクトリと同名の場合はエラーで停止 (上書き禁止)
- `git config` は対象ディレクトリ内のローカル設定のみ変更 (グローバル設定は変更しない)
- `projects/` 自体が存在しない場合は `mkdir -p` で作成する
  (`.gitignore` で既に除外済みのはずだが、未存在でもエラーにしない)

## Notes

- `projects/` は親リポジトリの `.gitignore` に含まれているため
  機密プロジェクトを安全に格納できる
- subproject 内の CLAUDE.md は親 CLAUDE.md の walk-up とは独立して動作する
- フレームワーク固有の雛形 (Next.js, FastAPI 等) は engineer が対応する
  この skill はフレームワーク非依存の最小骨格を提供するのみ
