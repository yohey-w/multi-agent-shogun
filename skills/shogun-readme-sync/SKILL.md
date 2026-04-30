---
name: shogun-readme-sync
description: README.md（英語）とREADME_ja.md（日本語）の同期を確認・実行するスキル。README変更時に両言語版を必ず同時更新するために使用。「README更新」「README同期」「readme sync」で起動。
---

# /shogun-readme-sync - README日英同期

## Overview

README.md（英語）とREADME_ja.md（日本語）の差分を検出し、不足セクションの追加・番号ズレの修正を行う。

README変更時のワークフロー:
1. 差分検出（どちらが新しいか自動判定）
2. 不足セクションのリストアップ
3. 翻訳・追記の実行
4. セクション番号の整合性チェック

## When to Use

- READMEを編集した後（機能追加、セクション追加、構成変更）
- 「README更新」「README同期」「readme sync」と言われた時
- 新機能をREADMEに書いた後に「日本語版も」と言われた時
- PR作成前のREADME整合性チェック

## Instructions

### Step 1: 差分検出

両ファイルを読み込み、以下の観点で差分を検出する:

```bash
# 両ファイルを読む
Read README.md
Read README_ja.md
```

**チェック項目:**

| 項目 | 確認方法 |
|------|----------|
| セクション数 | `###` ヘッダーの数が一致するか |
| セクション番号 | 番号付きセクション（`### ... 1.`, `### ... 2.`等）の連番が正しいか |
| ファイル構成 | File Structure / ファイル構成セクション内のファイル一覧が一致するか |
| バージョンセクション | `What's New` / `新機能` セクションが両方に存在するか |
| 折りたたみ内容 | `<details>` ブロックの有無が一致するか |

### Step 2: 差分レポート

検出した差分を報告する:

```
README同期チェック結果:

EN → JA で不足:
- セクション「Agent Status Check」が日本語版にない
- ファイル構成に lib/agent_status.sh が未掲載
- v3.3.2セクションがない

JA → EN で不足:
- （なし）

セクション番号ズレ:
- JA: スクリーンショットが5番だがENでは6番
```

### Step 3: 同期実行

差分を修正する。翻訳のルール:

| EN | JA |
|----|-----|
| Agent Status Check | エージェント稼働確認 |
| Screenshot Integration | スクリーンショット連携 |
| Context Management | コンテキスト管理 |
| Phone Notifications | スマホ通知 |
| Pane Border Task Display | ペインボーダータスク表示 |
| Shout Mode | シャウトモード（戦国エコー） |
| Event-Driven Communication | イベント駆動通信 |
| Parallel Execution | 並列実行 |
| Non-Blocking Workflow | ノンブロッキングワークフロー |
| Cross-Session Memory | セッション間記憶 |
| Bottom-Up Skill Discovery | ボトムアップスキル発見 |

**翻訳方針:**
- 技術用語はそのまま（tmux, YAML, CLI, MCP, inotifywait等）
- コードブロック内のコマンドは翻訳しない
- 出力例は日本語版に合わせる（「稼働中」「待機中」等）
- 絵文字はENと同じものを使う

### Step 4: 整合性最終チェック

修正後、以下を確認:
1. 両ファイルのセクション数が一致
2. 番号付きセクションの連番が正しい
3. ファイル構成セクションのエントリが一致
4. バージョンセクションが両方に存在

## Guidelines

- **ENが正**: 新機能は基本的にENに先に書かれる。JA側を追従させる
- **JA独自表現は維持**: 日本語版の「戦国エコー」等の独自表現はそのまま残す
- **一方通行にしない**: ENにしかない変更もJAにしかない変更も両方検出する
- **セクション番号は自動繰り上げ**: 中間にセクションを挿入した場合、後続の番号を全て繰り上げる
- **コードブロック内は触らない**: bash/yaml/markdownのコードブロック内テキストは翻訳対象外
