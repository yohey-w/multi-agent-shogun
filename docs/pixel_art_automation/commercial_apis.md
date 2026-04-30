# Pixel Art 自動化ツール調査 — 商用API/CLI編

調査日: 2026-04-12
担当: 足軽4号 (subtask_079_pixelart_commercial_apis)
担当範囲: DALL-E 3 / gpt-image-1 (OpenAI)、Midjourney API、Aseprite CLI、Adobe Firefly API

> 注記: タスクYAMLの`target_path`は `/Users/mizunomakoto/Project/makotoProj/multi-agent-shogun/docs/...` と記載されていたが、当該ディレクトリは存在しないため、実在する現行リポ `/ai_accelerate/multi-agent-shogun/docs/pixel_art_automation/` に配置した。family YAML(足軽3/5)も同じ誤記あり。

---

## 1. OpenAI gpt-image-1 / gpt-image-1-mini / GPT Image 1.5

### 概要
OpenAIの統合画像生成モデル群。2026年3月時点で **GPT Image 1.5** が現行主力、**gpt-image-1** が前世代、**gpt-image-1-mini** が低コスト版。Chat Completions API・Images API・Responses API 経由で利用可能。MCP連携は公式serverなし(コミュニティ製ラッパあり)。

### API/CLI/MCP
- REST API: `POST /v1/images/generations` (標準)、`POST /v1/images/edits` (編集)
- SDK: openai-python, openai-node 公式SDK対応
- CLI: なし(`openai` CLI経由で叩ける)
- MCP: 公式なし

### コスト (1024x1024, 2026-04時点)
| モデル | 低品質 | 中品質 | 高品質 |
|---|---|---|---|
| gpt-image-1 | ~$0.02 | ~$0.07 | ~$0.19 |
| gpt-image-1-mini | $0.005〜 | — | — |
| GPT Image 1.5 | $0.009〜 | 中間 | 高値 |

JPY換算(1USD=150円): 低品質 約0.75〜3円、高品質 約28.5円/枚。

### 品質 (pixel art/icon用途)
- 自然言語で "16x16 pixel art icon, retro 8-bit" 等の指示は通るが、**ネイティブに低解像度を出すのは苦手**。1024x1024で生成→縮小→ドット化が現実的。
- プロンプト遵守性は高い(テキスト描画可)。色数制限や厳密なドット整列は未対応。
- アイコン・イラスト調の「pixel art風」なら実用域。ピクセルパーフェクトなゲーム素材は追加加工必須。

### 速度
高品質で6〜15秒/枚、miniなら2〜5秒程度(APIリージョン依存)。

### ライセンス
- 商用利用可。**OpenAIが出力の全権利をユーザーに譲渡**。
- Business/Team/API階層では **入力データの学習利用なし**(opt-out済み)。
- 販促・商品化・再販すべて許可。

### 日本語プロンプト
公式対応。英語より若干品質低下するが実務許容レベル。

### 呼び出し例 (TypeScript)

```typescript
import OpenAI from "openai";
const openai = new OpenAI();

const res = await openai.images.generate({
  model: "gpt-image-1",
  prompt: "A 16x16 pixel art icon of an amber cat, retro 8-bit style, flat colors, transparent background",
  size: "1024x1024",
  quality: "low", // low/medium/high
  n: 1,
});
// res.data[0].b64_json を保存後、sharp等で16x16にnearest-neighbor縮小
```

### 総合評価: ★★★★☆ (4/5)
- 強み: 公式・安定・商用権利クリア・日本語可・API成熟
- 弱み: ネイティブpixel art出力精度が低く、後加工パイプライン前提

---

## 2. DALL-E 3 (OpenAI — 前世代)

### 概要
2023年リリースの画像生成モデル。2026年時点でも `dall-e-3` エンドポイントは稼働中だが、OpenAIの主力はgpt-image-1/1.5系に移行。後方互換として残っている扱い。

### API/CLI/MCP
- REST API: `POST /v1/images/generations` (model="dall-e-3")
- SDK: openai公式SDK対応
- MCP: コミュニティ製のみ

