# CPDD (Change-Propagation-Driven Development) 先行研究統合レポート

**作成日**: 2026-03-14
**リサーチソース**: 4本の並列リサーチ結果を統合

---

## 1. エグゼクティブサマリー

**CPDDとは**: 仕様が駆動するのではなく、V字モデル上の任意のノード（要件定義・設計書・コード・テスト仕様等）で発生した「変化点(Change)」が、依存グラフに沿って全ノードへ双方向に自動伝播する開発方法論。要件変更がテスト仕様まで流れるだけでなく、実装上の発見が要件定義に遡及する。

**先行研究の結論**: CPDDの構成要素となるパーツ（要件→設計の自動生成、ドキュメント依存管理、変化点伝播、コンテキスト最適化、プラグイン配布）は各領域で個別に研究・実装されているが、これらを統合し「変化点の双方向伝播」を軸に体系化した方法論は存在しない。

**殿のポジショニング**: エンタープライズSIerでのV字モデル実戦経験（要件定義→設計→実装→テストの全工程を現場で回してきた経験）と、マルチエージェントAIシステムの設計・運用実績（将軍システム）、およびOSS公開によるコミュニティ形成力を兼ね備える。KAMUI/Zoltraakの元木氏やGEAR.indigoと同じ日本語AIエンジニアリング圏内にいながら、エンタープライズ現場の痛みを知る唯一のポジションからCPDDを提唱できる。

---

## 2. CPDDの3本柱と先行研究マップ

### 柱1: 要件定義 → 設計書自動生成

要件定義からAIが設計書（アーキテクチャ、画面設計、DB設計等）を自動生成する研究・ツール群。2025年の「Spec-Driven Development (SDD)」ブームにより急速に発展中。

| 手法/ツール | 提唱者/提供元 | 概要 | 強み | 限界 |
|-------------|--------------|------|------|------|
| **SDD** | Thoughtworks (2025) | 要件仕様書をAIエージェントへのプロンプトとして使い、コードを生成するパラダイム。3段階の厳密度: spec-first, spec-anchored, spec-as-source | Technology Radar掲載、Martin Fowler推薦、業界標準化の流れ | 「設計書の自動生成」より「コードの自動生成」に重点。片道（仕様→コード）で逆方向の伝播がない |
| **Amazon Kiro** | AWS (2025 GA) | AI IDE (VS Code fork)。要件→ユーザーストーリー→受入基準→技術設計→実装タスクのワークフローを強制 | 最も構想に近い商用ツール。ワークフロー強制型 | IDE統合型で独立した設計書生成ではない。片道フロー |
| **GitHub Spec-Kit** | GitHub (OSS) | `/specify`→`/plan`→`/tasks`の3コマンド。22以上のAIプラットフォーム対応 | マルチプラットフォーム対応、テンプレートベースで軽量 | 人間が設計書を書くのをAIが支援するレベル |
| **BMAD-METHOD** | BMad Code (OSS) | 21の専門AIエージェント(PM, Architect, Developer等)をMarkdownで定義。PRD→設計→実装の4フェーズ | **思想的にCPDDに最も近い**: ドキュメントがSingle Source of Truth、コードは下流派生物 | 双方向伝播の仕組みがない。変化点管理は手動 |
| **MAAD Framework** | 学術論文 (arXiv 2507.21382, 2503.20536) | 4エージェント(Analyst, Modeler, Designer, Evaluator)が要件仕様→アーキテクチャ設計図を自動生成 | 学術的に最も厳密。MetaGPT比較実験で優位性を実証 | 学術研究段階。逆方向（実装→要件）の伝播は対象外 |
| **Tessl** | Tessl (2025) | 仕様ファースト開発フレームワーク。10,000以上のプリビルトspec、MCP Server対応 | 「仕様が主要成果物」という急進的立場。specレジストリは独自 | 仕様→実装に焦点。双方向性なし |
| **GEAR.indigo** | 日本発 | プロジェクト概要入力→要件定義書→設計書→ソースコードをステップバイステップで自動生成 | 殿の構想に最も直接的に近い日本発商用ツール | 変化点伝播・依存管理の仕組みは不明 |
| **KAMUI/Zoltraak** | 元木大介 (KandaQuantum) | 自然言語→要件定義YAML→150ファイルのシステム生成。Grimoire(YAML要件定義)、Arcana(リバースエンジニアリング) | 双方向性の萌芽: コード→Grimoire(YAML要件定義)へのリバースエンジニアリング | プラットフォーム全体としてはまだ発展途上 |
| **MDA/MDD** | OMG (2001-) | PIM→PSM→コードの変換パイプライン。UMLモデルベース | 歴史ある標準。2024-2032でCAGR 12.8%成長。LLM統合研究も進行中 | 起点が自然言語ではなくUMLモデル。AI統合は研究段階 |

