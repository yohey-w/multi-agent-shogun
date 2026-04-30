# Pixel Art 自動化ツール調査 — SD系・Pixel art特化モデル

調査日: 2026-04-12 / 担当: 足軽3号 / 親タスク: cmd_079

担当範囲: Stable Diffusion系(SDXL, FLUX, Replicate API)、Pixel art特化モデル
(PixelLab.ai, Scenario.gg, Retro Diffusion)、pixel art用LoRAの現状。
担当外: DALL-E/Midjourney等(足軽4号) / ComfyUI/ImageMagick等(足軽5号)。

---

## 1. Stable Diffusion XL (SDXL) + pixel art LoRA

- **概要**: Stability AI のオープンウェイトモデル。pixel art はベース単体ではやや苦手、
  Civitai 配布の LoRA(例: `Pixel Art XL` / `Pixel Art SDXL RW` / `Pixel Art Diffusion XL`)
  を重ねることで実用レベル。
- **API/CLI/MCP**: Stability Developer Platform(REST API)、Replicate、fal.ai、Runware 等から
  利用可。MCP サーバは非公式実装が多数。
- **コスト**: Stability API は $0.01/credit〜。Replicate は GPU 秒課金(SDXL 1枚 ≈ $0.002〜0.01)。
  年商 $1M 未満は Community License で自己ホスト無料。
- **品質(pixel art用途)**: LoRA 併用で ★★★★☆。素の SDXL は ★★。
  512×512 → nearest-neighbor 縮小 + 量子化の後処理が必須。
- **速度**: SDXL base + LoRA で1枚 2〜4秒(A100)。Replicate/fal 経由で体感 5〜10秒。
- **ライセンス**: CreativeML Open RAIL++-M(商用可、有害生成禁止)。生成物の権利は生成者。
  LoRA は配布者ごとに異なる(Civitai 個別確認)。
- **日本語プロンプト**: 直接非対応。英訳してから投入するのが標準。
- **呼び出し例 (Replicate, curl)**:
  ```bash
  curl -s -X POST https://api.replicate.com/v1/predictions \
    -H "Authorization: Bearer $REPLICATE_API_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "version": "stability-ai/sdxl:<version_hash>",
      "input": {
        "prompt": "pixel art, 16-bit rpg, mage character sprite, front view <lora:pixel-art-xl:1.0>",
        "width": 512, "height": 512, "num_inference_steps": 25
      }
    }'
  ```
- **総合評価**: ★★★★☆ — 柔軟性とコストは最強。ただし後処理とプロンプト工学の手間あり。

## 2. FLUX (Black Forest Labs)

- **概要**: SDXL 後継世代。テキストレンダリングと構図理解が強い。pixel art 特化ではないが、
  FLUX LoRA(例 `Pixel game assets [FLUX]`, `Pixel Art Styles FluxV3`)で対応可。
- **API**: Black Forest Labs 公式(bfl.ai)、fal.ai、Replicate。FLUX.2 系統
  (klein 4B/9B, flex, pro, max)が 2026 時点の主力。
- **コスト**: fal.ai で $0.03〜0.08/枚(モデル依存)。FLUX.2 pro/max は bfl.ai ダッシュボードで確認要。
- **品質(pixel art用途)**: LoRA 併用で ★★★★☆。素は SDXL+LoRA と同等〜やや上。
- **速度**: fal/bfl で 1枚 3〜8秒。
- **ライセンス**:
  - `FLUX.1-schnell`: Apache 2.0 (商用可、最も自由)
  - `FLUX.1-dev`: 非商用ウェイト(商用は別契約)
  - `FLUX.1-pro` / `FLUX.2`: API 経由のみ、商用可(bfl 利用規約準拠)
- **日本語プロンプト**: 英語優位。日本語もある程度解するが品質は落ちる。
- **呼び出し例 (fal.ai, TypeScript)**:
  ```ts
  import { fal } from "@fal-ai/client";
  fal.config({ credentials: process.env.FAL_KEY });
  const res = await fal.subscribe("fal-ai/flux-lora", {
    input: {
      prompt: "pixel art sprite, 16-bit, wizard casting fire",
      loras: [{ path: "https://civitai.com/.../pixel-art-flux.safetensors", scale: 1.0 }],
      image_size: { width: 512, height: 512 },
      num_inference_steps: 28,
    },
  });
  ```
- **総合評価**: ★★★★☆ — 品質最上位クラスだが、pixel art 用途では SDXL より割高になりがち。

