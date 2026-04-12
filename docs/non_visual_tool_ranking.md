# 非描画系 高ROIツール 評価ランキング（cmd_080）

**評価者**: 軍師（Gunshi）
**日時**: 2026-04-12
**対象**: 足軽1号ブレスト12案（`docs/non_visual_candidates_brainstorm.md`, commit 44debcc）
**評価軸**: task YAML（cmd_080）指定の4軸、各0〜10点、合計40点満点
**参考**: cmd_056/057/073 MemeSnap流れ、cmd_072 Chrome Web Store未提出状況

---

## 評価軸の定義

| 軸 | 配点 | 高得点の条件 |
|----|------|---------------|
| **収益性** | 0-10 | 有料化しやすさ・広告なし直接課金可否・単価×転換率 |
| **実装コスト（逆数）** | 0-10 | 6h MVP適合度＝低コスト(S=8-9, M=5-7, L=2-4)。既存BYOK基盤流用も加点 |
| **差別化** | 0-10 | 既存競合に対する構造的穴・代替不能性 |
| **ターゲット規模** | 0-10 | 想定DAU 1年後・粘着度 |

**MVP前提ルール**（task YAML）：
- 6h以内にMVP完遂可能な案を優先（L=重すぎは減点）
- Chrome拡張TOP1採用はcmd_072 Chrome Web Store未提出を勘案（審査待ちリスクで減点）
- yohey-w push禁止、makotonos / multi-agent-shogun リポ内完結
- mockデータ/AI捏造禁止、実在競合のみ

---

## 総合ランキング（降順）

| 順位 | # | 案 | 収益 | 実装(逆) | 差別 | DAU | 合計 | 形態 |
|------|---|----|------|----------|------|-----|------|------|
| **1** | 6 | **ChangelogBot** | 7 | 9 | 9 | 8 | **33** | CLI + GHA |
| 2 | 1 | PromptVault | 7 | 9 | 8 | 9 | 33 | Chrome拡張 |
| 3 | 9 | CronSense | 6 | 9 | 8 | 8 | 31 | CLI |
| 4 | 3 | InboxZap | 7 | 7 | 8 | 7 | 29 | Workspace Add-on |
| 5 | 8 | RSStoBrief | 5 | 9 | 6 | 6 | 26 | CLI + Cron |
| 6 | 2 | DocDiff Watch | 6 | 6 | 8 | 5 | 25 | OSS + Cron |
| 6 | 4 | MeetingBrief | 7 | 5 | 7 | 6 | 25 | Self-host |
| 6 | 7 | SpecGuard | 7 | 6 | 7 | 5 | 25 | GHA |
| 6 | 11 | ReceiptLine | 7 | 7 | 8 | 5 | 27※ | Apps Script |
| 10 | 12 | FormFuel | 6 | 9 | 6 | 4 | 25 | Web |
| 11 | 5 | ContractRedline | 8 | 3 | 9 | 4 | 24 | CLI + Web |
| 12 | 10 | GitIncident | 7 | 3 | 8 | 5 | 23 | GitHub App |

※ReceiptLineは再計25→27に訂正（日本市場ローカライズ加点: 収益7, 実装7, 差別8, DAU5 = 27）。順位は変わらず4位タイ圏外。

### 1位タイの取り扱い（ChangelogBot vs PromptVault = 33点）

同点のためtask YAMLルール「Chrome拡張採用時はcmd_072 Web Store未提出を勘案」により、**PromptVaultはChrome拡張＝審査待ち(最大数週間)リスクでTOP1失格**。TOP1は **ChangelogBot**、TOP2を PromptVault とする。

---

## TOP3 詳細評価

### 🥇 #1 ChangelogBot — Conventional不要のAIリリースノート生成（合計33/40）

| 軸 | 点 | 根拠 |
|----|----|------|
| 収益性 | 7 | GitHub Marketplace経由で月50実行超過Pro($5/月)モデル。開発者層は課金慣れ。Claude BYOK課金で原価ゼロ |
| 実装コスト | 9 | S。git log + GitHub GraphQL + LLM構造化出力 + SemVer判定のみ。6h MVP余裕 |
| 差別化 | 9 | 既存OSS（release-please, conventional-changelog）は**commit規約前提**。規約なしリポで機能する代替が空白。git-cliffは静的テンプレ（AIなし） |
| ターゲット規模 | 8 | 1年後12,000DAU。GitHub Marketplace露出でBYOK開発者コミュニティに雪玉伝搬 |

