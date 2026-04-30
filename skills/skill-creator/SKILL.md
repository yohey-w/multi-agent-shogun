---
name: skill-creator
description: |
  Claude Codeスキル（SKILL.md）の設計・作成・バリデーション・レビュー。
  Anthropic公式ガイド(2026-03)準拠。新規スキル作成、既存スキルの改善、
  description品質チェック、トリガーテスト設計に使用。
  「スキル作って」「スキル設計」「SKILL.md作成」「スキルレビュー」で起動。
  Do NOT use for: スキルの実行・呼び出し（それは各スキル自体が行う）。
argument-hint: "[skill-name or description]"
---

# Skill Creator — Claude Code Skills Design & Generation v2.0

Anthropic公式 "The Complete Guide to Building Skills for Claude" (2026-03) に完全準拠。
Agent Skills Open Standard (agentskills.io) にも対応し、Claude Code以外のAIツールでも動作するスキルを設計する。

## North Star

**再利用可能で高品質なスキルを最短で設計・作成すること。**
スキルの価値 = 発火精度 × 出力品質 × 保守性。

## Frontmatter Reference（全フィールド）

```yaml
---
# === 必須フィールド ===
name: skill-name              # kebab-case, max 64 chars. 省略時はディレクトリ名
                               # "claude" / "anthropic" を含む名前は禁止（予約語）
description: |                 # 【最重要】発火判断の唯一の材料。1024文字以内
  What + When を明記。トリガーワードを含める。
  ネガティブトリガー（Do NOT use for...）で誤発火防止。

# === 任意フィールド ===
argument-hint: "[target]"      # 補完時のヒント表示。引数ありスキル用
disable-model-invocation: false # true = 手動 /name でのみ起動（副作用あるスキル向け）
user-invocable: true           # false = /メニュー非表示（背景知識スキル向け）
allowed-tools: Read, Grep, Bash # 許可ツール。指定すると制限にもなる。省略=全ツール継承
model: sonnet                  # スキル実行時のモデル指定（省略=親から継承）
context: fork                  # fork = サブエージェントで隔離実行
agent: general-purpose         # fork時のエージェント種別: Explore, Plan, general-purpose
license: MIT                   # OSSスキル用。MIT, Apache-2.0 等
compatibility: |               # 環境要件（1-500文字）
  Claude Code + tmux + WSL2
metadata:                      # カスタムメタデータ
  author: your-name
  version: 1.0.0
  mcp-server: server-name      # MCP連携スキル用
hooks:                         # スキル内フック定義
  PostToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: "./scripts/lint.sh"
---
```

### Frontmatter セキュリティ制約

- XML角括弧 `< >` **禁止**（プロンプトインジェクション防止）
- `name`に "claude" / "anthropic" は使用禁止（予約語）
- フロントマターはシステムプロンプト内に展開される → 悪意あるコンテンツは危険

## Description設計（最重要 — 発火品質を決める）

descriptionはClaude Codeが「このスキルを使うか否か」を判断する**唯一の材料**。
本文は発火判定に使われない。**1024文字以内**。

### 構造: `[What] + [When] + [Negative trigger]`

```yaml
# Good — 具体的、トリガーあり、ネガティブトリガーあり
description: |
  Figmaデザインファイルを分析し、開発者向けハンドオフドキュメントを生成。
  .figファイルアップロード時、「デザインスペック」「コンポーネント文書」
  「デザインからコードへ」と言われた時に起動。
  Do NOT use for: 一般的な画像処理やUI設計（interface-designスキルを使え）。

# Bad — 曖昧、トリガーなし
description: ドキュメント処理
```

### 7項目チェックリスト