**CPDDとの決定的差分**: 既存のSDD系手法は全て**片道**(仕様→コード)。CPDDは**双方向**: 実装中に発見された設計上の問題が要件定義まで遡及し、テスト仕様の変更が設計書を更新する。V字モデルの全ノード間で変化点が伝播する。

---

### 柱2: ドキュメント依存管理 + 変化点伝播

ソフトウェア開発ドキュメント間の依存関係をトラッキングし、変更影響を分析・伝播する手法群。

#### 2-A. 要件トレーサビリティマトリクス (RTM) ツール群

| ツール | 提供元 | 概要 | 強み | 限界 |
|--------|--------|------|------|------|
| **IBM DOORS / DOORS Next** | IBM | 大規模要件管理の業界標準 | 数千件の要件、双方向トレーサビリティ、航空宇宙・防衛で圧倒的シェア | 変更の「検知・通知」まで。自動伝播はしない。UIが重い |
| **Polarion** | Siemens | ALM統合型要件管理 | LiveDocs(段落単位トレーサビリティ)、自動車・電子機器に強い | 同上。高コスト |
| **Jama Connect** | Jama Software | ハード・ソフト横断 | リアルタイム上流・下流トレーサビリティ、FDA/ISO規制対応 | 同上 |
| **ReqView** | ReqView | Git連携の軽量要件管理 | HW/SWの要件管理をGit上で実現、RTM自動生成 | 軽量だが伝播機能なし |

市場規模: 2025年に約15.9億USD → 2026年に17.5億USDへ成長見込み。

#### 2-B. Requirements-as-Code / Docs-as-Code

| ツール/手法 | 提唱者/提供元 | 概要 | 強み | 限界 |
|-------------|--------------|------|------|------|
| **TRLC** | BMW Software Engineering (OSS) | 要件をDSLテキストで定義。型システム付き。Gitでバージョン管理、CIでバリデーション | 自動車業界実戦済み。ISO 26262準拠 | 変更の「検証」はできるが「自動伝播」はしない |
| **LOBSTER** | BMW Software Engineering (OSS) | TRLCの要件とコード・テストを紐づけるトレーサビリティツール | TRLC+LOBSTERでISO 26262準拠のトレーサビリティレポート自動生成 | リンク管理が主。変化点の自動伝播は対象外 |
| **Sphinx-Needs / Open-Needs** | OSS | rst/md内に「need object」を定義しIDで相互リンク。動的RTM生成 | Docs-as-Codeの最も成熟した実装 | CI連動だが、変化点伝播は手動 |

#### 2-C. SDD系の依存管理ツール

| ツール | 提唱者/提供元 | 概要 | 強み | 限界 |
|--------|--------------|------|------|------|
| **Intent** | Augment Code | Living Specificationプラットフォーム。**双方向同期**: コード変更→仕様も自動更新 | **CPDDの柱2に最も近い既存実装**。Coordinator/Implementor/Verifierの3エージェント構成。40万ファイル対応 | 「仕様とコード」の2ノード間の同期。V字モデル全ノードの伝播ではない |
| **KAMUI/Grimoire** | 元木大介 | YAML要件定義書。依存関係YAML+関数定義YAMLの差し込み。リバースエンジニアリング対応 | 依存関係をYAMLで明示管理する先駆的アプローチ | 伝播の自動化はまだ研究段階 |

