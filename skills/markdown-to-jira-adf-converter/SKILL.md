---
name: markdown-to-jira-adf-converter
description: |
  Make sure to use this skill whenever the user asks to post Markdown to JIRA, convert Markdown to ADF, or update JIRA description via API v3 (「MarkdownをJIRAに」「ADF変換」「JIRA descriptionにMarkdownを」「JIRA API v3 description更新」).

  MarkdownテキストをJIRA API v3のdescription用ADF(Atlassian Document Format) JSONに変換する。

  Key capabilities: (1) 見出し・テーブル・リスト・太字・コードブロック等をADFノードに変換 (2) PUT /rest/api/3/issue/{key}で使用可能なJSON生成 (3) [要確認]マーカーを太字変換 (4) YAMLフロントマター除去対応 (5) 32KB制限考慮のサイズ確認 (6) Backlog &color()記法のtextColor変換
version: 1.0.0
---

# Markdown to JIRA ADF Converter

Markdown形式で記述された仕様書テキストを、JIRA REST API v3のdescriptionフィールドが要求するADF（Atlassian Document Format）JSON形式に変換するスキル。

## Overview

JIRA API v3ではdescriptionフィールドにADF形式のJSONを要求する。本スキルは以下のMarkdown要素をADFノードに変換する:

1. 見出し（`#`, `##`, `###`）→ heading
2. テーブル（`| col |`形式）→ table / tableRow / tableHeader / tableCell
3. 太字（`**text**`）→ text with strong mark
4. リスト（`- item`）→ bulletList / listItem
5. 段落（プレーンテキスト）→ paragraph / text
6. 水平線（`---`）→ rule
7. コードブロック（`` ``` ``）→ codeBlock

## When This Skill Applies

このスキルは以下の場合に適用される:
- Markdown仕様書をJIRAチケットのdescriptionに書き込む必要がある時
- JIRA API v3のPUT /rest/api/3/issue/{key}でdescription更新する時
- ADF形式の手動構築を避けたい時

## 入力パラメータ

| パラメータ | 必須 | 説明 | 例 |
|-----------|------|------|-----|
| `markdown_text` | Yes | 変換対象のMarkdownテキスト（文字列） | 仕様書の全文 |
| `--strip-frontmatter` | No | YAMLフロントマター（`---`で囲まれた部分）を除去する | - |

## 処理フロー

### Step 1: Markdownテキストの前処理

1. YAMLフロントマター（`--strip-frontmatter`指定時）を除去
2. テキストを行単位に分割
3. 空行を段落区切りとして認識

### Step 2: 行単位パース

各行を以下のパターンで判定し、ADFノードに変換する。

**判定優先順（上から順に評価）:**

| # | パターン | Markdownパターン | ADFノード |
|---|---------|-----------------|-----------|
| 1 | 水平線 | `---` (行全体) | `{"type": "rule"}` |
| 2 | 見出し | `^(#{1,6})\s+(.+)$` | heading (level=1-6) |
| 3 | テーブル | `^\|.*\|$` (連続行) | table |
| 4 | リスト | `^[-*]\s+(.+)$` (連続行) | bulletList |
| 5 | コードブロック | `` ^```(.*)$ `` | codeBlock |
| 6 | 段落 | その他の非空行 | paragraph |

### Step 3: インライン要素の変換

段落・セル・リスト項目内のテキストに対して、インライン変換を適用する。

| Markdownパターン | ADFマーク | 例 |
|-----------------|----------|-----|
| `**text**` | `{"type": "strong"}` | 太字 |
| `[text](url)` | `{"type": "link", "attrs": {"href": "url"}}` | リンク |
| `` `code` `` | `{"type": "code"}` | インラインコード |
| `[要確認]` / `[要確認: xxx]` | `{"type": "strong"}` (太字で強調) | 確認事項マーク |
| `&color(色名){テキスト}` | `{"type": "textColor", "attrs": {"color": "#xxxxxx"}}` | Backlog文字色 |

### Step 4: テーブル変換（詳細）

Markdownテーブルは以下のルールで変換する:

1. **ヘッダー行**（1行目）: `tableHeader` セルで構成
2. **セパレーター行**（`|---|---|`）: スキップ（ADFには不要）
3. **データ行**（3行目以降）: `tableCell` セルで構成
4. **セル内テキスト**: インライン変換（Step 3）を適用

```json
{
  "type": "table",
  "attrs": {"isNumberColumnEnabled": false, "layout": "default"},
  "content": [
    {
      "type": "tableRow",
      "content": [
        {
          "type": "tableHeader",
          "attrs": {},
          "content": [{"type": "paragraph", "content": [{"type": "text", "text": "項目"}]}]
        }
      ]
    },
    {
      "type": "tableRow",
      "content": [
        {
          "type": "tableCell",
          "attrs": {},
          "content": [{"type": "paragraph", "content": [{"type": "text", "text": "内容"}]}]
        }
      ]
    }
  ]
}
```

### Step 5: ADF文書の組み立て

全ノードをtop-levelのdocノードにまとめる。

```json
{
  "version": 1,
  "type": "doc",
  "content": [
    // Step 2-4で生成した各ノードを順番に配置
  ]
}
```

### Step 6: 出力

変換後のADF JSONを出力する。JIRA APIへのPUTリクエストでは以下の形式で使用:

```json
{
  "fields": {
    "description": {
      "version": 1,
      "type": "doc",
      "content": [...]
    }
  }
}
```

## ADFノード対応表

| Markdown | ADF type | 属性 |
|----------|----------|------|
| `# 見出し` | heading | `{"level": 1}` |
| `## 見出し` | heading | `{"level": 2}` |
| `### 見出し` | heading | `{"level": 3}` |
| `段落テキスト` | paragraph → text | - |
| `**太字**` | text | `marks: [{"type": "strong"}]` |
| `- リスト` | bulletList → listItem → paragraph → text | - |
| `\| テーブル \|` | table → tableRow → tableHeader/tableCell → paragraph → text | - |
| `---` | rule | - |
| `` ```code``` `` | codeBlock | `{"language": ""}` |
| `[text](url)` | text | `marks: [{"type": "link", "attrs": {"href": "url"}}]` |
| `&color(色名){テキスト}` | text | `marks: [{"type": "textColor", "attrs": {"color": "#xxxxxx"}}]` |

## Backlog記法: &color() の変換

Backlog記法の `&color(色名){テキスト}` をADFの `textColor` マークに変換する。

### パターン

```
&color(red){重要な注意事項}
```

→ ADF:

```json
{"type": "text", "text": "重要な注意事項", "marks": [{"type": "textColor", "attrs": {"color": "#ff0000"}}]}
```

### 色名→カラーコード変換表

| Backlog色名 | カラーコード |
|------------|-------------|
| `red` | `#ff0000` |
| `blue` | `#0000ff` |
| `green` | `#008000` |
| `orange` | `#ff8c00` |
| `purple` | `#800080` |
| `gray` / `grey` | `#808080` |
| `black` | `#000000` |
| `white` | `#ffffff` |
| `yellow` | `#ffff00` |
| `pink` | `#ff69b4` |
| `brown` | `#8b4513` |
| `#xxxxxx` (16進直接指定) | そのまま使用 |

### 注意事項

- `&color()` はネスト可能（`&color(red){**太字テキスト**}`）→ textColorマークとstrongマークを両方適用
- 色名が上記表にない場合は `#000000`（黒）にフォールバック
- 16進カラーコード直接指定（`&color(#ff5500){テキスト}`）はそのまま使用

## 実装指示

Claude Codeに対する指示:

1. **入力Markdownは文字列として受け取る**（ファイルパスではない。事前にReadで読み込んだテキストを渡す）
2. **JSON構築はPythonのdict/listで行い、json.dumps()で文字列化する**
3. **テーブルのセパレーター行（`|---|`）は必ずスキップする**
4. **セル内の先頭・末尾スペースはtrimする**
5. **空のcontentは許容しない**: ADFは空のparagraph等を受け付けないため、空ノードは除外する
6. **[要確認]マーカーは太字に変換**: 仕様書の未確定事項を視覚的に強調する

### テーブルヘッダーの配置（`:---:`対応）

| Markdownパターン | ADFアライン |
|-----------------|-----------|
| `:---:` (中央揃え) | 無視（ADFテーブルにアライン属性なし） |
| `---:` (右揃え) | 無視 |
| `:---` (左揃え、デフォルト) | 無視 |

セパレーター行のアライン記号はADFに対応する属性がないため、全て無視してスキップする。

## Best Practices

- 変換前にMarkdownの構文エラー（閉じていないテーブル、不正なネスト等）をチェックする
- 大きなMarkdownテキスト（100行超）は変換結果のJSON sizeを確認する（JIRAのdescriptionフィールドに32KB制限あり）
- テーブルが多い仕様書では、変換後にJIRAのWeb UIで表示を確認するステップを推奨
- JIRA API呼び出し前に、ADFのバリデーション（version=1, type="doc", contentが配列）を行う
- `[要確認]`マーカーは検索しやすいよう、太字に加えて一覧化すると監査に有効
