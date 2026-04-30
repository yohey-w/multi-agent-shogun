# 非描画系 高ROIツール候補ブレスト（cmd_080 支援）

**担当**: 足軽1号
**日時**: 2026-04-12
**対象範囲**: 画像生成/アイコン描画に依存しない、テキスト・コード・API完結型ツール12案
**出力方針**: Chrome拡張に限定せず、CLI / GitHub Action / Gmail Add-on / Self-host OSS / Webサービスなど形態は自由。
競合は実在サービス名＋URLで明記。評価軸は cmd_056 軍師採点（技術／市場／差別化／収益）を踏襲。

> **注**: task YAML の `target_path` は `multi-agent-shogun/docs/...` となっていたが、
> 該当ディレクトリが実在しないため、実在パスである
> `ai_accelerate/multi-agent-shogun/docs/non_visual_candidates_brainstorm.md` に出力している。

---

## サマリー表（12案）

| # | 名称 | 形態 | 差別化の核 | 実装コスト | 既存競合の穴 | 想定DAU(1年後) | 推奨度 |
|---|------|------|------------|-----------|---------------|----------------|--------|
| 1 | PromptVault | Chrome拡張 | BYOK前提・完全ローカル・複数LLM横断履歴 | S | AIPRMはChatGPT+Claude別拡張・$20/月 | 15,000 | ★★★★ |
| 2 | DocDiff Watch | Self-host OSS + Cron | 規約/料金ページ特化・日本語LLM要約 | M | VisualPingは視覚diff中心・$50/月〜 | 3,000 | ★★★ |
| 3 | InboxZap | Google Workspace Add-on | BYOK完全ローカル（サーバー不要） | M | SaneBoxは学習サーバー経由・$7〜$36/月 | 8,000 | ★★★★ |
| 4 | MeetingBrief | Self-host CLI + Cron | カレンダー＋メール＋Slack横断・朝配信 | M | Clay(旧Mesh)はCRM寄り、Reclaimは時間最適化のみ | 5,000 | ★★★★ |
| 5 | ContractRedline | CLI + Web | BYOKで社外秘契約をローカル赤入れ | L | Spellbook/IvoはSaaS・$150〜$300/席/月 | 2,000 | ★★★ |
| 6 | ChangelogBot | CLI + GitHub Action | Conventional Commits不要・任意履歴からAIリライト | S | release-pleaseはconventional必須・git-cliffは静的 | 12,000 | ★★★★ |
| 7 | SpecGuard | GitHub Action | 意味論レベルのbreaking検出（oasdiffは構文） | M | oasdiff PR commentはPro有料 | 4,000 | ★★★ |
| 8 | RSStoBrief | Self-host CLI + Cron | 完全OSS・10本クロス要約・単一メール | S | Feedly AIは$12/月〜・Readwise Readerは$9.99/月 | 6,000 | ★★★ |
| 9 | CronSense | CLI | 式＋GHA schedule衝突/死活まで検証 | S | crontab.guru/Cronifyは単発式のみ | 10,000 | ★★★★ |
| 10 | GitIncident | Self-host OSS + GitHub App | Sentry/ログ→PR本文自動RCA注入（OSS/BYOK） | L | Sentry Autofixは有料プラン限定 | 3,500 | ★★★ |
| 11 | ReceiptLine | Google Apps Script | 日本の領収書メール（楽天/Amazon/Uber等）→freee/弥生CSV | M | Dextは英語圏向け・Expensify SmartScanは画像OCR前提 | 4,000 | ★★★★ |
| 12 | FormFuel | Web (BYOK) | Google Forms/Typeform回答束→傾向要約＋返信ドラフト | S | MonkeyLearn/Sprigは高額SaaS・フォーム特化なし | 2,500 | ★★★ |

---

## 1. PromptVault — BYOKプロンプト金庫

- **一言**: ChatGPT/Claude/Gemini/Ollama に送ったプロンプトをローカル自動保存・タグ付け・再送できる、BYOK前提のプロンプト金庫。
- **ターゲット**: 業務で日常的に複数LLMを使い分けるエンジニア/ライター/コンサルで、AIPRMの月$20は重く、プロンプトを各サービスUIに散らしたくない層。
- **収益化モデル**: フリーミアム。無料=ローカル保存のみ / Pro($3/月)=E2E暗号化同期＋チーム共有。Proは5%転換想定。
- **実装コストS-M-L**: **S**（既存のBrowseToAnki/MemeSnapで培ったBYOK基盤＋IndexedDBをほぼ流用）
- **差別化**:
  - AIPRMは ChatGPT / Claude で別拡張・$20/月・広告タイル出現。本案は**完全ローカル・完全無料・全LLM一元管理**。
  - 勝手に送信テキストを拾うのではなく、**送信ボタン時点でフックして履歴化**するためプライバシー強い。
