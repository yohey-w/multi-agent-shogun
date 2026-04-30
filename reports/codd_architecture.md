# CPDD アーキテクチャ設計書（深層版）

**作成日**: 2026-03-14
**ステータス**: 初版・思考段階

---

## 0. この文書の目的

CPDDの核心的な問いに答える：

**「エンタープライズシステムで、ある箇所を変更したとき、影響を受ける全箇所をAIがどうやって特定するのか？」**

特に、ソースコードの静的解析だけでは追えない依存（設定駆動・マスターデータ・暗黙の慣習）を含めて。

---

## 1. 問題の形式化

### 1.1 エンタープライズシステムの構成要素

システム S は以下の要素で構成される：

| 記号 | 要素 | 例 |
|------|------|-----|
| **C** | ソースコード | ファイル、関数、クラス、メソッド |
| **K** | 設定 | config.yaml、環境変数、feature flag、プロパティファイル |
| **D** | データ定義 | DBスキーマ、マスターテーブル、ストアドプロシージャ |
| **W** | ドキュメント | 要件定義書、基本設計書、詳細設計書、テスト仕様書 |
| **I** | 暗黙知 | 慣習、パターン、「ここを触ったらあそこも」という経験則 |

### 1.2 変更影響問題

変化点 Δ が任意の要素 e ∈ {C ∪ K ∪ D ∪ W ∪ I} に発生したとき：

**影響セット E' = { e' | e' は Δ の影響を受ける } を求めよ。**

これがCPDDが解くべき問題の数学的な定義。

### 1.3 なぜ既存手法では解けないのか

依存関係には5つの層がある：

```
Layer 5: 慣習依存 ─── 「キャッシュテーブルを変えたらバッチも直す」（どこにも書いてない）
Layer 4: データ依存 ── マスターテーブルの値がビジネスロジックを制御（コードにはSELECT文しかない）
Layer 3: 設定依存 ─── config値で呼び出し先が分岐（静的解析では1メソッドに見える）
Layer 2: コード構造 ── import, 関数呼び出し, 継承（LSP/ASTで解ける）
Layer 1: ファイル ─── ファイル間の参照（grep/globで解ける）
```

既存ツールの到達点：

| ツール | Layer 1 | Layer 2 | Layer 3 | Layer 4 | Layer 5 |
|--------|:-------:|:-------:|:-------:|:-------:|:-------:|
| grep/glob | ✅ | - | - | - | - |
| Aider Repo Map | ✅ | ✅ | - | - | - |
| LSPRAG | ✅ | ✅ | - | - | - |
| Ripple (ICSE 2026) | ✅ | ✅ | △ | - | - |
| DOORS/Polarion | - | - | - | - | - |
| **CPDD（目標）** | **✅** | **✅** | **✅** | **✅** | **✅** |

**Layer 3-5が未開拓領域。ここがフロンティア。**

---

## 2. 熟練エンジニアのメンタルモデル分析

CPDDの設計思想は「熟練エンジニアの思考プロセスを再現する」こと。まず、彼らが何をしているかを分析する。

### 2.1 熟練エンジニアの思考フロー

```
「この関数を直す」
    │
    ├─ 即座に思い浮かぶ（メンタルモデル）
    │   「この関数はconfig.payment.providerで分岐するから、
    │    Stripe/PayPal両方のアダプタに影響する」
    │   「このマスターを使ってるバッチが夜間に走るから、
    │    反映タイミングに注意」
    │
    ├─ 確認のために調べる（検証）
    │   grep, IDE検索, DB検索
    │   「やっぱりここも影響するな」
    │
    └─ 経験から推測する（推論）
        「前にここを触った時、あのテストが壊れたから、
         今回も同じパターンだろう」
```

### 2.2 メンタルモデルの構成要素

熟練エンジニアの頭の中にあるもの：

1. **構造知識**: 「モジュールAはモジュールBに依存している」（≒Layer 1-2）
2. **挙動知識**: 「この設定値を変えるとこの振る舞いが変わる」（≒Layer 3）
3. **データフロー知識**: 「このマスターはあの画面とあのバッチで使われる」（≒Layer 4）
4. **経験則**: 「ここを触ったら必ずあそこも壊れる」（≒Layer 5）
5. **歴史知識**: 「前回ここを触った時にこういう障害が起きた」（≒学習データ）

### 2.3 CPDDが再現すべきもの

