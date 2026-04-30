# Dynamic Model Routing テスト仕様書

| 項目 | 内容 |
|---|---|
| 文書ID | DMR-SPEC-001 |
| Issue | #53 |
| 作成日 | 2026-02-17 |
| 参照要件 | reports/requirements_dynamic_model_routing.md |
| 対象 | Phase 1-4（TDD: テスト先行） |

---

## 1. 目的

本仕様書は、`reports/requirements_dynamic_model_routing.md` で定義された FR/NFR を、
実装前に検証可能なテストケースへ分解する。

ゴール:
- Phase 1から段階的にテスト→実装を繰り返す
- 各Phaseのテストが全PASSしてから次Phaseに進む
- 既存テスト（test_cli_adapter.bats）との回帰なしを保証

---

## 2. テストレベルと担当

| レベル | 名称 | 主担当 | 実行環境 | 用途 |
|---|---|---|---|---|
| L1 | Unit | 足軽 | bats + bash + python3 | 関数/ロジック単体検証 |
| L2 | Integration | 家老 | L1 + tmux + inbox_write | model_switch連携の統合検証 |
| L3 | E2E | 殿担当 | 実運用tmux全体 | Bloom分析→switch→実行の完走確認 |

注記:
- `SKIP=0` は必須。SKIPが1以上なら「未完了」扱い。
- Phase 1は L1 テストのみ。Phase 2以降でL2追加。

---

## 3. Phase 1 テストケース — capability_tier definition

### 3.1 FR-01: settings.yaml capability_tiersセクション

| TC ID | 要件 | レベル | 入力 | 期待値 |
|---|---|---|---|---|
| TC-DMR-001 | FR-01 基本読取 | L1 | capability_tiers定義済みYAML | パースエラーなし、各モデルのmax_bloomが読取可能 |
| TC-DMR-002 | FR-01 セクション不在 | L1 | capability_tiers未定義YAML | エラーなし、後方互換動作 |
| TC-DMR-003 | FR-01 cost_group読取 | L1 | capability_tiers定義済みYAML | 各モデルのcost_groupが読取可能 |

### 3.2 FR-02: get_capability_tier()

| TC ID | 要件 | レベル | 入力 | 期待値 |
|---|---|---|---|---|
| TC-DMR-010 | FR-02 Spark → 3 | L1 | model="gpt-5.3-codex-spark" | "3" |
| TC-DMR-011 | FR-02 Codex 5.3 → 4 | L1 | model="gpt-5.3" | "4" |
| TC-DMR-012 | FR-02 Sonnet → 5 | L1 | model="claude-sonnet-4-5-20250929" | "5" |
| TC-DMR-013 | FR-02 Opus → 6 | L1 | model="claude-opus-4-6" | "6" |
| TC-DMR-014 | FR-02 未定義モデル → 6 | L1 | model="unknown-model" | "6" |
| TC-DMR-015 | FR-02 セクション不在 → 6 | L1 | capability_tiers未定義 | "6" |
| TC-DMR-016 | FR-02 YAML破損 → 6 | L1 | 壊れたYAML | "6" |
| TC-DMR-017 | FR-02 空文字 → 6 | L1 | model="" | "6" |

### 3.3 FR-03: get_recommended_model()

| TC ID | 要件 | レベル | 入力 | 期待値 |
|---|---|---|---|---|
| TC-DMR-020 | FR-03 L1 → Spark | L1 | bloom_level=1 | "gpt-5.3-codex-spark" |
| TC-DMR-021 | FR-03 L2 → Spark | L1 | bloom_level=2 | "gpt-5.3-codex-spark" |
| TC-DMR-022 | FR-03 L3 → Spark | L1 | bloom_level=3 | "gpt-5.3-codex-spark" |
| TC-DMR-023 | FR-03 L4 → Codex 5.3 | L1 | bloom_level=4 | "gpt-5.3" |
| TC-DMR-024 | FR-03 L5 → Sonnet | L1 | bloom_level=5 | "claude-sonnet-4-5-20250929" |
| TC-DMR-025 | FR-03 L6 → Opus | L1 | bloom_level=6 | "claude-opus-4-6" |
| TC-DMR-026 | FR-03 セクション不在 → 空 | L1 | capability_tiers未定義 | "" (空文字列) |
| TC-DMR-027 | FR-03 範囲外(0) → exit 1 | L1 | bloom_level=0 | exit code 1 |
| TC-DMR-028 | FR-03 範囲外(7) → exit 1 | L1 | bloom_level=7 | exit code 1 |
| TC-DMR-029 | FR-03 コスト優先 | L1 | chatgpt_proとclaude_max同bloom | chatgpt_proグループのモデルが優先 |

