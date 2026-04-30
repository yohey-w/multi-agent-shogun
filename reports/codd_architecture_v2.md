# CPDD アーキテクチャ設計書 v2（統合版）

**作成日**: 2026-03-14
**ステータス**: v2 — Claude Opus 4.6 設計 × GPT-5.4 Pro Thinking (Heavy) 検証の統合版
**前版**: cpdd_architecture.md (v1)

---

## 0. この文書の位置づけ

CPDDの核心的な問いに答える設計書。

**「エンタープライズシステムで、ある箇所を変更したとき、影響を受ける全箇所をAIがどうやって特定するのか？」**

v1（Claude Opus 4.6 単独設計）に対し、GPT-5.4 Pro Thinking (Heavy) による22問の深層検証を突合し、12項目の設計改善を統合した版。

### 統合で取り込んだ主要改善

| # | 改善内容 | 出典 |
|---|---------|------|
| 1 | エッジに condition predicate（有効条件）追加 | GPT-5.4 |
| 2 | Evidence Ledger（証拠の分離管理）導入 | GPT-5.4 |
| 3 | 3帯域分類（Green/Amber/Gray）+ artifact別閾値 | GPT-5.4 |
| 4 | Change Atom taxonomy（11種の変更分類） | GPT-5.4 |
| 5 | 停止条件の5段階精密化 | GPT-5.4 |
| 6 | Phase 2に framework introspection 追加 | GPT-5.4 |
| 7 | Stage 3に OTel trace correlation 追加 | GPT-5.4 |
| 8 | 循環依存処理に SCC + state dominance 追加 | GPT-5.4 |
| 9 | 柱1を「graph delta生成」に再定義 | GPT-5.4 |
| 10 | コンテキスト選択を ambiguity-based + MMR knapsack に | GPT-5.4 |
| 11 | Noisy-OR をスコア集約方式に採用 | GPT-5.4 |
| 12 | 外部説明は5層、内部実装は3軸の dual表現 | 統合判断 |

---

## 1. 問題の形式化

### 1.1 エンタープライズシステムの構成要素

システム S は以下の要素で構成される:

| 記号 | 要素 | 例 |
|------|------|-----|
| **C** | ソースコード | ファイル、関数、クラス、メソッド |
| **K** | 設定 | config.yaml、環境変数、feature flag、DI定義 |
| **D** | データ定義 | DBスキーマ、マスターテーブル、migration |
| **W** | ドキュメント | 要件定義書、基本設計書、詳細設計書、テスト仕様書 |
| **I** | 暗黙知 | 慣習、パターン、障害履歴、レビュー知見 |

### 1.2 変更影響問題

変化点 Δ が任意の要素 e ∈ {C ∪ K ∪ D ∪ W ∪ I} に発生したとき:

**影響セット E' = { e' | e' は Δ の影響を受ける } を求めよ。**

ただし、影響は**条件付き**である。環境（prod/staging/dev）、テナント、feature flag、時間帯で有効な依存が変わる。

### 1.3 なぜ既存手法では解けないのか

#### 外部説明用: 5層モデル

エンジニアへの説明にはこちらを使う。

```
Layer 5: 慣習依存 ─── 「キャッシュテーブルを変えたらバッチも直す」（どこにも書いてない）
Layer 4: データ依存 ── マスターテーブルの値がビジネスロジックを制御（コードにはSELECT文しかない）
Layer 3: 設定依存 ─── config値で呼び出し先が分岐（静的解析では1メソッドに見える）
Layer 2: コード構造 ── import, 関数呼び出し, 継承（LSP/ASTで解ける）
Layer 1: ファイル ─── ファイル間の参照（grep/globで解ける）
```

#### 内部実装用: 3軸モデル

実装・データモデルにはこちらを使う。5層は境界が曖昧になるケースがある（設定がマスターデータを参照する等）。3軸分類なら本質的に分離できる。

**軸1: 依存の意味論（Semantic）**

| 分類 | 説明 | 5層との対応 |
|------|------|------------|
| Structural | import, call, inheritance, schema reference | Layer 1-2 |
| Resolution | DI, profile, feature flag, plugin, registry, config lookup | Layer 3 |
| Behavioral | data value が branch/dispatch/output を制御 | Layer 4 |
| Validation | requirement, test, monitor, runbook が何を検証・担保するか | V字モデル |
| Governance | ownership, convention, review rule, incident memory | Layer 5 |

**軸2: 証拠の出所（Evidence Source）**

| 出所 | 説明 |
|------|------|
| static | AST, LSP, SQL parser, config parser |
| framework | Spring Actuator, Guice introspection, plugin descriptor |
| dynamic | OTel traces, runtime observation, test execution |
| human | 人間注釈、ADR、レビューコメント |
| history | git co-changes, 障害履歴, rollback記録 |
| inferred | LLM推論（最後の手段） |

**軸3: 有効条件（Condition）**

| 条件 | 説明 |
|------|------|
| environment | prod / staging / dev / test |
| tenant | マルチテナントの場合 |
| feature_flag | ON/OFFで依存が変わる |
| time_window | 年度切替、バッチ実行時間帯 |
| data_predicate | マスターデータの値による条件 |

#### 既存ツールの到達点

| ツール | Structural | Resolution | Behavioral | Validation | Governance |
|--------|:----------:|:----------:|:----------:|:----------:|:----------:|
| grep/glob | △ | - | - | - | - |
| Aider Repo Map | ✅ | - | - | - | - |
| LSPRAG | ✅ | - | - | - | - |
| Ripple (ICSE 2026) | ✅ | △ | - | - | - |
| DOORS/Polarion | - | - | - | △ | - |
| BMAD-METHOD | - | - | - | ✅ | - |
| Intent (Augment) | ✅ | △ | - | - | - |
| **CPDD（目標）** | **✅** | **✅** | **✅** | **✅** | **✅** |

**Resolution〜Governanceが未開拓領域。ここがCPDDのフロンティア。**

---

## 2. 熟練エンジニアのメンタルモデル分析

### 2.1 熟練エンジニアの思考フロー

