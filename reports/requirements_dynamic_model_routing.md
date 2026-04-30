# Dynamic Model Routing 要件定義書

| 項目 | 内容 |
|---|---|
| 文書ID | DMR-REQ-001 |
| Issue | #53 |
| 作成日 | 2026-02-17 |
| 参照設計 | Issue #53 body, Issue #48 (共有インターフェース) |
| 対象 | Phase 1-4 段階的実装 |

---

## 0. 用語定義

| 用語 | 定義 |
|---|---|
| Bloom Level | Bloom's Taxonomy (L1-L6) によるタスク認知レベル分類 |
| capability_tier | モデルが対応可能なBloomレベル上限の定義 |
| model_switch | 足軽のCLIモデルを動的に切り替えるinbox type |
| gunshi_analysis | 軍師がタスクを分析し、Bloomレベル+推奨モデルを出力するYAML |
| bloom_routing | settings.yaml の設定。auto/manual/off |

### Bloom Taxonomy Levels

| Level | 名称 | タスク例 | 対応モデル下限 |
|---|---|---|---|
| L1 | Remember | テンプレ記事生成、定型ファイルコピー | Spark |
| L2 | Understand | 既存コード読解、ドキュメント要約 | Spark |
| L3 | Apply | 既知パターンの適用、SEO記事量産 | Spark |
| L4 | Analyze | バグ原因分析、コードレビュー、リファクタ | Codex 5.3 |
| L5 | Evaluate | 設計妥当性判断、アーキテクチャ評価 | Sonnet Thinking |
| L6 | Create | 新規設計、要件定義、戦略策定 | Opus Thinking |

---

## 1. 機能要件（FR: Functional Requirements）

### Phase 1: capability_tier definition

#### FR-01: settings.yaml — capability_tiersセクション

**概要**: モデル→Bloomレベル上限のマッピングをsettings.yamlに定義

**スキーマ**:
```yaml
capability_tiers:
  gpt-5.3-codex-spark:
    max_bloom: 3
    cost_group: chatgpt_pro
  gpt-5.3:
    max_bloom: 4
    cost_group: chatgpt_pro
  claude-sonnet-4-5-20250929:
    max_bloom: 5
    cost_group: claude_max
  claude-opus-4-6:
    max_bloom: 6
    cost_group: claude_max
```

**受け入れ条件**:
- [ ] capability_tiersセクションが省略された場合、全機能が現行動作を維持（後方互換）
- [ ] 各モデルに `max_bloom` (integer 1-6) と `cost_group` (string) が定義できる
- [ ] 未定義モデルはmax_bloom=6（制限なし）として扱う
- [ ] cost_groupは情報フィールドのみ（Phase 1ではロジックに使用しない）

---

#### FR-02: cli_adapter.sh — get_capability_tier()

**概要**: 指定モデルのBloomレベル上限を返す関数

**入力**: `$1 model_name` (例: "gpt-5.3-codex-spark", "claude-opus-4-6")

**出力**: stdout に integer (1-6) を出力。exit code 0。

**ロジック**:
1. `capability_tiers.{model_name}.max_bloom` をsettings.yamlから読取
2. 未定義 → 6 を返す（制限なしとして扱う）
3. settings.yaml読取失敗 → 6 を返す

**受け入れ条件**:
- [ ] `get_capability_tier "gpt-5.3-codex-spark"` → "3"
- [ ] `get_capability_tier "claude-opus-4-6"` → "6"
- [ ] 未定義モデル → "6"
- [ ] capability_tiersセクション不在 → "6"
- [ ] settings.yaml破損 → "6"

---

#### FR-03: cli_adapter.sh — get_recommended_model()

**概要**: 指定Bloomレベルに対応する最もコスト効率の良いモデルを返す

**入力**: `$1 bloom_level` (integer 1-6)

**出力**: stdout にモデル名を出力

**ロジック（コスト最小化）**:
1. capability_tiersから `max_bloom >= bloom_level` のモデルを全て列挙
2. そのうち `max_bloom` が最も小さいモデルを選択（ちょうど足りるモデル）
3. 同一max_bloomが複数 → cost_group優先（chatgpt_pro > claude_max）
4. 該当なし → 最大max_bloomのモデルを返す

