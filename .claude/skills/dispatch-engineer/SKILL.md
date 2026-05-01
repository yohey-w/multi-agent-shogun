---
name: dispatch-engineer
description: >
  Dispatch a spec task to its assigned engineer subagent. Use when the user says
  "dispatch task", "send task to engineer", "run spec", "start task", "delegate
  task", "invoke engineer", "engineer を動かして", "spec を実行して", "タスクを
  dispatch して", "task-id を engineer に渡して", "engineer に投げて". Reads the
  spec file, determines the `agent:` frontmatter field, and launches the
  appropriate engineer via Agent tool with the full spec as context.
argument-hint: "<task-id>  (e.g. 03-build-skills)"
allowed-tools:
  - Read
  - Bash
  - Agent
  - Glob
user-invocable: true
---

# /dispatch-engineer

## Purpose

`specs/` 内の任意の task spec を読み込み、`agent:` frontmatter フィールドで
指定された engineer subagent を Agent tool で起動する。

殿が spec の細部を知らなくても `/dispatch-engineer <task-id>` と打つだけで
適切な engineer に仕事が渡る。

## Usage

```
/dispatch-engineer <task-id>
/dispatch-engineer 03-build-skills
/dispatch-engineer v2-harness-engineering/03-build-skills
```

引数は task_id (frontmatter `task_id:` の値) または spec ファイルへの部分パス
のいずれでも可。

## Behavior

### Step 1 — spec ファイルの特定

```bash
# ARGUMENTS = ユーザ入力の task-id
TASK_ID="${ARGUMENTS}"
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SPECS_DIR="${PROJECT_ROOT}/specs"

# 検索: task_id が完全一致 or ファイル名が一致
SPEC_FILE=$(find "${SPECS_DIR}" -name "*.md" | xargs grep -l "^task_id: ${TASK_ID}" 2>/dev/null | head -1)

# フォールバック: パス部分一致
if [ -z "${SPEC_FILE}" ]; then
  SPEC_FILE=$(find "${SPECS_DIR}" -path "*${TASK_ID}*" -name "*.md" | head -1)
fi

if [ -z "${SPEC_FILE}" ]; then
  echo "ERROR: spec not found for task_id '${TASK_ID}'" >&2
  exit 1
fi
echo "Found spec: ${SPEC_FILE}"
```

### Step 2 — agent フィールドの抽出

spec ファイルの YAML frontmatter から `agent:` を読み取る。

```bash
AGENT_NAME=$(grep -m1 "^agent:" "${SPEC_FILE}" | awk '{print $2}' | tr -d '"'"'"' ')
if [ -z "${AGENT_NAME}" ]; then
  echo "ERROR: spec '${SPEC_FILE}' has no 'agent:' field" >&2
  exit 1
fi
echo "Target agent: ${AGENT_NAME}"
```

有効な `agent:` 値の例:
- `frontend-engineer`
- `backend-engineer`
- `infrastructure-engineer`
- `db-engineer`
- `qa-engineer`
- `ml-engineer`
- `chrome-extension-engineer`
- `native-app-engineer`
- `game-engineer`

### Step 3 — 依存 task の確認

```bash
DEPENDS_ON=$(grep -m1 "^depends_on:" "${SPEC_FILE}" | sed 's/depends_on: //')
if [ "${DEPENDS_ON}" != "[]" ] && [ -n "${DEPENDS_ON}" ]; then
  echo "WARNING: this task depends on: ${DEPENDS_ON}"
  echo "Verify dependencies are complete before dispatching."
fi
```

### Step 4 — Agent tool で engineer を起動

Read で spec 内容を取得し、以下の prompt で Agent tool を呼ぶ：

```
Agent tool invocation:
  subagent:  <AGENT_NAME>
  prompt: |
    以下の spec を実行してください。

    spec ファイル: <SPEC_FILE>

    ---
    <SPEC_FILE の全内容>
    ---

    完了後、以下を報告してください:
    1. 変更・作成したファイル一覧
    2. Verification セクションの各チェックの結果
    3. 問題点・懸念事項
```

### Step 5 — 結果の整理

engineer の完了レポートを受け取り、殿に要約して報告する：

```
Dispatch 完了レポート:
- task_id: <TASK_ID>
- agent: <AGENT_NAME>
- spec: <SPEC_FILE>
- 変更ファイル: <リスト>
- Verification: <PASS/FAIL 各項目>
- 所要時間: <elapsed>
```

## Error Handling

| 状況 | 対処 |
|------|------|
| spec ファイルが見つからない | エラーで停止、`find specs/ -name "*.md"` で候補一覧を提示 |
| `agent:` フィールドがない | エラーで停止、spec を開いて手動確認を促す |
| 依存 task が未完了 | 警告を出し、殿に続行確認を求める |
| engineer が失敗を返す | 失敗内容をそのまま殿に伝え、次の手順を提案 |

## Notes

- dispatch 後の engineer は独立コンテキストで動くため、殿の現在のコンテキストに
  影響しない
- 複数 task を連続 dispatch するときは `depends_on` の順序を守ること
- engineer の memory ファイルは `memory/<agent-name>.md` を参照している
  (SessionStart hook で自動注入)
- この skill 自身はコードを書かない — 書くのは engineer の責務