**全てを完璧に再現する必要はない。**

熟練者の7割の判断ができれば、若手が安全にシステムを改修できる。完璧を目指すと永遠に完成しない。

目標：**「見落とし」を防ぐセーフティネット**

- 熟練者: メンタルモデルで8割カバー → 残り2割は経験と勘
- CPDD: 自動検出で5割 + LLM推論で2割 + 人間注釈で1割 = 8割カバー
- 残り2割は「未知の依存」として、変更後のテスト/監視で補う

---

## 3. 統合依存グラフ (Unified Dependency Graph: UDG)

### 3.1 概要

CPDDの心臓部。5つのLayerの依存を一つのグラフに統合する。

```
┌─────────────────────────────────────────┐
│          Unified Dependency Graph        │
│                                         │
│   [要件定義] ──→ [基本設計] ──→ [詳細設計]│
│       ↕              ↕             ↕     │
│   [受入テスト] ← [結合テスト] ← [単体テスト]│
│       ↕              ↕             ↕     │
│   [設定K] ────→ [コードC] ←──── [データD] │
│                    ↕                     │
│              [暗黙知I]                   │
│                                         │
│   ノード: 任意のアドレス可能な要素         │
│   エッジ: 型付き依存関係（信頼度付き）     │
└─────────────────────────────────────────┘
```

### 3.2 ノード定義

```yaml
# ノードの型
node_types:
  source:        # ソースコード（ファイル、クラス、関数、メソッド）
  config_key:    # 設定キー（config.yaml::payment.provider 等）
  config_file:   # 設定ファイル全体
  db_table:      # DBテーブル
  db_column:     # DBカラム
  db_procedure:  # ストアドプロシージャ
  master_data:   # マスターデータ（テーブル+ビジネス的意味）
  requirement:   # 要件定義の項目
  design_section: # 設計書のセクション
  test_case:     # テストケース
  batch_job:     # バッチジョブ
  api_endpoint:  # APIエンドポイント
  convention:    # 慣習・暗黙のルール
```

### 3.3 エッジ定義

```yaml
# エッジの型と信頼度ソース
edge_types:
  # Layer 1-2: 自動検出可能（信頼度: 高）
  calls:          # 関数Aが関数Bを呼ぶ
  imports:        # ファイルAがファイルBをインポート
  inherits:       # クラスAがクラスBを継承
  implements:     # コードが要件/設計を実装

  # Layer 3: 設定依存（信頼度: 中〜高）
  reads_config:   # コードが設定値を読む
  switched_by:    # 設定値によって挙動が分岐する
  enabled_by:     # feature flagで有効化される

  # Layer 4: データ依存（信頼度: 中）
  queries:        # コードがテーブルをSELECTする
  mutates:        # コードがテーブルをINSERT/UPDATE/DELETEする
  driven_by:      # マスターデータが挙動を制御する
  derived_from:   # データがマスターから導出される

  # Layer 5: 暗黙知（信頼度: 低〜中、人間注釈）
  convention:     # 慣習的にセットで変更すべき
  co_changes:     # 過去に一緒に変更されてきた（git履歴から）
  breaks_if_not:  # 一緒に変更しないと壊れる（障害履歴から）

  # メタ
  inferred:       # LLMが推論した関係（信頼度スコア付き）

# 各エッジの属性
edge_attributes:
  confidence:     # 0.0〜1.0 信頼度
  source:         # auto_detected | llm_inferred | human_annotated | git_history
  annotated_by:   # 人間注釈の場合、誰が
  evidence:       # 根拠（gitコミット、障害チケット等）
  last_verified:  # 最後に検証された日時
  decay:          # 時間経過で信頼度が下がる速度
```

### 3.4 具体例：設定駆動の依存

**シナリオ**: 決済処理モジュール。config値でStripe/PayPal/内部決済を切り替える。