### 3.4 FR-04: get_cost_group()

| TC ID | 要件 | レベル | 入力 | 期待値 |
|---|---|---|---|---|
| TC-DMR-030 | FR-04 Spark → chatgpt_pro | L1 | model="gpt-5.3-codex-spark" | "chatgpt_pro" |
| TC-DMR-031 | FR-04 Opus → claude_max | L1 | model="claude-opus-4-6" | "claude_max" |
| TC-DMR-032 | FR-04 未定義 → unknown | L1 | model="unknown" | "unknown" |
| TC-DMR-033 | FR-04 セクション不在 → unknown | L1 | capability_tiers未定義 | "unknown" |

### 3.5 NFR-01: 後方互換性

| TC ID | 要件 | レベル | 観点 | 期待値 |
|---|---|---|---|---|
| TC-DMR-040 | NFR-01 既存テスト回帰なし | L1 | test_cli_adapter.bats | Phase 1コード追加後も全テストPASS |
| TC-DMR-041 | NFR-01 旧settings.yaml互換 | L1 | cli/capability_tiers両方なし | get_cli_type, get_agent_model等が従来と同一結果 |

### 3.6 NFR-05: テスト容易性

| TC ID | 要件 | レベル | 観点 | 期待値 |
|---|---|---|---|---|
| TC-DMR-050 | NFR-05 設定注入 | L1 | CLI_ADAPTER_SETTINGS | テスト用YAMLが注入可能 |

### 3.7 NFR-06: 冪等性

| TC ID | 要件 | レベル | 観点 | 期待値 |
|---|---|---|---|---|
| TC-DMR-055 | NFR-06 連続呼出一致 | L1 | 同一入力2回呼出 | get_recommended_model()が同一結果を返す |

---

## 4. Phase 2 テストケース — Karo manual model_switch

### 4.1 FR-05: Karo manual model_switch

| TC ID | 要件 | レベル | 観点 | 期待値 |
|---|---|---|---|---|
| TC-DMR-100 | FR-05 switch不要判定 | L1 | bloom=3, model=spark | switch不要と判定 |
| TC-DMR-101 | FR-05 switch必要判定 | L1 | bloom=4, model=spark | switch必要と判定 |
| TC-DMR-102 | FR-05 capability_tiers不在 | L1 | セクションなし | 判定スキップ |
| TC-DMR-103 | FR-05 bloomフィールドなし | L1 | タスクYAMLにbloom_levelなし | 判定スキップ |

### 4.2 FR-06: Karo model_switch判定ロジック

| TC ID | 要件 | レベル | 観点 | 期待値 |
|---|---|---|---|---|
| TC-DMR-110 | FR-06 同CLI内switch | L2 | codex spark→codex 5.3 | model_switch inbox送信 |
| TC-DMR-111 | FR-06 CLI跨ぎ | L2 | bloom=5, codex足軽 | Claude足軽に再割当 |
| TC-DMR-112 | FR-06 Codex足軽switchスキップ | L2 | Codex足軽にmodel_switch | サイレントスキップ |
| TC-DMR-113 | FR-06 switch不要時は送信なし | L2 | bloom=3, spark足軽 | inbox送信なし |

### 4.3 NFR-02: モデル切替レイテンシ

| TC ID | 要件 | レベル | 観点 | 期待値 |
|---|---|---|---|---|
| TC-DMR-120 | NFR-02 関数応答速度 | L1 | get_capability_tier() | 500ms以内 |
| TC-DMR-121 | NFR-02 推奨モデル応答速度 | L1 | get_recommended_model() | 500ms以内 |

