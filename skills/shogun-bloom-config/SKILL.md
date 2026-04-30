---
name: shogun-bloom-config
description: >
  Interactive wizard: guided questions with multiple-choice options about subscriptions,
  then outputs a ready-to-paste capability_tiers YAML + fixed agent model assignments.
  Trigger: "capability_tiers", "bloom config", "routing setup", "set up model routing",
  "ルーティング設定", "capability_tiers設定", "モデル設定", "サブスク設定", "model routing"
---

# /shogun-bloom-config — Bloom Routing Wizard

## Overview

選択肢誘導型インタビューで2問に答えるだけで、最適な `capability_tiers` 設定を
ready-to-paste 形式で生成する。

**Output:**
1. `capability_tiers` YAML → `config/settings.yaml` にそのまま貼り付け可
2. `available_cost_groups` 宣言
3. 固定エージェント推奨モデル（Karo / Gunshi）
4. カバレッジギャップ警告（Bloom L6が対応不可の場合など）

## When to Use

- `config/settings.yaml` の初期セットアップ
- サブスク追加・変更後の再設定
- "capability_tiersってどう設定すればいい？"
- `/shogun-model-list` でモデル一覧を確認した後

---

## Instructions

**IMPORTANT: Do NOT output the pattern tables directly. Always ask questions first using AskUserQuestion.**

### Step 1: Q1 — Claude plan (AskUserQuestion)

Call AskUserQuestion with the following:

```
question: "Claudeのプランを教えてください。"
header: "Claude Plan"
options:
  - label: "Max 20x ($200/月)"
    description: "Opus・Sonnet・Haiku全モデル利用可。20倍使用量。Spark Dual運用ならコレ (Recommended)"
  - label: "Max 5x ($100/月)"
    description: "同上、5倍使用量。コスト重視で十分な量なら。"
  - label: "Pro ($20/月)"
    description: "Opus・Sonnet・Haiku利用可。使用量は標準。個人利用に十分。"
  - label: "Free / なし"
    description: "SonnetとHaikuのみ（Opus不可）。L6タスクはギャップが発生する。"
```

### Step 2: Q2 — ChatGPT plan (AskUserQuestion)

Call AskUserQuestion with the following:

```
question: "ChatGPT（OpenAI）のプランを教えてください。"
header: "ChatGPT Plan"
options:
  - label: "なし（Claude onlyで運用）"
    description: "Claude枠のみ。シンプル構成。足軽はHaiku4.5が主力。"
  - label: "Plus ($20/月)"
    description: "gpt-5.3-codex利用可（Spark不可）。L4まで補完できる。"
  - label: "Pro ($200/月)"
    description: "Spark(1000 tok/s, Terminal-Bench 58.4%) + gpt-5.3(77.3%)利用可。足軽7体の最強構成 (Recommended)"
```

### Step 2.5: Q3 — Rate limit preference (両方契約の場合のみ)

**Q1=Pro/Max かつ Q2=Plus または Pro の場合のみ聞く。**
両方のサブスクが使える場合、同じBloomレベルをどちらのクォータで処理するか確認する。

#### Q3a: L3タスク（量産コード生成・テンプレート適用）の優先クォータ

Call AskUserQuestion with:

```
question: "L1-L3タスク（量産・テンプレート・簡単な実装）はどちらのクォータを優先しますか？"
header: "L3クォータ優先"
options:
  - label: "ChatGPT Pro (Spark / gpt-5.3) 優先 (Recommended)"
    description: "Spark 1000 tok/s で爆速処理。Claude Max枠を温存してL5-L6に集中。"
  - label: "Claude Max (Haiku 4.5) 優先"
    description: "Claude枠を均等利用。ChatGPT Pro枠を節約してL4に余裕を持たせる。"
```

#### Q3b: L4タスク（分析・コードレビュー・デバッグ）の優先クォータ — Q2=Pro の場合のみ

Call AskUserQuestion with:

```
question: "L4タスク（分析・デバッグ・コードレビュー）はどちらのクォータを優先しますか？"
header: "L4クォータ優先"
options:
  - label: "ChatGPT Pro (gpt-5.3-codex) 優先 (Recommended)"
    description: "Terminal-Bench 77.3%。Codex Pro枠を活用してClaude枠を温存。"
  - label: "Claude Max (Sonnet 4.6) 優先"
    description: "SWE-bench 79.6%。Claude品質でL4も処理。ChatGPT Pro枠をSparkに集中。"
```

これらの回答に応じて capability_tiers の max_bloom 値を調整する（下記パターンのカスタム節を参照）。

### Step 3: Map answers to pattern

| Claude | ChatGPT | Pattern |
|--------|---------|---------|
| なし/Free | なし | A-Free |
| Pro/Max | なし | A |
| なし/Free | Plus | B |
| なし/Free | Pro | C |
| Pro/Max | Plus | D |
| Pro/Max | Pro | **E (Full Power)** |

### Step 4: Output the matching pattern below

Output ONLY the matching pattern. Show:
1. 簡単な説明（なぜこの設定か）
2. `capability_tiers` YAML（コピー可能なコードブロック）
3. `available_cost_groups`
4. 固定エージェント推奨
5. ギャップ警告（あれば）
6. 次のステップ

---

## Pattern A-Free — Claude Free のみ

> Sonnet 4.6 と Haiku 4.5 が使えるが Opus 4.6 は不可。L6 タスクはL5品質で処理される。

### 固定エージェント

| エージェント | 推奨モデル | 備考 |
|------------|-----------|------|
| Karo (家老) | `claude-sonnet-4-6` | Opusは使えないのでSonnet |
| Gunshi (軍師) | `claude-sonnet-4-6` | 同上 |

### `config/settings.yaml` snippet

```yaml
available_cost_groups:
  - claude_max

capability_tiers:
  claude-haiku-4-5-20251001:
    max_bloom: 3       # L1-L3: $1/$5/M, SWE-bench 73.3%
    cost_group: claude_max
  claude-sonnet-4-6:
    max_bloom: 5       # L4-L5: $3/$15/M, SWE-bench 79.6%, 1M context
    cost_group: claude_max
```

### カバレッジ

| Bloom | モデル | 備考 |
|-------|-------|------|
| L1–L3 | Haiku 4.5 | 速い・安い |
| L4–L5 | Sonnet 4.6 | 分析・設計評価 |
| **L6** | ⚠️ **GAP** | Opus 4.6 不可。L5品質で代替処理される。 |

---

## Pattern A — Claude Pro/Max のみ ($20–$200/月)

> Claude Opusまで全モデル利用可。足軽はHaiku(L1-L3)→Sonnet(L4-L5)→Opus(L6)で自動ルーティング。

### 固定エージェント

| エージェント | 推奨モデル | 備考 |
|------------|-----------|------|
| Karo (家老) | `claude-sonnet-4-6` | L4-L5オーケストレーション。Opusは過剰。 |
| Gunshi (軍師) | `claude-opus-4-6` | L5-L6の深いQC・アーキテクチャ評価 |

### `config/settings.yaml` snippet

```yaml
available_cost_groups:
  - claude_max

capability_tiers:
  claude-haiku-4-5-20251001:
    max_bloom: 3       # L1-L3: $1/$5/M, SWE-bench 73.3% — 量産タスク主力
    cost_group: claude_max
  claude-sonnet-4-6:
    max_bloom: 5       # L4-L5: $3/$15/M, SWE-bench 79.6%, 1M context
    cost_group: claude_max
  claude-opus-4-6:
    max_bloom: 6       # L6: $5/$25/M, SWE-bench 80.8% — 真の創造タスクのみ
    cost_group: claude_max
```

### カバレッジ