```yaml
nodes:
  - id: src/payment/processor.py::route_payment
    type: source
    meta:
      description: "決済ルーティング。configのprovider値で振り分け"

  - id: config/payment.yaml::provider
    type: config_key
    meta:
      possible_values: [stripe, paypal, internal]
      description: "決済プロバイダー選択"

  - id: src/payment/stripe_adapter.py
    type: source
    meta:
      description: "Stripe決済アダプタ"

  - id: src/payment/paypal_adapter.py
    type: source
    meta:
      description: "PayPal決済アダプタ"

  - id: db/master/payment_fees
    type: master_data
    meta:
      description: "プロバイダー別手数料率マスター"

edges:
  - from: src/payment/processor.py::route_payment
    to: config/payment.yaml::provider
    type: reads_config
    confidence: 1.0
    source: auto_detected

  - from: config/payment.yaml::provider
    to: src/payment/stripe_adapter.py
    type: switched_by
    confidence: 0.95
    source: llm_inferred
    note: "provider=stripeの時にstripe_adapterが活性化"

  - from: config/payment.yaml::provider
    to: src/payment/paypal_adapter.py
    type: switched_by
    confidence: 0.95
    source: llm_inferred
    note: "provider=paypalの時にpaypal_adapterが活性化"

  - from: src/payment/processor.py::route_payment
    to: db/master/payment_fees
    type: driven_by
    confidence: 0.85
    source: llm_inferred
    note: "手数料計算がマスターの値に依存"

  - from: src/payment/processor.py
    to: docs/design/payment_flow.md::section3
    type: implements
    confidence: 0.8
    source: human_annotated
    annotated_by: senior_eng_watanabe

  - from: src/payment/stripe_adapter.py
    to: src/payment/paypal_adapter.py
    type: convention
    confidence: 0.7
    source: git_history
    evidence: "過去12回中11回、同時に変更されている"
    note: "インターフェースを揃える慣習"
```

**この依存グラフがあると何が起きるか：**

`stripe_adapter.py` を変更した瞬間に：
1. `processor.py::route_payment` に影響 → **自動検出**（Layer 2）
2. `config/payment.yaml::provider` の確認を促す → **設定依存**（Layer 3）
3. `db/master/payment_fees` の整合性確認を促す → **データ依存**（Layer 4）
4. `paypal_adapter.py` もインターフェース変更が必要か確認 → **慣習**（Layer 5）
5. `docs/design/payment_flow.md` の更新を促す → **ドキュメント連動**

**これが熟練エンジニアの頭の中で起きていることの再現。**

---

## 4. ブートストラップ：依存グラフをどう構築するか

### 4.1 最大の課題

数千万ステップのシステムに対して、手動で依存グラフを書くのは不可能。
段階的に構築する戦略が必要。

### 4.2 4フェーズ・ブートストラップ

```
Phase 1: 自動検出（分単位）
    ↓ Layer 1-2 のエッジが生成される
Phase 2: LLM推論（時間単位）
    ↓ Layer 3-4 のエッジが推論される
Phase 3: 人間検証（継続的）
    ↓ 推論結果の確認 + Layer 5 の追加
Phase 4: 学習（継続的）
    ↓ git履歴・障害履歴からエッジが強化/追加される
```

#### Phase 1: 自動検出（数分〜数十分）

ツール: AST parser (Tree-sitter), LSP, SQL parser, config parser

| 検出対象 | 手法 | 生成されるエッジ型 |
|---------|------|-----------------|
| import/require文 | AST | imports |
| 関数呼び出し | AST/LSP | calls |
| クラス継承 | AST/LSP | inherits |
| SQL文のテーブル参照 | SQL parser | queries, mutates |
| config読み込みコード | AST + パターンマッチ | reads_config |
| 環境変数参照 | grep `os.environ`, `process.env` | reads_config |

**重要**: Phase 1だけで Layer 1-2 はほぼ完全にカバーできる。
ここまでは既存技術の組み合わせ。

#### Phase 2: LLM推論（数時間）

Phase 1で検出した `reads_config` エッジを起点に、LLMに推論させる。

```
プロンプト設計（概念）:

「以下のコードは設定値 `payment.provider` を読んでいます。
この設定値が取りうる値は [stripe, paypal, internal] です。

コード: [processor.pyの該当関数]

質問: この設定値の変更は、他のどのファイルに影響しますか？
各影響について、理由と確信度を述べてください。」
```

同様に `queries` エッジから：

```
「以下のコードはテーブル `payment_fees` を参照しています。

コード: [該当関数]
テーブル定義: [DDL]

質問: このテーブルの構造やデータを変更した場合、
コード側でどのような影響がありますか？」
```

**Phase 2の出力**: `switched_by`, `driven_by`, `affects` 等のエッジ（confidence: 0.6〜0.9）

#### Phase 3: 人間検証（継続的）

LLMの推論結果を熟練エンジニアに提示する。

