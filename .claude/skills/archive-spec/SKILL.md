---
name: archive-spec
description: >
  Move completed or obsolete spec directories to the archive. Use when the user
  says "spec をアーカイブして", "完了した spec を片付けて", "archive spec",
  "古い spec を移動して", "spec の整理", "完了 spec をアーカイブ", "archive
  this topic", "spec ディレクトリを archive に", "終わった仕様を archive",
  "spec cleanup". Moves matching spec directories to specs/archive/YYYY-MM/
  and updates any dashboard references.
argument-hint: "<topic-or-date>  (e.g. user-auth  or  2026-04-30)"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
user-invocable: true
---

# /archive-spec

## Purpose

完了・陳腐化した spec ディレクトリを `specs/archive/YYYY-MM/` へ移動し、
`specs/` トップを常にアクティブ spec だけの状態に保つ。

## Usage

```
/archive-spec user-auth              # topic 名で部分一致
/archive-spec 2026-04-30-auth        # 日付付きディレクトリ名で一致
/archive-spec 2026-04-30             # その日作成された全 spec を対象
/archive-spec --all-done             # 全タスクが done 状態の spec を自動検出
```

## Behavior

### Step 1 — 対象ディレクトリの特定

```bash
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SPECS_DIR="${PROJECT_ROOT}/specs"
ARG="${ARGUMENTS}"
TODAY=$(date +%Y-%m)
ARCHIVE_DIR="${SPECS_DIR}/archive/${TODAY}"

# 対象候補を列挙
if [ "${ARG}" = "--all-done" ]; then
  # 全 spec ファイルの task_id に対して "done" 相当を確認する (後述)
  echo "Auto-detecting fully completed spec directories..."
  CANDIDATES=$(find "${SPECS_DIR}" -maxdepth 1 -mindepth 1 -type d \
    ! -name "archive" | sort)
else
  CANDIDATES=$(find "${SPECS_DIR}" -maxdepth 1 -mindepth 1 -type d \
    -name "*${ARG}*" ! -name "archive" | sort)
fi

if [ -z "${CANDIDATES}" ]; then
  echo "No matching spec directories found for: ${ARG}"
  echo "Available spec directories:"
  ls -d "${SPECS_DIR}"/*/
  exit 1
fi

echo "Candidates to archive:"
echo "${CANDIDATES}"
```

### Step 2 — 各ディレクトリの状態確認

```bash
for DIR in ${CANDIDATES}; do
  DIR_NAME=$(basename "${DIR}")
  SPEC_FILES=$(find "${DIR}" -name "*.md" ! -name "00-overview.md" | sort)
  TOTAL=$(echo "${SPEC_FILES}" | wc -l | tr -d ' ')

  echo ""
  echo "=== ${DIR_NAME} (${TOTAL} spec files) ==="

  # 各 spec の estimated_minutes と agent を表示 (状態の判断材料)
  for F in ${SPEC_FILES}; do
    TASK_ID=$(grep -m1 "^task_id:" "${F}" | awk '{print $2}')
    AGENT=$(grep -m1 "^agent:" "${F}" | awk '{print $2}')
    MINUTES=$(grep -m1 "^estimated_minutes:" "${F}" | awk '{print $2}')
    echo "  - ${TASK_ID}  agent=${AGENT}  ~${MINUTES}min"
  done
done
```

### Step 3 — 殿への確認

自動 `--all-done` 以外の場合は、アーカイブ前に確認を求める:

```
以下の spec ディレクトリをアーカイブします:

  specs/<dir1>/  (N tasks)
  specs/<dir2>/  (M tasks)

移動先: specs/archive/<YYYY-MM>/

続行しますか？ (yes/no)
```

殿が "yes" または確認を省いた場合は Step 4 へ進む。

### Step 4 — アーカイブ実行

```bash
mkdir -p "${ARCHIVE_DIR}"

for DIR in ${CANDIDATES}; do
  DIR_NAME=$(basename "${DIR}")
  DEST="${ARCHIVE_DIR}/${DIR_NAME}"

  if [ -d "${DEST}" ]; then
    # 既存ディレクトリとの衝突回避
    DEST="${ARCHIVE_DIR}/${DIR_NAME}-$(date +%H%M%S)"
  fi

  mv "${DIR}" "${DEST}"
  echo "Archived: specs/${DIR_NAME} -> specs/archive/${TODAY}/${DIR_NAME}"
done
```

### Step 5 — dashboard.md の更新

`dashboard.md` 内に spec ディレクトリへの参照があれば更新する:

```bash
DASHBOARD="${PROJECT_ROOT}/dashboard.md"
if [ -f "${DASHBOARD}" ]; then
  for DIR in ${CANDIDATES}; do
    DIR_NAME=$(basename "${DIR}")
    # specs/<dirname> への参照を "specs/archive/YYYY-MM/<dirname>" に置換
    sed -i.bak "s|specs/${DIR_NAME}|specs/archive/${TODAY}/${DIR_NAME}|g" "${DASHBOARD}"
    rm -f "${DASHBOARD}.bak"
  done
  echo "Updated dashboard.md"
fi
```

### Step 6 — 完了報告

```
Archive 完了:

  移動先: specs/archive/<YYYY-MM>/
  アーカイブ済み:
    - <dir1>  (N tasks)
    - <dir2>  (M tasks)

現在のアクティブ spec:
  <残存 spec ディレクトリ一覧>
```

## 自動完了検出 (`--all-done` モード)

全 spec ファイルが dispatch 済みかどうかを判断するロジック:

1. `specs/` 直下の各ディレクトリを走査
2. `00-overview.md` 以外の全 `.md` ファイルを列挙
3. 各ファイルの `task_id` を `dispatch-engineer` の実行ログと照合
   (ログが存在しない場合は "未 dispatch" として除外)
4. 全タスクが dispatch 済みのディレクトリを候補とする

注: 正確な "完了" 判定はログベースなので、ログがない環境では `--all-done` は
手動確認の補助として使う。

## Safety Rules

- `specs/archive/` 自体はアーカイブ対象外 (`! -name "archive"` フィルタ)
- 移動先に同名ディレクトリが存在する場合はタイムスタンプサフィックスで回避
  (上書き・削除は行わない)
- `mv` は同一ファイルシステム内なら atomic — データ損失リスクなし
- アーカイブ後に `ls specs/archive/` で確認を促す

## Rollback

```bash
# アーカイブした spec を戻す
mv specs/archive/<YYYY-MM>/<dir> specs/<dir>
# dashboard.md を git checkout で戻す
git checkout dashboard.md
```

## Notes

- アーカイブは削除ではない — 後から参照・復元が可能
- `memory-curate` skill も同様のアーカイブパターンを持つ (`memory/archive/` へ)
- 月次の定期整理に使うことを想定 (月末に `--all-done` で一括整理)