**エスカレーション順序**:
```
L1-L3 → gpt-5.3-codex-spark (Spark)
L4    → gpt-5.3 (Codex 5.3)
L5    → claude-sonnet-4-5-20250929 (Sonnet Thinking)
L6    → claude-opus-4-6 (Opus Thinking)
```

**受け入れ条件**:
- [ ] `get_recommended_model 3` → "gpt-5.3-codex-spark"
- [ ] `get_recommended_model 4` → "gpt-5.3"
- [ ] `get_recommended_model 5` → "claude-sonnet-4-5-20250929"
- [ ] `get_recommended_model 6` → "claude-opus-4-6"
- [ ] `get_recommended_model 1` → "gpt-5.3-codex-spark"（最もコスト効率が良い）
- [ ] capability_tiersセクション不在 → 空文字列（ルーティング不可を表す）
- [ ] bloom_levelが範囲外（0, 7等） → 空文字列 + exit code 1

---

#### FR-04: cli_adapter.sh — get_cost_group()

**概要**: 指定モデルのコストグループを返す

**入力**: `$1 model_name`

**出力**: stdout に "chatgpt_pro" | "claude_max" | "unknown"

**受け入れ条件**:
- [ ] `get_cost_group "gpt-5.3-codex-spark"` → "chatgpt_pro"
- [ ] `get_cost_group "claude-opus-4-6"` → "claude_max"
- [ ] 未定義モデル → "unknown"

---

### Phase 2: Karo manual model_switch

#### FR-05: Karo manual model_switch

**概要**: 家老がタスク内容を見て、手動でmodel_switchを判断・実行

**トリガー**:
- 殿が明示的に指示（「このタスクはSonnetでやれ」）
- 家老がタスクのBloomレベルを目視判断

**フロー**:
```
1. 家老がタスクYAMLを作成（通常通り）
2. 家老がget_capability_tier()で現在モデルの能力を確認
3. タスクのBloomレベルが現在モデルの上限を超えると判断
4. model_switch inbox + task_assigned inbox を順次送信
5. 足軽がモデル切替後にタスクを実行
```

**受け入れ条件**:
- [ ] model_switchの既存inbox_watcher.sh処理が正常動作する
- [ ] Claude Code足軽に対してのみmodel_switchが送信される（Codex/Copilot = スキップ）
- [ ] model_switch後のタスク実行が正常に開始される
- [ ] capability_tiersが未定義の場合、model_switchは実行されない（現行動作維持）

---

#### FR-06: Karo model_switch判定ロジック

**概要**: 家老がタスク配布時にモデル適合性を判定する関数

**入力**: タスクYAML（task_id, bloom_level フィールド）

**ロジック**:
```
1. タスクYAMLの bloom_level を読取（未指定 → 判定スキップ）
2. 割当先足軽の現在モデルを get_agent_model() で取得
3. 現在モデルの max_bloom を get_capability_tier() で取得
4. bloom_level > max_bloom → model_switch が必要
5. get_recommended_model(bloom_level) で推奨モデルを取得
6. 推奨モデルのCLI種別が足軽のCLI種別と一致するか確認
7. CLI種別不一致 → 別の足軽に割当 or スキップ（家老判断）
```

**受け入れ条件**:
- [ ] bloom_level=3, 現在model=spark → switch不要
- [ ] bloom_level=4, 現在model=spark → switch必要、推奨=codex-5.3
- [ ] bloom_level=5, 現在model=codex → CLI不一致（codex→claude必要）→ Claude足軽に再割当
- [ ] bloom_levelフィールドなし → 判定スキップ（現行動作）
- [ ] capability_tiers未定義 → 判定スキップ（現行動作）

---

### Phase 3: Gunshi Bloom analysis layer

#### FR-07: gunshi_analysis.yaml スキーマ（共有インターフェース）

**概要**: 軍師のタスク分析結果を格納するYAML。#53と#48の共有インターフェース。

**スキーマ**:
```yaml
# queue/analysis/gunshi_analysis.yaml
task_id: subtask_xxx
timestamp: "ISO 8601"
analysis:
  # #53の領域: モデルルーティング
  bloom_level: 4          # L1-L6
  bloom_reasoning: "バグ修正タスク。コード読解+原因分析が必要"
  recommended_model: "gpt-5.3"
  recommended_cli: "codex"
  confidence: 0.85        # 0.0-1.0 判定確信度

  # #48の領域: 品質基準（Phase 4で使用）
  quality_criteria:
    - "既存テストがパスすること"
    - "変更箇所にユニットテスト追加"
  qc_method: automated    # automated / gunshi_review / lord_review
  pdca_needed: false      # trueならPDCAループに入る
```

