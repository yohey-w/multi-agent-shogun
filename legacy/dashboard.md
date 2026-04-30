# 将軍システム ダッシュボード
最終更新: 2026-04-30 11:05 (cmd_095/098/101 done、cmd_102 Phase 6 発令)

## 🐸 Frog / ストリーク
| 項目 | 値 |
|------|-----|
| ストリーク | 🔥 1日目 (最長: 3日) |
| 前回完了 | 4/7 (04-23: cmd_096/097/099/100) |

## 📋 プロジェクト概況
- **chrome_extensions**: KindleSnap/BrowseToAnki/PageBreaker/MemeSnap 4拡張QC PASS済み、ストア公開待ち（殿の作業リスト→🚨要対応）
- **claude_side_income**: 動画テンプレートv4完成(ep001_v4.mp4)、YouTube開設・ブログドメイン待ち
- **web_update_alert**: Prisma7+Next15移行済み、ローカル動作確認OK、本番デプロイ待ち
- **ai_accelerate_plan**: プレゼン資料完成済み
- **multi-agent-shogun**: cmd_058完了（dashboard簡潔化済み）

## 🔄 進行中

### kindle-snap v1.1 SDD (cmd_096-102, 全7 Phase)
設計書+計画書(commit ee22e68/4cdc577)確定済。Phase 0→1→(2/3/4/5並列)→6の流れ。
- **cmd_096** (Phase 0: テスト基盤) ✅ PASS (fdfaa36 + 50f442b)
- **cmd_097** (Phase 1: 容易性基盤) ✅ PASS (4b5e1af/d249436/36a8d88/efb8006/f34caf9)
- **cmd_099** (Phase 3: padding) ✅ PASS (8596b40)。PDF全ページmax W×H統一、白余白padding、crop無し。
- **cmd_100** (Phase 4: fullscreen) ✅ PASS (a31acc1)。popup→scripting.executeScript→requestFullscreen、SW冒頭確認→failed=fatal。
- **cmd_098** (Phase 2: E2E TDD red) ✅ done。テスト仕様書(ebd1fd8)、軍師Phase A✅B✅C✅。AC-5/6/10 PASS、他NOT_TESTABLE(キャプチャ未実行制約)。構造的green蓋然性高。
- **cmd_101** (Phase 5: page-verify) ✅ CONDITIONAL PASS (b040440+66d26b0)。Location変化検知3層防御。MINOR 5件はE2E後追撃。
- **cmd_102** (Phase 6: 統合/v1.1.0 release) 🚧 **進行中**。足軽1号=version bump、軍師=フルE2E (Start Capture実行あり)。殿smokeは両完了後。

### その他
- **cmd_095** ✅ done (fc85ae4)。/archive-queue スキル。17テスト全PASS。

