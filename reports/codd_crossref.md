# CPDD 突合分析: Claude Opus 4.6 × GPT-5.4 Pro Thinking (Heavy)

**作成日**: 2026-03-14

---

## 概要

Claude Opus 4.6 が設計した CPDD アーキテクチャ v1 に対し、GPT-5.4 Pro Thinking (Heavy) に22問を投げて検証。その結果を突合し、v2統合版に反映した。

---

## 1. 一致点（高確信で正しい方向性）

| テーマ | 合意内容 |
|--------|----------|
| グラフは正しい | 依存をグラフで管理する方向性は正しい |
| plain graphでは不十分 | エッジに条件・証拠・信頼度が必要 |
| Layer 3-5がフロンティア | 既存手法では解けていない |
| 7割の精度が目標 | 完璧を目指すと永遠に完成しない |
| LLMは最後の手段 | 静的解析→FW解析→実行時観測→最後にLLM |
| Phase 1はdeterministic | Tree-sitter/AST/SQLパーサが主役 |
| 人間注釈は種から引き出す | 「全部書け」ではなく「これ合ってる？」 |
| change kindで伝播変更 | interface vs impl で深さ・幅が異なる |
| Claude Code Skills親和性 | スキルバンドルとしての実装が自然 |
| 段階的導入 | repo全体にday 1は無理 |
| 無限コンテキストでも有用 | 本質はchange semantics |

---

## 2. Claude Opus 4.6の盲点（GPT-5.4が指摘）

### 2.1 条件付きエッジ（condition predicate）
v1にはエッジの有効条件がなかった。環境・テナント・feature flagで依存が変わるのにノイズ爆発する。
→ **v2で採用。全relationにcondition_predicateフィールド追加。**

### 2.2 Evidence Ledger
v1はconfidenceを直接ベタ書き。根拠なき信頼度は腐る。
→ **v2で採用。Evidence Ledgerを独立データ構造として導入。Noisy-ORで集約。**

### 2.3 3帯域分類（Green/Amber/Gray）
v1は5段階だが最適化方向（precision vs recall）が不明確。
→ **v2で採用。3帯域 + artifact class別閾値に変更。**

### 2.4 Spring Boot Actuator活用
v1は「DI依存は原理的に追えない」と書いた。Actuator beans/conditions/configpropsで大半取れる。
→ **v2で採用。Phase 2にframework introspection追加。**

### 2.5 OpenTelemetry trace correlation
v1はLayer 4を「LLM推論+人間注釈」のみ。runtime observationで一部deterministic。
→ **v2で採用。Stage 3にOTel trace correlation追加。**

### 2.6 SCC + state dominance
v1は循環依存をvisited setで止めるだけ。
→ **v2で採用。SCC畳み込み + state dominance check追加。**

### 2.7 Change Atom taxonomy
v1は変更を正規化していない。全変更が同じBFS。
→ **v2で採用。11種のchange atomを定義。**

### 2.8 停止条件の精密化
v1は2値threshold。本命はcontract boundary。
→ **v2で採用。5段階（contract > satisfiability > information gain > risk > depth）。**

### 2.9 Graph Delta生成
v1の柱1は「設計書生成」。正しくはgraph deltaを生成しdocumentはview。
→ **v2で採用。柱1を再定義。**

### 2.10 Ambiguity-basedコンテキスト選択
v1は重要度ベース。全文が必要かはambiguityで決める。
→ **v2で採用。**

---

## 3. GPT-5.4の盲点（Claude/リサーチがカバー）

| テーマ | 詳細 |
|--------|------|
| 競合分析 | 具体的な15ツールの比較、ポジショニングマトリクスなし |
| 配布モデル | Agent Skills Open Standard、Plugin戦略の具体性が薄い |
| 殿のポジショニング | 「なぜこの人がやるべきか」への回答なし（プロンプト範囲外） |
| 大里LMS実験台 | 具体的な導入ターゲットの言及なし |

---

## 4. 意見が分かれた点

### 4.1 5層 vs 3軸
- Claude: 5層（直感的）
- GPT-5.4: 3軸×5源泉（本質的）
- **統合判断**: 内部実装は3軸、外部説明は5層のdual表現

### 4.2 Graph DB
- Claude: YAML/JSON → Neo4j
- GPT-5.4: SQLite → Neo4j projection
- **統合判断**: canonical storeはSQLite/DuckDB。YAMLはannotation用。Neo4jは必要時にprojection。

### 4.3 スコア集約
- Claude: 乗算ベース
- GPT-5.4: Noisy-OR
- **統合判断**: Noisy-OR採用（複数の弱い証拠が集まると強くなる性質が本質に合う）

### 4.4 コンテキスト構成
- Claude: U字型配置
- GPT-5.4: MMR付きknapsack
- **統合判断**: MMRで「何を」、U字型で「どこに」。両方統合。

---

## 5. 統合結果

12項目を取り込み `cpdd_architecture_v2.md` として統合。

主要な名称変更:
- UDG (Unified Dependency Graph) → **CEG (Conditioned Evidence Graph)**
- 5層 → **3軸（内部）+ 5層（外部説明）のdual表現**
- BFS + threshold → **Change Calculus（change atom × transfer function × stop rule）**
