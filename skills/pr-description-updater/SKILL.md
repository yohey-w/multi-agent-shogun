---
name: pr-description-updater
description: |
  Make sure to use this skill whenever the user asks to update a PR description, write PR body, or format PR changes for s-fit-core (「PR Description更新」「PRの説明欄更新」「PR body作成」「PR変更内容整理」).

  s-fit-coreのPR説明欄（Description）を変更内容に基づいてカテゴリ分類し、過去PRのフォーマットを踏襲して更新する。

  Key capabilities: (1) gh pr diffで変更内容把握 (2) 機能追加/バグ修正/リファクタリング・保守のカテゴリ分類 (3) 過去PR(#1163,#1172,#1175)のフォーマット踏襲 (4) gh pr edit/REST APIでDescription更新 (5) 関連チケット(Backlog/JIRA)リンク抽出
version: 1.0.0
---

# PR Description Updater

s-fit-coreのPR説明欄（Description）を変更内容に基づいてカテゴリ分類し、過去PRのフォーマットに準拠して更新するスキル。

## 前提条件

- リポジトリ: `initial-engine/s-fit-core`
- 記述言語: ビジネス日本語（外部公開場所のため戦国口調禁止）
- `gh` コマンドが認証済みであること

---

## 手順

### Step 1: 過去PRのフォーマット確認

```bash
gh pr view 1172 --repo initial-engine/s-fit-core --json body -q '.body'
```

必要に応じて他のPRも確認する:

```bash
gh pr view 1163 --repo initial-engine/s-fit-core --json body -q '.body'
gh pr view 1175 --repo initial-engine/s-fit-core --json body -q '.body'
```

### Step 2: 対象PRの現状確認

```bash
gh pr view {PR番号} --repo initial-engine/s-fit-core
```

タイトル・ベースブランチ・ターゲットブランチを確認する。

### Step 3: 変更内容の把握

```bash
# ファイル変更サマリー
gh pr diff {PR番号} --repo initial-engine/s-fit-core --stat

# 詳細差分
gh pr diff {PR番号} --repo initial-engine/s-fit-core
```

コミット履歴から関連PR番号・チケットIDを抽出する:

```bash
gh pr view {PR番号} --repo initial-engine/s-fit-core --json commits -q '.commits[].messageHeadline'
```

### Step 4: Description作成

過去PRフォーマットに準拠して以下の構成で作成する:

```markdown
# 概要
{ベースブランチ}から{ターゲットブランチ}への定期マージです。{主要変更の要約}。

# {日付（例: 2026-03-18）}
## 変更内容

### 機能追加
- **{機能名}**（#{PR番号} / {チケットID}）: {1行説明}

### バグ修正
- **{修正内容}**（#{PR番号} / {チケットID}）: {1行説明}

### リファクタリング・保守
- **{内容}**（#{PR番号}）: {1行説明}

## 影響範囲
- 変更ファイル数: {N} files
- 追加: +{N}行 / 削除: -{N}行
- 主な変更領域: {領域（例: app/Http/Controllers, resources/js 等）}

## 関連チケット
### Backlog チケット（IE_SFIT）
- [IE_SFIT-{N}](https://initial-engine.backlog.com/view/IE_SFIT-{N}) (#{PR番号}) - {概要}

### JIRA チケット（SFITDIP）
- [SFITDIP-{N}](https://initial-engine.atlassian.net/browse/SFITDIP-{N}) (#{PR番号}) - {概要}
```

### Step 5: Descriptionの更新

#### 通常（gh pr edit）

```bash
gh pr edit {PR番号} --repo initial-engine/s-fit-core --body "..."
```

#### GraphQLエラーが発生する場合: REST API直接更新

```bash
gh api repos/initial-engine/s-fit-core/pulls/{PR番号} -X PATCH -f body="..."
```

### Step 6: 更新内容の確認

```bash
gh pr view {PR番号} --repo initial-engine/s-fit-core --json body -q '.body'
```

Description が意図した内容で保存されていることを確認する。

---

## カテゴリ分類のルール

| カテゴリ | 対象 |
|----------|------|
| 機能追加 | 新規画面、新規APIエンドポイント、新規コンポーネント |
| バグ修正 | SFITDIP-* チケット対応、既存機能の不具合修正 |
| リファクタリング・保守 | Seeder修正、テスト追加、死コード削除、型修正、パフォーマンス改善 |

分類が曖昧な場合は「リファクタリング・保守」に含める。

---

## 注意事項

- **1行=1PRの粒度**で記載する（複数PRを1行にまとめない）
- **自PRへの参照（#{自分のPR番号}）は記載しない**
- コミット履歴から関連PR番号・チケットIDを正確に抽出する。推測で記載しない
- 該当カテゴリに変更がない場合はそのセクション自体を省略する
- 関連チケットが存在しない場合は「関連チケット」セクションを省略する

## よくあるエラーと対処

| エラー | 原因 | 対処 |
|--------|------|------|
| `gh pr edit` でGraphQLエラー | body文字列が長い・特殊文字含む | `gh api` REST API経由に切り替える |
| コミットメッセージにPR番号なし | スカッシュマージ等でリンクが消えた | `gh pr list --repo initial-engine/s-fit-core --state merged` で検索 |
| チケットIDが不明 | コミットに記載なし | Descriptionの該当行にチケットIDを記載しない（無理に補完しない） |
