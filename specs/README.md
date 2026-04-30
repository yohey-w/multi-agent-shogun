# specs/ — agent-orchestra v2 移行 仕様書群

殿の指示 (2026-04-30): 「Haiku 程度が作業できるレベルにまでタスクを分解、仕様として specs に格納、まず全体の絵を描いてから作業」

## 全体の絵
- [00-overview.md](00-overview.md) — v2 移行の北極星、アーキテクチャ、完了基準

## Phase 別タスク

| # | Phase | 仕様 | Haiku 実行可? |
|---|-------|------|--------------|
| 1 | 凍結とクリーンアップ | [01-freeze-and-cleanup/](01-freeze-and-cleanup/) | ✅ |
| 2 | GitHub fork + 公開設定 | [02-github-setup/](02-github-setup/) | 殿手動2件 + ✅ |
| 3 | User-level subagents 定義 | [03-user-level-subagents/](03-user-level-subagents/) | ✅ |
| 4 | Project-level subagents 定義 | [04-project-level-subagents/](04-project-level-subagents/) | ✅ |
| 5 | memory.md + SessionStart hook | [05-memory-and-context/](05-memory-and-context/) | ✅ |
| 6 | CLAUDE.md v2 書き換え | [06-claude-md-rewrite/](06-claude-md-rewrite/) | ✅ |
| 7 | legacy 削除 | [07-legacy-removal/](07-legacy-removal/) | ✅ |
| 8 | 動作検証 | [08-validation/](08-validation/) | 一部殿手動 |

## 各 task spec のフォーマット

```markdown
---
phase: <number>
task_id: <NN>-<short-name>
agent: <subagent name from User/Project level, or "manual" if Lord action>
estimated_minutes: <e.g. 5-15>
depends_on: [<task_id>, ...]
---

# Task: <タイトル>

## Goal
1 行で何を達成するか

## Inputs
具体的な入力 (ファイルパス、参照仕様、前提条件)

## Steps
1. ... (Bash/Edit/Write 等の具体コマンド or 操作)
2. ...

## Expected Output
- ファイル/状態/コマンド出力

## Verification
完了をどう確認するか (コマンド + 期待出力)

## Notes
注意事項
```

## 進行ルール

1. planner (= 将軍) が次に実行すべき task を選ぶ (Phase 順 + depends_on 順守)
2. task の `agent:` フィールドに従って Agent tool で起動
3. subagent は spec を Read → 実行 → 結果報告
4. planner が verification 確認 → ✅ なら次の task へ
5. NG なら spec を修正 or 追加 task 起案

## 完了判定

[00-overview.md の §9 完了基準](00-overview.md#9-完了基準) 全てが ✅ になった時点で v2 移行完了。
