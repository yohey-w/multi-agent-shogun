# Pixel Art 自動化ツール — 統合ガイド

**cmd_079統合 / 調査日: 2026-04-12** — 足軽3・4・5号による3軸調査完了

---

## 調査範囲と報告

本ガイドは、pixel art自動化のための**実行可能な実装パターン**を3つの観点から調査・統合したもの。

| 調査軸 | 担当 | 成果物 | TOP1 |
|---|---|---|---|
| **SD系・Pixel art特化モデル** | 足軽3号 | [`sd_family.md`](./sd_family.md) | PixelLab.ai ★★★★★ |
| **商用API・CLI** | 足軽4号 | [`commercial_apis.md`](./commercial_apis.md) | Aseprite CLI + gpt-image-1-mini ★★★★★ |
| **ローカル・プログラム描画** | 足軽5号 | [`local_programmatic.md`](./local_programmatic.md) | Pillow (Python) ★★★★★ |

---

## 全体TOP3ランキング (用途別推奨)

### 🥇 第1位: Pillow (Python)

**総合評価: ★★★★★**

**理由:**
- **実績あり**: cmd_078で琥珀色猫アイコン(16/48/128px)生成済み（パターン再利用可能）
- **Python統合**: Shogun/Karo全体がPython主体 → 直接呼び出し可能
- **16pxでも高品質**: size別再描画パターン確立済み(劣化なし)
- **ランニングコスト0円**: セットアップ1分のみ

**推奨シナリオ:**
- Chrome拡張のアイコン自動生成
- CLIツールのfavicon/icon群生成
- Shogun内部でのアイコン/図形描画

**呼び出し例 (Python):**
```python
from PIL import Image, ImageDraw

def make_pixel_icon(size, description, color):
    """シンプルなプログラム描画ベース"""
    img = Image.new('RGBA', (size, size), (0,0,0,0))
    d = ImageDraw.Draw(img)
    # スケール係数で解像度非依存設計
    p = lambda x: round(x * size / 128)
    d.ellipse([p(24), p(24), p(104), p(104)], fill=color)
    return img
```

---

### 🥈 第2位: PixelLab.ai API

**総合評価: ★★★★★**

**理由:**
- **MCP対応**: Claude/Cursor から自然言語で直接呼び出し可能
- **用途網羅**: 静止画/アニメ/タイルセット/inpaint がAPI1本で完結
- **透明なコスト**: $0.007〜$0.016/枚で予算見積が容易
- **商用ライセンス明快**: 有料プランでフル商用化可能

**推奨シナリオ:**
- ゲームアセット大量生成 (複雑なキャラ/敵/アイテム)
- Aseprite直接連携が必要な制作フロー
- エージェント→MCP経由の自動呼び出し

**呼び出し例 (MCP経由):**
```yaml
# settings.json
"mcpServers": {
  "pixellab": {
    "command": "python",
    "args": ["-m", "pixellab_mcp"]
  }
}
```

---

### 🥉 第3位: Aseprite CLI + gpt-image-1-mini

**総合評価: ★★★★☆**

**理由:**
- **現実的2段パイプライン**: 高解像度AI生成 → 16x16に縮小・色数削減がpixel art標準
- **コスト効率**: gpt-image-1-mini ($0.005/枚 ≈ 0.75円) + Aseprite買い切り($19.99)
- **業界標準**: Aseprite CLIは pixel art制作の事実上スタンダード
- **足軽5号パイプラインと親和**: local_programmatic調査結果と相互補完

**推奨シナリオ:**
- AI生成品のPNG→sprite化・色数削減が必要な場合
- 複数ツールの出力を統一品質に揃える最終工程
- 既存Aseprite資産がある制作チーム

**呼び出し例 (Bash):**
```bash
# 1. gpt-image-1-miniで生成
curl https://api.openai.com/v1/images/generations \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d '{
    "model": "gpt-image-1-mini",
    "prompt": "16-bit pixel art icon, mage character, transparent bg",
    "size": "1024x1024"
  }' | jq '.data[0].b64_json' | base64 -d > temp.png

# 2. Aseprite CLIで16x16化
aseprite -b temp.png \
  --scale 0.0625 \
  --color-mode indexed \
  --save-as final_icon_16x16.png
```

---

## 統合方針: 3軸ハイブリッド運用

単一ツールではなく、**用途ごとに3軸を使い分ける設計**を推奨:

| 用途 | 第一選択 | 第二選択 | 理由 |
|---|---|---|---|
| **単純アイコン(16x16)** | Pillow | — | 実績・速度・統合容易 |
| **複雑キャラドット絵** | PixelLab.ai | Retro Diffusion | 品質・MCP対応 |
| **既存PNG整形** | Aseprite CLI | Sharp | 業界標準・買い切り |
| **プロトタイピング** | gpt-image-1-mini | DALL-E 3 | コスト・速度 |

---

## エージェント呼び出し統合案

### 案1: Pythonスクリプト化 (軽量・現実的)

```python
# pixel_art_automation.py
import subprocess
import json
from enum import Enum

class PixelArtMode(Enum):
    PILLOW_ICON = "pillow_icon"        # シンプルアイコン
    PIXELLAB_ASSET = "pixellab_asset"  # ゲームアセット
    ASEPRITE_CONVERT = "aseprite_convert"  # 既存PNG整形

def generate_pixel_art(mode: str, prompt: str, size: int = 16) -> str:
    """
    pixel art生成の統一インターフェース
    Returns: output_png_path
    """
    if mode == PixelArtMode.PILLOW_ICON:
        # cmd_078パターン流用
        from generate_icons import make_icon
        return make_icon(size, prompt)
    
    elif mode == PixelArtMode.PIXELLAB_ASSET:
        # MCP経由またはAPI直呼び出し
        return call_pixellab_api(prompt, size)
    
    elif mode == PixelArtMode.ASEPRITE_CONVERT:
        return subprocess.run([
            "aseprite", "-b", prompt,
            "--scale", "0.0625",
            "--save-as", f"output_{size}x{size}.png"
        ])

# 呼び出し
path = generate_pixel_art("pillow_icon", "amber_cat_16px", size=16)
```

**メリット**:
- Python統合: shogunシステムから直接import可能
- 柔軟性: 各軸の実装詳細を隠蔽可能
- 保守性: 新ツール追加時に関数追加するだけ

---

### 案2: MCPサーバ化 (エージェント統一)

PixelLab.ai MCPを中核に、Pillow/Aseprite-CLIもMCPラッパで統一:

```yaml
"mcpServers": {
  "pixel_art": {
    "command": "python",
    "args": ["multi_tool_mcp.py"],
    "env": {
      "PIXELLAB_KEY": "...",
      "OPENAI_KEY": "..."
    }
  }
}
```

**メリット**:
- 全エージェント統一インターフェース
- Claude/Cursor からも自然言語で呼び出し可能
- 選択肢を「tool use」で表現

**デメリット**:
- MCP実装コスト (中程度)

---

### 案3: cURL直接呼び出し (シンプル)

各ツール固有のAPI/CLIを、タスク描述時に直接指定:

```yaml
task:
  id: pixel_art_gen_001
  type: pillow_icon
  params:
    size: 16
    description: "amber cat icon"
    output_path: "./assets/cat.png"
```

**メリット**:
- 最小限の中間層
- デバッグが直結

**デメリット**:
- エージェント側で各ツール仕様を把握する必要あり

---

## 推奨: **案1 + 案2の段階的導入**

1. **短期(2週間)**: 案1でPython関数化 → Shogun/Karo から呼び出し開始
2. **中期(1ヶ月)**: PixelLab.ai MCP設定 → 複雑アセット用途で並用
3. **長期**: 統合MCPサーバ検討 (複数プロジェクト横断時)

---

## サンプルディレクトリ構成

生成物を格納するディレクトリ:

```
docs/pixel_art_automation/
├── README.md (本ガイド)
├── sd_family.md
├── commercial_apis.md
├── local_programmatic.md
├── samples/ ← 実装例・テスト生成物格納先
│   ├── cmd_078_amber_cat_16x16.png (実績)
│   ├── pixellab_test_mage.png (テスト)
│   └── aseprite_pipeline_example.png
└── README_research.md ← 詳細リンク集
```

---

## 次のステップ

- [ ] **Pillow統合**: cmd_078パターンを汎用化 → `pixel_art_utils.py` 作成
- [ ] **PixelLab.ai MCP**: 実装・テスト (オプション高優先度)
- [ ] **CI/CDパイプライン**: Chrome拡張ビルド時のアイコン自動生成設定
- [ ] **コスト追跡**: 月次 OpenAI/PixelLab API使用額の予算集計

---

## 出典

- [`sd_family.md`](./sd_family.md) — 足軽3号調査
- [`commercial_apis.md`](./commercial_apis.md) — 足軽4号調査
- [`local_programmatic.md`](./local_programmatic.md) — 足軽5号調査
- cmd_078: `chrome_extensions/cat-stroll/generate_icons.py` (Pillow実績)

