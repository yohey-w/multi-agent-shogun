# 殿作業可視化 — 補助集計統計

生成日時: 2026-04-12  
データソース: queue/shogun_to_karo.yaml (cmd_001〜cmd_081), dashboard.md, shogun_log.md  
注記: 解釈・分析は ashigaru2 (cmd_081 メイン担当) に委ねる

---

## 1. cmd数カテゴリ別集計表

### 1-A. project別

| project | cmd数 | 割合 |
|---------|-------|------|
| chrome_extensions | 21 | 28.0% |
| ai_accelerate_plan | 20 | 26.7% |
| claude_side_income | 14 | 18.7% |
| web_update_alert | 8 | 10.7% |
| multi-agent-shogun | 4 | 5.3% |
| ai_accelerate | 4 | 5.3% |
| web_update_alert_upgrade | 3 | 4.0% |
| claude_rollout | 1 | 1.3% |
| **合計 (YAML記録分)** | **75** | 100% |

補足: cmd_036/038/054/056/057/077 の6件はshogun_log.md/dashboard.mdに記録があるがYAMLに未記録。  
総発令数(推定): 81 (cmd_001〜cmd_081, 欠番なし想定)

### 1-B. priority別

| priority | cmd数 | 割合 |
|----------|-------|------|
| high | 67 | 89.3% |
| critical | 6 | 8.0% |
| medium | 2 | 2.7% |
| **合計** | **75** | 100% |

### 1-C. status別

| status | cmd数 | 割合 |
|--------|-------|------|
| done | 56 | 74.7% |
| pending | 12 | 16.0% |
| in_progress | 6 | 8.0% |
| partial | 1 | 1.3% |
| **合計** | **75** | 100% |

---

## 2. 月別cmd数推移 (2026-01〜2026-04)

| 月 | cmd数 | バー |
|----|-------|------|
| 2026-01 | 0 | |
| 2026-02 | 0 | |
| 2026-03 | 51 | `████████████████████████████████████████████████████` |
| 2026-04 | 24 | `████████████████████████` |

※ ASCIIグラフ: 1文字 ≈ 1cmd

```
月別cmd数 (YAML記録分75件)
2026-03 |████████████████████████████████████████████████████ 51
2026-04 |████████████████████████ 24
         0        10        20        30        40        50
```

注記: 2026-04は04-12までのデータ。月途中のため参考値。

### 2-A. 2026-03 週次内訳

| 期間 | cmd数 | cmd IDs |
|------|-------|---------|
| 03/07〜03/09 | 15 | cmd_001〜cmd_015 |
| 03/10〜03/16 | 6 | cmd_016〜cmd_021 |
| 03/17〜03/19 | 13 | cmd_022〜cmd_034 |
| 03/20〜03/25 | 8 | cmd_035〜cmd_042 |
| 03/30〜03/31 | 9 | cmd_043〜cmd_052 (cmd_036,038含む可能性) |

### 2-B. 2026-04 日次内訳

| 日付 | cmd数 | cmd IDs |
|------|-------|---------|
| 04/01 | 1 | cmd_053 |
| 04/03〜04/04 | 4 | cmd_054〜cmd_057 (dashboard記録) |
| 04/11 | 4 | cmd_059〜cmd_062 |
| 04/12 | 15 | cmd_063〜cmd_081 |

---

## 3. 🚨要対応セクション履歴

### 3-A. 現在の未解決要対応 (dashboard.md 2026-04-12時点)

| No | cmd | 内容 | 状態 |
|----|-----|------|------|
| 1 | cmd_072 | CatStroll ブランチ整理 + lord_action_list.md コミット | 未完 |
| 2 | cmd_071 | MemeSnap WebP→PNG変換 実機E2E確認 | 未完 |
| 3 | cmd_069 | MemeSnap Vision+キャプション編集 実機E2E確認 | 未完 |
| 4 | cmd_068 | BrowseToAnki 殿の手動E2Eテスト (phase3 UI検証) | 未完 |
| 5 | cmd_059 | Chrome拡張4本 ストア提出 (アカウント/メール/push/スクリーンショット) | 未完 |
| 6 | cmd_047 | multi-agent-shogun push権限エラー (403) | 未完 |
| 7 | cmd_045/046 | claude_side_income video-template ブランチ整理 | 未完 |
| 8 | cmd_040 | YouTube開設/ドメイン取得/Hugo/AI開示方針 | 未完 |

