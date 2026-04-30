# GPT-5.4 Pro Extended Thinking (Heavy) — V5 Result

> Generated: 2026-03-19
> Prompt: reports/cpdd_gpt54_v5_prompt.md
> Mode: Extended Thinking (Heavy)
> Focus: Pure technical design (no business strategy)

---

### 0. 一枚結論（200字以内）

V5の最重要判断は、CPDDの中心を「1つの巨大なグラフDB」ではなく、「同一フォーマットのメタデータ束」に置くことです。greenfieldもbrownfieldも、`node + edge + resource_usage + term + runtime_observation` に収束させる。追跡はその上で動く別エンジンに分離する。この分離がないと、増分更新も大規模解析も両方で破綻します。

---

## 1. メタデータ仕様の設計

**結論**: CPDDの正体は「コードそのもの」ではなく、「コード・SQL・設定・型階層・用語・実行時証跡を同じID体系で束ねたメタデータ束」です。粒度は原則として**メソッド単位**、補助として**ファイル単位・型単位・テーブル/設定キー単位**にします。行単位はノードにせず、証拠としてだけ持ちます。

### 1.1 メタデータの全体構造

**結論**: 論理フォーマットは `cpdd-bundle/v1` に固定し、物理保存はRDBで持ちます。greenfieldもbrownfieldも、出力は必ず同じです。

まず、交換フォーマットを決めます。

```text
cpdd-bundle/
  manifest.json
  extraction_runs.ndjson
  source_files.ndjson
  nodes.ndjson
  edges.ndjson
  call_sites.ndjson
  call_targets.ndjson
  resource_usages.ndjson
  terms.ndjson
  term_links.ndjson
  runtime_observations.ndjson
```

`manifest.json` の最小形です。

```json
{
  "schema_version": "cpdd-bundle/v1",
  "repo_id": "repo:legacy-001",
  "commit_sha": "abc123...",
  "source_mode": "greenfield",
  "generated_at": "2026-03-18T10:00:00Z",
  "extractors": {
    "java": "tree-sitter+semantic-adapter",
    "sql": "sql-parser",
    "config": "yaml/json/properties/xml"
  }
}
```

この束の中心は5種類です。

1. `node`
   影響範囲の候補そのものです。`file`, `type`, `callable`, `db_table`, `config_key`, `route`, `screen`, `batch_job`, `test_case`, `rule_fragment` などをここに入れます。

2. `edge`
   `calls`, `extends`, `implements`, `overrides`, `contains`, `handles_route`, `covered_by_test` など、汎用の有向関係です。

3. `resource_usage`
   難所1のための専用テーブルです。モジュールが**どのテーブル/設定を、どの列・どの条件で、読む/書くか**を持ちます。ここは `edge` に埋めず、別テーブルにします。理由は、共有テーブルの絞り込み条件まで持たないとノイズが爆発するからです。

4. `term / term_link`
   難所7のための専用テーブルです。自然言語の要求を、コード上の起点へ変換する索引です。

5. `runtime_observation`
   難所5のための専用テーブルです。静的解析で見えない経路を、実行時に補います。

この分離にする理由は、LSPが参照検索・コール階層・型階層を出せても、それだけではテーブル共有や設定依存は表せないからです。また、Tree-sitterは増分構文解析に強く、LSPはIDE向けの参照・コール階層・型階層に強いので、構文と意味を分離したメタデータ層が必要です。

### 1.2 各メタデータ項目の詳細定義

**結論**: 物理スキーマは「汎用ノード/エッジ + 専用テーブル」で作るべきです。全部をproperty graph風の1表に押し込むと、更新も検索も遅くなります。

#### コアテーブル

