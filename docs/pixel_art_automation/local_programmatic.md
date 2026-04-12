# Pixel Art 自動化ツール調査 — ローカル / プログラム描画編

**cmd_079 / 足軽5号担当範囲**: ローカルComfyUI+MCP、Sharp、ImageMagick、Pillow、Emoji→PNGドット化
調査日: 2026-04-12 / 参考事例: cmd_078 `chrome_extensions/cat-stroll/generate_icons.py`（Pillowで琥珀色猫アイコン16/48/128px生成、実績あり）

> **注**: タスクYAMLの `target_path` は `/Users/mizunomakoto/Project/makotoProj/multi-agent-shogun/docs/...` だったが当該ディレクトリが存在しなかったため、実在する `ai_accelerate/multi-agent-shogun/docs/pixel_art_automation/` に配置した。

---

## 1. ローカル ComfyUI + MCP 連携

### 概要
ComfyUI本体（Stable Diffusion系のノードベースWF実行エンジン）をローカルで起動し、MCPサーバ経由でAIエージェントから画像生成を依頼する構成。代表実装は以下。

| 実装 | 種別 | 特徴 |
|---|---|---|
| `lalanikarim/comfy-ui` (PulseMCP掲載) | Python MCP server | ComfyUIへWebSocket接続、WF JSON切替対応 |
| `joenorton/comfyui-mcp-server` (mcp.so) | 同上 | prompt/width/height/modelを動的上書き |
| `jonpojonpo/comfy-ui` (PulseMCP掲載) | 同上 | 軽量版 |
| `jerryscription/mcp-pixel-paint` (LobeHub) | 独立MCP | 最大1000×1000キャンバスにpixel/line/rect/flood fill。16色パレット＋hex。SD不使用の純描画系 |
| `docs.comfy.org` 公式 MCP | Comfy Cloud | 公式クラウド連携 |

Pixel Art専用LoRA（`nerijs/pixel-art-xl` 等）＋ComfyUI WFで16×16〜64×64のドット絵が生成可能（kokutech.com, inzaniak blog, OpenArt "Pixel Art Workflow" 参照）。

### API・CLI・MCP対応状況
- MCPツール呼び出し（`generate_image(prompt, workflow, width, height)` 相当）からWebSocket経由でComfyUIに投入
- CLI単体は `python main.py` でローカル起動 → HTTP API `/prompt` も利用可
- MCP経由なら Claude / Cline / 本shogunシステムから直接呼び出し可能

### コスト
- セットアップ: ComfyUI本体 + Pixel Art XL LoRA + MCPサーバで **1〜3時間**
- マシン負荷: VRAM **6GB以上推奨**（SDXL系は12GB推奨）。M2 Mac/RTX 3060以上が実用線
- 金銭コスト: **ゼロ**（電気代のみ）

### 品質（pixel art/icon用途）
- Pixel Art XL LoRA + NearestNeighbor downscale で **高品質なキャラクタードット絵**が得られる。16×16では細部がつぶれがちなので32×32生成→ニアレスト縮小が定石
- アイコン用途（cat-strollのような単色主体の単純ロゴ）は **過剰スペック**。プロンプト揺れで再現性が落ちる
- `mcp-pixel-paint` のプリミティブ描画系は再現性◎だがクリエイティビティ低

### 速度
- SDXL + LoRA: 1枚 **5〜15秒**（RTX 4070級、20 steps）
- `mcp-pixel-paint` 系: **即時**（ただし生成AI要素なし）

### ライセンス
- ComfyUI: GPL-3.0 / ノード個別は各MIT/Apache
- Pixel Art XL LoRA: CreativeML Open RAIL-M（商用可、出力物の権利はユーザー）
- MCPサーバ実装: MIT系多数

### 呼び出し例（MCP経由、概念コード）
```yaml
# Claude側 settings.json
"mcpServers": {
  "comfyui": {
    "command": "python",
    "args": ["-m", "comfyui_mcp_server"],
    "env": {"COMFY_URL": "ws://127.0.0.1:8188"}
  }
}
```
```text
# エージェントから
tool: comfyui.generate_image
args: { prompt: "pixel art cat icon, amber fur, 16x16", workflow: "pixel_art_xl.json", width: 512, height: 512 }
→ 出力PNGを512で受けて nearest で 16x16 に落とす
```

