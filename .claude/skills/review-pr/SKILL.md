---
name: review-pr
description: >
  Run a full design + code review chain on the current branch or a specified PR.
  Use when the user says "PR をレビューして", "review this PR", "コードレビュー
  して", "設計レビューして", "design review", "code review", "マージ前に確認",
  "review before merge", "レビューを回して", "review chain を起動", "PR #NNN を
  見て", "diff をレビュー". Forks the worktree, runs design-reviewer then
  code-reviewer in sequence, and produces a consolidated review report.
argument-hint: "<branch-or-pr-number>  (e.g. feature/auth  or  42)"
allowed-tools:
  - Read
  - Bash
  - Agent
  - Glob
  - Edit
  - Write
user-invocable: true
context: fork
agent: code-reviewer
---

# /review-pr

## Purpose

設計レビュー (design-reviewer) とコードレビュー (code-reviewer) を順番に
実行し、マージ前の品質ゲートとして機能する。

`context: fork` により git worktree を分離して実行するため、レビュー中に
作業ブランチが汚染されない。

## Usage

```
/review-pr                          # 現在のブランチを base (main) と比較
/review-pr feature/user-auth        # 特定ブランチを指定
/review-pr 42                       # GitHub PR 番号を指定 (gh CLI 必要)
```

## Behavior

### Step 1 — 対象ブランチとベースの決定

```bash
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
ARG="${ARGUMENTS}"

if [ -z "${ARG}" ]; then
  TARGET_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  BASE_BRANCH=$(git remote show origin 2>/dev/null | grep "HEAD branch" | awk '{print $NF}' || echo "main")
elif echo "${ARG}" | grep -qE '^[0-9]+$'; then
  # PR 番号の場合
  echo "Fetching PR #${ARG} info..."
  PR_INFO=$(gh pr view "${ARG}" --json headRefName,baseRefName 2>/dev/null)
  TARGET_BRANCH=$(echo "${PR_INFO}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['headRefName'])")
  BASE_BRANCH=$(echo "${PR_INFO}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['baseRefName'])")
else
  TARGET_BRANCH="${ARG}"
  BASE_BRANCH="main"
fi

echo "Review target: ${TARGET_BRANCH} vs ${BASE_BRANCH}"
```

### Step 2 — diff と変更ファイルの取得

```bash
# 変更ファイル一覧
CHANGED_FILES=$(git diff --name-only "${BASE_BRANCH}...${TARGET_BRANCH}" 2>/dev/null \
  || git diff --name-only HEAD~1)

# diff 本体 (コンテキスト 5 行)
DIFF_CONTENT=$(git diff -U5 "${BASE_BRANCH}...${TARGET_BRANCH}" 2>/dev/null \
  || git diff -U5 HEAD~1)

# 統計
STATS=$(git diff --stat "${BASE_BRANCH}...${TARGET_BRANCH}" 2>/dev/null \
  || git diff --stat HEAD~1)

echo "Changed files:"
echo "${CHANGED_FILES}"
echo ""
echo "Stats:"
echo "${STATS}"
```

### Step 3 — design-reviewer を起動

Agent tool で design-reviewer を呼び出し、アーキテクチャ・セキュリティ方針の
事前レビューを実施する。

**design-reviewer への prompt:**

```
設計レビューを実施してください。

## レビュー対象
ブランチ: <TARGET_BRANCH>
ベース: <BASE_BRANCH>

## 変更ファイル
<CHANGED_FILES>

## diff
<DIFF_CONTENT>

## レビュー観点
1. アーキテクチャ設計の妥当性 (責務分離、レイヤー構成)
2. セキュリティ方針 (認証・認可、入力検証、secret 露出)
3. データフロー・API 設計の一貫性
4. 既存設計との整合性
5. 将来の拡張性・保守性

## 出力形式
- PASS / CONDITIONAL_PASS / FAIL の判定
- 問題点リスト (severity: critical / major / minor)
- 推奨事項リスト
- CONDITIONAL_PASS / FAIL の場合は必須修正事項を明示
```

### Step 4 — design-reviewer の結果確認

design-reviewer が FAIL を返した場合:
- 殿にレポートを提示
- code-reviewer を続行するか確認
- 殿の指示がなければ中断し、設計修正を促す

design-reviewer が PASS または CONDITIONAL_PASS の場合:
- Step 5 へ進む

### Step 5 — code-reviewer を起動

Agent tool で code-reviewer を呼び出し、実装細部を確認する。

**code-reviewer への prompt:**

```
コードレビューを実施してください。

## レビュー対象
ブランチ: <TARGET_BRANCH>
ベース: <BASE_BRANCH>

## 設計レビュー結果サマリ
<design-reviewer の結果 (判定 + 主要指摘)>

## 変更ファイル
<CHANGED_FILES>

## diff
<DIFF_CONTENT>

## レビュー観点
1. バグ・ロジックエラー
2. セキュリティ脆弱性 (OWASP Top 10 相当)
3. パフォーマンス問題 (N+1, 無駄な処理)
4. テストカバレッジの妥当性
5. コーディング規約準拠
6. エラーハンドリング漏れ
7. 型安全性・null safety
8. 秘密情報のハードコード

## 出力形式
- PASS / NEEDS_WORK の判定
- 指摘リスト (severity: blocking / major / suggestion)
- blocking 指摘がある場合は必ず NEEDS_WORK
- approve メッセージ (PASS 時)
```

### Step 6 — 統合レポートの生成

両レビュアーの結果を統合して殿に報告する。

```markdown
## Review Report

### 対象
- Branch: <TARGET_BRANCH> vs <BASE_BRANCH>
- 変更ファイル数: N
- 日時: <timestamp>

### 設計レビュー (design-reviewer)
判定: <PASS / CONDITIONAL_PASS / FAIL>

<指摘事項リスト>

### コードレビュー (code-reviewer)
判定: <PASS / NEEDS_WORK>

<指摘事項リスト>

### 総合判定
<APPROVE / REQUEST_CHANGES>

### 必須修正事項
1. ...
2. ...

### 推奨事項
- ...
```

## Error Handling

| 状況 | 対処 |
|------|------|
| git 操作失敗 | エラーメッセージと共に停止、ブランチ名を確認するよう促す |
| gh CLI が使えない (PR 番号指定時) | `gh` コマンドが不要な方法で代替、もしくはブランチ名での指定を促す |
| design-reviewer が FAIL | 殿に提示して中断、修正後に再実行を促す |
| diff が極端に大きい (>5000 行) | PR を分割するよう警告し、重要ファイルのみに絞ったレビューを提案 |

## Notes

- `context: fork` により worktree を分けるため、メインの作業コンテキストは汚染されない
- design-reviewer は `.claude/agents/design-reviewer.md` のシステムプロンプトを使用
- code-reviewer は `.claude/agents/code-reviewer.md` のシステムプロンプトを使用
- PR マージの実行はこの skill の範囲外 — 殿が手動で行う
- 継続的インテグレーションに組み込む場合は `PreToolUse` hook 経由で自動起動可