## ✅ 直近の完了（cmd_051以降）
- **cmd_094** (04-14) ✅QC PASS (eecd5e6)。C案ハイブリッド waitForPageRender。MINOR 4件はE2E保留→🚨要対応参照。
- **cmd_093** (04-13) ✅QC PASS (narrow=0807682 + 093b=43afbe5)。getKindleTab narrow + Already force-reset + .pagination-container stage_0。
- **cmd_091** (04-13) ✅QC PASS (8ee200a)。SW listener最上位+dynamic import化+popup 4分岐+ASIN fallback。
- **cmd_090** (04-13) ✅QC PASS (phase_2E=6d2fdf4 + 追撃090b=d34c037)。Kindle Ionic SPA適合、1-page/2-page対応、overlay suppression。
- **cmd_089** (04-13) [cancelled→cmd_090統合] 診断ログ強化3点+dumpTopDom 20要素化(83d60b7)を温存しcmd_090に吸収。
- **cmd_088** (04-13) [cancelled→cmd_090置換] phase_2A iframe primary化、軍師仮説再評価で書き直しリスク40%→仮説E確定で置換。
- **cmd_087** (04-13) phase_1=仮説調査完了。軍師が殿PDFスクショ+実機ログで仮説E(Ionic SPA+img+overlay)を確度90%+確定、cmd_090に発展。
- **cmd_086** (04-13) 足軽1号(Opus, 19c0c8b) kindle-snap bounds全ログ+2ページ検知+併発ページ送り+before/after hash。追撃2(729f85b) logger race bug修正(writeChain直列化)。
- **cmd_085** (04-12) 足軽1号(Opus, 7d9dd66) kindle-snap PDF出力経路改善。bounds位置ズレ+1ページ止まり判明→cmd_086へ。
- **cmd_084** (04-12) kindle-snap 壁1(4b6106f)/壁2+3(a799569)。実機で88x88誤検知+ArrowRight iframe未到達判明→cmd_085へ。
- **cmd_083** (04-12) 足軽1号(Opus, 61304df) kindle-snap Reader area根治、多段フォールバック実装。
- **cmd_082** (04-12) 足軽6号(Sonnet, fb50057) kindle-snap可視化。KindleSnapLogger+popup Recent Logs/詳細モーダル。
- **cmd_081** (04-12) 殿作業可視化 → 足軽2(2c9b380 自動化推奨5件) + 足軽6(c196d4b 補助集計)。
- **cmd_080** (04-12) ChangelogBot MVP実装 → 足軽1号CLI本体(b2ceab4) + 足軽2号GHA(146065e)。**b2ceab4のcommit message誤ラベル→🚨要対応**
- **cmd_079** (04-12) pixel art自動化3軸調査(8dd9250/5f43276/9852808)+足軽7統合(ea57c82)。用途別TOP1確定、統合方針=Python関数化+PixelLab.ai MCP。
- **cmd_078** (04-12) CatStroll アイコン生成(9fe372b)。Pillowで琥珀色フラット猫デザインicon16/48/128.png透過PNG生成、webpack CopyPlugin でdist/icons/反映済、generate_icons.py同梱。cmd_077ルール初適用(足軽6号Sonnet)。**殿のChrome再読込確認待ち→🚨要対応**。
- **cmd_076** (04-12) CatStroll manifest修正(f32ca25)。exclude_matchesから`chrome://*/*`/`chrome-extension://*/*`削除(Chrome MV3無効スキーム)。npm run build成功・dist反映済。**殿のChrome再読込確認待ち→🚨要対応**。
- **cmd_075** (04-12) MemeSnap Ollama Vision疎通修正(4ab7f2e)。原因=`format:'json'`未指定でllama3.2-visionがmarkdown返却→JSON.parse失敗。1行追加で根治。docs/ollama_vision_fix.mdに再現&検証手順記載。**殿のChromeでE2E確認→🚨要対応**。
- **cmd_074** (04-12) Chrome拡張新案12案ブレスト(4/5軸完了)。ローカライズ(77a3b06)・AI(4ec17b6)・生産性(953da3f)・エンタメ(82d89ff)。日本特化軸3案+軍師TOP5評価は後続発令。
- **cmd_073** (04-12) Chrome拡張ポートフォリオ集約(claude_side_income/chrome_extensions_report/)。既存4(6315195)・候補5(37478ba)・README統合+軍師評価(d3a541b)。**d3a541bがweb_update_alert/firstブランチ発、要main移行→🚨要対応**。
- **cmd_072** (04-12) 新拡張『CatStroll』実装完遂。Round1 scaffold+猫+歩行AI(e9fa561)、Round2 足軽2号=text/eat/heart(cb160e0)+足軽3号=popup/README/listing(EN/JA)/privacy-policy(91bc97e)。PageBreaker v2基準。**注意: 91bc97eがweb_update_alert/firstブランチ発、要main移行 + lord_action_list.md未commit(shogun裁量)→🚨要対応**。
- **cmd_071** (04-12) MemeSnap WebP→PNG統一(bf8747b)。image-fetcher.ts を OffscreenCanvas.convertToBlob({type:'image/png'}) 固定化、10MB超のみJPEG(0.85)フォールバック、base64先頭ログ(iVBORw0KGgo=PNG)追加。Ollama 500根本原因fix。**殿のGoogle画像検索WebP実機確認待ち→🚨要対応**。
- **cmd_070** (04-12) MemeSnap Ollama Vision guard(9fbe199)。isVisionCapable(9パターン)+listOllamaModels(/api/tags 5s timeout)+popup⟳ボタンで✅/❌併記+非Vision選択時window.confirm+500時body先頭500字露出+pull案内。silent hang三段防御。
- **cmd_069** (04-12) MemeSnap Vision+キャプション編集(5c2c857, 90d0610)。Claude image block/Ollama images field両対応、SW経由fetch+OffscreenCanvas長辺1568pxリサイズ、プレビュー上で3format編集→canvas再描画→DL/Copy/Share反映。**殿の実画像3枚E2E検証待ち→🚨要対応**。
- **cmd_068** (04-12) BrowseToAnki『Sending』silent hang根治(69ee3cd)。root cause=content-script sendMessage callback欠落+SEND_RESULT tab経路未実装。callback+15s timeout追加。phase1 curl全PASS(addNote id=1775982394482)、phase2 build成功。**phase3 UI E2E=殿の手動確認待ち→🚨要対応**。
- **cmd_067** (04-12) BrowseToAnki i18n対応 — AnkiConnectからデッキ/モデル/フィールド動的取得(55bdeee)。日本語Anki対応。
- **cmd_066** (04-12) BrowseToAnki hotfix第2弾 — tabs権限+エラーハンドリング+ログ(e7747b6)。
- **cmd_065** (04-12) Claude Code Notification Hook設定。macOS標準通知でClaude入力待ちを通知。
- **cmd_064** (04-12) BrowseToAnki+MemeSnap致命的バグ修正 — メッセージングフロー(b7ea355, a6c821f)。
- **cmd_063** (04-12) BrowseToAnki+MemeSnap Ollama対応(e8709ca, 5caa723)。APIキー不要で利用可能に。
- **cmd_062** (04-11) PageBreakerポリッシュ: HUDアイコン重複修正+スローボール削除(450dec6)。
- **cmd_061** (04-11) PageBreaker殿FB3点: 壊れた文字残す+アイテム永続化+メガボール(1c7e484)。
- **cmd_060** (04-11) PageBreaker v2: アイテム6種+文字ブロック化(+900行)。QC一発PASS(65ed4c3)。
- **cmd_059** (04-11) Chrome拡張公開ガイド+殿アクションリスト作成（1f436b1）。
- **cmd_058** (04-11) dashboard.md簡潔化（294→63行）+shogun_log.mdアーカイブ作成。
- **cmd_057** (04-04) PageBreaker QC+MemeSnap開発。4拡張連続QC PASS、公開準備完了。
- **cmd_056** (04-04) PageBreaker MVP完成+エンタメ拡張10案（MemeSnap推奨）。
- **cmd_055** (04-04) BrowseToAnki MINOR修正5点中4点完了。③連絡先メールのみ殿待ち。
- **cmd_054** (04-03) BrowseToAnki Chrome拡張開発。QC PASS、公開準備完了。
- **cmd_053** (04-03) Chrome拡張収益化PJ。KindleSnap実装→QC→公開準備完了(zip 201KB)。
- **cmd_052** (03-31) 字幕音声同期の根本修正。WordBoundary直接使用。ep001_v4.mp4。
- **cmd_051** (03-31) 動画品質テンプレート化+3品質課題修正。ep001_v3.mp4。