- **既存競合（実在）**:
  - AIPRM for ChatGPT（2M+ユーザー、$10〜$999/月） https://chromewebstore.google.com/detail/aiprm-for-chatgpt/ojnbohmppadfgpejeebfnmnknjdlckgj
  - PromptLayer（SaaS、開発者向け観測性寄り） https://www.promptlayer.com/
  - ChatGPT Toolbox（ChatGPT特化） https://www.chatgpt-toolbox.com/
- **想定DAU**: 1年後 15,000。プロンプト整理ニーズはAIPRM 2M+ユーザーの10%に内在する非AIPRM派を取り込める。
- **推奨理由**: 既存BYOK基盤の資産回収率が最高。絵不要・サーバー不要・クロスLLMの横串は現状どこも提供していない。

---

## 2. DocDiff Watch — 規約/料金ページ差分AI通知

- **一言**: 指定URLの利用規約・プライバシー・料金ページ変更を監視し、差分を日本語で3行要約して配信するCron型OSS。
- **ターゲット**: SaaS多数契約する情シス/法務・個人事業主・フリーランスで、VisualPingの$50/月は高すぎるが、規約改定を見逃したくない層。
- **収益化モデル**: OSS本体は無料。ホスティング代行サブスク($5/月 10URL)で収益化、またはスポンサー寄付。
- **実装コストS-M-L**: **M**（headless fetch＋テキスト抽出＋diff＋LLM要約＋通知チャネル複数）
- **差別化**:
  - VisualPingは**ビジュアル差分中心で誤報多**・$50/月〜。本案は**規約/料金HTML構造に特化したセマンティック差分＋LLM日本語要約**。
  - changedetection.ioはOSSだが差分通知止まりで意味解釈なし。本案は**「何が変わって何が実害か」を日本語3行で返す**。
- **既存競合（実在）**:
  - VisualPing（2M+ユーザー、$50〜/月） https://visualping.io/pricing
  - changedetection.io（OSS、Standard $110/月） https://changedetection.io/
  - PageCrawl.io https://pagecrawl.io/
- **想定DAU**: 1年後 3,000。規約監視はニッチだがB2Bで刺さる。
- **推奨理由**: BYOKで運用費ゼロ、GitHub Actionsのcronだけで動く最小構成。日本のSaaS契約管理マーケットに刺さる。

---

## 3. InboxZap — BYOKメール分類 Google Workspace Add-on

- **一言**: Gmail受信箱を「返信要／案内／購読／ゴミ」にBYOK LLMで分類し、サーバーレスにラベル付けるAdd-on。
- **ターゲット**: 日々100通以上受信するが、SaneBoxの$7〜36/月にロックインされたくない個人事業主・エンジニア。
- **収益化モデル**: 本体無料＋Pro($5/月)で分類ルールのバージョン履歴／複数アカウント。
- **実装コストS-M-L**: **M**（Apps Script＋BYOK LLMコール＋分類ルールYAML）
- **差別化**:
  - SaneBoxは**自社サーバーがメールヘッダーを読む**方式で、ゼロトラスト層に嫌われる。本案は**Apps Script内完結・LLM呼び出しのみ外部**。
  - Shortwaveは専用メールクライアントが必要。本案はGmail.comそのままで動く。
- **既存競合（実在）**:
  - SaneBox（$2〜$36/月） https://www.sanebox.com/
  - Shortwave（$7〜$36/月） https://www.shortwave.com/
  - Superhuman Business $33/月 https://blog.superhuman.com/superhuman-alternatives/
- **想定DAU**: 1年後 8,000。日本語メールで刺さる。
- **推奨理由**: Apps Scriptは学習コスト低・配布コストゼロ。BYOKで実運用費ゼロ。

---

## 4. MeetingBrief — 朝6時に届く次会議ブリーフ

- **一言**: Google Calendar で翌営業日の会議×参加者×過去メール履歴×過去Slackを束ねて3行ブリーフを朝6時配信するSelf-hostツール。
- **ターゲット**: 1日4〜6本会議が入るPM/BizDev/営業で、Clay(旧Mesh)月$149やEA雇用は過剰な個人・小規模チーム。
- **収益化モデル**: OSS本体無料＋ホスティングサブスク($10/月 1ユーザー)。
- **実装コストS-M-L**: **M**（Google Calendar API＋Gmail API＋Slack API＋LLM要約＋メール送信）
- **差別化**:
  - Clayは**CRM型で月$149〜**、Reclaim.aiは**時間スロット最適化特化**でブリーフィング機能は薄い。本案は**会議直前ブリーフ一点特化**。
  - 録音一切なし、テキストAPI（カレンダー/Gmail/Slack）のみ使用。