```sql
CREATE TABLE extraction_run (
  run_id            BIGSERIAL PRIMARY KEY,
  repo_id           TEXT NOT NULL,
  commit_sha        TEXT,
  source_mode       TEXT NOT NULL CHECK (source_mode IN ('greenfield','brownfield')),
  run_kind          TEXT NOT NULL CHECK (run_kind IN ('full','incremental','runtime','enrich')),
  started_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished_at       TIMESTAMPTZ,
  extractor_versions JSONB NOT NULL DEFAULT '{}'
);

CREATE TABLE source_file (
  file_id           BIGSERIAL PRIMARY KEY,
  repo_id           TEXT NOT NULL,
  path              TEXT NOT NULL,
  lang              TEXT NOT NULL,
  content_hash      TEXT NOT NULL,
  size_bytes        BIGINT NOT NULL,
  module_name       TEXT,
  last_run_id       BIGINT REFERENCES extraction_run(run_id),
  UNIQUE(repo_id, path)
);

CREATE TABLE node (
  node_id           BIGSERIAL PRIMARY KEY,
  repo_id           TEXT NOT NULL,
  stable_key        TEXT NOT NULL,
  kind              TEXT NOT NULL,
  lang              TEXT,
  name              TEXT NOT NULL,
  qualified_name    TEXT,
  file_id           BIGINT REFERENCES source_file(file_id),
  parent_node_id    BIGINT REFERENCES node(node_id),
  start_line        INT,
  end_line          INT,
  start_byte        INT,
  end_byte          INT,
  signature         TEXT,
  attrs             JSONB NOT NULL DEFAULT '{}',
  confidence        NUMERIC(4,3) NOT NULL DEFAULT 1.000,
  source_mode       TEXT NOT NULL CHECK (source_mode IN ('greenfield','brownfield')),
  created_run_id    BIGINT NOT NULL REFERENCES extraction_run(run_id),
  updated_run_id    BIGINT NOT NULL REFERENCES extraction_run(run_id),
  is_deleted        BOOLEAN NOT NULL DEFAULT FALSE,
  UNIQUE(repo_id, stable_key)
);

CREATE TABLE edge (
  edge_id           BIGSERIAL PRIMARY KEY,
  repo_id           TEXT NOT NULL,
  from_node_id      BIGINT NOT NULL REFERENCES node(node_id),
  to_node_id        BIGINT NOT NULL REFERENCES node(node_id),
  edge_type         TEXT NOT NULL,
  evidence_kind     TEXT NOT NULL, -- ast, semantic, sql, config, trace, llm
  evidence          JSONB NOT NULL DEFAULT '{}',
  confidence        NUMERIC(4,3) NOT NULL,
  attrs             JSONB NOT NULL DEFAULT '{}',
  created_run_id    BIGINT NOT NULL REFERENCES extraction_run(run_id),
  is_deleted        BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_node_repo_kind      ON node(repo_id, kind);
CREATE INDEX idx_node_repo_qname     ON node(repo_id, qualified_name);
CREATE INDEX idx_edge_from_type      ON edge(repo_id, from_node_id, edge_type);
CREATE INDEX idx_edge_to_type        ON edge(repo_id, to_node_id, edge_type);
CREATE INDEX idx_edge_repo_type      ON edge(repo_id, edge_type);
```

#### 呼び出しと型解決の専用テーブル

```sql
CREATE TABLE call_site (
  call_site_id            BIGSERIAL PRIMARY KEY,
  repo_id                 TEXT NOT NULL,
  caller_node_id          BIGINT NOT NULL REFERENCES node(node_id),
  file_id                 BIGINT NOT NULL REFERENCES source_file(file_id),
  start_line              INT NOT NULL,
  end_line                INT NOT NULL,
  dispatch_kind           TEXT NOT NULL, -- direct, static, virtual, interface, super, reflection
  method_name             TEXT NOT NULL,
  arity                   SMALLINT,
  receiver_static_type_id BIGINT REFERENCES node(node_id),
  target_hint             TEXT,
  attrs                   JSONB NOT NULL DEFAULT '{}',
  created_run_id          BIGINT NOT NULL REFERENCES extraction_run(run_id)
);

CREATE TABLE call_target (
  call_site_id            BIGINT NOT NULL REFERENCES call_site(call_site_id),
  callee_node_id          BIGINT NOT NULL REFERENCES node(node_id),
  resolution_kind         TEXT NOT NULL, -- exact, import, same_type, override, hierarchy, heuristic
  confidence              NUMERIC(4,3) NOT NULL,
  PRIMARY KEY (call_site_id, callee_node_id)
);
```

#### 難所1向けの専用テーブル

```sql
CREATE TABLE resource_usage (
  usage_id                BIGSERIAL PRIMARY KEY,
  repo_id                 TEXT NOT NULL,
  owner_node_id           BIGINT NOT NULL REFERENCES node(node_id), -- callable / batch_job / route handler
  resource_node_id        BIGINT NOT NULL REFERENCES node(node_id), -- db_table / config_key / env_var / db_routine
  access_kind             TEXT NOT NULL, -- read, write, read_write, call
  columns_read            TEXT[] NOT NULL DEFAULT '{}',
  columns_written         TEXT[] NOT NULL DEFAULT '{}',
  predicate_columns       TEXT[] NOT NULL DEFAULT '{}',
  predicate_literals      TEXT[] NOT NULL DEFAULT '{}',
  join_resources          TEXT[] NOT NULL DEFAULT '{}',
  selector_hash           TEXT,
  sql_fingerprint         TEXT,
  evidence                JSONB NOT NULL DEFAULT '{}',
  confidence              NUMERIC(4,3) NOT NULL,
  created_run_id          BIGINT NOT NULL REFERENCES extraction_run(run_id)
);

CREATE INDEX idx_ru_owner            ON resource_usage(repo_id, owner_node_id);
CREATE INDEX idx_ru_resource         ON resource_usage(repo_id, resource_node_id);
CREATE INDEX idx_ru_resource_access  ON resource_usage(repo_id, resource_node_id, access_kind);
```

