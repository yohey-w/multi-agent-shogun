# CPDD プロジェクト構成設計書

**作成日**: 2026-03-15
**目的**: 任意のプロジェクトにCPDDを導入する際の標準フォルダ構成・ファイル構成を定義する

---

## 1. 設計方針

### 原則

1. **非侵襲**: 既存プロジェクトの構成を壊さない。`cpdd/` ディレクトリを追加するだけ
2. **段階的**: Stage 0（手動注釈のみ）から始められる。パーサーやツールは後から追加
3. **ポータブル**: 言語・FW非依存。Python/Java/TypeScript/Go なんでも対応可能
4. **gitフレンドリー**: 全データがテキストベースで差分管理可能

### CPDDが管理する3つのデータ

| データ | 格納先 | 形式 | 説明 |
|--------|--------|------|------|
| **グラフ本体** | `cpdd/graph.db` | SQLite | ノード・エッジ・証拠の正規化データ |
| **人間注釈** | `cpdd/annotations/*.yaml` | YAML | 暗黙のルール・慣習・手動リンク |
| **レポート出力** | `cpdd/reports/` | Markdown | 影響分析レポート（生成物） |

---

## 2. 標準フォルダ構成

```
<project-root>/
├── src/                          # 既存ソースコード（言語依存）
├── tests/                        # 既存テスト
├── docs/                         # 既存ドキュメント（設計書等）
├── config/                       # 既存設定ファイル
│
├── cpdd/                         # ← CPDD追加分（ここだけ）
│   │
│   ├── cpdd.yaml                 # CPDD設定ファイル（プロジェクト固有設定）
│   │
│   ├── graph.db                  # CEG本体（SQLite）
│   │
│   ├── annotations/              # 人間注釈（YAML）
│   │   ├── conventions.yaml      # 暗黙のルール・慣習
│   │   ├── doc_links.yaml        # ドキュメント⇔コードのリンク
│   │   ├── data_dependencies.yaml # データ駆動依存（マスターテーブル等）
│   │   └── overrides.yaml        # 自動検出の上書き・否定証拠
│   │
│   ├── reports/                  # 生成レポート（gitignore推奨）
│   │   └── impact_YYYYMMDD_HHMMSS.md
│   │
│   └── .gitignore                # graph.db と reports/ を除外
│
├── scripts/                      # 既存スクリプト
│   └── cpdd/                     # CPDDツール群
│       ├── init.py               # プロジェクト初期化
│       ├── scan.py               # Phase 1: AST解析 → グラフ生成
│       ├── propagate.py          # 伝播エンジン
│       ├── impact.py             # 影響レポート生成
│       └── annotate.py           # 注釈ヘルパー
│
└── .cpdd_version                 # CPDDバージョン（互換性管理用）
```

---

## 3. 各ファイルの詳細

### 3.1 cpdd/cpdd.yaml — プロジェクト設定

```yaml
# CPDD プロジェクト設定
version: "0.1.0"

project:
  name: "osato-lms"
  language: "python"        # primary language
  frameworks:
    - "django"              # FW introspection対象
    - "celery"

# 解析対象
scan:
  source_dirs:
    - "src/"
  test_dirs:
    - "tests/"
  doc_dirs:
    - "docs/"
  config_files:
    - "config/settings.py"
    - "config/urls.py"
    - ".env"
  exclude:
    - "**/__pycache__/**"
    - "**/migrations/**"    # Djangoのmigrationは別途schema_contractとして処理

# グラフ設定
graph:
  store: "sqlite"           # sqlite | duckdb
  path: "cpdd/graph.db"

# 帯域分類の閾値
bands:
  green:
    min_confidence: 0.90
    min_evidence_count: 2
  amber:
    min_confidence: 0.50
  # gray: それ以外

# 伝播設定
propagation:
  max_depth: 10
  stop_at_contract_boundary: true
```

### 3.2 cpdd/annotations/conventions.yaml — 暗黙のルール

```yaml
# 暗黙のルール（熟練者の頭の中にあるもの）
# Stage 0ではここが唯一の依存情報源

conventions:
  - id: "conv_001"
    description: "ユーザーマスターを変更したら必ず認証モジュールも確認する"
    when_changed: "db_table:users"
    must_review:
      - "module:auth"
      - "test:test_auth_*"
    reason: "usersテーブルのカラム変更が認証ロジックに影響した過去の障害 (2026-01)"
    added_by: "watanabe"
    added_at: "2026-03-15"

  - id: "conv_002"
    description: "料金計算ロジックを変えたらメール通知テンプレートも確認"
    when_changed: "module:billing"
    must_review:
      - "module:notifications"
      - "file:templates/billing_*.html"
    reason: "料金表示がメールと画面で不一致になった過去事例"
    added_by: "watanabe"
    added_at: "2026-03-15"
```