```
CPDDが提示:
「stripe_adapter.py と paypal_adapter.py は
 config.payment.provider の値で切り替わると推論しました（確信度: 0.95）。
 これは正しいですか？」

熟練エンジニア:
「正しい。あと、internal_adapter.py もある。
 それとこの3つは必ずインターフェースを揃える必要がある。」

→ convention エッジ追加、internal_adapter.py のノード追加
```

**Phase 3の本質**: LLMの推論を「種」にして、人間から情報を引き出す。
ゼロから「依存関係を全部書いてください」と言われたら誰も書かない。
「これ合ってますか？他にありますか？」なら答えられる。

#### Phase 4: 学習（継続的・自動）

```
データソース:
  - git log: 同時に変更されるファイルのペア → co_changes エッジ
  - 障害チケット: 「Xを変えたのにYを変え忘れて障害」→ breaks_if_not エッジ
  - コードレビュー: 「ここも直さないと」コメント → convention エッジ
  - テスト失敗ログ: XのテストがYの変更で壊れた → 暗黙の依存
```

git log からの co_changes 検出（疑似コード）:

```python
# 過去N回のコミットで同時に変更されたファイルペアを抽出
for commit in git_log(last_n=1000):
    changed_files = commit.changed_files
    for pair in combinations(changed_files, 2):
        co_change_count[pair] += 1

# 閾値以上のペアを co_changes エッジとして追加
for pair, count in co_change_count.items():
    if count / total_commits_touching_either > 0.5:
        add_edge(pair, type="co_changes", confidence=count/total, source="git_history")
```

**Phase 4の重要性**: 時間が経つほど依存グラフが賢くなる。
最初は弱いメンタルモデルでも、使い続けると熟練者に近づく。

---

## 5. 変化点伝播エンジン

### 5.1 伝播アルゴリズム

```
入力: 変化点 Δ（変更されたノード + 変更内容）
出力: 影響セット E'（影響を受けるノード + 推奨アクション）

function propagate(Δ):
    queue = [Δ.node]
    visited = {}
    impact_set = []

    while queue is not empty:
        current = queue.pop()

        for edge in UDG.outgoing_edges(current):
            target = edge.target

            if target in visited:
                continue

            # 伝播するかどうかの判断
            propagation_score = evaluate_propagation(Δ, edge, target)

            if propagation_score > THRESHOLD:
                impact = {
                    node: target,
                    score: propagation_score,
                    reason: edge.type + edge.note,
                    action: determine_action(edge, propagation_score)
                }
                impact_set.append(impact)
                visited[target] = impact

                # 間接影響も辿る（ただし減衰あり）
                if propagation_score > INDIRECT_THRESHOLD:
                    queue.append(target)

    return sort_by_score(impact_set)
```

### 5.2 推奨アクションの決定

```yaml
action_rules:
  # 信頼度が高い自動検出エッジ
  - condition: "confidence >= 0.9 AND source == auto_detected"
    action: auto_update  # 自動更新（人間確認後）
    message: "この変更により、以下のファイルも更新が必要です"

  # LLM推論エッジ
  - condition: "confidence >= 0.7 AND source == llm_inferred"
    action: suggest_review  # レビューを提案
    message: "以下のファイルにも影響がある可能性があります（確信度: {confidence}）"

  # 人間注釈エッジ
  - condition: "source == human_annotated"
    action: require_review  # レビュー必須
    message: "過去の知見に基づき、以下も確認してください"

  # 履歴ベースエッジ
  - condition: "source == git_history"
    action: warn  # 警告
    message: "過去の変更パターンでは、以下も同時に変更されています"

  # 低信頼度
  - condition: "confidence < 0.5"
    action: info  # 情報提供のみ
    message: "関連がある可能性があります（要確認）"
```

### 5.3 Human-in-the-Loop: 選択肢提示

影響セットが大きい場合、AIが選択肢を提示する：

```
変更: src/payment/processor.py::route_payment

■ 自動更新候補（確信度95%以上）:
  1. [自動] docs/design/payment_flow.md のシーケンス図を更新
  2. [自動] tests/unit/test_processor.py のテストケースを追加

■ レビュー推奨（確信度70-95%）:
  3. [確認] src/payment/stripe_adapter.py — インターフェース整合性
  4. [確認] src/payment/paypal_adapter.py — 同上
  5. [確認] config/payment.yaml — 設定値の整合性

■ 注意喚起（確信度50-70%）:
  6. [注意] db/master/payment_fees — 手数料率マスターとの整合性
  7. [注意] src/batch/nightly_settlement.py — 夜間バッチへの影響

■ 参考情報（確信度50%未満）:
  8. [参考] src/reporting/monthly_report.py — 月次レポートで決済データを使用

→ どれを実行しますか？ [1-8の番号, all, skip]
```

