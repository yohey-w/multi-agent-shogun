---
name: backlog-to-jira-image-migrator
description: |
  Make sure to use this skill whenever the user asks to migrate images from Backlog to JIRA, embed images in JIRA ADF, or transfer Backlog attachments to JIRA (「Backlog画像をJIRAに」「JIRA画像転記」「Backlog添付ファイル転記」「BacklogからJIRAへ画像移行」「JIRA ADF画像埋め込み」).

  BacklogチケットのBacklog記法#image()で埋め込まれた画像をJIRAチケットのADF mediaSingleノードに転記する。

  Key capabilities: (1) Backlog API添付ファイル取得・ダウンロード (2) JIRAアタッチメントアップロード (3) Atlassian Media UUID取得（リダイレクト追跡） (4) ADF mediaSingleノード構築・配置 (5) 大きいADF(77KB超)のREST API直接更新
version: 1.0.0
---

# Backlog to JIRA Image Migrator

BacklogチケットのBacklog記法 `#image(ファイル名)` で埋め込まれた添付画像を、JIRA REST API v3のdescriptionフィールド（ADF形式）の `mediaSingle` ノードに転記するスキル。

## Overview

Backlogの画像添付記法（`#image()`）はJIRAに自動変換されない。本スキルは以下のステップで画像を転記する:

1. BacklogAPIで添付ファイル一覧・バイナリを取得
2. JIRAにアタッチメントとしてアップロード
3. Atlassian Media UUIDを取得（リダイレクト追跡）
4. ADF `mediaSingle` ノードを構築し、JIRAのdescriptionに配置

## 既存スキルとの棲み分け

| スキル | 対象 |
|--------|------|
| `markdown-to-jira-adf-converter` | テキスト（Markdown）→ ADF変換 |
| `backlog-to-jira-image-migrator`（本スキル） | Backlog添付画像 → JIRAアタッチメント + ADF画像ノード埋め込み |

## 処理フロー

### Step 1: Backlog添付ファイル一覧の取得

```
GET https://{space}.backlog.com/api/v2/issues/{issueIdOrKey}/attachments?apiKey={apiKey}
```

レスポンス例:
```json
[
  {"id": 12345, "name": "screenshot.png", "size": 102400},
  {"id": 12346, "name": "diagram.png",    "size": 51200}
]
```

- `id`: ダウンロード時に使用する数値ID
- `name`: Backlog記法 `#image(ファイル名)` のファイル名と照合する

### Step 2: 添付ファイルのダウンロード

```
GET https://{space}.backlog.com/api/v2/issues/{issueIdOrKey}/attachments/{attachmentId}?apiKey={apiKey}
```

- バイナリとして取得し、一時ファイルに保存する
- MCPツール非対応のため、Python/bashスクリプトで実行することを推奨

### Step 3: JIRAへアタッチメントアップロード

```
POST https://{jira-host}/rest/api/3/issue/{issueKey}/attachments
Headers:
  Authorization: Basic {base64(email:api_token)}
  X-Atlassian-Token: no-check
  Content-Type: multipart/form-data
Body:
  file=@/tmp/{filename}
```

レスポンスに**数値のattachment ID**が返る（ADFでは使用不可）:
```json
[{"id": "987654", "content": "https://.../.../attachments/987654"}]
```

### Step 4: Atlassian Media UUIDの取得（最重要）

**数値のattachment IDはADF mediaノードで使用不可。**
Media UUIDを取得するには、attachment contentのURLにアクセスしてリダイレクト先からUUIDを抽出する。

#### 手順

1. attachment contentのURLにHEADまたはGETリクエスト（`-L`でリダイレクト追跡）
2. 最終的なリダイレクト先URL: `https://api.media.atlassian.com/file/{uuid}/binary`
3. このパスの `{uuid}` 部分がMedia UUID

```bash
# リダイレクト先URLを取得
curl -sI -L \
  -u "{email}:{api_token}" \
  "https://{jira-host}/rest/api/3/attachment/content/{attachment_id}" \
  | grep -i "^location:" | tail -1
# 例: location: https://api.media.atlassian.com/file/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/binary
```