#### 難所7向けの専用テーブル

```sql
CREATE TABLE term (
  term_id                 BIGSERIAL PRIMARY KEY,
  repo_id                 TEXT NOT NULL,
  normalized_term         TEXT NOT NULL,
  term_type               TEXT NOT NULL, -- business, screen_label, route, error_code, identifier, table_name, config_key
  lang                    TEXT NOT NULL DEFAULT 'ja',
  synonyms                TEXT[] NOT NULL DEFAULT '{}',
  weight                  NUMERIC(4,3) NOT NULL DEFAULT 1.000,
  UNIQUE(repo_id, normalized_term, term_type, lang)
);

CREATE TABLE term_link (
  term_id                 BIGINT NOT NULL REFERENCES term(term_id),
  node_id                 BIGINT NOT NULL REFERENCES node(node_id),
  channel                 TEXT NOT NULL, -- identifier, string_literal, ui_label, error_code, route, sql_alias, comment
  evidence                JSONB NOT NULL DEFAULT '{}',
  weight                  NUMERIC(4,3) NOT NULL,
  PRIMARY KEY (term_id, node_id, channel)
);
```

#### 動的解析の専用テーブル

```sql
CREATE TABLE runtime_observation (
  obs_id                  BIGSERIAL PRIMARY KEY,
  repo_id                 TEXT NOT NULL,
  from_node_id            BIGINT REFERENCES node(node_id),
  to_node_id              BIGINT REFERENCES node(node_id),
  resource_node_id        BIGINT REFERENCES node(node_id),
  obs_kind                TEXT NOT NULL, -- span_next, jdbc_query, http_call, message_publish, message_consume, test_cover
  sample_count            BIGINT NOT NULL DEFAULT 1,
  first_seen_at           TIMESTAMPTZ,
  last_seen_at            TIMESTAMPTZ,
  attrs                   JSONB NOT NULL DEFAULT '{}',
  confidence              NUMERIC(4,3) NOT NULL,
  created_run_id          BIGINT NOT NULL REFERENCES extraction_run(run_id)
);
```

粒度はこう固定します。

* 変更候補の主粒度: `callable`
* 人が最終的に見る粒度: `file`
* 間接依存の主粒度: `db_table`, `config_key`, 必要なら列
* 型階層の主粒度: `type`, `call_site`, `call_target`
* 行番号: ノードではなく `evidence` と `start_line/end_line`

行単位ノードをやらない理由は、数千万STEPではID数が大きすぎるのと、行移動でIDが壊れやすいからです。影響範囲調査では「どのメソッド」「どのファイル」「どのテーブル/設定」が分かれば、最初の実務判断には足ります。

### 1.3 難所1（マスター/設定を媒介した間接依存）を解くために必要なメタデータ

**結論**: テーブル名だけでは足りません。**どの列を、どの条件で読んだ/書いたか**まで持つ必要があります。これがないと、「同じマスターを見ているだけ」のノイズが多すぎます。

保持すべき項目は `resource_usage` の5点です。

1. `access_kind`
   `read` と `write` を分けます。影響は `write -> read` が最も強いです。

2. `columns_read / columns_written`
   同じテーブルでも列が違えば影響の強さは変わります。

3. `predicate_columns / predicate_literals`
   たとえば `master_type='OUTPATIENT'` を見ているモジュールと、`master_type='INPATIENT'` を見ているモジュールは、同じテーブルでも別扱いに近いです。

4. `join_resources`
   依存が join で伝播するケースを拾うためです。

5. `selector_hash`
   条件の正規化済みハッシュです。重複排除と高速照合に使います。

共有資源の重なりは、単純一致ではなく重なり率で見ます。

```python
def selector_overlap(a, b):
    col_score = jaccard(a.predicate_columns, b.predicate_columns)
    lit_score = jaccard(a.predicate_literals, b.predicate_literals)
    rw_bonus  = 1.0 if a.access_kind == "write" or b.access_kind == "write" else 0.7
    return (0.5 * col_score + 0.3 * lit_score + 0.2 * rw_bonus)
```

判定は初期値として、以下にします。

* `overlap >= 0.75` かつ片方が `write`: 高確度
* `0.45 <= overlap < 0.75`: 中確度
* `overlap < 0.45`: 低確度

設定ファイルも同じです。`config_key` は**完全一致**、`prefix` 一致、`enum value` 一致の3段で追います。たとえば `billing.rate.outpatient` を変えるなら、`billing.rate.*` を使うモジュールも候補に入れます。

### 1.4 難所4（継承・オーバーライド）を解くために必要なメタデータ

**結論**: `method A calls method B` の1本線では不十分です。**呼び出し地点**と**候補ターゲット**を分けて持つ必要があります。

必要なのは4つです。

1. `type` ノードと `extends / implements` エッジ
   型階層の土台です。

2. `call_site`
   `どこで呼ばれたか` を保持します。これがないと、呼び出しが direct なのか virtual なのか区別できません。

