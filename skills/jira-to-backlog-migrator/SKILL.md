---
name: jira-to-backlog-migrator
description: |
  Make sure to use this skill whenever the user asks to migrate JIRA tickets to Backlog, convert ADF to Backlog notation, or transfer JIRA attachments to Backlog (「JIRAからBacklogに転記」「JIRA→Backlog転記」「ADF→Backlog変換」「JIRA添付ファイルをBacklogに」「JIRA仕様をBacklogに転記」).

  JIRAチケットのADF descriptionをBacklog記法に変換し、添付画像も含めてBacklogチケットに転記する。

  Key capabilities: (1) ADF→Backlog記法変換（見出し・太字・テーブル・文字色・コード等） (2) JIRA添付画像ダウンロード→Backlog添付+#image()埋め込み (3) Backlogチケット新規作成/既存更新の自動判定 (4) スプレッドシートD列へのBacklog URL書き込み (5) [要確認]赤字化・Figmaリンクハイパーリンク化
version: 1.0.0
---

# JIRA to Backlog Migrator

JIRAチケットのdescription（ADF形式）をBacklog記法に変換し、添付画像も含めてBacklogチケットに転記するスキル。

## Overview

JIRAのADF descriptionはBacklogでは解釈されない。本スキルは以下のステップで転記する:

1. スプレッドシートから要件情報（JIRAキー・既存Backlogキー）を取得
2. JIRA REST APIでdescription（ADF）と添付ファイル一覧を取得
3. ADF→Backlog記法に変換（テキスト・装飾・テーブル・色等）
4. JIRA添付画像をダウンロードしBacklogにアップロード
5. Backlogチケットを新規作成または既存チケットを更新
6. スプレッドシートのD列にBacklogキーを書き込む

## 既存スキルとの棲み分け

| スキル | 対象 |
|--------|------|
| `markdown-to-jira-adf-converter` | Markdown → ADF変換（Backlog→JIRA方向） |
| `backlog-to-jira-image-migrator` | Backlog添付画像 → JIRAアタッチメント + ADF画像ノード |
| `jira-to-backlog-migrator`（本スキル） | JIRAのADF description → Backlog記法 + 画像転記 |

## 前提条件 / 入力

### 認証情報

`projects/nash_nmc_credentials.yaml` から取得する（内容を直接出力・ログに記録しないこと）:

| キー | 用途 |
|------|------|
| `jira.email` | JIRA Basic認証のユーザー名 |
| `jira.api_token` | JIRA Basic認証のパスワード |
| `backlog.api_key` | Backlog API Key（クエリパラメータで付与） |
| `google_sheets.service_account_key` | Google Sheets SA鍵ファイルパス |

### 入力

- **要件ID**: スプレッドシートのA列に記載されたID（例: 214）
- 複数件対応: カンマ区切りまたはリスト形式で指定可能

### スプレッドシート情報

| 項目 | 値 |
|------|-----|
| スプレッドシートID | `1zlxFBUgZdiYJ8qOosgOMkEBvdZyX9TvCeo_lhW_yKLc` |
| シートGID | `1806724167` |
| A列 | 要件ID |
| D列 | BacklogキーまたはBacklog URL |
| E列 | JIRA URL |
| F列 | 機能名 |

### Backlog情報

| 項目 | 値 |
|------|-----|
| Base URL | `https://nashserver.backlog.jp` |
| プロジェクトキー | `NMCAPP` |
| カテゴリー（新規作成時） | `NMC-178_開発フェーズ4` |
| マイルストーン（新規作成時） | `v3.3.0` |
| 記法 | `textFormattingRule=backlog`（Markdown非対応） |

### JIRA情報

| 項目 | 値 |
|------|-----|
| Host | `newnoah.atlassian.net`（credentials.yamlから取得） |
| API | REST API v3（ADF形式） |
| BacklogURL格納フィールド | `customfield_10762` |

---

## 処理フロー

### Step 1: スプレッドシートから要件情報取得

Google Sheets APIを使用してサービスアカウント認証で読み取る。