#### 2-D. 変更影響分析 (Change Impact Analysis) の学術研究

| 手法 | 提唱者/出典 | 概要 | CPDDとの関連 |
|------|------------|------|-------------|
| **Ripple** | Yadavally & Nguyen (ICSE 2026) | LLMのChain-of-Thought推論で変更影響を予測。Planner LLM→Predictor LLMの2フェーズ | CPDDの伝播エンジンの参考実装候補 |
| **DepsRAG** | arXiv 2024 | LLM+RAG+Knowledge Graphで依存関係をKGとして構築。PyPI/NPM/Cargo/Go対応 | パッケージレベルの依存解析。ドキュメントレベルへの拡張が課題 |
| **Temporal Graph + GNN** | ScienceDirect 2023 | ソフトウェアをTemporal Graphとしてモデル化し、GNN+LSTMで変更伝播を予測 | 変更伝播の予測モデルとして参考になる |
| **NARCIA** | ESEC/FSE 2015 | 自然言語要件の変更影響分析自動化 | 要件間の依存関係分析。古い研究だがドメインは直接一致 |

#### 2-E. アーキテクチャ判断の依存管理

| ツール | 概要 |
|--------|------|
| **ADR (Architecture Decision Records)** | 設計判断を記録しSupersedes/Superseded byで依存を管理。adr-tools, MADR, Log4brains等 |
| **Structurizr** | C4モデルでアーキテクチャを可視化+ADR統合 |

**CPDDとの決定的差分**: 既存ツールは変更の「検知・通知」まで。CPDDは検知後に「自動伝播+選択肢提示」を行う。例: DB設計の変更を検知→影響を受けるAPI設計書・テスト仕様の変更案を自動生成→人間が選択肢から承認。Intentの「双方向同期」が最も近いが、仕様-コード間の2ノードに限定されており、V字モデル全体への伝播ではない。

---

### 柱3: 最適コンテキスト管理

LLM/AIエージェントが大規模コードベースを扱う際の、コンテキストウィンドウの最適利用に関する研究・ツール群。

#### 3-A. 根本問題: Lost in the Middle / Context Rot

| 問題 | 提唱者/出典 | 概要 | 意味 |
|------|------------|------|------|
| **Lost in the Middle** | Stanford (Liu et al., 2023, arXiv: 2307.03172) | LLMはコンテキストの先頭と末尾に高い注意を払うが、**中間部分の情報を見落とす**「U字型アテンションカーブ」を実証 | 全量投入しても中間部分の変更影響を見落とすリスク |
| **NoLiMa** | Adobe Research (ICML 2025) | 語彙的手がかりを除去したベンチマーク。32kトークンで13モデル中11モデルが短文脈時の50%以下に性能低下 | 「コンテキストを長くすれば解決」は幻想 |
| **Context Rot** | Chroma Research (2025) | 入力トークン数増加でLLM性能が劣化。コンテキストウィンドウが満杯でなくても発生。18最新モデル(GPT-4.1, Claude 4, Gemini 2.5等)で検証 | コンテキスト管理は「入れる」だけでなく「入れない」判断が重要 |

#### 3-B. コンテキスト管理の手法・ツール