| # | チェック | 悪い例 | 良い例 |
|---|---------|-------|-------|
| 1 | What: 何をするか明記 | "ドキュメント処理" | "PDFからテーブルを抽出しCSVに変換" |
| 2 | When: いつ使うか明記 | (なし) | "データ分析ワークフローで使用" |
| 3 | トリガーワード含有 | (なし) | "「記事QC」「バリデーション」で起動" |
| 4 | 具体的なアクション動詞 | "管理する" | "抽出・変換・検証する" |
| 5 | 長さ: 1024文字以内 | 1単語 or 長すぎ | 2-3文で概要+トリガー+除外 |
| 6 | 既存スキルと差別化 | 他スキルと被る | 独自の守備範囲を明示 |
| 7 | ネガティブトリガー | なし（誤発火リスク） | "Do NOT use for: ..." |

### Descriptionデバッグ手法

発火しない場合、Claudeに聞け：
> 「When would you use the [skill-name] skill?」

Claudeがdescriptionを引用して答える。足りない要素が見える。

## 3つのユースケースカテゴリー

スキル設計前に、どのカテゴリーか特定する：

| カテゴリ | 用途 | 例 |
|---------|------|-----|
| **1. Document & Asset Creation** | 成果物生成（PDF, コード, 記事等） | shogun-seo-writer |
| **2. Workflow Automation** | ステップバイステップの自動化 | shogun-git-release |
| **3. MCP Enhancement** | MCPツール+ワークフロー知識 | shogun-github-reviewer |

## 5つの設計パターン

### Pattern 1: Sequential Workflow（順序付き処理）
ステップ間に依存関係あり。各ステップにバリデーション + 失敗時ロールバック。

### Pattern 2: Multi-Service Coordination（複数サービス連携）
フェーズ分離 + データ受け渡し + フェーズ間バリデーション。

### Pattern 3: Iterative Refinement（品質ループ）
生成 → 検証スクリプト → 改善 → 再検証。品質閾値で停止。

### Pattern 4: Context-aware Selection（条件分岐）
コンテキストに応じてツール/手法を動的選択。判断理由をユーザーに説明。

### Pattern 5: Domain Intelligence（専門知識埋め込み）
ドメイン固有ルールをロジックに組み込む。コンプライアンス・監査証跡。

## Dynamic Features（動的機能）

### 引数置換

```
/my-skill 結婚 kekkon
```
- `$ARGUMENTS` → `結婚 kekkon`（全引数）
- `$0` → `結婚`（第1引数）
- `$1` → `kekkon`（第2引数）

`$ARGUMENTS` を本文で使わない場合、末尾に自動追加される。

### 動的コンテキスト `!`command``

スキル読み込み前にシェルコマンドを実行し、結果を埋め込む：

```markdown
## 現在のブランチ
!`git branch --show-current`

## 最近のコミット
!`git log --oneline -5`
```

## Execution Patterns（実行パターン）

### Pattern A: インライン実行（デフォルト）
メイン会話内で直接実行。ガイドライン型・短いタスク向け。

### Pattern B: Fork実行（隔離）
`context: fork` でサブエージェント実行。重い処理・大量出力向け。
**注意**: ガイドラインだけのスキルにforkを使うな。サブエージェントには明確なタスクが必要。

### Pattern C: 手動専用（副作用あり）
`disable-model-invocation: true` でClaude自動発火を禁止。/name でのみ起動。

## File Structure（ファイル構成）

```
~/.claude/skills/skill-name/
├── SKILL.md              # 必須。5,000語（約500行）以内。case-sensitive
├── scripts/              # 任意。バリデーション等の実行スクリプト
├── references/           # 任意。詳細なAPI仕様・ルール集
├── assets/               # 任意。テンプレート、フォント、アイコン
└── examples/             # 任意。入出力サンプル
```

### 命名規則
- フォルダ名: **kebab-case**（`notion-project-setup` ✅ / `Notion_Setup` ❌）
- `SKILL.md` は大文字小文字厳密（`skill.md` ❌ / `SKILL.MD` ❌）
- **README.md禁止**（スキルフォルダ内）。ドキュメントはSKILL.md or references/に

### Progressive Disclosure（3層構造）

| 層 | 内容 | 読み込みタイミング |
|---|------|-----------------|
| L1 | YAML frontmatter | **常時**（システムプロンプト内） |
| L2 | SKILL.md本文 | スキル関連と判断された時 |
| L3 | references/, scripts/ | 必要に応じてClaudeが参照 |