**受け入れ条件**:
- [ ] task_id と timestamp が必須フィールド
- [ ] analysis.bloom_level が integer 1-6
- [ ] analysis.recommended_model が capability_tiersに定義されたモデル名
- [ ] analysis.confidence が float 0.0-1.0
- [ ] #48領域のフィールド（quality_criteria, qc_method, pdca_needed）は省略可能
- [ ] YAMLが python3 yaml.safe_load() で正常パース可能

---

#### FR-08: 軍師Bloom分析トリガー

**概要**: 家老が軍師にBloom分析を依頼するフロー

**トリガー条件**:
- `bloom_routing: auto` 設定時 → 全タスクで軍師分析を実施
- `bloom_routing: manual` 設定時 → 家老が必要と判断した場合のみ
- `bloom_routing: off` 設定時 → 軍師分析なし（Phase 2動作）

**フロー**:
```
1. 家老がタスクを受領
2. bloom_routing設定を確認
3. auto → 軍師にinbox_write（分析依頼）
4. 軍師がタスクを分析 → gunshi_analysis.yaml を書き込み
5. 軍師が家老にinbox_write（分析完了通知）
6. 家老がgunshi_analysis.yamlを読取
7. recommended_modelに基づきmodel_switch判定（FR-06ロジック）
8. タスク配布
```

**受け入れ条件**:
- [ ] bloom_routing=auto → 全タスクで軍師分析が発火
- [ ] bloom_routing=manual → 家老の明示的判断時のみ発火
- [ ] bloom_routing=off → 軍師分析なし
- [ ] bloom_routing未定義 → off扱い（後方互換）
- [ ] 軍師が未起動の場合 → 分析スキップ、Phase 2動作にフォールバック

---

#### FR-09: bloom_routing設定

**概要**: settings.yamlにbloom_routing設定を追加

**スキーマ**:
```yaml
bloom_routing: off   # auto | manual | off
```

**受け入れ条件**:
- [ ] "auto" → 全タスクで軍師Bloom分析を自動実施
- [ ] "manual" → 家老が個別判断（タスクYAMLにbloom_analysis_required: trueで依頼）
- [ ] "off" → Bloom分析なし、Phase 2の手動switch or 固定モデル
- [ ] 未定義 → "off" 扱い（後方互換）
- [ ] 不正値 → "off" + stderr警告

---

### Phase 4: Full auto-selection

#### FR-10: 品質フィードバックによるモデル選定改善

**概要**: QC結果を蓄積し、タスク種別×モデルの適合度を学習

**スキーマ（蓄積データ）**:
```yaml
# queue/analysis/model_performance.yaml
history:
  - task_id: subtask_xxx
    task_type: seo_article
    bloom_level: 3
    model_used: gpt-5.3-codex-spark
    qc_result: pass    # pass / fail / partial
    qc_score: 0.85
    timestamp: "ISO 8601"
```

**受け入れ条件**:
- [ ] タスク完了ごとにQC結果がmodel_performance.yamlに追記される
- [ ] 同一task_type×bloom_levelの過去実績からモデル適合度を算出可能
- [ ] 適合度が閾値未満のモデル → 次回からエスカレーション推奨
- [ ] Phase 4未実装時はmodel_performance.yamlが空でもエラーにならない

---

## 2. 非機能要件（NFR: Non-Functional Requirements）

### NFR-01: 後方互換性

**概要**: capability_tiers、bloom_routingが未定義のsettings.yamlで現行動作が完全維持されること

**受け入れ条件**:
- [ ] capability_tiers未定義 → 全関数がデフォルト値を返し、既存動作に変化なし
- [ ] bloom_routing未定義 → off扱い、軍師分析なし
- [ ] Phase 1コード追加後、既存テスト（test_cli_adapter.bats）が全PASS
- [ ] settings.yaml に capability_tiers を追加しても、追加しなくても shutsujin が正常起動

---

### NFR-02: モデル切替レイテンシ

**概要**: model_switch発行→足軽がタスク開始までの時間が許容範囲内