※cmd_050以前は shogun_log.md 参照

## 🚨 要対応

### ✅ kindle-snap v1.1 拡張reload — 解決済 (CDP自動化)

将軍が CDP プロトコル経由で拡張 reload 実施 (chrome.runtime.reload() + Page.reload)。
殿の手動↺押下は今後不要。軍師 Phase C 実行中。

---

### kindle-snap v1.1 残りの殿依存

- **cmd_102 (Phase 6: 統合smoke)**: 全Phase完了後に5-10ページ連続キャプチャ確認 (約15-20分)。

---

### cmd_094 MINOR 4件 — v1.1 に吸収済

cmd_094 MINOR + cmd_093/093b E2E は v1.1 Phase 3-5 で根治。独立追撃停止。
Playwright検証結果 (2026-04-23): FAIL — (1)Amazon認証壁 (2)Chrome拡張ロード不可。CDP接続方式で Phase 2 以降に再検証。

**手順 (15分)**:
1. `chrome://extensions/` で kindle-snap 「更新」↺ → Kindle Cloud Reader タブ (reader, ?asin=含む) を開く
2. **【①1-page目視】** 3ページ以上洋書→Start Capture→PDF **余白・切れ無し確認** (MINOR-B 回帰検証: .pagination-container rectが広すぎて余白出る可能性)
3. **【②2-page分割】** 同本2-page表示→Start Capture→左右別PDF展開、ガター無し
4. **【③capture中 Start Capture】** capture進行中に再度Start Capture押下→force-reset発動し新走査開始するか (race観察)
5. **【④3連続成功】** 単独Reader タブで Start Capture→PDF完了→再Start→3回連続成功 (本丸AC)
6. **【⑤fallback健全性】** Console で `[dom-detection] stage=ionic-pagination` 選択されているか、fallback時 stage=ionic-img/renderer 順位保持か
7. Consoleログを `docs/lord_reports/cmd093b_e2e.txt` に保存→家老にinbox通知