| カテゴリ | 手法/ツール | 概要 | トークン効率 |
|---------|------------|------|------------|
| **AST構造解析** | Aider Repo Map | Tree-sitter + PageRankで重要定義のみをコンテキストに含める | 高 |
| **LSP依存グラフ** | LSPRAG (ICSE 2026, 清華大学) | LSPの"Go to Definition"/"Find References"で精密な依存グラフ構築。トークン使用量39%削減、カバレッジ135%向上 | 非常に高い |
| **階層的要約** | Code-Craft (HCGS, arXiv: 2504.08975) | LSPで言語非依存のコード解析、ボトムアップで多層的要約生成。top-1検索精度82%相対改善 | 高 |
| **ASTチャンキング** | cAST (EMNLP 2025) | Tree-sitterでASTノード単位のチャンク生成。意味的境界を保持した分割 | 高 |
| **セマンティックグラフ** | Sourcegraph Cody RSG | Repo-level Semantic Graphでリポジトリ全体をグラフ化。Contextual BM25 + Embeddings | 非常に高い |
| **フルセマンティック** | Augment Code Context Engine | 10万ファイル以上を同時処理。コミット履歴・暗黙知もインデックス。MCP経由で他ツールに接続可能 | 非常に高い |
| **Codified Context** | CLAUDE.md / AGENTS.md / .cursorrules | AI向けに意図的に書かれた構造化文書。3層構造: Hot Memory / Specialized Agents / Cold Memory | 高(手動) |
| **Observation Masking** | JetBrains Research (NeurIPS 2025) | 環境観察結果のみ隠蔽し、アクション・推論履歴は保持。LLM要約と同等以上の性能でコスト半減 | 高 |

**25%ルール** (Codified Context Infrastructure, arXiv: 2602.20478): 108,000行のC#プロジェクトをClaude Codeのみで構築した結果、アーキテクチャ整合性維持に約25,000行の仕様・プロンプト・ルールが必要だった（コード量の約25%）。

#### 3-C. 上位概念: Context Engineering

| 提唱者 | 要点 |
|--------|------|
| **Martin Fowler / Thoughtworks** | 「コンテキストが今やコーディングエージェントのボトルネック」。AIから10倍の価値を引き出す開発者と2倍に留まる開発者を分けるのはコンテキストエンジニアリングのスキル |
| **Andrej Karpathy** | 2025年6月、「Context Engineering」という用語を広めた |
| **技術評論社 (2026年2月)** | 書籍「LLMの原理、RAG・エージェント開発から読み解く コンテキストエンジニアリング」出版 |

**CPDDとの決定的差分**: 既存のContext Engineeringはツール実装レベルの話（どのファイルをコンテキストに入れるか）。CPDDはこれを**方法論として体系化**する。変化点伝播の際に「何をコンテキストに含めるべきか」を依存グラフから自動判断し、Lost in the Middleを回避しつつ必要十分な情報のみを提供する。

---

## 3. 配布モデル: プラグインとしてのCPDD

### 3-A. 配布プラットフォームの現状

| プラットフォーム | バンドル機構 | マーケットプレイス | クロスプラットフォーム | 成熟度 |
|-----------------|-------------|-------------------|---------------------|--------|
| **Claude Code Plugins** | スキル+エージェント+フック+MCP+LSP | 公式マーケットプレイス、GitHub、npm、pip | Agent Skills標準で一部互換 | 高（本番レベル） |
| **Agent Skills Open Standard** | SKILL.md (YAML frontmatter + Markdown) | -- | **30以上のAIツール対応** (Claude Code, Codex, Cursor, Copilot, Gemini CLI, Junie, Roo Code等) | 高 |
| **Cursor Rules** | 個別ファイル（バンドル不可） | なし（GitHub共有のみ） | Agent Skills標準で一部互換 | 中-高 |
| **MCP Servers** | ツール単位 | npm/pip/Docker | 広くクロスプラットフォーム | 高 |
| **GitHub Copilot Extensions** | VS Code Extension Pack | GitHub Marketplace | VS Code限定 | 中 |

### 3-B. 推奨アーキテクチャ