3. `call_target`
   1つの `call_site` に対して、候補ターゲットを複数持てるようにします。

4. `overrides` エッジ
   基底メソッドと実装メソッドを結びます。

実際の追跡では、次の順で候補を広げます。

```python
def resolve_dispatch(call_site):
    if call_site.dispatch_kind in ("direct", "static", "super"):
        return exact_targets(call_site)
    targets = targets_from_type_hierarchy(call_site.receiver_static_type_id,
                                          call_site.method_name,
                                          call_site.arity)
    return rank_targets(targets)  # 実装型に近い順、確度付き
```

LSPはコール階層と型階層を返せるので、IDE側の補助には使えます。ただし、レポジトリ全体のオフライン索引をLSP問合せの繰り返しで作るのは遅いです。LSPは補助、主役はバッチ抽出です。

### 1.5 難所7（変更要求→調査起点の変換）を解くために必要なメタデータ

**結論**: 自然言語から直接コードへ飛ばすのではなく、**用語索引**と**画面/経路/エラー/バッチの表面情報**を中継点にします。

必要なのは次の4層です。

1. `term`
   業務用語、画面ラベル、エラーコード、識別子分割語、テーブル名、設定キー名を正規化して持ちます。

2. `term_link`
   用語がどのノードに出てくるかを持ちます。

3. `route / screen / batch_job / rule_fragment` ノード
   人の要求文に近い表面層です。
   例: `月次請求`, `請求画面`, `ERR-1023`, `POST /claims/monthly`

4. `channel weight`
   どの根拠で結びついたかに重みを付けます。

初期重みはこうします。

* `ui_label`, `route`, `error_code`: 1.00
* `batch_job`, `sql_alias`, `table_name`: 0.85
* `identifier`: 0.70
* `string_literal`: 0.60
* `comment`: 0.40

さらに `rule_fragment` を置きます。これは `if`, `switch`, SQL `WHERE`, 設定キー参照などから作る小さなルール断片です。
例: `複数契約なら合算`, `月次請求時のみ`, `診療区分=外来`

これで「月次請求で複数契約の顧客の計算がおかしい」という要求が、`batch_job -> rule_fragment -> callable -> db_table` に落ちやすくなります。

### 1.6 メタデータのストレージ設計（RDBMS? Graph DB? ファイル? 規模による選択基準）

**結論**: デフォルトは **PostgreSQL**、ローカル試作は **SQLite**、必要になった時だけ **Neo4j を読取り系で追加**です。最初からGraph DBにしない方がよいです。

選び分けはこうします。

* **SQLite**
  単一ユーザー、`<= 200万 edge`、試作専用。
  理由はセットアップが最小だからです。

* **PostgreSQL**
  本命です。`node/edge` と `resource_usage/term` を同居でき、普通のSQL結合と再帰問い合わせが使えます。

* **Neo4j**
  `> 5000万 edge` で、複数人が探索型の経路問合せを頻繁に叩く時だけです。Cypherは可変長パスをそのまま書けますが、運用系を増やすコストがあります。

重要なのは、**熱い検索はアプリ側の探索**にすることです。PostgreSQLの再帰CTEは便利ですが、毎回それだけで本番探索を回す設計にはしません。
保存はPostgreSQL、探索はアプリの優先度付き探索、管理用の診断クエリだけSQL、という役割分担にします。

**検証**: 最も破綻しやすいのは、巨大な共有マスターテーブルに `resource_usage` が集中し、候補が雪崩れるケースです。その場合の回避策は、`selector_hash` と `predicate_literals` を必須化し、共有テーブルの単純一致を禁止することです。

---

## 2. greenfield時のメタデータ自動生成

**結論**: greenfieldでは、保存タイミングを1つにせず、**保存時の軽量更新 / CIの確定更新 / 夜間の重い補完**の3段に分けるべきです。リアルタイムで全部やる設計は重すぎます。

### 2.1 どのタイミングで生成するか

**結論**: `保存時に軽量更新、CIで正式反映、夜間で重い補完` にします。

3段に分けます。

1. **保存時**

   * 変更ファイルだけTree-sitterで再解析
   * `node`, `edge(contains/callsの一部)`, `resource_usage` の差分をローカルに更新
   * 目標 1〜3秒以内

2. **CI/ビルド時**

   * 依存解決後の確定抽出
   * 型階層、候補ターゲット、設定/SQL、テスト対応を正式反映
   * これを「正」とする

3. **夜間**

   * `rule_fragment` 抽出
   * 用語正規化
   * 低頻度の重い解析
   * LLM補完

Tree-sitterは増分パースができ、構文エラーがあっても有用な木を返せます。LSPには `didChange`、参照、コール階層、型階層の仕組みがあります。だから、保存時の軽量処理とIDE補助は相性がよいです。

### 2.2 どのツール/技術で生成するか

