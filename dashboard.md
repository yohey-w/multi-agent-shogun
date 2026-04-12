# 将軍システム ダッシュボード
最終更新: 2026-04-12 21:43

## 🐸 Frog / ストリーク
| 項目 | 値 |
|------|-----|
| ストリーク | 🔥 2日目 (最長: 3日) |
| 最終完了日 | 2026-04-12 |

## 📋 プロジェクト概況
- **chrome_extensions**: KindleSnap/BrowseToAnki/PageBreaker/MemeSnap 4拡張QC PASS済み、ストア公開待ち（殿の作業リスト→🚨要対応）
- **claude_side_income**: 動画テンプレートv4完成(ep001_v4.mp4)、YouTube開設・ブログドメイン待ち
- **web_update_alert**: Prisma7+Next15移行済み、ローカル動作確認OK、本番デプロイ待ち
- **ai_accelerate_plan**: プレゼン資料完成済み
- **multi-agent-shogun**: cmd_058完了（dashboard簡潔化済み）

## 🔄 進行中
- (なし — 全足軽待機中)

## ✅ 直近の完了（cmd_051以降）
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

### cmd_072 CatStroll ブランチ整理 + lord_action_list.md コミット
- [ ] 足軽3号のcommit 91bc97e が web_update_alert/first ブランチ発。main取り込み確認
- [ ] docs/lord_action_list.md の×5拡張化更新は未commit（shogun裁量で確認後commit）
- [ ] CatStrollをChrome Web Store作業リスト(殿の作業リスト下の各拡張×4→×5)に追加反映

### cmd_071 MemeSnap 殿のGoogle画像検索(WebP) E2E確認
WebP→PNG変換の実機確認。cmd_069/070と合わせて一括テスト可:
1. `chrome://extensions` → MemeSnap拡張🔄更新
2. Google画像検索で任意のキーワード→画像が出るページを開く
3. 右クリ→「MemeSnap this!」で画像選択
4. Ollama(llava or llama3.2-vision)で成功 → 500エラー消失、キャプション返却
5. Claudeでも成功
6. DevToolsコンソールでbase64先頭が `iVBORw0KGgo` (PNG)になっていることも確認
- [ ] Ollama(llama3.2-vision) WebP画像で成功
- [ ] Claude WebP画像で成功
- [ ] NGなら次cmdでhotfix

### cmd_069 MemeSnap 殿のVision+編集E2Eテスト
足軽のbuild+静的検証PASS。殿のブラウザで実画像E2E確認が必要:
1. `chrome://extensions` → MemeSnap拡張🔄更新（`chrome_extensions/meme-snap/dist`）
2. 猫/グラフ/風景など**実画像3枚以上**のページで右クリック→「MemeSnap this!」
3. Claude/Ollama両方で画像内容に即したキャプションが返ることを確認
4. プレビューで編集（top-bottom/caption/speech-bubbleの3format）→canvas再描画→DL/コピー画像に編集反映されるか確認
- [ ] Claude Vision 3枚テスト → 画像内容が反映されているか
- [ ] Ollama Vision 3枚テスト（llava等Visionモデル必要）→ 画像内容が反映されているか
- [ ] 編集→再描画→DL画像が編集後になっているか
- [ ] NGなら次cmdでhotfix、OKなら本件クローズ

### cmd_068 BrowseToAnki 殿の手動E2Eテスト（phase3 UI検証）
足軽の静的検証はPASS済み。殿のブラウザで実動作確認が必要（E2E layer）:
1. `chrome://extensions` → 開発者モードON → BrowseToAnki拡張の🔄更新ボタン
   （未読込なら「パッケージ化されていない拡張機能を読み込む」→ `chrome_extensions/browse-to-anki/dist` を選択）
2. 任意Webページで10文字以上を選択 → 紫のFAB（＋）をクリック
3. CardPreviewダイアログで「Send to Anki」クリック
4. 期待: 10秒以内に "1 card(s) sent to Anki" トースト＋Ankiデフォルトデッキに実カード追加
5. 失敗パス検証（任意）: AnkiConnect止めて実行→15s以内に明示的エラー表示（silent hangしないこと）
- [ ] 殿テスト実施 → 結果を次cmdで報告（NGならhotfix、OKなら本件クローズ）

### 🎯 Chrome拡張 殿の作業リスト（帰宅後すぐ着手可）
**共通（1回だけ）**
- [ ] Chrome Web Store開発者アカウント登録（$5）
- [ ] 連絡先メールアドレス決定（全拡張のprivacy-policy.md用）
- [ ] makotonos GitHub組織にリポ作成: kindle-snap, browse-to-anki, page-breaker, meme-snap

**各拡張（×4: KindleSnap/BrowseToAnki/PageBreaker/MemeSnap）**
- [ ] 連絡先メール → privacy-policy.md 置換
- [ ] gitリモート設定+push（makotonos/各リポ）
- [ ] ストアスクリーンショット3枚（実機キャプチャ 1280x800 PNG）
- [ ] Chrome Web Store提出（listing.md EN/JA準備済み）

推定: アカウント登録5分 + 各拡張15分 = 約1時間15分

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
- Chrome Web Storeへの4拡張一括提出
- BrowseToAnki連絡先メール設定
- YouTube/ブログ開設
