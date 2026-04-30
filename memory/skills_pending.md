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