**結論**: 構文はTree-sitter、意味解決は言語アダプタ、ルール抽出はLLM、動的証跡はOpenTelemetryとテストカバレッジです。LLMを構文解析に使ってはいけません。

役割分担を固定します。

* **Tree-sitter**

  * ファイル分類
  * 構文木
  * シンボル位置
  * 変更差分の局所化

* **言語アダプタ**

  * FQN解決
  * import解決
  * 型階層
  * コール候補

* **SQL/設定パーサ**

  * SQL AST
  * 設定キー列挙
  * XML/YAML/JSON/properties のキー列挙

* **LLM**

  * `rule_fragment`
  * `term` 正規化
  * 自然言語要求のアンカー候補作成
  * 説明文の整形

* **OpenTelemetry / coverage**

  * 実行時経路
  * DB呼び出し
  * テストごとの通過行・通過メソッド

### 2.3 開発者に追加負担をかけない設計

**結論**: 開発者に新しい記法を覚えさせないことが前提です。入力を増やすと必ず陳腐化します。

必須ルールは2つだけにします。

* コード、SQL、設定を通常通り書く
* CIを通す

任意の補助としてだけ、次を許します。

```text
.cpdd/
  aliases.yml     # 業務用語の別名
  ignore.yml      # 解析除外
  ownership.yml   # 画面/バッチの所有境界
```

しかし、これらは**なくても動く**前提にします。

### 2.4 コード変更時のメタデータ増分更新の仕組み

**結論**: 増分更新は、`ファイルハッシュ -> シンボルハッシュ -> 逆参照の再解決` の順でやります。全件再計算を毎回やる設計は成立しません。

更新アルゴリズムです。

```python
def incremental_sync(changed_files):
    for f in changed_files:
        ast = parse_file(f)
        new_file_hash = hash_file(ast)
        if new_file_hash == stored_hash(f):
            continue

        old_symbols = load_symbols(f)
        new_symbols = extract_symbols(ast)

        deleted = old_symbols - new_symbols
        inserted = new_symbols - old_symbols
        common   = old_symbols & new_symbols

        tombstone_nodes_edges(deleted)
        upsert_nodes_edges(inserted)
        update_changed_symbols(common)

        impacted_callers = reverse_lookup_callers(old_symbols | new_symbols)
        re_resolve_call_targets(impacted_callers)

        impacted_resources = reverse_lookup_resource_dependents(old_symbols | new_symbols)
        refresh_resource_usage(impacted_resources)
```

実装上の要点は3つです。

1. `stable_key` をIDの基準にする
   行番号ではなく、`qualified_name + signature` で同一性を取ります。

2. 古い行は物理削除せず `is_deleted` にする
   差分比較とロールバックのためです。

3. 逆参照インデックスを持つ
   呼ばれる側が変わった時、呼ぶ側の候補再解決が必要だからです。

### 2.5 具体的な実装アーキテクチャ（CLI? CI/CDパイプライン? IDE plugin?）

**結論**: 最初は **CLI + CI/CD** に固定します。IDE plugin は後回しです。

最小構成はこれです。

```text
repo
 ├─ cpdd.yaml
 ├─ .cpdd-cache/           # ローカル差分キャッシュ
 └─ CI
    └─ cpdd index --full
```

コンポーネントはこうします。

```text
[editor save]
   ↓
cpdd sync --changed
   ↓
local sqlite cache

[push / merge]
   ↓
CI job: cpdd index --full --publish
   ↓
PostgreSQL metadata store

[nightly]
   ↓
cpdd enrich --rules --terms --runtime
   ↓
PostgreSQL metadata store
```

**検証**: 最も破綻しやすいのは、保存時更新が遅くなり、開発者がオフにするケースです。その場合の回避策は、保存時はTree-sitterの構文差分だけに絞り、型解決とLLM補完をCIへ追い出すことです。

---

## 3. brownfield時のリバースエンジニアリング

**結論**: brownfieldでは、最初から完全意味解析を狙わず、**二段抽出**にします。第1段で高速に広く拾い、第2段でコンパイル可能な所だけ深く解きます。これなら数千万STEPでも現実的です。

> 以下の時間・精度は実測値ではなく、設計目標です。

### 3.1 数千万STEPのコードに対して現実的な時間で解析する方法

**結論**: 初回は**バッチ並列の全面スキャン**、2回目以降は**差分スキャン**です。初回に数時間かかるのは許容し、問い合わせ時は秒〜十数秒に寄せます。

パイプラインは6段です。

1. ファイル発見と分類
2. Tree-sitterで構文抽出
3. シンボル表作成
4. 呼び出し/型階層の解決
5. SQL/設定/環境変数/外部連携の抽出
6. term と rule の補完

設計目標は次です。

* 10M LOC: 初回 4〜10時間
* 30M LOC: 初回 12〜36時間
* 差分 1000ファイル: 5〜30分
* 問い合わせ: 5〜30秒