```
cpdd-plugin/
├── .claude-plugin/
│   └── plugin.json                # メタデータ・バージョン管理
├── skills/
│   ├── change-propagation/        # 変化点伝播スキル（CPDDコア）
│   │   ├── SKILL.md               # Agent Skills標準準拠
│   │   └── scripts/propagate.py
│   ├── dependency-graph/          # ドキュメント依存管理スキル
│   │   ├── SKILL.md
│   │   └── scripts/analyze.py
│   ├── spec-generator/            # 要件→設計書自動生成スキル
│   │   └── SKILL.md
│   ├── context-optimizer/         # コンテキスト最適化スキル
│   │   └── SKILL.md
│   └── quality-gate/              # 品質ゲートスキル
│       ├── SKILL.md
│       └── scripts/validate.sh
├── agents/
│   ├── architect.md               # 設計エージェント
│   ├── propagator.md              # 変化点伝播エージェント
│   └── reviewer.md                # レビューエージェント
├── hooks/
│   └── hooks.json                 # ファイル編集時の依存チェック自動実行
├── .mcp.json                      # 依存グラフMCPサーバー設定
└── settings.json                  # デフォルト設定
```

### 3-C. 日本語圏での先行事例

- Zennで「Claude Code skills plugin」関連記事: 195件（2026年3月時点）
- しかし「複数スキルをバンドルした方法論パッケージ」という切り口の日本語記事は**ゼロ**
- 「開発方法論をプラグインとして配布する」というコンセプト自体が未開拓領域

---

## 4. ポジショニングマトリクス

| 手法/ツール | 要件→設計 | 依存管理 | 変化伝播 | コンテキスト管理 | AI活用 | プラグイン配布 | エンタープライズ対応 |
|-------------|:---------:|:--------:|:--------:|:---------------:|:------:|:-------------:|:------------------:|
| **CPDD** | **双方向** | **V字全体** | **自動+選択肢提示** | **方法論として体系化** | **中核** | **Agent Skills標準** | **SIer実戦経験に基づく** |
| SDD (Thoughtworks) | 片道 | -- | -- | -- | 中核 | -- | 概念のみ |
| Amazon Kiro | 片道 | -- | -- | IDE内蔵 | 中核 | IDE統合 | -- |
| GitHub Spec-Kit | テンプレ | -- | -- | -- | 中核 | OSS | -- |
| BMAD-METHOD | 片道 | -- | -- | -- | 中核 | OSS | -- |
| MAAD Framework | 片道 | -- | -- | -- | 中核 | 学術 | -- |
| Intent (Augment) | 双方向* | 仕様-コード | 双方向* | Context Engine | 中核 | MCP | -- |
| DOORS/Polarion/Jama | -- | RTM | 検知・通知 | -- | 部分的 | 商用 | 規制産業標準 |
| TRLC+LOBSTER (BMW) | -- | DSL | CI検証 | -- | -- | OSS | ISO 26262 |
| KAMUI/Zoltraak | 片道+逆 | Grimoire YAML | 研究段階 | -- | 中核 | 部分的OSS | -- |
| GEAR.indigo | 片道 | -- | -- | -- | 中核 | 商用 | 日本向け |
| Aider Repo Map | -- | -- | -- | AST+PageRank | 中核 | OSS | -- |
| LSPRAG | -- | LSP依存グラフ | -- | LSP精密解析 | 中核 | 学術 | -- |
| Codified Context | -- | -- | -- | 構造化文書 | 前提 | CLAUDE.md等 | -- |

*Intent: 仕様-コード間の2ノード限定。V字モデル全体ではない。

**CPDDだけが全列を満たす。** 特に「変化伝播: 自動+選択肢提示」と「コンテキスト管理: 方法論として体系化」の組み合わせは他に存在しない。

---

## 5. CPDDの新規性（何が新しいか）

### 新規性1: V字モデル全ノードの双方向変化点伝播

既存手法は片道（仕様→コード）か、2ノード間の同期（Intent: 仕様-コード）に留まる。CPDDはV字モデル上の任意のノード（要件定義・基本設計・詳細設計・コード・単体テスト仕様・結合テスト仕様・受入テスト仕様）で発生した変化点が、依存グラフに沿って全ノードへ双方向に自動伝播する。