---

## 6. コンテキスト最適化エンジン

### 6.1 問題

影響セット E' が分かっても、全部をLLMのコンテキストに入れると：
- トークン数オーバー
- Lost in the Middle で中間部分を忘れる
- Context Rot で全体の精度が下がる

### 6.2 コンテキスト構成戦略

依存グラフの構造を使って、コンテキストを最適に構成する。

```
コンテキストウィンドウの構成:

┌─────────────────────────────────────────┐
│ [先頭: 高アテンション]                    │
│                                         │
│ 1. 変更対象ファイル（全文）               │
│ 2. 変更の意図・目的                      │
│ 3. 直接依存（confidence >= 0.9）の       │
│    関連コード                            │
│                                         │
├─────────────────────────────────────────┤
│ [中間: 低アテンション → 構造化で補完]      │
│                                         │
│ 4. 間接依存のメタ情報（コードではなく      │
│    「何をするモジュールか」の要約）        │
│ 5. 設定値の一覧と現在値                  │
│ 6. マスターデータの構造（DDLのみ）        │
│                                         │
│ ※ 中間部分はコード全文ではなく           │
│   メタ情報・要約を配置する               │
│   → Lost in the Middle の影響を最小化    │
│                                         │
├─────────────────────────────────────────┤
│ [末尾: 高アテンション]                    │
│                                         │
│ 7. 影響セットのサマリー表                 │
│ 8. 過去の関連障害（breaks_if_notエッジ）  │
│ 9. 「以下を確認してください」の           │
│    チェックリスト                        │
│                                         │
└─────────────────────────────────────────┘
```

### 6.3 設計原理

**原理1: 先頭に変更対象、末尾にチェックリスト**
→ U字型アテンションカーブの最も注意が高い位置に重要情報を配置

**原理2: 中間部分にはコード全文を入れない。メタ情報を入れる**
→ 中間部分はアテンションが低い。でもメタ情報（「このモジュールは○○する」）なら、
   忘れても致命的ではない。必要になったらオンデマンドで読み込む

**原理3: オンデマンド読み込み**
→ 中間部分のメタ情報を見て「ここを詳しく見る必要がある」と判断したら、
   その時点で該当ファイルを読み込む。最初から全部入れない

**原理4: 依存グラフがコンテキスト選択を決定する**
→ 何を入れるかを依存グラフのエッジ信頼度と距離で自動決定
   人間が「これも読んで」と指示する必要がない

---

## 7. V字モデルとの統合

### 7.1 V字モデルの各ノードとUDGの対応

```
要件定義 ←──────────────→ 受入テスト仕様
 [requirement]              [test_case:acceptance]
    │                           │
    │  implements               │  validates
    ↓                           ↓
基本設計 ←──────────────→ 結合テスト仕様
 [design_section:basic]     [test_case:integration]
    │                           │
    │  implements               │  validates
    ↓                           ↓
詳細設計 ←──────────────→ 単体テスト仕様
 [design_section:detail]    [test_case:unit]
    │                           │
    │  implements               │  validates
    ↓                           ↓
      ──→ 実装 (C + K + D) ←──
          [source + config + data]
```

### 7.2 双方向伝播の具体例

**下から上への伝播（逆伝播）:**

```
1. 実装中に「この設計では性能が出ない」と判明
2. 詳細設計の該当セクションに「性能問題」フラグ → 伝播
3. 基本設計のアーキテクチャ選択に影響 → 伝播
4. 要件定義の非機能要件と照合 → 「要件を満たせない可能性」を通知
5. 受入テスト仕様の性能テスト基準を確認 → 伝播

→ 人間に「要件を変えるか、設計を変えるか、実装を工夫するか」の選択肢を提示
```

**上から下への伝播（順伝播）:**