### 3.2 言語混在（Java + SQL + シェル + 設定ファイル + 画面定義）への対応

**結論**: 言語ごとに別アダプタで抽出し、出力だけ共通スキーマに合わせます。1つの万能パーサは作りません。

アダプタはこの単位で分けます。

* `java` / `csharp` / `typescript`
* `sql`
* `bash`
* `yaml/json/xml/properties`
* `html/jsp/template`
* `shell launcher / batch descriptor`

### 3.3 call graph自動生成の技術的手法と精度

**結論**: コールグラフは**二段階**で作ります。まず direct call を確定し、その後で継承・実装・抽象型から候補を広げます。

初期の確度はこう置きます。

* `exact/direct/static/super`: 0.95
* `same_type/import`: 0.90
* `override/hierarchy`: 0.75
* `heuristic/reflection string`: 0.40

### 3.4 data access map（テーブル×モジュールのマトリクス）自動生成の技術的手法

**結論**: data access map は「テーブル名一覧」ではなく、**`owner -> resource_usage -> table/config/env`** の三層で作ります。

#### SQL文の解析

* **直書きSQL**
  文字列リテラル、`.sql` ファイル、アノテーション内SQLを抽出し、SQL ASTに変換
* **ORM経由**
  まず `@Query`, mapper XML, repository method を優先対応
* **動的SQL**
  固定部分だけ抽出し、未解決部分を `wildcard` として保持
* **ストアドプロシージャ**
  `db_routine` ノードを作り、呼び出しは `call` として持つ。本文が手に入るなら別途解析

#### 取り出す項目

* table name
* view name
* columns read/write
* predicate columns
* literal values
* join targets
* SQL fingerprint

#### 設定ファイルの参照解析

* properties / yaml / json / xml のキー列挙
* `${ENV_VAR}` 形式の環境変数参照
* キー prefix の抽出

#### 外部連携

* HTTP client 呼出し先
* メッセージ publish/consume
* shell からのJava main起動
* DB migration / batch launch

この時点では pairwise の「モジュールAとBは同じテーブルを使う」エッジは作りません。
それを事前に全部作ると、ホットテーブルで O(n²) に膨れます。
代わりに、問い合わせ時に `resource_usage` を資源ごとに突き合わせます。

### 3.5 型階層（継承・オーバーライド）の自動解析

**結論**: 型階層は `type` ノードと `extends/implements/overrides` だけで十分です。重要なのは、**呼び出し地点に紐づく候補ターゲット**を持つことです。

### 3.6 設計書が陳腐化している前提での解析戦略（コードのみから抽出）

**結論**: 設計書は**入力にしません**。使うとしても、用語補助の低確度ソースだけです。

禁止ルールも固定します。

* 設計書だけで `edge` を作らない
* 設計書でコード由来の `edge` を消さない
* 設計書の記載を優先して exact 判定しない

### 3.7 解析精度の限界と、それを補完する方法

**結論**: 静的解析だけで解けない所は残ります。そこは**OpenTelemetryの実行時証跡**と**テストごとの通過情報**で補完します。

限界が出る場所は次です。

* reflection
* DIによる実装差し替え
* Criteria API / Query builder
* 非同期メッセージ
* タイミング依存
* 実行順序依存

補完方針はこうです。

* 静的で見えた経路 → 高確度
* 動的でしか見えない経路 → 中確度以下
* 静的と動的の両方で見えた経路 → 高確度へ格上げ

**検証**: 最も破綻しやすいのは、brownfieldのビルドが壊れていて意味解決ができないケースです。その場合の回避策は、構文ベースの抽出を先に通し、コンパイル可能なサブモジュールだけ深掘りすることです。

---

## 4. 影響範囲追跡エンジンの設計

**結論**: 追跡エンジンは、単純な深さ優先ではなく、**優先度付きの多点探索**にします。起点を複数取り、`calls + shared resource + override` を同時にたどり、経路ごとに確度を下げながら上位候補だけを返します。

### 4.1 追跡アルゴリズムの詳細設計

**結論**: 追跡は3段です。`要求文 -> 起点候補 -> 実装候補 -> 影響候補` の順で進めます。

#### Phase A: 起点候補の決定

```python
def resolve_start_nodes(request_text):
    terms = extract_terms(request_text)  # LLM + 正規化
    candidates = search_term_links(terms)  # term / route / screen / batch / error / rule
    return rerank_anchor_candidates(request_text, candidates)[:5]
```

#### Phase B: 表面起点から実装起点へ

```python
ANCHOR_EDGE_TYPES = {
    "handles_route", "renders_screen", "contains", "calls",
    "reads_table", "writes_table", "reads_config", "maps_rule"
}

def expand_to_impl(anchor_nodes):
    return bounded_walk(anchor_nodes,
                        edge_types=ANCHOR_EDGE_TYPES,
                        max_depth=3,
                        min_score=0.35)
```

