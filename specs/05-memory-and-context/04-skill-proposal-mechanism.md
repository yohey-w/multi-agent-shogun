---
phase: 5
task_id: 04-skill-proposal-mechanism
agent: planner (Haiku 可)
estimated_minutes: 5
depends_on: [03-session-start-hook]
---

# Task: スキル提案・更新機構を v2 に合わせて再構築

## Goal
殿が Q7 で「スキルの提案とアップデートの機構はそのまま」と言った要件を実装。Engineer/Reviewer subagent が「これは skill 化したら次から速い」と判断した時、planner が拾える形で残す機構。

## Steps

1. `memory/skills_pending.md` を作成 (skill 候補の溜め場):
```markdown
# Skills Pending Review (v2)

各 agent が見つけた「skill 化候補」のリスト。planner が定期的に見て採用判断する。

## エントリ形式
```yaml
- id: 連番 (skill_001, skill_002 ...)
  proposed_by: <agent name>
  proposed_at: YYYY-MM-DD
  trigger: いつ呼び出されるべきか (ユーザの言い回し例)
  description: 何をするか
  rationale: なぜ skill 化するか (頻度, コスト, 標準化効果)
  status: pending | approved | rejected | implemented
  notes: 追加情報
```

## エントリ
(空、agent が追記)
```

2. 各 subagent 定義 (specs/03, 04) で言及済の `skill_candidate` を統一: 完了レポートに以下フィールドを含める:
   - skill_candidate.found: bool
   - skill_candidate.id: 提案ID (新規発番)
   - skill_candidate.trigger / description / rationale

3. planner が定期 (タスク完遂時 or 殿指示) に `memory/skills_pending.md` を読んで status: approved → 実装 task 起案。

4. skill 実装は既存の skill-creator skill を呼ぶ:
```
/skill-creator
```
殿が決めた "メタ" 設計者。

5. commit:
```bash
git add memory/skills_pending.md
git commit -m "feat(v2): skill proposal queue (memory/skills_pending.md)"
```

## Verification
```bash
test -f memory/skills_pending.md
```

## Notes
- 旧戦国系の dashboard.md に「skill_candidate:」を集めていた仕組みを memory/skills_pending.md に置換
- planner は週次 or 殿指示で review、優先度高ければ skill-creator に dispatch
- skill は `~/.claude/skills/<name>/SKILL.md` 形式で生成 (既存)