### 4.4 NFR-03: CLI互換性

| TC ID | 要件 | レベル | 観点 | 期待値 |
|---|---|---|---|---|
| TC-DMR-130 | NFR-03 Codexスキップ | L1 | CLI=codex, model_switch | エラーなし、処理スキップ |
| TC-DMR-131 | NFR-03 Copilotスキップ | L1 | CLI=copilot, model_switch | エラーなし、処理スキップ |

### 4.5 NFR-04: コスト最適化

| TC ID | 要件 | レベル | 観点 | 期待値 |
|---|---|---|---|---|
| TC-DMR-140 | NFR-04 L3にOpus不使用 | L1 | bloom=3 | Opusが選択されない |
| TC-DMR-141 | NFR-04 chatgpt_pro優先 | L1 | 同bloom対応モデル複数 | chatgpt_proグループが優先 |
| TC-DMR-142 | NFR-04 不要switch抑制 | L1 | 現model=推奨model | switch発生しない |

---

## 5. Phase 3 テストケース — Gunshi Bloom analysis layer

### 5.1 FR-07: gunshi_analysis.yaml スキーマ

| TC ID | 要件 | レベル | 観点 | 期待値 |
|---|---|---|---|---|
| TC-DMR-200 | FR-07 正常YAML | L1 | 全フィールド定義 | yaml.safe_load()成功、全フィールド読取可能 |
| TC-DMR-201 | FR-07 #48フィールド省略 | L1 | quality_criteria等なし | パースエラーなし |
| TC-DMR-202 | FR-07 bloom_level範囲 | L1 | bloom_level=0,7等 | バリデーションエラー |
| TC-DMR-203 | FR-07 confidence範囲 | L1 | confidence=-1, 2.0等 | バリデーションエラー |

### 5.2 FR-08: 軍師Bloom分析トリガー

| TC ID | 要件 | レベル | 観点 | 期待値 |
|---|---|---|---|---|
| TC-DMR-210 | FR-08 auto → 全タスク分析 | L2 | bloom_routing=auto | 軍師にinbox送信される |
| TC-DMR-211 | FR-08 manual → 明示依頼のみ | L2 | bloom_routing=manual | bloom_analysis_required=trueのタスクのみ |
| TC-DMR-212 | FR-08 off → 分析なし | L2 | bloom_routing=off | 軍師にinbox送信されない |
| TC-DMR-213 | FR-08 未定義 → off | L2 | bloom_routing未設定 | 軍師にinbox送信されない |
| TC-DMR-214 | FR-08 軍師未起動フォールバック | L2 | 軍師ペイン不在 | Phase 2動作にフォールバック |

### 5.3 FR-09: bloom_routing設定

| TC ID | 要件 | レベル | 観点 | 期待値 |
|---|---|---|---|---|
| TC-DMR-220 | FR-09 auto読取 | L1 | bloom_routing: auto | "auto" |
| TC-DMR-221 | FR-09 manual読取 | L1 | bloom_routing: manual | "manual" |
| TC-DMR-222 | FR-09 off読取 | L1 | bloom_routing: off | "off" |
| TC-DMR-223 | FR-09 未定義 → off | L1 | bloom_routing未設定 | "off" |
| TC-DMR-224 | FR-09 不正値 → off | L1 | bloom_routing: invalid | "off" + stderr警告 |

---

## 6. Phase 4 テストケース — Full auto-selection

### 6.1 FR-10: 品質フィードバック

| TC ID | 要件 | レベル | 観点 | 期待値 |
|---|---|---|---|---|
| TC-DMR-300 | FR-10 履歴追記 | L1 | タスク完了時 | model_performance.yamlに1行追記 |
| TC-DMR-301 | FR-10 履歴読取 | L1 | 過去10件読取 | task_type×bloom_level別の集計が可能 |
| TC-DMR-302 | FR-10 空ファイル | L1 | model_performance.yaml不在 | エラーなし |
| TC-DMR-303 | FR-10 適合度算出 | L1 | 同一条件のpass/fail統計 | pass率が算出可能 |

---

## 7. ユニットテスト範囲（Phase 1実装対象）