#### Phase C: 実装起点から影響候補へ

```python
EDGE_WEIGHT = {
    "calls_exact": 0.95,
    "calls_hierarchy": 0.75,
    "overrides": 0.90,
    "extends": 0.80,
    "shared_resource_strong": 0.88,
    "shared_resource_weak": 0.55,
    "reads_config_exact": 0.90,
    "runtime_observed": 0.70,
    "covered_by_test": 0.85
}

def depth_penalty(depth):
    return 1.0 if depth <= 2 else (0.93 ** (depth - 2))

def track_impact(impl_nodes):
    pq = MaxHeap()
    best = {}     # node_id -> best_score
    paths = {}    # node_id -> best_path

    for n in impl_nodes:
        pq.push((1.0, 0, n, []))

    while pq:
        score, depth, node, path = pq.pop()
        if score < 0.18:
            continue
        if depth > 8:
            continue
        if best.get(node.id, 0) >= score:
            continue

        best[node.id] = score
        paths[node.id] = path

        for edge in structural_neighbors(node):
            next_score = score * edge.weight * depth_penalty(depth + 1)
            pq.push((next_score, depth + 1, edge.to_node, path + [edge]))

        for usage in usages_by_owner(node):
            for other in owners_sharing_resource(usage):
                overlap = selector_overlap(usage, other)
                if overlap < 0.35:
                    continue
                base = 0.88 if (usage.is_write or other.is_write) and overlap >= 0.75 else 0.55
                next_score = score * base * overlap * depth_penalty(depth + 1)
                pq.push((next_score, depth + 1, other.owner_node, path + [shared_resource_edge(usage, other)]))

    return rank_candidates(best, paths)
```

### 4.2 追跡の深さ制限と確度判定

確度バケットは次です。

* **確実に影響する** (high)
  * score >= 0.75, depth <= 3, heuristic edge なし

* **たぶん影響する** (medium)
  * 0.45 <= score < 0.75, or depth 4〜6, or heuristic edge 1本

* **影響するかもしれない** (low)
  * 0.18 <= score < 0.45, or reflection/dynamic SQL/runtime-only含む

### 4.3 変更要求（自然言語）→ 調査起点への変換

LLM入出力はJSON固定にします。

```json
{
  "request": "月次請求で複数契約の顧客の計算がおかしい",
  "candidate_evidence": [
    {
      "node_id": 101,
      "kind": "batch_job",
      "name": "MonthlyBillingJob",
      "matched_terms": ["月次請求"],
      "channels": ["identifier", "string_literal"]
    }
  ],
  "output_schema": {
    "anchors": [{"node_id": "int", "score": "0-1", "reason": "string"}]
  }
}
```

### 4.4 出力フォーマット

**変更候補・確認候補・テスト候補**の3区分で返します。

CLI表示はこうします。

```text
[HIGH] BillingService#calculateMonthly  score=0.88
  file: src/main/java/com/acme/billing/BillingService.java
  why : MonthlyBillingJob -> BillingController -> BillingService#calculateMonthly

[MED] ContractAggregateService#merge  score=0.61
  why : shared table(contract_master, overlap=0.78, write->read)
```

### 4.5 数千万STEPのコードベースでの性能要件

設計目標です。

* anchor search: 1〜3秒
* implementation expansion: 1〜5秒
* impact traversal: 3〜15秒
* explanation rendering: 1〜5秒
* total: 5〜20秒、重いケースで60秒上限

**検証**: 最も破綻しやすいのは、同じテーブルを数百モジュールが読むケースです。その場合の回避策は、`predicate_literals` の一致を必須にするか、共有テーブル探索を `write` 起点に限定することです。

---

## 5. 難所への個別解法

**結論**: 各難所は別々に見えますが、実装上は3つに集約できます。`shared resource`, `type-aware call`, `runtime observation` です。これに `request mapping` を前置きすれば全体がつながります。

### 5.1 マスター/設定を媒介した間接依存（難所1）
解法は `resource_usage` の強化。テーブル名一致ではなく条件付き共有で追う。

### 5.2 設計書の陳腐化（難所2）
設計書を真実源にしない。コードだけから抽出し、設計書は検索語補助に落とす。

### 5.3 人によって書き方が違う/言語混在（難所3）
命名規則に依存しない抽出。構文と資源アクセスで見る。

### 5.4 継承・オーバーライド（難所4）
`call_site` と `call_target` を分けて持つ。

### 5.5 動かさないと分からない問題（難所5）
静的を土台にしつつ、実行時証跡を別レイヤーで重ねる。

### 5.6 「まさかここに影響するとは」（難所6）
shared resource と reverse call の組み合わせで拾う。

### 5.7 変更要求→調査起点の変換（難所7）
term index と表面ノードを中継にする。LLMは起点候補作成のみ。

---

## 6. 技術スタックの選定