**受け入れ条件**:
- [ ] get_capability_tier() の応答時間: 500ms以内
- [ ] get_recommended_model() の応答時間: 500ms以内
- [ ] model_switch inbox → 足軽のモデル変更完了: 10秒以内（Claude Code /model コマンド）
- [ ] 軍師Bloom分析（FR-08のStep 3-5）: 60秒以内

---

### NFR-03: CLI互換性

**概要**: model_switchはClaude Code足軽でのみ動作。他CLIではサイレントスキップ。

**受け入れ条件**:
- [ ] Codex CLI足軽: model_switchが送信されてもエラーにならない（既存の動作維持）
- [ ] Copilot CLI足軽: 同上
- [ ] CLI種別不一致時のフォールバック動作が定義されている
- [ ] get_recommended_model() の結果がCLI種別を考慮（chatgpt_pro→codex足軽、claude_max→claude足軽）

---

### NFR-04: コスト最適化

**概要**: 可能な限り低コストモデルを選択し、不必要なエスカレーションを防止

**受け入れ条件**:
- [ ] L1-L3タスクにOpus Thinkingが選択されないこと
- [ ] L4タスクにSpark以外が選択されること
- [ ] 同一Bloomレベルで複数モデルが候補の場合、chatgpt_pro枠が優先される
- [ ] model_switch回数が最小限（タスク間でモデルが変わらない場合はswitchしない）

---

### NFR-05: テスト容易性

**概要**: 全Bloomルーティング関数がtmux/実CLIなしでテスト可能

**受け入れ条件**:
- [ ] get_capability_tier(), get_recommended_model(), get_cost_group() はsettings.yamlのみに依存
- [ ] テスト用settings.yamlを注入可能（CLI_ADAPTER_SETTINGS環境変数）
- [ ] gunshi_analysis.yamlの検証がPythonスクリプトで自動化可能
- [ ] model_performance.yamlの検証がPythonスクリプトで自動化可能

---

### NFR-06: 冪等性

**概要**: 同一入力に対して常に同一の推奨モデルを返すこと

**受け入れ条件**:
- [ ] get_recommended_model() に同一bloom_levelを渡すと、常に同一のモデル名を返す
- [ ] gunshi_analysis.yamlの同一タスクに対する分析結果が安定する（confidenceが閾値以上）
- [ ] model_performance.yamlの履歴追加が既存データを破壊しない

---

## 3. 要件一覧サマリ

| カテゴリ | ID範囲 | 件数 | Phase 1 | Phase 2 | Phase 3 | Phase 4 |
|---------|--------|------|---------|---------|---------|---------|
| 機能要件 | FR-01〜FR-10 | 10件 | FR-01〜FR-04 | FR-05〜FR-06 | FR-07〜FR-09 | FR-10 |
| 非機能要件 | NFR-01〜NFR-06 | 6件 | NFR-01,05,06 | NFR-02,03,04 | 全NFR | 全NFR |
| **合計** | | **16件** | **7件** | **5件** | **3件** | **1件** |

### Phase別実装順序

| Phase | 必須要件 | 依存 | 推定工数 |
|-------|---------|------|---------|
| Phase 1 | FR-01〜FR-04, NFR-01,05,06 | なし（設定+関数追加のみ） | 小 |
| Phase 2 | FR-05〜FR-06, NFR-02,03,04 | Phase 1 | 中 |
| Phase 3 | FR-07〜FR-09 + 全NFR | Phase 2, #48との共有IF | 大 |
| Phase 4 | FR-10 + 全NFR | Phase 3 + #48 | 大 |

---

## 4. #48との境界定義

| 領域 | #53 (本Issue) | #48 |
|------|--------------|-----|
| Bloom判定 | **担当** | 利用（軍師分析結果を読むだけ） |
| モデル選定 | **担当** | 利用しない |
| model_switch実行 | **担当** | 利用しない |
| capability_tiers定義 | **担当** | 利用しない |
| 品質基準設計 | 利用しない | **担当** |
| PDCAループ | 利用しない | **担当** |
| QCチェック | 利用しない | **担当** |
| gunshi_analysis.yaml | bloom_level, recommended_model | quality_criteria, qc_method, pdca_needed |

**共有インターフェース**: `queue/analysis/gunshi_analysis.yaml` — 軍師が1回の分析で両Issue向けの出力を生成。

---

**要件定義完了**: 2026-02-17
**次のアクション**: テストスペック作成 → batsテスト実装 → Phase 1コーディング
