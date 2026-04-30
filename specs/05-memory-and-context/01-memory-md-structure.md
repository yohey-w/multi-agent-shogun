---
phase: 5
task_id: 01-memory-md-structure
agent: planner (Haiku 可)
estimated_minutes: 5
depends_on: []
---

# Task: memory/ ディレクトリ構造の決定 + 仕様文書化

## Goal
プロジェクトルートの `memory/` 配下に「agent 別 memory.md」を配置する仕様を確定。

## Steps
1. ディレクトリ作成:
```bash
mkdir -p memory
```

2. `memory/MEMORY.md` を index として作成 (空骨格):
```markdown
# Memory Index

このプロジェクトの agent 別 memory ファイルの一覧。SessionStart hook が agent 起動時に該当ファイルを context 注入する。

## Project-level Agents
- [planner](planner.md) — タスク分解 / spec 作成 / dispatch の学び
- [design-reviewer](design-reviewer.md) — アーキ判断 / security 方針の蓄積
- [code-reviewer](code-reviewer.md) — レビュー指摘パターン / 過去のミス

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
```

3. `memory/agent-template.md` を作成 (各 agent の初期化雛形):
```markdown
# <agent-name> Memory (このプロジェクト用)

## このプロジェクトでの役割
<どんな仕事を期待されているか、1-2段落>

## 学習履歴
(初期は空、作業ごとに重要な学びを追記)

## 過去のミスと回避策
(空)

## 暗黙のルール (このプロジェクト固有)
(空)

## 次に着手する時のヒント
(空)
```

4. commit:
```bash
git add memory/MEMORY.md memory/agent-template.md
git commit -m "feat(v2): memory/ structure for per-agent persistent context"
```

## Verification
```bash
test -f memory/MEMORY.md && wc -l memory/MEMORY.md
test -f memory/agent-template.md
```

## Notes
- Claude Code の auto-memory (~/.claude/projects/.../memory/) と区別: こちらはプロジェクト内コミット可能、shared (チームで使える)
- auto-memory はユーザ個人観察 (殿のクセ等)、こちらは agent ごとの作業知識
