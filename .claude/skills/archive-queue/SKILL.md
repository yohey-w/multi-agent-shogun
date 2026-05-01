---
name: archive-queue
description: 古い done/cancelled cmd エントリを queue/ ファイルから月別アーカイブへ移動するスキル。user が cutoff_cmd_id を指定して実行。
user_invocable: true
---

# /archive-queue

queue/ 配下の肥大化ファイルから古い完了・取消エントリをアーカイブする。

## 使い方

```
/archive-queue <cutoff_cmd_id> [--dry-run] [--no-commit]
```

### 手順

1. **必ず dry-run から実行**:
```bash
.venv/bin/python3.14 scripts/archive_queue.py <cutoff_cmd_id> --dry-run
```

2. dry-run 結果を確認し、対象件数・ファイルが想定通りかuser に報告

3. user が承認したら本実行:
```bash
.venv/bin/python3.14 scripts/archive_queue.py <cutoff_cmd_id>
```

4. 自動で git commit される (`--no-commit` で抑制可)

## 対象ファイル

| ファイル | 単位 | フィルタ |
|----------|------|----------|
| `queue/orchestrator_to_planner.yaml` | cmd エントリ | id < cutoff AND status in {done, cancelled} |
| `dashboard.md` | `## ✅ 直近の完了` セクション内の `- **cmd_NNN**` 行 | cmd_id < cutoff |
| `queue/reports/gunshi_report.yaml` | YAML ドキュメント | parent_cmd < cutoff AND status in {done, cancelled} |
| `queue/inbox/*.yaml` | messages エントリ | read:true AND content内の全cmd_id < cutoff |
| `queue/tasks/*.yaml` | 単一タスク | parent_cmd < cutoff AND status in {done, cancelled} |
| `queue/reports/*_report.yaml` | 単一レポート | parent_cmd < cutoff AND status in {done, cancelled} |

## アーカイブ先

`queue/archive/YYYY-MM/` (実行月ベース)

## 安全設計

- **cutoff_cmd_id 自身は保護** (strictly less than)
- **pending / in_progress / partial は絶対に触らない**
- **inbox の read:false は絶対に触らない**
- **inbox で cmd_id が cutoff 以上を1つでも含むメッセージは保守的に残す**
- entry 数の前後検証 (不一致ならロールバック)
- tmp ファイル経由の安全書き込み
- ruamel.yaml (round-trip) でコメント・リテラルブロック保全

## 対象外 (触らないファイル)

- `.claude/projects/.../*.jsonl` (Claude Code 管理)
- `MEMORY.md` / `memory/*.md` / `config/` / `.claude/rules/`
- `projects/` (機密プロジェクト)