```
「この関数を直す」
    │
    ├─ 即座に思い浮かぶ（メンタルモデル）
    │   「この関数はconfig.payment.providerで分岐するから、
    │    Stripe/PayPal両方のアダプタに影響する」
    │   「ただし本番は今Stripeしか使ってないから、
    │    PayPalは確認だけでいい」              ← ★条件付き判断
    │   「このマスターを使ってるバッチが夜間に走るから、
    │    反映タイミングに注意」
    │
    ├─ 確認のために調べる（検証）
    │   grep, IDE検索, DB検索, Actuatorの/beans確認
    │
    └─ 経験から推測する（推論）
        「前にここを触った時、あのテストが壊れたから、
         今回も同じパターンだろう」
```

### 2.2 メンタルモデルの構成要素

熟練エンジニアの頭の中にあるもの:

1. **構造知識**: 「モジュールAはモジュールBに依存している」（Structural）
2. **解決知識**: 「この設定値を変えるとDIの解決先が変わる」（Resolution）
3. **挙動知識**: 「このマスターの値がビジネスロジックを制御する」（Behavioral）
4. **検証知識**: 「この要件はあのテストで担保されている」（Validation）
5. **統治知識**: 「ここを触ったら必ずあそこも壊れる」「あの人に聞け」（Governance）
6. **条件知識**: 「本番ではStripeだけだが、ステージングではPayPalも」（Condition）

### 2.3 CPDDが再現すべきもの

**全てを完璧に再現する必要はない。**

ただし「7割の精度」は単一スカラーでは危険。3つの指標に分ける:

| 指標 | 定義 | 目標 |
|------|------|------|
| **Review Recall** | 本当に確認すべきものを候補に入れられたか | 70%以上 |
| **Auto-update Precision** | 自動更新したものが安全だったか | 95%以上 |
| **Explanation Acceptance** | 提示した影響パスを人間が納得したか | 70%以上 |

意味論ごとの現実的な精度見積り:

| 依存の種類 | Precision | Recall | 備考 |
|-----------|-----------|--------|------|
| Structural | 90-98% | 80-95% | 既存技術で十分 |
| Resolution（FW対応+runtime証拠あり） | 70-90% | 60-85% | Actuator等で底上げ |
| Behavioral（instrumentation あり） | 50-80% | 40-70% | OTel併用で改善 |
| Governance | 40-70% | 30-60% | 人間注釈の蓄積が鍵 |

**狙うべきは:**
- must-review帯域のcritical recallを最大化
- auto-update帯域のprecisionを極限まで高く
- 上位K件のimpact listで重要影響の70%を拾う

---

## 3. 条件付き証拠グラフ (Conditioned Evidence Graph: CEG)

v1の「UDG（統合依存グラフ）」を改名・再設計。plain graphではなく、**条件付き・証拠付き・時間付きのproperty graph + reified relation**。

### 3.1 概要

```
┌─────────────────────────────────────────────┐
│      Conditioned Evidence Graph (CEG)       │
│                                             │
│   [要件定義] ──→ [基本設計] ──→ [詳細設計]    │
│       ↕              ↕             ↕         │
│   [受入テスト] ← [結合テスト] ← [単体テスト]    │
│       ↕              ↕             ↕         │
│   [設定K] ────→ [コードC] ←──── [データD]     │
│                    ↕                         │
│              [暗黙知I]                       │
│                                             │
│   ノード: 任意のアドレス可能な要素              │
│   リレーション: 型付き + 条件付き + 証拠付き     │
│   証拠: Evidence Ledgerで独立管理             │
└─────────────────────────────────────────────┘
```

### 3.2 ノード定義

```yaml
node_types:
  # Artifact nodes
  repository:        # リポジトリ
  module:            # モジュール / bounded context
  file:              # ファイル
  document_section:  # 設計書セクション
  test_case:         # テストケース
  runbook:           # 運用手順書
  adr:               # Architecture Decision Record
  incident:          # 障害記録

  # Symbol nodes
  package:           # パッケージ / 名前空間
  class:             # クラス / インターフェース
  method:            # メソッド / 関数
  endpoint:          # APIエンドポイント
  event:             # イベント / メッセージトピック
  sql_statement:     # SQL文
  db_table:          # DBテーブル
  db_column:         # DBカラム
  config_key:        # 設定キー
  feature_flag:      # フィーチャーフラグ
  batch_job:         # バッチジョブ

  # Contract nodes
  requirement:       # 要件
  design_decision:   # 設計判断
  api_contract:      # API契約（OpenAPI等）
  schema_contract:   # スキーマ契約（DDL, migration）
  invariant:         # 不変条件
  test_oracle:       # テストの期待値

  # Runtime / Governance nodes
  bean:              # DI Bean / Provider
  profile:           # 環境プロファイル
  tenant:            # テナント / プロダクトバリアント
  convention:        # 慣習 / 暗黙のルール
  owner:             # オーナー / チーム

# 各ノードの必須属性
node_attributes:
  id:                # 一意識別子
  type:              # 上記のいずれか
  subtype:           # 詳細分類
  boundary_id:       # 所属するbounded context
  source_uri:        # ソースの場所（ファイルパス、URL等）
  snapshot_id:       # グラフのスナップショットID（★時間管理）
  valid_from:        # 有効開始日時
  valid_to:          # 有効終了日時（null = 現在有効）
  content_hash:      # 内容ハッシュ
  structural_hash:   # 構造ハッシュ（コメント変更等を無視）
  contract_hash:     # 契約ハッシュ（public interface部分のみ）
  criticality:       # 重要度（business_critical, normal, peripheral）
  owner:             # 責任者
  summary_refs:      # 要約への参照
  labels:            # 自由タグ
```

### 3.3 リレーション定義

リレーションは単なるsrc-dst-edgeではなく、**条件付き・証拠付き**。n項関係が必要な場合はrelation nodeにreifyする。

