---
name: update-memory
description: >
  Internal hook-only skill: automatically curate and update an engineer agent's
  memory file after subagent completion. This skill is NOT user-invocable and
  should NOT be triggered by user conversation. It is called exclusively by the
  SubagentStop hook to update memory/<agent-name>.md with lessons learned from
  the completed task, keeping the file within 200 lines. Do NOT invoke this
  from user prompts — use memory-curate skill for manual memory management.
argument-hint: "<agent-name> <task-id>"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
user-invocable: false
disable-model-invocation: true
---

# update-memory (hook-only)

## Purpose

SubagentStop hook から呼び出され、完了した engineer subagent の
`memory/<agent-name>.md` を更新する。

- 新しい学び・発見を追記
- ファイルを 200 行以内に維持 (超過分は `memory/archive/` へ退避)
- Claude の推論を使わず deterministic に動作 (`disable-model-invocation: true`)

**このスキルはユーザが直接呼ぶものではない。**
手動でメモリ整理をしたい場合は `/memory-curate <agent-name>` を使う。

## Invocation Context

SubagentStop hook のシェルスクリプトから以下の形式で呼び出される:

```bash
# .claude/hooks/post_engineer.sh から呼び出されるイメージ
# 環境変数: CLAUDE_PROJECT_DIR, hook stdin JSON (agent_name, task_id, result 等)
AGENT_NAME=$(cat /dev/stdin | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('agent_name',''))")
TASK_ID=$(cat /dev/stdin | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('task_id',''))")
```

## Behavior (Deterministic Shell Operations)

このスキルは `disable-model-invocation: true` のため、
Claude による推論・生成を行わず、シェル操作のみで動作する。

### Step 1 — 引数の解析

```bash
# ARGUMENTS = "<agent-name> <task-id>"
AGENT_NAME=$(echo "${ARGUMENTS}" | awk '{print $1}')
TASK_ID=$(echo "${ARGUMENTS}" | awk '{print $2}')
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}"
MEMORY_FILE="${PROJECT_ROOT}/memory/${AGENT_NAME}.md"
ARCHIVE_DIR="${PROJECT_ROOT}/memory/archive"
TODAY=$(date +%Y-%m-%d)
MONTH=$(date +%Y-%m)
```

### Step 2 — memory ファイルの存在確認

```bash
if [ ! -f "${MEMORY_FILE}" ]; then
  # テンプレートから作成
  TEMPLATE="${PROJECT_ROOT}/memory/agent-template.md"
  if [ -f "${TEMPLATE}" ]; then
    cp "${TEMPLATE}" "${MEMORY_FILE}"
    sed -i.bak "s/AGENT_NAME_PLACEHOLDER/${AGENT_NAME}/g" "${MEMORY_FILE}"
    rm -f "${MEMORY_FILE}.bak"
  else
    cat > "${MEMORY_FILE}" << 'TMPL'
# <AGENT> Memory (このプロジェクト用)

## このプロジェクトでの役割

## 学習履歴

## 過去のミスと回避策

## 暗黙のルール (このプロジェクト固有)

## 次に着手する時のヒント
TMPL
    sed -i.bak "s/<AGENT>/${AGENT_NAME}/g" "${MEMORY_FILE}"
    rm -f "${MEMORY_FILE}.bak"
  fi
  echo "Created memory file: ${MEMORY_FILE}"
fi
```

### Step 3 — task 完了タイムスタンプの追記

```bash
LINE_COUNT=$(wc -l < "${MEMORY_FILE}")
echo "Current memory file: ${LINE_COUNT} lines"

# 完了した task の記録を「学習履歴」セクションに追記
TASK_NOTE="- [${TODAY}] task_id=${TASK_ID} 完了"

# "## 学習履歴" の後の最初の空行を探して追記
python3 - "${MEMORY_FILE}" "${TASK_NOTE}" << 'PYEOF'
import sys

filepath = sys.argv[1]
note = sys.argv[2]

with open(filepath, 'r') as f:
    lines = f.readlines()

inserted = False
new_lines = []
for i, line in enumerate(lines):
    new_lines.append(line)
    if '## 学習履歴' in line and not inserted:
        # 次の空行または次のセクション前に挿入
        if i + 1 < len(lines) and lines[i+1].strip() == '':
            new_lines.append(note + '\n')
            inserted = True

if not inserted:
    new_lines.append(note + '\n')

with open(filepath, 'w') as f:
    f.writelines(new_lines)

print(f"Appended task note to {filepath}")
PYEOF
```

