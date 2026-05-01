---
name: dashboard
description: >
  Regenerate the dashboard.md file with current project status. Use when the
  user says "dashboard を更新して", "ダッシュボード再生成", "status を更新",
  "現状をまとめて", "dashboard refresh", "update dashboard", "project 状況を
  出して", "何が動いてるか教えて", "active spec の一覧", "進捗確認",
  "dashboard を作り直して". Scans active specs, memory files, and recent git
  activity to produce a fresh dashboard.md.
argument-hint: "(no argument needed)"
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
user-invocable: true
---

# /dashboard

## Purpose

`dashboard.md` を現在のプロジェクト状態から再生成する。

- アクティブ spec 一覧
- 各 spec のタスク進行状況
- 最近の git コミット
- memory ファイルの最終更新状況

## Usage

```
/dashboard
```

引数不要。現在の `specs/`、`memory/`、`git log` をスキャンして生成する。

## Behavior

### Step 1 — 現状データの収集

```bash
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
NOW=$(date '+%Y-%m-%d %H:%M:%S')

# アクティブ spec ディレクトリ (archive 以外)
ACTIVE_SPECS=$(find "${PROJECT_ROOT}/specs" -maxdepth 1 -mindepth 1 \
  -type d ! -name "archive" | sort)

# 最近の git コミット (10件)
RECENT_COMMITS=$(git -C "${PROJECT_ROOT}" log --oneline -10 2>/dev/null || echo "(git log unavailable)")

# memory ファイル一覧と最終更新日時
MEMORY_FILES=$(find "${PROJECT_ROOT}/memory" -maxdepth 1 -name "*.md" \
  ! -name "MEMORY.md" ! -name "MEMORY.md.sample" ! -name "agent-template.md" \
  | sort)
```

### Step 2 — アクティブ spec の詳細集計

```python
import os, glob, re, sys
from datetime import datetime

project_root = os.environ.get('PROJECT_ROOT', '.')
specs_dir = os.path.join(project_root, 'specs')

spec_summary = []

for spec_dir in sorted(os.listdir(specs_dir)):
    if spec_dir == 'archive':
        continue
    dir_path = os.path.join(specs_dir, spec_dir)
    if not os.path.isdir(dir_path):
        continue

    task_files = [f for f in glob.glob(os.path.join(dir_path, '*.md'))
                  if os.path.basename(f) != '00-overview.md']

    tasks = []
    for tf in sorted(task_files):
        with open(tf) as f:
            content = f.read()
        task_id = re.search(r'^task_id:\s*(.+)$', content, re.M)
        agent = re.search(r'^agent:\s*(.+)$', content, re.M)
        phase = re.search(r'^phase:\s*(.+)$', content, re.M)
        minutes = re.search(r'^estimated_minutes:\s*(.+)$', content, re.M)
        tasks.append({
            'task_id': task_id.group(1).strip() if task_id else '?',
            'agent': agent.group(1).strip() if agent else '?',
            'phase': phase.group(1).strip() if phase else '?',
            'minutes': minutes.group(1).strip() if minutes else '?',
        })

    spec_summary.append({'dir': spec_dir, 'tasks': tasks})

for s in spec_summary:
    print(f"SPEC:{s['dir']}:{len(s['tasks'])}")
    for t in s['tasks']:
        print(f"  TASK:{t['task_id']}:{t['agent']}:phase={t['phase']}:{t['minutes']}min")
```

### Step 3 — dashboard.md の生成

以下の形式で `dashboard.md` を書き出す:

```markdown
# Dashboard

最終更新: <NOW>

---

## アクティブ Spec

### <spec-dir-1>

| task_id | agent | phase | 分数 |
|---------|-------|-------|------|
| task-01 | frontend-engineer | 1 | 10 |
| task-02 | backend-engineer  | 1 | 15 |
| task-03 | qa-engineer       | 2 | 10 |

### <spec-dir-2>

...

---

## Memory 最終更新

| agent | 最終更新日時 | 行数 |
|-------|------------|------|
| planner | 2026-04-30 | 45 |
| backend-engineer | 2026-04-29 | 112 |
| ...   | ...        | ...  |

---

## 最近の Git コミット

```
<git log --oneline -10 の出力>
```

---

## 注意事項

- アーカイブ済み spec: `specs/archive/` 参照
- memory 整理: `/memory-curate <agent-name>`
- spec アーカイブ: `/archive-spec <topic>`
```

### Step 4 — dashboard.md への書き込み

```bash
# 実際の書き込みは Write tool で行う
# 以下は生成したコンテンツを dashboard.md に出力する
DASHBOARD_PATH="${PROJECT_ROOT}/dashboard.md"
echo "Writing dashboard to: ${DASHBOARD_PATH}"
```

Write tool で `dashboard.md` に生成コンテンツを書き込む。

### Step 5 — 完了報告

```
dashboard.md 更新完了:

  更新日時: <NOW>
  アクティブ spec: N ディレクトリ, M タスク
  memory ファイル: K 件
  書き込み先: dashboard.md
```

## Memory ファイル統計の取得

```bash
for MFILE in ${MEMORY_FILES}; do
  AGENT=$(basename "${MFILE}" .md)
  LINES=$(wc -l < "${MFILE}")
  MTIME=$(stat -f '%Sm' -t '%Y-%m-%d' "${MFILE}" 2>/dev/null \
    || stat --format='%y' "${MFILE}" 2>/dev/null | cut -d' ' -f1)
  echo "${AGENT}|${MTIME}|${LINES}"
done
```

## 差分更新 vs 全再生成

この skill は **常に全再生成** を行う (incremental update ではない)。

理由:
- spec の追加・削除・変更を確実に反映するため
- diff による部分更新は複雑で誤りが出やすいため
- dashboard.md は git で追跡されるため、diff で変更が明確になる

## Notes

- PostToolUse hook (Edit/Write 完了後) から自動呼び出しされる設定も可能
  (`settings.json` の `hooks.PostToolUse` で `inject_dashboard.sh` 経由)
- 大規模プロジェクトで spec が 20+ ディレクトリになった場合は
  アーカイブ済みを除いたアクティブのみを表示する現状の設計で十分
- dashboard.md に secret や API key を書かないこと (git 追跡対象のため)