### 3.3 cpdd/annotations/doc_links.yaml — ドキュメント⇔コードリンク

```yaml
# V字モデルの成果物とコードの対応関係
# Stage 0では手動。Stage 1以降でパーサーが補完

links:
  - requirement: "docs/requirements.md#ユーザー登録"
    design: "docs/basic_design.md#認証モジュール"
    code:
      - "src/services/user_service.py"
      - "src/controllers/auth_controller.py"
    test:
      - "tests/test_user_registration.py"
    config:
      - "config/settings.py#AUTH_BACKEND"
    operation:
      - "docs/runbook.md#ユーザー関連障害対応"

  - requirement: "docs/requirements.md#コース管理"
    design: "docs/basic_design.md#LMSコア"
    code:
      - "src/services/course_service.py"
      - "src/models/course.py"
    test:
      - "tests/test_course_crud.py"
    db:
      - "db_table:courses"
      - "db_table:enrollments"
```

### 3.4 cpdd/annotations/data_dependencies.yaml — データ駆動依存

```yaml
# マスターテーブルの値がビジネスロジックを制御するケース
# コードにはSELECT文しか見えないが、値が変わると挙動が変わる

data_dependencies:
  - table: "course_categories"
    column: "display_order"
    affects:
      - "src/views/course_list.py"     # 表示順序が変わる
      - "src/api/course_api.py"        # APIレスポンスの順序が変わる
    condition: "display_order の値が変わると一覧の並び順が変わる"
    semantic: "behavioral"

  - table: "system_settings"
    column: "max_enrollments"
    affects:
      - "src/services/enrollment_service.py"  # 上限チェックロジック
    condition: "値を増減すると受講可能人数の制限が変わる"
    semantic: "behavioral"
```

### 3.5 cpdd/annotations/overrides.yaml — 上書き・否定証拠

```yaml
# 自動検出の結果を人間が修正する場所
# Evidence Ledgerにnegative evidenceとして記録される

overrides:
  - edge_pattern:
      source: "src/legacy/old_billing.py"
      target: "src/services/billing_service.py"
    action: "suppress"
    reason: "old_billing.pyはdead code。2025年に無効化済みだがまだ削除されていない"
    added_by: "watanabe"
    added_at: "2026-03-15"
```

---

## 4. SQLite スキーマ（graph.db）

```sql
-- ═══════════════════════════════════════
-- CPDD Conditioned Evidence Graph (CEG)
-- ═══════════════════════════════════════

-- ノード
CREATE TABLE nodes (
    id          TEXT PRIMARY KEY,      -- "file:src/services/user_service.py"
    type        TEXT NOT NULL,         -- file, class, method, db_table, config_key,
                                      -- requirement, design, test_case, endpoint, etc.
    path        TEXT,                  -- ファイルパスやドキュメントセクション
    name        TEXT,                  -- 人間可読な名前
    module      TEXT,                  -- 所属モジュール
    created_at  TEXT DEFAULT (datetime('now')),
    updated_at  TEXT DEFAULT (datetime('now'))
);

-- エッジ（依存関係）
CREATE TABLE edges (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    source_id   TEXT NOT NULL,
    target_id   TEXT NOT NULL,
    relation    TEXT NOT NULL,         -- calls, imports, reads_table, writes_table,
                                      -- reads_config, tests, specifies, inherits,
                                      -- implements, triggers, must_review
    semantic    TEXT NOT NULL,         -- structural, resolution, behavioral,
                                      -- validation, governance
    confidence  REAL DEFAULT 0.5,     -- Noisy-OR集約後の信頼度
    condition   TEXT,                  -- JSON: {"env": "prod", "feature_flag": "new_billing"}
    is_active   INTEGER DEFAULT 1,    -- suppressされたら0
    created_at  TEXT DEFAULT (datetime('now')),
    updated_at  TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (source_id) REFERENCES nodes(id),
    FOREIGN KEY (target_id) REFERENCES nodes(id)
);

-- 証拠（Evidence Ledger）
CREATE TABLE evidence (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    edge_id     INTEGER NOT NULL,
    source_type TEXT NOT NULL,         -- static, framework, dynamic, human, history, inferred
    method      TEXT,                  -- "tree-sitter", "actuator", "otel", "manual", "git-cochange"
    detail      TEXT,                  -- 証拠の詳細（JSON or テキスト）
    score       REAL NOT NULL,        -- この証拠単体のスコア (0.0-1.0)
    is_negative INTEGER DEFAULT 0,    -- 否定証拠なら1
    observed_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (edge_id) REFERENCES edges(id)
);

-- Change Atom（変更の正規化）
CREATE TABLE change_atoms (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    commit_hash TEXT,
    node_id     TEXT NOT NULL,
    atom_type   TEXT NOT NULL,         -- signature_change, body_change, config_value_change,
                                      -- schema_add_column, schema_drop_column, test_change,
                                      -- doc_change, dependency_add, dependency_remove,
                                      -- permission_change, data_migration
    description TEXT,
    created_at  TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (node_id) REFERENCES nodes(id)
);

-- インデックス
CREATE INDEX idx_edges_source ON edges(source_id);
CREATE INDEX idx_edges_target ON edges(target_id);
CREATE INDEX idx_edges_relation ON edges(relation);
CREATE INDEX idx_edges_semantic ON edges(semantic);
CREATE INDEX idx_evidence_edge ON evidence(edge_id);
CREATE INDEX idx_change_atoms_node ON change_atoms(node_id);
CREATE INDEX idx_change_atoms_commit ON change_atoms(commit_hash);
```