```yaml
relation_classes:

  # Structural（自動検出、高信頼度）
  structural:
    - contains       # モジュールがファイルを含む
    - defines        # ファイルがクラス/関数を定義
    - imports        # ファイルが別ファイルをインポート
    - calls          # 関数Aが関数Bを呼ぶ
    - implements     # クラスがインターフェースを実装
    - extends        # クラスが別クラスを継承
    - queries        # コードがテーブルをSELECT
    - mutates        # コードがテーブルをINSERT/UPDATE/DELETE
    - reads_config   # コードが設定値を読む
    - writes_config  # コードが設定値を書く

  # Resolution（FW解析+runtime観測、中〜高信頼度）
  resolution:
    - bound_from_config    # 設定値からBeanが決定
    - selected_by          # 条件でimpl/handlerが選択
    - active_under         # profile/flagで有効化
    - provided_by          # ServiceLoader/SPI/pluginで提供
    - loaded_via           # リフレクション/動的ロードで取得
    - resolved_by_registry # カスタムファクトリ/レジストリで解決

  # Behavioral（データ駆動、中信頼度）
  behavioral:
    - column_controls_branch  # カラム値がif/switchを制御
    - value_routes_to         # 値がルーティング先を決定
    - threshold_affects       # 閾値が判定結果を左右
    - flag_switches           # フラグが挙動を切り替え
    - policy_governs          # ポリシーテーブルがロジックを統治

  # Validation（検証関係）
  validation:
    - satisfies_requirement     # 実装が要件を満たす
    - validated_by_test         # テストが実装を検証
    - monitored_by              # 監視が実装を見張る
    - documented_by             # ドキュメントが実装を説明
    - operationalized_by_runbook # 運用手順が実装を操作

  # Governance（統治・暗黙知）
  governance:
    - owned_by                    # 責任者
    - reviewed_by                 # レビュー者
    - co_changed_with             # 過去に同時変更された
    - convention_requires         # 慣習で一緒に変更すべき
    - incident_correlated_with    # 障害で関連が判明した

# 各リレーションの属性
relation_attributes:
  id:                          # 一意識別子
  kind:                        # 上記のいずれか
  src_ids: []                  # ソースノードID（複数可: n項関係）
  dst_ids: []                  # ターゲットノードID（複数可）
  directionality:              # forward / reverse / bidirectional
  condition_predicate:         # ★v2追加: 有効条件
  forward_transfer_profile:    # 順方向の伝播規則
  reverse_transfer_profile:    # 逆方向の伝播規則
  confidence:                  # 信頼度（Evidence Ledgerから計算）
  freshness:                   # 鮮度（最終検証からの経過）
  evidence_ids: []             # ★v2追加: 証拠への参照
  context_tags: []             # 文脈タグ
```

### 3.4 Evidence Ledger（証拠台帳）

**v2で新規追加。** confidenceをエッジに直接書くのではなく、証拠を独立管理し、confidenceを再計算可能にする。

```yaml
evidence:
  id:                    # 証拠ID
  source_type:           # static / framework / dynamic / human / history / inferred
  extractor:             # 検出器名（tree-sitter, actuator, otel, human:watanabe, git-cochange等）
  timestamp:             # 記録日時
  artifact_ref:          # 参照先（ファイルパス、コミットハッシュ、チケット番号等）
  snippet_ref:           # 該当箇所の引用
  supports_or_contradicts: # supports / contradicts
  raw_score:             # 生スコア
  calibrated_score:      # 校正済みスコア
  context:               # 文脈情報

# confidence計算方式: Noisy-OR
# edge_confidence = 1 - Π(1 - calibrated_score_i) + contradiction_penalty
#
# 複数の弱い証拠が集まると強くなる。
# これは熟練者の「いくつかの匂いが一致したから怪しい」を数理的に表現。
```

### 3.5 Change Atom（変更の正規化）

**v2で新規追加。** 変更を正規化してから伝播する。同じ「ファイル変更」でも種類によって伝播パターンが全く異なる。

```yaml
change_atom:
  id:                # 変更ID
  target_node_id:    # 変更対象ノード
  facet:             # contract / impl / config / data / doc / test / req
  delta_kind:        # add / remove / modify / rename / semantic_shift
  severity:          # critical / major / minor / cosmetic

change_taxonomy:
  # 変更の種類（11分類）
  - InterfaceContractChanged      # public APIの型・シグネチャ変更 → 広く伝播
  - ImplementationSemanticsChanged # 内部実装の意味変更 → test/validationへ
  - RefactoringNoSemanticIntent    # リファクタリング（意味変更なし）→ 最小伝播
  - ConfigDefaultChanged           # 設定のデフォルト値変更 → 条件付き伝播
  - ConfigResolutionRuleChanged    # 設定の解決規則変更 → Resolution依存へ
  - SchemaChanged                  # DBスキーマ変更 → query/ORM/migrationへ
  - MasterValueAdded               # マスターデータの行追加 → validation/UIへ
  - MasterValueRemoved             # マスターデータの行削除 → 危険、広く伝播
  - MasterMeaningChanged           # マスターデータの意味変更 → 最も危険
  - RequirementChanged             # 要件変更 → V字モデル全体へ順伝播
  - DocumentationOnlyChanged       # ドキュメントのみ → 原則伝播しない
```

### 3.6 具体例: 決済処理モジュール