**根拠**: SDD (Thoughtworks)は明確に「仕様→コード」の片道。Intentは「仕様-コード」の2ノード同期だがテスト仕様や要件定義への遡及はない。DOORS/Polarionは「検知・通知」まで。Ripple (ICSE 2026)は影響分析研究だが「伝播」の自動実行は行わない。

### 新規性2: 変化点が駆動する（仕様ではなく変化が起点）

SDDは「仕様が駆動」する。CPDDは「変化点が駆動」する。これにより、仕様が確定する前の探索的開発フェーズでも機能する。コードの実験的変更が設計書への反映を自動的にトリガーする。

**根拠**: SDD系手法は全て「まず仕様を書く」ことを前提とする。しかしエンタープライズ現場では、既存システムの改修（仕様が不完全な状態からスタートする）が大半。CPDDは変化点を起点とするため、既存システムの改修にも自然に適用できる。

### 新規性3: コンテキスト管理の方法論的体系化

既存のContext Engineering研究はツール実装レベル（Aider Repo Map, LSPRAG, Codified Context等）に留まる。CPDDは「変化点伝播時に何をコンテキストに含めるべきか」を依存グラフから自動判断する方法論を提供し、Lost in the Middle問題とContext Rot問題を構造的に回避する。

**根拠**: Martin FowlerもKarpathyもContext Engineeringを「ツール/スキル」として論じており、開発方法論のレイヤーで体系化した例はない。Codified Context Infrastructure論文（arXiv: 2602.20478）は最も近いが、あくまで「インフラ」としての構造化であり「方法論」ではない。

### 新規性4: エンタープライズV字モデルとAIエージェントの統合

学術研究（MAAD等）はグリーンフィールド（新規開発）を前提とする。エンタープライズSIerの現場では、既存システムの改修・保守がタスクの80%以上を占める。CPDDはV字モデル（エンタープライズSIerの共通言語）とAIエージェントを統合し、既存システムの改修にも適用可能な方法論を提供する。

**根拠**: BMAD-METHODはAgile前提。MAAD Frameworkは新規アーキテクチャ設計が対象。Kiroも新規プロジェクト向け。V字モデルに基づく既存システム改修のためのAI方法論は存在しない。

### 新規性5: プラグインとして配布可能な方法論パッケージ

開発方法論をAIツールのプラグイン（Agent Skills標準準拠）として配布するコンセプト自体が新しい。Rails (Convention over Configuration) やESLint Config等の先例はあるが、AI開発方法論をスキル+エージェント+フック+MCPのバンドルとして配布する例は存在しない。

**根拠**: Claude Code Pluginsの公式事例（feature-dev, code-review等）は「ワークフロー」のバンドルであり「方法論」ではない。日本語圏でのバンドル型方法論パッケージの先行事例はゼロ。

---

## 6. 参考文献・ソース一覧

### 学術論文

