---
name: memory-curate
description: >
  Manually curate and trim an agent's memory file to within 200 lines. Use when
  the user says "memory を整理して", "memory をキュレートして", "memory が長すぎる",
  "memory の整理", "curate memory", "memory を圧縮", "古い学びをアーカイブ",
  "memory-curate", "agent の記憶を整理", "memory ファイルを 200 行以内に",
  "memory cleanup". Reads the specified agent's memory file, distills the most
  important learnings, archives older entries, and rewrites the file concisely.
argument-hint: "<agent-name>  (e.g. backend-engineer)"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
user-invocable: true
---

# /memory-curate

## Purpose

指定された engineer agent の `memory/<agent-name>.md` を読み込み、
Claude が推論してコンテンツを整理・圧縮し、200 行以内に収める。

古い・重複した学びは `memory/archive/YYYY-MM/<agent>-<timestamp>.md` へ退避。

## Usage

```
/memory-curate backend-engineer
/memory-curate frontend-engineer
/memory-curate planner
/memory-curate infrastructure-engineer
```

## Behavior

### Step 1 — 対象ファイルの確認

```bash
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
AGENT_NAME="${ARGUMENTS}"
MEMORY_FILE="${PROJECT_ROOT}/memory/${AGENT_NAME}.md"
ARCHIVE_DIR="${PROJECT_ROOT}/memory/archive"
TODAY=$(date +%Y-%m-%d)
MONTH=$(date +%Y-%m)

if [ -z "${AGENT_NAME}" ]; then
  echo "ERROR: agent name is required"
  echo "Available agents:"
  ls "${PROJECT_ROOT}/memory/"*.md | xargs -I{} basename {} .md | grep -v "MEMORY\|agent-template\|skills_pending"
  exit 1
fi

if [ ! -f "${MEMORY_FILE}" ]; then
  echo "ERROR: memory file not found: ${MEMORY_FILE}"
  exit 1
fi

LINE_COUNT=$(wc -l < "${MEMORY_FILE}")
echo "Current: ${MEMORY_FILE} (${LINE_COUNT} lines)"
```

### Step 2 — 現在のコンテンツを Read

Read tool で `memory/<agent-name>.md` の全内容を取得し、
以下の観点で分析する:

**保持すべき情報 (キープ)**
- このプロジェクト固有の暗黙のルール
- 繰り返し役立つパターン・解決策
- 直近 3 ヶ月の重要な学び
- 「次に着手する時のヒント」セクション
- 将来のタスクに影響する未解決の問題

**アーカイブすべき情報**
- 特定タスクの詳細な実行ログ (task_id + 日付のみ残す)
- 3 ヶ月以上前の古い学び (価値が下がっている)
- 重複した内容 (同じ学びが複数箇所に書いてある)
- 既に解決済みの一時的な問題
- コード conventions / file paths (コードを読めば分かる — CLAUDE.md §8)

### Step 3 — 整理方針の殿への提示

Read した内容を分析後、以下の形式で殿に方針を提示する:

```
memory/<agent-name>.md の整理方針:

現在: <N> 行
目標: 200 行以内

保持:
  - <セクション名>: 現 N 行 → 整理後 M 行 (理由)
  - ...

アーカイブ:
  - <内容の説明>: <N> 行 (理由: 古い/重複/一時的)
  - ...

整理後推定: <推定行数> 行

続行しますか？
```

殿が確認した場合は Step 4 へ進む。

### Step 4 — アーカイブファイルの生成

アーカイブ対象の内容を `memory/archive/YYYY-MM/<agent>-<timestamp>.md` に書き出す。

```bash
mkdir -p "${ARCHIVE_DIR}/${MONTH}"
ARCHIVE_FILE="${ARCHIVE_DIR}/${MONTH}/${AGENT_NAME}-${TODAY}.md"
```

Write tool でアーカイブファイルに以下の形式で書き込む:

```markdown
# Archive: <agent-name> memory (curated <TODAY>)

元ファイル: memory/<agent-name>.md
アーカイブ日: <TODAY>
アーカイブ理由: memory-curate による整理

---

<アーカイブ対象の内容をそのまま保存>
```

### Step 5 — memory ファイルの書き直し

アーカイブ後、`memory/<agent-name>.md` を以下の標準構造で書き直す:

```markdown
# <agent-name> Memory (このプロジェクト用)

## このプロジェクトでの役割
<1-2 段落、このエージェントが担当する範囲と期待される仕事>

## 学習履歴
<最近 3 ヶ月 + 重要なもののみ、各行 1 エントリ>
- [YYYY-MM-DD] task_id=xxx: <1 行サマリ>
- ...

## 過去のミスと回避策
<繰り返さないべき失敗と対処法>
- <ミスの説明>: <回避策>
- ...

## 暗黙のルール (このプロジェクト固有)
<このプロジェクトならではの制約・慣例>
- ...

## 次に着手する時のヒント
<次回起動時に最初に確認すべきこと>
- ...
```

内容は **要約・統合** する (同じ学びは 1 エントリにまとめる)。

### Step 6 — 行数の確認

```bash
NEW_COUNT=$(wc -l < "${MEMORY_FILE}")
echo "After curation: ${NEW_COUNT} lines"

if [ "${NEW_COUNT}" -gt 200 ]; then
  echo "WARNING: still over 200 lines. Consider further reduction."
fi
```

### Step 7 — 完了報告

```
memory-curate 完了:

  対象: memory/<agent-name>.md
  整理前: <BEFORE> 行
  整理後: <AFTER> 行
  削減率: <PERCENT>%

  アーカイブ先: memory/archive/<YYYY-MM>/<agent>-<TODAY>.md
                (<ARCHIVED_LINES> 行)

  保持したセクション:
    - このプロジェクトでの役割 (<N> 行)
    - 学習履歴 (<N> 行, 直近のみ)
    - 過去のミスと回避策 (<N> 行)
    - 暗黙のルール (<N> 行)
    - 次に着手する時のヒント (<N> 行)
```

## 有効な Agent 名一覧

```bash
ls "${PROJECT_ROOT}/memory/"*.md | xargs -I{} basename {} .md \
  | grep -v "MEMORY\|agent-template\|skills_pending\|claude-code-expert"
```

通常は以下の名前が有効:
- `planner`
- `design-reviewer`
- `code-reviewer`
- `frontend-engineer`
- `backend-engineer`
- `infrastructure-engineer`
- `db-engineer`
- `qa-engineer`
- `ml-engineer`
- `chrome-extension-engineer`
- `native-app-engineer`
- `game-engineer`

## CLAUDE.md §8 の適用

以下の情報は memory に書かない (書いてあれば削除):
- code conventions / file paths / architecture (コードを読めば分かる)
- git history (git log で十分)
- bug fix recipes (commit message に書く)
- ephemeral state (進行中の task)
- API key, password, PII (絶対禁止)

## Notes

- `update-memory` (hook 専用) との違い: こちらは Claude が推論して整理する
  `update-memory` は deterministic なシェル操作のみ (model invocation なし)
- 定期実行の目安: memory ファイルが 150 行を超えたら実行推奨
- アーカイブは削除ではない — `memory/archive/` で参照・復元可能
- 全 agent を一括整理したい場合は engineer ごとに繰り返し呼び出す
  (並列 dispatch は planner 経由で可能)