```yaml
# --- ノード ---
nodes:
  - id: src/payment/processor.py::route_payment
    type: method
    boundary_id: payment
    criticality: business_critical
    owner: team-payment

  - id: config/payment.yaml::provider
    type: config_key
    meta:
      possible_values: [stripe, paypal, internal]

  - id: src/payment/stripe_adapter.py
    type: file
    boundary_id: payment

  - id: src/payment/paypal_adapter.py
    type: file
    boundary_id: payment

  - id: db/master/payment_fees
    type: db_table
    subtype: policy_table  # ★マスターの類型化
    meta:
      master_type: routing_table  # 手数料率でルーティング的に使われる
      key_columns: [provider_code, fee_tier]
      control_columns: [fee_rate, min_amount]

# --- リレーション ---
relations:
  - id: rel_001
    kind: reads_config
    src_ids: [src/payment/processor.py::route_payment]
    dst_ids: [config/payment.yaml::provider]
    confidence: 1.0
    evidence_ids: [ev_001]  # AST解析で検出

  - id: rel_002
    kind: selected_by
    src_ids: [config/payment.yaml::provider]
    dst_ids: [src/payment/stripe_adapter.py]
    condition_predicate: "provider == 'stripe'"  # ★v2: 条件付き
    confidence: 0.97
    evidence_ids: [ev_002, ev_003, ev_004]  # AST + Actuator + runtime

  - id: rel_003
    kind: selected_by
    src_ids: [config/payment.yaml::provider]
    dst_ids: [src/payment/paypal_adapter.py]
    condition_predicate: "provider == 'paypal'"  # ★v2: 条件付き
    confidence: 0.97
    evidence_ids: [ev_002, ev_005]

  - id: rel_004
    kind: column_controls_branch
    src_ids: [db/master/payment_fees]
    dst_ids: [src/payment/processor.py::route_payment]
    condition_predicate: "fee_tier IN (SELECT DISTINCT fee_tier FROM payment_fees)"
    confidence: 0.82
    evidence_ids: [ev_006, ev_007]  # SQL lineage + OTel trace

  - id: rel_005
    kind: convention_requires
    src_ids: [src/payment/stripe_adapter.py]
    dst_ids: [src/payment/paypal_adapter.py]
    confidence: 0.75
    evidence_ids: [ev_008, ev_009]  # git co-change + review comment

# --- 証拠 ---
evidences:
  - id: ev_001
    source_type: static
    extractor: tree-sitter-python
    artifact_ref: "src/payment/processor.py:42"
    snippet_ref: "provider = config.get('payment.provider')"
    supports_or_contradicts: supports
    calibrated_score: 1.0

  - id: ev_002
    source_type: static
    extractor: ast-pattern-matcher
    artifact_ref: "src/payment/processor.py:45-52"
    snippet_ref: "if provider == 'stripe': return StripeAdapter()"
    supports_or_contradicts: supports
    calibrated_score: 0.95

  - id: ev_003
    source_type: framework
    extractor: spring-actuator-beans
    artifact_ref: "actuator/beans?profile=prod"
    snippet_ref: "paymentAdapter -> StripeAdapter (active under profile=prod)"
    supports_or_contradicts: supports
    calibrated_score: 0.98

  - id: ev_004
    source_type: dynamic
    extractor: otel-trace-collector
    artifact_ref: "trace:abc123:span:payment-route"
    snippet_ref: "config.provider=stripe -> StripeAdapter.charge() called 15,234 times in 7d"
    supports_or_contradicts: supports
    calibrated_score: 0.99

  - id: ev_006
    source_type: static
    extractor: sql-lineage-parser
    artifact_ref: "src/payment/processor.py:67"
    snippet_ref: "SELECT fee_rate FROM payment_fees WHERE provider_code = ?"
    supports_or_contradicts: supports
    calibrated_score: 0.85

  - id: ev_007
    source_type: dynamic
    extractor: otel-db-trace
    artifact_ref: "trace:def456:span:db-query"
    snippet_ref: "payment_fees.fee_rate -> variable fee -> if fee > threshold"
    supports_or_contradicts: supports
    calibrated_score: 0.80

  - id: ev_008
    source_type: history
    extractor: git-cochange-analyzer
    artifact_ref: "git log --follow (last 500 commits)"
    snippet_ref: "stripe_adapter.py + paypal_adapter.py: co-changed 11/12 times"
    supports_or_contradicts: supports
    calibrated_score: 0.75

  - id: ev_009
    source_type: human
    extractor: "human:watanabe"
    artifact_ref: "PR #234 review comment"
    snippet_ref: "「adapter間のインターフェースは必ず揃えること」"
    supports_or_contradicts: supports
    calibrated_score: 0.90
```

**この依存グラフがあると何が起きるか:**

`stripe_adapter.py` を変更した瞬間に:

1. `processor.py::route_payment` に影響 → **Structural**（自動検出）
2. `paypal_adapter.py` もインターフェース変更が必要か → **Governance**（co-change + convention）
3. `config/payment.yaml::provider` の確認 → **Resolution**（condition: provider=stripe）
4. `db/master/payment_fees` の整合性確認 → **Behavioral**（column_controls_branch）
5. `docs/design/payment_flow.md` の更新 → **Validation**（documented_by）
6. ただし**condition_predicate**により: 「PayPal環境では影響大、Stripe-only環境では影響小」が明示される

**これが熟練エンジニアの頭の中で起きていることの再現。条件付きで。**

---

## 4. ブートストラップ: CEGをどう構築するか

### 4.1 設計原則

v1の「4フェーズ直列」からパイプラインに変更。

```
常時動く:  deterministic extractor（コミットごと）
定期実行:  framework introspection（デプロイごと）
定期実行:  runtime observation（日次/週次）
差分起点:  impact analyzer（PR/変更ごと）
夜間/定期: deep analysis + LLM queue（未解決フロンティアのみ）
継続的:    human feedback + calibration
```

### 4.2 Phase 1: 自動検出（分単位・毎コミット）

**ツール**: Tree-sitter, LSP, SQL parser, config parser, ORM extractor

| 検出対象 | 手法 | 生成されるrelation |
|---------|------|-------------------|
| import/require文 | AST | imports |
| 関数呼び出し | AST/LSP | calls |
| クラス継承/実装 | AST/LSP | extends, implements |
| SQL文のテーブル参照 | SQL parser | queries, mutates |
| config読み込みコード | AST + パターンマッチ | reads_config |
| 環境変数参照 | grep `os.environ`, `process.env` | reads_config |
| API定義 | OpenAPI/gRPC parser | api_contract |
| DB migration | Flyway/Liquibase parser | schema_contract |

**Phase 1だけでStructural依存はほぼ完全にカバーできる。ここまでは既存技術の組み合わせ。**

### 4.3 Phase 2: Framework Introspection + LLM推論

**v2で大幅改善。** LLMの前にframework introspectionを入れる。

#### 4.3.1 Framework Introspection（★v2追加）

Spring Boot Actuatorを例にすると、以下のエンドポイントからResolution依存が取れる:

| Actuator | 取得できるもの | 生成されるrelation |
|----------|-------------|-------------------|
| /beans | 登録済みBean一覧 + 依存関係 | bound_from_config, provided_by |
| /conditions | Conditional評価結果 | active_under |
| /configprops | 設定プロパティのバインディング | reads_config |
| /env | 環境変数・プロパティソース一覧 | reads_config |
| /mappings | URL→Controller マッピング | endpoint → handler |
| /flyway, /liquibase | migration適用状況 | schema_contract |

**これにより、v1で「原理的に追えない」と書いたDI依存の大部分がdeterministicに取れる。**

#### 4.3.2 設定駆動の依存: 6パターン分類

Layer 3をひとまとめにせず、検出戦略ごとに分ける。