### 総合評価: ★★★☆☆（3/5）
**強み**: クリエイティブなキャラドット絵 / ローカル完結 / ランニングコストゼロ
**弱み**: セットアップ重い、16pxアイコンには過剰、再現性がSeed依存
**推奨シナリオ**: 敵キャラ/アイテムアイコンを量産したいゲーム系。cat-strollのような単純ブランドアイコンには非推奨。

---

## 2. Sharp (Node.js) によるプログラム描画

### 概要
libvipsベースの高速画像処理Node.jsライブラリ。ピクセル単位操作はraw Buffer経由で可能だが、**描画プリミティブ（line/polygon等）は持たない**。pixel配列を自前で組み立てるか、SVG→PNGラスタライズで対処するのが主流。

### API・CLI・MCP対応状況
- npm: `sharp`（lovell/sharp、週間DL 1000万超）
- CLI: なし（Node.jsスクリプト経由）
- MCP: 専用なし。Node製自作MCPから呼べる

### コスト
- セットアップ: `npm i sharp` のみ（**5分**）
- マシン負荷: 極軽量、CLIバッチ可

### 品質
- raw Bufferで1px単位制御可→**完全な再現性**
- SVGを入力にすればベクター描画の全機能が使える（`{input: svgBuffer}` → PNG出力）
- `kernel: 'nearest'` で pixel art縮小OK

### 速度
- 16×16生成＋PNG書き出し: **< 10ms/枚**
- 100枚バッチ: **1秒未満**

### ライセンス
- Apache-2.0（商用OK、派生物の権利もユーザー）

### 呼び出し例
```js
// ピクセル配列直接指定（16x16 amber dot）
import sharp from 'sharp';
const W = 16, H = 16;
const buf = Buffer.alloc(W * H * 4);
for (let i = 0; i < W * H; i++) {
  buf.set([255, 165, 40, 255], i * 4);
}
await sharp(buf, { raw: { width: W, height: H, channels: 4 } })
  .png().toFile('icon16.png');

// SVG→PNG（複雑形状）
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128">
  <circle cx="64" cy="64" r="40" fill="#FFA528"/></svg>`;
await sharp(Buffer.from(svg))
  .resize(16, 16, { kernel: 'nearest' })
  .png().toFile('icon16.png');
```

### 総合評価: ★★★★☆（4/5）
**強み**: 圧倒的速度 / 既存Node資産と統合容易 / SVG経由でベクター描画も可
**弱み**: プリミティブ描画API不在（SVGかraw buffer頼み）
**推奨シナリオ**: Chrome拡張ビルド時のアイコン自動生成、CIでのファビコン量産。

---

## 3. ImageMagick による CLI 描画

### 概要
200+フォーマット対応の老舗画像処理。`magick` CLI一本で描画・変換・ICO多重化まで完結。

### API・CLI・MCP対応状況
- CLI: `magick` (v7) / `convert` (v6 legacy)
- Node/Python: `gm`, `wand` バインディング
- MCP: 専用なし（自作可）

### コスト
- セットアップ: `brew install imagemagick` / `apt install imagemagick`（**2分**）
- 負荷: 軽量

### 品質
- `-filter Point` で縮小時のエッジ保持（pixel art向け）
- 描画プリミティブ（circle/polygon/text）を直接記述可能
- ICOマルチサイズ生成ネイティブ対応（16+32+48を1ファイルに）

### 速度
- 単発変換 **数十ms**、Pillowより若干速い〜同等

### ライセンス
- ImageMagick License（Apache-2.0類似、商用OK）

### 呼び出し例
```bash
# 1. 大きく描いて nearest で16pxに落とす
magick -size 128x128 xc:none \
  -fill "#FFA528" -draw "circle 64,64 64,24" \
  -filter Point -resize 16x16 icon16.png

# 2. 多解像度ICO一発生成
magick icon.png \
  \( -clone 0 -resize 16x16 \) \
  \( -clone 0 -resize 32x32 \) \
  \( -clone 0 -resize 48x48 \) \
  -delete 0 favicon.ico
