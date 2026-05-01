---
name: spec-haiku
description: >
  Generate a set of Haiku-grade task specs from a feature request or requirement.
  Use when the user says "spec を作って", "仕様を書いて", "Haiku spec を生成",
  "タスク分割して", "要件を spec 化", "spec 切って", "planner に spec 作らせて",
  "task breakdown", "spec out this feature", "break this into tasks",
  "この要件を spec に". Creates a dated directory under specs/ and populates it
  with individual task files, each assigned to the appropriate engineer subagent.
argument-hint: "<topic>  (e.g. user-auth-overhaul)"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
user-invocable: true
---

# /spec-haiku

## Purpose

殿の要件 (自然言語) を受け取り、`specs/YYYY-MM-DD-<topic>/` 配下に
Haiku 粒度の task spec 群を生成する。

"Haiku grade" = ファイル特定済み + 入出力明確 + 実行時間 5〜15 分程度。

## Usage

```
/spec-haiku <topic>
/spec-haiku user-auth-overhaul
/spec-haiku "payment gateway integration"
```

引数は topic 名 (ディレクトリ名のスラッグに使用)。
殿がその後で要件を話してくれれば良い (引数なしでも対話形式で受け付ける)。

## Behavior

### Step 1 — 日付とディレクトリ決定

```bash
TODAY=$(date +%Y-%m-%d)
TOPIC="${ARGUMENTS:-untitled}"
# スペース・特殊文字をハイフンに
SLUG=$(echo "${TOPIC}" | tr '[:upper:] ' '[:lower:]-' | sed 's/[^a-z0-9-]//g')
SPEC_DIR="specs/${TODAY}-${SLUG}"
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TARGET="${PROJECT_ROOT}/${SPEC_DIR}"
mkdir -p "${TARGET}"
echo "Spec directory: ${TARGET}"
```

### Step 2 — 要件の確認と対話

殿の要件が不明確な場合、以下の質問をして補完する (superpower: brainstorming 相当):

1. このタスクの **ゴール** は何か？
2. **影響範囲** はどのファイル・サービスか？
3. **担当 engineer** の割り当て案はあるか？
4. **優先度・緊急度** は？
5. **依存関係** (先に終わっている必要があるタスク) はあるか？

要件が明確なら Step 3 へ直行。

### Step 3 — タスク分割

以下の原則で Haiku grade に分割する：

- **1 task = 1 ファイル = 5〜15 分以内**
- **1 タスクに 1 担当 agent** (複数 engineer にまたがるなら分割)
- 依存関係が明確になるよう `depends_on` を設定
- phase 番号で実行順を制御 (phase 1 → 並列可、phase 2 → phase 1 完了後)

有効な agent 名:
- `frontend-engineer` — UI, CSS, React, Vue, SPA
- `backend-engineer` — API, サーバ処理, 認証, ビジネスロジック
- `infrastructure-engineer` — Docker, CI/CD, IaC, 監視, secrets
- `db-engineer` — スキーマ, migration, クエリ最適化
- `qa-engineer` — テスト計画, E2E, 品質保証
- `ml-engineer` — ML モデル, 推論, データパイプライン
- `chrome-extension-engineer` — ブラウザ拡張
- `native-app-engineer` — iOS/Android
- `game-engineer` — ゲームロジック

### Step 4 — spec ファイル生成

各 task に対して `${TARGET}/NN-<task-name>.md` を生成する。

ファイル命名規則: `01-`, `02-`, ... (2 桁ゼロパディング)

各 spec ファイルのフォーマット (CLAUDE.md §5 準拠):

```markdown
---
phase: <番号>
task_id: <NN>-<task-name>
agent: <subagent name>
estimated_minutes: <5-15>
depends_on: [<task_id>, ...]
---

# Task: <タイトル>

## Goal
<このタスクが達成すること 1〜3 文>

## Inputs
- <前提ファイル・データ・設定>
- <depends_on のタスクが生成する成果物>

## Steps
1. <具体的な手順 (Haiku grade: ファイル名まで明記)>
2. ...

## Expected Output
- <変更・作成されるファイル一覧>
- <確認可能な状態 (テスト通過, ログ出力等)>

## Verification
1. <コマンドまたは目視確認の手順>
2. ...

## Notes
- <実装上の注意、代替案、既知のリスク>
```

### Step 5 — overview ファイル生成

`${TARGET}/00-overview.md` を生成してトピック全体を俯瞰する:

```markdown
# Spec Overview: <TOPIC>

作成日: <TODAY>
ディレクトリ: <SPEC_DIR>

## 要件サマリ
<殿から受けた要件の 3〜5 行要約>

## タスク一覧

| task_id | agent | phase | depends_on | 分数 |
|---------|-------|-------|-----------|------|
| ...     | ...   | ...   | ...       | ...  |

## 実行順序

```
Phase 1 (並列可):
  - 01-... (frontend-engineer)
  - 02-... (backend-engineer)

Phase 2 (Phase 1 完了後):
  - 03-... (qa-engineer)
```

## Dispatch 方法

```
/dispatch-engineer 01-<task-name>
/dispatch-engineer 02-<task-name>
# Phase 1 完了後:
/dispatch-engineer 03-<task-name>
```
```

### Step 6 — 生成結果の報告

```
Spec 生成完了:
  ディレクトリ: specs/<date>-<topic>/
  生成ファイル数: N
  task 一覧:
    01-xxx  (frontend-engineer,  5 min, phase 1)
    02-xxx  (backend-engineer,  10 min, phase 1)
    03-xxx  (qa-engineer,       15 min, phase 2)

次のステップ:
  /dispatch-engineer 01-xxx  — Phase 1 から開始
```

## Quality Checks

生成した各 spec ファイルについて以下を確認してから殿に提出:

- [ ] frontmatter の全必須フィールドが揃っている
- [ ] `agent:` の値が有効な subagent 名
- [ ] `estimated_minutes` が 5〜15 の範囲
- [ ] Steps が具体的 (「ファイル A の関数 B を修正」レベル)
- [ ] Verification が実行可能 (コマンド or 目視手順)
- [ ] `depends_on` に循環がない

## Notes

- spec 生成後は自動 dispatch しない — 殿が `/dispatch-engineer` で明示的に起動する
- 不明な点は Step 2 の対話で解消してから spec を書く (曖昧なまま書かない)
- 既存 spec ディレクトリと topic が被る場合は連番サフィックスを付ける
  (例: `2026-04-30-auth-2/`)
- `archive-spec` skill で完了後にアーカイブできる