| パターン | 例 | 検出戦略 |
|---------|-----|---------|
| (a) 宣言的DI | @Autowired, constructor injection | AST + FW introspection |
| (b) 条件付きDI | @Profile, @ConditionalOnProperty | AST + Actuator /conditions |
| (c) 外部設定参照 | @Value, @ConfigurationProperties | AST + Actuator /configprops |
| (d) Service/Provider loading | ServiceLoader, META-INF/services | manifest parser |
| (e) リフレクション/動的proxy | Class.forName, Method.invoke | AST heuristic + runtime |
| (f) Strategy registry/factory | Map\<String, Handler\>, configでhandler選択 | **LLM推論の出番** |

**LLMがやるのは(e)(f)だけ。それも「依存を想像する」のではなく「パターンを分類し候補relationを提案する」。**

#### 4.3.3 LLM推論（フロンティアのみ）

Phase 2のLLM対象は以下に限定:

- カスタムfactory / registryパターンの分類
- 曖昧なconfig-to-codeマッピング
- DBカラムのsemantic role推定
- ADR / incident / reviewコメントからのobligation抽出
- モジュール要約の生成

**LLMの優先度**: `uncertainty × change_frequency × business_criticality × graph_centrality` で決定。repo全体にかけない。

### 4.4 Phase 3: 人間検証（継続的）

LLMの推論結果を熟練エンジニアに提示し、知識を引き出す。

```
CPDDが提示:
「stripe_adapter.py と paypal_adapter.py は
 config.payment.provider の値で切り替わると推論しました。
 証拠: AST解析(0.95) + Actuator beans(0.98)。
 これは正しいですか？」

熟練エンジニア:
「正しい。あと、internal_adapter.py もある。
 それとこの3つは必ずインターフェースを揃える必要がある。」

→ convention_requires relation追加
→ internal_adapter.py のノード追加
→ evidence追加（source_type: human）
```

**Phase 3の本質: LLMの推論を「種」にして、人間から情報を引き出す。ゼロから書けと言われたら誰も書かない。「これ合ってますか？」なら答えられる。**

### 4.5 Phase 4: 学習（継続的・自動）

```yaml
data_sources:
  git_cochange:
    description: "同時に変更されるファイルペア"
    generates: co_changed_with
    evidence_type: history

  incident_ticket:
    description: "「Xを変えたのにYを変え忘れて障害」"
    generates: incident_correlated_with
    evidence_type: history

  code_review:
    description: "「ここも直さないと」コメント"
    generates: convention_requires
    evidence_type: human

  test_failure:
    description: "Xの変更でYのテストが壊れた"
    generates: validated_by_test（逆向き発見）
    evidence_type: dynamic

  codeowners:
    description: "パスごとの責任者定義"
    generates: owned_by
    evidence_type: static

  adr:
    description: "設計判断記録"
    generates: design_decision relations
    evidence_type: human
```

**注意: 履歴データは悪習慣も学習する。** co-changeは正しさではなく慣性。過去のバグパターンも覚えるため、evidenceとして記録し、人間がsupports/contradictsを判定できるようにする。

---

## 5. 変化点伝播エンジン（Change Calculus）

### 5.1 設計原則

v1のBFS + threshold から、**change atom別のtransfer function + 5段階停止条件 + Noisy-OR集約**に改善。

### 5.2 伝播アルゴリズム

```python
def propagate(change_atoms, target_context):
    """
    change_atoms: 正規化された変更の集合
    target_context: 対象環境（prod/staging等）
    """
    agenda = PriorityQueue()  # risk scoreで優先
    best_state = {}           # node → 最良到達状態
    scc_map = precompute_scc(graph)  # 強連結成分

    for atom in change_atoms:
        seed = make_seed_state(atom, target_context)
        agenda.push(seed)

    while agenda:
        state = agenda.pop_max_risk()

        # State dominance check（★v2: 循環依存対策）
        if dominated(state, best_state):
            continue
        best_state = merge(best_state, state)

        for rel in outgoing_and_reverse_relations(state.node):
            # Change atom がこのrelationを伝播するか
            if not rel.supports(state.change_atom):
                continue

            # ★v2: 条件の充足判定
            sat, extra_assumptions = satisfiable(
                state.context, rel.condition_predicate
            )
            if not sat:
                continue

            # Transfer function適用
            next_state = apply_transfer(state, rel, extra_assumptions)

            # ★v2: 5段階停止条件
            if should_stop(next_state, rel):
                continue

            agenda.push(next_state)

    return classify_actions(best_state)
```

### 5.3 Transfer Function（change atom × relation kindで決まる）

同じrelationでも、change atomの種類によって伝播が変わる:

```yaml
transfer_rules:
  # InterfaceContractChanged × calls
  - change: InterfaceContractChanged
    relation: calls
    direction: to_caller
    band: must_review  # callerは必ずレビュー
    weight: 0.95

  # ImplementationSemanticsChanged × calls
  - change: ImplementationSemanticsChanged
    relation: calls
    direction: to_caller
    band: info  # callerへは情報のみ（契約は変わっていない）
    weight: 0.3

  # ImplementationSemanticsChanged × validated_by_test
  - change: ImplementationSemanticsChanged
    relation: validated_by_test
    direction: to_test
    band: must_review  # テストは必ずレビュー
    weight: 0.9

  # ConfigDefaultChanged × selected_by
  - change: ConfigDefaultChanged
    relation: selected_by
    direction: to_selected
    band: must_review  # 条件付きで影響
    weight: 0.85
    condition: "matches target_context"

  # MasterMeaningChanged × column_controls_branch
  - change: MasterMeaningChanged
    relation: column_controls_branch
    direction: to_branch_handler
    band: must_review  # 最も危険
    weight: 0.95

  # MasterMeaningChanged → test + runbook
  - change: MasterMeaningChanged
    relation: [validated_by_test, operationalized_by_runbook]
    direction: forward
    band: must_review
    weight: 0.90

  # DocumentationOnlyChanged × any
  - change: DocumentationOnlyChanged
    relation: "*"
    band: info
    weight: 0.05  # 原則伝播しない
```

### 5.4 停止条件（★v2: 5段階精密化）