```python
from google.oauth2 import service_account
from googleapiclient.discovery import build
import yaml

# credentials読み込み（内容をstdoutに出力しないこと）
with open("projects/nash_nmc_credentials.yaml") as f:
    creds_yaml = yaml.safe_load(f)

sa_key_path = creds_yaml["google_sheets"]["service_account_key"]
credentials = service_account.Credentials.from_service_account_file(
    sa_key_path,
    scopes=["https://www.googleapis.com/auth/spreadsheets"]
)
service = build("sheets", "v4", credentials=credentials)

SPREADSHEET_ID = "1zlxFBUgZdiYJ8qOosgOMkEBvdZyX9TvCeo_lhW_yKLc"
result = service.spreadsheets().values().get(
    spreadsheetId=SPREADSHEET_ID,
    range="A:F"
).execute()
rows = result.get("values", [])

# A列で要件IDを検索
target_req_id = str(要件ID)
for i, row in enumerate(rows):
    if row and row[0] == target_req_id:
        jira_url = row[4] if len(row) > 4 else ""   # E列: JIRA URL
        backlog_key = row[3] if len(row) > 3 else "" # D列: Backlogキー
        func_name = row[5] if len(row) > 5 else ""   # F列: 機能名
        row_index = i + 1  # 1-indexed（API更新時に使用）
        break
```

JIRAキーはE列のURLから抽出する（例: `https://newnoah.atlassian.net/browse/NMC-56` → `NMC-56`）。

### Step 2: JIRA description・添付ファイル取得

JIRA REST API v3でADF descriptionと添付ファイル一覧を一括取得する。

```bash
curl -s \
  -u "{email}:{api_token}" \
  -H "Accept: application/json" \
  "https://{jira-host}/rest/api/3/issue/{jiraKey}?fields=summary,description,attachment,customfield_10762"
```

レスポンス構造:
```json
{
  "fields": {
    "summary": "チケットタイトル",
    "description": {
      "version": 1,
      "type": "doc",
      "content": [...]
    },
    "attachment": [
      {"id": "12345", "filename": "image.png", "content": "https://..."}
    ],
    "customfield_10762": "https://nashserver.backlog.jp/view/NMCAPP-271"
  }
}
```

- `description` がnullの場合は空文字列として処理する
- `customfield_10762` にBacklog URLがある場合はStep 5で更新パスを使用する

### Step 3: ADF→Backlog記法変換

ADF（Atlassian Document Format）のJSONノードをBacklog記法のプレーンテキストに変換する。

#### 変換ルール一覧

| ADFノード / マーク | Backlog記法 | 備考 |
|-------------------|-------------|------|
| `heading` (level=1) | `* 見出し` | |
| `heading` (level=2) | `** 見出し` | |
| `heading` (level=3) | `*** 見出し` | |
| `heading` (level=4以下) | `*** 見出し` | level 3に丸める |
| `paragraph` | テキスト + 改行 | 空paragraphは空行として出力 |
| `bulletList` / `listItem` | `- アイテム` | ネスト: `-- ` `--- ` |
| `orderedList` / `listItem` | `+ アイテム` | ネスト: `++ ` `+++ ` |
| `table` | テーブル記法（後述） | |
| `rule` | `----` | 水平線 |
| `codeBlock` | `{code}\n...\n{/code}` | |
| `strong` (mark) | `''太字''` | |
| `em` (mark) | `'''イタリック'''` | |
| `strike` (mark) | `%%取り消し%%` | |
| `code` (mark) | `` `コード` `` | インラインコード |
| `underline` (mark) | `__テキスト__` | |
| `link` (mark) | `[[テキスト>URL]]` | |
| `textColor` (mark) | `&color(#hex){テキスト}` | |
| `mediaSingle` / `media` | `#image(ファイル名)` | ファイル名はattachment一覧と照合 |

#### テーブル変換詳細

Backlogのテーブル記法は行末に修飾子を付ける:

```
|ヘッダ1|ヘッダ2|ヘッダ3|h
|データ1|データ2|データ3|
|データ4|データ5|データ6|
```

- `tableHeader` を含む行の末尾に `h` を付ける
- `tableCell` の行は末尾修飾子なし
- セル内の改行は `&br;` で表現する
- **Backlog記法にはMarkdownのようなヘッダー区切り線（`---`）は不要**。ADF→Backlog変換時に `---` テキストを含む行はスキップまたは除去すること
- `tableCell` / `tableHeader` 内に `mediaSingle` ノードがある場合は `#image(ファイル名)` をセル内にインラインで出力する（テーブル外に出さない）

#### [要確認]の赤字化ルール

テキスト内に `[要確認]` または `[要確認: ...]` が含まれる場合、Backlog記法の文字色で赤くする:

```
&color(red){[要確認]}テキストの続き
&color(red){[要確認: 仕様未定]}
```

#### FigmaリンクのURL化

テキスト中にFigmaのURL（`https://www.figma.com/...`）が含まれる場合、ハイパーリンクとして変換する:

```
[[Figmaリンク>https://www.figma.com/design/...?node-id=...]]
```

#### Python実装例

```python
def adf_to_backlog(node, depth=0):
    """ADFノードを再帰的にBacklog記法テキストに変換する"""
    node_type = node.get("type", "")
    content = node.get("content", [])
    attrs = node.get("attrs", {})

    if node_type == "doc":
        return "\n".join(adf_to_backlog(c) for c in content)

    elif node_type == "heading":
        level = attrs.get("level", 2)
        level = min(level, 3)  # Backlogは最大3階層
        prefix = "*" * level
        text = inline_to_backlog(content)
        return f"{prefix} {text}"

    elif node_type == "paragraph":
        text = inline_to_backlog(content)
        return text if text else ""

    elif node_type == "bulletList":
        lines = []
        for item in content:  # listItem
            prefix = "-" * (depth + 1)
            item_content = item.get("content", [])
            # listItem内のparagraphとネストリスト
            for c in item_content:
                if c["type"] in ("bulletList", "orderedList"):
                    lines.append(adf_to_backlog(c, depth + 1))
                else:
                    lines.append(f"{prefix} {inline_to_backlog(c.get('content', []))}")
        return "\n".join(lines)

    elif node_type == "orderedList":
        lines = []
        for item in content:
            prefix = "+" * (depth + 1)
            item_content = item.get("content", [])
            for c in item_content:
                if c["type"] in ("bulletList", "orderedList"):
                    lines.append(adf_to_backlog(c, depth + 1))
                else:
                    lines.append(f"{prefix} {inline_to_backlog(c.get('content', []))}")
        return "\n".join(lines)

    elif node_type == "table":
        rows = []
        for row in content:  # tableRow
            cells = []
            is_header = False
            for cell in row.get("content", []):
                if cell["type"] == "tableHeader":
                    is_header = True
                # セル内の複数ノード（paragraph, mediaSingle等）を処理
                cell_parts = []
                for child in cell.get("content", []):
                    if child.get("type") == "mediaSingle":
                        # セル内の画像をインラインで処理
                        for media_child in child.get("content", []):
                            if media_child.get("type") == "media":
                                media_id = media_child.get("attrs", {}).get("id", "")
                                filename = media_id_to_filename.get(media_id, media_id)
                                cell_parts.append(f"#image({filename})")
                    elif child.get("type") == "paragraph":
                        part = inline_to_backlog(child.get("content", []))
                        if part:
                            cell_parts.append(part)
                    else:
                        part = inline_to_backlog(child.get("content", []))
                        if part:
                            cell_parts.append(part)
                cell_text = "&br;".join(cell_parts)
                cells.append(cell_text)
            # Markdown区切り線行（全セルが"---"または"-"のみ）はスキップ
            if all(re.match(r'^-+$', c.strip()) for c in cells if c.strip()):
                continue
            suffix = "h" if is_header else ""
            rows.append("|" + "|".join(cells) + "|" + suffix)
        return "\n".join(rows)

    elif node_type == "rule":
        return "----"

    elif node_type == "codeBlock":
        lang = attrs.get("language", "")
        lang_str = f":{lang}" if lang else ""
        code_text = "".join(c.get("text", "") for c in content if c.get("type") == "text")
        return f"{{code{lang_str}}}\n{code_text}\n{{/code}}"

    elif node_type == "mediaSingle":
        # 添付ファイル名はmedia nodeのattrs.idをファイル名マッピングで解決
        for child in content:
            if child.get("type") == "media":
                media_id = child.get("attrs", {}).get("id", "")
                filename = media_id_to_filename.get(media_id, media_id)
                return f"#image({filename})"
        return ""

    return ""


def inline_to_backlog(content_nodes):
    """インラインノード（text, marks等）をBacklog記法に変換する"""
    result = ""
    for node in content_nodes:
        if isinstance(node, str):
            result += node
            continue
        node_type = node.get("type", "")
        if node_type == "text":
            text = node.get("text", "")
            marks = node.get("marks", [])
            # [要確認]の赤字化
            import re
            text = re.sub(r'\[要確認[^\]]*\]', lambda m: f"&color(red){{{m.group()}}}", text)
            # Figmaリンクのハイパーリンク化
            text = re.sub(
                r'(https://www\.figma\.com/\S+)',
                r'[[Figmaリンク>\1]]',
                text
            )
            # marksを逆順に適用（内側から外側へ）
            for mark in reversed(marks):
                mark_type = mark.get("type", "")
                if mark_type == "strong":
                    text = f"''{text}''"
                elif mark_type == "em":
                    text = f"'''{text}'''"
                elif mark_type == "strike":
                    text = f"%%{text}%%"
                elif mark_type == "code":
                    text = f"`{text}`"
                elif mark_type == "underline":
                    text = f"__{text}__"
                elif mark_type == "link":
                    href = mark.get("attrs", {}).get("href", "")
                    text = f"[[{text}>{href}]]"
                elif mark_type == "textColor":
                    color = mark.get("attrs", {}).get("color", "#000000")
                    text = f"&color({color}){{{text}}}"
            result += text
        elif node_type == "hardBreak":
            result += "\n"
        elif node_type in ("mention", "emoji"):
            result += node.get("attrs", {}).get("text", "")
        elif node_type == "inlineCard":
            url = node.get("attrs", {}).get("url", "")
            result += f"[[{url}>{url}]]"
    return result
```

