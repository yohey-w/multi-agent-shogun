# TOP1 MVP 仕様書 — ChangelogBot

**親コマンド**: cmd_080
**起案者**: 軍師（Gunshi）
**日時**: 2026-04-12
**MVP定義**: 「動く最小実装 + README」。既存リポでCLI実行 → `CHANGELOG.md` 生成＋GitHub Action経由でPRに自動コメントが最低ライン。

---

## 1. 製品概要

**ChangelogBot** — Conventional Commits規約を要求せず、任意のgit履歴・PR本文・Issue本文からLLMでSemVer準拠 CHANGELOG を生成するCLI＋GitHub Action。

**価値提案**:
- release-please / conventional-changelog は commit 規約必須 → 規約なしリポ（市場の70%超）では機能しない
- git-cliffは静的テンプレでAI要約なし
- 本案は**commit本文 + PR本文 + diff要約を LLM に直接渡し、ユーザー向けコピーにリライト**

---

## 2. 配置先リポジトリ

**新規リポ**: `github.com/makotonos/changelog-bot`（makotonosアカウント下、yohey-w禁止ルール遵守）

作業ディレクトリ: `/Users/mizunomakoto/Project/makotoProj/ai_accelerate/multi-agent-shogun/experiments/changelog-bot/`（MVP完成後リポ切出し）

※初期開発は multi-agent-shogun リポ内 `experiments/` サブディレクトリで進め、MVP QC PASS後に独立リポ化して GitHub Marketplace 登録。

---

## 3. ファイル構成（最小）

```
changelog-bot/
├── package.json            # deps宣言
├── tsconfig.json           # TS strict
├── README.md               # 使い方・インストール・BYOK設定
├── action.yml              # GitHub Action メタデータ
├── Dockerfile              # GHA用コンテナ（node:20-alpine）
├── src/
│   ├── cli.ts              # commander CLI エントリ
│   ├── git.ts              # git log / tag / diff 取得（simple-git）
│   ├── github.ts           # GitHub GraphQL で PR/Issue本文取得（@octokit/graphql）
│   ├── llm.ts              # BYOK Claude/OpenAI 呼出し（@anthropic-ai/sdk, openai）
│   ├── semver.ts           # LLM出力から major/minor/patch 判定
│   ├── render.ts           # Markdown CHANGELOG 整形
│   └── types.ts            # zod スキーマ（LLM構造化出力検証）
└── test/
    └── smoke.test.ts       # CLI smoke test（実git log → LLM モック → 出力検証）
```

**合計ファイル数**: 11ファイル。LOC目安 400-600行。

---

## 4. 依存ライブラリ

```json
{
  "dependencies": {
    "@anthropic-ai/sdk": "^0.30.0",
    "openai": "^4.60.0",
    "simple-git": "^3.25.0",
    "@octokit/graphql": "^7.1.0",
    "commander": "^12.0.0",
    "semver": "^7.6.0",
    "zod": "^3.23.0"
  },
  "devDependencies": {
    "typescript": "^5.4.0",
    "vitest": "^1.6.0",
    "@types/node": "^20.0.0"
  }
}
```

**BYOK**: 環境変数 `ANTHROPIC_API_KEY` または `OPENAI_API_KEY` のどちらかが設定されていれば動作。GitHub Action入力でも指定可。

---

## 5. CLI仕様

```
$ npx changelog-bot [options]

Options:
  --from <ref>      起点タグ/コミット（省略時: 直近タグ）
  --to <ref>        終点（省略時: HEAD）
  --output <file>   出力先（省略時: stdout）
  --provider <p>    anthropic | openai（省略時: env変数から自動判定）
  --model <name>    モデル名（省略時: claude-haiku-4-5）
  --bump            SemVer bump判定のみ出力（CHANGELOGなし）
  --dry-run         LLM呼び出しせず git log 生データのみ表示
  --repo <owner/r>  GitHub GraphQL用リポ（省略時: origin remote自動取得）
  --github-token    PR/Issue本文取得用（省略時: env GITHUB_TOKEN）
```

**出力例**（stdout）:
```markdown
## [1.3.0] - 2026-04-12

### Added
- 音声解析パイプラインに Whisper fallback を追加（#123）
- Vision API 対応で画像入力が可能に

### Fixed
- Ollama WebP エンコードで 500 エラーが発生する問題を修正（#128）

### Changed
- LLM プロバイダ設定を YAML ベースに統一

**Suggested bump**: minor
```

---

## 6. GitHub Action仕様（action.yml）

```yaml
name: 'ChangelogBot'
description: 'AI-powered changelog generation without conventional commits'
branding:
  icon: 'file-text'
  color: 'purple'
inputs:
  anthropic-api-key:
    description: 'Anthropic API key (BYOK)'
    required: false
  openai-api-key:
    description: 'OpenAI API key (BYOK)'
    required: false
  from:
    description: 'Starting ref'
    required: false
  to:
    description: 'Ending ref'
    default: 'HEAD'
  mode:
    description: 'pr-comment | release-notes | file-commit'
    default: 'pr-comment'
  github-token:
    description: 'GitHub token for PR/Issue fetching + PR comment'
    default: ${{ github.token }}
runs:
  using: 'docker'
  image: 'Dockerfile'
outputs:
  changelog:
    description: 'Generated changelog markdown'
  bump:
    description: 'Suggested SemVer bump (major/minor/patch)'
```