**結論**: 最初の選定は、**Tree-sitter + PostgreSQL + Python + 必要最小限のLLM**です。

### 6.1 構文解析: Tree-sitter（標準入口）、言語固有パーサー（深掘り）、LSP（補助）

### 6.2 グラフ管理: PostgreSQL + edge table（本番）、SQLite（試作）、Neo4j（条件付き後追加）

### 6.3 LLM活用: 意味の橋渡しだけ。構文・型・呼び出し解決には使わない。

### 6.4 実装言語: Python。副業時間で最短。

### 6.5 最小構成（プロトタイプ）と本番構成の違い: 保存先、解析対象、動的証跡。

---

## 7. プロトタイプの実装計画

**結論**: 4月中に作る最小プロトタイプは、**Java 1言語、call graph + data access map、CLIのみ**に絞るべきです。

### 7.1 スコープ

含める: `.java`, SQL文字列, `.sql`, `.properties/.yaml`, file/type/callable/db_table/config_key/term, calls/resource_usage/term_link, CLI query/explain

含めない: GUI, IDE plugin, overrideの完全解決, Spring DI深い解決, MyBatis/JPA Criteria, shell/XML画面, OpenTelemetry, test mapping

### 7.2 対象言語: Java

### 7.3 最小限のメタデータ項目

7テーブル: extraction_run, source_file, node, edge, resource_usage, term, term_link

### 7.4 最小限の追跡ロジック

`calls` と `shared resource` だけ。

### 7.5 CLI設計

4コマンド: `index`, `query`, `explain`, `dump`

```bash
cpdd index --repo /work/legacy --lang java --db sqlite:///cpdd.db
cpdd query --db sqlite:///cpdd.db --request "月次請求で..." --top-k 20 --format table
cpdd explain --db sqlite:///cpdd.db --node "java-callable:..." --max-depth 4
cpdd dump --db sqlite:///cpdd.db --out ./cpdd-bundle
```

### 7.6 実装手順

1. SQLite schema → 2. Java file crawler → 3. Tree-sitter Java parser → 4. file/type/callable 抽出 → 5. direct calls 抽出 → 6. SQL文字列抽出とdb_table登録 → 7. config key 抽出 → 8. resource_usage 生成 → 9. traversal engine → 10. simple term index → 11. query/explain → 12. LLM rerank は最後

```text
cpdd-proto/
  pyproject.toml
  cpdd/
    cli.py
    config.py
    model/
      schema.sql
      ids.py
    parsers/
      java_ast.py
      sql_extract.py
      config_extract.py
    indexer/
      crawl.py
      symbols.py
      calls.py
      resources.py
      terms.py
    engine/
      anchor.py
      traverse.py
      score.py
      explain.py
    storage/
      sqlite_store.py
    llm/
      request_mapper.py
  tests/
  samples/
```

### 7.7 想定工数

**4〜5週間、28〜40時間** が目安。

* schema + storage: 4〜6時間
* Java抽出: 8〜10時間
* call抽出: 4〜6時間
* SQL/config抽出: 5〜8時間
* traversal + explain: 5〜7時間
* CLI + tests: 4〜6時間
* LLM rerank: 2〜4時間

---

## 8. レッドチーム

主な技術リスク5つ:

1. **共有マスターテーブル爆発**: 対策は `predicate_literals` と `write->read` 必須化
2. **動的SQL / ORM / reflection**: low confidenceで残し、後でruntime併用
3. **多義語の要求文**: route/screen/batch/errorを優先、identifier単独を下げる
4. **ビルド不能brownfield**: syntax-onlyモードとconfidence降格
5. **ストレージ肥大**: pairwise shared edgeを事前生成しない

最も厳しいシナリオ: 巨大共有テーブル + 動的SQL + 曖昧な日本語要求が同時。回避策: 自然言語起点を諦め、table/config明示アンカーからのCLIを先に用意。

---

## 9. 最終提言

最初に作るべきもの3つ:
1. **`cpdd-bundle/v1` のスキーマとSQLite保存層**
2. **Java向け抽出器** (file/type/callable, direct call, SQL table, config key)
3. **`calls + shared resource` の追跡エンジン**

作るべきでないもの3つ:
1. **GUI / IDE plugin**
2. **最初からNeo4j移行**
3. **継承・reflection・ORM・runtimeを一気に全部**

---

## 最終検証

### 1. 統一性検証
greenfield/brownfield出力フォーマットは論理的に同一。差異は `source_mode`, `evidence_kind`, `confidence` に閉じ込め。

### 2. スケーラビリティ検証
初回メタデータ生成は数時間〜1日、追跡は数秒〜数十秒。毎回全面再解析しないことが前提。

### 3. プロトタイプ検証
4月プロトタイプの役割は「CPDDの核心である call graph + data access map の統合追跡が成立するか」を確かめること。通れば継承と動的証跡を足す、通らなければ設計を縮める。