**軍師MINOR観測** (E2E必須、次cmd候補):
- [MINOR-A] SW force-reset が in-flight runCaptureLoop 非cancel → 連打race可能性、殿意思優先で受容
- [MINOR-B] .pagination-container rect が実画像より広め→1-page PDFに微量余白回帰リスク (**①で必ず目視**)
- [MINOR-C] visibility:hidden 要素除外無
- [MINOR-D] stage_0 と goToNextPageMulti が同一selector→capture中の誤click発火
- [INFO-E] cmd_090 ionic-img成功経緯ログ観測推奨

- [ ] ①1-page余白目視
- [ ] ②2-page分割
- [ ] ③capture中force-reset
- [ ] ④3連続capture (本丸AC)
- [ ] ⑤fallback健全性

### 🔧 殿の裁量判断 (kindle-snap push先設定)

kindle-snap ローカルリポに makotonos remote 未設定で `git push` 不可。以下いずれかを裁量決定:
- (a) makotonos GitHub に `kindle-snap` リポ新規作成 → `git remote add origin git@github.com:makotonos/kindle-snap.git` → 足軽がpush
- (b) 既存 `makotonos/makotoProj` モノレポに統合 (subtree/submodule)
- (c) 当面localのみ (E2E検証はdist反映で成立、push はストア公開時期に合わせる)

現状: local commits (cmd_090=6d2fdf4, 090b=d34c037, 091=8ee200a, 093=0807682, 093b=43afbe5)。
- [ ] 殿判断 → 家老に inbox で指示

---

### ▶ 今すぐ殿が確認可能 (ビルド反映済、いつでもE2E可)

**推奨実行順 (合計約15分)**: ① `chrome://extensions/` で全拡張一括「更新」↺ → ② cmd_078/076 視認 (2分) → ③ cmd_075/071/069 MemeSnap連続E2E (10分) → ④ cmd_068 BrowseToAnki (3分)

#### cmd_078 CatStroll アイコン確認 (1分)
1. `chrome://extensions/` → CatStroll「更新」↺
2. 拡張アイコン16/48/128が琥珀色フラット猫デザインで表示されるか
- [ ] 殿のChrome再読込確認

#### cmd_076 CatStroll manifest修正 確認 (1分)
1. `chrome://extensions/` → CatStroll「更新」↺ でエラーなくロードできるか (invalid scheme警告消失)
- [ ] 殿のChrome再読込確認

#### cmd_075 MemeSnap Ollama Vision疎通 E2E (3分)
1. `chrome://extensions/` → MemeSnap「更新」↺
2. Google画像検索で適当な画像ページ→右クリ→「MemeSnap this!」
3. Ollama (llava/llama3.2-vision) でキャプション返却成功・JSON.parse失敗消失
- [ ] 殿のE2E確認