```python
def should_stop(state, rel):
    # 優先度1: 契約境界で止める
    # contract-preserving な変更が stable contract をまたぐなら強く減衰
    if crosses_stable_contract_boundary(state, rel):
        if state.change_atom.facet != 'contract':
            return True  # 契約変更でなければ止める

    # 優先度2: 条件が充足不能
    if unsat_or_too_many_assumptions(state):
        return True

    # 優先度3: 情報利得がない
    # 新しいnodeに行ってもimpact dimensionが増えない
    if no_information_gain(state):
        return True

    # 優先度4: リスク閾値を下回った
    if state.risk_score < threshold_for(state.node.criticality):
        return True

    # 優先度5: 深さ制限（最後の安全弁）
    if state.depth > MAX_DEPTH:
        return True

    return False
```

### 5.5 Risk Aggregation（★v2: Noisy-OR）

```python
def compute_node_risk(node, paths):
    """
    独立した複数の弱い証拠が集まると強くなる。
    熟練者の「いくつかの匂いが一致したから怪しい」を表現。
    """
    path_scores = []
    for path in paths:
        score = path.seed_severity
        for edge in path.edges:
            score *= (
                edge.confidence
                * edge.transfer_weight
                * edge.context_match
                * edge.freshness
            )
        path_scores.append(score)

    # Noisy-OR: 1 - Π(1 - score_i)
    node_risk = 1.0
    for score in path_scores:
        node_risk *= (1.0 - score)
    node_risk = 1.0 - node_risk

    return node_risk
```

### 5.6 3帯域分類（★v2: Green/Amber/Gray）

```yaml
action_bands:
  green:
    name: "auto-update"
    description: "自動更新候補。precisionを最優先"
    condition: "confidence >= 0.95 AND source in [static, framework] AND change is mechanical"
    optimization: precision  # 間違った自動更新は信頼を壊す

  amber:
    name: "must-review"
    description: "人間がレビュー必須。recallを最優先"
    condition: "risk_score >= amber_threshold(artifact_class)"
    optimization: recall  # 見落としは障害になる

  gray:
    name: "info"
    description: "参考情報・弱いシグナル。探索用"
    condition: "risk_score >= gray_threshold"
    optimization: coverage

# artifact classごとに閾値を変える
artifact_thresholds:
  business_critical:  # 本番設定、料金計算、法令判定、セキュリティ
    amber: 0.3        # 低い閾値 = 広くレビュー（FN高コスト）
    gray: 0.1
  normal:
    amber: 0.5
    gray: 0.2
  peripheral:         # README、周辺ドキュメント
    amber: 0.7        # 高い閾値 = 重要なものだけ
    gray: 0.3
```

### 5.7 出力フォーマット

```
変更: src/payment/processor.py::route_payment
  Change Atom: InterfaceContractChanged (severity: major)
  環境: prod (provider=stripe)

■ Green（自動更新候補）:
  1. [auto] tests/unit/test_processor.py — 引数変更に追従
     evidence: AST(1.0) | path: direct calls
  2. [auto] docs/api/payment.md — APIシグネチャ更新
     evidence: static(0.98) | path: documented_by

■ Amber（レビュー必須）:
  3. [review] src/payment/stripe_adapter.py — インターフェース整合性
     evidence: AST(0.95)+convention(0.75) | risk: 0.92
     path: calls + convention_requires
  4. [review] src/payment/paypal_adapter.py — 同上
     evidence: convention(0.75)+cochange(0.75) | risk: 0.85
     ★ 条件: provider=paypal環境のみ影響
  5. [review] db/master/payment_fees — 手数料率マスターとの整合性
     evidence: SQL(0.85)+OTel(0.80) | risk: 0.78
     path: column_controls_branch

■ Gray（参考情報）:
  6. [info] src/batch/nightly_settlement.py — 夜間バッチへの影響
     evidence: cochange(0.45) | risk: 0.35
  7. [info] src/reporting/monthly_report.py — 月次レポート
     evidence: queries(0.30) | risk: 0.22

→ 各項目の根拠パスと証拠が説明可能。
  「なぜこれが影響リストに入ったのか」に常に答えられる。
```

---

## 6. コンテキスト最適化エンジン

### 6.1 設計原則

v1のU字型配置に加え、**MMR付きknapsack**で「何を入れるか」を最適化し、**ambiguity-based**で「全文が必要か」を判断する。

### 6.2 Multi-Resolution Representation

各ノードに対し、複数の表現を持つ:

```yaml
representations:
  full:            # 全文（トークン大、情報量最大）
  relevant_excerpt: # 変更関連部分の抜粋
  public_signature: # public API/契約部分のみ
  summary_200:     # 200トークン要約
  meta_oneline:    # 1行メタ情報
```

### 6.3 コンテキスト構成アルゴリズム

```python
def build_context(task, impacted_nodes, token_budget):
    """
    Step 1: 各ノード×各表現の有用度を計算
    Step 2: MMR付きknapsackで選択
    Step 3: U字型に配置
    """
    # Step 1: 候補生成
    candidates = []
    for node in impacted_nodes:
        for repr in representations(node, task):
            utility = (
                impact_score(node)
                * task_relevance(node, task)
                * uncertainty_reduction(node, repr, task)  # ★ambiguity
                * trust(node)
                / token_cost(repr)
            )
            candidates.append((node, repr, utility))

    # Step 2: MMR knapsackで冗長性を排除しつつ選択
    selected = mmr_knapsack(candidates, token_budget)

    # Step 3: U字型配置
    return render_bundle(
        # 先頭（高アテンション）
        task_frame=make_task_frame(task),
        changed_nodes=full_text_of_direct_changes(task),
        contracts=top_contracts(selected),

        # 中間（低アテンション → メタ情報で耐える）
        explanation_paths=top_paths_as_summaries(selected),
        config_and_data=meta_only(selected, types=['config_key', 'db_table']),

        # 末尾（高アテンション）
        validation_checks=relevant_tests_and_runbooks(selected),
        open_assumptions=list_assumptions(selected),
        checklist=generate_checklist(selected),
    )
```

### 6.4 オンデマンド読み込みの判断基準（★v2: ambiguity-based）

全文が必要かどうかは**重要度ではなくambiguity（曖昧さ）**で決める。

