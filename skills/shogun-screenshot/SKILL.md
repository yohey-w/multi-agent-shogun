---
name: shogun-screenshot
description: |
  スクリーンショットの取得・加工を行う。ローカルスクショから最新画像を取得、
  PlaywrightでWebページをキャプチャ、画像のトリミング・リサイズ、機微情報を黒塗りマスキング。
  記事執筆、レポート作成、UI確認、画像加工時に起動。
  「スクショ」「スクリーンショット」「画面キャプチャ」「最新のスクショ」「画像加工」「トリミング」「マスク」「写メ」「写メ撮った」「スクショ撮った」で起動。
  Do NOT use for: 画像生成（shogun-imagegenを使え）。
argument-hint: "[url-or-target e.g. https://example.com, latest]"
allowed-tools: Bash, Read
---

# /shogun-screenshot - スクリーンショット取得・加工スキル

## North Star（全判断の最上位基準）

このスキルの北極星は**記事・報告書のビジュアル品質向上によるコンテンツ差別化**。
高品質な画像（マスク済み・適切にトリミング済み）を記事・レポートに挿入することで、
テキスト単体の競合コンテンツとの差別化を実現する。

## Input

`$ARGUMENTS` = 操作対象の指定（URLまたはモードキーワード）

- URL（`https://...`）→ Mode 2: Webキャプチャ
- `latest`（省略可）→ Mode 1: ローカルスクショ取得
- 引数なし → ユーザーの意図に応じて最適なモードを選択

## Overview

スクリーンショットの取得・加工を行う。4つのモードがある:

1. **ローカル取得**: ユーザーのスクショフォルダから最新画像を取得
2. **Webキャプチャ**: URLを指定してPlaywright MCPでページをキャプチャ
3. **トリミング**: 既存画像の一部を切り出し・リサイズ
4. **マスキング**: 機微情報（APIキー、個人情報等）を黒塗り

## When to Use

- 「最新のスクショを見せて」「スクショ取って」と言われた時
- 記事やレポートに画像を挿入する時
- UI画面のキャプチャが必要な時
- 画像のトリミング・切り出しが必要な時
- スクショ内の機密情報をマスクする時

## Configuration

スクショフォルダのパスは `config/settings.yaml` で管理（優先順の配列）:

```yaml
screenshot:
  paths:
    - "/path/to/your/Screenshots/"      # OS のスクショ保存先
    - "queue/screenshots/"               # モバイルアプリ等からの受信先
  capture_dir: "images/"                 # Webキャプチャの保存先
  trim_dir: "images/trimmed/"            # トリミング後の保存先
```

`paths` 配列を上から順に探索し、ディレクトリが存在＋画像ファイルがあるものを使う。
全パスが存在しない場合はエラーを返す。

## Instructions

### Mode 1: ローカルスクショ取得（複数パスフォールバック）

**手順**:
1. config/settings.yaml から `screenshot.paths` 配列を読む
2. **優先順に各パスを探索**:
   a. `ls <path>` でディレクトリ存在を確認（存在しなければ次へ）
   b. 存在するパスで `ls -lt <path>/*.png <path>/*.jpg 2>/dev/null | head -5` で最新画像を取得
3. 最も新しい画像ファイルを Read ツールで表示
4. 複数パスに画像がある場合、**全パスの最新を比較して最も新しいもの**を表示

**ヘルパースクリプト** (全パスを自動探索):
```bash
bash skills/shogun-screenshot/scripts/capture_local.sh -n 3
```

**手動で特定パスを指定する場合**:
```bash
# config/settings.yaml の screenshot.paths に設定されたパスを使用
ls -lt "/path/to/Screenshots/"*.png 2>/dev/null | head -3
```

**注意**: ディレクトリ自体が存在しない可能性がある（ドライブ未マウント等）。
`2>/dev/null` で存在しないパスのエラーを抑制すること。

### Mode 2: Webキャプチャ（Playwright MCP）

1. Playwright MCP の `playwright_navigate` でURLに遷移
2. `playwright_screenshot` でキャプチャ
   - fullPage: true（ページ全体）
   - selector: 指定（要素のみ）
   - savePng: true, downloadsDir: 保存先
3. 保存されたPNGのパスを返す

### Mode 3: トリミング

1. 対象画像のパスを受け取る
2. Python (PIL/Pillow) でトリミング実行
3. トリミング後の画像を保存

```bash
python3 skills/shogun-screenshot/scripts/trim_image.py \
  --input /path/to/image.png \
  --output /path/to/trimmed.png \
  --crop "x1,y1,x2,y2"
```

オプション: `--resize "width,height"` でリサイズも同時に行える。

### Mode 4: 機微情報マスキング

スクショ内のAPIキー、トピック名、個人情報等を矩形で黒塗りする。

```bash
# 単一領域
python3 skills/shogun-screenshot/scripts/mask_sensitive.py \
  --input /path/to/image.png \
  --output /path/to/masked.png \
  --regions "100,50,400,80"

# 複数領域
python3 skills/shogun-screenshot/scripts/mask_sensitive.py \
  --input /path/to/image.png \
  --output /path/to/masked.png \
  --regions "100,50,400,80" "500,200,800,230"

# 位置確認（赤枠プレビュー、塗りつぶさない）
python3 skills/shogun-screenshot/scripts/mask_sensitive.py \
  --input /path/to/image.png \
  --output /path/to/preview.png \
  --regions "100,50,400,80" --preview
```

オプション:
- `--color "R,G,B"` — 塗りつぶし色（デフォルト: 黒 `0,0,0`）
- `--preview` — 赤枠表示のみ（塗りつぶさない。座標確認用）

**手順**:
1. Read ツールで画像を確認し、マスクすべき領域を特定
2. `--preview` で座標が正しいか確認
3. プレビューOKなら `--preview` を外して実行

## Guidelines

- APIキーや認証情報を画像に含めないよう注意。公開前に必ず Mode 4 でマスキング
- Playwright MCPが利用不可の場合は、ローカルモードのみで動作
- 大量のスクショを一度に処理する場合は、バッチ処理スクリプトを使用
- トリミング・マスキング座標は左上(0,0)基準のピクセル値
- 保存先のデフォルト: プロジェクトの images/ ディレクトリ
