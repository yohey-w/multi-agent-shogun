---
name: figma-frame-deep-linker
description: |
  Make sure to use this skill whenever the user asks for Figma deep links, frame search, or embedding Figma design references in documents (「Figmaリンクを埋め込む」「Figmaディープリンク」「Figmaフレーム検索」「FigmaのURL取得」「仕様書にFigmaリンク」).

  Figma REST APIでフレーム/セクションをキーワード検索し、ディープリンクURL(node-id形式)を生成する。仕様書へのリンク埋め込みに使用。

  Key capabilities: (1) GET /v1/filesでフレーム構造取得 (2) SECTION/FRAME/COMPONENTをキーワード部分一致+OR検索 (3) node-idコロン→ハイフン変換でURL生成 (4) Markdownリンク形式出力 (5) 複数キーワードを1API呼び出しで処理
version: 1.0.0
---

# Figma Frame Deep Linker

Figma REST APIを使用してデザインファイル内のフレーム/セクションを検索し、キーワードに一致するノードのディープリンクURLを生成するスキル。仕様書の「参考」セクションにFigmaリンクを挿入する際に使用する。

## Overview

このスキルは以下を実行する:

1. Figma REST API（GET /v1/files/{file_key}）でファイル構造を取得
2. フレーム名をキーワードで検索（部分一致）
3. 一致したフレームのディープリンクURLを生成
4. 仕様書に挿入可能なMarkdownリンクとして出力

## When This Skill Applies

このスキルは以下の場合に適用される:
- 仕様書にFigmaデザインへのリンクを埋め込む必要がある時
- 特定の画面デザインがFigmaのどのフレームに該当するかを調べたい時
- Figmaファイル内のフレーム構造を一覧化したい時

## 入力パラメータ

| パラメータ | 必須 | 説明 | 例 |
|-----------|------|------|-----|
| `file_key` | Yes | FigmaファイルのキーID | `abCy1tq5spM0jeXbhLemu6` |
| `access_token` | Yes | Figma Personal Access Token | `figd_XXXX...` |
| `keywords` | Yes | 検索キーワード（カンマ区切りで複数可） | `いいね,検索,ランダム` |
| `--depth` | No | フレーム階層の取得深度（デフォルト: 2） | `3` |
| `--page` | No | 検索対象ページ名（デフォルト: 全ページ） | `design` |

## 処理フロー

### Step 1: Figma API呼び出し

Figma REST APIでファイル構造を取得する。

```bash
curl -s -H "X-Figma-Token: {access_token}" \
  "https://api.figma.com/v1/files/{file_key}?depth={depth}"
```

**レスポンス構造:**

```json
{
  "name": "250425_Nash App Design_",
  "document": {
    "children": [
      {
        "id": "0:1",
        "name": "design",
        "type": "CANVAS",
        "children": [
          {
            "id": "2427:44475",
            "name": "いいねしたコンテンツ詳細（トラック）",
            "type": "SECTION",
            "children": [...]
          }
        ]
      }
    ]
  }
}
```

### Step 2: フレーム/セクション検索

レスポンスのノードツリーを再帰的に走査し、以下の条件でフィルタする:

**検索対象ノードタイプ:**
- `SECTION`: セクション（大分類）
- `FRAME`: フレーム（画面単位）
- `COMPONENT`: コンポーネント
- `COMPONENT_SET`: コンポーネントセット

**検索ロジック:**
1. 各ノードの`name`フィールドに対してキーワードの部分一致検索を行う
2. 大文字/小文字を区別しない（日本語はそのまま比較）
3. 複数キーワード指定時はOR検索（いずれかに一致すれば結果に含む）
4. `--page`指定時は該当ページ（CANVAS）配下のみ検索

**走査アルゴリズム:**

```
function searchNodes(node, keywords, results):
  if node.type in [SECTION, FRAME, COMPONENT, COMPONENT_SET]:
    for keyword in keywords:
      if keyword in node.name (case-insensitive):
        results.append({
          id: node.id,
          name: node.name,
          type: node.type,
          page: parentCanvasName
        })
        break  # 1ノードは1回だけマッチ
  if node.children:
    for child in node.children:
      searchNodes(child, keywords, results)
```

### Step 3: ディープリンク生成

