# 殿のアクションリスト
最終更新: 2026-04-11

## 優先度★★★（ボトルネック・すぐやれる）
ここが終わらないと公開プロセスが進まない項目:

- [ ] Chrome Web Store開発者アカウント登録（$5, 5分）
  - URL: https://chrome.google.com/webstore/devconsole/
  - Googleアカウントでログイン→$5支払い→即利用可能
- [ ] 公開用メールアドレス決定（1分）
  - 全拡張のprivacy-policy.mdに記載する連絡先
  - 推奨: 専用のGmail作成 or 既存メール
- [ ] GitHub makotonos組織にリポ4つ作成（5分）
  - kindle-snap, browse-to-anki, page-breaker, meme-snap
  - publicリポ推奨（プライバシーポリシーURLに使うため）
  - ※yohey-w組織には絶対にpushしない

## 優先度★★（公開プロセス — ★★★完了後）
4拡張それぞれに対して:

### KindleSnap
- [ ] 連絡先メールアドレス → privacy-policy.md のTODO/example.com部分を置換
- [ ] gitリモート設定+push（5分）
  ```bash
  cd /Users/mizunomakoto/Project/makotoProj/chrome_extensions/kindle-snap/
  git remote add origin https://github.com/makotonos/kindle-snap.git
  git push -u origin main
  ```
- [ ] ローカルテスト（10分）— 詳細は docs/chrome_extension_publish_guide.md Phase 1参照
- [ ] スクリーンショット撮影（5分、1280x800 PNG、最低1枚推奨3枚）
- [ ] Chrome Web Store提出（10分）— 詳細は docs/chrome_extension_publish_guide.md Phase 2参照

### BrowseToAnki
- [ ] 連絡先メールアドレス → privacy-policy.md のTODO/example.com部分を置換
- [ ] gitリモート設定+push（5分）
  ```bash
  cd /Users/mizunomakoto/Project/makotoProj/chrome_extensions/browse-to-anki/
  git remote add origin https://github.com/makotonos/browse-to-anki.git
  git push -u origin main
  ```
- [ ] ローカルテスト（10分）
- [ ] スクリーンショット撮影（5分、1280x800 PNG、最低1枚推奨3枚）
- [ ] Chrome Web Store提出（10分）

### PageBreaker
- [ ] 連絡先メールアドレス → privacy-policy.md のTODO/example.com部分を置換
- [ ] gitリモート設定+push（5分）
  ```bash
  cd /Users/mizunomakoto/Project/makotoProj/chrome_extensions/page-breaker/
  git remote add origin https://github.com/makotonos/page-breaker.git
  git push -u origin main
  ```
- [ ] ローカルテスト（10分）
- [ ] スクリーンショット撮影（5分、1280x800 PNG、最低1枚推奨3枚）
- [ ] Chrome Web Store提出（10分）

### MemeSnap
- [ ] 連絡先メールアドレス → privacy-policy.md のTODO/example.com部分を置換
- [ ] gitリモート設定+push（5分）
  ```bash
  cd /Users/mizunomakoto/Project/makotoProj/chrome_extensions/meme-snap/
  git remote add origin https://github.com/makotonos/meme-snap.git
  git push -u origin main
  ```
- [ ] ローカルテスト（10分）
- [ ] スクリーンショット撮影（5分、1280x800 PNG、最低1枚推奨3枚）
- [ ] Chrome Web Store提出（10分）

**推定所要時間**: 各拡張15分 × 4 = 約1時間

## 優先度★（余裕がある時）

### コンテンツ関連
- [ ] YouTubeチャンネル「本日のAI開発」開設+ロゴ設定（15分）
- [ ] ブログ用ドメイン取得（年間約¥1,500、10分）
- [ ] 動画サンプル ep001_v4.mp4 の最終確認（5分）
- [ ] Hugo環境セットアップ確認（10分）
- [ ] AI生成コンテンツ開示方針の決定（YouTube概要欄への記載方法）

### リポジトリ整理
- [ ] multi-agent-shogun: push先リモートURL変更（yohey-w→makotonos）
  - 現状403エラー: makotonosにyohey-wリポpush権限なし
  ```bash
  cd /Users/mizunomakoto/Project/makotoProj/ai_accelerate/multi-agent-shogun
  git remote set-url origin https://github.com/makotonos/multi-agent-shogun.git
  ```
- [ ] claude_side_income: firstブランチ→mainマージ
  - video-templateがweb_update_alert/firstブランチ上にある
  ```bash
  cd /Users/mizunomakoto/Project/makotoProj/claude_side_income
  git checkout main
  git merge first
  git push
  ```