```

### 総合評価: ★★★★☆（4/5）
**強み**: シェル一行で完結 / ICO/ICNS多重化が強力 / 依存追加なし
**弱み**: スクリプト言語から呼ぶと引数組立が冗長 / 複雑描画はSVGの方が楽
**推奨シナリオ**: Makefile/CIで favicon・Chrome拡張icon群を生成、Bashだけで完結したい時。

---

## 4. Pillow (Python) ベース 16×16 生成 ★cmd_078実績★

### 概要
Python標準の画像処理。`ImageDraw` で円・矩形・多角形・線・テキスト等のプリミティブ描画、`Image.resize(..., NEAREST)` でピクセルパーフェクト縮小。

### 実績（cmd_078）
`chrome_extensions/cat-stroll/generate_icons.py` で **琥珀色猫アイコン16/48/128px** を一括生成。head/ear/eye/nose/whisker/tail/paw を `ellipse/polygon/line` で構成、scale factor `p(x) = round(x * s / 128)` で解像度非依存の設計。**sizeごとに描き直す**（resize依存しない）方式で16pxでも潰れない。→ この設計思想は再利用すべき。

### API・CLI・MCP対応状況
- PyPI: `Pillow`（12.x系 2026現在）
- CLI: なし（Pythonスクリプト）
- MCP: 専用なし
- 補助: `pilmoji`（2026-01リリース）でUnicode emoji描画

### コスト
- セットアップ: `pip install Pillow`（**1分**）
- 負荷: 軽量

### 品質
- 16pxで**LANCZOSは使わずNEARESTまたはサイズ別に直接描画**が鉄則（検索結果の2026ベストプラクティスでも一致）
- cmd_078実績: 16pxでも形状が保たれる設計パターンが確立済み

### 速度
- 16×16 1枚 **< 20ms**、100枚 **< 1秒**

### ライセンス
- MIT-CMU（商用OK）

### 呼び出し例（cmd_078パターン簡略版）
```python
from PIL import Image, ImageDraw
def make_icon(size, color=(255,165,40,255)):
    img = Image.new('RGBA', (size, size), (0,0,0,0))
    d = ImageDraw.Draw(img)
    p = lambda x: round(x * size / 128)
    d.ellipse([p(24), p(24), p(104), p(104)], fill=color)
    return img
for s in (16, 48, 128):
    make_icon(s).save(f'icon{s}.png')
```

### 総合評価: ★★★★★（5/5）
**強み**: cmd_078で実績済み / Python資産と統合容易 / 描画プリミティブ完備 / Sizeごと再描画で16pxも美しい / Shogunシステム全体がPython主体なら自然
**弱み**: Node環境ではsubprocess経由
**推奨シナリオ**: Chrome拡張・CLIツールのアイコン自動生成すべて。**本系譜で最優先推奨**。

---

## 5. Emoji → PNG → ドット化（劣化版・最終手段）

### 概要
`pilmoji`等でUnicode emoji (🐱, 🔥 等) をPNG化 → NEARESTで縮小 or 量子化して16×16ドット絵化。

### API・CLI・MCP対応状況
| ツール | 用途 |
|---|---|
| `pilmoji` (PyPI, 2026-01リリース) | Pillow上でemoji描画 |
| `Pixel-Art-Emoji` (dratinyy/GitHub) | emoji_grid.pngを個別PNGへ分割 |
| `pic2emoji` / `Emojifier` | 画像→emojiモザイク（逆方向） |

### コスト
- セットアップ: `pip install pilmoji`（**1分**）
- 負荷: 極軽量

### 品質
- **劣化あり**: emoji画像はもともと多色・アンチエイリアス前提の絵文字。16pxへnearestすると潰れる
- パレット統一不可、ブランドアイコンとしての統一感に欠ける
- 著作権: emoji画像そのものはApple/Google/Microsoft等の権利物。Twemoji（CC-BY 4.0）/ OpenMoji（CC-BY-SA 4.0）なら商用利用可

### 速度
- 1枚 **< 100ms**

### ライセンス
- pilmoji: MIT
- **出力物のライセンスは使うemojiフォントに依存**（Appleエモジ使用→商用NG、Twemoji→表示義務つきでOK）

### 呼び出し例
```python
from pilmoji import Pilmoji
from PIL import Image
img = Image.new('RGBA', (128, 128), (0,0,0,0))
with Pilmoji(img) as p:
    p.text((0, 0), '🐱', (0,0,0), font=...)