一致したノードのディープリンクURLを生成する。

**URL形式:**

```
https://www.figma.com/design/{file_key}/{file_name}?node-id={node_id_escaped}
```

**node-idの変換ルール:**
- Figma APIのノードID: `2427:44475`（コロン区切り）
- URL内のnode-id: `2427-44475`（ハイフン区切り）
- 変換: `:` → `-`

**file_name:**
- ファイル名はAPIレスポンスの`name`フィールドから取得
- URLエンコードする（スペース→`+`、日本語→`%XX`）
- ただし、file_nameがなくてもnode-idがあればFigmaは正しいフレームにナビゲートする

### Step 4: 結果出力

検索結果をMarkdownテーブルとリンク一覧で出力する。

**一覧出力:**

```markdown
## Figma Frame Search Results

Keywords: いいね, 検索

| # | Page | Type | Frame Name | Deep Link |
|---|------|------|------------|-----------|
| 1 | design | SECTION | いいねしたコンテンツ詳細（トラック） | [Link](https://www.figma.com/design/abCy1tq5spM0jeXbhLemu6/250425_Nash-App-Design_?node-id=2427-44475) |
| 2 | design | FRAME | いいねボタン | [Link](https://www.figma.com/design/abCy1tq5spM0jeXbhLemu6/250425_Nash-App-Design_?node-id=2805-12345) |
| 3 | design | SECTION | 検索画面 | [Link](https://www.figma.com/design/abCy1tq5spM0jeXbhLemu6/250425_Nash-App-Design_?node-id=2805-64307) |

Found: 3 frames matching keywords
```

**仕様書埋め込み用フォーマット:**

```markdown
## 参考

- Figma: [いいねしたコンテンツ詳細（トラック）](https://www.figma.com/design/abCy1tq5spM0jeXbhLemu6/250425_Nash-App-Design_?node-id=2427-44475)
- Figma: [検索画面](https://www.figma.com/design/abCy1tq5spM0jeXbhLemu6/250425_Nash-App-Design_?node-id=2805-64307)
```

## 認証情報の取得

Figma Personal Access Tokenは以下で管理:

| 保管場所 | パス |
|----------|------|
| プロジェクト認証YAML | `projects/{project}_credentials.yaml` の `figma.personal_access_token` |
| 環境変数（代替） | `FIGMA_ACCESS_TOKEN` |

**認証ヘッダー:**

```
X-Figma-Token: {access_token}
```

## 実装指示

Claude Codeに対する指示:

1. **API呼び出しにはBashツールでcurlを使用する**（WebFetchは認証ヘッダーを送れないため不可）
2. **レスポンスJSONの解析にはpython3 -c を使用する**（jqでも可だがpythonの方がUnicode処理が安定）
3. **depth=2で十分な場合が多い**: ページ→セクション→フレームの3階層。depth=3以上はAPI応答が大きくなるため必要時のみ
4. **ファイルキーと認証トークンは認証YAMLから読み取る**: ハードコーディング禁止
5. **検索結果が0件の場合**: キーワードの変更を提案する（例: 「いいね」→「イイネ」「like」等）
6. **node-idの`:`→`-`変換を忘れないこと**: URL内では必ずハイフン区切り

### API Rate Limit

| 制限 | 値 |
|------|-----|
| リクエスト/分 | 30（Personal Access Token） |
| ファイルサイズ制限 | 大規模ファイルはdepthを制限すること |

depth=2でファイル全体の構造を取得するリクエストは1回で十分。検索はローカル（レスポンスJSON内）で行うため、追加APIコールは不要。

## Best Practices

- 同一ファイルへの複数キーワード検索は1回のAPI呼び出しで行う（depth取得後にローカル検索）
- Figmaファイル名にアンダースコアや日本語が含まれる場合、URLエンコードに注意
- セクション名は日本語で命名されていることが多い。検索キーワードも日本語で指定する
- 検索結果が多い場合（10件超）は、`--page`オプションでページ絞り込みを推奨
- ディープリンクのfile_name部分は省略可能（Figmaはnode-idだけでナビゲートできる）が、可読性のため含めることを推奨
- 仕様書に埋め込む際は「仕様書埋め込み用フォーマット」を使用し、テーブル形式ではなくリスト形式にする