### コスト
| サイズ/品質 | 価格 |
|---|---|
| 1024x1024 Standard | $0.040 |
| 1024x1024 HD | $0.080 |
| 1792x1024 / 1024x1792 HD | $0.120 |

JPY換算: 6〜18円/枚。gpt-image-1 miniより割高、高品質はgpt-image-1高品質より安い中間帯。

### 品質
- pixel artスタイル対応可、ただしgpt-image-1と同様ネイティブ低解像度は弱い。
- 2026年現在はgpt-image-1.5の方がプロンプト遵守・細部表現ともに上。新規採用する理由は薄い。

### 速度
5〜15秒/枚。

### ライセンス
gpt-image-1と同様、ユーザーに全権利譲渡。商用OK。

### 日本語プロンプト
対応。

### 呼び出し例 (curl)

```bash
curl https://api.openai.com/v1/images/generations \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "dall-e-3",
    "prompt": "16-bit pixel art treasure chest icon, top-down view, transparent background",
    "size": "1024x1024",
    "quality": "standard",
    "n": 1
  }'
```

### 総合評価: ★★★☆☆ (3/5)
- 強み: 枯れていて安定、ドキュメント豊富
- 弱み: gpt-image-1系に完全に上位互換され、新規採用の優位性なし。**既存実装の保守用途のみ推奨**

---

## 3. Midjourney API

### 概要
Midjourneyは **2026年時点で公式APIを提供していない**。全てDiscord/Webフロント経由の対話型UIのみ。開発者はサードパーティの「非公式API」で自動化するしかない。

### API/CLI/MCP
- 公式API: **なし** (REST/SDK/Webhook/API Key 一切未提供)
- 非公式API: ImagineAPI, Useapi.net, PiAPI, ApiFrame, LinkrAPI 等が存在
  - いずれもブラウザ自動化やボット経由でMidjourney UIを操作する仕組み
- MCP: なし(非公式ラッパ経由でMCP化した例は個人プロジェクトレベル)

### コスト
| 経路 | 価格 |
|---|---|
| Midjourney本体 Basic | $10/月 (~200枚) |
| Midjourney本体 Standard | $30/月 (無制限Relaxed) |
| LinkrAPI (BYO token) | +$7/月〜 |
| ImagineAPI | $30/月(無制限) |
| PiAPI | $45/月(無制限) |
| ホスト型 pay-per-image | $0.02〜0.05/枚 |

### 品質
- pixel art表現は他モデルより芸術的・やや解釈的。厳密なドット再現は不向き。
- プロンプトに "pixel art, 16-bit, retro game icon" を入れるとスタイル再現は最高水準だが、**16x16で使える素材にはならない**(高解像度イラスト調)。
- アート作品・キービジュアル用途に強い。ゲーム素材自動化には不向き。

### 速度
Fast モード 30〜60秒、Relaxed モード数分。非公式API経由ではさらに遅延あり。

### ライセンス
- 有料プラン加入者は商用利用可。**Pro以上でのみ他ユーザーから生成物を非公開化可能**。
- **非公式API利用は Midjourney ToS 違反**。アカウント凍結リスク実在。

### 日本語プロンプト
対応するが英語推奨。スタイル指示は英語の方が安定。

### 呼び出し例 (ImagineAPI, TypeScript)

```typescript
const res = await fetch("https://cl.imagineapi.dev/items/images/", {
  method: "POST",
  headers: {
    "Authorization": `Bearer ${process.env.IMAGINE_API_TOKEN}`,
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    prompt: "16-bit pixel art cat icon, retro, clean background --style raw",
  }),
});
// 非同期ジョブ。後で GET でステータス/URL取得
```

### 総合評価: ★★☆☆☆ (2/5)
- 強み: アート品質は依然トップクラス
- 弱み: **公式API無し・ToS違反リスク・pixel art用途ではコスパ悪い・自動化パイプライン組み込み不向き**

---

## 4. Aseprite CLI + 既存素材加工