## 3. Retro Diffusion (Astropulse)

- **概要**: アーティスト設計の pixel art 特化モデル。`RD Plus` / `Tile` / `Animation` の3系列。
  生成物が真の pixel art (色数制御、シャープエッジ、後処理不要)として出るのが強み。
- **API/CLI/MCP**: Replicate (`retro-diffusion/rd-plus`)、Scenario.gg 連携、自社 Web アプリ、Aseprite 連携。
  公式 MCP は未確認。Runware 経由でも提供。
- **入力パラメータ**: width/height、palette 指定、背景除去、tileable、strength(img2img)。
- **コスト**: Replicate は GPU 秒課金(公開ページに固定単価記載なし。体感1枚 $0.003〜0.008)。
  自社アプリはクレジット制(月額プラン $5〜)。
- **品質(pixel art用途)**: ★★★★★。素出しで後処理ほぼ不要。カラーパレット指定に対応。
- **速度**: 1枚 1〜3秒(Replicate A100)。
- **ライセンス**: 商用利用可(有料プラン/API 契約内)。Itch 版はユーザー単位のライセンス。
- **日本語プロンプト**: 英語前提。短いキーワード中心でよいので影響は小さい。
- **呼び出し例 (Replicate, curl)**:
  ```bash
  curl -s -X POST https://api.replicate.com/v1/predictions \
    -H "Authorization: Bearer $REPLICATE_API_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "version": "retro-diffusion/rd-plus:latest",
      "input": {
        "prompt": "knight sprite, side view, idle pose",
        "width": 64, "height": 64, "tileable": false, "remove_background": true
      }
    }'
  ```
- **総合評価**: ★★★★★ — pixel art 専用途では現状最強。自動化パイプラインへの組込が一番素直。

## 4. PixelLab.ai

- **概要**: インディーゲーム開発者向け pixel art 特化 SaaS。キャラ/アニメ/タイルセットまで
  プログラマブル生成。Aseprite プラグインと MCP サーバ(`pixellab-code/pixellab-mcp`)を公式提供。
- **API**: `https://api.pixellab.ai/v2/docs`。エンドポイント例:
  `/generate-image-pixflux`, `/generate-image-bitforge`, `/inpaint`, `/rotate`,
  `/animate-skeleton`, `/estimate-skeleton`。
- **コスト(2026-04 時点)**:
  | 機能 | 単価(USD) |
  |---|---|
  | Pixflux 画像生成 (64×64〜400×400) | $0.00793〜$0.0132 |
  | Bitforge 画像生成 (32×32〜200×200) | $0.0071〜$0.01122 |
  | Inpaint | $0.00716〜$0.01122 |
  | Rotate | $0.01057〜$0.01091 |
  | Skeleton アニメ | $0.0136〜$0.01572 |
  - 無料枠: 40 fast + 日5 slow(〜200×200)。
  - サブスク: Pixel Apprentice $12/月(〜320×320、アニメ/マップ機能)。
- **品質**: ★★★★★ (スプライト/タイルセット)。構造化された pixel 出力に強い。
- **速度**: 1〜3秒/枚。
- **ライセンス**: 有料プランで商用可、生成物の著作権はユーザー帰属(許諾不要)。
- **日本語プロンプト**: 公式ドキュメントに明記なし。英語推奨。
- **呼び出し例 (curl)**:
  ```bash
  curl -s -X POST https://api.pixellab.ai/v2/generate-image-pixflux \
    -H "Authorization: Bearer $PIXELLAB_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{
      "description": "fox warrior, side view, 64x64",
      "image_size": {"width": 64, "height": 64},
      "no_background": true
    }'
  ```
- **MCP 呼び出し例**: `pixellab-code/pixellab-mcp` を `mcp.servers` に追加し、
  Claude/Cursor から自然言語で `generate-image-pixflux` を呼べる。
- **総合評価**: ★★★★★ — API+MCP+Aseprite の3経路が揃い、エージェント連携が最も楽。
  ゲームアセット用途なら第一候補。

## 5. Scenario.gg (Retro Diffusion Plus ホスト)

- **概要**: ゲームアセット生成プラットフォーム。Retro Diffusion Plus/Tile/Animation を含む
  多数のスタイル特化モデルをホストし、自前 LoRA 学習も可能。
- **API/CLI**: REST API(`docs.scenario.com`)、Zapier 連携。`dryRun=true` で事前コスト試算可。
- **コスト**:
  - Starter $19/月: private generator、API アクセス、一定クレジット。
  - Pro $99/月: unlimited generator、高クレジット、Zapier、優先サポート。
  - Enterprise: 見積。
  - 実行課金: step 数 × ピクセル次元 × 後処理(upscale 等)でクレジット消費。
