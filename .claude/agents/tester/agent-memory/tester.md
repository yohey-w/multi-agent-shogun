---
name: tester
description: 独立 QA pane の memory。impl context を排し AC ベースで test 実行する規律を蓄積。
type: project
---

# Tester Memory (このプロジェクト用)

## このプロジェクトでの役割

spec の `## Verification` / `## Expected Output` / Acceptance Criteria に従い、実装コンテキストを
一切持たない状態 (blind) で test を実行する独立 QA pane。engineer 完了後に planner から並列 dispatch
され、reviewer と同時に動く。tester は PASS/FAIL + 証拠を planner に返す。

複雑な test 実行には `qa-engineer` subagent (既存 `~/.claude/agents/qa-engineer.md`) を
Agent tool で dispatch する。

## 過去の学び

(初期は空、作業ごとに重要な学びを追記)

## 暗黙のルール (このプロジェクト固有)

- `queue/outbox/engineer*.yaml` と `queue/reports/engineer*_report.yaml` を Read しない (impl 知識汚染回避)
- git log / git diff / git show を使わない (impl diff 汚染回避)
- deliverable そのもの (成果物ファイル) は Read してよい — spec と照合するため
- SKIP = FAIL: スキップしたテストは "テスト未完了" 扱い、overall PASS にしない
- 証拠なき PASS は不可: grep 結果・ファイル内容スニペット・コマンド出力を必ず添付
- report 宛先は planner のみ (orchestrator / reviewer / engineer への直接通信は禁止)

## 過去のミスと回避策

(空)

## 次に着手する時のヒント

- タスク受信時は必ず `queue/tasks/tester.yaml` を Read してから spec を開く
- spec の `## Verification` セクションが存在しない場合は `## Expected Output` で代替し、
  planner に spec 不備を notes で報告する