### 概要
pixel art専用エディタAsepriteに搭載されたCLI。**生成はしないが、既存素材のバッチ加工・エクスポート・スプライトシート作成に最適**。1ライセンス$19.99買い切り(Steam/公式)。

### API/CLI/MCP
- CLI: `aseprite -b ...` で完全バッチ実行
- スクリプティング: Lua script API(`--script`)
- MCP: なし(シェル呼び出しで代替可)

### コスト
- 本体: $19.99 買い切り (継続費用なし)
- 生成コスト: 0 (ローカル実行)

### 主要オプション
| オプション | 機能 |
|---|---|
| `-b` / `--batch` | UI起動せずに実行(CIに必須) |
| `--save-as <file>` | 別形式で保存(PNG/GIF/JPG等) |
| `--sheet <file.png>` | スプライトシート出力 |
| `--data <file.json>` | メタデータJSON出力 |
| `--scale <N>` | 全スプライト拡大(nearest neighbor) |
| `--split-layers` | レイヤー別にファイル出力 |
| `--split-tags` | アニメーションtag別に分割 |
| `--script <lua>` | 任意Luaスクリプト実行 |

### 品質
- 純粋なピクセル整列。劣化ゼロ。
- pixel artパイプラインの**最終工程として事実上標準**。

### 速度
数百ファイルでも数秒〜。ローカルI/Oバウンド。

### ライセンス
- MIT互換(商用可)。生成/加工物の権利は完全にユーザー帰属。

### 日本語プロンプト
該当なし(プロンプトベースではない)。

### 呼び出し例 (Bash)

```bash
# .asepriteファイルをPNG+メタデータJSONに一括変換
for file in assets/*.aseprite; do
  aseprite -b "$file" \
    --save-as "build/$(basename "${file%.aseprite}").png" \
    --sheet "build/$(basename "${file%.aseprite}")_sheet.png" \
    --data "build/$(basename "${file%.aseprite}").json" \
    --sheet-pack
done

# AI生成PNGをAseprite経由で色数削減+16x16化
aseprite -b generated.png \
  --scale 0.0625 \
  --color-mode indexed \
  --save-as final_16x16.png
```

### TypeScript(execa)例

```typescript
import { execa } from "execa";
await execa("aseprite", [
  "-b", "input.png",
  "--scale", "0.0625",
  "--color-mode", "indexed",
  "--save-as", "output_16.png",
]);
```

### 総合評価: ★★★★★ (5/5)
- 強み: **pixel art業界標準・買い切り・CI/CD統合容易・劣化なし・高速**
- 弱み: 画像生成機能はなし(他ツールと組み合わせ前提)。WSL2/Linux headless環境ではXvfb等が必要な場合あり

---

## 5. Adobe Firefly API

### 概要
Adobeの生成AI。**商用安全性**を最大のセールスポイントとする(Adobe Stock + パブリックドメイン + ライセンス済みコンテンツで学習)。2025年にPhotoshop APIとFirefly APIが独立し、Firefly Servicesとして単独プラットフォーム化。

### API/CLI/MCP
- REST API: Firefly Services API (`firefly-api.adobe.io`)
- SDK: Node.js/Python SDK提供
- CLI: なし
- MCP: なし
- **エンタープライズ契約必須** (約$1,000/月 minimum commitment)

### コスト
| プラン | 月額 | 備考 |
|---|---|---|
| Firefly Standard (consumer) | $9.99/月 | 2000 credits |
| Firefly Pro | $29.99/月 | 7000 credits |
| Firefly Premium | $199.99/月 | 大規模制作者向け |
| Firefly API (enterprise) | ~$1,000/月〜 | API利用時 |

- 1枚あたり: 約$0.02〜0.10(Image 4 Ultra=20 credits消費で$0.08〜0.10)
- JPY換算: 3〜15円/枚、**ただしエンタープライズ最低コミット必須**

### 品質
- 写真調・商用イラストは非常に高品質。
- **pixel art用途は弱い**。スタイル指定は可能だが専用チューニングなく、gpt-image-1と同等かやや下。
- 強みはピクセル表現ではなく「安全に商用利用できる」点。