SKILL.md本体は**5,000語以内**。詳細はreferences/に分離。

## テスト戦略（3領域）

### 1. Triggering Test（発火テスト）
```
Should trigger:
- "新しいスキルを作りたい"
- "SKILL.mdのレビュー"
- "スキル設計して"

Should NOT trigger:
- "スキルを実行して"
- "天気教えて"
- "コード書いて"
```

### 2. Functional Test（機能テスト）
- 正しい出力が生成されるか
- エラーハンドリングが動作するか
- エッジケースが処理されるか

### 3. Performance Test（性能テスト）
スキルあり/なしの比較：
- ツール呼び出し回数
- トークン消費量
- ユーザーの手戻り回数

**Pro Tip**: まず1つの難しいタスクで反復。成功したアプローチをスキル化。
その後テストケースを広げる。

## Creation Workflow（作成フロー）

スキル作成時、以下を順に実行：

1. **ユースケース特定**: 2-3個の具体的シナリオを定義
2. **カテゴリ判定**: Document / Workflow / MCP Enhancement
3. **description設計**: 7項目チェック + ネガティブトリガー + 1024文字以内
4. **既存スキルとの重複チェック**: `ls ~/.claude/skills/` で確認
5. **実行パターン選択**: インライン / fork / 手動専用
6. **allowed-tools設計**: 必要最小限に制限
7. **引数設計**: `$0`, `$1` → `argument-hint` 記載
8. **動的コンテキスト**: `!`command`` で事前取得すべきデータ検討
9. **SKILL.md執筆**: 5,000語以内。重要指示はファイル上部に配置
10. **バリデーションスクリプト化**: クリティカルなチェックはscripts/に（コードは決定的、言語は非決定的）
11. **テスト**: Triggering / Functional / Performance の3領域
12. **設置**: `~/.claude/skills/skill-name/` に配置

## バリデーションスクリプト推奨

**公式ガイドの最重要Tips**: クリティカルなバリデーションはスクリプトで行え。
コードは決定的、言語の解釈は非決定的。

```bash
# scripts/validate.sh の例
#!/bin/bash
# 出力ファイルの品質チェック
if [ $(wc -w < "$1") -lt 100 ]; then
  echo "ERROR: Output too short (min 100 words)"
  exit 1
fi
```

## 将軍システム固有ルール

- 保存先: `~/.claude/skills/shogun-{skill-name}/`
- スキル候補は足軽が発見 → 家老経由で将軍に報告 → 将軍が設計 → 殿が承認 → 家老が作成
- 将軍システム連携（inbox_write, task YAML等）が必要なスキルは allowed-tools に Bash を含めよ
- north_star はフロントマターでなく**本文に記載**（フロントマターのカスタムフィールドはClaude Codeに無視される）


## Anti-Patterns（やってはいけないこと）

| NG | 理由 | 代わりに |
|----|------|---------|
| SKILL.md 5,000語超 | 読み込みコスト爆増、応答品質低下 | references/ に分離 |
| description が曖昧 | 発火しない or 誤発火 | What + When + ネガティブトリガー |
| description 1024文字超 | フロントマター制限超過 | 簡潔に3文以内 |
| description に `< >` | セキュリティ違反 | 角括弧不使用 |
| ネガティブトリガーなし | 類似スキル間で誤発火 | "Do NOT use for: ..." 追加 |
| `context: fork` + ガイドラインのみ | サブエージェントが迷走 | インライン実行 |
| `disable-model-invocation` + `user-invocable: false` | 誰も起動できない | どちらか片方 |
| allowed-tools 未指定で重い処理 | 意図しないツール使用 | 必要なツールのみ列挙 |
| フロントマターに独自フィールド | Claude Codeに無視される | 本文のMarkdownに記載 |
| スキルフォルダにREADME.md | 仕様違反 | SKILL.md or references/ |
| 同時有効スキル50個超 | コンテキスト圧迫 | 選択的有効化 |