| Bloom | モデル | 備考 |
|-------|-------|------|
| L1–L3 | Haiku 4.5 | SWE-bench 73.3%、Sonnet 4.5比▲4pp、コスト1/3 |
| L4–L5 | Sonnet 4.6 | SWE-bench 79.6%、数学+27pt (vs Sonnet 4.5) |
| L6 | Opus 4.6 | SWE-bench 80.8%。Sonnetと1.2pp差。真のL6のみ推奨 |

---

## Pattern B — ChatGPT Plus のみ ($20/月)

> Spark は使えない。gpt-5.3-codex が主力。L6 ギャップあり。Claude なし構成はコスパが低い。

### 固定エージェント

> Claude サブスクなし → Karo/Gunshi も Codex モデル使用。L6 ギャップに注意。

| エージェント | 推奨モデル |
|------------|-----------|
| Karo (家老) | `gpt-5.3-codex` |
| Gunshi (軍師) | `gpt-5.1-codex-max` |

### `config/settings.yaml` snippet

```yaml
available_cost_groups:
  - chatgpt_plus

capability_tiers:
  gpt-5-codex-mini:
    max_bloom: 2       # L1-L2: 軽量タスク専用
    cost_group: chatgpt_plus
  gpt-5.3-codex:
    max_bloom: 4       # L3-L4: Terminal-Bench 77.3%
    cost_group: chatgpt_plus
  gpt-5.1-codex-max:
    max_bloom: 5       # L5: 最高Codexモデル
    cost_group: chatgpt_plus
```

### カバレッジ

| Bloom | モデル | 備考 |
|-------|-------|------|
| L1–L2 | codex-mini | 最小クォータ消費 |
| L3–L4 | gpt-5.3-codex | |
| L5 | codex-max | |
| **L6** | ⚠️ **GAP** | Codex は新規創造設計タスクに不適。Claude Opus 推奨。 |

---

## Pattern C — ChatGPT Pro のみ ($200/月)

> Spark (1000 tok/s) 使用可。L6 ギャップは残る。Claude も加えると完全構成に。

### 固定エージェント

| エージェント | 推奨モデル |
|------------|-----------|
| Karo (家老) | `gpt-5.3-codex` |
| Gunshi (軍師) | `gpt-5.1-codex-max` |

### `config/settings.yaml` snippet

```yaml
available_cost_groups:
  - chatgpt_pro

capability_tiers:
  gpt-5.3-codex-spark:
    max_bloom: 3       # L1-L3: 1000+ tok/s — 足軽7体でも余裕のスループット
    cost_group: chatgpt_pro
  gpt-5.3-codex:
    max_bloom: 4       # L4: Terminal-Bench 77.3%, 400K+ context
    cost_group: chatgpt_pro
  gpt-5.1-codex-max:
    max_bloom: 5       # L5: 最高Codex capability
    cost_group: chatgpt_pro
```

### カバレッジ

| Bloom | モデル | 備考 |
|-------|-------|------|
| L1–L3 | **Spark** | Cerebras製。Codex枠と独立クォータ。 |
| L4 | gpt-5.3-codex | |
| L5 | codex-max | |
| **L6** | ⚠️ **GAP** | L6 は Claude Opus 4.6 必須。 |

---

## Pattern D — Claude Pro/Max + ChatGPT Plus ($40–$220/月)


> Claude が高品質担当 (L4+)。Codex Plus がL1-L4の量産をカバー。Spark 不可。

### 固定エージェント

| エージェント | 推奨モデル |
|------------|-----------|
| Karo (家老) | `claude-sonnet-4-6` |
| Gunshi (軍師) | `claude-opus-4-6` |

### `config/settings.yaml` snippet