### Step 4 — 200 行制限のチェックと切り詰め

```bash
LINE_COUNT=$(wc -l < "${MEMORY_FILE}")

if [ "${LINE_COUNT}" -gt 200 ]; then
  echo "Memory file exceeds 200 lines (${LINE_COUNT}). Archiving excess..."

  mkdir -p "${ARCHIVE_DIR}/${MONTH}"
  ARCHIVE_FILE="${ARCHIVE_DIR}/${MONTH}/${AGENT_NAME}-$(date +%Y%m%d-%H%M%S).md"

  # 先頭 200 行を保持、残りをアーカイブ
  python3 - "${MEMORY_FILE}" "${ARCHIVE_FILE}" << 'PYEOF'
import sys

filepath = sys.argv[1]
archive_path = sys.argv[2]

with open(filepath, 'r') as f:
    lines = f.readlines()

keep = lines[:200]
overflow = lines[200:]

# アーカイブにヘッダ付きで保存
with open(archive_path, 'w') as f:
    f.write(f"# Archive (overflow from {filepath})\n\n")
    f.writelines(overflow)

# 元ファイルを 200 行に切り詰め
with open(filepath, 'w') as f:
    f.writelines(keep)

print(f"Archived {len(overflow)} lines to {archive_path}")
print(f"Memory file trimmed to {len(keep)} lines")
PYEOF

  echo "Archived overflow to: ${ARCHIVE_FILE}"
fi

FINAL_COUNT=$(wc -l < "${MEMORY_FILE}")
echo "Final memory file: ${FINAL_COUNT} lines"
```

### Step 5 — 完了ログ出力

```bash
echo "update-memory complete:"
echo "  agent:    ${AGENT_NAME}"
echo "  task_id:  ${TASK_ID}"
echo "  memory:   ${MEMORY_FILE} (${FINAL_COUNT} lines)"
```

## Hook 呼び出し元 (参考)

このスキルを呼び出す SubagentStop hook の想定実装:

```bash
#!/usr/bin/env bash
# .claude/hooks/post_engineer.sh
set -euo pipefail

# stdin から SubagentStop イベント JSON を読む
EVENT=$(cat)
AGENT_NAME=$(echo "${EVENT}" | python3 -c "
import sys,json
d=json.load(sys.stdin)
print(d.get('agent_name', d.get('agent_id', '')))
" 2>/dev/null || echo "")

TASK_ID=$(echo "${EVENT}" | python3 -c "
import sys,json
d=json.load(sys.stdin)
# transcript や context から task_id を推定
ctx = d.get('context', {})
print(ctx.get('task_id', 'unknown'))
" 2>/dev/null || echo "unknown")

if [ -n "${AGENT_NAME}" ]; then
  # update-memory skill を直接スクリプト呼び出しで実行
  # (skill は hook から直接 claude CLI を叩かずシェルスクリプトとして動作)
  SKILL_DIR="${CLAUDE_PROJECT_DIR}/.claude/skills/update-memory"
  bash "${SKILL_DIR}/run.sh" "${AGENT_NAME}" "${TASK_ID}" 2>&1 || true
fi
```

## Important Constraints

- **model invocation なし**: このスキルはシェルスクリプトのみで動作
- **user からの直接呼び出し禁止**: `user-invocable: false`
- **副作用最小化**: memory ファイルとアーカイブファイルのみ変更
- **失敗しても hook は続行**: エラーは非 blocking (exit 0 を返す)
- **CLAUDE.md §8 に従い**: API key, password, PII は絶対に memory に書かない

## Notes

- 手動でメモリを整理・編集したい場合は `/memory-curate <agent-name>` を使う
  (こちらは Claude が推論して整理する、user-invocable: true のスキル)
- アーカイブ先: `memory/archive/YYYY-MM/<agent>-<timestamp>.md`
- 200 行の境界でセクション途中切断が起きる場合は python3 スクリプトで
  セクション境界を探して切り詰めることも検討 (v2 改良案)