**実行モード**:
- `pr-comment`: PRのbaseブランチとの差分を要約 → PR本文にコメント
- `release-notes`: タグpush時に自動実行 → GitHub Release本文投入
- `file-commit`: `CHANGELOG.md` 更新 → botコミットとして自動push

---

## 7. LLM プロンプト設計（src/llm.ts）

**System**:
```
You are a release note generator. Given raw git commit messages, PR titles/bodies,
and optional issue bodies, produce a user-facing CHANGELOG section in Keep-a-Changelog
format (Added/Changed/Fixed/Removed/Deprecated/Security). Also suggest a SemVer bump
(major/minor/patch) based on breaking-change heuristics. Never fabricate features not
present in the input. Write in the same language as the majority of input (ja if >50%
Japanese).
```

**User**（構造化）:
```json
{
  "commits": [{ "sha": "...", "message": "...", "body": "..." }],
  "prs": [{ "number": 123, "title": "...", "body": "..." }],
  "issues": [{ "number": 45, "title": "...", "body": "..." }],
  "from_ref": "v1.2.0",
  "to_ref": "HEAD"
}
```

**出力構造（zod 検証）**:
```ts
const Output = z.object({
  sections: z.object({
    added: z.array(z.string()),
    changed: z.array(z.string()),
    fixed: z.array(z.string()),
    removed: z.array(z.string()).optional(),
    deprecated: z.array(z.string()).optional(),
    security: z.array(z.string()).optional(),
  }),
  bump: z.enum(['major', 'minor', 'patch']),
  breaking_notes: z.array(z.string()),
});
```

---

## 8. 工数見積

| フェーズ | 担当 | 時間 | 内容 |
|---------|------|------|------|
| P1: CLI実装 | 足軽1号 | 3h | src/cli.ts, git.ts, llm.ts, semver.ts, render.ts, types.ts |
| P2: GHA化 | 足軽2号 | 2h | action.yml, Dockerfile, smoke.test.ts, 実リポでのPR コメント動作確認 |
| P3: README + 公開準備 | 足軽2号 | 1h | README.md（install/usage/BYOK手順/example output） |
| **合計** | **2名** | **6h** | |

**並列可能性**: P1とP2のaction.yml下書きは部分並行可（足軽2号先行）。実質5h完遂も狙える。

---

## 9. QC基準（軍師によるQC実施項目）

**必須PASS条件**:

1. **実動作確認（dogfooding）**:
   - multi-agent-shogun リポで `npx changelog-bot --from v0.1.0 --to HEAD --dry-run` が動く
   - 同リポで `--dry-run` なし＋BYOK Claude で実出力が生成される
   - 出力に捏造（inputに存在しない機能記述）がないこと

2. **GHA経由動作**:
   - サンプルリポ（新規作成可）でPRを作成、Action発火 → PR本文に CHANGELOG コメントが投下される
   - スクリーンショット or リンクをreport YAMLに添付

3. **SemVer bump判定妥当性**:
   - 手動テスト3パターン: (a) bug fix only → patch, (b) new feature → minor, (c) breaking change (body に "BREAKING" 含む) → major

4. **README 手順再現性**:
   - README記載のインストール手順通りに新規ディレクトリで動作すること
   - BYOK設定エラー時のエラーメッセージが親切（missing API key を明示）

5. **エラーハンドリング**:
   - git log 空（新規リポ）→ 適切なメッセージで exit 0
   - API key 未設定 → exit 1 + README 参照誘導
   - LLM出力zod検証失敗 → リトライ1回、それでもNGなら exit 1

**SKIP = FAIL ルール適用**: 上記5項目のいずれかが SKIP なら不合格。

---

## 10. リスク対応

| ID | リスク | 対応 |
|----|-------|------|
| R1 | GitHub / OpenAI 純正機能との衝突 | OSS + BYOK + プレイブックYAML優位性を README で明示 |
| R2 | SemVer bump LLM誤判定 | `--dry-run` / `--bump` サブモード標準提供、人力最終判断前提を README に明記 |
| R3 | GitHub API rate limit | incremental fetch、最終タグからの差分のみ取得、`@octokit/graphql` でバッチ |
| R4 | LLM コスト予測外れ | デフォルト claude-haiku-4-5 / gpt-4o-mini で原価抑制、モデル切替可 |
| R5 | PR本文/Issue本文に機密情報 | README で警告、`--exclude-labels` で指定ラベルのPRを除外可能にする（P1.5で追加） |

---

## 11. 公開・継続運用

**Phase 1**（本MVP）: multi-agent-shogun の experiments/ 内で実装＋QC
**Phase 2**（次コマンド）: makotonos アカウントで新規リポ作成 → git push → GitHub Marketplace 申請
**Phase 3**: 実績蓄積後、PromptVault（TOP2）に着手

---

## 12. Acceptance Criteria チェックリスト

- [ ] `src/cli.ts` 含む11ファイルが存在する
- [ ] `npm install && npm run build` が成功する
- [ ] `npx changelog-bot --dry-run` が multi-agent-shogun リポで動く
- [ ] BYOK Claude モードで実CHANGELOG生成が確認できる
- [ ] action.yml が GitHub Actions schema に適合
- [ ] Dockerfile ビルドが通る
- [ ] サンプルリポのPRでGHA経由コメント投下が成功
- [ ] README 記載手順通りに新規環境で再現できる
- [ ] smoke.test.ts が通る（vitest）
- [ ] 軍師QC PASS（上記9章の5項目）

---

*本仕様は cmd_080 軍師成果物として作成。Karoの承認後、足軽1-2名にMVP実装を発令する。*