Python例:
```python
import requests

resp = requests.get(
    f"https://{jira_host}/rest/api/3/attachment/content/{attachment_id}",
    auth=(email, api_token),
    allow_redirects=True
)
# resp.url が最終リダイレクト先
# "https://api.media.atlassian.com/file/{uuid}/binary" の形式
uuid = resp.url.split("/file/")[1].split("/")[0]
```

### Step 5: ADF mediaSingleノードの構築

#### 正解: mediaSingle（ブロック要素、**画像として表示**）

```json
{
  "type": "mediaSingle",
  "attrs": {"layout": "center"},
  "content": [
    {
      "type": "media",
      "attrs": {
        "type": "file",
        "id": "<atlassian-media-uuid>",
        "collection": ""
      }
    }
  ]
}
```

#### 注意: mediaInline（インライン要素、**テキストリンクとして表示される**）

```json
{
  "type": "mediaInline",
  "attrs": {
    "type": "file",
    "id": "<atlassian-media-uuid>",
    "collection": ""
  }
}
```

**テーブルセル内の画像は必ず `mediaSingle` を使用すること。**
`mediaInline` はテキストリンクとして表示されるため、画像として表示されない。

### Step 6: Backlog記法 `#image()` の位置特定とADF配置

1. BacklogチケットのdescriptionをBacklog記法（生テキスト）で取得
2. `#image(ファイル名)` の出現位置を特定
3. JIRAのADF descriptionを取得し、対応するtableCell・paragraph等を特定
4. 該当箇所に `mediaSingle` ノードを挿入

#### tableCell内への配置例

```json
{
  "type": "tableCell",
  "attrs": {},
  "content": [
    {
      "type": "paragraph",
      "content": [{"type": "text", "text": "説明テキスト"}]
    },
    {
      "type": "mediaSingle",
      "attrs": {"layout": "center"},
      "content": [
        {
          "type": "media",
          "attrs": {
            "type": "file",
            "id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
            "collection": ""
          }
        }
      ]
    }
  ]
}
```

### Step 7: JIRAのdescriptionを更新

#### 小さいADF（～77KB）: MCPツール使用可

```
editJiraIssue MCP tool:
  issueKey: {key}
  fields: {description: {version:1, type:"doc", content:[...]}}
```

#### 大きいADF（77KB超）: REST API直接更新

MCPツールでは大きなADFが途中で切れる場合があるため、JIRA REST APIを直接呼び出す:

```bash
curl -s -X PUT \
  -u "{email}:{api_token}" \
  -H "Content-Type: application/json" \
  -d @/tmp/adf_payload.json \
  "https://{jira-host}/rest/api/3/issue/{issueKey}"
```

`/tmp/adf_payload.json`:
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

## チェックリスト

- [ ] Backlog API Keyを確認
- [ ] JIRA認証情報（email + API token）を確認
- [ ] `#image()` に記載のファイル名とattachment一覧のnameが一致していること
- [ ] Media UUIDが `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` 形式（UUID v4）であること
- [ ] テーブルセル内の画像は `mediaSingle`（`mediaInline` 不可）を使用
- [ ] 更新後にJIRAの画面で画像が表示されていること（リンクではなく画像）

## よくあるエラーと対処

| エラー | 原因 | 対処 |
|--------|------|------|
| ADF保存後に画像がリンク表示になる | `mediaInline` を使用している | `mediaSingle` に変更 |
| ADF保存後に画像が表示されない | 数値attachment IDをUUIDとして使用している | リダイレクト追跡でMedia UUIDを取得し直す |
| ADF更新が途中で切れる | MCPツールの入力制限（77KB超） | curl直接呼び出しに切り替える |
| 404 Not Found (attachment download) | Backlog APIの認証不足 | `?apiKey=` パラメータを確認 |
| X-Atlassian-Token未設定エラー | JIRAアタッチメントアップロード時 | ヘッダー `X-Atlassian-Token: no-check` を付与 |