```yaml
available_cost_groups:
  - claude_max
  - chatgpt_plus

capability_tiers:
  gpt-5-codex-mini:
    max_bloom: 2       # L1-L2: Claude枠節約。Codex Plusクォータを消費。
    cost_group: chatgpt_plus
  gpt-5.3-codex:
    max_bloom: 4       # L3-L4: Terminal-Bench 77.3%
    cost_group: chatgpt_plus
  claude-sonnet-4-6:
    max_bloom: 5       # L5: Claude品質のアーキテクチャ評価
    cost_group: claude_max
  claude-opus-4-6:
    max_bloom: 6       # L6: 創造・戦略タスク
    cost_group: claude_max
```

### カバレッジ

| Bloom | モデル | 備考 |
|-------|-------|------|
| L1–L2 | codex-mini | Codex Plus枠を消費してClaude Max節約 |
| L3–L4 | gpt-5.3-codex | |
| L5 | Sonnet 4.6 | Claude品質に切り替わる |
| L6 | Opus 4.6 | |

---

## Pattern E — Claude Pro/Max + ChatGPT Pro ($220–$400/月) ⭐ Full Power

> **最強構成**。Spark で L1-L3 を爆速処理、Claude で L4-L6 を高品質処理。
> 月 $400（Claude Max 20x + ChatGPT Pro）で全 Bloom をフルカバー。

### 固定エージェント

| エージェント | 推奨モデル | 理由 |
|------------|-----------|------|
| Karo (家老) | `claude-sonnet-4-6` | L4-L5オーケストレーション。SWE-bench 79.6% |
| Gunshi (軍師) | `claude-opus-4-6` | L5-L6深いQC。SWE-bench 80.8% |

### Q3a×Q3b の回答別 config

#### E-1: Spark優先 (L3) × Codex優先 (L4) ← **デフォルト推奨**

> Claude Max枠をL5-L6に集中。ChatGPT Pro枠でL1-L4を高速処理。

```yaml
available_cost_groups:
  - claude_max
  - chatgpt_pro

capability_tiers:
  gpt-5.3-codex-spark:
    max_bloom: 3       # L1-L3: 1000+ tok/s — ChatGPT Pro枠でL1-L3を高速処理
    cost_group: chatgpt_pro
  claude-haiku-4-5-20251001:
    max_bloom: 3       # L1-L3: Claude枠フォールバック（Spark枠切れ時に自動切替）
    cost_group: claude_max
  gpt-5.3-codex:
    max_bloom: 4       # L4: Terminal-Bench 77.3% — Codex Pro枠をL4にも活用
    cost_group: chatgpt_pro
  claude-sonnet-4-6:
    max_bloom: 5       # L5: SWE-bench 79.6%, 1M context
    cost_group: claude_max
  claude-opus-4-6:
    max_bloom: 6       # L6: SWE-bench 80.8%
    cost_group: claude_max
```

#### E-2: Spark優先 (L3) × Sonnet優先 (L4)

> L4もClaude品質で処理。ChatGPT Pro枠をSparkに集中させる。

```yaml
available_cost_groups:
  - claude_max
  - chatgpt_pro

capability_tiers:
  gpt-5.3-codex-spark:
    max_bloom: 3       # L1-L3: 1000+ tok/s — ChatGPT Pro枠をSparkに集中
    cost_group: chatgpt_pro
  claude-haiku-4-5-20251001:
    max_bloom: 3       # L1-L3: Claude枠フォールバック
    cost_group: claude_max
  claude-sonnet-4-6:
    max_bloom: 5       # L4-L5: SWE-bench 79.6% — L4もClaude品質
    cost_group: claude_max
  claude-opus-4-6:
    max_bloom: 6       # L6: SWE-bench 80.8%
    cost_group: claude_max
```

#### E-3: Haiku優先 (L3) × Codex優先 (L4)

> L3はClaude枠で処理してChatGPT Pro枠をL4のgpt-5.3に温存する。