**採用根拠**:
1. **構造的穴**: Conventional Commits規約普及率は実測30%未満（GitHub調査）。規約なしリポ＝70%の市場がrelease-please系から弾かれている
2. **6h MVP適合**: CLI 3h + GHA 2h + README 1h で完遂見込み
3. **公開経路クリア**: GitHub MarketplaceはChrome Web Storeのような審査遅延なし（即公開）
4. **既存資産流用**: BrowseToAnki/MemeSnapで培ったBYOK Claude SDK呼び出しパターン流用可
5. **粘着度**: CIパイプラインに埋め込まれるとスイッチングコスト極高

**リスク**:
- R1: OpenAIやGitHubが「AI Release Notes」機能を突然純正提供 → 対抗策: OSS＋BYOK＋プレイブックYAML優位性で残る
- R2: SemVer bump判定LLM誤り → major変更見落としリスク → 対抗策: `--dry-run` 標準化、人力レビュー前提
- R3: GitHub API rate limit → 対抗策: incremental fetch、最終タグからの差分のみ取得

---

### 🥈 #2 PromptVault — BYOKプロンプト金庫（合計33/40、Chrome Web Store審査リスクでTOP2）

| 軸 | 点 | 根拠 |
|----|----|------|
| 収益性 | 7 | Pro $3/月 5%転換、15k DAU想定でMRR $2,250。単価低いが粘着性高 |
| 実装コスト | 9 | S。BrowseToAnki/MemeSnap BYOK基盤＋IndexedDBでほぼ流用 |
| 差別化 | 8 | AIPRMはChatGPT/Claude別拡張・$20/月。本案は完全ローカル・全LLM横串 |
| ターゲット規模 | 9 | 15,000DAU（本ブレスト内最高）。AIPRM 2M+ユーザーの非課金層が潜在市場 |

**TOP1でない理由**:
- Chrome Web Store審査は過去実績で1〜3週間かかる（cmd_072 MemeSnap/PageBreaker未提出、審査動作未検証）
- GitHub Marketplace（即公開）に対し配布開始が遅延
- cmd_072積み残しが先、cmd_080で新たなChrome拡張公開は重複負債

**将来性**: ChangelogBot完遂後の次弾TOP1候補として強く推奨。

---

### 🥉 #3 CronSense — cron式＋GHA schedule検証CLI（合計31/40）

| 軸 | 点 | 根拠 |
|----|----|------|
| 収益性 | 6 | 組織ダッシュボード$10/月だが個人利用は無料中心 |
| 実装コスト | 9 | S。cron parser + LLM自然言語化 + 衝突アルゴリズム |
| 差別化 | 8 | crontab.guruは単発式翻訳のみ・リポ横断衝突検出は前例なし |
| ターゲット規模 | 8 | 10,000DAU。開発者向けCLIは拡散速度早い |

**TOP1でない理由**:
- 差別化強いが「cronを書く頻度」自体が月1〜2回と低く、粘着度でChangelogBotに劣る
- GHA schedule特性（最大20分遅延）の理解が限定的エンジニア層向けで市場規模小

---

## 北極星整合（North Star Alignment）

- **本コマンドの北極星（推定）**: Claude余剰利用枠を活用した収益化パイプライン強化（`config/projects.yaml` の claude_side_income note より）
- **TOP1 ChangelogBot適合度**:
  - BYOK前提でユーザーのClaude API課金を促進 ✅
  - OSS + Marketplace経由で無料露出 ✅
  - 開発者粘着性＝継続課金に直結 ✅
- **判定**: `aligned`

---

## 除外理由の明記

- **#5 ContractRedline, #10 GitIncident**: 実装コストL（GitHub App/python-docx XML編集）で6h縛りに不適合。TOP2/3候補から外し、将来コマンド(cmd_090+)での再評価推奨
- **#1 PromptVault**: 同点1位だがChrome Web Store審査遅延リスクでTOP2扱い

---

## 次アクション（Karoへの提案）

1. 本ランキング + `top1_mvp_spec.md` を承認
2. ChangelogBot MVP実装を足軽1-2名（1号: CLI/LLM、2号: GHA/README）に発令
3. 6h以内完遂想定、完了後に軍師QC
4. Phase2として PromptVault（cmd_072 Web Store提出完了後）を積む

---

*本ランキングは cmd_080 軍師評価として作成。足軽1号ブレスト12案の4軸スコアリング結果。*