### Step 4: JIRA添付画像→Backlog転記

#### 4-1: JIRA添付画像のダウンロード

```python
import requests
import os

auth = (creds["jira"]["email"], creds["jira"]["api_token"])

for attachment in attachments:
    url = attachment["content"]
    filename = attachment["filename"]
    resp = requests.get(url, auth=auth)
    tmp_path = f"/tmp/{filename}"
    with open(tmp_path, "wb") as f:
        f.write(resp.content)
```

#### 4-2: Backlogスペースへの添付ファイルアップロード

```bash
curl -s -X POST \
  "https://nashserver.backlog.jp/api/v2/space/attachment?apiKey={api_key}" \
  -F "file=@/tmp/{filename}"
```

レスポンス:
```json
{"id": 98765, "name": "image.png", "size": 102400}
```

返却される `id`（attachmentId）を次のチケット更新時に渡す。

#### 4-3: media_id→ファイル名マッピングの構築

ADF descriptionのmedia nodeには `attrs.id`（JIRA Media UUID）が入っている。これをBacklog記法の `#image(ファイル名)` に変換するため、JIRA attachmentのリダイレクト追跡でUUIDを取得してマッピングを構築する。

```python
import re

def get_media_uuid(attachment_id, auth, jira_host):
    """JIRAアタッチメントIDからAtlassian Media UUIDを取得"""
    resp = requests.get(
        f"https://{jira_host}/rest/api/3/attachment/content/{attachment_id}",
        auth=auth,
        allow_redirects=True
    )
    # 最終リダイレクト先: https://api.media.atlassian.com/file/{uuid}/binary
    match = re.search(r'/file/([0-9a-f-]{36})/', resp.url)
    return match.group(1) if match else None

# {media_uuid: filename} のマッピングを構築
media_id_to_filename = {}
for att in attachments:
    uuid = get_media_uuid(att["id"], auth, jira_host)
    if uuid:
        media_id_to_filename[uuid] = att["filename"]
```

### Step 5: Backlogチケット作成/更新

#### 判定ロジック

1. Step 2で取得した `customfield_10762` にBacklog URLが存在するか確認
2. **URLあり** → BacklogキーをURLから抽出し、既存チケットを更新（PATCH）
3. **URLなし** → 新規チケットを作成（POST）し、JIRAの `customfield_10762` にBacklog URLを書き戻す

#### 5-1: 既存チケット更新（PATCH）

```bash
curl -s -X PATCH \
  "https://nashserver.backlog.jp/api/v2/issues/{backlogKey}?apiKey={api_key}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "description={backlog記法テキスト}" \
  -d "attachmentId[]={attachmentId1}" \
  -d "attachmentId[]={attachmentId2}"
```

**注意**: Backlog APIのPATCH issueは `application/x-www-form-urlencoded`。`attachmentId[]` を複数指定することで画像を添付できる。

#### 5-2: 新規チケット作成（POST）

事前にプロジェクトのissueTypeId・categoryId・milestoneIdを取得する:

```bash
# issueTypes一覧取得
curl -s "https://nashserver.backlog.jp/api/v2/projects/NMCAPP/issueTypes?apiKey={api_key}"

# カテゴリー一覧取得
curl -s "https://nashserver.backlog.jp/api/v2/projects/NMCAPP/categories?apiKey={api_key}"

# マイルストーン一覧取得
curl -s "https://nashserver.backlog.jp/api/v2/projects/NMCAPP/versions?apiKey={api_key}"
```

チケット作成:

```bash
curl -s -X POST \
  "https://nashserver.backlog.jp/api/v2/issues?apiKey={api_key}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "summary={機能名}" \
  --data-urlencode "description={backlog記法テキスト}" \
  -d "projectId={nmcapp_project_id}" \
  -d "issueTypeId={issueTypeId}" \
  -d "categoryId[]={categoryId}" \
  -d "milestoneId[]={milestoneId}" \
  -d "attachmentId[]={attachmentId1}"
```

#### 5-3: JIRAへのBacklog URL書き戻し（新規作成時のみ）

```bash
curl -s -X PUT \
  -u "{email}:{api_token}" \
  -H "Content-Type: application/json" \
  -d '{"fields": {"customfield_10762": "https://nashserver.backlog.jp/view/{backlogKey}"}}' \
  "https://{jira-host}/rest/api/3/issue/{jiraKey}"
```

### Step 6: スプレッドシートD列更新

```python
body = {
    "values": [[f"https://nashserver.backlog.jp/view/{backlogKey}"]]
}
service.spreadsheets().values().update(
    spreadsheetId=SPREADSHEET_ID,
    range=f"D{row_index}",
    valueInputOption="RAW",
    body=body
).execute()
```

D列に既にBacklogキーまたはURLが入力済みの場合は、既存値を確認してから上書きする（誤上書き防止）。

---

## チェックリスト

**処理前**:
- [ ] `projects/nash_nmc_credentials.yaml` の読み込み確認
- [ ] SA鍵ファイル `projects/ie-automation-48ba5420466f.json` の存在確認
- [ ] スプレッドシートで対象要件IDの行を特定
- [ ] E列にJIRA URLが入力されていること

**処理後**:
- [ ] Backlogチケットのdescriptionにテキストが正しく反映されていること
- [ ] 画像が `#image()` 記法で本文内の元の位置に配置されていること
- [ ] Backlog上で画像が表示されること（リンクではなく画像として）
- [ ] テーブルのヘッダー行に `h` サフィックスがついていること
- [ ] `[要確認]` が赤字（`&color(red){...}`）になっていること
- [ ] スプレッドシートD列にBacklogキー/URLが入力されていること
- [ ] （新規作成時）JIRAの `customfield_10762` にBacklog URLが書き戻されていること

---

## よくあるエラーと対処

| エラー | 原因 | 対処 |
|--------|------|------|
| `description` が空白のまま | ADFをBacklog記法に変換せず生JSONを渡した | `adf_to_backlog()` 関数で変換してから渡す |
| 画像が表示されない | `#image()` のファイル名がBacklog添付名と不一致 | attachmentIdで先にBacklogにアップロードし、返却されたnameを使用 |
| テーブルが崩れる | セル内改行を処理していない | セル内改行は `&br;` に置換する |
| Backlog APIが400エラー | `application/json` で送信している | `application/x-www-form-urlencoded` を使用する |
| `customfield_10762` がnull | JIRA側にBacklog URLが未設定 | 新規作成パスで処理し、作成後に書き戻す |
| Google Sheets 403エラー | SAのスコープが `readonly` | スコープを `spreadsheets`（読み書き）に変更 |
| `[要確認]` が変換されない | inline_to_backlog適用前にADF変換している | inline_to_backlog内で正規表現変換を行うこと |

---

## Backlog記法の重要注意事項

- **Backlog APIの記法設定**: `textFormattingRule=backlog`（デフォルト）。Markdown記法は使用不可
- **Base URL**: `https://nashserver.backlog.jp`（nashserverサブドメイン）
- **API認証**: クエリパラメータ `?apiKey={api_key}`（Authorizationヘッダー不要）
- **Content-Type**: issue作成・更新は `application/x-www-form-urlencoded`
- **attachmentIdは先にアップロード**: スペースへの事前アップロード（`/api/v2/space/attachment`）でIDを取得してからissue更新時に渡す
- **外部公開先（Backlog）の記述**: ビジネス日本語を使用（戦国口調禁止）
