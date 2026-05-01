# Memory Index

このプロジェクトの agent 別 memory ファイルの一覧。SessionStart hook が agent 起動時に該当ファイルを context 注入する。

## Project-level Agents
- [planner](planner.md) — タスク分解 / spec 作成 / dispatch の学び
- [tester](tester.md) — 独立 QA pane の memory。impl context を排し AC ベースで test 実行する規律
- [design-reviewer](design-reviewer.md) — アーキ判断 / security 方針の蓄積
- [code-reviewer](code-reviewer.md) — レビュー指摘パターン / 過去のミス
- [claude-code-expert](claude-code-expert.md) — Anthropic Claude Code 公式仕様マスター (settings/hooks/subagents/skills/MCP/memory/agent-teams)

## User-level Agents
- [frontend-engineer](frontend-engineer.md)
- [backend-engineer](backend-engineer.md)
- [infrastructure-engineer](infrastructure-engineer.md)
- [db-engineer](db-engineer.md)
- [chrome-extension-engineer](chrome-extension-engineer.md)
- [native-app-engineer](native-app-engineer.md)
- [game-engineer](game-engineer.md)
- [ml-engineer](ml-engineer.md)
- [qa-engineer](qa-engineer.md)

## ルール
- 各 memory ファイルは 200 行以内 (context 圧迫回避)
- 200 行超えたら古い学びを `memory/archive/` に移動
- 機密情報 (API key, password, PII) を書かない
- 学習内容は具体的に (× "気をつける" / ◎ "Foo クラスは null 返すので明示的に check")
