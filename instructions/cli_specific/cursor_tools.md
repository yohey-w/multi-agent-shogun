# Cursor Agent CLI — 固有の操作ルール

これは Cursor Agent CLI 環境でのみ適用される操作ルール。
共有プロトコル（CLAUDE.md / AGENTS.md）と role 指示書と組み合わせて使う。

## 概要

- `CLAUDE.md`・`AGENTS.md`・`.cursor/rules/` はセッション開始時に自動読み込みされる
- `--yolo` モード（Auto-run）で起動するため、ツール実行に追加の承認は不要
- エージェント間通信は `inbox-write` スキル経由で行う

## セッションリセット

```
/new-chat
```

## 終了

```
/quit
```

（テキストと Enter は 0.3s 分けて送信される。）

## エージェント間通信

エージェントへのメッセージ送信は必ず `inbox-write` スキルを使うこと。
tmux を直接操作することは禁止。

```bash
bash scripts/inbox_write.sh <target_agent> "<message>" <type> <from>
```

## モデル切り替え

```
/model <model-name>
```

引数なしで実行すると利用可能なモデル一覧を表示する。

## 自動読み込みファイル

| ファイル | 内容 |
|----------|------|
| `CLAUDE.md` | セッション手順・通信プロトコル・禁止事項 |
| `AGENTS.md` | エージェント構成 |
| `.cursor/rules/` | 追加ルール（Always Apply タイプ） |
| `.cursor/skills/` | スキル定義（起動時に自動ロード） |

## 利用可能なツール

Cursor Agent は以下のツールを提供する：

- **ファイル操作**: 読み取り・書き込み・編集
- **シェルコマンド**: ターミナルコマンドの実行
- **Web 検索**: 組み込みの検索機能
