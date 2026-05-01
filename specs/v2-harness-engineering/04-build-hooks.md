---
phase: 1
task_id: 04-build-hooks
agent: infrastructure-engineer
estimated_minutes: 15
depends_on: []
---

# Task: 4 hooks 構築 + `.claude/settings.json` で配線

## Goal
公式 hook event を活用して安全性 + 自動化を強化。`memory/claude-code-expert.md §2 §10.3` 参照。

## Inputs
- `memory/claude-code-expert.md` (公式 hook event 一覧、入出力 schema)
- 既存: `.claude/hooks/session_start_inject_memory.sh`, `.claude/settings.json`
- `CLAUDE.md §7` (Destructive Operation Safety、guard 内容の参照元)

## Steps

### A. 4 hook script を `.claude/hooks/` に作成

#### A1. `guard_rm.sh` (PreToolUse, Bash matcher)
- 入力: stdin に PreToolUse 発火時の JSON (公式 schema)
- 動作: `command` field を parse し、危険な `rm -rf` パターン (CLAUDE.md §7 D001-D008 系) なら exit 2 (block) で stderr に理由
- パターン:
  - `rm -rf /` `rm -rf /mnt/` `rm -rf /home/` `rm -rf ~` (D001)
  - working tree 外の絶対パス削除 (D002)
  - 10 file 超の削除予測 (`rm -rf` で複数ディレクトリ指定時、深さ確認)
- 危険でなければ exit 0 (許可)
- 実行可能: `chmod +x`

#### A2. `guard_outside_project.sh` (PreToolUse, Edit|Write matcher)
- 入力: stdin の JSON から `file_path` extract
- 動作: `$CLAUDE_PROJECT_DIR` 配下にない path への Edit/Write を block (exit 2)
- 例外: `~/.claude/agents/`, `~/.claude/CLAUDE.md`, `/tmp/claude/` は許可

#### A3. `post_engineer.sh` (SubagentStop)
- 入力: 完了した subagent の name + working dir
- 動作:
  1. subagent の memory file (`memory/<agent>.md`) が 200 行超なら `update-memory` skill を invoke (slash command 経由)
  2. 該当 spec の Verification 句を抽出して結果ロギング
  3. `dashboard.md` の対応行を completed に更新

#### A4. `inject_dashboard.sh` (UserPromptSubmit)
- 入力: 殿 prompt
- 動作: `dashboard.md` の現状 + `queue/inbox/<role>.yaml` の未読件数 を抽出して context 注入 (stdout に Markdown 出力 → Claude が context 取込)
- 軽量に (50 行以内、不要なら早期 exit)

### B. `.claude/settings.json` の `hooks` block 更新

`memory/claude-code-expert.md §10.3` の例を参考に hooks block を追記:

```jsonc
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {"type": "command",
           "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/guard_rm.sh"}
        ]
      },
      {
        "matcher": "Edit|Write",
        "hooks": [
          {"type": "command",
           "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/guard_outside_project.sh"}
        ]
      }
    ],
    "SubagentStop": [
      {
        "hooks": [
          {"type": "command",
           "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/post_engineer.sh"}
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {"type": "command",
           "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/inject_dashboard.sh"}
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {"type": "command",
           "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/session_start_inject_memory.sh"}
        ]
      }
    ]
  }
}
```

既存 hooks (例: SessionStart) は保持。`permissions` 等の他 key も保持。

### C. 動作テスト (可能な範囲で)
- `bash -n .claude/hooks/*.sh` で構文チェック
- guard_rm.sh に dummy stdin (例: `{"tool_input":{"command":"rm -rf /tmp"}}`) を流して exit code 確認
- json validate: `python3 -c 'import json; json.load(open(".claude/settings.json"))'`

## Expected Output
- `.claude/hooks/{guard_rm,guard_outside_project,post_engineer,inject_dashboard}.sh` 計 4 hook
- `.claude/settings.json` の `hooks` block に 4 event 配線済 (既存 SessionStart も維持)
- 全 hook script が `chmod +x`

## Verification
1. `ls -la .claude/hooks/*.sh` で 5 ファイル (既存含む) すべて executable
2. `bash -n .claude/hooks/*.sh` 構文 OK
3. `python3 -c 'import json; json.load(open(".claude/settings.json"))'` JSON valid
4. `jq '.hooks | keys' .claude/settings.json` で `["PreToolUse","SessionStart","SubagentStop","UserPromptSubmit"]` (alphabetical) を含む

## Notes
- hook の入出力仕様は **公式 doc** (`memory/claude-code-expert.md §2`) を厳守
- block (exit 2) は本当に危険な時だけ。通常は warn + log で許可するほうが UX 良い
- post_engineer.sh は重い処理を避ける (子プロセス subagent 完了直後に呼ばれるため遅延を作らない)
- commit はしない (planner = 親 session が一括 commit)