---

## 5. Stage別の使い方

### Stage 0: 手動注釈のみ（今日から可能）

```
cpdd/
├── cpdd.yaml              # 設定
├── annotations/
│   ├── conventions.yaml   # 暗黙のルールを書き出す
│   ├── doc_links.yaml     # 要件⇔コードのリンクを手動で書く
│   └── data_dependencies.yaml  # データ駆動依存を手動で書く
└── graph.db               # まだ空 or 手動注釈分のみ
```

**できること**: `conventions.yaml`を見て「ここ変えたらここも見ろ」を人間が確認
**価値**: 熟練者の暗黙知を初めて文書化できる

### Stage 1: Phase 1パーサー追加

```
scripts/cpdd/
├── scan.py                # Tree-sitter/ASTでコード解析 → graph.dbに書き込み
├── impact.py              # 変更ファイル → graph.db辿って影響リスト出力
└── annotate.py            # 注釈ヘルパー（対話的にconventions追加）
```

**できること**: コード変更時に自動で影響範囲を出す（Structural依存）
**価値**: grepやIDE検索の上位互換 + 手動注釈の暗黙知

### Stage 2: FW introspection + CI統合

```
scripts/cpdd/
├── scan.py                # + DI/config解析
├── propagate.py           # 伝播エンジン（Change Calculus）
└── hooks/
    └── pre-commit         # git hookでPRごとにimpact report自動生成
```

**できること**: config変更・DI変更の影響も追跡。PRに影響レポートが自動で付く
**価値**: 「この設定変えたらどのbeanが危ないか」が出る

---

## 6. プロジェクトへの導入手順

### 初回導入（5分）

```bash
# 1. cpddディレクトリ作成
mkdir -p cpdd/annotations cpdd/reports

# 2. 設定ファイル作成（テンプレートからコピー）
cp templates/cpdd.yaml cpdd/cpdd.yaml
# → プロジェクト名、言語、ディレクトリを編集

# 3. gitignore追加
echo "cpdd/graph.db" >> cpdd/.gitignore
echo "cpdd/reports/" >> cpdd/.gitignore

# 4. 最初の注釈を書く
# → cpdd/annotations/conventions.yaml に暗黙のルールを1つ書く
# → cpdd/annotations/doc_links.yaml に要件⇔コードのリンクを1つ書く

# 5. コミット
git add cpdd/
git commit -m "feat: add CPDD skeleton for change impact tracking"
```

### Stage 1への移行

```bash
# パーサーを追加（Pythonプロジェクトの場合）
pip install tree-sitter tree-sitter-python

# 初回スキャン
python scripts/cpdd/scan.py

# 影響分析テスト
python scripts/cpdd/impact.py --diff HEAD~1
```

---

## 7. cpdd/.gitignore

```gitignore
# グラフ本体（バイナリ、再生成可能）
graph.db
graph.db-journal
graph.db-wal

# 生成レポート
reports/

# パーサーキャッシュ
__pycache__/
*.pyc
```

**注意**: `annotations/` はgitで追跡する（人間の知識は再生成不可能）。

---

## 8. テンプレート配布

将来的にCPDDをOSS化する際、以下をテンプレートとして配布する:

```
cpdd-template/
├── cpdd.yaml.template
├── annotations/
│   ├── conventions.yaml.template
│   ├── doc_links.yaml.template
│   ├── data_dependencies.yaml.template
│   └── overrides.yaml.template
├── .gitignore
└── README.md
```

`cpdd init` コマンドで自動生成できるようにする。