### 速度
5〜15秒/枚。

### ライセンス
- **商用利用安全(ウォーターマーク不要・帰属表示不要)** ※ベータ機能除く
- 学習データが権利クリア済み素材のみなので、著作権侵害リスクが他社モデル比で極小
- 生成物の権利は利用者に帰属

### 日本語プロンプト
対応。Adobe翻訳レイヤ経由で英語に変換される仕様。

### 呼び出し例 (curl)

```bash
curl -X POST https://firefly-api.adobe.io/v3/images/generate \
  -H "Authorization: Bearer $ADOBE_ACCESS_TOKEN" \
  -H "x-api-key: $ADOBE_CLIENT_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "16-bit pixel art icon, cat, flat colors, transparent background",
    "size": { "width": 1024, "height": 1024 },
    "contentClass": "art"
  }'
```

### 総合評価: ★★★☆☆ (3/5)
- 強み: **商用安全性が圧倒的**(法務リスク重視の企業向け)、Adobe CC連携
- 弱み: エンタープライズ契約必須(個人/小規模には重い)、pixel art特化能力なし

---

## 総合比較表

| ツール | 1枚コスト | pixel art適性 | 商用ライセンス | 日本語 | API公式 | 総合 |
|---|---|---|---|---|---|---|
| gpt-image-1 / 1.5 | $0.005〜0.19 | ◎(後加工前提) | ◎完全譲渡 | ○ | ◎ | ★★★★☆ |
| DALL-E 3 | $0.04〜0.12 | ○ | ◎完全譲渡 | ○ | ◎ | ★★★☆☆ |
| Midjourney | $0.02〜0.05相当 | △(芸術寄り) | △(非公式API違反) | ○ | ✕ | ★★☆☆☆ |
| Aseprite CLI | $0(買い切り$19.99) | ◎(加工特化) | ◎ | N/A | N/A | ★★★★★ |
| Adobe Firefly | $0.02〜0.10 | △ | ◎(安全性最強) | ○ | ◎(要ENT) | ★★★☆☆ |

---

## TOP1 推奨

### **Aseprite CLI + gpt-image-1-mini の二段構え**

**理由**:
1. 単独でpixel artをネイティブ生成できる商用APIは2026年時点で存在しない(Midjourneyも含め全て「pixel art風の高解像度イラスト」を返す)
2. 現実解は **「高解像度でAI生成 → Aseprite CLIで16x16/32x32に縮小・色数削減・整形」** の二段パイプライン
3. gpt-image-1-mini を使えば **1枚$0.005**(約0.75円)で試行錯誤可能、Aseprite加工はローカル無料
4. Aseprite CLIは足軽5号担当のローカル/プログラム描画パイプラインとも親和性高く、チーム内で統一工程にできる

**代替**:
- 商用安全性を最優先する法務重視案件 → Adobe Firefly
- 単体ゲーム素材の芸術的アイコン少数 → Midjourney手動(自動化は不可)
- **DALL-E 3はgpt-image-1完全上位互換のため、新規採用非推奨**

---

## Sources

- [OpenAI API Pricing](https://openai.com/api/pricing/)
- [OpenAI DALL-E & GPT Image Pricing Calculator (Apr 2026)](https://costgoat.com/pricing/openai-images)
- [DALL-E 3 Commercial Rights & Output Ownership 2026](https://terms.law/ai-output-rights/dall-e/)
- [10 Best Midjourney APIs & Their Cost (Working in 2026)](https://www.myarchitectai.com/blog/midjourney-apis)
- [Midjourney API Pricing in 2026](https://linkrapi.com/blog/midjourney-api-pricing)
- [Aseprite CLI Docs](https://www.aseprite.org/docs/cli/)
- [aseprite/docs cli.md (GitHub)](https://github.com/aseprite/docs/blob/main/cli.md)
- [Adobe Firefly API Pricing 2026](https://sudomock.com/blog/adobe-firefly-api-pricing-2026)
- [Adobe Firefly Plans](https://www.adobe.com/products/firefly/plans.html)