```yaml
require_full_text_when:
  - node_is_direct_edit_target      # そのノード自体を編集する
  - node_is_control_sink            # 分岐制御の着地点
  - summary_lacks_change_symbol     # 要約に関連シンボルが出てこない
  - summary_confidence_low          # 要約の信頼度が低い
  - path_explanations_conflict      # 影響パス同士が矛盾
  - auto_patch_failed               # 自動生成パッチがcompile/test失敗
  - human_asked_why                 # 人間が「なぜ？」を問うた

# 重要だが曖昧でないノードはsummaryで十分。
# 多くの失敗は「重要だから全文」と考えることから起きる。
# 本当は「曖昧だから全文が要る」。
```

### 6.5 階層要約 + Hash Invalidation

```yaml
summary_hierarchy:
  - symbol_summary     # 関数/メソッド単位
  - file_summary       # ファイル単位
  - module_summary     # モジュール単位
  - context_summary    # bounded context単位

invalidation_rules:
  - comment_only_change:       # コメント変更 → 再生成不要
  - implementation_change:     # 内部実装変更 → file summary再生成
  - public_contract_change:    # public API変更 → file + module summary再生成
  - config_consumer_change:    # 設定消費者変更 → resolution summary再生成

summary_slots:  # 固定構造の要約
  purpose:              # 目的
  public_contract:      # 公開契約
  key_invariants:       # 重要な不変条件
  inbound_dependencies: # 入力依存
  outbound_dependencies: # 出力依存
  selectors:            # 設定/データ選択子
  validation_assets:    # 検証資産
  known_obligations:    # 既知の義務
```

---

## 7. V字モデルとの統合

### 7.1 柱1の再定義: Graph Delta生成（★v2改善）

v1では「要件→設計書自動生成」と書いた。v2では:

**要件 → candidate graph delta生成 → 人間選択 → document/code render**

```
要件定義（入力）
    │
    ▼
Graph Delta Generator
    │  要件をCEGへの追加・変更操作に変換
    │  複数の設計パターンを graph delta として提示
    │
    ▼
候補1: [delta_a] ← 設計パターンA（マイクロサービス分割）
候補2: [delta_b] ← 設計パターンB（モジュラーモノリス）
候補3: [delta_c] ← 設計パターンC（イベント駆動）
    │
    ▼
Human-in-the-Loop: 選択
    │
    ▼
graph delta をCEGに適用
    │
    ▼
Artifact Renderers:
  ├─ 設計書（Markdown/HTML）    ← CEGの view
  ├─ コード雛形                 ← CEGの view
  ├─ テスト雛形                 ← CEGの view
  ├─ 設定テンプレート            ← CEGの view
  └─ migration雛形             ← CEGの view
```

**出力はdocumentではなくgraph delta。documentはviewに過ぎない。**

逆方向（設計書やコードを変更した場合）:
```
設計書/コード変更（入力）
    │
    ▼
Delta Extractor: 差分をgraph deltaに変換
    │
    ▼
CEGに適用
    │
    ▼
伝播エンジン起動 → 影響範囲特定
    │
    ▼
影響を受けるview（他の設計書/コード/テスト）を更新提案
```

**これで初めて双方向伝播が数理的に成立する。**

### 7.2 V字モデルの各ノードとCEGの対応

```
要件定義 ←──────────────→ 受入テスト仕様
 [requirement]              [test_case:acceptance]
    │                           │
    │  satisfies_requirement    │  validated_by_test
    ↓                           ↓
基本設計 ←──────────────→ 結合テスト仕様
 [design_section:basic]     [test_case:integration]
    │                           │
    │  satisfies_requirement    │  validated_by_test
    ↓                           ↓
詳細設計 ←──────────────→ 単体テスト仕様
 [design_section:detail]    [test_case:unit]
    │                           │
    │  satisfies_requirement    │  validated_by_test
    ↓                           ↓
      ──→ 実装 (C + K + D) ←──
          [source + config + data]
```

---

## 8. 実装アーキテクチャ

### 8.1 コンポーネント図

```
[情報源]
  Repo / Docs / Config / DB Migrations / Runtime Traces / Tickets / Incidents
                         |
                         v
[Extractors + Normalizers Layer]
  AST(Tree-sitter), dataflow, framework(Actuator), SQL lineage,
  docs parser, obligation extractor, git history analyzer
                         |
                         v
[Canonical Store: CEG + Evidence Ledger + Summary Store]
  Stage 0-2: SQLite/DuckDB + YAML (annotation用)
  Stage 3+:  + Neo4j projection (interactive query用)
                         |
          +--------------+---------------+
          |                              |
          v                              v
[Change Normalizer]             [Design Synthesizer]
  diff → change atoms             requirements → candidate graph deltas
          |                              |
          v                              v
[Propagation Engine]  -------->  [Artifact Renderers]
  change calculus                 design docs / code stubs / tests
          |
          v
[Action Planner]
  green/amber/gray classification
          |
          +-------------------+-------------------+
          |                   |                   |
          v                   v                   v
[CI/PR Bot]               [IDE Plugin]     [Claude Code Skill Pack]
                                                  |
                                                  v
                                           [Human Feedback]
                                                  |
                                                  v
                                     [Calibration / Rule Refinement]
```

### 8.2 ストレージ戦略

| 段階 | Canonical Store | Serving | Local Cache |
|------|----------------|---------|-------------|
| Stage 0-2 | SQLite + YAML annotation | 同一 | JSON slice |
| Stage 3+ | SQLite/DuckDB | Neo4j projection | SQLite slice |

YAMLの役割:
- Stage 0: manual rules / conventions / control-table tags
- 常時: human annotation DSL
- **graph本体はYAMLに持たない**（数千万ステップでは差分管理・queryが困難）

### 8.3 Claude Code Plugin構成