### 3-B. 解決済み要対応 (shogun_log.md)

| cmd | 内容 | 解決 |
|-----|------|------|
| cmd_039 | 声クローン/ペルソナ/コンテンツ方向 方針判断 | cmd_040で確定 (2026-03-22) |
| cmd_035 | claude_side_income Phase 3 テーマ判断 | 殿がテーマ3選択 (2026-03-21) |
| cmd_033 | Prisma7+Next15移行・テスト全PASS | 完了 (2026-03-19) |

---

## 4. cmd_ID × project 対応一覧 (CSV形式)

```csv
cmd_id,timestamp,project,priority,status
cmd_001,2026-03-07T17:30:00+09:00,web_update_alert,high,done
cmd_002,2026-03-08T19:05:00+09:00,ai_accelerate_plan,high,done
cmd_003,2026-03-08T19:30:00+09:00,ai_accelerate_plan,high,done
cmd_004,2026-03-09T10:00:00+09:00,ai_accelerate_plan,high,done
cmd_005,2026-03-09T10:00:00+09:00,ai_accelerate_plan,high,done
cmd_006,2026-03-09T09:15:00+09:00,ai_accelerate_plan,high,done
cmd_007,2026-03-09T09:45:00+09:00,ai_accelerate_plan,high,done
cmd_008,2026-03-09T10:15:00+09:00,ai_accelerate_plan,high,done
cmd_009,2026-03-09T13:00:00+09:00,ai_accelerate_plan,high,done
cmd_010,2026-03-09T13:30:00+09:00,ai_accelerate_plan,high,done
cmd_011,2026-03-09T14:10:00+09:00,ai_accelerate_plan,high,done
cmd_012,2026-03-09T14:50:00+09:00,ai_accelerate_plan,high,done
cmd_013,2026-03-09T17:00:00+09:00,ai_accelerate_plan,high,done
cmd_014,2026-03-09T21:10:00+09:00,ai_accelerate_plan,high,done
cmd_015,2026-03-09T22:30:00+09:00,ai_accelerate_plan,high,done
cmd_016,2026-03-10T08:00:00+09:00,ai_accelerate_plan,high,done
cmd_017,2026-03-10T16:00:00+09:00,ai_accelerate_plan,high,done
cmd_018,2026-03-10T16:30:00+09:00,ai_accelerate_plan,high,done
cmd_019,2026-03-13T10:00:00+09:00,ai_accelerate_plan,high,done
cmd_020,2026-03-13T17:30:00+09:00,ai_accelerate_plan,high,done
cmd_021,2026-03-16T10:00:00+09:00,ai_accelerate_plan,high,done
cmd_022,2026-03-17T00:00:00+09:00,multi-agent-shogun,high,pending
cmd_023,2026-03-17T00:10:00+09:00,web_update_alert,high,done
cmd_024,2026-03-17T16:30:00+09:00,multi-agent-shogun,high,pending
cmd_025,2026-03-17T16:30:00+09:00,web_update_alert,high,done
cmd_026,2026-03-17T16:45:00+09:00,web_update_alert,high,done
cmd_027,2026-03-17T17:00:00+09:00,web_update_alert,high,pending
cmd_028,2026-03-18T00:00:00+09:00,web_update_alert,high,done
cmd_029,2026-03-19T00:00:00+09:00,web_update_alert,high,done
cmd_030,2026-03-19T00:00:00+09:00,claude_rollout,high,done
cmd_031,2026-03-19T10:00:00+09:00,web_update_alert,high,done
cmd_032,2026-03-19T12:00:00+09:00,web_update_alert_upgrade,high,done
cmd_033,2026-03-19T12:01:00+09:00,web_update_alert_upgrade,high,done
cmd_034,2026-03-19T15:00:00+09:00,web_update_alert_upgrade,high,done
cmd_035,2026-03-20T10:00:00+09:00,claude_side_income,high,in_progress
cmd_036,--,claude_side_income,--,done (shogun_log記録: README夜間稼働モード追記)
cmd_037,2026-03-20T01:00:00+09:00,claude_side_income,high,done
cmd_038,--,claude_side_income,--,done (shogun_log記録: デュアルパイプライン実行準備)
cmd_039,2026-03-21T22:30:00+09:00,claude_side_income,high,done
cmd_040,2026-03-22T00:15:00+09:00,claude_side_income,high,done
cmd_041,2026-03-23T00:30:00+09:00,claude_side_income,high,done
cmd_042,2026-03-25T10:00:00+09:00,claude_side_income,high,done
cmd_043,2026-03-30T12:00:00+09:00,ai_accelerate,high,done
cmd_044,2026-03-30T15:00:00+09:00,claude_side_income,high,pending
cmd_045,2026-03-30T15:00:00+09:00,claude_side_income,medium,partial
cmd_046,2026-03-31T09:00:00+09:00,claude_side_income,high,pending
cmd_047,2026-03-31T09:05:00+09:00,ai_accelerate,high,pending
cmd_048,2026-03-31T10:00:00+09:00,ai_accelerate,high,pending
cmd_049,2026-03-31T10:30:00+09:00,claude_side_income,high,pending
cmd_050,2026-03-31T14:00:00+09:00,ai_accelerate,high,pending
cmd_051,2026-03-31T15:00:00+09:00,claude_side_income,high,pending
cmd_052,2026-03-31T16:00:00+09:00,claude_side_income,critical,pending
cmd_053,2026-04-01T10:00:00+09:00,chrome_extensions,high,done
cmd_054,--,chrome_extensions,--,done (dashboard記録: BrowseToAnki開発 04-03)
cmd_055,2026-04-04T10:00:00+09:00,chrome_extensions,high,done
cmd_056,--,chrome_extensions,--,done (dashboard記録: PageBreaker MVP 04-04)
cmd_057,--,chrome_extensions,--,done (dashboard記録: PageBreaker QC+MemeSnap 04-04)
cmd_058,2026-03-30T23:00:00+09:00,multi-agent-shogun,high,pending
cmd_059,2026-04-11T12:00:00+09:00,chrome_extensions,high,done
cmd_060,2026-04-11T12:30:00+09:00,chrome_extensions,high,done
cmd_061,2026-04-11T13:00:00+09:00,chrome_extensions,high,done
cmd_062,2026-04-11T13:30:00+09:00,chrome_extensions,high,done
cmd_063,2026-04-12T00:00:00+09:00,chrome_extensions,high,done
cmd_064,2026-04-12T01:00:00+09:00,chrome_extensions,critical,done
cmd_065,2026-04-12T01:30:00+09:00,multi-agent-shogun,high,done
cmd_066,2026-04-12T02:00:00+09:00,chrome_extensions,critical,done
cmd_067,2026-04-12T02:30:00+09:00,chrome_extensions,critical,done
cmd_068,2026-04-12T17:30:00+09:00,chrome_extensions,critical,done
cmd_069,2026-04-12T18:00:00+09:00,chrome_extensions,high,done
cmd_070,2026-04-12T19:10:00+09:00,chrome_extensions,high,done
cmd_071,2026-04-12T19:30:00+09:00,chrome_extensions,critical,done
cmd_072,2026-04-12T19:45:00+09:00,chrome_extensions,high,done
cmd_073,2026-04-12T20:00:00+09:00,claude_side_income,high,in_progress
cmd_074,2026-04-12T20:10:00+09:00,claude_side_income,high,in_progress
cmd_075,2026-04-12T18:00:00+09:00,chrome_extensions,high,done
cmd_076,2026-04-12T18:30:00+09:00,chrome_extensions,high,done
cmd_077,--,chrome_extensions,--,done (dashboard記録: cmd_077ルール策定)
cmd_078,2026-04-12T21:45:00+09:00,chrome_extensions,high,done
cmd_079,2026-04-12T22:00:00+09:00,chrome_extensions,high,in_progress
cmd_080,2026-04-12T22:05:00+09:00,chrome_extensions,high,in_progress
cmd_081,2026-04-12T22:10:00+09:00,chrome_extensions,medium,in_progress
```

---

*本文書は ashigaru6 (Sonnet) が生成。解釈・分析は ashigaru2 本分析 (lord_work_map.md) に委ねる。*