- **品質**: ★★★★★(Retro Diffusion Plus 経由の pixel art)。
- **速度**: 2〜5秒/枚。
- **ライセンス**: 全有料プランでフル商用ライセンス(販売/クライアント納品可、ロイヤリティなし)。
- **日本語プロンプト**: 英語推奨。
- **呼び出し例 (curl)**:
  ```bash
  curl -s -X POST https://api.cloud.scenario.com/v1/generate/txt2img \
    -H "Authorization: Basic $SCENARIO_BASIC_AUTH" \
    -H "Content-Type: application/json" \
    -d '{
      "modelId": "retro-diffusion-plus",
      "prompt": "pixel art, 32x32 potion icon, transparent background",
      "width": 32, "height": 32, "numInferenceSteps": 30
    }'
  ```
- **総合評価**: ★★★★☆ — 自前 LoRA 学習したいチーム向け。個人/軽量用途は Retro Diffusion 直/Replicate 経由のほうが安価。

## 6. Pixel art用 LoRA の現状 (2026-04)

- **配布拠点**: Civitai が事実上の標準。pixel art タグで 479 モデル超。
- **SDXL 向け代表作**:
  - `Pixel Art XL` (v1.1) — 汎用、軽量。
  - `Pixel Art SDXL RW` — 解像度維持とエッジ品質。
  - `Pixel Art Diffusion XL` (Sprite Shaper) — チェックポイント(LoRA ではなく full ckpt)。
- **FLUX 向け代表作**:
  - `Pixel game assets [FLUX] by Dever` — ゲームアセット特化。
  - `Pixel Art Styles FluxV3` — MidJourney 学習ベースの pixel スタイル。
- **商用利用**: ベースモデルのライセンス(SDXL=RAIL++-M, FLUX.1-dev=非商用, schnell=Apache2)
  に加え、LoRA 個別のライセンスを Civitai ページで必ず確認。
- **組込パターン**: Replicate `sdxl-lora-explorer` や fal `flux-lora` エンドポイントに
  Civitai の .safetensors URL を渡すだけで呼べる。

## 7. 比較サマリと TOP1 推奨

| ツール | 品質 | コスト | 速度 | 自動化容易性 | 総合 |
|---|---|---|---|---|---|
| SDXL + LoRA | ★★★★ | ★★★★★ | ★★★ | ★★★ | ★★★★ |
| FLUX + LoRA | ★★★★☆ | ★★★ | ★★★ | ★★★ | ★★★★ |
| Retro Diffusion | ★★★★★ | ★★★★ | ★★★★★ | ★★★★ | ★★★★★ |
| PixelLab.ai | ★★★★★ | ★★★★ | ★★★★ | ★★★★★ | ★★★★★ |
| Scenario.gg | ★★★★★ | ★★ | ★★★★ | ★★★★ | ★★★★ |

### TOP1 推奨: **PixelLab.ai**

理由:
1. **エージェント連携**: 公式 MCP サーバあり。Claude/Cursor から自然言語で直接呼べる唯一の選択肢。
2. **透明なコスト**: 1リクエスト $0.007〜$0.016 と単価明示。予算見積が容易。
3. **商用ライセンス明快**: 有料プランで即商用可、生成物の権利ユーザー帰属。
4. **用途網羅**: 静止画/アニメ/タイルセット/回転/inpaint まで単一 API で完結。

### 次点: **Retro Diffusion (Replicate 経由)**

- LoRA 不要で素出し品質最高。
- PixelLab が対応しないアート寄り(1枚絵、ポスター的 pixel art)は Retro Diffusion が上。
- MCP は未提供なので Replicate API を直接叩く自動化になる。

### コスト最優先: **SDXL + LoRA (Replicate)**

- 月数千枚規模の大量生成なら自己ホスト or Replicate が最安。
- 後処理(量子化・nearest neighbor 縮小)の自作が必要。

---

## 付記: タスクYAML の出力パス誤記について

タスク指定: `/Users/mizunomakoto/Project/makotoProj/multi-agent-shogun/docs/pixel_art_automation/sd_family.md`
実在リポ: `/Users/mizunomakoto/Project/makotoProj/ai_accelerate/multi-agent-shogun/`

指定パスは存在しないため、実在する ai_accelerate/multi-agent-shogun リポ配下に作成した。