```yaml
# Skills
skills:
  cpdd-impact:
    description: "変更差分から影響分析を実行"
    trigger: "pre-commit, PR open"

  cpdd-context:
    description: "作業用コンテキストbundleを生成"
    trigger: "session start, file open"

  cpdd-propose:
    description: "green-band のdoc/test/config patchを提案"
    trigger: "post-impact analysis"

  cpdd-explain:
    description: "影響パスを人間向けに説明"
    trigger: "human asks 'why'"

  cpdd-annotate:
    description: "convention/obligationを追加"
    trigger: "code review, incident postmortem"

# Subagents
subagents:
  graph-explorer:       "CEG探索・パス検索"
  config-resolver:      "設定値の解決経路追跡"
  data-dependency-analyst: "マスターデータ依存分析"
  obligation-extractor: "ADR/incident/reviewからobligation抽出"
  patch-planner:        "変更パッチの計画・生成"

# Hooks
hooks:
  session_start: "bounded context summaryとactive conventionsを注入"
  pre_edit:      "unsafe zone（business_critical）なら warning"
  post_edit:     "local CEG slice再計算"
  pre_commit:    "impact analysis強制実行"
  pr_open:       "must-review report生成"

# MCP Server
mcp:
  graph_query:    "CEGへのクエリAPI"
  ticket_search:  "JIRA/Linear/GitHub Issues検索"
  trace_lookup:   "OTel trace検索"
  migration_history: "Flyway/Liquibase履歴"
```

---

## 9. 未解決の問題（正直に）

### 9.1 原理的限界

1. **記録されていない意図は復元できない** — コードにもdocsにもtraceにも残っていないbusiness intentは弱い
2. **まれな経路は観測しにくい** — runtime evidenceは強いが、未観測rare pathには弱い
3. **意味の等価性は一般には判定不能** — implementation changeがbehavior-preservingかは理論的にundecidable
4. **組織的事情はコードから見えない** — 「この人に確認しないと危ない」はsocio-technical
5. **履歴データは悪習慣も学習する** — co-changeは正しさではなく慣性

### 9.2 補完手段

| 限界 | 補完 |
|------|------|
| 未記録の意図 | human annotation + ADR |
| 未観測のrare path | counterfactual test（staging環境でデータを変えて試す） |
| 意味等価性 | test oracle + runtime canary |
| 組織的事情 | CODEOWNERS + reviewer history |
| 悪習慣学習 | evidence supports/contradicts + 人間レビュー |

### 9.3 新規開発時

CPDDは既存改修が主ターゲットだが、新規開発時は:
- 柱1（graph delta生成）が主役
- 設計が生成された時点でCEGを自動構築
- 実装が進むにつれrelationが追加
- Phase 4（学習）が最初から動く

---

## 10. 実装ロードマップ

### Stage 0: 思想の公開 + モデルの種（今ここ）

**成果物:**
- リサーチレポート ✅ (`reports/cpdd_research_report.md`)
- アーキテクチャ設計書 v2 ✅ (この文書)
- GPT-5.4突合分析 ✅ (`reports/cpdd_crossref.md`)
- node/relation taxonomy 定義 ✅ (この文書のSection 3)
- change atom taxonomy 定義 ✅ (この文書のSection 3.5)
- evidence schema 定義 ✅ (この文書のSection 3.4)
- human annotation DSL (YAML) — 例:

```yaml
# YAML annotation例: 熟練者の知識を記録
rule_id: conv.pricing.cache_reload
when:
  node: module://pricing
  change_kinds: [MasterMeaningChanged, ConfigResolutionRuleChanged]
then:
  review:
    - runbook://ops/cache-reload
    - test://pricing-golden-master
owner: team-pricing
confidence: 0.95
source: human
```

- Zenn記事で思想を公開
- GitHubリポジトリ作成

### Stage 1: Structural CPDD（大里LMSで実験）

**成果物:**
- incremental parser pipeline (Tree-sitter)
- symbol / call / import / schema / query graph
- diff → change atom classifier
- must-review の初版
- summary cache の初版
- Claude Code スキルとして実装

**出口条件:**
- structural changeでtop-K recallが実用水準
- PRで「どのinterface/test/docsを見ろ」が出せる

### Stage 2: Resolution-aware CPDD

**成果物:**
- Spring/config/plugin resolver
- context predicate engine
- Actuator/FW introspection import
- config-to-consumer graph
- environment-specific impact（condition_predicate活用）

**出口条件:**
- config/DI変更で「どの環境でどのbeanが危ない」が出せる

### Stage 3: Data-aware CPDD

**成果物:**
- SQL/ORM lineage
- master table taxonomy（7分類）
- query-result → control-sink linker
- OTel trace correlation
- counterfactual master-data test harness
- runtime-conditioned explanation path

**出口条件:**
- master-data changeでcode/test/runbookまでmust-reviewが出る
- explanation pathを人間が納得する

### Stage 4: Socio-technical CPDD + Plugin化

**成果物:**
- PR review / CODEOWNERS / incident / ADR / ticket extractor
- obligation rule store
- review routing
- OpenRewrite/codemod連携（recipe優先、free-form LLMは最後）
- Claude Code skill/hook/MCP pack（Agent Skills Open Standard準拠）
- calibration dashboard
- green/amber/gray operational thresholds

**出口条件:**
- must-review listのacceptanceが高い
- green-band auto updatesのprecisionが95%以上
- 人間がCPDDを「ノイズ発生器」ではなく「弱いメンタルモデル」と認識する

---

## 11. CPDDのコア定義（まとめ）

```
CPDD = Conditioned Evidence Graph
     + Change Calculus
     + Multi-resolution Context Engine

CEG: 条件付き・証拠付き・時間付きの依存グラフ
Change Calculus: change atom × relation kind × condition → action
Context Engine: ambiguity-based × MMR knapsack × U字型配置
```

**CPDDが提供するもの:**
- 「何が関係ありそうか」（impact list）
- 「どこまで見れば安全か」（band classification）
- 「なぜそう言えるか」（evidence + explanation path）

**これが実務で使える"弱いメンタルモデル"。**

---

## 12. なぜこれを解けるのは殿だけなのか

1. **問題を体で知っている**: 数千万ステップのパッケージソフト開発で「ここ直したらどこが壊れるか分からない」を何年も経験した
2. **Layer 3-5の存在を知っている**: ソースだけ見ても追えない依存があることを、学術論文ではなく現場の痛みとして理解している
3. **熟練エンジニアの思考プロセスを言語化できる**: 自分自身がそのメンタルモデルを持っていた
4. **AIシステムの設計・運用ができる**: 将軍システムでマルチエージェント管理・YAML伝播を既に実装・運用
5. **OSSとして出す意志がある**: 業界全体を変えるためにOSS公開

ツール作者にはLayer 3-5の存在が見えない。
学術研究者には現場の痛みが分からない。
SIerの現場エンジニアにはAIシステムを設計する力がない。

**この交差点に立てるのは殿だけ。**