- **既存競合（実在）**:
  - Clay.earth（旧Mesh、$149/月〜） https://www.toolsforhumans.ai/ai-tools/clay
  - Reclaim.ai（Free / $10〜$18/月） https://reclaim.ai/
  - Fireflies.ai（録音型、月$10〜） https://fireflies.ai/
- **想定DAU**: 1年後 5,000。
- **推奨理由**: BYOKで完全ローカル処理可能。日本企業の「録音禁止」社内規定に適合。

---

## 5. ContractRedline — BYOK契約書レッドライン

- **一言**: DOCX/PDF契約書をアップすると、Claude/GPT-5に自社プレイブックを当てて赤入れしたDOCX Diffを返すCLI＋Webアプリ。
- **ターゲット**: 法務担当者ゼロのスタートアップCEO／個人士業で、Spellbook($150〜$300/席/月)・Ivo($200〜/席/月)が重すぎる層。
- **収益化モデル**: OSS + 自社プレイブック管理SaaS（$15/月）。
- **実装コストS-M-L**: **L**（python-docx XMLレベル編集＋LLMコール＋プレイブックYAML＋差分表示UI）
- **差別化**:
  - Spellbook/Ivoは**SaaS前提で社外秘契約のアップロードに心理的抵抗**あり。本案は**CLI+BYOK=完全ローカルで動く**。
  - プレイブックをYAMLで持つため、GitHub Actionsに組み込んでプルリクで契約書レビュー回せる。
- **既存競合（実在）**:
  - Spellbook（GPT-5/Claude, Word Add-in, 4,000+チーム） https://www.spellbook.legal/
  - Ivo（Word Add-in、プレイブック型、$200/席〜） https://www.spellbook.legal/vs/ivo
  - GC AI https://www.spellbook.legal/briefs/ivo-vs-gc-ai
- **想定DAU**: 1年後 2,000（B2B中心、DAUよりMRR）。
- **推奨理由**: 法務AIはトップダウンでSaaS化しているが、**BYOK×OSS層が丸ごと空白**。

---

## 6. ChangelogBot — Conventional不要のAIリリースノート生成

- **一言**: Conventional Commitsを強制せず、任意のgit履歴・PR本文・Issue本文をLLMに渡してSemVer準拠CHANGELOGを生成するCLI＋GitHub Action。
- **ターゲット**: 個人OSS/小規模チーム/社内リポで、commit規約が守られない現場のメンテナ。
- **収益化モデル**: OSS + GitHub Marketplaceで月50実行以上Pro($5/月)。
- **実装コストS-M-L**: **S**（git log＋GitHub GraphQL＋LLM構造化出力＋SemVerバンプ判定）
- **差別化**:
  - conventional-changelog / release-please は**commitメッセージ規約が前提**で、規約なしリポでは機能しない。本案は**コミット本文＋PR本文＋diffを直接LLMに要約させる**。
  - git-cliffは静的テンプレ中心でAI要約なし。本案は**ユーザー向けコピーにリライト**。
  - ChangelogaiやGitSagaはCLI有料寄り。本案はOSS＋BYOK。
- **既存競合（実在）**:
  - release-please（Google、OSS） https://github.com/googleapis/release-please
  - conventional-changelog（OSS） https://github.com/conventional-changelog/conventional-changelog
  - git-cliff（OSS、AIなし） https://git-cliff.org/
  - GitSaga / Changelogai / Changeish（各SaaS/OSS混在） https://personabox.app/blog/best-changelog-tools
- **想定DAU**: 1年後 12,000。開発者向けCLIは普及速度が早い。
- **推奨理由**: 実装Sコスト、既存OSSの穴（規約不問）を埋める。GitHub Marketplace露出＝Claude API課金ユーザー取り込みに直結。

---

## 7. SpecGuard — 意味論レベルのAPI breaking GitHub Action

- **一言**: OpenAPI/GraphQL/Protobuf定義の変更を「構文diff」でなく「意味論的breaking」で検出するGitHub Action。
- **ターゲット**: 複数チームでAPI共有する中規模開発組織で、oasdiffの無料枠ではPRコメントが出ず、Proにお金は出したくない層。
- **収益化モデル**: OSS + 組織ライセンス ($29/リポ/月) でPRコメント／Slack通知／事例蓄積。
- **実装コストS-M-L**: **M**（oasdiffラッパー＋LLMセマンティック判定＋GitHubコメントAPI）
- **差別化**:
  - oasdiffは**CLI無料、PRコメント機能はPro**。本案は**OSS＋BYOKでPRコメントまで無料**。
  - セマンティック層（例: enum値の意味変更、必須フィールドの意味転換）まで踏み込む。