```yaml
available_cost_groups:
  - claude_max
  - chatgpt_pro

capability_tiers:
  claude-haiku-4-5-20251001:
    max_bloom: 3       # L1-L3: SWE-bench 73.3% — Claude枠でL3を処理
    cost_group: claude_max
  gpt-5.3-codex-spark:
    max_bloom: 2       # L1-L2のみ: Sparkは補助的に使用（L3はHaikuへ）
    cost_group: chatgpt_pro
  gpt-5.3-codex:
    max_bloom: 4       # L4: Terminal-Bench 77.3% — ChatGPT Pro枠をL4に集中
    cost_group: chatgpt_pro
  claude-sonnet-4-6:
    max_bloom: 5       # L5
    cost_group: claude_max
  claude-opus-4-6:
    max_bloom: 6       # L6
    cost_group: claude_max
```

#### E-4: Haiku優先 (L3) × Sonnet優先 (L4)

> L1-L5を全てClaude枠で処理。ChatGPT Pro枠は節約（Spark補助的使用のみ）。

```yaml
available_cost_groups:
  - claude_max
  - chatgpt_pro

capability_tiers:
  gpt-5.3-codex-spark:
    max_bloom: 2       # L1-L2補助: Sparkで超軽量タスクのみ処理
    cost_group: chatgpt_pro
  claude-haiku-4-5-20251001:
    max_bloom: 3       # L1-L3: Claude枠で統一処理
    cost_group: claude_max
  claude-sonnet-4-6:
    max_bloom: 5       # L4-L5: Claude品質でL4も処理
    cost_group: claude_max
  claude-opus-4-6:
    max_bloom: 6       # L6
    cost_group: claude_max
```

### カバレッジ（E-1基準）

| Bloom | モデル | 速度/品質 |
|-------|-------|----------|
| L1–L3 | **Spark** → Haiku(フォールバック) | 1000 tok/s。枠切れ時に自動切替 |
| L4 | gpt-5.3-codex | Codex Pro枠フル活用 |
| L5 | Sonnet 4.6 | Claude品質。Opusとの差1.2ptで1/5価格 |
| L6 | Opus 4.6 | 真の創造タスクのみ投入 |

> **コスト最適化のポイント**: Spark と gpt-5.3 は独立クォータ。両方を同時最大利用可能。
> L5 は Opus でなく Sonnet 4.6 で十分（SWE-bench差1.2%、価格差約1.7倍: $3/$15 vs $5/$25/M）。

---

## Step 5: 設定の適用手順

出力したYAMLの後に、以下の適用手順を必ず案内する:

**1. `config/settings.yaml` を開く**

```yaml
# available_cost_groups と capability_tiers を貼り付け
available_cost_groups:
  - ...   ← ここに貼り付け

capability_tiers:
  ...:    ← ここに貼り付け
```

**2. 固定エージェントのモデルを更新**

```yaml
cli:
  agents:
    karo:
      type: claude
      model: claude-sonnet-4-6     # ← Karo推奨モデルに変更
    gunshi:
      type: claude
      model: opus                  # ← Gunshi推奨モデルに変更
    ashigaru1:                     # ← 足軽はcapability_tiersに従って自動ルーティング
      type: codex                  #    CLIの種類はサブスクに合わせて設定
      model: gpt-5.3-codex-spark
```

**3. bloom_routing の有効化（オプション）**

```yaml
bloom_routing: "manual"   # "off"(無効) → "manual"(手動) → "auto"(全自動)
```

**4. 設定の検証（ターミナルで）**

```bash
# subscription coverage チェック（カバーできないBloomレベルを検出）
source lib/cli_adapter.sh && validate_subscription_coverage
```

---

## Quick Decision Tree

```
Claude Pro以上を契約している?
  Yes → 固定エージェント(Shogun/Karo/Gunshi)にClaudeが使える ✓
  No  → Codexのみ。L6ギャップに注意 ⚠️

ChatGPT Pro ($200) を契約している?
  Yes → Spark (L1-L3, 1000 tok/s) + gpt-5.3 (L4) が使える ✓
  Plus ($20) → gpt-5.3 (L3-L4) のみ。Spark不可。
  なし → Claude Haikuが足軽のL1-L3を担当
```