```
1. 要件定義に「多通貨対応」が追加
2. 基本設計の決済モジュール設計に影響 → 伝播
3. 詳細設計のDB設計（通貨カラム追加）に影響 → 伝播
4. 実装の決済処理コードに影響 → 伝播
5. 設定ファイルに通貨設定の追加が必要 → 伝播
6. マスターデータに通貨マスターが必要 → 伝播
7. 全レベルのテスト仕様に多通貨テストケース追加 → 伝播

→ 影響範囲の全体像と、各ノードでの具体的な変更案を提示
```

---

## 8. 未解決の問題（正直に）

### 8.1 設定駆動の分岐をどこまで追えるか

```java
// パターン1: 直接分岐（検出しやすい）
if (config.get("provider") == "stripe") {
    return new StripeAdapter();
}

// パターン2: リフレクション（検出困難）
String className = config.get("adapter.class");
return Class.forName(className).newInstance();

// パターン3: フレームワークのDI（検出困難）
// Spring Boot: application.yml → Bean定義 → 実行時注入
// 設定ファイルとコードの関係がフレームワークの中に隠れている
```

パターン2,3は静的解析では原理的に追えない。
LLM推論で「このクラスはDIで注入される可能性が高い」と推測するしかない。

**現時点の答え**: パターン1は自動検出。パターン2,3はLLM推論 + 人間注釈のハイブリッド。
完璧は目指さない。7割カバーがCPDDの目標。

### 8.2 依存グラフの鮮度維持

コードは毎日変わる。依存グラフも更新し続ける必要がある。

**案**:
- CIパイプラインにPhase 1（自動検出）を組み込み、毎コミットで更新
- Phase 2（LLM推論）は週次で差分実行
- エッジに `last_verified` と `decay` を持たせ、古いエッジの信頼度を自動低下

### 8.3 巨大システムでのスケーラビリティ

数千万ステップ、数万ファイルのシステムでUDGを構築すると、
ノード数十万、エッジ数百万になる可能性がある。

**案**:
- グラフDBの使用（Neo4j等）
- モジュール境界でのサブグラフ分割
- 変更影響の探索を深さN（例: 5ホップ）で打ち切り

### 8.4 新規開発 vs 既存改修

CPDDは既存システムの改修を主なターゲットとしているが、
新規開発時はUDGが存在しない。

**案**:
- 新規開発時は柱1（要件→設計自動生成）が主役
- 設計書が生成された時点で、設計書間のUDGを自動構築
- 実装が進むにつれて、コード↔設計のエッジが追加される
- Phase 4（学習）が最初から動く

---

## 9. 実装ロードマップ（段階的）

### Stage 0: 思想の公開（今ここ）
- リサーチレポート ✅
- アーキテクチャ設計書（この文書）
- Zenn記事で思想を公開
- GitHub リポジトリ作成

### Stage 1: 最小実装（大里LMSで実験）
- Phase 1の自動検出のみ実装
- YAML依存グラフの手動作成（大里LMS規模なら可能）
- 変化点伝播の最小版（直接依存のみ）
- Claude Code スキルとして実装

### Stage 2: LLM推論の追加
- Phase 2のLLM推論を実装
- 設定依存（Layer 3）の検出
- コンテキスト最適化エンジンの基本版

### Stage 3: データ依存 + 暗黙知
- Phase 3-4の人間検証 + 学習を実装
- Layer 4-5のエッジ追加
- git履歴からのco_changes検出

### Stage 4: プラグイン化
- Agent Skills標準に準拠したスキルバンドル
- Claude Code Plugin として配布
- マーケットプレイス公開

---

## 10. なぜこれを解けるのは殿だけなのか

1. **問題を体で知っている**: 数千万ステップのパッケージソフト開発で「ここ直したらどこが壊れるか分からない」を何年も経験した
2. **Layer 3-5の存在を知っている**: ソースだけ見ても追えない依存があることを、学術論文ではなく現場の痛みとして理解している
3. **熟練エンジニアの思考プロセスを言語化できる**: 自分自身がそのメンタルモデルを持っていた（あるいは持っている人と働いてきた）
4. **AIシステムの設計・運用ができる**: 将軍システムでマルチエージェントのYAML管理・伝播の仕組みを既に実装・運用している
5. **OSSとして出す意志がある**: これを商用ツールにして囲い込むのではなく、OSS公開して業界全体を変えようとしている

ツール作者にはLayer 3-5の存在が見えない。
学術研究者には現場の痛みが分からない。
SIerの現場エンジニアにはAIシステムを設計する力がない。

**この交差点に立てるのは殿だけ。**