| 論文 | 出典 | URL |
|------|------|-----|
| Lost in the Middle: How Language Models Use Long Contexts | Stanford, TACL 2023 | [arXiv: 2307.03172](https://arxiv.org/abs/2307.03172) |
| NoLiMa: Long-Context Evaluation Beyond Literal Matching | Adobe Research, ICML 2025 | [arXiv: 2502.05167](https://arxiv.org/abs/2502.05167) |
| Never Lost in the Middle (PAM QA) | ACL 2024 | [arXiv: 2311.09198](https://arxiv.org/abs/2311.09198) |
| Context Rot | Chroma Research, 2025 | [research.trychroma.com](https://research.trychroma.com/context-rot) |
| Spec-Driven Development: From Code to Contract | arXiv 2025 | [arXiv: 2602.00180](https://arxiv.org/abs/2602.00180) |
| MAAD: Automate Software Architecture Design | arXiv 2025 | [arXiv: 2507.21382](https://arxiv.org/abs/2507.21382) |
| MAAD: Knowledge-Based Multi-Agent Collaboration | FSE 2025 | [arXiv: 2503.20536](https://arxiv.org/abs/2503.20536) |
| From Requirements to Architecture | Eisenreich, 2025 | [arXiv: 2504.12192](https://arxiv.org/abs/2504.12192) |
| LLMs for Requirements Engineering: SLR | arXiv 2025 | [arXiv: 2509.11446](https://arxiv.org/abs/2509.11446) |
| Software Architecture Meets LLMs | arXiv 2025 | [arXiv: 2505.16697](https://arxiv.org/abs/2505.16697) |
| AI-Driven Automated Software Documentation Generation | IEEE 2024 | [IEEE Xplore: 10691221](https://ieeexplore.ieee.org/document/10691221/) |
| Towards AI-Enabled Model-Driven Architecture | Scitepress 2025 | [PDF](https://www.scitepress.org/Papers/2025/133740/133740.pdf) |
| MDA + CNN Code Generation | Frontiers 2025 | [frontiersin.org](https://www.frontiersin.org/journals/artificial-intelligence/articles/10.3389/frai.2025.1491958/full) |
| cAST: AST-Based Structural Chunking | EMNLP 2025 | [arXiv: 2506.15655](https://arxiv.org/html/2506.15655v1) |
| Code-Craft: Hierarchical Graph-Based Code Summarization | arXiv 2025 | [arXiv: 2504.08975](https://arxiv.org/abs/2504.08975) |
| LSPRAG: LSP-Guided RAG | ICSE 2026 | [arXiv: 2510.22210](https://arxiv.org/abs/2510.22210) |
| Monitor-Guided Decoding of Code LMs | NeurIPS 2023 | [NeurIPS Proceedings](https://proceedings.neurips.cc/paper_files/paper/2023/file/662b1774ba8845fc1fa3d1fc0177ceeb-Paper-Conference.pdf) |
| The Complexity Trap (Observation Masking) | JetBrains Research, NeurIPS 2025 | [JetBrains Blog](https://blog.jetbrains.com/research/2025/12/efficient-context-management/) |
| Codified Context Infrastructure | arXiv 2026 | [arXiv: 2602.20478](https://arxiv.org/abs/2602.20478) |
| RepoAgent | arXiv 2024 | [arXiv: 2402.16667](https://arxiv.org/html/2402.16667v1) |
| Ripple: Intent-Aware Change Impact Analysis | ICSE 2026 | [PDF](https://aashishyadavally.github.io/assets/pdf/pub-icse2026-(2).pdf) |
| DepsRAG: LLM+RAG+Knowledge Graph | arXiv 2024 | [arXiv: 2405.20455](https://arxiv.org/html/2405.20455v3/) |
| NARCIA: NL Requirements Change Impact Analysis | ESEC/FSE 2015 | -- |
| Context Engineering for Multi-Agent LLM Code Assistants | arXiv 2025 | [arXiv: 2508.08322](https://arxiv.org/html/2508.08322v1) |

### ツール・OSS

| ツール | URL |
|--------|-----|
| GitHub Spec-Kit | [github.com/github/spec-kit](https://github.com/github/spec-kit) |
| BMAD-METHOD | [github.com/bmad-code-org/BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) |
| TRLC (BMW) | [github.com/bmw-software-engineering/trlc](https://github.com/bmw-software-engineering/trlc) |
| LOBSTER (BMW) | [github.com/bmw-software-engineering/lobster](https://github.com/bmw-software-engineering/lobster) |
| Zoltraak | [github.com/dai-motoki/zoltraak](https://github.com/dai-motoki/zoltraak) |
| Sphinx-Needs | [sphinx-needs.com](https://www.sphinx-needs.com/) |
| Open-Needs | [open-needs.org](https://open-needs.org/) |
| ADR Tools | [adr.github.io](https://adr.github.io/) |
| Log4brains | [github.com/thomvaill/log4brains](https://github.com/thomvaill/log4brains) |
| Reqflow | [goeb.github.io/reqflow](https://goeb.github.io/reqflow/) |
| BASIL (Red Hat/ELISA) | [github.com/elisa-tech/BASIL](https://github.com/elisa-tech/BASIL) |
| OSRMT | [github.com/osrmt/osrmt](https://github.com/osrmt/osrmt) |
| Aider | [aider.chat](https://aider.chat/) |
| Continue.dev | [docs.continue.dev](https://docs.continue.dev/) |
| awesome-mcp-servers | GitHub 83.1k stars |
| awesome-cursorrules | GitHub 38.4k stars |

### 商用ツール・サービス

| ツール | URL |
|--------|-----|
| Amazon Kiro | [kiro.dev](https://kiro.dev/) |
| Tessl | [tessl.io](https://tessl.io/) |
| Intent (Augment Code) | [augmentcode.com](https://www.augmentcode.com/) |
| GEAR.indigo | [WEEL紹介記事](https://weel.co.jp/media/innovator/gear-indigo/) |
| CoBrain | [cobrain.jp](https://cobrain.jp/) |
| Jitera | [prtimes.jp](https://prtimes.jp/main/html/rd/p/000000020.000110428.html) |
| IBM DOORS | IBM |
| Polarion | Siemens |
| Jama Connect | Jama Software |
| KAMUI | [kamui.ai](https://www.kamui.ai/) |
| Sourcegraph Cody | [sourcegraph.com](https://sourcegraph.com/) |
| Augment Code Context Engine | [augmentcode.com/context-engine](https://www.augmentcode.com/context-engine) |

### 記事・書籍

| タイトル | 出典 | URL |
|---------|------|-----|
| Spec-Driven Development Unpacking 2025 | Thoughtworks | [thoughtworks.com](https://www.thoughtworks.com/en-us/insights/blog/agile-engineering-practices/spec-driven-development-unpacking-2025-new-engineering-practices) |
| SDD Tools: Kiro, spec-kit, Tessl | Martin Fowler | [martinfowler.com](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html) |
| Context Engineering for Coding Agents | Martin Fowler | [martinfowler.com](https://martinfowler.com/articles/exploring-gen-ai/context-engineering-coding-agents.html) |
| SDD Map of 30+ Frameworks | Medium (visrow) | [medium.com](https://medium.com/@visrow/spec-driven-development-is-eating-software-engineering-a-map-of-30-agentic-coding-frameworks-6ac0b5e2b484) |
| Claude Code Plugins公式ドキュメント | Anthropic | [code.claude.com/docs/en/plugins](https://code.claude.com/docs/en/plugins) |
| Agent Skills Open Standard | agentskills.io | [agentskills.io](https://agentskills.io/) |
| Claude Code Skills公式ドキュメント | Anthropic | [code.claude.com/docs/en/skills](https://code.claude.com/docs/en/skills) |
| Introducing RDD | Mehdi Parsaei | [medium.com](https://mehdiparsaeigm.medium.com/introducing-requirement-driven-development-rdd-a-pragmatic-approach-to-software-development-e7329a82f2d3) |
| コンテキストエンジニアリング | 技術評論社 (2026) | [gihyo.jp](https://gihyo.jp/book/2026/978-4-297-15419-6) |
| LLMはコンテキストがすべて | Zenn (karaage0703) | [zenn.dev](https://zenn.dev/karaage0703/articles/76f2a1b20cd6c1) |
| コンテキストエンジニアリング | 日経XTECH | [xtech.nikkei.com](https://xtech.nikkei.com/atcl/nxt/keyword/18/00002/111700298/) |
| How Claude Code Works | Anthropic | [code.claude.com/docs](https://code.claude.com/docs/en/how-claude-code-works) |
| How Cody Understands Your Codebase | Sourcegraph | [sourcegraph.com/blog](https://sourcegraph.com/blog/how-cody-understands-your-codebase) |

---

*本レポートは4本の並列リサーチ（要件→設計自動生成、ドキュメント依存管理+変化点伝播、最適コンテキスト管理、プラグイン配布モデル）の結果を統合し作成した。*