- **既存競合（実在）**:
  - oasdiff GitHub Action https://github.com/oasdiff/oasdiff-action
  - Stoplight Spectral（lint特化） https://stoplight.io/open-source/spectral
  - openapi-diff (OpenAPITools/openapi-diff) https://github.com/OpenAPITools/openapi-diff
- **想定DAU**: 1年後 4,000（GitHub Actions実行ベース）。
- **推奨理由**: DevOps層向けで粘着度高・有料プラン転換率高。

---

## 8. RSStoBrief — 朝1通に束ねるRSSクロス要約メール

- **一言**: 指定RSS/Atomフィード最大10本を毎朝LLMで横断要約し、1通のメールにまとめて配信するSelf-host CLI + Cron。
- **ターゲット**: Feedly AI($12/月〜)やReadwise Reader($9.99/月)にお金を出したくないが、毎朝Feedly/Inoreaderを開いて読む時間がない情報収集派。
- **収益化モデル**: OSS + SendGrid/Resend代行サブスク($3/月)。
- **実装コストS-M-L**: **S**（RSSパース＋LLM要約＋SendGrid/SMTP）
- **差別化**:
  - Feedly AIは**Feedly内に閉じた要約**。本案は**任意フィード→任意メールアドレス配信**。
  - Readless/Brevioは類似コンセプトだがSaaS寄り。本案は**自分のサーバーで動くCLI**でプライバシー強。
- **既存競合（実在）**:
  - Feedly AI（$12/月〜） https://feedly.com/
  - Readwise Reader（$9.99/月） https://readwise.io/read
  - Readless https://www.readless.app/
  - Brevio https://brevio.news/
- **想定DAU**: 1年後 6,000。
- **推奨理由**: OSS開発者層に刺さる。BYOK Claude Haikuで1ユーザー月10円未満の原価。

---

## 9. CronSense — cron式＋GitHub Actions schedule検証CLI

- **一言**: crontabやGitHub Actions scheduleの式をLLMで自然言語化・衝突検出・死活監視スケジュール提案するCLI。
- **ターゲット**: 複数リポ・複数サーバーのcron/GHA schedule管理者で、crontab.guruやCronifyでは単発式しか見られない層。
- **収益化モデル**: OSS + 組織ダッシュボード($10/月)。
- **実装コストS-M-L**: **S**（cron parser＋LLM説明＋衝突アルゴリズム）
- **差別化**:
  - crontab.guru/Cronifyは**単発式の翻訳のみ**、リポ横断衝突検出なし。本案は**リポ全体を走査し、同時刻集中／重複／欠落を警告**。
  - GHA scheduleは「最大20分遅延する」特性まで考慮。
- **既存競合（実在）**:
  - crontab.guru https://crontab.guru/
  - Cronify https://cronify.zimo.li/
  - cron-expression-descriptor https://bradymholt.github.io/cron-expression-descriptor/
- **想定DAU**: 1年後 10,000。
- **推奨理由**: 開発者向けCLIで粘着・BYOK原価ほぼゼロ。

---

## 10. GitIncident — OSS版 Sentry Autofix

- **一言**: Sentry/Rollbar/ログ収集サービスのissueと GitHub Issue/PR を紐付け、BYOK LLMでRCAレポートをPR本文に自動注入するSelf-host GitHub App。
- **ターゲット**: Sentry Autofix (Paid限定)を払えない小〜中規模チーム／自前ログ基盤運用チーム。
- **収益化モデル**: OSS + ホスティング代行($15/月 チーム)。
- **実装コストS-M-L**: **L**（GitHub App＋Sentry/Rollbar APIs＋ログストリーム→LLM RCA＋PR comment/書き込み）
- **差別化**:
  - Sentry Autofix/Seerは**Sentry Paid Plan前提**。本案は**BYOKでSentry無料枠でも動く**。
  - Rootlyは有料SaaS・インシデント管理中心。本案はPR本文への**自動RCA注入一点特化**。
- **既存競合（実在）**:
  - Sentry Autofix（Paid） https://docs.sentry.io/product/ai-in-sentry/seer/autofix/
  - StarSling（Sentry向けAI agent） https://www.starsling.dev/sentry
  - Rootly https://rootly.com/