#### cmd_071 MemeSnap WebP→PNG統一 E2E (3分) — cmd_075と一括可
1. `chrome://extensions/` → MemeSnap「更新」↺
2. Google画像検索(WebP多め)で画像選択→キャプション取得
3. DevTools Console で base64先頭が `iVBORw0KGgo` (PNG) になっているか
- [ ] Ollama WebP成功
- [ ] Claude WebP成功

#### cmd_069 MemeSnap Vision+編集 E2E (5分)
1. `chrome://extensions/` → MemeSnap「更新」↺
2. 実画像3枚以上で右クリ→「MemeSnap this!」 (猫/グラフ/風景等)
3. Claude/Ollama 両方で画像内容に即したキャプション返却
4. プレビューで3format編集→canvas再描画→DL/コピー反映
- [ ] Claude Vision 3枚
- [ ] Ollama Vision 3枚
- [ ] 編集→再描画→DL画像が編集後

#### cmd_068 BrowseToAnki phase3 UI E2E (3分)
1. `chrome://extensions/` → BrowseToAnki「更新」↺
2. 任意Webページで10文字以上選択→紫FAB(＋)→CardPreviewで Send to Anki
3. 10秒以内に "1 card(s) sent to Anki" トースト+Ankiに実カード追加
- [ ] 殿のE2Eテスト

---

### ⏸ 保留: cmd_090 E2E完了待ち (今は触らないでOK)

以下のkindle-snap E2E項目 (cmd_082/083/084/085/086) は cmd_090 (Ionic SPA適合+2-page対応) E2E完了後にまとめて再確認。今は cmd_090 1-page-mode E2E (上記🔥) に集中されたし。

- **cmd_086** 追撃E2E (logger race fix同梱版, 729f85b) — [dom-detection:candidates]全件出力+本文欠落なし+3ページ確認
- **cmd_085** 根本対応E2E — bounds 300×300以上+ArrowRight iframe到達+3ページキャプチャ
- **cmd_084** 3壁根治E2E — タイトル取得+複数ページ継続+PDF実保存
- **cmd_083** Reader bounds 実機確認 — selectorログ + Reader area not found消失
- **cmd_082** 可視化 Chrome再読込確認 — Recent Logs/詳細ログモーダル表示

### cmd_072 CatStroll ブランチ整理 + lord_action_list.md コミット
- [ ] 足軽3号のcommit 91bc97e が web_update_alert/first ブランチ発。main取り込み確認
- [ ] docs/lord_action_list.md の×5拡張化更新は未commit（shogun裁量で確認後commit）

### 🎯 Chrome拡張 殿の作業リスト
**共通（1回だけ）**
- [ ] Chrome Web Store開発者アカウント登録（$5）
- [ ] 連絡先メールアドレス決定（全拡張のprivacy-policy.md用）
- [ ] makotonos GitHub組織にリポ作成: kindle-snap, browse-to-anki, page-breaker, meme-snap, catstroll

**各拡張（×5: KindleSnap/BrowseToAnki/PageBreaker/MemeSnap/CatStroll）**
- [ ] 連絡先メール → privacy-policy.md 置換
- [ ] gitリモート設定+push（makotonos/各リポ）
- [ ] ストアスクリーンショット3枚（実機キャプチャ 1280x800 PNG）
- [ ] Chrome Web Store提出（listing.md EN/JA準備済み）

推定: アカウント登録5分 + 各拡張15分 = 約1時間30分

### cmd_047 push権限エラー（2026-03-31）
- [ ] multi-agent-shogun push 403: makotonosにyohey-wリポpush権限なし。リモートURL変更 or 権限追加要。

### cmd_045/046 claude_side_income ブランチ整理
- [ ] video-templateがweb_update_alert/firstブランチ上。mainマージ要。

### cmd_040 殿のアクション待ち
- [ ] YouTubeチャンネル開設（「本日のAI開発」）
- [ ] ブログ用ドメイン取得（年間約¥1,500）
- [ ] Hugo環境セットアップ確認
- [ ] AI生成コンテンツ開示方針の決定

## 💡 NEXTアクション候補
- WikiRace Rush開発（エンタメ拡張2位、サーバー不要）
- Chrome Web Storeへの5拡張一括提出
- BrowseToAnki連絡先メール設定
- YouTube/ブログ開設