img.resize((16, 16), Image.NEAREST).save('cat16.png')
```

### 総合評価: ★★☆☆☆（2/5）
**強み**: プロンプト/描画コード不要、絵文字指定だけで即完成
**弱み**: 16pxで潰れる / ブランド統一感なし / フォントライセンス要確認
**推奨シナリオ**: プロトタイピング・一時的placeholder・社内ツールのみ。**本番アイコンには非推奨**。

---

## 総合評価サマリー

| 手段 | ★ | セットアップ | 速度 | 品質 | コスト | 16pxアイコン適性 |
|---|---|---|---|---|---|---|
| **Pillow (Python)** | **★★★★★** | 1分 | <20ms | 実績あり | 0円 | ◎ (cmd_078実証) |
| Sharp (Node.js) | ★★★★ | 5分 | <10ms | 高 | 0円 | ◎ (Node環境時) |
| ImageMagick CLI | ★★★★ | 2分 | 数十ms | 高 | 0円 | ○ (ICOマルチ強) |
| ComfyUI + MCP | ★★★ | 1-3時間 | 5-15秒 | キャラ絵に◎ | 0円(VRAM要) | △ (過剰) |
| Emoji→PNG | ★★ | 1分 | <100ms | 低 | 0円 | × (劣化) |

## TOP1 推奨: **Pillow (Python)**

**理由**:
1. cmd_078 `generate_icons.py` で本システム内に**実証済みの資産**あり。パターン(size別再描画 + `p(x)=round(x*s/128)`スケーリング)をコピペ再利用できる
2. Shogunシステム自体Python主体。足軽/家老からsubprocess不要で直接呼べる
3. 16pxアイコンで潰れない設計パターンが確立済み
4. 描画プリミティブ完備でSharpのような「SVG迂回」不要

**サブ推奨（シーン別）**:
- Node専用プロジェクト → **Sharp**
- Bash/Makefile完結したい → **ImageMagick**
- キャラドット絵量産 → **ComfyUI + Pixel Art XL LoRA**（別用途）

---

## 出典 (Sources)

- [ComfyUI MCP Server by Karim Lalani | PulseMCP](https://www.pulsemcp.com/servers/lalanikarim-comfy-ui)
- [MCP Pixel Paint | LobeHub](https://lobehub.com/mcp/jerryscription-mcp-pixel-paint)
- [ComfyUI MCP Server | mcp.so](https://mcp.so/server/comfyui-mcp-server/joenorton)
- [ComfyUI公式 MCP Server](https://docs.comfy.org/development/cloud/mcp-server)
- [How to Use ComfyUI & Pixel-Art-XL to Generate Pixel Art Sprites | kokutech](https://www.kokutech.com/blog/gamedev/tips/art/pixel-art-generation-with-comfyui)
- [The Pixel Art ComfyUI Workflow Guide | inzaniak](https://inzaniak.github.io/blog/articles/the-pixel-art-comfyui-workflow-guide.html)
- [Pixel Art Workflow | OpenArt](https://openart.ai/workflows/megaaziib/pixel-art-workflow/09EGyt3ZOBM9kD4ZZGP5)
- [sharp - High performance Node.js image processing](https://sharp.pixelplumbing.com/)
- [lovell/sharp GitHub](https://github.com/lovell/sharp)
- [Pixel Editing in Node.js with Sharp | ShillehTek](https://shillehtek.com/blogs/news/pixel-editing-in-node-js-with-sharp-step-by-step)
- [Data-Pixels | gmattie GitHub](https://github.com/gmattie/Data-Pixels)
- [ImageMagick | Command-line Tools: Convert](https://imagemagick.org/script/convert.php)
- [How to Resize Pixel Art on the Command Line | Ryan Kubik](https://ryankubik.com/blog/resize-pixel-art-command-line)
- [ImageMagick multi-resolution favicon.ico gist (nateware)](https://gist.github.com/nateware/900d2d09f4884ac0c073)
- [Image Processing With the Python Pillow Library | Real Python](https://realpython.com/image-processing-with-the-python-pillow-library/)
- [Generate Web Icons In Python With Pil | Kinsa Creative](https://blog.kinsacreative.com/articles/generate-web-icons-with-pil/)
- [Pillow (PIL Fork) 12.2.0 Documentation](https://pillow.readthedocs.io/en/stable/handbook/concepts.html)
- [pilmoji | PyPI](https://pypi.org/project/pilmoji/)
- [Pixel-Art-Emoji | dratinyy GitHub](https://github.com/dratinyy/Pixel-Art-Emoji)
- [Emoji Mosaic Art | scientific-python blog](https://blog.scientific-python.org/matplotlib/emoji-mosaic-art/)