- **想定DAU**: 1年後 3,500。
- **推奨理由**: 開発者向け粘着度極めて高。BYOKでClaude API課金ユーザー比率が高く、アフィ/ケース蓄積の価値大。

---

## 11. ReceiptLine — 日本の領収書メール→freee/弥生CSV

- **一言**: Gmail内の楽天/Amazon/Uber Eats/SmartHRなどの領収書メールをApps ScriptでLLM抽出し、freee/弥生向けCSVを自動生成。
- **ターゲット**: 日本の個人事業主／小規模法人で、Expensify/Dextは英語圏・月$5/人〜、SmartScanは紙領収書前提で「メール本文の領収書」に弱い層。
- **収益化モデル**: Apps Script無料＋プレミアムテンプレ（freee会計科目自動マッピング等）$3/月。
- **実装コストS-M-L**: **M**（Apps Script＋LLM抽出＋freee/弥生CSV仕様）
- **差別化**:
  - Expensify SmartScanは**画像OCR前提**で、メール本文の領収書は苦手。Dextは英語圏向け。本案は**日本のEC/サービス領収書メール特化**。
  - freee AI会計・弥生オンラインも銀行口座連携中心で、メールボックス内の領収書メール取り込みは弱い。
- **既存競合（実在）**:
  - Expensify SmartScan https://use.expensify.com/receipt-scanning-app
  - Dext Prepare https://dext.com/
  - freee会計 https://www.freee.co.jp/houjin/
  - 弥生会計オンライン https://www.yayoi-kk.co.jp/
- **想定DAU**: 1年後 4,000。
- **推奨理由**: 日本市場特化（ローカライズ軸）、Apps Scriptで配布コスト極小、freee/弥生連携で有料プラン転換率高。

---

## 12. FormFuel — フォーム回答→傾向要約＋返信ドラフトWeb

- **一言**: Google Forms/Typeform回答CSVをアップロードするとClaude/GPTで傾向要約・課題抽出・返信文ドラフトを返すBYOK Webツール。
- **ターゲット**: イベント運営・店舗・教育機関の問い合わせフォーム管理者で、MonkeyLearn/Sprigは過剰・高額な層。
- **収益化モデル**: BYOK Web無料＋有料プラン（Typeform Webhook自動連携、$8/月）。
- **実装コストS-M-L**: **S**（CSV取込＋LLM要約・分類＋返信テンプレ）
- **差別化**:
  - MonkeyLearn/Sprigは**汎用NLP SaaS・月$100〜**。本案は**フォーム回答一点特化＋BYOK**で原価ほぼゼロ。
  - Google Forms内蔵の「回答サマリー」は棒グラフのみ。本案は**自由記述の意味要約＋返信ドラフト**。
- **既存競合（実在）**:
  - MonkeyLearn https://monkeylearn.com/
  - Sprig AI https://sprig.com/
  - Typeform AI https://www.typeform.com/ai/
- **想定DAU**: 1年後 2,500。
- **推奨理由**: Sコスト・MemeSnap/BrowseToAnki のBYOK基盤を流用可・日本語イベント運営層に刺さる。

---

## 推奨TOP3（本ブレスト担当の私見）

軍師の最終ランキング作成の参考として、足軽1号からの私見を付記する：

1. **#1 ChangelogBot**（★★★★／実装Sコスト／OSS開発者層の強い粘着）
   - 既存OSSの「conventional commits必須」という構造的穴を埋める。GitHub Marketplace露出でBYOKユーザーが雪玉式に増える。
2. **#2 PromptVault**（★★★★／既存基盤の資産回収率最高）
   - 既存BrowseToAnki / MemeSnap のBYOK基盤をほぼ流用。AIPRM層の「$20/月払いたくない」サイレント・マジョリティを取り込める。
3. **#3 CronSense**（★★★★／粘着度高・実装Sコスト）
   - 開発者向けCLIの中で最も競合が薄い。リポ横断衝突検出は現行ツールに存在しない。

---

## 除外した案（参考）

ブレスト段階で検討したが採用しなかった案：

- **KeigoBot CLI版**: 既存 candidates_new/ashigaru1_keigo-lint.md のCLI版に過ぎず、重複。
- **SlackChannelBrief**: Slack公式 AI Summary / Slack Lists に吸収される可能性高。
- **PDFPortfolioBuilder**: 「描画系」にかすり、本ブレストの非描画縛りから外れる。
- **InvoiceChaser (未払い催促メール自動化)**: freee/マネーフォワード請求書が既に提供。

---

*本ドキュメントは cmd_080 支援として足軽1号が作成。軍師が本ブレストを元に最終ランキングを作成する。*
