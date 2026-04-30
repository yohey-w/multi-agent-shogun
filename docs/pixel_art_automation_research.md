# Pixel Art 自動化ツール研究 — 統合ガイド

**cmd_079** — 足軽3・4・5号による3軸調査 + 足軽7号による統合
**調査完了日**: 2026-04-12

---

## 📚 調査報告書

本研究は pixel art自動化の**実装パターン**を3つの専門軸で調査し、各軸のTOP1ツール、コスト、統合方針をまとめたもの。

### 調査軸別報告書

1. **[SD系・Pixel art特化モデル](./pixel_art_automation/sd_family.md)** — 足軽3号
   - Stable Diffusion / FLUX / Retro Diffusion / PixelLab.ai / Scenario.gg
   - **TOP1**: PixelLab.ai ★★★★★ (API+MCP+Aseprite統合)

2. **[商用API・CLI](./pixel_art_automation/commercial_apis.md)** — 足軽4号
   - OpenAI gpt-image-1 / DALL-E 3 / Midjourney / Aseprite CLI / Adobe Firefly
   - **TOP1**: Aseprite CLI + gpt-image-1-mini ★★★★★ (2段パイプライン)

3. **[ローカル・プログラム描画](./pixel_art_automation/local_programmatic.md)** — 足軽5号
   - ComfyUI+MCP / Sharp / ImageMagick / Pillow / Emoji→PNG
   - **TOP1**: Pillow (Python) ★★★★★ (cmd_078実績あり)

---

## 🎯 全体TOP3ランキング

### 🥇 第1位: **Pillow (Python)**
- **総合評価**: ★★★★★
- **シーン**: Chrome拡張アイコン、CLIツールfavicon、内部図形描画
- **セットアップ**: 1分 / **コスト**: $0
- **詳細**: [ローカル・プログラム描画](./pixel_art_automation/local_programmatic.md#4-pillow-python-ベース-16×16-生成-cmd078実績)

### 🥈 第2位: **PixelLab.ai API**
- **総合評価**: ★★★★★
- **シーン**: ゲームアセット大量生成（複雑キャラ/敵）、MCP統合
- **セットアップ**: 10分 / **コスト**: $0.007〜$0.016/枚
- **詳細**: [SD系・Pixel art特化モデル](./pixel_art_automation/sd_family.md#4-pixellaiai)

### 🥉 第3位: **Aseprite CLI + gpt-image-1-mini**
- **総合評価**: ★★★★☆
- **シーン**: 既存PNG整形、16x16化・色数削減パイプライン
- **セットアップ**: 5分 / **コスト**: $19.99 + $0.005/枚
- **詳細**: [商用API・CLI](./pixel_art_automation/commercial_apis.md#4-aseprite-cli--既存素材加工) + [local_programmatic](./pixel_art_automation/local_programmatic.md#2-sharp-nodejs-によるプログラム描画)

---

## 🔗 統合ガイド

### 推奨実装パターン

**[pixel_art_automation/README.md](./pixel_art_automation/README.md)** — 統合ガイド
- 3軸ハイブリッド運用方針
- エージェント呼び出し統合案（Python/MCP/curl）
- 推奨: **案1 (Python関数化) + 案2 (MCP段階的導入)**

---

## 📦 サンプル & 成果物

```
docs/
├── pixel_art_automation_research.md ← 本ファイル (エントリーポイント)
└── pixel_art_automation/
    ├── README.md (統合ガイド)
    ├── sd_family.md (調査報告書1)
    ├── commercial_apis.md (調査報告書2)
    ├── local_programmatic.md (調査報告書3)
    └── samples/ (生成テスト物格納先)
        ├── cmd_078_amber_cat_16x16.png
        └── .gitkeep
```

---

## 💾 コミット情報

| 軸 | 担当 | commit | TOP1 |
|---|---|---|---|
| SD系 | 足軽3号 | 8dd9250 | PixelLab.ai ★★★★★ |
| 商用API | 足軽4号 | 5f43276 | Aseprite CLI + gpt-image-1-mini ★★★★★ |
| ローカル | 足軽5号 | 9852808 | Pillow ★★★★★ |

---

## 🚀 次のステップ

1. **Pillow統合** (優先度: 🔴高)
   - cmd_078 `generate_icons.py` を汎用化 → `pixel_art_utils.py`
   - Shogun/Karo から直接import可能に

2. **PixelLab.ai MCP** (優先度: 🟡中)
   - 複雑アセット用途で並用開始
   - エージェント統一インターフェース

3. **CI/CD統合** (優先度: 🟡中)
   - Chrome拡張ビルド時のアイコン自動生成

4. **コスト追跡** (優先度: 🟢低)
   - 月次 OpenAI/PixelLab API使用額集計

---

## 参考資料

### 詳細報告書
- [`sd_family.md`](./pixel_art_automation/sd_family.md) — Stable Diffusion / FLUX / Retro Diffusion / PixelLab.ai / Scenario.gg
- [`commercial_apis.md`](./pixel_art_automation/commercial_apis.md) — OpenAI gpt-image / DALL-E / Midjourney / Aseprite / Adobe Firefly
- [`local_programmatic.md`](./pixel_art_automation/local_programmatic.md) — ComfyUI / Sharp / ImageMagick / Pillow / Emoji

### 実装参考
- cmd_078: [`chrome_extensions/cat-stroll/generate_icons.py`](../../chrome_extensions/cat-stroll/) — Pillow実装実績(琥珀色猫16/48/128px)

---

**Status**: ✅ 調査完了 / 統合ガイド確定 / 実装フェーズへ準備完了