### 7.1 capability_tier読取

- UT-DMR-001: 定義済みモデルのmax_bloom取得
- UT-DMR-002: 未定義モデルのデフォルト値(6)取得
- UT-DMR-003: セクション不在時のデフォルト値(6)取得
- UT-DMR-004: YAML破損時のデフォルト値(6)取得

### 7.2 推奨モデル選定

- UT-DMR-010: L1-L3 → Spark選定
- UT-DMR-011: L4 → Codex 5.3選定
- UT-DMR-012: L5 → Sonnet Thinking選定
- UT-DMR-013: L6 → Opus Thinking選定
- UT-DMR-014: chatgpt_proグループ優先
- UT-DMR-015: 範囲外入力のエラーハンドリング
- UT-DMR-016: 冪等性（2回呼出で同一結果）

### 7.3 コストグループ

- UT-DMR-020: 各モデルのcost_group取得
- UT-DMR-021: 未定義モデルの"unknown"取得

---

## 8. 統合テスト範囲（Phase 2以降、家老担当）

- IT-DMR-001: model_switch inbox → 足軽モデル変更確認
- IT-DMR-002: CLI跨ぎ時の足軽再割当
- IT-DMR-003: Codex/Copilot足軽へのmodel_switchスキップ
- IT-DMR-004: 軍師Bloom分析 → 家老model_switch → 足軽実行の連携
- IT-DMR-005: bloom_routingフラグによる軍師分析の制御

---

## 9. E2E範囲（殿担当）

- E2E-DMR-001: 殿→将軍→軍師(Bloom分析)→家老(switch)→足軽(実行)の全系統完走
- E2E-DMR-002: L3タスクとL5タスクの混在時、異なるモデルで実行されること
- E2E-DMR-003: capability_tiers追加前後でshutsuijinの正常起動を確認

---

## 10. 前提条件（Preflight）

- `bash`, `python3`, `bats` が利用可能
- `.venv/bin/python3` が PyYAML をインポート可能
- L2以上は `tmux`, `inotifywait` が利用可能
- テスト用 settings.yaml が注入可能（CLI_ADAPTER_SETTINGS環境変数）

前提未充足時:
- 該当テストは実行せず、未充足理由を記録する
- SKIP報告は禁止（未完了として扱う）

---

## 11. テストケースIDサマリ

| Phase | TC ID範囲 | 件数 | レベル |
|-------|----------|------|--------|
| Phase 1 | TC-DMR-001〜055 | 23件 | L1 |
| Phase 2 | TC-DMR-100〜142 | 15件 | L1/L2 |
| Phase 3 | TC-DMR-200〜224 | 14件 | L1/L2 |
| Phase 4 | TC-DMR-300〜303 | 4件 | L1 |
| **合計** | | **56件** | |

---

## 12. FR/NFRトレース

| 要件ID | TC ID(s) | Phase |
|--------|----------|-------|
| FR-01 | TC-DMR-001〜003 | 1 |
| FR-02 | TC-DMR-010〜017 | 1 |
| FR-03 | TC-DMR-020〜029 | 1 |
| FR-04 | TC-DMR-030〜033 | 1 |
| FR-05 | TC-DMR-100〜103 | 2 |
| FR-06 | TC-DMR-110〜113 | 2 |
| FR-07 | TC-DMR-200〜203 | 3 |
| FR-08 | TC-DMR-210〜214 | 3 |
| FR-09 | TC-DMR-220〜224 | 3 |
| FR-10 | TC-DMR-300〜303 | 4 |
| NFR-01 | TC-DMR-040〜041 | 1 |
| NFR-02 | TC-DMR-120〜121 | 2 |
| NFR-03 | TC-DMR-130〜131 | 2 |
| NFR-04 | TC-DMR-140〜142 | 2 |
| NFR-05 | TC-DMR-050 | 1 |
| NFR-06 | TC-DMR-055 | 1 |

全FR/NFR(16件)に対し1件以上のTCが存在。欠落なし。

---

**テスト仕様書完了**: 2026-02-17
**次のアクション**: Phase 1のbatsテスト実装 → cli_adapter.shにFR-01〜FR-04の関数追加
