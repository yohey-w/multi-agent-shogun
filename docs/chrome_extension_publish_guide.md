# Chrome拡張 テスト〜公開ガイド

Chrome拡張をローカルでテストし、Chrome Web Storeに公開するまでの手順書。

---

## Phase 1: ローカルテスト（所要: 各拡張10〜15分）

### 前提条件

- Node.js と npm がインストール済み
- Google Chrome ブラウザ

### 1-1. ビルド

各拡張のディレクトリに移動してビルドする。

```bash
cd /Users/mizunomakoto/Project/makotoProj/chrome_extensions/KindleSnap/
npm install && npm run build
```

```bash
cd /Users/mizunomakoto/Project/makotoProj/chrome_extensions/BrowseToAnki/
npm install && npm run build
```

```bash
cd /Users/mizunomakoto/Project/makotoProj/chrome_extensions/PageBreaker/
npm install && npm run build
```

```bash
cd /Users/mizunomakoto/Project/makotoProj/chrome_extensions/MemeSnap/
npm install && npm run build
```

### 1-2. Chromeに読み込む

1. Chrome で `chrome://extensions/` を開く
2. 右上の **「デベロッパーモード」** をONにする
3. **「パッケージ化されていない拡張機能を読み込む」** をクリック
4. 各拡張の `dist/` フォルダを選択

### 1-3. 各拡張のテスト方法

#### KindleSnap

1. [read.amazon.co.jp](https://read.amazon.co.jp) でKindle本を開く
2. ツールバーのKindleSnapアイコンをクリック
3. PDF変換が正常に動作することを確認

#### BrowseToAnki

1. **初回設定**: ツールバーのアイコンをクリック → ポップアップからClaude APIキーを設定
2. 任意のWebページでテキストを選択
3. 右クリック → コンテキストメニューからフラッシュカード生成を選択
4. フラッシュカードが正常に生成されることを確認

#### PageBreaker

1. 任意のWebページでツールバーのアイコンをクリック
2. ページ上でブロック崩しゲームが開始される
3. ゲームが動作することを確認
4. ESCキーで終了

#### MemeSnap

1. **初回設定**: ツールバーのアイコンをクリック → ポップアップからClaude APIキーを設定
2. 任意のWebページで画像を右クリック
3. **「MemeSnap this!」** を選択
4. ミーム生成UIが表示され、画像が加工されることを確認

### 1-4. エラー確認方法

問題が起きたら以下の方法でエラーを確認する。

| 確認箇所 | 手順 |
|----------|------|
| 拡張エラー | `chrome://extensions/` → 該当拡張の **「エラー」** ボタン |
| ポップアップのコンソール | ポップアップ画面を右クリック → **「検証」** → Console タブ |
| Service Worker のコンソール | `chrome://extensions/` → 該当拡張の **「Service Worker」** リンクをクリック → Console タブ |

---

## Phase 2: Chrome Web Store 公開（所要: 各拡張30〜60分 + 審査1〜3営業日）

### Step 1: 開発者アカウント登録（初回のみ、所要: 5分）

1. [Chrome Web Store Developer Dashboard](https://chrome.google.com/webstore/devconsole/) にアクセス
2. Googleアカウントでログイン
3. 開発者登録料 **$5**（一度きり）を支払う
4. 登録完了

### Step 2: zipファイル作成（所要: 1分/拡張）

各拡張の `dist/` フォルダをzip化する。

```bash
cd /Users/mizunomakoto/Project/makotoProj/chrome_extensions/KindleSnap/dist
zip -r ../KindleSnap.zip .
```

```bash
cd /Users/mizunomakoto/Project/makotoProj/chrome_extensions/BrowseToAnki/dist
zip -r ../BrowseToAnki.zip .
```

```bash
cd /Users/mizunomakoto/Project/makotoProj/chrome_extensions/PageBreaker/dist
zip -r ../PageBreaker.zip .
```

```bash
cd /Users/mizunomakoto/Project/makotoProj/chrome_extensions/MemeSnap/dist
zip -r ../MemeSnap.zip .
```

### Step 3: スクリーンショット撮影（所要: 5〜10分/拡張）

- **サイズ**: 1280x800 ピクセル（PNG形式）
- **枚数**: 最低1枚、推奨3枚
- **撮影方法**: macOS の `Cmd + Shift + 4` でエリア選択してキャプチャ
- **ポイント**: 各拡張を実際に動作させた状態でキャプチャする

撮影例:
- KindleSnap: PDF変換中の画面
- BrowseToAnki: フラッシュカード生成結果の画面
- PageBreaker: ブロック崩しプレイ中の画面
- MemeSnap: ミーム生成UIの画面

> **Tips**: macOSのスクリーンショットはデフォルトでデスクトップに保存される。`Cmd + Shift + 5` でサイズ指定やタイマー撮影も可能。

### Step 4: ストアに提出（所要: 15〜20分/拡張）

1. [Developer Dashboard](https://chrome.google.com/webstore/devconsole/) を開く
2. **「新しいアイテム」** をクリック
3. Step 2で作成したzipファイルをアップロード
4. 以下を入力:

| 項目 | 内容 |
|------|------|
| 名前・説明 | 各拡張の `store-assets/listing.md` に準備済み（EN/JA） |
| カテゴリ | 拡張の種類に合わせて選択 |
| スクリーンショット | Step 3で撮影した画像を添付 |
| プライバシーポリシーURL | 下記「プライバシーポリシー」セクション参照 |

5. 内容を確認し、**「審査のために提出」** をクリック

### Step 5: 審査（所要: 1〜3営業日）

- 提出後、Googleによる審査が行われる
- 審査結果はDeveloper Dashboardおよびメールで通知される

#### リジェクトされた場合

よくあるリジェクト理由:

| 理由 | 対処 |
|------|------|
| 権限の説明不足 | manifest.jsonの`permissions`に対する説明を追記 |
| スクリーンショット不備 | サイズ・枚数を確認し再撮影 |
| プライバシーポリシー不備 | URLが有効か確認、内容を充実させる |

リジェクト理由を読んで修正し、再提出する。

---

## プライバシーポリシーのホスト方法

各拡張にはすでに `privacy-policy.md` が作成済み。

### URLの作り方

GitHubリポジトリをpublicにすれば、以下のURLで自動的にアクセス可能になる:

```
https://github.com/makotonos/KindleSnap/blob/main/privacy-policy.md
https://github.com/makotonos/BrowseToAnki/blob/main/privacy-policy.md
https://github.com/makotonos/PageBreaker/blob/main/privacy-policy.md
https://github.com/makotonos/MemeSnap/blob/main/privacy-policy.md
```

### 公開前の確認事項

各 `privacy-policy.md` 内の連絡先メールアドレスが `TODO` や `example.com` のままになっている場合は、実際のメールアドレスに置換すること。

```bash
# 確認コマンド（各拡張ディレクトリで実行）
grep -n "TODO\|example.com" privacy-policy.md
```

---

## チェックリスト

公開前に各拡張で以下を確認:

- [ ] `npm install && npm run build` が成功する
- [ ] Chromeにローカル読み込みして動作確認済み
- [ ] エラーコンソールにエラーがない
- [ ] `dist/` からzipを作成済み
- [ ] スクリーンショット（1280x800 PNG）を3枚撮影済み
- [ ] `privacy-policy.md` の連絡先が実メールアドレスに更新済み
- [ ] `store-assets/listing.md` の内容を確認済み
- [ ] 開発者アカウント登録済み（初回のみ）
